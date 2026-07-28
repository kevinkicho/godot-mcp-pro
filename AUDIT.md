# Godot MCP Pro — Full Code Audit (2026-07-27)

Scope: `addons/godot_mcp/**`, `server/src/**` (open fork server).

## Executive summary

CLI MCP is solid. Most console spam and live-editor flakiness came from:

1. MeshLibrary type/API misuse (fixed earlier: `set_item_preview`, shape pairs)
2. Broken `play_scene` contract with open server (`mode: "custom"` + `path`)
3. Input IPC writing **editor** `user://` instead of **game** user dir
4. Port range 6510–6514 reconnect churn with no listeners
5. Unserialized game IPC races
6. Plugin only works when Survivor editor is open (operational, not a bug)

---

## Critical (fixed in 1.16.1)

| # | Issue | Fix |
|---|--------|-----|
| 1 | `play_scene` ignored `path` when `mode: "custom"` | Support `main` / `current` / `custom`+`path` + legacy path-in-mode |
| 2 | Input sim wrote wrong `user://` dir | Editor writers use `get_game_user_dir()` |
| 3 | Concurrent IPC races | Command router serializes `execute()` |
| 4 | `params` non-Dictionary crashed WS handler | Guard + JSON-RPC -32602 |
| 5 | Ports 6505–6514 vs server 6505–6509 | Plugin max port **6509**; CONNECTING timeout |
| 6 | `execute_script` null `current_scene` | Fall back to tree root / error |
| 7 | MeshLibrary preview/shapes type errors | Texture2D previews; Shape+Transform pairs |
| 8 | WS pong to wrong client | Reply on the sending socket; track pending.ws |

## High (fixed or mitigated)

| # | Issue | Status |
|---|--------|--------|
| `update_project_uids` overwrites open scenes | Skip open scenes |
| Heartbeat reconnect spam | `print_verbose` instead of `push_warning` |
| `firstOpenClient` races | Per-socket message handling |

## High (remaining — design / later)

| # | Issue | Recommendation |
|---|--------|----------------|
| Arbitrary `execute_*_script` | Keep localhost-only; optional deny-list for `OS.execute` |
| Write tools not strictly confined to `res://` | Gate mutate tools with `begins_with("res://")` + no `..` |
| Expression.parse on agent strings | Prefer PropertyParser only |
| Auto-dismiss dialogs can confirm destructive OK | Whitelist / prefer cancel |
| Nested result envelopes on game IPC | Unwrap once at boundary |

## Medium (remaining)

- Input file overwrite if two writes before game reads (queue merge)
- MeshLibrary collision only scans one level under root children
- Status panel / docs still mention older port lore
- Dynamic ListTools schemas empty for discovered editor methods
- Autoload injection can leave permanent project.godot diffs after crash

## Operational checklist (not code bugs)

1. Open **Survivor - Godot Engine** (not Project Manager only)
2. Plugin **Godot MCP Pro** enabled
3. Bottom panel **MCP Pro** shows connected client(s)
4. `get_connection_status` → `editor_connected: true`
5. Reload project after addon deploy

## Files touched in 1.16.1

- `commands/scene_commands.gd` — play_scene
- `commands/input_commands.gd` — game user dir
- `commands/test_commands.gd` — game user dir
- `commands/compat_commands.gd` — MeshLibrary + open-scene UID skip
- `websocket_server.gd` — ports, params guard, connect timeout
- `command_router.gd` — serialize execute
- `mcp_game_inspector_service.gd` — null scene host
- `plugin.gd` / `plugin.cfg` — version 1.16.1
- `server/src/websocket-bridge.ts` — per-socket ping/pong + pending

## Solid areas

- `base_command.gd` helpers (`get_game_user_dir`, scene guards)
- `property_parser.gd`, `node_utils.gd`
- `mcp_screenshot_service.gd`, input event construction
- `godot-cli.ts` process launch / headless ops
