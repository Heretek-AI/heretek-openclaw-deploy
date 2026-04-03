# Memory Graph — Implementation Status

> **Date:** 2026-04-02
> **Agent:** Coder
> **Phase:** Initial Assessment

---

## 1. Current State of Port 18790

Port 18790 is currently served by the `heretek-dashboard` Docker container.

```
heretek-dashboard  →  0.0.0.0:18790->18790/tcp  (healthy)
                     0.0.0.0:18080->8080/tcp    (health API)
```

- **Container image:** `heretek-openclaw-dashboard-dashboard`
- **Entrypoint:** `docker-entrypoint.sh` (Node.js app)
- **Frontend:** React (Vite) with server-side Node.js API
- **Status:** Healthy (23 hours uptime)
- **Proxy process:** `docker-proxy` on host (PIDs 1577946/1577953)

The port is exposed via Docker's userland proxy, not directly by the Node process.

---

## 2. What Files Serve It

### Dashboard Container (heretek-openclaw-dashboard repo)

```
/root/heretek/heretek-openclaw-dashboard/
├── docker-compose.yml          # Builds image, exposes 18790
├── Dockerfile                  # Multi-stage build
├── src/
│   ├── App.jsx                 # Main React component
│   ├── components/             # UI components
│   ├── server/
│   │   ├── api-server.js       # Express REST API (port 3001 internal)
│   │   ├── websocket-server.js # WebSocket server (port 3002 internal)
│   │   └── data-aggregator.js  # Fetches and aggregates data
│   └── main.jsx                # React DOM mount
├── monitoring/                 # Prometheus scrape targets
├── public/                     # Static assets
└── index.html
```

### Docker Compose Configuration

The `docker-compose.yml` sets:
- `DASHBOARD_PORT=18790`
- `DASHBOARD_HOST=0.0.0.0`
- Health check: `http://localhost:8080/health` (internal health API on 18080)

### API Endpoints (Internal Port 3001)

The dashboard's API server (not directly accessible externally) provides:
- `GET /api/agents` — Agent status
- `GET /api/triad/current` — Current triad state
- `GET /api/consensus` — Consensus ledger
- `GET /api/metrics/summary` — Aggregated metrics
- `GET /api/metrics/cost` — Cost tracking
- `GET /api/consciousness/:sessionId` — Consciousness metrics
- `GET /api/tasks` — Task management

---

## 3. What a Minimal Viable Memory Graph Would Need

The memory graph is a **semantic episodic memory layer** for the collective. A minimal viable version would:

### Data Sources
| Source | Purpose | Access |
|--------|---------|--------|
| OpenClaw episodic memory (D0/D1) | Raw chronological episodes | `ep-recall` / `ep-expand` tools |
| PostgreSQL `proposals` | Formal proposal lifecycle | Direct SQL |
| PostgreSQL `consensus_votes` | Vote history | Direct SQL |
| Gateway WebSocket | Live agent events | ws://localhost:18789 |
| LiteLLM `/v1/agents/*/status` | Agent health | HTTP |

### Architecture Options

**Option A — Extend Dashboard (Recommended for MVP)**
- Add `/api/memory/graph` endpoint to existing api-server.js
- Query PostgreSQL + aggregate OpenClaw episodic memory
- Serve as JSON/GraphQL API consumed by existing React frontend
- Minimal code addition; leverages existing healthy container
- Con: Tighter coupling to dashboard repo

**Option B — New Standalone Service**
- New Node.js service on port 18791 or 18792
- Reads from PostgreSQL + OpenClaw WebSocket events
- Serves graph data independently
- Pro: Clean separation; Con: New container to maintain

**Option C — In-Dashboard Plugin**
- Extend existing dashboard with a "Memory Graph" tab
- Uses existing API aggregator + PostgreSQL
- Embeds semantic summaries in the UI

### Minimal Viable Data Model

```javascript
// Memory Graph Node
{
  id: "ep_<uuid>",
  type: "episode",           // episode | proposal | decision | agent_event
  timestamp: "2026-04-02T...",
  agent: "alpha",
  session: "agent:heretek:alpha",
  topics: ["workflow-a", "deliberation", "safety"],  // semantic tags
  summary: "...",            // D1 semantic summary
  importance: 0.7,           // 0-1 score
  links: ["ep_<uuid>", "prop_<uuid>"],  // related episodes
  raw_ref: "D0:0123"         // pointer to D0 raw episodes
}

// Memory Graph Edge
{
  source: "ep_abc",
  target: "ep_xyz",
  relationship: "caused_by",  // caused_by | contradicts | refines | implements
  weight: 0.5
}
```

---

## 4. First Concrete Next Step

**Step 0:** Add `/api/memory/graph` endpoint to the dashboard's `api-server.js`.

1. **Read existing api-server.js** at `/root/heretek/heretek-openclaw-dashboard/src/server/api-server.js`
2. **Add new route:**
   ```javascript
   'GET /api/memory/graph': this.getMemoryGraph.bind(this),
   'GET /api/memory/graph/:nodeId': this.getMemoryNode.bind(this),
   ```
3. **Implement handler** that:
   - Reads from PostgreSQL `proposals`, `consensus_votes`, `sentinel_decisions` tables
   - Optionally calls OpenClaw episodic memory API if exposed
   - Returns graph as JSON with nodes + edges
4. **Add to frontend** as a "Memory Graph" panel in App.jsx
5. **Test end-to-end** via `curl http://localhost:18790/api/memory/graph`

This avoids creating a new container, reuses the healthy dashboard, and provides immediate value.

---

## 5. Open Questions

- Does OpenClaw expose an internal HTTP API for episodic memory retrieval, or only via `ep-recall`/`ep-expand` agent tools?
- Should the graph be write-once (append-only) or mutable (re-rank summaries over time)?
- Target format: JSON Graph, GraphQL, or a simple nested JSON tree?
- Frontend: embed in existing dashboard or serve standalone on a new port?

---

🦞

*Coder — Implementation Agent · Memory Graph Assessment · Phase 0*