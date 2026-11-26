output "vpc_id" {
  description = "Provisioned VPC ID"
  value       = module.vpc.vpc_id
}

output "ami_id" {
  description = "Ubuntu 24.04 LTS AMI ID used for all instances"
  value       = module.compute.ami_id
}

output "key_name" {
  description = "AWS key pair name attached to all instances"
  value       = module.compute.key_name
}

output "ssh_private_key_path" {
  description = "Path to the SSH private key for Ansible and manual SSH access"
  value       = module.compute.private_key_path
}

output "lb_public_ip" {
  description = "Public IP address of the Nginx Load Balancer"
  value       = module.compute.lb_server.public_ip
}

output "lb_url" {
  description = "HTTP URL of the Nginx Load Balancer"
  value       = "http://${module.compute.lb_server.public_ip}"
}

output "lb_server" {
  description = "Load Balancer instance metadata (public_ip, private_ip, id)"
  value       = module.compute.lb_server
}

output "web_nodes" {
  description = "Detailed metadata of all managed web nodes (private IPs, IDs)"
  value       = module.compute.web_nodes
}

output "nagios_server_ip" {
  description = "Public IP of the Nagios monitoring server"
  value       = module.compute.nagios_server.public_ip
}

output "nagios_public_ip" {
  description = "Public IP of the Nagios monitoring server (alias)"
  value       = module.compute.nagios_server.public_ip
}

output "nagios_dashboard_url" {
  description = "Nagios Web Monitoring UI URL"
  value       = "http://${module.compute.nagios_server.public_ip}/nagios4"
}

output "nagios_server" {
  description = "Nagios server instance metadata (public_ip, private_ip, id)"
  value       = module.compute.nagios_server
}

output "nat_gateway_id" {
  description = "NAT Gateway ID providing outbound internet for private web nodes"
  value       = module.vpc.nat_gateway_id
}

output "ssh_commands" {
  description = "Ready-to-use SSH commands for all public instances"
  value = {
    lb     = "ssh -i ${module.compute.private_key_path != "" ? module.compute.private_key_path : "~/.ssh/${module.compute.key_name}.pem"} ubuntu@${module.compute.lb_server.public_ip}"
    nagios = "ssh -i ${module.compute.private_key_path != "" ? module.compute.private_key_path : "~/.ssh/${module.compute.key_name}.pem"} ubuntu@${module.compute.nagios_server.public_ip}"
  }
}
