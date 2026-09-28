import { handleAdminReset } from "../_shared/handlers.ts";
import { realDeps } from "../_shared/deps.ts";

const deps = realDeps();
Deno.serve((req) =>
  handleAdminReset(req, deps).catch((e) => {
    console.error(JSON.stringify({ evt: "unhandled", message: String(e?.message ?? e) }));
    return new Response(JSON.stringify({ error: "internal_error", message: "Something went wrong. Try again." }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  })
);
