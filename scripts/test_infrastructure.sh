#!/usr/bin/env bash
# ==============================================================================
# DevOps College Project: Automated Infrastructure Verification & Health Suite
# Tests: Nginx LB, Backend Redundancy, Nagios Web UI, and SSH Connectivity
# ==============================================================================

set -uo pipefail

# ANSI Color Codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

pass_count=0
fail_count=0

pass() {
    echo -e "  [${GREEN}PASS${NC}] $1"
    pass_count=$((pass_count + 1))
}

fail() {
    echo -e "  [${RED}FAIL${NC}] $1"
    fail_count=$((fail_count + 1))
}

warn() {
    echo -e "  [${YELLOW}WARN${NC}] $1"
}

info() {
    echo -e "\n${CYAN}==> $1${NC}"
}

if [ $# -lt 2 ]; then
    echo -e "${RED}Usage: $0 <LB_PUBLIC_IP> <NAGIOS_PUBLIC_IP> [KEY_PATH]${NC}"
    echo "Example: $0 13.51.10.20 13.51.10.30 ~/.ssh/aws-auto-infra-dev-key.pem"
    exit 1
fi

LB_IP="$1"
NAGIOS_IP="$2"
KEY_PATH="${3:-}"

echo "================================================================================"
echo " Starting DevOps Automated Infrastructure Test Suite"
echo " Target Load Balancer: http://${LB_IP}"
echo " Target Nagios Server: http://${NAGIOS_IP}/nagios4"
echo "================================================================================"

# ------------------------------------------------------------------------------
# Test 1: Nginx Load Balancer HTTP Availability
# ------------------------------------------------------------------------------
info "Test 1: Verifying Nginx Load Balancer HTTP Response (Port 80)"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 8 "http://${LB_IP}/" || echo "000")
if [ "$HTTP_CODE" -eq 200 ]; then
    pass "Load Balancer root URL responded with HTTP 200 OK"
else
    fail "Load Balancer returned HTTP status ${HTTP_CODE} (Expected 200)"
fi

# ------------------------------------------------------------------------------
# Test 2: Application Health Endpoint Verification
# ------------------------------------------------------------------------------
info "Test 2: Verifying Application Health Check Endpoint (/health)"
HEALTH_RESPONSE=$(curl -s --connect-timeout 8 "http://${LB_IP}/health" || echo "")
if echo "$HEALTH_RESPONSE" | grep -q '"status":"UP"'; then
    pass "Health endpoint successfully returned status UP: ${HEALTH_RESPONSE}"
else
    fail "Health check failed or did not contain '\"status\":\"UP\"'. Response: ${HEALTH_RESPONSE}"
fi

# ------------------------------------------------------------------------------
# Test 3: Load Balancing & Backend Traffic Distribution
# ------------------------------------------------------------------------------
info "Test 3: Testing Load Distribution across Backend Web Nodes (10 requests)"
declare -A NODE_RESPONSES
for i in {1..10}; do
    RESPONSE=$(curl -s --connect-timeout 5 "http://${LB_IP}/health" || echo "")
    NODE=$(echo "$RESPONSE" | grep -o '"server":"[^"]*' | cut -d'"' -f4 || echo "unknown")
    if [ -n "$NODE" ] && [ "$NODE" != "unknown" ]; then
        NODE_RESPONSES["$NODE"]=$((${NODE_RESPONSES["$NODE"]:-0} + 1))
    fi
    sleep 0.2
done

echo "  Distribution tally over 10 requests:"
for node in "${!NODE_RESPONSES[@]}"; do
    echo "    - Node [$node]: ${NODE_RESPONSES[$node]} responses"
done

if [ ${#NODE_RESPONSES[@]} -ge 2 ]; then
    pass "Traffic was actively distributed across multiple backend nodes (${!NODE_RESPONSES[*]})"
elif [ ${#NODE_RESPONSES[@]} -eq 1 ]; then
    warn "Only 1 backend responded (${!NODE_RESPONSES[*]}). Check if web_node_2 is still starting up."
else
    fail "Could not resolve backend server identity from responses."
fi

# ------------------------------------------------------------------------------
# Test 4: Nagios Monitoring Server Web Dashboard Check
# ------------------------------------------------------------------------------
info "Test 4: Verifying Nagios Web UI Accessibility & Authentication (Port 80)"
NAGIOS_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 8 "http://${NAGIOS_IP}/nagios4/" || echo "000")
if [ "$NAGIOS_CODE" -eq 401 ]; then
    pass "Nagios Core web interface is active and protected by HTTP Basic Auth (HTTP 401 Unauthorized)"
elif [ "$NAGIOS_CODE" -eq 200 ]; then
    pass "Nagios Core web interface returned HTTP 200 OK"
else
    fail "Nagios server returned HTTP status ${NAGIOS_CODE} (Expected 401 or 200)"
fi

# ------------------------------------------------------------------------------
# Test 5 & 6: SSH Connectivity Verification (Optional if key provided)
# ------------------------------------------------------------------------------
if [ -n "$KEY_PATH" ] && [ -f "$KEY_PATH" ]; then
    info "Test 5: Checking SSH Connectivity to Nginx Load Balancer"
    if ssh -i "$KEY_PATH" -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no ubuntu@"$LB_IP" "uptime" >/dev/null 2>&1; then
        pass "SSH connection to Nginx Load Balancer successful"
    else
        fail "Unable to establish SSH connection to Load Balancer at ${LB_IP}"
    fi

    info "Test 6: Checking SSH Connectivity to Nagios Monitoring Server"
    if ssh -i "$KEY_PATH" -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no ubuntu@"$NAGIOS_IP" "uptime" >/dev/null 2>&1; then
        pass "SSH connection to Nagios Monitoring Server successful"
    else
        fail "Unable to establish SSH connection to Nagios Server at ${NAGIOS_IP}"
    fi
else
    warn "SSH key path not provided or file not found. Skipping SSH checks."
fi

# ------------------------------------------------------------------------------
# Summary Report
# ------------------------------------------------------------------------------
echo -e "\n================================================================================"
echo " Automated Verification Summary"
echo " Passed: ${GREEN}${pass_count}${NC}"
echo " Failed: ${RED}${fail_count}${NC}"
echo "================================================================================"

if [ "$fail_count" -eq 0 ]; then
    echo -e "${GREEN}SUCCESS: All infrastructure tests passed! Project is fully functional.${NC}"
    exit 0
else
    echo -e "${RED}FAILURE: Some tests failed. Please review the output above.${NC}"
    exit 1
fi
