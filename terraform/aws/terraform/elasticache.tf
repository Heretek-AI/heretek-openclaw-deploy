# ==============================================================================
# Heretek OpenClaw - AWS ElastiCache Redis Configuration
# ==============================================================================
# ElastiCache Redis for OpenClaw caching and session management
# ==============================================================================

# ------------------------------------------------------------------------------
# ElastiCache Subnet Group
# ------------------------------------------------------------------------------

resource "aws_elasticache_subnet_group" "openclaw" {
  name       = "${local.name_prefix}-redis-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-redis-subnet-group"
  })
}

# ------------------------------------------------------------------------------
# ElastiCache Security Group
# ------------------------------------------------------------------------------

resource "aws_security_group" "elasticache" {
  name        = "${local.name_prefix}-elasticache-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-elasticache-sg"
  })
}

# Allow Redis access from EKS nodes
resource "aws_security_group_rule" "elasticache_ingress_from_nodes" {
  description              = "Allow Redis access from EKS nodes"
  security_group_id        = aws_security_group.elasticache.id
  protocol                 = "tcp"
  from_port                = 6379
  to_port                  = 6379
  source_security_group_id = var.security_group_ids[0]
  type                     = "ingress"
}

# ------------------------------------------------------------------------------
# ElastiCache Parameter Group
# ------------------------------------------------------------------------------

resource "aws_elasticache_parameter_group" "openclaw" {
  family = "redis7"
  name   = "${local.name_prefix}-redis-params"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  parameter {
    name  = "tcp-keepalive"
    value = "60"
  }

  parameter {
    name  = "slowlog-log-slower-than"
    value = "10000"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-redis-params"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# ElastiCache Redis Cluster (Replication Group)
# ------------------------------------------------------------------------------

resource "aws_elasticache_replication_group" "openclaw" {
  replication_group_id       = "${local.name_prefix}-redis"
  description                = "ElastiCache Redis cluster for OpenClaw"
  node_type                  = var.redis_node_type
  num_cache_clusters         = var.redis_automatic_failover_enabled ? 2 : var.redis_num_cache_nodes
  engine                     = "redis"
  engine_version             = var.redis_engine_version
  parameter_group_name       = aws_elasticache_parameter_group.openclaw.name
  subnet_group_name          = aws_elasticache_subnet_group.openclaw.name
  security_group_ids         = [aws_security_group.elasticache.id]
  
  # Authentication
  auth_token                 = var.redis_auth_token
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  
  # High availability
  automatic_failover_enabled = var.redis_automatic_failover_enabled
  multi_az_enabled           = var.redis_multi_az_enabled
  
  # Persistence
  snapshot_retention_limit   = var.environment == "prod" ? 7 : 0
  snapshot_window            = "03:00-04:00"
  maintenance_window         = "Mon:04:00-Mon:05:00"
  
  # Notifications
  notification_topic_arn     = var.alarm_notification_arn
  
  # Monitoring
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.slowlog[0].name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-redis"
  })

  lifecycle {
    prevent_destroy = true
  }
}

# ------------------------------------------------------------------------------
# CloudWatch Log Group for Slow Query Log
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "slowlog" {
  count = var.environment == "prod" ? 1 : 0

  name              = "/aws/elasticache/${local.name_prefix}-slowlog"
  retention_in_days = 30

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# ElastiCache Global Datastore (Cross-Region Replication for DR)
# ------------------------------------------------------------------------------

resource "aws_elasticache_global_replication_group" "openclaw" {
  count = var.environment == "prod" && var.redis_multi_az_enabled ? 1 : 0

  global_replication_group_id_suffix = "${local.name_prefix}-global"
  primary_replication_group_id       = aws_elasticache_replication_group.openclaw.id

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# ElastiCache Serverless (Alternative for Variable Workloads)
# ------------------------------------------------------------------------------

resource "aws_elasticache_serverless_cache" "openclaw" {
  count = var.environment == "dev" ? 1 : 0

  name        = "${local.name_prefix}-redis-serverless"
  engine      = "REDIS"
  subnet_ids  = var.subnet_ids
  security_group_ids = [aws_security_group.elasticache.id]
  
  major_engine_version = "7"
  
  description = "Serverless Redis cache for development environment"

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# CloudWatch Alarms for ElastiCache
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "elasticache_cpu" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-redis-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Redis CPU utilization is too high"
  alarm_actions       = var.alarm_notification_arn != null ? [var.alarm_notification_arn] : []
  ok_actions          = var.alarm_notification_arn != null ? [var.alarm_notification_arn] : []

  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.openclaw.primary_cluster_id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "elasticache_memory" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-redis-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 268435456  # 256MB
  comparison_operator = "LessThanThreshold"
  alarm_description   = "Redis freeable memory is too low"
  alarm_actions       = var.alarm_notification_arn != null ? [var.alarm_notification_arn] : []
  ok_actions          = var.alarm_notification_arn != null ? [var.alarm_notification_arn] : []

  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.openclaw.primary_cluster_id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "elasticache_connections" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-redis-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CurrConnections"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 1000
  alarm_description   = "Redis current connections is too high"
  alarm_actions       = var.alarm_notification_arn != null ? [var.alarm_notification_arn] : []
  ok_actions          = var.alarm_notification_arn != null ? [var.alarm_notification_arn] : []

  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.openclaw.primary_cluster_id
  }

  tags = local.common_tags
}
