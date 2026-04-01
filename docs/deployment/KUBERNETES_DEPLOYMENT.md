# Kubernetes Deployment Guide for Heretek OpenClaw

**Version:** 1.0.0  
**Last Updated:** 2026-03-31  
**OpenClaw Version:** v2026.3.28

This guide provides instructions for deploying Heretek OpenClaw to Kubernetes clusters using Kustomize.

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Directory Structure](#directory-structure)
4. [Base Configuration](#base-configuration)
5. [Environment Overlays](#environment-overlays)
6. [Deployment](#deployment)
7. [Post-Deployment](#post-deployment)
8. [Troubleshooting](#troubleshooting)

---

## Overview

The Kubernetes deployment uses Kustomize for environment-specific configurations:

- **Base manifests** - Common resources for all environments
- **Overlays** - Environment-specific customizations (dev, staging, prod)

### Components

| Component | Resource Type | Purpose |
|-----------|--------------|---------|
| OpenClaw Gateway | Deployment + Service | Main application gateway |
| LiteLLM Proxy | Deployment + Service | LLM routing and proxy |
| PostgreSQL | StatefulSet + Service | Primary database with pgvector |
| Redis | StatefulSet + Service | Cache and session management |

---

## Prerequisites

### Required Tools

```bash
# kubectl
kubectl version --client

# Kustomize (included in kubectl 1.14+)
kubectl version --client --short
```

### Kubernetes Requirements

- Kubernetes 1.26+ cluster
- Storage class for persistent volumes
- Ingress controller (nginx recommended)
- Metrics server for HPA

---

## Directory Structure

```
deploy/kubernetes/
├── base/
│   ├── namespace.yaml
│   ├── openclaw-deployment.yaml
│   ├── openclaw-service.yaml
│   ├── litellm-deployment.yaml
│   ├── litellm-service.yaml
│   ├── postgresql-statefulset.yaml
│   └── redis-statefulset.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml
    ├── staging/
    │   └── kustomization.yaml
    └── prod/
        └── kustomization.yaml
```

---

## Base Configuration

### Namespace

All resources are deployed to the `openclaw` namespace by default.

### OpenClaw Gateway

- **Replicas:** 1 (base)
- **Port:** 18789 (HTTP), 18790 (WebSocket)
- **Resources:** 2-4 CPU, 4-8Gi memory
- **Storage:** 10Gi persistent volume

### LiteLLM Proxy

- **Replicas:** 1 (base)
- **Port:** 4000
- **Resources:** 1-2 CPU, 2-4Gi memory
- **Config:** ConfigMap for model configuration

### PostgreSQL

- **Replicas:** 1
- **Port:** 5432
- **Image:** pgvector/pgvector:pg17
- **Storage:** 50Gi persistent volume
- **Extensions:** pgvector enabled

### Redis

- **Replicas:** 1
- **Port:** 6379
- **Image:** redis:7-alpine
- **Storage:** 10Gi persistent volume
- **Persistence:** AOF enabled

---

## Environment Overlays

### Development

```bash
kubectl apply -k deploy/kubernetes/overlays/dev
```

**Characteristics:**
- Namespace: `openclaw-dev`
- Minimal resources
- Debug logging enabled
- Development secrets

### Staging

```bash
kubectl apply -k deploy/kubernetes/overlays/staging
```

**Characteristics:**
- Namespace: `openclaw-staging`
- 2 replicas for HA
- Production-like configuration
- Staging secrets

### Production

```bash
kubectl apply -k deploy/kubernetes/overlays/prod
```

**Characteristics:**
- Namespace: `openclaw-prod`
- 3+ replicas for HA
- Pod disruption budgets
- Resource limits enforced
- Production secrets (from secret manager)

---

## Deployment

### Step 1: Create Secrets

```bash
kubectl create namespace openclaw-dev

kubectl create secret generic openclaw-secrets \
  --namespace openclaw-dev \
  --from-literal=database-url="postgresql://user:pass@host:5432/db" \
  --from-literal=redis-url="redis://:password@host:6379/0" \
  --from-literal=minimax-api-key="your-key" \
  --from-literal=zai-api-key="your-key"
```

### Step 2: Deploy

```bash
# Development
kubectl apply -k deploy/kubernetes/overlays/dev

# Staging
kubectl apply -k deploy/kubernetes/overlays/staging

# Production
kubectl apply -k deploy/kubernetes/overlays/prod
```

### Step 3: Verify

```bash
# Check pods
kubectl get pods -n openclaw-dev

# Check services
kubectl get svc -n openclaw-dev

# Check logs
kubectl logs -n openclaw-dev -l app.kubernetes.io/name=openclaw-gateway
```

---

## Post-Deployment

### Access Gateway

```bash
# Port forward for local access
kubectl port-forward -n openclaw-dev svc/dev-openclaw-gateway 18789:18789

# Or access via ingress
curl http://openclaw.local/health
```

### Access LiteLLM

```bash
# Port forward
kubectl port-forward -n openclaw-dev svc/dev-litellm 4000:4000

# Test endpoint
curl http://localhost:4000/health
```

### Scale Components

```bash
# Scale Gateway
kubectl scale deployment dev-openclaw-gateway --replicas=3 -n openclaw-dev

# Scale LiteLLM
kubectl scale deployment dev-litellm --replicas=2 -n openclaw-dev
```

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Pods pending | Check storage class, node capacity |
| CrashLoopBackOff | Check logs, secrets configuration |
| Service not accessible | Check ingress, network policies |
| Database connection failed | Verify secrets, network connectivity |

### Debug Commands

```bash
# Describe pod for events
kubectl describe pod <pod-name> -n openclaw-dev

# Check logs
kubectl logs <pod-name> -n openclaw-dev

# Exec into pod
kubectl exec -it <pod-name> -n openclaw-dev -- /bin/sh

# Check resource usage
kubectl top pods -n openclaw-dev
```

---

🦞 *The thought that never ends.*
