# Godot MCP Pro (open fork)

**Agentic control plane** for Godot 4 — project-neutral MCP so AI agents can explore, build, playtest, and fix games with live editor + runtime feedback.

Fork of [youichi-uda/godot-mcp-pro](https://github.com/youichi-uda/godot-mcp-pro) with an **open Node MCP server**, Coding-Solo parity tools, production macros, and a native **run probe** (TCP + video). See [FORK.md](FORK.md).

| | |
|--|--|
| **Plugin** | `addons/godot_mcp/` (Godot 4.4+) |
| **Server** | `server/` (Node 18+, stdio MCP) |
| **Surface** | ~**690+** registered plugin commands · [SURFACE_REGISTRY.md](SURFACE_REGISTRY.md) |
| **Version** | see `addons/godot_mcp/plugin.cfg` |

---

## Table of contents

1. [What you get](#what-you-get)
2. [Architecture](#architecture)
3. [Quick start](#quick-start)
4. [MCP modes](#mcp-modes)
5. [Agent production loop](#agent-production-loop)
6. [Command surface](#command-surface)
7. [Documentation](#documentation)
8. [Scripts](#scripts)
9. [License](#license)

### Documentation index

Full docs live under **[`docs/`](docs/README.md)**:

| Doc | Description |
|-----|-------------|
| **[docs/README.md](docs/README.md)** | Docs table of contents |
| **[docs/INSTALL.md](docs/INSTALL.md)** | Machine-wide install + MCP client config |
| **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** | Edit plane, run plane, media, web, tests |
| **[docs/RUNTIME_PROBE.md](docs/RUNTIME_PROBE.md)** | TCP probe, video, timeline, auth, Playwright |
| **[docs/AGENT_WORKFLOW.md](docs/AGENT_WORKFLOW.md)** | health_check → build → playtest → fix |
| **[docs/COMMAND_SURFACE.md](docs/COMMAND_SURFACE.md)** | Categories and discovery |
| **[docs/PRODUCTION_SYSTEMS.md](docs/PRODUCTION_SYSTEMS.md)** | Characters, AI, quests, multiplayer, VFX |
| **[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)** | Add commands, ship versions |
| **[docs/DOCS_COVERAGE_ANALYSIS.md](docs/DOCS_COVERAGE_ANALYSIS.md)** | MCP ↔ Godot docs/SDK coverage analysis |
| **[docs/INSPECTOR_FINE_TUNE.md](docs/INSPECTOR_FINE_TUNE.md)** | Full node & parameter fine-tune for agents |
| **[docs/SURFACE_EXPANSION.md](docs/SURFACE_EXPANSION.md)** | Closing remaining Godot docs surface gaps |
| **[docs/HEADLESS_AGENT.md](docs/HEADLESS_AGENT.md)** | Full IDE-parity agentic / headless workflow |
| **[docs/ANIMATION_FINE_TUNE.md](docs/ANIMATION_FINE_TUNE.md)** | Example animations → fine-tune via MCP |

### Reference

| File | Description |
|------|-------------|
| [FORK.md](FORK.md) | Fork notes, remotes, vs upstream |
| [SURFACE_REGISTRY.md](SURFACE_REGISTRY.md) | Generated full command list |
| [CHANGELOG.md](CHANGELOG.md) | Version history |
| [GAPS_VS_GODOT_DOCS.md](GAPS_VS_GODOT_DOCS.md) | Short docs-area gap heatmap |
| [DOCS_SURFACE_100.md](DOCS_SURFACE_100.md) | Coverage honesty summary |
| [docs/DOCS_COVERAGE_ANALYSIS.md](docs/DOCS_COVERAGE_ANALYSIS.md) | Full official-docs crosswalk |
| [skills/godot-mcp/SKILL.md](skills/godot-mcp/SKILL.md) | Agent skill |
| [addons/godot_mcp/skills.md](addons/godot_mcp/skills.md) | In-plugin skill notes |

---

## What you get

- **Edit plane** — WebSocket bridge (ports **6505–6509**): scenes, nodes, scripts, animation, physics, UI, import, export, …
- **Run plane** — TCP probe (**6510–6514**) into the playing game: tree, properties, asserts, video record, property timelines
- **Production macros** — scaffold, input map presets, import wait, playtest report, characters / AI / quests / multiplayer scaffolds
- **OSS adapters** — FFmpeg media, GUT/GdUnit test runners, optional Playwright for **HTML5 only**
- **Project-neutral** — no hard-coded game paths; install into any Godot 4 project

Upstream public repo ships the **plugin only** (commercial server). **This fork includes `server/`** for open agent use.

---

## Architecture

```
AI assistant  ──stdio/MCP──►  Node server  ──WS 6505–6509──►  Godot editor plugin
                                    │
                                    └── TCP 6510–6514 ──►  running game (inspector + capture)
```

Details: **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** · Run probe: **[docs/RUNTIME_PROBE.md](docs/RUNTIME_PROBE.md)**

---

## Quick start

### 1. Install machine-wide

```powershell
cd path\to\godot-mcp-pro
.\scripts\update-install.ps1
```

Installs to `~/.grok/mcp/godot/` (server build + addon snapshot).

### 2. Plugin into a project

```powershell
.\scripts\install-addon-into-project.ps1 -Project "D:\path\to\YourGodotGame"
```

Enable: **Project → Project Settings → Plugins → Godot MCP Pro**.

### 3. Configure the MCP client (Grok example)

```toml
[mcp_servers.godot]
command = "node"
args = ["C:/Users/YOU/.grok/mcp/godot/build/index.js"]
enabled = true
startup_timeout_sec = 45

[mcp_servers.godot.env]
GODOT_PATH = "C:/Path/To/Godot.exe"
GODOT_MCP_PORT = "6505"
```

### 4. Verify

Open the project with the plugin enabled, then call **`health_check`**.

Step-by-step clients, modes, and troubleshooting: **[docs/INSTALL.md](docs/INSTALL.md)**

---

## MCP modes

| Mode | Flag | Best for |
|------|------|----------|
| Full | (default) | Full tool list |
| Lite | `--lite` | Smaller list + `call_editor` for the rest |
| Minimal | `--minimal` | Tiny context / local LLMs |

Pass the flag as an extra arg after `index.js` in your MCP config.

---

## Agent production loop

```
health_check
  → mutate scenes/scripts (editor tools)
  → save / validate
  → play / run_session_start
  → screenshot · get_game_scene_tree · assert_node_state · optional video
  → stop → fix → repeat
```

Full guide: **[docs/AGENT_WORKFLOW.md](docs/AGENT_WORKFLOW.md)** · Skill: **[skills/godot-mcp/SKILL.md](skills/godot-mcp/SKILL.md)**

---

## Command surface

Commands are auto-discovered from `addons/godot_mcp/commands/*_commands.gd`.  
Counts change each release — source of truth:

- **[SURFACE_REGISTRY.md](SURFACE_REGISTRY.md)** (generated)
- Live: `list_mcp_commands` / `list_surface_registry`

Category overview: **[docs/COMMAND_SURFACE.md](docs/COMMAND_SURFACE.md)**  
Systems (AI, quests, multiplayer, …): **[docs/PRODUCTION_SYSTEMS.md](docs/PRODUCTION_SYSTEMS.md)**

### Sample categories

| Area | Examples |
|------|----------|
| Agent | `health_check`, `agent_workflow_guide`, `list_docs_coverage` |
| Project / scene / node | settings, tree, CRUD, signals, groups |
| Script / ClassDB | create/edit/validate, `describe_class` |
| Runtime | game tree, frames, input record, `run_session_*` |
| Animation / skeleton | clips, AnimationTree, bones |
| 2D / 3D / physics | tilemaps, meshes, lights, collision, navigation |
| Production systems | character, AI, BT, quest, UI, settings, VFX |
| Media / tests | FFmpeg, GUT/GdUnit |
| Export / Android / XR | presets, deploy, XR setup |

Coverage is **workflow-oriented**, not “100% of ClassDB.” See [GAPS_VS_GODOT_DOCS.md](GAPS_VS_GODOT_DOCS.md).

---

## Documentation

```
docs/
  README.md              ← start here (TOC)
  INSTALL.md
  ARCHITECTURE.md
  RUNTIME_PROBE.md
  AGENT_WORKFLOW.md
  COMMAND_SURFACE.md
  PRODUCTION_SYSTEMS.md
  CONTRIBUTING.md
  README.*.md            ← localized upstream-style READMEs
```

Open **[docs/README.md](docs/README.md)** for the full docs table of contents.

Contributing / shipping versions: **[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)**

---

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/update-install.ps1` | Build server + install to `~/.grok/mcp/godot` |
| `scripts/install-addon-into-project.ps1` | Copy plugin into a game project |
| `scripts/export-surface-registry.ps1` | Regenerate `SURFACE_REGISTRY.md` |

---

## License

- Upstream plugin: proprietary — see [LICENSE](LICENSE)
- This fork’s open MCP server and fork-added tooling: see [FORK.md](FORK.md)

```text
origin    https://github.com/kevinkicho/godot-mcp-pro.git
upstream  https://github.com/youichi-uda/godot-mcp-pro.git
```
