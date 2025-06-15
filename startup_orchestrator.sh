#!/bin/bash

# --- Raspberry Pi Startup Orchestrator v2 ---
# An intelligent, state-aware script to start systemd services sequentially,
# based on system load to prevent boot-time resource contention.
#
# MIT License - Copyright (c) 2025 Luis Branco | https://github.com/BrancoDigital

# ==============================================================================
# ---                           CONFIGURATION                              ---
# =================================s=============================================
#
# INSTRUCTIONS:
# 1. Edit the 'SERVICES_TO_START' array with the exact names of the services
#    you want to manage (e.g., "caddy.service", "docker.service").
# 2. The order of services in the list determines their startup priority.
# 3. Adjust the threshold and delay values below to match your device's
#    performance characteristics.
#
# ------------------------------------------------------------------------------

# The list of services to start, in the desired order of priority.
# EXAMPLE:
# SERVICES_TO_START=(
#     "caddy.service"
#     "gitea.service"
#     "docker.service"
# )
SERVICES_TO_START=(
    "service1-critical.service"
    "service2-important.service"
    "service3-heavy.service"
    "service4-optional.service"
)

# The initial "all clear" load threshold for the very first service.
# A good starting point for a 4-core Pi is "1.5".
INITIAL_LOAD_THRESHOLD="1.5"

# How much to raise the threshold after each service successfully starts.
# This accounts for the rising baseline load of a healthy system.
# A value of "0.7" is a reasonable starting point.
SUBSEQUENT_LOAD_INCREMENT="0.7"

# How many seconds to wait for the system to settle AFTER starting a service.
# This gives the 1-minute load average time to catch up. "30" is a safe value.
POST_START_DELAY="30"

# How many seconds to wait before re-checking the load if it's too high.
BACKOFF_DELAY="15"


# ==============================================================================
# ---                        ORCHESTRATION LOGIC                           ---
# ---                  (No changes needed below this line)                 ---
# ==============================================================================

TOTAL_SERVICES=${#SERVICES_TO_START[@]}
echo "Orchestrator v2: Starting sequence for ${TOTAL_SERVICES} services."

# Loop through our array of services
for (( i=0; i<${TOTAL_SERVICES}; i++ )); do
    SERVICE_NAME=${SERVICES_TO_START[$i]}
    
    # Calculate the adaptive threshold for the CURRENT service.
    EFFECTIVE_THRESHOLD=$(echo "$INITIAL_LOAD_THRESHOLD + ($i * $SUBSEQUENT_LOAD_INCREMENT)" | bc)

    echo "Orchestrator: Preparing service #${i}: ${SERVICE_NAME}. Effective load threshold is now ${EFFECTIVE_THRESHOLD}."

    # Loop until the system load is below the current threshold
    while true; do
        CURRENT_LOAD=$(awk '{print $1}' /proc/loadavg)
        
        # Use 'bc' for floating-point comparison
        if (( $(echo "${CURRENT_LOAD} < ${EFFECTIVE_THRESHOLD}" | bc -l) )); then
            echo "Orchestrator: System load (${CURRENT_LOAD}) is below threshold (${EFFECTIVE_THRESHOLD}). Green light for ${SERVICE_NAME}."
            
            # Start the service and immediately return, letting systemd manage it
            systemctl start --no-block ${SERVICE_NAME}
            
            echo "Orchestrator: Start command issued for ${SERVICE_NAME}. Waiting ${POST_START_DELAY}s for system to settle..."
            sleep ${POST_START_DELAY}
            
            break # Exit the inner while loop and move to the next service
        else
            echo "Orchestrator: System load (${CURRENT_LOAD}) is too high (threshold is ${EFFECTIVE_THRESHOLD}). Holding... Will check again in ${BACKOFF_DELAY}s."
            sleep ${BACKOFF_DELAY}
        fi
    done
done

echo "Orchestrator v2: All services have been started. Sequence complete."
