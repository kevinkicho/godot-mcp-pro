# Documentation

Godot MCP Pro (open fork) — agentic control plane for **any Godot 4 project**.

Plugin version: see [`../addons/godot_mcp/plugin.cfg`](../addons/godot_mcp/plugin.cfg) · Command surface: [`../SURFACE_REGISTRY.md`](../SURFACE_REGISTRY.md)

## Table of contents

| Doc | Description |
|-----|-------------|
| [INSTALL.md](INSTALL.md) | Machine-wide install, project plugin, MCP client config (Grok / Claude / Cursor) |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Edit plane (WS), run plane (TCP), media, web, tests |
| [RUNTIME_PROBE.md](RUNTIME_PROBE.md) | Native playtest probe: TCP, video, timeline, auth, Playwright |
| [AGENT_WORKFLOW.md](AGENT_WORKFLOW.md) | Production loop: health_check → build → playtest → fix |
| [COMMAND_SURFACE.md](COMMAND_SURFACE.md) | Command categories and how to discover tools |
| [PRODUCTION_SYSTEMS.md](PRODUCTION_SYSTEMS.md) | Characters, AI, quests, multiplayer, VFX, settings, BT |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Add commands, ship versions, regenerate registry |
| [DOCS_COVERAGE_ANALYSIS.md](DOCS_COVERAGE_ANALYSIS.md) | MCP ↔ official Godot docs / SDK surface map |
| [INSPECTOR_FINE_TUNE.md](INSPECTOR_FINE_TUNE.md) | Full node/parameter fine-tune for agents |

### Root reference (not under `docs/`)

| File | Description |
|------|-------------|
| [../README.md](../README.md) | Project overview and quick start |
| [../FORK.md](../FORK.md) | Fork lineage, remotes, what changed vs upstream |
| [../SURFACE_REGISTRY.md](../SURFACE_REGISTRY.md) | Full list of registered plugin commands (generated) |
| [../CHANGELOG.md](../CHANGELOG.md) | Version history |
| [../GAPS_VS_GODOT_DOCS.md](../GAPS_VS_GODOT_DOCS.md) | Short gap heatmap vs official Godot docs |
| [../DOCS_SURFACE_100.md](../DOCS_SURFACE_100.md) | Coverage honesty summary |
| [../skills/godot-mcp/SKILL.md](../skills/godot-mcp/SKILL.md) | Agent skill for Grok / coding agents |
| [../addons/godot_mcp/skills.md](../addons/godot_mcp/skills.md) | In-plugin skill notes |

### Localized READMEs (upstream-oriented)

Spanish, Hindi, Japanese, Portuguese (BR), Russian, Chinese translations of the marketing README live here as `README.*.md`. Prefer the English root [README.md](../README.md) for this open fork.

## Start here

1. **[INSTALL.md](INSTALL.md)** — get the server + plugin running  
2. **[AGENT_WORKFLOW.md](AGENT_WORKFLOW.md)** — how agents should drive production  
3. **[RUNTIME_PROBE.md](RUNTIME_PROBE.md)** — deep playtest (tree, video, asserts)  
4. **[ARCHITECTURE.md](ARCHITECTURE.md)** — how the pieces fit  
