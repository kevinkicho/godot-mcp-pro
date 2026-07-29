#Requires -Version 5.1
# Offline validation for full MCP tool surface (no Godot required).
$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root
python tests/run_all_static.py
exit $LASTEXITCODE
