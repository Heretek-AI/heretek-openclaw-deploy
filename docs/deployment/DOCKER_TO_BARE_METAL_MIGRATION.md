# Docker to Bare Metal Migration Guide

**Version:** 1.0.0  
**Last Updated:** 2026-03-31  
**OpenClaw Version:** v2026.3.28

This guide provides step-by-step instructions for migrating from a Docker-based OpenClaw deployment to a bare metal or VM installation.

---

## Table of Contents

1. [Overview](#overview)
2. [Pre-Migration Checklist](#pre-migration-checklist)
3. [Migration Planning](#migration-planning)
4. [Step 1: Backup Docker Deployment](#step-1-backup-docker-deployment)
5. [Step 2: Prepare Target System](#step-2-prepare-target-system)
6. [Step 3: Export Docker Data](#step-3-export-docker-data)
7. [Step 4: Install Bare Metal Dependencies](#step-4-install-bare-metal-dependencies)
8. [Step 5: Migrate PostgreSQL Data](#step-5-migrate-postgresql-data)
9. [Step 6: Migrate Redis Data](#step-6-migrate-redis-data)
10. [Step 7: Migrate Ollama Models](#step-7-migrate-ollama-models)
11. [Step 8: Configure LiteLLM](#step-8-configure-litellm)
12. [Step 9: Migrate OpenClaw Configuration](#step-9-migrate-openclaw-configuration)
13. [Step 10: Start and Verify Services](#step-10-start-and-verify-services)
14. [Rollback Procedures](#rollback-procedures)
15. [Post-Migration Tasks](#post-migration-tasks)

---

## Overview

### Why Migrate?

| Reason | Docker | Bare Metal |
|--------|--------|------------|
| **Performance** | Container overhead | Native performance |
| **GPU Access** | Passthrough complexity | Direct access |
| **Debugging** | Limited visibility | Full system access |
| **Compliance** | Container restrictions | Full control |
| **Cost** | Docker Enterprise licensing | No licensing costs |

### Migration Architecture Comparison

```
┌─────────────────────────────────────────────────────────────────┐
│                    Docker Deployment                            │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Docker Engine                                             │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │  │
│  │  │ LiteLLM  │  │PostgreSQL│  │  Redis   │  │  Ollama  │  │  │
│  │  │ Container│  │ Container│  │ Container│  │ Container│  │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                  Bare Metal Deployment                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │ LiteLLM  │  │PostgreSQL│  │  Redis   │  │  Ollama  │       │
│  │  System  │  │  System  │  │  System  │  │  System  │       │
│  │  Service │  │  Service │  │  Service │  │  Service │       │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

### Port Mapping

| Service | Docker Port | Bare Metal Port | Notes |
|---------|-------------|-----------------|-------|
| LiteLLM | 4000 | 4000 | Same |
| PostgreSQL | 5432 (internal) | 5432 (localhost) | Bind to localhost |
| Redis | 6379 (internal) | 6379 (localhost) | Bind to localhost |
| Ollama | 11434 (internal) | 11434 (localhost) | Bind to localhost |
| OpenClaw Gateway | 18789 | 18789 | Same |

---

## Pre-Migration Checklist

### Current State Assessment

```bash
# Verify Docker deployment is healthy
docker compose ps

# Check all services are running
docker compose ps | grep -E "Up|healthy"

# Document current configuration
docker compose config > docker-compose-config-backup.yaml

# List Docker volumes
docker volume ls

# Check disk usage
docker system df
```

### Required Information

| Item | Location | Example |
|------|----------|---------|
| Docker Compose file | `docker-compose.yml` | Current directory |
| Environment file | `.env` | Current directory |
| PostgreSQL password | `.env` or secrets | `POSTGRES_PASSWORD` |
| Redis password | `.env` or secrets | `REDIS_URL` |
| LiteLLM keys | `.env` | `LITELLM_MASTER_KEY` |
| Provider API keys | `.env` | `MINIMAX_API_KEY` |
| OpenClaw config | `~/.openclaw/openclaw.json` | Home directory |
| Agent workspaces | `~/.openclaw/agents/` | Home directory |

### Tools Required

```bash
# Install migration tools
sudo apt-get install -y \
    postgresql-client \
    redis-tools \
    jq \
    yq

# Or for RHEL
sudo dnf install -y \
    postgresql \
    redis-tools \
    jq \
    yq
```

---

## Migration Planning

### Downtime Estimation

| Phase | Estimated Time | Can Run While Docker Running? |
|-------|----------------|-------------------------------|
| Backup | 5-10 minutes | Yes |
| Target preparation | 30-60 minutes | Yes |
| Data export | 10-30 minutes | No (read-only recommended) |
| Data import | 10-30 minutes | No |
| Configuration | 15-30 minutes | No |
| Verification | 10-15 minutes | No |
| **Total** | **80-155 minutes** | **Partial** |

### Migration Window Planning

```bash
# Calculate migration window
# Recommended: Schedule during low-usage period
# Minimum: 2 hours downtime
# Recommended: 4 hours for first migration

# Notify stakeholders
# Example notification template:
cat << 'EOF'
Subject: Scheduled Maintenance - OpenClaw Migration

Dear Team,

We will be performing a planned migration of the OpenClaw system
from Docker to bare metal deployment.

Maintenance Window:
- Start: [DATE] at [TIME]
- Expected Duration: 2-4 hours
- Impact: OpenClaw services will be unavailable

Rollback Plan:
If issues occur, we will revert to the Docker deployment
within 30 minutes.

Contact: [YOUR_CONTACT]

EOF
```

---

## Step 1: Backup Docker Deployment

### Full System Backup

```bash
# Create backup directory
BACKUP_DIR="/tmp/openclaw-migration-$(date +%Y%m%d-%H%M%S)"
mkdir -p $BACKUP_DIR

# Backup Docker Compose configuration
cp docker-compose.yml $BACKUP_DIR/
cp .env $BACKUP_DIR/
cp .env.example $BACKUP_DIR/
cp litellm_config.yaml $BACKUP_DIR/
cp openclaw.json $BACKUP_DIR/

# Backup OpenClaw data
tar -czf $BACKUP_DIR/openclaw-data.tar.gz ~/.openclaw/

# Backup Docker volumes
docker run --rm \
    -v heretek-openclaw_postgres_data:/source:ro \
    -v $BACKUP_DIR:/backup \
    alpine tar -czf /backup/postgres-data.tar.gz -C /source .

docker run --rm \
    -v heretek-openclaw_redis_data:/source:ro \
    -v $BACKUP_DIR:/backup \
    alpine tar -czf /backup/redis-data.tar.gz -C /source .

docker run --rm \
    -v heretek-openclaw_ollama_data:/source:ro \
    -v $BACKUP_DIR:/backup \
    alpine tar -czf /backup/ollama-data.tar.gz -C /source .

# Verify backups
ls -lah $BACKUP_DIR/
echo "Backup completed: $BACKUP_DIR"
```

### Database Backup

```bash
# Export PostgreSQL database
docker compose exec -T postgres pg_dump -U openclaw openclaw > $BACKUP_DIR/openclaw-database.sql

# Verify SQL dump
wc -l $BACKUP_DIR/openclaw-database.sql
head -20 $BACKUP_DIR/openclaw-database.sql
```

### Redis Backup

```bash
# Trigger Redis BGSAVE
docker compose exec redis redis-cli BGSAVE

# Wait for save to complete
sleep 5

# Export Redis data
docker cp heretek-redis:/data/dump.rdb $BACKUP_DIR/dump.rdb

# Verify RDB file
ls -lah $BACKUP_DIR/dump.rdb
```

---

## Step 2: Prepare Target System

### System Requirements Check

```bash
# Check OS version
cat /etc/os-release

# Check available disk space
df -h /

# Check available memory
free -h

# Check CPU cores
nproc

# Check GPU (if applicable)
lspci | grep -i vga
```

### Install Prerequisites

```bash
# For Ubuntu/Debian
curl -fsSL https://raw.githubusercontent.com/Heretek-AI/heretek-openclaw/main/scripts/install/ubuntu-deps.sh -o ubuntu-deps.sh
chmod +x ubuntu-deps.sh
sudo ./ubuntu-deps.sh

# For RHEL/CentOS
curl -fsSL https://raw.githubusercontent.com/Heretek-AI/heretek-openclaw/main/scripts/install/rhel-deps.sh -o rhel-deps.sh
chmod +x rhel-deps.sh
sudo ./rhel-deps.sh
```

### Create Required Users and Directories

```bash
# Create litellm user
sudo useradd -r -s /bin/false litellm
sudo mkdir -p /opt/litellm
sudo chown litellm:litellm /opt/litellm

# Create OpenClaw directories
sudo mkdir -p /etc/litellm
sudo mkdir -p /etc/openclaw
sudo mkdir -p /var/log/openclaw

# Set permissions
sudo chmod 755 /etc/litellm
sudo chmod 755 /etc/openclaw
sudo chmod 755 /var/log/openclaw
```

---

## Step 3: Export Docker Data

### Export PostgreSQL Data

```bash
# Export full database with schema
docker compose exec -T postgres pg_dumpall -U openclaw > $BACKUP_DIR/full-export.sql

# Export specific database
docker compose exec -T postgres pg_dump -U openclaw -Fc openclaw > $BACKUP_DIR/openclaw.custom

# Export schema only (for reference)
docker compose exec -T postgres pg_dump -U openclaw --schema-only openclaw > $BACKUP_DIR/schema.sql

# Export data only
docker compose exec -T postgres pg_dump -U openclaw --data-only openclaw > $BACKUP_DIR/data.sql

# Verify exports
ls -lah $BACKUP_DIR/*.sql $BACKUP_DIR/*.custom
```

### Export Redis Data

```bash
# Export Redis data in different formats
docker compose exec redis redis-cli --rdb /data/dump.rdb
docker cp heretek-redis:/data/dump.rdb $BACKUP_DIR/

# Export as RDB
docker compose exec redis redis-cli SAVE
docker cp heretek-redis:/data/dump.rdb $BACKUP_DIR/redis-dump.rdb

# Export specific keys (optional)
docker compose exec redis redis-cli KEYS '*' > $BACKUP_DIR/redis-keys.txt
```

### Export Ollama Models

```bash
# List Ollama models
docker compose exec ollama ollama list

# Export model files
docker run --rm \
    -v heretek-openclaw_ollama_data:/ollama:ro \
    -v $BACKUP_DIR:/backup \
    alpine tar -czf /backup/ollama-models.tar.gz -C /ollama .

# Alternative: Pull models on target system
# (Recommended for large models)
docker compose exec ollama ollama list --format json > $BACKUP_DIR/ollama-models.json
```

---

## Step 4: Install Bare Metal Dependencies

### Install PostgreSQL

```bash
# Ubuntu/Debian
sudo apt-get install -y postgresql-15 postgresql-contrib-15 postgresql-15-pgvector

# RHEL/CentOS
sudo dnf install -y postgresql15 postgresql15-contrib postgresql15-pgvector

# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

### Install Redis

```bash
# Ubuntu/Debian
sudo apt-get install -y redis

# RHEL/CentOS
sudo dnf install -y redis

# Start Redis
sudo systemctl start redis
sudo systemctl enable redis
```

### Install Ollama

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Configure Ollama (see BARE_METAL_DEPLOYMENT.md for GPU setup)
sudo systemctl start ollama
sudo systemctl enable ollama
```

### Install LiteLLM

```bash
# Create virtual environment
sudo -u litellm python3 -m venv /opt/litellm/venv

# Install LiteLLM
sudo -u litellm /opt/litellm/venv/bin/pip install \
    'litellm[proxy]' \
    'litellm[langfuse]' \
    'litellm[postgres]' \
    'litellm[redis]' \
    psycopg2-binary \
    redis \
    langfuse
```

### Install OpenClaw Gateway

```bash
# Install OpenClaw
curl -fsSL https://openclaw.ai/install.sh | bash

# Verify installation
openclaw --version
```

---

## Step 5: Migrate PostgreSQL Data

### Create Database and User

```bash
# Connect to PostgreSQL
sudo -u postgres psql
```

```sql
-- Create database and user
CREATE DATABASE openclaw;
CREATE USER openclaw WITH PASSWORD 'your-secure-password';
GRANT ALL PRIVILEGES ON DATABASE openclaw TO openclaw;

-- Enable pgvector extension
\c openclaw
CREATE EXTENSION IF NOT EXISTS vector;

-- Verify
\dx
\q
```

### Import Data

```bash
# Import SQL dump
psql -U openclaw -d openclaw -f $BACKUP_DIR/openclaw-database.sql

# Or import custom format
pg_restore -U openclaw -d openclaw $BACKUP_DIR/openclaw.custom

# Or import full export
psql -U openclaw -d openclaw -f $BACKUP_DIR/full-export.sql

# Verify import
psql -U openclaw -d openclaw -c "SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public';"
psql -U openclaw -d openclaw -c "\dt"
```

### Update Connection Strings

```bash
# The DATABASE_URL needs to change from Docker to localhost
# Docker: postgresql://openclaw:password@postgres:5432/openclaw
# Bare Metal: postgresql://openclaw:password@localhost:5432/openclaw

# Update environment file
sed -i 's/@postgres:5432/@localhost:5432/g' $BACKUP_DIR/.env
```

---

## Step 6: Migrate Redis Data

### Stop Redis Service

```bash
# Stop Redis temporarily
sudo systemctl stop redis
```

### Import RDB File

```bash
# Copy RDB file to Redis data directory
sudo cp $BACKUP_DIR/dump.rdb /var/lib/redis/dump.rdb

# Set correct ownership
sudo chown redis:redis /var/lib/redis/dump.rdb
sudo chmod 640 /var/lib/redis/dump.rdb
```

### Start Redis Service

```bash
# Start Redis
sudo systemctl start redis

# Verify data loaded
redis-cli -a your-redis-password KEYS '*' | head -20
```

### Update Redis URL

```bash
# Update REDIS_URL in environment file
# Docker: redis://redis:6379/0
# Bare Metal: redis://:password@localhost:6379/0

sed -i 's|redis://redis:6379|redis://:your-redis-password@localhost:6379|g' $BACKUP_DIR/.env
```

---

## Step 7: Migrate Ollama Models

### Option 1: Restore from Backup

```bash
# Stop Ollama
sudo systemctl stop ollama

# Restore model data
sudo tar -xzf $BACKUP_DIR/ollama-models.tar.gz -C /var/lib/ollama/

# Set permissions
sudo chown -R ollama:ollama /var/lib/ollama

# Start Ollama
sudo systemctl start ollama

# Verify models
ollama list
```

### Option 2: Re-pull Models (Recommended)

```bash
# Get list of models from backup
cat $BACKUP_DIR/ollama-models.json | jq -r '.[].name' > $BACKUP_DIR/model-list.txt

# Pull each model
while read model; do
    echo "Pulling $model..."
    ollama pull $model
done < $BACKUP_DIR/model-list.txt

# Verify models
ollama list
```

---

## Step 8: Configure LiteLLM

### Copy Configuration

```bash
# Copy LiteLLM configuration
sudo cp $BACKUP_DIR/litellm_config.yaml /etc/litellm/litellm_config.yaml
sudo chown litellm:litellm /etc/litellm/litellm_config.yaml
```

### Update Configuration for Bare Metal

```bash
# Update database connection in litellm_config.yaml
# Change postgres host from 'postgres' to 'localhost'

# Update Redis connection
# Change redis host from 'redis' to 'localhost'

# Or use environment variables (recommended)
# The systemd service will set these
```

### Create Environment File

```bash
# Copy environment template
cp $BACKUP_DIR/.env /etc/openclaw/.env

# Update for bare metal
sed -i 's/@postgres:5432/@localhost:5432/g' /etc/openclaw/.env
sed -i 's|redis://redis:6379|redis://localhost:6379|g' /etc/openclaw/.env
sed -i 's|OLLAMA_HOST=http://ollama:11434|OLLAMA_HOST=http://localhost:11434|g' /etc/openclaw/.env

# Set permissions
sudo chmod 600 /etc/openclaw/.env
sudo chown root:root /etc/openclaw/.env
```

---

## Step 9: Migrate OpenClaw Configuration

### Restore OpenClaw Data

```bash
# Extract OpenClaw data
tar -xzf $BACKUP_DIR/openclaw-data.tar.gz -C ~/

# Verify extraction
ls -la ~/.openclaw/
ls -la ~/.openclaw/agents/
```

### Validate Configuration

```bash
# Validate openclaw.json
openclaw gateway validate

# Check agent workspaces
for agent in steward alpha beta charlie examiner explorer sentinel coder dreamer empath historian; do
    echo "=== $agent ==="
    ls -la ~/.openclaw/agents/$agent/
done
```

### Update Configuration Paths

```bash
# If paths need to be updated, edit openclaw.json
nano ~/.openclaw/openclaw.json

# Common path changes:
# - Database URLs
# - File paths
# - API endpoints
```

---

## Step 10: Start and Verify Services

### Start Services in Order

```bash
# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl status postgresql

# Start Redis
sudo systemctl start redis
sudo systemctl status redis

# Start Ollama
sudo systemctl start ollama
sudo systemctl status ollama

# Start LiteLLM
sudo systemctl start litellm
sudo systemctl status litellm

# Start OpenClaw Gateway
sudo systemctl start openclaw-gateway
sudo systemctl status openclaw-gateway
```

### Verify Services

```bash
# Check PostgreSQL
psql -U openclaw -d openclaw -c "SELECT version();"

# Check Redis
redis-cli -a your-redis-password ping

# Check Ollama
curl http://localhost:11434/api/tags

# Check LiteLLM
curl http://localhost:4000/health

# Check OpenClaw Gateway
openclaw gateway status
```

### Run Health Checks

```bash
# Run comprehensive health check
cd /root/heretek/heretek-openclaw
./scripts/health-check.sh

# Or individual checks
curl http://localhost:4000/v1/models
openclaw agent status steward
```

---

## Rollback Procedures

### Quick Rollback to Docker

If the bare metal deployment fails, you can quickly rollback to Docker:

```bash
# Stop bare metal services
sudo systemctl stop openclaw-gateway
sudo systemctl stop litellm
sudo systemctl stop ollama

# Return to project directory
cd /root/heretek/heretek-openclaw

# Start Docker deployment
docker compose up -d

# Verify Docker services
docker compose ps
```

### Rollback Decision Tree

```
┌─────────────────────────────────────────────────────────────┐
│              Rollback Decision Tree                         │
├─────────────────────────────────────────────────────────────┤
│ Issue Type                    │ Action                      │
├───────────────────────────────┼─────────────────────────────┤
│ PostgreSQL migration failed   │ Restore from SQL dump       │
│ Redis data corrupted          │ Restore RDB file            │
│ Ollama models missing         │ Re-pull models              │
│ LiteLLM won't start           │ Check logs, restore config  │
│ OpenClaw agents not loading   │ Validate openclaw.json      │
│ Critical failure              │ Full Docker rollback        │
└────��────────────────────────────────────────────────────────┘
```

### Rollback Script

```bash
#!/bin/bash
# rollback-to-docker.sh

echo "Starting rollback to Docker deployment..."

# Stop bare metal services
sudo systemctl stop openclaw-gateway litellm ollama redis postgresql

# Start Docker
cd /root/heretek/heretek-openclaw
docker compose up -d

# Wait for services
sleep 30

# Verify
docker compose ps

echo "Rollback complete. Verify services with: docker compose ps"
```

---

## Post-Migration Tasks

### Update Documentation

```bash
# Document the migration
cat << EOF >> /var/log/openclaw/migration-log.txt
Migration Date: $(date)
From: Docker Deployment
To: Bare Metal Deployment
Duration: [TIME]
Issues: [LIST ANY ISSUES]
Resolution: [LIST RESOLUTIONS]
Verified By: [NAME]
EOF
```

### Configure Monitoring

```bash
# Enable systemd service monitoring
sudo systemctl enable --now openclaw-gateway
sudo systemctl enable --now litellm

# Configure log rotation
sudo nano /etc/logrotate.d/openclaw
```

```
/var/log/openclaw/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
}
```

### Update Backup Procedures

```bash
# Update backup scripts to use system paths
# See BARE_METAL_DEPLOYMENT.md for backup configuration

# Test backup restoration
# Restore from new backup to verify process
```

### Performance Validation

```bash
# Compare performance metrics
# Docker vs Bare Metal

# Response time
time curl -s http://localhost:4000/health

# Database query time
psql -U openclaw -d openclaw -c "\timing" -c "SELECT COUNT(*) FROM pg_tables;"

# Redis latency
redis-cli -a your-redis-password --latency
```

### Security Validation

```bash
# Verify firewall rules
sudo ufw status  # Ubuntu
sudo firewall-cmd --list-all  # RHEL

# Verify service isolation
netstat -tlnp | grep -E '5432|6379|11434|4000|18789'

# Verify SSL/TLS (if configured)
openssl s_client -connect localhost:4000 -servername localhost
```

---

## Troubleshooting

### Common Migration Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| PostgreSQL connection refused | Wrong host in connection string | Change `postgres` to `localhost` |
| Redis authentication failed | Password not set in bare metal | Add password to redis.conf |
| Ollama models not found | Models not migrated | Re-pull models or restore backup |
| LiteLLM health check fails | Database/Redis connection | Verify environment variables |
| OpenClaw agents missing | Workspace paths incorrect | Check ~/.openclaw/agents/ |

### Migration Logs

```bash
# Check service logs
journalctl -u postgresql -f
journalctl -u redis -f
journalctl -u ollama -f
journalctl -u litellm -f
journalctl -u openclaw-gateway -f

# Check migration log
cat /var/log/openclaw/migration-log.txt
```

---

## Support

For issues or questions:
- Check [`BARE_METAL_DEPLOYMENT.md`](./BARE_METAL_DEPLOYMENT.md)
- Check [`NON_DOCKER_TROUBLESHOOTING.md`](./NON_DOCKER_TROUBLESHOOTING.md)
- Open an issue on GitHub: https://github.com/Heretek-AI/heretek-openclaw/issues

---

🦞 *The thought that never ends.*
