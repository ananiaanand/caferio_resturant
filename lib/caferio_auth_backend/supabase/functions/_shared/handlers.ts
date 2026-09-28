// Request handlers for the four auth Edge Functions.
// All I/O goes through `Deps`, so the exact same code runs in production (real
// supabase-js client, see deps.ts) and in tests (in-memory fake).

import {
  checkDisplayName,
  checkPassword,
  checkUsername,
} from "./validation.ts";

// ------------------------------------------------------------------ types
export interface SessionOut {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  expires_at?: number;
  token_type: string;
}
export interface DbResult<T> { data: T | null; error: { message: string; status?: number; code?: string } | null }

export interface Deps {
  /** service-role RPC to the internal_* functions */
  rpc<T = unknown>(fn: string, args: Record<string, unknown>): Promise<DbResult<T>>;
  createUser(a: {
    email: string; password: string;
    app_metadata: Record<string, unknown>;
  }): Promise<DbResult<{ id: string }>>;
  updateUserPassword(id: string, password: string, opts?: { unban?: boolean }): Promise<DbResult<{ id: string }>>;
  /** validates a user JWT with GoTrue (never trusts the token by itself) */
  getUserFromJwt(jwt: string): Promise<DbResult<{ id: string; email: string | null }>>;
  /** password grant using the ANON key (this is Supabase Auth doing the authentication) */
  signInWithPassword(email: string, password: string): Promise<DbResult<{ session: SessionOut; user: { id: string } }>>;
  getRole(userId: string): Promise<string | null>;
  findUserIdByUsername(usernameNormalized: string): Promise<string | null>;
  randomAlias(): string;
  log(event: string, data?: Record<string, unknown>): void;
  sleep(ms: number): Promise<void>;
}

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*", // native mobile app: no cookies are used, tokens are in the body
  "Access-Control-Allow-Headers": "authorization, content-type, apikey, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: unknown, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store", ...CORS_HEADERS, ...extra },
  });
}
const err = (status: number, error: string, message: string, extra: Record<string, string> = {}) =>
  json(status, { error, message }, extra);

const MAX_BODY_BYTES = 4096;

async function readJson(req: Request): Promise<Record<string, unknown> | null> {
  if (!(req.headers.get("content-type") ?? "").toLowerCase().includes("application/json")) return null;
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (declared > MAX_BODY_BYTES) return null;
  const text = await req.text();
  if (text.length > MAX_BODY_BYTES) return null;
  try {
    const v = JSON.parse(text);
    return v && typeof v === "object" && !Array.isArray(v) ? v as Record<string, unknown> : null;
  } catch {
    return null;
  }
}

export function clientIp(req: Request): string {
  const h = req.headers;
  const ip = h.get("cf-connecting-ip") ?? h.get("x-real-ip") ??
    (h.get("x-forwarded-for") ?? "").split(",")[0].trim();
  return (ip || "unknown").slice(0, 64);
}

function bearer(req: Request): string | null {
  const m = /^Bearer\s+([A-Za-z0-9._~+\/-]+=*)$/i.exec(req.headers.get("authorization") ?? "");
  return m ? m[1] : null;
}

/** Extracts session_id from a JWT that GoTrue has ALREADY validated (never used for authorization). */
export function sessionIdFromJwt(jwt: string): string | null {
  try {
    const payload = jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = payload + "=".repeat((4 - (payload.length % 4)) % 4);
    const obj = JSON.parse(atob(padded));
    return typeof obj.session_id === "string" ? obj.session_id : null;
  } catch {
    return null;
  }
}

async function limited(d: Deps, key: string, limit: number, windowSec: number): Promise<boolean | "error"> {
  const r = await d.rpc<boolean>("internal_rate_limit", { p_key: key, p_limit: limit, p_window_seconds: windowSec });
  if (r.error) {
    d.log("rate_limit_rpc_error", { message: r.error.message });
    return "error";
  }
  return r.data === true; // true = still allowed
}

function preflight(req: Request): Response | null {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS_HEADERS });
  if (req.method !== "POST") return err(405, "method_not_allowed", "Use POST.", { Allow: "POST, OPTIONS" });
  return null;
}

const TOO_MANY = (retry = 60) =>
  err(429, "rate_limited", "Too many attempts. Try again later.", { "Retry-After": String(retry) });
const GENERIC_LOGIN_FAIL = () => err(401, "invalid_credentials", "Incorrect username or password.");
const INTERNAL = () => err(500, "internal_error", "Something went wrong. Try again.");

// ------------------------------------------------------------------ LOGIN
export async function handleLogin(req: Request, d: Deps): Promise<Response> {
  const pre = preflight(req);
  if (pre) return pre;

  const body = await readJson(req);
  if (!body) return err(400, "bad_request", "Invalid request.");

  // Any malformed credentials get the SAME response as wrong credentials.
  const u = checkUsername(body.username, { allowReserved: true });
  const password = body.password;
  if (!u.ok || typeof password !== "string" || password.length === 0 || password.length > 256) {
    return GENERIC_LOGIN_FAIL();
  }
  const uname = u.value.normalized;
  const ip = clientIp(req);

  // Three independent limiters. A per-username limit that ignores the IP would let an
  // attacker lock a victim out, so the tight one is keyed on (username, ip).
  const checks = [
    await limited(d, `login:ip:${ip}`, 40, 600),
    await limited(d, `login:uip:${uname}:${ip}`, 8, 900),
    await limited(d, `login:user:${uname}`, 60, 3600),
  ];
  if (checks.includes("error")) return INTERNAL();
  if (checks.includes(false)) return TOO_MANY(300);

  const lookup = await d.rpc<string>("internal_resolve_login_identity", { p_username: uname });
  if (lookup.error) {
    d.log("login_lookup_error", { message: lookup.error.message });
    return INTERNAL();
  }

  // Unknown username: still run a password grant against a throw-away alias so the
  // response time does not reveal whether the account exists.
  const alias = lookup.data ?? d.randomAlias();
  const res = await d.signInWithPassword(alias, password);

  if (res.error || !res.data) {
    const s = res.error?.status ?? 0;
    if (s >= 500 || s === 429) {
      d.log("login_upstream_error", { status: s, code: res.error?.code });
      return s === 429 ? TOO_MANY() : INTERNAL();
    }
    d.log("login_failed", { username: uname, known: lookup.data != null, code: res.error?.code });
    return GENERIC_LOGIN_FAIL();
  }

  await d.rpc("internal_rate_limit_reset", { p_key: `login:uip:${uname}:${ip}` });
  const s = res.data.session;
  return json(200, {
    session: {
      access_token: s.access_token,
      refresh_token: s.refresh_token,
      expires_in: s.expires_in,
      expires_at: s.expires_at,
      token_type: s.token_type,
    },
  });
}

// ------------------------------------------------------------------ REGISTER
export async function handleRegister(req: Request, d: Deps): Promise<Response> {
  const pre = preflight(req);
  if (pre) return pre;

  const body = await readJson(req);
  if (!body) return err(400, "bad_request", "Invalid request.");

  const u = checkUsername(body.username);
  if (!u.ok) return err(422, u.error, u.message);

  const p = checkPassword(body.password, u.value.normalized);
  if (!p.ok) return err(422, p.error, p.message);

  if (typeof body.confirm_password !== "string" || body.confirm_password !== body.password) {
    return err(422, "password_mismatch", "Passwords do not match.");
  }
  const nm = checkDisplayName(body.display_name);
  if (!nm.ok) return err(422, nm.error, nm.message);

  const ip = clientIp(req);
  const rl = [
    await limited(d, `register:ip:${ip}`, 10, 3600),
    await limited(d, `register:global`, 300, 3600),
  ];
  if (rl.includes("error")) return INTERNAL();
  if (rl.includes(false)) return TOO_MANY(600);

  // Fast, friendly duplicate check. NOT the safety net: the unique index is (see below).
  const avail = await d.rpc<boolean>("internal_username_available", { p_username: u.value.normalized });
  if (avail.error) return INTERNAL();
  if (avail.data === false) return err(409, "username_taken", "That username is not available.");

  const alias = d.randomAlias();
  const created = await d.createUser({
    email: alias,
    password: body.password as string,
    app_metadata: {
      caferio_provisioned: "true",         // required by the DB trigger; only the service role can set it
      username: u.value.display,
      ...(nm.value ? { display_name: nm.value } : {}),
    },
  });

  if (created.error || !created.data) {
    // Race lost / trigger rejected. The DB is authoritative: if the name is now taken, say so.
    const again = await d.rpc<boolean>("internal_username_available", { p_username: u.value.normalized });
    if (again.data === false) return err(409, "username_taken", "That username is not available.");
    const msg = created.error?.message ?? "";
    if (/password/i.test(msg) && (created.error?.status ?? 0) < 500) {
      return err(422, "weak_password", "Password was rejected. Choose a stronger one.");
    }
    d.log("register_create_failed", { status: created.error?.status, code: created.error?.code, message: msg });
    return INTERNAL();
  }

  // Sign in immediately so the app gets a normal Supabase session.
  const si = await d.signInWithPassword(alias, body.password as string);
  if (si.error || !si.data) {
    // Account exists; client should just call auth-login.
    d.log("register_signin_failed", { user: created.data.id });
    return json(201, { registered: true, session: null });
  }
  const s = si.data.session;
  return json(201, {
    registered: true,
    session: {
      access_token: s.access_token, refresh_token: s.refresh_token,
      expires_in: s.expires_in, expires_at: s.expires_at, token_type: s.token_type,
    },
  });
}

// ------------------------------------------------------------------ CHANGE PASSWORD (signed-in user)
export async function handleChangePassword(req: Request, d: Deps): Promise<Response> {
  const pre = preflight(req);
  if (pre) return pre;

  const jwt = bearer(req);
  if (!jwt) return err(401, "unauthorized", "Sign in required.");
  const who = await d.getUserFromJwt(jwt);
  if (who.error || !who.data || !who.data.email) return err(401, "unauthorized", "Sign in required.");
  const uid = who.data.id;

  const body = await readJson(req);
  if (!body) return err(400, "bad_request", "Invalid request.");
  const cur = body.current_password, next = body.new_password;
  if (typeof cur !== "string" || cur.length === 0 || cur.length > 256) {
    return err(422, "invalid_password", "Current password is required.");
  }
  if (typeof body.confirm_password !== "string" || body.confirm_password !== next) {
    return err(422, "password_mismatch", "Passwords do not match.");
  }
  const unameRow = await d.rpc<string>("internal_username_of", { p_user_id: uid }).catch(() => null);
  const np = checkPassword(next, unameRow?.data ?? undefined);
  if (!np.ok) return err(422, np.error, np.message);
  if (next === cur) return err(422, "weak_password", "New password must differ from the current one.");

  const rl = await limited(d, `chpw:${uid}`, 5, 900);
  if (rl === "error") return INTERNAL();
  if (rl === false) return TOO_MANY(300);

  // Re-authenticate: prove knowledge of the current password with Supabase Auth itself.
  const verify = await d.signInWithPassword(who.data.email, cur);
  if (verify.error || !verify.data) {
    const s = verify.error?.status ?? 0;
    if (s >= 500) return INTERNAL();
    return err(401, "invalid_credentials", "Current password is incorrect.");
  }

  const upd = await d.updateUserPassword(uid, next as string);
  if (upd.error) {
    d.log("chpw_update_failed", { user: uid, message: upd.error.message });
    return upd.error.status && upd.error.status < 500
      ? err(422, "weak_password", "Password was rejected. Choose a stronger one.")
      : INTERNAL();
  }

  // Kill every other session (incl. the verification session created above).
  await d.rpc("internal_revoke_sessions", { p_user_id: uid, p_except_session: sessionIdFromJwt(jwt) });
  d.log("password_changed", { user: uid });
  return json(200, { ok: true });
}

// ------------------------------------------------------------------ ADMIN RESET (no e-mail recovery exists)
export async function handleAdminReset(req: Request, d: Deps): Promise<Response> {
  const pre = preflight(req);
  if (pre) return pre;

  const jwt = bearer(req);
  if (!jwt) return err(401, "unauthorized", "Sign in required.");
  const who = await d.getUserFromJwt(jwt);
  if (who.error || !who.data) return err(401, "unauthorized", "Sign in required.");

  // Authorization comes from the database, never from the token.
  const role = await d.getRole(who.data.id);
  if (role !== "admin") {
    d.log("admin_reset_denied", { user: who.data.id });
    return err(403, "forbidden", "Not allowed.");
  }

  const rl = await limited(d, `adminreset:${who.data.id}`, 20, 3600);
  if (rl === "error") return INTERNAL();
  if (rl === false) return TOO_MANY(600);

  const body = await readJson(req);
  if (!body) return err(400, "bad_request", "Invalid request.");
  const u = checkUsername(body.username, { allowReserved: true });
  if (!u.ok) return err(422, u.error, u.message);
  const p = checkPassword(body.new_password, u.value.normalized);
  if (!p.ok) return err(422, p.error, p.message);

  const targetId = await d.findUserIdByUsername(u.value.normalized);
  if (!targetId) return err(404, "user_not_found", "No such user.");
  if (targetId === who.data.id) {
    return err(422, "use_change_password", "Use the change-password flow for your own account.");
  }

  const upd = await d.updateUserPassword(targetId, body.new_password as string, { unban: body.unban === true });
  if (upd.error) {
    d.log("admin_reset_failed", { target: targetId, message: upd.error.message });
    return INTERNAL();
  }
  await d.rpc("internal_revoke_sessions", { p_user_id: targetId, p_except_session: null });
  d.log("admin_reset_ok", { admin: who.data.id, target: targetId, unban: body.unban === true });
  return json(200, { ok: true });
}
