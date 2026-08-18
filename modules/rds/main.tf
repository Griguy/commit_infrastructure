resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-${var.environment}-rds"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.project_name}-${var.environment}-rds"
  }
}

resource "random_password" "master" {
  length           = 20
  override_special = "!#$%&*()-_=+[]{}"
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

# Carries no rules of its own -- it exists purely as an identity. Anything
# that needs to reach the database (namely the EKS backend pods, via a
# SecurityGroupPolicy attaching this SG id by pod label) gets attached to
# it, and the "rds" security group below trusts that membership instead of
# a CIDR range. This is what keeps the database off-limits to everything
# else in the VPC, including the frontend pods and the Windows workstation.
resource "aws_security_group" "client" {
  name        = "${var.project_name}-${var.environment}-rds-client"
  description = "Attach to anything that must reach the ${var.project_name}-${var.environment} RDS instance"
  vpc_id      = var.vpc_id

  # Egress isn't the enforcement boundary here -- the "rds" security group's
  # ingress rule below is, since it only trusts this SG's membership. An
  # egress rule scoped to the RDS SG would create a dependency cycle between
  # the two security groups, so this stays open like the rest of the
  # project's egress rules (see modules/windows).
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-client"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds"
  description = "Controls access to the ${var.project_name}-${var.environment} RDS instance"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Database traffic from the RDS client security group"
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    security_groups = [aws_security_group.client.id]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds"
  }
}

resource "aws_db_instance" "this" {
  identifier     = "${var.project_name}-${var.environment}"
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.master_username
  password = random_password.master.result
  port     = var.port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az                   = false
  backup_retention_period    = 1
  auto_minor_version_upgrade = true

  deletion_protection = false
  skip_final_snapshot = true
  apply_immediately   = true

  tags = {
    Name = "${var.project_name}-${var.environment}"
  }
}
