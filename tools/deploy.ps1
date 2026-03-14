<#
.SYNOPSIS
    Uploads game builds to Steam via SteamCMD.

.DESCRIPTION
    Pushes the built game to Steamworks using the VDF configuration files
    in tools/steam/. Requires SteamCMD to be installed and on PATH (or
    specify via -SteamCmdExe).

.PARAMETER Username
    Your Steamworks partner account username. Required.

.PARAMETER SteamCmdExe
    Path to steamcmd.exe. Defaults to 'steamcmd' (assumes on PATH).

.PARAMETER Description
    Build description shown in Steamworks. Defaults to timestamp.

.EXAMPLE
    .\deploy.ps1 -Username mysteamaccount
    .\deploy.ps1 -Username mysteamaccount -Description "Playtest v0.1.0"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Username,

    [string]$SteamCmdExe = "steamcmd",

    [string]$Description = ""
)

$ErrorActionPreference = 'Stop'

$projectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$buildRoot = Join-Path $projectPath "build"
$steamDir = Join-Path $PSScriptRoot "steam"
$appBuildVdf = Join-Path $steamDir "app_build.vdf"

# --- Validate prerequisites ---
if (!(Test-Path $appBuildVdf)) {
    Write-Error "SteamCMD app build VDF not found: $appBuildVdf"
    exit 1
}

# Verify at least one build directory has content
$hasBuilds = $false
foreach ($dir in @("windows", "linux", "macos")) {
    $dirPath = Join-Path $buildRoot $dir
    if ((Test-Path $dirPath) -and (Get-ChildItem $dirPath).Count -gt 0) {
        $hasBuilds = $true
        Write-Output "Found build: $dir"
    } else {
        Write-Warning "No build found for $dir -- depot will be empty"
    }
}

if (-not $hasBuilds) {
    Write-Error "No builds found in $buildRoot. Run tools\build.ps1 first."
    exit 1
}

# --- Generate build description ---
if ([string]::IsNullOrWhiteSpace($Description)) {
    $Description = "Build $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
}
Write-Output "Build description: $Description"

# --- Create temp deploy directory with absolute paths ---
$tempDir = Join-Path $env:TEMP "scsg_deploy"
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir | Out-Null

$q = [char]34

# Copy and patch app_build.vdf -- make buildoutput absolute
$vdfLines = Get-Content $appBuildVdf
$buildOutput = Join-Path $buildRoot "steam_output"
$updatedLines = foreach ($line in $vdfLines) {
    if ($line -match '^\s+"desc"') {
        "`t${q}desc${q}`t`t${q}${Description}${q}"
    } elseif ($line -match '^\s+"buildoutput"') {
        "`t${q}buildoutput${q}`t${q}${buildOutput}${q}"
    } else {
        $line
    }
}
$tempVdf = Join-Path $tempDir "app_build.vdf"
$updatedLines | Set-Content -Path $tempVdf

# Copy and patch depot VDFs -- make contentroot absolute
foreach ($depotFile in @("depot_build_windows.vdf", "depot_build_linux.vdf", "depot_build_macos.vdf")) {
    $srcPath = Join-Path $steamDir $depotFile
    if (Test-Path $srcPath) {
        $depotLines = Get-Content $srcPath
        $patchedLines = foreach ($dline in $depotLines) {
            if ($dline -match '^\s+"contentroot"') {
                # Extract platform from filename (depot_build_PLATFORM.vdf)
                $platform = $depotFile -replace 'depot_build_', '' -replace '\.vdf$', ''
                $absContent = Join-Path $buildRoot $platform
                "`t${q}contentroot${q}`t${q}${absContent}${q}"
            } else {
                $dline
            }
        }
        $patchedLines | Set-Content -Path (Join-Path $tempDir $depotFile)
    }
}

# --- Run SteamCMD ---
Write-Output ""
Write-Output "=== Uploading to Steam ==="
Write-Output "Using VDF: $tempVdf"
Write-Output "Account: $Username"
Write-Output ""

try {
    $steamOutput = & $SteamCmdExe +login $Username +run_app_build $tempVdf +quit 2>&1
    $exitCode = $LASTEXITCODE
    $steamOutput | ForEach-Object { Write-Output $_ }
} catch {
    Write-Error "SteamCMD failed to execute. Is it installed and on PATH?"
    Write-Error $_.Exception.Message
    exit 1
}

# --- Cleanup ---
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}

if ($exitCode -ne 0) {
    Write-Error "SteamCMD exited with code $exitCode"
    exit $exitCode
}

# --- Extract BuildID and save to release_state.json ---
$buildId = ""
foreach ($line in $steamOutput) {
    if ($line -match 'Successfully finished AppID \d+ build \(BuildID (\d+)\)') {
        $buildId = $Matches[1]
        break
    }
}

$stateFile = Join-Path $PSScriptRoot "release_state.json"
if ((Test-Path $stateFile) -and $buildId) {
    $state = Get-Content $stateFile -Raw | ConvertFrom-Json
    $state.last_build_id = $buildId
    $state | ConvertTo-Json -Depth 3 | Set-Content -Path $stateFile -Encoding UTF8
    Write-Output "Updated release_state.json with BuildID $buildId"
}

Write-Output ""
Write-Output "=== Upload Complete ==="
Write-Output "Build has been uploaded to Steamworks."
if ($buildId) { Write-Output "BuildID: $buildId" }
Write-Output ""
Write-Output "Next steps:"
Write-Output "  1. Go to https://partner.steamgames.com/apps/builds/4502490"
Write-Output "  2. Find the uploaded build and set it live for the playtest branch"
Write-Output "  3. Test by requesting access to the playtest as a tester account"
exit 0