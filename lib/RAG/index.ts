// supabase/functions/rag-sync/index.ts
// Indexes restaurant data into rag_documents.
//  - Database Webhook (INSERT/UPDATE/DELETE) -> re-index one row
//  - POST {"mode":"full"} with header x-rag-secret -> re-index everything
//
// !! Table/column names below are ASSUMPTIONS. Edit builders to match your schema.
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

// ---------- builders: row -> text docs ----------
function menuDocs(m: any): Doc[] {
  return [{
    source_table: "menu_items",
    source_id: String(m.id),
    allowed_roles: ["admin", "chef"],
    metadata: { type: "menu_item", name: m.name },
    content:
      `Menu item: ${m.name}. Category: ${m.category ?? "n/a"}. ` +
      `Description: ${m.description ?? "none"}. Price: ${m.price}. ` +
      `Available: ${m.is_available ? "yes" : "no"}. ` +
      `Stock: ${m.stock ?? "untracked"}. Prep time: ${m.prep_time_minutes ?? "n/a"} min.`,
  }];
}

function orderDocs(o: any, items: any[]): Doc[] {
  const itemLine = items
    .map((i) => `${i.quantity}x ${i.item_name}${i.notes ? ` (note: ${i.notes})` : ""}`)
    .join(", ");
  const base = `Order #${o.id}. Status: ${o.status}. Table: ${o.table_number ?? "n/a"}. ` +
    `Placed: ${o.created_at}. Items: ${itemLine || "none"}.`;
  return [
    {
      // chef version: NO prices, NO customer info
      source_table: "orders",
      source_id: `${o.id}:chef`,
      allowed_roles: ["chef"],
      metadata: { type: "order", order_id: o.id, status: o.status },
      content: base,
    },
    {
      // admin version: money + customer
      source_table: "orders",
      source_id: `${o.id}:admin`,
      allowed_roles: ["admin"],
      metadata: { type: "order", order_id: o.id, status: o.status },
      content: `${base} Total: ${o.total}. Payment: ${o.payment_status ?? "n/a"}. ` +
        `Customer: ${o.customer_name ?? "guest"}.`,
    },
  ];
}

// ---------- upsert / delete ----------
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
  await sb.from("rag_documents").delete()
    .eq("source_table", table)
    .or(`source_id.eq.${id},source_id.like.${id}:%`);
}

async function indexOrder(orderId: string | number) {
  const { data: o } = await sb.from("orders").select("*").eq("id", orderId).single();
  if (!o) return;
  const { data: items } = await sb.from("order_items").select("*").eq("order_id", orderId);
  await upsert(orderDocs(o, items ?? []));
}

// ---------- handler ----------
Deno.serve(async (req) => {
  if (req.headers.get("x-rag-secret") !== SECRET) {
    return new Response("forbidden", { status: 403 });
  }
  const body = await req.json().catch(() => ({}));

  try {
    // full reindex
    if (body.mode === "full") {
      const { data: menu } = await sb.from("menu_items").select("*");
      for (const m of menu ?? []) await upsert(menuDocs(m));

      const { data: orders } = await sb.from("orders").select("id")
        .order("created_at", { ascending: false }).limit(500);
      for (const o of orders ?? []) await indexOrder(o.id);

      return Response.json({ ok: true, menu: menu?.length ?? 0, orders: orders?.length ?? 0 });
    }

    // webhook payload: { type, table, record, old_record }
    const { type, table, record, old_record } = body;
    if (type === "DELETE") {
      await removeBySource(table, String(old_record.id));
    } else if (table === "menu_items") {
      await upsert(menuDocs(record));
    } else if (table === "orders") {
      await indexOrder(record.id);
    } else if (table === "order_items") {
      await indexOrder(record.order_id); // item change -> reindex parent order
    }
    return Response.json({ ok: true });
  } catch (e) {
    console.error(e);
    return Response.json({ ok: false, error: String(e) }, { status: 500 });
  }
});
