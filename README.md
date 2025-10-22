# Raspberry Pi Startup Orchestrator v2

An intelligent, state-aware script to start `systemd` services sequentially, based on system load, to prevent boot-time resource contention on Raspberry Pi and other SBCs.

*MIT License - Copyright (c) 2025 Luis Branco | https://github.com/BrancoDigital*

---

## The Problem

On resource-constrained devices, starting multiple heavy services simultaneously at boot can cause a "thundering herd" problem. This high initial I/O and CPU load can lead to system instability, slow boot times, and even service startup failures as processes time out.

## The Solution

This script runs as a single `systemd` service at boot. It then takes control of starting a predefined list of *other* services sequentially. By monitoring the system's load average, it ensures that it only launches the next service when the system is ready, preventing overload and ensuring a stable, predictable boot sequence.

### How It Works

1.  **Reads a Priority List:** The orchestrator reads a list of services you define, in the order you want them to start.
2.  **Waits for a Green Light:** Before starting the very first service, it waits for the 1-minute system load average to drop below an initial "all clear" threshold.
3.  **Issues the Start Command:** Once the system is calm, it uses `systemctl` to start the service and immediately moves on, letting `systemd` manage the process itself.
4.  **Pauses to Settle:** It waits for a configurable delay period to allow the newly started service to initialize and for the system load to stabilize.
5.  **Calculates a New Threshold:** It intelligently raises the load threshold to account for the new baseline load of the running service.
6.  **Repeats:** It moves to the next service in the list and repeats the process until all services have been started.

## Requirements

-   A `systemd`-based Linux distribution (e.g., Raspberry Pi OS).
-   `bash`
-   `bc` (for floating-point math). If not installed, run: `sudo apt update && sudo apt install bc`

## Installation

#### 1. Place the Orchestrator Script

Copy the `startup_orchestrator.sh` script to a standard location like `/usr/local/bin/`.

```bash
sudo cp startup_orchestrator.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/startup_orchestrator.sh```

#### 2. Disable Individual Service Autostart

**This is the most important step.** The orchestrator must be in full control of the services it manages. You must disable each service from starting on its own at boot.

```bash
sudo systemctl disable caddy.service
sudo systemctl disable gitea.service
# ...and so on for every service in your list
```

#### 3. Create the Orchestrator Service

Create a `systemd` service file to run the orchestrator itself at boot.

```bash
sudo nano /etc/systemd/system/startup-orchestrator.service
```

Paste the following content into the file:

```ini
[Unit]
Description=Custom Startup Orchestrator v2
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/startup_orchestrator.sh

[Install]
WantedBy=multi-user.target
```

#### 4. Activate the System

Enable the new orchestrator service and reboot to see it in action.

```bash
sudo systemctl enable startup-orchestrator.service
sudo systemctl daemon-reload
sudo reboot
```

## Configuration

All customization is done by editing the variables at the top of the `startup_orchestrator.sh` script.

-   **`SERVICES_TO_START`**
    An array of the exact `systemd` service names you want to manage (e.g., `"gitea.service"`). The order of the services in this list determines their startup priority.

-   **`INITIAL_LOAD_THRESHOLD`**
    The "all clear" load average required before starting the *first* service. A good starting point for a 4-core Pi is `"1.5"`.

-   **`SUBSEQUENT_LOAD_INCREMENT`**
    The magic of the adaptive threshold. This value is added to the threshold after each service starts, accounting for the rising baseline load of a healthy system. A value of `"0.7"` is a reasonable start.

-   **`POST_START_DELAY`**
    How many seconds to wait after a service is launched for the system to settle and for the 1-minute load average to begin reflecting the new state. `"30"` is a safe value.

-   **`BACKOFF_DELAY`**
    If the system load is too high, this is how many seconds the script will wait before checking again.

## Monitoring

You can watch the orchestrator's logs in real-time as the system boots to see it making decisions. Open a second SSH terminal after rebooting and run:

```bash
journalctl -u startup-orchestrator.service -f
```
