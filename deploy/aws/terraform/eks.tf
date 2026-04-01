# ==============================================================================
# Heretek OpenClaw - AWS EKS Configuration
# ==============================================================================
# EKS cluster and node group configurations
# ==============================================================================

# ------------------------------------------------------------------------------
# EKS Cluster
# ------------------------------------------------------------------------------

resource "aws_eks_cluster" "openclaw_cluster" {
  name     = "${local.name_prefix}-eks"
  version  = var.eks_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eks"
  })

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller
  ]
}

# ------------------------------------------------------------------------------
# EKS Cluster IAM Role
# ------------------------------------------------------------------------------

resource "aws_iam_role" "eks_cluster" {
  name = "${local.name_prefix}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

# ------------------------------------------------------------------------------
# EKS Cluster Security Group
# ------------------------------------------------------------------------------

resource "aws_security_group" "eks_cluster" {
  name        = "${local.name_prefix}-eks-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# OIDC Provider for IRSA
# ------------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "eks" {
  count = var.enable_irsa ? 1 : 0

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  url             = aws_eks_cluster.openclaw_cluster.identity[0].oidc[0].issuer

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# EKS Node Group - General Purpose
# ------------------------------------------------------------------------------

resource "aws_eks_node_group" "general" {
  cluster_name    = aws_eks_cluster.openclaw_cluster.name
  node_group_name = "${local.name_prefix}-general"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.subnet_ids

  instance_types = var.node_groups.general.instance_types

  scaling_config {
    desired_size = var.node_groups.general.desired_size
    max_size     = var.node_groups.general.max_size
    min_size     = var.node_groups.general.min_size
  }

  disk_size = var.node_groups.general.disk_size

  ami_type       = "AL2_x86_64"
  capacity_type  = "ON_DEMAND"
  force_update_version = true

  labels = {
    "workload-type" = "general"
    "environment"   = var.environment
  }

  taint {
    key    = "workload-type"
    value  = "general"
    effect = "NO_SCHEDULE"
  }

  lifecycle {
    ignore_changes = [
      scaling_config[0].desired_size
    ]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-general-ng"
  })

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_read_only
  ]
}

# ------------------------------------------------------------------------------
# EKS Node Group - Compute Optimized
# ------------------------------------------------------------------------------

resource "aws_eks_node_group" "compute" {
  cluster_name    = aws_eks_cluster.openclaw_cluster.name
  node_group_name = "${local.name_prefix}-compute"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.subnet_ids

  instance_types = var.node_groups.compute.instance_types

  scaling_config {
    desired_size = var.node_groups.compute.desired_size
    max_size     = var.node_groups.compute.max_size
    min_size     = var.node_groups.compute.min_size
  }

  disk_size = var.node_groups.compute.disk_size

  ami_type       = "AL2_x86_64"
  capacity_type  = "ON_DEMAND"
  force_update_version = true

  labels = {
    "workload-type" = "compute"
    "environment"   = var.environment
  }

  taint {
    key    = "workload-type"
    value  = "compute"
    effect = "NO_SCHEDULE"
  }

  lifecycle {
    ignore_changes = [
      scaling_config[0].desired_size
    ]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-compute-ng"
  })

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_read_only
  ]
}

# ------------------------------------------------------------------------------
# EKS Node Group - GPU (Optional)
# ------------------------------------------------------------------------------

resource "aws_eks_node_group" "gpu" {
  count = var.enable_gpu_support ? 1 : 0

  cluster_name    = aws_eks_cluster.openclaw_cluster.name
  node_group_name = "${local.name_prefix}-gpu"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.subnet_ids

  instance_types = var.gpu_instance_types

  scaling_config {
    desired_size = 1
    max_size     = 4
    min_size     = 0
  }

  disk_size = 100

  ami_type       = "AL2_x86_64_GPU"
  capacity_type  = "ON_DEMAND"
  force_update_version = true

  labels = {
    "workload-type" = "gpu"
    "environment"   = var.environment
    "gpu"           = "true"
  }

  taint {
    key    = "nvidia.com/gpu"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  lifecycle {
    ignore_changes = [
      scaling_config[0].desired_size
    ]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-gpu-ng"
  })

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_read_only
  ]
}

# ------------------------------------------------------------------------------
# EKS Nodes IAM Role
# ------------------------------------------------------------------------------

resource "aws_iam_role" "eks_nodes" {
  name = "${local.name_prefix}-eks-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# ------------------------------------------------------------------------------
# EKS Nodes Security Group
# ------------------------------------------------------------------------------

resource "aws_security_group" "eks_nodes" {
  name        = "${local.name_prefix}-eks-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# Allow communication from EKS control plane
resource "aws_security_group_rule" "eks_nodes_ingress_cluster" {
  description              = "Allow EKS control plane to communicate with nodes"
  security_group_id        = aws_security_group.eks_nodes.id
  protocol                 = "tcp"
  from_port                = 1025
  to_port                  = 65535
  source_security_group_id = aws_security_group.eks_cluster.id
  type                     = "ingress"
}

# Allow communication between nodes
resource "aws_security_group_rule" "eks_nodes_self" {
  description       = "Allow nodes to communicate with each other"
  security_group_id = aws_security_group.eks_nodes.id
  protocol          = "tcp"
  from_port         = 0
  to_port           = 65535
  self              = true
  type              = "ingress"
}

# ------------------------------------------------------------------------------
# Cluster Autoscaler IAM Policy
# ------------------------------------------------------------------------------

resource "aws_iam_policy" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  name        = "${local.name_prefix}-cluster-autoscaler-policy"
  description = "IAM policy for Cluster Autoscaler"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# AWS Load Balancer Controller IAM Policy
# ------------------------------------------------------------------------------

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${local.name_prefix}-aws-load-balancer-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "iam:CreateServiceLinkedRole"
        ]
        Effect = "Allow"
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      {
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ec2:CreateSecurityGroup"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ec2:CreateTags"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = "CreateSecurityGroup"
          }
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DeleteSecurityGroup"
        ]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          Null = {
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup"
        ]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Action = [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
        ]
      },
      {
        Action = [
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DeleteTargetGroup"
        ]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          Null = {
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Action = [
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      }
    ]
  })

  tags = local.common_tags
}
