# ==============================================================================
# Heretek OpenClaw - AWS ECR Configuration
# ==============================================================================
# Elastic Container Registry for OpenClaw container images
# ==============================================================================

# ------------------------------------------------------------------------------
# ECR Lifecycle Policy Document
# ------------------------------------------------------------------------------

locals {
  ecr_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire images older than 30 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.lifecycle_policy_days
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last N tagged images"
        selection = {
          tagStatus   = "tagged"
          tagPrefixList = ["latest", "main"]
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# ECR Repository - OpenClaw Gateway
# ------------------------------------------------------------------------------

resource "aws_ecr_repository" "openclaw_gateway" {
  name                 = "openclaw-gateway"
  image_tag_mutability = "MUTABLE"
  force_delete         = var.environment == "dev"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }

  tags = merge(local.common_tags, {
    Name        = "openclaw-gateway"
    Component   = "gateway"
  })
}

resource "aws_ecr_lifecycle_policy" "openclaw_gateway" {
  repository = aws_ecr_repository.openclaw_gateway.name
  policy     = local.ecr_lifecycle_policy
}

# ------------------------------------------------------------------------------
# ECR Repository - LiteLLM Proxy
# ------------------------------------------------------------------------------

resource "aws_ecr_repository" "litellm_proxy" {
  name                 = "litellm-proxy"
  image_tag_mutability = "MUTABLE"
  force_delete         = var.environment == "dev"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }

  tags = merge(local.common_tags, {
    Name        = "litellm-proxy"
    Component   = "litellm"
  })
}

resource "aws_ecr_lifecycle_policy" "litellm_proxy" {
  repository = aws_ecr_repository.litellm_proxy.name
  policy     = local.ecr_lifecycle_policy
}

# ------------------------------------------------------------------------------
# ECR Repository - Ollama (Optional for Custom Images)
# ------------------------------------------------------------------------------

resource "aws_ecr_repository" "ollama" {
  count = var.enable_gpu_support ? 1 : 0

  name                 = "ollama"
  image_tag_mutability = "MUTABLE"
  force_delete         = var.environment == "dev"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }

  tags = merge(local.common_tags, {
    Name        = "ollama"
    Component   = "ollama"
  })
}

resource "aws_ecr_lifecycle_policy" "ollama" {
  count = var.enable_gpu_support ? 1 : 0

  repository = aws_ecr_repository.ollama[0].name
  policy     = local.ecr_lifecycle_policy
}

# ------------------------------------------------------------------------------
# ECR Repository - Monitoring Stack (Optional)
# ------------------------------------------------------------------------------

resource "aws_ecr_repository" "monitoring" {
  name                 = "monitoring"
  image_tag_mutability = "MUTABLE"
  force_delete         = var.environment == "dev"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }

  tags = merge(local.common_tags, {
    Name        = "monitoring"
    Component   = "monitoring"
  })
}

resource "aws_ecr_lifecycle_policy" "monitoring" {
  repository = aws_ecr_repository.monitoring.name
  policy     = local.ecr_lifecycle_policy
}

# ------------------------------------------------------------------------------
# KMS Key for ECR Encryption
# ------------------------------------------------------------------------------

resource "aws_kms_key" "ecr" {
  description             = "KMS key for ECR repository encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow ECR Service"
        Effect = "Allow"
        Principal = {
          Service = "ecr.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow EKS Service"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecr-key"
  })
}

resource "aws_kms_alias" "ecr" {
  name          = "alias/${local.name_prefix}-ecr"
  target_key_id = aws_kms_key.ecr.key_id
}

# ------------------------------------------------------------------------------
# ECR Access Policy for Cross-Account (Optional)
# ------------------------------------------------------------------------------

resource "aws_ecr_repository_policy" "openclaw_gateway" {
  repository = aws_ecr_repository.openclaw_gateway.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Allow EKS Pull"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

resource "aws_ecr_repository_policy" "litellm_proxy" {
  repository = aws_ecr_repository.litellm_proxy.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Allow EKS Pull"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# ECR Pull-Through Cache Rules (Optional - for Docker Hub, etc.)
# ------------------------------------------------------------------------------

resource "aws_ecr_pull_through_cache_rule" "docker_hub" {
  count = var.environment == "prod" ? 1 : 0

  ecr_repository_prefix = "dockerhub"
  upstream_registry_url = "registry-1.docker.io"

  tags = local.common_tags
}

resource "aws_ecr_pull_through_cache_rule" "ghcr" {
  count = var.environment == "prod" ? 1 : 0

  ecr_repository_prefix = "ghcr"
  upstream_registry_url = "ghcr.io"

  tags = local.common_tags
}
