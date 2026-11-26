variable "project_name" {
  description = "Name prefix for all created AWS resources"
  type        = string
  default     = "aws-auto-infra"
}

variable "environment" {
  description = "Deployment environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region to deploy infrastructure into"
  type        = string
  default     = "eu-north-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the custom VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets across AZs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets across AZs (used by web nodes)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "lb_instance_type" {
  description = "EC2 instance type for the Nginx Load Balancer"
  type        = string
  default     = "t3.micro"
}

variable "nagios_instance_type" {
  description = "EC2 instance type for the Nagios monitoring server (t3.micro is free-tier eligible)"
  type        = string
  default     = "t3.micro"
}

variable "web_instance_type" {
  description = "EC2 instance type for the managed web nodes"
  type        = string
  default     = "t3.micro"
}

variable "web_node_count" {
  description = "Number of managed web server nodes to provision"
  type        = number
  default     = 2
}

variable "existing_key_name" {
  description = "Optional existing EC2 key pair name in the target region. Leave empty to auto-generate a new SSH key pair."
  type        = string
  default     = ""
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into EC2 instances (restrict to your IP/32 in production)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "allowed_nagios_ui_cidr" {
  description = "CIDR allowed to access the Nagios Web Dashboard (port 80)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "nagios_admin_password" {
  description = "Password for the nagiosadmin web UI user (override via TF_VAR_nagios_admin_password or tfvars)"
  type        = string
  sensitive   = true
  default     = "ChangeMeNagios123!"
}

variable "alert_email" {
  description = "Email address for Nagios alert notifications"
  type        = string
  default     = "admin@example.com"
}
