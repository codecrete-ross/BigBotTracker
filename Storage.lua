local addonName, BBT = ...
BBT = BBT or _G.BigBotTracker or {}
_G.BigBotTracker = BBT

BBT.Storage = BBT.Storage or {}

local Storage = BBT.Storage
local Util = BBT.Util
local Normalizer = BBT.Normalizer
local Scoring = BBT.Scoring

local SCHEMA_VERSION = 1

local DEFAULT_DB = {
    schemaVersion = SCHEMA_VERSION,
    settings = {
        debug = false,
        sync = {
            enabled = true,
            firstRunNoticeShown = false,
            channelName = "BigBotTracker",
            prefix = "BigBotTrack",
            sendInterval = 12,
            candidateCooldown = 90,
        },
        promotion = {
            messageCount = 3,
            windowSeconds = 1800,
            nearDuplicateThreshold = 0.82,
            timingSampleCount = 4,
        },
        timing = {
            intervalBin = 10,
            rollingWindows = { 5, 10, 20 },
            minInterval = 5,
            maxInterval = 3600,
            minPhaseLength = 3,
            activeRunGap = 600,
        },
        storage = {
            maxIntervals = 300,
            maxRecentHashes = 80,
        },
        ui = {
            sortKey = "score",
            sortDescending = true,
        },
        monitor = {
            trade = true,
            services = true,
        },
    },
    candidates = {},
    templates = {},
    peers = {},
    sessions = {},
}

local function createCandidate(identity, now, source)
    return {
        name = identity.name,
        realm = identity.realm,
        nameKey = identity.nameKey,
        realmKey = identity.realmKey,
        fullKey = identity.fullKey,
        displayName = identity.displayName,
        source = source or "local",
        firstSeen = now,
        firstPromoted = now,
        lastSeen = now,
        channels = {},
        daysSeen = {},
        totalMessages = 0,
        sessionMessages = 0,
        sessionId = BBT.session and BBT.session.id or nil,
        timing = {
            intervals = {},
            intervalCount = 0,
            lastMessageAt = nil,
            repeatedIntervalStreak = 0,
        },
        content = {
            templateCounts = {},
            recentHashes = {},
            templateTotal = 0,
            nearDuplicateCount = 0,
            messageLengthSum = 0,
            messageLengthSquareSum = 0,
        },
        behavior = {
            activeSpan = 0,
            longestActiveSpan = 0,
            currentRunStart = now,
            currentRunLast = now,
            currentRunCount = 0,
            burstCount = 0,
            lastBurstAt = 0,
        },
        network = {
            peers = {},
            peerCount = 0,
            confidence = 0,
            lastReceived = 0,
        },
        score = {
            localScore = 0,
            networkAdjustedScore = 0,
            tier = "Insufficient Data",
            confidence = 0,
            reasons = {},
        },
    }
end

local function ensureRealm(db, realmKey)
    db.candidates[realmKey] = db.candidates[realmKey] or {}
    return db.candidates[realmKey]
end

local function ensureTemplate(db, hash)
    db.templates[hash] = db.templates[hash]
        or {
            hash = hash,
            count = 0,
            firstSeen = Util.GetNow(),
            lastSeen = Util.GetNow(),
        }
    return db.templates[hash]
end

function Storage.Initialize()
    if type(BigBotTrackerDB) ~= "table" then
        BigBotTrackerDB = {}
    end

    Util.MergeDefaults(BigBotTrackerDB, DEFAULT_DB)

    if BigBotTrackerDB.schemaVersion ~= SCHEMA_VERSION then
        BigBotTrackerDB.schemaVersion = SCHEMA_VERSION
    end

    BBT.DB = BigBotTrackerDB
    BBT.session = BBT.session or {}
    BBT.session.id = tostring(Util.GetNow())
    BBT.session.pretrack = BBT.session.pretrack or {}
    BBT.session.recentNormalized = BBT.session.recentNormalized or {}
    BBT.session.seenLines = BBT.session.seenLines or {}

    BigBotTrackerDB.sessions[BBT.session.id] = {
        startedAt = Util.GetNow(),
    }

    for _, realmCandidates in pairs(BigBotTrackerDB.candidates) do
        for _, candidate in pairs(realmCandidates) do
            candidate.sessionId = BBT.session.id
            candidate.sessionMessages = 0
        end
    end
end

function Storage.GetSettings()
    return BBT.DB and BBT.DB.settings or DEFAULT_DB.settings
end

function Storage.GetCandidate(identity)
    if type(identity) == "string" then
        identity = Util.NormalizeIdentity(identity)
    end
    if not BBT.DB or not identity then
        return nil
    end

    local realm = BBT.DB.candidates[identity.realmKey]
    return realm and realm[identity.nameKey] or nil
end

function Storage.GetOrCreateCandidate(identity, now, source)
    if type(identity) == "string" then
        identity = Util.NormalizeIdentity(identity)
    end

    now = now or Util.GetNow()
    local realm = ensureRealm(BBT.DB, identity.realmKey)
    if not realm[identity.nameKey] then
        realm[identity.nameKey] = createCandidate(identity, now, source)
    end
    return realm[identity.nameKey]
end

function Storage.GetAllCandidates()
    local candidates = {}
    if not BBT.DB or type(BBT.DB.candidates) ~= "table" then
        return candidates
    end

    for _, realmCandidates in pairs(BBT.DB.candidates) do
        for _, candidate in pairs(realmCandidates) do
            candidates[#candidates + 1] = candidate
        end
    end

    table.sort(candidates, function(left, right)
        local leftScore = left.score and left.score.networkAdjustedScore or 0
        local rightScore = right.score and right.score.networkAdjustedScore or 0
        if leftScore == rightScore then
            return (left.lastSeen or 0) > (right.lastSeen or 0)
        end
        return leftScore > rightScore
    end)

    return candidates
end

local function updateSessionCount(candidate)
    local sessionId = BBT.session and BBT.session.id
    if candidate.sessionId ~= sessionId then
        candidate.sessionId = sessionId
        candidate.sessionMessages = 0
    end
    candidate.sessionMessages = (candidate.sessionMessages or 0) + 1
end

local function updateTiming(candidate, now)
    local timing = candidate.timing
    local settings = Storage.GetSettings()
    local minInterval = settings.timing.minInterval or 5
    local maxInterval = settings.timing.maxInterval or 3600
    local intervalBin = settings.timing.intervalBin or 10

    if timing.lastMessageAt then
        local interval = now - timing.lastMessageAt
        if interval >= minInterval and interval <= maxInterval then
            local bucket = Scoring.BucketInterval(interval, intervalBin)
            local previous = timing.intervals[#timing.intervals]
            if previous and previous.b == bucket then
                timing.repeatedIntervalStreak = (timing.repeatedIntervalStreak or 0) + 1
            else
                timing.repeatedIntervalStreak = 1
            end

            Util.PushLimited(timing.intervals, {
                t = now,
                s = interval,
                b = bucket,
            }, settings.storage.maxIntervals or 300)

            timing.intervalCount = (timing.intervalCount or 0) + 1
        end
    end

    timing.lastMessageAt = now
end

local function updateBehavior(candidate, now)
    local behavior = candidate.behavior
    local settings = Storage.GetSettings()
    local activeRunGap = settings.timing.activeRunGap or 600

    if not behavior.currentRunStart or not behavior.currentRunLast or now - behavior.currentRunLast > activeRunGap then
        behavior.currentRunStart = now
        behavior.currentRunCount = 0
    end

    behavior.currentRunLast = now
    behavior.currentRunCount = (behavior.currentRunCount or 0) + 1

    local currentRunSpan = behavior.currentRunLast - behavior.currentRunStart
    if currentRunSpan > (behavior.longestActiveSpan or 0) then
        behavior.longestActiveSpan = currentRunSpan
    end
end

local function updateBurst(candidate, now)
    local content = candidate.content
    content.recentMessageTimes = content.recentMessageTimes or {}
    Util.PushLimited(content.recentMessageTimes, now, 12)

    local recent = 0
    for _, timestamp in ipairs(content.recentMessageTimes) do
        if now - timestamp <= 120 then
            recent = recent + 1
        end
    end

    if recent >= 3 and now - (candidate.behavior.lastBurstAt or 0) > 180 then
        candidate.behavior.burstCount = (candidate.behavior.burstCount or 0) + 1
        candidate.behavior.lastBurstAt = now
    end
end

function Storage.RecordObservation(candidate, observation)
    if not candidate or not observation then
        return nil
    end

    local now = observation.timestamp or Util.GetNow()
    local settings = Storage.GetSettings()
    local normalized = observation.normalized or Normalizer.NormalizeMessage(observation.text)
    local hash = observation.hash or Normalizer.Hash(normalized)
    local dateKey = Util.GetDateKey(now)
    local channelKey = observation.channelKey or "unknown"

    candidate.firstSeen = math.min(candidate.firstSeen or now, now)
    candidate.lastSeen = math.max(candidate.lastSeen or now, now)
    candidate.daysSeen[dateKey] = true
    candidate.channels[channelKey] = (candidate.channels[channelKey] or 0) + 1
    candidate.totalMessages = (candidate.totalMessages or 0) + 1

    updateSessionCount(candidate)
    updateTiming(candidate, now)
    updateBehavior(candidate, now)
    updateBurst(candidate, now)

    local content = candidate.content
    local messageLength = #(observation.text or "")
    content.templateCounts[hash] = (content.templateCounts[hash] or 0) + 1
    content.templateTotal = (content.templateTotal or 0) + 1
    content.messageLengthSum = (content.messageLengthSum or 0) + messageLength
    content.messageLengthSquareSum = (content.messageLengthSquareSum or 0) + (messageLength * messageLength)

    if observation.nearDuplicate or content.templateCounts[hash] > 1 then
        content.nearDuplicateCount = (content.nearDuplicateCount or 0) + 1
    end

    Util.PushLimited(content.recentHashes, hash, settings.storage.maxRecentHashes or 80)

    local template = ensureTemplate(BBT.DB, hash)
    template.count = template.count + 1
    template.lastSeen = now

    Scoring.Recalculate(candidate, settings)

    if BBT.Sync and BBT.Sync.QueueCandidate then
        BBT.Sync.QueueCandidate(candidate)
    end

    return candidate
end

function Storage.PromoteFromPretrack(identity, pretrack)
    local now = Util.GetNow()
    local candidate = Storage.GetOrCreateCandidate(identity, pretrack.firstSeen or now, "local")
    if (candidate.totalMessages or 0) == 0 then
        candidate.firstPromoted = now
    end

    for _, observation in ipairs(pretrack.messages or {}) do
        Storage.RecordObservation(candidate, observation)
    end

    return candidate
end

function Storage.CreateNetworkCandidate(fullName, firstSeen)
    local identity = Util.NormalizeIdentity(fullName)
    local candidate = Storage.GetOrCreateCandidate(identity, firstSeen or Util.GetNow(), "network")
    candidate.networkOnly = (candidate.totalMessages or 0) == 0
    return candidate
end

function Storage.MergeNetworkEvidence(capsule)
    if type(capsule) ~= "table" or not capsule.fullName or not capsule.peerId then
        return nil, "malformed"
    end

    local now = Util.GetNow()
    if capsule.lastSeen and capsule.lastSeen > now + 3600 then
        return nil, "future"
    end

    local candidate = Storage.CreateNetworkCandidate(capsule.fullName, capsule.firstSeen)
    candidate.network = candidate.network or { peers = {}, peerCount = 0 }

    if not candidate.network.peers[capsule.peerId] then
        candidate.network.peerCount = (candidate.network.peerCount or 0) + 1
    end

    candidate.network.peers[capsule.peerId] = capsule
    candidate.network.lastReceived = now

    local confidenceTotal = 0
    local peerCount = 0
    local messageTotal = 0
    local rollingEntropyTotal = 0
    local globalEntropyTotal = 0
    local templateReuseTotal = 0
    local postsPerHourTotal = 0
    local cadenceSwitchTotal = 0
    for _, peerCapsule in pairs(candidate.network.peers) do
        confidenceTotal = confidenceTotal + (peerCapsule.confidence or 0)
        messageTotal = messageTotal + (peerCapsule.messageCount or 0)
        rollingEntropyTotal = rollingEntropyTotal + (peerCapsule.rollingEntropy or 1)
        globalEntropyTotal = globalEntropyTotal + (peerCapsule.globalEntropy or 1)
        templateReuseTotal = templateReuseTotal + (peerCapsule.templateReusePercent or 0)
        postsPerHourTotal = postsPerHourTotal + (peerCapsule.postsPerHour or 0)
        cadenceSwitchTotal = cadenceSwitchTotal + (peerCapsule.cadenceSwitchCount or 0)
        peerCount = peerCount + 1
    end
    candidate.network.peerCount = peerCount
    candidate.network.confidence = peerCount > 0 and confidenceTotal / peerCount or 0
    candidate.network.summary = {
        messageCount = messageTotal,
        averageRollingEntropy = peerCount > 0 and rollingEntropyTotal / peerCount or 1,
        averageGlobalEntropy = peerCount > 0 and globalEntropyTotal / peerCount or 1,
        averageTemplateReusePercent = peerCount > 0 and templateReuseTotal / peerCount or 0,
        averagePostsPerHour = peerCount > 0 and postsPerHourTotal / peerCount or 0,
        cadenceSwitchCount = cadenceSwitchTotal,
    }

    Scoring.Recalculate(candidate, Storage.GetSettings())
    return candidate, nil
end

function Storage.ClearSessionBuffers()
    if BBT.session then
        BBT.session.pretrack = {}
        BBT.session.recentNormalized = {}
        BBT.session.seenLines = {}
    end
end

function Storage.PurgeCandidate(candidate)
    if not candidate or not BBT.DB then
        return
    end
    local realm = BBT.DB.candidates[candidate.realmKey]
    if realm then
        realm[candidate.nameKey] = nil
    end
end

function Storage.PurgeAll()
    if not BBT.DB then
        return
    end
    BBT.DB.candidates = {}
    BBT.DB.templates = {}
    BBT.DB.peers = {}
    Storage.ClearSessionBuffers()
end

function Storage.BuildDebugSummary()
    local rows = {}
    local candidates = Storage.GetAllCandidates()

    rows[#rows + 1] = "Big Bot Tracker Debug Summary"
    rows[#rows + 1] = "Generated: " .. Util.FormatTimestamp(Util.GetNow())
    rows[#rows + 1] = "Candidates: " .. tostring(#candidates)
    rows[#rows + 1] = "Sync: " .. tostring(BBT.Sync and BBT.Sync.status or "Unknown")
    rows[#rows + 1] = ""

    for index = 1, math.min(25, #candidates) do
        local candidate = candidates[index]
        local score = candidate.score or {}
        local timing = candidate.timing or {}
        local content = candidate.content or {}
        rows[#rows + 1] = string.format(
            "%d. %s | tier=%s score=%d confidence=%d messages=%d lastSeen=%s avgInterval=%ds reuse=%d%% peers=%d",
            index,
            candidate.displayName or "?",
            score.tier or "Insufficient Data",
            math.floor((score.networkAdjustedScore or 0) + 0.5),
            math.floor((score.confidence or 0) + 0.5),
            candidate.totalMessages or 0,
            Util.FormatTimestamp(candidate.lastSeen),
            math.floor((timing.averageInterval or 0) + 0.5),
            math.floor((content.templateReusePercent or 0) + 0.5),
            candidate.network and candidate.network.peerCount or 0
        )
    end

    return table.concat(rows, "\n")
end
