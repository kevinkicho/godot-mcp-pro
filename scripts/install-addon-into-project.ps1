#Requires -Version 5.1
<#
.SYNOPSIS
  Copy the Godot MCP Pro plugin into any Godot project's addons/ folder.

.PARAMETER Project
  Path to a Godot project root (directory containing project.godot).

.EXAMPLE
  .\scripts\install-addon-into-project.ps1 -Project "D:\games\my_platformer"
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$Project
)

$ErrorActionPreference = "Stop"
$Project = (Resolve-Path $Project).Path
$projectFile = Join-Path $Project "project.godot"
if (-not (Test-Path $projectFile)) {
  throw "Not a Godot project (missing project.godot): $Project"
}

$InstallAddon = Join-Path $env:USERPROFILE ".grok\mcp\godot\addon\godot_mcp"
$RepoAddon = Join-Path (Split-Path $PSScriptRoot -Parent) "addons\godot_mcp"
$Source = if (Test-Path (Join-Path $InstallAddon "plugin.cfg")) { $InstallAddon } else { $RepoAddon }
if (-not (Test-Path (Join-Path $Source "plugin.cfg"))) {
  throw "Addon source not found. Run scripts\update-install.ps1 first."
}

$dest = Join-Path $Project "addons\godot_mcp"
New-Item -ItemType Directory -Force -Path (Join-Path $Project "addons") | Out-Null
if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
Copy-Item -Recurse -Force $Source $dest

# Enable plugin in project.godot if not already listed
$content = Get-Content $projectFile -Raw
if ($content -notmatch 'godot_mcp/plugin\.cfg') {
  if ($content -match '\[editor_plugins\]') {
    if ($content -match 'enabled=PackedStringArray\(([^)]*)\)') {
      $inner = $Matches[1].Trim()
      $entry = '"res://addons/godot_mcp/plugin.cfg"'
      if ($inner -notmatch [regex]::Escape($entry)) {
        $newInner = if ([string]::IsNullOrWhiteSpace($inner)) { $entry } else { "$inner, $entry" }
        $content = $content -replace 'enabled=PackedStringArray\([^)]*\)', "enabled=PackedStringArray($newInner)"
        Set-Content -Path $projectFile -Value $content -NoNewline
      }
    }
  } else {
    $block = @"

[editor_plugins]

enabled=PackedStringArray("res://addons/godot_mcp/plugin.cfg")
"@
    Add-Content -Path $projectFile -Value $block
  }
  Write-Host "Enabled plugin in project.godot"
} else {
  Write-Host "Plugin already referenced in project.godot"
}

Write-Host "Installed addon -> $dest"
Write-Host "Open the project in Godot and confirm Project Settings > Plugins > Godot MCP Pro is On."
