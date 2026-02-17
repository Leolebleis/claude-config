---
name: pi-mediastack
description: Use when managing the Pi mediastack - start/stop services, check VPN, view logs, monitor health, troubleshoot containers. Invoke whenever working with the Docker media stack on the Raspberry Pi.
---

# Pi Mediastack Management

## Context

Dockerized media stack at `/opt/mediastack/` on Raspberry Pi 4B. Access via `ssh pi`.

10 containers: gluetun (ProtonVPN WireGuard), qBittorrent, Prowlarr, Sonarr, Radarr, Jellyfin, Seerr, Byparr, Watchtower, Port Manager.

Design doc: `docs/plans/2026-02-14-pi-mediastack-design.md`
Implementation plan: `docs/plans/2026-02-14-pi-mediastack-plan.md`

## Networking Architecture

- **qBittorrent + Prowlarr** behind gluetun (VPN) -- UK ISP blocks torrent sites at TCP level
- **Sonarr, Radarr, Jellyfin, Seerr** on default Docker network
- Gluetun has `FIREWALL_OUTBOUND_SUBNETS=192.168.1.0/24` for LAN access
- All inter-service connections use **Pi host IP (192.168.1.168)**, NOT Docker DNS names
- Port Manager auto-syncs gluetun forwarded port to qBittorrent

## Credentials

- qBittorrent: `admin` / `mediastack`
- Sonarr API: `ef99fa5723c744f08c5c4e87208a16a3`
- Radarr API: `200b133c066a415eb4caab0be8b0a615`
- Prowlarr API: `5d3bae047a8744699f78a205cc1965ea`

## Quick Commands

All commands run via `ssh pi "<command>"`.

### Stack Control

```bash
cd /opt/mediastack && docker compose up -d
cd /opt/mediastack && docker compose down
cd /opt/mediastack && docker compose restart <service>
cd /opt/mediastack && docker compose ps
cd /opt/mediastack && docker compose pull && docker compose up -d
cd /opt/mediastack && docker compose logs -f <service>
```

### VPN Health

```bash
docker exec gluetun wget -qO- https://ipinfo.io
docker exec gluetun cat /tmp/gluetun/forwarded_port
docker logs gluetun --tail 30
```

### Resource Monitoring

```bash
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}'
df -h /
du -sh /opt/mediastack/media/*
free -h
vcgencmd measure_temp
```

### Web UIs

| Service | LAN | MagicDNS (Tailscale) |
|---------|-----|----------------------|
| qBittorrent | `http://raspberrypi.local:8080` | `http://raspberrypi:8080` |
| Sonarr | `http://raspberrypi.local:8989` | `http://raspberrypi:8989` |
| Radarr | `http://raspberrypi.local:7878` | `http://raspberrypi:7878` |
| Prowlarr | `http://raspberrypi.local:9696` | `http://raspberrypi:9696` |
| Jellyfin | `http://raspberrypi.local:8096` | `http://raspberrypi:8096` |
| Seerr | `http://raspberrypi.local:5055` | `http://raspberrypi:5055` |

## Troubleshooting

### VPN not connecting
1. Check gluetun logs: `docker logs gluetun --tail 50`
2. Verify .env has correct `WIREGUARD_PRIVATE_KEY`
3. Try different server: edit `SERVER_COUNTRIES` in `.env`, then `docker compose restart gluetun`

### qBittorrent no peers / slow
1. Check port forwarding: `docker exec gluetun cat /tmp/gluetun/forwarded_port`
2. Port Manager should auto-sync. Verify: `docker logs port-manager --tail 10`
3. If port is empty, gluetun NAT-PMP isn't working -- check ProtonVPN Plus subscription

### Sonarr/Radarr can't reach qBittorrent
- Download client host must be `192.168.1.168` (Pi host IP), port `8080`
- qBittorrent is in gluetun's network namespace, accessed via host port mapping

### Prowlarr can't reach Sonarr/Radarr
- Prowlarr is behind gluetun. It reaches Sonarr/Radarr via `FIREWALL_OUTBOUND_SUBNETS` + host IP
- prowlarrUrl must be `http://192.168.1.168:9696` (not localhost)
- Sonarr/Radarr URLs must be `http://192.168.1.168:8989` / `http://192.168.1.168:7878`

### Indexers not finding content
- Check Prowlarr has active indexers: Prowlarr API `/api/v1/indexer`
- Trigger Prowlarr sync: POST `/api/v1/command` with `{"name":"ApplicationIndexerSync"}`
- Check Sonarr has indexers: Sonarr API `/api/v3/indexer`
- UK ISP blocks many torrent sites -- Prowlarr must be behind VPN

### qBittorrent IP ban (auth failures)
1. Stop qBittorrent: `docker compose stop qbittorrent`
2. Remove password hash: delete `WebUI\Password_PBKDF2` line from config
3. Restart and set permanent password immediately

### Disk full
1. Check: `du -sh /opt/mediastack/media/*`
2. Clear completed downloads in qBittorrent
3. Seeding limits already set: ratio 1.0, 24h max seed, auto-remove

### Container won't start
```bash
cd /opt/mediastack && docker compose logs <service> --tail 50
```
Common: permission issues (check PUID/PGID), port conflicts, image not available for arm64.
