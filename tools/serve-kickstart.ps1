# Serves ai-sandbox repo over HTTP for inst.ks=http://<host>:PORT/ks.cfg
param([int]$Port = 8000)

$ErrorActionPreference = "Stop"
$ToolsDir = $PSScriptRoot
$Base = if ($env:AI_SANDBOX_HOME) { $env:AI_SANDBOX_HOME } elseif ($env:SANDBOX) { $env:SANDBOX } else { (Resolve-Path (Join-Path $ToolsDir "..")).Path }
$Ks = Join-Path $Base "ks.cfg"
if (-not (Test-Path $Ks)) {
    Write-Error "Missing $Ks  - run generate-ks-windows.ps1 first."
}

Set-Location $Base
$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) {
    Write-Host "Serving: $Base (Python)"
    Write-Host "Kickstart: http://<host-LAN-ip>:$Port/ks.cfg"
    Write-Host "Anaconda boot option: inst.ks=http://<host-ip>:$Port/ks.cfg"
    Write-Host "Firewall (elevated): New-NetFirewallRule -DisplayName ai-sandbox-ks -Direction Inbound -LocalPort $Port -Protocol TCP -Action Allow"
    & python -m http.server $Port --bind 0.0.0.0
    exit 0
}

Write-Host "Python not found. Install Python 3, or from Git Bash run: ./tools/serve-kickstart.sh"
Write-Host "Alternatively use WSL: cd `$HOME/ai-sandbox; python3 -m http.server $Port --bind 0.0.0.0"
exit 1
