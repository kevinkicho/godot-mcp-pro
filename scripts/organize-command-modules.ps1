#Requires -Version 5.1
<#
.SYNOPSIS
  Move flat commands/*_commands.gd into domain subfolders (structural refactor).

.DESCRIPTION
  Idempotent: skips files already under a domain folder.
  base_command.gd stays at commands/ root.
#>
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$Commands = Join-Path $RepoRoot "addons\godot_mcp\commands"

function Get-Domain([string]$baseName) {
  $n = $baseName.ToLowerInvariant()
  # Order matters — more specific first
  if ($n -match '^(agent|discovery|production|surface_closure|best_practices|batch|compat)') { return 'agent' }
  if ($n -match '^(animation|skeleton|retarget|ragdoll|spring_bone|humanoid)') { return 'animation' }
  if ($n -match '^(audio|music)') { return 'audio' }
  if ($n -match '^(export|android|ios_platform|gdextension|plugin_)') { return 'export' }
  if ($n -match '^(import|resource|texture|font|material|shape_resource|mesh_|lod_|lightmap|occlusion|compositor|render_|modern_render|quality_preset|environment|decal|csg|terrain|multimesh|structure_3d)') { return 'assets' }
  if ($n -match '^(i18n|theme|stylebox|ui_|label_|control_|container|game_ui|dialogue|quest|settings_save|inventory|gameplay)') { return 'ui_gameplay' }
  if ($n -match '^(multiplayer|webrtc|http_io|websocket)') { return 'network' }
  if ($n -match '^(xr_)') { return 'xr' }
  if ($n -match '^(tile|gridmap|level_|scene_2d|scene_3d|scene_|pixel_2d|camera|light_2d|canvas|subviewport|path_follow|astar|nav_|navigation|character|interaction|physics|joint|vehicle|softbody|particle|vfx|shader|visual_shader|spring_arm|scene_pack|scene_flow|scene_instance|scene_stream|scene_unique|scene_audit|node_|editor_|viewport_|debugger|playtest|run_session|runtime|test_|profiling|performance|media|movie|expression|utility|behavior|ai_|analysis|migration|csharp|class|curve|tween|timer|input|joypad|display|project|group|autoload|async|engine_runtime|save_game|io_commands)') {
    # split further
  }
  if ($n -match '^(tile|gridmap|level_|pixel_2d|light_2d|canvas_draw|mesh_2d|astar)') { return '2d' }
  if ($n -match '^(scene_3d|csg|lod_|lightmap|occlusion|compositor|render_|modern_render|decal|environment|structure_3d|spring_arm|vehicle|softbody|terrain|multimesh|import_3d|humanoid|ragdoll)') { return '3d' }
  if ($n -match '^(nav_|navigation)') { return 'navigation' }
  if ($n -match '^(physics|joint|character_body|collision|shape_resource|mesh_collision)') { return 'physics' }
  if ($n -match '^(particle|vfx|shader|visual_shader)') { return 'shaders_vfx' }
  if ($n -match '^(playtest|run_session|runtime|test_|debugger|profiling|performance|media|movie|analysis)') { return 'qa_runtime' }
  if ($n -match '^(editor_|viewport_focus|batch|compat|project|group|autoload|display|engine_runtime|input|joypad|io_commands|async|csharp|class|curve|tween|timer|expression|utility|behavior|ai_|migration|save_game|scene_|node_|camera|path_follow|interaction)') { return 'core' }
  return 'core'
}

$moved = 0
$skipped = 0
Get-ChildItem -Path $Commands -Filter '*_commands.gd' -File | ForEach-Object {
  $domain = Get-Domain $_.BaseName
  $destDir = Join-Path $Commands $domain
  if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir | Out-Null
  }
  $dest = Join-Path $destDir $_.Name
  if ($_.FullName -eq (Resolve-Path $dest -ErrorAction SilentlyContinue)) {
    $skipped++
    return
  }
  if (Test-Path $dest) {
    Write-Warning "Target exists, skip: $dest"
    $skipped++
    return
  }
  Move-Item -LiteralPath $_.FullName -Destination $dest
  # move .uid if present
  $uid = $_.FullName + '.uid'
  if (Test-Path $uid) {
    Move-Item -LiteralPath $uid -Destination ($dest + '.uid') -ErrorAction SilentlyContinue
  }
  Write-Host "  $($_.Name) -> $domain/"
  $moved++
}

Write-Host "Moved $moved modules; skipped $skipped"
Write-Host "base_command.gd remains at commands/ root"
