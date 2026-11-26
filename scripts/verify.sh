#!/usr/bin/env bash
# Post-deployment health & monitoring verification script
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"
ANSIBLE_DIR="${ROOT_DIR}/ansible"

NAGIOS_IP=$(terraform -chdir="${TF_DIR}" output -raw nagios_public_ip 2>/dev/null || terraform -chdir="${TF_DIR}" output -json nagios_server | jq -r '.public_ip')
LB_IP=$(terraform -chdir="${TF_DIR}" output -raw lb_public_ip 2>/dev/null || terraform -chdir="${TF_DIR}" output -json lb_server | jq -r '.public_ip')

echo "============================================================"
echo " 1. Checking Nginx Load Balancer on http://${LB_IP} ..."
echo "============================================================"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 8 "http://${LB_IP}/")
if [[ "${HTTP_CODE}" == "200" ]]; then
  echo "  [OK] Load Balancer root URL reachable (HTTP 200)"
else
  echo "  [FAIL] Load Balancer returned HTTP ${HTTP_CODE}"
fi

echo "Checking Application Health Endpoint via Load Balancer (http://${LB_IP}/health) ..."
HEALTH_BODY=$(curl -sS --max-time 10 "http://${LB_IP}/health" || echo "FAILED")
echo "  [OK] Response: ${HEALTH_BODY}"

echo ""
echo "============================================================"
echo " 2. Checking Nagios Web UI on http://${NAGIOS_IP}/nagios4 ..."
echo "============================================================"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 8 "http://${NAGIOS_IP}/nagios4/")
if [[ "${HTTP_CODE}" == "401" || "${HTTP_CODE}" == "200" ]]; then
  echo "  [OK] Nagios Web UI reachable (HTTP ${HTTP_CODE}, authentication active)"
else
  echo "  [FAIL] Nagios Web UI returned HTTP ${HTTP_CODE}"
fi

echo ""
echo "============================================================"
echo " 3. Running Comprehensive Test Suite ..."
echo "============================================================"
KEY_FILE=$(ls "${ROOT_DIR}"/.ssh/*-key.pem 2>/dev/null | head -n 1 || echo "")
if [[ -n "${KEY_FILE}" && -f "${KEY_FILE}" ]]; then
  bash "${ROOT_DIR}/scripts/test_infrastructure.sh" "${LB_IP}" "${NAGIOS_IP}" "${KEY_FILE}"
else
  bash "${ROOT_DIR}/scripts/test_infrastructure.sh" "${LB_IP}" "${NAGIOS_IP}"
fi
