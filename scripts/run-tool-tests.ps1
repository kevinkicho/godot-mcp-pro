#Requires -Version 5.1
# Run offline tool-surface test suite.
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $RepoRoot
Write-Host "==> Godot MCP Pro tool surface tests (static)"
python tests/run_all_static.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host ""
Write-Host "Live suite (optional, needs editor plugin):"
Write-Host "  run_critical_path_validation"
Write-Host "  run_tool_validation_suite mode=all_safe write_report=true"
