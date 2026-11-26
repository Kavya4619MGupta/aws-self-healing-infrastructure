# College Project Viva & Interview Questions with Answers
## Automated Self-Healing, Secure and Fault-Tolerant Web Infrastructure Using AWS, Terraform, Ansible, Nginx and Nagios

---

### Section 1: DevOps & Architectural Concepts

#### Q1. What is the core problem this project solves?
**Answer:** In traditional IT operations, service outages require manual detection, human triage, and manual intervention (e.g., system administrator SSH-ing into a server to restart a crashed service). This leads to high Mean Time to Recovery (MTTR) and business downtime. This project implements an **automated, self-healing, fault-tolerant architecture** on AWS where:
1. Nginx load balancing ensures zero downtime for end-users when a backend node fails.
2. Nagios Core detects service degradation via automated polling.
3. Event handlers automatically trigger targeted Ansible remediation playbooks to restore the failed service without human intervention.
4. Infrastructure as Code (Terraform) and Configuration Management (Ansible) guarantee repeatability and eliminate configuration drift.

#### Q2. What is the difference between Fault Tolerance, High Availability, and Self-Healing?
**Answer:**
- **High Availability (HA):** Designing a system to remain operational and accessible with minimal downtime (e.g., 99.9% uptime) across redundant components.
- **Fault Tolerance (FT):** The system's ability to continue operating properly without interruption even when one or more underlying components fail. In our project, Nginx's `least_conn` upstream pool with `proxy_next_upstream` provides fault tolerance because requests to a failed backend are instantly routed to the surviving healthy backend.
- **Self-Healing:** An autonomous feedback loop that actively detects component failure and triggers programmatic workflows to remediate or replace the broken resource, returning the system to its intended desired state without manual engineer intervention.

#### Q3. What is Infrastructure as Code (IaC) versus Configuration Management (CM)?
**Answer:**
- **IaC (Terraform):** Focuses on provisioning, modifying, and destroying foundational infrastructure components (VPC, subnets, route tables, internet gateways, NAT gateways, security groups, EC2 instances). It treats infrastructure as declarative definitions versioned in Git.
- **CM (Ansible):** Focuses on configuring the operating systems, installing software packages, templating application configuration files, managing system services, and applying security baselines once the infrastructure is provisioned.

#### Q4. Why use Terraform and Ansible together rather than doing everything in Terraform?
**Answer:** Terraform is designed for stateful resource lifecycle management using declarative cloud APIs. While Terraform has `local-exec` and `remote-exec` provisioners, they lack idempotency controls, state drift handling for OS packages, granular error recovery, and role modularity. Ansible is agentless, uses YAML playbooks, has rich modules for system administration (`apt`, `service`, `template`, `lineinfile`), and excels at multi-host configuration orchestration. Using Terraform for day-0 provisioning and Ansible for day-1 configuration and day-2 automated recovery provides the best separation of concerns.

#### Q5. What is idempotency and why is it vital in DevOps?
**Answer:** An operation is idempotent if executing it multiple times produces the exact same result as executing it once, without causing unintended side effects. For example, in Ansible, ensuring `nginx` is `started` will only take action if Nginx is stopped; running the playbook a second time results in `ok` with 0 changed tasks. This is vital for self-healing and CI/CD pipelines because scripts can be re-run safely at any time.

---

### Section 2: AWS Networking & Security Architecture

#### Q6. Explain the VPC design in this project.
**Answer:**
The project deploys a custom AWS VPC with a `10.0.0.0/16` CIDR block spanning two Availability Zones (AZs) for high availability:
- **Public Subnet 1 (`10.0.1.0/24`)** in AZ 1: Hosts the public-facing Nginx Load Balancer and the NAT Gateway.
- **Public Subnet 2 (`10.0.2.0/24`)** in AZ 2: Hosts the Nagios Monitoring Server.
- **Private Subnet 1 (`10.0.11.0/24`)** in AZ 1: Hosts Web Server 1.
- **Private Subnet 2 (`10.0.12.0/24`)** in AZ 2: Hosts Web Server 2.

#### Q7. Why are the backend web servers in private subnets with no public IP?
**Answer:** Placing backend web servers in private subnets implements the security principle of **defense in depth** and **least privilege**:
1. Eliminates direct Internet exposure: Attackers on the public internet cannot directly scan, port probe, or launch DDoS/exploit attempts against the web nodes.
2. Enforces architectural boundaries: The web servers can only accept HTTP traffic routed through the Nginx Load Balancer and management/NRPE traffic from the Nagios server.
3. Outbound internet access is strictly controlled through the NAT Gateway for package installation and OS security patches.

#### Q8. What is the difference between an Internet Gateway (IGW) and a NAT Gateway?
**Answer:**
- **Internet Gateway (IGW):** A horizontally scaled, redundant VPC component that enables two-way communication between instances in public subnets (with public/elastic IPs) and the internet. It performs 1:1 NAT translation.
- **NAT Gateway (Network Address Translation):** A managed AWS service deployed in a public subnet that allows instances in *private* subnets to initiate outbound traffic to the internet (e.g., running `apt update`), while preventing external internet entities from initiating inbound connections to those private instances.

#### Q9. How do Security Groups differ from Network ACLs (NACLs)?
**Answer:**
- **Security Groups (SGs):** Stateful virtual firewalls operating at the instance/ENI level. If inbound traffic is permitted on port 80, the return response traffic is automatically allowed regardless of outbound rules. They support source rules referencing other Security Groups.
- **Network ACLs (NACLs):** Stateless filtering operating at the subnet boundary. Inbound and outbound traffic must be explicitly allowed. They evaluate numbered rules in sequential order.

#### Q10. How are Security Groups configured in this project to prevent unauthorized access?
**Answer:**
We use three custom Security Groups:
1. `lb_sg`: Inbound HTTP (80) and HTTPS (443) from `0.0.0.0/0`. Inbound SSH (22) restricted to administrator IP.
2. `web_sg`: Inbound HTTP (80) allowed **only** from `lb_sg`. Inbound SSH (22) and NRPE (5666) allowed **only** from `nagios_sg`. Direct public ingress is completely blocked.
3. `nagios_sg`: Inbound HTTP (80/Apache Web UI) and SSH (22) restricted to the administrator's IP (`allowed_nagios_ui_cidr` / `allowed_ssh_cidr`).

#### Q11. What is IMDSv2 and why is it enabled on all EC2 instances in this project?
**Answer:** Instance Metadata Service Version 2 (IMDSv2) protects against Server-Side Request Forgery (SSRF) vulnerabilities. Unlike IMDSv1 (which uses simple GET requests), IMDSv2 uses session-oriented requests requiring a signed `PUT` request with a security token (`X-aws-ec2-metadata-token-ttl-seconds`) before fetching metadata. We enforce `http_tokens = "required"` in Terraform.

---

### Section 3: Terraform (Infrastructure as Code)

#### Q12. Explain the purpose of Terraform state (`terraform.tfstate`).
**Answer:** Terraform state maps real-world cloud resources to configuration files, tracks metadata, and manages resource dependencies. When running `terraform plan`, Terraform compares the state file with the actual cloud state (via AWS API calls) and the local code to calculate necessary changes.

#### Q13. Why use separate `aws_security_group_rule` resources instead of inline rules?
**Answer:** Defining rules inline inside `aws_security_group` blocks can cause circular dependency cycles when rules reference other security groups (e.g., `web_sg` referencing `lb_sg` while `lb_sg` egress references `web_sg`). Using discrete `aws_security_group_rule` resources allows Terraform's directed acyclic graph (DAG) to resolve dependencies smoothly.

#### Q14. What are Terraform Modules and why did you structure the code into modules?
**Answer:** Modules are containers for multiple resources used together. We structured the project into three distinct modules:
- `modules/vpc`: Encapsulates networking (VPC, subnets, IGW, NAT GW, route tables).
- `modules/security`: Encapsulates firewall and security group rules.
- `modules/compute`: Encapsulates EC2 instances, key pairs, and AMI lookups.
This enforces reusability, maintainability, and clean separation of concerns.

#### Q15. How does Terraform dynamically generate files for Ansible?
**Answer:** Using the `local_file` resource combined with the `templatefile()` function:
- `ansible/inventory/hosts.ini`: Injected with dynamic public and private IPs of the provisioned EC2 instances.
- `ansible/group_vars/all/generated.yml`: Injected with variables such as admin passwords, private IPs, and environment flags.

---

### Section 4: Nginx Load Balancing & Fault Tolerance

#### Q16. Which load balancing algorithm does Nginx use in this project, and why?
**Answer:** The configuration uses `least_conn;` (Least Connections). This algorithm passes new requests to the backend server with the fewest active connections. It is preferred over Round Robin in production because it prevents a server handling long-lived requests from being overwhelmed while other servers sit idle.

#### Q17. How does Nginx detect and handle a backend server failure?
**Answer:**
Through the upstream configuration:
```nginx
upstream backend_pool {
    least_conn;
    server 10.0.11.X:80 max_fails=3 fail_timeout=30s;
    server 10.0.12.Y:80 max_fails=3 fail_timeout=30s;
}
```
If a server fails 3 health check attempts within 30 seconds (`max_fails=3 fail_timeout=30s`), Nginx marks it as temporarily unavailable and suspends routing traffic to it for 30 seconds. Furthermore, `proxy_next_upstream error timeout http_500 http_502 http_503;` immediately retries incoming requests against another healthy backend server.

#### Q18. What happens from an end-user perspective when one web server crashes?
**Answer:** The end-user experiences **zero downtime**. Because of `proxy_next_upstream`, when Nginx receives an error or timeout from the failing web server, it instantly replays the user's request to the second healthy web server. The user receives an HTTP 200 response with transparent service continuity.

---

### Section 5: Nagios Monitoring & Self-Healing Event Handlers

#### Q19. What is the difference between a Nagios SOFT state and a HARD state?
**Answer:**
- **SOFT State:** When a service check initially fails, Nagios records a SOFT state and increments the retry counter (e.g., attempt 1 of 4). It repeats the check at shorter intervals (`retry_interval = 1 minute`) to filter out transient network glitches.
- **HARD State:** When the service check fails consistently for `max_check_attempts` (e.g., 4 consecutive checks), it transitions to a HARD state. Only at this point does Nagios send notifications and execute **Event Handlers**.

#### Q20. What is a Nagios Event Handler?
**Answer:** An Event Handler is an optional shell script or binary executed by the Nagios daemon whenever a host or service changes state (e.g., OK -> WARNING -> CRITICAL or vice versa). It receives operational parameters:
- `$HOSTADDRESS$`: Target IP address
- `$SERVICESTATE$`: `OK`, `WARNING`, `UNKNOWN`, or `CRITICAL`
- `$SERVICESTATETYPE$`: `SOFT` or `HARD`
- `$SERVICEATTEMPT$`: Current check iteration

#### Q21. Explain step-by-step how the self-healing workflow operates.
**Answer:**
1. **Failure Occurrence:** Nginx service on Web Server 1 crashes or is stopped.
2. **Detection:** Nagios polls `/health` via `check_http_string` and detects a connection failure.
3. **State Escalation:** Nagios retries across `max_check_attempts` until confirming a `CRITICAL` `HARD` state.
4. **Trigger Event Handler:** Nagios executes `/usr/lib/nagios/plugins/eventhandlers/restart_nginx.sh` with host parameters.
5. **Ansible Invocation:** The event handler runs `ansible-playbook /opt/ansible/recovery/restart_nginx.yml -i /opt/ansible/inventory/hosts.ini --limit 10.0.11.X`.
6. **Remediation:** Ansible connects to Web Server 1, restarts the `nginx` service, and asserts that port 80 is listening.
7. **Verification:** Ansible queries `http://10.0.11.X/health` and verifies HTTP 200 `"status":"UP"`.
8. **Recovery Confirmation:** In the next check cycle, Nagios detects HTTP 200 and transitions the service back to `OK` `HARD`.

#### Q22. What is NRPE and why is it required?
**Answer:** Nagios Remote Plugin Executor (NRPE) is a daemon running on remote Linux hosts that allows Nagios to execute local monitoring plugins to query metrics that cannot be checked across network ports—such as internal CPU load, disk usage percentage, RAM consumption, and process tables.

---

### Section 6: Ansible Configuration Management

#### Q23. What are Ansible Roles and what roles exist in this project?
**Answer:** Roles provide a structured directory format to package tasks, handlers, variables, files, and templates. In this project:
- `common`: Configures base packages, `chrony` NTP synchronization, timezone, and UFW firewalls.
- `lb`: Installs and configures Nginx load balancer reverse proxy.
- `webserver`: Deploys backend Nginx web applications with customized `/health` endpoints and identity dashboards.
- `nrpe_agent`: Installs and secures the `nagios-nrpe-server` daemon and custom monitoring scripts (`check_mem.sh`).
- `nagios_server`: Configures Nagios Core 4, Apache2 web dashboard, CGI authentication, host/service definitions, and event handler automation.

#### Q24. How do Ansible Handlers work?
**Answer:** Handlers are special tasks that execute only when notified by another task that resulted in a `changed` state. For example, if the Nginx configuration template is modified, the task issues `notify: Restart nginx`. Handlers run once at the very end of the play, preventing redundant restarts.

#### Q25. How does Ansible connect to backend servers residing in private subnets?
**Answer:** Ansible uses the SSH `ProxyJump` or `ProxyCommand` directive in `ansible.cfg` / `hosts.ini`, using either the Load Balancer or the Nagios server (which have public IPs) as a **Bastion / Jump Host** to tunnel SSH connections into the private IPs (`10.0.11.X`).

---

### Section 7: Security & Production Readiness

#### Q26. How are secrets and passwords handled securely in this repository?
**Answer:**
- No sensitive keys or passwords are committed to source control.
- `terraform.tfvars` and `.ssh/` private keys are added to `.gitignore`.
- Sensitive Terraform variables are flagged with `sensitive = true`.
- In a full production enterprise environment, secrets would be stored in AWS Secrets Manager or HashiCorp Vault.

#### Q27. What are the key limitations of this project and how could it be scaled?
**Answer:**
1. **Single Load Balancer:** The EC2 Nginx LB is a single point of failure (SPOF). In production, an AWS Application Load Balancer (ALB) across multiple AZs would be used.
2. **Manual Scale:** Web nodes are statically defined. In production, an AWS Auto Scaling Group (ASG) based on CPU/RAM metrics would scale instances dynamically.
3. **Metrics Storage:** Nagios is primarily an alerting tool. Adding Prometheus (time-series metrics) and Grafana (rich visualization) provides long-term trend analysis.

---

### Section 8: Quick-Fire Technical Questions (Q28 - Q50)

- **Q28. What port does Nagios Web UI use?** Port 80 (Apache2 HTTP with HTTP Basic Auth).
- **Q29. What port does NRPE operate on?** Port 5666 (TCP).
- **Q30. What port does SSH use?** Port 22 (TCP).
- **Q31. How does Nginx reverse proxy preserve client IP?** By adding `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;` and `proxy_set_header X-Real-IP $remote_addr;`.
- **Q32. What command checks Nagios configuration syntax?** `/usr/sbin/nagios4 -v /etc/nagios4/nagios.cfg`.
- **Q33. What command tests Nginx configuration syntax?** `sudo nginx -t`.
- **Q34. What is the default administrative user in Nagios?** `nagiosadmin`.
- **Q35. Where are Nagios check plugins located in Ubuntu?** `/usr/lib/nagios/plugins/`.
- **Q36. What is the status endpoint format used in this project?** HTTP GET `/health` returning JSON: `{"status":"UP","server":"web-node-1","role":"webserver"}`.
- **Q37. What AWS EC2 instance type is used?** `t3.micro` (2 vCPUs, 1 GiB memory, burstable performance, Free Tier eligible).
- **Q38. What Linux distribution is used?** Ubuntu 24.04 LTS (Noble Numbat) 64-bit AMD64.
- **Q39. What storage volume type is used?** General Purpose SSD (`gp3`).
- **Q40. What is the function of `chrony`?** Ensures system clocks stay synchronized using Network Time Protocol (NTP), essential for log correlation across distributed nodes.
- **Q41. What is UFW?** Uncomplicated Firewall, a user-friendly frontend for iptables on Ubuntu systems.
- **Q42. How does Terraform track what resources it already created?** Via the state file (`terraform.tfstate`), matching code declarations with cloud resource IDs.
- **Q43. What does `terraform refresh` do?** Updates the state file with the real-world status of resources in the cloud.
- **Q44. What does `terraform fmt` do?** Formats Terraform configuration files according to canonical HCL style rules.
- **Q45. What does `terraform validate` do?** Verifies the internal consistency and syntax of configuration files without accessing cloud APIs.
- **Q46. What is `ansible-playbook --check`?** A "dry-run" mode that simulates changes without applying them to remote targets.
- **Q47. What is `ansible_ssh_common_args` in inventory?** Arguments passed directly to the SSH client, such as `-o ProxyJump=ubuntu@LB_PUBLIC_IP`.
- **Q48. What is the difference between Public IP and Elastic IP?** A standard public IP changes when an EC2 instance stops and starts; an Elastic IP (EIP) is a static public IPv4 address that remains allocated to your AWS account until released.
- **Q49. Why do we need an Elastic IP for the NAT Gateway?** AWS NAT Gateways strictly require a dedicated Elastic IP to provide a consistent outbound public IP for internet communication.
- **Q50. If you were asked to explain this project to a non-technical interviewer, how would you summarize it in two sentences?**
  *"This project builds an automated, resilient web hosting environment on AWS that never leaves customers stranded. When any web server crashes, the system instantly reroutes visitors to healthy servers while a robotic watchdog detects the failure and heals the broken server in seconds without human help."*
