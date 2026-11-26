# ---------------------------------------------------------------------------
# Security Groups — defined with no inline rules to prevent dependency cycles
# Rules are attached via separate aws_security_group_rule resources below.
# ---------------------------------------------------------------------------

resource "aws_security_group" "lb_sg" {
  name        = "${var.name_prefix}-lb-sg"
  description = "Security group for the Nginx Load Balancer (public-facing)"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-lb-sg"
  }
}

resource "aws_security_group" "web_sg" {
  name        = "${var.name_prefix}-web-sg"
  description = "Security group for private web nodes (Nginx backend)"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-web-sg"
  }
}

resource "aws_security_group" "nagios_sg" {
  name        = "${var.name_prefix}-nagios-sg"
  description = "Security group for the Nagios Monitoring Server"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-nagios-sg"
  }
}

# ---------------------------------------------------------------------------
# LB Security Group Rules
# ---------------------------------------------------------------------------

resource "aws_security_group_rule" "lb_ingress_http" {
  type              = "ingress"
  description       = "Public HTTP traffic"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lb_sg.id
}

resource "aws_security_group_rule" "lb_ingress_https" {
  type              = "ingress"
  description       = "Public HTTPS traffic"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lb_sg.id
}

resource "aws_security_group_rule" "lb_ingress_ssh" {
  type              = "ingress"
  description       = "SSH admin access"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.allowed_ssh_cidr]
  security_group_id = aws_security_group.lb_sg.id
}

resource "aws_security_group_rule" "lb_egress_all" {
  type              = "egress"
  description       = "Allow all outbound traffic"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lb_sg.id
}

# ---------------------------------------------------------------------------
# Web Security Group Rules
# ---------------------------------------------------------------------------

resource "aws_security_group_rule" "web_ingress_http_from_lb" {
  type                     = "ingress"
  description              = "HTTP from Load Balancer only"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb_sg.id
  security_group_id        = aws_security_group.web_sg.id
}

resource "aws_security_group_rule" "web_ingress_nrpe_from_nagios" {
  type                     = "ingress"
  description              = "NRPE monitoring queries from Nagios"
  from_port                = 5666
  to_port                  = 5666
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.nagios_sg.id
  security_group_id        = aws_security_group.web_sg.id
}

resource "aws_security_group_rule" "web_ingress_ssh_from_nagios" {
  type                     = "ingress"
  description              = "SSH from Nagios server (bastion / event handler)"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.nagios_sg.id
  security_group_id        = aws_security_group.web_sg.id
}

resource "aws_security_group_rule" "web_ingress_ssh_from_lb" {
  type                     = "ingress"
  description              = "SSH from Load Balancer (bastion jump host)"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb_sg.id
  security_group_id        = aws_security_group.web_sg.id
}

resource "aws_security_group_rule" "web_egress_all" {
  type              = "egress"
  description       = "Allow all outbound traffic"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web_sg.id
}

# ---------------------------------------------------------------------------
# Nagios Security Group Rules
# ---------------------------------------------------------------------------

resource "aws_security_group_rule" "nagios_ingress_http" {
  type              = "ingress"
  description       = "Nagios web UI access"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [var.allowed_nagios_ui_cidr]
  security_group_id = aws_security_group.nagios_sg.id
}

resource "aws_security_group_rule" "nagios_ingress_ssh" {
  type              = "ingress"
  description       = "SSH admin access to Nagios server"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.allowed_ssh_cidr]
  security_group_id = aws_security_group.nagios_sg.id
}

resource "aws_security_group_rule" "nagios_egress_all" {
  type              = "egress"
  description       = "Allow all outbound traffic"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nagios_sg.id
}
