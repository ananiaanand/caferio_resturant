// supabase/functions/rag-sync/index.ts
//
// Indexes restaurant data into rag_documents with role-based access control:
//   - 'customer'  → menu items only (name, description, price, availability)
//   - 'chef'      → orders (no revenue/customer info) + menu items
//   - 'admin'     → orders (full incl. revenue/customer) + menu items
//
// Trigger modes:
//   A) POST { "mode": "full" } with header x-rag-secret → re-index everything
//   B) Database Webhook payload (INSERT/UPDATE/DELETE) → re-index single row
//
import { createClient } from "npm:@supabase/supabase-js@2";
import { embed } from "../_shared/gemini.ts";

const sb = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);
const SECRET = Deno.env.get("RAG_SYNC_SECRET")!;

type Doc = {
  source_table: string;
  source_id: string;
  content: string;
  metadata: Record<string, unknown>;
  allowed_roles: string[];
};

// ---------- Document builders ----------

/**
 * Creates THREE documents per menu item:
 *   • customer – publicly visible info (name, category, description, price, availability)
 *   • chef – same as customer + allergens / ingredient notes
 *   • admin – same as chef + stock tracking info
 */
function menuDocs(m: any): Doc[] {
  const base =
    `Menu item: ${m.name}. Category: ${m.category ?? "n/a"}. ` +
    `Description: ${m.description ?? "none"}. Price: ₹${m.price}. ` +
    `Available: ${m.is_available !== false ? "yes" : "no"}.`;

  return [
    {
      source_table: "menu_items",
      source_id: `${m.id}:customer`,
      allowed_roles: ["customer", "chef", "admin"],
      metadata: { type: "menu_item", name: m.name, role_scope: "customer" },
      content: base,
    },
    {
      source_table: "menu_items",
      source_id: `${m.id}:chef`,
      allowed_roles: ["chef", "admin"],
      metadata: { type: "menu_item", name: m.name, role_scope: "chef" },
      content:
        `${base} Ingredients: ${
          Array.isArray(m.ingredients) && m.ingredients.length
            ? m.ingredients.join(", ")
            : "not listed"
        }. Prep time: ${m.prep_time_minutes ?? "n/a"} min.`,
    },
    {
      source_table: "menu_items",
      source_id: `${m.id}:admin`,
      allowed_roles: ["admin"],
      metadata: { type: "menu_item", name: m.name, role_scope: "admin" },
      content:
        `${base} Stock: ${m.stock ?? "untracked"}. ` +
        `Prep time: ${m.prep_time_minutes ?? "n/a"} min. ` +
        `Ingredients: ${
          Array.isArray(m.ingredients) && m.ingredients.length
            ? m.ingredients.join(", ")
            : "not listed"
        }.`,
    },
  ];
}

/**
 * Creates TWO documents per order:
 *   • chef  – task info only (items, notes, table, status). No prices, no customer PII.
 *   • admin – full info including revenue and customer details.
 * Customers never see order documents.
 */
function orderDocs(o: any, items: any[]): Doc[] {
  const itemLine = items
    .map(
      (i) =>
        `${i.quantity}x ${i.item_name ?? `item#${i.menu_item_id}`}${
          i.notes ? ` (note: ${i.notes})` : ""
        }`,
    )
    .join(", ");

  const base =
    `Order #${o.id}. Status: ${o.status}. Table: ${o.table_number ?? "n/a"}. ` +
    `Placed: ${o.created_at}. Items: ${itemLine || "none"}.`;

  return [
    {
      source_table: "orders",
      source_id: `${o.id}:chef`,
      allowed_roles: ["chef", "admin"],
      metadata: { type: "order", order_id: o.id, status: o.status, role_scope: "chef" },
      content: base,
    },
    {
      source_table: "orders",
      source_id: `${o.id}:admin`,
      allowed_roles: ["admin"],
      metadata: { type: "order", order_id: o.id, status: o.status, role_scope: "admin" },
      content:
        `${base} Total: ₹${o.total_amount ?? o.total ?? "n/a"}. ` +
        `Payment: ${o.payment_status ?? "n/a"}. ` +
        `Customer ID: ${o.customer_id ?? "guest"}.`,
    },
  ];
}

// ---------- Upsert / delete ----------

async function upsert(docs: Doc[]) {
  for (const d of docs) {
    const embedding = await embed(d.content, "RETRIEVAL_DOCUMENT");
    const { error } = await sb.from("rag_documents").upsert(
      { ...d, embedding, updated_at: new Date().toISOString() },
      { onConflict: "source_table,source_id" },
    );
    if (error) throw error;
  }
}

async function removeBySource(table: string, id: string) {
  await sb
    .from("rag_documents")
    .delete()
    .eq("source_table", table)
    .or(`source_id.eq.${id},source_id.like.${id}:%`);
}

async function indexOrder(orderId: string | number) {
  const { data: o } = await sb.from("orders").select("*").eq("id", orderId).single();
  if (!o) return;
  const { data: items } = await sb
    .from("order_items")
    .select("*, menu_items(name)")
    .eq("order_id", orderId);
  // Normalise item_name
  const normalized = (items ?? []).map((i: any) => ({
    ...i,
    item_name: i.menu_items?.name ?? i.item_name ?? null,
  }));
  await upsert(orderDocs(o, normalized));
}

// ---------- Handler ----------

Deno.serve(async (req) => {
  if (req.headers.get("x-rag-secret") !== SECRET) {
    return new Response("forbidden", { status: 403 });
  }
  const body = await req.json().catch(() => ({}));

  try {
    // Full re-index
    if (body.mode === "full") {
      const { data: menu } = await sb.from("menu_items").select("*");
      for (const m of menu ?? []) await upsert(menuDocs(m));

      const { data: orders } = await sb
        .from("orders")
        .select("id")
        .order("created_at", { ascending: false })
        .limit(500);
      for (const o of orders ?? []) await indexOrder(o.id);

      return Response.json({
        ok: true,
        menu: menu?.length ?? 0,
        orders: orders?.length ?? 0,
      });
    }

    // Webhook payload: { type, table, record, old_record }
    const { type, table, record, old_record } = body;
    if (type === "DELETE") {
      await removeBySource(table, String(old_record.id));
    } else if (table === "menu_items") {
      await upsert(menuDocs(record));
    } else if (table === "orders") {
      await indexOrder(record.id);
    } else if (table === "order_items") {
      await indexOrder(record.order_id);
    }

    return Response.json({ ok: true });
  } catch (e) {
    console.error(e);
    return Response.json({ ok: false, error: String(e) }, { status: 500 });
  }
});
