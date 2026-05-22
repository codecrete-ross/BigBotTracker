local addonName, BBT = ...
BBT = BBT or {}
_G.BigBotTracker = BBT

BBT.addonName = addonName or "BigBotTracker"
BBT.Util = BBT.Util or {}

local Util = BBT.Util

BBT.CHAT_PREFIX = "|cff66d9ef[Big Bot Tracker]|r "

function Util.Print(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(BBT.CHAT_PREFIX .. tostring(message))
    elseif print then
        print("[Big Bot Tracker] " .. tostring(message))
    end
end

function Util.Debug(message)
    if BigBotTrackerDB and BigBotTrackerDB.settings and BigBotTrackerDB.settings.debug then
        Util.Print("Debug: " .. tostring(message))
    end
end

function Util.Trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function Util.Clone(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nestedValue in pairs(value) do
        copy[key] = Util.Clone(nestedValue)
    end
    return copy
end

function Util.MergeDefaults(target, defaults)
    if type(target) ~= "table" then
        target = {}
    end

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = Util.MergeDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end

function Util.CountMap(map)
    local count = 0
    if type(map) ~= "table" then
        return count
    end

    for _ in pairs(map) do
        count = count + 1
    end
    return count
end

function Util.PushLimited(list, value, limit)
    if type(list) ~= "table" then
        return
    end

    list[#list + 1] = value
    while limit and #list > limit do
        table.remove(list, 1)
    end
end

function Util.Round(value, places)
    if type(value) ~= "number" then
        return 0
    end

    local factor = 10 ^ (places or 0)
    return math.floor(value * factor + 0.5) / factor
end

function Util.Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function Util.SafeNumber(value, fallback)
    value = tonumber(value)
    if value == nil then
        return fallback or 0
    end
    return value
end

function Util.GetNow()
    if time then
        return time()
    end
    return os.time()
end

function Util.GetDateKey(timestamp)
    timestamp = timestamp or Util.GetNow()
    if date then
        return date("%Y-%m-%d", timestamp)
    end
    return os.date("%Y-%m-%d", timestamp)
end

function Util.GetPlayerRealm()
    if GetNormalizedRealmName then
        local normalized = GetNormalizedRealmName()
        if normalized and normalized ~= "" then
            return normalized
        end
    end

    if GetRealmName then
        local realm = GetRealmName()
        if realm and realm ~= "" then
            return realm:gsub("%s+", "")
        end
    end

    return "UnknownRealm"
end

function Util.GetPlayerFullName()
    if UnitFullName then
        local name, realm = UnitFullName("player")
        if name and realm and realm ~= "" then
            return name .. "-" .. realm
        end
        if name then
            return name .. "-" .. Util.GetPlayerRealm()
        end
    end
    return "Unknown-" .. Util.GetPlayerRealm()
end

function Util.NormalizeIdentity(sender)
    sender = Util.Trim(sender)
    if sender == "" then
        sender = "Unknown"
    end

    if Ambiguate then
        sender = Ambiguate(sender, "none") or sender
    end

    local name, realm = sender:match("^([^-]+)%-(.+)$")
    if not name or name == "" then
        name = sender
        realm = Util.GetPlayerRealm()
    end

    realm = Util.Trim(realm or Util.GetPlayerRealm()):gsub("%s+", "")
    name = Util.Trim(name)

    local nameKey = string.lower(name)
    local realmKey = string.lower(realm)
    local displayName = name .. "-" .. realm

    return {
        name = name,
        realm = realm,
        nameKey = nameKey,
        realmKey = realmKey,
        displayName = displayName,
        fullKey = nameKey .. "-" .. realmKey,
    }
end

function Util.IsSelf(sender)
    local senderIdentity = Util.NormalizeIdentity(sender)
    local playerIdentity = Util.NormalizeIdentity(Util.GetPlayerFullName())
    return senderIdentity.fullKey == playerIdentity.fullKey
end

function Util.FormatDuration(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)

    if seconds < 60 then
        return string.format("%ds", seconds)
    end
    if seconds < 3600 then
        return string.format("%dm %02ds", math.floor(seconds / 60), seconds % 60)
    end
    if seconds < 86400 then
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        return string.format("%dh %02dm", hours, minutes)
    end

    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    return string.format("%dd %02dh", days, hours)
end

function Util.FormatTimestamp(timestamp)
    timestamp = tonumber(timestamp)
    if not timestamp or timestamp <= 0 then
        return "-"
    end
    if date then
        return date("%Y-%m-%d %H:%M", timestamp)
    end
    return os.date("%Y-%m-%d %H:%M", timestamp)
end

function Util.FormatPercent(value)
    value = tonumber(value) or 0
    return string.format("%d%%", math.floor(value + 0.5))
end

function Util.FormatNumber(value, places)
    value = tonumber(value) or 0
    places = places or 0
    if places <= 0 then
        return tostring(math.floor(value + 0.5))
    end
    return string.format("%." .. places .. "f", value)
end

function Util.TableKeysSorted(map)
    local keys = {}
    if type(map) ~= "table" then
        return keys
    end
    for key in pairs(map) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end
