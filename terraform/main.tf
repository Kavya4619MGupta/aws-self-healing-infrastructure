locals {
  name_prefix        = "${var.project_name}-${var.environment}"
  generated_key_path = abspath("${path.module}/../.ssh/${local.name_prefix}-key.pem")
  ansible_ssh_key    = var.existing_key_name == "" ? local.generated_key_path : "~/.ssh/${var.existing_key_name}.pem"
}

module "vpc" {
  source = "./modules/vpc"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "security" {
  source = "./modules/security"

  name_prefix            = local.name_prefix
  vpc_id                 = module.vpc.vpc_id
  vpc_cidr               = module.vpc.vpc_cidr
  allowed_ssh_cidr       = var.allowed_ssh_cidr
  allowed_nagios_ui_cidr = var.allowed_nagios_ui_cidr
}

module "compute" {
  source = "./modules/compute"

  name_prefix          = local.name_prefix
  public_subnet_ids    = module.vpc.public_subnet_ids
  private_subnet_ids   = module.vpc.private_subnet_ids
  lb_sg_id             = module.security.lb_sg_id
  nagios_sg_id         = module.security.nagios_sg_id
  web_sg_id            = module.security.web_sg_id
  lb_instance_type     = var.lb_instance_type
  nagios_instance_type = var.nagios_instance_type
  web_instance_type    = var.web_instance_type
  web_node_count       = var.web_node_count
  existing_key_name    = var.existing_key_name
  generated_key_path   = local.generated_key_path
}

# ---------------------------------------------------------------------------
# Generate Ansible inventory from Terraform-provisioned instance metadata
# ---------------------------------------------------------------------------
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/../ansible/inventory/hosts.ini.tpl", {
    lb_server       = module.compute.lb_server
    nagios_server   = module.compute.nagios_server
    web_nodes       = module.compute.web_nodes
    ansible_ssh_key = local.ansible_ssh_key
  })
  filename        = abspath("${path.module}/../ansible/inventory/hosts.ini")
  file_permission = "0644"
}

# ---------------------------------------------------------------------------
# Pass dynamic runtime values (IPs, credentials) to Ansible group_vars
# ---------------------------------------------------------------------------
resource "local_file" "ansible_generated_vars" {
  content = templatefile("${path.module}/../ansible/group_vars/generated.yml.tpl", {
    lb_server             = module.compute.lb_server
    nagios_server         = module.compute.nagios_server
    web_nodes             = module.compute.web_nodes
    nagios_admin_password = var.nagios_admin_password
    alert_email           = var.alert_email
    aws_region            = var.aws_region
    environment           = var.environment
  })
  filename        = abspath("${path.module}/../ansible/group_vars/all/generated.yml")
  file_permission = "0600"
}
