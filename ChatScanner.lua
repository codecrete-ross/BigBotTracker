local addonName, BBT = ...
BBT = BBT or _G.BigBotTracker or {}
_G.BigBotTracker = BBT

BBT.ChatScanner = BBT.ChatScanner or {}

local ChatScanner = BBT.ChatScanner
local Util = BBT.Util
local Normalizer = BBT.Normalizer
local Storage = BBT.Storage
local Scoring = BBT.Scoring

local TARGET_CHANNEL_NAMES = {
    trade = true,
    services = true,
    ["trade services"] = true,
}

local function normalizeChannelName(value)
    value = tostring(value or ""):lower()
    value = value:gsub("^%d+%.%s*", "")
    value = value:gsub("%-", " ")
    value = value:gsub("%(", " "):gsub("%)", " ")
    value = value:gsub("%s+", " ")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return value
end

function ChatScanner.GetTargetChannel(channelName, channelBaseName)
    local base = normalizeChannelName(channelBaseName)
    local full = normalizeChannelName(channelName)
    local settings = Storage.GetSettings()
    local monitor = settings.monitor or {}

    if TARGET_CHANNEL_NAMES[base] or TARGET_CHANNEL_NAMES[full] then
        if base:find("services") or full:find("services") then
            return monitor.services ~= false and "services" or nil
        end
        return monitor.trade ~= false and "trade" or nil
    end

    if base:find("services") or full:find("services") then
        return monitor.services ~= false and "services" or nil
    end
    if base:find("trade") or full:find("trade") then
        return monitor.trade ~= false and "trade" or nil
    end

    return nil
end

local function getPretrack(identity)
    BBT.session.pretrack[identity.fullKey] = BBT.session.pretrack[identity.fullKey]
        or {
            identity = identity,
            firstSeen = Util.GetNow(),
            messages = {},
            recentNormalized = {},
            nearDuplicatePairFound = false,
            nearDuplicateMessages = 0,
        }
    return BBT.session.pretrack[identity.fullKey]
end

local function prunePretrackMessages(entry, windowSeconds, now)
    local kept = {}
    for _, message in ipairs(entry.messages) do
        if now - message.timestamp <= windowSeconds then
            kept[#kept + 1] = message
        end
    end
    entry.messages = kept
end

local function hasRegularTiming(entry, settings)
    if #entry.messages < (settings.promotion.timingSampleCount or 4) + 1 then
        return false
    end

    local counts = {}
    local total = 0
    local bin = settings.timing.intervalBin or 10
    for index = 2, #entry.messages do
        local interval = entry.messages[index].timestamp - entry.messages[index - 1].timestamp
        if interval >= (settings.timing.minInterval or 5) and interval <= (settings.timing.maxInterval or 3600) then
            local bucket = Scoring.BucketInterval(interval, bin)
            counts[bucket] = (counts[bucket] or 0) + 1
            total = total + 1
        end
    end

    for _, count in pairs(counts) do
        if total >= 4 and count / total >= 0.75 then
            return true
        end
    end

    return false
end

local function shouldPromote(entry, settings, now)
    prunePretrackMessages(entry, settings.promotion.windowSeconds or 1800, now)

    if #entry.messages >= (settings.promotion.messageCount or 3) then
        return true, "message threshold"
    end

    if entry.nearDuplicatePairFound then
        return true, "near duplicate threshold"
    end

    if hasRegularTiming(entry, settings) then
        return true, "timing threshold"
    end

    return false, nil
end

function ChatScanner.HandleChannelMessage(
    text,
    sender,
    channelName,
    zoneChannelID,
    channelIndex,
    channelBaseName,
    lineID,
    guid
)
    if not BBT.DB then
        return
    end

    local channelKey = ChatScanner.GetTargetChannel(channelName, channelBaseName)
    if not channelKey then
        return
    end

    if Util.IsSelf(sender) then
        return
    end

    if lineID and BBT.session.seenLines[lineID] then
        return
    end
    if lineID then
        BBT.session.seenLines[lineID] = true
    end

    local now = Util.GetNow()
    local identity = Util.NormalizeIdentity(sender)
    local candidate = Storage.GetCandidate(identity)
    local normalized = Normalizer.NormalizeMessage(text)
    local hash = Normalizer.Hash(normalized)
    local sessionRecent = BBT.session.recentNormalized[identity.fullKey] or {}
    local nearDuplicate = false
    local similarity = 0

    if
        candidate
        and candidate.content
        and candidate.content.templateCounts
        and candidate.content.templateCounts[hash]
    then
        nearDuplicate = true
        similarity = 1
    else
        nearDuplicate, similarity = Normalizer.IsNearDuplicate(
            normalized,
            sessionRecent,
            Storage.GetSettings().promotion.nearDuplicateThreshold
        )
    end

    local observation = {
        timestamp = now,
        text = text,
        normalized = normalized,
        hash = hash,
        channelKey = channelKey,
        zoneChannelID = zoneChannelID,
        channelIndex = channelIndex,
        channelName = channelName,
        channelBaseName = channelBaseName,
        lineID = lineID,
        guid = guid,
        nearDuplicate = nearDuplicate,
        similarity = similarity,
    }

    if candidate then
        Storage.RecordObservation(candidate, observation)
        Util.PushLimited(sessionRecent, normalized, 10)
        BBT.session.recentNormalized[identity.fullKey] = sessionRecent
        return
    end

    local entry = getPretrack(identity)
    entry.messages[#entry.messages + 1] = observation
    Util.PushLimited(entry.recentNormalized, normalized, 10)

    if nearDuplicate then
        entry.nearDuplicatePairFound = true
        entry.nearDuplicateMessages = (entry.nearDuplicateMessages or 0) + 1
    end

    local promote, reason = shouldPromote(entry, Storage.GetSettings(), now)
    if promote then
        candidate = Storage.PromoteFromPretrack(identity, entry)
        BBT.session.pretrack[identity.fullKey] = nil
        Util.Debug(string.format("Promoted %s: %s", identity.displayName, reason or "threshold"))
    end

    Util.PushLimited(sessionRecent, normalized, 10)
    BBT.session.recentNormalized[identity.fullKey] = sessionRecent
end
