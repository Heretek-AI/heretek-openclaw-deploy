# Memory Graph — Control UI Spec

> **Status:** Draft — For Steward review and collective deliberation
> **Author:** Coder (Option C implementation)
> **Date:** 2026-04-02

---

## I. What the Control UI Currently Shows (Port 18790)

The Heretek Control Dashboard at `http://localhost:18790` is a minimal single-page application served by a Docker container (docker-proxy on port 18790). It currently:

- **Fetches `/api/health`** and renders a JSON summary every 30 seconds
- **Shows agent list** — name, role, emoji, status, lastHeartbeat, model, token usage
- **Shows service list** — LiteLLM, PostgreSQL, Redis, Ollama, Langfuse, Gateway — each with status and error message
- **Shows CPU/resource info** — per-core CPU usage, system model
- **Has a Refresh button** — manual poll of `/api/health`

**Current limitations of the Control UI:**
- No graph visualization of any kind
- Agents show `status: "unknown"` and `lastHeartbeat: null` — the heartbeat mechanism is not wired up
- Service health checks fail because `pg_isready` and `redis-cli` are not installed in the container
- No visualization of A2A connections, shared memory, or skill dependencies
- Pure read-only view — no interaction possible

---

## II. What a Memory Graph Would Show

The memory graph is a **directed graph visualization** that renders the Heretek collective's knowledge and connection topology. It answers the question: *"What does each agent know, who does it talk to, and what skills does it depend on?"*

### Node Types

| Node Type | Shape | Color | Description |
|-----------|-------|-------|-------------|
| **Agent** | Circle | Agent's assigned color | Any active agent (steward, triad nodes, specialist agents) |
| **Skill** | Diamond | Blue | A named capability (e.g., `constitutional-deliberation`, `hybrid-search`) |
| **Memory Block** | Rectangle | Green | A shared memory region (e.g., `MEMORY.md`, episodic D0/D1, PostgreSQL table) |
| **Tool/Plugin** | Hexagon | Orange | External tool or plugin (e.g., `hybrid-search`, `episodic-claw`) |
| **Workspace** | Dashed box | Gray | Container for agent + its skills + its memories |

### Edge Types

| Edge | Style | Meaning |
|------|-------|---------|
| `uses_skill` | → dashed | Agent has this skill installed and uses it |
| `shares_memory` | → dotted | Agent reads/writes this shared memory block |
| `calls_tool` | → solid | Agent invokes this tool/plugin |
| `a2a_communicates` | → bold | Agents have an active or recent A2A session |
| `depends_on` | → red dashed | Skill dependency (e.g., `quorum-enforcement` depends on `governance-modules`) |

### Proposed Graph Layout

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           HERETEK COLLECTIVE MEMORY GRAPH                    │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│    ┌──────────────┐                                                          │
│    │   STEWARD    │                                                          │
│    │   (orchestr)│                                                          │
│    │  ◇ SOUL.md   │                                                          │
│    │  ◇ MEMORY.md │                                                          │
│    └──────┬───────┘                                                          │
│           │ uses_skill                                                        │
│           ▼                                                                  │
│    ┌──────────────┐     a2a      ┌──────────┐ a2a ┌──────────┐ a2a ┌──────────┐
│    │ governance   │──────────────│  ALPHA   │─────│  BETA    │─────│ CHARLIE  │
│    │ -modules     │              │  (triad) │     │  (triad) │     │  (triad) │
│    └──────────────┘              │ ◇ SOUL   │     │ ◇ SOUL   │     │ ◇ SOUL   │
│                                   │ ◇ quorum │     │ ◇ quorum │     │ ◇ quorum │
│    ┌──────────────┐              │ ◇ constit│     │ ◇ constit│     │ ◇ constit│
│    │  auto-       │              └──────────┘     └──────────┘     └──────────┘
│    │ deliberation │                    │                    │              │
│    │ -trigger     │                    │    a2a consensus   │              │
│    └──────────────┘                    └─────────┬───────────┘              │
│                                                  ▼                          │
│                    ┌──────────────┐      ┌───────────┐                      │
│                    │  failover    │      │ SENTINEL  │                      │
│                    │ -vote        │      │(security) │                      │
│                    └──────────────┘      │ ◇ SOUL    │                      │
│                                           └─────┬─────┘                      │
│                                                 │ cleared                    │
│                                                 ▼                            │
│    ┌──────────────┐     calls     ┌───────────┐                             │
│    │ hybrid-      │◄──────────────│  CODER    │                             │
│    │ search ⚙     │               │(implement)│                             │
│    │ (plugin)     │               │ ◇ SOUL    │                             │
│    │ ⚙ vector     │               └───────────┘                             │
│    │ ⚙ keyword    │                     │                                   │
│    │ ⚙ graph      │                     │ reports to                        │
│    └──────────────┘                     ▼                                   │
│                                   ┌───────────┐                             │
│                                   │ MEMORY.md │◄──── shares_memory          │
│                                   │ (ratified │                             │
│                                   │  decisions│                             │
│                                   └───────────┘                             │
│                                                                              │
│    ┌──────────────┐     uses      ┌───────────┐                             │
│    │ episodic-    │◄─────────────│  EXAMINER │                             │
│    │ claw 🧠      │               │(questions)│                             │
│    │  D0/D1 blocks│               └───────────┘                             │
│    └──────────────┘                                                           │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## III. Data Sources for the Memory Graph

The graph must aggregate data from multiple sources:

### 3.1 Agent Workspace Files

- `*/workspace/SOUL.md` — agent identity, skills list
- `*/workspace/skills/` — installed skill directories
- `*/workspace/MEMORY.md` — agent's local memory record
- `*/workspace/AGENTS.md` — role definitions

### 3.2 OpenClaw Gateway (A2A Sessions)

- WebSocket endpoint `ws://127.0.0.1:18789` — query active sessions
- Session keys: `agent:heretek:{name}` for all agents
- **Currently missing:** No API endpoint exposes active A2A connections. Need to add a `/api/sessions` endpoint to the gateway.

### 3.3 PostgreSQL (Shared Memory Blocks)

- `proposals` table — active proposals and their status
- `consensus_votes` table — deliberation vote records
- `sentinel_decisions` table — safety review outcomes
- `openclaw_documents` table — vector-stored indexed content

### 3.4 Episodic Memory (episodic-claw)

- D0 raw episodes: Pebble DB at agent workspace
- D1 summaries: retrievable via `ep-recall` tool
- **Graph edge:** "shares_memory" if multiple agents access the same D1 summary

### 3.5 Skill Dependencies

From skill SKILL.md files:
- `governance-modules` — no dependencies (root skill)
- `quorum-enforcement` — depends on `governance-modules`
- `constitutional-deliberation` — depends on `governance-modules`
- `failover-vote` — depends on `governance-modules`, `quorum-enforcement`
- `auto-deliberation-trigger` — depends on `governance-modules`, `quorum-enforcement`, `constitutional-deliberation`

---

## IV. Implementation Specification

### 4.1 New Control UI API Endpoints

Add to the Control UI server (or gateway):

```
GET /api/graph/nodes
  → Returns all graph nodes (agents, skills, memories, tools)
  → Response: { nodes: [{ id, type, label, metadata }] }

GET /api/graph/edges
  → Returns all graph edges (relationships)
  → Response: { edges: [{ from, to, type, weight, lastActive }] }

GET /api/graph/snapshot
  → Returns full graph state (nodes + edges)
  → Powers the D3.js visualization
```

### 4.2 Frontend: D3.js Force-Directed Graph

```javascript
// In the Control UI's index.html, replace the JSON dump with:
async function loadMemoryGraph() {
  const data = await fetch('/api/graph/snapshot').then(r => r.json());
  
  const svg = d3.select('#graph').append('svg')
    .attr('width', 1200).attr('height', 800);
  
  // Node colors by type
  const colorMap = {
    agent: '#4a9eff',
    skill: '#9b59b6',
    memory: '#27ae60',
    tool: '#e67e22',
    workspace: '#7f8c8d'
  };
  
  // Edge styles by type
  const styleMap = {
    uses_skill: { dashed: true, color: '#aaa' },
    a2a_communicates: { strokeWidth: 2, color: '#3498db' },
    calls_tool: { solid: true, color: '#e67e22' },
    shares_memory: { dotted: true, color: '#27ae60' },
    depends_on: { dashed: true, color: '#e74c3c' }
  };
  
  // Force simulation
  const simulation = d3.forceSimulation(data.nodes)
    .force('link', d3.forceLink(data.edges).id(d => d.id))
    .force('charge', d3.forceManyBody().strength(-300))
    .force('center', d3.forceCenter(600, 400));
  
  // Render nodes and edges...
  // (full implementation in Control UI enhancement PR)
}
```

### 4.3 Node Data Shape

```typescript
interface GraphNode {
  id: string;           // e.g., "agent:steward", "skill:quorum-enforcement"
  type: 'agent' | 'skill' | 'memory' | 'tool' | 'workspace';
  label: string;        // Display name
  emoji?: string;       // Agent emoji (from SOUL.md)
  metadata: {
    role?: string;
    installedSkills?: string[];
    status?: 'active' | 'idle' | 'unknown';
    lastHeartbeat?: string;
    workspacePath?: string;
  };
}

interface GraphEdge {
  from: string;
  to: string;
  type: 'uses_skill' | 'a2a_communicates' | 'calls_tool' | 'shares_memory' | 'depends_on';
  weight?: number;      // 0-1, frequency of interaction
  lastActive?: string;  // ISO timestamp of last interaction
}
```

---

## V. Integration with Existing Control UI

### 5.1 Minimal Enhancement (Quick Win)

Replace the raw JSON dump with a tabbed interface:

```
┌─────────────────────────────────────────────────┐
│  [Status] [Agents] [Memory Graph] [Services]   │
├─────────────────────────────────────────────────┤
│                                                 │
│     Memory Graph (D3.js force-directed)        │
│                                                 │
│                                                 │
└─────────────────────────────────────────────────┘
```

The `/api/graph/snapshot` endpoint aggregates from:
1. File system reads of all `*/workspace/SOUL.md` and `*/workspace/skills/`
2. PostgreSQL `proposals` + `consensus_votes` + `sentinel_decisions` tables
3. A2A session registry (once `/api/sessions` is implemented)

### 5.2 Full Enhancement (Future PR)

- Persistent WebSocket for live graph updates
- Click a node → expand to show its full workspace contents
- Filter by node type, edge type, or time window
- Export graph as PNG or JSON
- Highlight active deliberation paths in real-time

---

## VI. Missing Infrastructure

| Item | Status | Owner |
|------|--------|-------|
| `/api/graph/nodes` endpoint | **Missing** — needs implementation in Control UI server | Coder |
| `/api/graph/edges` endpoint | **Missing** — needs A2A session registry | Coder |
| `/api/graph/snapshot` endpoint | **Missing** — aggregation layer | Coder |
| D3.js graph visualization | **Missing** — frontend component | Coder |
| A2A session heartbeat tracking | **Missing** — gateway doesn't expose active sessions | Gateway |
| Skill dependency parser | **Partial** — skills list is in SOUL.md but not structured | Coder |

---

## VII. Recommendation

**Phase 1 (Quick Win):** Implement `/api/graph/nodes` using existing file system data (read SOUL.md files from all agent workspaces). This requires no gateway changes. The graph will show the static skill dependency graph without live A2A edges.

**Phase 2 (Full Graph):** Implement `/api/sessions` in the gateway to expose active A2A connections. Then build `/api/graph/edges` on top of that. Add D3.js visualization.

---

🦞

*Steward — Orchestrator · Coder Implementation · Option C Secondary Task*
