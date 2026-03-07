<#
.SYNOPSIS
    Builds Super Cool Space Game for all platforms (Windows, Linux, macOS).

.DESCRIPTION
    Runs a headless sanity check, then exports the game using Godot's CLI
    for each configured export preset. Copies Steam redistributable files
    alongside each platform's binary.

.PARAMETER GodotExe
    Path to the Godot 4.6 editor executable. Defaults to standard local path.

.PARAMETER SkipSanityCheck
    Skip the headless import sanity check before building.

.PARAMETER Platform
    Build only a specific platform: Windows, Linux, macOS, or All (default).

.EXAMPLE
    .\build.ps1
    .\build.ps1 -Platform Windows
    .\build.ps1 -SkipSanityCheck
#>
param(
    [string]$GodotExe = "C:\git\godot\Godot_v4.6-stable_win64\Godot_v4.6-stable_win64.exe",
    [switch]$SkipSanityCheck,
    [ValidateSet("All", "Windows", "Linux", "macOS")]
    [string]$Platform = "All"
)

$ErrorActionPreference = 'Stop'

$projectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$buildRoot = Join-Path $projectPath "build"

# --- Export preset names (must match names in export_presets.cfg) ---
$presets = @{
    Windows = @{
        Preset = "Windows Desktop"
        Output = "windows\SuperCoolSpaceGame.exe"
        SteamLib = "steam_api64.dll"
    }
    Linux = @{
        Preset = "Linux"
        Output = "linux/SuperCoolSpaceGame.x86_64"
        SteamLib = "libsteam_api.so"
    }
    macOS = @{
        Preset = "macOS"
        Output = "macos/SuperCoolSpaceGame.zip"
        SteamLib = $null  # macOS Steam lib goes inside the .app bundle
    }
}

# --- Validate Godot executable ---
if (!(Test-Path $GodotExe)) {
    Write-Error "Godot executable not found: $GodotExe"
    exit 1
}

# --- Sanity check ---
if (-not $SkipSanityCheck) {
    Write-Output "=== Running headless sanity check ==="
    $sanityScript = Join-Path $PSScriptRoot "headless_sanity_check.ps1"
    & $sanityScript
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Sanity check failed. Fix errors before building."
        exit 1
    }
    Write-Output ""
}

# --- Determine which platforms to build ---
$targetPlatforms = if ($Platform -eq "All") { $presets.Keys } else { @($Platform) }

# --- Clean and create build directories ---
foreach ($plat in $targetPlatforms) {
    $outputPath = Join-Path $buildRoot $presets[$plat].Output
    $outputDir = Split-Path $outputPath -Parent
    if (Test-Path $outputDir) {
        Remove-Item $outputDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# --- Export each platform ---
$results = @{}
foreach ($plat in $targetPlatforms) {
    $preset = $presets[$plat]
    $outputPath = Join-Path $buildRoot $preset.Output
    Write-Output "=== Building $plat ($($preset.Preset)) ==="
    Write-Output "  Output: $outputPath"

    $exportArgs = @(
        '--headless',
        '--path', "`"$projectPath`"",
        '--export-release', "`"$($preset.Preset)`"",
        "`"$outputPath`""
    )

    $proc = Start-Process -FilePath $GodotExe -ArgumentList $exportArgs `
        -PassThru -Wait -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $buildRoot "$plat-stdout.log") `
        -RedirectStandardError (Join-Path $buildRoot "$plat-stderr.log")

    if ($proc.ExitCode -ne 0) {
        Write-Warning "  FAILED (exit code $($proc.ExitCode)). Check $buildRoot\$plat-stderr.log"
        $results[$plat] = "FAILED"
        continue
    }

    # Copy Steam redistributable library alongside the binary
    if ($preset.SteamLib) {
        $steamLibSrc = Join-Path $projectPath $preset.SteamLib
        $outputDir = Split-Path $outputPath -Parent
        if (Test-Path $steamLibSrc) {
            Copy-Item $steamLibSrc -Destination $outputDir
            Write-Output "  Copied $($preset.SteamLib)"
        } else {
            Write-Warning "  Steam library not found: $steamLibSrc (build will work without Steam overlay)"
        }
    }

    # Copy steam_appid.txt alongside the binary
    $appIdSrc = Join-Path $projectPath "steam_appid.txt"
    $outputDir = Split-Path $outputPath -Parent
    if (Test-Path $appIdSrc) {
        Copy-Item $appIdSrc -Destination $outputDir
    }

    $results[$plat] = "OK"
    Write-Output "  Success"
    Write-Output ""
}

# --- Summary ---
Write-Output "=== Build Summary ==="
foreach ($plat in $targetPlatforms) {
    $outputPath = Join-Path $buildRoot $presets[$plat].Output
    $status = $results[$plat]
    if ($status -eq "OK" -and (Test-Path $outputPath)) {
        $size = (Get-Item $outputPath).Length
        $sizeMB = [math]::Round($size / 1MB, 2)
        Write-Output "  $plat : $status ($sizeMB MB)"
    } else {
        Write-Output "  $plat : $status"
    }
}

$failCount = ($results.Values | Where-Object { $_ -ne "OK" }).Count
if ($failCount -gt 0) {
    Write-Error "$failCount platform(s) failed to build."
    exit 1
}

Write-Output "`nAll builds completed successfully."
Write-Output "Build output: $buildRoot"
exit 0
