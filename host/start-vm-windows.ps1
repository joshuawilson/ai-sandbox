# Start an existing Hyper-V VM. Default name: VM_NAME from host\vm-host.env or ai-sandbox
$ErrorActionPreference = "Stop"

$HostDir = $PSScriptRoot
. "$HostDir\lib\read-vm-host-env.ps1"
$Base = Get-SandboxRepoRoot -HostScriptDirectory $HostDir
$VmEnv = Get-VmHostEnvMerged -RepoRoot $Base
$Name = if ($env:VIRSH_DOMAIN) { $env:VIRSH_DOMAIN } else { $VmEnv['VM_NAME'] }

try {
    $vm = Get-VM -Name $Name -ErrorAction Stop
    if ($vm.State -eq 'Running') {
        Write-Host "VM $Name is already running."
    } else {
        Start-VM -Name $Name
        Write-Host "Started VM $Name."
    }
} catch {
    Write-Error "VM $Name not found. Create it with host\create-vm-windows.ps1 first."
    exit 1
}

Write-Host "Log in to the guest, then: ~/ai-sandbox/config/start-day.sh"
