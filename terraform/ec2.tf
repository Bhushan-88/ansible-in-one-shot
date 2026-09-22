resource "aws_key_pair" "ansible" {
  key_name   = var.key_name
  public_key = file("${path.module}/terra-key-ansible.pub")
}

data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"]

  filter {
    name   = "name"
    values = ["RHEL-9.*_HVM-*-x86_64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "amazon" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  latest_ami_by_os = {
    ubuntu = data.aws_ami.ubuntu.id
    redhat = data.aws_ami.redhat.id
    amazon = data.aws_ami.amazon.id
  }
}

resource "aws_security_group" "ansible_lab" {
  name        = "ansible-lab-sg"
  description = "Security group for Ansible lab instances"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "ansible-lab-sg"
  }
}

resource "aws_instance" "my_instance" {
  for_each = var.instances

  ami                    = lookup(local.latest_ami_by_os, each.value.os_family, each.value.ami)
  instance_type          = each.value.instance_type
  key_name               = aws_key_pair.ansible.key_name
  vpc_security_group_ids = [aws_security_group.ansible_lab.id]

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
  }

  tags = {
    Name      = each.key
    OSFamily  = each.value.os_family
    ManagedBy = "terraform"
    Project   = "ansible-training"
  }

  depends_on = [aws_security_group.ansible_lab, aws_key_pair.ansible]
}
