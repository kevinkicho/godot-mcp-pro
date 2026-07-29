# Native run probe (TCP + video)

Deep **playtest** without treating the AI as a blind file editor: inspect the live tree, assert state, record video, sample properties over time.

Desktop Play uses the **native** run plane. Playwright is **optional and HTML5-only**.

## Architecture

```
Agent → MCP server → Editor WS (edit plane)
                  ↘ Game TCP 127.0.0.1:6510–6514 (run plane)
                     file IPC fallback when TCP down
```

| Component | Role |
|-----------|------|
| `mcp_game_inspector_service.gd` | Game autoload: command dispatch |
| `utils/runtime_tcp_server.gd` | TCP listen, queue, auth, meta file |
| `utils/runtime_tcp_client.gd` | Editor → game client |
| `utils/runtime_capture.gd` | Video frames, timeline samples, event/log ring |
| `run_session_commands.gd` | High-level session / record / timeline tools |
| `media_commands.gd` | FFmpeg: frames → video, keyframes |

## Quick start

1. Enable plugin (or `ensure_runtime_autoloads` for permanent inject)  
2. Play: `play_scene` or **`run_session_start`**  
3. **`run_ping_runtime`** / `runtime_ping` / `ping_runtime`  
4. Probe: `get_game_scene_tree`, `run_find_nodes`, `assert_node_state`, `get_game_node_properties`, …  
5. Optional video:

```
run_record_start  →  play / simulate  →  run_record_stop
  → media_frames_to_video / media_extract_keyframes
```

6. Optional property series: **`run_capture_timeline`** / `capture_timeline`  
7. Events: `log_run_event`, `get_run_events`, `get_run_logs`, `get_run_status`  
8. Stop: `stop_scene` / **`run_session_stop`**

## Protocol (TCP)

- Bind: **127.0.0.1 only**, ports **6510–6514**  
- Framing: JSON lines  

```json
{"id": 1, "command": "get_scene_tree", "params": {}}
```

```json
{"id": 1, "ok": true, "data": { ... }}
```

- Meta: `user://mcp_runtime_port`, `user://mcp_runtime_meta.json`  
- Fallback: `user://mcp_game_request` / `user://mcp_game_response` file IPC  

## Auth (optional)

```
set_runtime_token token=secret
```

MCP Node process:

```bash
# env
MCP_RUNTIME_TOKEN=secret
```

Every TCP request may include `"token":"secret"`. Clear with `set_runtime_token clear=true`.  
Localhost-only bind; token is extra protection against other local processes.

## Queue limits

| Limit | Value |
|-------|-------|
| Max TCP clients | 8 |
| Max queued requests | 48 |
| Ports | 6510–6514 |

Busy runtime returns `queue_full`; clients retry. Concurrent **read** probes may run during video/timeline; non-concurrent commands **abort** capture and finalize video meta.

## Video & timeline

| Capability | Notes |
|------------|-------|
| Frame dump | PNGs under `user://mcp_recordings/<session_id>/` |
| Events | `events.jsonl` + optional property samples |
| Meta | `meta.json` (fps, frame_count, duration) |
| Timeline | Sample node properties at interval; optional half-res images |
| Encode | FFmpeg via `media_*` tools |

Implementation: `utils/runtime_capture.gd` (see [ARCHITECTURE.md](ARCHITECTURE.md)).

## Web export only (Playwright)

```
web_serve_export export_dir=path/to/html5
web_playwright_probe export_dir=... screenshot_path=... record_video_dir=...
web_serve_stop
```

Requires optional `playwright` package. **Not** used for desktop Play — prefer native TCP + FFmpeg.

## Tests (OSS adapters)

| Framework | Tools |
|-----------|--------|
| GUT | adapters under `test_framework_commands` |
| GdUnit4 | CLI path when installed |

Use with runtime asserts for regression loops.

## Related

- [AGENT_WORKFLOW.md](AGENT_WORKFLOW.md)  
- [ARCHITECTURE.md](ARCHITECTURE.md)  
- [INSTALL.md](INSTALL.md)  
