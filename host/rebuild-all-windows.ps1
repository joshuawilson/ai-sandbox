$ErrorActionPreference = "Stop"

$HostDir = $PSScriptRoot
. "$HostDir\lib\read-vm-host-env.ps1"
$Base = Get-SandboxRepoRoot -HostScriptDirectory $HostDir
$VmEnv = Get-VmHostEnvMerged -RepoRoot $Base
$VMName = $VmEnv['VM_NAME']

Write-Host "=== AI SANDBOX REBUILD (WINDOWS) ==="

Write-Host "[1/4] Generating Kickstart..."
& (Join-Path $Base "host\generate-ks-windows.ps1")

Write-Host "[2/4] Destroying VM..."
Stop-VM -Name $VMName -Force -ErrorAction SilentlyContinue
Remove-VM -Name $VMName -Force -ErrorAction SilentlyContinue

Write-Host "[3/4] Removing disk..."
Remove-Item (Join-Path $Base "vm\$VMName.vhdx") -ErrorAction SilentlyContinue

Write-Host "[4/4] Recreating VM..."
& (Join-Path $Base "host\create-vm-windows.ps1")

Write-Host "Done."
