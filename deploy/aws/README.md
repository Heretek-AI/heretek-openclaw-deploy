# AWS Deployment Guide for Heretek OpenClaw

**Version:** 1.0.0  
**Last Updated:** 2026-03-31  
**OpenClaw Version:** v2026.3.28

This guide provides comprehensive instructions for deploying Heretek OpenClaw on Amazon Web Services (AWS) using Terraform Infrastructure as Code (IaC).

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

This Terraform configuration deploys a production-ready OpenClaw environment on AWS with:

- **EKS (Elastic Kubernetes Service)** - Managed Kubernetes cluster
- **RDS PostgreSQL** - Managed PostgreSQL with pgvector support
- **ElastiCache Redis** - Managed Redis for caching and sessions
- **ECR (Elastic Container Registry)** - Private container registry
- **ALB (Application Load Balancer)** - Traffic routing and SSL termination
- **CloudWatch** - Monitoring, logging, and alerting

### Components

| Component | Service | Purpose |
|-----------|---------|---------|
| Gateway | EKS | OpenClaw Gateway (port 18789) |
| LiteLLM | EKS | LLM proxy and routing (port 4000) |
| Database | RDS PostgreSQL 15 | Primary data store with pgvector |
| Cache | ElastiCache Redis 7 | Session management, caching |
| Container Registry | ECR | Private image storage |
| Load Balancer | ALB | HTTPS termination, routing |
| Monitoring | CloudWatch | Metrics, logs, alarms |

---

## Prerequisites

### Required Tools

```bash
# Install Terraform
brew install terraform  # macOS
# or download from https://www.terraform.io/downloads

# Install AWS CLI
brew install awscli  # macOS
# or follow https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

# Install kubectl
brew install kubectl

# Install Helm
brew install helm
```

### AWS Account Setup

1. **AWS Account** - Active AWS account with administrative access
2. **IAM User** - User with programmatic access credentials
3. **Budget Alert** - Set up billing alerts in AWS Budgets

### Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Or use environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### Required AWS Permissions

| Service | Required Permissions |
|---------|---------------------|
| EKS | Full access |
| EC2 | Full access |
| RDS | Full access |
| ElastiCache | Full access |
| ECR | Full access |
| ELB | Full access |
| IAM | Create roles and policies |
| CloudWatch | Full access |
| S3 | Create buckets |
| KMS | Create and manage keys |
| Route53 | DNS management (optional) |

---

## Architecture

```
                                    ┌─────────────────────────────────────────────┐
                                    │                  AWS Region                  │
                                    │                   us-east-1                  │
                                    └─────────────────────────────────────────────┘
                                                      │
                    ┌─────────────────────────────────┼─────────────────────────────────┐
                    │                                 │                                 │
                    ▼                                 ▼                                 ▼
        ┌───────────────────────┐         ┌───────────────────────┐         ┌───────────────────────┐
        │     Public Subnet 1    │         │     Public Subnet 2    │         │     Public Subnet 3    │
        │      (us-east-1a)      │         │      (us-east-1b)      │         │      (us-east-1c)      │
        │                        │         │                        │         │                        │
        │  ┌────────────────┐    │         │  ┌────────────────┐    │         │  ┌────────────────┐    │
        │  │   NAT Gateway  │    │         │  │   NAT Gateway  │    │         │  │   NAT Gateway  │    │
        │  └────────────────┘    │         │  └────────────────┘    │         │  └────────────────┘    │
        └───────────────────────┘         └───────────────────────┘         └───────────────────────┘
                    │                                 │                                 │
                    └─────────────────────────────────┼─────────────────────────────────┘
                                                      │
                    ┌─────────────────────────────────┼─────────────────────────────────┐
                    │                                 │                                 │
                    ▼                                 ▼                                 ▼
        ┌───────────────────────┐         ┌───────────────────────┐         ┌───────────────────────┐
        │    Private Subnet 1    │         │    Private Subnet 2    │         │    Private Subnet 3    │
        │      (us-east-1a)      │         │      (us-east-1b)      │         │      (us-east-1c)      │
        │                        │         │                        │         │                        │
        │  ┌────────────────┐    │         │  ┌────────────────┐    │         │  ┌────────────────┐    │
        │  │   EKS Nodes    │    │         │  │   EKS Nodes    │    │         │  │   EKS Nodes    │    │
        │  │   (General)    │    │         │  │   (Compute)    │    │         │  │   (GPU)        │    │
        │  └────────────────┘    │         │  └────────────────┘    │         │  └────────────────┘    │
        │                        │         │                        │         │                        │
        │  ┌────────────────┐    │         │  ┌────────────────┐    │         │  ┌────────────────┐    │
        │  │   RDS Primary  │    │         │  │  ElastiCache   │    │         │  │   ECR Repo     │    │
        │  │   PostgreSQL   │    │         │  │     Redis      │    │         │  │   Images       │    │
        │  └────────────────┘    │         │  └────────────────┘    │         │  └────────────────┘    │
        └───────────────────────┘         └───────────────────────┘         └───────────────────────┘
                    │                                 │                                 │
                    └─────────────────────────────────┼─────────────────────────────────┘
                                                      │
                    ┌─────────────────────────────────┼─────────────────────────────────┐
                    │                                 │                                 │
                    ▼                                 ▼                                 ▼
        ┌───────────────────────┐         ┌───────────────────────┐         ┌───────────────────────┐
        │   Database Subnet 1    │         │   Database Subnet 2    │         │   Database Subnet 3    │
        │      (us-east-1a)      │         │      (us-east-1b)      │         │      (us-east-1c)      │
        │                        │         │                        │         │                        │
        │  ┌────────────────┐    │         │  ┌────────────────┐    │         │                        │
        │  │  RDS Standby   │    │         │  │ ElastiCache    │    │         │                        │
        │  │  (Multi-AZ)    │    │         │  │ Replica        │    │         │                        │
        │  └────────────────┘    │         │  └────────────────┘    │         │                        │
        └───────────────────────┘         └───────────────────────┘         └───────────────────────┘
```

---

## Cost Estimates

### Development Environment

| Resource | Configuration | Monthly Cost (USD) |
|----------|--------------|-------------------|
| EKS Cluster | Control Plane | $73.00 |
| EKS Nodes | 2x m6i.xlarge | $280.00 |
| RDS PostgreSQL | db.m6i.large, 50GB | $125.00 |
| ElastiCache Redis | cache.m6i.large | $75.00 |
| ALB | Standard | $16.00 |
| NAT Gateway | 1x | $32.00 |
| ECR Storage | 10GB | $2.50 |
| CloudWatch Logs | 10GB | $3.00 |
| Data Transfer | Estimated | $50.00 |
| **Total** | | **~$656.50/month** |

### Production Environment

| Resource | Configuration | Monthly Cost (USD) |
|----------|--------------|-------------------|
| EKS Cluster | Control Plane | $73.00 |
| EKS Nodes General | 3x m6i.2xlarge | $840.00 |
| EKS Nodes Compute | 4x c6i.4xlarge | $2,000.00 |
| EKS Nodes GPU | 2x g5.2xlarge | $4,000.00 |
| RDS PostgreSQL | db.m6i.xlarge, Multi-AZ, 200GB | $500.00 |
| ElastiCache Redis | cache.m6i.xlarge, Multi-AZ | $300.00 |
| ALB | Standard | $16.00 |
| NAT Gateway | 3x | $96.00 |
| ECR Storage | 50GB | $12.50 |
| CloudWatch Logs | 50GB | $15.00 |
| Data Transfer | Estimated | $200.00 |
| **Total** | | **~$8,052.50/month** |

> **Note:** GPU costs are significant. Consider using spot instances or on-demand scaling for cost optimization.

### Cost Optimization Tips

1. **Use Spot Instances** for non-critical workloads (up to 70% savings)
2. **Enable Cluster Autoscaler** to scale nodes based on demand
3. **Use Savings Plans** for predictable workloads
4. **Right-size instances** based on actual usage
5. **Enable RDS Reserved Instances** for production databases

---

## Quick Start

### Clone Repository

```bash
git clone https://github.com/Heretek-AI/heretek-openclaw.git
cd heretek-openclaw/deploy/aws/terraform
```

### Initialize Terraform

```bash
terraform init
```

### Create Terraform Variables File

```bash
cat > terraform.tfvars <<EOF
aws_region    = "us-east-1"
environment   = "dev"
owner         = "your-team"
vpc_cidr      = "10.0.0.0/16"

db_password   = "generate-secure-password"
redis_auth_token = "generate-secure-token"

# Optional: GPU support for Ollama
enable_gpu_support = false

# Optional: Custom domain
domain_name = "openclaw.example.com"
acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxx"
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
aws eks update-kubeconfig --name openclaw-dev-eks --region us-east-1
```

### Deploy OpenClaw to EKS

```bash
cd ../../kubernetes
kubectl apply -k overlays/dev
```

---

## Configuration

### Input Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `aws_region` | AWS region | `us-east-1` | No |
| `environment` | Environment name | `dev` | Yes |
| `owner` | Resource owner | `platform-team` | No |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` | No |
| `enable_gpu_support` | Enable GPU nodes | `false` | No |
| `db_password` | RDS master password | `null` | Yes |
| `redis_auth_token` | Redis auth token | `null` | Yes |
| `acm_certificate_arn` | SSL certificate ARN | `null` | No |
| `domain_name` | Custom domain | `null` | No |

### Environment-Specific Overrides

#### Development (`terraform.dev.tfvars`)

```hcl
environment       = "dev"
single_nat_gateway = true
db_multi_az       = false
redis_multi_az_enabled = false
enable_cloudwatch_alarms = false

node_groups = {
  general = {
    instance_types = ["m6i.large"]
    min_size       = 1
    max_size       = 2
    desired_size   = 1
  }
  compute = {
    instance_types = ["c6i.xlarge"]
    min_size       = 0
    max_size       = 2
    desired_size   = 1
  }
}
```

#### Production (`terraform.prod.tfvars`)

```hcl
environment       = "prod"
single_nat_gateway = false
db_multi_az       = true
redis_multi_az_enabled = true
enable_cloudwatch_alarms = true
alb_deletion_protection = true

node_groups = {
  general = {
    instance_types = ["m6i.2xlarge"]
    min_size       = 3
    max_size       = 10
    desired_size   = 3
  }
  compute = {
    instance_types = ["c6i.4xlarge"]
    min_size       = 2
    max_size       = 20
    desired_size   = 4
  }
  gpu = {
    instance_types = ["g5.2xlarge"]
    min_size       = 1
    max_size       = 4
    desired_size   = 2
  }
}
```

---

## Deployment Steps

### Step 1: Prepare AWS Account

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check service quotas
aws service-quotas list-service-quotas --service-code eks
aws service-quotas list-service-quotas --service-code rds
aws service-quotas list-service-quotas --service-code elasticache
```

### Step 2: Configure Terraform Backend

```bash
# Create S3 bucket for state
aws s3api create-bucket --bucket openclaw-terraform-state --region us-east-1

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name openclaw-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### Step 3: Initialize and Apply

```bash
# Initialize with S3 backend
terraform init \
  -backend-config="bucket=openclaw-terraform-state" \
  -backend-config="key=openclaw/dev/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=openclaw-terraform-locks"

# Plan
terraform plan -var-file=terraform.dev.tfvars -out=tfplan

# Apply
terraform apply tfplan
```

### Step 4: Verify Deployment

```bash
# Check EKS cluster
aws eks describe-cluster --name openclaw-dev-eks

# Check RDS instance
aws rds describe-db-instances --db-instance-identifier openclaw-dev-pg

# Check ElastiCache cluster
aws elasticache describe-cache-clusters --cache-cluster-id openclaw-dev-redis

# Check ECR repositories
aws ecr describe-repositories
```

---

## Post-Deployment

### Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig --name openclaw-dev-eks --region us-east-1

# Verify cluster access
kubectl get nodes
kubectl get namespaces
```

### Deploy OpenClaw Helm Chart

```bash
# Add Helm repository (if published)
helm repo add heretek https://heretek.github.io/helm-charts
helm repo update

# Deploy using Helm
helm install openclaw ./charts/openclaw \
  --namespace openclaw \
  --create-namespace \
  --values values.dev.yaml \
  --set image.repository=123456789012.dkr.ecr.us-east-1.amazonaws.com/openclaw-gateway \
  --set litellm.image.repository=123456789012.dkr.ecr.us-east-1.amazonaws.com/litellm-proxy
```

### Configure Secrets

```bash
# Create Kubernetes secrets
kubectl create secret generic openclaw-secrets \
  --namespace openclaw \
  --from-literal=database-url="postgresql://openclaw:password@openclaw-dev-pg.xxx.us-east-1.rds.amazonaws.com:5432/openclaw" \
  --from-literal=redis-url="redis://:token@openclaw-dev-redis.xxx.cache.amazonaws.com:6379" \
  --from-literal=minimax-api-key="your-minimax-key" \
  --from-literal=zai-api-key="your-zai-key"
```

### Verify Services

```bash
# Check pods
kubectl get pods -n openclaw

# Check services
kubectl get svc -n openclaw

# Check logs
kubectl logs -n openclaw -l app=openclaw-gateway
kubectl logs -n openclaw -l app=litellm
```

---

## GPU Support

### Enable GPU Nodes

```hcl
# terraform.tfvars
enable_gpu_support = true
gpu_instance_types = ["g5.xlarge", "g5.2xlarge"]
```

### Install NVIDIA Device Plugin

```bash
kubectl apply -f https://raw.githubusercontent.com/GoogleContainerTools/kpt-packages/master/second-party/nvidia-device-plugin/gke.yaml
```

### Configure Ollama for GPU

```yaml
# values.yaml
ollama:
  enabled: true
  gpu:
    enabled: true
    type: nvidia
  resources:
    limits:
      nvidia.com/gpu: 1
```

---

## Monitoring

### CloudWatch Dashboard

The deployment creates a CloudWatch dashboard with:

- EKS cluster metrics
- Node group metrics
- RDS PostgreSQL metrics
- ElastiCache Redis metrics
- ALB request metrics
- Application logs

### Access Dashboard

```bash
# Get dashboard name from Terraform output
terraform output cloudwatch_dashboard_arn

# Open in AWS Console
open "https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=openclaw-dev-dashboard"
```

### CloudWatch Alarms

Default alarms configured:

| Alarm | Metric | Threshold |
|-------|--------|-----------|
| EKS CPU Utilization | Cluster CPU | > 80% |
| RDS CPU Utilization | DB CPU | > 80% |
| RDS Free Storage | DB Storage | < 10GB |
| Redis CPU Utilization | Cache CPU | > 80% |
| Redis Memory | Freeable Memory | < 256MB |
| ALB 5XX Errors | HTTP 5XX count | > 10 |

---

## Backup & Recovery

### Automated Backups

| Resource | Backup Strategy | Retention |
|----------|----------------|-----------|
| RDS PostgreSQL | Automated snapshots | 7 days |
| ElastiCache Redis | Snapshot on delete | Manual |
| ECR Images | Lifecycle policy | 30 days |
| Terraform State | S3 versioning | Unlimited |

### Manual Backup

```bash
# RDS snapshot
aws rds create-db-snapshot \
  --db-instance-identifier openclaw-dev-pg \
  --db-snapshot-identifier openclaw-manual-snapshot-$(date +%Y%m%d)

# ElastiCache snapshot
aws elasticache create-snapshot \
  --cache-cluster-id openclaw-dev-redis \
  --snapshot-name openclaw-redis-snapshot-$(date +%Y%m%d)

# ECR image backup
aws ecr batch-get-image \
  --repository-name openclaw-gateway \
  --image-ids imageTag=latest \
  --query 'images[].imageManifest' \
  --output text > openclaw-gateway-manifest.json
```

### Disaster Recovery

1. **Restore RDS from snapshot**
2. **Recreate ElastiCache from snapshot**
3. **Reapply Terraform**
4. **Restore Kubernetes workloads**

---

## Troubleshooting

### Common Issues

#### EKS Nodes Not Joining Cluster

```bash
# Check node status
kubectl get nodes

# Check node logs
aws eks describe-cluster --name openclaw-dev-eks

# Verify IAM role permissions
aws iam get-role-policy --role-name openclaw-dev-eks-nodes-role --policy-name AmazonEKSWorkerNodePolicy
```

#### RDS Connection Issues

```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids sg-xxx

# Verify database connectivity
psql -h openclaw-dev-pg.xxx.us-east-1.rds.amazonaws.com -U openclaw -d openclaw
```

#### ALB Health Check Failures

```bash
# Check target group health
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:xxx

# Verify health check path
curl -v http://<pod-ip>:18789/health
```

### Support Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [AWS RDS Documentation](https://docs.aws.amazon.com/AmazonRDS/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [OpenClaw Documentation](../../docs/)

---

## Cleanup

### Destroy Infrastructure

```bash
# Delete Kubernetes resources first
kubectl delete namespace openclaw

# Destroy Terraform resources
terraform destroy -var-file=terraform.dev.tfvars

# Verify deletion
aws eks describe-cluster --name openclaw-dev-eks  # Should return error
```

### Manual Cleanup

```bash
# Delete ECR repositories
aws ecr delete-repository --repository-name openclaw-gateway --force
aws ecr delete-repository --repository-name litellm-proxy --force

# Delete S3 bucket
aws s3 rb s3://openclaw-terraform-state --force

# Delete DynamoDB table
aws dynamodb delete-table --table-name openclaw-terraform-locks
```

---

## Next Steps

1. **Configure CI/CD** - Set up automated deployments
2. **Enable Monitoring** - Configure alerts and dashboards
3. **Set Up Backup** - Implement backup automation
4. **Security Hardening** - Review security configurations
5. **Cost Optimization** - Implement cost controls

---

🦞 *The thought that never ends.*
