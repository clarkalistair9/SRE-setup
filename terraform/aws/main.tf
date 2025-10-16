terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "http" {}
}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}

variable "aws_access_key" {
  type      = string
  sensitive = true
}

variable "aws_secret_key" {
  type      = string
  sensitive = true
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "key_pair_name" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "environment" {
  type    = string
  default = "sre-monitoring"
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_vpc" "sre_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "${var.environment}-vpc", Environment = var.environment }
}

resource "aws_internet_gateway" "sre_igw" {
  vpc_id = aws_vpc.sre_vpc.id
  tags   = { Name = "${var.environment}-igw", Environment = var.environment }
}

resource "aws_subnet" "sre_public_subnet" {
  vpc_id                  = aws_vpc.sre_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = { Name = "${var.environment}-public-subnet", Environment = var.environment }
}

resource "aws_route_table" "sre_public_rt" {
  vpc_id = aws_vpc.sre_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sre_igw.id
  }
  tags = { Name = "${var.environment}-public-rt", Environment = var.environment }
}

resource "aws_route_table_association" "sre_public_rta" {
  subnet_id      = aws_subnet.sre_public_subnet.id
  route_table_id = aws_route_table.sre_public_rt.id
}

resource "aws_security_group" "sre_sg" {
  name        = "${var.environment}-sg"
  description = "Security group for SRE monitoring server"
  vpc_id      = aws_vpc.sre_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment}-sg", Environment = var.environment }
}

resource "aws_instance" "sre_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.sre_public_subnet.id
  vpc_security_group_ids = [aws_security_group.sre_sg.id]

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", { hostname = "${var.environment}-server" }))

  tags = { Name = "${var.environment}-server", Environment = var.environment, Role = "monitoring" }
}

output "public_ip" {
  value       = aws_instance.sre_server.public_ip
  description = "Public IP of the instance"
}

output "instance_id" {
  value       = aws_instance.sre_server.id
  description = "Instance ID"
}

output "ssh_user" {
  value       = "ubuntu"
  description = "Default SSH username"
}

output "prometheus_url" {
  value = "http://${aws_instance.sre_server.public_ip}:9090"
}

output "grafana_url" {
  value = "http://${aws_instance.sre_server.public_ip}:3000"
}



