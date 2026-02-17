---
name: tailscale
description: Use when managing Tailscale on servers, Pi, or VPS - configuring exit nodes, subnet routers, SSH, serve/funnel, ACLs, DNS, certificates, auth keys, or troubleshooting connectivity and key expiry
---

# Tailscale Reference

Complete CLI, API, and configuration reference for Tailscale network management.

## Quick Decision: `up` vs `set`

| Use `tailscale set` | Use `tailscale up` |
|---|---|
| Change ONE setting on a running node | First-time connection / re-auth |
| Settings persist automatically | Flags NOT persisted (must re-specify all) |
| `set --advertise-exit-node` | `up --auth-key=tskey-xxx` |

**Golden rule**: After initial `tailscale up`, always use `tailscale set` for changes.

## Common Operations

```bash
# Status & diagnostics
tailscale status                          # Connection table
tailscale status --json                   # Machine-readable
tailscale ping --until-direct <device>    # Check direct path
tailscale netcheck                        # NAT, DERP, UDP diagnostics

# Exit node
sudo tailscale set --advertise-exit-node  # Offer (needs IP forwarding + admin approval)
sudo tailscale set --exit-node=<ip>       # Use
sudo tailscale set --exit-node=           # Stop using

# Subnet router
sudo tailscale set --advertise-routes=192.168.1.0/24

# SSH
sudo tailscale set --ssh                  # Enable on destination
ssh device-name                           # Connect via MagicDNS

# Serve (tailnet-only) & Funnel (public internet)
tailscale serve 3000                      # Proxy local:3000 to tailnet
tailscale funnel 3000                     # Proxy local:3000 to internet (ports 443/8443/10000 only)
tailscale serve --bg 3000                 # Background (survives reboot)

# Certificates
sudo tailscale cert machine.tailnet.ts.net

# File transfer
tailscale file cp ./file device:          # Send
sudo tailscale file get .                 # Receive (Linux needs sudo)

# Headless server setup (one-liner)
sudo tailscale up --auth-key=tskey-xxx --hostname=my-server --ssh --advertise-routes=192.168.1.0/24
```

## Critical Gotchas

- **IP forwarding required** before advertising exit node or subnet routes
- **`tailscale up` drops unspecified flags** -- use `tailscale set` for incremental changes
- **Funnel: only ports 443, 8443, 10000** -- no other ports
- **`tailscale set --ssh` hangs existing SSH connections** to that Tailscale IP
- **Key expiry: 180 days default** -- disable for infrastructure in admin console
- **Linux DNS**: use systemd-resolved; DHCP clients fight tailscaled over resolv.conf
- **Cert Transparency**: machine names become public when HTTPS enabled
- **Taildrop can't send to tagged nodes** -- use SCP over Tailscale SSH instead
- **`--advertise-tags` is a `tailscale up` flag, NOT `tailscale set`** -- use Tailscale API to tag devices instead

## ACL Policy Structure

```jsonc
{
  "acls": [
    {"action": "accept", "src": ["group:admins"], "dst": ["tag:prod:*"]}
  ],
  "groups": {"group:admins": ["alice@example.com"]},
  "tagOwners": {"tag:prod": ["group:admins"]},
  "autoApprovers": {
    "routes": {"192.168.1.0/24": ["tag:router"]},
    "exitNode": ["tag:exit-node"]
  },
  "ssh": [{"action": "check", "src": ["autogroup:member"], "dst": ["autogroup:self"], "users": ["autogroup:nonroot"]}],
  "tests": [
    {"src": "alice@example.com", "accept": ["tag:prod:80"]},
    {"src": "alice@example.com", "deny": ["tag:prod:22"]}
  ]
}
```

**ACLs are deny-by-default, directional, port-level (not HTTP path-level).**

Identifiers: users, groups, tags, autogroups (`autogroup:member`, `autogroup:owner`, `autogroup:self`, `autogroup:internet`), IPs, CIDRs.

## REST API

Base URL: `https://api.tailscale.com/api/v2`. Auth: `-u "tskey-api-xxxxx:"` or `Authorization: Bearer`. Use `-` as tailnet ID.

Key endpoints: `/tailnet/-/devices`, `/device/{id}/tags`, `/tailnet/-/acl`, `/tailnet/-/acl/validate`, `/tailnet/-/keys`.

## `tailscale set` Full Flags

```bash
# Network
--advertise-exit-node[=false]    --advertise-routes=CIDR[,CIDR]
--exit-node=<ip>                 --exit-node-allow-lan-access
--accept-routes                  --accept-dns=false

# Security
--ssh[=false]                    --shields-up[=false]

# Identity
--hostname=NAME                  --nickname=NAME    --operator=USER

# Features
--auto-update    --webclient    --advertise-connector
```

## Serve & Funnel Modes

```bash
tailscale serve 3000                           # Reverse proxy (tailnet)
tailscale serve /path/to/dir                   # File server
tailscale serve text:"Hello"                   # Static text
tailscale serve --tcp=5432 localhost:5432       # TCP forwarding
tailscale funnel 3000                          # Public internet (443/8443/10000 only)
tailscale [serve|funnel] --bg 3000             # Background mode
tailscale [serve|funnel] status                # Show config
tailscale [serve|funnel] reset                 # Clear all
```

## Auth Keys

Types: one-off, reusable, ephemeral (auto-remove offline), pre-approved, tagged. Expiry 1-90 days. Create via admin console or API.

## Diagnostics Cheat Sheet

```bash
tailscale status --json | jq '.Self.Online'    # Am I connected?
tailscale netcheck --format=json | jq '.UDP'   # UDP working?
tailscale ping --c 1 --timeout=5s <device>     # Can I reach it?
tailscale whois 100.x.y.z                      # Who is this IP?
tailscale metrics print                        # Prometheus metrics
tailscale bugreport --diagnose                 # Full diagnostic
```
