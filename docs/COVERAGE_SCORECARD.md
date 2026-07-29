# Coverage scorecard (honest agent production %)

**As of:** plugin **v1.59** · live registry via `list_surface_registry` / `SURFACE_REGISTRY.md`  
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
| **Docs-area weighted depth** | **~94–96%** | High | Character/env/audio FX/net peer gaps closed; platform/migrate remain |
| **Scene / inspector / scripts** | **~96%** | High | Core production path is mature |
| **Playtest / runtime / QA** | **~90%** | High | Sequences, asserts, fix loops; GPU debugger still engine-only |
| **2D production (pixel→ship)** | **~93%** | High | Skeleton2D, mesh2d, tiles, pixel, layers, draw, CharacterBody presets |
| **3D production** | **~92%** | High | TPS rig, Environment/Sky/Fog, occlusion, PBR; DCC polish remains |
| **Animation / skeleton** | **~90%** | Med | Player libraries/autoplay + Tree/Bezier/retarget; no visual graph UI |
| **Physics / collision** | **~92%** | High | Bodies, PhysicsMaterial resources, shapes, joints, ragdoll |
| **Navigation / AI pathing** | **~88%** | Med | Navmesh + AStarGrid2D; live replan viz thinner |
| **Assets / import** | **~88%** | Med | Stage/wait/presets/schemas; every importer option UI not mirrored |
| **UI / theme / fonts** | **~88%** | Med | Theme depth, StyleBox, LabelSettings/FontFile; Theme editor graph N/A |
| **Audio / music** | **~90%** | High | Typed bus effects (reverb/EQ/compressor…), polyphony, music |
| **Multiplayer / net** | **~90%** | High | ENet + lobby ready-up + spawns + sync bulk + interest/WebRTC; no hosted MM |
| **Rendering advanced** | **~88%** | Med | Env/Sky/Fog + GI/compositor/lightmap; vendor GPU captures N/A |
| **Shaders / VFX** | **~82%** | Med | Text + VisualShader presets + particles; full VS node catalog N/A |
| **XR** | **~80%** | Med | OpenXR maps + passthrough helpers; vendor AR kits partial |
| **Export / ship** | **~88%** | Med | Pre-ship pipeline + presets/signing; iOS needs macOS |
| **Platform (iOS/console)** | **~45%** | High | Intentionally limited (vendor SDKs) |
| **Migration 3→4** | **~40%** | High | Scan/replace helpers; full converter is Godot’s job |
| **ClassDB method-for-method** | **~N/A (~lookup 100%)** | High | **Not a goal** — discovery via `describe_class` is complete |
| **Agent discoverability of tools** | **~88%** | Med | Domains/search/examples/lite/pipelines; long tail via call_editor |

### Composite “can agents ship a real game via MCP?”

| Genre | Estimate |
|-------|---------:|
| 2D pixel platformer / top-down | **~94%** |
| 2D tile RPG with dialogue/quests | **~91%** |
| 3D greybox → playable prototype | **~92%** |
| 3D character + TPS + locomotion | **~90%** |
| Multiplayer prototype | **~90%** |
| XR prototype | **~75%** |
| Console-ready ship | **~50%** (platform/vendor limits) |

**Overall agent production readiness (all genres blended): ~94–97%** (v1.61 lobby + game loop + saves).  
**Remaining ~3–6%** is mostly: platform/vendor SDKs, visual editors (VS/Theme/Anim graphs), hosted matchmaking, and long-tail polish — not missing core docks.

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
| Plugin commands (v1.61) | ~1428 |
| Modules | ~182 |
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
