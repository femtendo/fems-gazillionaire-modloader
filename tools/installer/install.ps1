# Installer/patcher for the Gazillionaire mod build, Windows edition.
# Mirrors tools/installer/install.sh (bash/macOS+Linux) — same manifest
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

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Resolve-Path (Join-Path $ScriptDir "..\..")
$Manifest = Join-Path $RootDir "engine\engine.manifest.json"
$BuiltSwf = Join-Path $RootDir "build\output\gazillionaire-modded.swf"

# Windows AIR captive-runtime installs put the SWF directly alongside the
# .exe (no Resources/ bundle like the macOS .app), under the Steam library
# — unverified against a real Windows install (no Windows machine
# available in this environment); pass -Target explicitly if this guess is
# wrong for your Steam library location.
if (-not $Target) {
    $Target = Join-Path ${env:ProgramFiles(x86)} "Steam\steamapps\common\Gazillionaire\Gazillionaire.swf"
}

function Get-Sha256($path) {
    return (Get-FileHash -Path $path -Algorithm SHA256).Hash.ToLower()
}

function Read-ManifestHash {
    $manifestJson = Get-Content -Raw -Path $Manifest | ConvertFrom-Json
    return $manifestJson.officialSwfSha256.ToLower()
}

$Backup = "$Target.original-backup"
$LooseAssetsDir = Join-Path $RootDir "build\output\loose-assets"
$LooseAssetsManifest = Join-Path $LooseAssetsDir "manifest.json"
$ResourcesDir = Split-Path -Parent $Target

function Install-LooseAssets {
    if (-not (Test-Path $LooseAssetsManifest)) { return }
    # @(...) forces an array even when the JSON has exactly one element —
    # Windows PowerShell 5.1's ConvertFrom-Json otherwise collapses a
    # single-element array to a scalar and silently skips the foreach body.
    $paths = @(Get-Content -Raw -Path $LooseAssetsManifest | ConvertFrom-Json)
    foreach ($rel in $paths) {
        $dest = Join-Path $ResourcesDir $rel
        $destBackup = "$dest.original-backup"
        if (-not (Test-Path $dest)) {
            Write-Warning "Loose asset target not found, skipping: $dest"
            continue
        }
        if (Test-Path $destBackup) {
            Write-Error "Loose-asset backup already exists at $destBackup — refusing to overwrite it."
            exit 1
        }
        Copy-Item $dest $destBackup
        Copy-Item (Join-Path $LooseAssetsDir $rel) $dest -Force
    }
}

function Restore-LooseAssets {
    if (Test-Path $LooseAssetsManifest) {
        $paths = @(Get-Content -Raw -Path $LooseAssetsManifest | ConvertFrom-Json)
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
            Write-Error "No built SWF at $BuiltSwf — run tools/modloader/build.js first"
            exit 1
        }

        $expectedHash = Read-ManifestHash
        $actualHash = Get-Sha256 $Target
        if ($actualHash -ne $expectedHash) {
            Write-Error "Hash mismatch — refusing to patch.`n  expected: $expectedHash`n  actual:   $actualHash"
            exit 1
        }

        if (Test-Path $Backup) {
            Write-Error "Backup already exists at $Backup — refusing to overwrite it. (If you want to re-install from a clean state, restore first.)"
            exit 1
        }

        Copy-Item $Target $Backup
        Copy-Item $BuiltSwf $Target -Force
        Install-LooseAssets
        Write-Host "Installed. Original backed up to $Backup"
    }

    "restore" {
        if (-not (Test-Path $Backup)) {
            Write-Error "No backup found at $Backup — nothing to restore."
            exit 1
        }

        $expectedHash = Read-ManifestHash
        $backupHash = Get-Sha256 $Backup
        if ($backupHash -ne $expectedHash) {
            Write-Error "Backup hash does not match the known-good manifest hash — refusing to restore a corrupt backup.`n  expected: $expectedHash`n  backup:   $backupHash"
            exit 1
        }

        Copy-Item $Backup $Target -Force
        Remove-Item $Backup
        Restore-LooseAssets
        Write-Host "Restored original SWF to $Target and removed the backup."
    }
}
