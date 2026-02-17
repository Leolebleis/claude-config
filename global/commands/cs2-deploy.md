# CS2 Plugin Deploy Skill

Use when deploying DisqtModes or other CounterStrikeSharp plugins to the CS2 server.

## Quick Deploy (DisqtModes)

Run these commands in sequence:

```bash
# 1. Pull latest code on server
ssh cs "cd /home/cs/disqt-bot && git pull origin main"

# 2. Build plugin
ssh cs "cd /home/cs/disqt-bot/DisqtModes && dotnet build -c Release"

# 3. Deploy DLL and lang files
ssh cs "cp /home/cs/disqt-bot/DisqtModes/bin/Release/net8.0/DisqtModes.dll /home/cs/cs2/game/csgo/addons/counterstrikesharp/plugins/DisqtModes/"
ssh cs "cp -r /home/cs/disqt-bot/DisqtModes/lang /home/cs/cs2/game/csgo/addons/counterstrikesharp/plugins/DisqtModes/"

# 4. Restart server
ssh cs "/home/cs/stop-cs2.sh && sleep 3 && /home/cs/start-cs2.sh"
```

## Deploy Config/Custom Files Changes

Server uses a git-based overlay system. All customizations live in `custom_files/` in the fork repo.

```bash
# 1. Edit files in the repo's custom_files/ directory
ssh cs "vi /home/cs/cs2-modded-server/custom_files/path/to/file"

# 2. Commit and push
ssh cs "cd /home/cs/cs2-modded-server && git add -A && git commit -m 'description' && git push origin master"

# 3. Sync overlay and restart
ssh cs "/home/cs/sync-mods.sh && /home/cs/stop-cs2.sh && sleep 3 && /home/cs/start-cs2.sh"
```

**Key paths in custom_files:**
| What | Path in custom_files/ |
|------|----------------------|
| Server-wide settings | `cfg/custom_all.cfg` |
| Bot defaults | `cfg/custom_bots.cfg` |
| Mode list/ordering | `addons/counterstrikesharp/configs/plugins/GameModeManager/GameModeManager.json` |
| DisqtModes plugin | `addons/counterstrikesharp/plugins/DisqtModes/` |
| Bot behavior tree | `addons/scripts/ai/dont_buy/bt_default.kv3` |
| Admin list | `cfg/admins.json` |

## Hot Reload (Without Restart)

If only code changes (no new dependencies):
```bash
ssh cs "screen -S cs2 -p 0 -X stuff 'css_plugins reload DisqtModes\n'"
```

Note: Hot reload sometimes fails. If it does, full restart is needed.

## Verify Deployment

Check plugin loaded:
```bash
ssh cs "tail -20 /home/cs/cs2/game/csgo/addons/counterstrikesharp/logs/log-cssharp$(date +%Y%m%d).txt | grep -i disqt"
```

Check for plugin errors:
```bash
ssh cs "grep -i 'error\|exception\|invalid function' /home/cs/cs2/game/csgo/addons/counterstrikesharp/logs/log-all$(date +%Y%m%d).txt | tail -20"
```

## Deploy Other Plugins

For plugins from the `disabled/` folder:
```bash
# Enable a plugin
ssh cs "mv /home/cs/cs2/game/csgo/addons/counterstrikesharp/plugins/disabled/PluginName /home/cs/cs2/game/csgo/addons/counterstrikesharp/plugins/"

# Disable a plugin
ssh cs "mv /home/cs/cs2/game/csgo/addons/counterstrikesharp/plugins/PluginName /home/cs/cs2/game/csgo/addons/counterstrikesharp/plugins/disabled/"
```

## Broken Plugins (as of 2026-02-11)

These plugins are loaded but non-functional due to Valve updates breaking their hooks/patches:
- **Deathmatch (NockyCZ v1.3.0)**: DISABLED from mode list. `OnWeaponCanAcquire` DynamicHook crash. No alternatives.
- **BotAI (K4ryuu)**: Loaded but memory patches are stale. Bots still switch to knives.

Both will break again after any Valve CS2 update. This is inherent to DynamicHook/memory-patch plugins.

## Server Paths Reference

| What | Path |
|------|------|
| Plugin source | `/home/cs/disqt-bot/DisqtModes/` |
| Fork repo | `/home/cs/cs2-modded-server/` |
| Custom overrides | `/home/cs/cs2-modded-server/custom_files/` |
| Deployed plugins | `/home/cs/cs2/game/csgo/addons/counterstrikesharp/plugins/` |
| Plugin configs | `/home/cs/cs2/game/csgo/addons/counterstrikesharp/configs/plugins/` |
| CSS logs | `/home/cs/cs2/game/csgo/addons/counterstrikesharp/logs/` |
| Server configs | `/home/cs/cs2/game/csgo/cfg/` |
| Sync script | `/home/cs/sync-mods.sh` |
