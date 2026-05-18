import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const OPENROUTER_API_KEY = Deno.env.get("OPENROUTER_API_KEY")!;
const MCP_ACCESS_KEY = Deno.env.get("MCP_ACCESS_KEY")!;

const OPENROUTER_BASE = "https://openrouter.ai/api/v1";
const EMBEDDING_MODEL = "openai/text-embedding-3-small";
const DEFAULT_BATCH_SIZE = 50;
const MAX_BATCH_SIZE = 200;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function getEmbedding(text: string): Promise<number[]> {
  const r = await fetch(`${OPENROUTER_BASE}/embeddings`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${OPENROUTER_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: EMBEDDING_MODEL,
      input: text,
    }),
  });
  if (!r.ok) {
    const msg = await r.text().catch(() => "");
    throw new Error(`OpenRouter embeddings failed: ${r.status} ${msg}`);
  }
  const d = await r.json();
  return d.data[0].embedding;
}

interface PendingRow {
  id: number;
  content: string;
}

async function runBackfill(batchSize: number): Promise<{
  attempted: number;
  succeeded: number;
  failed: number;
  errors: Array<{ id: number; error: string }>;
}> {
  const { data, error } = await supabase
    .from("thoughts")
    .select("id, content")
    .is("embedding", null)
    .order("created_at", { ascending: true })
    .limit(batchSize);

  if (error) throw new Error(`Fetch pending failed: ${error.message}`);

  const rows = (data ?? []) as PendingRow[];

  let succeeded = 0;
  let failed = 0;
  const errors: Array<{ id: number; error: string }> = [];

  for (const row of rows) {
    try {
      const embedding = await getEmbedding(row.content);
      const { error: updateError } = await supabase
        .from("thoughts")
        .update({ embedding })
        .eq("id", row.id);
      if (updateError) {
        failed++;
        errors.push({ id: row.id, error: updateError.message });
      } else {
        succeeded++;
      }
    } catch (err) {
      failed++;
      errors.push({ id: row.id, error: (err as Error).message });
    }
  }

  return { attempted: rows.length, succeeded, failed, errors };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type, x-brain-key",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
      },
    });
  }

  const url = new URL(req.url);
  const provided = req.headers.get("x-brain-key") || url.searchParams.get("key");
  if (!provided || provided !== MCP_ACCESS_KEY) {
    return new Response(JSON.stringify({ error: "Invalid or missing access key" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  let batchSize = DEFAULT_BATCH_SIZE;
  try {
    if (req.method === "POST" && req.headers.get("content-length") !== "0") {
      const body = await req.json().catch(() => ({}));
      if (typeof body.batch_size === "number") {
        batchSize = Math.min(Math.max(1, Math.floor(body.batch_size)), MAX_BATCH_SIZE);
      }
    }

    const result = await runBackfill(batchSize);
    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
