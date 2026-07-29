# Godot MCP vs Official Docs — Gap Analysis

> **v1.38 refresh:** Full heatmap, module crosswalk, and scorecard live in  
> **[docs/DOCS_COVERAGE_ANALYSIS.md](docs/DOCS_COVERAGE_ANALYSIS.md)**.  
> Live tool: **`list_docs_coverage`**. Command inventory: **[SURFACE_REGISTRY.md](SURFACE_REGISTRY.md)**.

Source map: [godotengine/godot-docs](https://github.com/godotengine/godot-docs) (`tutorials/`, `getting_started/`, class reference).  
Compared against this fork’s plugin surface: **~692** registered methods, **68** modules, **v1.38.0**.

**Goal:** agent-driven game production that feels like a human using the editor — not 1:1 with every docs page or ClassDB method.

**Honesty:** Older notes claimed “100% docs surface.” That only meant “every top-level tutorial folder has *some* tool path,” including ClassDB-only escapes — **not** full SDK or human-dock parity. That metric is retired.

---

## How to read coverage

| Coverage | Meaning |
|----------|---------|
| **Strong** | Dedicated tools; agents can do the workflow end-to-end |
| **Partial** | Some tools; missing steps, discovery, or depth |
| **Thin** | Docs-area workflow barely agent-operable |
| **classdb_only** | Lookup/scripts only (intentional for math) |
| **Out of scope** | Engine/user responsibility, not MCP |

**Also:** Capability exists ≠ agents discover it. Lite mode + `call_editor` + `list_mcp_commands` matter as much as raw tool count.

---

## Summary heatmap (docs topic → MCP) — v1.38

| Docs area | Coverage | Notes |
|-----------|----------|--------|
| getting_started | **Strong** | scaffold, playtest, scene/script basics |
| Editor | **Strong** | inspector, selection, debugger, breakpoints |
| Scripting (GDScript + C# basics) | **Strong** | CRUD, ClassDB, unique names, C# project helpers |
| Scenes / 2D / 3D | **Strong** | controllers, cameras, tilemap/tileset, probes/GI basics |
| Animation | **Strong** | Player + Tree + Skeleton; thin Bezier/retarget UI |
| Assets pipeline | **Strong** | stage, wait, import options, glTF extract |
| Physics | **Strong** | body/area/joint/ray/soft/vehicle; thin viz |
| Navigation | **Strong** | region/agent/bake + AI agents |
| Audio | **Strong** | buses, effects, layout I/O |
| Inputs | **Strong** | Input Map events + simulate; no joypad wizard |
| UI / Theme | **Strong** | anchors, lists, dialogs, game UI scaffolds |
| Shaders | **Strong** | text + VisualShader basics + VFX presets |
| Networking | **Strong** | multiplayer templates/runtime; WebRTC **partial** |
| I18n | **Strong** | locale, CSV/PO; no auto extract |
| Export | **Strong** | presets, run_export, Android deploy |
| Performance | **Strong** | monitors, timelines; no GPU frame debugger export |
| XR | **Strong** | OpenXR action maps; passthrough thin |
| IO / save | **Partial** | Config/JSON/user:// + save managers; encryption thin |
| Platform | **Partial** | Android best; iOS/console thin |
| Plugins / GDExtension | **Partial** | scaffold; no godot-cpp auto-build |
| Rendering advanced | **Partial** | env/lights/GI partial; compositor/SDFGI thin |
| Best practices | **Partial** | workflow guide + analyzers |
| Migrating | **Thin** | version + search/edit only |
| Math | **classdb_only** | intentional |
| Class reference | **Strong (lookup)** | `describe_class` family — not one tool per method |

**Weighted docs-area depth ≈ 88%** (see analysis doc for formula). **Not** “88% of ClassDB.”

---

## Score by production layer

| Layer | Score |
|-------|-------|
| Scene / node / inspector / signals / scripts | **~90%** |
| Playtest / runtime probe / media | **~85%** |
| Assets import | **~85%** |
| 2D / 3D content depth | **~75–80%** |
| Multiplayer / i18n / XR | **~70%** (WebRTC/platform lower) |
| Agent discovery of existing tools | **~70%** (lite + macros + list_*) |

---

## Top remaining gaps (agent production)

1. Rendering bake automation (lightmap / SDFGI / compositor)  
2. Joypad mapping wizard  
3. i18n string extraction  
4. Encrypted / cloud saves  
5. WebRTC TURN / matchmaking  
6. Animation Bezier + full retarget UI  
7. Theme type full resource editor  
8. godot-cpp automated build  
9. Godot 3→4 migrator  
10. GPU profiler export  

### Explicit non-goals

- One MCP tool per ClassDB method  
- Full visual shader / animation GUIs  
- Console vendor SDKs  
- Replacing the official docs browser  

Escape: `describe_class`, `execute_editor_script`, `call_editor`.

---

## How to refresh

```powershell
.\scripts\export-surface-registry.ps1
# In editor + MCP: list_docs_coverage
```

Full write-up: **[docs/DOCS_COVERAGE_ANALYSIS.md](docs/DOCS_COVERAGE_ANALYSIS.md)**

---

## References

- Docs repo: https://github.com/godotengine/godot-docs  
- Tutorial index: `tutorials/index.rst`  
- Live map: `addons/godot_mcp/commands/agent_commands.gd` → `_list_docs_coverage`  
- Registry: `SURFACE_REGISTRY.md`  
