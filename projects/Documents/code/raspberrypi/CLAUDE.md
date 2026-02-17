# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repository contains documentation, scripts, and configuration for a **Raspberry Pi 4 Model B** used as a local network server, accessed via SSH.

## Hardware

| Component | Details |
|-----------|---------|
| Board | Raspberry Pi 4 Model B (BCM2711, quad-core Cortex-A72 @ 1.8GHz) |
| Case | Argon ONE M.2 (with fan + power button control via I2C) |
| Storage | 250GB M.2 NVMe SSD (connected via USB-C to USB-A 3.0 adapter -- **not native PCIe**) |
| Performance | ~350 MB/s sequential (USB 3.0 bottleneck), still ~8-10x faster than microSD |
| OS | Raspberry Pi OS Lite 64-bit (Debian Trixie, released 2025-12-04) -- fresh install |

## Network & Access

- Connected to local network via Ethernet (Gigabit) + WiFi configured
- Tailscale: connected, IP `100.115.104.35`
- SSH (local): `ssh pi` (resolves via `raspberrypi.local`)
- SSH (Tailscale): `ssh pi-ts` (via `100.115.104.35`, works from anywhere)
- User: `leo`, key auth (ed25519), password fallback: `Serveur Raspberrypi`
- Headless only (no micro-HDMI cable available)

## Argon ONE Case

The case requires a daemon for fan control and power button support. Without it, both are non-functional.

### Install

```bash
curl https://download.argon40.com/argon1.sh | bash
```

If the official script fails on newer Pi OS (Bookworm/64-bit), use the community C daemon: https://gitlab.com/DarkElvenAngel/argononed

### Fan Thresholds (defaults)

| CPU Temp | Fan Speed |
|----------|-----------|
| < 55C | Off |
| 55C | 10% |
| 60C | 55% |
| 65C | 100% |

Reconfigure: `argonone-config` (reboot after changing)

### Power Button

| Action | Result |
|--------|--------|
| Short press (off) | Power ON |
| Double tap (on) | Reboot |
| Long press >= 3s (on) | Soft shutdown |
| Long press >= 5s (on) | Forced shutdown |

### Troubleshooting

```bash
sudo raspi-config                # Interface Options > I2C > Enable
sudo apt install -y i2c-tools
i2cdetect -y 1                   # Should show device at 0x1a
systemctl status argononed
```

## USB SSD Boot

The Pi 4 has no exposed PCIe -- the NVMe SSD connects through USB 3.0 internally. UASP must be active for full speed.

### Verify UASP

```bash
lsusb -t   # Look for Driver=uas (good) vs Driver=usb-storage (bad)
```

### EEPROM & Boot Order

```bash
sudo rpi-eeprom-update                    # Check EEPROM version
sudo -E rpi-eeprom-config --edit          # Edit boot config
```

Set `BOOT_ORDER=0xf41` for USB-first boot (read right to left: `1`=SD, `4`=USB, `f`=loop).

## Tailscale

Installed (v1.94.2), authenticated under `Leolebleis@` account.

### Enable as Exit Node / Subnet Router

```bash
# Required: enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf

# Advertise as exit node
sudo tailscale set --advertise-exit-node

# Advertise local subnet
sudo tailscale set --advertise-routes=192.168.1.0/24
```

Routes require approval in the Tailscale admin console.

### Key Commands

```bash
tailscale status              # Connected nodes and IPs
tailscale ip                  # This device's Tailscale IP
tailscale ping <node>         # Ping another tailnet node
tailscale netcheck            # Connectivity diagnostics
```

## Mediastack (Deployed)

Dockerized media automation stack. Design: `docs/plans/2026-02-14-pi-mediastack-design.md`, Real-Debrid migration: `docs/plans/2026-02-16-realdebrid-migration-design.md`.

| Service | Port | Image | Network |
|---------|------|-------|---------|
| Gluetun | 9696 | `qmcgaw/gluetun` | VPN gateway (ProtonVPN WireGuard, Prowlarr indexer access only) |
| RDTClient | 6500 | `rogerfar/rdtclient` | default (Real-Debrid download proxy, emulates qBittorrent API) |
| Prowlarr | (via gluetun) | `linuxserver/prowlarr` | service:gluetun |
| Sonarr | 8989 | `linuxserver/sonarr` | default |
| Radarr | 7878 | `linuxserver/radarr` | default |
| Jellyfin | 8096 | `jellyfin/jellyfin` | default |
| Seerr | 5055 | `ghcr.io/seerr-team/seerr` | default |
| Watchtower | -- | `containrrr/watchtower` | default (auto-updates at 4am) |
| nginx | 80 | `nginx:alpine` | Reverse proxy (`/` -> Glance, `/media/` -> Jellyfin, `/metrics/` -> Grafana) |
| Prometheus | -- | `prom/prometheus` | Metrics store (7-day retention) |
| cAdvisor | 8180 | `gcr.io/cadvisor/cadvisor` | Container metrics |
| Node Exporter | -- | `prom/node-exporter` | System metrics |
| Grafana | 3000 | `grafana/grafana` | Monitoring dashboard |
| Glance | 8080 | `glanceapp/glance` | Homepage dashboard |
| Prefetcharr | -- | `phueber/prefetcharr` | Polls Jellyfin playback, tells Sonarr to fetch next episodes |

All under `/opt/mediastack/` (15 containers). Downloads use Real-Debrid via RDTClient (~3 EUR/mo). Prowlarr routes through gluetun VPN (UK ISP blocks indexer sites). Sonarr, Radarr, Jellyfin, Seerr on normal Docker network. Inter-service connections use Pi host IP (`192.168.1.168`), not Docker DNS names. Gluetun has `FIREWALL_OUTBOUND_SUBNETS=192.168.1.0/24` so Prowlarr can reach LAN services.

### Access URLs
- `http://raspberrypi/` -- Jellyfin (media player + Seerr requests via Jellyfin Enhanced plugin)
- `http://raspberrypi/metrics/` -- Grafana monitoring dashboard
- `http://raspberrypi.local` -- same as above, for LAN devices without Tailscale

### Jellyfin Plugins
Intro Skipper, Jellyfin Enhanced (Seerr integration), Open Subtitles, Fanart, File Transformation, Plugin Pages, **Home Screen Sections v2.5.6.0**, **Media Cleaner v2.24.0.0** + built-ins (AudioDB, MusicBrainz, OMDb, Studio Images, TMDb).

**Home Screen Sections**: Modular home page (Discover, Latest, Upcoming sections). CRITICAL: `SectionSettings` array must be pre-configured or it crashes with `.Max()` on empty collection. Configure via plugin API before first use. See MEMORY.md for full details.

### Disk Space Management

Design: `docs/plans/2026-02-16-disk-space-management-design.md`

- **Media Cleaner** (Jellyfin plugin): Deletes movies 7 days after watched, episodes 3 days after watched (individual episode deletion, not season-level). Any single user watching triggers the countdown. Favorited items are protected. Keeps latest season for continuing shows (`KeepSeriesKind: Last`). Tag items `mediacleaner_keep` to protect from deletion.
- **Prefetcharr** (container): Polls Jellyfin every 5 min for active TV playback, tells Sonarr to download 2 episodes ahead. Config: `/opt/mediastack/config/prefetcharr/config.toml`.
- **Sonarr**: `autoUnmonitorPreviouslyDownloadedEpisodes: true` -- prevents re-downloading deleted episodes.
- **Radarr**: `autoUnmonitorPreviouslyDownloadedMovies: true` -- prevents re-downloading deleted movies.
- **Seerr**: `activeMonitorType: "pilot"` -- only downloads Episode 1 when a show is requested. Prefetcharr handles subsequent episodes. `partialRequestsEnabled: true` for manual episode requests.

### Remote Path Mappings
Sonarr and Radarr have remote path mappings: `/data/downloads/` -> `/media/downloads/` (host: `192.168.1.168`). Required because RDTClient mounts `./media/downloads:/data/downloads` while Sonarr/Radarr mount `./media:/media`.

### Docker Commands

```bash
ssh pi "cd /opt/mediastack && docker compose up -d"      # Start all
ssh pi "cd /opt/mediastack && docker compose down"        # Stop all
ssh pi "cd /opt/mediastack && docker compose ps"          # Status
ssh pi "cd /opt/mediastack && docker compose logs -f"     # Follow logs
ssh pi "docker stats --no-stream"                         # Resource usage
```

## System Administration

### Updates

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt autoremove -y
sudo rpi-eeprom-update        # Check firmware separately
```

**Do not use `rpi-update`** -- that's bleeding-edge test firmware.

### Monitoring

```bash
vcgencmd measure_temp         # CPU temperature
vcgencmd get_throttled        # Throttle status (0x0 = clean)
vcgencmd measure_clock arm    # Current clock speed
free -h                       # RAM
df -h                         # Disk usage
lsblk                         # Block devices and mounts
uptime                        # Load averages
```

`get_throttled` key values: `0x0` = clean, `0x1` = under-voltage NOW, `0x4` = throttled NOW, `0x50005` = actively throttled with history.

### Static IP (Pi OS Bookworm uses NetworkManager)

```bash
sudo nmcli con mod "Wired connection 1" ipv4.addresses 192.168.1.100/24
sudo nmcli con mod "Wired connection 1" ipv4.gateway 192.168.1.1
sudo nmcli con mod "Wired connection 1" ipv4.dns "1.1.1.1,8.8.8.8"
sudo nmcli con mod "Wired connection 1" ipv4.method manual
sudo nmcli con down "Wired connection 1" && sudo nmcli con up "Wired connection 1"
```

Older guides referencing `dhcpcd.conf` are outdated for Bookworm+. Use `nmcli` or `sudo nmtui`.

### Hostname

```bash
sudo hostnamectl set-hostname <name>
```

### raspi-config

Swiss army knife for SSH, I2C, SPI, WiFi, locale, boot order, etc:

```bash
sudo raspi-config
```


<claude-mem-context>
# Recent Activity

<!-- This section is auto-generated by claude-mem. Edit content outside the tags. -->

*No recent activity*
</claude-mem-context>