#Requires -Version 5.1
<#
  Debug kickstart ISO creation and attachment for Windows VMs.
#>

$ErrorActionPreference = "Continue"

$HostDir = $PSScriptRoot
. "$HostDir\lib\read-vm-host-env.ps1"
$Base = Get-SandboxRepoRoot -HostScriptDirectory $HostDir
$VmEnv = Get-VmHostEnvMerged -RepoRoot $Base
$VMName = $VmEnv['VM_NAME']

Write-Host "=== Kickstart Debugging for Windows ===" -ForegroundColor Cyan
Write-Host ""

# Check ks.cfg exists
$KsCfg = Join-Path $Base "ks.cfg"
if (Test-Path $KsCfg) {
    Write-Host "[OK] ks.cfg exists: $KsCfg" -ForegroundColor Green
    Write-Host "     Size: $((Get-Item $KsCfg).Length) bytes"

    # Check for CIFS_GUEST setting
    $content = Get-Content $KsCfg -Raw
    if ($content -match "CIFS_GUEST=1") {
        Write-Host "     Mode: Guest access (no password)" -ForegroundColor Green
    } elseif ($content -match "CIFS_CREDENTIALS") {
        Write-Host "     Mode: Authenticated (with credentials)" -ForegroundColor Green
    } else {
        Write-Host "     WARNING: No CIFS configuration found" -ForegroundColor Yellow
    }
} else {
    Write-Host "[FAIL] ks.cfg missing: $KsCfg" -ForegroundColor Red
    Write-Host "       Run: .\host\generate-ks-windows.ps1"
}

Write-Host ""

# Check kickstart ISO exists
$KsISO = Join-Path $Base "vm\kickstart.iso"
if (Test-Path $KsISO) {
    Write-Host "[OK] Kickstart ISO exists: $KsISO" -ForegroundColor Green
    Write-Host "     Size: $([math]::Round((Get-Item $KsISO).Length / 1KB, 2)) KB"
} else {
    Write-Host "[FAIL] Kickstart ISO missing: $KsISO" -ForegroundColor Red
    Write-Host "       This is why kickstart didn't run automatically!" -ForegroundColor Yellow
    Write-Host "       Install oscdimg: .\host\install-adk-windows.ps1"
    Write-Host "       Then recreate ISO: .\host\create-ks-iso-windows.ps1"
}

Write-Host ""

# Check VM DVD drives
try {
    $dvds = Get-VMDvdDrive -VMName $VMName -ErrorAction SilentlyContinue
    if ($dvds) {
        Write-Host "[INFO] VM DVD Drives:" -ForegroundColor Cyan
        $dvdNum = 1
        foreach ($dvd in $dvds) {
            Write-Host "       DVD $dvdNum : $(if ($dvd.Path) { $dvd.Path } else { '(empty)' })"
            if ($dvd.Path -like "*kickstart.iso") {
                Write-Host "              ^ This should trigger auto-kickstart (OEMDRV label)" -ForegroundColor Green
            }
            $dvdNum++
        }
    } else {
        Write-Host "[WARN] No DVD drives found on VM" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[WARN] Could not query VM (not running or need Administrator): $_" -ForegroundColor Yellow
}

Write-Host ""

# Check SMB share
$shareName = "ai-sandbox"
$share = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue
if ($share) {
    Write-Host "[OK] SMB share exists: \\$env:COMPUTERNAME\$shareName" -ForegroundColor Green
    Write-Host "     Path: $($share.Path)"

    # Check permissions
    $access = Get-SmbShareAccess -Name $shareName -ErrorAction SilentlyContinue
    if ($access) {
        Write-Host "     Access:"
        $access | ForEach-Object {
            Write-Host "       - $($_.AccountName): $($_.AccessRight) $($_.AccessControlType)"
        }
    }
} else {
    Write-Host "[FAIL] SMB share missing: $shareName" -ForegroundColor Red
    Write-Host "       Guest won't be able to mount host files!" -ForegroundColor Yellow
    Write-Host "       The VM will create: .\host\create-vm-windows.ps1"
}

Write-Host ""
Write-Host "=== Solutions ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $KsISO)) {
    Write-Host "Problem: No kickstart ISO (manual install required)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Solution 1 - Install ADK and rebuild VM:" -ForegroundColor Green
    Write-Host "  .\host\install-adk-windows.ps1"
    Write-Host "  .\stop-vm.ps1 -Remove"
    Write-Host "  .\host\create-vm-windows.ps1"
    Write-Host ""
    Write-Host "Solution 2 - Use HTTP kickstart (works now):" -ForegroundColor Green
    Write-Host "  1. Terminal 1: .\tools\serve-kickstart.ps1"
    Write-Host "  2. Get IP: ipconfig | Select-String 'IPv4'"
    Write-Host "  3. In VM: Press 'e' at boot menu"
    Write-Host "  4. Add to kernel line: inst.ks=http://YOUR-IP:8000/ks.cfg"
    Write-Host "  5. Press Ctrl+X to boot"
} else {
    Write-Host "Kickstart ISO exists but wasn't detected by Anaconda." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This can happen if:" -ForegroundColor Yellow
    Write-Host "  - ISO was created without OEMDRV volume label"
    Write-Host "  - ISO was attached after VM already booted"
    Write-Host "  - Anaconda started before detecting the second DVD"
    Write-Host ""
    Write-Host "Try:" -ForegroundColor Green
    Write-Host "  1. Stop the VM: .\stop-vm.ps1"
    Write-Host "  2. Start it again: .\start-vm.ps1"
    Write-Host "  3. Watch the boot - Anaconda should find ks.cfg automatically"
    Write-Host ""
    Write-Host "Or use HTTP kickstart (see Solution 2 above)" -ForegroundColor Green
}
