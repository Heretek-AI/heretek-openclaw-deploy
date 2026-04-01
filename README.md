# Heretek OpenClaw Deploy

> Infrastructure as Code and deployment configurations for Heretek OpenClaw.

## Overview

This repository contains Terraform modules, Kubernetes manifests, and Helm charts for deploying Heretek OpenClaw to various cloud providers and on-premises environments.

## Supported Platforms

| Platform | Status | Documentation |
|----------|--------|---------------|
| AWS | ✅ Stable | [AWS Guide](docs/aws.md) |
| GCP | ✅ Stable | [GCP Guide](docs/gcp.md) |
| Azure | 🚧 Beta | [Azure Guide](docs/azure.md) |
| Kubernetes | ✅ Stable | [Kubernetes Guide](docs/kubernetes.md) |
| Docker | ✅ Stable | [Docker Guide](docs/docker.md) |
| Bare Metal | ✅ Stable | [Bare Metal Guide](docs/bare-metal.md) |

## Quick Start

### Prerequisites

- Terraform 1.5+
- kubectl (for Kubernetes deployments)
- Helm 3+ (for Helm deployments)
- Cloud provider CLI (aws, gcloud, az)

### AWS Deployment

```bash
cd terraform/aws

# Initialize Terraform
terraform init

# Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings

# Plan deployment
terraform plan -out=tfplan

# Apply deployment
terraform apply tfplan

# Output will show access URLs and credentials
```

### GCP Deployment

```bash
cd terraform/gcp

# Initialize Terraform
terraform init

# Configure variables
cp terraform.tfvars.example terraform.tfvars

# Plan deployment
terraform plan -out=tfplan

# Apply deployment
terraform apply tfplan
```

### Kubernetes Deployment

#### Using Helm (Recommended)

```bash
cd helm

# Add Helm repo (if published)
helm repo add heretek https://heretek.github.io/charts

# Install OpenClaw
helm install openclaw ./openclaw -f values.yaml

# Or from source
helm install openclaw ./openclaw \
  --namespace openclaw \
  --create-namespace \
  --set gateway.replicas=1
```

#### Using kubectl

```bash
cd kubernetes

# Apply base manifests
kubectl apply -f base/

# Apply overlays for your environment
kubectl apply -k overlays/production/
```

## Terraform Modules

### Available Modules

| Module | Description | Location |
|--------|-------------|----------|
| `gateway` | OpenClaw Gateway deployment | `terraform/modules/gateway/` |
| `litellm` | LiteLLM Gateway deployment | `terraform/modules/litellm/` |
| `database` | PostgreSQL with pgvector | `terraform/modules/database/` |
| `cache` | Redis cache cluster | `terraform/modules/cache/` |
| `networking` | VPC, subnets, security groups | `terraform/modules/networking/` |

### Module Usage Example

```hcl
module "openclaw_gateway" {
  source = "./modules/gateway"
  
  cluster_name    = "openclaw-prod"
  instance_type   = "m5.xlarge"
  min_capacity    = 1
  max_capacity    = 5
  
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  
  database_url    = module.database.connection_string
  redis_url       = module.cache.endpoint
}
```

## Helm Charts

### Chart Values

| Key | Default | Description |
|-----|---------|-------------|
| `gateway.replicas` | `1` | Number of Gateway replicas |
| `gateway.image.tag` | `latest` | Gateway image tag |
| `litellm.enabled` | `true` | Enable LiteLLM |
| `database.enabled` | `true` | Deploy PostgreSQL |
| `redis.enabled` | `true` | Deploy Redis |
| `monitoring.enabled` | `true` | Enable monitoring stack |

### Custom Values Example

```yaml
# values.yaml
gateway:
  replicas: 3
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 4Gi

litellm:
  models:
    - name: agent/steward
      model: openai/gpt-4o

database:
  storage: 100Gi
  backup:
    enabled: true
    schedule: "0 2 * * *"
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GATEWAY_URL` | Gateway endpoint | `http://localhost:18789` |
| `LITELLM_URL` | LiteLLM endpoint | `http://localhost:4000` |
| `POSTGRES_HOST` | PostgreSQL host | `localhost` |
| `POSTGRES_PORT` | PostgreSQL port | `5432` |
| `REDIS_HOST` | Redis host | `localhost` |
| `REDIS_PORT` | Redis port | `6379` |

### Terraform Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `cluster_name` | Cluster name | `openclaw` |
| `region` | Cloud region | `us-west-2` |
| `environment` | Environment name | `production` |
| `instance_type` | Instance type | `m5.xlarge` |

## CI/CD Integration

### GitHub Actions

```yaml
name: Deploy OpenClaw

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: hashicorp/setup-terraform@v3
      
      - run: terraform init
      - run: terraform plan -out=tfplan
      - run: terraform apply tfplan
```

## Monitoring

### Health Checks

```bash
# Check Gateway health
curl http://localhost:18789/health

# Check LiteLLM health
curl http://localhost:4000/health

# Check PostgreSQL
pg_isready -h localhost -p 5432

# Check Redis
redis-cli ping
```

### Metrics

- Prometheus metrics available at `/metrics` endpoint
- Grafana dashboards included in monitoring stack
- Custom alerts configured in `monitoring/alerts/`

## Troubleshooting

### Common Issues

#### Terraform Apply Fails

```bash
# Check state
terraform state list

# Refresh state
terraform refresh

# Import existing resources if needed
terraform import <resource> <id>
```

#### Kubernetes Pods Not Starting

```bash
# Check pod status
kubectl get pods -n openclaw

# View logs
kubectl logs -n openclaw <pod-name>

# Describe pod for events
kubectl describe pod -n openclaw <pod-name>
```

## Documentation

- [AWS Deployment](docs/aws.md)
- [GCP Deployment](docs/gcp.md)
- [Azure Deployment](docs/azure.md)
- [Kubernetes Deployment](docs/kubernetes.md)
- [Helm Charts](docs/helm.md)
- [Monitoring Setup](docs/monitoring.md)
- [Backup & Recovery](docs/backup.md)

## Related Repositories

- [Core](https://github.com/heretek/heretek-openclaw-core) - Gateway and agents
- [CLI](https://github.com/heretek/heretek-openclaw-cli) - Deployment CLI
- [Dashboard](https://github.com/heretek/heretek-openclaw-dashboard) - Health monitoring
- [Plugins](https://github.com/heretek/heretek-openclaw-plugins) - Plugin system
- [Docs](https://github.com/heretek/heretek-openclaw-docs) - Documentation site

## License

MIT

## Support

- **Issues:** https://github.com/heretek/heretek-openclaw-deploy/issues
- **Discussions:** https://github.com/heretek/heretek-openclaw-deploy/discussions

---

🦞 *The thought that never ends.*
