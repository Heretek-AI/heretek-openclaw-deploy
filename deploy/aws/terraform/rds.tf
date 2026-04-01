# ==============================================================================
# Heretek OpenClaw - AWS RDS PostgreSQL Configuration
# ==============================================================================
# RDS PostgreSQL database for OpenClaw
# ==============================================================================

# ------------------------------------------------------------------------------
# RDS Subnet Group
# ------------------------------------------------------------------------------

resource "aws_db_subnet_group" "openclaw" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = var.database_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-subnet-group"
  })
}

# ------------------------------------------------------------------------------
# RDS Security Group
# ------------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-sg"
  })
}

# Allow PostgreSQL access from EKS nodes
resource "aws_security_group_rule" "rds_ingress_from_nodes" {
  description              = "Allow PostgreSQL access from EKS nodes"
  security_group_id        = aws_security_group.rds.id
  protocol                 = "tcp"
  from_port                = 5432
  to_port                  = 5432
  source_security_group_id = var.security_group_ids[0]
  type                     = "ingress"
}

# Allow outbound traffic
resource "aws_security_group_rule" "rds_egress" {
  description       = "Allow outbound traffic"
  security_group_id = aws_security_group.rds.id
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = ["0.0.0.0/0"]
  type              = "egress"
}

# ------------------------------------------------------------------------------
# RDS PostgreSQL Instance
# ------------------------------------------------------------------------------

resource "aws_db_instance" "openclaw" {
  identifier = "${local.name_prefix}-pg"

  # Engine configuration
  engine               = "postgres"
  engine_version       = var.postgresql_version
  instance_class       = var.db_instance_class
  allocated_storage    = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type         = "gp3"
  storage_encrypted    = true
  kms_key_id           = var.db_password_kms_key_id

  # Database configuration
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.openclaw.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # High availability
  multi_az               = var.db_multi_az
  availability_zone      = var.db_multi_az ? null : data.aws_availability_zones.available.names[0]

  # Backup configuration
  backup_retention_period      = var.db_backup_retention_period
  backup_window                = var.db_backup_window
  maintenance_window           = var.db_maintenance_window
  copy_tags_to_snapshot        = true
  delete_automated_backups     = var.environment == "dev"
  skip_final_snapshot          = var.environment == "dev"
  final_snapshot_identifier    = var.environment == "dev" ? null : "${local.name_prefix}-final-snapshot"

  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql"]
  performance_insights_enabled    = var.db_performance_insights_enabled
  performance_insights_retention_period = var.db_performance_insights_enabled ? var.db_performance_insights_retention : null
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn

  # Parameters
  parameter_group_name = aws_db_parameter_group.openclaw.name
  option_group_name    = aws_db_option_group.openclaw.name

  # Tags
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-pg"
  })

  lifecycle {
    prevent_destroy = true
  }
}

# ------------------------------------------------------------------------------
# RDS Parameter Group
# ------------------------------------------------------------------------------

resource "aws_db_parameter_group" "openclaw" {
  name   = "${local.name_prefix}-pg-params"
  family = "postgres${var.postgresql_version}"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  parameter {
    name  = "pg_stat_statements.track"
    value = "all"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-pg-params"
  })
}

# ------------------------------------------------------------------------------
# RDS Option Group
# ------------------------------------------------------------------------------

resource "aws_db_option_group" "openclaw" {
  name                     = "${local.name_prefix}-pg-options"
  option_group_description = "Option group for OpenClaw PostgreSQL"
  engine_name              = "postgres"
  major_engine_version     = var.postgresql_version

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-pg-options"
  })
}

# ------------------------------------------------------------------------------
# RDS Monitoring IAM Role
# ------------------------------------------------------------------------------

resource "aws_iam_role" "rds_monitoring" {
  name = "${local.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ------------------------------------------------------------------------------
# RDS Read Replica (Optional for Production)
# ------------------------------------------------------------------------------

resource "aws_db_instance" "openclaw_replica" {
  count = var.environment == "prod" && var.db_multi_az ? 1 : 0

  identifier          = "${local.name_prefix}-pg-replica"
  replicate_source_db = aws_db_instance.openclaw.identifier
  instance_class      = var.db_instance_class

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.openclaw.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # Backup configuration
  backup_retention_period = 0
  skip_final_snapshot     = true

  # Monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-pg-replica"
    Role = "read-replica"
  })
}

# ------------------------------------------------------------------------------
# RDS Proxy (Optional for Connection Pooling)
# ------------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "rds_credentials" {
  name = "${local.name_prefix}/rds/credentials"

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    dbname   = var.db_name
    host     = aws_db_instance.openclaw.address
    port     = aws_db_instance.openclaw.port
  })
}

resource "aws_db_proxy" "openclaw" {
  count = var.environment == "prod" ? 1 : 0

  name                   = "${local.name_prefix}-db-proxy"
  debug_logging          = false
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.rds_proxy.arn
  vpc_security_group_ids = [aws_security_group.rds.id]
  vpc_subnet_ids         = var.database_subnet_ids

  auth {
    auth_scheme     = "SECRETS"
    iam_auth        = "DISABLED"
    secret_arn      = aws_secretsmanager_secret.rds_credentials.arn
    client_password = "REQUIRED"
  }

  tags = local.common_tags
}

resource "aws_db_proxy_default_target_group" "openclaw" {
  count = var.environment == "prod" ? 1 : 0

  db_proxy_name = aws_db_proxy.openclaw[0].name

  connection_pool_config {
    connection_borrow_timeout    = 120
    init_query                   = "SET SESSION CHARACTERISTICS AS TRANSACTION READ ONLY;"
    max_connections_percent      = 100
    max_idle_connections_percent = 50
    session_pinning_filters      = ["EXCLUDE_CHANGE_SET"]
  }
}

resource "aws_db_proxy_target" "openclaw" {
  count = var.environment == "prod" ? 1 : 0

  db_instance_identifier = aws_db_instance.openclaw.identifier
  db_proxy_name          = aws_db_proxy.openclaw[0].name
  target_group_name      = aws_db_proxy_default_target_group.openclaw[0].name
}

# ------------------------------------------------------------------------------
# RDS Proxy IAM Role
# ------------------------------------------------------------------------------

resource "aws_iam_role" "rds_proxy" {
  count = var.environment == "prod" ? 1 : 0

  name = "${local.name_prefix}-rds-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_proxy" {
  count = var.environment == "prod" ? 1 : 0

  role       = aws_iam_role.rds_proxy[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSProxyFullAccess"
}
