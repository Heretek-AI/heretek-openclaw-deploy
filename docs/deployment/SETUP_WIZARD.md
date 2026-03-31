# Interactive Setup Wizard Guide

**Version:** 1.0.0  
**Last Updated:** 2026-03-31  
**OpenClaw Version:** v2026.3.28

This guide provides instructions for using the Heretek OpenClaw Interactive Setup Wizard.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Wizard Steps](#wizard-steps)
- [Configuration Files Generated](#configuration-files-generated)
- [Post-Setup Steps](#post-setup-steps)
- [Troubleshooting](#troubleshooting)
- [Manual Setup Alternative](#manual-setup-alternative)

---

## Overview

The Interactive Setup Wizard is a guided configuration tool for first-time Heretek OpenClaw users. It simplifies the setup process by:

- **Interactive Prompts:** Step-by-step configuration with clear explanations
- **API Key Validation:** Real-time validation of API key formats
- **Provider Selection:** Choose from OpenAI, Anthropic, Google, MiniMax, z.ai, or Ollama
- **Database Setup:** Configure PostgreSQL and/or Redis
- **Agent Configuration:** Select which agents to enable
- **Deployment Mode:** Docker or non-Docker deployment selection
- **Automatic Generation:** Creates `.env`, configuration files, and setup scripts

---

## Prerequisites

### Required Software

| Software | Minimum | Recommended | How to Install |
|----------|---------|-------------|----------------|
| **Node.js** | 18.x | 20.x LTS | `curl -fsSL https://deb.nodesource.com/setup_20.x \| sudo -E bash -` |
| **npm** | 9.x | Latest | Included with Node.js |
| **Git** | Any | Latest | `sudo apt-get install git` |

### Optional Software

| Software | Purpose | How to Install |
|----------|---------|----------------|
| **Docker** | Container deployment | `curl -fsSL https://get.docker.com \| bash` |
| **Docker Compose** | Multi-container orchestration | Included with Docker Desktop |

### Verify Prerequisites

```bash
# Check Node.js
node --version  # Should show v18.x or higher

# Check npm
npm --version   # Should show 9.x or higher

# Check Docker (optional)
docker --version
docker compose version
```

---

## Quick Start

### Run the Wizard

```bash
# From the project root directory
./scripts/setup-wizard.sh
```

### Alternative: Run Directly with Node.js

```bash
# Install dependencies first
npm install --ignore-scripts

# Run the wizard
node scripts/setup-wizard.js
```

### Command Line Options

```bash
# Show help
./scripts/setup-wizard.sh --help

# Check prerequisites only
./scripts/setup-wizard.sh --check

# Show manual setup instructions
./scripts/setup-wizard.sh --manual
```

---

## Wizard Steps

### Step 1: Welcome and Deployment Type

The wizard starts by checking prerequisites and asking for deployment type:

```
╔══════════════════════════════════════════════════════════╗
║  Heretek OpenClaw Setup Wizard                           ║
║  Interactive configuration for first-time users          ║
╚══════════════════════════════════════════════════════════╝

Checking prerequisites...
✓ Docker is installed
✓ Node.js v20.11.0 found

═══════════════════════════════════════════════════════
→ Step 1: Deployment Type
═══════════════════════════════════════════════════════

Choose your deployment type:

  1) Docker - Recommended for most users
     Includes PostgreSQL, Redis, Ollama, Langfuse containers
  2) Non-Docker - Manual infrastructure setup
     Requires existing database and services

Select deployment type: 1

✓ Deployment type: docker
```

### Step 2: AI Provider Selection

Select your primary and failover AI providers:

```
═══════════════════════════════════════════════════════
→ Step 2: AI Provider Selection
═══════════════════════════════════════════════════════

Select your primary AI provider:

  1) MiniMax - Primary LLM provider (recommended)
  2) z.ai - Failover LLM provider
  3) OpenAI - OpenAI GPT models
  4) Anthropic - Claude models
  5) Google - Gemini models
  6) Ollama - Local models (free)

Primary provider: 1

✓ Primary provider: MiniMax

Select a failover provider (used when primary is unavailable):

  0) Skip failover configuration
  1) z.ai - Failover LLM provider
  2) OpenAI - OpenAI GPT models
  ...

Failover provider: 2

✓ Failover provider: OpenAI
```

### Step 3: API Key Configuration

Enter API keys for selected providers:

```
═══════════════════════════════════════════════════════
→ Step 3: API Key Configuration
═══════════════════════════════════════════════════════

Enter your API keys for the selected providers.
Keys are stored locally in .env file and never transmitted.

MiniMax API Key: **********************
ℹ Validating minimax API key...
✓ minimax API key is valid

OpenAI API Key: **********************
ℹ Validating openai API key...
✓ openai API key is valid

Optional API Keys:
Add Anthropic API key? (y/N) n
Add Google API key? (y/N) n

Observability (Langfuse):
Enable Langfuse observability? (y/N) y
Langfuse Public Key: **********************
Langfuse Secret Key: **********************
✓ Langfuse configured
```

### Step 4: Database Configuration

Configure database settings:

```
═══════════════════════════════════════════════════════
→ Step 4: Database Configuration
═══════════════════════════════════════════════════════

Docker deployment includes PostgreSQL and Redis.
Configure database credentials:

Generated secure database password
Use custom database name? (openclaw) 

✓ Database configured: postgresql
```

### Step 5: Agent Configuration

Select which agents to enable:

```
═══════════════════════════════════════════════════════
→ Step 5: Agent Configuration
═══════════════════════════════════════════════════════

Configure which agents to enable:

  1) Enable all agents (recommended)
  2) Select specific agents

Agent configuration: 1

✓ All 11 agents enabled
```

### Step 6: Path Configuration

Configure OpenClaw workspace paths:

```
═══════════════════════════════════════════════════════
→ Step 6: Path Configuration
═══════════════════════════════════════════════════════

Configure OpenClaw workspace paths:

OpenClaw directory [/root/.openclaw] 

✓ OpenClaw directory: /root/.openclaw
✓ Agents workspace: /root/.openclaw/agents
```

### Step 7: Review Configuration

Review and confirm your configuration:

```
═══════════════════════════════════════════════════════
→ Step 7: Review Configuration
═══════════════════════════════════════════════════════

Please review your configuration:

Deployment:
  Type: docker

AI Providers:
  Primary: minimax
  Failover: openai

API Keys Configured:
  ☑ minimax
  ☑ openai

Database:
  Type: postgresql
  Host: localhost:5432
  Database: openclaw
  Redis: localhost:6379

Agents:
  All agents enabled

Paths:
  OpenClaw Dir: /root/.openclaw
  Workspace: /root/.openclaw/agents

Proceed with this configuration? (Y/n) y
```

---

## Configuration Files Generated

After completing the wizard, the following files are created:

### 1. `.env` - Environment Variables

```bash
# LiteLLM Gateway
LITELLM_MASTER_KEY=generated_secure_key
LITELLM_SALT_KEY=generated_secure_key

# AI Provider API Keys
MINIMAX_API_KEY=your_minimax_api_key
OPENAI_API_KEY=your_openai_api_key

# Database
POSTGRES_USER=openclaw
POSTGRES_PASSWORD=generated_secure_password
POSTGRES_DB=openclaw
DATABASE_URL=postgresql://openclaw:password@localhost:5432/openclaw

# Redis
REDIS_URL=redis://localhost:6379

# OpenClaw Gateway
OPENCLAW_DIR=/root/.openclaw
OPENCLAW_WORKSPACE=/root/.openclaw/agents

# Observability
LANGFUSE_ENABLED=true
LANGFUSE_PUBLIC_KEY=your_public_key
LANGFUSE_SECRET_KEY=your_secret_key
```

### 2. `docker-compose.override.yml` (Docker Mode)

Overrides default Docker Compose configuration with your settings.

### 3. `scripts/setup-openclaw.sh` (Non-Docker Mode)

Shell script to complete manual setup.

### 4. `~/.openclaw/openclaw.json`

OpenClaw Gateway configuration with selected agents.

---

## Post-Setup Steps

### For Docker Deployment

```bash
# 1. Start Docker services
docker compose up -d

# 2. Verify services
docker compose ps

# Expected output:
# NAME                      STATUS          PORTS
# heretek-litellm           Up (healthy)    0.0.0.0:4000->4000/tcp
# heretek-postgres          Up (healthy)    127.0.0.1:5432->5432/tcp
# heretek-redis             Up (healthy)    127.0.0.1:6379->6379/tcp
# heretek-ollama            Up              127.0.0.1:11434->11434/tcp

# 3. Install OpenClaw Gateway
curl -fsSL https://openclaw.ai/install.sh | bash

# 4. Verify installation
openclaw --version

# 5. Initialize daemon
openclaw onboard --install-daemon

# 6. Copy configuration
cp openclaw.json ~/.openclaw/openclaw.json

# 7. Create agent workspaces
./agents/deploy-agent.sh steward orchestrator
./agents/deploy-agent.sh alpha triad
# ... (repeat for all selected agents)

# 8. Verify Gateway status
openclaw gateway status
```

### For Non-Docker Deployment

```bash
# 1. Run the setup script
./scripts/setup-openclaw.sh

# 2. Start PostgreSQL and Redis services
sudo systemctl start postgresql
sudo systemctl start redis

# 3. Verify Gateway status
openclaw gateway status
```

---

## Troubleshooting

### Wizard Won't Start

**Symptom:** `./scripts/setup-wizard.sh: Permission denied`

**Solution:**
```bash
chmod +x scripts/setup-wizard.sh
./scripts/setup-wizard.sh
```

### Node.js Not Found

**Symptom:** `Node.js is not installed`

**Solution:**
```bash
# Install Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installation
node --version
npm --version
```

### Dependencies Not Installed

**Symptom:** `Cannot find module 'readline'`

**Solution:**
```bash
npm install --ignore-scripts
```

### Docker Compose Not Found

**Symptom:** `Docker Compose not found`

**Solution:**
```bash
# For Docker Desktop, Compose is included
# For Linux, install separately
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### API Key Validation Fails

**Symptom:** `Could not validate API key format`

**Solution:**
- The wizard will still accept the key for local setup
- Verify your API key is copied correctly (no extra spaces)
- Check with your provider that the key is active

### Configuration Files Not Created

**Symptom:** `.env` file not found after wizard completes

**Solution:**
```bash
# Check if wizard completed successfully
ls -la .env
ls -la ~/.openclaw/

# Re-run wizard if needed
./scripts/setup-wizard.sh
```

---

## Manual Setup Alternative

If you prefer not to use the wizard, follow the manual setup guide:

1. **Copy environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your configuration:**
   ```bash
   nano .env
   ```

3. **Install OpenClaw Gateway:**
   ```bash
   curl -fsSL https://openclaw.ai/install.sh | bash
   ```

4. **Initialize Gateway:**
   ```bash
   openclaw onboard --install-daemon
   ```

5. **Copy configuration:**
   ```bash
   cp openclaw.json ~/.openclaw/openclaw.json
   ```

6. **Create agent workspaces:**
   ```bash
   ./agents/deploy-agent.sh steward orchestrator
   ```

For detailed manual setup instructions, see [`LOCAL_DEPLOYMENT.md`](./LOCAL_DEPLOYMENT.md).

---

## Additional Resources

- **Local Deployment Guide:** [`LOCAL_DEPLOYMENT.md`](./LOCAL_DEPLOYMENT.md)
- **Configuration Reference:** [`../CONFIGURATION.md`](../CONFIGURATION.md)
- **Provider Setup:** [`../configuration/PROVIDER_SETUP.md`](../configuration/PROVIDER_SETUP.md)
- **Operations Guide:** [`../OPERATIONS.md`](../OPERATIONS.md)

---

🦞 *The thought that never ends.*
