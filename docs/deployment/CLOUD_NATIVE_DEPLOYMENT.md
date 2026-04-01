# Cloud-Native Deployment Guide for Heretek OpenClaw

**Version:** 1.0.0  
**Last Updated:** 2026-03-31  
**OpenClaw Version:** v2026.3.28

This guide provides comprehensive instructions for deploying Heretek OpenClaw on major cloud platforms using Infrastructure as Code (IaC) and Kubernetes.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Supported Cloud Providers](#supported-cloud-providers)
4. [Prerequisites](#prerequisites)
5. [Quick Start](#quick-start)
6. [Deployment Options](#deployment-options)
7. [Configuration Reference](#configuration-reference)
8. [Security](#security)
9. [Monitoring](#monitoring)
10. [Backup & Disaster Recovery](#backup--disaster-recovery)
11. [Cost Optimization](#cost-optimization)
12. [Troubleshooting](#troubleshooting)

---

## Overview

Heretek OpenClaw supports cloud-native deployments across all major cloud providers:

- **AWS** - EKS, RDS PostgreSQL, ElastiCache, ECR, ALB
- **GCP** - GKE, Cloud SQL, Memorystore, Artifact Registry, Cloud Load Balancing
- **Azure** - AKS, Azure Database for PostgreSQL, Azure Cache for Redis, ACR, Application Gateway

### Key Features

| Feature | Description |
|---------|-------------|
| **Infrastructure as Code** | Terraform configurations for all cloud providers |
| **Kubernetes Native** | Kustomize overlays for dev, staging, prod |
| **High Availability** | Multi-AZ deployments with auto-scaling |
| **GPU Support** | Optional GPU nodes for Ollama (G5, A2, NCas) |
| **Managed Services** | Managed databases, caches, and container registries |
| **Observability** | Integrated monitoring, logging, and alerting |
| **Security** | Private networking, encryption, IAM roles |

---

## Architecture

### High-Level Architecture

```
                                    ┌─────────────────────────────────────────────┐
                                    │              Cloud Provider                   │
                                    │          (AWS / GCP / Azure)                  │
                                    └─────────────────────────────────────────────┘
                                                      │
                    ┌─────────────────────────────────┼─────────────────────────────────┐
                    │                                 │                                 │
                    ▼                                 ▼                                 ▼
        ┌───────────────────────┐         ┌───────────────────────┐         ┌───────────────────────┐
        │    Kubernetes          │         │    Managed            │         │    Managed            │
        │    Cluster             │         │    Database           │         │    Cache              │
        │    (EKS/GKE/AKS)       │         │    (RDS/Cloud SQL/    │         │    (ElastiCache/      │
        │                        │         │     Azure PG)         │         │     Memorystore/      │
        │  ┌────────────────┐    │         │                       │         │     Azure Redis)      │
        │  │ OpenClaw       │    │         │                       │         │                       │
        │  │ Gateway        │    │         │                       │         │                       │
        │  └────────────────┘    │         │                       │         │                       │
        │  ┌────────────────┐    │         │                       │         │                       │
        │  │ LiteLLM Proxy  │    │         │                       │         │                       │
        │  └────────────────┘    │         │                       │         │                       │
        │  ┌────────────────┐    │         │                       │         │                       │
        │  │ Ollama (GPU)   │    │         │                       │         │                       │
        │  └────────────────┘    │         │                       │         │                       │
        └───────────────────────┘         └───────────────────────┘         └───────────────────────┘
                    │                                 │                                 │
                    └─────────────────────────────────┼─────────────────────────────────┘
                                                      │
                    ┌─────────────────────────────────┼─────────────────────────────────┐
                    │                                 │                                 │
                    ▼                                 ▼                                 ▼
        ┌───────────────────────┐         ┌───────────────────────┐         ┌───────────────────────┐
        │    Container           │         │    Load Balancer      │         │    Monitoring         │
        │    Registry            │         │    (ALB/CLB/App GW)   │         │    (CloudWatch/       │
        │    (ECR/AR/ACR)        │         │                       │         │     Monitoring/       │
        │                        │         │                       │         │     Azure Monitor)    │
        └───────────────────────┘         └───────────────────────┘         └───────────────────────┘
```

### Network Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              VPC / VNet / VPC                                    │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                         Public Subnet(s)                                   │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                        │  │
│  │  │   NAT GW    │  │   NAT GW    │  │   NAT GW    │                        │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                        │  │
│  │                                                                            │  │
│  │  ┌─────────────────────────────────────────────────────────────────────┐   │  │
│  │  │                      Load Balancer                                   │   │  │
│  │  │              (Public-facing, SSL Termination)                        │   │  │
│  │  └─────────────────────────────────────────────────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                        Private Subnet(s)                                   │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                        │  │
│  │  │  K8s Nodes  │  │  K8s Nodes  │  │  K8s Nodes  │                        │  │
│  │  │  (General)  │  │  (Compute)  │  │   (GPU)     │                        │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                        │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                       Database Subnet(s)                                   │  │
│  │  ┌─────────────┐  ┌─────────────┐                                         │  │
│  │  │   RDS/PG    │  │   RDS/PG    │                                         │  │
│  │  │  (Primary)  │  │  (Standby)  │                                         │  │
│  │  └─────────────┘  └─────────────┘                                         │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                        Cache Subnet(s)                                     │  │
│  │  ┌─────────────┐  ┌─────────────┐                                         │  │
│  │  │   Redis     │  │   Redis     │                                         │  │
│  │  │  (Primary)  │  │  (Replica)  │                                         │  │
│  │  └─────────────┘  └─────────────┘                                         │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Supported Cloud Providers

### AWS

| Service | Resource | Purpose |
|---------|----------|---------|
| EKS | eks_cluster | Kubernetes cluster |
| RDS | rds_postgresql | PostgreSQL database |
| ElastiCache | elasticache_redis | Redis cache |
| ECR | ecr_repository | Container registry |
| ALB | application_lb | Load balancer |
| CloudWatch | cloudwatch_dashboard | Monitoring |

**Documentation:** [`deploy/aws/README.md`](../../deploy/aws/README.md)

### GCP

| Service | Resource | Purpose |
|---------|----------|---------|
| GKE | gke_cluster | Kubernetes cluster |
| Cloud SQL | cloud_sql_postgresql | PostgreSQL database |
| Memorystore | memorystore_redis | Redis cache |
| Artifact Registry | artifact_registry | Container registry |
| Cloud LB | cloud_load_balancer | Load balancer |
| Cloud Monitoring | monitoring_dashboard | Monitoring |

**Documentation:** [`deploy/gcp/README.md`](../../deploy/gcp/README.md)

### Azure

| Service | Resource | Purpose |
|---------|----------|---------|
| AKS | aks_cluster | Kubernetes cluster |
| Azure DB for PostgreSQL | postgresql_flexible_server | PostgreSQL database |
| Azure Cache for Redis | redis_cache | Redis cache |
| ACR | container_registry | Container registry |
| Application Gateway | application_gateway | Load balancer |
| Azure Monitor | azure_monitor | Monitoring |

**Documentation:** [`deploy/azure/README.md`](../../deploy/azure/README.md)

---

## Prerequisites

### Required Tools

```bash
# Terraform
brew install terraform

# kubectl
brew install kubectl

# Helm
brew install helm

# Cloud provider CLIs
brew install awscli              # AWS
brew install --cask google-cloud-sdk  # GCP
brew install azure-cli           # Azure
```

### Cloud Account Requirements

| Provider | Requirements |
|----------|-------------|
| AWS | IAM user with admin access, budget alerts configured |
| GCP | Project with billing enabled, required APIs enabled |
| Azure | Subscription with contributor access, resource providers registered |

### Kubernetes Requirements

- Kubernetes 1.26+ cluster
- Storage class for persistent volumes
- Ingress controller (nginx recommended)
- Metrics server for HPA

---

## Quick Start

### AWS Quick Start

```bash
cd deploy/aws/terraform

# Initialize Terraform
terraform init

# Create variables file
cat > terraform.tfvars <<EOF
aws_region    = "us-east-1"
environment   = "dev"
db_password   = "secure-password-here"
redis_auth_token = "secure-token-here"
EOF

# Deploy
terraform plan -out=tfplan
terraform apply tfplan

# Configure kubectl
aws eks update-kubeconfig --name openclaw-dev-eks --region us-east-1

# Deploy OpenClaw
cd ../../kubernetes
kubectl apply -k overlays/dev
```

### GCP Quick Start

```bash
cd deploy/gcp/terraform

# Initialize Terraform
terraform init

# Create variables file
cat > terraform.tfvars <<EOF
project_id    = "your-project-id"
region        = "us-central1"
environment   = "dev"
db_password   = "secure-password-here"
EOF

# Deploy
terraform plan -out=tfplan
terraform apply tfplan

# Configure kubectl
gcloud container clusters get-credentials openclaw-dev-gke --region us-central1

# Deploy OpenClaw
cd ../../kubernetes
kubectl apply -k overlays/dev
```

### Azure Quick Start

```bash
cd deploy/azure/terraform

# Initialize Terraform
terraform init

# Create variables file
cat > terraform.tfvars <<EOF
resource_group_name = "openclaw-rg"
location            = "eastus"
environment         = "dev"
db_administrator_password = "secure-password-here"
EOF

# Deploy
terraform plan -out=tfplan
terraform apply tfplan

# Configure kubectl
az aks get-credentials --resource-group openclaw-rg --name openclaw-dev-aks

# Deploy OpenClaw
cd ../../kubernetes
kubectl apply -k overlays/dev
```

---

## Deployment Options

### Environment Overlays

| Environment | Replicas | Resources | Use Case |
|-------------|----------|-----------|----------|
| Dev | 1 | Minimal | Development, testing |
| Staging | 2 | Medium | Pre-production validation |
| Production | 3+ | Full | Production workloads |

### GPU Support

Enable GPU nodes for Ollama local LLM inference:

```hcl
# terraform.tfvars
enable_gpu_support = true

# AWS
gpu_instance_types = ["g5.xlarge", "g5.2xlarge"]

# GCP
gpu_node_pool = {
  machine_type      = "g2-standard-4"
  accelerator_type  = "nvidia-l4"
  accelerator_count = 1
}

# Azure
gpu_node_pool = {
  vm_size = "Standard_NC4as_T4_v3"
}
```

### High Availability

Production deployments include:

- Multi-AZ database (RDS/Cloud SQL/Azure PG)
- Multi-AZ cache (ElastiCache/Memorystore/Azure Redis)
- Multiple node pools across availability zones
- Pod disruption budgets
- Horizontal pod autoscaling

---

## Configuration Reference

### Input Variables

See individual provider documentation for complete variable lists:

- [AWS Variables](../../deploy/aws/terraform/variables.tf)
- [GCP Variables](../../deploy/gcp/terraform/variables.tf)
- [Azure Variables](../../deploy/azure/terraform/variables.tf)

### Kubernetes Configuration

Base manifests: [`deploy/kubernetes/base/`](../../deploy/kubernetes/base/)

Overlays:
- [`deploy/kubernetes/overlays/dev/`](../../deploy/kubernetes/overlays/dev/)
- [`deploy/kubernetes/overlays/staging/`](../../deploy/kubernetes/overlays/staging/)
- [`deploy/kubernetes/overlays/prod/`](../../deploy/kubernetes/overlays/prod/)

### Secrets Management

**Never commit secrets to version control.** Use:

1. **Cloud Secret Managers**
   - AWS Secrets Manager
   - GCP Secret Manager
   - Azure Key Vault

2. **Kubernetes Secrets** (encrypted at rest)

3. **External Secrets Operator** for sync from cloud secret managers

---

## Security

### Network Security

- Private subnets for application workloads
- Security groups / firewall rules for least privilege
- VPC Flow Logs for network monitoring
- Private endpoints for managed services

### Data Security

- Encryption at rest (database, cache, storage)
- Encryption in transit (TLS 1.2+)
- Secrets encryption with KMS
- Network policies for pod isolation

### Access Control

- IAM roles for service accounts (IRSA/Workload Identity)
- RBAC for Kubernetes access
- Network policies for pod communication
- Pod security policies/standards

---

## Monitoring

### Cloud-Native Monitoring

Each deployment includes:

- Cloud provider dashboards (CloudWatch/Cloud Monitoring/Azure Monitor)
- Pre-configured alerts for CPU, memory, storage
- Log aggregation and retention
- Cost monitoring and budget alerts

### Kubernetes Monitoring

- Prometheus metrics via ServiceMonitor
- Grafana dashboards
- Alertmanager for notifications
- Distributed tracing (optional)

---

## Backup & Disaster Recovery

### Automated Backups

| Resource | Strategy | Retention |
|----------|----------|-----------|
| Database | Automated snapshots | 7-35 days |
| Cache | Persistence + manual snapshots | Manual |
| Container Registry | Lifecycle policies | 30 days |
| Terraform State | Versioned storage | Unlimited |

### Disaster Recovery

1. **Multi-AZ** - Automatic failover within region
2. **Cross-Region** - Manual failover to secondary region
3. **Backup Restoration** - Documented procedures for each service

---

## Cost Optimization

### Development Environments

- Single NAT Gateway
- Burstable database instances
- Basic cache tier
- Spot/preemptible instances for non-critical workloads

### Production Optimizations

- Reserved instances / committed use discounts
- Savings plans for predictable workloads
- Cluster autoscaler for dynamic scaling
- Right-sizing based on actual usage

### Cost Estimates

See individual provider READMEs for detailed cost breakdowns:

- [AWS Cost Estimates](../../deploy/aws/README.md#cost-estimates)
- [GCP Cost Estimates](../../deploy/gcp/README.md#cost-estimates)
- [Azure Cost Estimates](../../deploy/azure/README.md#cost-estimates)

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Pods not scheduling | Check node pool capacity, taints, tolerations |
| Database connection failures | Verify security groups, private endpoints |
| Load balancer not routing | Check target group health, ingress configuration |
| GPU not detected | Verify device plugin, node labels, tolerations |

### Support Resources

- [AWS Deployment Guide](../../deploy/aws/README.md)
- [GCP Deployment Guide](../../deploy/gcp/README.md)
- [Azure Deployment Guide](../../deploy/azure/README.md)
- [Kubernetes Deployment Guide](../../docs/deployment/KUBERNETES_DEPLOYMENT.md)

---

🦞 *The thought that never ends.*
