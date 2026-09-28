// Input validation. The username rules here MUST match the SQL in
// 20260928000001_auth_core.sql (private.is_valid_username / is_reserved_username).
// The database is the final authority; this is fast-fail + friendly errors.

export const USERNAME_RE = /^[a-z0-9][a-z0-9_-]{1,28}[a-z0-9]$/;
// The *display* form is validated too: some non-ASCII characters (e.g. KELVIN SIGN U+212A)
// lowercase to plain ASCII, so validating only the normalized form would let them through.
export const DISPLAY_USERNAME_RE = /^[A-Za-z0-9][A-Za-z0-9_-]{1,28}[A-Za-z0-9]$/;

export const RESERVED_USERNAMES = new Set([
  "admin", "administrator", "root", "system", "support", "staff", "kitchen", "chef",
  "manager", "owner", "caferio", "cafe", "moderator", "mod", "service", "null",
  "undefined", "anonymous", "guest", "help", "security", "official", "api", "auth",
]);

// bcrypt (used by GoTrue) silently ignores everything after 72 bytes.
export const PASSWORD_MIN_BYTES = 8;
export const PASSWORD_MAX_BYTES = 72;

const COMMON_PASSWORDS = new Set([
  "password", "password1", "password123", "12345678", "123456789", "1234567890",
  "qwertyui", "qwerty123", "iloveyou", "admin123", "letmein1", "welcome1",
  "abc12345", "11111111", "00000000", "caferio1", "caferio123", "passw0rd",
]);

export function normalizeUsername(u: string): string {
  return u.trim().toLowerCase();
}

export type Check<T = void> = { ok: true; value: T } | { ok: false; error: string; message: string };

export function checkUsername(input: unknown, opts: { allowReserved?: boolean } = {}): Check<{ display: string; normalized: string }> {
  if (typeof input !== "string") {
    return { ok: false, error: "invalid_username", message: "Username is required." };
  }
  // Reject control characters / newlines outright (regex `$` handling differs across engines).
  // deno-lint-ignore no-control-regex
  if (/[\u0000-\u001f\u007f]/.test(input)) {
    return { ok: false, error: "invalid_username", message: "Username contains invalid characters." };
  }
  const display = input.trim();
  const normalized = normalizeUsername(display);
  if (normalized.length < 3) {
    return { ok: false, error: "invalid_username", message: "Username must be at least 3 characters." };
  }
  if (normalized.length > 30) {
    return { ok: false, error: "invalid_username", message: "Username must be at most 30 characters." };
  }
  if (!DISPLAY_USERNAME_RE.test(display) || !USERNAME_RE.test(normalized)) {
    return {
      ok: false,
      error: "invalid_username",
      message: "Use only letters, digits, '_' or '-', starting and ending with a letter or digit.",
    };
  }
  if (!opts.allowReserved && RESERVED_USERNAMES.has(normalized)) {
    return { ok: false, error: "reserved_username", message: "This username is reserved." };
  }
  return { ok: true, value: { display, normalized } };
}

export function byteLength(s: string): number {
  return new TextEncoder().encode(s).length;
}

export function checkPassword(input: unknown, usernameNormalized?: string): Check {
  if (typeof input !== "string") {
    return { ok: false, error: "invalid_password", message: "Password is required." };
  }
  const bytes = byteLength(input);
  if (bytes < PASSWORD_MIN_BYTES) {
    return { ok: false, error: "invalid_password", message: `Password must be at least ${PASSWORD_MIN_BYTES} characters.` };
  }
  if (bytes > PASSWORD_MAX_BYTES) {
    return { ok: false, error: "invalid_password", message: `Password must be at most ${PASSWORD_MAX_BYTES} bytes.` };
  }
  if (input.trim().length === 0) {
    return { ok: false, error: "invalid_password", message: "Password cannot be blank." };
  }
  if (new Set(input).size < 4) {
    return { ok: false, error: "weak_password", message: "Password is too repetitive." };
  }
  const lower = input.toLowerCase();
  if (COMMON_PASSWORDS.has(lower)) {
    return { ok: false, error: "weak_password", message: "Password is too common." };
  }
  if (usernameNormalized && (lower === usernameNormalized || (usernameNormalized.length >= 4 && lower.includes(usernameNormalized)))) {
    return { ok: false, error: "weak_password", message: "Password must not contain your username." };
  }
  return { ok: true, value: undefined };
}

export function checkDisplayName(input: unknown): Check<string | null> {
  if (input === undefined || input === null || input === "") return { ok: true, value: null };
  if (typeof input !== "string") {
    return { ok: false, error: "invalid_name", message: "Name must be text." };
  }
  // deno-lint-ignore no-control-regex
  const cleaned = input.replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim();
  if (cleaned.length > 80) {
    return { ok: false, error: "invalid_name", message: "Name must be at most 80 characters." };
  }
  return { ok: true, value: cleaned.length ? cleaned : null };
}
