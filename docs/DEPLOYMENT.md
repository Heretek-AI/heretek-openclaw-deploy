# Heretek OpenClaw Deployment Guide

**Version:** 2.0.3  
**Last Updated:** 2026-03-31  
**OpenClaw Gateway:** v2026.3.28

---

## Overview

This guide covers deployment of Heretek OpenClaw using Docker Compose for infrastructure services and OpenClaw Gateway for agent management.

### Architecture Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                    Heretek OpenClaw Stack                        │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   Docker Services                         │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐ │  │
│  │  │ LiteLLM  │ │PostgreSQL│ │  Redis   │ │    Ollama    │ │  │
│  │  │  :4000   │ │  :5432   │ │  :6379   │ │   :11434     │ │  │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────────┘ │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              OpenClaw Gateway (System Daemon)              │  │
│  │                    Port 18789                              │  │
│  │  All 11 agents run as workspaces within Gateway process   │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### System Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| **CPU** | 4 cores | 8+ cores |
| **RAM** | 8 GB | 16+ GB |
| **Disk** | 20 GB | 50+ GB SSD |
| **GPU** | Optional | AMD ROCm compatible |

### Software Requirements

- Docker 20.10+
- Docker Compose 2.0+
- Git
- Node.js 18+ (for OpenClaw Gateway)
- curl, wget

---

## Installation

### Step 1: Clone Repository

```bash
git clone https://github.com/Heretek-AI/heretek-openclaw.git
cd heretek-openclaw
```

### Step 2: Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit environment variables
nano .env
```

#### Required Environment Variables

```bash
# LiteLLM Gateway
LITELLM_MASTER_KEY=heretek-master-key-change-me
LITELLM_UI_PASSWORD=change-me-please

# Provider API Keys
MINIMAX_API_KEY=your-minimax-api-key
ZAI_API_KEY=your-zai-api-key

# PostgreSQL
POSTGRES_PASSWORD=heretek

# Redis
REDIS_PASSWORD=
```

### Step 3: Start Docker Services

```bash
# Start all services
docker compose up -d

# Verify services are running
docker compose ps

# View logs
docker compose logs -f litellm
```

### Step 4: Install OpenClaw Gateway

```bash
# Install OpenClaw Gateway
curl -fsSL https://openclaw.ai/install.sh | bash

# Verify installation
openclaw gateway status
```

### Step 5: Configure Gateway

```bash
# Copy configuration
cp openclaw.json ~/.openclaw/openclaw.json

# Validate configuration
openclaw gateway validate
```

### Step 6: Create Agent Workspaces

```bash
# Create agent workspaces from templates
cd agents

# Deploy each agent
./deploy-agent.sh steward Steward orchestrator
./deploy-agent.sh alpha Alpha triad_member
./deploy-agent.sh beta Beta triad_member
./deploy-agent.sh charlie Charlie triad_member
./deploy-agent.sh examiner Examiner evaluator
./deploy-agent.sh explorer Explorer researcher
./deploy-agent.sh sentinel Sentinel safety
./deploy-agent.sh coder Coder developer
./deploy-agent.sh dreamer Dreamer creative
./deploy-agent.sh empath Empath emotional
./deploy-agent.sh historian Historian archivist
```

### Step 7: Start Gateway

```bash
# Start OpenClaw Gateway
openclaw gateway start

# Verify Gateway is running
openclaw gateway status

# List all agents
openclaw agent list
```

---

## Docker Services

### Start Services

```bash
# Start all services
docker compose up -d

# Start specific service
docker compose up -d litellm

# Start with rebuild
docker compose up -d --build
```

### Stop Services

```bash
# Stop all services
docker compose down

# Stop and remove volumes
docker compose down -v

# Stop specific service
docker compose stop postgres
```

### Service Health

```bash
# Check all services
docker compose ps

# Check specific service
docker compose ps litellm

# View logs
docker compose logs -f litelll
docker compose logs -f postgres
docker compose logs -f redis
```

---

## Verification

### Health Check Script

```bash
# Full system health check
./scripts/health-check.sh

# Continuous monitoring
./scripts/health-check.sh --watch

# Check specific service
./scripts/health-check.sh litellm
```

### Manual Verification

```bash
# Check LiteLLM
curl -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  http://localhost:4000/health

# Check PostgreSQL
docker compose exec postgres psql -U heretek -c "SELECT 1;"

# Check Redis
docker compose exec redis redis-cli ping

# Check OpenClaw Gateway
openclaw gateway status

# Check agents
openclaw agent list
```

---

## Agent Deployment

### Deploy Single Agent

```bash
cd agents

# Deploy from template
./deploy-agent.sh <id> <name> <role>

# Example
./deploy-agent.sh steward Steward orchestrator
```

### Deploy All Agents

```bash
#!/bin/bash
cd agents

agents=(
  "steward:Steward:orchestrator"
  "alpha:Alpha:triad_member"
  "beta:Beta:triad_member"
  "charlie:Charlie:triad_member"
  "examiner:Examiner:evaluator"
  "explorer:Explorer:researcher"
  "sentinel:Sentinel:safety"
  "coder:Coder:developer"
  "dreamer:Dreamer:creative"
  "empath:Empath:emotional"
  "historian:Historian:archivist"
)

for agent in "${agents[@]}"; do
  IFS=':' read -r id name role <<< "$agent"
  ./deploy-agent.sh "$id" "$name" "$role"
done
```

### Verify Agent Deployment

```bash
# Check workspace exists
ls -la ~/.openclaw/agents/steward/

# Check identity files
cat ~/.openclaw/agents/steward/IDENTITY.md

# Check agent status
openclaw agent status steward
```

---

## Plugin Installation

### Install Plugins

```bash
# List available plugins
openclaw plugins list

# Install consciousness plugin
cd plugins/openclaw-consciousness-plugin
npm install
npm link
openclaw plugins install @heretek-ai/openclaw-consciousness-plugin

# Install liberation plugin
cd plugins/openclaw-liberation-plugin
npm install
npm link
openclaw plugins install @heretek-ai/openclaw-liberation-plugin
```

### Verify Plugins

```bash
# List installed plugins
openclaw plugins list

# Check plugin status
openclaw plugins status consciousness
```

---

## Configuration Validation

### Validate openclaw.json

```bash
openclaw gateway validate
```

### Validate litellm_config.yaml

```bash
# Test LiteLLM configuration
curl -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  http://localhost:4000/v1/models
```

### Validate Environment

```bash
# Check environment variables
env | grep -E "LITELLM|MINIMAX|ZAI|POSTGRES|REDIS"
```

---

## Troubleshooting

### Gateway Won't Start

```bash
# Check Gateway status
openclaw gateway status

# Check Gateway logs
journalctl -u openclaw-gateway -f

# Reinstall Gateway
openclaw gateway reinstall
```

### Agent Not Responding

```bash
# Check agent workspace
ls -la ~/.openclaw/agents/<agent>/

# Validate configuration
openclaw gateway validate

# Restart Gateway
openclaw gateway restart
```

### LiteLLM Issues

```bash
# Check LiteLLM logs
docker compose logs litellm

# Test LiteLLM endpoint
curl http://localhost:4000/health

# Restart LiteLLM
docker compose restart litellm
```

### PostgreSQL Issues

```bash
# Check PostgreSQL logs
docker compose logs postgres

# Test connection
docker compose exec postgres psql -U heretek -c "SELECT 1;"

# Restart PostgreSQL
docker compose restart postgres
```

---

## Backup and Restore

### Production Backup

```bash
# Full backup
./scripts/production-backup.sh --all

# Database only
./scripts/production-backup.sh --database

# List backups
./scripts/production-backup.sh --list
```

### Restore from Backup

```bash
# Restore latest backup
./scripts/production-backup.sh --restore latest

# Restore specific date
./scripts/production-backup.sh --restore 20260331
```

---

## Update Procedures

### Update Docker Services

```bash
# Pull latest images
docker compose pull

# Restart with new images
docker compose up -d
```

### Update OpenClaw Gateway

```bash
# Update Gateway
openclaw gateway update

# Restart Gateway
openclaw gateway restart
```

### Update Configuration

```bash
# Pull latest configuration
git pull origin main

# Validate new configuration
openclaw gateway validate

# Restart Gateway
openclaw gateway restart
```

---

## Production Deployment

### Security Hardening

1. **Change Default Keys**
```bash
# Generate secure master key
openssl rand -hex 32

# Update .env
LITELLM_MASTER_KEY=<generated-key>
```

2. **Enable Firewall**
```bash
# Allow only required ports
ufw allow 4000/tcp  # LiteLLM
ufw allow 5432/tcp  # PostgreSQL
ufw allow 6379/tcp  # Redis
ufw allow 11434/tcp # Ollama
ufw allow 18789/tcp # OpenClaw Gateway
```

3. **Enable Observability**
```bash
# Enable Langfuse
LANGFUSE_ENABLED=true
LANGFUSE_PUBLIC_KEY=<key>
LANGFUSE_SECRET_KEY=<key>
```

### Monitoring Setup

```bash
# Enable metrics
docker compose exec litellm \
  curl -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  http://localhost:4000/metrics

# Set up health check cron
(crontab -l 2>/dev/null; echo "*/5 * * * * /root/heretek/heretek-openclaw/scripts/health-check.sh") | crontab -
```

---

## External Integrations

This section covers external projects and services that integrate with Heretek OpenClaw.

### Dashboard Options

| Dashboard | Type | Access | Auth | Best For |
|-----------|------|--------|------|----------|
| **[OpenClaw Dashboard](../EXTERNAL_PROJECTS.md#openclaw-dashboard)** | Third-party | localhost/Tailscale | Username+Password+TOTP | Full-featured monitoring |
| **[ClawBridge](../EXTERNAL_PROJECTS.md#clawbridge)** | Official | Mobile/VPN/Tunnel | Access Key | Mobile-first, remote access |

### Plugin Extensions

| Plugin | Source | Purpose | Security Level |
|--------|--------|---------|----------------|
| **[skill-git-official](../EXTERNAL_PROJECTS.md#skill-git-official)** | ClawHub | Skill version control | ⚠️ Review before install |
| **[episodic-claw](../EXTERNAL_PROJECTS.md#episodic-claw)** | ClawHub | Episodic memory | ⚠️ Native binary download |
| **[SwarmClaw](../EXTERNAL_PROJECTS.md#swarmclaw)** | External | Swarm coordination | ✅ MIT licensed |

### Observability

| Service | Type | Purpose |
|---------|------|---------|
| **[Langfuse](../operations/LANGFUSE_OBSERVABILITY.md)** | Self-hosted | A2A tracing, cost tracking, analytics |

### Quick Install Commands

```bash
# OpenClaw Dashboard (full-featured monitoring)
git clone https://github.com/tugcantopaloglu/openclaw-dashboard.git
cd openclaw-dashboard && node server.js

# ClawBridge (mobile-first dashboard)
curl -sL https://clawbridge.app/install.sh | bash

# skill-git-official (skill version control)
openclaw bundles install clawhub:skill-git-official

# episodic-claw (long-term memory)
openclaw plugins install clawhub:episodic-claw

# SwarmClaw (external control plane)
curl -fsSL https://swarmclaw.ai/install.sh | bash
```

### Security Considerations

| Project | Risk Level | Notes |
|---------|------------|-------|
| OpenClaw Dashboard | ✅ Low | PBKDF2 hashing, TOTP MFA, local-only by default |
| ClawBridge | ✅ Low | MIT licensed, Cloudflare tunnel, access key auth |
| skill-git-official | ⚠️ Medium | Contains prompt-injection patterns, broad filesystem access |
| episodic-claw | ⚠️ Medium | Downloads native Go binary, external API calls |
| SwarmClaw | ✅ Low | MIT licensed, 17 provider support |

**Recommendations:**
- Review [`EXTERNAL_PROJECTS.md`](../EXTERNAL_PROJECTS.md) for detailed security information
- Test external plugins in sandbox environment before production use
- Verify all external binaries before execution
- Keep secrets out of skill files before version control operations

---

## References

- [`ARCHITECTURE.md`](ARCHITECTURE.md) - System architecture
- [`CONFIGURATION.md`](CONFIGURATION.md) - Configuration reference
- [`OPERATIONS.md`](OPERATIONS.md) - Operations runbooks
- [`architecture/GATEWAY_ARCHITECTURE.md`](architecture/GATEWAY_ARCHITECTURE.md) - Gateway details

---

🦞 *The thought that never ends.*
