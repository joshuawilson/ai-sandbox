#Requires -Version 5.1
param(
    [switch]$CreateSmbShare
)

$ErrorActionPreference = "Stop"
$HostDir = $PSScriptRoot
. "$HostDir\lib\read-vm-host-env.ps1"
$Base = Get-SandboxRepoRoot -HostScriptDirectory $HostDir
$VmEnv = Get-VmHostEnvMerged -RepoRoot $Base

$VMName = $VmEnv['VM_NAME']
$VMPath = Join-Path $Base "vm"
$VHD = Join-Path $VMPath "$VMName.vhdx"
$ISO = Join-Path $VMPath "fedora.iso"
$ISOURL = $VmEnv['VM_ISO_URL']
$DiskGb = [int64]$VmEnv['VM_DISK_GB']
$MemBytes = [uint64]$VmEnv['VM_MEMORY_MIB'] * 1MB
$ProcCount = [int]$VmEnv['VM_VCPUS']
$SwitchName = $VmEnv['VM_HYPERV_SWITCH']

New-Item -ItemType Directory -Force -Path $VMPath | Out-Null

if ((Test-Path (Join-Path $Base "secrets\ssh\id_ed25519.pub")) -and (Test-Path (Join-Path $Base "secrets\vm-password.env"))) {
    Write-Host "Generating ks.cfg..."
    & (Join-Path $Base "host\generate-ks-windows.ps1")
} else {
    Write-Host "Skipping generate-ks-windows.ps1 (create secrets\ssh and secrets\vm-password.env first)."
}

Write-Host "Downloading Fedora ISO..."
if (-not (Test-Path $ISO)) {
    Invoke-WebRequest -Uri $ISOURL -OutFile $ISO
}

Write-Host "Creating disk..."
if (-not (Test-Path $VHD)) {
    New-VHD -Path $VHD -SizeBytes ($DiskGb * 1GB) -Dynamic
} else {
    Write-Host "Disk already exists: $VHD"
}

Write-Host "Creating VM..."
$switch = $SwitchName
if (-not (Get-VMSwitch -Name $switch -ErrorAction SilentlyContinue)) {
    $sw = Get-VMSwitch -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $sw) {
        Write-Error "No Hyper-V virtual switch found. Create one in Hyper-V Manager (e.g. Default Switch or External)."
    }
    $switch = $sw.Name
    Write-Host "Using virtual switch: $switch"
}
New-VM -Name $VMName -MemoryStartupBytes $MemBytes -VHDPath $VHD -Generation 2 -SwitchName $switch

Set-VMProcessor -VMName $VMName -Count $ProcCount

# Add DVD drive with ISO
$dvd = Add-VMDvdDrive -VMName $VMName -Path $ISO -Passthru

# Configure firmware for Generation 2 VM
# 1. Disable Secure Boot (required for most Linux ISOs)
Set-VMFirmware -VMName $VMName -EnableSecureBoot Off

# 2. Set boot order: DVD first, then hard drive
$hdd = Get-VMHardDiskDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -BootOrder $dvd,$hdd

Write-Host "Boot order configured: DVD (ISO) first, then VHD"

if ($CreateSmbShare) {
    try {
        $shareName = "ai-sandbox"
        if (-not (Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue)) {
            New-SmbShare -Name $shareName -Path $Base -FullAccess "$env:USERDOMAIN\$env:USERNAME" -ErrorAction Stop
            Write-Host "SMB share created: \\$env:COMPUTERNAME\$shareName -> $Base"
            Write-Host "In the Fedora guest, set /etc/ai-sandbox/cifs.env (see config/cifs.env.example) and USE_CIFS=1, then run ensure-sandbox-mounts.sh."
        }
    } catch {
        Write-Warning "SMB share failed (Home editions or policy may block): $_"
    }
}

Start-VM -VMName $VMName
Write-Host "VM started."

Write-Host ""
Write-Host "=== Kickstart (optional unattended install) ==="
Write-Host "On this host, run:  tools\serve-kickstart.ps1"
Write-Host "At Anaconda boot, add:  inst.ks=http://<this-PC-LAN-IP>:8000/ks.cfg"
Write-Host "Open Windows Firewall for TCP 8000 if needed."
Write-Host ""
Write-Host "=== UTM-style manual install ==="
Write-Host "If you install without kickstart, after Fedora is up configure SMB or virtio-9p in Hyper-V/ guest tools, then:"
Write-Host "  sudo ~/ai-sandbox/config/ensure-sandbox-mounts.sh ai"
Write-Host "  ~/ai-sandbox/config/install-inside-vm.sh"
