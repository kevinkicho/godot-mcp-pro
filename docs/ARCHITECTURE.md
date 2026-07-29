# Architecture

Godot MCP Pro (open fork) — post-**1.38**.

## Overview

```
AI assistant  ──stdio/MCP──►  Node server (server/)  ──WebSocket 6505–6509──►  Editor plugin
                                      │
                                      └── (optional) TCP 6510–6514 ──►  running game (MCPGameInspector)
```

JSON-RPC 2.0 over WebSocket for **edit-time** work. A separate **run plane** probes the playing game without blocking the editor bridge.

## Planes

| Plane | Transport | Code |
|-------|-----------|------|
| **Edit** | WS **6505–6509** (plugin ↔ MCP server) | `websocket_server.gd`, `command_router.gd`, `commands/*` |
| **Run** | TCP **6510–6514** (preferred) + file IPC fallback | `mcp_game_inspector_service.gd`, `utils/runtime_tcp_*`, `utils/runtime_capture.gd` |
| **Media** | FFmpeg CLI | `commands/media_commands.gd` |
| **Web** | Optional Playwright | `server/src/web-playwright.ts` |
| **Tests** | GUT / GdUnit CLI | `commands/test_framework_commands.gd` |

## Plugin structure

| Path | Role |
|------|------|
| `plugin.gd` / `plugin.cfg` | EditorPlugin entry, version |
| `websocket_server.gd` | Accepts MCP server connections |
| `command_router.gd` | Auto-discovers `commands/*_commands.gd` |
| `commands/base_command.gd` | Result helpers, script I/O, `send_game_command` |
| `commands/*_commands.gd` | Tool handlers (`get_commands()` map) |
| `mcp_game_inspector_service.gd` | Runtime autoload: tree, frames, dispatch |
| `mcp_input_service.gd` / `mcp_screenshot_service.gd` | Input + screenshot helpers |
| `utils/*` | Shared I/O, TCP, capture, node/property utils |

## Shared utilities

| File | Role |
|------|------|
| `utils/script_io.gd` | `res://` text/json writers |
| `utils/runtime_tcp_server.gd` | Game-side TCP probe server (queue, auth) |
| `utils/runtime_tcp_client.gd` | Editor-side TCP client |
| `utils/runtime_capture.gd` | Video record, property timeline, event/log ring |
| `utils/node_utils.gd` | Node ownership helpers |
| `utils/property_parser.gd` | Property value parsing |

## Server structure

| Path | Role |
|------|------|
| `server/src/index.ts` | MCP server, version, tool routing |
| `server/src/websocket-bridge.ts` | Connect to plugin WS |
| `server/src/tools.ts` (+ lite/cli splits) | Tool schemas |
| `server/src/tool-groups.ts` | Category map for lite/CLI |
| `server/src/godot-cli.ts` | Headless / CLI Godot ops |
| `server/src/game-runtime-bridge.ts` | Direct runtime TCP when editor offline |
| `server/src/web-playwright.ts` | HTML5 export probe (optional) |

## Adding a command

1. Implement in `commands/*_commands.gd` extending `base_command.gd`  
2. Return methods from `get_commands()` → `{"tool_name": _handler}`  
3. **Auto-registered** by `command_router.gd` (any `*_commands.gd` under `commands/`)  
4. Optionally add LITE/CLI schema in `server/src/tools-lite.ts` or `tools-cli.ts`  
5. Bump `plugin.cfg` + CHANGELOG when shipping  

### Shared helpers (prefer these)

| Helper | Use |
|--------|-----|
| `write_script_file` / `write_json_file` | Create scripts/resources |
| `ensure_autoload` / `maybe_add_autoload` | Register singletons |
| `send_game_command` | Runtime probe (TCP → file IPC) |

## Run probe flow

```
run_session_start
  → RuntimeTcpServer (game) accepts 127.0.0.1:6510+
  → base_command.send_game_command prefers RuntimeTcpClient
  → file IPC if TCP unavailable and editor is playing
run_session_stop
```

Video / timeline / events live in **`RuntimeCapture`** (delegated from the inspector).  
Details: [RUNTIME_PROBE.md](RUNTIME_PROBE.md).

## Reliability

- Edit WS: auto-reconnect with backoff; heartbeat ping/pong  
- Run TCP: request queue (max 48), max clients 8, optional token auth  
- Mutations: prefer UndoRedo via editor APIs  

## Related

- [INSTALL.md](INSTALL.md)  
- [COMMAND_SURFACE.md](COMMAND_SURFACE.md)  
- [CONTRIBUTING.md](CONTRIBUTING.md)  
