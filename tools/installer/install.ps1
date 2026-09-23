# Installer/patcher for the Gazillionaire mod build, Windows edition.
# Mirrors tools/installer/install.sh (bash/macOS+Linux) - same manifest
# hash-verify + backup/restore contract, minus the macOS-only code-signing
# and Info.plist/application.xml steps, which have no Windows equivalent
# (Windows AIR captive-runtime builds aren't code-signed the same way and
# don't hit the <visible> handshake bug documented in install.sh).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File install.ps1 install [-Target <path>]
#   powershell -ExecutionPolicy Bypass -File install.ps1 restore [-Target <path>]

param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet("install", "restore")]
    [string]$Command,

    [string]$Target
)

$ErrorActionPreference = "Stop"

# Bumped every time this file changes, and always printed first. If a bug
# report doesn't match the version printed here, the fix already exists
# but the report is from a stale copy of this script - re-download rather
# than debug further.
$ScriptVersion = "2026-09-23.3"
Write-Host "install.ps1 version $ScriptVersion"

$ScriptDir = [string](Split-Path -Parent $MyInvocation.MyCommand.Path)
if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
    Write-Error "Could not determine this script's own folder (PowerShell gave back an empty path for `$MyInvocation.MyCommand.Path). Try running it by its full path instead of a relative one, e.g.: powershell -ExecutionPolicy Bypass -File `"C:\full\path\to\install.ps1`" $Command"
    exit 1
}
# Explicit [string] casts throughout this section: Resolve-Path returns a
# PathInfo object, not a plain string, and relying on it auto-converting
# everywhere it's later used (string interpolation, Join-Path, Test-Path)
# is a well-known PowerShell foot-gun - forcing it to a real string once,
# right here, removes an entire category of "which cmdlet's implicit
# conversion behaves differently on this PowerShell version" uncertainty.
$RootDir = [string](Resolve-Path (Join-Path $ScriptDir "..\.."))
$Manifest = [string](Join-Path $RootDir "engine\engine.manifest.json")
$BuiltSwf = [string](Join-Path $RootDir "build\output\gazillionaire-modded.swf")

# Windows AIR captive-runtime installs put the SWF directly alongside the
# .exe (no Resources/ bundle like the macOS .app), under the Steam library
# - unverified against a real Windows install (no Windows machine
# available in this environment); pass -Target explicitly if this guess is
# wrong for your Steam library location.
if (-not $Target) {
    # ${env:ProgramFiles(x86)} has been observed to come back empty on a
    # real Windows machine (likely running powershell.exe as a 32-bit
    # process, where that variable isn't populated the same way) -
    # Join-Path then throws instead of just producing a wrong path. Fall
    # back to the standard literal, which is right far more often than the
    # env var lookup fails.
    $programFilesX86 = [string](${env:ProgramFiles(x86)})
    if ([string]::IsNullOrWhiteSpace($programFilesX86)) {
        $programFilesX86 = "C:\Program Files (x86)"
    }
    $Target = [string](Join-Path $programFilesX86 "Steam\steamapps\common\Gazillionaire\Gazillionaire.swf")
}
$Target = [string]$Target

# Diagnostic trace: if a Join-Path/Resolve-Path call still fails somewhere
# below despite the casts above, this prints BEFORE that happens, so a bug
# report includes the actual type/value of every path this script derived
# instead of just a bare exception with no context.
Write-Host "ScriptDir=[$ScriptDir] ($($ScriptDir.GetType().Name))"
Write-Host "RootDir=[$RootDir] ($($RootDir.GetType().Name))"
Write-Host "Manifest=[$Manifest] ($($Manifest.GetType().Name))"
Write-Host "BuiltSwf=[$BuiltSwf] ($($BuiltSwf.GetType().Name))"
Write-Host "Target=[$Target] ($($Target.GetType().Name))"

function Get-Sha256($path) {
    return (Get-FileHash -Path $path -Algorithm SHA256).Hash.ToLower()
}

function Read-ManifestHash {
    $manifestJson = Get-Content -Raw -Path $Manifest | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace($manifestJson.officialSwfSha256)) {
        Write-Error "officialSwfSha256 missing from $Manifest - repo/build is corrupt or out of date."
        exit 1
    }
    return $manifestJson.officialSwfSha256.ToLower()
}

$Backup = "$Target.original-backup"
$LooseAssetsDir = [string](Join-Path $RootDir "build\output\loose-assets")
$LooseAssetsManifest = [string](Join-Path $LooseAssetsDir "manifest.json")
$ResourcesDir = [string](Split-Path -Parent $Target)

function Install-LooseAssets {
    if (-not (Test-Path $LooseAssetsManifest)) { return }
    # @(...) forces an array even when the JSON has exactly one element -
    # Windows PowerShell 5.1's ConvertFrom-Json otherwise collapses a
    # single-element array to a scalar and silently skips the foreach
    # body. But ConvertFrom-Json on an EMPTY array "[]" returns $null, not
    # an empty array, and @($null) is a *one-element* array containing
    # $null (not zero elements) - Where-Object strips that out so a
    # build with no loose-asset overrides (an empty manifest, the common
    # case) doesn't crash on Join-Path $ResourcesDir $null.
    # The @(...) must wrap the WHOLE pipeline, not just ConvertFrom-Json's
    # output - piping a single surviving element through Where-Object and
    # assigning THAT result would collapse back to a scalar the same way,
    # just one step later.
    $paths = @(Get-Content -Raw -Path $LooseAssetsManifest | ConvertFrom-Json | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    foreach ($rel in $paths) {
        $dest = Join-Path $ResourcesDir $rel
        $destBackup = "$dest.original-backup"
        if (-not (Test-Path $dest)) {
            Write-Warning "Loose asset target not found, skipping: $dest"
            continue
        }
        if (Test-Path $destBackup) {
            Write-Error "Loose-asset backup already exists at $destBackup - refusing to overwrite it."
            exit 1
        }
        Copy-Item $dest $destBackup
        Copy-Item (Join-Path $LooseAssetsDir $rel) $dest -Force
    }
}

function Restore-LooseAssets {
    if (Test-Path $LooseAssetsManifest) {
        $paths = @(Get-Content -Raw -Path $LooseAssetsManifest | ConvertFrom-Json | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        foreach ($rel in $paths) {
            $dest = Join-Path $ResourcesDir $rel
            $destBackup = "$dest.original-backup"
            if (Test-Path $destBackup) {
                Copy-Item $destBackup $dest -Force
                Remove-Item $destBackup
            }
        }
    }

    # Same orphan sweep as install.sh's restore_loose_assets: the current
    # build's manifest reflects the mod set enabled *now*, which can differ
    # from what was actually installed, so sweep the target folders
    # directly for any leftover *.original-backup files.
    foreach ($sub in @("SWF", "PNG", "MP3")) {
        $dir = Join-Path $ResourcesDir $sub
        if (-not (Test-Path $dir)) { continue }
        Get-ChildItem -Path $dir -Filter "*.original-backup" -File | ForEach-Object {
            $dest = $_.FullName.Substring(0, $_.FullName.Length - ".original-backup".Length)
            Copy-Item $_.FullName $dest -Force
            Remove-Item $_.FullName
        }
    }
}

switch ($Command) {
    "install" {
        if (-not (Test-Path $Target)) {
            Write-Error "Target SWF not found: $Target"
            exit 1
        }
        if (-not (Test-Path $BuiltSwf)) {
            Write-Error "No built SWF at $BuiltSwf - run tools/modloader/build.js first"
            exit 1
        }

        $expectedHash = Read-ManifestHash
        $actualHash = Get-Sha256 $Target
        if ($actualHash -ne $expectedHash) {
            Write-Error "Hash mismatch - refusing to patch.`n  expected: $expectedHash`n  actual:   $actualHash"
            exit 1
        }

        if (Test-Path $Backup) {
            Write-Error "Backup already exists at $Backup - refusing to overwrite it. (If you want to re-install from a clean state, restore first.)"
            exit 1
        }

        Copy-Item $Target $Backup
        Copy-Item $BuiltSwf $Target -Force
        Install-LooseAssets
        Write-Host "Installed. Original backed up to $Backup"
    }

    "restore" {
        if (-not (Test-Path $Backup)) {
            Write-Error "No backup found at $Backup - nothing to restore."
            exit 1
        }

        $expectedHash = Read-ManifestHash
        $backupHash = Get-Sha256 $Backup
        if ($backupHash -ne $expectedHash) {
            Write-Error "Backup hash does not match the known-good manifest hash - refusing to restore a corrupt backup.`n  expected: $expectedHash`n  backup:   $backupHash"
            exit 1
        }

        Copy-Item $Backup $Target -Force
        Remove-Item $Backup
        Restore-LooseAssets
        Write-Host "Restored original SWF to $Target and removed the backup."
    }
}
