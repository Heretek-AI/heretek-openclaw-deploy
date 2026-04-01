# Bare Metal Deployment Guide

**Version:** 1.0.0  
**Last Updated:** 2026-03-31  
**OpenClaw Version:** v2026.3.28

This guide provides comprehensive instructions for deploying the Heretek OpenClaw stack on bare metal Linux servers without Docker containerization.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [System Requirements](#system-requirements)
3. [Installation Overview](#installation-overview)
4. [Step 1: Install System Dependencies](#step-1-install-system-dependencies)
5. [Step 2: Install and Configure PostgreSQL](#step-2-install-and-configure-postgresql)
6. [Step 3: Install and Configure Redis](#step-3-install-and-configure-redis)
7. [Step 4: Install and Configure Ollama](#step-4-install-and-configure-ollama)
8. [Step 5: Install LiteLLM](#step-5-install-litellm)
9. [Step 6: Install OpenClaw Gateway](#step-6-install-openclaw-gateway)
10. [Step 7: Configure Environment Variables](#step-7-configure-environment-variables)
11. [Step 8: Initialize Database](#step-8-initialize-database)
12. [Step 9: Configure Systemd Services](#step-9-configure-systemd-services)
13. [Step 10: Verify Installation](#step-10-verify-installation)
14. [Post-Deployment Configuration](#post-deployment-configuration)
15. [Security Hardening](#security-hardening)

---

## Prerequisites

### Required Knowledge

- Basic Linux system administration
- Familiarity with systemd service management
- Understanding of PostgreSQL and Redis
- Node.js and npm package management
- Python virtual environments

### Required API Keys

| Provider | Purpose | Get Key |
|----------|---------|---------|
| **MiniMax** | Primary LLM | https://platform.minimaxi.com |
| **z.ai** | Failover LLM | https://platform.z.ai |
| **(Optional) Langfuse** | Observability | https://cloud.langfuse.com |

---

## System Requirements

### Minimum Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **OS** | Ubuntu 20.04 / RHEL 8 | Ubuntu 22.04 LTS / RHEL 9 |
| **CPU** | 4 cores | 8+ cores |
| **RAM** | 8 GB | 16+ GB |
| **Disk** | 20 GB SSD | 50+ GB NVMe SSD |
| **Network** | 100 Mbps | 1 Gbps |

### GPU Requirements (Optional)

| GPU Type | Requirements | Notes |
|----------|--------------|-------|
| **AMD ROCm** | RX 6000/7000 series, MI50/MI100 | ROCm 5.6+ required |
| **NVIDIA CUDA** | RTX 3000/4000 series, A100/H100 | CUDA 11.8+, cuDNN 8.6+ |

---

## Installation Overview

The bare metal installation involves the following components:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Heretek OpenClaw Stack                        │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    Core Services                           │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────┐ │  │
│  │  │ LiteLLM  │  │PostgreSQL│  │  Redis   │  │  Ollama   │ │  │
│  │  │  :4000   │  │  :5432   │  │  :6379   │  │ :11434    │ │  │
│  │  │  Python  │  │ +pgvector│  │  Cache   │  │ Local LLM │ │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └───────────┘ │  │
│  └───────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              OpenClaw Gateway (Port 18789)                 │  │
│  │  All 12 agents run as workspaces within Gateway process    │  │
│  │  Agent workspaces: ~/.openclaw/agents/{agent}/             │  │
│  └───────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    Web Interface                           │  │
│  │  ┌────────────────────────────────────────────────────┐   │  │
│  │  │              Web Dashboard (:3000)                 │   │  │
│  │  │  SvelteKit • TypeScript • TailwindCSS • WebSocket  │   │  │
│  │  └────────────────────────────────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Default Ports

| Service | Port | Protocol |
|---------|------|----------|
| LiteLLM Gateway | 4000 | HTTP |
| PostgreSQL | 5432 | TCP |
| Redis | 6379 | TCP |
| Ollama | 11434 | HTTP |
| OpenClaw Gateway | 18789 | WebSocket |
| Web Dashboard | 3000 | HTTP |

---

## Step 1: Install System Dependencies

### Ubuntu/Debian

```bash
# Update system packages
sudo apt-get update && sudo apt-get upgrade -y

# Install core dependencies
sudo apt-get install -y \
    curl \
    git \
    wget \
    gnupg \
    ca-certificates \
    software-properties-common \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3-dev \
    python3-pip \
    python3-venv \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libxml2-dev \
    libxmlsec1-dev \
    liblzma-dev

# Install Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installations
node --version  # Should be v20.x
npm --version   # Should be 10.x
python3 --version  # Should be 3.10+
```

### RHEL/CentOS/Rocky Linux

```bash
# Update system packages
sudo dnf update -y

# Install EPEL repository
sudo dnf install -y epel-release

# Install core dependencies
sudo dnf install -y \
    curl \
    git \
    wget \
    gnupg2 \
    ca-certificates \
    gcc \
    gcc-c++ \
    make \
    openssl-devel \
    libffi-devel \
    python3-devel \
    python3-pip \
    bzip2-devel \
    readline-devel \
    sqlite-devel \
    ncurses-devel \
    xz-devel \
    tk-devel \
    libxml2-devel \
    libxmlsec1-devel \
    zlib-devel

# Install Node.js 20 LTS
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo -E bash -
sudo dnf install -y nodejs

# Verify installations
node --version  # Should be v20.x
npm --version   # Should be 10.x
python3 --version  # Should be 3.10+
```

---

## Step 2: Install and Configure PostgreSQL

### Install PostgreSQL 15+

#### Ubuntu/Debian

```bash
# Add PostgreSQL repository
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

# Install PostgreSQL 15
sudo apt-get update
sudo apt-get install -y postgresql-15 postgresql-contrib-15 postgresql-15-pgvector

# Start and enable PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

#### RHEL/CentOS

```bash
# Add PostgreSQL repository
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# Disable default PostgreSQL module
sudo dnf -qy module disable postgresql

# Install PostgreSQL 15
sudo dnf install -y postgresql15 postgresql15-contrib postgresql15-pgvector

# Start and enable PostgreSQL
sudo systemctl start postgresql-15
sudo systemctl enable postgresql-15
```

### Configure PostgreSQL

```bash
# Switch to postgres user
sudo -u postgres psql
```

```sql
-- Create OpenClaw database and user
CREATE DATABASE openclaw;
CREATE USER openclaw WITH PASSWORD 'generate-secure-password-here';
GRANT ALL PRIVILEGES ON DATABASE openclaw TO openclaw;

-- Enable pgvector extension
\c openclaw
CREATE EXTENSION IF NOT EXISTS vector;

-- Verify extension
SELECT * FROM pg_extension WHERE extname = 'vector';

-- Exit psql
\q
```

### Configure PostgreSQL for Remote Access (Optional)

```bash
# Edit PostgreSQL configuration
sudo nano /etc/postgresql/15/main/postgresql.conf
```

```ini
# postgresql.conf
listen_addresses = 'localhost'  # Change to '*' for remote access
max_connections = 100
shared_buffers = 256MB
work_mem = 8MB
```

```bash
# Edit pg_hba.conf for authentication
sudo nano /etc/postgresql/15/main/pg_hba.conf
```

```ini
# pg_hba.conf
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     peer
host    openclaw        openclaw        127.0.0.1/32            scram-sha-256
host    openclaw        openclaw        ::1/128                 scram-sha-256
```

```bash
# Restart PostgreSQL
sudo systemctl restart postgresql
```

---

## Step 3: Install and Configure Redis

### Install Redis 7+

#### Ubuntu/Debian

```bash
# Add Redis repository
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list

# Install Redis
sudo apt-get update
sudo apt-get install -y redis

# Start and enable Redis
sudo systemctl start redis
sudo systemctl enable redis
```

#### RHEL/CentOS

```bash
# Install Redis from Remi repository
sudo dnf install -y dnf-utils
sudo dnf config-manager --set-enabled powertools
sudo dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm
sudo dnf module reset redis -y
sudo dnf module enable redis:7 -y
sudo dnf install -y redis

# Start and enable Redis
sudo systemctl start redis
sudo systemctl enable redis
```

### Configure Redis

```bash
# Edit Redis configuration
sudo nano /etc/redis/redis.conf
```

```ini
# redis.conf
bind 127.0.0.1
port 6379
protected-mode yes
requirepass generate-secure-redis-password-here
maxmemory 256mb
maxmemory-policy allkeys-lru
appendonly yes
appendfsync everysec
```

```bash
# Restart Redis
sudo systemctl restart redis

# Verify Redis
redis-cli -a your-redis-password ping  # Should return PONG
```

---

## Step 4: Install and Configure Ollama

### Install Ollama

```bash
# Install Ollama (official installer)
curl -fsSL https://ollama.ai/install.sh | sh

# Start and enable Ollama
sudo systemctl start ollama
sudo systemctl enable ollama
```

### Configure Ollama for GPU

#### AMD ROCm

```bash
# Create systemd override for ROCm
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo nano /etc/systemd/system/ollama.service.d/rocm.conf
```

```ini
# rocm.conf
[Service]
Environment="HSA_OVERRIDE_GFX_VERSION=10.3.0"
Environment="OLLAMA_HOST=0.0.0.0:11434"
DevicePolicy=closed
DeviceAllow=/dev/kfd rw
DeviceAllow=/dev/dri rw
```

#### NVIDIA CUDA

```bash
# Create systemd override for CUDA
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo nano /etc/systemd/system/ollama.service.d/cuda.conf
```

```ini
# cuda.conf
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="PATH=/usr/bin:/usr/local/cuda/bin"
Environment="LD_LIBRARY_PATH=/usr/local/cuda/lib64"
DevicePolicy=closed
DeviceAllow=/dev/nvidia0 rw
DeviceAllow=/dev/nvidiactl rw
DeviceAllow=/dev/nvidia-uvm rw
```

### Pull Embedding Models

```bash
# Pull embedding model
ollama pull nomic-embed-text-v2-moe

# Verify model
ollama list

# Test Ollama
curl http://localhost:11434/api/tags
```

---

## Step 5: Install LiteLLM

### Create Python Virtual Environment

```bash
# Create LiteLLM user
sudo useradd -r -s /bin/false litellm
sudo mkdir -p /opt/litellm
sudo chown litellm:litellm /opt/litellm

# Create virtual environment
sudo -u litellm python3 -m venv /opt/litellm/venv
sudo -u litellm /opt/litellm/venv/bin/pip install --upgrade pip
```

### Install LiteLLM

```bash
# Install LiteLLM with dependencies
sudo -u litellm /opt/litellm/venv/bin/pip install \
    'litellm[proxy]' \
    'litellm[langfuse]' \
    'litellm[postgres]' \
    'litellm[redis]' \
    psycopg2-binary \
    redis \
    langfuse
```

### Configure LiteLLM

```bash
# Create LiteLLM config directory
sudo mkdir -p /etc/litellm
sudo cp litellm_config.yaml /etc/litellm/litellm_config.yaml
sudo chown litellm:litellm /etc/litellm/litellm_config.yaml
```

---

## Step 6: Install OpenClaw Gateway

### Install OpenClaw

```bash
# Install OpenClaw Gateway
curl -fsSL https://openclaw.ai/install.sh | bash

# Verify installation
openclaw --version

# Initialize daemon
openclaw onboard --install-daemon

# Verify Gateway status
openclaw gateway status
```

### Configure OpenClaw

```bash
# Copy Gateway configuration
cp openclaw.json ~/.openclaw/openclaw.json

# Validate configuration
openclaw gateway validate

# Restart Gateway
openclaw gateway restart
```

---

## Step 7: Configure Environment Variables

### Create Environment File

```bash
# Copy environment template
cp .env.bare-metal.example .env

# Edit with your values
nano .env
```

### Required Environment Variables

See [`.env.bare-metal.example`](../../.env.bare-metal.example) for the complete template.

Key variables to configure:

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
DATABASE_URL=postgresql://openclaw:your_password@localhost:5432/openclaw

# Redis
REDIS_URL=redis://:your-redis-password@localhost:6379/0

# Ollama
OLLAMA_HOST=http://localhost:11434

# OpenClaw Gateway
OPENCLAW_DIR=/root/.openclaw
OPENCLAW_WORKSPACE=/root/.openclaw/agents
```

---

## Step 8: Initialize Database

### Run Database Migrations

```bash
# Activate LiteLLM virtual environment
source /opt/litellm/venv/bin/activate

# Run OpenClaw database migrations
cd /root/heretek/heretek-openclaw
npm run db:migrate

# Verify database tables
psql -U openclaw -d openclaw -c "\dt"
```

### Initialize LiteLLM Database

```bash
# LiteLLM will auto-create tables on first run
# Verify tables after starting LiteLLM
psql -U openclaw -d openclaw -c "\dt litellm*"
```

---

## Step 9: Configure Systemd Services

### Install Systemd Service Files

```bash
# Copy service files
sudo cp systemd/openclaw-gateway.service /etc/systemd/system/
sudo cp systemd/litellm.service /etc/systemd/system/
sudo cp systemd/ollama.service /etc/systemd/system/
sudo cp systemd/redis.service /etc/systemd/system/
sudo cp systemd/postgresql.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload
```

### Enable and Start Services

```bash
# Start services in order
sudo systemctl start postgresql
sudo systemctl start redis
sudo systemctl start ollama
sudo systemctl start litellm
sudo systemctl start openclaw-gateway

# Enable auto-start on boot
sudo systemctl enable postgresql
sudo systemctl enable redis
sudo systemctl enable ollama
sudo systemctl enable litellm
sudo systemctl enable openclaw-gateway

# Verify services
sudo systemctl status postgresql
sudo systemctl status redis
sudo systemctl status ollama
sudo systemctl status litellm
sudo systemctl status openclaw-gateway
```

---

## Step 10: Verify Installation

### Health Checks

```bash
# Check PostgreSQL
curl -f http://localhost:5432 || psql -U openclaw -d openclaw -c "SELECT version();"

# Check Redis
redis-cli -a your-redis-password ping

# Check Ollama
curl http://localhost:11434/api/tags

# Check LiteLLM
curl http://localhost:4000/health

# Check OpenClaw Gateway
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

## Post-Deployment Configuration

### Create Agent Workspaces

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

### Install Plugins & Skills

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

# Install skills
cd ../../skills/triad-consensus
openclaw skills install ./SKILL.md
```

### Configure LiteLLM

```bash
# Copy LiteLLM configuration
sudo cp /root/heretek/heretek-openclaw/litellm_config.yaml /etc/litellm/litellm_config.yaml

# Restart LiteLLM
sudo systemctl restart litellm

# Verify endpoints
curl http://localhost:4000/v1/models
```

---

## Security Hardening

### Firewall Configuration

#### UFW (Ubuntu)

```bash
# Enable UFW
sudo ufw enable

# Allow SSH
sudo ufw allow ssh

# Allow only localhost for internal services
sudo ufw allow from 127.0.0.1 to any port 5432  # PostgreSQL
sudo ufw allow from 127.0.0.1 to any port 6379  # Redis
sudo ufw allow from 127.0.0.1 to any port 11434 # Ollama

# Allow public access to LiteLLM and OpenClaw
sudo ufw allow 4000/tcp  # LiteLLM
sudo ufw allow 18789/tcp # OpenClaw Gateway

# Check status
sudo ufw status verbose
```

#### firewalld (RHEL)

```bash
# Enable firewalld
sudo systemctl start firewalld
sudo systemctl enable firewalld

# Allow SSH
sudo firewall-cmd --permanent --add-service=ssh

# Allow only localhost for internal services
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="127.0.0.1" port port="5432" protocol="tcp" accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="127.0.0.1" port port="6379" protocol="tcp" accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="127.0.0.1" port port="11434" protocol="tcp" accept'

# Allow public access
sudo firewall-cmd --permanent --add-port=4000/tcp
sudo firewall-cmd --permanent --add-port=18789/tcp

# Reload firewall
sudo firewall-cmd --reload
```

### SSL/TLS Configuration

For production deployments, configure SSL/TLS for LiteLLM and OpenClaw Gateway using nginx or Apache as a reverse proxy.

### API Key Management

```bash
# Generate secure keys
openssl rand -hex 32  # For LITELLM_MASTER_KEY
openssl rand -hex 32  # For LITELLM_SALT_KEY

# Store keys securely
sudo mkdir -p /etc/openclaw/secrets
sudo chmod 700 /etc/openclaw/secrets
```

---

## Troubleshooting

See [`NON_DOCKER_TROUBLESHOOTING.md`](./NON_DOCKER_TROUBLESHOOTING.md) for detailed troubleshooting guide.

### Common Issues

| Issue | Solution |
|-------|----------|
| PostgreSQL won't start | Check logs: `journalctl -u postgresql -f` |
| Redis connection refused | Verify password in redis.conf |
| Ollama GPU not detected | Check ROCm/CUDA installation |
| LiteLLM health check fails | Verify DATABASE_URL and REDIS_URL |
| OpenClaw Gateway not running | Check workspace permissions |

---

## Backup Configuration

```bash
# Backup OpenClaw configuration
tar -czf openclaw-backup-$(date +%Y%m%d).tar.gz \
  ~/.openclaw/openclaw.json \
  ~/.openclaw/agents/ \
  /etc/litellm/litellm_config.yaml \
  /etc/openclaw/.env

# Backup PostgreSQL
pg_dump -U openclaw openclaw > openclaw-db-$(date +%Y%m%d).sql

# Backup is stored in current directory
ls -la openclaw-backup-*.tar.gz openclaw-db-*.sql
```

---

## Next Steps

After successful deployment:

1. **Access LiteLLM Dashboard** - http://localhost:4000/ui
2. **Test Agent Communication** - Send messages via Gateway WebSocket RPC
3. **Configure User Profiles** - Set up user rolodex
4. **Enable Autonomous Operations** - Activate dreamer agent
5. **Review Documentation** - See [`docs/`](../../docs/) for advanced configuration

---

## Support

For issues or questions:
- Check [`NON_DOCKER_TROUBLESHOOTING.md`](./NON_DOCKER_TROUBLESHOOTING.md)
- Review [`CHANGELOG.md`](../../CHANGELOG.md)
- Open an issue on GitHub: https://github.com/Heretek-AI/heretek-openclaw/issues

---

🦞 *The thought that never ends.*
