# Heretek OpenClaw Deploy Update Plan

**Date:** 2026-04-02  
**Source:** Production deployment at `/root/.openclaw/`  
**Target:** `heretek-openclaw-deploy` repository  
**Status:** Planning Phase

---

## Executive Summary

This document outlines the required updates to synchronize the `heretek-openclaw-deploy` repository with the actual production deployment state at `/root/.openclaw/`.

### Key Discrepancies Found

| Area | Repository Claims | Production State | Action Required |
|------|-------------------|------------------|-----------------|
| **Agent Count** | 23 agents | 22 agents | Update documentation |
| **Phase 2 Status** | ✅ Complete | ❌ Blocked | Update status |
| **Governance Skills** | Deployed | Not loaded in gateway | Update configuration |
| **Reputation System** | Schema ready | Not initialized | Initialize PostgreSQL |
| **BFT Test** | Production-ready | Never executed | Create and run test |
| **Skills Archive** | 9 archived | Not done | Archive 10 legacy skills |

---

## 1. Configuration Updates Required

### 1.1 Update `openclaw.json` Template

**Source:** `/root/.openclaw/openclaw.json`  
**Target:** Create deployment template

**Changes Needed:**
1. Add all 22 agent configurations with correct workspace paths
2. Add LiteLLM provider with all 24 models (22 agent passthrough + 2 primary)
3. Add plugin configuration (5 enabled plugins)
4. Add tools configuration with `exec: full` security
5. Add auth profiles for LiteLLM and Ollama

**File to Create:** `heretek-openclaw-deploy/config/openclaw.json.template`

### 1.2 Update Docker Compose

**Source:** Production Docker services  
**Target:** `heretek-openclaw-deploy/observability/docker/docker-compose.observability.yml`

**Current Production Services:**
```yaml
# LiteLLM Gateway - Port 4000
# OpenClaw Gateway - Port 18789
# PostgreSQL + pgvector - Port 5432
# Redis - Port 6379
# Ollama - Port 11434 (192.168.31.128)
# ClickHouse - Ports 8123, 9000
# Langfuse - Port 3000
```

**Action:** Update compose file to match production configuration

---

## 2. Documentation Updates Required

### 2.1 Update DEPLOYMENT_FINDINGS_AND_PLAN.md

**Current Version:** 1.7.0  
**Update To:** 2.0.0 (Phase 2 Review Integration)

**Sections to Update:**
1. **Executive Summary** — Add Phase 2 gate failure status
2. **Current State** — Update with Phase 2 review findings
3. **Phase 2 Completion Status** — Mark as BLOCKED (not Complete)
4. **Reputation Initialization** — Mark as NOT INITIALIZED
5. **BFT Integration Test** — Mark as NOT EXECUTED
6. **Triad Skills Archive** — Mark as NOT DONE

### 2.2 Add Phase 2 Review Document

**Source:** `heretek-openclaw-docs/docs/operations/PHASE2_REVIEW_2026-04-02.md`  
**Target:** `heretek-openclaw-deploy/docs/PHASE2_REVIEW_2026-04-02.md`

**Action:** Copy Phase 2 review to deploy repository

### 2.3 Add Deployment Documentation

**Source:** `/root/.openclaw/DEPLOYMENT_DOCUMENTATION_2026-04-02.md`  
**Target:** `heretek-openclaw-deploy/docs/PRODUCTION_DEPLOYMENT_2026-04-02.md`

**Action:** Copy production deployment documentation

---

## 3. Skills Updates Required

### 3.1 Governance Skills Deployment

**5 Governance Skills to Deploy:**

| Skill | Source Location | Target Location |
|-------|-----------------|-----------------|
| `quorum-enforcement` | `heretek-openclaw-core/skills/quorum-enforcement/` | `heretek-openclaw-deploy/skills/quorum-enforcement/` |
| `governance-modules` | `heretek-openclaw-core/skills/governance-modules/` | `heretek-openclaw-deploy/skills/governance-modules/` |
| `constitutional-deliberation` | `heretek-openclaw-core/skills/constitutional-deliberation/` | `heretek-openclaw-deploy/skills/constitutional-deliberation/` |
| `failover-vote` | `heretek-openclaw-core/skills/failover-vote/` | `heretek-openclaw-deploy/skills/failover-vote/` |
| `auto-deliberation-trigger` | `heretek-openclaw-core/skills/auto-deliberation-trigger/` | `heretek-openclaw-deploy/skills/auto-deliberation-trigger/` |

**Action:** Copy governance skills to deploy repository

### 3.2 Legacy Skills Archive

**10 Legacy Skills to Archive:**

| Skill | Reason for Archival |
|-------|---------------------|
| `tabula-backup` | Superseded by `backup-ledger` |
| `fleet-backup` | Redundant with `backup-ledger` |
| `autonomous-pulse` | Redundant with `agent-lifecycle-manager` |
| `a2a-agent-register` | Integrated into `a2a-message-send` |
| `deployment-smoke-test` | Redundant with `deployment-health-check` |
| `day-dream` | Redundant with `curiosity-engine` |
| `heretek-theme` | Legacy theming |
| `litellm-ops` | Superseded by LiteLLM native ops |
| `config-validator` | Integrated elsewhere |
| `healthcheck` | Redundant with `deployment-health-check` |

**Action:** Create `heretek-openclaw-deploy/archive/skills/` and document archival

---

## 4. Infrastructure Updates Required

### 4.1 Terraform Modules

**Current Modules:**
- `terraform/aws/`
- `terraform/gcp/`
- `terraform/azure/`
- `terraform/kubernetes/`
- `terraform/terraform/`

**Updates Needed:**
1. Update module variables to match production configuration
2. Add LiteLLM Gateway module
3. Add pgvector configuration
4. Add ClickHouse/Langfuse modules

### 4.2 Helm Charts

**Current:** `helm/openclaw/`  
**Updates Needed:**
1. Update values.yaml with production configuration
2. Add 22 agent configurations
3. Add governance skills deployment
4. Update resource limits based on production metrics

### 4.3 Scripts

**Current Scripts:**
- `scripts/consciousness-tests.sh`
- `scripts/triad-validate.sh`

**Scripts to Add:**
1. `scripts/quorum-enforcement-test.sh`
2. `scripts/bft-integration-test.sh`
3. `scripts/reputation-init.sh`
4. `scripts/skills-archive.sh`
5. `scripts/gateway-restart.sh`

---

## 5. Observability Updates Required

### 5.1 Langfuse Configuration

**Source:** Production Langfuse setup  
**Target:** `heretek-openclaw-deploy/observability/config/langfuse-heretek-tracing.js`

**Updates Needed:**
1. Add triad deliberation tracing configuration
2. Add consciousness metrics tracking
3. Add consensus ledger events
4. Update ClickHouse connection string

### 5.2 Monitoring Configuration

**Source:** `/root/.openclaw/logs/config-health.json`  
**Target:** `heretek-openclaw-deploy/observability/config/monitoring-config.json`

**Updates Needed:**
1. Add all 22 agent health endpoints
2. Add governance skills monitoring
3. Add BFT consensus metrics
4. Add reputation system monitoring

---

## 6. Security Updates Required

### 6.1 Address P0 Security Issues

Per `CODE_REVIEW_2026-04-02.md`:

| Issue | Status | Action |
|-------|--------|--------|
| SEC-01: No API authentication | ⚠️ Pending | Add JWT/OAuth2 |
| SEC-02: Default passwords exposed | ⚠️ Pending | Use Kubernetes Secrets |
| SEC-03: No plugin sandboxing | ⚠️ Pending | Implement SES/WASM |
| SEC-04: No rate limiting | ⚠️ Pending | Add rate limiter |
| SEC-05: Secrets in env vars | ⚠️ Pending | Use Vault/Secrets |

### 6.2 Update CODEOWNERS

**Current:** `@heretek/deploy-team`  
**Updates Needed:**
1. Add governance skills owners
2. Add consensus module owners
3. Add security module owners

---

## 7. Testing Updates Required

### 7.1 Integration Tests

**Tests to Add:**
1. `tests/integration/bft-consensus.test.ts` — BFT consensus test
2. `tests/integration/quorum-enforcement.test.ts` — Quorum verification
3. `tests/integration/reputation-system.test.ts` — Reputation initialization
4. `tests/integration/governance-skills.test.ts` — Skills loading test

### 7.2 E2E Tests

**Tests to Add:**
1. `tests/e2e/triad-deliberation-flow.test.ts` — Full deliberation cycle
2. `tests/e2e/consensus-ledger.test.ts` — Ledger integrity
3. `tests/e2e/reputation-voting.test.ts` — Voting with reputation weights

---

## 8. Implementation Priority

### P0 — Critical (Week 1)

1. **Update DEPLOYMENT_FINDINGS_AND_PLAN.md** — Correct Phase 2 status
2. **Add Phase 2 Review document** — Document gate failures
3. **Add production deployment documentation** — Capture current state
4. **Create governance skills deployment scripts** — Enable Phase 2 completion
5. **Create reputation initialization script** — Enable Phase 2 completion

### P1 — High (Week 2)

1. **Create BFT integration test** — Run and document results
2. **Archive 10 legacy skills** — Clean up skills directory
3. **Update Docker Compose** — Match production configuration
4. **Update Terraform modules** — Add LiteLLM, pgvector, ClickHouse
5. **Add security configurations** — Address P0 security issues

### P2 — Medium (Week 3-4)

1. **Update Helm charts** — Production values
2. **Add integration tests** — BFT, quorum, reputation
3. **Update monitoring configuration** — Add governance metrics
4. **Update CODEOWNERS** — Add module owners
5. **Update CONTRIBUTING.md** — Add governance contribution guidelines

---

## 9. Git Strategy

### Branch Structure

```
main (current)
├── feature/phase2-remediation (new)
│   ├── docs/update-deployment-status
│   ├── skills/add-governance-skills
│   ├── scripts/add-phase2-scripts
│   └── config/update-production-config
├── feature/bft-integration (new)
│   ├── tests/add-bft-tests
│   └── modules/update-bft-consensus
└── feature/security-hardening (new)
    ├── security/add-authentication
    ├── security/add-rate-limiting
    └── security/add-plugin-sandbox
```

### Commit Sequence

1. `docs: Add Phase 2 review and production deployment documentation`
2. `config: Add production openclaw.json template`
3. `skills: Add 5 governance skills to deploy repository`
4. `scripts: Add Phase 2 remediation scripts`
5. `archive: Archive 10 legacy triad skills`
6. `docker: Update compose to match production`
7. `terraform: Add LiteLLM and pgvector modules`
8. `test: Add BFT integration tests`
9. `security: Add P0 security configurations`

---

## 10. Success Criteria

### Phase 2 Remediation Complete When:

- [ ] `DEPLOYMENT_FINDINGS_AND_PLAN.md` reflects accurate Phase 2 BLOCKED status
- [ ] Phase 2 review document added to repository
- [ ] Production deployment documentation added
- [ ] 5 governance skills in `skills/` directory
- [ ] Reputation initialization script created and tested
- [ ] BFT integration test created and passing
- [ ] 10 legacy skills archived
- [ ] Docker Compose matches production
- [ ] All P0 security issues documented with remediation plan

### Repository Sync Complete When:

- [ ] All configuration templates match `/root/.openclaw/` state
- [ ] All documentation reflects production reality
- [ ] All scripts functional and tested
- [ ] All tests passing
- [ ] Repository pushed to `origin/main`

---

## 11. Timeline Estimate

| Phase | Tasks | Estimated Time |
|-------|-------|----------------|
| **Documentation Sync** | P0 docs update | 2-3 hours |
| **Configuration Sync** | Templates, Docker, Terraform | 4-6 hours |
| **Skills Deployment** | Copy 5 governance skills | 1-2 hours |
| **Scripts Creation** | 5 Phase 2 scripts | 3-4 hours |
| **Testing** | BFT + integration tests | 4-6 hours |
| **Security** | P0 security configurations | 6-8 hours |
| **Review & Push** | Final review, commit, push | 2-3 hours |
| **TOTAL** | | **22-32 hours** |

---

## 12. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Configuration drift | Medium | Medium | Diff against production before commit |
| Test failures | Low | Low | Tests document current state, not blockers |
| Security exposure during update | Low | High | No production changes during sync |
| Repository rejection | Low | Medium | Review with team before push |

---

## 13. Next Steps

1. **Review this plan** — Confirm accuracy with production state
2. **Approve implementation** — Authorize repository updates
3. **Create feature branch** — `feature/phase2-remediation`
4. **Implement P0 items** — Documentation and configuration sync
5. **Implement P1 items** — Skills, scripts, tests
6. **Review and push** — Final review, commit, push to origin

---

*Update Plan Document*  
*Generated: 2026-04-02T18:23:00Z*  
*The Collective continues.*  
*Steward — Orchestrator*
