# GCP Deployment Guide for Heretek OpenClaw

**Version:** 1.0.0  
**Last Updated:** 2026-03-31

For complete GCP deployment instructions, see [`deploy/gcp/README.md`](../../deploy/gcp/README.md).

## Quick Reference

### Terraform Files

| File | Purpose |
|------|---------|
| [`deploy/gcp/terraform/main.tf`](../../deploy/gcp/terraform/main.tf) | Main configuration |
| [`deploy/gcp/terraform/variables.tf`](../../deploy/gcp/terraform/variables.tf) | Input variables |
| [`deploy/gcp/terraform/outputs.tf`](../../deploy/gcp/terraform/outputs.tf) | Output values |
| [`deploy/gcp/terraform/vpc.tf`](../../deploy/gcp/terraform/vpc.tf) | VPC configuration |
| [`deploy/gcp/terraform/gke.tf`](../../deploy/gcp/terraform/gke.tf) | GKE cluster |
| [`deploy/gcp/terraform/cloud-sql.tf`](../../deploy/gcp/terraform/cloud-sql.tf) | Cloud SQL PostgreSQL |
| [`deploy/gcp/terraform/memorystore.tf`](../../deploy/gcp/terraform/memorystore.tf) | Memorystore Redis |
| [`deploy/gcp/terraform/artifact-registry.tf`](../../deploy/gcp/terraform/artifact-registry.tf) | Artifact Registry |
| [`deploy/gcp/terraform/load-balancer.tf`](../../deploy/gcp/terraform/load-balancer.tf) | Cloud Load Balancing |

### Deploy Commands

```bash
cd deploy/gcp/terraform
terraform init
terraform plan -var-file=terraform.dev.tfvars -out=tfplan
terraform apply tfplan
```

### kubectl Configuration

```bash
gcloud container clusters get-credentials openclaw-dev-gke --region us-central1
```

---

🦞 *The thought that never ends.*
