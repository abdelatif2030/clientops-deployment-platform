# Use default VPC
data "aws_vpc" "default" {
  default = true
}

# Dynamically get latest Ubuntu 22.04 LTS AMI in eu-north-1
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Security group that allows all traffic
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

# App EC2
resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = "terraform"
  security_groups = [aws_security_group.clientops_sg.name]
  tags = { Name = "app-server" }
}

# Monitoring EC2
resource "aws_instance" "monitoring_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = "terraform"
  security_groups = [aws_security_group.clientops_sg.name]
  tags = { Name = "monitoring-server" }
}
