# Godot MCP Pro — Fork notes

This repository is a fork of [youichi-uda/godot-mcp-pro](https://github.com/youichi-uda/godot-mcp-pro)
(`origin` → your fork, `upstream` → original).

**Project-neutral:** install into any Godot 4 game. No game-specific paths or content.

## Role

Primary **agentic control plane** for agent-driven game production: explore → build → playtest → fix, with live editor feedback when the plugin is connected.

## Install / update (machine-wide)

```powershell
cd path\to\godot-mcp-pro
.\scripts\update-install.ps1
# optional lite mode snippet:
.\scripts\update-install.ps1 -Lite
```

Install plugin into any project:

```powershell
.\scripts\install-addon-into-project.ps1 -Project "D:\path\to\YourGodotGame"
```

## What this fork adds

Upstream Pro’s public repo only ships the **Godot editor plugin**. The commercial
Node MCP server is paid. This fork adds:

### 0. Agent production tools (plugin)

`addons/godot_mcp/commands/agent_commands.gd`

| Tool | Purpose |
|------|---------|
| `health_check` | Ready for agent production? ports, commands, open scene, issues |
| `agent_workflow_guide` | Project-neutral production loop (topic: production/2d/3d/ui/playtest) |

### 1. Coding-Solo parity tools (plugin)

New file: `addons/godot_mcp/commands/compat_commands.gd`

| Tool | Purpose |
|------|---------|
| `get_godot_version` | Engine version string + info |
| `get_uid` | UID for a resource (Coding-Solo param names) |
| `update_project_uids` | Resave resources to refresh UIDs |
| `load_sprite` | Set texture on Sprite2D / Sprite3D / TextureRect |
| `export_mesh_library` | Export scene meshes as MeshLibrary |
| `list_projects` | Find `project.godot` under a directory |
| `launch_editor` | Spawn Godot editor for a project path |
| `list_mcp_commands` | Enumerate all registered plugin commands |

### 2. Open-source MCP server (`server/`)

MIT-licensed Node server that:

- Speaks **stdio MCP** to Grok / Claude / Cursor
- Hosts **WebSocket on ports 6505–6509** for the Pro plugin
- Implements **Coding-Solo CLI** tools without the editor
- Proxies **all Pro editor commands** when the plugin is connected
- **`--lite`**: core tools + `call_editor` (less tool-list noise for agents)
- **`health_check`** / **`agent_workflow_guide`** for agent production readiness

## Setup for Grok

Prefer:

```powershell
.\scripts\update-install.ps1
```

Then in `~/.grok/config.toml` (paths from script output):

```toml
[mcp_servers.godot]
command = "node"
args = ["C:/Users/YOU/.grok/mcp/godot/build/index.js"]
# optional: args = [".../index.js", "--lite"]
enabled = true

[mcp_servers.godot.env]
GODOT_PATH = "C:/Path/To/Godot.exe"
GODOT_MCP_PORT = "6505"
```

Restart Grok. Open any Godot 4 project with the plugin enabled. Call **`health_check`**.

## Git remotes

```text
origin    https://github.com/kevinkicho/godot-mcp-pro.git   (your fork)
upstream  https://github.com/youichi-uda/godot-mcp-pro.git  (upstream)
```

```bash
git fetch upstream
git merge upstream/master   # or rebase
git push origin main
```

## License

- Upstream plugin: proprietary (see `LICENSE`)
- This fork’s `server/` and `compat_commands.gd` additions: intended as MIT for the
  open server; respect upstream LICENSE for the rest of the addon.
