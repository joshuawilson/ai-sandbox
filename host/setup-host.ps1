#Requires -RunAsAdministrator
<#
  One entry point for Windows: install-virt-windows.ps1, then check-host-windows.ps1.
  From repo root (elevated PowerShell):
    Set-ExecutionPolicy -Scope Process Bypass; .\setup-host.ps1
  Check only (after reboot):
    .\setup-host.ps1 -CheckOnly
  Real script lives under host/; repo root setup-host.ps1 is a thin wrapper.
#>
param(
    [switch]$CheckOnly,
    [switch]$Help,
    [switch]$SkipVmConfig
)

$ErrorActionPreference = "Stop"

$HostScriptDir = $PSScriptRoot
$RepoRoot = Split-Path -Parent $HostScriptDir
Set-Location $RepoRoot

if ($Help) {
    Write-Host @"
Usage: .\setup-host.ps1 [-CheckOnly] [-SkipVmConfig]

  Installs Hyper-V prerequisites (unless -CheckOnly), then runs check-host-windows.ps1.
  After a successful check, offers host\configure-vm-host.ps1 (or bash configure-vm-host.sh
  if Git Bash is installed) for VM sizing + auto-generated secrets\vm-password.env.
  Use -SkipVmConfig or env SKIP_VM_CONFIGURE=1 to skip.

  Unix hosts: use ./setup-host.sh
"@
    exit 0
}

if ($CheckOnly) {
    & "$HostScriptDir\check-host-windows.ps1"
    exit $LASTEXITCODE
}

& "$HostScriptDir\install-virt-windows.ps1"
Write-Host ""
& "$HostScriptDir\check-host-windows.ps1"

if (-not $CheckOnly -and -not $SkipVmConfig -and [string]::IsNullOrEmpty($env:SKIP_VM_CONFIGURE)) {
    if ([Environment]::UserInteractive) {
        $cfg = Read-Host "Configure VM sizing and guest password (host\vm-host.env + secrets)? [Y/n]"
        if ($cfg -eq '' -or $cfg -match '^[Yy]') {
            $bash = Get-Command bash -ErrorAction SilentlyContinue
            if ($null -ne $bash) {
                bash (Join-Path $HostScriptDir "configure-vm-host.sh")
            } else {
                & (Join-Path $HostScriptDir "configure-vm-host.ps1")
            }
        } else {
            Write-Host "Skipped. Run host\configure-vm-host.ps1 (or .sh) before create-vm when ready."
        }
    } else {
        Write-Host ""
        Write-Host "Non-interactive: skipped VM config. Before create-vm run: host\configure-vm-host.ps1"
    }
}
