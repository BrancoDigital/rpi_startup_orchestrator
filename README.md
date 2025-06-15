# Raspberry Pi Startup Orchestrator

A lightweight, shell-based startup orchestrator for Raspberry Pi (and other SBCs) that sequentially starts services based on system load to prevent boot-time resource contention.

---

## The Problem

On resource-constrained devices, starting multiple services simultaneously at boot can cause a "thundering herd" problem. This high initial load can lead to system instability, slow boot times, and service startup failures.

## The Solution

This script acts as a `systemd` service that intelligently manages a predefined list of services. It launches them sequentially, only when the system is ready, preventing overload.

### Features
- **Sequential Startup:** Launches services one by one, in a defined order of priority.
- **Load-Aware:** Checks the 1-minute system load average and waits until it is below a threshold before proceeding.
- **Adaptive Threshold:** The load threshold intelligently increases after each service starts, accounting for the rising baseline load of a healthy system.
- **Configurable Delays:** Allows for custom delays after each service start to let the system stabilize.
- **Simple Configuration:** All logic and configuration are contained in a single, easy-to-edit shell script.

## Requirements
- A `systemd`-based Linux distribution (e.g., Raspberry Pi OS).
- `bash`
- `bc` (to handle floating-point math). If not installed: `sudo apt install bc`

## Installation

1.  **Place the Script**

    Copy the `startup_orchestrator.sh` script to `/usr/local/bin/`.

    ```bash
    sudo cp startup_orchestrator.sh /usr/local/bin/
    sudo chmod +x /usr/local/bin/startup_orchestrator.sh
    ```

2.  **Disable Individual Service Autostart**

    The orchestrator must be in full control. Disable the services you wish to manage from starting on their own.

    ```bash
    sudo systemctl disable <service1_name>.service
    sudo systemctl disable <service2_name>.service
    # ...and so on
    ```

3.  **Create the Orchestrator Service**

    Create a `systemd` service file to run the orchestrator at boot.

    ```bash
    sudo nano /etc/systemd/system/startup-orchestrator.service
    ```

    Paste the following content:

    ```ini
    [Unit]
    Description=Custom Startup Orchestrator
    After=network-online.target

    [Service]
    Type=oneshot
    ExecStart=/usr/local/bin/startup_orchestrator.sh

    [Install]
    WantedBy=multi-user.target
    ```

4.  **Activate the System**

    Enable the new service and reboot.

    ```bash
    sudo systemctl enable startup-orchestrator.service
    sudo systemctl daemon-reload
    sudo reboot
    ```

## Configuration

All customization is done by editing the variables at the top of the `startup_orchestrator.sh` script.

-   **`SERVICES_TO_START`**: An array of service names to manage. The order determines startup priority.
-   **`INITIAL_LOAD_THRESHOLD`**: The "all clear" load value required before starting the first service.
-   **`SUBSEQUENT_LOAD_INCREMENT`**: How much to raise the threshold after each subsequent service starts.
-   **`POST_START_DELAY`**: How many seconds to wait after a service is launched for the system to settle.
-   **`BACKOFF_DELAY`**: How many seconds to wait before re-checking the load if it is too high.

## Monitoring

To watch the orchestrator work in real-time during a boot sequence, use `journalctl`:

```bash
journalctl -u startup-orchestrator.service -f
