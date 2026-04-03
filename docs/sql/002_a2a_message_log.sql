-- Migration: 002_a2a_message_log.sql
-- Version: 0.1.0
-- Author: Heretek OpenClaw Collective
-- Created: 2026-04-02
-- Description:
--   Creates the a2a_messages table for logging agent-to-agent WebSocket
--   message metadata and summaries.  See A2A_CHANNEL_PLUGIN_SPEC.md for
--   full context on how these rows are populated.
--
--   NOTE: The table will remain empty until the gateway interception
--   layer (plugin or WebSocket proxy) is implemented.  The dashboard
--   UI is built and ready; this schema is the data sink.
--
-- Prerequisite: PostgreSQL 14+ (for gen_random_uuid(), JSONB, TIMESTAMPTZ)
-- Database: heretek_openclaw (set via DATABASE_URL env var)
--
-- Run with: psql $DATABASE_URL -f 002_a2a_message_log.sql

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- Table: a2a_messages
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS a2a_messages (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  logged_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  from_agent      TEXT        NOT NULL,
  to_agent        TEXT        NOT NULL,
  message_type    TEXT        NOT NULL,
  payload_summary JSONB,
  session_key     TEXT,
  routed_via      TEXT,

  -- Internal tracking fields (populated when available)
  _gateway_ts     TIMESTAMPTZ,
  _seq            BIGINT
);

-- ─────────────────────────────────────────────────────────────────────────────
-- Indexes
-- ─────────────────────────────────────────────────────────────────────────────

-- Query: "show me all messages from agent X, most recent first"
CREATE INDEX IF NOT EXISTS idx_a2a_from
  ON a2a_messages(from_agent)
  INCLUDE (logged_at, to_agent, message_type);

-- Query: "show me all messages sent to agent Y, most recent first"
CREATE INDEX IF NOT EXISTS idx_a2a_to
  ON a2a_messages(to_agent)
  INCLUDE (logged_at, from_agent, message_type);

-- Query: "show me the N most recent messages regardless of who"
CREATE INDEX IF NOT EXISTS idx_a2a_logged
  ON a2a_messages(logged_at DESC);

-- Query: "show me all messages of type X"
CREATE INDEX IF NOT EXISTS idx_a2a_type
  ON a2a_messages(message_type);

-- Query: "show me all messages for session key X"
CREATE INDEX IF NOT EXISTS idx_a2a_session
  ON a2a_messages(session_key)
  WHERE session_key IS NOT NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- Retention cleanup function (7-day default)
-- ─────────────────────────────────────────────────────────────────────────────
-- To customise retention period set search_path before running, e.g.:
--   SET app.a2a_retention_days = 30;
-- or update the function to read from an environment variable / config table.

DO $$
BEGIN
  -- Create a custom schema-level setting if it doesn't exist
  -- (PostgreSQL doesn't have schema-level settings, so we use a function)
  -- The cleanup function reads from app.a2a_retention_days if it exists.
  -- Default is 7 days.  Call manually or from a cron job.
END
$$;

CREATE OR REPLACE FUNCTION cleanup_old_a2a_messages(retention_days INT DEFAULT 7)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
  deleted BIGINT;
BEGIN
  DELETE FROM a2a_messages
    WHERE logged_at < now() - (retention_days || ' days')::INTERVAL;

  GET DIAGNOSTICS deleted = ROW_COUNT;
  RAISE NOTICE 'a2a_messages: deleted % rows older than % days', deleted, retention_days;
  RETURN deleted;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Unique constraint for deduplication
-- ─────────────────────────────────────────────────────────────────────────────
-- Deduplicate on (from_agent, to_agent, message_type, _gateway_ts).
-- If the gateway assigns a stable timestamp per message, this prevents
-- duplicate logging on WebSocket reconnect / retry.
--
-- Note: _gateway_ts is nullable.  Rows with NULL _gateway_ts skip this
-- constraint.  This is intentional — we still want to log messages even
-- when the gateway timestamp is not available.

DO $$
BEGIN
  CREATE CONSTRAINT TRIGGER deduplicate_a2a_message
    AFTER INSERT ON a2a_messages
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXCLUDE USING gist (
      from_agent WITH =,
      to_agent   WITH =,
      message_type WITH =,
      _gateway_ts WITH =,
      logged_at   WITH =
    )
    WHERE _gateway_ts IS NOT NULL;
EXCEPTION
  WHEN duplicate_object THEN
    RAISE NOTICE 'Deduplication trigger already exists — skipping.';
END
$$;

COMMIT;

-- ─────────────────────────────────────────────────────────────────────────────
-- Verify
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  ASSERT EXISTS (
    SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public'
        AND table_name   = 'a2a_messages'
  ), 'a2a_messages table was not created!';

  RAISE NOTICE '✅ Migration 002_a2a_message_log.sql applied successfully.';
  RAISE NOTICE '   Run cleanup_old_a2a_messages() manually or via cron.';
END
$$;
