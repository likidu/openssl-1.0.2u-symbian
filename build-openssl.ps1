<#
.SYNOPSIS
    Build OpenSSL static libraries and wrap them into Qt-friendly DLLs.

.DESCRIPTION
    Runs the `mingw32-make` build described in README.md and then wraps the
    resulting static libraries into `out\libeay32.dll` and `out\ssleay32.dll`.

.PARAMETER MinGWBinPath
    Optional path to a MinGW `bin` directory to prepend to PATH for this run.
    If omitted, the current PATH is used as-is.

.PARAMETER Jobs
    Overrides the number of parallel jobs passed to `mingw32-make`. Defaults to
    the number of logical processors.

.EXAMPLE
    .\build-openssl.ps1

.EXAMPLE
    .\build-openssl.ps1 -MinGWBinPath 'C:\Symbian\QtSDK\mingw\bin' -Jobs 8
#>

param(
    [string]$MinGWBinPath,
    [int]$Jobs = [Environment]::ProcessorCount
)

function Write-Info { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Step { param([string]$Message) Write-Host "[STEP] $Message" -ForegroundColor Yellow }
function Write-Success { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "[WARN] $Message" -ForegroundColor DarkYellow }
function Write-ErrorMessage { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$originalPath = $null
$locationPushed = $false
try {
    if ($MinGWBinPath) {
        if (-not (Test-Path -Path $MinGWBinPath)) {
            throw "Provided MinGW bin path '$MinGWBinPath' does not exist."
        }
        $originalPath = $env:PATH
        $env:PATH = "${MinGWBinPath};$env:PATH"
        Write-Info "Prepended MinGW path '$MinGWBinPath' to PATH."
    }

    $repoRoot = Split-Path -Path $PSCommandPath -Parent
    Push-Location $repoRoot
    $locationPushed = $true
    Write-Info "Working directory: $repoRoot"

    if ($Jobs -lt 1) {
        $Jobs = 1
        Write-Warn "Jobs parameter must be at least 1. Using 1 instead."
    }

    $makeArgs = @('-f', 'ms/mingw32a.mak')
    if ($Jobs -gt 1) {
        $makeArgs += "-j$Jobs"
    }

    Write-Step ("Running mingw32-make {0}" -f ($makeArgs -join ' '))
    & mingw32-make @makeArgs
    if ($LASTEXITCODE -ne 0) {
        throw "mingw32-make failed with exit code $LASTEXITCODE"
    }

    if (-not (Test-Path -Path 'out')) {
        New-Item -ItemType Directory -Path 'out' | Out-Null
    }

    $dllwrapSteps = @(
        @{ Name = 'libeay32'; Args = @('--verbose', '--dllname', 'libeay32.dll', '--output-lib', 'out/libeay32.a', '--def', 'ms/libeay32.def', 'out/libcrypto.a', '-lws2_32', '-lgdi32', '-o', 'out/libeay32.dll') },
        @{ Name = 'ssleay32'; Args = @('--verbose', '--dllname', 'ssleay32.dll', '--output-lib', 'out/libssleay32.a', '--def', 'ms/ssleay32.def', 'out/libssl.a', 'out/libeay32.a', '-o', 'out/ssleay32.dll') }
    )

    foreach ($step in $dllwrapSteps) {
        Write-Step "Wrapping $($step.Name).dll"
        & dllwrap @($step.Args)
        if ($LASTEXITCODE -ne 0) {
            throw "dllwrap for $($step.Name) failed with exit code $LASTEXITCODE"
        }
    }

    Write-Success "Build and wrapping completed successfully."
}
catch {
    Write-ErrorMessage $_.Exception.Message
    throw
}
finally {
    if ($originalPath -ne $null) {
        $env:PATH = $originalPath
        Write-Info "PATH restored."
    }
    if ($locationPushed) {
        Pop-Location -ErrorAction SilentlyContinue | Out-Null
    }
}
