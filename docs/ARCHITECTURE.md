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
2. Return methods from `get_commands()` → `{"tool_name": _handler}`
3. **Auto-registered** by `command_router.gd` (any `*_commands.gd` under `commands/`)
4. Optionally add LITE/CLI schema in `server/src/tools-lite.ts` or `tools-cli.ts`
5. Bump `plugin.cfg` + CHANGELOG when shipping

### Shared helpers (prefer these)

| Helper | Use |
|--------|-----|
| `write_script_file` / `write_json_file` | Create scripts/resources |
| `ensure_autoload` / `maybe_add_autoload` | Register singletons |
| `send_game_command` | Runtime probe (TCP → file) |

## Run probe flow

```
run_session_start
  → RuntimeTcpServer (game) accepts 127.0.0.1:6510+
  → base_command.send_game_command prefers RuntimeTcpClient
  → file IPC if TCP unavailable and editor is playing
run_session_stop
```

See `RUNTIME_PROBE.md` for auth, queue limits, and Playwright web notes.
