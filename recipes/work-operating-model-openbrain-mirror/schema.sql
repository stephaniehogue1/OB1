-- ============================================
-- Work Operating Model → OpenBrain Mirror (v1.1)
-- ============================================
-- Adds database triggers that mirror every work-operating-model entry and
-- approved layer checkpoint into the core OpenBrain `thoughts` table. The
-- relationship is enforced two ways:
--
--   1. An explicit foreign key: `mirrored_thought_id BIGINT REFERENCES
--      thoughts(id) ON DELETE SET NULL` on `operating_model_entries` and
--      `operating_model_layer_checkpoints`. Visible in the Schema
--      Visualizer.
--
--   2. Postgres triggers that maintain that FK and the mirror row
--      automatically on every INSERT / UPDATE / DELETE.
--
-- After this runs, anything captured by the Work Operating Model workflow
-- is visible to `list_thoughts`, `thought_stats`, and any metadata-filtered
-- query against `thoughts` — automatically, with no application code path
-- required.
--
-- Caveat: SQL triggers cannot call OpenRouter, so mirrored rows have
-- NULL `embedding`. They will NOT appear in `search_thoughts` (semantic
-- vector search) until an embedding backfill runs. See
-- `recipes/embedding-backfill/` for the scheduled-cron solution.
--
-- Idempotent — safe to re-run. The one-time backfill at the bottom only
-- inserts/links rows that don't already have a mirror.
--
-- Prerequisite: `recipes/work-operating-model-activation` schema applied
-- (the `operating_model_*` tables must exist). The `thoughts` table from
-- the core OpenBrain setup must also exist.
--
-- Run this in your Supabase SQL Editor.
-- ============================================


-- --------------------------------------------
-- 1. Add the FK columns (idempotent)
-- --------------------------------------------
ALTER TABLE operating_model_entries
  ADD COLUMN IF NOT EXISTS mirrored_thought_id BIGINT
    REFERENCES thoughts(id) ON DELETE SET NULL;

ALTER TABLE operating_model_layer_checkpoints
  ADD COLUMN IF NOT EXISTS mirrored_thought_id BIGINT
    REFERENCES thoughts(id) ON DELETE SET NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_ome_mirrored_thought_id
  ON operating_model_entries(mirrored_thought_id)
  WHERE mirrored_thought_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_omc_mirrored_thought_id
  ON operating_model_layer_checkpoints(mirrored_thought_id)
  WHERE mirrored_thought_id IS NOT NULL;


-- --------------------------------------------
-- 2. Backfill the FK from any existing metadata.source_id linkage
--    (handles upgrade from v1.0 of this recipe)
-- --------------------------------------------
UPDATE operating_model_entries e
SET mirrored_thought_id = t.id
FROM thoughts t
WHERE e.mirrored_thought_id IS NULL
  AND t.metadata @> jsonb_build_object(
    'source', 'work_operating_model',
    'source_table', 'operating_model_entries',
    'source_id', e.id::text
  );

UPDATE operating_model_layer_checkpoints c
SET mirrored_thought_id = t.id
FROM thoughts t
WHERE c.mirrored_thought_id IS NULL
  AND c.status = 'approved'
  AND t.metadata @> jsonb_build_object(
    'source', 'work_operating_model',
    'source_table', 'operating_model_layer_checkpoints',
    'source_id', c.id::text
  );


-- --------------------------------------------
-- 3. Helpers — compose thought row from a WOM row
-- --------------------------------------------
CREATE OR REPLACE FUNCTION wom_compose_entry_content(p_row operating_model_entries)
RETURNS TEXT AS $$
DECLARE
  v_parts TEXT[] := ARRAY[]::TEXT[];
BEGIN
  v_parts := v_parts || format('[WOM/%s] %s', p_row.layer, p_row.title);
  v_parts := v_parts || p_row.summary;

  IF p_row.cadence IS NOT NULL AND p_row.cadence <> '' THEN
    v_parts := v_parts || ('Cadence: ' || p_row.cadence);
  END IF;

  IF p_row.trigger IS NOT NULL AND p_row.trigger <> '' THEN
    v_parts := v_parts || ('Trigger: ' || p_row.trigger);
  END IF;

  IF array_length(p_row.stakeholders, 1) > 0 THEN
    v_parts := v_parts || ('Stakeholders: ' || array_to_string(p_row.stakeholders, ', '));
  END IF;

  IF array_length(p_row.inputs, 1) > 0 THEN
    v_parts := v_parts || ('Inputs: ' || array_to_string(p_row.inputs, ', '));
  END IF;

  IF array_length(p_row.constraints, 1) > 0 THEN
    v_parts := v_parts || ('Constraints: ' || array_to_string(p_row.constraints, ', '));
  END IF;

  RETURN array_to_string(v_parts, E'\n');
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION wom_compose_entry_metadata(p_row operating_model_entries)
RETURNS JSONB AS $$
DECLARE
  v_meta JSONB;
BEGIN
  v_meta := jsonb_build_object(
    'source', 'work_operating_model',
    'source_table', 'operating_model_entries',
    'source_id', p_row.id::text,
    'type', 'operating_model_entry',
    'topics', to_jsonb(ARRAY['operating model', p_row.layer]),
    'people', to_jsonb(COALESCE(p_row.stakeholders, ARRAY[]::TEXT[])),
    'layer', p_row.layer,
    'profile_version', p_row.profile_version,
    'status', p_row.status,
    'source_confidence', p_row.source_confidence
  );

  IF p_row.layer = 'friction' AND p_row.details ? 'priority' THEN
    v_meta := v_meta || jsonb_build_object(
      'friction_priority', p_row.details->>'priority'
    );
  END IF;

  RETURN v_meta;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION wom_compose_checkpoint_content(p_row operating_model_layer_checkpoints)
RETURNS TEXT AS $$
BEGIN
  RETURN format(
    '[WOM/%s summary, v%s] %s',
    p_row.layer,
    p_row.profile_version,
    p_row.checkpoint_summary
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION wom_compose_checkpoint_metadata(p_row operating_model_layer_checkpoints)
RETURNS JSONB AS $$
BEGIN
  RETURN jsonb_build_object(
    'source', 'work_operating_model',
    'source_table', 'operating_model_layer_checkpoints',
    'source_id', p_row.id::text,
    'type', 'operating_model_summary',
    'topics', to_jsonb(ARRAY['operating model', p_row.layer, 'summary']),
    'layer', p_row.layer,
    'profile_version', p_row.profile_version,
    'status', p_row.status
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- --------------------------------------------
-- 4. Trigger functions (v1.1 — FK-based)
-- --------------------------------------------

-- entries: BEFORE INSERT/UPDATE writes the mirror and stamps the FK on NEW
CREATE OR REPLACE FUNCTION wom_mirror_entry()
RETURNS TRIGGER AS $$
DECLARE
  v_thought_id BIGINT;
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO thoughts (content, metadata)
    VALUES (
      wom_compose_entry_content(NEW),
      wom_compose_entry_metadata(NEW)
    )
    RETURNING id INTO v_thought_id;
    NEW.mirrored_thought_id := v_thought_id;
    RETURN NEW;
  END IF;

  -- UPDATE
  IF NEW.mirrored_thought_id IS NOT NULL THEN
    UPDATE thoughts
       SET content  = wom_compose_entry_content(NEW),
           metadata = wom_compose_entry_metadata(NEW)
     WHERE id = NEW.mirrored_thought_id;

    IF FOUND THEN
      RETURN NEW;
    END IF;
    -- thought was deleted out from under us; fall through and re-create
  END IF;

  INSERT INTO thoughts (content, metadata)
  VALUES (
    wom_compose_entry_content(NEW),
    wom_compose_entry_metadata(NEW)
  )
  RETURNING id INTO v_thought_id;
  NEW.mirrored_thought_id := v_thought_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- entries: AFTER DELETE cleans up the mirror
CREATE OR REPLACE FUNCTION wom_mirror_entry_delete()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.mirrored_thought_id IS NOT NULL THEN
    DELETE FROM thoughts WHERE id = OLD.mirrored_thought_id;
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;


-- checkpoints: same shape, but only `approved` rows get mirrored
CREATE OR REPLACE FUNCTION wom_mirror_checkpoint()
RETURNS TRIGGER AS $$
DECLARE
  v_thought_id BIGINT;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status = 'approved' THEN
      INSERT INTO thoughts (content, metadata)
      VALUES (
        wom_compose_checkpoint_content(NEW),
        wom_compose_checkpoint_metadata(NEW)
      )
      RETURNING id INTO v_thought_id;
      NEW.mirrored_thought_id := v_thought_id;
    END IF;
    RETURN NEW;
  END IF;

  -- UPDATE
  IF NEW.status <> 'approved' THEN
    -- status moved away from approved — drop the mirror
    IF NEW.mirrored_thought_id IS NOT NULL THEN
      DELETE FROM thoughts WHERE id = NEW.mirrored_thought_id;
      NEW.mirrored_thought_id := NULL;
    END IF;
    RETURN NEW;
  END IF;

  -- status = approved
  IF NEW.mirrored_thought_id IS NOT NULL THEN
    UPDATE thoughts
       SET content  = wom_compose_checkpoint_content(NEW),
           metadata = wom_compose_checkpoint_metadata(NEW)
     WHERE id = NEW.mirrored_thought_id;

    IF FOUND THEN
      RETURN NEW;
    END IF;
    -- thought was deleted out from under us; fall through and re-create
  END IF;

  INSERT INTO thoughts (content, metadata)
  VALUES (
    wom_compose_checkpoint_content(NEW),
    wom_compose_checkpoint_metadata(NEW)
  )
  RETURNING id INTO v_thought_id;
  NEW.mirrored_thought_id := v_thought_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION wom_mirror_checkpoint_delete()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.mirrored_thought_id IS NOT NULL THEN
    DELETE FROM thoughts WHERE id = OLD.mirrored_thought_id;
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;


-- --------------------------------------------
-- 5. Replace any v1.0 triggers with the new ones
-- --------------------------------------------
DROP TRIGGER IF EXISTS wom_mirror_entry_trigger ON operating_model_entries;
DROP TRIGGER IF EXISTS wom_mirror_checkpoint_trigger ON operating_model_layer_checkpoints;

CREATE TRIGGER wom_mirror_entry_biud_trigger
  BEFORE INSERT OR UPDATE ON operating_model_entries
  FOR EACH ROW
  EXECUTE FUNCTION wom_mirror_entry();

CREATE TRIGGER wom_mirror_entry_ad_trigger
  AFTER DELETE ON operating_model_entries
  FOR EACH ROW
  EXECUTE FUNCTION wom_mirror_entry_delete();

CREATE TRIGGER wom_mirror_checkpoint_biud_trigger
  BEFORE INSERT OR UPDATE ON operating_model_layer_checkpoints
  FOR EACH ROW
  EXECUTE FUNCTION wom_mirror_checkpoint();

CREATE TRIGGER wom_mirror_checkpoint_ad_trigger
  AFTER DELETE ON operating_model_layer_checkpoints
  FOR EACH ROW
  EXECUTE FUNCTION wom_mirror_checkpoint_delete();


-- --------------------------------------------
-- 6. One-time content backfill
--    For any WOM row that still has no mirror, create one and link it.
-- --------------------------------------------
DO $$
DECLARE
  r operating_model_entries%ROWTYPE;
  v_thought_id BIGINT;
BEGIN
  FOR r IN
    SELECT * FROM operating_model_entries WHERE mirrored_thought_id IS NULL
  LOOP
    INSERT INTO thoughts (content, metadata)
    VALUES (
      wom_compose_entry_content(r),
      wom_compose_entry_metadata(r)
    )
    RETURNING id INTO v_thought_id;

    UPDATE operating_model_entries
       SET mirrored_thought_id = v_thought_id
     WHERE id = r.id;
  END LOOP;
END $$;

DO $$
DECLARE
  r operating_model_layer_checkpoints%ROWTYPE;
  v_thought_id BIGINT;
BEGIN
  FOR r IN
    SELECT * FROM operating_model_layer_checkpoints
    WHERE mirrored_thought_id IS NULL AND status = 'approved'
  LOOP
    INSERT INTO thoughts (content, metadata)
    VALUES (
      wom_compose_checkpoint_content(r),
      wom_compose_checkpoint_metadata(r)
    )
    RETURNING id INTO v_thought_id;

    UPDATE operating_model_layer_checkpoints
       SET mirrored_thought_id = v_thought_id
     WHERE id = r.id;
  END LOOP;
END $$;


-- --------------------------------------------
-- Verification (uncomment to inspect)
-- --------------------------------------------
-- Count mirrored entries by layer
-- SELECT layer,
--        COUNT(*) AS total,
--        COUNT(mirrored_thought_id) AS mirrored
-- FROM operating_model_entries
-- GROUP BY 1 ORDER BY 1;
--
-- Confirm the FK is populated everywhere expected
-- SELECT 'entries' AS table, COUNT(*) AS total,
--        COUNT(mirrored_thought_id) AS with_fk
-- FROM operating_model_entries
-- UNION ALL
-- SELECT 'approved_checkpoints', COUNT(*),
--        COUNT(mirrored_thought_id)
-- FROM operating_model_layer_checkpoints WHERE status = 'approved';
