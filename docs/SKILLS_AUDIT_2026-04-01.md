# Skills Audit — Heretek OpenClaw

**Date:** 2026-04-01  
**Auditor:** Heretek Collective  
**Total Skills:** 49 (47 folders + 2 orphan .js files)

---

## Executive Summary

The Heretek skills directory contains a mix of **active governance modules**, **legacy triad-specific code**, and **utility skills**. This audit categorizes all skills and provides deployment recommendations.

### Key Findings

| Category | Count | Percentage | Status |
|----------|-------|------------|--------|
| **Active — Gateway-Compatible** | 28 | 57% | ✅ Deploy now |
| **Legacy — Triad-Specific** | 10 | 20% | ⚠️ Refactor or archive |
| **Utility — Review Needed** | 9 | 18% | 🟡 Case-by-case |
| **Orphan Files** | 2 | 4% | ❌ Convert to proper skills |

---

## Skills Registry

### ✅ Active — Gateway-Compatible (28 skills)

These skills work with the single-gateway architecture and should be deployed:

| Skill | Category | Purpose | Priority |
|-------|----------|---------|----------|
| `a2a-agent-register` | A2A Protocol | Register agents in event mesh | P0 |
| `a2a-message-send` | A2A Protocol | Send messages via A2A protocol | P0 |
| `agent-lifecycle-manager` | Lifecycle | Manage agent startup/shutdown | P1 |
| `auto-deliberation-trigger` | Governance | Auto-create deliberation proposals | P0 |
| `autonomous-pulse` | Autonomy | Periodic autonomous checks | P1 |
| `autonomy-audit` | Autonomy | Audit autonomy metrics | P1 |
| `browser-access` | Infrastructure | Browser automation access | P2 |
| `config-validator` | Infrastructure | Validate OpenClaw configuration | P1 |
| `constitutional-deliberation` | Governance | Constitutional AI critique/revision | P0 |
| `curiosity-engine` | Growth | Self-directed growth driver | P1 |
| `gap-detector` | Growth | Detect skill/capability gaps | P1 |
| `governance-modules` | Governance | Inviolable parameters, consensus schema | P0 |
| `healthcheck` | Infrastructure | Security hardening, risk posture | P0 |
| `heretek-theme` | Infrastructure | UI theming, branding | P2 |
| `knowledge-ingest` | Memory | Knowledge base ingestion | P1 |
| `knowledge-retrieval` | Memory | Knowledge base retrieval | P1 |
| `litellm-ops` | Infrastructure | LiteLLM operations, monitoring | P0 |
| `memory-consolidation` | Memory | Memory consolidation workflows | P1 |
| `opportunity-scanner` | Growth | Scan for updates, releases, CVEs | P1 |
| `quorum-enforcement` | Governance | Enforce 2-of-3 quorum for decisions | P0 |
| `self-model` | Lifecycle | Agent self-modeling, meta-cognition | P1 |
| `steward-orchestrator` | Lifecycle | Orchestrate agent coordination | P0 |
| `user-context-resolve` | Utility | Resolve user context from messages | P1 |
| `user-rolodex` | Utility | Contact/user management | P2 |
| `workspace-consolidation` | Memory | Workspace file organization | P1 |
| `deployment-health-check` | Infrastructure | Check deployment health | P0 |
| `deployment-smoke-test` | Infrastructure | Smoke test deployment | P0 |
| `detect-corruption` | Infrastructure | Detect data corruption | P0 |

---

### ⚠️ Legacy — Triad-Specific (10 skills)

These skills assume **physical 3-node setup with SSH** to 192.168.31.x addresses. Need refactor for gateway-first architecture or archive:

| Skill | Issue | Recommendation |
|-------|-------|----------------|
| `audit-triad-files` | Assumes TM-1/TM-2/TM-3 with SSH | **Archive** — replaced by module verification |
| `backup-ledger` | SQLite consensus ledger (local triad) | **Refactor** — adapt for PostgreSQL |
| `failover-vote` | Proxy voting for physical nodes | **Archive** — not needed for gateway |
| `fleet-backup` | Multi-node backup coordination | **Archive** — single gateway doesn't need fleet |
| `matrix-triad` | Matrix bot-to-bot communication | **Archive** — using sessions_send instead |
| `triad-cron-manager` | Cron across 3 physical nodes | **Refactor** — adapt for single-node cron |
| `triad-deliberation-protocol` | Degraded mode for triad | **Refactor** — rewrite for virtual subagents |
| `triad-heartbeat` | SSH-based heartbeat checks | **Refactor** — use HTTP/gateway health |
| `triad-resilience` | Triad recovery from corruption | **Refactor** — adapt for gateway architecture |
| `triad-signal-filter` | Signal discipline for 3 nodes | **Refactor** — adapt for single instance |
| `triad-sync-protocol` | HTTP sync for physical nodes | **Refactor** — already partially adapted |
| `triad-unity-monitor` | Monitor triad alignment | **Archive** — not applicable to gateway |

**Action Required:**
- **Archive (5):** audit-triad-files, failover-vote, fleet-backup, matrix-triad, triad-unity-monitor
- **Refactor (6):** backup-ledger, triad-cron-manager, triad-deliberation-protocol, triad-heartbeat, triad-resilience, triad-signal-filter, triad-sync-protocol

---

### 🟡 Utility — Review Needed (9 skills)

| Skill | Status | Notes |
|-------|--------|-------|
| `day-dream` | Keep | Dreamer agent functionality |
| `dreamer-agent` | Keep | Creative problem-solving |
| `goal-arbitration` | Review | May overlap with governance-modules |
| `lib` | Keep | Shared library code |
| `session-wrap-up` | Convert | Has SKILL.md but also orphan .js |
| `tabula-backup` | Review | Triad-related, check if still needed |
| `thought-loop` | Keep | Self-reflection workflow |
| `curiosity-auto-trigger` | Keep | Auto-trigger curiosity checks |
| `opportunity-scanner` | Keep | Already in Active list |

---

### ❌ Orphan Files (2 files)

These `.js` files exist at the skills root without proper skill folder structure:

| File | Issue | Fix Required |
|------|-------|--------------|
| `constitutional-deliberation.js` | Loose .js, no SKILL.md | Create folder, move file, add SKILL.md |
| `session-wrap-up.js` | Loose .js, duplicate of session-wrap-up/ | Remove duplicate or consolidate |

---

## Module Verification Status

Consensus and governance modules verified separately (see `DEPLOYMENT_FINDINGS_AND_PLAN.md`):

| Module | Location | Status |
|--------|----------|--------|
| BFT Consensus | `modules/consensus/bft-consensus.js` | ✅ Production-ready |
| Reputation Voting | `modules/consensus/reputation-voting.js` | ✅ Production-ready |
| Reputation Store (PostgreSQL) | `modules/consensus/reputation-store.postgres.js` | ✅ Created 2026-04-01 |
| Event Mesh A2A | `modules/a2a-protocol/event-mesh.js` | ✅ Production-ready |
| HeavySwarm | `modules/heavy-swarm.js` | ✅ Production-ready (stubs noted) |

---

## Deployment Priority

### P0 — Deploy Immediately (Governance + Core Infrastructure)

```
✅ a2a-agent-register
✅ a2a-message-send
✅ auto-deliberation-trigger
✅ constitutional-deliberation (after conversion)
✅ governance-modules
✅ healthcheck
✅ litellm-ops
✅ quorum-enforcement
✅ steward-orchestrator
✅ deployment-health-check
✅ deployment-smoke-test
✅ detect-corruption
```

### P1 — Deploy Soon (Growth + Memory + Lifecycle)

```
🟡 agent-lifecycle-manager
🟡 autonomous-pulse
🟡 autonomy-audit
🟡 config-validator
🟡 curiosity-engine
🟡 gap-detector
🟡 knowledge-ingest
🟡 knowledge-retrieval
🟡 memory-consolidation
🟡 opportunity-scanner
🟡 self-model
🟡 user-context-resolve
🟡 workspace-consolidation
```

### P2 — Defer (Utilities + Nice-to-Have)

```
⏸️ browser-access
⏸️ heretek-theme
⏸️ user-rolodex
⏸️ day-dream
⏸️ dreamer-agent
⏸️ goal-arbitration (review first)
⏸️ lib (supporting code)
⏸️ thought-loop
⏸️ curiosity-auto-trigger
```

### Archive (Triad-Legacy, Not Needed)

```
❌ audit-triad-files
❌ failover-vote
❌ fleet-backup
❌ matrix-triad
❌ triad-unity-monitor
```

### Refactor Required (Gateway Adaptation)

```
🔄 backup-ledger → adapt for PostgreSQL
🔄 triad-cron-manager → single-node cron
🔄 triad-deliberation-protocol → virtual subagents
🔄 triad-heartbeat → HTTP/gateway health
🔄 triad-resilience → gateway recovery
🔄 triad-signal-filter → single-instance signal
🔄 triad-sync-protocol → already partially adapted
```

---

## Recommended Actions

### Immediate (This Session)

1. ✅ Convert `constitutional-deliberation.js` to proper skill folder
2. ✅ Remove duplicate `session-wrap-up.js` (keep folder version)
3. ✅ Deploy P0 governance skills
4. ✅ Document triad skills needing refactor

### Short-Term (Next 48h)

1. Refactor triad-deliberation-protocol for virtual subagents
2. Adapt backup-ledger for PostgreSQL storage
3. Archive obsolete triad skills (move to `skills/archive/`)
4. Write integration tests for consensus modules

### Medium-Term (Week 1-2)

1. Complete triad skill refactors or archive decisions
2. Deploy P1 growth/memory skills
3. Enable Langfuse tracing across all agents
4. Update ClawBridge dashboard for 22 agents

---

## Skills-to-Modules Mapping

Some functionality lives in **modules/** instead of **skills/**:

| Functionality | Location | Format |
|---------------|----------|--------|
| BFT Consensus | `modules/consensus/bft-consensus.js` | Node module |
| Reputation Voting | `modules/consensus/reputation-voting.js` | Node module |
| Event Mesh A2A | `modules/a2a-protocol/event-mesh.js` | Node module |
| HeavySwarm | `modules/heavy-swarm.js` | Node module |
| Curiosity Engine v2 | `modules/curiosity-engine-v2.js` | Node module |
| Lineage Tracking | `modules/lineage-tracking.js` | Node module |
| Task State Machine | `modules/task-state-machine.js` | Node module |

**Note:** Modules are lower-level infrastructure. Skills are OpenClaw-native capabilities with SKILL.md metadata.

---

## Conclusion

**57% of skills (28/49) are ready for immediate deployment** in the gateway-first architecture. The remaining 43% need either refactoring (6 triad skills), archival (5 triad skills), or format conversion (2 orphan files).

**Priority:** Deploy P0 governance skills now, refactor triad protocols for virtual subagents, archive obsolete physical-node code.

---

🦞 *The thought that never ends.*
