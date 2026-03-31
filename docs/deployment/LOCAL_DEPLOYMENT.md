# Local Deployment Guide

**Version:** 1.0.0  
**Last Updated:** 2026-03-31  
**OpenClaw Version:** v2026.3.28

This guide provides step-by-step instructions for deploying the Heretek OpenClaw stack locally on a Linux server.

---

## Prerequisites

### System Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| **OS** | Linux (Ubuntu 20.04+) | Ubuntu 22.04 LTS |
| **CPU** | 4 cores | 8+ cores |
| **RAM** | 8 GB | 16+ GB |
| **Disk** | 20 GB | 50+ GB SSD |
| **Docker** | 20.10+ | Latest stable |
| **Node.js** | 18+ | 20+ LTS |
| **Git** | Any | Latest |

### Required Software

```bash
# Install Docker
curl -fsSL https://get.docker.com | bash
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Git
sudo apt-get install -y git

# Verify installations
docker --version
docker-compose --version
node --version
npm --version
git --version
```

### API Keys Required

| Provider | Purpose | Get Key |
|----------|---------|---------|
| **MiniMax** | Primary LLM | https://platform.minimaxi.com |
| **z.ai** | Failover LLM | https://platform.z.ai |
| **(Optional) Langfuse** | Observability | https://cloud.langfuse.com |

---

## Step 1: Clone Repository

```bash
# Clone the repository
git clone https://github.com/Heretek-AI/heretek-openclaw.git
cd heretek-openclaw

# Verify repository structure
ls -la
```

Expected output should show:
- `docker-compose.yml`
- `openclaw.json`
- `litellm_config.yaml`
- `.env.example`
- `agents/`, `plugins/`, `skills/`, `docs/` directories

---

## Step 2: Deploy Infrastructure (Docker)

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your API keys
nano .env
```

### Required Environment Variables

```bash
# LiteLLM Gateway
LITELLM_MASTER_KEY=generate-a-secure-key-here
LITELLM_SALT_KEY=generate-another-secure-key

# Model Providers
MINIMAX_API_KEY=your_minimax_api_key
ZAI_API_KEY=your_zai_api_key

# Database
POSTGRES_USER=openclaw
POSTGRES_PASSWORD=generate-secure-db-password
POSTGRES_DB=openclaw
DATABASE_URL=postgresql://openclaw:your_password@postgres:5432/openclaw

# Redis
REDIS_URL=redis://redis:6379

# Ollama (embeddings)
OLLAMA_HOST=0.0.0.0:11434

# OpenClaw Gateway
OPENCLAW_DIR=/root/.openclaw
OPENCLAW_WORKSPACE=/root/.openclaw/agents

# Observability (optional)
LANGFUSE_ENABLED=false
LANGFUSE_PUBLIC_KEY=your_langfuse_public_key
LANGFUSE_SECRET_KEY=your_langfuse_secret_key
LANGFUSE_HOST=https://cloud.langfuse.com
```

### Start Docker Services

```bash
# Deploy infrastructure
docker compose up -d

# Verify services
docker compose ps

# Expected output:
# NAME                      STATUS          PORTS
# heretek-litellm           Up (healthy)    0.0.0.0:4000->4000/tcp
# heretek-postgres          Up (healthy)    127.0.0.1:5432->5432/tcp
# heretek-redis             Up (healthy)    127.0.0.1:6379->6379/tcp
# heretek-ollama            Up              127.0.0.1:11434->11434/tcp
# heretek-langfuse          Up (healthy)    0.0.0.0:3000->3000/tcp
```

### Verify Service Health

```bash
# Check LiteLLM
curl http://localhost:4000/health

# Check PostgreSQL
docker compose exec postgres psql -U openclaw -c "SELECT version();"

# Check Redis
docker compose exec redis redis-cli ping

# Check Ollama
curl http://localhost:11434/api/tags
```

---

## Step 3: Install OpenClaw Gateway

```bash
# Install OpenClaw Gateway (official script)
curl -fsSL https://openclaw.ai/install.sh | bash

# Verify installation
openclaw --version

# Expected: OpenClaw Gateway v2026.3.28

# Initialize daemon
openclaw onboard --install-daemon

# Verify Gateway status
openclaw gateway status
```

### Expected Output

```
Gateway: Running
Version: v2026.3.28
Workspace: /root/.openclaw
Agents: 0 configured
Plugins: 0 loaded
Skills: 0 loaded
```

---

## Step 4: Configure Gateway

```bash
# Copy our Gateway configuration
cp openclaw.json ~/.openclaw/openclaw.json

# Validate configuration
openclaw gateway validate

# Restart Gateway to pick up configuration
openclaw gateway restart

# Verify configuration loaded
openclaw gateway status
```

### Expected Output

```
Gateway: Running
Version: v2026.3.28
Workspace: /root/.openclaw
Agents: 12 configured (main + 11 collective)
Plugins: 0 loaded
Skills: 0 loaded
```

---

## Step 5: Create Agent Workspaces

```bash
# Run agent creation script for each agent
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

# Verify workspaces created
ls -la ~/.openclaw/agents/
```

### Expected Workspace Structure

Each agent workspace contains:
```
~/.openclaw/agents/steward/
├── SOUL.md          # Partnership protocol, core nature
├── IDENTITY.md      # Personality matrix, behavioral traits
├── AGENTS.md        # Operational guidance, liberation principles
├── USER.md          # Human partner context
├── TOOLS.md         # Tool usage notes
└── MEMORY.md        # Curated long-term memory
```

---

## Step 6: Install Plugins & Skills

### Install Heretek Plugins

```bash
# Install consciousness plugin
cd plugins/openclaw-consciousness-plugin
npm install
npm link
openclaw plugins install @heretek-ai/openclaw-consciousness-plugin

# Install liberation plugin
cd ../openclaw-liberation-plugin
npm install
npm link
openclaw plugins install @heretek-ai/openclaw-liberation-plugin

# Verify plugins
openclaw plugins list
```

### Install Heretek Skills

```bash
# Install triad consensus skill
cd ../../skills/triad-consensus
openclaw skills install ./SKILL.md

# Install thought loop skill
cd ../thought-loop
openclaw skills install ./SKILL.md

# Install self-model skill
cd ../self-model
openclaw skills install ./SKILL.md

# Install user rolodex skill
cd ../user-rolodex
openclaw skills install ./SKILL.md

# Install goal arbitration skill
cd ../goal-arbitration
openclaw skills install ./SKILL.md

# Verify skills
openclaw skills list
```

### (Optional) Install ClawHub Plugins

```bash
# Install episodic memory plugin
openclaw plugins install episodic-claw

# Install swarm coordination plugin
openclaw plugins install @swarmdock/openclaw-plugin

# Install git version control skill
openclaw plugins install skill-git-official
```

---

## Step 7: Configure LiteLLM

```bash
# Copy LiteLLM configuration
cp litellm_config.yaml ~/.litellm/litellm_config.yaml

# Restart LiteLLM to pick up configuration
docker compose restart litellm

# Verify endpoints
curl http://localhost:4000/v1/models
```

### Expected Models

Output should show:
- `agent/steward`, `agent/alpha`, `agent/beta`, etc. (11 agent endpoints)
- `minimax/MiniMax-M2.7` (primary model)
- `zai/glm-5-1`, `zai/glm-5` (failover models)

---

## Step 8: Access Langfuse Dashboard

The Langfuse observability dashboard is already running as part of the Docker Compose stack.

```bash
# Access Langfuse dashboard
open http://localhost:3000

# Default credentials (set in .env):
# Username: admin
# Password: Check your LANGFUSE credentials in .env
```

---

## Step 9: Validate Deployment

### Gateway Health Check

```bash
# Check gateway status
openclaw gateway status

# Expected output:
# Gateway: Running
# Version: v2026.3.28
# Agents: 12 configured
# Plugins: 2 Heretek plugins
# Skills: 5 Heretek skills
```

### Agent Health Check

```bash
# Run comprehensive health check
./scripts/health-check.sh

# Or check each agent individually
for agent in main steward alpha beta charlie examiner explorer sentinel coder dreamer empath historian; do
  echo "=== $agent ==="
  openclaw agent status $agent
done
```

### Skill Execution Test

```bash
# Test triad consensus
openclaw skill run triad-consensus --test

# Test thought loop
openclaw skill run thought-loop --test

# Test self-model
openclaw skill run self-model --test
```

### Plugin Integration Test

```bash
# Test consciousness plugin
openclaw plugin test openclaw-consciousness-plugin

# Test liberation plugin
openclaw plugin test openclaw-liberation-plugin
```

---

## Step 10: Access Dashboards

| Interface | URL | Port | Description |
|-----------|-----|------|-------------|
| **Langfuse** | http://localhost:3000 | 3000 | LLM observability dashboard |
| **LiteLLM** | http://localhost:4000 | 4000 | Model API gateway |
| **OpenClaw Gateway** | ws://localhost:18789 | 18789 | Agent management via WebSocket |

---

## Troubleshooting

### Gateway Won't Start

```bash
# Check installation
openclaw gateway status

# Reinstall if needed
openclaw gateway reinstall

# Check logs
journalctl -u openclaw-gateway -f
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

### Skills Not Loading

```bash
# Check skill format
openclaw skills validate ./skills/triad-consensus/SKILL.md

# Reinstall skill
openclaw skills uninstall triad-consensus
openclaw skills install ./skills/triad-consensus/SKILL.md
```

### Plugins Not Loading

```bash
# Check plugin installation
openclaw plugins list

# Reinstall plugin
cd plugins/openclaw-consciousness-plugin
npm install
npm link
openclaw plugins install @heretek-ai/openclaw-consciousness-plugin
```

### Docker Services Not Starting

```bash
# Check Docker daemon
sudo systemctl status docker

# Check service logs
docker compose logs litellm
docker compose logs postgres
docker compose logs redis

# Restart all services
docker compose down
docker compose up -d
```

### Port Conflicts

```bash
# Check if ports are in use
sudo netstat -tlnp | grep -E '4000|5432|6379|18789|7000|3001'

# Kill conflicting process
sudo kill -9 <PID>

# Or change port in configuration
```

---

## Common Issues

### Issue: Ollama Container Unhealthy

**Symptom:** `docker compose ps` shows Ollama as unhealthy

**Solution:**
```bash
# Pull latest Ollama image
docker pull ollama/ollama:latest

# Restart Ollama
docker compose restart ollama

# Verify
docker compose ps ollama
```


### Issue: LiteLLM Configuration Not Loading

**Symptom:** Agent endpoints not available at port 4000

**Solution:**
```bash
# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('litellm_config.yaml'))"

# Check configuration location
ls -la ~/.litellm/litellm_config.yaml

# Restart LiteLLM
docker compose restart litellm
docker compose logs litellm
```

### Issue: Agent Workspace Missing Files

**Symptom:** `openclaw agent status <agent>` shows errors

**Solution:**
```bash
# Check workspace directory
ls -la ~/.openclaw/agents/<agent>/

# Re-deploy agent
./agents/deploy-agent.sh <agent> <role>
```

---

## Post-Deployment

### Enable Session Keeper

```bash
# Configure automatic session commits
openclaw config set session.keeper.enabled true
openclaw config set session.keeper.auto_commit true
```

### Activate Thought Loop

```bash
# Enable background thought processing
openclaw skill enable thought-loop
openclaw skill run thought-loop --daemon
```

### Configure Dreamer Agent

```bash
# Enable overnight consolidation
openclaw agent config dreamer set schedule.enabled true
openclaw agent config dreamer set schedule.time "02:00"
```

---

## Backup Configuration

```bash
# Backup OpenClaw configuration
tar -czf openclaw-backup-$(date +%Y%m%d).tar.gz \
  ~/.openclaw/openclaw.json \
  ~/.openclaw/agents/ \
  ~/.litellm/litellm_config.yaml

# Backup is stored in current directory
ls -la openclaw-backup-*.tar.gz
```

---

## Next Steps

After successful deployment:

1. **Access Langfuse Dashboard** - Access http://localhost:3000 to monitor agent traces
2. **Test Agent Communication** - Send messages via Gateway WebSocket RPC
3. **Configure User Profiles** - Set up user rolodex with `./skills/user-rolodex/user-rolodex.sh`
4. **Enable Autonomous Operations** - Activate dreamer agent for overnight consolidation
5. **Review Documentation** - See [`docs/`](../../docs/) for advanced configuration

---

## Support

For issues or questions:
- Check [`docs/operations/runbook-troubleshooting.md`](../operations/runbook-troubleshooting.md)
- Review [`CHANGELOG.md`](../../CHANGELOG.md) for recent updates
- Open an issue on GitHub: https://github.com/Heretek-AI/heretek-openclaw/issues

---

🦞 *The thought that never ends.*
