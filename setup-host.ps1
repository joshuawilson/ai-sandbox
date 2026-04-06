# Only host-setup entry point at repo root; other host scripts live under host/
$RepoRoot = $PSScriptRoot
$Name = Split-Path -Leaf $PSCommandPath
& (Join-Path $RepoRoot "host\$Name") @args
exit $LASTEXITCODE
