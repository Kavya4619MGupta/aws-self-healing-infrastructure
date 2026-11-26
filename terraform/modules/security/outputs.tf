output "lb_sg_id" {
  description = "Security group ID for the Nginx Load Balancer"
  value       = aws_security_group.lb_sg.id
}

output "web_sg_id" {
  description = "Security group ID for private web nodes"
  value       = aws_security_group.web_sg.id
}

output "nagios_sg_id" {
  description = "Security group ID for the Nagios Monitoring Server"
  value       = aws_security_group.nagios_sg.id
}
