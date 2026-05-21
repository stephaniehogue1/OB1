# ChatGPT Import — Personal Configuration

> **Personal config — do NOT merge to `main` or upstream.** This file is scoped to
> the `claude/chatgpt-export-integration-8Lqj7` branch and captures the exact
> settings for re-running the ChatGPT import against this Open Brain instance.

## Recipe

[`recipes/chatgpt-conversation-import/`](../recipes/chatgpt-conversation-import/README.md)

## Priorities

Focus topics (in priority order):

1. `$BEEP Communications` (ChatGPT project folder)
2. `$BEEP` (ChatGPT project folder)
3. `YPO Forum`
4. Market intelligence
5. Home gardening
6. Horses (Monty, Luther)
7. Hammy the hamster

Health data is allowed in — just not prioritized. No exclusion clause needed.

## One-time setup

Required because we're using `--store-conversations`:

1. Open Supabase → SQL Editor
2. Paste the contents of [`recipes/chatgpt-conversation-import/schema.sql`](../recipes/chatgpt-conversation-import/schema.sql)
3. Run it (creates the `chatgpt_conversations` table)

Only needs to be done once per Open Brain instance.

## Environment variables

Pulled from the personal credential tracker — not stored here.

```bash
export SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
export OPENROUTER_API_KEY=sk-or-v1-your-key
```

## Commands

> **Shell note:** the focus string is wrapped in single quotes so `$BEEP` is
> passed through literally instead of being expanded as a shell variable.

### Dry-run (recommended first pass)

```bash
cd recipes/chatgpt-conversation-import
pip install -r requirements.txt

python import-chatgpt.py path/to/chatgpt-export.zip \
  --store-conversations \
  --focus '$BEEP Communications, $BEEP, YPO Forum, market intelligence, home gardening, horses (Monty, Luther), Hammy the hamster' \
  --dry-run --limit 10
```

### Full import

```bash
cd recipes/chatgpt-conversation-import

python import-chatgpt.py path/to/chatgpt-export.zip \
  --store-conversations \
  --focus '$BEEP Communications, $BEEP, YPO Forum, market intelligence, home gardening, horses (Monty, Luther), Hammy the hamster' \
  --report chatgpt-import-report.md
```

## Re-running after a new export

Just re-run the same command. The `chatgpt-sync-log.json` file written next to
`import-chatgpt.py` tracks which conversations have been processed (by hash and
`update_time`) — only new or changed conversations get re-imported. Delete that
file to start fresh.

## Verification

- Supabase → Table Editor → `thoughts` — filter by `metadata.source = "chatgpt"`
- Supabase → Table Editor → `chatgpt_conversations` — one row per processed
  conversation with pyramid summaries and the ChatGPT URL
- In Claude Desktop (or any MCP client): "Search my brain for thoughts from
  ChatGPT about [topic]"

## Notes

- Topics outside the focus list are still sent to the LLM but typically return
  empty thoughts. They still get a row in `chatgpt_conversations` (summary
  level), so the "I know I asked about X" lookup still works for non-focus
  material.
- Default LLM is `openai/gpt-4o-mini` via OpenRouter (~$0.001 per conversation).
  To zero out extraction cost, swap to local Ollama: append
  `--model ollama --ollama-model qwen3`. Embeddings still use OpenRouter.
