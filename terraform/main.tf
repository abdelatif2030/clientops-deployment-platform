# ---------------------------
# Data: Default VPC
# ---------------------------
data "aws_vpc" "default" {
  default = true
}

# ---------------------------
# Data: Latest Ubuntu 22.04 AMI
# ---------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# ---------------------------
# Security Group - Allow all
# ---------------------------
resource "aws_security_group" "clientops_sg" {
  name        = "clientops_sg"
  description = "Allow all traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "All inbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------
# Generate SSH Key (IMPORTANT)
# ---------------------------
resource "tls_private_key" "terraform" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# ---------------------------
# AWS Key Pair
# ---------------------------
resource "aws_key_pair" "terraform" {
  key_name   = "terraform-key"
  public_key = tls_private_key.terraform.public_key_openssh
}

# ---------------------------
# Root Public Key for User Data
# ---------------------------
variable "root_public_key" {
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDxkfLKhCBPFlOvgyDpRmupFyzhrvA5yxmBfuQfdFj+Eie6xebK8p9P+zClSxYcDlKVFVqFuxItT6mNZmNYxgWCK1hFAVAOcwd7Stn8MvqaQzXDogWk3VPp5YzbgwdDQceQRKHfw9wli0JmHfjlTz5zkQ/hV5wwcM9s9edh5kcqKlnFwOeLDgRZ0fEjBr0gUI2I2EQEOdQPAzL+Q92Pp9oEuYoqsu7iryqAQwfPhNDYx7S7FhHjUKDq5fWHlZH4kc0wBYjphjwoXb/cJYv5ZPnwDSdKT4E4ct+3HiYxFtrpbsKRc7sLwMTt6Hwv+ujb7oqKBfv2Z3aKLeF9X5Mi3NO/"
}

locals {
  user_data_root_key = <<-EOF
    #!/bin/bash
    mkdir -p /root/.ssh
    echo "${var.root_public_key}" >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    chown root:root /root/.ssh/authorized_keys
  EOF
}

# ---------------------------
# App Server
# ---------------------------
resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.terraform.key_name
  vpc_security_group_ids = [aws_security_group.clientops_sg.id]

  tags = {
    Name = "app-server"
  }

  user_data = local.user_data_root_key
}

# ---------------------------
# Monitoring Server
# ---------------------------
resource "aws_instance" "monitoring_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.terraform.key_name
  vpc_security_group_ids = [aws_security_group.clientops_sg.id]

  tags = {
    Name = "monitoring-server"
  }

  user_data = local.user_data_root_key
}

