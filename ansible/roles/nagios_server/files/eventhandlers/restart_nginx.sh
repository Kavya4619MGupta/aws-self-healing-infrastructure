#!/bin/bash
# Nagios event handler: restart nginx on a web node via Ansible
HOST_ADDRESS="$1"
SERVICE_STATE="$2"
SERVICE_STATE_TYPE="$3"
SERVICE_ATTEMPT="$4"
LOG_FILE="/var/log/nagios/event_handler.log"
RECOVERY_PLAYBOOK="/opt/ansible/recovery/restart_nginx.yml"
INVENTORY="/opt/ansible/inventory/hosts.ini"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

echo "$(timestamp) Event handler called: host=$HOST_ADDRESS state=$SERVICE_STATE type=$SERVICE_STATE_TYPE attempt=$SERVICE_ATTEMPT" >> "$LOG_FILE"

if [ "$SERVICE_STATE" = "CRITICAL" ] && [ "$SERVICE_STATE_TYPE" = "HARD" ]; then
    echo "$(timestamp) CRITICAL HARD detected on $HOST_ADDRESS — triggering Ansible recovery" >> "$LOG_FILE"
    ansible-playbook "$RECOVERY_PLAYBOOK" -i "$INVENTORY" --limit "$HOST_ADDRESS" >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        echo "$(timestamp) Recovery playbook completed successfully for $HOST_ADDRESS" >> "$LOG_FILE"
    else
        echo "$(timestamp) ERROR: Recovery playbook FAILED for $HOST_ADDRESS" >> "$LOG_FILE"
    fi
else
    echo "$(timestamp) State is $SERVICE_STATE/$SERVICE_STATE_TYPE — no action taken" >> "$LOG_FILE"
fi
