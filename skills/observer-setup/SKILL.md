---
name: observer-setup
description: "Set up OTEL telemetry export for Claude Code on a new machine. Configures env vars to send data to the Workflow Observer pipeline."
---

# Workflow Observer - OTEL Setup

Sets up Claude Code's OpenTelemetry export on the current machine so sessions are tracked by the Workflow Observer at `http://raspberrypi/observer/`.

## Prerequisites

- Workflow Observer stack running on the Pi (otel-collector on port 4318)
- Machine must be on the same LAN as the Pi (192.168.1.167), or use Tailscale (100.115.104.35)

## Required Environment Variables

```
CLAUDE_CODE_ENABLE_TELEMETRY=1
OTEL_LOGS_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_EXPORTER_OTLP_ENDPOINT=http://<PI_IP>:4318
OTEL_LOG_TOOL_DETAILS=1
OTEL_RESOURCE_ATTRIBUTES=host.name=<MACHINE_NAME>
```

## Setup Procedure

### 1. Determine the Pi's IP

- **LAN**: `192.168.1.167`
- **Tailscale**: `100.115.104.35`

### 2. Set env vars (platform-specific)

**Windows** (persistent user env vars):
```bash
setx CLAUDE_CODE_ENABLE_TELEMETRY 1
setx OTEL_LOGS_EXPORTER otlp
setx OTEL_METRICS_EXPORTER otlp
setx OTEL_EXPORTER_OTLP_PROTOCOL http/protobuf
setx OTEL_EXPORTER_OTLP_ENDPOINT http://192.168.1.167:4318
setx OTEL_LOG_TOOL_DETAILS 1
setx OTEL_RESOURCE_ATTRIBUTES host.name=windows-pc
```

**Linux / macOS** (add to `~/.bashrc` or `~/.zshrc`):
```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_LOGS_EXPORTER=otlp
export OTEL_METRICS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_ENDPOINT=http://192.168.1.167:4318
export OTEL_LOG_TOOL_DETAILS=1
export OTEL_RESOURCE_ATTRIBUTES=host.name=$(hostname)
```

### 3. Restart terminal

`setx` and `.bashrc` changes only apply to **new** terminal windows. Fully close and reopen.

### 4. Verify

```bash
echo $OTEL_EXPORTER_OTLP_PROTOCOL
# Should print: http/protobuf
```

Then use Claude Code for a minute and check:
```bash
ssh pi "docker logs otel-collector --tail 5 2>&1"
# Should show "log records" entries
```

## Optional Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `OTEL_LOG_USER_PROMPTS` | `0` | Set to `1` to include actual prompt text (sensitive) |
| `OTEL_METRIC_EXPORT_INTERVAL` | `60000` | Metrics flush interval (ms) |
| `OTEL_LOGS_EXPORT_INTERVAL` | `5000` | Logs flush interval (ms) |

## Gotchas

- **`OTEL_EXPORTER_OTLP_PROTOCOL` is required** -- without it, Claude Code silently sends nothing
- **Windows**: `setx` does NOT affect the current terminal, only new ones
- **Linux**: Claude Code doesn't source `.bashrc` in non-login shells -- verify env vars are actually set in the Claude Code process
