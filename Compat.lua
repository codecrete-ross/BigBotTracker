local addonName, BBT = ...
BBT = BBT or _G.BigBotTracker or {}
_G.BigBotTracker = BBT

BBT.addonName = addonName or BBT.addonName or "BigBotTracker"
BBT.Compat = BBT.Compat or {}

local Compat = BBT.Compat

Compat.FLAVOR_RETAIL = "retail"
Compat.FLAVOR_VANILLA = "vanilla"
Compat.FLAVOR_TBC = "tbc"
Compat.FLAVOR_WRATH = "wrath"
Compat.FLAVOR_TITAN = "titan"
Compat.FLAVOR_CATA = "cata"
Compat.FLAVOR_MISTS = "mists"
Compat.FLAVOR_UNKNOWN = "unknown"

local FLAVOR_LABELS = {
    retail = "Retail",
    vanilla = "Classic Era",
    tbc = "TBC Anniversary",
    wrath = "Wrath Classic",
    titan = "Titan Reforged",
    cata = "Cataclysm Classic",
    mists = "Mists Classic",
    unknown = "Unknown",
}

local PROJECT_MAINLINE = 1
local PROJECT_CLASSIC = 2
local PROJECT_TBC = 5
local PROJECT_WRATH = 11
local PROJECT_CATA = 14
local PROJECT_MISTS = 19

local function getGlobalNumber(name, fallback)
    local value = tonumber(_G[name])
    if value ~= nil then
        return value
    end
    return fallback
end

function Compat.GetBuildInfo()
    if type(GetBuildInfo) ~= "function" then
        return {
            version = nil,
            build = nil,
            date = nil,
            interfaceVersion = nil,
        }
    end

    local ok, version, build, dateValue, interfaceVersion = pcall(GetBuildInfo)
    if not ok then
        return {
            version = nil,
            build = nil,
            date = nil,
            interfaceVersion = nil,
        }
    end

    return {
        version = version,
        build = build,
        date = dateValue,
        interfaceVersion = tonumber(interfaceVersion),
    }
end

function Compat.GetInterfaceVersion()
    return Compat.GetBuildInfo().interfaceVersion
end

function Compat.GetFlavor()
    local buildInfo = Compat.GetBuildInfo()
    local interfaceVersion = tonumber(buildInfo.interfaceVersion) or 0
    local projectId = tonumber(_G.WOW_PROJECT_ID)

    local mainline = getGlobalNumber("WOW_PROJECT_MAINLINE", PROJECT_MAINLINE)
    local classic = getGlobalNumber("WOW_PROJECT_CLASSIC", PROJECT_CLASSIC)
    local tbc = getGlobalNumber("WOW_PROJECT_BURNING_CRUSADE_CLASSIC", PROJECT_TBC)
    local wrath = getGlobalNumber("WOW_PROJECT_WRATH_CLASSIC", PROJECT_WRATH)
    local cata = getGlobalNumber("WOW_PROJECT_CATACLYSM_CLASSIC", PROJECT_CATA)
    local mists = getGlobalNumber("WOW_PROJECT_MISTS_CLASSIC", PROJECT_MISTS)

    if projectId == mainline or interfaceVersion >= 100000 then
        return Compat.FLAVOR_RETAIL
    end
    if projectId == mists or (interfaceVersion >= 50500 and interfaceVersion < 50600) then
        return Compat.FLAVOR_MISTS
    end
    if projectId == cata or (interfaceVersion >= 40400 and interfaceVersion < 40500) then
        return Compat.FLAVOR_CATA
    end
    if projectId == wrath then
        if interfaceVersion >= 38000 and interfaceVersion < 39000 then
            return Compat.FLAVOR_TITAN
        end
        return Compat.FLAVOR_WRATH
    end
    if interfaceVersion >= 38000 and interfaceVersion < 39000 then
        return Compat.FLAVOR_TITAN
    end
    if interfaceVersion >= 30400 and interfaceVersion < 30500 then
        return Compat.FLAVOR_WRATH
    end
    if projectId == tbc or (interfaceVersion >= 20500 and interfaceVersion < 20600) then
        return Compat.FLAVOR_TBC
    end
    if projectId == classic or (interfaceVersion >= 11500 and interfaceVersion < 11600) then
        return Compat.FLAVOR_VANILLA
    end

    return Compat.FLAVOR_UNKNOWN
end

function Compat.GetFlavorLabel(flavor)
    return FLAVOR_LABELS[flavor or Compat.GetFlavor()] or FLAVOR_LABELS.unknown
end

function Compat.GetClientInfo()
    local buildInfo = Compat.GetBuildInfo()
    local flavor = Compat.GetFlavor()
    return {
        flavor = flavor,
        label = Compat.GetFlavorLabel(flavor),
        interfaceVersion = buildInfo.interfaceVersion,
        version = buildInfo.version,
        build = buildInfo.build,
        date = buildInfo.date,
    }
end

function Compat.IsRetail()
    return Compat.GetFlavor() == Compat.FLAVOR_RETAIL
end

function Compat.IsClassic()
    local flavor = Compat.GetFlavor()
    return flavor == Compat.FLAVOR_VANILLA
        or flavor == Compat.FLAVOR_TBC
        or flavor == Compat.FLAVOR_WRATH
        or flavor == Compat.FLAVOR_TITAN
        or flavor == Compat.FLAVOR_CATA
        or flavor == Compat.FLAVOR_MISTS
end

local DEFAULT_TEMPLATE_FALLBACKS = {
    BasicFrameTemplateWithInset = { "BasicFrameTemplate" },
    UIPanelButtonTemplate = {},
    UIPanelScrollFrameTemplate = {},
}

local function appendTemplate(candidates, seen, template)
    if template == nil or template == "" or seen[template] then
        return
    end
    seen[template] = true
    candidates[#candidates + 1] = template
end

local function appendFallbacks(candidates, seen, fallbacks)
    if type(fallbacks) ~= "table" then
        return
    end
    for _, template in ipairs(fallbacks) do
        appendTemplate(candidates, seen, template)
    end
end

function Compat.CreateFrame(frameType, name, parent, template, fallbackTemplates)
    if type(CreateFrame) ~= "function" then
        return nil
    end

    local candidates = {}
    local seen = {}
    appendTemplate(candidates, seen, template)
    appendFallbacks(candidates, seen, fallbackTemplates)
    appendFallbacks(candidates, seen, DEFAULT_TEMPLATE_FALLBACKS[template])

    for _, candidateTemplate in ipairs(candidates) do
        local ok, frame = pcall(CreateFrame, frameType, name, parent, candidateTemplate)
        if ok and frame then
            return frame
        end
    end

    local ok, frame = pcall(CreateFrame, frameType, name, parent)
    if ok then
        return frame
    end
    return nil
end
