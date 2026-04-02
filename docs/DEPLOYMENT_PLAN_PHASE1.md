# Deployment Plan — Phase 1 (Immediate)

**Date:** 2026-04-01  
**Status:** In Progress  
**Goal:** Deploy governance + core infrastructure skills, enable observability, initialize consensus modules

---

## Completed Tasks ✅

### 1. Module Verification
- ✅ BFT Consensus (`bft-consensus.js`) — Production-ready
- ✅ Reputation Voting (`reputation-voting.js`) — Production-ready
- ✅ PostgreSQL Store (`reputation-store.postgres.js`) — Created
- ✅ Event Mesh A2A (`event-mesh.js`) — Production-ready
- ✅ HeavySwarm (`heavy-swarm.js`) — Production-ready (stubs noted)

### 2. Skills Audit
- ✅ Complete registry created: `SKILLS_AUDIT_2026-04-01.md`
- ✅ Categorized all 49 skills (28 active, 10 triad-legacy, 9 utility, 2 orphan)
- ✅ Deployment priority assigned (P0/P1/P2/Archive/Refactor)

### 3. Orphan File Cleanup
- ✅ Converted `constitutional-deliberation.js` → proper skill folder with SKILL.md
- ✅ Removed duplicate `session-wrap-up.js`

### 4. Documentation Updates
- ✅ Updated `DEPLOYMENT_FINDINGS_AND_PLAN.md` with:
  - Consensus modules assessment section
  - Skills assessment summary table
  - Recommended action plan (3 phases)
  - Appendix with skills audit summary
- ✅ Created `SKILLS_AUDIT_2026-04-01.md` (full registry)

---

## In Progress 🟡

### 1. Dashboard Debugging
- ⚠️ ClawBridge dashboard not accessible at http://192.168.31.166:18790
- Container shows healthy but frontend not responding
- Subagent spawned for debugging (awaiting report)

### 2. Langfuse Observability
- ⏳ Subagent deployed to activate Langfuse tracing
- Awaiting completion report

### 3. Reputation Tracking Initialization
- 🟡 PostgreSQL store created
- ⏳ Need to initialize scores for all 22 agents (base 100)
- ⏳ Configure decay/slashing rates in config

### 4. BFT Consensus Integration Test
- 🟡 Modules verified functional
- ⏳ Need to wire into agent decision path
- ⏳ Test quorum achievement with triad subagents

---

## Pending Tasks ⏸️

### P0 Governance Skills Deployment

Deploy these skills to OpenClaw gateway:

```bash
# A2A Protocol
openclaw skills deploy a2a-agent-register
openclaw skills deploy a2a-message-send

# Governance
openclaw skills deploy auto-deliberation-trigger
openclaw skills deploy constitutional-deliberation
openclaw skills deploy governance-modules
openclaw skills deploy quorum-enforcement

# Core Infrastructure
openclaw skills deploy healthcheck
openclaw skills deploy litellm-ops
openclaw skills deploy steward-orchestrator
openclaw skills deploy deployment-health-check
openclaw skills deploy deployment-smoke-test
openclaw skills deploy detect-corruption
```

### P1 Growth/Memory Skills Deployment

```bash
# Growth
openclaw skills deploy curiosity-engine
openclaw skills deploy gap-detector
openclaw skills deploy opportunity-scanner

# Memory
openclaw skills deploy knowledge-ingest
openclaw skills deploy knowledge-retrieval
openclaw skills deploy memory-consolidation

# Lifecycle
openclaw skills deploy agent-lifecycle-manager
openclaw skills deploy autonomous-pulse
openclaw skills deploy autonomy-audit
openclaw skills deploy self-model
openclaw skills deploy user-context-resolve
openclaw skills deploy workspace-consolidation
openclaw skills deploy config-validator
```

### Triad Legacy Cleanup

```bash
# Archive obsolete triad skills
mkdir -p skills/archive
mv skills/audit-triad-files skills/archive/
mv skills/failover-vote skills/archive/
mv skills/fleet-backup skills/archive/
mv skills/matrix-triad skills/archive/
mv skills/triad-unity-monitor skills/archive/

# Refactor list (decision needed)
# - backup-ledger → adapt for PostgreSQL
# - triad-cron-manager → single-node cron
# - triad-deliberation-protocol → virtual subagents
# - triad-heartbeat → HTTP/gateway health
# - triad-resilience → gateway recovery
# - triad-signal-filter → single-instance signal
# - triad-sync-protocol → already partially adapted
```

---

## Integration Tests Required

### 1. BFT Consensus Test Plan

```javascript
// Test 1: Basic quorum achievement (3 nodes, 0 faulty)
const consensus = new BFTConsensus({ clusterSize: 4 });
const result = await consensus.propose({ type: 'test', data: {} });
assert(result.agreed === true);

// Test 2: Byzantine fault tolerance (4 nodes, 1 faulty)
// Simulate node failure during PRE-PREPARE phase
// Verify view change and successful consensus

// Test 3: Quorum failure (4 nodes, 2 faulty)
// Should fail to reach consensus
// Verify graceful degradation
```

### 2. Reputation Voting Test Plan

```javascript
// Test 1: Base reputation initialization
await voting.resetReputation('agent-1', 100);
const rep = await voting.getReputation('agent-1');
assert(rep === 100);

// Test 2: Success increases reputation
await voting.updateReputation('agent-1', true, 1.0);
// Expected: 100 → 110 (+10%)

// Test 3: Failure slashes reputation
await voting.updateReputation('agent-1', false, 1.0);
// Expected: 110 → 88 (-20%)

// Test 4: Quadratic voting cost
const vote = await voting.quadraticVote('agent-1', 'cpu-budget', 5);
assert(vote.cost === 25); // 5² = 25

// Test 5: Decay over time
// Simulate 1 week passage
// Expected: 10% decay applied
```

### 3. Event Mesh A2A Test Plan

```javascript
// Test 1: Wildcard subscription
await mesh.subscribe('agents.*', callback);
await mesh.publish('agents.Sage', event);
// Verify callback received event

// Test 2: Request-response pattern
const response = await mesh.request('agents.Sage', query, 5000);
// Verify synchronous response

// Test 3: Message persistence
// Publish to Redis Streams
// Verify message durability across restarts
```

---

## Success Criteria

Phase 1 complete when:

- [x] Module verification complete (5/5 passed)
- [x] Skills audit documented
- [x] Orphan files cleaned up
- [ ] Langfuse observability enabled and tracing
- [ ] ClawBridge dashboard accessible and showing all 22 agents
- [ ] Reputation scores initialized for all agents
- [ ] BFT consensus integrated and tested
- [ ] P0 governance skills deployed
- [ ] P1 growth/memory skills deployed
- [ ] Triad legacy skills archived/refactored

---

## Timeline

| Week | Focus | Deliverables |
|------|-------|--------------|
| **Week 1** (Apr 1-7) | Governance + Observability | Langfuse live, P0 skills deployed, BFT tested |
| **Week 2** (Apr 8-14) | Growth + Memory | P1 skills deployed, reputation tracking active |
| **Week 3** (Apr 15-21) | Triad Cleanup | Legacy archived, refactors complete |
| **Week 4** (Apr 22-28) | Integration Testing | All tests passing, production ready |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Exec restrictions block subagents | High | Use read-based verification, manual deployment |
| Triad refactor breaks existing workflows | Medium | Archive first, refactor in isolated branch |
| Langfuse integration fails | Low | Fallback to local logging, retry later |
| Dashboard frontend broken | Medium | Debug container, rebuild if needed |
| Consensus modules conflict with gateway | High | Test in isolation before integration |

---

## Next Actions

1. **Await subagent reports:**
   - Dashboard debugging (`dashboard-debug`)
   - Langfuse deployment (`langfuse-deploy`)

2. **Manual deployment of P0 skills:**
   - Start with governance-modules (inviolable parameters)
   - Deploy quorum-enforcement (decision integrity)
   - Deploy constitutional-deliberation (self-critique)

3. **Initialize reputation tracking:**
   - Run initialization script for 22 agents
   - Verify PostgreSQL persistence
   - Test decay/slashing logic

4. **BFT consensus integration:**
   - Create test harness
   - Run quorum achievement test
   - Document results

---

🦞 *The thought that never ends.*
