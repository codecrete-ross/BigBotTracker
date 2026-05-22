$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$tocPath = Join-Path $projectRoot "BigBotTracker.toc"

if (-not (Test-Path $tocPath)) {
    throw "Missing BigBotTracker.toc"
}

$toc = Get-Content -Path $tocPath
$interfaceLine = $toc | Where-Object { $_ -match '^## Interface:' } | Select-Object -First 1
$requiredInterfaces = @("120005", "50503", "40402", "38001", "30405", "20505", "11508")
foreach ($interface in $requiredInterfaces) {
    if ($interfaceLine -notmatch "(^|[\s,])$interface($|[\s,])") {
        throw "TOC Interface is missing target client version: $interface"
    }
}

$luaFiles = $toc | Where-Object { $_ -match '\.lua$' }
$utilIndex = [array]::IndexOf($luaFiles, "Util.lua")
$compatIndex = [array]::IndexOf($luaFiles, "Compat.lua")
if ($compatIndex -lt 0) {
    throw "TOC is missing Compat.lua"
}
if ($compatIndex -ne ($utilIndex + 1)) {
    throw "Compat.lua must load immediately after Util.lua"
}

foreach ($file in $luaFiles) {
    $path = Join-Path $projectRoot $file
    if (-not (Test-Path $path)) {
        throw "TOC references missing file: $file"
    }
}

$deployScript = Get-Content -Path (Join-Path $projectRoot "scripts\deploy.ps1") -Raw
foreach ($file in $luaFiles) {
    if ($deployScript -notmatch [regex]::Escape('"' + $file + '"')) {
        throw "Deploy script does not copy TOC Lua file: $file"
    }
}

$requiredFiles = @(
    "BigBotTracker.toc",
    "Util.lua",
    "Compat.lua",
    "Normalizer.lua",
    "Scoring.lua",
    "Storage.lua",
    "ChatScanner.lua",
    "Sync.lua",
    "Report.lua",
    "UI.lua",
    "Core.lua",
    ".pkgmeta",
    "scripts\deploy.ps1",
    "README.md",
    "CHANGELOG.md",
    "AGENTS.md"
)

foreach ($file in $requiredFiles) {
    $path = Join-Path $projectRoot $file
    if (-not (Test-Path $path)) {
        throw "Missing required file: $file"
    }
}

$allLua = Get-ChildItem -Path $projectRoot -Filter *.lua
$allLuaText = $allLua | ForEach-Object { Get-Content -Path $_.FullName -Raw }

if ($allLuaText -match "ChatFrame_AddMessageEventFilter") {
    throw "Use event-frame scanning, not ChatFrame_AddMessageEventFilter."
}

if ($allLuaText -match "SendChatMessage\(.*report") {
    throw "Addon must not automate public accusations or reports."
}

$sessionMetricPatterns = @(
    "sessionsSeen",
    "sessionMessages",
    "sessionId",
    "activeSessionPostsPerHour",
    "ClearSessionBuffers",
    "clear session"
)

foreach ($pattern in $sessionMetricPatterns) {
    if ($allLuaText -match [regex]::Escape($pattern)) {
        throw "Session-derived reporting metric is still present: $pattern"
    }
}

$syncLua = Get-Content -Path (Join-Path $projectRoot "Sync.lua") -Raw
$prefixMatch = [regex]::Match($syncLua, 'local PREFIX = "([^"]+)"')
if (-not $prefixMatch.Success) {
    throw "Could not find sync prefix."
}
if ($prefixMatch.Groups[1].Value.Length -gt 16) {
    throw "Sync prefix is longer than 16 characters."
}
if ($syncLua -match "JoinTemporaryChannel" -or $syncLua -match "GetChannelName") {
    throw "Sync must not join or inspect custom chat channels."
}
if ($syncLua -match 'SendAddonMessage\([^)]*"CHANNEL"') {
    throw "Sync must not send addon messages over custom chat channels."
}

$coreLua = Get-Content -Path (Join-Path $projectRoot "Core.lua") -Raw
if ($coreLua -notmatch "function BigBotTracker_OnAddonCompartmentClick") {
    throw "Missing addon compartment function."
}

Write-Host "Static checks passed for BigBotTracker."
