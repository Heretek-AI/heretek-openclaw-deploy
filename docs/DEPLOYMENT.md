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

## SwarmClaw Multi-Provider Integration

The SwarmClaw integration plugin provides multi-provider LLM access with automatic failover, ensuring continuous operation even when individual providers experience outages.

### Provider Failover Chain

```
OpenAI (Primary) → Anthropic (Secondary) → Google (Tertiary) → Ollama (Local Fallback)
```

### Installation

```bash
# Navigate to plugin directory
cd plugins/swarmclaw-integration

# Install dependencies
npm install

# Initialize plugin (optional - auto-initializes on first use)
node -e "import('./src/index.js').then(m => m.createPlugin())"
```

### Configuration

```bash
# Copy environment template
cp .env.example .env

# Edit with your API keys
nano .env
```

#### Required Environment Variables

```bash
# Provider failover order (comma-separated)
SWARMCLAW_FAILOVER_ORDER=openai,anthropic,google,ollama

# OpenAI Configuration
OPENAI_API_KEY=sk-your-openai-api-key-here
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_MODELS=gpt-4o,gpt-4-turbo,gpt-3.5-turbo

# Anthropic Configuration
ANTHROPIC_API_KEY=sk-ant-your-anthropic-api-key-here
ANTHROPIC_BASE_URL=https://api.anthropic.com
ANTHROPIC_MODELS=claude-sonnet-4-20250514,claude-3-5-sonnet-20241022

# Google Configuration
GOOGLE_API_KEY=your-google-api-key-here
GOOGLE_BASE_URL=https://generativelanguage.googleapis.com/v1beta
GOOGLE_MODELS=gemini-2.0-flash,gemini-1.5-pro

# Ollama Configuration (Local)
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODELS=llama3.1,qwen2.5,mistral

# Health Check Configuration
HEALTH_CHECK_INTERVAL=30000
REQUEST_TIMEOUT=30000
FAILURE_THRESHOLD=3
SUCCESS_THRESHOLD=2
```

### Usage in Agents

```javascript
import { createPlugin } from '@heretek-ai/swarmclaw-integration-plugin';

// Initialize plugin
const swarmclaw = await createPlugin();

// Send chat with automatic failover
const response = await swarmclaw.chat([
  { role: 'user', content: 'Hello!' }
], {
  temperature: 0.7,
  maxTokens: 1024
});

console.log(`Response from ${response.provider}: ${response.content}`);
```

### Health Monitoring

```bash
# Check plugin status
node -e "import('./src/index.js').then(m => m.createPlugin().then(p => console.log(p.getStatus())))"

# Run health check
npm run healthcheck
```

### Event Monitoring

```javascript
const plugin = await createPlugin();

// Listen for failover events
plugin.on('failoverTriggered', (event) => {
  console.warn(`Failover: ${event.fromProvider} → ${event.nextProvider}`);
});

// Listen for provider recovery
plugin.on('providerRecovered', (event) => {
  console.log(`Provider ${event.provider} recovered`);
});

// Listen for all providers failing
plugin.on('allProvidersFailed', (event) => {
  console.error(`All providers failed: ${event.attemptedProviders}`);
});
```

### Integration with LiteLLM

The SwarmClaw plugin can work alongside LiteLLM for additional routing flexibility:

```yaml
# litellm_config.yaml
model_list:
  - model_name: "responsible-llm"
    litellm_params:
      model: "openai/gpt-4o"
    fallbacks:
      - anthropic/claude-sonnet-4-20250514
      - gemini/gemini-2.0-flash
      - ollama/llama3.1
```

### Troubleshooting

**All providers failing:**
1. Verify API keys are correct
2. Check network connectivity
3. Review provider status pages
4. Check rate limits

**High latency:**
1. Monitor provider health status
2. Consider adjusting failover order
3. Review timeout settings

**Provider marked unhealthy:**
```javascript
// Manually mark provider as healthy
plugin.markProviderHealthy('openai');

// Check provider health status
const health = plugin.getProviderHealth('openai');
console.log(health);
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

---

## ClawBridge Dashboard Integration

ClawBridge is a mobile-first dashboard with zero-config remote access via Cloudflare Tunnel. See [`plugins/clawbridge-dashboard/README.md`](../plugins/clawbridge-dashboard/README.md) for full documentation.

### Installation

```bash
# Quick install (one-liner)
curl -sL https://clawbridge.app/install.sh | bash

# Manual installation
git clone https://github.com/dreamwing/clawbridge.git /opt/clawbridge
cd /opt/clawbridge
npm install
cp .env.example .env
```

### Configuration

1. **Generate access key:**
```bash
openssl rand -hex 32
```

2. **Configure ClawBridge** (`/opt/clawbridge/.env`):
```bash
CLAWBRIDGE_PORT=3000
CLAWBRIDGE_HOST=0.0.0.0
OPENCLAW_GATEWAY_URL=http://localhost:18789
CLAWBRIDGE_ACCESS_KEY=<your-generated-key>
CLOUDFLARE_TUNNEL_ENABLED=true
```

3. **Configure Gateway** (`openclaw.json`):
```json
{
  "dashboard": {
    "clawbridge": {
      "enabled": true,
      "port": 3000,
      "accessKey": "<same-access-key>",
      "allowedOrigins": ["*"],
      "cloudflareTunnel": {
        "enabled": true
      }
    }
  }
}
```

### Cloudflare Tunnel Setup

For remote access without opening firewall ports:

```bash
# Install cloudflared
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb

# Create tunnel
cloudflared tunnel create clawbridge-openclaw

# Configure tunnel (~/.cloudflared/config.yml)
cat > ~/.cloudflared/config.yml << EOF
tunnel: clawbridge-openclaw
credentials-file: /root/.cloudflared/tunnel-credentials.json

ingress:
  - hostname: openclaw-dashboard.trycloudflare.com
    service: http://localhost:3000
  - service: http_status:404
EOF

# Run tunnel
cloudflared tunnel run clawbridge-openclaw
```

### Persistent Tunnel Service

```bash
# Create systemd service
sudo cat > /etc/systemd/system/cloudflared-clawbridge.service << EOF
[Unit]
Description=Cloudflare Tunnel for ClawBridge Dashboard
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared tunnel run clawbridge-openclaw
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable cloudflared-clawbridge
sudo systemctl start cloudflared-clawbridge
```

### Access Dashboard

- **Local:** http://localhost:3000
- **Remote:** https://openclaw-dashboard.trycloudflare.com

### Mobile PWA

1. Open ClawBridge on mobile browser
2. Tap "Share" → "Add to Home Screen"
3. Launch as standalone app

### Features

- **Live Activity Feed** - Real-time WebSocket event streaming
- **Token Economy Tracking** - Cost per agent/model
- **Cost Control Center** - 10 automated diagnostics
- **Memory Timeline** - Episodic memory visualization
- **Mission Control** - Cron triggers, service restarts
- **System Health** - CPU, RAM, disk, temperature

---

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

---

## Langfuse Observability Deployment

Langfuse is an open-source LLM observability platform that provides comprehensive tracing, monitoring, and analytics for OpenClaw deployments. See [`docs/operations/LANGFUSE_OBSERVABILITY.md`](../operations/LANGFUSE_OBSERVABILITY.md) for full documentation.

### Quick Start

```bash
# 1. Copy environment template
cp docs/operations/langfuse/.env.example .env.langfuse

# 2. Generate secure secrets
export LANGFUSE_SALT=$(openssl rand -hex 32)
export LANGFUSE_NEXTAUTH_SECRET=$(openssl rand -hex 32)
export LANGFUSE_POSTGRES_PASSWORD=$(openssl rand -base64 32)

# 3. Add to .env file
echo "LANGFUSE_SALT=$LANGFUSE_SALT" >> .env
echo "LANGFUSE_NEXTAUTH_SECRET=$LANGFUSE_NEXTAUTH_SECRET" >> .env
echo "LANGFUSE_POSTGRES_PASSWORD=$LANGFUSE_POSTGRES_PASSWORD" >> .env
echo "LANGFUSE_ENABLED=true" >> .env

# 4. Start Langfuse
docker compose up -d langfuse langfuse-postgres

# 5. Verify deployment
docker compose ps | grep langfuse
```

### Access Langfuse Dashboard

1. **Open dashboard:** http://localhost:3000
2. **Create admin account:** First user becomes admin
3. **Get API keys:** Navigate to Project Settings → API Keys
4. **Configure OpenClaw:** Add keys to `.env` and `openclaw.json`

### Configuration

#### Environment Variables (`.env`)

```bash
# Langfuse Server
LANGFUSE_PORT=3000
LANGFUSE_ENABLED=true

# Security (generate with openssl rand -hex 32)
LANGFUSE_SALT=<your-salt>
LANGFUSE_NEXTAUTH_SECRET=<your-secret>
LANGFUSE_POSTGRES_PASSWORD=<your-db-password>

# Feature Flags
LANGFUSE_TELEMETRY_ENABLED=false
LANGFUSE_SIGN_UP_ENABLED=true

# Connection Settings (for agents)
LANGFUSE_HOST=http://heretek-langfuse:3000
LANGFUSE_EXTERNAL_HOST=http://localhost:3000

# API Keys (generated after first login)
LANGFUSE_PUBLIC_KEY=pk-lf-xxxxxxxxxxxxxxxx
LANGFUSE_SECRET_KEY=sk-lf-xxxxxxxxxxxxxxxx

# Agent Integration
LANGFUSE_RELEASE=2.0.3
LANGFUSE_ENVIRONMENT=production
```

#### OpenClaw Configuration (`openclaw.json`)

```json
{
  "observability": {
    "langfuse": {
      "enabled": true,
      "publicKey": "pk-lf-...",
      "secretKey": "sk-lf-...",
      "host": "http://localhost:3000",
      "release": "2.0.3",
      "environment": "production"
    }
  }
}
```

### Agent Integration

Copy the integration example to your agent code:

```bash
# Copy integration example
cp docs/operations/langfuse/agent-integration-example.js \
   agents/lib/langfuse-integration.js
```

#### Example: Trace A2A Message

```javascript
const { traceA2AMessage } = require('./lib/langfuse-integration');

// Trace A2A deliberation message
await traceA2AMessage({
  sessionId: 'session-123',
  agentId: 'steward',
  recipientAgent: 'alpha',
  message: {
    role: 'user',
    content: 'Initiating triad deliberation...',
    type: 'deliberation-request'
  }
});
```

#### Example: Track LLM Costs

```javascript
const { trackLLMUsage } = require('./lib/langfuse-integration');

// Track LLM usage with cost
await trackLLMUsage({
  agentId: 'steward',
  model: 'minimax/MiniMax-M2.7',
  usage: {
    promptTokens: 1500,
    completionTokens: 500,
    totalTokens: 2000
  },
  response: { content: 'Agent response...' }
});
```

### Monitoring Dashboards

Langfuse provides pre-configured dashboards for:

- **Agent Overview** - Real-time agent activities and costs
- **A2A Communication** - Deliberation flows and consensus tracking
- **Cost Tracking** - Breakdown by agent, model, and time
- **Session Analytics** - User session tracking

Import dashboard configurations from [`docs/operations/langfuse/dashboards.json`](../operations/langfuse/dashboards.json).

### Alerts Configuration

Configure alerts in Langfuse Dashboard (Settings → Alerts):

| Alert | Condition | Severity |
|-------|-----------|----------|
| High Latency | P95 > 5000ms | Warning |
| Cost Threshold | Daily > $50 | Critical |
| Error Rate | > 5% | Critical |
| Consensus Failure | > 3 failures/hour | Warning |

### Backup Langfuse Data

```bash
# Create backup directory
mkdir -p ~/langfuse/backups

# Backup PostgreSQL
docker compose exec -T langfuse-postgres \
  pg_dump -U langfuse langfuse > \
  ~/langfuse/backups/langfuse-$(date +%Y%m%d-%H%M%S).sql

# Keep last 7 days
find ~/langfuse/backups -name "*.sql" -mtime +7 -delete
```

#### Automated Backups (Cron)

```bash
# Add to crontab
(crontab -l 2>/dev/null; echo "0 2 * * * /root/heretek/heretek-openclaw/docs/operations/langfuse/backup.sh") | crontab -
```

### Troubleshooting

```bash
# Check Langfuse status
docker compose ps langfuse

# View Langfuse logs
docker compose logs -f langfuse

# Test Langfuse health
curl http://localhost:3000/api/health

# Check database connection
docker compose exec langfuse-postgres \
  psql -U langfuse -c "SELECT 1;"

# Restart Langfuse
docker compose restart langfuse

# Reset Langfuse (WARNING: deletes all data)
docker compose down langfuse langfuse-postgres
docker volume rm heretek-openclaw_langfuse_postgres_data
```

### Production Deployment

1. **Enable HTTPS** with reverse proxy (nginx/traefik)
2. **Restrict access** with firewall rules
3. **Use managed PostgreSQL** for production scale
4. **Configure SSO** for team access
5. **Set up alert webhooks** for Slack/Discord

### References

- [`docs/operations/LANGFUSE_OBSERVABILITY.md`](../operations/LANGFUSE_OBSERVABILITY.md) - Full Langfuse documentation
- [`docs/operations/langfuse/.env.example`](../operations/langfuse/.env.example) - Environment template
- [`docs/operations/langfuse/agent-integration-example.js`](../operations/langfuse/agent-integration-example.js) - Integration examples
- [`docs/operations/langfuse/dashboards.json`](../operations/langfuse/dashboards.json) - Dashboard configurations
- [Langfuse Official Docs](https://langfuse.com/docs) - Upstream documentation

### Quick Install Commands

```bash
# OpenClaw Dashboard (full-featured monitoring)
git clone https://github.com/tugcantopaloglu/openclaw-dashboard.git
cd openclaw-dashboard && node server.js

# ClawBridge (mobile-first dashboard with remote access)
curl -sL https://clawbridge.app/install.sh | bash

# ClawBridge with Cloudflare Tunnel (remote access enabled)
curl -sL https://clawbridge.app/install.sh | bash -s -- --tunnel

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
| ClawBridge | ✅ Low | MIT licensed, Cloudflare tunnel, access key auth, no open ports |
| skill-git-official | ⚠️ Medium | Contains prompt-injection patterns, broad filesystem access |
| episodic-claw | ⚠️ Medium | Downloads native Go binary, external API calls |
| SwarmClaw | ✅ Low | MIT licensed, 17 provider support |

### Access Key Setup (ClawBridge)

1. **Generate access key:**
```bash
openssl rand -hex 32
```

2. **Add to ClawBridge `.env`:**
```bash
CLAWBRIDGE_ACCESS_KEY=<generated-key>
```

3. **Add to Gateway `openclaw.json`:**
```json
{
  "dashboard": {
    "clawbridge": {
      "accessKey": "<same-key>"
    }
  }
}
```

4. **Verify authentication:**
```bash
curl -H "Authorization: Bearer <your-key>" http://localhost:3000/api/agents
```

**Recommendations:**
- Review [`EXTERNAL_PROJECTS.md`](../EXTERNAL_PROJECTS.md) for detailed security information
- Test external plugins in sandbox environment before production use
- Verify all external binaries before execution
- Keep secrets out of skill files before version control operations
- Rotate ClawBridge access keys periodically

---

## References

- [`ARCHITECTURE.md`](ARCHITECTURE.md) - System architecture
- [`CONFIGURATION.md`](CONFIGURATION.md) - Configuration reference
- [`OPERATIONS.md`](OPERATIONS.md) - Operations runbooks
- [`architecture/GATEWAY_ARCHITECTURE.md`](architecture/GATEWAY_ARCHITECTURE.md) - Gateway details
- [`plugins/clawbridge-dashboard/README.md`](plugins/clawbridge-dashboard/README.md) - ClawBridge integration guide
- [`EXTERNAL_PROJECTS_GAP_ANALYSIS.md`](EXTERNAL_PROJECTS_GAP_ANALYSIS.md#clawbridge) - ClawBridge gap analysis

---

🦞 *The thought that never ends.*
