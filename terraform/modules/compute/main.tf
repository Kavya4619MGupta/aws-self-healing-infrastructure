data "aws_ami" "ubuntu_24_04" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  use_generated_key = var.existing_key_name == ""
  key_name          = local.use_generated_key ? aws_key_pair.generated[0].key_name : var.existing_key_name
}

# ---------------------------------------------------------------------------
# SSH Key Pair (auto-generated when existing_key_name is not provided)
# ---------------------------------------------------------------------------

resource "tls_private_key" "generated" {
  count = local.use_generated_key ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated" {
  count = local.use_generated_key ? 1 : 0

  key_name   = "${var.name_prefix}-key"
  public_key = tls_private_key.generated[0].public_key_openssh
}

resource "local_file" "private_key" {
  count = local.use_generated_key ? 1 : 0

  content         = tls_private_key.generated[0].private_key_pem
  filename        = var.generated_key_path
  file_permission = "0600"
}

# ---------------------------------------------------------------------------
# Load Balancer — public subnet, public IP
# ---------------------------------------------------------------------------

resource "aws_instance" "lb" {
  ami                         = data.aws_ami.ubuntu_24_04.id
  instance_type               = var.lb_instance_type
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.lb_sg_id]
  key_name                    = local.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 10
    delete_on_termination = true
  }

  metadata_options {
    http_tokens = "required" # Enforce IMDSv2
  }

  tags = {
    Name = "${var.name_prefix}-lb-server"
    Role = "lb"
  }
}

# ---------------------------------------------------------------------------
# Web Nodes — private subnets, NO public IP
# ---------------------------------------------------------------------------

resource "aws_instance" "web" {
  count = var.web_node_count

  ami                         = data.aws_ami.ubuntu_24_04.id
  instance_type               = var.web_instance_type
  subnet_id                   = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]
  vpc_security_group_ids      = [var.web_sg_id]
  key_name                    = local.key_name
  associate_public_ip_address = false

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 10
    delete_on_termination = true
  }

  metadata_options {
    http_tokens = "required" # Enforce IMDSv2
  }

  tags = {
    Name = "${var.name_prefix}-web-node-${count.index + 1}"
    Role = "webserver"
  }
}

# ---------------------------------------------------------------------------
# Nagios Server — public subnet, public IP
# ---------------------------------------------------------------------------

resource "aws_instance" "nagios" {
  ami                         = data.aws_ami.ubuntu_24_04.id
  instance_type               = var.nagios_instance_type
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.nagios_sg_id]
  key_name                    = local.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 12
    delete_on_termination = true
  }

  metadata_options {
    http_tokens = "required" # Enforce IMDSv2
  }

  tags = {
    Name = "${var.name_prefix}-nagios-server"
    Role = "nagios"
  }
}
