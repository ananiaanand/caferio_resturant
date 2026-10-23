// supabase/functions/_shared/gemini.ts
const KEY = Deno.env.get("GEMINI_API_KEY")!;
const BASE = "https://generativelanguage.googleapis.com/v1beta";

export const EMBED_MODEL = Deno.env.get("GEMINI_EMBED_MODEL") ?? "gemini-embedding-001";
export const CHAT_MODEL = Deno.env.get("GEMINI_CHAT_MODEL") ?? "gemini-2.5-flash";

export async function embed(
  text: string,
  taskType: "RETRIEVAL_DOCUMENT" | "RETRIEVAL_QUERY",
): Promise<number[]> {
  const res = await fetch(`${BASE}/models/${EMBED_MODEL}:embedContent`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": KEY },
    body: JSON.stringify({
      model: `models/${EMBED_MODEL}`,
      content: { parts: [{ text }] },
      taskType,
      outputDimensionality: 768, // must match vector(768)
    }),
  });
  if (!res.ok) throw new Error(`embed failed: ${res.status} ${await res.text()}`);
  const json = await res.json();
  return json.embedding.values as number[];
}

export async function generate(
  system: string,
  history: { role: "user" | "model"; text: string }[],
  prompt: string,
): Promise<string> {
  const res = await fetch(`${BASE}/models/${CHAT_MODEL}:generateContent`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": KEY },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: system }] },
      contents: [
        ...history.map((m) => ({ role: m.role, parts: [{ text: m.text }] })),
        { role: "user", parts: [{ text: prompt }] },
      ],
      generationConfig: { temperature: 0.2 },
    }),
  });
  if (!res.ok) throw new Error(`generate failed: ${res.status} ${await res.text()}`);
  const json = await res.json();
  return json.candidates?.[0]?.content?.parts?.map((p: any) => p.text).join("") ?? "";
}
