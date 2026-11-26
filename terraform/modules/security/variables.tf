variable "name_prefix" {
  description = "Naming prefix applied to all security group resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID in which to create the security groups"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC (used for internal-only rules)"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block permitted to SSH into public instances (restrict to your IP/32 in production)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "allowed_nagios_ui_cidr" {
  description = "CIDR block permitted to access the Nagios Web Dashboard on port 80"
  type        = string
  default     = "0.0.0.0/0"
}
