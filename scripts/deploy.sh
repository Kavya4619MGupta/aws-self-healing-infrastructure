#!/usr/bin/env bash
# End-to-End Automated Deployment: Terraform Provisioning -> Ansible Configuration -> Verification
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"
ANSIBLE_DIR="${ROOT_DIR}/ansible"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: Required command '$1' not found. Run ./scripts/bootstrap-control-node.sh first."
    exit 1
  fi
}

echo "=== [Step 1/5] Checking prerequisites ==="
require_cmd terraform
require_cmd ansible-playbook
require_cmd aws
require_cmd jq

echo "=== [Step 2/5] Verifying AWS credentials ==="
aws sts get-caller-identity --output table

if [[ ! -f "${TF_DIR}/terraform.tfvars" ]]; then
  echo "No terraform.tfvars found; copying terraform.tfvars.example -> terraform.tfvars"
  cp "${TF_DIR}/terraform.tfvars.example" "${TF_DIR}/terraform.tfvars"
fi

echo "=== [Step 3/5] Provisioning AWS infrastructure with Terraform ==="
terraform -chdir="${TF_DIR}" init -upgrade
terraform -chdir="${TF_DIR}" apply -auto-approve

echo "=== [Step 4/5] Waiting 30s for cloud-init and configuring servers with Ansible ==="
sleep 30
ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg" ansible-playbook \
  -i "${ANSIBLE_DIR}/inventory/hosts.ini" \
  "${ANSIBLE_DIR}/playbooks/site.yml"

echo "=== [Step 5/5] Verifying deployment ==="
bash "${ROOT_DIR}/scripts/verify.sh"

LB_URL=$(terraform -chdir="${TF_DIR}" output -raw lb_url 2>/dev/null || echo "http://$(terraform -chdir="${TF_DIR}" output -raw lb_public_ip)")
NAGIOS_URL=$(terraform -chdir="${TF_DIR}" output -raw nagios_dashboard_url 2>/dev/null || echo "http://$(terraform -chdir="${TF_DIR}" output -raw nagios_public_ip)/nagios4")

echo ""
echo "============================================================"
echo " 🎉 DEPLOYMENT COMPLETE & VERIFIED"
echo "============================================================"
echo " Load Balancer URL : ${LB_URL}"
echo " Health Endpoint   : ${LB_URL}/health"
echo " Nagios Dashboard  : ${NAGIOS_URL}"
echo " Nagios Username   : nagiosadmin"
echo "============================================================"
