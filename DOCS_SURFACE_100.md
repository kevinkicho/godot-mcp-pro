# Godot docs / SDK surface honesty (v1.38)

## Hard rule

Expand **workflow** tools. Do **not** claim 100% of ClassDB or every editor dock pixel.

## Live numbers

| Metric | Value |
|--------|------:|
| Plugin version | **1.38.0** |
| Registered commands | **692** |
| Command modules | **68** |
| Weighted docs-area depth | **~88%** |

Sources: [SURFACE_REGISTRY.md](SURFACE_REGISTRY.md) · `list_docs_coverage` · [docs/DOCS_COVERAGE_ANALYSIS.md](docs/DOCS_COVERAGE_ANALYSIS.md)

## Status legend

| Status | Meaning |
|--------|---------|
| strong | End-to-end agent workflow |
| partial | Tools exist; depth gaps |
| thin | Barely operable |
| classdb_only | Lookup only (e.g. math) |

## Official tutorial folders (summary)

Most `tutorials/*` folders are **strong** as of 1.38 (editor, scripting, 2d/3d, animation, assets, physics, navigation, audio, inputs, ui, shaders, networking, i18n, export, performance, xr).

Still **partial / thin**: io (encryption), platform (iOS/console), plugins (godot-cpp build), rendering (SDFGI/compositor), best_practices, **migrating**, math (classdb_only).

## Agent production extras (beyond docs folders)

Gameplay systems, quests/dialogue, behavior trees, WebRTC, VFX, settings/save, **runtime probe** (TCP video/timeline + FFmpeg + GUT/GdUnit) — see analysis doc.

## Escape hatches

`describe_class`, `execute_editor_script`, `call_editor`, `list_mcp_commands`, `list_docs_coverage`.

## Still incomplete (examples)

- Full lightmap / SDFGI / compositor automation  
- Joypad mapping wizard  
- Auto i18n string extract  
- Visual Bezier / full retarget wizard  
- godot-cpp auto-clone/build  
- Automated 3→4 migrator  
- GPU frame debugger export  

Full gap list: [GAPS_VS_GODOT_DOCS.md](GAPS_VS_GODOT_DOCS.md) · [docs/DOCS_COVERAGE_ANALYSIS.md](docs/DOCS_COVERAGE_ANALYSIS.md)
