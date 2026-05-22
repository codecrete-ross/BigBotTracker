local addonName, BBT = ...
BBT = BBT or _G.BigBotTracker or {}
_G.BigBotTracker = BBT

BBT.Sync = BBT.Sync or {}

local Sync = BBT.Sync
local Util = BBT.Util
local Storage = BBT.Storage
local Normalizer = BBT.Normalizer

local PREFIX = "BigBotTrack"
local PROTOCOL_VERSION = 2
local FEATURE_VERSION = 3
local MAX_PAYLOAD_BYTES = 240
local OBSERVATION_WINDOW_SECONDS = 1800

Sync.queue = Sync.queue or {}
Sync.queued = Sync.queued or {}
Sync.lastSendAt = Sync.lastSendAt or 0
Sync.channelId = Sync.channelId or nil
Sync.status = Sync.status or "Not started"

local function getSettings()
    local settings = Storage.GetSettings()
    return settings.sync
end

local function split(value, delimiter)
    local parts = {}
    delimiter = delimiter or "|"
    value = tostring(value or "")
    local startIndex = 1
    while true do
        local delimiterStart, delimiterEnd = value:find(delimiter, startIndex, true)
        if not delimiterStart then
            parts[#parts + 1] = value:sub(startIndex)
            break
        end
        parts[#parts + 1] = value:sub(startIndex, delimiterStart - 1)
        startIndex = delimiterEnd + 1
    end
    return parts
end

local function encodeNumber(value, multiplier)
    value = tonumber(value) or 0
    multiplier = multiplier or 1
    return tostring(math.floor(value * multiplier + 0.5))
end

local function decodePercent(value)
    return (tonumber(value) or 0) / 100
end

local function observationWindow(timestamp)
    timestamp = tonumber(timestamp) or Util.GetNow()
    return math.floor(timestamp / OBSERVATION_WINDOW_SECONDS)
end

local function topHashes(map, limit)
    local rows = {}
    for hash, count in pairs(map or {}) do
        rows[#rows + 1] = { hash = hash, count = count }
    end
    table.sort(rows, function(left, right)
        if left.count == right.count then
            return left.hash < right.hash
        end
        return left.count > right.count
    end)

    local encoded = {}
    for index = 1, math.min(limit or 2, #rows) do
        encoded[#encoded + 1] = rows[index].hash .. ":" .. tostring(rows[index].count)
    end
    return table.concat(encoded, ",")
end

local function parseHashes(value)
    local hashes = {}
    for pair in tostring(value or ""):gmatch("[^,]+") do
        local hash, count = pair:match("^([^:]+):(%d+)$")
        if hash and count then
            hashes[hash] = tonumber(count) or 0
        end
    end
    return hashes
end

local function getPeerId(sender)
    local identity = Util.NormalizeIdentity(sender or "unknown")
    return Normalizer.Hash(identity.fullKey)
end

function Sync.GetLocalPeerId()
    return getPeerId(Util.GetPlayerFullName())
end

function Sync.SerializeCandidate(candidate)
    if not candidate or not candidate.displayName then
        return nil
    end

    local score = candidate.score or {}
    local timing = candidate.timing or {}
    local content = candidate.content or {}
    local behavior = candidate.behavior or {}
    local firstSeen = math.floor(candidate.firstSeen or 0)
    local lastSeen = math.floor(candidate.lastSeen or 0)

    for hashLimit = 2, 0, -1 do
        local payload = table.concat({
            "C",
            tostring(PROTOCOL_VERSION),
            tostring(candidate.featureVersion or FEATURE_VERSION),
            candidate.displayName,
            tostring(firstSeen),
            tostring(lastSeen),
            tostring(observationWindow(firstSeen)),
            tostring(observationWindow(lastSeen)),
            tostring(candidate.totalMessages or 0),
            encodeNumber(timing.averageInterval or 0),
            encodeNumber(timing.robustCoefficientVariation or timing.coefficientVariation or 0, 100),
            encodeNumber(timing.globalEntropy or 1, 100),
            encodeNumber(timing.lowestRollingEntropy or 1, 100),
            encodeNumber(content.templateReusePercent or 0),
            encodeNumber(content.shingleReusePercent or 0),
            tostring(timing.cadenceSwitchCount or 0),
            encodeNumber(behavior.postsPerHour or 0, 10),
            encodeNumber(score.confidence or 0),
            topHashes(content.templateCounts, hashLimit),
            topHashes(content.shingleCounts, hashLimit),
        }, "|")

        if #payload <= MAX_PAYLOAD_BYTES then
            return payload
        end
    end

    return nil
end

function Sync.ParseCapsule(message, sender)
    if #tostring(message or "") > MAX_PAYLOAD_BYTES then
        return nil, "oversized"
    end

    local parts = split(message, "|")
    if parts[1] ~= "C" or tonumber(parts[2]) ~= PROTOCOL_VERSION then
        return nil, "version"
    end
    if not parts[4] or parts[4] == "" then
        return nil, "identity"
    end

    local capsule = {
        peerId = getPeerId(sender),
        featureVersion = tonumber(parts[3]) or 1,
        fullName = parts[4],
        firstSeen = tonumber(parts[5]) or 0,
        lastSeen = tonumber(parts[6]) or 0,
        firstWindow = tonumber(parts[7]) or 0,
        lastWindow = tonumber(parts[8]) or 0,
        messageCount = tonumber(parts[9]) or 0,
        averageInterval = tonumber(parts[10]) or 0,
        robustCoefficientVariation = decodePercent(parts[11]),
        coefficientVariation = decodePercent(parts[11]),
        globalEntropy = decodePercent(parts[12]),
        rollingEntropy = decodePercent(parts[13]),
        templateReusePercent = tonumber(parts[14]) or 0,
        shingleReusePercent = tonumber(parts[15]) or 0,
        cadenceSwitchCount = tonumber(parts[16]) or 0,
        postsPerHour = (tonumber(parts[17]) or 0) / 10,
        confidence = tonumber(parts[18]) or 0,
        templateHashes = parseHashes(parts[19]),
        shingleHashes = parseHashes(parts[20]),
        receivedAt = Util.GetNow(),
    }

    if capsule.firstSeen <= 0 or capsule.lastSeen < capsule.firstSeen then
        return nil, "timestamp"
    end

    return capsule, nil
end

function Sync.QueueCandidate(candidate)
    if not BBT.DB or not candidate or not candidate.fullKey then
        return
    end

    local settings = getSettings()
    if not settings.enabled then
        return
    end

    if (candidate.totalMessages or 0) < 3 then
        return
    end

    local now = Util.GetNow()
    if candidate.lastSyncQueuedAt and now - candidate.lastSyncQueuedAt < (settings.candidateCooldown or 90) then
        return
    end

    candidate.lastSyncQueuedAt = now

    if not Sync.queued[candidate.fullKey] then
        Sync.queue[#Sync.queue + 1] = candidate.fullKey
        Sync.queued[candidate.fullKey] = true
    end
end

local function findCandidateByFullKey(fullKey)
    for _, candidate in ipairs(Storage.GetAllCandidates()) do
        if candidate.fullKey == fullKey then
            return candidate
        end
    end
    return nil
end

function Sync.JoinChannel()
    local settings = getSettings()
    if not settings.enabled then
        Sync.status = "Disabled"
        return false
    end

    if not JoinTemporaryChannel or not GetChannelName then
        Sync.status = "Channel API unavailable"
        return false
    end

    local channelName = settings.channelName or "BigBotTracker"
    local id = GetChannelName(channelName)
    if not id or id == 0 then
        JoinTemporaryChannel(channelName)
        id = GetChannelName(channelName)
    end

    if not id or id == 0 then
        Sync.channelId = nil
        Sync.status = "Unable to join sync channel"
        return false
    end

    Sync.channelId = id
    Sync.status = "Connected to " .. channelName
    return true
end

function Sync.SendNext()
    local settings = getSettings()
    if not settings.enabled or not Sync.channelId or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        return
    end

    local now = Util.GetNow()
    if now - (Sync.lastSendAt or 0) < (settings.sendInterval or 12) then
        return
    end

    local fullKey = table.remove(Sync.queue, 1)
    if not fullKey then
        return
    end

    Sync.queued[fullKey] = nil
    local candidate = findCandidateByFullKey(fullKey)
    if not candidate then
        return
    end

    local payload = Sync.SerializeCandidate(candidate)
    if not payload then
        return
    end

    local ok = C_ChatInfo.SendAddonMessage(PREFIX, payload, "CHANNEL", Sync.channelId)
    if ok == false then
        Sync.status = "Send throttled or failed"
    else
        Sync.status = "Last sent " .. candidate.displayName
        Sync.lastSendAt = now
    end
end

function Sync.HandleAddonMessage(prefix, message, channel, sender)
    if prefix ~= PREFIX then
        return
    end
    if Util.IsSelf(sender) then
        return
    end

    local capsule, reason = Sync.ParseCapsule(message, sender)
    if not capsule then
        Util.Debug("Rejected sync packet: " .. tostring(reason))
        return
    end

    local candidate, mergeReason = Storage.MergeNetworkEvidence(capsule)
    if candidate then
        Sync.status = "Received evidence for " .. candidate.displayName
    else
        Util.Debug("Rejected network evidence: " .. tostring(mergeReason))
    end
end

function Sync.ShowFirstRunNotice()
    local settings = getSettings()
    if settings.firstRunNoticeShown then
        return
    end

    settings.firstRunNoticeShown = true

    if StaticPopupDialogs and StaticPopup_Show then
        StaticPopupDialogs.BIGBOTTRACKER_SYNC_NOTICE = {
            text = "Big Bot Tracker shares compact evidence summaries with other users in a custom addon sync channel. It does not share raw chat text. Sync is enabled by default and can be disabled in /bbt.",
            button1 = "OK",
            button2 = "Disable Sync",
            OnAccept = function()
                settings.enabled = true
                Sync.JoinChannel()
            end,
            OnCancel = function()
                settings.enabled = false
                Sync.status = "Disabled"
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = false,
            preferredIndex = 3,
        }
        StaticPopup_Show("BIGBOTTRACKER_SYNC_NOTICE")
    else
        Util.Print("Sync shares compact evidence summaries, not raw chat text. Use /bbt sync off to disable.")
        Sync.JoinChannel()
    end
end

function Sync.Initialize()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
end

function Sync.Start()
    if not BBT.DB then
        return
    end

    Sync.ShowFirstRunNotice()
    if getSettings().firstRunNoticeShown and getSettings().enabled then
        Sync.JoinChannel()
    end
end

function Sync.OnUpdate()
    Sync.SendNext()
end
