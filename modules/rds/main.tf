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

# Scoped to the private subnet CIDRs, not a security-group-membership rule --
# EKS Auto Mode doesn't support Security Groups for Pods (no branch-ENI
# trunking on Auto Mode-managed compute; SecurityGroupPolicy resources just
# get stuck at "Insufficient vpc.amazonaws.com/pod-eni" forever), so a
# per-pod-identity boundary isn't available on this cluster. This CIDR list
# is everything in the private subnets -- EKS pods, the Windows workstation --
# which is broader than "backend pods only," but the database's own
# username/password is still the real access boundary; this is defense in
# depth, not the sole gate.
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds"
  description = "Controls access to the ${var.project_name}-${var.environment} RDS instance"
  vpc_id      = var.vpc_id

  ingress {
    description = "Database traffic from private subnets"
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
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
