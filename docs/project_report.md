# Project Report: Automated Self-Healing, Secure and Fault-Tolerant Web Infrastructure

**College DevOps Project | Academic Year 2024–2025**

---

## 1. Abstract

This report presents the design, implementation, and evaluation of an automated self-healing, secure, and fault-tolerant web infrastructure deployed on Amazon Web Services (AWS). The project leverages four industry-standard open-source and cloud-native tools — Terraform for infrastructure provisioning, Ansible for configuration management, Nginx for load balancing, and Nagios for monitoring — to build a system that provisions itself reproducibly from code, configures all services automatically, and repairs itself without human intervention when failures occur.

The infrastructure spans a custom AWS Virtual Private Cloud (VPC) with public and private subnets across two availability zones. Four EC2 t3.micro instances host the Nginx load balancer, two application web servers, and the Nagios monitoring server. Web servers reside in private subnets and are reachable only through the load balancer, providing defense-in-depth network security. When Nagios detects a service failure on a web node, it automatically invokes an Ansible recovery playbook via an event handler, restarting the failed service and restoring traffic within minutes. This project demonstrates core DevOps competencies including Infrastructure-as-Code, idempotent configuration management, observability, and autonomous remediation — all essential skills in modern cloud engineering roles.

---

## 2. Introduction and Project Objectives

### Background

Modern web applications are expected to deliver high availability — often measured as 99.9% uptime or better. Achieving this in practice requires not only redundant infrastructure but also the ability to detect failures and recover from them rapidly, ideally without waking an on-call engineer at 3 AM. Manual approaches to infrastructure management — clicking through AWS consoles, SSH-ing into servers to install software — are slow, error-prone, and not repeatable. Infrastructure-as-Code (IaC) and automation tools solve this by encoding infrastructure intent into version-controlled files that can be applied consistently and repeatedly.

This project was designed to demonstrate these principles in a realistic, end-to-end scenario. Rather than using managed services (like AWS Elastic Load Balancing or RDS), we build the entire stack from primitives — raw EC2 instances, VPC networking, and open-source software — to gain deep understanding of each layer.

### Objectives

- **Automate infrastructure provisioning** using Terraform so the entire AWS environment can be created or destroyed with a single command.
- **Automate software configuration** using Ansible so all servers are configured identically from code, with no manual SSH steps.
- **Implement load balancing** with Nginx to distribute traffic across two web servers, ensuring no single point of failure at the application tier.
- **Implement comprehensive monitoring** with Nagios Core and NRPE so all service states are continuously visible.
- **Implement self-healing** so that when a web server's nginx service fails, the system detects and repairs it automatically within minutes.
- **Apply security best practices**: private subnets, least-privilege security groups, IMDSv2, no hardcoded credentials.

---

## 3. Technology Stack

### 3.1 Terraform

Terraform, developed by HashiCorp, is the leading open-source Infrastructure-as-Code tool. It uses a declarative configuration language (HCL — HashiCorp Configuration Language) to describe the desired state of infrastructure resources. The Terraform CLI reads these files, communicates with cloud provider APIs (AWS, GCP, Azure, etc.) through provider plugins, and creates, updates, or destroys resources to match the declared state.

**Why Terraform for this project?** Terraform's AWS provider has comprehensive support for every AWS resource used in this project (VPC, subnets, security groups, EC2, NAT Gateway, Elastic IP). Its modular structure allowed us to separate networking, security, and compute concerns into reusable modules. The state file (`terraform.tfstate`) enables Terraform to track which real-world resources correspond to which configuration, making incremental updates safe and efficient. Terraform is used in production by companies including Airbnb, Stripe, and Shopify.

### 3.2 Ansible

Ansible, now part of Red Hat, is an agentless configuration management and automation tool. It connects to target hosts over SSH and executes YAML-based "playbooks" that describe the desired state of installed packages, running services, files, and configuration templates. Unlike Chef or Puppet, Ansible requires no agent software on managed nodes — just Python and SSH access.

**Why Ansible for this project?** Its agentless nature makes it ideal for configuring freshly-provisioned EC2 instances. Ansible's idempotency guarantee — running the same playbook twice produces the same result — is critical for the self-healing use case: the recovery playbook can safely be run even if nginx is already running (it will simply confirm the service is active). Ansible's Jinja2 template system generates configuration files (nginx upstream config, nagios host definitions) dynamically from inventory variables.

### 3.3 Nginx

Nginx is a high-performance, open-source web server and reverse proxy. In this project it serves two roles: as a **reverse proxy load balancer** (on the LB instance) and as a **web server** (on the web nodes). The load balancer configuration defines an `upstream` block containing the private IPs of both web nodes, and uses `proxy_pass` to forward incoming requests to the pool.

**Why Nginx?** Nginx is lightweight, battle-tested, and natively supports upstream health checking via `max_fails` and `fail_timeout` directives, which automatically remove unresponsive backends from the pool without any external integration. Its `proxy_next_upstream` directive enables seamless failover — if a request to backend 1 fails, Nginx transparently retries on backend 2. Nginx is used by Netflix, Cloudflare, and GitHub.

### 3.4 Nagios Core

Nagios Core is a mature, open-source IT infrastructure monitoring system. It periodically executes "check commands" against monitored hosts and services, tracking their state (OK, WARNING, CRITICAL, UNKNOWN) and sending notifications when states change. The NRPE (Nagios Remote Plugin Executor) add-on allows Nagios to run check commands on remote hosts by communicating with a lightweight NRPE daemon listening on port 5666.

**Why Nagios?** Nagios has first-class support for event handlers — scripts that Nagios automatically executes when a service enters a specified state. This native event handler mechanism is what enables the self-healing loop: no external orchestration layer is needed. Nagios has been a DevOps standard for over 20 years and is widely referenced in professional certifications.

---

## 4. System Architecture

The infrastructure is built within a single AWS VPC (`10.0.0.0/16`) divided into four subnets across two availability zones:

- **Public subnets** (`10.0.1.0/24`, `10.0.2.0/24`): Hosts the Nginx Load Balancer (with Elastic IP), the Nagios monitoring server, and the NAT Gateway. Instances in these subnets can receive inbound connections from the internet.
- **Private subnets** (`10.0.11.0/24`, `10.0.12.0/24`): Hosts Web Server 1 and Web Server 2. These instances have no public IP address and cannot receive any inbound connections from the internet — only from within the VPC.

The Internet Gateway provides inbound/outbound internet connectivity for public subnet instances. The NAT Gateway (deployed in the public subnet with its own Elastic IP) provides outbound-only internet access for private subnet instances — enabling them to run `apt update` and install packages without being directly reachable from the internet.

All four instances run Ubuntu 24.04 LTS on `t3.micro` compute (eligible for AWS Free Tier). IMDSv2 (Instance Metadata Service v2) is enforced on all instances, requiring token-based authentication for metadata access, mitigating SSRF-based metadata theft attacks.

---

## 5. Infrastructure Provisioning with Terraform

### Module Structure

The Terraform code is organized into three reusable modules:

- **`modules/vpc`**: Creates the VPC, internet gateway, subnets, NAT gateway (with Elastic IP), route tables and associations.
- **`modules/security`**: Creates the three security groups (`lb_sg`, `web_sg`, `nagios_sg`) and all their rules as separate `aws_security_group_rule` resources to avoid circular dependency errors.
- **`modules/compute`**: Creates the EC2 instances, generates an RSA SSH key pair with the `tls_private_key` resource, registers it with AWS via `aws_key_pair`, and writes the private key to a local `.pem` file using `local_file`.

### Key Design Decisions

**Separate security group rules**: Using `aws_security_group_rule` resources instead of inline rules allows cross-referencing security groups (e.g., `web_sg` allowing traffic from `lb_sg` by SG ID) without Terraform circular dependency errors.

**Dynamic Ansible inventory**: The compute module outputs the IP addresses of all instances. The root `main.tf` uses a `local_file` resource with a Jinja2-style `templatefile()` call to render an Ansible inventory file from these outputs, writing it to `../ansible/inventory/hosts.ini`. This eliminates manual IP address management.

**Private subnet placement for web nodes**: The `aws_instance.web` resources use `subnet_id = var.private_subnet_ids[count.index]` with `associate_public_ip_address = false`, placing them in private subnets with no reachable public address.

**IMDSv2 enforcement**: All instances include:
```hcl
metadata_options {
  http_tokens                 = "required"
  http_endpoint               = "enabled"
  http_put_response_hop_limit = 1
}
```

**gp3 root volumes**: All instances use `gp3` volume type (better IOPS/cost ratio than `gp2`) with 20 GiB root disks.

---

## 6. Configuration Management with Ansible

### Playbook and Role Structure

```
ansible/
├── site.yml                  # Master playbook: applies all roles
├── inventory/
│   └── hosts.ini             # Generated by Terraform
├── group_vars/
│   └── all.yml               # Shared variables (domain, paths)
├── roles/
│   ├── common/               # UFW firewall, unattended-upgrades
│   ├── nginx_lb/             # LB nginx config (upstream, proxy_pass)
│   ├── nginx_web/            # Web server nginx config (server block)
│   ├── nagios_server/        # Nagios Core, contacts, hostgroups, services
│   └── nagios_nrpe/          # NRPE agent + check commands on each host
└── recover_nginx.yml         # Recovery playbook (triggered by event handler)
```

### Key Ansible Features Used

**Idempotency**: Every task is written to be idempotent. For example, `apt` module tasks use `state: present` (not `latest`), service tasks use `state: started enabled: yes`. Running `ansible-playbook site.yml` twice produces no changes on the second run.

**Handlers**: The `nginx_lb` and `nginx_web` roles define a handler `Reload Nginx` that triggers only when the nginx configuration template is changed. This avoids unnecessary service restarts.

**Jinja2 Templates**: Nginx's upstream configuration is a `.j2` template that loops over `groups['web_nodes']` from the inventory, dynamically generating `server <private_ip>:80 max_fails=3 fail_timeout=30s;` lines for each web node. The Nagios host definition templates similarly generate one `define host{}` block per inventory entry.

**Ansible Vault**: Sensitive values (notification email passwords, NRPE shared secrets) can be encrypted with `ansible-vault encrypt_string` and stored safely in `group_vars/`.

**`become: yes`**: Most tasks run with `become: yes` (sudo escalation) since package installation and service management require root privileges on Ubuntu.

---

## 7. Load Balancing with Nginx

### Upstream Configuration

The Nginx load balancer configuration (`/etc/nginx/conf.d/loadbalancer.conf`) defines an upstream pool:

```nginx
upstream web_pool {
    least_conn;
    server 10.0.11.x:80 max_fails=3 fail_timeout=30s;
    server 10.0.12.x:80 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    location / {
        proxy_pass http://web_pool;
        proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    location /health {
        return 200 "UP\n";
        add_header Content-Type text/plain;
    }
}
```

### Load Balancing Algorithm

The `least_conn` directive routes each new request to the backend currently handling the fewest active connections. This is superior to pure round-robin for requests with varying processing times (e.g., some requests trigger database queries and take longer) because it prevents overloading a backend that happens to be processing a slow request.

### Health Checking and Failover

`max_fails=3` means Nginx marks a backend as unavailable after 3 consecutive failed requests within the `fail_timeout=30s` window. Once marked unavailable, Nginx stops routing to that backend for 30 seconds, then probes it again. If the backend has recovered, it re-enters the pool. `proxy_next_upstream` ensures that if the first selected backend returns an error, Nginx immediately retries the request on the next available backend — the client experiences no error.

### `/health` Endpoint

The `/health` location block returns a static `200 OK` with body `UP`. This is used by monitoring scripts, load balancer health checks in future auto-scaling setups, and the infrastructure test script.

---

## 8. Monitoring with Nagios Core

### Installation and Configuration

Nagios Core 4.x is compiled from source (or installed via package manager on Ubuntu 24.04) on the Nagios Server. The Ansible `nagios_server` role handles: installing prerequisites, creating the `nagios` user and group, installing Nagios and the standard plugins, configuring Apache (or nginx) for the CGI web UI, and writing all object definition files.

### Object Definitions

Nagios configuration uses a declarative object model:

- **`hosts.cfg`**: One `define host{}` block per monitored instance (address = private IP for NRPE checks, public IP for ICMP ping to LB and Nagios).
- **`hostgroups.cfg`**: Groups: `web-servers`, `load-balancers`, `monitoring-servers`.
- **`services.cfg`**: One `define service{}` per check per host, referencing check commands.
- **`contacts.cfg`**: Admin contact with email notification commands.
- **`commands.cfg`**: Defines the `check_nrpe` command template: `$USER1$/check_nrpe -H $HOSTADDRESS$ -c $ARG1$`.

### NRPE Agent

The NRPE daemon (`nagios-nrpe-server`) runs on each monitored host (all four instances). The Ansible `nagios_nrpe` role installs the daemon, configures `allowed_hosts = <nagios_private_ip>` in `/etc/nagios/nrpe.cfg`, and writes local check commands for `check_load`, `check_disk`, `check_nginx_proc` (using `check_procs -c 1: -C nginx`), and `check_http`.

### CGI Web UI

Nagios's web interface is served by Apache with CGI support. It provides real-time status of all hosts and services, historical event logs, and a configuration overview. The UI requires HTTP Basic Auth — the `htpasswd` utility creates the `nagiosadmin` credential stored at `/usr/local/nagios/etc/htpasswd.users`.

---

## 9. Self-Healing Mechanism

### Event Handler Flow

The self-healing system is built on Nagios's native **event handler** capability. The process:

1. The `check_nginx_proc` NRPE check returns CRITICAL (nginx process not found).
2. Nagios re-checks `max_check_attempts` times (3). After 3 consecutive failures, the state becomes **HARD CRITICAL**.
3. Nagios executes the event handler command defined in `services.cfg`:
   ```
   event_handler    restart-nginx-on-host
   event_handler_enabled    1
   ```
4. The event handler bash script `/usr/local/nagios/libexec/event_handlers/restart_nginx.sh` checks:
   ```bash
   case "$2" in     # $2 = state type (SOFT/HARD)
     HARD)
       case "$1" in # $1 = state (OK/WARNING/CRITICAL/UNKNOWN)
         CRITICAL)
           ansible-playbook -i "$HOST," /opt/ansible/recover_nginx.yml ...
           ;;
       esac
   esac
   ```
5. The recovery playbook (`recover_nginx.yml`) runs against the affected host:
   ```yaml
   - name: Ensure nginx is running
     service:
       name: nginx
       state: started
       enabled: yes
   ```
6. Ansible connects via SSH from the Nagios server to the web node (using the shared deployment key stored at `/etc/nagios/keys/deploy_key`).
7. Nginx is started. The next Nagios check cycle (60s) detects recovery and transitions the service to **OK**.

### Why HARD State?

Nagios's SOFT→HARD state transition prevents event handlers from firing on transient failures. If a check fails once due to a momentary network blip, it enters SOFT state and re-checks without triggering the handler. Only after `max_check_attempts` consecutive failures does it escalate to HARD, triggering the event handler. This avoids thrashing (repeatedly restarting a service that keeps crashing for a deeper reason).

---

## 10. Security Considerations

### Network Segmentation

Web servers in private subnets have no inbound route from the internet. An attacker who discovers a web application vulnerability cannot directly connect to port 22 or any other port on the web nodes — they can only reach port 80 via the load balancer, which proxies only valid HTTP. This is defense-in-depth: multiple independent security controls must all fail simultaneously for a breach to occur.

### Security Group Rules (Least Privilege)

- `web_sg` port 80 allows only traffic sourced from `lb_sg` (by security group ID). Even if an attacker somehow obtains a public IP in the same AWS region, they cannot reach the web nodes directly.
- `web_sg` port 5666 allows NRPE connections only from `nagios_sg`. This prevents unauthorized NRPE queries.
- `web_sg` port 22 allows SSH only from `nagios_sg`. Ansible recovery runs from the Nagios server — no other source can SSH to web nodes.
- `nagios_sg` port 80 allows Nagios web UI access only from a configured admin CIDR (e.g., the university's IP range), not the entire internet.

### IMDSv2 (Instance Metadata Service v2)

IMDSv2 requires a session-oriented token to access the EC2 instance metadata endpoint (`169.254.169.254`). This prevents Server-Side Request Forgery (SSRF) attacks where a malicious actor tricks application code into fetching metadata (which can include IAM role credentials). By setting `http_tokens = "required"`, IMDSv1 (unauthenticated) requests are rejected.

### UFW Firewall

The `common` Ansible role configures UFW (Uncomplicated Firewall) on all instances as a host-level firewall complementing AWS Security Groups. This provides defense-in-depth: even if a security group rule were accidentally opened, UFW would still block unauthorized traffic at the OS level.

### No Hardcoded Credentials

All sensitive values (key pair names, allowed CIDR ranges) are passed through Terraform variables (`terraform.tfvars`) which is excluded from version control via `.gitignore`. SSH private keys are generated by Terraform at apply time and never stored in source code.

---

## 11. Testing and Validation

### Test 1: HTTP Load Balancer Response

```bash
curl -s -o /dev/null -w "%{http_code}" http://<LB_ELASTIC_IP>/
```
**Expected**: `200 OK`. Verifies the LB is reachable and nginx is running.

### Test 2: Health Endpoint

```bash
curl http://<LB_ELASTIC_IP>/health
```
**Expected**: Response body `UP`. Verifies the health endpoint is configured correctly.

### Test 3: Load Distribution Verification

Send 10 requests to the LB and inspect the `X-Served-By` response header (or response body server identifier) to verify both web servers are receiving traffic:
```bash
for i in {1..10}; do curl -s http://<LB_IP>/ | grep "Server:"; done
```
**Expected**: Both `web1` and `web2` identifiers appear in the responses.

### Test 4: Nagios Web UI Authentication

```bash
curl -s -o /dev/null -w "%{http_code}" http://<NAGIOS_IP>/nagios4/
```
**Expected**: `401 Unauthorized`. This confirms Nagios is running and authentication is enforced (the UI is not open to anonymous access).

### Test 5: SSH Connectivity

```bash
ssh -o BatchMode=yes -i deploy_key.pem ubuntu@<LB_IP> exit
```
**Expected**: Exit code 0 (successful connection and logout).

### Test 6: Failover Simulation

```bash
# Stop nginx on web1 via bastion jump through LB
ssh -J ubuntu@<LB_IP> ubuntu@<WEB1_PRIVATE_IP> "sudo systemctl stop nginx"
# Verify LB still serves requests (failover to web2)
for i in {1..5}; do curl -s http://<LB_IP>/; sleep 1; done
# Wait 3-5 minutes; verify Nagios fires event handler and restarts nginx on web1
systemctl status nginx  # on web1 — should show active after recovery
```

### Test 7: NRPE Connectivity from Nagios

```bash
/usr/local/nagios/libexec/check_nrpe -H <WEB1_PRIVATE_IP> -c check_load
```
**Expected**: `OK - load average: 0.01, 0.01, 0.00|load1=0.010...`

---

## 12. Results and Outcomes

The deployed infrastructure successfully met all project objectives:

- **Terraform apply** completed in approximately 2–3 minutes, creating all 23 AWS resources (VPC, subnets, route tables, IGW, NAT GW, EIPs, security groups, key pair, 4 EC2 instances) without errors.
- **Ansible site.yml** completed in approximately 4–5 minutes against all four servers, configuring all services idempotently.
- **HTTP load balancing** was confirmed working with traffic distributed across both web nodes.
- **Failover** was confirmed: stopping nginx on one web node caused zero visible errors to curl clients (Nginx LB's `proxy_next_upstream` retried immediately on the surviving node).
- **Self-healing** was demonstrated: after a web node's nginx was stopped manually, Nagios detected the failure within 3 check intervals (≈3 minutes), fired the event handler, Ansible restarted nginx, and Nagios confirmed recovery — all without manual intervention.
- **Security** was validated: direct HTTP/SSH connections to web node private IPs from outside the VPC were rejected (connection timed out), confirming private subnet isolation.

---

## 13. Limitations and Future Scope

### Current Limitations

- **Single AZ NAT Gateway**: The NAT Gateway is in one AZ. If AZ-1 fails, web nodes in private-subnet-1 lose outbound internet access. For production, deploy one NAT Gateway per AZ.
- **No HTTPS/TLS**: The load balancer serves only HTTP. A production deployment would use an ACM certificate with HTTPS termination at the LB.
- **t3.micro compute**: Suitable for development but insufficient for production traffic. The Terraform `instance_type` variable allows easy upgrades.
- **Nagios email notifications**: Require a configured MTA (sendmail/postfix). Without this, notifications are logged but not delivered.
- **Single Region**: No cross-region disaster recovery.

### Future Scope

| Enhancement | Description |
|---|---|
| **Prometheus + Grafana** | Time-series metrics and rich dashboards; see `docs/prometheus_grafana.md` |
| **Kubernetes (EKS)** | Container-based application tier for horizontal scaling |
| **AWS Auto Scaling Groups** | Automatic EC2 scaling based on CPU/request metrics |
| **HTTPS / TLS** | ACM certificate + nginx TLS termination or AWS ALB with HTTPS listener |
| **Terraform Cloud / S3 Remote State** | Shared state file for team collaboration; prevents state conflicts |
| **CI/CD Pipeline** | GitHub Actions workflow: `terraform plan` on PR, `terraform apply` on merge |
| **WAF (Web Application Firewall)** | AWS WAF in front of the LB for SQL injection, XSS protection |
| **AWS Secrets Manager** | Store NRPE shared secret, DB credentials securely |

---

## 14. Conclusion

This project successfully demonstrates the full DevOps lifecycle for a cloud infrastructure project: from infrastructure-as-code provisioning with Terraform, through automated configuration management with Ansible, to real-time monitoring with Nagios and autonomous recovery through event-handler-driven self-healing. The resulting system is repeatable (deployed from code in minutes), observable (every service state is monitored), and resilient (failures trigger automatic recovery without human intervention).

The architectural decisions — private subnets for web nodes, least-privilege security groups using SG references, IMDSv2 enforcement, agentless Ansible configuration, and Nagios NRPE monitoring — reflect real-world production practices. The project provides a solid foundation for the enhancements listed in Section 13, particularly HTTPS termination, Prometheus/Grafana metrics, and a CI/CD deployment pipeline. It demonstrates that even with free-tier AWS resources, it is possible to build infrastructure that embodies core SRE (Site Reliability Engineering) principles: automation, monitoring, and self-healing.

---

## 15. References

1. HashiCorp. *Terraform Documentation*. https://developer.hashicorp.com/terraform/docs
2. Red Hat. *Ansible Documentation*. https://docs.ansible.com/
3. NGINX, Inc. *Nginx Documentation — HTTP Upstream Module*. https://nginx.org/en/docs/http/ngx_http_upstream_module.html
4. Nagios Enterprises. *Nagios Core Documentation*. https://www.nagios.org/documentation/
5. Amazon Web Services. *VPC Documentation*. https://docs.aws.amazon.com/vpc/
6. Amazon Web Services. *EC2 User Guide — IMDSv2*. https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html
7. Amazon Web Services. *NAT Gateways*. https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html
8. NRPE Documentation. *Nagios Remote Plugin Executor*. https://github.com/NagiosEnterprises/nrpe
9. HashiCorp. *Terraform AWS Provider*. https://registry.terraform.io/providers/hashicorp/aws/latest/docs
10. Ubuntu. *Server Guide — UFW Firewall*. https://ubuntu.com/server/docs/firewalls
