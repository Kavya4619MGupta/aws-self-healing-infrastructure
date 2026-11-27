---
lb_server:
  public_ip: "${lb_server.public_ip}"
  private_ip: "${lb_server.private_ip}"
  id: "${lb_server.id}"
nagios_private_ip: "${nagios_server.private_ip}"
nagios_public_ip: "${nagios_server.public_ip}"
web_nodes:
%{ for node in web_nodes ~}
  - private_ip: "${node.private_ip}"
    id: "${node.id}"
%{ endfor ~}
nagios_admin_password: "${nagios_admin_password}"
alert_email: "${alert_email}"
aws_region: "${aws_region}"
environment: "${environment}"
