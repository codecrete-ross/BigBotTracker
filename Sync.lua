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
Sync.status = Sync.status or "Off"

local function getSettings()
    local settings = Storage.GetSettings()
    return settings.sync
end

local function sanitizeSettings()
    local settings = getSettings()
    settings.channelName = nil
    settings.prefix = nil
    settings.includeGuild = settings.includeGuild ~= false
    settings.includeGroup = settings.includeGroup ~= false
    settings.sendInterval = tonumber(settings.sendInterval) or 12
    settings.candidateCooldown = tonumber(settings.candidateCooldown) or 90
    settings.maxQueueSize = tonumber(settings.maxQueueSize) or 30
    return settings
end

local function isEnumSuccess(enumTable, result)
    if result == nil or result == true then
        return true
    end
    if result == false then
        return false
    end
    if enumTable and enumTable.Success ~= nil then
        return result == enumTable.Success
    end
    return true
end

local function ensurePrefixRegistered()
    if not C_ChatInfo or type(C_ChatInfo.RegisterAddonMessagePrefix) ~= "function" then
        Sync.status = "Addon channel API unavailable"
        return false
    end

    if type(C_ChatInfo.IsAddonMessagePrefixRegistered) == "function" then
        local ok, registered = pcall(C_ChatInfo.IsAddonMessagePrefixRegistered, PREFIX)
        if ok and registered then
            Sync.prefixRegistered = true
            return true
        end
    end

    local ok, result1, result2 = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    if not ok then
        Sync.status = "Addon prefix registration failed"
        return false
    end

    local result = result2 ~= nil and result2 or result1
    Sync.prefixRegistered = isEnumSuccess(Enum and Enum.RegisterAddonMessagePrefixResult, result)
    if not Sync.prefixRegistered then
        Sync.status = "Addon prefix registration failed"
    end
    return Sync.prefixRegistered
end

local function getGroupTransport()
    if type(IsInGroup) ~= "function" then
        return nil
    end

    local instanceCategory = LE_PARTY_CATEGORY_INSTANCE or 2
    if IsInGroup(instanceCategory) then
        return "INSTANCE_CHAT"
    end
    if type(IsInRaid) == "function" and IsInRaid() then
        return "RAID"
    end
    if IsInGroup() then
        return "PARTY"
    end
    return nil
end

local function appendTransport(transports, chatType)
    if chatType then
        transports[#transports + 1] = chatType
    end
end

local function formatTransports(transports)
    local labels = {
        GUILD = "guild",
        PARTY = "party",
        RAID = "raid",
        INSTANCE_CHAT = "instance",
    }
    local formatted = {}
    for _, transport in ipairs(transports or {}) do
        formatted[#formatted + 1] = labels[transport] or transport:lower()
    end
    return table.concat(formatted, "/")
end

local function getEligibleTransports()
    local settings = sanitizeSettings()
    local transports = {}
    if not settings.enabled then
        return transports
    end

    if settings.includeGuild and type(IsInGuild) == "function" and IsInGuild() then
        appendTransport(transports, "GUILD")
    end

    if settings.includeGroup then
        appendTransport(transports, getGroupTransport())
    end

    return transports
end

local function updateStatus()
    local settings = sanitizeSettings()
    if not settings.enabled then
        Sync.status = "Off"
        return
    end

    local transports = getEligibleTransports()
    if #transports == 0 then
        Sync.status = "Waiting for guild/group"
    else
        Sync.status = "Ready: " .. formatTransports(transports)
    end
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

    local settings = sanitizeSettings()
    if not settings.enabled then
        return
    end

    if (candidate.totalMessages or 0) < 3 then
        return
    end

    local now = Util.GetNow()
    if candidate.lastSyncQueuedAt and now - candidate.lastSyncQueuedAt < settings.candidateCooldown then
        return
    end

    candidate.lastSyncQueuedAt = now

    if not Sync.queued[candidate.fullKey] then
        if #Sync.queue >= settings.maxQueueSize then
            local dropped = table.remove(Sync.queue, 1)
            if dropped then
                Sync.queued[dropped] = nil
            end
        end
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

function Sync.SetEnabled(enabled)
    local settings = sanitizeSettings()
    settings.enabled = enabled == true
    if not settings.enabled then
        Sync.queue = {}
        Sync.queued = {}
    end
    updateStatus()
end

function Sync.JoinChannel()
    sanitizeSettings()
    updateStatus()
    return false
end

function Sync.SendNext()
    local settings = sanitizeSettings()
    if not settings.enabled then
        updateStatus()
        return
    end
    if not C_ChatInfo or type(C_ChatInfo.SendAddonMessage) ~= "function" then
        Sync.status = "Addon channel API unavailable"
        return
    end

    if not ensurePrefixRegistered() then
        return
    end

    local transports = getEligibleTransports()
    if #transports == 0 then
        updateStatus()
        return
    end

    local now = Util.GetNow()
    if now - (Sync.lastSendAt or 0) < settings.sendInterval then
        return
    end

    local fullKey = table.remove(Sync.queue, 1)
    if not fullKey then
        updateStatus()
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

    local sent = 0
    for _, transport in ipairs(transports) do
        local ok, result1, result2 = pcall(C_ChatInfo.SendAddonMessage, PREFIX, payload, transport)
        local result = result2 ~= nil and result2 or result1
        if ok and isEnumSuccess(Enum and Enum.SendAddonMessageResult, result) then
            sent = sent + 1
        else
            Util.Debug("Sync send failed on " .. tostring(transport) .. ".")
        end
    end

    if sent > 0 then
        Sync.status = "Last sent via " .. formatTransports(transports)
        Sync.lastSendAt = now
    else
        Sync.status = "Send throttled or failed"
    end
end

function Sync.HandleAddonMessage(prefix, message, channel, sender)
    local settings = sanitizeSettings()
    if not settings.enabled or prefix ~= PREFIX then
        return
    end
    if Util.IsSelf(sender) then
        return
    end

    local allowedChannel = channel == "GUILD"
        or channel == "PARTY"
        or channel == "RAID"
        or channel == "INSTANCE_CHAT"
        or channel == "WHISPER"
    if not allowedChannel then
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
    local settings = sanitizeSettings()
    if settings.firstRunNoticeShown then
        return
    end

    settings.firstRunNoticeShown = true
    settings.enabled = false

    if StaticPopupDialogs and StaticPopup_Show then
        StaticPopupDialogs.BIGBOTTRACKER_SYNC_NOTICE = {
            text = "Big Bot Tracker can share compact evidence summaries through hidden WoW addon channels with guild or group members who also run it. It does not join custom chat channels and does not share raw chat text.",
            button1 = "Enable Sync",
            button2 = "Keep Local",
            OnAccept = function()
                Sync.SetEnabled(true)
            end,
            OnCancel = function()
                Sync.SetEnabled(false)
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = false,
            preferredIndex = 3,
        }
        StaticPopup_Show("BIGBOTTRACKER_SYNC_NOTICE")
    else
        Sync.SetEnabled(false)
    end
end

function Sync.Initialize()
    sanitizeSettings()
    ensurePrefixRegistered()
    updateStatus()
end

function Sync.Start()
    if not BBT.DB then
        return
    end

    sanitizeSettings()
    Sync.ShowFirstRunNotice()
    if getSettings().enabled then
        ensurePrefixRegistered()
    end
    updateStatus()
end

function Sync.OnUpdate()
    Sync.SendNext()
end
