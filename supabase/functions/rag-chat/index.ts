// supabase/functions/rag-chat/index.ts
//
// Flutter → this function (with user JWT or anonymous flag) → embed query → pgvector → Gemini.
//
// Role-based access control:
//   • customer  → can only retrieve menu documents (customer-scoped)
//                 gets a friendly, public-facing assistant
//   • chef      → can retrieve menu + orders (chef-scoped, no prices/revenue)
//                 focused on cooking tasks, ingredient/allergy notes, kitchen ops
//   • admin     → full access to all document types
//                 focused on sales, operations, stock management
//
// Role is resolved SERVER-SIDE from the 'app_roles' table (or 'profiles').
// Client sends a role hint; the server validates it and overrides if needed.
// Unauthenticated callers default to 'customer'.
//
import { createClient } from "npm:@supabase/supabase-js@2";
import { embed, generate } from "../_shared/gemini.ts";

const URL_ = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-role-hint",
};

type AppRole = "customer" | "chef" | "admin";

// ---------- System prompts per role ----------

const SYSTEM: Record<AppRole, string> = {
  customer: `
You are Caferio's friendly restaurant assistant chatbot. You help customers with:
- Browsing our menu: what dishes we have, descriptions, prices, and whether they are available
- Dietary questions: ingredients, allergen info if available
- General questions about the restaurant

Guidelines:
- Be warm, helpful, and concise.
- Only answer from the CONTEXT provided. If you don't know, say so politely — never invent dish names, prices, or availability.
- Never discuss internal orders, kitchen operations, revenue, stock levels, or staff matters.
- Keep responses brief and customer-friendly. Use bullet points where helpful.
`.trim(),

  chef: `
You are the kitchen assistant for Caferio. The user is a CHEF.
Answer ONLY from the CONTEXT provided. If the context lacks the answer, say you don't have that information.

Focus on:
- Pending and recent orders: items, quantities, special notes, allergies
- Menu item ingredients and prep times
- Stock availability relevant to cooking
- Kitchen operations and order status

Never discuss:
- Revenue, prices, or financial data
- Customer personal information
- Admin-level reports

Be short, practical, and kitchen-focused.
`.trim(),

  admin: `
You are the management assistant for Caferio. The user is an ADMIN.
Answer ONLY from the CONTEXT provided. If the context lacks the answer, say you don't have that information.

Focus on:
- Sales, revenue, and financial summaries
- Order management: all orders including customer details and payment status
- Menu management: items, pricing, stock levels, availability
- Kitchen operations, inventory, and shortages
- Business insights and operational efficiency

Be concise, data-driven, and professional.
`.trim(),
};

// ---------- Role resolution ----------

/**
 * Resolves the caller's actual role from the database.
 * Falls back to 'customer' for anonymous/unauthenticated users.
 */
async function resolveRole(authHeader: string): Promise<AppRole> {
  if (!authHeader || !authHeader.startsWith("Bearer ")) return "customer";

  try {
    const userClient = createClient(URL_, ANON, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
    } = await userClient.auth.getUser();
    if (!user) return "customer";

    // Look up role in profiles or app_roles table
    const admin = createClient(URL_, SERVICE);

    // Try 'profiles' table first (common pattern)
    const { data: profile } = await admin
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    const role = profile?.role;
    if (role === "admin" || role === "chef" || role === "customer") {
      return role as AppRole;
    }

    // Try app_metadata as fallback
    const metaRole = user.app_metadata?.role;
    if (metaRole === "admin" || metaRole === "chef") return metaRole;

    return "customer"; // default
  } catch {
    return "customer";
  }
}

// ---------- Handler ----------

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    // 1. Resolve role server-side (never trust client role claim)
    const authHeader = req.headers.get("Authorization") ?? "";
    const role = await resolveRole(authHeader);

    // 2. Parse request body
    const { question, history = [] } = await req.json();
    if (!question || typeof question !== "string") {
      return new Response("bad request: missing question", { status: 400, headers: cors });
    }

    // 3. Embed the query
    const qEmb = await embed(question, "RETRIEVAL_QUERY");

    // 4. Retrieve role-filtered context from pgvector
    const admin = createClient(URL_, SERVICE);
    const { data: matches, error } = await admin.rpc("match_rag_documents", {
      query_embedding: qEmb,
      match_count: 8,
      caller_role: role,
    });
    if (error) throw error;

    const context = (matches ?? [])
      .map((m: any, i: number) => `[${i + 1}] ${m.content}`)
      .join("\n");

    // 5. Generate answer with role-appropriate system prompt
    const prompt = `CONTEXT:\n${context || "(no relevant information found)"}\n\nQUESTION: ${question}`;
    const answer = await generate(SYSTEM[role], history.slice(-6), prompt);

    return Response.json(
      {
        answer,
        role, // echo back resolved role (useful for debugging)
        sources: (matches ?? []).map((m: any) => m.metadata),
      },
      { headers: cors },
    );
  } catch (e) {
    console.error(e);
    return Response.json({ error: String(e) }, { status: 500, headers: cors });
  }
});
