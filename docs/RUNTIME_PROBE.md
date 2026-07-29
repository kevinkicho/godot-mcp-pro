# Native run probe (TCP + video)

## Architecture

```
Agent → MCP server → Editor WS (edit plane)
                  ↘ Game TCP 127.0.0.1:6510-6514 (run plane)
                     file IPC fallback when TCP down
```

## Quick start

1. Enable plugin / `ensure_runtime_autoloads`
2. Play scene (`run_session_start`) or launch game with autoloads
3. `run_ping_runtime` or `runtime_ping`
4. Probe: `get_game_scene_tree`, `run_find_nodes`, `assert_node_state`, …
5. Optional video: `run_record_start` → play → `run_record_stop` → `media_extract_keyframes`

## Auth (optional)

```
set_runtime_token token=secret
# and for the MCP Node process:
#   MCP_RUNTIME_TOKEN=secret
```

Every TCP request includes `"token":"secret"`. Clear with `set_runtime_token clear=true`.

Localhost-only bind; token is extra protection if other local processes are untrusted.

## Queue limits

| Limit | Value |
|-------|-------|
| Max TCP clients | 8 |
| Max queued requests | 48 |
| Ports | 6510–6514 |

Busy runtime returns `code: queue_full`; clients retry automatically.

## Web export only

```
web_serve_export export_dir=path/to/html5
web_playwright_probe export_dir=... screenshot_path=... record_video_dir=...
web_serve_stop
```

Requires optional `playwright` package — not used for desktop Play.
