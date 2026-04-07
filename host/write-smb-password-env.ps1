#Requires -Version 5.1
<#
  Create secrets\smb-password.env with your Windows account password for SMB share access.
  This is stored in the same format as vm-password.env.
#>
param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$HostDir = $PSScriptRoot
. "$HostDir\lib\read-vm-host-env.ps1"
$Base = Get-SandboxRepoRoot -HostScriptDirectory $HostDir
$F = Join-Path $Base "secrets\smb-password.env"

function Test-PasswordLineOk {
    if (-not (Test-Path $F)) { return $false }
    if ((Get-Item $F).Length -eq 0) { return $false }
    $text = Get-Content -Raw -LiteralPath $F
    return $text -match '(?m)^\s*SMB_PASSWORD\s*='
}

function ConvertTo-BashSingleQuoted([string]$s) {
    if ($null -eq $s) { return "''" }
    return "'" + ($s -replace "'", "'\''") + "'"
}

function Write-SmbPasswordLine([string]$password) {
    $line = "SMB_PASSWORD=" + (ConvertTo-BashSingleQuoted $password)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($F, "$line`n", $utf8NoBom)
}

if (-not $Force -and (Test-PasswordLineOk)) {
    Write-Host "Already exists (unchanged): $F"
    exit 0
}

New-Item -ItemType Directory -Force -Path (Split-Path $F) | Out-Null

Write-Host "Enter your Windows account password (for SMB share access from VM)."
Write-Host "This is the password you use to log into Windows."
Write-Host ""
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
Write-SmbPasswordLine $p1
Write-Host "Wrote $F"
Write-Host "This password will be used for SMB authentication from the VM."
