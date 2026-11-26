variable "name_prefix" {
  description = "Naming prefix for EC2 instances and key pairs"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs used for LB and Nagios instances"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used for web node instances (no public IP)"
  type        = list(string)
}

variable "lb_sg_id" {
  description = "Security group ID for the Nginx Load Balancer"
  type        = string
}

variable "nagios_sg_id" {
  description = "Security group ID for the Nagios monitoring server"
  type        = string
}

variable "web_sg_id" {
  description = "Security group ID for managed web nodes"
  type        = string
}

variable "lb_instance_type" {
  description = "EC2 instance type for the Load Balancer"
  type        = string
  default     = "t3.micro"
}

variable "nagios_instance_type" {
  description = "EC2 instance type for the Nagios monitoring server"
  type        = string
  default     = "t3.micro"
}

variable "web_instance_type" {
  description = "EC2 instance type for managed web nodes"
  type        = string
  default     = "t3.micro"
}

variable "web_node_count" {
  description = "Number of managed web server nodes to provision"
  type        = number
  default     = 2
}

variable "existing_key_name" {
  description = "Existing EC2 key pair name (leave empty to auto-generate a new key)"
  type        = string
  default     = ""
}

variable "generated_key_path" {
  description = "Local filesystem path where the generated private key will be saved"
  type        = string
}
