// End-to-end tests of the REAL handler code (supabase/functions/_shared/handlers.ts).
//
// Postgres is real (triggers, grants, RLS, RPCs from the migrations). Only GoTrue is faked:
// FakeAuth reproduces the parts of its behaviour the handlers rely on — bcrypt password
// check, banned users, sessions table, pre-confirmed admin.createUser, updateUserById.
// It exists so the suite runs without Docker; run against `supabase start` for the real thing.
//
//   deno test -A --config supabase/functions/deno.json tests/handlers_test.ts
//   CAFERIO_TEST_PG=postgres://postgres:postgres@127.0.0.1:5432/caferio_test

import pg from "npm:pg@8.11.5";
import {
  handleAdminReset,
  handleChangePassword,
  handleLogin,
  handleRegister,
  type Deps,
} from "../supabase/functions/_shared/handlers.ts";

const PG = Deno.env.get("CAFERIO_TEST_PG") ?? "postgres://postgres:postgres@127.0.0.1:5432/caferio_test";
const pool = new pg.Pool({ connectionString: PG, max: 8 });

// deno-lint-ignore no-explicit-any
async function asService(fn: (c: pg.PoolClient) => Promise<any>): Promise<any> {
  const c = await pool.connect();
  try {
    await c.query("set role service_role");
    return await fn(c);
  } finally {
    await c.query("reset role");
    c.release();
  }
}
// deno-lint-ignore no-explicit-any
async function asOwner(fn: (c: pg.PoolClient) => Promise<any>): Promise<any> {
  const c = await pool.connect();
  try { return await fn(c); } finally { c.release(); }
}

const b64 = (o: unknown) => btoa(JSON.stringify(o)).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");

function makeDeps(): Deps & { logs: { event: string; data?: Record<string, unknown> }[]; aliases: string[] } {
  const logs: { event: string; data?: Record<string, unknown> }[] = [];
  const aliases: string[] = [];
  return {
    logs, aliases,
    async rpc(fn, args) {
      try {
        const keys = Object.keys(args);
        const call = `select public.${fn}(${keys.map((k, i) => `${k} => $${i + 1}`).join(", ")}) as r`;
        const r = await asService((c) => c.query(call, keys.map((k) => args[k])));
        return { data: r.rows[0].r, error: null };
      } catch (e) {
        return { data: null, error: { message: (e as Error).message } };
      }
    },
    async createUser({ email, password, app_metadata }) {
      const c = await pool.connect();
      try {
        const r = await c.query(
          `insert into auth.users (instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
                                   raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
           values ('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated',$1,
                   extensions.crypt($2, extensions.gen_salt('bf')), now(), $3::jsonb, '{}'::jsonb, now(), now())
           returning id`,
          [email, password, JSON.stringify({ provider: "email", providers: ["email"], ...app_metadata })],
        );
        return { data: { id: r.rows[0].id }, error: null };
      } catch (e) {
        const m = (e as { code?: string }).code === "23505" ? "A user with this email address has already been registered" : "Database error creating new user";
        return { data: null, error: { message: m, status: (e as { code?: string }).code === "23505" ? 422 : 500, code: "unexpected_failure" } };
      } finally { c.release(); }
    },
    async updateUserPassword(id, password, o) {
      const r = await asOwner((c) => c.query(
        `update auth.users set encrypted_password = extensions.crypt($2, extensions.gen_salt('bf')),
                banned_until = case when $3 then null else banned_until end where id=$1 returning id`,
        [id, password, o?.unban === true]));
      return r.rowCount ? { data: { id }, error: null } : { data: null, error: { message: "not found", status: 404 } };
    },
    async getUserFromJwt(jwt) {
      try {
        const p = JSON.parse(atob(jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
        if (jwt.split(".")[2] !== "sig") throw new Error("bad sig");
        const r = await asOwner((c) => c.query(
          `select u.id, u.email from auth.sessions s join auth.users u on u.id = s.user_id where s.id=$1 and u.id=$2`,
          [p.session_id, p.sub]));
        if (!r.rowCount) return { data: null, error: { message: "session revoked", status: 401 } };
        return { data: { id: r.rows[0].id, email: r.rows[0].email }, error: null };
      } catch {
        return { data: null, error: { message: "invalid jwt", status: 401 } };
      }
    },
    async signInWithPassword(email, password) {
      const r = await asOwner((c) => c.query(
        `select id, banned_until, (encrypted_password = extensions.crypt($2, encrypted_password)) as ok
           from auth.users where email=$1`, [email, password]));
      const row = r.rows[0];
      if (!row || !row.ok) {
        if (!row) await asOwner((c) => c.query("select extensions.crypt($1, extensions.gen_salt('bf'))", [password])); // constant-ish work
        return { data: null, error: { message: "Invalid login credentials", status: 400, code: "invalid_credentials" } };
      }
      if (row.banned_until && new Date(row.banned_until) > new Date()) {
        return { data: null, error: { message: "User is banned", status: 400, code: "user_banned" } };
      }
      const s = await asOwner((c) => c.query("insert into auth.sessions(user_id) values ($1) returning id", [row.id]));
      const tok = `h.${b64({ sub: row.id, session_id: s.rows[0].id, aud: "authenticated" })}.sig`;
      return {
        data: {
          session: { access_token: tok, refresh_token: "rt_" + crypto.randomUUID(), expires_in: 3600, token_type: "bearer" },
          user: { id: row.id },
        },
        error: null,
      };
    },
    async getRole(userId) {
      const r = await asService((c) => c.query("select role::text from public.profiles where id=$1", [userId]));
      return r.rows[0]?.role ?? null;
    },
    async findUserIdByUsername(n) {
      const r = await asService((c) => c.query("select id from public.profiles where username_normalized=$1", [n]));
      return r.rows[0]?.id ?? null;
    },
    randomAlias() {
      const a = `u${crypto.randomUUID().replaceAll("-", "")}@auth.example.test`;
      aliases.push(a);
      return a;
    },
    log(event, data) { logs.push({ event, data }); },
    sleep: () => Promise.resolve(),
  };
}

let ipCounter = 0;
const freshIp = () => `10.${(Date.now() >> 8) & 255}.${++ipCounter & 255}.${Math.floor(Math.random() * 250)}`;
const uniq = () => Math.random().toString(36).slice(2, 8);

function post(fn: "login" | "register" | "chpw" | "reset", body: unknown, o: { ip?: string; token?: string; raw?: string; headers?: Record<string, string> } = {}) {
  const h: Record<string, string> = { "content-type": "application/json", "x-forwarded-for": o.ip ?? freshIp(), ...(o.headers ?? {}) };
  if (o.token) h["authorization"] = `Bearer ${o.token}`;
  return new Request(`http://localhost/${fn}`, { method: "POST", headers: h, body: o.raw ?? JSON.stringify(body) });
}
const handlers = { login: handleLogin, register: handleRegister, chpw: handleChangePassword, reset: handleAdminReset };
async function call(d: Deps, fn: keyof typeof handlers, body: unknown, o: Parameters<typeof post>[2] = {}) {
  const res = await handlers[fn](post(fn, body, o), d);
  const text = await res.text();
  let j: any = null; try { j = JSON.parse(text); } catch { /* */ }
  return { status: res.status, json: j, text, headers: res.headers };
}

function eq(a: unknown, b: unknown, msg = "") {
  if (JSON.stringify(a) !== JSON.stringify(b)) throw new Error(`${msg} expected ${JSON.stringify(b)} got ${JSON.stringify(a)}`);
}
function ok(cond: unknown, msg: string) { if (!cond) throw new Error(msg); }

const PW = "Sunflower-Kettle-42";

async function register(d: Deps, username: string, ip?: string) {
  return await call(d, "register", { username, password: PW, confirm_password: PW }, { ip });
}

// =============================================================================== REGISTER
Deno.test("register: valid -> 201 + session; alias is random, not derived from username; role customer; no email/alias in response", async () => {
  const d = makeDeps();
  const u = "Cafe_" + uniq();
  const r = await register(d, u);
  eq(r.status, 201);
  ok(r.json.session.access_token && r.json.session.refresh_token, "session tokens missing");
  ok(!/@|email|alias|password/i.test(r.text.replace(/access_token|refresh_token/g, "")), "response leaks identity/credential fields: " + r.text);
  const row = await asOwner((c) => c.query(
    `select p.username, p.username_normalized, p.role::text, u.email, u.raw_app_meta_data->>'role' as jr
       from public.profiles p join auth.users u on u.id=p.id where p.username_normalized=$1`, [u.toLowerCase()]));
  eq(row.rows[0].username, u); eq(row.rows[0].role, "customer"); eq(row.rows[0].jr, "customer");
  ok(!row.rows[0].email.toLowerCase().includes(u.toLowerCase()), "alias contains the username (predictable)");
  eq(d.aliases.length, 1);
});

Deno.test("register: stored password is a bcrypt hash inside auth.users only; no plaintext anywhere in public/private", async () => {
  const d = makeDeps();
  const u = "hash" + uniq();
  await register(d, u);
  const r = await asOwner((c) => c.query("select encrypted_password from auth.users where email = any($1)", [d.aliases]));
  ok(/^\$2[aby]\$/.test(r.rows[0].encrypted_password), "not bcrypt");
  ok(!r.rows[0].encrypted_password.includes(PW), "plaintext");
  const dump = await asOwner((c) => c.query("select p::text t from public.profiles p where username_normalized=$1", [u]));
  ok(!dump.rows[0].t.includes(PW), "password in profiles row");
});

Deno.test("register: duplicate (different case) -> 409 and exactly one account", async () => {
  const d = makeDeps();
  const u = "dup" + uniq();
  eq((await register(d, u)).status, 201);
  const second = await register(d, u.toUpperCase());
  eq(second.status, 409); eq(second.json.error, "username_taken");
  const n = await asOwner((c) => c.query("select count(*)::int n from public.profiles where username_normalized=$1", [u]));
  eq(n.rows[0].n, 1);
});

Deno.test("register: validation errors (invalid/reserved username, weak/short/long/mismatched password, bad body)", async () => {
  const d = makeDeps();
  const base = { username: "valid" + uniq(), password: PW, confirm_password: PW };
  const cases: [string, unknown, number, string][] = [
    ["empty username", { ...base, username: "" }, 422, "invalid_username"],
    ["short", { ...base, username: "ab" }, 422, "invalid_username"],
    ["long", { ...base, username: "a".repeat(31) }, 422, "invalid_username"],
    ["space", { ...base, username: "a b c" }, 422, "invalid_username"],
    ["sql chars", { ...base, username: "x'; drop table profiles;--" }, 422, "invalid_username"],
    ["unicode", { ...base, username: "caf\u00e9x" }, 422, "invalid_username"],
    ["kelvin", { ...base, username: "\u212Aenny" }, 422, "invalid_username"],
    ["newline", { ...base, username: "abc\ndef" }, 422, "invalid_username"],
    ["number type", { ...base, username: 12345 }, 422, "invalid_username"],
    ["missing username", { password: PW, confirm_password: PW }, 422, "invalid_username"],
    ["reserved", { ...base, username: "ADMIN" }, 422, "reserved_username"],
    ["short pw", { ...base, password: "abc123", confirm_password: "abc123" }, 422, "invalid_password"],
    ["73-byte pw", { ...base, password: "a1".repeat(37), confirm_password: "a1".repeat(37) }, 422, "invalid_password"],
    ["common pw", { ...base, password: "password123", confirm_password: "password123" }, 422, "weak_password"],
    ["repetitive pw", { ...base, password: "aaaaaaaaaaaa", confirm_password: "aaaaaaaaaaaa" }, 422, "weak_password"],
    ["pw contains username", { ...base, username: "juliet77", password: "xxjuliet77xx", confirm_password: "xxjuliet77xx" }, 422, "weak_password"],
    ["mismatch", { ...base, confirm_password: PW + "x" }, 422, "password_mismatch"],
    ["no confirm", { username: base.username, password: PW }, 422, "password_mismatch"],
    ["long display name", { ...base, display_name: "x".repeat(81) }, 422, "invalid_name"],
  ];
  for (const [name, body, st, code] of cases) {
    const r = await call(d, "register", body);
    if (r.status !== st || r.json?.error !== code) throw new Error(`${name}: got ${r.status} ${r.text}`);
  }
  eq((await call(d, "register", null, { raw: "{not json" })).status, 400);
  eq((await call(d, "register", null, { raw: "[]" })).status, 400);
  eq((await call(d, "register", null, { raw: JSON.stringify({ pad: "x".repeat(5000) }) })).status, 400);
  const noCt = await handleRegister(new Request("http://x/r", { method: "POST", body: "{}" }), d);
  eq(noCt.status, 400);
});

Deno.test("register: role / restaurant / provisioning flags in the request body are ignored", async () => {
  const d = makeDeps();
  const u = "evil" + uniq();
  const r = await call(d, "register", { username: u, password: PW, confirm_password: PW, role: "admin", app_metadata: { role: "admin" }, user_metadata: { role: "admin" }, caferio_provisioned: "true" });
  eq(r.status, 201);
  const row = await asOwner((c) => c.query("select p.role::text r, u.raw_app_meta_data->>'role' j from public.profiles p join auth.users u on u.id=p.id where username_normalized=$1", [u]));
  eq(row.rows[0], { r: "customer", j: "customer" });
});

Deno.test("register: 20 parallel requests for ONE username -> exactly one 201, rest 409, one profile, no orphan auth users", async () => {
  const d = makeDeps();
  const u = "race" + uniq();
  const before = await asOwner((c) => c.query("select count(*)::int n from auth.users"));
  const rs = await Promise.all(Array.from({ length: 20 }, (_, i) => register(d, i % 2 ? u.toUpperCase() : u)));
  const statuses = rs.map((r) => r.status).sort();
  eq(statuses.filter((s) => s === 201).length, 1, "winners");
  ok(statuses.every((s) => s === 201 || s === 409), "unexpected statuses " + statuses);
  const after = await asOwner((c) => c.query("select count(*)::int n from auth.users"));
  const prof = await asOwner((c) => c.query("select count(*)::int n from public.profiles where username_normalized=$1", [u]));
  eq(prof.rows[0].n, 1); eq(after.rows[0].n - before.rows[0].n, 1, "orphan/extra auth users");
});

Deno.test("register: per-IP rate limit (10/h) then 429 with Retry-After", async () => {
  const d = makeDeps();
  const ip = freshIp();
  let last = 0;
  for (let i = 0; i < 11; i++) last = (await call(d, "register", { username: "rl" + uniq() + i, password: PW, confirm_password: PW }, { ip })).status;
  eq(last, 429);
  const r = await call(d, "register", { username: "rl" + uniq(), password: PW, confirm_password: PW }, { ip });
  ok(r.headers.get("retry-after"), "no Retry-After");
});

// =============================================================================== LOGIN
Deno.test("login: OK, case/space-insensitive; response has session only (no email/alias/user info)", async () => {
  const d = makeDeps();
  const u = "Login" + uniq();
  await register(d, u);
  for (const variant of [u, u.toLowerCase(), u.toUpperCase(), `  ${u}  `]) {
    const r = await call(d, "login", { username: variant, password: PW });
    eq(r.status, 200, variant);
    eq(Object.keys(r.json), ["session"]);
    ok(!/@|email|alias/i.test(r.text), "leak: " + r.text);
    eq(r.json.session.token_type, "bearer");
  }
});

Deno.test("login: legacy account (old @myapp.app alias) still logs in with its username", async () => {
  const d = makeDeps();
  const r = await call(d, "login", { username: "ALICE", password: "alicepass1" });
  eq(r.status, 200);
});

Deno.test("login: wrong password / unknown user / malformed input -> IDENTICAL 401 body (no enumeration)", async () => {
  const d = makeDeps();
  const u = "enum" + uniq();
  await register(d, u);
  const bodies = new Set<string>();
  const inputs: unknown[] = [
    { username: u, password: "wrong-Pass-1" },
    { username: "nobody" + uniq(), password: "wrong-Pass-1" },
    { username: "x", password: "wrong-Pass-1" },
    { username: "bad user!", password: "wrong-Pass-1" },
    { username: u },
    { password: PW },
    { username: 5, password: 5 },
    { username: u, password: "" },
    { username: u, password: "x".repeat(300) },
  ];
  for (const b of inputs) {
    const r = await call(d, "login", b);
    eq(r.status, 401, JSON.stringify(b));
    bodies.add(r.text);
  }
  eq(bodies.size, 1, "responses differ: " + [...bodies].join(" | "));
});

Deno.test("login: SQL-injection usernames/passwords are inert", async () => {
  const d = makeDeps();
  for (const s of ["' or '1'='1", "admin'--", "a\"; drop table public.profiles; --", "\\'; select pg_sleep(5);--"]) {
    eq((await call(d, "login", { username: s, password: s })).status, 401);
  }
  const t = await asOwner((c) => c.query("select to_regclass('public.profiles') is not null t"));
  eq(t.rows[0].t, true);
});

Deno.test("login: brute force -> 429 after 8 bad tries per (user, ip); correct password then blocked too; other IP unaffected", async () => {
  const d = makeDeps();
  const u = "brute" + uniq();
  await register(d, u);
  const ip = freshIp();
  const codes: number[] = [];
  for (let i = 0; i < 8; i++) codes.push((await call(d, "login", { username: u, password: "nope-nope-" + i }, { ip })).status);
  ok(codes.every((c) => c === 401), "first 8 should be 401: " + codes);
  eq((await call(d, "login", { username: u, password: "nope-nope-9" }, { ip })).status, 429);
  eq((await call(d, "login", { username: u, password: PW }, { ip })).status, 429, "lockout must also apply to the correct password");
  eq((await call(d, "login", { username: u, password: PW }, { ip: freshIp() })).status, 200, "attacker must not lock the victim out from elsewhere");
});

Deno.test("login: successful login resets the (user, ip) failure counter", async () => {
  const d = makeDeps();
  const u = "reset" + uniq();
  await register(d, u);
  const ip = freshIp();
  for (let r = 0; r < 3; r++) {
    for (let i = 0; i < 6; i++) eq((await call(d, "login", { username: u, password: "bad-bad-" + i }, { ip })).status, 401);
    eq((await call(d, "login", { username: u, password: PW }, { ip })).status, 200);
  }
});

Deno.test("login: banned account (e.g. legacy weak admin) cannot sign in; generic error", async () => {
  const d = makeDeps();
  const r = await call(d, "login", { username: "admin", password: "admin" });
  eq(r.status, 401); eq(r.json.error, "invalid_credentials");
});

Deno.test("login: GoTrue outage (5xx) -> 500 not 401; internal alias/log never contain password", async () => {
  const d = makeDeps();
  const u = "down" + uniq();
  await register(d, u);
  const broken: Deps = { ...d, signInWithPassword: () => Promise.resolve({ data: null, error: { message: "boom", status: 503 } }) };
  const r = await call(broken, "login", { username: u, password: PW });
  eq(r.status, 500);
  ok(!JSON.stringify(d.logs).includes(PW), "password in logs");
});

Deno.test("http: GET -> 405, OPTIONS -> 204 with CORS, no stack traces", async () => {
  const d = makeDeps();
  const g = await handleLogin(new Request("http://x/l", { method: "GET" }), d);
  eq(g.status, 405);
  const o = await handleLogin(new Request("http://x/l", { method: "OPTIONS" }), d);
  eq(o.status, 204); ok(o.headers.get("access-control-allow-headers")?.includes("authorization"), "cors");
});

// =============================================================================== CHANGE PASSWORD
async function signedIn(d: Deps, u: string) {
  await register(d, u);
  const l = await call(d, "login", { username: u, password: PW });
  return l.json.session.access_token as string;
}

Deno.test("change-password: needs valid token, right current password, valid new password; revokes OTHER sessions only", async () => {
  const d = makeDeps();
  const u = "chpw" + uniq();
  await register(d, u);
  const tokA = (await call(d, "login", { username: u, password: PW })).json.session.access_token as string; // device A
  const tokB = (await call(d, "login", { username: u, password: PW })).json.session.access_token as string; // device B
  const NEW = "Marmalade-Comet-77";

  eq((await call(d, "chpw", { current_password: PW, new_password: NEW, confirm_password: NEW })).status, 401, "no token");
  eq((await call(d, "chpw", { current_password: PW, new_password: NEW, confirm_password: NEW }, { token: "garbage" })).status, 401, "bad token");
  eq((await call(d, "chpw", { current_password: "wrong-Pass-1", new_password: NEW, confirm_password: NEW }, { token: tokA })).status, 401, "wrong current");
  eq((await call(d, "chpw", { current_password: PW, new_password: "short", confirm_password: "short" }, { token: tokA })).status, 422, "weak new");
  eq((await call(d, "chpw", { current_password: PW, new_password: NEW, confirm_password: NEW + "x" }, { token: tokA })).status, 422, "mismatch");
  eq((await call(d, "chpw", { current_password: PW, new_password: PW, confirm_password: PW }, { token: tokA })).status, 422, "same as old");

  const ok1 = await call(d, "chpw", { current_password: PW, new_password: NEW, confirm_password: NEW }, { token: tokA });
  eq(ok1.status, 200);

  eq((await call(d, "login", { username: u, password: PW })).status, 401, "old password must stop working");
  eq((await call(d, "login", { username: u, password: NEW })).status, 200, "new password works");
  ok((await d.getUserFromJwt(tokA)).data, "current session must survive");
  ok(!(await d.getUserFromJwt(tokB)).data, "other device session must be revoked");
});

Deno.test("change-password: rate limited (5 / 15 min)", async () => {
  const d = makeDeps();
  const u = "chrl" + uniq();
  const tok = await signedIn(d, u);
  let last = 0;
  for (let i = 0; i < 7; i++) last = (await call(d, "chpw", { current_password: "wrong-Pass-" + i, new_password: "Marmalade-Comet-77", confirm_password: "Marmalade-Comet-77" }, { token: tok })).status;
  eq(last, 429);
});

Deno.test("change-password: password may not contain own username (looked up server-side)", async () => {
  const d = makeDeps();
  const u = "zorbax" + uniq();
  const tok = await signedIn(d, u);
  const bad = `pre-${u}-post-9`;
  eq((await call(d, "chpw", { current_password: PW, new_password: bad, confirm_password: bad }, { token: tok })).status, 422);
});

// =============================================================================== ADMIN RESET
Deno.test("admin-reset: customer -> 403; anonymous -> 401; admin resets, revokes target sessions, can unban; no self-reset; 404 unknown", async () => {
  const d = makeDeps();
  const target = "tgt" + uniq(), adm = "adm" + uniq(), cust = "cus" + uniq();
  const tokTarget = await signedIn(d, target);
  const tokCust = await signedIn(d, cust);
  const tokAdm = await signedIn(d, adm);
  await asOwner((c) => c.query("select private.bootstrap_set_role($1,'admin')", [adm]));
  const NEW = "Reset-Pumpkin-2026";

  eq((await call(d, "reset", { username: target, new_password: NEW })).status, 401);
  eq((await call(d, "reset", { username: target, new_password: NEW }, { token: tokCust })).status, 403);
  eq((await call(d, "reset", { username: target, new_password: NEW }, { token: tokAdm })).status, 200);
  eq((await call(d, "login", { username: target, password: PW })).status, 401);
  eq((await call(d, "login", { username: target, password: NEW })).status, 200);
  ok(!(await d.getUserFromJwt(tokTarget)).data, "target's old session must be revoked");
  eq((await call(d, "reset", { username: adm, new_password: NEW }, { token: tokAdm })).status, 422, "self");
  eq((await call(d, "reset", { username: "ghost" + uniq(), new_password: NEW }, { token: tokAdm })).status, 404);
  eq((await call(d, "reset", { username: target, new_password: "short" }, { token: tokAdm })).status, 422);

  // unban the legacy weak admin with a strong password
  eq((await call(d, "login", { username: "admin", password: "admin" })).status, 401);
  eq((await call(d, "reset", { username: "admin", new_password: "Strong-Kettle-Pass-9!", unban: true }, { token: tokAdm })).status, 200);
  eq((await call(d, "login", { username: "admin", password: "Strong-Kettle-Pass-9!" })).status, 200);
  await asOwner((c) => c.query("update auth.users set banned_until = timestamptz '2999-12-31' where id=(select id from public.profiles where username_normalized='admin')"));
});

Deno.test("admin-reset: a customer who forges role claims in the JWT is still refused (role read from DB)", async () => {
  const d = makeDeps();
  const u = "forge" + uniq();
  await register(d, u);
  const good = (await call(d, "login", { username: u, password: PW })).json.session.access_token as string;
  const [h, p] = good.split(".");
  const payload = JSON.parse(atob(p.replace(/-/g, "+").replace(/_/g, "/")));
  payload.app_metadata = { role: "admin" }; payload.role = "admin";
  const forged = `${h}.${b64(payload)}.sig`;
  eq((await call(d, "reset", { username: "chef", new_password: "Strong-Kettle-Pass-9!" }, { token: forged })).status, 403);
});

// cleanup so the pool doesn't keep the process alive
Deno.test({ name: "zz_cleanup", sanitizeOps: false, sanitizeResources: false, fn: async () => { await pool.end(); } });
