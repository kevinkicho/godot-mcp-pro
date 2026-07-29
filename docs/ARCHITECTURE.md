# Godot MCP Pro — architecture (post-1.36)

## Planes

| Plane | Transport | Code |
|-------|-----------|------|
| **Edit** | WS 6505–6509 (plugin ↔ open MCP server) | `websocket_server.gd`, `command_router.gd`, `commands/*` |
| **Run** | TCP 6510–6514 (preferred) + file IPC fallback | `mcp_game_inspector_service.gd`, `utils/runtime_tcp_server.gd`, `utils/runtime_tcp_client.gd` |
| **Media** | FFmpeg CLI | `commands/media_commands.gd` |
| **Web** | Optional Playwright | `server/src/web-playwright.ts` |
| **Tests** | GUT / GdUnit CLI | `commands/test_framework_commands.gd` |

## Shared utilities

| File | Role |
|------|------|
| `utils/script_io.gd` | res:// text/json writers |
| `utils/runtime_tcp_server.gd` | Game-side TCP probe server |
| `utils/runtime_tcp_client.gd` | Editor-side TCP client |
| `utils/node_utils.gd` | Node ownership helpers |
| `utils/property_parser.gd` | Property value parsing |

## Adding a command

1. Implement in `commands/*_commands.gd` extending `base_command.gd`
2. Register `get_commands()` dict of name → Callable
3. Preload module in `command_router.gd`
4. Optionally add LITE schema in `server/src/tools.ts`
5. Bump `plugin.cfg` + CHANGELOG when shipping

## Run probe flow

```
run_session_start
  → RuntimeTcpServer (game) accepts 127.0.0.1:6510+
  → base_command.send_game_command prefers RuntimeTcpClient
  → file IPC if TCP unavailable and editor is playing
run_session_stop
```

See `RUNTIME_PROBE.md` for auth, queue limits, and Playwright web notes.
