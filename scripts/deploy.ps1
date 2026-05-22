param(
    [string]$WoWAddOnsRoot = "G:\Battle.net Games\World of Warcraft\_retail_\Interface\AddOns"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$addonName = "BigBotTracker"
$destination = Join-Path $WoWAddOnsRoot $addonName

$filesToCopy = @(
    "BigBotTracker.toc",
    "Util.lua",
    "Normalizer.lua",
    "Scoring.lua",
    "Storage.lua",
    "ChatScanner.lua",
    "Sync.lua",
    "Report.lua",
    "UI.lua",
    "Core.lua",
    "logo.tga"
)

New-Item -ItemType Directory -Force -Path $destination | Out-Null

foreach ($file in $filesToCopy) {
    $source = Join-Path $projectRoot $file
    if (Test-Path $source) {
        Copy-Item -LiteralPath $source -Destination $destination -Force
    }
}

Write-Host "Deployed $addonName to $destination"
