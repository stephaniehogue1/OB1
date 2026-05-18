-- ============================================
-- Work Operating Model → OpenBrain Mirror
-- ============================================
-- Adds database triggers that mirror every work-operating-model entry and
-- layer checkpoint into the core OpenBrain `thoughts` table. After this
-- runs, anything captured by the Work Operating Model workflow is visible
-- to `list_thoughts`, `thought_stats`, and any JSONB/metadata-filtered
-- query against `thoughts` — automatically, with no application code path
-- required.
--
-- Caveat: SQL triggers cannot call OpenRouter, so mirrored rows have
-- NULL `embedding`. They will NOT appear in `search_thoughts` (semantic
-- vector search) until an embedding backfill runs. See the recipe README
-- for the backfill pattern.
--
-- Idempotent — safe to re-run. The one-time backfill at the bottom only
-- inserts rows that don't already have a mirror.
--
-- Prerequisite: `recipes/work-operating-model-activation` schema applied
-- (the `operating_model_*` tables must exist). The `thoughts` table from
-- the core OpenBrain setup must also exist.
--
-- Run this in your Supabase SQL Editor.
-- ============================================


-- --------------------------------------------
-- Helper: build a thought row from a WOM entry
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

  -- friction layer carries a priority in details — expose it for filtering
  IF p_row.layer = 'friction' AND p_row.details ? 'priority' THEN
    v_meta := v_meta || jsonb_build_object(
      'friction_priority', p_row.details->>'priority'
    );
  END IF;

  RETURN v_meta;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- --------------------------------------------
-- Trigger: mirror operating_model_entries
-- --------------------------------------------
CREATE OR REPLACE FUNCTION wom_mirror_entry()
RETURNS TRIGGER AS $$
DECLARE
  v_match JSONB;
  v_updated INTEGER;
BEGIN
  IF TG_OP = 'DELETE' THEN
    DELETE FROM thoughts
    WHERE metadata @> jsonb_build_object(
      'source', 'work_operating_model',
      'source_table', 'operating_model_entries',
      'source_id', OLD.id::text
    );
    RETURN OLD;
  END IF;

  v_match := jsonb_build_object(
    'source', 'work_operating_model',
    'source_table', 'operating_model_entries',
    'source_id', NEW.id::text
  );

  IF TG_OP = 'UPDATE' THEN
    UPDATE thoughts
       SET content  = wom_compose_entry_content(NEW),
           metadata = wom_compose_entry_metadata(NEW)
     WHERE metadata @> v_match;
    GET DIAGNOSTICS v_updated = ROW_COUNT;

    IF v_updated > 0 THEN
      RETURN NEW;
    END IF;
    -- fall through to INSERT if no mirror row exists yet
  END IF;

  INSERT INTO thoughts (content, metadata)
  VALUES (
    wom_compose_entry_content(NEW),
    wom_compose_entry_metadata(NEW)
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


DROP TRIGGER IF EXISTS wom_mirror_entry_trigger ON operating_model_entries;
CREATE TRIGGER wom_mirror_entry_trigger
  AFTER INSERT OR UPDATE OR DELETE ON operating_model_entries
  FOR EACH ROW
  EXECUTE FUNCTION wom_mirror_entry();


-- --------------------------------------------
-- Trigger: mirror operating_model_layer_checkpoints
-- (layer summary rows — one per (session, layer))
-- --------------------------------------------
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


CREATE OR REPLACE FUNCTION wom_mirror_checkpoint()
RETURNS TRIGGER AS $$
DECLARE
  v_match JSONB;
  v_updated INTEGER;
BEGIN
  IF TG_OP = 'DELETE' THEN
    DELETE FROM thoughts
    WHERE metadata @> jsonb_build_object(
      'source', 'work_operating_model',
      'source_table', 'operating_model_layer_checkpoints',
      'source_id', OLD.id::text
    );
    RETURN OLD;
  END IF;

  -- only mirror approved checkpoints; superseded/draft are noise
  IF NEW.status <> 'approved' THEN
    DELETE FROM thoughts
    WHERE metadata @> jsonb_build_object(
      'source', 'work_operating_model',
      'source_table', 'operating_model_layer_checkpoints',
      'source_id', NEW.id::text
    );
    RETURN NEW;
  END IF;

  v_match := jsonb_build_object(
    'source', 'work_operating_model',
    'source_table', 'operating_model_layer_checkpoints',
    'source_id', NEW.id::text
  );

  IF TG_OP = 'UPDATE' THEN
    UPDATE thoughts
       SET content  = wom_compose_checkpoint_content(NEW),
           metadata = wom_compose_checkpoint_metadata(NEW)
     WHERE metadata @> v_match;
    GET DIAGNOSTICS v_updated = ROW_COUNT;

    IF v_updated > 0 THEN
      RETURN NEW;
    END IF;
  END IF;

  INSERT INTO thoughts (content, metadata)
  VALUES (
    wom_compose_checkpoint_content(NEW),
    wom_compose_checkpoint_metadata(NEW)
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


DROP TRIGGER IF EXISTS wom_mirror_checkpoint_trigger ON operating_model_layer_checkpoints;
CREATE TRIGGER wom_mirror_checkpoint_trigger
  AFTER INSERT OR UPDATE OR DELETE ON operating_model_layer_checkpoints
  FOR EACH ROW
  EXECUTE FUNCTION wom_mirror_checkpoint();


-- --------------------------------------------
-- One-time backfill for existing rows
-- --------------------------------------------
-- Inserts mirror rows for any WOM entry/checkpoint that doesn't already
-- have one. Safe to re-run.

INSERT INTO thoughts (content, metadata)
SELECT
  wom_compose_entry_content(e),
  wom_compose_entry_metadata(e)
FROM operating_model_entries e
WHERE NOT EXISTS (
  SELECT 1
  FROM thoughts t
  WHERE t.metadata @> jsonb_build_object(
    'source', 'work_operating_model',
    'source_table', 'operating_model_entries',
    'source_id', e.id::text
  )
);

INSERT INTO thoughts (content, metadata)
SELECT
  wom_compose_checkpoint_content(c),
  wom_compose_checkpoint_metadata(c)
FROM operating_model_layer_checkpoints c
WHERE c.status = 'approved'
  AND NOT EXISTS (
    SELECT 1
    FROM thoughts t
    WHERE t.metadata @> jsonb_build_object(
      'source', 'work_operating_model',
      'source_table', 'operating_model_layer_checkpoints',
      'source_id', c.id::text
    )
  );

-- --------------------------------------------
-- Verification (uncomment to inspect)
-- --------------------------------------------
-- SELECT metadata->>'type' AS type, COUNT(*) AS n
-- FROM thoughts
-- WHERE metadata @> '{"source": "work_operating_model"}'::jsonb
-- GROUP BY 1
-- ORDER BY 1;
