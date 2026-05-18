# Embedding Backfill

> A small scheduled Edge Function that finds any `thoughts` rows with a NULL embedding, generates an OpenRouter embedding for each, and writes it back. Makes mirrored/imported rows fully discoverable by semantic search (`search_thoughts`).

## What It Does

The core `thoughts` table has an `embedding vector(1536)` column that powers `search_thoughts` (vector similarity search). When you capture a thought via the standard MCP `capture_thought` tool, the embedding is generated synchronously. But some workflows insert rows *without* embeddings:

- The [WOM → OpenBrain Mirror](../work-operating-model-openbrain-mirror/) recipe (database triggers can't call OpenRouter)
- Bulk imports that insert rows directly
- Any future workflow that creates rows outside the standard capture flow

This recipe deploys a tiny Edge Function and a `pg_cron` schedule that fills in those missing embeddings automatically.

## How It Works

```
hourly cron tick
     │
     ▼
pg_net.http_post → Edge Function "embedding-backfill"
                        │
                        ├─ SELECT id, content FROM thoughts
                        │  WHERE embedding IS NULL LIMIT 50
                        │
                        ├─ for each row: call OpenRouter embeddings API
                        │
                        └─ UPDATE thoughts SET embedding = ... WHERE id = ...
```

Cheap when there's nothing to do (a single `SELECT` returning 0 rows). When there is work, processes up to 50 rows per run by default — adjust via `batch_size` in the request body if you have a large backlog.

## Prerequisites

- Working OpenBrain setup ([guide](../../docs/01-getting-started.md))
- Existing OpenBrain Edge Function deployed (this recipe reuses its `OPENROUTER_API_KEY` and `MCP_ACCESS_KEY` environment variables — they're project-level, so no need to set them again)
- Supabase CLI installed and linked to your project (or willingness to deploy via the dashboard UI)

## Steps

### 1. Enable the required Postgres extensions

In your Supabase SQL Editor, run:

```sql
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;
```

Both ship with Supabase but need to be explicitly enabled. (The included `schema.sql` does this automatically in step 4 if you'd rather skip ahead — running it again is harmless.)

### 2. Deploy the Edge Function

**Option A — Supabase CLI (recommended):**

```bash
cd ~/Documents/OB1
supabase functions deploy embedding-backfill --project-ref YOUR_PROJECT_REF
```

The CLI looks for the function source at `recipes/embedding-backfill/index.ts` (or wherever you copied it). If your project layout requires the function under `supabase/functions/embedding-backfill/`, copy the files there first.

**Option B — Dashboard:**

Edge Functions → "Deploy a new function" → name it exactly `embedding-backfill` → paste the contents of `index.ts` → also include `deno.json` for the import map → Deploy.

### 3. Store two vault secrets (for the cron job)

`pg_cron` runs inside Postgres, so it can't read the function's env vars. Store what it needs in Supabase Vault. In the SQL Editor:

```sql
-- Replace the placeholder values with your actual values
SELECT vault.create_secret(
  'https://YOUR_PROJECT_REF.supabase.co',
  'project_url'
);

SELECT vault.create_secret(
  'YOUR_MCP_ACCESS_KEY_VALUE',
  'mcp_access_key'
);
```

You can find your project URL on the Supabase dashboard (Project Settings → API → Project URL). Your `MCP_ACCESS_KEY` value is the same one you set when deploying the OpenBrain Edge Function — if you've forgotten it, you can look it up via `supabase secrets list --project-ref YOUR_PROJECT_REF` or reset it.

> **Note:** Vault secrets are encrypted at rest. They can only be read by privileged roles inside Postgres, which is exactly what we need for `pg_cron`.

### 4. Schedule the cron job

Open the SQL Editor and run [`schema.sql`](./schema.sql). This schedules an hourly job named `embedding-backfill-hourly` that calls the Edge Function with the right auth header.

### 5. Verify

Check the schedule exists:

```sql
SELECT jobname, schedule, active
FROM cron.job
WHERE jobname = 'embedding-backfill-hourly';
```

After the first hour ticks, check run history:

```sql
SELECT status, return_message, start_time
FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'embedding-backfill-hourly')
ORDER BY start_time DESC
LIMIT 5;
```

Count remaining un-embedded thoughts (should trend toward 0):

```sql
SELECT COUNT(*) AS pending FROM thoughts WHERE embedding IS NULL;
```

If you don't want to wait an hour for the first run, trigger it manually:

```sql
SELECT net.http_post(
  url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
         || '/functions/v1/embedding-backfill',
  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'x-brain-key', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'mcp_access_key')
  ),
  body := '{"batch_size": 200}'::jsonb,
  timeout_milliseconds := 120000
);
```

A few seconds later, recount pending thoughts — it should drop by up to 200.

## Tuning

**Schedule:** Default is hourly (`0 * * * *`). To change, edit `schema.sql` and re-run, or update directly:

```sql
SELECT cron.unschedule('embedding-backfill-hourly');
-- Then re-run cron.schedule(...) with a different cron expression.
```

Common alternatives:
- `*/15 * * * *` — every 15 minutes (near-realtime)
- `0 */6 * * *` — every 6 hours (batch mode)
- `0 3 * * *` — once daily at 3 AM

**Batch size:** Default is 50 per run. Pass `{"batch_size": N}` in the body to override (capped at 200). For a one-time large backfill, run with `200` a few times in a row.

## Cost

- **OpenRouter embeddings:** `openai/text-embedding-3-small` costs roughly $0.00002 per 1K tokens. A typical thought is 50–200 tokens, so ~$0.000004 per thought. Embedding 1,000 backfilled rows ≈ $0.004.
- **Supabase Edge Function invocations:** 720 cron runs per month (hourly) is far below the Free tier's 500K monthly limit. Empty runs are essentially free.
- **pg_net + pg_cron:** Included in Supabase Free.

## Troubleshooting

**Issue: `cron.job_run_details` shows `failed` status**
Solution: Check the `return_message` column. Common causes:
- Vault secret not set or named differently — verify with `SELECT name FROM vault.decrypted_secrets;`
- Function not deployed — check the Edge Functions list in the dashboard
- Function returned 401 — `mcp_access_key` vault value doesn't match `MCP_ACCESS_KEY` env var

**Issue: Pending count not decreasing**
Solution: Trigger a manual run (see step 5). If that returns a non-200 status, the error message in the response will pinpoint the problem.

**Issue: Some rows never get embedded**
Solution: The function skips rows individually if OpenRouter fails for that input (e.g., empty content). Check `cron.job_run_details.return_message` — the function returns counts of `attempted/succeeded/failed`, and any failures include the row IDs and error messages.

**Issue: I want to undo everything**
Solution:
```sql
SELECT cron.unschedule('embedding-backfill-hourly');
SELECT vault.delete_secret('project_url');
SELECT vault.delete_secret('mcp_access_key');
```
And delete the Edge Function from the dashboard. Existing embeddings remain on the thoughts table — they're not undone.
