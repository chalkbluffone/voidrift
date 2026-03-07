---
applyTo: "globals/steam_manager.gd,tools/build.ps1,tools/deploy.ps1,tools/steam/**"
---

# Steam — Build, Deploy & Integration

## Overview

The game ships as a **confidential Steam playtest** (App ID `4502490`). Three platform depots are uploaded via SteamCMD. GodotSteam GDExtension provides optional Steam overlay/achievements integration.

## Steamworks IDs

| Resource        | ID                |
| --------------- | ----------------- |
| Playtest App    | `4502490`         |
| Windows Depot   | `4502491`         |
| Linux Depot     | `4502492`         |
| macOS Depot     | `4502493`         |
| Partner Account | `chalkbluffmedia` |

## SteamManager Autoload (`globals/steam_manager.gd`)

- Autoload #12, loaded after `SettingsManager`
- Uses `Engine.has_singleton("Steam")` / `Engine.get_singleton("Steam")` for dynamic access
- All Steam API calls go through `_steam.call("method_name")` to avoid parse errors when GodotSteam addon is absent
- Gracefully degrades — game runs without Steam integration when addon is not installed
- Calls `run_callbacks()` every frame when active

### GodotSteam GDExtension (Not Yet Installed)

When ready to add Steam overlay/achievements:

1. Download GodotSteam GDExtension from GitHub
2. Place in `addons/godotsteam/`
3. Copy Steam redistributable libs (`steam_api64.dll`, `libsteam_api.so`) to project root
4. `steam_manager.gd` will automatically detect and initialize

## Build Pipeline (`tools/build.ps1`)

### Usage

```powershell
.\tools\build.ps1                           # All platforms
.\tools\build.ps1 -PlatformsToExport Windows  # Single platform
```

### What It Does

1. Validates Godot executable exists
2. Runs headless sanity check (must pass)
3. Exports via `--headless --export-release` for each platform
4. Copies `steam_appid.txt` alongside binaries (for dev testing)
5. Reports build sizes

### Output Structure

```
build/
  windows/    SuperCoolSpaceGame.exe + .pck
  linux/      SuperCoolSpaceGame.x86_64 + .pck
  macos/      SuperCoolSpaceGame.zip (.app bundle)
  steam_output/   SteamCMD build logs
```

### Export Presets

Export presets are configured in the Godot Editor (not version-controlled in `export_presets.cfg`):

| Preset            | Notes                                                                |
| ----------------- | -------------------------------------------------------------------- |
| "Windows Desktop" | Default settings                                                     |
| "Linux"           | Default settings                                                     |
| "macOS"           | Bundle ID: `com.chalkbluffone.supercoolspacegame`, ETC2 ASTC enabled |

### macOS Requirements

- `textures/vram_compression/import_etc2_astc=true` in `project.godot` `[rendering]` section for ARM64/universal builds
- Bundle identifier must be set in export preset

## Deploy Pipeline (`tools/deploy.ps1`)

### Usage

```powershell
.\tools\deploy.ps1 -Username chalkbluffmedia -SteamCmdExe "F:\SteamCMD\steamcmd.exe"
.\tools\deploy.ps1 -Username chalkbluffmedia -Description "Playtest v0.1.0"
```

### What It Does

1. Validates builds exist in `build/`
2. Creates temp directory with patched VDFs (absolute paths for `buildoutput` and `contentroot`)
3. Updates build description in app VDF
4. Copies and patches all depot VDFs alongside app VDF
5. Runs SteamCMD with `+login` and `+run_app_build`
6. Cleans up temp directory

### SteamCMD Setup

- Installed at `F:\SteamCMD\steamcmd.exe`
- First login requires interactive password + Steam Guard code
- After first auth, credentials are cached for subsequent deploys

## VDF Configuration (`tools/steam/`)

| File                      | Purpose                            |
| ------------------------- | ---------------------------------- |
| `app_build.vdf`           | Master build config (app + depots) |
| `depot_build_windows.vdf` | Windows depot → `build/windows/`   |
| `depot_build_linux.vdf`   | Linux depot → `build/linux/`       |
| `depot_build_macos.vdf`   | macOS depot → `build/macos/`       |

All depot VDFs exclude `steam_appid.txt` via `FileExclusion`.

## VS Code Tasks

| Task                  | Command                                                                              |
| --------------------- | ------------------------------------------------------------------------------------ |
| Build All Platforms   | `tools/build.ps1`                                                                    |
| Build Windows Only    | `tools/build.ps1 -PlatformsToExport Windows`                                         |
| Deploy to Steamworks  | `tools/deploy.ps1 -Username chalkbluffmedia -SteamCmdExe "F:\SteamCMD\steamcmd.exe"` |
| Headless Sanity Check | `tools/headless_sanity_check.ps1`                                                    |

The deploy VS Code task includes `-Username` and `-SteamCmdExe` so it runs without manual prompts. SteamCMD is NOT on PATH — always specify the full path via `-SteamCmdExe`.

## Post-Deploy Checklist

1. Go to Steamworks → App Admin → SteamPipe → Builds
2. Find the uploaded build by BuildID
3. Set it live on the target branch (e.g., `default`)
4. Testers with access see the update in their Steam library

## PowerShell 5.1 Gotchas

- Use `[char]34` for embedded double quotes instead of escaped `\"` in regex/replace operations
- Non-ASCII characters (em-dashes, etc.) require UTF-8 BOM encoding in `.ps1` files
- `Start-Process -ArgumentList` splits on spaces — use backtick-escaped quotes for preset names with spaces: ``"`"Windows Desktop`""``

## .gitignore Entries

```
build/
steam_appid.txt
steam_api64.dll
libsteam_api.so
libsteam_api.dylib
build/steam_output/
```
