# Applies the TLS 1.1/1.2 backport to Qt 4.7.4 sources.
#
# Usage (from any location):
#   powershell -ExecutionPolicy Bypass -File diff\apply_combined_tls.ps1
#
# The script assumes this file sits next to combined_tls.patch under diff/.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-Tool($name) {
  return $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

$scriptDir = Split-Path -LiteralPath $MyInvocation.MyCommand.Path -Parent
$repoRoot  = Split-Path -LiteralPath $scriptDir -Parent
$patchFile = Join-Path -LiteralPath $scriptDir 'combined_tls.patch'

if (-not (Test-Path -LiteralPath $patchFile)) {
  throw "Patch file not found: $patchFile"
}

Write-Host "Applying combined patch:" -ForegroundColor Cyan
Write-Host "  $patchFile" -ForegroundColor Cyan
Write-Host "Repository root:" $repoRoot -ForegroundColor Cyan

Push-Location $repoRoot
try {
  if (Test-Tool 'patch') {
    Write-Host "Using 'patch' to apply..." -ForegroundColor Green
    & patch -p1 -i $patchFile
    if ($LASTEXITCODE -ne 0) { throw "patch exited with code $LASTEXITCODE" }
    Write-Host "Patch applied successfully via 'patch'." -ForegroundColor Green
  }
  elseif (Test-Tool 'git') {
    Write-Host "'patch' not found; trying 'git apply'..." -ForegroundColor Yellow
    & git apply --reject --whitespace=fix --directory=. $patchFile
    if ($LASTEXITCODE -ne 0) { throw "git apply exited with code $LASTEXITCODE" }
    Write-Host "Patch applied successfully via 'git apply'." -ForegroundColor Green
  }
  else {
    throw "Neither 'patch' nor 'git' found on PATH. Install Git for Windows or GNU patch and retry."
  }
}
finally {
  Pop-Location
}

Write-Host "Done." -ForegroundColor Cyan

