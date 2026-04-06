# Stop or remove the Hyper-V sandbox VM. See host\stop-vm-windows.ps1
$RepoRoot = $PSScriptRoot
& (Join-Path $RepoRoot "host\stop-vm-windows.ps1") @args
exit $LASTEXITCODE
