# Coverage scorecard (honest agent production %)

**As of:** plugin **v1.58** · live registry via `list_surface_registry` / `SURFACE_REGISTRY.md`  
**Refresh:** `list_docs_coverage` in editor · `.\scripts\export-surface-registry.ps1`

---

## What “100%” means (and does not)

| Metric | Goal? | Meaning |
|--------|:-----:|---------|
| **Agent production workflow depth** | **Yes** | Agent can do what a human does for shipping content: scenes, inspect, import, playtest, export recipes |
| **Docs-area tutorial depth** | **Yes** | Each major Godot docs folder has end-to-end tools (weighted score below) |
| **MCP discoverability** | **Yes** | Domains, search, lite tools, `call_editor` for long tail |
| **One tool per ClassDB method** | **No** | Thousands of APIs; use `describe_class` + `call_node_method` + `execute_editor_script` |
| **Every editor dock button** | **No** | Escape hatches; not pixel-perfect UI automation |

**Bottom line:** “100% agent production surface” ≈ **workflow completeness + discovery + ClassDB escapes**, not 100% of engine methods.

---

## Headline scores (v1.58 estimate)

| Layer | Estimate | Confidence | Notes |
|-------|---------:|:----------:|-------|
| **Docs-area weighted depth** | **~92–94%** | High | Almost all tutorial folders **strong**; platform/migrate still partial |
| **Scene / inspector / scripts** | **~95%** | High | Core production path is mature |
| **Playtest / runtime / QA** | **~90%** | High | Sequences, asserts, fix loops; GPU debugger still engine-only |
| **2D production (pixel→ship)** | **~92%** | High | Skeleton2D, mesh2d, tiles, pixel presets, layers, draw recipes |
| **3D production** | **~88%** | Med | GI/LOD/lightmap/CSG strong; per-DCC importer polish remains |
| **Animation / skeleton** | **~88%** | Med | Tree recipes, Bezier Cartesian, retarget pipelines; no visual graph UI |
| **Physics / collision** | **~90%** | High | Bodies, shapes-as-resources, joints, ragdoll, debug ray |
| **Navigation / AI pathing** | **~88%** | Med | Navmesh + **AStarGrid2D** recipes; live replan viz thinner |
| **Assets / import** | **~88%** | Med | Stage/wait/presets/schemas; every importer option UI not mirrored |
| **UI / theme / fonts** | **~88%** | Med | Theme depth, StyleBox, LabelSettings/FontFile; Theme editor graph N/A |
| **Audio / music** | **~85%** | Med | Buses, music controller, polyphony, generator; no DAW graph |
| **Multiplayer / net** | **~80%** | Med | Spawner/sync/RPC/interest/WebRTC templates; no hosted matchmaking |
| **Rendering advanced** | **~85%** | Med | SDFGI/SSAO/SSR/glow/compositor/lightmap; vendor GPU captures N/A |
| **Shaders / VFX** | **~82%** | Med | Text + VisualShader presets + particles; full VS node catalog N/A |
| **XR** | **~80%** | Med | OpenXR maps + passthrough helpers; vendor AR kits partial |
| **Export / ship** | **~85%** | Med | Presets, Android, signing checklist; iOS notarization needs macOS |
| **Platform (iOS/console)** | **~45%** | High | Intentionally limited (vendor SDKs) |
| **Migration 3→4** | **~40%** | High | Scan/replace helpers; full converter is Godot’s job |
| **ClassDB method-for-method** | **~N/A (~lookup 100%)** | High | **Not a goal** — discovery via `describe_class` is complete |
| **Agent discoverability of tools** | **~85%** | Med | Domains/search/examples/lite; still easy to miss long-tail |

### Composite “can agents ship a real game via MCP?”

| Genre | Estimate |
|-------|---------:|
| 2D pixel platformer / top-down | **~93%** |
| 2D tile RPG with dialogue/quests | **~90%** |
| 3D greybox → playable prototype | **~88%** |
| 3D character + retarget + locomotion | **~85%** |
| Multiplayer prototype | **~78%** |
| XR prototype | **~75%** |
| Console-ready ship | **~50%** (platform/vendor limits) |

**Overall agent production readiness (all genres blended): ~88–92%.**  
**Remaining ~8–12%** is mostly: platform/vendor, visual editors (VS/Theme/Anim graphs), hosted net services, and long-tail polish — not missing core docks.

---

## How the docs-area % is computed

From `list_docs_coverage` status weights:

```
score = (strong×1.0 + partial×0.55 + thin×0.25 + classdb_only×0.35) / area_count
```

v1.38 historical: **~88%** with 34 areas.  
v1.54–1.58: most former partials (rendering, IO, plugins, best practices, 2D depth) moved **strong** → estimate **~92–94%**.

---

## Gaps that still move the needle toward “100% production”

1. **iOS/macOS signing automation** (host-dependent)  
2. **Hosted matchmaking / relay** (third-party — templates only)  
3. **VisualShader full node catalog** (use ClassDB + presets)  
4. **Animation retarget for every DCC variant** (pipelines cover common paths)  
5. **GPU frame debugger export** (engine UI)  
6. **Godot 3→4 full scene converter** (official Project Converter)  
7. **Discovery UX** — keep expanding lite tools + examples (capability already high)

Escape hatches that already count as coverage for long tail:

- `call_editor` / `batch_call_editor`  
- `describe_class` / `list_class_*`  
- `call_node_method` / `execute_editor_script`  
- `update_property` on any inspector path  

---

## Live inventory

| Snapshot | Value |
|----------|------:|
| Plugin commands (v1.58) | ~1320 |
| Modules | ~161 |
| Lite MCP tools | 300+ typed + `call_editor` |
| Domains (`list_agent_domains`) | 20+ |

After each ship: regenerate `SURFACE_REGISTRY.md` and bump this scorecard.

---

## Related

- [DOCS_COVERAGE_ANALYSIS.md](DOCS_COVERAGE_ANALYSIS.md)  
- [GAPS_VS_GODOT_DOCS.md](../GAPS_VS_GODOT_DOCS.md)  
- [IDE_PARITY.md](IDE_PARITY.md)  
- [SDK_STRUCTURE_EXPANSION.md](SDK_STRUCTURE_EXPANSION.md)  
- Live: `list_docs_coverage`, `get_agent_capability_map`, `list_surface_registry`  
