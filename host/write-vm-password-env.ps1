#Requires -Version 5.1
<#
  Create secrets\vm-password.env for kickstart user "ai" on the Fedora VM (login/unlock).
  Cursor runs in the VM—not inside Podman—so there is no separate container password for the IDE.
  The password remains in this file on the host for later lookup.

  Writes to this repo's secrets\ (folder that contains host\). If the file is missing, empty, or has no
  VM_PASSWORD= line, a new password is generated. Use -Force to replace an existing file.
  Use -Manual to prompt for password twice (no auto-generation).

  Run:  .\host\write-vm-password-env.ps1
        .\host\write-vm-password-env.ps1 -Force
        .\host\write-vm-password-env.ps1 -Manual
#>
param(
    [switch]$Force,
    [switch]$Manual
)

$ErrorActionPreference = "Stop"

$HostDir = $PSScriptRoot
. "$HostDir\lib\read-vm-host-env.ps1"
$Base = Get-SandboxRepoRoot -HostScriptDirectory $HostDir
$F = Join-Path $Base "secrets\vm-password.env"

function Test-PasswordLineOk {
    if (-not (Test-Path $F)) { return $false }
    if ((Get-Item $F).Length -eq 0) { return $false }
    $text = Get-Content -Raw -LiteralPath $F
    return $text -match '(?m)^\s*VM_PASSWORD\s*='
}

function ConvertTo-BashSingleQuoted([string]$s) {
    if ($null -eq $s) { return "''" }
    return "'" + ($s -replace "'", "'\''") + "'"
}

function Write-VmPasswordLine([string]$password) {
    $line = "VM_PASSWORD=" + (ConvertTo-BashSingleQuoted $password)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($F, "$line`n", $utf8NoBom)
}

if ($Manual) {
    if (-not $Force -and (Test-PasswordLineOk)) {
        $ov = Read-Host "Overwrite existing vm-password.env? [y/N]"
        if ($ov -notmatch '^[Yy]') {
            Write-Host "Keeping existing $F"
            exit 0
        }
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $F) | Out-Null
    Write-Host "Enter a password for kickstart user 'ai' (stored in $F)."
    $sec1 = Read-Host "Password" -AsSecureString
    $sec2 = Read-Host "Confirm" -AsSecureString
    $bstr1 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec1)
    $bstr2 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec2)
    try {
        $p1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr1)
        $p2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr2)
    } finally {
        if ($bstr1 -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr1) }
        if ($bstr2 -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr2) }
    }
    if ([string]::IsNullOrEmpty($p1)) {
        Write-Error "Password cannot be empty."
    }
    if ($p1 -ne $p2) {
        Write-Error "Passwords do not match."
    }
    Write-VmPasswordLine $p1
    Write-Host "Wrote $F"
    Write-Host "Store this password safely; it is used for the VM user in kickstart."
    exit 0
}

if (-not $Force -and (Test-PasswordLineOk)) {
    Write-Host "Already exists (unchanged): $F"
    exit 0
}

New-Item -ItemType Directory -Force -Path (Split-Path $F) | Out-Null

$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$bytes = New-Object byte[] 24
$rng.GetBytes($bytes)
$pw = [Convert]::ToBase64String($bytes)
Write-VmPasswordLine $pw
Write-Host "Wrote $F"
Write-Host "VM_PASSWORD is set (see file)."
Write-Host "Store this password safely; it is used for the VM user in kickstart."
