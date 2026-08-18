data "aws_ssm_parameter" "windows_ami" {
  # Full Base = Desktop Experience (GUI), not Core.
  name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

#TODO this must end up stored in terraform state. Reconsider
resource "random_password" "windows_admin" {
  length           = 20
  override_special = "!#$%&*()-_=+[]{}"
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

resource "aws_security_group" "windows" {
  name        = "${var.project_name}-${var.environment}-windows-workstation"
  description = "Windows workstation ENI; reached via SSM Session Manager port forwarding, no inbound rules needed"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-windows-workstation"
  }
}

resource "aws_iam_role" "windows_ssm" {
  name = "${var.project_name}-${var.environment}-windows-ssm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "windows_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.windows_ssm.name
}

resource "aws_iam_instance_profile" "windows" {
  name = "${var.project_name}-${var.environment}-windows-workstation"
  role = aws_iam_role.windows_ssm.name
}

resource "aws_instance" "windows" {
  ami                         = data.aws_ssm_parameter.windows_ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.windows.id]
  iam_instance_profile        = aws_iam_instance_profile.windows.name
  associate_public_ip_address = false

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  # EC2Launch runs <powershell> user data once, on first boot only.
  user_data = <<-EOF
    <powershell>
    net user Administrator "${random_password.windows_admin.result}"
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    </powershell>
  EOF

  tags = {
    Name = "${var.project_name}-${var.environment}-windows-workstation"
  }
}
