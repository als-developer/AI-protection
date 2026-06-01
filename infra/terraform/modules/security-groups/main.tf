resource "aws_security_group" "bioshield" {
  name        = var.security_group_name
  description = "Security group for BioShield infrastructure"
  vpc_id      = var.vpc_id

  # HTTPS (API)
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # API Port
  ingress {
    description = "API from internal networks"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = var.internal_cidrs
  }

  # SSH from bastion
  ingress {
    description = "SSH from bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.bastion_cidr]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bioshield-security-group"
  }
}
