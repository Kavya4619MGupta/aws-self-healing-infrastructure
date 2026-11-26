#!/usr/bin/env bash
# ==============================================================================
# DevOps Project: Failure Injection & Self-Healing Demonstration Script
# Simulates backend web server crashes and observes autonomous system recovery
# ==============================================================================

set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

KEY_FILE=""
BASTION_IP=""
TARGET_PRIVATE_IP=""
ACTION="crash"

usage() {
    echo -e "${CYAN}Usage: $0 --key <PATH_TO_PEM> --bastion <LB_PUBLIC_IP> --target <WEB_PRIVATE_IP> [--action crash|recover|status]${NC}"
    echo ""
    echo "Options:"
    echo "  --key       Path to SSH private key (.pem)"
    echo "  --bastion   Public IP of Load Balancer or Nagios instance (used as SSH jump host)"
    echo "  --target    Private IP of target Web Server (e.g., 10.0.11.10)"
    echo "  --action    crash (stop nginx), recover (start nginx), or status (check systemctl status)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --key) KEY_FILE="$2"; shift 2 ;;
        --bastion) BASTION_IP="$2"; shift 2 ;;
        --target) TARGET_PRIVATE_IP="$2"; shift 2 ;;
        --action) ACTION="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter: $1"; usage ;;
    esac
done

if [ -z "$KEY_FILE" ] || [ -z "$BASTION_IP" ] || [ -z "$TARGET_PRIVATE_IP" ]; then
    usage
fi

if [ ! -f "$KEY_FILE" ]; then
    echo -e "${RED}Error: Key file '$KEY_FILE' does not exist!${NC}"
    exit 1
fi

SSH_CMD="ssh -i $KEY_FILE -o StrictHostKeyChecking=no -o ProxyCommand=\"ssh -i $KEY_FILE -W %h:%p ubuntu@$BASTION_IP\" ubuntu@$TARGET_PRIVATE_IP"

case "$ACTION" in
    crash)
        echo -e "${RED}==> [INJECTING FAILURE] Stopping Nginx on Web Server (${TARGET_PRIVATE_IP})...${NC}"
        ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no -o ProxyCommand="ssh -i $KEY_FILE -W %h:%p ubuntu@$BASTION_IP" ubuntu@"$TARGET_PRIVATE_IP" "sudo systemctl stop nginx"
        echo -e "${YELLOW}--> Nginx has been forcibly stopped!${NC}"
        echo -e "\n${CYAN}What happens next in the autonomous loop:${NC}"
        echo "1. The Load Balancer automatically removes this node from the active pool via least_conn failover."
        echo "2. Nagios polls /health every 60s, detecting failure and transitioning from SOFT to HARD CRITICAL state."
        echo "3. Nagios executes the event handler: /usr/lib/nagios/plugins/eventhandlers/restart_nginx.sh"
        echo "4. The event handler runs Ansible recovery playbook: /opt/ansible/recovery/restart_nginx.yml"
        echo "5. Nginx is automatically restarted and verified healthy!"
        echo ""
        echo "Monitor live logs on the Nagios server with:"
        echo "  tail -f /var/log/nagios/event_handler.log"
        ;;
    recover)
        echo -e "${GREEN}==> [MANUAL RECOVERY] Starting Nginx on Web Server (${TARGET_PRIVATE_IP})...${NC}"
        ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no -o ProxyCommand="ssh -i $KEY_FILE -W %h:%p ubuntu@$BASTION_IP" ubuntu@"$TARGET_PRIVATE_IP" "sudo systemctl start nginx"
        echo -e "${GREEN}--> Nginx manually restarted.${NC}"
        ;;
    status)
        echo -e "${CYAN}==> Querying Nginx service status on (${TARGET_PRIVATE_IP})...${NC}"
        ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no -o ProxyCommand="ssh -i $KEY_FILE -W %h:%p ubuntu@$BASTION_IP" ubuntu@"$TARGET_PRIVATE_IP" "sudo systemctl status nginx --no-pager"
        ;;
    *)
        echo -e "${RED}Unknown action: $ACTION${NC}"
        usage
        ;;
esac
