# AWS Deployment Guide for Heretek OpenClaw

**Version:** 1.0.0  
**Last Updated:** 2026-03-31

For complete AWS deployment instructions, see [`deploy/aws/README.md`](../../deploy/aws/README.md).

## Quick Reference

### Terraform Files

| File | Purpose |
|------|---------|
| [`deploy/aws/terraform/main.tf`](../../deploy/aws/terraform/main.tf) | Main configuration |
| [`deploy/aws/terraform/variables.tf`](../../deploy/aws/terraform/variables.tf) | Input variables |
| [`deploy/aws/terraform/outputs.tf`](../../deploy/aws/terraform/outputs.tf) | Output values |
| [`deploy/aws/terraform/vpc.tf`](../../deploy/aws/terraform/vpc.tf) | VPC configuration |
| [`deploy/aws/terraform/eks.tf`](../../deploy/aws/terraform/eks.tf) | EKS cluster |
| [`deploy/aws/terraform/rds.tf`](../../deploy/aws/terraform/rds.tf) | RDS PostgreSQL |
| [`deploy/aws/terraform/elasticache.tf`](../../deploy/aws/terraform/elasticache.tf) | ElastiCache Redis |
| [`deploy/aws/terraform/ecr.tf`](../../deploy/aws/terraform/ecr.tf) | ECR repositories |
| [`deploy/aws/terraform/alb.tf`](../../deploy/aws/terraform/alb.tf) | Application Load Balancer |

### Deploy Commands

```bash
cd deploy/aws/terraform
terraform init
terraform plan -var-file=terraform.dev.tfvars -out=tfplan
terraform apply tfplan
```

### kubectl Configuration

```bash
aws eks update-kubeconfig --name openclaw-dev-eks --region us-east-1
```

---

🦞 *The thought that never ends.*
