# Hybrid Search Plugin — Setup Guide

> **Plugin:** `hybrid-search`
> **Version:** 1.0.0 (internal)
> **Replaces:** README.md (brief setup instructions)
> **Date:** 2026-04-02

---

## I. Overview

The hybrid-search plugin combines three retrieval methods into one unified search:

| Method | What it does | Backend |
|--------|-------------|---------|
| **Vector Search** | Semantic similarity — finds conceptually related content | `pgvector` (PostgreSQL extension) |
| **Keyword Search** | BM25/TF-IDF — finds exact term matches | In-memory or Qdrant |
| **Graph Search** | Relationship traversal — finds connected entities | Graph DB or adjacency table |
| **Hybrid Fusion** | Weighted Reciprocal Rank Fusion — combines all three | Plugin logic |
| **Reranking** | Cross-encoder refinement | LiteLLM / embedding model |

---

## II. Prerequisites

### Required

- **PostgreSQL 15+** with **`pgvector` extension** enabled
  ```bash
  # Check if pgvector is installed
  psql -U heretek -d heretek -c "SELECT * FROM pg_extension WHERE extname = 'vector';"
  # Expected: one row with extname = 'vector'
  ```
- **LiteLLM Gateway** running at `http://localhost:4000` (for embeddings)
- **OpenClaw Gateway** running at `ws://127.0.0.1:18789`

### Connection String

The plugin uses this PostgreSQL connection string by default:

```
postgres://heretek:<PASSWORD>@127.0.0.1:5432/heretek
```

> ⚠️ **IMPORTANT:** The credentials are embedded in the source code (`vector-search.js`). This is a security risk for production deployments. The recommended way to override this is via the `openclaw.plugin.json` config (see Section IV).

---

## III. Known Failure Modes

### Failure 1: `pgvector` Extension Not Installed

**Symptom:**
```
[VectorSearch] Failed to initialize pgvector: error: relation "openclaw_documents" does not exist
```
or
```
[VectorSearch] Failed to initialize pgvector: error: function vector_cosine_ops does not exist
```

**Cause:** The PostgreSQL server does not have the `pgvector` extension enabled.

**Fix:**
```sql
-- As postgres superuser:
CREATE EXTENSION IF NOT EXISTS vector;

-- Verify:
SELECT extname, extversion FROM pg_extension WHERE extname = 'vector';
```

### Failure 2: Wrong Hostname in Connection String

**Symptom:**
```
[VectorSearch] Failed to initialize pgvector: getaddrinfo ENOTFOUND postgres
```

**Cause:** The plugin defaults to `postgres` as the hostname (Docker service name), but the container hostname is `127.0.0.1` (host networking) or a different Docker service name.

**Fix:** Set `connectionString` in plugin config (see Section IV). The Docker container networking can vary:
- With Docker Compose `network_mode: host`: use `127.0.0.1`
- With Docker Compose default networking: use the service name (e.g., `postgres`)
- With external PostgreSQL: use the external IP/hostname

### Failure 3: Permission Denied on `openclaw_documents` Table

**Symptom:**
```
[VectorSearch] Failed to initialize pgvector: permission denied for schema heretek
```

**Cause:** The database user (`heretek`) does not have permissions to create tables.

**Fix:**
```sql
-- Grant schema permissions
GRANT ALL PRIVILEGES ON SCHEMA public TO heretek;
GRANT ALL PRIVILEGES ON DATABASE heretek TO heretek;

-- If tables already exist:
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO heretek;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO heretek;
```

### Failure 4: HNSW Index Creation Failure (Low Memory)

**Symptom:**
```
[VectorSearch] Failed to initialize pgvector: cannot create index due to insufficient memory
```

**Cause:** HNSW index parameters (`m = 16, ef_construction = 64`) require significant RAM.

**Fix:** Reduce HNSW parameters in `vector-search.js` or config:
```javascript
// In config:
vector: {
  hnswM: 8,        // Reduced from 16
  hnswEfConstruction: 32  // Reduced from 64
}
```

### Failure 5: LiteLLM Gateway Unavailable (Embedding Generation Fails)

**Symptom:**
```
[VectorSearch] Embedding generation failed: connect ECONNREFUSED 127.0.0.1:4000
```

**Cause:** LiteLLM gateway is not running.

**Fix:**
```bash
# Check LiteLLM status
curl http://localhost:4000/health

# Restart if needed
openclaw gateway restart
```

### Failure 6: Health Check Container Lacks `pg_isready`

**Symptom (Control UI):**
```
postgres: Command failed: pg_isready -h postgres -p 5432 -U heretek
/bin/sh: pg_isready: not found
```

**Cause:** The Docker container running the Control UI does not have `pg_isready` installed.

**Fix:** This is a false negative — PostgreSQL may be healthy even if this check fails. The hybrid-search plugin uses its own Node.js `pg` library to connect, which works regardless. To fix the health check:

```bash
# Install postgresql-client in the health-check container
apt-get update && apt-get install -y postgresql-client
```

---

## IV. Configuration

### Method 1: Via `openclaw.plugin.json` (Recommended)

Add to your OpenClaw config:

```json
{
  "plugins": {
    "entries": [
      {
        "name": "hybrid-search",
        "enabled": true,
        "config": {
          "vectorWeight": 0.5,
          "keywordWeight": 0.3,
          "graphWeight": 0.2,
          "topK": 10,
          "minScore": 0.3,
          "enableReranking": true,
          "vector": {
            "connectionString": "postgres://heretek:<YOUR_PASSWORD>@127.0.0.1:5432/heretek",
            "collection": "openclaw_documents",
            "dimensions": 1536,
            "indexType": "hnsw",
            "hnswM": 16,
            "hnswEfConstruction": 64,
            "cacheSize": 1000
          },
          "keyword": {
            "topK": 20
          },
          "graph": {
            "maxDepth": 3
          }
        }
      }
    ]
  }
}
```

### Method 2: Via Environment Variable

```bash
export OPENCLAW_HYBRID_SEARCH_VECTOR_CONNECTION_STRING="postgres://heretek:<PASSWORD>@127.0.0.1:5432/heretek"
```

### Method 3: Via Code (Direct Instantiation)

```javascript
const HybridSearchPlugin = require('./extensions/hybrid-search/src/index.js');

const search = new HybridSearchPlugin({
  vector: {
    connectionString: 'postgres://heretek:<PASSWORD>@127.0.0.1:5432/heretek',
    collection: 'openclaw_documents',
    dimensions: 1536,
    indexType: 'hnsw'
  },
  vectorWeight: 0.5,
  keywordWeight: 0.3,
  graphWeight: 0.2
});
```

---

## V. Docker Deployment Checklist

Use this checklist when deploying hybrid-search in Docker:

- [ ] PostgreSQL container has `pgvector` extension enabled
- [ ] `heretek` database user exists and has correct permissions
- [ ] Connection string in config matches actual PostgreSQL host/port
- [ ] LiteLLM gateway is running and accessible from plugin container
- [ ] `openclaw_documents` table can be created (check disk space and permissions)
- [ ] HNSW index creation has enough RAM (`m=16, ef=64` needs ~2GB free)
- [ ] Control UI container has `postgresql-client` installed (for health checks)
- [ ] Plugin is listed in `openclaw.plugin.json` with `enabled: true`

---

## VI. Initialization Sequence

The plugin initializes in this order (from `original-index.js`):

```
1. VectorSearch.initialize()
   → Creates pgvector connection pool
   → Creates "openclaw_documents" table (if not exists)
   → Creates HNSW index on embedding column (if not exists)

2. KeywordSearch.initialize()
   → Sets up BM25/TF-IDF index

3. GraphSearch.initialize()
   → Sets up graph adjacency structure

4. CrossReferenceLinker.initialize()
   → Sets up cross-reference tracking

5. Plugin.initialized = true
```

If any step fails, the plugin logs the error but continues in degraded mode (vector search returns empty, keyword search still works, etc.).

---

## VII. Testing the Plugin

### Test 1: Verify Initialization

```javascript
const search = require('./extensions/hybrid-search/src/index.js');

// Check if initialized
console.log('Plugin initialized:', search.initialized);  // should be true
```

### Test 2: Index a Document

```javascript
await search.index({
  id: 'test-doc-1',
  content: 'The Heretek Collective uses A2A protocol for agent communication.',
  metadata: { type: 'test', source: 'manual' }
});
console.log('Document indexed successfully');
```

### Test 3: Perform a Search

```javascript
const results = await search.search('A2A communication protocol', {
  topK: 5,
  minScore: 0.1
});
console.log('Found', results.length, 'results');
results.forEach((r, i) => {
  console.log(`[${i+1}] Score: ${r.combinedScore?.toFixed(3)}`);
  console.log(`    Content: ${(r.content || '').slice(0, 100)}...`);
});
```

### Test 4: Verify Vector Table in PostgreSQL

```sql
-- Connect to the database
psql -U heretek -d heretek

-- Check table exists
SELECT COUNT(*) FROM openclaw_documents;

-- Check vector dimension
SELECT vector_dims(embedding) FROM openclaw_documents LIMIT 1;

-- Check index exists
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'openclaw_documents';
```

---

## VIII. Quick-Start (Copy-Paste)

```bash
# 1. Verify PostgreSQL + pgvector
psql -U heretek -d heretek -c "CREATE EXTENSION IF NOT EXISTS vector;"
psql -U heretek -d heretek -c "SELECT extname FROM pg_extension WHERE extname = 'vector';"

# 2. Verify LiteLLM is up
curl http://localhost:4000/health

# 3. Add to openclaw.plugin.json (see Section IV)
# 4. Restart gateway
openclaw gateway restart

# 5. Check plugin loaded
grep "hybrid-search" /root/.openclaw/logs/*.log
```

---

## IX. Uninstalling / Resetting

```sql
-- Drop the documents table (destroys all indexed data)
DROP TABLE IF EXISTS openclaw_documents;

-- Verify cleanup
SELECT * FROM openclaw_documents;  -- should fail: relation does not exist
```

To disable the plugin without removing data:
```json
// In openclaw.plugin.json:
{
  "plugins": {
    "entries": [
      {
        "name": "hybrid-search",
        "enabled": false
      }
    ]
  }
}
```

---

*Hybrid Search Plugin — Heretek OpenClaw Collective*
