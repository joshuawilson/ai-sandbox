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

            # Check if we're using guest or authenticated access
            $SmbPasswordFile = Join-Path $Base "secrets\smb-password.env"
            if (Test-Path $SmbPasswordFile) {
                # Authenticated access - only grant access to current user
                New-SmbShare -Name $shareName -Path $Base -FullAccess "$env:USERDOMAIN\$env:USERNAME" -Description "AI Sandbox (authenticated)" -ErrorAction Stop
                Write-Host "SMB share created (authenticated access as $env:USERNAME)"
            } else {
                # Guest access - grant Everyone read access
                New-SmbShare -Name $shareName -Path $Base -ReadAccess "Everyone" -Description "AI Sandbox (guest)" -ErrorAction Stop
                Grant-SmbShareAccess -Name $shareName -AccountName "$env:USERDOMAIN\$env:USERNAME" -AccessRight Full -Force -ErrorAction SilentlyContinue
                Write-Host "SMB share created (guest access - may require AllowInsecureGuestAuth)"
                Write-Host "For better security, run: .\host\write-smb-password-env.ps1"
            }
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
Write-Host "=== Kickstart Installation ===" -ForegroundColor Cyan
Write-Host ""

if ($useKickstart) {
    Write-Host "Kickstart ISO created and attached." -ForegroundColor Green
    Write-Host ""
    Write-Host "NOTE: Fedora Workstation Live ISO does not auto-detect kickstart." -ForegroundColor Yellow
    Write-Host "You must add the boot parameter manually (one time, at first boot):" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  IN THE VM, AT BOOT MENU:" -ForegroundColor White
    Write-Host "    1. Press 'e' to edit boot options"
    Write-Host "    2. Add to the end of the 'linux' line:"
    Write-Host "       inst.ks=hd:LABEL=OEMDRV:/ks.cfg" -ForegroundColor Green
    Write-Host "    3. Press Ctrl+X to boot"
    Write-Host ""
    Write-Host "  OR use HTTP kickstart (fully automatic):" -ForegroundColor White
    Write-Host "    Run: .\host\start-kickstart-server-windows.ps1"
    Write-Host "    (Displays IP and boot parameter automatically)"
} else {
    Write-Host "Kickstart ISO creation failed (oscdimg not available)." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Use HTTP kickstart instead (easier and more reliable):" -ForegroundColor Green
    Write-Host "  Run: .\host\start-kickstart-server-windows.ps1"
    Write-Host ""
    Write-Host "This will display your IP and the exact boot parameter to use."
}

Write-Host ""
Write-Host "After kickstart installation:" -ForegroundColor Cyan
Write-Host "  - Username: ai"
Write-Host "  - Password: (see secrets\vm-password.env)"
Write-Host "  - SMB share will auto-mount"
Write-Host "  - Cursor, Podman, Claude will install automatically"
Write-Host ""
Write-Host "Create a checkpoint after install:"
Write-Host "  Checkpoint-VM -Name $VMName -SnapshotName 'Clean Install'"
