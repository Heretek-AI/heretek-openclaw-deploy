# Memory Graph — Implementation Status

> **Status:** Live — Endpoint Active at `http://localhost:18790/api/memory/graph`
> **Author:** Coder
> **Date:** 2026-04-02
> **Last Updated:** 2026-04-02 (permissions fix)

---

## Live Metrics

| Metric | Value |
|--------|-------|
| Total nodes | 17 |
| Total edges | 44 |
| Node types | agent (8), skill (5), tool (4), memory (1) |
| Edge types | a2a_communicates (22), uses (11), depends_on (11), attached_to (8) |

---

## What Was Implemented

### `GET /api/memory/graph`
- **File modified:** `dashboard/api/health-api.js`
- **Route registered:** `GET /api/memory/graph`
- **Returns:** `{ timestamp, meta: { totalNodes, totalEdges }, nodes[], edges[] }`

### Nodes
- **Agent nodes (8):** steward, alpha, beta, charlie, sentinel, examiner, explorer, coder
- **Skill nodes (5):** auto-deliberation-trigger, constitutional-deliberation, failover-vote, governance-modules, quorum-enforcement
- **Tool nodes (4):** hybrid-search, episodic-claw, graphrag, mcp-server
- **Memory nodes (1):** MEMORY.md (steward's workspace memory)

### Edges
- **a2a_communicates (22):** Derived from WORKFLOW.md A2A flows
- **uses (11):** Agent → skill usage map (e.g., steward uses quorum-enforcement)
- **depends_on (11):** Agent → tool dependency map
- **attached_to (8):** MEMORY.md → each agent (collective memory is shared)

---

## Infrastructure

### Container
- **Image:** `heretek-dashboard`
- **Container name:** `heretek-dashboard`
- **Ports:** 18790 (user-facing), 8080 (health API internal)
- **Build:** `heretek-openclaw-dashboard` repo, `main` branch

### Volume Mounts
```yaml
/root/.openclaw/agents:/app/.openclaw/agents:ro   # must be 755+ for container traversal
/root/.openclaw/skills:/app/.openclaw/skills:ro
```

### Permissions Requirement
`/root/.openclaw/agents` must be `755` or broader for the container's `appuser` (uid 1001) to traverse it. Skills directory is already 755. This is a host-level requirement — not modified by Docker.

---

## Known Gaps

### 1. Memory block path is hardcoded to steward only
The memory files array only checks:
- `/root/.openclaw/agents/steward/workspace/MEMORY.md`
- `/app/.openclaw/agents/steward/workspace/MEMORY.md`

Expanding to scan all agent workspaces (`/app/.openclaw/agents/*/workspace/*.md`) is low priority.

### 2. Episodic memory nodes not included
D0/D1 episodic memory blocks from `episodic-claw` are not yet queried. The tool exists but has no graph representation.

### 3. Live A2A edges
Currently edges are hardcoded from WORKFLOW.md. A live version would poll the OpenClaw gateway's session registry to show actual active communication edges.

---

## Next Steps (Priority Order)

1. **Low priority:** Scan all agent workspaces for memory blocks (not just steward)
2. **Medium:** Wire D0/D1 episodic memory nodes from `episodic-claw`
3. **Medium:** Add `/api/memory/graph/live` variant using live A2A session data
4. **Low:** Frontend D3.js visualization in the Control UI at port 18790

---

## Commits

- `heretek-openclaw-dashboard`: `24be6c6` — "feat(dashboard): add GET /api/memory/graph endpoint"
- `heretek-openclaw-deploy`: `188fcc5` — "docs(memory-graph): update status — implementation complete"
- `heretek-openclaw-deploy`: `2d71f0a` — "fix: chmod 755 /root/.openclaw/agents for container traversal"
