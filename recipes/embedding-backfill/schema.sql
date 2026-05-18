-- ============================================
-- Embedding Backfill — Scheduled Cron
-- ============================================
-- Schedules a recurring pg_cron job that calls the embedding-backfill
-- Edge Function. The function finds any `thoughts` rows where
-- `embedding IS NULL`, generates embeddings via OpenRouter, and writes
-- them back — making mirrored/imported rows discoverable by
-- `search_thoughts` (vector similarity search).
--
-- Prerequisites:
--   1. `pg_cron` and `pg_net` extensions enabled (see README step 1)
--   2. `embedding-backfill` Edge Function deployed (see README step 2)
--   3. Two vault secrets configured (see README step 3):
--        - project_url      → your https://YOUR_REF.supabase.co URL
--        - mcp_access_key   → same value as MCP_ACCESS_KEY env var
--
-- Idempotent — safe to re-run. The unschedule+schedule pattern below
-- replaces any prior schedule with this one.
-- ============================================


-- --------------------------------------------
-- 1. Enable required extensions
-- --------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;


-- --------------------------------------------
-- 2. Replace any existing schedule with this one
-- --------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'embedding-backfill-hourly') THEN
    PERFORM cron.unschedule('embedding-backfill-hourly');
  END IF;
END $$;


-- --------------------------------------------
-- 3. Schedule hourly backfill
-- --------------------------------------------
-- Runs at minute 0 every hour. Change the cron expression below to
-- adjust frequency. The job is cheap when there's nothing to embed
-- (single SELECT returning 0 rows).
SELECT cron.schedule(
  'embedding-backfill-hourly',
  '0 * * * *',
  $job$
  SELECT net.http_post(
    url := (
      SELECT decrypted_secret
      FROM vault.decrypted_secrets
      WHERE name = 'project_url'
    ) || '/functions/v1/embedding-backfill',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-brain-key', (
        SELECT decrypted_secret
        FROM vault.decrypted_secrets
        WHERE name = 'mcp_access_key'
      )
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000
  );
  $job$
);


-- --------------------------------------------
-- Verification
-- --------------------------------------------
-- View the scheduled job:
-- SELECT jobname, schedule, active, command
-- FROM cron.job
-- WHERE jobname = 'embedding-backfill-hourly';
--
-- View recent runs after the first hour:
-- SELECT runid, jobid, status, return_message, start_time, end_time
-- FROM cron.job_run_details
-- WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'embedding-backfill-hourly')
-- ORDER BY start_time DESC
-- LIMIT 5;
--
-- Count remaining un-embedded thoughts (should trend to 0 after each run):
-- SELECT COUNT(*) AS pending FROM thoughts WHERE embedding IS NULL;
