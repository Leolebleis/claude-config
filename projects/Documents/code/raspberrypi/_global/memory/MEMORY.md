# Raspberry Pi Project Memory

## Pi Healthcheck

```bash
vcgencmd measure_temp                    # CPU temp
vcgencmd get_throttled                   # 0x0 = clean
free -h                                  # RAM (8GB total, stack uses ~1.8GB)
df -h /                                  # Disk (250GB SSD)
docker stats --no-stream                 # Container resource usage
tailscale status                         # Tailscale connectivity
docker exec gluetun wget -qO- https://ipinfo.io  # VPN IP check
```

## People

- **Rue** = Leo's girlfriend. Tailscale user `qp6pjntdp9@privaterelay.appleid.com`, device `rues-phone` (iOS), `autogroup:member`.

## Key Facts

- Pi 4B **8GB RAM**, Pi OS Lite 64-bit (Debian Trixie)
- 250GB NVMe SSD via USB 3.0, Argon ONE M.2 case
- SSH: `ssh pi` (local) or `ssh pi-ts` (Tailscale)
- User: `leo`, key auth, password fallback: `Serveur Raspberrypi`
- Tailscale IP: `100.115.104.35`, MagicDNS enabled
- Pi LAN IP: `192.168.1.168`
- ProtonVPN Plus (WireGuard, Sweden server, Prowlarr indexer access only)
- Real-Debrid (~3 EUR/mo) for downloads via RDTClient

## Mediastack State (2026-02-17)

**15 containers.** ~1.8GB RAM. All under `/opt/mediastack/`.

### Containers (media)
| Container | Image | Network |
|-----------|-------|---------|
| gluetun | qmcgaw/gluetun | host port: 9696 (Prowlarr only) |
| rdtclient | rogerfar/rdtclient | default (port 6500) |
| prowlarr | linuxserver/prowlarr | service:gluetun |
| sonarr | linuxserver/sonarr | default (port 8989) |
| radarr | linuxserver/radarr | default (port 7878) |
| jellyfin | jellyfin/jellyfin | default (port 8096) |
| seerr | ghcr.io/seerr-team/seerr | default (port 5055) |
| watchtower | containrrr/watchtower | default |
| prefetcharr | phueber/prefetcharr | default (polls Jellyfin, prefetches episodes via Sonarr) |

### Containers (infra)
| Container | Image | Purpose |
|-----------|-------|---------|
| glance | glanceapp/glance | Homepage dashboard |
| nginx | nginx:alpine | Reverse proxy (port 80) |
| prometheus | prom/prometheus | Metrics (7-day retention) |
| cadvisor | gcr.io/cadvisor/cadvisor | Container metrics (port 8180) |
| node-exporter | prom/node-exporter | System metrics |
| grafana | grafana/grafana | Dashboard UI |

### Glance Dashboard
- Config: `/opt/mediastack/config/glance/glance.yml` (auto-reloads on change)
- Widgets: server-stats, docker-containers, bookmarks, RDTClient stats (qBit API on port 6500), Tailscale devices, Jellyfin latest, Hacker News, Reddit (r/selfhosted, r/homelab), weather, calendar, GitHub releases, xkcd
- Tailscale API key in `/opt/mediastack/.env` (expires every 90 days, renew at https://login.tailscale.com/admin/settings/keys)

### Nginx Reverse Proxy
- `http://raspberrypi/` -> Glance (port 8080)
- `http://raspberrypi/media/` -> Jellyfin (port 8096, BaseUrl=/media)
- `http://raspberrypi/metrics/` -> Grafana (port 3000, subpath mode)
- Config: `/opt/mediastack/config/nginx/default.conf`
- **After changing nginx config**: must `docker exec nginx nginx -s reload`
- **Grafana subpath fix**: `proxy_pass http://grafana:3000;` (NO trailing slash) with `GF_SERVER_SERVE_FROM_SUB_PATH=true`

### Credentials
- Sonarr API: `ef99fa5723c744f08c5c4e87208a16a3`
- Radarr API: `200b133c066a415eb4caab0be8b0a615`
- Prowlarr API: `5d3bae047a8744699f78a205cc1965ea`
- RDTClient: `admin` / `mediastack1` (port 6500, emulates qBittorrent API)
- Real-Debrid API key: `CHBZIB23WJ4QW4MJVIQ22PMVSGKDAZO32BAMX6RXKFIECUGXT47A`
- Grafana: `admin` / `mediastack` (anonymous viewing enabled)
- Jellyfin API: `62396ca567054d8aa4cb1e0d41a136dd`
- Seerr API: `MTc3MTE4MTY4MTk4MjZhZDdiOTIyLTZkY2YtNDUwZS04ZjVjLTAwZmNmMzJmZjRmZQ==`
- Seerr login: `Termiduck` / `T#6kd&82zj0m1H` (Jellyfin auth)

### Jellyfin Config
- **BaseUrl**: `/media` (set in `/opt/mediastack/config/jellyfin/config/network.xml`)
- **API base**: `http://jellyfin:8096/media/` (internal Docker), `http://raspberrypi:8096/media/` (external)
- Seerr/Sonarr/Radarr connect via direct port 8096 -- BaseUrl doesn't affect their API calls

### Jellyfin Plugins (13 active)
Intro Skipper, Jellyfin Enhanced, Open Subtitles, Fanart, File Transformation, Plugin Pages, **Home Screen Sections v2.5.6.0**, **Media Cleaner v2.24.0.0**, AudioDB, MusicBrainz, OMDb, Studio Images, TMDb

**Jellyfin Enhanced** integrates Seerr into Jellyfin UI (search+request in one place). Config: `/opt/mediastack/config/jellyfin/plugins/configurations/Jellyfin.Plugin.JellyfinEnhanced.xml`. Seerr URL set to `http://192.168.1.168:5055`.

### Seerr External URLs
- Sonarr: `http://raspberrypi:8989`
- Radarr: `http://raspberrypi:7878`
- Jellyfin: `http://raspberrypi:8096`
- Application URL: `http://raspberrypi:5055`

### Remote Path Mappings (Sonarr + Radarr)
- Host: `192.168.1.168`, Remote: `/data/downloads/`, Local: `/media/downloads/`
- RDTClient mounts `./media/downloads:/data/downloads`, Sonarr/Radarr mount `./media:/media`.

### Disk Space Management
- **Media Cleaner** (Jellyfin plugin, GUID `607fee7797eb41febf2226844d99ffb0`): movies 7d, episodes 3d, individual episode deletion, AnyUser watched, favorites protected, `KeepSeriesKind: Last`, tag `mediacleaner_keep` to protect items
- **Prefetcharr** (container): polls Jellyfin every 5min, prefetches 2 episodes ahead via Sonarr. Config: `/opt/mediastack/config/prefetcharr/config.toml`
- **Sonarr**: `autoUnmonitorPreviouslyDownloadedEpisodes: true`, `deleteEmptyFolders: true`
- **Radarr**: `autoUnmonitorPreviouslyDownloadedMovies: true`, `deleteEmptyFolders: true`
- **Seerr**: `activeMonitorType: "pilot"` (only downloads Ep 1 on new show request). `partialRequestsEnabled: true` for manual episode requests. Set via `PUT /api/v1/settings/sonarr/0` with `activeMonitorType` field
- **Media Cleaner scheduled task**: "Played media cleanup" runs every 24h inside Jellyfin
- **Repo URL**: `https://raw.githubusercontent.com/shemanaev/jellyfin-plugin-repo/master/manifest.json`

### Monitoring Stack
- Prometheus config: `/opt/mediastack/config/prometheus/prometheus.yml`
- Grafana provisioning: `/opt/mediastack/config/grafana/provisioning/`
- Custom "Pi Overview" dashboard (uid: `pi-overview`) set as home
- Scrape targets: prometheus (self), node-exporter:9100, cadvisor:8180
- Volumes: `prometheus-data`, `grafana-data`

## Gotchas Discovered

- **UK ISPs block torrent sites at TCP level** -- Prowlarr must be behind VPN
- **Prowlarr behind gluetun needs FIREWALL_OUTBOUND_SUBNETS** to reach LAN
- **All inter-service URLs use host IP** (192.168.1.168) across Docker networks
- **Remote path mapping required** -- RDTClient sees `/data/downloads/`, Sonarr/Radarr see `/media/downloads/`
- **Jellyfin Enhanced plugin config** owned by root -- need `sudo` to edit XML
- **Grafana subpath proxy** -- `proxy_pass` must NOT have trailing slash when using `serve_from_sub_path`
- **Grafana dashboard downloads** -- check revision number; Grafana API 404s silently to JSON
- **Seerr config permissions** -- `sudo chown -R leo:leo` after migration
- **RDTClient password requires a digit** -- used `mediastack1` (not `mediastack`)
- **RDTClient settings API** -- PUT to `/Api/Settings` with array of `{key, value}` objects. Auth via `/Api/Authentication/Create` (first user) then `/Api/Authentication/Login`. Returns 402 "Setup required" before first user.
- **RDTClient queueing_enabled doesn't persist** via qBit API `setPreferences`. Workaround: set Radarr download priority to "Last" (0) instead of "First"
- **Real-Debrid goes down for maintenance** -- RDTClient shows deserialize error with HTML maintenance page. Just wait, Sonarr/Radarr will retry.
- **docker compose down doesn't remove orphaned containers** -- containers not in new compose file need manual `docker stop/rm`
- **Jellyfin creates files as root** inside container
- **`ssh pi` uses mDNS** which can fail -- use `ssh pi-ts` as fallback
- **Prometheus/Grafana don't expose ports** to host -- access via Docker DNS or nginx
- **Node-exporter `--path.rootfs=/rootfs`** changes read path but metric label stays `mountpoint="/"` (NOT `/rootfs`). Dashboard queries must use `mountpoint="/"`
- **Grafana provisioned dashboards can't be edited via API** -- returns "Cannot save provisioned dashboard". Must edit source JSON file on disk + restart Grafana container
- **Editing Grafana dashboard files over SSH** -- use `sed` for simple replacements or SCP a Python script. Nested quote escaping with SSH + heredoc + Python + JSON is fragile
- **Rollback to qBittorrent** -- backup at `/opt/mediastack/docker-compose.yml.pre-realdebrid`, old config at `./config/qbittorrent/`
- **Jellyfin BaseUrl affects API paths** -- When BaseUrl=/media, Glance widget must use `http://jellyfin:8096/media` as base-url. Direct port access (Seerr, Sonarr, Radarr) is unaffected.
- **HSS CachedImage path ignores BaseUrl** -- HSS JS requests `/HomeScreen/CachedImage/...` without `/media/` prefix. Fix: add nginx `location /HomeScreen/ { proxy_pass http://jellyfin:8096/media/HomeScreen/; }` to rewrite the path.
- **nginx config reload required** -- After SCP'ing new default.conf, must run `docker exec nginx nginx -s reload` (container restart also works but is slower)
- **Tailscale SSH re-auth prompts** -- Tailscale SSH (`tailscale set --ssh`) requires periodic web-based re-authentication. Use `ssh pi` (LAN/mDNS) for automation, reserve `ssh pi-ts` for remote access.
- **sed on Pi breaks YAML** -- Multi-line sed insertions collapse into single lines. Use SCP (write locally, upload) for complex file edits instead of SSH+sed.
- **Jellyfin plugin configs owned by root** -- ALL plugin XML configs in `/opt/mediastack/config/jellyfin/plugins/configurations/` need `sudo` to edit
- **Playwright available for verification** -- set up at `C:\Users\leole\.claude\plugins\cache\playwright-skill\playwright-skill\4.1.0\skills\playwright-skill`. Use to verify UI state instead of assuming. Use Windows paths (not /tmp/) for script files.
- **Tailscale device tagging is one-way via API** -- `POST /device/{id}/tags` with `{"tags":[]}` returns "tagged nodes cannot be untagged without reauth". But the **admin console UI** (Machines > device > Edit tags > clear > Save) CAN remove tags. Always untag via admin console, not API.
- **Don't clean up ACL rules before untagging device** -- removing the rule for a tagged device locks it out completely.
- **`--advertise-tags` is `tailscale up` only** -- NOT a `tailscale set` flag. Use the Tailscale API to tag devices instead.
- **RDTClient reports Windows paths via qBit API** -- paths like `C:\Downloads\radarr\` instead of `/data/downloads/radarr/`. Remote path mappings in Sonarr/Radarr must cover BOTH `/data/downloads/` (Linux) AND `C:\Downloads\` (Windows) formats. Current mappings: Radarr has `C:\Downloads\radarr\` -> `/media/downloads/radarr/`, Sonarr has `C:\Downloads\` -> `/media/downloads/`.
