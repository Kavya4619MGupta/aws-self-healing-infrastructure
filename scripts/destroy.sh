#!/usr/bin/env bash
# Destroy all provisioned AWS resources and clean generated files
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"

echo "Destroying AWS infrastructure managed by Terraform..."
terraform -chdir="${TF_DIR}" destroy -auto-approve

echo "Cleaning generated SSH keys and dynamic Ansible files..."
rm -f "${ROOT_DIR}/.ssh/"*.pem
rm -f "${ROOT_DIR}/ansible/inventory/hosts.ini"
rm -f "${ROOT_DIR}/ansible/group_vars/all/generated.yml"

echo "Teardown complete."
