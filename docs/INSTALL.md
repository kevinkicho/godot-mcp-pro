# Install

Project-neutral install: one machine-wide MCP server, then copy the plugin into any Godot 4 game.

## Requirements

- **Godot 4.4+** (tested on 4.x / 4.6)
- **Node.js 18+**
- Windows, macOS, or Linux
- An MCP client (Grok, Claude Code, Cursor, VS Code Copilot, etc.)

## 1. Clone and install machine-wide

```powershell
cd path\to\godot-mcp-pro
.\scripts\update-install.ps1
# optional: print Grok snippet with --lite
.\scripts\update-install.ps1 -Lite
```

This builds `server/` and installs to:

| Path | Contents |
|------|----------|
| `~/.grok/mcp/godot/build/` | MCP server (`index.js`) |
| `~/.grok/mcp/godot/addon/godot_mcp/` | Editor plugin snapshot |

Re-run `update-install.ps1` after pulls to refresh both.

## 2. Add the plugin to a game project

```powershell
.\scripts\install-addon-into-project.ps1 -Project "D:\path\to\YourGodotGame"
```

Or manually:

```text
Copy addons/godot_mcp/  →  YourGame/addons/godot_mcp/
```

In Godot: **Project → Project Settings → Plugins → Godot MCP Pro → Enable**.

## 3. Configure your MCP client

### Grok (`~/.grok/config.toml`)

```toml
[mcp_servers.godot]
command = "node"
args = [
    "C:/Users/YOU/.grok/mcp/godot/build/index.js"
]
# Optional smaller tool list:
# args = ["C:/Users/YOU/.grok/mcp/godot/build/index.js", "--lite"]
enabled = true
startup_timeout_sec = 45

[mcp_servers.godot.env]
GODOT_PATH = "C:/Path/To/Godot.exe"
GODOT_MCP_PORT = "6505"
DEBUG = "false"
```

Restart Grok after install.

### Claude Code / Cursor / other MCP hosts

```json
{
  "mcpServers": {
    "godot": {
      "command": "node",
      "args": ["/path/to/.grok/mcp/godot/build/index.js"],
      "env": {
        "GODOT_PATH": "/path/to/Godot",
        "GODOT_MCP_PORT": "6505"
      }
    }
  }
}
```

Modes (pass as extra args after `index.js`):

| Flag | Use when |
|------|----------|
| (none) | Full surface (default) |
| `--lite` | Smaller tool list + `call_editor` for the rest |
| `--3d` | 3D-focused subset (if supported by your build) |
| `--minimal` | Smallest subset for tiny context windows |

## 4. Verify

1. Open a Godot 4 project with the plugin enabled.  
2. From the agent, call **`health_check`**.  
3. Expect `editor_connected` / ready flags when the WebSocket bridge is up (ports **6505–6509**).

If the editor is closed, CLI/offline tools still work for launch/list; full production needs the plugin.

## 5. Optional: permanent runtime autoloads

For CLI/export play without relying on plugin inject each run:

- Call **`ensure_runtime_autoloads`** once in the project, **or**
- Keep using plugin-managed inject on Play.

See [RUNTIME_PROBE.md](RUNTIME_PROBE.md).

## 6. Optional dependencies

| Dependency | Used for |
|------------|----------|
| **FFmpeg** on `PATH` | `media_frames_to_video`, keyframe extract |
| **GUT** / **GdUnit4** in project | `run_gut_tests` / GdUnit CLI adapters |
| **Playwright** (`npm i playwright` in server env) | HTML5 export probe only — **not** desktop Play |

## Troubleshooting

| Symptom | What to try |
|---------|-------------|
| `editor_connected: false` | Enable plugin; check port 6505 free; restart Godot + MCP |
| Tools missing in client | Restart MCP host; try without `--lite` |
| Runtime probe fails | Play scene; `run_ping_runtime`; see [RUNTIME_PROBE.md](RUNTIME_PROBE.md) |
| Import stuck | `scan_filesystem` → `wait_for_import` / `ensure_imported` |

## Related

- [ARCHITECTURE.md](ARCHITECTURE.md) — ports and planes  
- [../FORK.md](../FORK.md) — fork vs upstream  
- [../scripts/update-install.ps1](../scripts/update-install.ps1) — install script source  
