#Requires -Version 5.1
<#
  Stop or remove the Hyper-V AI Sandbox VM. Default name: ai-sandbox (override: $env:VIRSH_DOMAIN).
  Usage:
    .\host\stop-vm-windows.ps1              # force turn-off, keep VM + VHD
    .\host\stop-vm-windows.ps1 -Shutdown    # try graceful stop first
    .\host\stop-vm-windows.ps1 -Remove     # turn off, remove VM + disk under vm\
#>
param(
    [switch]$Shutdown,
    [switch]$Remove
)

$ErrorActionPreference = "Stop"

$HostDir = $PSScriptRoot
. "$HostDir\lib\read-vm-host-env.ps1"
$Base = Get-SandboxRepoRoot -HostScriptDirectory $HostDir
$VmEnv = Get-VmHostEnvMerged -RepoRoot $Base
$Name = if ($env:VIRSH_DOMAIN) { $env:VIRSH_DOMAIN } else { $VmEnv['VM_NAME'] }
$VMPath = Join-Path $Base "vm"
$VHD = Join-Path $VMPath "$Name.vhdx"

function Test-HyperVAvailable {
    return $null -ne (Get-Command Get-VM -ErrorAction SilentlyContinue)
}

if (-not (Test-HyperVAvailable)) {
    Write-Error "Hyper-V cmdlets not available (run elevated, enable Hyper-V)."
    exit 1
}

$vm = Get-VM -Name $Name -ErrorAction SilentlyContinue
if (-not $vm) {
    Write-Host "VM '$Name' not found."
    if ($Remove -and (Test-Path $VHD)) {
        Write-Host "Removing leftover disk: $VHD"
        Remove-Item -Force $VHD
    }
    exit 0
}

if ($vm.State -eq 'Running') {
    if ($Shutdown) {
        Write-Host "Stopping $Name (guest ACPI)..."
        Stop-VM -Name $Name
        $deadline = (Get-Date).AddSeconds(120)
        while ((Get-VM -Name $Name).State -eq 'Running' -and (Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 2
        }
    }
    if ((Get-VM -Name $Name).State -eq 'Running') {
        Write-Host "Force turn-off $Name..."
        Stop-VM -Name $Name -TurnOff -Force
    }
} else {
    Write-Host "VM $Name is not running."
}

if ($Remove) {
    Write-Host "Removing VM $Name and disk..."
    Remove-VM -Name $Name -Force
    if (Test-Path $VHD) {
        Remove-Item -Force $VHD
    }
    Write-Host "Cleanup done. Recreate with: host\create-vm-windows.ps1"
}
