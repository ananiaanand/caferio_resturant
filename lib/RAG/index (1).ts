// supabase/functions/rag-chat/index.ts
// Flutter -> this function (with user JWT) -> embed query -> pgvector -> Gemini.
// Role is read from DB, NEVER trusted from client.
//
// !! Assumes table `profiles(id uuid, role text)` with role in ('admin','chef','customer').
import { createClient } from "npm:@supabase/supabase-js@2";
import { embed, generate } from "../_shared/gemini.ts";

const URL_ = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SYSTEM = (role: string) => `
You are the in-app assistant for a restaurant management app. The user is a ${role.toUpperCase()}.
Answer ONLY from the CONTEXT provided. If the context lacks the answer, say you don't have that
information. Never invent orders, prices, or stock. Be short and practical.
${role === "chef"
  ? "Focus on: orders to cook, item notes/allergies, prep, availability. Never discuss revenue or prices."
  : "Focus on: sales, orders, menu, stock, operations."}
`.trim();

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    // 1. who is calling
    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(URL_, ANON, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return new Response("unauthorized", { status: 401, headers: cors });

    const admin = createClient(URL_, SERVICE);
    const { data: profile } = await admin.from("profiles").select("role").eq("id", user.id).single();
    const role = profile?.role;
    if (role !== "admin" && role !== "chef") {
      return new Response("forbidden", { status: 403, headers: cors });
    }

    // 2. input
    const { question, history = [] } = await req.json();
    if (!question || typeof question !== "string") {
      return new Response("bad request", { status: 400, headers: cors });
    }

    // 3. retrieve (role-filtered inside SQL)
    const qEmb = await embed(question, "RETRIEVAL_QUERY");
    const { data: matches, error } = await admin.rpc("match_rag_documents", {
      query_embedding: qEmb,
      match_count: 8,
      caller_role: role,
    });
    if (error) throw error;

    const context = (matches ?? [])
      .map((m: any, i: number) => `[${i + 1}] ${m.content}`)
      .join("\n");

    // 4. generate
    const prompt = `CONTEXT:\n${context || "(nothing found)"}\n\nQUESTION: ${question}`;
    const answer = await generate(SYSTEM(role), history.slice(-6), prompt);

    return Response.json(
      { answer, sources: (matches ?? []).map((m: any) => m.metadata) },
      { headers: cors },
    );
  } catch (e) {
    console.error(e);
    return Response.json({ error: String(e) }, { status: 500, headers: cors });
  }
});
