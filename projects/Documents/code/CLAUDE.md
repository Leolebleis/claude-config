# Code Directory

This is the root directory for various projects related to disqt.com infrastructure.

**Before working on any subproject, always read its CLAUDE.md first.** This applies whether you're editing local files, running SSH commands, or doing cross-project orchestration. Subproject CLAUDE.md files contain critical context (build steps, deploy procedures, known issues) that won't load automatically when working from this parent directory.

## Projects

| Project | Description | CLAUDE.md |
|---------|-------------|-----------|
| **disqt-discord-bot/** | Discord bot + DisqtModes CS2 plugin | `disqt-discord-bot/CLAUDE.md` |
| **lgsm-info-api/** | Game server status API (Go). nginx caches `/servers` (10min TTL, stale-while-revalidate) | `lgsm-info-api/CLAUDE.md` |
| **minecraft-updater/** | Minecraft plugin auto-updater (Python) | `minecraft-updater/CLAUDE.md` |
| **disqt-info-website/** | disqt.com website | `disqt-info-website/CLAUDE.md` |
| **miaro-scheduler-api/** | Scheduler API | `miaro-scheduler-api/CLAUDE.md` |
| **metrics/** | VPS metrics monitoring design docs | `metrics/docs/plans/CLAUDE.md` |
| **ableton-mcp/** | Ableton MCP server | -- |
| **pygame/** | Pygame projects | -- |
| **vps-wiki/** | VPS documentation | -- |
| **cs2-map-mistakes/** | CS2 notes site content (deployed to disqt.com/cs/) | -- |
| **cs-nades/** | CS2 grenade lineups app (Astro SSR + Python scraper, deployed to disqt.com/cs/nades/). GitHub: `disqt/cs-nades` (public) | -- |

## Static Notes Site (disqt.com/cs/)

Private notes hosted at `https://disqt.com/cs/`. Dark-themed static HTML, `noindex` meta tag.

### Locations
```
/home/dev/notes/cs/                    # VPS root (served by nginx)
/home/dev/notes/cs/index.html          # Index page listing all notes
/home/dev/notes/cs/map-mistakes/       # CS2 map mistakes
/home/dev/notes/cs/nades/              # CS2 grenade lineups (auto-scraped from csnades.gg)
```

### nginx
Location block in `/etc/nginx/sites-enabled/disqt.com`:
```nginx
location /cs/ {
    alias /home/dev/notes/cs/;
    index index.html;
    try_files $uri $uri/ =404;
}
```

### Adding New Pages
1. Create subfolder: `ssh dev "mkdir -p /home/dev/notes/cs/<topic>/"`
2. SCP `index.html` + assets to subfolder
3. Add `<li>` entry to `/home/dev/notes/cs/index.html`
4. No nginx changes needed

## CS2 Dedicated Server

Server accessible via SSH: `ssh cs` (hostname: disqt.com, port 24420, user: cs)

### Server Locations
```
/home/cs/cs2/                     # CS2 game files
/home/cs/cs2/game/csgo/cfg/       # Configuration files
/home/cs/cs2/game/csgo/addons/    # Plugins (Metamod, CounterStrikeSharp)
/home/cs/disqt-bot/               # Discord bot + DisqtModes source
/home/cs/start-cs2.sh             # Start script
/home/cs/stop-cs2.sh              # Stop script
```

### Server Control
```bash
ssh cs "/home/cs/start-cs2.sh"    # Start
ssh cs "/home/cs/stop-cs2.sh"     # Stop
ssh cs "screen -r cs2"            # Attach to console (Ctrl+A,D to detach)
```

### Update Workflow (Git-based)
```
/home/cs/cs2-modded-server/          # Private fork of kus/cs2-modded-server
/home/cs/cs2-modded-server/custom_files/  # Our customizations (committed to fork)
/home/cs/sync-mods.sh                # Copies repo files -> CS2 install, overlays custom_files, patches gameinfo.gi
```
- **Auto-update**: Daily cron at 5am fetches upstream, ff-only merges, syncs.
- **Manual update**: `ssh cs "cd /home/cs/cs2-modded-server && git pull upstream master && git push origin master"` (post-merge hook handles sync+restart).
- **Deploy custom_files changes**: Edit in repo, commit, push, then `sync-mods.sh` + restart.
- **CounterStrikeSharp**: v1.0.362 (latest as of 2026-02-11)

### Active Plugins
| Plugin | Purpose |
|--------|---------|
| **GameModeManager** | Modes (!mode), maps (!map, !maps), RTV, voting |
| **DisqtModes** | Modifiers, bots, workshop maps, tips |
| **CS2AnnouncementBroadcaster** | Announcements |
| **SimpleAdmin** | Admin commands |
| **InventorySimulator** | Skins |
| **BotAI** | Bot behavior (BROKEN -- memory patches outdated, see Known Issues) |

### Broken/Disabled Plugins
| Plugin | Status | Issue |
|--------|--------|-------|
| **Deathmatch (NockyCZ v1.3.0)** | Disabled from mode list | `OnWeaponCanAcquire` DynamicHook crashes: `Invalid function pointer`. No alternatives exist. Re-enable when upstream fixes. |
| **BotAI (K4ryuu)** | Loaded but non-functional | Memory patches broken after Valve updates. Confirmed by maintainer on issue #266. |

### DisqtModes Commands (v2.0)
- Modifiers: `!headshot`, `!pistol`, `!vampire`, `!ammo`
- Bots: `!bot add [n] [ct|t]`, `!bot kick [ct|t]`, `!bot difficulty [0-3]`
- Workshop: `!workshop <URL or ID>`
- Help: `!help`

Note: Mode switching is handled by **GameModeManager** (`!mode` in-game), not DisqtModes.

### Known Issues

#### Deathmatch Mode Disabled (2026-02-11)
Both DM options are broken:
- **Plugin DM** (NockyCZ/CS2-Deathmatch v1.3.0): `OnWeaponCanAcquire` hook crashes with `Invalid function pointer` after Valve updates. Bots can't acquire weapons -> fall back to knives. Can also crash the server (`FATAL ERROR: WriteEnterPVS: GetEntServerClass failed`).
- **Valve DM**: Bots default to AWPs due to broken buying AI. No fix without hooks.
- **No alternatives**: NockyCZ's is the only CS2 DM plugin in the CSS ecosystem. All forks are stale.
- **Custom behavior tree deployed**: `custom_files/addons/scripts/ai/dont_buy/bt_default.kv3` moves `action_equip_weapon` to top priority. Partial improvement for other modes but can't fix the core DM issue.
- **To re-enable**: When upstream updates the Deathmatch plugin, add it back to `GameModeManager.json` List array.

#### Bot Add Still Adds Extra Bots
**Symptom:** `!bot add 1` sometimes adds 2 bots.

**Investigated (all applied but issue persists):**
- `bot_join_after_player 0` in bots.cfg
- `bot_quota 0` with `bot_quota_mode "normal"`
- `mp_autoteambalance 0` and `mp_limitteams 0`

**Possible remaining causes:**
- Game mode configs resetting bot cvars on mode switch
- CS2 engine behavior with `bot_add` commands
- Need to investigate what happens during mode transitions

#### Warmup Duration
- Set `mp_warmuptime 10` in server.cfg (was 30)
- Some game modes override this in their cfg files

### Bot Configuration
- Default: `bots.cfg` sets `bot_quota 0` (no bots)
- Most modes override this via `custom_*.cfg` with `bot_quota 10; bot_quota_mode fill` (fills server, bots leave as humans join)
- Solo modes (practice, aim, prefire, course, bhop, kz, surf) and structured modes (comp, wingman, 1v1) have no default bots
```
bot_quota 10                   # Target total players (bots + humans)
bot_quota_mode "fill"          # Bots leave as humans join
bot_join_after_player 0        # Don't auto-join when human joins
mp_autoteambalance 0           # Allow unbalanced teams
mp_limitteams 0                # No team size limits
bot_difficulty 5               # 1=pacifist, 2=easy, 3=normal, 4=hard, 5=expert
```

### Build & Deploy DisqtModes
```bash
ssh cs "cd /home/cs/disqt-bot/DisqtModes && dotnet build -c Release"
ssh cs "cp /home/cs/disqt-bot/DisqtModes/bin/Release/net8.0/DisqtModes.dll /home/cs/cs2/game/csgo/addons/counterstrikesharp/plugins/DisqtModes/"
ssh cs "cp -r /home/cs/disqt-bot/DisqtModes/lang /home/cs/cs2/game/csgo/addons/counterstrikesharp/plugins/DisqtModes/"
ssh cs "/home/cs/stop-cs2.sh && sleep 3 && /home/cs/start-cs2.sh"
```

### Config Files That Affect Behavior
- `/home/cs/cs2/game/csgo/cfg/server.cfg` - Base server settings
- `/home/cs/cs2/game/csgo/cfg/bots.cfg` - Bot behavior and quotas
- `/home/cs/cs2/game/csgo/cfg/*.cfg` - Game mode configs (ffa.cfg, comp.cfg, etc.)
- Mode configs can override server.cfg settings!

### Discord Bot
- Location: `/home/cs/disqt-bot/`
- Service: `sudo systemctl restart disqt-bot`
- Config: `/home/cs/disqt-bot/.env`
- Commands: `/cs exec`, `/cs map`, `/cs maps`, `/cs status`, `/cs bot add/kick/difficulty`
- Mode switching is done in-game via **GameModeManager** (`!mode`), not the Discord bot

### Performance Tuning (Applied)
- **Kernel:** `/etc/sysctl.d/99-gameserver.conf` -- UDP buffers 4MB, backlog 5000, vm.swappiness=10, vm.dirty_ratio=40 (shared across all game servers)
- **server.cfg CVars:** `sv_maxrate 0`, `sv_minrate 128000`, `sv_parallel_sendsnapshot 1`, `sv_clockcorrection_msecs 15`
- **Tickrate:** CS2 is locked at 64 tick with sub-tick. Not configurable.
- **Invalid CVars:** `net_splitpacket_maxrate`, `net_splitrate`, `net_maxcleartime`, `sv_pure` do NOT exist in CS2 (CSGO-era, removed in Source 2)
- Full research: `metrics/docs/plans/2026-02-07-cs2-server-optimization.md`

### Debugging
- CSS logs: `/home/cs/cs2/game/csgo/addons/counterstrikesharp/logs/`
- Server console: `ssh cs "screen -r cs2"` (often flooded with AI BT messages)
- Apply cvar changes live: `ssh cs "screen -S cs2 -p 0 -X stuff 'cvar_name value\n'"`
- Server crash logs: `/home/cs/logs/cs2-*.log` (check tail for `FATAL ERROR`)
- Check plugin errors: `grep -i 'error\|exception' /home/cs/cs2/game/csgo/addons/counterstrikesharp/logs/log-all$(date +%Y%m%d).txt`
- **`[AI BT]: Bot does not have a weapon.`**: Bots literally have no guns -- weapon acquisition failed upstream (broken plugin hook, not a behavior tree issue).
- **`Invalid function pointer`**: A DynamicHook is stale after Valve updates. The plugin needs recompiling against current CSS SDK.
- **`FATAL ERROR: WriteEnterPVS: GetEntServerClass failed`**: Entity corruption, often downstream from broken plugin hooks.

### Plugin Fragility Pattern
Any CSS plugin using **DynamicHook** or **MemoryPatch** will break when Valve ships CS2 updates. This includes Deathmatch.dll and BotAI.dll. Pure event-based plugins (DisqtModes, GameModeManager) are stable across updates.

## Xonotic Dedicated Server

Server accessible via SSH: `ssh xonotic` (hostname: disqt.com, port 24420, user: xonotic)

Managed via **LinuxGSM** (`/home/xonotic/xntserver`). Uses tmux for console.

### Server Locations
```
/home/xonotic/xntserver                        # LGSM entry point
/home/xonotic/serverfiles/                     # Game files + binary
/home/xonotic/serverfiles/xntserver/data/server.cfg  # Server config
/home/xonotic/lgsm/                            # LGSM internals
```

### Server Control
```bash
ssh xonotic "/home/xonotic/xntserver start"    # Start
ssh xonotic "/home/xonotic/xntserver stop"     # Stop
ssh xonotic "/home/xonotic/xntserver restart"  # Restart
ssh xonotic "/home/xonotic/xntserver details"  # Status + details
ssh xonotic "/home/xonotic/xntserver console"  # Attach to tmux console
```

### Server Details
- Port: 26420 (UDP)
- Max players: 8
- Default gametype: deathmatch
- Bots: 4 (minplayers), skill 6, prefix `[DISQT]`
- Grappling hook: enabled
- RCON password: `Serveur X0N0T1C`

## Minecraft Dedicated Server

Server accessible via SSH: `ssh minecraft` (hostname: disqt.com, port 24420, user: minecraft)

Managed via **LinuxGSM** (`/home/minecraft/pmcserver`). Uses tmux for console. PaperMC 1.21.11 on Java 21 (Temurin via SDKMAN).

### Server Locations
```
/home/minecraft/pmcserver                      # LGSM entry point
/home/minecraft/serverfiles/                   # Game files (paper.jar, worlds, plugins)
/home/minecraft/serverfiles/plugins/           # Plugin JARs
/home/minecraft/serverfiles/server.properties  # Core server config
/home/minecraft/serverfiles/bukkit.yml         # Bukkit settings
/home/minecraft/serverfiles/spigot.yml         # Spigot settings
/home/minecraft/serverfiles/config/            # Paper configs
/home/minecraft/lgsm/config-lgsm/pmcserver/    # LGSM config (JVM flags, Java path)
/home/minecraft/backup.sh                      # Backup script (daily 6am cron)
```

### Server Control
```bash
ssh minecraft "/home/minecraft/pmcserver start"    # Start
ssh minecraft "/home/minecraft/pmcserver stop"     # Stop
ssh minecraft "/home/minecraft/pmcserver restart"  # Restart
```

### Console Access
```bash
# Find tmux socket and attach
ssh minecraft "tmux -S /tmp/tmux-1000/pmcserver-bb664df1 attach -t pmcserver"
# Send command to console without attaching
ssh minecraft "tmux -S /tmp/tmux-1000/pmcserver-bb664df1 send-keys -t pmcserver 'command here' Enter"
# Read console output
ssh minecraft "tmux -S /tmp/tmux-1000/pmcserver-bb664df1 capture-pane -t pmcserver -p"
```

### Java Configuration
LGSM uses full SDKMAN Java 21 path in `/home/minecraft/lgsm/config-lgsm/pmcserver/common.cfg`:
```
/home/minecraft/.sdkman/candidates/java/21.0.4-tem/bin/java
```
**Do NOT use bare `java`** -- system Java is 17, PaperMC requires 21. Using system java causes `UnsupportedClassVersionError`.

### JVM Flags
Aikar's G1GC flags with 5.5GB heap (`-Xms5632M -Xmx5632M`). Full flags in `common.cfg`.

### Active Plugins
| Plugin | Version | Purpose |
|--------|---------|---------|
| AuthMe | 5.6.0 | Offline-mode authentication |
| AxGraves | 1.26.1 | Death graves |
| BlueMap | 5.15 | 3D web map |
| BlueMapBannerMarker | 1.1 | Banner markers on BlueMap (impl-paper-1.1-all.jar) |
| BlueMapDeathMarkers | 1.4 | Death markers on BlueMap |
| BlueMapMCMapSync | 0.2 | Map sync |
| Chunky | 1.4.40 | World pre-generation |
| ChunkyBorder | 1.2.23 | World border enforcement |
| DHSupport | 0.12.0 | Distant Horizons server-side LODs |
| LuckPerms | 5.5.11 | Permissions |
| MiniMOTD | 2.2.2 | Server list MOTD |
| Multiverse-Core | 5.5.2 | Multiple worlds |
| Multiverse-Inventories | 5.3.1 | Per-world inventories |
| Multiverse-NetherPortals | 5.0.4 | Nether portal routing |
| SkinsRestorer | 15.10.0 | Offline-mode skins |

### Distant Horizons (DH) Support
- Config: `/home/minecraft/serverfiles/plugins/DHSupport/config.yml` (config_version: 10)
- Database: `/home/minecraft/serverfiles/plugins/DHSupport/data.sqlite`
- `render_distance: 500`, `generate_new_chunks: false`, `scheduler_threads: 4`
- Overworld uses `FastOverworldBuilder`, nether has `render_distance: 64`

**DH Commands (console):**
```
dhs worlds                                    # List worlds
dhs pregen start <world> <x> <z> <radius>     # Pre-gen LODs (radius in CHUNKS)
dhs pregen status <world>                      # Check progress
dhs pregen stop <world>                        # Stop pre-gen
dhs reload                                     # Reload config
dhs status                                     # Global status
```

### Backup System
- Script: `/home/minecraft/backup.sh` (runs daily at 6am via cron)
- Flow: LGSM backup -> `rclone move` to `onedrive-leo:pmc_backup` -> `rclone delete --min-age 3d` (prune)
- Zero local backup storage; OneDrive keeps 3 days of snapshots
- LGSM `maxbackups=2` as safety net if OneDrive is unreachable
- **OneDrive token expires periodically.** Fix: `ssh -t -L 53682:localhost:53682 minecraft "rclone config reconnect onedrive-leo:"` (requires SSH port forwarding for browser auth on headless VPS)

### Performance Tuning (Applied 2026-02-08)
Full audit: `docs/plans/2026-02-08-minecraft-server-optimization-audit.md`

**Key settings:**
| Setting | Value | File |
|---------|-------|------|
| `simulation-distance` | 8 (was 12) | server.properties |
| `view-distance` | 8 (was 6) | server.properties |
| `allow-flight` | true | server.properties |
| `monster-spawns` | 10 (was 1) | bukkit.yml |
| `mob-spawn-range` | 7 | spigot.yml |
| `merge-radius.item` | 3.5 | spigot.yml |
| `merge-radius.exp` | 4.0 | spigot.yml |
| `optimize-explosions` | true | paper-world-defaults.yml |
| `hopper.disable-move-event` | true | paper-world-defaults.yml |
| `hopper.ignore-occluding-blocks` | true | paper-world-defaults.yml |
| `prevent-moving-into-unloaded-chunks` | true | paper-world-defaults.yml |
| `armor-stands.do-collision-entity-lookups` | false | paper-world-defaults.yml |
| `validatenearbypoi` | 60 | paper-world-defaults.yml |
| `secondarypoisensor` | 80 | paper-world-defaults.yml |

**Kernel (shared VPS):** `vm.swappiness=10`, `vm.dirty_ratio=40` in `/etc/sysctl.d/99-gameserver.conf`

### Spark Profiling
Spark is built into Paper 1.21+. No plugin JAR needed. Use from console:
```
spark profiler start              # Start profiling
spark profiler stop               # Stop and get report URL
spark tps                         # Current TPS
spark health                      # CPU, memory, disk, network
```
Baseline report (pre-optimization): https://spark.lucko.me/KMta838srp

### Worlds
| World | Description |
|-------|-------------|
| world_new | Main survival overworld |
| world_new_nether | Nether |
| world_new_the_end | End |
| sandbox | Sandbox world |
| creative | Creative world |

### Debugging
- Server logs: `/home/minecraft/serverfiles/logs/latest.log`
- LGSM console log: `/home/minecraft/log/console/pmcserver-console.log`
- Backup log: `/home/minecraft/log/backup.log`
- Plugin configs: `/home/minecraft/serverfiles/plugins/<PluginName>/`

## VPS Metrics Monitoring

Dashboard: `https://disqt.com/metrics/` (public read-only, admin login for editing)

### Stack
| Component | Port | Service |
|-----------|------|---------|
| Node Exporter 1.10.2 | localhost:9100 | `node-exporter.service` |
| Process Exporter 0.8.7 | localhost:9256 | `process-exporter.service` |
| Prometheus 3.9.1 | localhost:9090 | `prometheus.service` |
| Grafana 12.3.2 | localhost:3000 | `grafana.service` |

### Locations
```
/home/dev/metrics/
  bin/                          # node_exporter, process-exporter, prometheus, promtool
  prometheus/prometheus.yml     # Scrape config
  prometheus/data/              # Time series storage (30d retention)
  process-exporter/config.yml   # Process name mappings
  grafana/                      # Grafana data (db, provisioning)
  grafana-dist/                 # Grafana binaries + assets
  grafana.ini                   # Grafana config
```

### Tracked Processes
| Process | Match Method |
|---------|-------------|
| CS2 | comm: `cs2` |
| Minecraft | cmdline: `.*paper\.jar.*` |
| Xonotic | cmdline: `.*xonotic.*` |
| Discord bot | cmdline: `.*bot\.py.*` |
| lgsm-info-api | cmdline: `.*lgsm-info-api.*` |
| miaro-scheduler-api | cmdline: `.*miaro.*` |
| nginx | comm: `nginx` |
| prometheus | comm: `prometheus` |
| grafana | comm: `grafana` |

### Admin
- Login: `admin` / `Serveur Grafana`
- Config: `/home/dev/metrics/grafana.ini`
- Restart: `ssh dev "sudo systemctl restart grafana"`
- All services: `ssh dev "sudo systemctl restart node-exporter process-exporter prometheus grafana"`
