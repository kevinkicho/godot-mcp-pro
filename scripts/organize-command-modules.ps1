#Requires -Version 5.1
<#
.SYNOPSIS
  Rebalance command modules into domain folders (idempotent, recursive).

.DESCRIPTION
  Moves any *_commands.gd under commands/ into the correct domain directory
  based on module basename rules. base_command.gd stays at commands/ root.
#>
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$Commands = Join-Path $RepoRoot "addons\godot_mcp\commands"

function Get-Domain([string]$baseName) {
  $n = $baseName.ToLowerInvariant()

  # Agent / meta
  if ($n -match '^(agent|discovery|production|surface_closure|best_practices|batch|compat)') { return 'agent' }

  # Animation / character rigs
  if ($n -match '^(animation|skeleton|retarget|ragdoll|spring_bone|humanoid)') { return 'animation' }

  # Audio
  if ($n -match '^(audio|music)') { return 'audio' }

  # Export / platform / plugins
  if ($n -match '^(export|android|ios_platform|gdextension|plugin_)') { return 'export' }

  # XR
  if ($n -match '^xr_') { return 'xr' }

  # Network
  if ($n -match '^(multiplayer|webrtc|http_io)') { return 'network' }

  # Navigation
  if ($n -match '^(nav_|navigation|astar)') { return 'navigation' }

  # Physics
  if ($n -match '^(physics|joint|character_body|collision|shape_resource|mesh_collision)') { return 'physics' }

  # Shaders / VFX / particles
  if ($n -match '^(particle|vfx|shader|visual_shader)') { return 'shaders_vfx' }

  # QA / runtime
  if ($n -match '^(playtest|run_session|runtime|test_|debugger|profiling|performance|media|movie|analysis)') { return 'qa_runtime' }

  # 2D content
  if ($n -match '^(tile|gridmap|level_|pixel_2d|light_2d|canvas_draw|mesh_2d|scene_2d|sprite_frames)') { return '2d' }

  # 3D content (geometry / world nodes)
  if ($n -match '^(scene_3d|spring_arm|vehicle|softbody|csg|terrain|multimesh|structure_3d)') { return '3d' }

  # Rendering (split from assets)
  if ($n -match '^(lod_|lightmap|occlusion|compositor|render_|modern_render|decal|environment|quality_preset)') { return 'rendering' }

  # Assets / import / resources
  if ($n -match '^(import|resource|texture|font|material)') { return 'assets' }

  # UI + gameplay systems
  if ($n -match '^(i18n|theme|stylebox|ui_|label_|control_|container|game_ui|dialogue|quest|settings_save|inventory|gameplay|character_system|interaction)') { return 'ui_gameplay' }

  # Scene graph / packing / unique / flow / stream / audit
  if ($n -match '^(scene_|node_|subviewport|path_follow|camera)') { return 'scene' }

  # Editor docks / workspace / clipboard / viewport focus
  if ($n -match '^(editor_|viewport_focus)') { return 'editor' }

  # Project settings / display / groups / autoload / engine info
  if ($n -match '^(project|display|group_layer|autoload|engine_runtime|save_game)') { return 'project' }

  # Input
  if ($n -match '^(input|joypad)') { return 'input' }

  # Scripting / ClassDB / C# / curves / timers / expression
  if ($n -match '^(script|class|csharp|curve|tween|timer|expression|filesystem|io_commands|async|migration)') { return 'scripting' }

  # AI / utility agents
  if ($n -match '^(ai_|behavior|utility_ai|utility_node)') { return 'ai' }

  return 'core'
}

$moved = 0
$skipped = 0
Get-ChildItem -Path $Commands -Filter '*_commands.gd' -File -Recurse | ForEach-Object {
  $domain = Get-Domain $_.BaseName
  $destDir = Join-Path $Commands $domain
  if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir | Out-Null
  }
  $dest = Join-Path $destDir $_.Name
  $srcResolved = (Resolve-Path $_.FullName).Path
  $destParent = Split-Path $dest -Parent
  if (-not (Test-Path $destParent)) { New-Item -ItemType Directory -Path $destParent | Out-Null }

  if ((Test-Path $dest) -and ((Resolve-Path $dest).Path -eq $srcResolved)) {
    $skipped++
    return
  }
  if ((Test-Path $dest) -and ((Resolve-Path $dest).Path -ne $srcResolved)) {
    Write-Warning "Target exists with different file, skip: $dest"
    $skipped++
    return
  }

  Move-Item -LiteralPath $_.FullName -Destination $dest -Force
  $uid = $_.FullName + '.uid'
  if (Test-Path $uid) {
    Move-Item -LiteralPath $uid -Destination ($dest + '.uid') -Force -ErrorAction SilentlyContinue
  }
  Write-Host ("  {0} -> {1}/" -f $_.Name, $domain)
  $moved++
}

# Remove empty domain dirs (except keep structure intentionally)
Get-ChildItem -Path $Commands -Directory | ForEach-Object {
  $left = @(Get-ChildItem $_.FullName -Force | Where-Object { $_.Name -ne '.' -and $_.Name -ne '..' })
  if ($left.Count -eq 0) {
    Remove-Item $_.FullName -Force
    Write-Host ("Removed empty domain: {0}" -f $_.Name)
  }
}

Write-Host ("Moved {0} modules; already correct {1}" -f $moved, $skipped)
Write-Host "base_command.gd remains at commands/ root"
