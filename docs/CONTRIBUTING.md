# Contributing

How to extend this fork safely: new commands, refactors, and releases.

## Repo layout

```
godot-mcp-pro/
  addons/godot_mcp/     # Godot 4 editor plugin
    commands/            # *_commands.gd — auto-discovered
    utils/               # shared GDScript helpers
    mcp_*_service.gd     # runtime autoloads
  server/src/            # open MCP Node server (TypeScript)
  docs/                  # this documentation
  scripts/               # install + registry export
  SURFACE_REGISTRY.md    # generated command list
  CHANGELOG.md
```

## Add a plugin command

1. Create or edit `addons/godot_mcp/commands/<area>_commands.gd`  
2. Extend `base_command.gd`  
3. Implement handlers and return them from `get_commands()`:

```gdscript
func get_commands() -> Dictionary:
	return {
		"my_tool": _my_tool,
	}
```

4. Prefer shared helpers:
   - `write_script_file` / `write_json_file`
   - `ensure_autoload` / `maybe_add_autoload`
   - `send_game_command` for runtime probe  
5. **Auto-discovery**: any `*_commands.gd` under `commands/` is registered by `command_router.gd` — no manual preload list.  
6. Optionally add LITE/CLI schemas in `server/src/tools-lite.ts` or `tools-cli.ts`.  
7. Bump version + CHANGELOG when shipping (see below).

## Runtime / capture changes

| File | Role |
|------|------|
| `utils/runtime_tcp_server.gd` | Game TCP server |
| `utils/runtime_tcp_client.gd` | Editor TCP client |
| `utils/runtime_capture.gd` | Video, timeline, event logs |
| `mcp_game_inspector_service.gd` | Dispatch + remaining capture modes |

See [ARCHITECTURE.md](ARCHITECTURE.md) and [RUNTIME_PROBE.md](RUNTIME_PROBE.md).

## Server (TypeScript)

```bash
cd server
npm install
npm run build
```

- `index.ts` — MCP entry, version constant  
- `tools*.ts` / `tool-groups.ts` — tool schemas and grouping  
- `game-runtime-bridge.ts` — offline TCP bridge  
- `web-playwright.ts` — optional HTML5 probe  

## Ship a version

1. Bump `addons/godot_mcp/plugin.cfg` `version`  
2. Bump `server/package.json` + `SERVER_VERSION` in `server/src/index.ts`  
3. Update `CHANGELOG.md`  
4. Regenerate registry:

```powershell
.\scripts\export-surface-registry.ps1
```

5. Install + verify:

```powershell
.\scripts\update-install.ps1
```

6. Commit and push.

## Docs

- Update pages under `docs/` when behavior changes  
- Keep [docs/README.md](README.md) TOC in sync  
- Link new pages from root [../README.md](../README.md)

## Style notes

- Project-neutral: no hard-coded game names or absolute content paths  
- JSON-RPC style errors via `error()` / `error_invalid_params()` on base_command  
- Prefer UndoRedo through existing editor APIs for mutations  

## License

- Upstream plugin: proprietary — see [../LICENSE](../LICENSE)  
- Open `server/` and fork-added tooling: follow [../FORK.md](../FORK.md)  
