#Requires -Version 5.1
<#
  Start HTTP kickstart server and display connection instructions for the VM.
  This is the most reliable kickstart method for Windows/Hyper-V.
#>

param(
    [int]$Port = 8000
)

$ErrorActionPreference = "Stop"

$HostDir = $PSScriptRoot
. "$HostDir\lib\read-vm-host-env.ps1"
$Base = Get-SandboxRepoRoot -HostScriptDirectory $HostDir

# Check ks.cfg exists
$KsCfg = Join-Path $Base "ks.cfg"
if (-not (Test-Path $KsCfg)) {
    Write-Error @"
ks.cfg not found. Run first:
  .\host\generate-ks-windows.ps1
"@
}

# Get host IP address(es)
$ips = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } |
    Select-Object -ExpandProperty IPAddress

if (-not $ips) {
    Write-Warning "No network IP found - using localhost"
    $ips = @("127.0.0.1")
}

$primaryIp = $ips[0]

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  AI Sandbox - Kickstart Server" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Serving: $Base" -ForegroundColor Green
Write-Host "Port:    $Port" -ForegroundColor Green
Write-Host ""

if ($ips.Count -gt 1) {
    Write-Host "Available IP addresses:" -ForegroundColor Yellow
    foreach ($ip in $ips) {
        Write-Host "  - $ip"
    }
    Write-Host ""
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  IN THE HYPER-V VM - AT BOOT MENU:" -ForegroundColor White
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Press 'e' to edit boot options" -ForegroundColor Yellow
Write-Host ""
Write-Host "2. Find the line starting with 'linux'" -ForegroundColor Yellow
Write-Host ""
Write-Host "3. Add at the END of that line:" -ForegroundColor Yellow
Write-Host ""
Write-Host "   inst.ks=http://${primaryIp}:${Port}/ks.cfg" -ForegroundColor Green -BackgroundColor Black
Write-Host ""
Write-Host "4. Press Ctrl+X to boot" -ForegroundColor Yellow
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Check firewall
try {
    $fwRule = Get-NetFirewallRule -DisplayName "ai-sandbox-kickstart" -ErrorAction SilentlyContinue
    if (-not $fwRule) {
        Write-Host "Firewall: Not configured" -ForegroundColor Yellow
        Write-Host "If the VM can't connect, run in another elevated PowerShell:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  New-NetFirewallRule -DisplayName 'ai-sandbox-kickstart' -Direction Inbound -LocalPort $Port -Protocol TCP -Action Allow" -ForegroundColor Gray
        Write-Host ""
    } else {
        Write-Host "Firewall: Rule 'ai-sandbox-kickstart' is configured" -ForegroundColor Green
        Write-Host ""
    }
} catch {
    # Non-admin, can't check firewall
}

Write-Host "Starting HTTP server on port $Port..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop when installation begins" -ForegroundColor Gray
Write-Host ""
Write-Host "------------------------------------------------"
Write-Host ""

# Start Python HTTP server
Set-Location $Base

$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) {
    & python -m http.server $Port --bind 0.0.0.0
} else {
    Write-Error @"
Python not found. Install Python 3:
  https://python.org

Or use PowerShell alternative (slower):
  # In an elevated PowerShell:
  Install-Module -Name PSWebServer
  Start-PSWebServer -Path '$Base' -Port $Port
"@
}
