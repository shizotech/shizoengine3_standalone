# nettask — ShizoScript Process Daemon

A lightweight service daemon for [ShizoScript](https://github.com/shizotech/shizoscript3_source) that automatically discovers, launches, monitors and restarts scripts. Each sub-directory with an entry point is treated as a managed **task**.

## Quick Start

```bash
cd /opt/my-services
shz nettask_server
```

That's it. Every sub-folder containing an `__init__.shio` or `__init__.shx` is picked up and launched as a child process. Crashed tasks are automatically restarted.

## Directory Structure

```
my-services/
├── nettask_server.shio        # the daemon script
├── shizonet.json              # optional — enables REST API
├── mqtt.json                  # optional — enables Home Assistant
├── weather_bot/
│   └── __init__.shio          # ✓ discovered & launched
├── api_server/
│   └── __init__.shx           # ✓ compiled scripts work too
├── shared_lib/
│   └── utils.shio             # ✗ ignored (no __init__ file)
└── notes.txt                  # ✗ ignored (not a directory)
```

## How It Works

1. **Discovery** — on startup, nettask scans the working directory for immediate sub-folders. Any folder containing `__init__.shio` or `__init__.shx` becomes a managed task.
2. **Launch** — each task is started as a separate `shz` process via the `subprocess` module.
3. **Watchdog** — the main loop checks all tasks every `poll_interval` milliseconds (default `5000`). If a task has exited, it is restarted automatically.
4. **Control** — optionally, tasks can be started, stopped and monitored via a **Shizonet API** or **Home Assistant MQTT**.

## Configuration

Both config files are optional. If a file doesn't exist, the corresponding feature is silently disabled.

### shizonet.json

Enables the Shizonet network API for controlling tasks programmatically from other ShizoScript instances or any TCP client.

```json
{
    "port": 9100,
    "name": "nettask-daemon"
}
```

| Key    | Type   | Default            | Description                            |
|--------|--------|--------------------|----------------------------------------|
| `port` | int    | `9100`             | TCP port for the Shizonet server       |
| `name` | string | `"nettask-daemon"` | Service name advertised on the network |

### mqtt.json

Enables Home Assistant integration via MQTT Discovery. Each task is represented as a set of entities grouped under a single HA device.

```json
{
    "broker":        "tcp://homeassistant.local:1883",
    "user":          "myuser",
    "pass":          "mypass",
    "client_id":     "nettask_daemon",
    "ha_prefix":     "homeassistant",
    "device_id":     "nettask_daemon",
    "device_name":   "Nettask Daemon",
    "poll_interval": 5000
}
```

| Key              | Type   | Default                  | Description                          |
|------------------|--------|--------------------------|--------------------------------------|
| `broker`         | string | `"tcp://localhost:1883"` | MQTT broker URI                      |
| `user`           | string | `""`                     | MQTT username                        |
| `pass`           | string | `""`                     | MQTT password                        |
| `client_id`      | string | `"nettask_daemon"`       | MQTT client identifier               |
| `ha_prefix`      | string | `"homeassistant"`        | HA MQTT Discovery prefix             |
| `device_id`      | string | `"nettask_daemon"`       | Unique device identifier in HA       |
| `device_name`    | string | `"Nettask Daemon"`       | Display name of the device in HA     |
| `poll_interval`  | int    | `5000`                   | Watchdog / state sync interval in ms |

## Shizonet API

When `shizonet.json` is present, the following endpoints are available over the local network.

| Endpoint  | Data Parameter | Response                        | Description            |
|-----------|----------------|---------------------------------|------------------------|
| `ping`    | —              | `"pong"`                        | Health check           |
| `list`    | —              | `[{ dir, path, running }, ...]` | List all managed tasks |
| `status`  | app name       | `{ dir, path, running }`        | Status of a single task|
| `start`   | app name       | `{ success, message }`          | Start a stopped task   |
| `stop`    | app name       | `{ success, message }`          | Stop a running task    |
| `restart` | app name       | `{ success, message }`          | Restart a task         |

### Example — calling from another ShizoScript

```
client = shizonet.client("nettask-daemon");
apps = client.get("list");
std.print(apps);

client.get("restart", "weather_bot");
```

## MQTT Topics

When `mqtt.json` is present, nettask publishes and subscribes to the following topics:

| Topic                          | Direction | Payload      | Description                     |
|--------------------------------|-----------|--------------|---------------------------------|
| `nettask/availability`         | publish   | `online`     | Daemon online status (retained) |
| `nettask/<task>/state`         | publish   | `ON` / `OFF` | Current task state (retained)   |
| `nettask/<task>/set`           | subscribe | `ON` / `OFF` | Command to start or stop task   |
| `nettask/<task>/restart`       | subscribe | `PRESS`      | Command to restart task         |
| `nettask/<task>/path`          | publish   | script path  | Entry point path (retained)     |

## Home Assistant

Once `mqtt.json` is configured and the daemon is running, each task automatically appears under a single **Nettask Daemon** device in Home Assistant with the following entities:

| Entity         | Type          | Description                                |
|----------------|---------------|--------------------------------------------|
| Switch         | `switch`      | Turn ON to start, turn OFF to stop         |
| Status         | `binary_sensor` | Shows whether the task is currently running |
| Restart        | `button`      | Press to restart the task                  |
| Script Path    | `sensor`      | Diagnostic — shows the entry point path    |

All entities share an availability topic. When the daemon stops, every entity shows as **unavailable** in HA.

No manual HA YAML configuration is needed. Everything is handled via [MQTT Discovery](https://www.home-assistant.io/integrations/mqtt/#mqtt-discovery).

### Future: Custom Task Status

> Tasks will be able to publish their own status information (e.g. "processing", "idle", "error") via a shared MQTT topic or shizonet callback. This allows richer monitoring directly in the HA dashboard beyond simple ON/OFF state.

### Prerequisites

1. MQTT integration enabled in HA (**Settings → Devices & Services → MQTT**)
2. Discovery enabled (default: ON)
3. Discovery prefix matches `ha_prefix` in `mqtt.json` (default: `homeassistant`)
4. MQTT user has publish/subscribe permissions on `nettask/#` and `homeassistant/#`

## Running as a Systemd Service

Create `/etc/systemd/system/nettask.service`:

```ini
[Unit]
Description=ShizoScript Nettask Daemon
After=network-online.target mosquitto.service
Wants=network-online.target

[Service]
Type=simple
User=shizo
WorkingDirectory=/opt/my-services
ExecStart=/usr/local/bin/shz nettask_server
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Then enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now nettask
sudo journalctl -u nettask -f
```

## Requirements

| Module       | Required | Purpose                      |
|--------------|----------|------------------------------|
| `subprocess` | always   | Launching and managing tasks |
| `mqtt`       | optional | Home Assistant MQTT bridge   |

Both modules ship with the standard ShizoScript distribution.

## License

Part of the [ShizoScript](https://github.com/shizotech/shizoscript3_source) project.