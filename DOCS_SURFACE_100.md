# Godot docs / SDK surface honesty (v1.26)

## Hard rule

Expand workflow tools. Do **not** claim 100% of ClassDB.

## 1.26 additions

| Surface | Tools |
|---------|--------|
| **Scene flow** | fade transition autoload script, loading screen scene (threaded load), set_main_scene |
| **Gameplay templates** | SaveManager, EventBus, ObjectPool, CameraShake scripts |
| **2D utilities** | CanvasLayer, DirectionalLight2D, Timer, RemoteTransform2D, VisibleOnScreenNotifier2D, attach shake to Camera2D |
| **GDExtension** | `run_gdextension_scons_build` |

## Scale

~520+ plugin commands (approx).

## Still incomplete

- godot-cpp auto-clone  
- Full dialogue visual editor  
- GPU frame debugger export  
- Inventory/quest frameworks (intentionally not game-specific)

Escape: `describe_class`, `execute_editor_script`, `call_editor`.
