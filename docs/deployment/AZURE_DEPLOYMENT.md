# Azure Deployment Guide for Heretek OpenClaw

**Version:** 1.0.0  
**Last Updated:** 2026-03-31

For complete Azure deployment instructions, see [`deploy/azure/README.md`](../../deploy/azure/README.md).

## Quick Reference

### Terraform Files

| File | Purpose |
|------|---------|
| [`deploy/azure/terraform/main.tf`](../../deploy/azure/terraform/main.tf) | Main configuration |
| [`deploy/azure/terraform/variables.tf`](../../deploy/azure/terraform/variables.tf) | Input variables |
| [`deploy/azure/terraform/outputs.tf`](../../deploy/azure/terraform/outputs.tf) | Output values |
| [`deploy/azure/terraform/vnet.tf`](../../deploy/azure/terraform/vnet.tf) | VNet configuration |
| [`deploy/azure/terraform/aks.tf`](../../deploy/azure/terraform/aks.tf) | AKS cluster |
| [`deploy/azure/terraform/postgresql.tf`](../../deploy/azure/terraform/postgresql.tf) | Azure Database for PostgreSQL |
| [`deploy/azure/terraform/redis.tf`](../../deploy/azure/terraform/redis.tf) | Azure Cache for Redis |
| [`deploy/azure/terraform/acr.tf`](../../deploy/azure/terraform/acr.tf) | Azure Container Registry |
| [`deploy/azure/terraform/application-gateway.tf`](../../deploy/azure/terraform/application-gateway.tf) | Application Gateway |

### Deploy Commands

```bash
cd deploy/azure/terraform
terraform init
terraform plan -var-file=terraform.dev.tfvars -out=tfplan
terraform apply tfplan
```

### kubectl Configuration

```bash
az aks get-credentials --resource-group openclaw-rg --name openclaw-dev-aks
```

---

🦞 *The thought that never ends.*
