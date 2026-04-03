-- 001_workflow_schema_rollback.sql
-- Rollback for 001_workflow_schema.sql
-- Description: Removes the proposals, consensus_votes, and sentinel_decisions tables
--              and all associated indexes and triggers.
-- Version: 1.1.0
-- Date: 2026-04-02

BEGIN;

-- Remove trigger first (depends on function)
DROP TRIGGER IF EXISTS trg_proposals_updated_at ON proposals;

-- Remove trigger function
DROP FUNCTION IF EXISTS fn_proposals_updated_at();

-- Remove tables (order matters: child tables first due to FK)
DROP TABLE IF EXISTS sentinel_decisions CASCADE;
DROP TABLE IF EXISTS consensus_votes    CASCADE;
DROP TABLE IF EXISTS proposals           CASCADE;

COMMIT;