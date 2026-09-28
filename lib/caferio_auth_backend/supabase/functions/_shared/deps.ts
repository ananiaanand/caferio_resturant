// Production wiring: real supabase-js clients. Secrets come from Edge Function env
// (SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are injected by Supabase).
// The service-role key lives ONLY here, server-side. It must never be in the Flutter app.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import type { Deps } from "./handlers.ts";

const opts = { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } };

// Internal alias domain. It only has to be syntactically valid for GoTrue; no mail is ever
// sent to it (users are created pre-confirmed and e-mail flows are unused).
// Set ALIAS_DOMAIN to a domain YOU control (see README).
const ALIAS_DOMAIN = Deno.env.get("ALIAS_DOMAIN") ?? "caferio-auth.invalid";

export function realDeps(): Deps {
  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  if (!url || !anon || !service) throw new Error("missing Supabase env");

  const admin = createClient(url, service, opts);
  const anonClient = () => createClient(url, anon, opts); // fresh, stateless client per call

  const mapErr = (e: { message: string; status?: number; code?: string } | null) =>
    e ? { message: e.message, status: e.status, code: e.code } : null;

  return {
    async rpc(fn, args) {
      const { data, error } = await admin.rpc(fn, args);
      return { data: data as never, error: error ? { message: error.message, code: error.code } : null };
    },
    async createUser({ email, password, app_metadata }) {
      const { data, error } = await admin.auth.admin.createUser({
        email, password, email_confirm: true, user_metadata: app_metadata,
      });
      return { data: data?.user ? { id: data.user.id } : null, error: mapErr(error) };
    },
    async updateUserPassword(id, password, o) {
      const { data, error } = await admin.auth.admin.updateUserById(id, {
        password,
        ...(o?.unban ? { ban_duration: "none" } : {}),
      });
      return { data: data?.user ? { id: data.user.id } : null, error: mapErr(error) };
    },
    async getUserFromJwt(jwt) {
      // Round-trips to GoTrue: signature, expiry AND session revocation are all checked.
      const { data, error } = await admin.auth.getUser(jwt);
      return {
        data: data?.user ? { id: data.user.id, email: data.user.email ?? null } : null,
        error: mapErr(error),
      };
    },
    async signInWithPassword(email, password) {
      const { data, error } = await anonClient().auth.signInWithPassword({ email, password });
      if (error || !data.session) return { data: null, error: mapErr(error) ?? { message: "no session" } };
      const s = data.session;
      return {
        data: {
          session: {
            access_token: s.access_token, refresh_token: s.refresh_token,
            expires_in: s.expires_in, expires_at: s.expires_at, token_type: s.token_type,
          },
          user: { id: data.user.id },
        },
        error: null,
      };
    },
    async getRole(userId) {
      const { data } = await admin.from("profiles").select("role").eq("id", userId).maybeSingle();
      return (data?.role as string | undefined) ?? null;
    },
    async findUserIdByUsername(n) {
      const { data } = await admin.from("profiles").select("id").eq("username_normalized", n).maybeSingle();
      return (data?.id as string | undefined) ?? null;
    },
    randomAlias() {
      // 128 random bits: unguessable, unrelated to the username, never shown to anyone.
      const b = crypto.getRandomValues(new Uint8Array(16));
      const hex = Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
      return `u${hex}@${ALIAS_DOMAIN}`;
    },
    log(event, data) {
      // never log passwords/tokens; handlers only pass ids/usernames/status codes
      console.log(JSON.stringify({ evt: event, ...data }));
    },
    sleep: (ms) => new Promise((r) => setTimeout(r, ms)),
  };
}
