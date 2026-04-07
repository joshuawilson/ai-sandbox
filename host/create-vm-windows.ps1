#Requires -Version 5.1
param(
    [switch]$SkipSmbShare
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

$useKickstart = $false
if ((Test-Path (Join-Path $Base "secrets\ssh\id_ed25519.pub")) -and (Test-Path (Join-Path $Base "secrets\vm-password.env"))) {
    Write-Host "Generating ks.cfg..."
    & (Join-Path $Base "host\generate-ks-windows.ps1")
    $useKickstart = $true
} else {
    Write-Host "Skipping kickstart (create secrets\ssh and secrets\vm-password.env first)."
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

# Add primary DVD drive with Fedora ISO
$dvd = Add-VMDvdDrive -VMName $VMName -Path $ISO -Passthru

# Try to create and attach kickstart ISO for automated installation
if ($useKickstart) {
    try {
        $ksISO = Join-Path $VMPath "kickstart.iso"
        Write-Host "Creating kickstart ISO for automated installation..."
        & (Join-Path $Base "host\create-ks-iso-windows.ps1") -OutputISO $ksISO
        if (Test-Path $ksISO) {
            Add-VMDvdDrive -VMName $VMName -Path $ksISO
            Write-Host "Kickstart ISO attached - installation will proceed automatically"
        }
    } catch {
        Write-Warning "Failed to create kickstart ISO: $_"
        Write-Host "Fallback: use manual kickstart with tools\serve-kickstart.ps1"
        $useKickstart = $false
    }
}

# Configure firmware for Generation 2 VM
# 1. Disable Secure Boot (required for most Linux ISOs)
Set-VMFirmware -VMName $VMName -EnableSecureBoot Off

# 2. Set boot order: DVD first, then hard drive
$hdd = Get-VMHardDiskDrive -VMName $VMName
Set-VMFirmware -VMName $VMName -BootOrder $dvd,$hdd

Write-Host "Boot order configured: DVD (ISO) first, then VHD"

# Create SMB share for guest to access config/secrets/workspace (required for automated setup)
if (-not $SkipSmbShare) {
    try {
        $shareName = "ai-sandbox"
        $existingShare = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue
        if ($existingShare) {
            Write-Host "SMB share already exists: \\$env:COMPUTERNAME\$shareName"
            if ($existingShare.Path -ne $Base) {
                Write-Warning "Existing share points to $($existingShare.Path), expected $Base"
                Write-Host "Remove with: Remove-SmbShare -Name '$shareName' -Force"
            }
        } else {
            Write-Host "Creating SMB share: \\$env:COMPUTERNAME\$shareName -> $Base"
            New-SmbShare -Name $shareName -Path $Base -FullAccess "$env:USERDOMAIN\$env:USERNAME" -ErrorAction Stop
            Write-Host "SMB share created successfully"
        }
        Write-Host "Guest will auto-mount via CIFS: //$env:COMPUTERNAME/ai-sandbox"
    } catch {
        Write-Warning "SMB share creation failed: $_"
        Write-Warning "This is common on Windows Home edition or with restrictive policies."
        Write-Warning "Without SMB share, you must manually copy files or use alternative mounting."
        Write-Host ""
        Write-Host "Alternative: Use virtiofs via WSL2 or manual file sync."
    }
}

Start-VM -VMName $VMName
Write-Host "VM started."

Write-Host ""
if ($useKickstart) {
    Write-Host "=== Automated Kickstart Installation ===" -ForegroundColor Green
    Write-Host "Kickstart ISO attached - Fedora will install automatically!"
    Write-Host "The VM will:"
    Write-Host "  1. Boot from the Fedora ISO"
    Write-Host "  2. Auto-detect ks.cfg from the kickstart ISO (OEMDRV label)"
    Write-Host "  3. Install Fedora unattended (~15-30 minutes)"
    Write-Host "  4. Reboot into the desktop"
    Write-Host "  5. Auto-mount SMB share and run install-inside-vm.sh"
    Write-Host ""
    Write-Host "Username: ai"
    Write-Host "Password: (see secrets\vm-password.env)"
    Write-Host ""
    Write-Host "After installation completes, you can create a checkpoint:"
    Write-Host "  Checkpoint-VM -Name $VMName -SnapshotName 'Clean Install'"
} else {
    Write-Host "=== Manual Kickstart (HTTP) ===" -ForegroundColor Yellow
    Write-Host "On this host, run:  tools\serve-kickstart.ps1"
    Write-Host "At Anaconda boot, add:  inst.ks=http://<this-PC-LAN-IP>:8000/ks.cfg"
    Write-Host "Open Windows Firewall for TCP 8000 if needed."
    Write-Host ""
    Write-Host "=== Or Manual Install ==="
    Write-Host "After Fedora is up, configure SMB or virtio-9p, then:"
    Write-Host "  sudo ~/ai-sandbox/config/ensure-sandbox-mounts.sh ai"
    Write-Host "  ~/ai-sandbox/config/install-inside-vm.sh"
}
