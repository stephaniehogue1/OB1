# Work Operating Model → OpenBrain Mirror

> Make the core `thoughts` table the universal index. Every Work Operating Model entry and approved layer summary is mirrored into `thoughts` automatically via Postgres triggers, with an explicit foreign key column so the relationship is visible in the Schema Visualizer.

## What It Does

The [Work Operating Model Activation](../work-operating-model-activation/) recipe stores rich structured data in its own tables (`operating_model_entries`, `operating_model_layer_checkpoints`, etc.). Those tables are excellent for layer-aware queries and export generation, but they are invisible to the core OpenBrain MCP tools, which only read from `thoughts`.

This recipe creates a two-way connection:

1. **A foreign key column** — `mirrored_thought_id BIGINT REFERENCES thoughts(id) ON DELETE SET NULL` is added to both WOM tables. Visible in **Database → Schema Visualizer**.

2. **Database triggers** — On every INSERT/UPDATE/DELETE the WOM table receives, the corresponding row in `thoughts` is created/updated/removed, and the FK is populated. Same transaction; cannot drift.

| Source row | Mirror thought | `metadata.type` |
|---|---|---|
| `operating_model_entries` (canonical entries) | one thought per entry | `operating_model_entry` |
| `operating_model_layer_checkpoints` (approved layer summaries only) | one thought per approved checkpoint | `operating_model_summary` |

The mirror is enforced at the database level, so it can't drift — direct edits in the Supabase dashboard, future MCP servers writing to the WOM tables, and backfills all flow through the same projection.

## Why a Trigger (Not Application Code)

Application-level write-through only works if every writer goes through that one code path. A trigger guarantees the mirror regardless of who writes — the WOM MCP server, a future workflow, a manual `UPDATE` in SQL Editor, anything. It's the single source of truth.

## Caveat: Semantic Search

SQL triggers cannot call out to OpenRouter, so mirror rows have `embedding = NULL`. This means:

- ✅ `list_thoughts` — works (returns mirror rows)
- ✅ `thought_stats` — works (counts mirror rows in types/topics/people)
- ✅ Metadata filters (`metadata->>'layer' = 'friction'`, `metadata @> '{"source":"work_operating_model"}'`, etc.) — work
- ❌ `search_thoughts` (vector similarity) — will not return mirror rows until embeddings are backfilled

If you want semantic search over your operating model, add a small embedding-backfill job that selects `thoughts WHERE embedding IS NULL`, calls OpenRouter, and writes the result. A simple cron-driven Edge Function works well.

## Prerequisites

- Working OpenBrain setup ([guide](../../docs/01-getting-started.md)) — core `thoughts` table must exist
- [Work Operating Model Activation](../work-operating-model-activation/) recipe applied — `operating_model_*` tables must exist

## Steps

### 1. Run the schema

Open your Supabase SQL Editor and run [`schema.sql`](./schema.sql):

```text
https://supabase.com/dashboard/project/YOUR_PROJECT_ID/sql/new
```

This is idempotent — re-running it is safe and will only insert mirror rows for entries/checkpoints that don't already have one.

### 2. Verify

Run this in the SQL Editor:

```sql
SELECT metadata->>'type' AS type, COUNT(*) AS n
FROM thoughts
WHERE metadata @> '{"source": "work_operating_model"}'::jsonb
GROUP BY 1
ORDER BY 1;
```

You should see counts for `operating_model_entry` and `operating_model_summary` matching the number of rows in `operating_model_entries` and approved `operating_model_layer_checkpoints` respectively.

Then ask any AI client connected to your core OpenBrain MCP server:

```text
List my recent thoughts filtered by topic "operating model".
```

You should see your WOM entries appearing as thoughts.

### 3. Going forward

Nothing more to do. Every time the WOM workflow saves a layer, the trigger fires and the mirror updates automatically. The same is true if you ever edit a WOM row directly — for example, fixing a typo in the Supabase dashboard.

## How the Projection Works

### For `operating_model_entries`

**Content:**
```
[WOM/<layer>] <title>
<summary>
Cadence: <cadence>
Trigger: <trigger>
Stakeholders: <comma-separated>
Inputs: <comma-separated>
Constraints: <comma-separated>
```
(Optional fields are omitted when empty.)

**Metadata:**
```json
{
  "source": "work_operating_model",
  "source_table": "operating_model_entries",
  "source_id": "<wom entry uuid>",
  "type": "operating_model_entry",
  "topics": ["operating model", "<layer>"],
  "people": ["<stakeholders>"],
  "layer": "<layer>",
  "profile_version": <n>,
  "status": "<active|unresolved|superseded>",
  "source_confidence": "<confirmed|synthesized>",
  "friction_priority": "<low|medium|high>"   // only for friction layer
}
```

### For `operating_model_layer_checkpoints`

Only **approved** checkpoints are mirrored. Drafts and superseded checkpoints are excluded (and removed if status changes away from `approved`).

**Content:** `[WOM/<layer> summary, v<version>] <checkpoint_summary>`

**Metadata:** same shape as above but with `type: "operating_model_summary"` and `topics: ["operating model", "<layer>", "summary"]`.

## Troubleshooting

**Issue: Counts don't match after running the schema**
Solution: Check `operating_model_layer_checkpoints` — only `status = 'approved'` rows are mirrored. Drafts and superseded checkpoints are deliberately excluded.

**Issue: I want WOM entries to come back in `search_thoughts`**
Solution: Add an embedding backfill (see the caveat section above). Without embeddings, `search_thoughts` will skip these rows.

**Issue: I want to undo the mirror**
Solution: Drop the triggers, helper functions, and FK columns, then delete the mirror rows:

```sql
DROP TRIGGER IF EXISTS wom_mirror_entry_biud_trigger ON operating_model_entries;
DROP TRIGGER IF EXISTS wom_mirror_entry_ad_trigger ON operating_model_entries;
DROP TRIGGER IF EXISTS wom_mirror_checkpoint_biud_trigger ON operating_model_layer_checkpoints;
DROP TRIGGER IF EXISTS wom_mirror_checkpoint_ad_trigger ON operating_model_layer_checkpoints;
DROP FUNCTION IF EXISTS wom_mirror_entry();
DROP FUNCTION IF EXISTS wom_mirror_entry_delete();
DROP FUNCTION IF EXISTS wom_mirror_checkpoint();
DROP FUNCTION IF EXISTS wom_mirror_checkpoint_delete();
DROP FUNCTION IF EXISTS wom_compose_entry_content(operating_model_entries);
DROP FUNCTION IF EXISTS wom_compose_entry_metadata(operating_model_entries);
DROP FUNCTION IF EXISTS wom_compose_checkpoint_content(operating_model_layer_checkpoints);
DROP FUNCTION IF EXISTS wom_compose_checkpoint_metadata(operating_model_layer_checkpoints);

ALTER TABLE operating_model_entries DROP COLUMN IF EXISTS mirrored_thought_id;
ALTER TABLE operating_model_layer_checkpoints DROP COLUMN IF EXISTS mirrored_thought_id;

DELETE FROM thoughts WHERE metadata @> '{"source": "work_operating_model"}'::jsonb;
```

**Issue: I already had summary thoughts captured by the skill (via `capture_thought`)**
Solution: Those have `metadata.source = "mcp"` and won't be touched. They coexist with the trigger-mirrored summaries, which carry `metadata.source = "work_operating_model"`. If you want to deduplicate, delete the older `source = "mcp"` summaries by hand.
