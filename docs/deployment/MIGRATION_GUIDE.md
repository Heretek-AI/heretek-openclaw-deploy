# Heretek OpenClaw v2.0.3 Migration Guide

**Version:** 2.0.3  
**Release Date:** 2026-03-31  
**OpenClaw Gateway:** v2026.3.28

This guide documents the breaking changes and upgrade procedures for migrating from v1.x to v2.0.3.

---

## Table of Contents

1. [Overview](#overview)
2. [Breaking Changes](#breaking-changes)
3. [Architecture Changes](#architecture-changes)
4. [Migration Steps](#migration-steps)
5. [Post-Migration Validation](#post-migration-validation)
6. [Rollback Procedures](#rollback-procedures)
7. [Troubleshooting](#troubleshooting)

---

## Overview

Version 2.0.3 represents a significant architectural shift from container-based agent deployment to the **OpenClaw Gateway** architecture. This consolidation simplifies deployment, reduces resource overhead, and improves inter-agent communication.

### Key Changes Summary

| Component | v1.x | v2.0.3 |
|-----------|------|--------|
| **Agent Runtime** | 11 separate Docker containers | Single Gateway process |
| **A2A Communication** | Redis pub/sub | Gateway WebSocket RPC |
| **Session Storage** | Redis | JSONL files per workspace |
| **Agent Ports** | 8001-8011 | 18789 (Gateway) |
| **Web Interface** | SvelteKit Dashboard | Langfuse Dashboard |
| **Observability** | Per-agent Langfuse client | Gateway-level integration |

---

## Breaking Changes

### 1. Agent Architecture

**Before (v1.x):**
- Each agent ran as a separate Docker container
- Agents communicated via Redis pub/sub
- Individual health endpoints on ports 8001-8011

**After (v2.0.3):**
- All 11 agents run as workspaces within Gateway process
- A2A communication via Gateway WebSocket RPC (port 18789)
- Single Gateway health endpoint

**Impact:**
- Docker Compose configurations must be updated
- Agent health checks now target Gateway port 18789
- Redis pub/sub no longer required for A2A

### 2. Removed Components

The following components have been removed:

| Component | Reason | Replacement |
|-----------|--------|-------------|
| `web-interface/` | Codebase consolidation | Langfuse Dashboard |
| `dashboard/` | Redundant with Gateway | Gateway WebSocket API |
| `clawbridge/` | Deprecated mobile interface | Direct Gateway access |
| `modules/thought-loop/` | Gateway-level feature | Gateway thought processing |
| `modules/self-model/` | Gateway-level feature | Gateway self-model |
| `collective/registry.js` | Gateway-level feature | Gateway multi-collective |
| `observability/langfuse-client.js` | Gateway-level integration | Gateway Langfuse |
| `observability/opentelemetry.js` | Gateway-level integration | Gateway OpenTelemetry |

### 3. Configuration Changes

**openclaw.json:**
- `agents[].port` field deprecated (agents no longer have individual ports)
- `a2a_protocol.endpoints` now use Gateway base URL
- New `passthrough_endpoints` configuration for LiteLLM integration

**.env Variables:**

| Variable | Status | Notes |
|----------|--------|-------|
| `OPENCLAW_DIR` | Required | Gateway workspace directory |
| `OPENCLAW_WORKSPACE` | Required | Agent workspaces location |
| `GATEWAY_URL` | New | `ws://127.0.0.1:18789` |
| `AGENT_*_PORT` | Deprecated | No longer used |
| `REDIS_URL` | Optional | Only for caching, not A2A |

### 4. Docker Compose Changes

**Services Removed:**
- `web` (Web Interface)
- `websocket-bridge` (Redis-to-WebSocket)
- `steward`, `alpha`, `beta`, `charlie`, `examiner`, `explorer`, `sentinel`, `coder`, `dreamer`, `empath`, `historian` (agent containers)

**Services Retained:**
- `langfuse` (Observability)
- `langfuse-postgres` (Langfuse database)
- `litellm` (Model routing)
- `postgres` (Primary database with pgvector)
- `redis` (Caching layer)
- `ollama` (Local LLM/embeddings)

---

## Architecture Changes

### v1.x Architecture (Legacy)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Heretek OpenClaw Stack                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   Core Services                           │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐               │   │
│  │  │ LiteLLM  │  │PostgreSQL│  │  Redis   │               │   │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘               │   │
│  └───────┼─────────────┼─────────────┼──────────────────────┘   │
│          │             │             │                           │
│  ┌───────▼─────────────▼─────────────▼──────────────────────┐   │
│  │              Individual Agent Containers                  │   │
│  │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ...    │   │
│  │  │Stew │ │Alpha│ │Beta │ │ ... │ │Empath│ │Hist │      │   │
│  │  │:8001│ │:8002│ │:8003│ │     │ │:8010│ │:8011│      │   │
│  │  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘ └─────┘      │   │
│  └───────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Web Interface (:3000)                        │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### v2.0.3 Architecture (Current)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Heretek OpenClaw Stack                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   Core Services                           │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐               │   │
│  │  │ LiteLLM  │  │PostgreSQL│  │  Redis   │               │   │
│  │  │  :4000   │  │  :5432   │  │  :6379   │               │   │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘               │   │
│  └───────┼─────────────┼─────────────┼──────────────────────┘   │
│          │             │             │                           │
│  ┌───────▼─────────────▼─────────────▼──────────────────────┐   │
│  │              OpenClaw Gateway (Port 18789)                │   │
│  │  All 11 agents run as workspaces within Gateway process  │   │
│  │  Agent workspaces: ~/.openclaw/agents/{agent}/           │   │
│  └───────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Langfuse Dashboard (:3000)                   │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Migration Steps

### Step 1: Backup Current Installation

```bash
# Create backup directory
mkdir -p ~/openclaw-backup-$(date +%Y%m%d)

# Backup configuration files
cp -r ~/.openclaw ~/openclaw-backup-$(date +%Y%m%d)/
cp docker-compose.yml ~/openclaw-backup-$(date +%Y%m%d)/
cp openclaw.json ~/openclaw-backup-$(date +%Y%m%d)/
cp .env ~/openclaw-backup-$(date +%Y%m%d)/

# Backup agent workspaces
cp -r ~/.openclaw/agents ~/openclaw-backup-$(date +%Y%m%d)/

# Verify backup
tar -czf openclaw-backup-$(date +%Y%m%d).tar.gz ~/openclaw-backup-$(date +%Y%m%d)/
```

### Step 2: Stop Current Services

```bash
# Stop Docker Compose services
cd /path/to/heretek-openclaw
docker compose down

# Stop any running Gateway processes
pkill -f openclaw || true
```

### Step 3: Update Docker Compose

Replace your `docker-compose.yml` with the v2.0.3 version:

```bash
# Backup old compose file
mv docker-compose.yml docker-compose.yml.v1

# The new docker-compose.yml should only contain:
# - langfuse, langfuse-postgres
# - litellm, postgres, redis, ollama
# NO agent containers, NO web interface
```

### Step 4: Install OpenClaw Gateway

```bash
# Install OpenClaw Gateway (official script)
curl -fsSL https://openclaw.ai/install.sh | bash

# Verify installation
openclaw --version
# Expected: OpenClaw Gateway v2026.3.28
```

### Step 5: Update Configuration

```bash
# Update .env with new variables
cat >> .env << EOF

# OpenClaw Gateway (v2.0.3)
OPENCLAW_DIR=/root/.openclaw
OPENCLAW_WORKSPACE=/root/.openclaw/agents
GATEWAY_URL=ws://127.0.0.1:18789
EOF

# Update openclaw.json
# Ensure passthrough_endpoints is enabled
jq '.model_routing.passthrough_endpoints.enabled = true' openclaw.json > openclaw.json.tmp
mv openclaw.json.tmp openclaw.json
```

### Step 6: Migrate Agent Workspaces

```bash
# Create new workspace structure
mkdir -p ~/.openclaw/agents

# Deploy each agent workspace
cd /path/to/heretek-openclaw
./agents/deploy-agent.sh steward orchestrator
./agents/deploy-agent.sh alpha triad
./agents/deploy-agent.sh beta triad
./agents/deploy-agent.sh charlie triad
./agents/deploy-agent.sh examiner interrogator
./agents/deploy-agent.sh explorer scout
./agents/deploy-agent.sh sentinel guardian
./agents/deploy-agent.sh coder artisan
./agents/deploy-agent.sh dreamer visionary
./agents/deploy-agent.sh empath diplomat
./agents/deploy-agent.sh historian archivist

# Verify workspaces
ls -la ~/.openclaw/agents/
```

### Step 7: Start Services

```bash
# Start Docker Compose infrastructure
docker compose up -d

# Wait for services to be healthy
docker compose ps

# Start Gateway
openclaw gateway start

# Verify Gateway status
openclaw gateway status
```

### Step 8: Validate Migration

```bash
# Check Gateway health
curl http://localhost:18789/health

# List agents
openclaw agent list

# Check agent status
for agent in steward alpha beta charlie examiner explorer sentinel coder dreamer empath historian; do
  echo "=== $agent ==="
  openclaw agent status $agent
done
```

---

## Post-Migration Validation

### Checklist

- [ ] All Docker services running (`docker compose ps`)
- [ ] Gateway started and healthy
- [ ] All 11 agents registered
- [ ] LiteLLM endpoints accessible
- [ ] Langfuse dashboard accessible
- [ ] A2A communication working
- [ ] Skills loading correctly
- [ ] Plugins loading correctly

### Test Commands

```bash
# Gateway health
openclaw gateway status

# Agent communication test
openclaw agent send steward "Hello from migration test"

# LiteLLM endpoints
curl http://localhost:4000/v1/models

# Langfuse dashboard
open http://localhost:3000
```

---

## Rollback Procedures

If you need to rollback to v1.x:

```bash
# Stop Gateway
openclaw gateway stop

# Restore backup
cd ~/openclaw-backup-$(date +%Y%m%d)
cp -r .openclaw ~/.openclaw
cp docker-compose.yml /path/to/heretek-openclaw/
cp openclaw.json /path/to/heretek-openclaw/

# Restore Docker Compose
cd /path/to/heretek-openclaw
docker compose down
docker compose -f docker-compose.yml.v1 up -d

# Verify rollback
docker compose ps
```

---

## Troubleshooting

### Gateway Won't Start

```bash
# Check installation
openclaw --version

# Check logs
journalctl -u openclaw-gateway -f

# Reinstall if needed
openclaw gateway reinstall
```

### Agents Not Showing

```bash
# Validate configuration
openclaw gateway validate

# Check workspaces exist
ls -la ~/.openclaw/agents/

# Recreate if needed
./agents/deploy-agent.sh <agent> <role>
```

### A2A Communication Issues

```bash
# Check Gateway WebSocket
wscat -c ws://localhost:18789

# Verify agent registration
curl http://localhost:18789/v1/agents
```

### LiteLLM Integration Issues

```bash
# Check LiteLLM health
curl http://localhost:4000/health

# Verify model endpoints
curl http://localhost:4000/v1/models

# Check LiteLLM logs
docker compose logs litellm
```

---

## Support

For issues or questions:

- **Documentation:** [`docs/`](../docs/)
- **Architecture:** [`docs/architecture/GATEWAY_ARCHITECTURE.md`](../architecture/GATEWAY_ARCHITECTURE.md)
- **Operations:** [`docs/operations/runbook-troubleshooting.md`](../operations/runbook-troubleshooting.md)
- **GitHub Issues:** https://github.com/Heretek-AI/heretek-openclaw/issues

---

**Last Updated:** 2026-03-31  
**Version:** 2.0.3
