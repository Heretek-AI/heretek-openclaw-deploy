# Non-Docker Troubleshooting Guide

**Version:** 1.0.0  
**Last Updated:** 2026-03-31  
**OpenClaw Version:** v2026.3.28

This guide provides comprehensive troubleshooting procedures for bare metal and VM deployments of the Heretek OpenClaw stack.

---

## Table of Contents

1. [Diagnostic Tools](#diagnostic-tools)
2. [Service Status Commands](#service-status-commands)
3. [PostgreSQL Issues](#postgresql-issues)
4. [Redis Issues](#redis-issues)
5. [Ollama Issues](#ollama-issues)
6. [LiteLLM Issues](#litellm-issues)
7. [OpenClaw Gateway Issues](#openclaw-gateway-issues)
8. [Network Issues](#network-issues)
9. [GPU Issues](#gpu-issues)
10. [Performance Issues](#performance-issues)
11. [Log Analysis](#log-analysis)
12. [Common Error Messages](#common-error-messages)

---

## Diagnostic Tools

### System Health Check Script

```bash
#!/bin/bash
# quick-health-check.sh

echo "=== System Health Check ==="
echo "Date: $(date)"
echo ""

# System resources
echo "=== System Resources ==="
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')%"
echo "Memory Usage: $(free | awk '/Mem/ {printf "%.2f%%", $3/$2 * 100}')"
echo "Disk Usage: $(df -h / | awk 'NR==2 {print $5}')"
echo ""

# Service status
echo "=== Service Status ==="
for service in postgresql redis ollama litellm openclaw-gateway; do
    status=$(systemctl is-active $service 2>/dev/null || echo "not installed")
    echo "$service: $status"
done
echo ""

# Port check
echo "=== Listening Ports ==="
netstat -tlnp 2>/dev/null | grep -E '5432|6379|11434|4000|18789' || \
ss -tlnp | grep -E '5432|6379|11434|4000|18789'
echo ""

# Quick connectivity tests
echo "=== Connectivity Tests ==="
echo -n "PostgreSQL: "
psql -U openclaw -d openclaw -c "SELECT 1;" > /dev/null 2>&1 && echo "OK" || echo "FAILED"

echo -n "Redis: "
redis-cli ping > /dev/null 2>&1 && echo "OK" || echo "FAILED"

echo -n "Ollama: "
curl -s http://localhost:11434/api/tags > /dev/null 2>&1 && echo "OK" || echo "FAILED"

echo -n "LiteLLM: "
curl -s http://localhost:4000/health > /dev/null 2>&1 && echo "OK" || echo "FAILED"

echo -n "OpenClaw: "
openclaw gateway status > /dev/null 2>&1 && echo "OK" || echo "FAILED"
```

### Log Collection Script

```bash
#!/bin/bash
# collect-logs.sh

LOG_DIR="/tmp/openclaw-logs-$(date +%Y%m%d-%H%M%S)"
mkdir -p $LOG_DIR

echo "Collecting logs to $LOG_DIR..."

# System logs
journalctl -u postgresql --no-pager > $LOG_DIR/postgresql.log 2>&1
journalctl -u redis --no-pager > $LOG_DIR/redis.log 2>&1
journalctl -u ollama --no-pager > $LOG_DIR/ollama.log 2>&1
journalctl -u litellm --no-pager > $LOG_DIR/litellm.log 2>&1
journalctl -u openclaw-gateway --no-pager > $LOG_DIR/openclaw-gateway.log 2>&1

# Application logs
cp -r /var/log/openclaw/ $LOG_DIR/ 2>/dev/null
cp ~/.openclaw/logs/ $LOG_DIR/ 2>/dev/null

# Configuration files
cp /etc/litellm/litellm_config.yaml $LOG_DIR/ 2>/dev/null
cp /etc/openclaw/.env $LOG_DIR/ 2>/dev/null
cp ~/.openclaw/openclaw.json $LOG_DIR/ 2>/dev/null

# System info
uname -a > $LOG_DIR/system-info.txt
free -h >> $LOG_DIR/system-info.txt
df -h >> $LOG_DIR/system-info.txt
nproc >> $LOG_DIR/system-info.txt

# Compress for sharing
tar -czf $LOG_DIR.tar.gz $LOG_DIR
rm -rf $LOG_DIR

echo "Logs collected: $LOG_DIR.tar.gz"
```

---

## Service Status Commands

### Systemd Service Management

```bash
# Check service status
systemctl status postgresql
systemctl status redis
systemctl status ollama
systemctl status litellm
systemctl status openclaw-gateway

# Check all OpenClaw services
systemctl list-units --type=service | grep -E 'postgresql|redis|ollama|litellm|openclaw'

# Restart a service
sudo systemctl restart <service-name>

# Stop a service
sudo systemctl stop <service-name>

# Start a service
sudo systemctl start <service-name>

# Enable auto-start on boot
sudo systemctl enable <service-name>

# Disable auto-start
sudo systemctl disable <service-name>

# View service logs
journalctl -u <service-name> -f

# View last 100 log entries
journalctl -u <service-name> -n 100

# View logs since specific time
journalctl -u <service-name> --since "2026-03-31 10:00:00"

# View logs for specific boot
journalctl -u <service-name> -b 0
```

### Process Information

```bash
# Find process by port
sudo lsof -i :4000
sudo netstat -tlnp | grep 4000
sudo ss -tlnp | grep 4000

# Find process by name
pgrep -a postgres
pgrep -a redis
pgrep -a ollama
pgrep -a node  # OpenClaw

# Check process resource usage
ps aux | grep -E 'postgres|redis|ollama|node' | grep -v grep
top -p $(pgrep -d, postgres)  # PostgreSQL processes
```

---

## PostgreSQL Issues

### Service Won't Start

```bash
# Check service status
systemctl status postgresql

# Check logs
journalctl -u postgresql -f

# Common issues and solutions:

# 1. Check if port is in use
sudo lsof -i :5432
sudo netstat -tlnp | grep 5432

# 2. Check disk space
df -h /var/lib/postgresql

# 3. Check permissions
ls -la /var/lib/postgresql/
sudo chown -R postgres:postgres /var/lib/postgresql

# 4. Check configuration
sudo -u postgres psql -c "SHOW config_file;"
sudo nano /etc/postgresql/15/main/postgresql.conf

# 5. Try manual start for more details
sudo -u postgres /usr/lib/postgresql/15/bin/pg_ctl -D /var/lib/postgresql/15/main start
```

### Connection Refused

```bash
# Test local connection
sudo -u postgres psql

# Test remote connection
psql -h localhost -U openclaw -d openclaw

# Check if PostgreSQL is listening
sudo netstat -tlnp | grep 5432
sudo ss -tlnp | grep 5432

# Check pg_hba.conf
sudo nano /etc/postgresql/15/main/pg_hba.conf

# Verify pg_hba.conf allows local connections:
# local   all             all                                     peer
# host    all             all             127.0.0.1/32            scram-sha-256

# Reload configuration
sudo systemctl reload postgresql

# Check PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-15-main.log
```

### pgvector Extension Issues

```bash
# Check if pgvector is installed
dpkg -l | grep pgvector  # Ubuntu
rpm -qa | grep pgvector  # RHEL

# Check if extension is loaded
psql -U openclaw -d openclaw -c "\dx"

# Install pgvector if missing
# Ubuntu
sudo apt-get install -y postgresql-15-pgvector

# RHEL
sudo dnf install -y postgresql15-pgvector

# Enable extension
psql -U openclaw -d openclaw -c "CREATE EXTENSION IF NOT EXISTS vector;"

# Verify
psql -U openclaw -d openclaw -c "SELECT * FROM pg_extension WHERE extname = 'vector';"
```

### Database Migration Issues

```bash
# Check current migration state
psql -U openclaw -d openclaw -c "SELECT * FROM schema_migrations ORDER BY version;"

# Check for failed migrations
psql -U openclaw -d openclaw -c "SELECT * FROM ar_internal_metadata;"

# Re-run migrations
cd /root/heretek/heretek-openclaw
npm run db:migrate

# Rollback last migration
npm run db:rollback

# Check migration files
ls -la migrations/
```

---

## Redis Issues

### Service Won't Start

```bash
# Check service status
systemctl status redis

# Check logs
journalctl -u redis -f

# Check Redis configuration
sudo nano /etc/redis/redis.conf

# Common issues:

# 1. Port in use
sudo lsof -i :6379

# 2. Permission issues
ls -la /var/lib/redis/
sudo chown -R redis:redis /var/lib/redis/

# 3. Memory issues
free -h
# If low on memory, check redis.conf maxmemory setting

# 4. Try manual start
sudo -u redis redis-server /etc/redis/redis.conf
```

### Connection Refused

```bash
# Test connection
redis-cli ping

# Test with password
redis-cli -a your-redis-password ping

# Check if Redis is listening
sudo netstat -tlnp | grep 6379

# Check Redis configuration
sudo grep -E "bind|port|requirepass" /etc/redis/redis.conf

# Verify bind address
# Should be: bind 127.0.0.1

# Verify password
# Should match: requirepass your-redis-password

# Restart Redis
sudo systemctl restart redis
```

### Redis Persistence Issues

```bash
# Check RDB file
ls -la /var/lib/redis/dump.rdb

# Check AOF file
ls -la /var/lib/redis/appendonly.aof

# Check disk space
df -h /var/lib/redis

# Force BGSAVE
redis-cli -a your-redis-password BGSAVE

# Check last save time
redis-cli -a your-redis-password LASTSAVE

# Check memory info
redis-cli -a your-redis-password INFO memory
```

---

## Ollama Issues

### Service Won't Start

```bash
# Check service status
systemctl status ollama

# Check logs
journalctl -u ollama -f

# Check if port is in use
sudo lsof -i :11434

# Check Ollama data directory
ls -la /var/lib/ollama/
sudo chown -R ollama:ollama /var/lib/ollama/

# Try manual start
sudo -u ollama ollama serve
```

### GPU Not Detected

#### AMD ROCm

```bash
# Check ROCm installation
rocm-smi

# Check GPU devices
ls -la /dev/kfd
ls -la /dev/dri/

# Check user groups
groups $(whoami)
# Should include: render, video

# Add user to groups if needed
sudo usermod -aG render,video $USER

# Check systemd override
systemctl cat ollama

# Verify ROCm environment variables
echo $HSA_OVERRIDE_GFX_VERSION

# Restart Ollama with ROCm
sudo systemctl restart ollama

# Check Ollama logs for GPU detection
journalctl -u ollama | grep -i gpu
journalctl -u ollama | grep -i rocm
```

#### NVIDIA CUDA

```bash
# Check NVIDIA driver
nvidia-smi

# Check CUDA installation
nvcc --version

# Check GPU devices
ls -la /dev/nvidia*

# Check user groups
groups $(whoami)
# Should include: video

# Check systemd override
systemctl cat ollama

# Restart Ollama
sudo systemctl restart ollama

# Check Ollama logs for GPU detection
journalctl -u ollama | grep -i gpu
journalctl -u ollama | grep -i nvidia
journalctl -u ollama | grep -i cuda
```

### Models Not Found

```bash
# List available models
ollama list

# Pull missing model
ollama pull nomic-embed-text-v2-moe

# Check model directory
ls -la /var/lib/ollama/models/

# Re-pull all models
ollama list --format json | jq -r '.[].name' | xargs -I {} ollama pull {}

# Check disk space for models
df -h /var/lib/ollama
```

### Ollama Health Check

```bash
# Basic health check
curl http://localhost:11434/api/tags

# Test embedding
curl http://localhost:11434/api/embeddings -d '{
  "model": "nomic-embed-text-v2-moe",
  "prompt": "Hello, world!"
}'

# Test generation
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Hello!",
  "stream": false
}'
```

---

## LiteLLM Issues

### Service Won't Start

```bash
# Check service status
systemctl status litellm

# Check logs
journalctl -u litellm -f

# Check LiteLLM configuration
sudo nano /etc/litellm/litellm_config.yaml

# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('/etc/litellm/litellm_config.yaml'))"

# Check virtual environment
ls -la /opt/litellm/venv/bin/python

# Test LiteLLM manually
sudo -u litellm /opt/litellm/venv/bin/litellm --config /etc/litellm/litellm_config.yaml

# Check environment file
sudo cat /etc/openclaw/.env | grep -E 'DATABASE_URL|REDIS_URL'
```

### Health Check Fails

```bash
# Test health endpoint
curl -v http://localhost:4000/health

# Check LiteLLM logs
sudo tail -f /var/log/litellm/litellm.log

# Common issues:

# 1. Database connection
psql -U openclaw -d openclaw -c "SELECT 1;"

# 2. Redis connection
redis-cli -a your-redis-password ping

# 3. Check environment variables
sudo -u litellm bash -c 'source /opt/litellm/venv/bin/activate && env | grep -E "DATABASE|REDIS"'

# 4. Check model configuration
curl http://localhost:4000/v1/models

# 5. Check provider API keys
sudo cat /etc/openclaw/.env | grep API_KEY
```

### Model Routing Issues

```bash
# List available models
curl http://localhost:4000/v1/models

# Test specific model
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "minimax/MiniMax-M2.7",
    "messages": [{"role": "user", "content": "Hello"}]
  }'

# Check router logs
journalctl -u litellm | grep -i router

# Check fallback configuration
sudo grep -A 10 "fallback_models" /etc/litellm/litellm_config.yaml
```

### Cost Tracking Issues

```bash
# Check cost tracking configuration
sudo grep -A 20 "budget_settings" /etc/litellm/litellm_config.yaml

# Check spend data
curl http://localhost:4000/spend \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY"

# Check budget status
curl http://localhost:4000/budget/list \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY"

# Reset spend (if needed)
curl -X POST http://localhost:4000/spend/reset \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY"
```

---

## OpenClaw Gateway Issues

### Gateway Won't Start

```bash
# Check service status
systemctl status openclaw-gateway

# Check logs
journalctl -u openclaw-gateway -f

# Check OpenClaw installation
openclaw --version

# Check configuration
openclaw gateway validate

# Check workspace directory
ls -la ~/.openclaw/
ls -la ~/.openclaw/agents/

# Check openclaw.json
cat ~/.openclaw/openclaw.json | jq .

# Try manual start
openclaw gateway start
```

### Agents Not Loading

```bash
# List configured agents
openclaw gateway status

# Check agent workspace
ls -la ~/.openclaw/agents/steward/

# Required files in each agent workspace:
# - SOUL.md
# - IDENTITY.md
# - AGENTS.md
# - USER.md
# - TOOLS.md
# - MEMORY.md

# Re-deploy agent if missing
./agents/deploy-agent.sh steward orchestrator

# Validate agent configuration
openclaw agent validate steward

# Check agent logs
tail -f ~/.openclaw/logs/agent-steward.log
```

### Plugins Not Loading

```bash
# List installed plugins
openclaw plugins list

# Check plugin installation
npm list -g @heretek-ai/openclaw-consciousness-plugin

# Reinstall plugin
cd plugins/openclaw-consciousness-plugin
npm install
npm link
openclaw plugins install @heretek-ai/openclaw-consciousness-plugin

# Check plugin configuration
cat plugins/openclaw-consciousness-plugin/config/default.json | jq .
```

### Skills Not Loading

```bash
# List installed skills
openclaw skills list

# Check skill installation
ls -la ~/.openclaw/skills/

# Reinstall skill
openclaw skills uninstall triad-consensus
openclaw skills install ./skills/triad-consensus/SKILL.md

# Validate skill
openclaw skills validate ./skills/triad-consensus/SKILL.md
```

### WebSocket Connection Issues

```bash
# Check if Gateway is listening
sudo netstat -tlnp | grep 18789

# Test WebSocket connection
wscat -c ws://localhost:18789

# Check firewall
sudo ufw status | grep 18789

# Check Gateway logs
journalctl -u openclaw-gateway | grep -i websocket

# Restart Gateway
sudo systemctl restart openclaw-gateway
```

---

## Network Issues

### Port Conflicts

```bash
# Find process using port
sudo lsof -i :4000
sudo netstat -tlnp | grep 4000

# Kill conflicting process
sudo kill -9 <PID>

# Or change port in configuration
# Edit service file or config file
```

### Firewall Issues

#### UFW (Ubuntu)

```bash
# Check UFW status
sudo ufw status verbose

# Allow required ports
sudo ufw allow 4000/tcp   # LiteLLM
sudo ufw allow 18789/tcp  # OpenClaw Gateway
sudo ufw allow 3000/tcp   # Dashboard (optional)

# Check UFW logs
sudo tail -f /var/log/ufw.log
```

#### firewalld (RHEL)

```bash
# Check firewalld status
sudo firewall-cmd --state

# List allowed ports
sudo firewall-cmd --list-all

# Allow required ports
sudo firewall-cmd --permanent --add-port=4000/tcp
sudo firewall-cmd --permanent --add-port=18789/tcp
sudo firewall-cmd --reload

# Check firewalld logs
sudo tail -f /var/log/firewalld
```

### DNS Issues

```bash
# Check DNS resolution
nslookup api.minimaxi.chat
dig api.minimaxi.chat

# Check /etc/resolv.conf
cat /etc/resolv.conf

# Test with different DNS
curl --dns-servers 8.8.8.8 https://api.minimaxi.chat

# Fix DNS (if needed)
sudo nano /etc/systemd/resolved.conf
```

---

## GPU Issues

### AMD ROCm Troubleshooting

```bash
# Check ROCm version
rocm-smi --showversion

# Check GPU status
rocm-smi --showall

# Check kernel modules
lsmod | grep amdgpu

# Check dmesg for GPU errors
dmesg | grep -i amdgpu

# Test ROCm installation
rocminfo

# Check HIP runtime
hipinfo
```

### NVIDIA CUDA Troubleshooting

```bash
# Check driver version
nvidia-smi

# Check CUDA version
nvcc --version

# Check kernel modules
lsmod | grep nvidia

# Check dmesg for GPU errors
dmesg | grep -i nvidia

# Test CUDA installation
deviceQuery  # From CUDA samples

# Check GPU utilization
nvidia-smi dmon
```

---

## Performance Issues

### High CPU Usage

```bash
# Identify high CPU processes
top -bn1 | head -20

# Check OpenClaw processes
ps aux | grep node | grep -v grep

# Check LiteLLM processes
ps aux | grep litellm | grep -v grep

# Check for runaway processes
ps aux --sort=-%cpu | head -10

# Kill runaway process (if needed)
sudo kill -9 <PID>
```

### High Memory Usage

```bash
# Check memory usage
free -h

# Check process memory
ps aux --sort=-%mem | head -10

# Check for memory leaks
watch -n 1 'free -h'

# Clear caches (if needed)
sudo sync && sudo sysctl -w vm.drop_caches=3

# Adjust swap
sudo swapon -s
```

### High Disk I/O

```bash
# Check disk I/O
iostat -x 1

# Check disk usage
df -h

# Find large files
sudo find / -type f -size +1G -exec ls -lh {} \;

# Check PostgreSQL WAL files
ls -la /var/lib/postgresql/15/main/pg_wal/

# Clean up old logs
sudo journalctl --vacuum-time=7d
```

---

## Log Analysis

### Centralized Log Viewing

```bash
# View all OpenClaw logs
journalctl -t openclaw -f

# View all database logs
journalctl -u postgresql -f

# View all Redis logs
journalctl -u redis -f

# View all Ollama logs
journalctl -u ollama -f

# View all LiteLLM logs
journalctl -u litellm -f

# View all Gateway logs
journalctl -u openclaw-gateway -f
```

### Log Pattern Search

```bash
# Search for errors
journalctl -u openclaw-gateway | grep -i error

# Search for warnings
journalctl -u litellm | grep -i warn

# Search for specific agent
journalctl -u openclaw-gateway | grep -i steward

# Search for API calls
journalctl -u litellm | grep -i "POST /v1"

# Search for authentication failures
journalctl -u openclaw-gateway | grep -i "auth\|unauthorized"
```

### Log Rotation

```bash
# Check log rotation configuration
cat /etc/logrotate.d/openclaw

# Force log rotation
sudo logrotate -f /etc/logrotate.d/openclaw

# Check rotated logs
ls -la /var/log/openclaw/
```

---

## Common Error Messages

### "Connection refused"

```
Error: connect ECONNREFUSED 127.0.0.1:5432
```

**Cause:** PostgreSQL is not running or not listening on localhost

**Solution:**
```bash
sudo systemctl start postgresql
sudo systemctl status postgresql
```

### "Authentication failed"

```
Error: password authentication failed for user "openclaw"
```

**Cause:** Incorrect password in connection string

**Solution:**
```bash
# Update password in .env file
nano /etc/openclaw/.env

# Or reset PostgreSQL password
sudo -u postgres psql -c "ALTER USER openclaw WITH PASSWORD 'new-password';"
```

### "Model not found"

```
Error: Model 'minimax/MiniMax-M2.7' not found
```

**Cause:** Model not configured in LiteLLM or API key invalid

**Solution:**
```bash
# Check LiteLLM configuration
sudo cat /etc/litellm/litellm_config.yaml | grep -A 5 "minimax"

# Check API key
echo $MINIMAX_API_KEY

# Test API key
curl -H "Authorization: Bearer $MINIMAX_API_KEY" https://api.minimaxi.chat/v1/models
```

### "Out of memory"

```
Error: JavaScript heap out of memory
```

**Cause:** Node.js process exceeded memory limit

**Solution:**
```bash
# Increase Node.js memory limit
export NODE_OPTIONS="--max-old-space-size=4096"

# Or edit systemd service
sudo nano /etc/systemd/system/openclaw-gateway.service
# Add: Environment="NODE_OPTIONS=--max-old-space-size=4096"

sudo systemctl daemon-reload
sudo systemctl restart openclaw-gateway
```

### "GPU not detected"

```
Error: No GPU detected, running on CPU only
```

**Cause:** GPU drivers not installed or not configured

**Solution:**
```bash
# For AMD ROCm
rocm-smi  # Should show GPU

# For NVIDIA CUDA
nvidia-smi  # Should show GPU

# Check device permissions
ls -la /dev/kfd /dev/dri  # AMD
ls -la /dev/nvidia*       # NVIDIA
```

---

## Support

For additional help:

1. **Check Documentation:**
   - [`BARE_METAL_DEPLOYMENT.md`](./BARE_METAL_DEPLOYMENT.md)
   - [`VM_DEPLOYMENT.md`](./VM_DEPLOYMENT.md)
   - [`DOCKER_TO_BARE_METAL_MIGRATION.md`](./DOCKER_TO_BARE_METAL_MIGRATION.md)

2. **Collect Logs:**
   ```bash
   ./collect-logs.sh
   ```

3. **Open an Issue:**
   https://github.com/Heretek-AI/heretek-openclaw/issues

4. **Include in Issue Report:**
   - System information (`uname -a`)
   - Service status (`systemctl status <service>`)
   - Relevant logs (last 50 lines)
   - Configuration files (sanitized)
   - Steps to reproduce

---

🦞 *The thought that never ends.*
