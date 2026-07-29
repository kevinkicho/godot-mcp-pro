#Requires -Version 5.1
# Regenerate SURFACE_REGISTRY.md from plugin command modules (recursive domains).
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
[void]$sb.AppendLine("See list_docs_coverage, docs/PRODUCTION_SURFACE_COMPLETE.md, GAPS_VS_GODOT_DOCS.md.")
[void]$sb.AppendLine("Modules live under addons/godot_mcp/commands/<domain>/ (recursive auto-discover).")
[void]$sb.AppendLine("")

$total = 0
$modCount = 0
$domainCounts = @{}
$modSections = New-Object System.Text.StringBuilder

$files = Get-ChildItem -Path $base -Filter '*_commands.gd' -File -Recurse | Sort-Object FullName
foreach ($file in $files) {
  $pattern = '^\s*"([a-z_0-9]+)":\s*_'
  $names = @(Select-String -Path $file.FullName -Pattern $pattern | ForEach-Object { $_.Matches.Groups[1].Value })
  if ($names.Count -eq 0) { continue }
  $rel = $file.FullName.Substring($base.Length).TrimStart('\', '/')
  $domain = 'root'
  if ($rel.Contains('\') -or $rel.Contains('/')) {
    $domain = ($rel -split '[\\/]')[0]
  }
  if (-not $domainCounts.ContainsKey($domain)) { $domainCounts[$domain] = 0 }
  $domainCounts[$domain] += $names.Count
  $total += $names.Count
  $modCount++
  [void]$modSections.AppendLine("### $domain / $($file.BaseName) ($($names.Count))")
  [void]$modSections.AppendLine("")
  foreach ($n in $names) { [void]$modSections.AppendLine("- ``$n``") }
  [void]$modSections.AppendLine("")
}

[void]$sb.AppendLine("## Totals")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("- **Registered plugin commands:** $total")
[void]$sb.AppendLine("- **Command modules:** $modCount")
[void]$sb.AppendLine("- **Domains:** $($domainCounts.Count)")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Commands by domain")
[void]$sb.AppendLine("")
foreach ($d in ($domainCounts.Keys | Sort-Object)) {
  [void]$sb.AppendLine(("- **{0}** - {1} commands" -f $d, $domainCounts[$d]))
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Commands by module")
[void]$sb.AppendLine("")
[void]$sb.Append($modSections.ToString())
[void]$sb.AppendLine("## Refresh")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("``````powershell")
[void]$sb.AppendLine(".\scripts\export-surface-registry.ps1")
[void]$sb.AppendLine(".\scripts\organize-command-modules.ps1  # optional re-bucket")
[void]$sb.AppendLine("``````")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Live agent discovery")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("- list_mcp_commands / list_command_modules / list_command_domains")
[void]$sb.AppendLine("- list_docs_coverage / get_production_surface_report")
[void]$sb.AppendLine("- list_surface_registry")
[void]$sb.AppendLine("")

$out = Join-Path $RepoRoot "SURFACE_REGISTRY.md"
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($out, $sb.ToString(), $utf8)
Write-Host "Wrote $out ($total commands, $modCount modules, $($domainCounts.Count) domains)"
