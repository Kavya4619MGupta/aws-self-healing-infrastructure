# 🏗️ Automated Self-Healing, Secure and Fault-Tolerant Web Infrastructure Using AWS, Terraform, Ansible, Nginx and Nagios

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Ansible](https://img.shields.io/badge/Ansible-2.15+-EE0000?logo=ansible&logoColor=white)](https://www.ansible.com/)
[![Nginx](https://img.shields.io/badge/Nginx-Reverse%20Proxy%20%26%20LB-009639?logo=nginx&logoColor=white)](https://nginx.org/)
[![Nagios](https://img.shields.io/badge/Nagios%20Core-4.x-FF6600?logo=nagios&logoColor=white)](https://www.nagios.org/)
[![AWS](https://img.shields.io/badge/AWS-VPC%20%2B%20EC2-232F3E?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A production-grade, enterprise-ready College DevOps Capstone Project demonstrating **Infrastructure as Code (IaC)**, **Configuration Management**, **Fault-Tolerant Load Balancing**, and **Closed-Loop Autonomous Self-Healing**.

---

## 📑 Table of Contents
1. [Project Overview](#-project-overview)
2. [Architecture & Network Topography](#-architecture--network-topography)
3. [Key Features](#-key-features)
4. [System Components & EC2 Roles](#-system-components--ec2-roles)
5. [The Autonomous Self-Healing Loop](#-the-autonomous-self-healing-loop)
6. [Local Project Structure](#-local-project-structure)
7. [Prerequisites & System Requirements](#-prerequisites--system-requirements)
8. [Step-by-Step Deployment Guide](#-step-by-step-deployment-guide)
9. [Automated Verification & Testing](#-automated-verification--testing)
10. [Simulating Failures (Self-Healing Demo)](#-simulating-failures-self-healing-demo)
11. [AWS Cost Estimation & Risk Analysis](#-aws-cost-estimation--risk-analysis)
12. [Optional Observability (Prometheus & Grafana)](#-optional-observability-prometheus--grafana)
13. [College Viva & Interview Preparation](#-college-viva--interview-preparation)
14. [License](#-license)

---

## 🎯 Project Overview
In modern web architectures, downtime directly impacts revenue and reputation. This project solves service outage challenges by combining:
- **Terraform:** Automatically provisions a secure multi-tier AWS VPC with public and private subnets, an Internet Gateway, a NAT Gateway, and 4 dedicated EC2 instances.
- **Ansible:** Configures the servers, installs system dependencies, deploys application endpoints, sets up NRPE monitoring agents, and configures the Nagios server.
- **Nginx:** Operates as a fault-tolerant Layer 7 Load Balancer that dynamically detects backend node failures and reroutes visitor traffic with zero downtime.
- **Nagios Core & Event Handlers:** Continuously monitors system health and application endpoints. When a service fails, Nagios triggers an **automated event handler** that invokes an Ansible remediation playbook to restart the service and verify recovery without human intervention.

---

## 🌐 Architecture & Network Topography

```
                                      INTERNET
                                         │
                                   [HTTP/HTTPS]
                                         │
                                         ▼
                         ┌────────────────────────────────┐
                         │   AWS Internet Gateway (IGW)   │
                         └───────────────┬────────────────┘
                                         │
                 ┌───────────────────────┴───────────────────────┐
                 │                                               │
                 ▼                                               ▼
     ┌────────────────────────┐                     ┌────────────────────────┐
     │  Public Subnet 1 (AZ1) │                     │  Public Subnet 2 (AZ2) │
     │      10.0.1.0/24       │                     │      10.0.2.0/24       │
     │                        │                     │                        │
     │  [ Nginx Load Balancer]│                     │   [ Nagios Monitoring  │
     │     Elastic Public IP  │                     │       & Automation ]   │
     │                        │                     │                        │
     │   [ AWS NAT Gateway ]  │                     └────────────┬───────────┘
     └───────────┬────────────┘                                  │
                 │                                               │
      (Private HTTP Proxy)                            (NRPE & SSH Management)
                 │                                               │
                 ├───────────────────────┬───────────────────────┤
                 ▼                       ▼                       ▼
     ┌────────────────────────┐     ┌────────────────────────┐   │
     │ Private Subnet 1 (AZ1) │     │ Private Subnet 2 (AZ2) │   │
     │      10.0.11.0/24      │     │      10.0.12.0/24      │   │
     │                        │     │                        │   │
     │   [ Web Server 1 ]     │     │   [ Web Server 2 ]     │   │
     │   NO Public IP         │     │   NO Public IP         │   │
     │   (Outbound via NAT)   │     │   (Outbound via NAT)   │   │
     └────────────────────────┘     └────────────────────────┘   │
                 ▲                               ▲               │
                 └─────────── NAT Egress ────────┴───────────────┘
```

---

## ✨ Key Features
- **Zero-Downtime Fault Tolerance:** Nginx upstream configuration automatically drops unresponsive backend nodes from rotation and re-routes active user requests immediately.
- **Autonomous Closed-Loop Self-Healing:** Nagios event handlers execute an Ansible recovery playbook that restarts the failed service and validates the `/health` endpoint.
- **Strict Network Isolation (Defense in Depth):** Backend web servers reside in isolated private subnets with **no public IPv4 addresses**, preventing direct scanning or exploit attempts.
- **Dynamic Inventory Generation:** Terraform outputs automatically template the Ansible `hosts.ini` inventory and runtime group variables.
- **Hardened Security Profiles:** Security Groups use discrete reference rules; IMDSv2 is strictly enforced on all instances; UFW firewalls restrict traffic on the OS level.

---

## 🖥️ System Components & EC2 Roles

| Role | Instance Name | Subnet Tier | Public IP | Security Group | Function |
|---|---|---|---|---|---|
| **Load Balancer** | `aws-auto-infra-dev-lb` | Public (`10.0.1.0/24`) | **Yes** (Public) | `lb_sg` | Distributes HTTP requests (`least_conn`) to private backend nodes |
| **Web Server 1** | `aws-auto-infra-dev-web-node-1` | Private (`10.0.11.0/24`) | **No** (Private only) | `web_sg` | Serves web application and health check JSON (`/health`) |
| **Web Server 2** | `aws-auto-infra-dev-web-node-2` | Private (`10.0.12.0/24`) | **No** (Private only) | `web_sg` | Serves redundant web application in second AZ |
| **Monitoring Server** | `aws-auto-infra-dev-nagios-server` | Public (`10.0.2.0/24`) | **Yes** (Public) | `nagios_sg` | Nagios Core 4, Apache2 dashboard, event handlers, and Ansible controller |

---

## 🔄 The Autonomous Self-Healing Loop

1. **Failure Event:** The Nginx service on Web Server 1 (`10.0.11.x`) terminates unexpectedly.
2. **Immediate Traffic Protection:** The Load Balancer attempts forwarding to Web Server 1, receives an error, and immediately re-routes the user to Web Server 2 (`proxy_next_upstream`). **Zero impact to end-users.**
3. **Detection by Nagios:** Nagios actively polls `http://10.0.11.x/health` using `check_http_string`. After consecutive failed attempts, the service transitions to a `CRITICAL` `HARD` state.
4. **Event Handler Trigger:** Nagios executes `/usr/lib/nagios/plugins/eventhandlers/restart_nginx.sh`.
5. **Targeted Ansible Remediation:** The script calls:
   ```bash
   ansible-playbook /opt/ansible/recovery/restart_nginx.yml -i /opt/ansible/inventory/hosts.ini --limit "10.0.11.x"
   ```
6. **Service Restoration & Verification:** Ansible connects over internal SSH, restarts `nginx`, and asserts the HTTP 200 `/health` response.
7. **Return to Green:** Nagios detects service recovery on the next check cycle and marks the host as `OK`.

---

## 📁 Local Project Structure

```text
aws-infra-automation/
├── Makefile                                # Unified build and automation targets
├── README.md                               # Project documentation & operational runbook
├── .gitignore                              # Git exclusion rules (keys, state, tfvars)
├── docs/
│   ├── architecture.md                     # Deep architectural breakdown & diagrams
│   ├── project_report.md                   # Full 2500+ word academic college report
│   ├── viva_questions.md                   # 50 in-depth viva Q&A for examination
│   └── prometheus_grafana.md               # Optional Prometheus + Grafana guide
├── scripts/
│   ├── bootstrap-control-node.sh           # Installs Terraform & Ansible on Ubuntu
│   ├── deploy.sh                           # End-to-end automated deployment pipeline
│   ├── destroy.sh                          # Clean AWS teardown script
│   ├── verify.sh                           # Smoke test script
│   ├── test_infrastructure.sh              # Full automated test suite
│   └── simulate_failure.sh                 # Failure injection & self-healing demo
├── terraform/
│   ├── main.tf                             # Root Terraform configuration
│   ├── variables.tf                        # Input variable definitions
│   ├── outputs.tf                          # Exported IPs, IDs, and SSH connection strings
│   ├── versions.tf                         # Provider constraints (AWS, TLS, Local)
│   ├── terraform.tfvars.example            # Sample configuration values
│   └── modules/
│       ├── vpc/                            # VPC, Subnets, IGW, NAT Gateway, Routes
│       ├── security/                       # Security Groups and least-privilege rules
│       └── compute/                        # EC2 instances, key pair generation, AMIs
└── ansible/
    ├── ansible.cfg                         # Configuration: SSH multiplexing, inventory
    ├── inventory/
    │   ├── hosts.ini.tpl                   # Terraform dynamic inventory template
    │   └── hosts.ini.example               # Reference manual inventory
    ├── group_vars/
    │   ├── generated.yml.tpl               # Terraform dynamic variable template
    │   └── all/main.yml                    # Global Ansible configuration variables
    ├── playbooks/
    │   ├── site.yml                        # Master 5-play provisioning playbook
    │   └── recovery/restart_nginx.yml      # Targeted automated recovery playbook
    └── roles/
        ├── common/                         # Baseline packages, chrony NTP, UFW
        ├── lb/                             # Nginx reverse proxy load balancer
        ├── webserver/                      # Application server, health check, UI
        ├── nrpe_agent/                     # Nagios NRPE agent and check scripts
        └── nagios_server/                  # Nagios Core 4, Apache2, Event handlers
```

---

## ⚙️ Prerequisites & System Requirements

- **AWS Account:** Active account with permissions for EC2, VPC, EIP, and IAM.
- **Control Node (Linux / WSL / EC2):**
  - Ubuntu 22.04 LTS or 24.04 LTS
  - Terraform `>= 1.5.0`
  - Ansible `>= 2.15.0`
  - AWS CLI configured via `aws configure`

> **Note for Windows Users:** You do not need to install Terraform or Ansible directly on Windows! You can run this project effortlessly via **WSL (Windows Subsystem for Linux)** or by deploying a free `t3.micro` EC2 control node and running `./scripts/bootstrap-control-node.sh`.

---

## 🚀 Step-by-Step Deployment Guide

### Phase 1: Environment Setup
1. Clone this repository or open the project directory:
   ```bash
   cd aws-infra-automation
   ```
2. If working on a fresh Ubuntu machine / WSL:
   ```bash
   chmod +x scripts/*.sh
   ./scripts/bootstrap-control-node.sh
   ```

### Phase 2: Configure Parameters
Copy the example variables file:
```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```
Edit `terraform/terraform.tfvars` with your preferred settings:
- `aws_region`: Set to your preferred region (e.g., `us-east-1` or `eu-north-1`).
- `allowed_ssh_cidr`: Restrict to your home/work IP (e.g., `203.0.113.45/32`).
- `nagios_admin_password`: Set your secure password for the Nagios web UI.

### Phase 3: Infrastructure Provisioning & Configuration
Execute the master deployment script:
```bash
./scripts/deploy.sh
# Alternatively using make:
make deploy
```
This script will:
1. Initialize and execute `terraform apply` to build the VPC, NAT Gateway, and EC2 instances.
2. Auto-generate the dynamic inventory `ansible/inventory/hosts.ini`.
3. Wait for EC2 instances to finish cloud-init boot.
4. Execute `ansible-playbook ansible/playbooks/site.yml` across all 4 nodes.
5. Display the access URLs and generated SSH keys.

### Phase 4: Access Your Infrastructure
- **Web Application:** `http://<LB_PUBLIC_IP>`
- **Application Health:** `http://<LB_PUBLIC_IP>/health`
- **Nagios Dashboard:** `http://<NAGIOS_PUBLIC_IP>/nagios4`
  - Username: `nagiosadmin`
  - Password: (As configured in `terraform.tfvars`)

---

## 🧪 Automated Verification & Testing

Execute the comprehensive automated verification test suite:
```bash
./scripts/test_infrastructure.sh <LB_PUBLIC_IP> <NAGIOS_PUBLIC_IP> .ssh/aws-auto-infra-dev-key.pem
```

The suite validates:
- [x] Load Balancer root HTTP 200 OK
- [x] Application JSON health endpoint response
- [x] Active traffic distribution across backend web nodes
- [x] Nagios Web UI availability and HTTP Basic Auth security
- [x] SSH connectivity and key validation

---

## 💥 Simulating Failures (Self-Healing Demo)

To demonstrate self-healing during your project presentation or evaluation:

1. **Crash Web Server 1:**
   ```bash
   ./scripts/simulate_failure.sh \
     --key .ssh/aws-auto-infra-dev-key.pem \
     --bastion <LB_PUBLIC_IP> \
     --target <WEB_SERVER_1_PRIVATE_IP> \
     --action crash
   ```
2. **Observe Zero-Downtime:** Refresh `http://<LB_PUBLIC_IP>` repeatedly. The website stays online because Nginx instantly routes all traffic to Web Server 2!
3. **Observe Self-Healing:**
   - Log into the Nagios dashboard at `http://<NAGIOS_PUBLIC_IP>/nagios4`.
   - Watch the service state transition from `CRITICAL (SOFT)` to `CRITICAL (HARD)`.
   - The event handler triggers Ansible in the background.
   - Within 60–90 seconds, Nginx is restarted and Nagios transitions back to `OK`.

---

## 💰 AWS Cost Estimation & Risk Analysis

| AWS Resource | Quantity | Hourly Cost (eu-north-1) | Estimated Monthly Cost | Free Tier Eligibility |
|---|---|---|---|---|
| **EC2 `t3.micro`** | 4 instances | ~$0.0104 / hr each | ~$30.00 (if run 24/7) | **750 hours/month Free** for 12 months |
| **AWS NAT Gateway** | 1 gateway | ~$0.045 / hr | ~$32.40 (if run 24/7) | Not Free Tier eligible |
| **Elastic IP (EIP)** | 1 allocated | $0.00 / hr (when attached) | $0.00 | Free while attached to running instance |
| **EBS Storage (gp3)** | 42 GB total | ~$0.08 / GB-month | ~$3.36 | 30 GB/month Free |

> **Cost Optimization Tip:** For college evaluations and demonstrations, deploy the infrastructure using `./scripts/deploy.sh`, conduct testing and demonstrations for 1–2 hours, and immediately tear down the environment using:
> ```bash
> ./scripts/destroy.sh
> # Or:
> make destroy
> ```
> Total cost for a 2-hour demonstration is **under $0.20 USD**.

---

## 📊 Optional Observability (Prometheus & Grafana)
For guidelines on extending this setup with Prometheus time-series metric collection and interactive Grafana dashboards, review the dedicated guide:
📖 [docs/prometheus_grafana.md](docs/prometheus_grafana.md)

---

## 🎓 College Viva & Interview Preparation
A complete set of 50 comprehensive questions and answers covering DevOps, IaC, Configuration Management, Networking, and Self-Healing is provided in:
📖 [docs/viva_questions.md](docs/viva_questions.md)

---

## 📄 License
This project is open-source under the [MIT License](LICENSE).
