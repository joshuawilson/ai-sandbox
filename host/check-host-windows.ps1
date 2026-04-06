#Requires -Version 5.1
# Read-only check: Windows host ready for create-vm-windows.ps1 (Hyper-V + Git + keys).
# Run in PowerShell. Some Hyper-V checks need Administrator -- script degrades gracefully.

$ErrorActionPreference = "Continue"
$HostDir = $PSScriptRoot
. "$HostDir\lib\read-vm-host-env.ps1"
$Base = Get-SandboxRepoRoot -HostScriptDirectory $HostDir

function Ok($m) { Write-Host "OK   $m" -ForegroundColor Green }
function Warn($m) { Write-Host "WARN $m" -ForegroundColor Yellow }
function Miss($m) { Write-Host "MISS $m" -ForegroundColor Red }

$issues = 0
$warnings = 0

Write-Host "=== AI Sandbox -- Windows host check ===" -ForegroundColor White
Write-Host ""

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Warn "PowerShell 5.1+ recommended."
    $warnings++
}

# --- Edition: Home vs Pro (Hyper-V not on Home) ---
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
if ($os) {
    Ok "OS: $($os.Caption)"
    if ($os.Caption -match 'Home') {
        Warn "Windows Home does not include Hyper-V -- use Windows Pro/Enterprise/Education, or use WSL2 + different workflow."
        $warnings++
    }
}

# --- Virtualization firmware (BIOS) ---
try {
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    if ($cs.HypervisorPresent) {
        Ok "HypervisorPresent: true (hypervisor detected)"
    } else {
        Warn "HypervisorPresent: false -- enable Virtualization in UEFI/firmware (Intel VT-x / AMD-V) and ensure no conflict with other hypervisors."
        $warnings++
    }
} catch {
    Warn "Could not read Win32_ComputerSystem: $_"
    $warnings++
}

# --- Hyper-V feature (often needs Admin) ---
$script:hvState = $null
try {
    $f = $null
    foreach ($name in @('Microsoft-Hyper-V', 'Microsoft-Hyper-V-All')) {
        $f = Get-WindowsOptionalFeature -Online -FeatureName $name -ErrorAction SilentlyContinue
        if ($f) { break }
    }
    if ($f) {
        $script:hvState = $f.State
        if ($f.State -eq "Enabled") {
            Ok "Windows feature Hyper-V: Enabled"
        } else {
            Miss "Hyper-V: $($f.State) -- run install-virt-windows.ps1 as Administrator, or: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All"
            $issues++
        }
    } else {
        Warn "Could not find Hyper-V optional feature (run as Administrator to verify)"
        $warnings++
    }
} catch {
    Warn "Could not query Hyper-V feature (try Administrator): $_"
    $warnings++
}

# --- Hyper-V PowerShell module / services ---
if (Get-Command Get-VM -ErrorAction SilentlyContinue) {
    Ok "Hyper-V module available (Get-VM)"
    try {
        $sw = Get-VMSwitch -ErrorAction SilentlyContinue
        if ($sw) {
            Ok "At least one virtual switch exists: $($sw[0].Name)"
        } else {
            Miss "No Hyper-V virtual switch -- create 'Default Switch' or an external switch in Hyper-V Manager"
            $issues++
        }
    } catch {
        Warn "Could not list VMSwitch: $_"
        $warnings++
    }
} else {
    if ($script:hvState -eq "Enabled") {
        Warn "Hyper-V enabled but Get-VM missing -- reboot or install Hyper-V management tools."
        $warnings++
    }
}

# --- Git + ssh-keygen (install-virt-windows.ps1) ---
$gitSsh = "C:\Program Files\Git\usr\bin\ssh-keygen.exe"
if (Test-Path $gitSsh) {
    Ok "Git ssh-keygen: $gitSsh"
} else {
    Miss "Git for Windows (ssh-keygen) -- run install-virt-windows.ps1 or install from https://git-scm.com/"
    $issues++
}

if (Get-Command git -ErrorAction SilentlyContinue) {
    Ok "git on PATH"
} else {
    Warn "git not on PATH -- re-open terminal after Git install"
    $warnings++
}

# --- Python (tools/serve-kickstart.ps1) ---
if (Get-Command python -ErrorAction SilentlyContinue) {
    Ok "python on PATH (for tools/serve-kickstart.ps1)"
} else {
    Warn "python not on PATH -- install Python 3 or use Git Bash + tools/serve-kickstart.sh"
    $warnings++
}

# --- OpenSSL from Git (generate-ks-windows.ps1) ---
$ossl = Join-Path ${env:ProgramFiles} "Git\usr\bin\openssl.exe"
if (Test-Path $ossl) {
    Ok "OpenSSL (Git): $ossl"
} else {
    Miss "Git OpenSSL -- install Git for Windows"
    $issues++
}

# --- Repo layout ---
if (Test-Path $Base) {
    Ok "Directory exists: $Base"
} else {
    Miss "Repo not found at $Base (clone or set SANDBOX/AI_SANDBOX_HOME)"
    $issues++
}

$pub = Join-Path $Base "secrets\ssh\id_ed25519.pub"
if (Test-Path $pub) {
    Ok "sandbox SSH public key present"
} else {
    Warn "No $pub -- run install-virt-windows.ps1"
    $warnings++
}

$vmpw = Join-Path $Base "secrets\vm-password.env"
if (Test-Path $vmpw) {
    Ok "secrets\vm-password.env present"
} else {
    Warn "No $vmpw -- create before generate-ks-windows.ps1"
    $warnings++
}

Write-Host ""
Write-Host "Manual steps (not scripted):" -ForegroundColor White
Write-Host "  - Enable virtualization in BIOS/UEFI if Hyper-V or VMs fail to start."
Write-Host "  - Reboot after enabling Hyper-V if the installer asked."
Write-Host "  - Windows Firewall: allow TCP 8000 if you use serve-kickstart for inst.ks=http://..."
Write-Host "  - SMB: create-vm-windows.ps1 -CreateSmbShare may require file sharing enabled."
Write-Host ""
Write-Host "Summary: issues=$issues warnings=$warnings" -ForegroundColor White
if ($issues -gt 0) {
    Write-Host "Fix MISS lines before create-vm-windows.ps1." -ForegroundColor Red
    exit 1
}
if ($warnings -gt 0) {
    Write-Host "Review WARN lines." -ForegroundColor Yellow
} else {
    Write-Host "Host looks ready to create the VM." -ForegroundColor Green
}
if ($warnings -gt 0 -and $issues -eq 0) {
    Write-Host "Host is usable once WARN lines are acceptable." -ForegroundColor Green
}
Write-Host ""
Write-Host "Next (first VM on this host):" -ForegroundColor White
Write-Host "  1. Ensure secrets\vm-password.env exists (see host\write-vm-password-env.ps1)."
Write-Host "  2. Run:  host\create-vm-windows.ps1"
Write-Host ""
Write-Host "That script runs generate-ks-windows.ps1 for you. Run generate-ks-windows.ps1 alone only to refresh ks.cfg without reinstalling."
exit 0
