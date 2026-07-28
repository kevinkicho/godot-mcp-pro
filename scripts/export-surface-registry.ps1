#Requires -Version 5.1
# Regenerate SURFACE_REGISTRY.md from plugin command modules (ASCII-safe).
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$base = Join-Path $RepoRoot "addons\godot_mcp\commands"
$ver = "unknown"
$cfg = Get-Content (Join-Path $RepoRoot "addons\godot_mcp\plugin.cfg") -Raw
if ($cfg -match 'version="([^"]+)"') { $ver = $Matches[1] }
$date = Get-Date -Format "yyyy-MM-dd"

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# Godot MCP Pro - Tool Surface Registry")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Generated: $date  ")
[void]$sb.AppendLine("Plugin version: **$ver**  ")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Honesty")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Tracks workflow command surface growth - not 100% of ClassDB or every editor control.")
[void]$sb.AppendLine("See list_docs_coverage, DOCS_SURFACE_100.md, GAPS_VS_GODOT_DOCS.md.")
[void]$sb.AppendLine("")

$total = 0
$modCount = 0
$modSections = New-Object System.Text.StringBuilder
Get-ChildItem (Join-Path $base "*.gd") | Sort-Object Name | ForEach-Object {
  $pattern = '^\s*"([a-z_0-9]+)":\s*_'
  $names = @(Select-String -Path $_.FullName -Pattern $pattern | ForEach-Object { $_.Matches.Groups[1].Value })
  if ($names.Count -eq 0) { return }
  $total += $names.Count
  $modCount++
  [void]$modSections.AppendLine("### $($_.BaseName) ($($names.Count))")
  [void]$modSections.AppendLine("")
  foreach ($n in $names) { [void]$modSections.AppendLine("- ``$n``") }
  [void]$modSections.AppendLine("")
}

[void]$sb.AppendLine("## Totals")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("- **Registered plugin commands:** $total")
[void]$sb.AppendLine("- **Command modules:** $modCount")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Commands by module")
[void]$sb.AppendLine("")
[void]$sb.Append($modSections.ToString())
[void]$sb.AppendLine("## Refresh")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("``````powershell")
[void]$sb.AppendLine(".\scripts\export-surface-registry.ps1")
[void]$sb.AppendLine("``````")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Live agent discovery")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("- list_mcp_commands")
[void]$sb.AppendLine("- list_docs_coverage")
[void]$sb.AppendLine("- list_surface_registry")
[void]$sb.AppendLine("")

$out = Join-Path $RepoRoot "SURFACE_REGISTRY.md"
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($out, $sb.ToString(), $utf8)
Write-Host "Wrote $out ($total commands, $modCount modules)"
