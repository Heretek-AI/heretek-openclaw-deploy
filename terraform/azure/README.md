# Azure Deployment Guide for Heretek OpenClaw

**Version:** 1.0.0  
**Last Updated:** 2026-03-31  
**OpenClaw Version:** v2026.3.28

This guide provides comprehensive instructions for deploying Heretek OpenClaw on Microsoft Azure using Terraform Infrastructure as Code (IaC).

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Architecture](#architecture)
4. [Cost Estimates](#cost-estimates)
5. [Quick Start](#quick-start)
6. [Configuration](#configuration)
7. [Deployment Steps](#deployment-steps)
8. [Post-Deployment](#post-deployment)
9. [GPU Support](#gpu-support)
10. [Monitoring](#monitoring)
11. [Backup & Recovery](#backup--recovery)
12. [Troubleshooting](#troubleshooting)

---

## Overview

This Terraform configuration deploys a production-ready OpenClaw environment on Azure with:

- **AKS (Azure Kubernetes Service)** - Managed Kubernetes cluster
- **Azure Database for PostgreSQL** - Flexible Server with pgvector support
- **Azure Cache for Redis** - Managed Redis for caching and sessions
- **Azure Container Registry (ACR)** - Private container registry
- **Application Gateway** - Traffic routing and SSL termination
- **Azure Monitor** - Metrics, logging, and alerting

### Components

| Component | Service | Purpose |
|-----------|---------|---------|
| Gateway | AKS | OpenClaw Gateway (port 18789) |
| LiteLLM | AKS | LLM proxy and routing (port 4000) |
| Database | Azure Database for PostgreSQL 15 | Primary data store with pgvector |
| Cache | Azure Cache for Redis | Session management, caching |
| Container Registry | ACR | Private image storage |
| Load Balancer | Application Gateway | HTTPS termination, routing |
| Monitoring | Azure Monitor | Metrics, logs, alerts |

---

## Prerequisites

### Required Tools

```bash
# Install Terraform
brew install terraform  # macOS
# or download from https://www.terraform.io/downloads

# Install Azure CLI
brew install azure-cli  # macOS
# or follow https://docs.microsoft.com/en-us/cli/azure/install-azure-cli

# Install kubectl
brew install kubectl

# Install Helm
brew install helm
```

### Azure Account Setup

1. **Azure Subscription** - Active subscription with sufficient credits
2. **Service Principal** - Service principal with contributor access
3. **Budget Alert** - Set up cost alerts in Azure Cost Management

### Configure Azure Credentials

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Create service principal for Terraform
az ad sp create-for-rbac --name "openclaw-terraform" --role contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --sdk-auth

# Set environment variables
export ARM_CLIENT_ID="your-app-id"
export ARM_CLIENT_SECRET="your-password"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
```

### Required Azure Permissions

| Service | Required Permissions |
|---------|---------------------|
| AKS | Contributor |
| Virtual Network | Network Contributor |
| PostgreSQL | PostgreSQL Server Contributor |
| Redis | Redis Cache Contributor |
| ACR | AcrPush |
| Application Gateway | Network Contributor |
| Key Vault | Key Vault Administrator |
| Monitor | Monitoring Contributor |

### Enable Required Resource Providers

```bash
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.DBforPostgreSQL
az provider register --namespace Microsoft.Cache
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.KeyVault
```

---

## Architecture

```
                                    ┌─────────────────────────────────────────────┐
                                    │              Microsoft Azure                 │
                                    │                  East US                     │
                                    └─────────────────────────────────────────────┘
                                                      │
                    ┌─────────────────────────────────┼─────────────────────────────────┐
                    │                                 │                                 │
                    ▼                                 ▼                                 ▼
        ┌───────────────────────┐         ┌───────────────────────┐         ┌───────────────────────┐
        │    Availability        │         │    Availability        │         │    Availability        │
        │       Zone 1           │         │       Zone 2           │         │       Zone 3           │
        │                        │         │                        │         │                        │
        │  ┌────────────────┐    │         │  ┌────────────────┐    │         │  ┌────────────────┐    │
        │  │   AKS Nodes    │    │         │  │   AKS Nodes    │    │         │  │   AKS Nodes    │    │
        │  │   (System)     │    │         │  │   (User)       │    │         │  │   (GPU)        │    │
        │  └────────────────┘    │         │  └────────────────┘    │         │  └────────────────┘    │
        │                        │         │                        │         │                        │
        │  ┌────────────────┐    │         │  ┌────────────────┐    │         │  ┌────────────────┐    │
        │  │ PostgreSQL     │    │         │  │ Azure Cache    │    │         │  │   ACR          │    │
        │  │ Flexible       │    │         │  │ for Redis      │    │         │  │                │    │
        │  │ Server         │    │         │  │                │    │         │  │                │    │
        │  └────────────────┘    │         │  └────────────────┘    │         │  └────────────────┘    │
        └───────────────────────┘         └───────────────────────┘         └───────────────────────┘
                    │                                 │                                 │
                    └─────────────────────────────────┼─────────────────────────────────┘
                                                      │
                    ┌─────────────────────────────────┼─────────────────────────────────┐
                    │                                 │                                 │
                    ▼                                 ▼                                 ▼
        ┌─────────────────────────────────────────────────────────────────────────────────────────┐
        │                           Application Gateway                                           │
        │                      (WAF_v2 with SSL Termination)                                      │
        └─────────────────────────────────────────────────────────────────────────────────────────┘
                                                      │
                                                      ▼
        ┌─────────────────────────────────────────────────────────────────────────────────────────┐
        │                           Azure Monitor                                                 │
        │                    (Log Analytics, Alerts, Dashboard)                                   │
        └─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Cost Estimates

### Development Environment

| Resource | Configuration | Monthly Cost (USD) |
|----------|--------------|-------------------|
| AKS Cluster | Standard | $73.00 |
| AKS Nodes | 2x Standard_D4s_v3 | $280.00 |
| PostgreSQL | GP_Gen5_2, 100GB | $150.00 |
| Redis Cache | C2 Standard | $100.00 |
| Application Gateway | Standard_v2 | $30.00 |
| ACR | Standard | $10.00 |
| Azure Monitor | Standard | $50.00 |
| Network Egress | Estimated | $30.00 |
| **Total** | | **~$723.00/month** |

### Production Environment

| Resource | Configuration | Monthly Cost (USD) |
|----------|--------------|-------------------|
| AKS Cluster | Standard | $73.00 |
| AKS Nodes System | 3x Standard_D2s_v3 | $210.00 |
| AKS Nodes User | 4x Standard_D8s_v3 | $1,120.00 |
| AKS Nodes GPU | 2x Standard_NC4as_T4_v3 | $5,000.00 |
| PostgreSQL | GP_Gen5_4, Multi-AZ, 200GB | $400.00 |
| Redis Cache | C6 Premium | $400.00 |
| Application Gateway | WAF_v2 | $100.00 |
| ACR | Premium | $50.00 |
| Azure Monitor | Premium | $100.00 |
| Key Vault | Standard | $5.00 |
| Network Egress | Estimated | $150.00 |
| **Total** | | **~$7,608.00/month** |

> **Note:** GPU costs are significant. Consider using spot instances or scheduling for cost optimization.

### Cost Optimization Tips

1. **Use Azure Reserved VM Instances** for predictable workloads (up to 72% savings)
2. **Use Azure Spot VMs** for non-critical workloads
3. **Enable AKS Cluster Autoscaler** to scale nodes based on demand
4. **Use PostgreSQL Burstable SKU** for development environments
5. **Enable Azure Cost Management budgets**

---

## Quick Start

### Clone Repository

```bash
git clone https://github.com/Heretek-AI/heretek-openclaw.git
cd heretek-openclaw/deploy/azure/terraform
```

### Initialize Terraform

```bash
terraform init
```

### Create Terraform Variables File

```bash
cat > terraform.tfvars <<EOF
resource_group_name = "openclaw-rg"
location            = "eastus"
environment         = "dev"

vnet_address_space  = ["10.0.0.0/16"]

db_administrator_login    = "openclaw"
db_administrator_password = "generate-secure-password"
redis_password            = "generate-secure-token"

# Optional: GPU support for Ollama
enable_gpu_support = false

# Optional: Custom domain
domain_name_label = "openclaw-dev"
EOF
```

### Plan and Apply

```bash
# Review the plan
terraform plan -out=tfplan

# Apply the configuration
terraform apply tfplan
```

### Configure kubectl

```bash
az aks get-credentials --resource-group openclaw-rg --name openclaw-dev-aks
```

### Deploy OpenClaw to AKS

```bash
cd ../../kubernetes
kubectl apply -k overlays/dev
```

---

## Configuration

### Input Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `resource_group_name` | Resource group name | `openclaw-rg` | No |
| `location` | Azure region | `eastus` | No |
| `environment` | Environment name | `dev` | Yes |
| `vnet_address_space` | VNet CIDR | `["10.0.0.0/16"]` | No |
| `enable_gpu_support` | Enable GPU nodes | `false` | No |
| `db_administrator_password` | PostgreSQL password | `null` | Yes |
| `redis_password` | Redis password | `null` | Yes |
| `domain_name_label` | DNS label for gateway | `null` | No |

### Environment-Specific Overrides

#### Development (`terraform.dev.tfvars`)

```hcl
environment       = "dev"
db_geo_redundant_backup = false
redis_sku_name    = "Basic"
enable_monitoring_alerts = false

default_node_pool = {
  name                = "default"
  vm_size             = "Standard_D2s_v3"
  node_count          = 1
  min_count           = 1
  max_count           = 2
  enable_auto_scaling = true
}
```

#### Production (`terraform.prod.tfvars`)

```hcl
environment       = "prod"
db_geo_redundant_backup = true
redis_sku_name    = "Premium"
enable_monitoring_alerts = true
enable_private_cluster = true

default_node_pool = {
  name                = "default"
  vm_size             = "Standard_D8s_v3"
  node_count          = 3
  min_count           = 3
  max_count           = 10
  enable_auto_scaling = true
}

gpu_node_pool = {
  name                = "gpu"
  vm_size             = "Standard_NC4as_T4_v3"
  node_count          = 2
  min_count           = 1
  max_count           = 4
  enable_auto_scaling = true
}
```

---

## Deployment Steps

### Step 1: Prepare Azure Subscription

```bash
# Verify Azure CLI configuration
az account show

# Check subscription quota
az vm list-usage --location eastus

# Enable required providers
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.DBforPostgreSQL
```

### Step 2: Configure Terraform Backend

```bash
# Create resource group
az group create --name openclaw-tfstate-rg --location eastus

# Create storage account
az storage account create --name tfstateopenclaw --resource-group openclaw-tfstate-rg \
  --location eastus --sku Standard_LRS

# Create container
az storage container create --name tfstate --account-name tfstateopenclaw
```

### Step 3: Initialize and Apply

```bash
# Initialize with Azure backend
terraform init \
  -backend-config="resource_group_name=openclaw-tfstate-rg" \
  -backend-config="storage_account_name=tfstateopenclaw" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=openclaw/dev/terraform.tfstate"

# Plan
terraform plan -var-file=terraform.dev.tfvars -out=tfplan

# Apply
terraform apply tfplan
```

### Step 4: Verify Deployment

```bash
# Check AKS cluster
az aks show --resource-group openclaw-rg --name openclaw-dev-aks

# Check PostgreSQL server
az postgres flexible-server show --resource-group openclaw-rg --name openclaw-dev-pg

# Check Redis cache
az redis show --resource-group openclaw-rg --name openclaw-dev-redis

# Check ACR
az acr show --name openclawdevacr
```

---

## Post-Deployment

### Configure kubectl

```bash
# Get AKS credentials
az aks get-credentials --resource-group openclaw-rg --name openclaw-dev-aks

# Verify cluster access
kubectl get nodes
kubectl get namespaces
```

### Deploy OpenClaw Helm Chart

```bash
# Deploy using Helm
helm install openclaw ./charts/openclaw \
  --namespace openclaw \
  --create-namespace \
  --values values.dev.yaml \
  --set image.repository=openclawdevacr.azurecr.io/openclaw-gateway \
  --set litellm.image.repository=openclawdevacr.azurecr.io/litellm-proxy
```

### Configure Secrets

```bash
# Create Kubernetes secrets
kubectl create secret generic openclaw-secrets \
  --namespace openclaw \
  --from-literal=database-url="postgresql://openclaw:password@openclaw-dev-pg.postgres.database.azure.com:5432/postgres" \
  --from-literal=redis-url="redis://:password@openclaw-dev-redis.redis.cache.windows.net:6379" \
  --from-literal=minimax-api-key="your-minimax-key" \
  --from-literal=zai-api-key="your-zai-key"
```

---

## GPU Support

### Enable GPU Nodes

```hcl
# terraform.tfvars
enable_gpu_support = true
gpu_node_pool = {
  name                = "gpu"
  vm_size             = "Standard_NC4as_T4_v3"
  node_count          = 1
  min_count           = 0
  max_count           = 4
  enable_auto_scaling = true
}
```

### Install NVIDIA Device Plugin

```bash
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.1/nvidia-device-plugin.yml
```

---

## Monitoring

### Azure Monitor Dashboard

The deployment creates an Azure Monitor dashboard with:

- AKS cluster metrics
- Node pool metrics
- PostgreSQL metrics
- Redis metrics
- Application Gateway metrics
- Application logs

### Access Dashboard

```bash
# Open in Azure Portal
open "https://portal.azure.com/#blade/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade"
```

---

## Backup & Recovery

### Automated Backups

| Resource | Backup Strategy | Retention |
|----------|----------------|-----------|
| PostgreSQL | Automated + Geo-redundant | 35 days |
| Redis | Persistence enabled | Manual |
| ACR | Geo-redundant (Premium) | 30 days |
| Terraform State | Blob versioning | Unlimited |

---

## Cleanup

### Destroy Infrastructure

```bash
# Delete Kubernetes resources first
kubectl delete namespace openclaw

# Destroy Terraform resources
terraform destroy -var-file=terraform.dev.tfvars
```

---

🦞 *The thought that never ends.*
