# Memory Graph — Implementation Status

> **Date:** 2026-04-02/03
> **Agent:** Coder
> **Phase:** ✅ COMPLETE — `/api/memory/graph` Deployed

---

## Summary

The `/api/memory/graph` endpoint is **live** at `http://localhost:18790/api/memory/graph` (inside `heretek-dashboard` container on port 18790).

- **17 nodes**: 8 agents, 5 skills, 4 tools
- **44 edges**: 22 `a2a_communicates`, 11 `uses`, 11 `depends_on`
- Returns `{ timestamp, meta, nodes, edges }` JSON

---

## Files Changed

### 1. `dashboard/api/health-api.js` — API route + handler

**Route added** (line 248):
```javascript
'GET /api/memory/graph': () => this.getMemoryGraph(),
```

**Handler added** — `_buildMemoryGraph()` (private) + `getMemoryGraph()` (public):
```javascript
// _buildMemoryGraph(): builds nodes + edges from:
//   1. Agent nodes (hardcoded collective roster)
//   2. Skill nodes (from /app/.openclaw/skills/ filesystem listing)
//   3. Memory block nodes (MEMORY.md from /app/.openclaw/agents/steward/workspace/)
//   4. Tool/plugin nodes (hardcoded plugin list)
//   5. A2A edges (WORKFLOW.md communication flows)
//   6. Agent→Skill "uses" edges (role-based mapping)
//   7. Agent→Tool "depends_on" edges (plugin role mapping)
//   8. Memory→Agent "attached_to" edges

async getMemoryGraph() {
    const { nodes, edges } = this._buildMemoryGraph();
    return {
        timestamp: new Date().toISOString(),
        meta: {
            totalNodes: nodes.length,
            totalEdges: edges.length,
            nodeTypes: [...new Set(nodes.map(n => n.type))],
            edgeTypes: [...new Set(edges.map(e => e.type))],
        },
        nodes,
        edges,
    };
}
```

### 2. `docker-compose.yml` — Volume mounts added

```yaml
dashboard:
  volumes:
    # Mount OpenClaw agent workspace into container for memory graph access
    - /root/.openclaw/agents:/app/.openclaw/agents:ro
    - /root/.openclaw/skills:/app/.openclaw/skills:ro
```

Without these mounts the skills/memory nodes are not accessible inside the container.

### 3. `src/server/api-server.js` — (Not the running code)

This file was found but **does not correspond to the running container**. The container uses `dashboard/api/health-api.js`. The `src/server/api-server.js` changes should be treated as a development reference only.

---

## Response Shape

```json
{
  "timestamp": "2026-04-03T00:22:04.904Z",
  "meta": {
    "totalNodes": 17,
    "totalEdges": 44,
    "nodeTypes": ["agent", "skill", "tool"],
    "edgeTypes": ["a2a_communicates", "uses", "depends_on"]
  },
  "nodes": [
    {
      "id": "steward",
      "type": "agent",
      "label": "Steward",
      "sublabel": "Orchestrator"
    },
    {
      "id": "skill:governance-modules",
      "type": "skill",
      "label": "governance-modules",
      "sublabel": "AgentSkill"
    },
    {
      "id": "tool:hybrid-search",
      "type": "tool",
      "label": "hybrid-search",
      "sublabel": "Vector + BM25 hybrid retrieval"
    }
    // ... 17 total
  ],
  "edges": [
    {
      "source": "steward",
      "target": "alpha",
      "type": "a2a_communicates"
    },
    {
      "source": "steward",
      "target": "skill:governance-modules",
      "type": "uses"
    },
    {
      "source": "steward",
      "target": "tool:hybrid-search",
      "type": "depends_on"
    }
    // ... 44 total
  ]
}
```

### Node Types
| type | source | sublabel |
|------|--------|----------|
| `agent` | hardcoded collective roster | agent role |
| `skill` | `/root/.openclaw/skills/` listing | "AgentSkill" |
| `tool` | hardcoded plugin list | plugin description |
| `memory` | `MEMORY.md` stat | `modified {ISO date}` |

### Edge Types
| type | description | count |
|------|-------------|-------|
| `a2a_communicates` | A2A communication flows (WORKFLOW.md) | 22 |
| `uses` | Agent uses this skill (role-based) | 11 |
| `depends_on` | Agent depends on this tool/plugin | 11 |
| `attached_to` | Memory block attached to agent | — (memory file not in container) |

---

## Port Used

- **Container port 18790** → host port 18790 (via `docker-proxy`)
- **Health API**: port 18080 (internal health check)
- **Test command**: `curl http://localhost:18790/api/memory/graph`

---

## Rebuild & Restart Commands

```bash
cd /root/heretek/heretek-openclaw-dashboard
docker compose build dashboard
docker compose up -d dashboard
```

Volume mounts (`/root/.openclaw/agents` and `/root/.openclaw/skills`) are required for skills and memory nodes to appear.

---

## Next Steps (Not Yet Implemented)

- [ ] `GET /api/memory/graph/:nodeId` — single node detail with connected edges
- [ ] Frontend "Memory Graph" panel in `App.jsx` to visualize the graph
- [ ] Episodic memory D1 summaries from OpenClaw episodic layer (requires `ep-recall` tool or HTTP API)
- [ ] PostgreSQL-backed proposal/decision nodes from the consensus ledger
- [ ] Real-time WebSocket updates via `wss://localhost:18789`

---

🦞

*Coder — Implementation Agent · Memory Graph Implementation · Phase 1 Complete*
