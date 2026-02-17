# Memory

## Workflow Preferences

- **PRs for user repos**: Create PRs but don't merge them. User reviews and merges in GitHub.
- **ALWAYS use superpowers skills**: For ANY debugging, planning, or implementation task, invoke the relevant superpowers skill FIRST (systematic-debugging, writing-plans, brainstorming, etc.). No exceptions, even for "simple" issues. The user HATES rambling and rapid-fire guessing. Be methodical or don't start.

## VPS Access

- SSH hosts: `cs`, `dev`, `minecraft`, `xonotic` (all disqt.com:24420, key `~/.ssh/id_ed25519`)
- `dev` has passwordless sudo. `minecraft` does NOT have sudo -- use `dev` for system-wide changes (sysctl, etc.).

## CS2 Server

- **Based on [kus/cs2-modded-server](https://github.com/kus/cs2-modded-server)**: Private fork at `disqt/cs2-modded-server`. Repo cloned on VPS at `/home/cs/cs2-modded-server/`.
- **gameinfo.gi gets overwritten by Valve updates**: SteamCMD replaces it with the stock version, removing the Metamod `SearchPaths` entry. `patch-metamod.sh` fixes this (uses awk to insert after `Game_LowViolence` line -- must come BEFORE `Game csgo` for Metamod's libserver.so to take priority).
- **Mode-leaking bug**: The repo's 156-line `server.cfg` resets all settings between mode switches. Our old 26-line version didn't, causing bhop/surf settings to leak into competitive. Fixed by adopting the repo's server.cfg with our settings in `custom_all.cfg`.
- **custom_files overlay**: Our customizations live in `custom_files/` (committed to fork). `sync-mods.sh` copies repo files into CS2 install, then overlays custom_files on top, then patches gameinfo.gi.
- **Rebase complete (2026-02-11)**: Fork pushed, custom_files committed, initial sync done, server restarted with all plugins loading. Post-merge hook deployed (auto sync+restart on `git pull`). Daily cron at 5am fetches upstream, ff-only merges, syncs. Branch is `master`. Update workflow: `ssh cs "cd /home/cs/cs2-modded-server && git pull upstream master && git push origin master"` (post-merge hook handles the rest).
- **sync-mods.sh overlay source**: Must overlay from `$REPO/custom_files/` (git-tracked), NOT `$CS2/custom_files/` (stale). Bug was found and fixed 2026-02-11.
- **`-disable_workshop_command_filtering`**: Required in start-cs2.sh launch args. Without it, Valve blocks cvars like `bot_loadout` on workshop maps. Added 2026-02-11.
- **Console frame spike spam**: `UNEXPECTED LONG FRAME DETECTED` floods the console, making it unreadable. `engine_frametime_warnings_enable 0` and `engine_frametime_print_report 0` exist but don't work at runtime. May need launch params. UNSOLVED.
- **Deathmatch mode DISABLED (2026-02-11)**: Both the plugin-based DM and Valve's native DM are broken. Removed from `!modes` menu until upstream fixes.
  - **NockyCZ/CS2-Deathmatch v1.3.0**: `OnWeaponCanAcquire` DynamicHook crashes with `Invalid function pointer` after Valve updates. Last updated Oct 2025. No maintained alternatives exist in the CSS ecosystem.
  - **Valve native DM**: Bots default to AWPs due to broken bot buying AI. No plugin can fix this without hooking (which breaks).
  - **BotAI plugin (K4ryuu)**: Memory patches outdated -- confirmed broken by maintainer (GitHub issue #266). Was supposed to prevent bots from using knives.
- **Bot knife root cause**: The `dont_buy` behavior tree (`addons/scripts/ai/dont_buy/bt_default.kv3`) only has `action_equip_weapon weapon="BEST"` in the lowest-priority "hunt" fallback. Bots in attack/investigate states never equip weapons. We deployed a modified tree with equip at top priority (still in custom_files), but it can't help if bots have no weapons (because DM plugin crashes on acquisition).
- **`[AI BT]: Bot does not have a weapon.`**: Console spam means the behavior tree can't find a weapon to equip. Usually caused by the DM plugin's broken `OnWeaponCanAcquire` hook preventing weapon acquisition entirely.
- **DynamicHook/memory-patch fragility**: Both BotAI and Deathmatch plugins broke after Valve updates. This is a recurring pattern -- any plugin using DynamicHook or memory signatures will break when Valve ships a CS2 update. Expect this for any hook-based plugin.
- **GameModeManager mode ordering**: Controlled solely by JSON array order in `GameModes.List`. No sorting/priority config exists in the plugin. Dictionary preserves insertion order (.NET Core+).
- **CounterStrikeSharp version**: Server runs v1.0.362 (latest as of 2026-02-11).
- **Iterator crash pattern**: Don't modify collections (like weapon lists) during iteration. Collect items first, then remove.
- **CSGO CVars that don't exist in CS2**: `net_splitpacket_maxrate`, `net_splitrate`, `net_maxcleartime`, `sv_pure` -- all removed in Source 2.
- **`sudo nice` breaks Steam Runtime**: Runs as root, looks for `/root/.steam/`. Fatal crash.
- **Kernel tuning**: `/etc/sysctl.d/99-gameserver.conf` applied -- benefits CS2, Minecraft, Xonotic (shared VPS).

## Xonotic Server

- Managed via **LinuxGSM** (`/home/xonotic/xntserver`), uses **tmux** (not screen)
- No systemd service or crontab -- won't auto-restart on reboot
- Stock maps only, port 26420
- **Invisible walls bug**: Client-side version mismatch, not a server issue. Fix: ensure matching Xonotic version, clear `~/.xonotic/data/dlcache/`

## Minecraft Server

- Managed via **LinuxGSM** (`/home/minecraft/pmcserver`), uses **tmux**
- **Java version trap**: System `java` is 17, but PaperMC 1.21.11+ requires **Java 21** via SDKMAN. LGSM config now uses full path: `/home/minecraft/.sdkman/candidates/java/21.0.4-tem/bin/java` (fixed 2026-02-08). Using system java causes `UnsupportedClassVersionError`.
- **LGSM tmux socket**: After restart, socket is at `/tmp/tmux-1000/pmcserver-bb664df1`. Use `tmux -S /tmp/tmux-1000/pmcserver-bb664df1` to access (the `-L` flag doesn't always work).
- **Backup system**: Daily at 6am via `/home/minecraft/backup.sh`. Uses `rclone move` to upload to `onedrive-leo:pmc_backup`, then `rclone delete --min-age 3d` to prune. Zero local storage. OneDrive token expires periodically -- fix with `ssh -t -L 53682:localhost:53682 minecraft "rclone config reconnect onedrive-leo:"` (needs SSH port forwarding for browser auth).
- **Spark is built into Paper 1.21+**: No separate JAR needed. Commands available in server console directly.
- **DHSupport pregen syntax**: `dhs pregen start <world_name> <centerX> <centerZ> <radius_in_chunks>` -- radius is in **chunks** not blocks. `dhs pregen stop/status <world_name>` to control.
- **DHSupport config regeneration**: If config_version is outdated, delete config.yml, reload (`dhs reload`), then re-apply customizations. Don't try to bump the version number manually.
- **Plugin updater** deployed at `/home/minecraft/mc-updater/` (updater.py + plugins.json)
- **Plugin test server**: Boot throwaway instance in `/tmp/mc-test/` on port 25566 with Java 21. Must copy plugin config dirs (not just JARs) and exclude DHSupport/ (cache). First boot takes ~105s due to plugin remapping.
- **impl-paper-1.1-all.jar** is actually **BlueMap BannerMarker** by Miraculixx (discontinued)
- **Optimization audit**: Full plan at `docs/plans/2026-02-08-minecraft-server-optimization-audit.md`

## Static Notes Site (disqt.com/cs/)

- **Location**: `/home/dev/notes/cs/` on VPS, served by nginx
- **nginx**: `location /cs/` block in `/etc/nginx/sites-enabled/disqt.com`, alias to `/home/dev/notes/cs/`
- **Structure**: Each topic gets a subfolder with `index.html` + assets (e.g. `map-mistakes/index.html` + `frames/`)
- **Index page**: `/home/dev/notes/cs/index.html` lists all notes
- **Style**: Dark theme (#0d1117 bg), inline CSS, no external dependencies, `noindex` meta tag
- **First page**: CS2 map mistakes summary with 33 video frame screenshots at `disqt.com/cs/map-mistakes/`
- **Adding new pages**: Create subfolder with index.html + assets, add `<li>` to index.html. No nginx changes needed.

## YouTube Transcript Tools

- **`youtube-transcript-api`** (Python): `pip install youtube-transcript-api` -- fetches captions via YouTube's internal API, no API key needed
- **`yt-dlp`** (installed via winget): Can download video, extract subtitles, extract frames with ffmpeg
- **Frame extraction workflow**: Download video with yt-dlp, extract frames at specific timestamps with ffmpeg (`-ss <timestamp> -frames:v 1`)
- **ffmpeg path** (winget install): `C:/Users/leole/AppData/Local/Microsoft/WinGet/Packages/yt-dlp.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-N-122319-gf6a95c7eb7-win64-gpl/bin/ffmpeg.exe`

## CS2 Grenade Lineups Page (disqt.com/cs/nades/)

- **GitHub**: https://github.com/disqt/cs-nades (public). Branch `v2-astro-ssr` (default).
- **Stack**: Astro 5 SSR (Node adapter, port 4321), SQLite (better-sqlite3), Python scraper
- **Features**: Nickname identity (SHA-256), bookmarks, frame reports, lineup reports, result video clips (3s), submissions with metadata, technique icons, admin panel
- **Admin**: `localhost:3001` via SSH tunnel (`ssh -L 3001:127.0.0.1:3001 dev`)
- **Base path gotcha**: `base: '/cs/nades/'` in astro.config.mjs. Client-side fetch URLs use `window.__base`. `import.meta.env.BASE_URL` for server-side.
- **Env var gotcha**: `import.meta.env` is build-time only. Runtime env vars need `process.env` fallback in nades.ts and db.ts.
- **CSRF gotcha (Astro 5)**: `security.checkOrigin` defaults to `true` in Astro 5 SSR, which blocks all POST requests when behind a reverse proxy (Origin header mismatch: `https://disqt.com` vs `localhost:4321`). Fixed with `security: { checkOrigin: false }` in astro.config.mjs (2026-02-15).
- **Cookie path**: Must be `Path=/cs/nades/` (not `/`), otherwise logout won't clear the cookie behind nginx proxy.
- **VPS**: `/home/dev/cs-nades-v2/` (git clone from GitHub), `.env` has `NADES_DATA_DIR` and `NADES_DB_PATH`
- **Systemd**: `cs-nades.service` (port 4321), `cs-nades-admin.service` (port 3001, localhost only)
- **nginx**: `/cs/nades/data/` -> direct file serving (7d cache), `/cs/nades/` -> proxy to :4321, `/cs/` -> static
- **Deploy**: `git push` then `ssh dev "cd /home/dev/cs-nades-v2 && git pull && npm run build && cd admin && npm run build && cd .. && sudo systemctl restart cs-nades"`
- **Weekly cron**: Monday 6am, `update.sh` (git pull, rebuild, scrape, restart)
- **Scraper**: Parallel by map (ProcessPoolExecutor, 7 workers). Frame timing at 2/3 into VTT caption segment. 3s result clips. `MIN_NADES_PER_MAP = 8` with beginner+recommended fallback.
- **68 lineups** (2026-02-14): 7 maps (mirage 13, dust2 12, inferno 10, overpass 9, ancient 8, anubis 8, nuke 8)
- **docs/plans/ removed from repo** (2026-02-14): History cleaned with git-filter-repo. Design docs kept locally only.
- **DB tables**: accounts, bookmarks, reports, submissions, lineup_reports
- **Technique icons**: Inline SVGs (mouse left/right, jump, running). Jump icon mirrored with `scaleX(-1)`. Movement (running/walking/crouched) displayed as technique badges, not tags.
- **Technique data**: Techniques in scraped data: `left`, `left_jump`, `both_jump`, `right`. Movements: `stationary`, `running`, `walking`, `crouched_walking`, `crouched_stationary`. `decomposeTechnique()` handles technique, `movementComponent()` handles movement.
- **Community badge**: Infrastructure in place (isCommunityNade checks source_url). Will appear when user submissions are approved.
- **sqlite3 installed on VPS** (2026-02-15): `apt install sqlite3` on dev host. Useful for direct DB queries.

## Process-Exporter Gotchas

- `comm` is the **binary basename** (first 15 chars of `/proc/PID/comm`), not the service name
- Xonotic binary comm = `xonotic-linux64`, not `xonotic` -- use `cmdline` matcher instead
- Go binaries compiled as `main` have comm = `main` -- use `cmdline` with path pattern
- When both `comm` and `cmdline` are specified, **AND logic** applies -- both must match
- Always verify comm with `cat /proc/PID/comm` before writing config
