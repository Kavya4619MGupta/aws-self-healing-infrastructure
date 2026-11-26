[lb_server]
${lb_server.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=${ansible_ssh_key}

[web_nodes]
%{ for node in web_nodes ~}
${node.private_ip} ansible_user=ubuntu ansible_ssh_private_key_file=${ansible_ssh_key}
%{ endfor ~}

[web_nodes:vars]
ansible_ssh_common_args=-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -W %h:%p -q ubuntu@${lb_server.public_ip} -i ${ansible_ssh_key} -o StrictHostKeyChecking=no"

[nagios_server]
${nagios_server.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=${ansible_ssh_key}

[all:vars]
ansible_python_interpreter=/usr/bin/python3
