#!/usr/bin/env bash
# Bootstrap an Ubuntu 22.04 / 24.04 Control Node (e.g., EC2 in eu-north-1)
# Installs Terraform, Ansible, AWS CLI v2, jq, and make.
set -euo pipefail

echo "[1/5] Updating apt packages..."
sudo apt-get update -y
sudo apt-get install -y gnupg software-properties-common curl unzip jq make

echo "[2/5] Installing HashiCorp Terraform..."
if ! command -v terraform >/dev/null 2>&1; then
  wget -qO- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y terraform
else
  echo "Terraform already installed: $(terraform version | head -n1)"
fi

echo "[3/5] Installing Ansible..."
if ! command -v ansible-playbook >/dev/null 2>&1; then
  sudo apt-get install -y ansible
else
  echo "Ansible already installed: $(ansible --version | head -n1)"
fi

echo "[4/5] Installing AWS CLI v2..."
if ! command -v aws >/dev/null 2>&1; then
  TMP_DIR=$(mktemp -d)
  curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "${TMP_DIR}/awscliv2.zip"
  unzip -q "${TMP_DIR}/awscliv2.zip" -d "${TMP_DIR}"
  sudo "${TMP_DIR}/aws/install"
  rm -rf "${TMP_DIR}"
else
  echo "AWS CLI already installed: $(aws --version)"
fi

echo "[5/5] Done!"
echo "Next steps:"
echo "  1. Configure AWS credentials (or attach an IAM Role to this EC2 instance): aws configure"
echo "  2. Run: ./scripts/deploy.sh"
