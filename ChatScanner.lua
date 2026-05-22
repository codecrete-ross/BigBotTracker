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
    BBT.runtime.pretrack[identity.fullKey] = BBT.runtime.pretrack[identity.fullKey]
        or {
            identity = identity,
            firstSeen = Util.GetNow(),
            messages = {},
            recentMessages = {},
            nearDuplicatePairFound = false,
            nearDuplicateMessages = 0,
            strongShingleMatches = 0,
            adIntentMessages = 0,
            intentCounts = {},
        }
    return BBT.runtime.pretrack[identity.fullKey]
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

local function countTokens(normalized)
    local count = 0
    for _ in tostring(normalized or ""):gmatch("%S+") do
        count = count + 1
    end
    return count
end

local function isPromotionLength(normalized, settings)
    return countTokens(normalized) >= (settings.promotion.minDuplicateTokens or 4)
end

local function hasTemplateReuse(entry, settings)
    if #entry.messages < (settings.promotion.messageCount or 3) then
        return false
    end

    local counts = {}
    local total = 0
    for _, message in ipairs(entry.messages) do
        if isPromotionLength(message.normalized, settings) then
            local hash = message.hash or Normalizer.Hash(message.normalized)
            counts[hash] = (counts[hash] or 0) + 1
            total = total + 1
        end
    end

    if total < (settings.promotion.messageCount or 3) then
        return false
    end

    local threshold = settings.promotion.templateReusePercent or 67
    for _, count in pairs(counts) do
        if count >= 2 and (count / total * 100) >= threshold then
            return true
        end
    end

    return false
end

local function hasNearDuplicateCluster(entry, settings)
    if #entry.messages < (settings.promotion.messageCount or 3) then
        return false
    end

    if (entry.nearDuplicateMessages or 0) >= (settings.promotion.nearDuplicateClusterCount or 3) then
        return true
    end

    return (entry.strongShingleMatches or 0) >= (settings.promotion.strongShingleMatchCount or 2)
end

local function hasHighVolume(entry, settings, now, identity)
    local windowSeconds = settings.promotion.highVolumeWindowSeconds or 600
    local count = 0
    local intentCount = 0
    local templateCounts = {}
    local topTemplateCount = 0
    for _, message in ipairs(entry.messages) do
        if now - message.timestamp <= windowSeconds then
            count = count + 1
            if message.adIntent and message.adIntent.hasIntent then
                intentCount = intentCount + 1
            end
            if isPromotionLength(message.normalized, settings) then
                local hash = message.hash or Normalizer.Hash(message.normalized)
                templateCounts[hash] = (templateCounts[hash] or 0) + 1
                if templateCounts[hash] > topTemplateCount then
                    topTemplateCount = templateCounts[hash]
                end
            end
        end
    end

    if count < (settings.promotion.highVolumeCount or 6) then
        return false
    end

    local lowDiversity = count > 0 and (topTemplateCount / count) >= 0.50
    local hasRepeatedIntent = intentCount >= 3
    local channelKey = entry.messages[#entry.messages] and entry.messages[#entry.messages].channelKey or "unknown"
    local isOutlier = Storage.IsHighVolumeOutlier
        and Storage.IsHighVolumeOutlier(identity, channelKey, count, windowSeconds)

    return hasRepeatedIntent or lowDiversity or isOutlier
end

local function hasRegularTiming(entry, settings)
    if #entry.messages < (settings.promotion.timingSampleCount or 4) + 1 then
        return false
    end

    local counts = {}
    local values = {}
    local total = 0
    local bin = settings.timing.intervalBin or 10
    for index = 2, #entry.messages do
        local interval = entry.messages[index].timestamp - entry.messages[index - 1].timestamp
        if interval >= (settings.timing.minInterval or 5) and interval <= (settings.timing.maxInterval or 3600) then
            local bucket = Scoring.BucketInterval(interval, bin)
            counts[bucket] = (counts[bucket] or 0) + 1
            values[#values + 1] = interval
            total = total + 1
        end
    end

    local entropy = Scoring.CalculateEntropy(counts, total)
    local robust = Scoring.CalculateRobustStats(values)
    if total >= 4 and robust.robustCoefficientVariation <= 0.18 then
        return true
    end

    for _, count in pairs(counts) do
        if total >= 4 and count / total >= 0.75 and (entropy <= 0.40 or robust.robustCoefficientVariation <= 0.18) then
            return true
        end
    end

    return false
end

local function shouldPromote(entry, settings, now, identity)
    prunePretrackMessages(entry, settings.promotion.windowSeconds or 1800, now)

    if hasTemplateReuse(entry, settings) then
        return true, "template reuse threshold"
    end

    if hasNearDuplicateCluster(entry, settings) then
        return true, "near duplicate threshold"
    end

    if hasRegularTiming(entry, settings) then
        return true, "timing threshold"
    end

    if hasHighVolume(entry, settings, now, identity) then
        return true, "high volume threshold"
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

    if lineID and BBT.runtime.seenLines[lineID] then
        return
    end
    if lineID then
        BBT.runtime.seenLines[lineID] = true
    end

    local now = Util.GetNow()
    local identity = Util.NormalizeIdentity(sender)
    local candidate = Storage.GetCandidate(identity)
    local normalized = Normalizer.NormalizeMessage(text)
    local hash = Normalizer.Hash(normalized)
    local shingles = Normalizer.ShingleSignature(normalized)
    local shingleKey = Normalizer.SignatureKey(shingles, 4)
    local adIntent = Normalizer.DetectAdIntent(text, normalized)
    local runtimeRecent = BBT.runtime.recentNormalized[identity.fullKey] or {}
    local nearDuplicate = false
    local similarity = 0
    local nearDuplicateMethod = nil
    local settings = Storage.GetSettings()
    local promotionLength = isPromotionLength(normalized, settings)

    if
        promotionLength
        and candidate
        and candidate.content
        and candidate.content.templateCounts
        and candidate.content.templateCounts[hash]
    then
        nearDuplicate = true
        similarity = 1
        nearDuplicateMethod = "template"
    elseif
        promotionLength
        and candidate
        and candidate.content
        and candidate.content.shingleCounts
        and shingleKey ~= ""
        and candidate.content.shingleCounts[shingleKey]
    then
        nearDuplicate = true
        similarity = 1
        nearDuplicateMethod = "shingle"
    else
        nearDuplicate, similarity, nearDuplicateMethod = Normalizer.IsNearDuplicate(
            normalized,
            runtimeRecent,
            settings.promotion.nearDuplicateThreshold,
            settings.promotion.shingleNearDuplicateThreshold,
            shingles
        )
    end

    if not promotionLength then
        nearDuplicate = false
        similarity = 0
        nearDuplicateMethod = nil
    end

    local observation = {
        timestamp = now,
        text = text,
        normalized = normalized,
        hash = hash,
        shingles = shingles,
        shingleKey = shingleKey,
        adIntent = adIntent,
        channelKey = channelKey,
        zoneChannelID = zoneChannelID,
        channelIndex = channelIndex,
        channelName = channelName,
        channelBaseName = channelBaseName,
        lineID = lineID,
        guid = guid,
        nearDuplicate = nearDuplicate,
        similarity = similarity,
        nearDuplicateMethod = nearDuplicateMethod,
        tokenCount = countTokens(normalized),
    }

    if candidate then
        Storage.RecordObservation(candidate, observation)
        Util.PushLimited(runtimeRecent, { normalized = normalized, shingles = shingles }, 10)
        BBT.runtime.recentNormalized[identity.fullKey] = runtimeRecent
        return
    end

    local entry = getPretrack(identity)
    entry.messages[#entry.messages + 1] = observation
    Util.PushLimited(entry.recentMessages, { normalized = normalized, shingles = shingles }, 10)

    if nearDuplicate then
        entry.nearDuplicatePairFound = true
        entry.nearDuplicateMessages = (entry.nearDuplicateMessages or 0) + 1
        if nearDuplicateMethod == "shingle" and similarity >= (settings.promotion.shingleStrongThreshold or 0.72) then
            entry.strongShingleMatches = (entry.strongShingleMatches or 0) + 1
        end
    end

    if adIntent and adIntent.hasIntent then
        entry.adIntentMessages = (entry.adIntentMessages or 0) + 1
        entry.intentCounts[adIntent.categoryKey] = (entry.intentCounts[adIntent.categoryKey] or 0) + 1
    end

    if Storage.RecordPretrackBaselineSample then
        Storage.RecordPretrackBaselineSample(identity, channelKey, entry, now)
    end

    local promote, reason = shouldPromote(entry, settings, now, identity)
    if promote then
        candidate = Storage.PromoteFromPretrack(identity, entry)
        BBT.runtime.pretrack[identity.fullKey] = nil
        Util.Debug(string.format("Promoted %s: %s", identity.displayName, reason or "threshold"))
    end

    Util.PushLimited(runtimeRecent, { normalized = normalized, shingles = shingles }, 10)
    BBT.runtime.recentNormalized[identity.fullKey] = runtimeRecent
end
