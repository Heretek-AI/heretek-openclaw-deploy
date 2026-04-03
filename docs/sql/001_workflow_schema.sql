-- 001_workflow_schema.sql
-- Implements WORKFLOW.md PostgreSQL infrastructure
-- Version: 1.1.0
-- Date: 2026-04-02
-- Description: Core tables for proposal lifecycle, consensus voting, and Sentinel review

BEGIN;

-- ============================================================================
-- TABLE: proposals
-- Tracks the full lifecycle of collective deliberation proposals.
-- Status values: draft | deliberating | ratified | rejected | implemented
-- ============================================================================
CREATE TABLE IF NOT EXISTS proposals (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    title           TEXT NOT NULL,
    body            TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'draft',
    priority        INTEGER NOT NULL DEFAULT 5 CHECK (priority BETWEEN 1 AND 10),
    source_agent    TEXT NOT NULL,
    source_workflow TEXT NOT NULL,
    gate_phase      INTEGER CHECK (gate_phase IN (2, 3)),
    options_json    JSONB,
    deliberation_notes TEXT,
    enacted_by      TEXT,
    enacted_at      TIMESTAMPTZ
);

-- ============================================================================
-- TABLE: consensus_votes
-- Records each triad node's vote on a proposal. One row per (proposal, agent).
-- vote values: yes | no | abstain
-- ============================================================================
CREATE TABLE IF NOT EXISTS consensus_votes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    proposal_id     UUID NOT NULL REFERENCES proposals(id) ON DELETE CASCADE,
    agent_key       TEXT NOT NULL,
    vote            TEXT NOT NULL CHECK (vote IN ('yes', 'no', 'abstain')),
    rationale       TEXT,
    conditions_json JSONB,
    voted_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (proposal_id, agent_key)
);

-- ============================================================================
-- TABLE: sentinel_decisions
-- Records Sentinel's safety review verdict for each proposal.
-- verdict values: clear | hold | rejected
-- ============================================================================
CREATE TABLE IF NOT EXISTS sentinel_decisions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    proposal_id         UUID NOT NULL REFERENCES proposals(id) ON DELETE CASCADE,
    verdict             TEXT NOT NULL CHECK (verdict IN ('clear', 'hold', 'rejected')),
    reasoning           TEXT,
    concerns_json       JSONB,
    conditions_json     JSONB,
    flagged_for_diagnostics TEXT,
    rendered_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_proposals_status          ON proposals(status);
CREATE INDEX IF NOT EXISTS idx_proposals_source_workflow ON proposals(source_workflow);
CREATE INDEX IF NOT EXISTS idx_proposals_gate_phase      ON proposals(gate_phase);
CREATE INDEX IF NOT EXISTS idx_proposals_created_at      ON proposals(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_votes_proposal            ON consensus_votes(proposal_id);
CREATE INDEX IF NOT EXISTS idx_votes_agent_key           ON consensus_votes(agent_key);
CREATE INDEX IF NOT EXISTS idx_sentinel_proposal         ON sentinel_decisions(proposal_id);

-- ============================================================================
-- TRIGGER: auto-update updated_at on proposals
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_proposals_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_proposals_updated_at
    BEFORE UPDATE ON proposals
    FOR EACH ROW
    EXECUTE FUNCTION fn_proposals_updated_at();

COMMIT;