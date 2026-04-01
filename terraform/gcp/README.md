# GCP Deployment Guide for Heretek OpenClaw

**Version:** 1.0.0  
**Last Updated:** 2026-03-31  
**OpenClaw Version:** v2026.3.28

This guide provides comprehensive instructions for deploying Heretek OpenClaw on Google Cloud Platform (GCP) using Terraform Infrastructure as Code (IaC).

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

This Terraform configuration deploys a production-ready OpenClaw environment on GCP with:

- **GKE (Google Kubernetes Engine)** - Managed Kubernetes cluster
- **Cloud SQL PostgreSQL** - Managed PostgreSQL with pgvector support
- **Memorystore Redis** - Managed Redis for caching and sessions
- **Artifact Registry** - Private container registry
- **Cloud Load Balancing** - Traffic routing and SSL termination
- **Cloud Monitoring** - Metrics, logging, and alerting

### Components

| Component | Service | Purpose |
|-----------|---------|---------|
| Gateway | GKE | OpenClaw Gateway (port 18789) |
| LiteLLM | GKE | LLM proxy and routing (port 4000) |
| Database | Cloud SQL PostgreSQL 15 | Primary data store with pgvector |
| Cache | Memorystore Redis 7 | Session management, caching |
| Container Registry | Artifact Registry | Private image storage |
| Load Balancer | Cloud LB | HTTPS termination, routing |
| Monitoring | Cloud Monitoring | Metrics, logs, alerts |

---

## Prerequisites

### Required Tools

```bash
# Install Terraform
brew install terraform  # macOS
# or download from https://www.terraform.io/downloads

# Install Google Cloud SDK
brew install --cask google-cloud-sdk  # macOS
# or follow https://cloud.google.com/sdk/docs/install

# Install kubectl
brew install kubectl

# Install Helm
brew install helm
```

### GCP Account Setup

1. **GCP Project** - Active GCP project with billing enabled
2. **Service Account** - Service account with required permissions
3. **Budget Alert** - Set up billing alerts in GCP Console

### Configure GCP Credentials

```bash
# Authenticate with Google Cloud
gcloud auth login

# Set project
gcloud config set project YOUR_PROJECT_ID

# Create service account for Terraform
gcloud iam service-accounts create terraform \
  --display-name "Terraform Service Account"

# Grant required permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:terraform@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/editor"

# Create and download key
gcloud iam service-accounts keys create terraform-key.json \
  --iam-account=terraform@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS=$(pwd)/terraform-key.json
```

### Required GCP Permissions

| Service | Required Permissions |
|---------|---------------------|
| GKE | Container Admin |
| Compute Engine | Compute Admin |
| Cloud SQL | Cloud SQL Admin |
| Memorystore | Redis Admin |
| Artifact Registry | Artifact Registry Admin |
| Cloud Load Balancing | Load Balancing Admin |
| IAM | Service Account Admin |
| Cloud Monitoring | Monitoring Admin |
| Secret Manager | Secret Manager Admin |
| Cloud KMS | KMS Admin |

### Enable Required APIs

```bash
gcloud services enable \
  container.googleapis.com \
  sqladmin.googleapis.com \
  redis.googleapis.com \
  artifactregistry.googleapis.com \
  servicenetworking.googleapis.com \
  monitoring.googleapis.com \
  secretmanager.googleapis.com \
  cloudkms.googleapis.com
```

---

## Architecture

```
                                    ┌─────────────────────────────────────────────┐
                                    │              Google Cloud Platform           │
                                    │                 us-central1                  │
                                    └─────────────────────────────────────────────┘
                                                      │
                    ┌─────────────────────────────────┼─────────────────────────────────┐
                    │                                 │                                 │
                    ▼                                 ▼                                 ▼
        ┌───────────────────────┐         ┌───────────────────────┐         ┌───────────────────────┐
        │       Zone A           │         │       Zone B           │         │       Zone C           │
        │    (us-central1-a)     │         │    (us-central1-b)     │         │    (us-central1-c)     │
        │                        │         │                        │         │                        │
        │  ┌────────────────┐    │         │  ┌────────────────┐    │         │  ┌────────────────┐    │
        │  │   GKE Nodes    │    │         │  │   GKE Nodes    │    │         │  │   GKE Nodes    │    │
        │  │   (General)    │    │         │  │   (Compute)    │    │         │  │   (GPU)        │    │
        │  └────────────────┘    │         │  └────────────────┘    │         │  └────────────────┘    │
        │                        │         │                        │         │                        │
        │  ┌────────────────┐    │         │  ┌────────────────┐    │         │  ┌────────────────┐    │
        │  │ Cloud SQL      │    │         │  │ Memorystore    │    │         │  │ Artifact       │    │
        │  │ Primary        │    │         │  │ Redis          │    │         │  │ Registry       │    │
        │  └────────────────┘    │         │  └────────────────┘    │         │  └────────────────┘    │
        └───────────────────────┘         └───────────────────────┘         └───────────────────────┘
                    │                                 │                                 │
                    └─────────────────────────────────┼─────────────────────────────────┘
                                                      │
                    ┌─────────────────────────────────┼─────────────────────────────────┐
                    │                                 │                                 │
                    ▼                                 ▼                                 ▼
        ┌─────────────────────────────────────────────────────────────────────────────────────────┐
        │                              Cloud Load Balancing                                        │
        │                            (Global HTTP(S) LB)                                           │
        └─────────────────────────────────────────────────────────────────────────────────────────┘
                                                      │
                                                      ▼
        ┌─────────────────────────────────────────────────────────────────────────────────────────┐
        │                              Cloud Monitoring                                            │
        │                       (Metrics, Logging, Alerting)                                       │
        └─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Cost Estimates

### Development Environment

| Resource | Configuration | Monthly Cost (USD) |
|----------|--------------|-------------------|
| GKE Cluster | Autopilot/Standard | $73.00 |
| GKE Nodes | 2x n2-standard-4 | $280.00 |
| Cloud SQL | db-custom-4-15360, 100GB | $150.00 |
| Memorystore | 4GB STANDARD_HA | $150.00 |
| Cloud Load Balancer | External | $18.00 |
| Artifact Registry | 10GB | $2.50 |
| Cloud Monitoring | Standard | $5.00 |
| Network Egress | Estimated | $30.00 |
| **Total** | | **~$708.50/month** |

### Production Environment

| Resource | Configuration | Monthly Cost (USD) |
|----------|--------------|-------------------|
| GKE Cluster | Standard | $73.00 |
| GKE Nodes General | 3x n2-standard-8 | $840.00 |
| GKE Nodes Compute | 4x c2-standard-16 | $2,400.00 |
| GKE Nodes GPU | 2x g2-standard-4 (L4) | $3,000.00 |
| Cloud SQL | db-custom-8-30720, Multi-Region, 200GB | $600.00 |
| Memorystore | 16GB STANDARD_HA | $600.00 |
| Cloud Load Balancer | External | $18.00 |
| Artifact Registry | 50GB | $12.50 |
| Cloud Monitoring | Premium | $50.00 |
| Network Egress | Estimated | $150.00 |
| **Total** | | **~$7,743.50/month** |

> **Note:** GPU costs are significant. Consider using preemptible VMs or autoscaling for cost optimization.

### Cost Optimization Tips

1. **Use Committed Use Discounts** for predictable workloads (up to 57% savings)
2. **Enable GKE Autopilot** for automatic resource optimization
3. **Use Cloud SQL on-demand backups** instead of high availability for dev
4. **Right-size instances** based on actual usage
5. **Enable Cloud Monitoring budget alerts**

---

## Quick Start

### Clone Repository

```bash
git clone https://github.com/Heretek-AI/heretek-openclaw.git
cd heretek-openclaw/deploy/gcp/terraform
```

### Initialize Terraform

```bash
terraform init
```

### Create Terraform Variables File

```bash
cat > terraform.tfvars <<EOF
project_id    = "your-gcp-project-id"
region        = "us-central1"
environment   = "dev"

vpc_cidr      = "10.0.0.0/16"

db_password   = "generate-secure-password"
redis_auth_string = "generate-secure-token"

# Optional: GPU support for Ollama
enable_gpu_support = false

# Optional: Custom domain
managed_domain = "openclaw.example.com"
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
gcloud container clusters get-credentials openclaw-dev-gke --region us-central1
```

### Deploy OpenClaw to GKE

```bash
cd ../../kubernetes
kubectl apply -k overlays/dev
```

---

## Configuration

### Input Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `project_id` | GCP project ID | - | Yes |
| `region` | GCP region | `us-central1` | No |
| `environment` | Environment name | `dev` | Yes |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` | No |
| `enable_gpu_support` | Enable GPU nodes | `false` | No |
| `db_password` | Cloud SQL password | `null` | Yes |
| `redis_auth_string` | Redis AUTH string | `null` | Yes |
| `managed_domain` | Custom domain | `null` | No |

### Environment-Specific Overrides

#### Development (`terraform.dev.tfvars`)

```hcl
environment       = "dev"
db_high_availability = false
redis_tier        = "BASIC"
enable_monitoring_alerts = false

node_pools = {
  general = {
    machine_type  = "n2-standard-2"
    min_count     = 1
    max_count     = 2
    initial_count = 1
  }
  compute = {
    machine_type  = "c2-standard-4"
    min_count     = 0
    max_count     = 2
    initial_count = 1
  }
}
```

#### Production (`terraform.prod.tfvars`)

```hcl
environment       = "prod"
db_high_availability = true
redis_tier        = "STANDARD_HA"
enable_monitoring_alerts = true

node_pools = {
  general = {
    machine_type  = "n2-standard-8"
    min_count     = 3
    max_count     = 10
    initial_count = 3
  }
  compute = {
    machine_type  = "c2-standard-16"
    min_count     = 2
    max_count     = 20
    initial_count = 4
  }
  gpu = {
    machine_type      = "g2-standard-4"
    accelerator_type  = "nvidia-l4"
    accelerator_count = 1
    min_count         = 1
    max_count         = 4
    initial_count     = 2
  }
}
```

---

## Deployment Steps

### Step 1: Prepare GCP Project

```bash
# Verify gcloud configuration
gcloud config list

# Check project billing
gcloud billing accounts list

# Enable required APIs
gcloud services enable \
  container.googleapis.com \
  sqladmin.googleapis.com \
  redis.googleapis.com \
  artifactregistry.googleapis.com
```

### Step 2: Configure Terraform Backend

```bash
# Create GCS bucket for state
gsutil mb -p YOUR_PROJECT_ID -l us-central1 gs://openclaw-terraform-state

# Enable versioning
gsutil versioning set on gs://openclaw-terraform-state

# Create lock table (using Firestore)
gcloud firestore databases create --location us-central --type FIRESTORE_MODE
```

### Step 3: Initialize and Apply

```bash
# Initialize with GCS backend
terraform init \
  -backend-config="bucket=openclaw-terraform-state" \
  -backend-config="prefix=openclaw/dev/terraform.tfstate"

# Plan
terraform plan -var-file=terraform.dev.tfvars -out=tfplan

# Apply
terraform apply tfplan
```

### Step 4: Verify Deployment

```bash
# Check GKE cluster
gcloud container clusters describe openclaw-dev-gke --region us-central1

# Check Cloud SQL instance
gcloud sql instances describe openclaw-dev-pg

# Check Memorystore instance
gcloud redis instances describe openclaw-dev-redis --region us-central1

# Check Artifact Registry
gcloud artifacts repositories describe openclaw-dev-registry --location us-central1
```

---

## Post-Deployment

### Configure kubectl

```bash
# Get cluster credentials
gcloud container clusters get-credentials openclaw-dev-gke --region us-central1

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
  --set image.repository=us-central1-docker.pkg.dev/YOUR_PROJECT_ID/openclaw-dev-registry/openclaw-gateway \
  --set litellm.image.repository=us-central1-docker.pkg.dev/YOUR_PROJECT_ID/openclaw-dev-registry/litellm-proxy
```

### Configure Secrets

```bash
# Create Kubernetes secrets
kubectl create secret generic openclaw-secrets \
  --namespace openclaw \
  --from-literal=database-url="postgresql://openclaw:password@PRIVATE_IP:5432/openclaw" \
  --from-literal=redis-url="redis://:token@MEMORystore_HOST:6379" \
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
  machine_type      = "g2-standard-4"
  accelerator_type  = "nvidia-l4"
  accelerator_count = 1
  min_count         = 0
  max_count         = 4
  initial_count     = 1
}
```

### Install NVIDIA Device Plugin

```bash
kubectl apply -f https://raw.githubusercontent.com/GoogleContainerTools/kpt-packages/master/second-party/nvidia-device-plugin/gke.yaml
```

---

## Monitoring

### Cloud Monitoring Dashboard

The deployment creates a Cloud Monitoring dashboard with:

- GKE cluster metrics
- Node pool metrics
- Cloud SQL metrics
- Memorystore metrics
- Load Balancer metrics
- Application logs

### Access Dashboard

```bash
# Open in GCP Console
open "https://console.cloud.google.com/monitoring/dashboards"
```

---

## Backup & Recovery

### Automated Backups

| Resource | Backup Strategy | Retention |
|----------|----------------|-----------|
| Cloud SQL | Automated + On-demand | 7 days |
| Memorystore | Persistence enabled | Manual |
| Artifact Registry | Lifecycle policy | 30 days |
| Terraform State | GCS versioning | Unlimited |

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
