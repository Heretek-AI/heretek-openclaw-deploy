# VM Deployment Guide

**Version:** 1.0.0  
**Last Updated:** 2026-03-31  
**OpenClaw Version:** v2026.3.28

This guide provides instructions for deploying the Heretek OpenClaw stack on virtual machines (VMs) across different platforms and operating systems.

---

## Table of Contents

1. [Overview](#overview)
2. [Ubuntu/Debian VM Deployment](#ubuntudebian-vm-deployment)
3. [RHEL/CentOS VM Deployment](#rhelcentos-vm-deployment)
4. [Cloud VM Considerations](#cloud-vm-considerations)
5. [Network Configuration](#network-configuration)
6. [Security Hardening](#security-hardening)
7. [Resource Optimization](#resource-optimization)
8. [Backup and Recovery](#backup-and-recovery)

---

## Overview

### Supported VM Platforms

| Platform | Supported OS | Notes |
|----------|--------------|-------|
| **AWS EC2** | Ubuntu 22.04, RHEL 9 | Use Graviton (ARM) or x86_64 |
| **GCP Compute** | Ubuntu 22.04, Rocky Linux 9 | N1, N2, or C2 machine types |
| **Azure VM** | Ubuntu 22.04, RHEL 9 | D-series or E-series |
| **DigitalOcean** | Ubuntu 22.04 | Droplets with 4+ GB RAM |
| **Linode** | Ubuntu 22.04, AlmaLinux 9 | Linode 4GB+ plans |
| **Proxmox** | Any supported OS | LXC or full VM |
| **VMware** | Any supported OS | ESXi 7.0+ |

### VM Sizing Recommendations

| Workload | vCPU | RAM | Storage | GPU |
|----------|------|-----|---------|-----|
| **Development** | 2-4 | 8 GB | 50 GB SSD | Optional |
| **Production (Small)** | 4-8 | 16 GB | 100 GB SSD | Optional |
| **Production (Medium)** | 8-16 | 32 GB | 200 GB SSD | Recommended |
| **Production (Large)** | 16-32 | 64 GB | 500 GB NVMe | Required |

---

## Ubuntu/Debian VM Deployment

### Prerequisites

- Ubuntu 22.04 LTS VM instance
- SSH access with sudo privileges
- Outbound internet access
- Minimum 4 vCPU, 8 GB RAM

### Quick Start Script

```bash
# Download and run the VM installer
curl -fsSL https://raw.githubusercontent.com/Heretek-AI/heretek-openclaw/main/scripts/install/vm-install.sh -o vm-install.sh
chmod +x vm-install.sh
sudo ./vm-install.sh --os ubuntu --gpu none
```

### Manual Installation

#### Step 1: System Update

```bash
# Update system packages
sudo apt-get update && sudo apt-get upgrade -y

# Install essential tools
sudo apt-get install -y \
    curl \
    git \
    wget \
    gnupg \
    ca-certificates \
    software-properties-common
```

#### Step 2: Install Dependencies

```bash
# Run Ubuntu dependencies script
curl -fsSL https://raw.githubusercontent.com/Heretek-AI/heretek-openclaw/main/scripts/install/ubuntu-deps.sh -o ubuntu-deps.sh
chmod +x ubuntu-deps.sh
sudo ./ubuntu-deps.sh
```

#### Step 3: Clone Repository

```bash
# Clone OpenClaw repository
git clone https://github.com/Heretek-AI/heretek-openclaw.git
cd heretek-openclaw

# Verify repository structure
ls -la
```

#### Step 4: Configure Environment

```bash
# Copy environment template
cp .env.vm.example .env

# Edit with your values
nano .env
```

#### Step 5: Run Post-Installation

```bash
# Run post-installation script
sudo ./scripts/install/post-install.sh

# Verify installation
./scripts/health-check.sh
```

---

## RHEL/CentOS VM Deployment

### Prerequisites

- RHEL 9 or Rocky Linux 9 VM instance
- SSH access with sudo privileges
- Outbound internet access
- Minimum 4 vCPU, 8 GB RAM

### Quick Start Script

```bash
# Download and run the VM installer
curl -fsSL https://raw.githubusercontent.com/Heretek-AI/heretek-openclaw/main/scripts/install/vm-install.sh -o vm-install.sh
chmod +x vm-install.sh
sudo ./vm-install.sh --os rhel --gpu none
```

### Manual Installation

#### Step 1: System Update

```bash
# Update system packages
sudo dnf update -y

# Install essential tools
sudo dnf install -y \
    curl \
    git \
    wget \
    gnupg2 \
    ca-certificates \
    epel-release
```

#### Step 2: Install Dependencies

```bash
# Run RHEL dependencies script
curl -fsSL https://raw.githubusercontent.com/Heretek-AI/heretek-openclaw/main/scripts/install/rhel-deps.sh -o rhel-deps.sh
chmod +x rhel-deps.sh
sudo ./rhel-deps.sh
```

#### Step 3: Clone Repository

```bash
# Clone OpenClaw repository
git clone https://github.com/Heretek-AI/heretek-openclaw.git
cd heretek-openclaw

# Verify repository structure
ls -la
```

#### Step 4: Configure Environment

```bash
# Copy environment template
cp .env.vm.example .env

# Edit with your values
nano .env
```

#### Step 5: Run Post-Installation

```bash
# Run post-installation script
sudo ./scripts/install/post-install.sh

# Verify installation
./scripts/health-check.sh
```

---

## Cloud VM Considerations

### AWS EC2

#### Instance Types

| Use Case | Instance Type | vCPU | RAM | Notes |
|----------|---------------|------|-----|-------|
| Development | t3.medium | 2 | 4 GB | Burstable |
| Production Small | m5.large | 2 | 8 GB | General purpose |
| Production Medium | m5.xlarge | 4 | 16 GB | General purpose |
| Production Large | m5.2xlarge | 8 | 32 GB | General purpose |
| GPU Workload | g5.xlarge | 4 | 16 GB | NVIDIA A10G |

#### Security Group Rules

```bash
# Required inbound rules
Type: SSH, Port: 22, Source: Your IP
Type: Custom TCP, Port: 4000, Source: Your IP (LiteLLM)
Type: Custom TCP, Port: 18789, Source: Your IP (OpenClaw)
Type: Custom TCP, Port: 3000, Source: Your IP (Dashboard - optional)
```

#### IAM Role (Optional)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::your-backup-bucket/*"
    }
  ]
}
```

#### User Data Script

```bash
#!/bin/bash
# EC2 User Data for automatic installation
yum update -y
yum install -y git curl wget
git clone https://github.com/Heretek-AI/heretek-openclaw.git
cd heretek-openclaw
./scripts/install/rhel-deps.sh
./scripts/install/post-install.sh
```

### GCP Compute Engine

#### Machine Types

| Use Case | Machine Type | vCPU | RAM | Notes |
|----------|--------------|------|-----|-------|
| Development | e2-medium | 2 | 4 GB | Balanced |
| Production Small | n2-standard-2 | 2 | 8 GB | General purpose |
| Production Medium | n2-standard-4 | 4 | 16 GB | General purpose |
| Production Large | n2-standard-8 | 8 | 32 GB | General purpose |
| GPU Workload | g2-standard-4 | 4 | 24 GB | NVIDIA L4 |

#### Firewall Rules

```bash
# Create firewall rule
gcloud compute firewall-rules create openclaw-allow \
  --allow tcp:22,tcp:4000,tcp:18789,tcp:3000 \
  --source-ranges YOUR_IP/32 \
  --target-tags openclaw-instance
```

#### Service Account

```bash
# Create service account
gcloud iam service-accounts create openclaw-sa \
  --display-name "OpenClaw Service Account"

# Grant storage access
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member "serviceAccount:openclaw-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role "roles/storage.objectAdmin"
```

### Azure VM

#### VM Sizes

| Use Case | VM Size | vCPU | RAM | Notes |
|----------|---------|------|-----|-------|
| Development | Standard_B2s | 2 | 4 GB | Burstable |
| Production Small | Standard_D2s_v3 | 2 | 8 GB | General purpose |
| Production Medium | Standard_D4s_v3 | 4 | 16 GB | General purpose |
| Production Large | Standard_D8s_v3 | 8 | 32 GB | General purpose |
| GPU Workload | Standard_NC4as_T4_v3 | 4 | 28 GB | NVIDIA T4 |

#### Network Security Group

```bash
# Create NSG rule
az network nsg rule create \
  --resource-group openclaw-rg \
  --nsg-name openclaw-nsg \
  --name AllowOpenClaw \
  --priority 1000 \
  --source-address-prefixes YOUR_IP/32 \
  --destination-port-ranges 22 4000 18789 3000 \
  --access Allow \
  --protocol Tcp
```

#### Managed Identity

```bash
# Create managed identity
az identity create \
  --resource-group openclaw-rg \
  --name openclaw-identity

# Grant storage access
az role assignment create \
  --assignee OBJECT_ID \
  --role "Storage Blob Data Contributor" \
  --scope /subscriptions/SUBSCRIPTION_ID/resourceGroups/openclaw-rg
```

---

## Network Configuration

### Static IP Configuration

#### Ubuntu/Debian (netplan)

```yaml
# /etc/netplan/01-netcfg.yaml
network:
  version: 2
  ethernets:
    eth0:
      addresses:
        - 192.168.1.100/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses:
          - 1.1.1.1
          - 8.8.8.8
```

#### RHEL/CentOS (NetworkManager)

```bash
# Configure static IP
nmcli connection modify eth0 \
  ipv4.addresses 192.168.1.100/24 \
  ipv4.gateway 192.168.1.1 \
  ipv4.dns "1.1.1.1 8.8.8.8" \
  ipv4.method manual

nmcli connection up eth0
```

### DNS Configuration

```bash
# Configure DNS resolver
sudo nano /etc/systemd/resolved.conf
```

```ini
[Resolve]
DNS=1.1.1.1 8.8.8.8
FallbackDNS=9.9.9.9
DNSSEC=allow-downgrade
```

```bash
# Restart systemd-resolved
sudo systemctl restart systemd-resolved
```

### Hostname Configuration

```bash
# Set hostname
sudo hostnamectl set-hostname openclaw-server

# Update /etc/hosts
sudo nano /etc/hosts
```

```
127.0.0.1   localhost localhost.localdomain
192.168.1.100   openclaw-server openclaw
```

---

## Security Hardening

### SSH Hardening

```bash
# Edit SSH configuration
sudo nano /etc/ssh/sshd_config
```

```ini
# SSH Hardening
Port 2222  # Change from default
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowTcpForwarding no
```

```bash
# Restart SSH
sudo systemctl restart sshd
```

### Fail2Ban Configuration

```bash
# Install Fail2Ban
sudo apt-get install -y fail2ban  # Ubuntu
sudo dnf install -y fail2ban      # RHEL

# Configure Fail2Ban
sudo nano /etc/fail2ban/jail.local
```

```ini
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 2222
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[openclaw]
enabled = true
port = 4000,18789
filter = openclaw
logpath = /var/log/openclaw/*.log
maxretry = 10
```

```bash
# Create OpenClaw filter
sudo nano /etc/fail2ban/filter.d/openclaw.conf
```

```ini
[Definition]
failregex = ^.*Failed authentication.*$
            ^.*Invalid API key.*$
            ^.*Rate limit exceeded.*$
ignoreregex =
```

```bash
# Start Fail2Ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### SELinux Configuration (RHEL)

```bash
# Check SELinux status
getenforce

# Set to permissive for testing
sudo setenforce 0

# Create SELinux policy for OpenClaw
sudo nano /etc/selinux/targeted/src/policy/local.te
```

```
module openclaw 1.0;

require {
    type http_port_t;
    type postgresql_port_t;
    class tcp_socket name_connect;
}

# Allow OpenClaw to bind to ports
allow http_port_t self:tcp_socket name_connect;
allow postgresql_port_t self:tcp_socket name_connect;
```

```bash
# Compile and install policy
cd /etc/selinux/targeted/src/policy
make -f /usr/share/selinux/devel/Makefile
sudo semodule -i openclaw.pp

# Re-enable SELinux
sudo setenforce 1
```

### Audit Logging

```bash
# Install auditd
sudo apt-get install -y auditd  # Ubuntu
sudo dnf install -y audit       # RHEL

# Configure audit rules
sudo auditctl -w /etc/openclaw -p wa -k openclaw-config
sudo auditctl -w /root/.openclaw -p wa -k openclaw-data
sudo auditctl -w /etc/litellm -p wa -k litellm-config
```

---

## Resource Optimization

### Memory Optimization

```bash
# Configure swap (if needed)
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make swap permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Verify swap
free -h
```

### CPU Optimization

```bash
# Set CPU governor to performance
sudo apt-get install -y linux-tools-common linux-tools-generic
sudo cpupower frequency-set -g performance

# Verify CPU governor
cpupower frequency-info
```

### Disk I/O Optimization

```bash
# Check current I/O scheduler
cat /sys/block/sda/queue/scheduler

# Set to deadline for better performance
echo deadline | sudo tee /sys/block/sda/queue/scheduler

# Make permanent
sudo nano /etc/default/grub
```

```
GRUB_CMDLINE_LINUX="elevator=deadline"
```

```bash
# Update GRUB
sudo update-grub  # Ubuntu
sudo grub2-mkconfig -o /boot/grub2/grub.cfg  # RHEL
```

---

## Backup and Recovery

### Automated Backup Script

```bash
#!/bin/bash
# /usr/local/bin/openclaw-backup.sh

BACKUP_DIR="/backup/openclaw"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup OpenClaw configuration
tar -czf $BACKUP_DIR/openclaw-config-$DATE.tar.gz \
    ~/.openclaw/ \
    /etc/litellm/ \
    /etc/openclaw/

# Backup PostgreSQL
pg_dump -U openclaw openclaw > $BACKUP_DIR/openclaw-db-$DATE.sql

# Backup Redis
redis-cli -a $REDIS_PASSWORD BGSAVE
cp /var/lib/redis/dump.rdb $BACKUP_DIR/redis-dump-$DATE.rdb

# Compress database backup
gzip $BACKUP_DIR/openclaw-db-$DATE.sql

# Remove old backups
find $BACKUP_DIR -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete
find $BACKUP_DIR -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
find $BACKUP_DIR -name "*.rdb" -mtime +$RETENTION_DAYS -delete

# Log backup
echo "Backup completed: $DATE" >> /var/log/openclaw-backup.log
```

### Systemd Backup Timer

```ini
# /etc/systemd/system/openclaw-backup.timer
[Unit]
Description=Daily OpenClaw Backup
Documentation=file:///root/heretek/heretek-openclaw/docs/operations/AUTOMATED_BACKUP.md

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

```ini
# /etc/systemd/system/openclaw-backup.service
[Unit]
Description=OpenClaw Backup Service
After=postgresql.service redis.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/openclaw-backup.sh
User=root
Group=root
```

```bash
# Enable backup timer
sudo systemctl daemon-reload
sudo systemctl enable openclaw-backup.timer
sudo systemctl start openclaw-backup.timer
```

---

## Troubleshooting

### Common VM Issues

| Issue | Solution |
|-------|----------|
| VM won't boot after installation | Check cloud-init logs: `/var/log/cloud-init.log` |
| Network connectivity issues | Verify security group/firewall rules |
| Performance degradation | Check resource allocation, enable swap |
| SSH connection refused | Verify SSH port and security group |
| Disk space warnings | Extend volume or clean up old backups |

### Cloud-Specific Commands

#### AWS EC2

```bash
# Check instance status
aws ec2 describe-instance-status --instance-ids i-1234567890abcdef0

# Get system log
aws ec2 get-console-output --instance-id i-1234567890abcdef0

# Reboot instance
aws ec2 reboot-instances --instance-ids i-1234567890abcdef0
```

#### GCP Compute

```bash
# Check instance status
gcloud compute instances describe INSTANCE_NAME

# Get serial port output
gcloud compute instances get-serial-port-output INSTANCE_NAME

# Reset instance
gcloud compute instances reset INSTANCE_NAME
```

#### Azure VM

```bash
# Check VM status
az vm show -d -g openclaw-rg -n openclaw-vm

# Get boot diagnostics
az vm boot-diagnostics get-boot-log -g openclaw-rg -n openclaw-vm

# Restart VM
az vm restart -g openclaw-rg -n openclaw-vm
```

---

## Next Steps

After successful VM deployment:

1. **Configure Monitoring** - Set up cloud monitoring and alerts
2. **Enable Auto-Scaling** (if applicable) - Configure scaling policies
3. **Set Up Backup** - Configure automated backups to cloud storage
4. **Configure DNS** - Set up domain name and SSL certificates
5. **Test Failover** - Verify backup and recovery procedures

---

## Support

For issues or questions:
- Check [`NON_DOCKER_TROUBLESHOOTING.md`](./NON_DOCKER_TROUBLESHOOTING.md)
- Review [`BARE_METAL_DEPLOYMENT.md`](./BARE_METAL_DEPLOYMENT.md)
- Open an issue on GitHub: https://github.com/Heretek-AI/heretek-openclaw/issues

---

🦞 *The thought that never ends.*
