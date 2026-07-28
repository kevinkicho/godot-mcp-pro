#Requires -Version 5.1
<#
.SYNOPSIS
  Build the open Godot MCP server and install it machine-wide (project-neutral).

.DESCRIPTION
  Installs to:  %USERPROFILE%\.grok\mcp\godot\
    build/     — MCP server (stdio + WebSocket)
    addon/     — Godot editor plugin (copy into any project's addons/)

  Does NOT touch any game project. To add the plugin to a project:

    Copy-Item -Recurse "$env:USERPROFILE\.grok\mcp\godot\addon\godot_mcp" `
      "path\to\YourGame\addons\godot_mcp"

.PARAMETER Lite
  After install, print Grok config snippet with --lite enabled.

.EXAMPLE
  .\scripts\update-install.ps1
#>
param(
  [switch]$Lite
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$ServerDir = Join-Path $RepoRoot "server"
$AddonSrc = Join-Path $RepoRoot "addons\godot_mcp"
$InstallRoot = Join-Path $env:USERPROFILE ".grok\mcp\godot"

if (-not (Test-Path (Join-Path $ServerDir "package.json"))) {
  throw "Server package not found at $ServerDir"
}
if (-not (Test-Path (Join-Path $AddonSrc "plugin.cfg"))) {
  throw "Addon not found at $AddonSrc"
}

Write-Host "==> Building open MCP server..."
Push-Location $ServerDir
try {
  if (-not (Test-Path "node_modules")) {
    npm install
  }
  npm run build
  if ($LASTEXITCODE -ne 0) { throw "npm run build failed" }
}
finally {
  Pop-Location
}

Write-Host "==> Installing to $InstallRoot"
New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null

$buildDest = Join-Path $InstallRoot "build"
$addonDest = Join-Path $InstallRoot "addon\godot_mcp"
$nmDest = Join-Path $InstallRoot "node_modules"

if (Test-Path $buildDest) { Remove-Item -Recurse -Force $buildDest }
if (Test-Path $addonDest) { Remove-Item -Recurse -Force $addonDest }

Copy-Item -Recurse -Force (Join-Path $ServerDir "build") $buildDest
Copy-Item -Recurse -Force $AddonSrc $addonDest
Copy-Item -Force (Join-Path $ServerDir "package.json") (Join-Path $InstallRoot "package.json")

# node_modules: prefer install at target for cleanliness, else copy
if (Test-Path (Join-Path $ServerDir "node_modules")) {
  if (Test-Path $nmDest) { Remove-Item -Recurse -Force $nmDest }
  Copy-Item -Recurse -Force (Join-Path $ServerDir "node_modules") $nmDest
}

$indexJs = Join-Path $buildDest "index.js"
if (-not (Test-Path $indexJs)) {
  throw "Missing $indexJs after build"
}

$ver = "unknown"
$cfg = Get-Content (Join-Path $AddonSrc "plugin.cfg") -Raw
if ($cfg -match 'version="([^"]+)"') { $ver = $Matches[1] }

Write-Host ""
Write-Host "Installed Godot MCP v$ver"
Write-Host "  Server: $indexJs"
Write-Host "  Addon:  $addonDest"
Write-Host ""
Write-Host "Grok user config (~/.grok/config.toml):"
Write-Host ""

$liteArg = if ($Lite) { ', "--lite"' } else { '' }
@"
[mcp_servers.godot]
command = "node"
args = [
    "$($indexJs.Replace('\', '/'))"$liteArg
]
enabled = true
startup_timeout_sec = 45

[mcp_servers.godot.env]
GODOT_PATH = "C:/Path/To/Godot.exe"
GODOT_MCP_PORT = "6505"
DEBUG = "false"
"@ | Write-Host

Write-Host ""
Write-Host "Any Godot project: copy addon into addons/godot_mcp and enable the plugin."
Write-Host "Restart Grok sessions after install."
