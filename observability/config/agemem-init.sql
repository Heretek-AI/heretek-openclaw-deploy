-- agemem-init.sql
-- AgeMem Unified Memory PostgreSQL Schema Extension
-- Description: Adds Ebbinghaus decay support to memory storage
-- Version: 1.0.0
-- Date: 2026-04-04

-- ============================================================================
-- AgeMem Memory Store Schema
-- ============================================================================

-- Main memory entries table with Ebbinghaus decay support
CREATE TABLE IF NOT EXISTS memories (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content         TEXT NOT NULL,
    type            VARCHAR(20) NOT NULL DEFAULT 'episodic' 
                    CHECK (type IN ('working', 'episodic', 'semantic', 'procedural', 'archival')),
    importance_score FLOAT NOT NULL DEFAULT 0.5 
                    CHECK (importance_score >= 0.0 AND importance_score <= 1.0),
    access_count    INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_accessed_at TIMESTAMPTZ DEFAULT NULL,
    memory_type     VARCHAR(20) NOT NULL DEFAULT 'episodic',
    source          TEXT DEFAULT NULL,
    cluster_id      UUID DEFAULT NULL,
    tags            TEXT[] DEFAULT ARRAY[]::TEXT[],
    metadata        JSONB DEFAULT '{}'::jsonb,
    storage_path    TEXT NOT NULL,
    is_archived     BOOLEAN NOT NULL DEFAULT false,
    is_deleted      BOOLEAN NOT NULL DEFAULT false,
    deleted_at      TIMESTAMPTZ DEFAULT NULL,
    deleted_reason  TEXT DEFAULT NULL
);

-- Index for fast retrieval by type and importance
CREATE INDEX IF NOT EXISTS idx_memories_type 
    ON memories(type) WHERE NOT is_deleted;

CREATE INDEX IF NOT EXISTS idx_memories_importance 
    ON memories(importance_score DESC) WHERE NOT is_deleted;

-- Index for temporal queries (age-based decay calculation)
CREATE INDEX IF NOT EXISTS idx_memories_created_at 
    ON memories(created_at DESC) WHERE NOT is_deleted;

-- Index for access pattern tracking
CREATE INDEX IF NOT EXISTS idx_memories_last_accessed 
    ON memories(last_accessed_at DESC NULLS LAST) WHERE NOT is_deleted;

-- Index for cluster-based queries
CREATE INDEX IF NOT EXISTS idx_memories_cluster_id 
    ON memories(cluster_id) WHERE cluster_id IS NOT NULL AND NOT is_deleted;

-- GIN index for tag array searches
CREATE INDEX IF NOT EXISTS idx_memories_tags 
    ON memories USING GIN(tags) WHERE NOT is_deleted;

-- GIN index for JSONB metadata searches
CREATE INDEX IF NOT EXISTS idx_memories_metadata 
    ON memories USING GIN(metadata) WHERE NOT is_deleted;

-- Composite index for common retrieval patterns
CREATE INDEX IF NOT EXISTS idx_memories_type_importance_created 
    ON memories(type, importance_score DESC, created_at DESC) 
    WHERE NOT is_deleted;

-- ============================================================================
-- Memory Access Log (for tracking access patterns)
-- ============================================================================

CREATE TABLE IF NOT EXISTS memory_access_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    memory_id       UUID NOT NULL REFERENCES memories(id) ON DELETE CASCADE,
    accessed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    access_type     VARCHAR(20) NOT NULL DEFAULT 'read'
                    CHECK (access_type IN ('read', 'write', 'update', 'delete')),
    agent_id        TEXT DEFAULT NULL,
    session_id      TEXT DEFAULT NULL,
    query_context   TEXT DEFAULT NULL
);

-- Index for access pattern analysis
CREATE INDEX IF NOT EXISTS idx_memory_access_memory_id 
    ON memory_access_log(memory_id);

CREATE INDEX IF NOT EXISTS idx_memory_access_timestamp 
    ON memory_access_log(accessed_at DESC);

-- ============================================================================
-- Ebbinghaus Decay Functions
-- ============================================================================

-- Function to calculate decayed score for a memory
-- R(t) = S × e^(-λt) × repetition_bonus
-- Where λ = ln(2) / halfLifeDays
CREATE OR REPLACE FUNCTION calculate_decayed_score(
    importance_score FLOAT,
    created_at TIMESTAMPTZ,
    access_count INTEGER,
    memory_type VARCHAR(20)
) RETURNS FLOAT AS $$
DECLARE
    age_in_days FLOAT;
    half_life_days FLOAT;
    lambda FLOAT;
    decay_multiplier FLOAT;
    repetition_bonus FLOAT;
    decayed_score FLOAT;
BEGIN
    -- Calculate age in days
    age_in_days := EXTRACT(EPOCH FROM (NOW() - created_at)) / 86400.0;
    
    -- Determine half-life based on memory type
    CASE memory_type
        WHEN 'working' THEN half_life_days := 0.5;
        WHEN 'episodic' THEN half_life_days := 7.0;
        WHEN 'semantic' THEN half_life_days := 30.0;
        WHEN 'procedural' THEN half_life_days := 90.0;
        WHEN 'archival' THEN RETURN importance_score; -- No decay for archival
        ELSE half_life_days := 7.0;
    END CASE;
    
    -- Calculate decay constant λ = ln(2) / halfLifeDays
    lambda := LN(2.0) / half_life_days;
    
    -- Calculate decay multiplier: e^(-λ × age)
    decay_multiplier := EXP(-lambda * age_in_days);
    
    -- Calculate repetition bonus: 1 + log10(accessCount + 1) × 0.5
    IF access_count > 0 THEN
        repetition_bonus := 1.0 + (LOG(10.0, access_count + 1) * 0.5);
    ELSE
        repetition_bonus := 1.0;
    END IF;
    
    -- Calculate final decayed score
    decayed_score := importance_score * decay_multiplier * repetition_bonus;
    
    -- Apply floor (minimum 10% of original importance)
    IF decayed_score < (importance_score * 0.1) THEN
        decayed_score := importance_score * 0.1;
    END IF;
    
    RETURN decayed_score;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- View for memory retrieval with decayed scores
-- ============================================================================

CREATE OR REPLACE VIEW memories_with_decay AS
SELECT 
    m.id,
    m.content,
    m.type,
    m.importance_score AS original_score,
    calculate_decayed_score(
        m.importance_score, 
        m.created_at, 
        m.access_count, 
        m.memory_type
    ) AS decayed_score,
    EXTRACT(EPOCH FROM (NOW() - m.created_at)) / 86400.0 AS age_in_days,
    m.access_count,
    m.created_at,
    m.last_accessed_at,
    m.tags,
    m.metadata,
    m.storage_path,
    m.cluster_id,
    m.source
FROM memories m
WHERE NOT m.is_deleted AND NOT m.is_archived;

-- ============================================================================
-- Function to retrieve memories with Ebbinghaus decay weighting
-- ============================================================================

CREATE OR REPLACE FUNCTION retrieve_memories(
    search_query TEXT DEFAULT NULL,
    memory_type_filter VARCHAR(20) DEFAULT NULL,
    min_importance FLOAT DEFAULT 0.0,
    limit_count INTEGER DEFAULT 100
) RETURNS TABLE (
    id UUID,
    content TEXT,
    type VARCHAR(20),
    original_score FLOAT,
    decayed_score FLOAT,
    age_in_days FLOAT,
    access_count INTEGER,
    created_at TIMESTAMPTZ,
    tags TEXT[],
    metadata JSONB,
    storage_path TEXT,
    similarity_score FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.id,
        m.content,
        m.type::VARCHAR(20),
        m.importance_score AS original_score,
        calculate_decayed_score(
            m.importance_score, 
            m.created_at, 
            m.access_count, 
            m.memory_type
        ) AS decayed_score,
        EXTRACT(EPOCH FROM (NOW() - m.created_at)) / 86400.0 AS age_in_days,
        m.access_count,
        m.created_at,
        m.tags,
        m.metadata,
        m.storage_path,
        CASE 
            WHEN search_query IS NOT NULL THEN
                ts_rank(to_tsvector('english', m.content), plainto_tsquery('english', search_query))
            ELSE 0.0
        END AS similarity_score
    FROM memories m
    WHERE NOT m.is_deleted 
      AND NOT m.is_archived
      AND (search_query IS NULL OR to_tsvector('english', m.content) @@ plainto_tsquery('english', search_query))
      AND (memory_type_filter IS NULL OR m.type = memory_type_filter)
      AND m.importance_score >= min_importance
    ORDER BY 
        calculate_decayed_score(
            m.importance_score, 
            m.created_at, 
            m.access_count, 
            m.memory_type
        ) DESC,
        m.created_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- Function to add a new memory (AgeMem memory_add API)
-- ============================================================================

CREATE OR REPLACE FUNCTION add_memory(
    p_content TEXT,
    p_type VARCHAR(20) DEFAULT 'episodic',
    p_importance FLOAT DEFAULT 0.5,
    p_tags TEXT[] DEFAULT ARRAY[]::TEXT[],
    p_metadata JSONB DEFAULT '{}'::jsonb,
    p_source TEXT DEFAULT NULL,
    p_cluster_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_id UUID;
    v_storage_path TEXT;
    v_date_str TEXT;
BEGIN
    -- Validate importance score
    p_importance := GREATEST(0.0, LEAST(1.0, COALESCE(p_importance, 0.5)));
    
    -- Validate memory type
    IF p_type NOT IN ('working', 'episodic', 'semantic', 'procedural', 'archival') THEN
        p_type := 'episodic';
    END IF;
    
    -- Generate storage path based on type
    v_date_str := TO_CHAR(NOW(), 'YYYY-MM-DD');
    v_id := gen_random_uuid();
    
    CASE p_type
        WHEN 'working' THEN v_storage_path := 'working/' || v_id || '.tmp';
        WHEN 'episodic' THEN v_storage_path := 'episodes/' || v_date_str || '/' || v_id || '.jsonl';
        WHEN 'semantic' THEN v_storage_path := 'memory/semantic/' || v_id || '.md';
        WHEN 'procedural' THEN v_storage_path := 'memory/procedural/' || v_id || '.md';
        WHEN 'archival' THEN v_storage_path := 'archive/' || v_date_str || '/' || v_id || '.md';
        ELSE v_storage_path := 'memory/' || v_id || '.md';
    END CASE;
    
    -- Insert memory
    INSERT INTO memories (
        id, content, type, importance_score, access_count, 
        created_at, updated_at, memory_type, source, 
        cluster_id, tags, metadata, storage_path, is_archived, is_deleted
    ) VALUES (
        v_id, p_content, p_type, p_importance, 0,
        NOW(), NOW(), p_type, p_source,
        p_cluster_id, p_tags, p_metadata, v_storage_path, false, false
    );
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- ============================================================================
-- Function to update memory access count and last accessed timestamp
-- ============================================================================

CREATE OR REPLACE FUNCTION track_memory_access(
    p_memory_id UUID,
    p_access_type VARCHAR(20) DEFAULT 'read',
    p_agent_id TEXT DEFAULT NULL,
    p_session_id TEXT DEFAULT NULL,
    p_query_context TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    -- Update memory access statistics
    UPDATE memories 
    SET 
        access_count = access_count + 1,
        last_accessed_at = NOW(),
        updated_at = NOW()
    WHERE id = p_memory_id AND NOT is_deleted;
    
    -- Log the access
    INSERT INTO memory_access_log (
        memory_id, access_type, agent_id, session_id, query_context
    ) VALUES (
        p_memory_id, p_access_type, p_agent_id, p_session_id, p_query_context
    );
END;
$$ LANGUAGE plpgsql VOLATILE;

-- ============================================================================
-- Function to calculate optimal review interval for a memory
-- Based on Ebbinghaus curve: when will score drop below threshold?
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_review_interval(
    p_importance_score FLOAT,
    p_memory_type VARCHAR(20),
    p_threshold FLOAT DEFAULT 0.5
) RETURNS FLOAT AS $$
DECLARE
    half_life_days FLOAT;
    lambda FLOAT;
    days_until_threshold FLOAT;
BEGIN
    -- Determine half-life based on memory type
    CASE p_memory_type
        WHEN 'working' THEN half_life_days := 0.5;
        WHEN 'episodic' THEN half_life_days := 7.0;
        WHEN 'semantic' THEN half_life_days := 30.0;
        WHEN 'procedural' THEN half_life_days := 90.0;
        WHEN 'archival' THEN RETURN -1; -- No review needed for archival
        ELSE half_life_days := 7.0;
    END CASE;
    
    -- If already below threshold, review immediately
    IF p_importance_score <= p_threshold THEN
        RETURN 0;
    END IF;
    
    -- Calculate decay constant
    lambda := LN(2.0) / half_life_days;
    IF lambda <= 0 THEN
        RETURN half_life_days;
    END IF;
    
    -- Calculate days until score decays to threshold
    -- threshold = importance × e^(-λ × t)
    -- t = -ln(threshold/importance) / λ
    days_until_threshold := -LN(p_threshold / p_importance_score) / lambda;
    
    RETURN GREATEST(0, days_until_threshold);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- Trigger to automatically update updated_at timestamp
-- ============================================================================

CREATE OR REPLACE FUNCTION update_memory_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_memory_updated_at
    BEFORE UPDATE ON memories
    FOR EACH ROW
    EXECUTE FUNCTION update_memory_updated_at();

-- ============================================================================
-- Comments for documentation
-- ============================================================================

COMMENT ON TABLE memories IS 'AgeMem unified memory store with Ebbinghaus decay support';
COMMENT ON COLUMN memories.type IS 'Memory type: working, episodic, semantic, procedural, archival';
COMMENT ON COLUMN memories.importance_score IS 'Initial importance (0-1), decays over time unless reinforced';
COMMENT ON COLUMN memories.access_count IS 'Number of times this memory has been accessed (boosts retention)';
COMMENT ON COLUMN memories.memory_type IS 'Used to determine half-life for decay calculation';
COMMENT ON FUNCTION calculate_decayed_score IS 'Calculates R(t) = S × e^(-λt) × repetition_bonus with floor protection';
COMMENT ON FUNCTION retrieve_memories IS 'Retrieves memories ranked by decayed score with optional full-text search';
COMMENT ON FUNCTION add_memory IS 'AgeMem memory_add API - adds memory with auto-generated storage path';
COMMENT ON FUNCTION track_memory_access IS 'Updates access_count and last_accessed_at, logs to access_log';
COMMENT ON FUNCTION calculate_review_interval IS 'Calculates days until memory decays below threshold (spaced repetition)';

-- ============================================================================
-- Initial status report
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE 'AgeMem PostgreSQL schema extension installed successfully';
    RAISE NOTICE 'Tables created: memories, memory_access_log';
    RAISE NOTICE 'Functions created: calculate_decayed_score, retrieve_memories, add_memory, track_memory_access, calculate_review_interval';
    RAISE NOTICE 'View created: memories_with_decay';
    RAISE NOTICE 'Indexes created: 9 indexes for optimized retrieval';
END $$;
