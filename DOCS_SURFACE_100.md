# Godot docs / SDK surface honesty (v1.27)

## Hard rule

Expand workflow tools. Do **not** claim 100% of ClassDB.

## 1.26–1.27 additions

| Surface | Tools |
|---------|--------|
| **Scene flow** | fade transition, loading screen, set_main_scene |
| **Gameplay templates** | SaveManager, EventBus, ObjectPool, CameraShake, generic FSM |
| **2D utilities** | CanvasLayer, lights, Timer, RemoteTransform, notifiers, materials/modulate, Label/Button/TextureRect |
| **3D utilities** | SpringArm3D, RemoteTransform3D, markers, groups |
| **Project** | list_autoloads, window settings, physics ticks, list settings keys |
| **GDExtension** | scaffold + scons build |

## Scale

See **SURFACE_REGISTRY.md** for live totals (regenerate with `scripts/export-surface-registry.ps1`).

## Still incomplete

- godot-cpp auto-clone  
- Full dialogue visual editor  
- GPU frame debugger export  
- Inventory/quest frameworks (intentionally not game-specific)

Escape: `describe_class`, `execute_editor_script`, `call_editor`.
