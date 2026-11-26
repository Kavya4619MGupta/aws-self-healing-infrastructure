output "ami_id" {
  description = "Ubuntu 24.04 LTS AMI ID resolved for the target region"
  value       = data.aws_ami.ubuntu_24_04.id
}

output "key_name" {
  description = "AWS key pair name attached to all instances"
  value       = local.key_name
}

output "private_key_path" {
  description = "Filesystem path of the generated SSH private key (empty when using an existing key)"
  value       = local.use_generated_key ? var.generated_key_path : ""
}

output "lb_server" {
  description = "Load Balancer instance metadata"
  value = {
    public_ip  = aws_instance.lb.public_ip
    private_ip = aws_instance.lb.private_ip
    id         = aws_instance.lb.id
  }
}

output "web_nodes" {
  description = "List of web node instance metadata (private subnet, no public IP)"
  value = [for w in aws_instance.web : {
    public_ip  = w.public_ip
    private_ip = w.private_ip
    id         = w.id
  }]
}

output "nagios_server" {
  description = "Nagios monitoring server instance metadata"
  value = {
    public_ip  = aws_instance.nagios.public_ip
    private_ip = aws_instance.nagios.private_ip
    id         = aws_instance.nagios.id
  }
}
