local addonName, BBT = ...
BBT = BBT or _G.BigBotTracker or {}
_G.BigBotTracker = BBT

BBT.Storage = BBT.Storage or {}

local Storage = BBT.Storage
local Util = BBT.Util
local Normalizer = BBT.Normalizer
local Scoring = BBT.Scoring

local SCHEMA_VERSION = 4
local FEATURE_VERSION = 4
local CURRENT_DATA_EPOCH = 20260527
local DATA_RESET_REASON = "player-facing-detection-cutover"
local OBSERVATION_WINDOW_SECONDS = 1800

local DEFAULT_DB = {
    schemaVersion = SCHEMA_VERSION,
    featureVersion = FEATURE_VERSION,
    dataEpoch = CURRENT_DATA_EPOCH,
    settings = {
        debug = false,
        sync = {
            enabled = false,
            firstRunNoticeShown = false,
            includeGuild = true,
            includeGroup = true,
            sendInterval = 12,
            candidateCooldown = 90,
            maxQueueSize = 30,
            maxCapsuleAgeSeconds = 30 * 86400,
        },
        promotion = {
            messageCount = 3,
            windowSeconds = 1800,
            nearDuplicateThreshold = 0.82,
            shingleNearDuplicateThreshold = 0.66,
            shingleStrongThreshold = 0.72,
            nearDuplicateCount = 2,
            nearDuplicateClusterCount = 2,
            strongShingleMatchCount = 2,
            templateReusePercent = 67,
            shingleReusePercent = 67,
            timingSampleCount = 4,
            highVolumeCount = 6,
            highVolumeWindowSeconds = 600,
            minDuplicateTokens = 4,
        },
        timing = {
            intervalBin = 10,
            rollingWindows = { 5, 10, 20 },
            minInterval = 5,
            maxInterval = 3600,
            minPhaseLength = 3,
            activeRunGap = 600,
            featureWindows = { 600, 1800, 7200 },
        },
        storage = {
            maxIntervals = 300,
            maxRecentHashes = 80,
            maxRecentShingles = 80,
        },
        baseline = {
            sampleCooldown = 300,
            minSamples = 50,
            matureSamples = 200,
        },
        ui = {
            sortKey = "score",
            sortDescending = true,
            filterKey = "active",
        },
        monitor = {
            public = true,
            trade = true,
            services = true,
        },
    },
    candidates = {},
    templates = {},
    baselines = {
        realms = {},
    },
    peers = {},
    resetHistory = {},
}

local function createCandidate(identity, now, source)
    return {
        name = identity.name,
        realm = identity.realm,
        nameKey = identity.nameKey,
        realmKey = identity.realmKey,
        fullKey = identity.fullKey,
        displayName = identity.displayName,
        featureVersion = FEATURE_VERSION,
        source = source or "local",
        firstSeen = now,
        firstPromoted = now,
        lastSeen = now,
        channels = {},
        daysSeen = {},
        observationWindows = {},
        lastGuid = nil,
        lastLineID = nil,
        lastReportObservedAt = nil,
        lastReportDiagnostic = nil,
        triage = {},
        totalMessages = 0,
        timing = {
            intervals = {},
            intervalCount = 0,
            lastMessageAt = nil,
            repeatedIntervalStreak = 0,
        },
        content = {
            templateCounts = {},
            shingleCounts = {},
            adIntentCounts = {},
            recentHashes = {},
            recentShingleHashes = {},
            templateTotal = 0,
            shingleTotal = 0,
            adIntentTotal = 0,
            eligibleMessageCount = 0,
            nearDuplicateCount = 0,
            strongShingleMatchCount = 0,
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
            overlap = "None",
        },
        baseline = {
            sampleCount = 0,
            label = "Baseline warming up",
        },
        features = {
            version = FEATURE_VERSION,
            familyScores = {},
            familyCount = 0,
        },
        score = {
            localScore = 0,
            displayScore = 0,
            networkAdjustedScore = 0,
            networkScore = 0,
            networkConfidence = 0,
            tier = "Observing",
            status = "Observing",
            statusCapReasons = {},
            confidence = 0,
            evidenceFamilyCount = 0,
            familyScores = {},
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

local function observationWindow(timestamp)
    timestamp = tonumber(timestamp) or Util.GetNow()
    return math.floor(timestamp / OBSERVATION_WINDOW_SECONDS)
end

local function ensureTriage(candidate)
    candidate.triage = candidate.triage or {}
    candidate.triage.watched = candidate.triage.watched == true and true or nil
    candidate.triage.reported = candidate.triage.reported == true and true or nil
    candidate.triage.ignored = candidate.triage.ignored == true and true or nil
    local reportOpenCount = tonumber(candidate.triage.reportOpenCount) or 0
    candidate.triage.reportOpenCount = reportOpenCount > 0 and reportOpenCount or nil
    return candidate.triage
end

local function ensureCandidateShape(candidate)
    candidate.featureVersion = FEATURE_VERSION
    candidate.channels = candidate.channels or {}
    candidate.daysSeen = candidate.daysSeen or {}
    candidate.observationWindows = candidate.observationWindows or {}
    if candidate.lastReportDiagnostic ~= nil and type(candidate.lastReportDiagnostic) ~= "table" then
        candidate.lastReportDiagnostic = nil
    end
    candidate.timing = candidate.timing or {}
    candidate.timing.intervals = candidate.timing.intervals or {}
    candidate.timing.intervalCount = candidate.timing.intervalCount or #(candidate.timing.intervals or {})
    candidate.content = candidate.content or {}
    candidate.content.templateCounts = candidate.content.templateCounts or {}
    candidate.content.shingleCounts = candidate.content.shingleCounts or {}
    candidate.content.adIntentCounts = candidate.content.adIntentCounts or {}
    candidate.content.recentHashes = candidate.content.recentHashes or {}
    candidate.content.recentShingleHashes = candidate.content.recentShingleHashes or {}
    candidate.content.templateTotal = candidate.content.templateTotal or candidate.totalMessages or 0
    candidate.content.shingleTotal = candidate.content.shingleTotal or 0
    candidate.content.adIntentTotal = candidate.content.adIntentTotal or 0
    candidate.content.eligibleMessageCount = candidate.content.eligibleMessageCount or 0
    candidate.content.nearDuplicateCount = candidate.content.nearDuplicateCount or 0
    candidate.content.strongShingleMatchCount = candidate.content.strongShingleMatchCount or 0
    candidate.behavior = candidate.behavior or {}
    candidate.network = candidate.network or {}
    candidate.network.peers = candidate.network.peers or {}
    candidate.network.peerCount = candidate.network.peerCount or 0
    candidate.network.overlap = candidate.network.overlap or "None"
    candidate.baseline = candidate.baseline or { sampleCount = 0, label = "Baseline warming up" }
    candidate.features = candidate.features or { version = FEATURE_VERSION, familyScores = {}, familyCount = 0 }
    candidate.score = candidate.score or {}
    candidate.score.familyScores = candidate.score.familyScores or {}
    candidate.score.reasons = candidate.score.reasons or {}
    candidate.score.status = candidate.score.status or candidate.score.tier or "Observing"
    candidate.score.statusCapReasons = candidate.score.statusCapReasons or {}
    ensureTriage(candidate)
end

local function markTriageChanged(reason)
    if BBT.UI and BBT.UI.MarkDirty then
        BBT.UI.MarkDirty(reason or "triage")
    end
end

local function refreshExistingCandidates()
    local settings = Storage.GetSettings()
    for _, realmCandidates in pairs(BigBotTrackerDB.candidates or {}) do
        for _, candidate in pairs(realmCandidates) do
            ensureCandidateShape(candidate)
            Scoring.Recalculate(candidate, settings)
        end
    end
end

local function ensureBaseline(realmKey, channelKey)
    BigBotTrackerDB.baselines = BigBotTrackerDB.baselines or { realms = {} }
    BigBotTrackerDB.baselines.realms = BigBotTrackerDB.baselines.realms or {}

    local realm = BigBotTrackerDB.baselines.realms[realmKey]
    if not realm then
        realm = { channels = {} }
        BigBotTrackerDB.baselines.realms[realmKey] = realm
    end

    realm.channels = realm.channels or {}
    local channel = realm.channels[channelKey]
    if not channel then
        channel = {
            sampleCount = 0,
            firstSeen = Util.GetNow(),
            lastSeen = Util.GetNow(),
            postsPerHourBins = {},
            regularityBins = {},
            templateReuseBins = {},
            burstBins = {},
        }
        realm.channels[channelKey] = channel
    end

    return channel
end

local function incrementBin(map, value, binSize)
    value = tonumber(value) or 0
    binSize = binSize or 5
    local bucket = math.floor((value + (binSize / 2)) / binSize) * binSize
    local key = tostring(bucket)
    map[key] = (map[key] or 0) + 1
end

local function percentileFromBins(map, value, sampleCount)
    value = tonumber(value) or 0
    sampleCount = tonumber(sampleCount) or 0
    if sampleCount <= 0 then
        return 0
    end

    local belowOrEqual = 0
    for bucket, count in pairs(map or {}) do
        if (tonumber(bucket) or 0) <= value then
            belowOrEqual = belowOrEqual + count
        end
    end

    return Util.Clamp((belowOrEqual / sampleCount) * 100, 0, 100)
end

local function mergeBaselineBins(target, source)
    for bucket, count in pairs(source or {}) do
        target[bucket] = (target[bucket] or 0) + count
    end
end

local function copyIfPresent(source, target, key)
    if type(source) == "table" and source[key] ~= nil then
        target[key] = Util.Clone(source[key])
    end
end

local function preserveSettings(previousSettings)
    local settings = Util.Clone(DEFAULT_DB.settings)
    if type(previousSettings) ~= "table" then
        return settings
    end

    copyIfPresent(previousSettings, settings, "debug")

    settings.sync = settings.sync or {}
    for _, key in ipairs({
        "enabled",
        "firstRunNoticeShown",
        "includeGuild",
        "includeGroup",
        "sendInterval",
        "candidateCooldown",
        "maxQueueSize",
        "maxCapsuleAgeSeconds",
    }) do
        copyIfPresent(previousSettings.sync, settings.sync, key)
    end
    settings.sync.channelName = nil
    settings.sync.prefix = nil

    settings.monitor = settings.monitor or {}
    for _, key in ipairs({ "public", "trade", "services" }) do
        copyIfPresent(previousSettings.monitor, settings.monitor, key)
    end

    settings.ui = settings.ui or {}
    for _, key in ipairs({ "sortKey", "sortDescending", "filterKey", "channelFilter" }) do
        copyIfPresent(previousSettings.ui, settings.ui, key)
    end

    return settings
end

local function detectPreviousFeatureVersion(previousDb)
    if type(previousDb) ~= "table" then
        return nil
    end
    if previousDb.featureVersion then
        return previousDb.featureVersion
    end
    for _, realmCandidates in pairs(previousDb.candidates or {}) do
        if type(realmCandidates) == "table" then
            for _, candidate in pairs(realmCandidates) do
                if type(candidate) == "table" then
                    if candidate.featureVersion then
                        return candidate.featureVersion
                    end
                    if candidate.features and candidate.features.version then
                        return candidate.features.version
                    end
                end
            end
        end
    end
    return nil
end

local function installFreshDb(previousDb)
    local previousSettings = type(previousDb) == "table" and previousDb.settings or nil
    local resetRecord
    if type(previousDb) == "table" then
        resetRecord = {
            previousSchemaVersion = previousDb.schemaVersion,
            previousFeatureVersion = detectPreviousFeatureVersion(previousDb),
            previousDataEpoch = previousDb.dataEpoch,
            resetAt = Util.GetNow(),
            dataEpoch = CURRENT_DATA_EPOCH,
            reason = DATA_RESET_REASON,
        }
    end

    BigBotTrackerDB = Util.Clone(DEFAULT_DB)
    BigBotTrackerDB.settings = preserveSettings(previousSettings)

    if resetRecord then
        BigBotTrackerDB.resetHistory = { resetRecord }
        BigBotTrackerDB._freshEvidenceCutoverNotice = true
    end
end

local function normalizeCurrentDb()
    Util.MergeDefaults(BigBotTrackerDB, DEFAULT_DB)
    BigBotTrackerDB.schemaVersion = SCHEMA_VERSION
    BigBotTrackerDB.featureVersion = FEATURE_VERSION
    BigBotTrackerDB.dataEpoch = CURRENT_DATA_EPOCH
    BigBotTrackerDB.resetHistory = BigBotTrackerDB.resetHistory or {}
    while #BigBotTrackerDB.resetHistory > 2 do
        table.remove(BigBotTrackerDB.resetHistory, 1)
    end
end

function Storage.Initialize()
    if type(BigBotTrackerDB) ~= "table" then
        installFreshDb(nil)
    elseif BigBotTrackerDB.dataEpoch ~= CURRENT_DATA_EPOCH then
        installFreshDb(BigBotTrackerDB)
    else
        normalizeCurrentDb()
    end

    normalizeCurrentDb()
    BigBotTrackerDB.settings.sync.channelName = nil
    BigBotTrackerDB.settings.sync.prefix = nil

    BBT.DB = BigBotTrackerDB
    BBT.runtime = BBT.runtime or {}
    BBT.runtime.pretrack = BBT.runtime.pretrack or {}
    BBT.runtime.recentNormalized = BBT.runtime.recentNormalized or {}
    BBT.runtime.seenLines = BBT.runtime.seenLines or {}
    BBT.runtime.baselineSampled = BBT.runtime.baselineSampled or {}
    if BigBotTrackerDB._freshEvidenceCutoverNotice then
        Storage.ClearRuntimeBuffers()
    end

    for _, realmCandidates in pairs(BigBotTrackerDB.candidates) do
        for _, candidate in pairs(realmCandidates) do
            ensureCandidateShape(candidate)
        end
    end

    refreshExistingCandidates()

    if BigBotTrackerDB._freshEvidenceCutoverNotice then
        BigBotTrackerDB._freshEvidenceCutoverNotice = nil
        Util.Print(
            "Big Bot Tracker started fresh for the updated evidence model. Older saved candidates and metrics were cleared."
        )
    end
end

function Storage.GetSettings()
    return BBT.DB and BBT.DB.settings or DEFAULT_DB.settings
end

function Storage.GetCurrentDataEpoch()
    return CURRENT_DATA_EPOCH
end

function Storage.GetCandidate(identity)
    if type(identity) == "string" then
        identity = Util.NormalizeIdentity(identity)
    end
    if not BBT.DB or not identity then
        return nil
    end

    local realm = BBT.DB.candidates[identity.realmKey]
    local candidate = realm and realm[identity.nameKey] or nil
    if candidate then
        ensureCandidateShape(candidate)
    end
    return candidate
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
    ensureCandidateShape(realm[identity.nameKey])
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

function Storage.GetCandidateTriage(candidate)
    if not candidate then
        return {
            watched = false,
            reported = false,
            ignored = false,
            reportOpenCount = 0,
        }
    end
    return ensureTriage(candidate)
end

function Storage.IsCandidateWatched(candidate)
    return candidate and ensureTriage(candidate).watched == true or false
end

function Storage.IsCandidateReported(candidate)
    return candidate and ensureTriage(candidate).reported == true or false
end

function Storage.IsCandidateIgnored(candidate)
    return candidate and ensureTriage(candidate).ignored == true or false
end

function Storage.IsCandidateHandled(candidate)
    if not candidate then
        return false
    end
    local triage = ensureTriage(candidate)
    return triage.reported == true or triage.ignored == true
end

function Storage.SetWatched(candidate, watched, now)
    if not candidate then
        return false
    end

    now = now or Util.GetNow()
    local triage = ensureTriage(candidate)
    local desired = watched == true
    if (triage.watched == true) == desired then
        return desired
    end

    triage.watched = desired and true or nil
    if desired then
        triage.watchedAt = now
        triage.watchedClearedAt = nil
    else
        triage.watchedClearedAt = now
    end
    markTriageChanged("watch")
    return desired
end

function Storage.ToggleWatched(candidate, now)
    return Storage.SetWatched(candidate, not Storage.IsCandidateWatched(candidate), now)
end

function Storage.MarkReported(candidate, now, fromReportOpen)
    if not candidate then
        return false
    end

    now = now or Util.GetNow()
    local triage = ensureTriage(candidate)
    if fromReportOpen then
        triage.reportOpenCount = (tonumber(triage.reportOpenCount) or 0) + 1
        triage.reportOpenedAt = now
    end
    triage.reported = true
    triage.reportedAt = now
    triage.reportedClearedAt = nil
    triage.ignored = nil
    markTriageChanged("reported")
    return true
end

function Storage.ClearReported(candidate, now)
    if not candidate then
        return false
    end

    now = now or Util.GetNow()
    local triage = ensureTriage(candidate)
    if triage.reported ~= true then
        return false
    end

    triage.reported = nil
    triage.reportedClearedAt = now
    markTriageChanged("reported-cleared")
    return true
end

function Storage.SetIgnored(candidate, ignored, now)
    if not candidate then
        return false
    end

    now = now or Util.GetNow()
    local triage = ensureTriage(candidate)
    local desired = ignored == true
    if (triage.ignored == true) == desired then
        return desired
    end

    triage.ignored = desired and true or nil
    if desired then
        triage.ignoredAt = now
        triage.ignoredClearedAt = nil
    else
        triage.ignoredClearedAt = now
    end
    markTriageChanged(desired and "ignored" or "ignored-cleared")
    return desired
end

function Storage.RecordBaselineSample(identity, channelKey, sample, now)
    if not BBT.DB or not identity or type(sample) ~= "table" then
        return
    end

    now = now or Util.GetNow()
    channelKey = channelKey or "unknown"
    local settings = Storage.GetSettings()
    local sampleKey = tostring(identity.fullKey or "unknown") .. ":" .. channelKey
    BBT.runtime = BBT.runtime or {}
    BBT.runtime.baselineSampled = BBT.runtime.baselineSampled or {}

    if
        BBT.runtime.baselineSampled[sampleKey]
        and now - BBT.runtime.baselineSampled[sampleKey] < (settings.baseline.sampleCooldown or 300)
    then
        return
    end
    BBT.runtime.baselineSampled[sampleKey] = now

    local baseline = ensureBaseline(identity.realmKey or "unknown", channelKey)
    baseline.sampleCount = (baseline.sampleCount or 0) + 1
    baseline.firstSeen = math.min(baseline.firstSeen or now, now)
    baseline.lastSeen = math.max(baseline.lastSeen or now, now)
    incrementBin(baseline.postsPerHourBins, sample.postsPerHour or 0, 5)
    incrementBin(baseline.regularityBins, sample.regularity or 0, 5)
    incrementBin(baseline.templateReuseBins, sample.templateReusePercent or 0, 10)
    incrementBin(baseline.burstBins, sample.burstCount or 0, 1)
end

function Storage.RecordCandidateBaselineSample(candidate, channelKey, now)
    if not candidate or (candidate.totalMessages or 0) < 3 then
        return
    end

    local identity = {
        fullKey = candidate.fullKey,
        realmKey = candidate.realmKey,
    }
    local timing = candidate.timing or {}
    local content = candidate.content or {}
    local behavior = candidate.behavior or {}
    local rate = behavior.postsPerHour or 0
    for _, summary in pairs(timing.windowSummaries or {}) do
        rate = math.max(rate, summary.postsPerHour or 0)
    end

    Storage.RecordBaselineSample(identity, channelKey or "unknown", {
        postsPerHour = rate,
        regularity = (1 - (timing.lowestRollingEntropy or 1)) * 100,
        templateReusePercent = math.max(content.templateReusePercent or 0, content.shingleReusePercent or 0),
        burstCount = behavior.burstCount or 0,
    }, now)
end

function Storage.RecordPretrackBaselineSample(identity, channelKey, entry, now)
    if not identity or not entry or #(entry.messages or {}) < 3 then
        return
    end

    now = now or Util.GetNow()
    local messages = entry.messages or {}
    local first = messages[1] and messages[1].timestamp or now
    local span = math.max(60, now - first)
    local rate = #messages / (span / 3600)
    local templateCounts = {}
    local topTemplateCount = 0
    local eligible = 0
    local intervalCounts = {}
    local intervalTotal = 0
    local settings = Storage.GetSettings()
    local bin = settings.timing.intervalBin or 10

    for index, message in ipairs(messages) do
        if (message.tokenCount or 0) >= (settings.promotion.minDuplicateTokens or 4) then
            local hash = message.hash or Normalizer.Hash(message.normalized)
            templateCounts[hash] = (templateCounts[hash] or 0) + 1
            if templateCounts[hash] > topTemplateCount then
                topTemplateCount = templateCounts[hash]
            end
            eligible = eligible + 1
        end

        if index > 1 then
            local interval = message.timestamp - messages[index - 1].timestamp
            if interval >= (settings.timing.minInterval or 5) and interval <= (settings.timing.maxInterval or 3600) then
                local bucket = Scoring.BucketInterval(interval, bin)
                intervalCounts[bucket] = (intervalCounts[bucket] or 0) + 1
                intervalTotal = intervalTotal + 1
            end
        end
    end

    local entropy = Scoring.CalculateEntropy(intervalCounts, intervalTotal)
    Storage.RecordBaselineSample(identity, channelKey or "unknown", {
        postsPerHour = rate,
        regularity = (1 - entropy) * 100,
        templateReusePercent = eligible > 0 and (topTemplateCount / eligible * 100) or 0,
        burstCount = entry.burstCount or 0,
    }, now)
end

function Storage.GetBaselineComparison(candidate)
    local result = {
        sampleCount = 0,
        postsPerHourPercentile = 0,
        regularityPercentile = 0,
        templateReusePercentile = 0,
        label = "Baseline warming up",
    }
    if not BBT.DB or not candidate then
        return result
    end

    local realm = BBT.DB.baselines
        and BBT.DB.baselines.realms
        and BBT.DB.baselines.realms[candidate.realmKey or "unknown"]
    if not realm or not realm.channels then
        return result
    end

    local merged = {
        sampleCount = 0,
        postsPerHourBins = {},
        regularityBins = {},
        templateReuseBins = {},
    }

    for channelKey in pairs(candidate.channels or {}) do
        local baseline = realm.channels[channelKey]
        if baseline then
            merged.sampleCount = merged.sampleCount + (baseline.sampleCount or 0)
            mergeBaselineBins(merged.postsPerHourBins, baseline.postsPerHourBins)
            mergeBaselineBins(merged.regularityBins, baseline.regularityBins)
            mergeBaselineBins(merged.templateReuseBins, baseline.templateReuseBins)
        end
    end

    if merged.sampleCount <= 0 then
        return result
    end

    local timing = candidate.timing or {}
    local content = candidate.content or {}
    local behavior = candidate.behavior or {}
    local rate = behavior.postsPerHour or 0
    for _, summary in pairs(timing.windowSummaries or {}) do
        rate = math.max(rate, summary.postsPerHour or 0)
    end
    local regularity = (1 - (timing.lowestRollingEntropy or 1)) * 100
    local reuse = math.max(content.templateReusePercent or 0, content.shingleReusePercent or 0)

    result.sampleCount = merged.sampleCount
    result.postsPerHourPercentile = percentileFromBins(merged.postsPerHourBins, rate, merged.sampleCount)
    result.regularityPercentile = percentileFromBins(merged.regularityBins, regularity, merged.sampleCount)
    result.templateReusePercentile = percentileFromBins(merged.templateReuseBins, reuse, merged.sampleCount)

    local best = math.max(result.postsPerHourPercentile, result.regularityPercentile, result.templateReusePercentile)
    local baselineSettings = Storage.GetSettings().baseline or {}
    local minSamples = baselineSettings.minSamples or 50
    if merged.sampleCount < minSamples then
        result.label = "Baseline warming up"
    elseif best >= 95 then
        result.label = "Above 95th percentile"
    elseif best >= 90 then
        result.label = "Above 90th percentile"
    else
        result.label = "Within current channel range"
    end

    return result
end

function Storage.IsHighVolumeOutlier(identity, channelKey, count, windowSeconds)
    local realm = BBT.DB
        and BBT.DB.baselines
        and BBT.DB.baselines.realms
        and BBT.DB.baselines.realms[identity and identity.realmKey or "unknown"]
    local baseline = realm and realm.channels and realm.channels[channelKey or "unknown"]
    if not baseline or (baseline.sampleCount or 0) < (Storage.GetSettings().baseline.minSamples or 50) then
        return false
    end

    local rate = (count or 0) / ((windowSeconds or 600) / 3600)
    return percentileFromBins(baseline.postsPerHourBins, rate, baseline.sampleCount) >= 90
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

    ensureCandidateShape(candidate)

    local now = observation.timestamp or Util.GetNow()
    local settings = Storage.GetSettings()
    local normalized = observation.normalized or Normalizer.NormalizeMessage(observation.text)
    local hash = observation.hash or Normalizer.Hash(normalized)
    local shingles = observation.shingles or Normalizer.ShingleSignature(normalized)
    local shingleKey = observation.shingleKey or Normalizer.SignatureKey(shingles, 4)
    local adIntent = observation.adIntent or Normalizer.DetectAdIntent(observation.text, normalized)
    local dateKey = Util.GetDateKey(now)
    local channelKey = observation.channelKey or "unknown"

    candidate.firstSeen = math.min(candidate.firstSeen or now, now)
    candidate.lastSeen = math.max(candidate.lastSeen or now, now)
    candidate.networkOnly = false
    candidate.daysSeen[dateKey] = true
    candidate.observationWindows[tostring(observationWindow(now))] = true
    candidate.channels[channelKey] = (candidate.channels[channelKey] or 0) + 1
    candidate.totalMessages = (candidate.totalMessages or 0) + 1
    if observation.guid and observation.guid ~= "" then
        candidate.lastGuid = observation.guid
        candidate.lastReportObservedAt = now
    end
    if observation.lineID ~= nil then
        candidate.lastLineID = observation.lineID
        candidate.lastReportObservedAt = now
    end

    updateTiming(candidate, now)
    updateBehavior(candidate, now)
    updateBurst(candidate, now)

    local content = candidate.content
    local messageLength = #(observation.text or "")
    content.templateCounts[hash] = (content.templateCounts[hash] or 0) + 1
    content.templateTotal = (content.templateTotal or 0) + 1
    if (observation.tokenCount or 0) >= (settings.promotion.minDuplicateTokens or 4) then
        content.eligibleMessageCount = (content.eligibleMessageCount or 0) + 1
    end
    content.messageLengthSum = (content.messageLengthSum or 0) + messageLength
    content.messageLengthSquareSum = (content.messageLengthSquareSum or 0) + (messageLength * messageLength)

    if shingleKey ~= "" then
        content.shingleCounts[shingleKey] = (content.shingleCounts[shingleKey] or 0) + 1
        content.shingleTotal = (content.shingleTotal or 0) + 1
        Util.PushLimited(content.recentShingleHashes, shingleKey, settings.storage.maxRecentShingles or 80)
    end

    if adIntent and adIntent.hasIntent then
        local categoryKey = adIntent.categoryKey or "unknown"
        content.adIntentCounts[categoryKey] = (content.adIntentCounts[categoryKey] or 0) + 1
        content.adIntentTotal = (content.adIntentTotal or 0) + 1
    end

    if
        observation.nearDuplicate
        or content.templateCounts[hash] > 1
        or (shingleKey ~= "" and content.shingleCounts[shingleKey] > 1)
    then
        content.nearDuplicateCount = (content.nearDuplicateCount or 0) + 1
    end
    if
        observation.nearDuplicateMethod == "shingle"
        and (observation.similarity or 0) >= (settings.promotion.shingleStrongThreshold or 0.72)
    then
        content.strongShingleMatchCount = (content.strongShingleMatchCount or 0) + 1
    end

    Util.PushLimited(content.recentHashes, hash, settings.storage.maxRecentHashes or 80)

    local template = ensureTemplate(BBT.DB, hash)
    template.count = template.count + 1
    template.lastSeen = now

    Scoring.Recalculate(candidate, settings)
    Storage.RecordCandidateBaselineSample(candidate, channelKey, now)

    if BBT.Sync and BBT.Sync.QueueCandidate then
        BBT.Sync.QueueCandidate(candidate)
    end

    if BBT.UI and BBT.UI.MarkDirty then
        BBT.UI.MarkDirty("observation")
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

    if BBT.UI and BBT.UI.MarkDirty then
        BBT.UI.MarkDirty("promotion")
    end

    return candidate
end

function Storage.CreateNetworkCandidate(fullName, firstSeen)
    local identity = Util.NormalizeIdentity(fullName)
    local candidate = Storage.GetOrCreateCandidate(identity, firstSeen or Util.GetNow(), "network")
    candidate.networkOnly = (candidate.totalMessages or 0) == 0
    return candidate
end

local function classifyNetworkOverlap(candidate, capsule)
    local localWindows = candidate.observationWindows or {}
    local firstWindow = capsule.firstWindow or observationWindow(capsule.firstSeen)
    local lastWindow = capsule.lastWindow or observationWindow(capsule.lastSeen)
    if not firstWindow or not lastWindow or lastWindow < firstWindow then
        return "Unknown"
    end

    if not next(localWindows) then
        return "Network only"
    end

    local total = 0
    local overlap = 0
    for window = firstWindow, lastWindow do
        total = total + 1
        if localWindows[tostring(window)] then
            overlap = overlap + 1
        end
    end

    if total == 0 then
        return "Unknown"
    end
    if overlap == 0 then
        return "Non-overlapping"
    end
    if overlap == total then
        return "Overlapping"
    end
    return "Partially overlapping"
end

function Storage.MergeNetworkEvidence(capsule)
    if type(capsule) ~= "table" or not capsule.fullName or not capsule.peerId then
        return nil, "malformed"
    end

    local now = Util.GetNow()
    local settings = Storage.GetSettings()
    if capsule.lastSeen and capsule.lastSeen > now + 3600 then
        return nil, "future"
    end
    if
        capsule.lastSeen
        and capsule.lastSeen > 0
        and now - capsule.lastSeen > (settings.sync.maxCapsuleAgeSeconds or 30 * 86400)
    then
        return nil, "stale"
    end
    if capsule.featureVersion and capsule.featureVersion > FEATURE_VERSION then
        return nil, "feature-version"
    end

    local candidate = Storage.CreateNetworkCandidate(capsule.fullName, capsule.firstSeen)
    candidate.network = candidate.network or { peers = {}, peerCount = 0 }
    local overlap = classifyNetworkOverlap(candidate, capsule)
    capsule.overlap = overlap

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
    local shingleReuseTotal = 0
    local postsPerHourTotal = 0
    local cadenceSwitchTotal = 0
    local overlapCounts = {}
    for _, peerCapsule in pairs(candidate.network.peers) do
        confidenceTotal = confidenceTotal + (peerCapsule.confidence or 0)
        messageTotal = messageTotal + (peerCapsule.messageCount or 0)
        rollingEntropyTotal = rollingEntropyTotal + (peerCapsule.rollingEntropy or 1)
        globalEntropyTotal = globalEntropyTotal + (peerCapsule.globalEntropy or 1)
        templateReuseTotal = templateReuseTotal + (peerCapsule.templateReusePercent or 0)
        shingleReuseTotal = shingleReuseTotal + (peerCapsule.shingleReusePercent or 0)
        postsPerHourTotal = postsPerHourTotal + (peerCapsule.postsPerHour or 0)
        cadenceSwitchTotal = cadenceSwitchTotal + (peerCapsule.cadenceSwitchCount or 0)
        overlapCounts[peerCapsule.overlap or "Unknown"] = (overlapCounts[peerCapsule.overlap or "Unknown"] or 0) + 1
        peerCount = peerCount + 1
    end
    candidate.network.peerCount = peerCount
    candidate.network.confidence = peerCount > 0 and confidenceTotal / peerCount or 0
    candidate.network.overlapCounts = overlapCounts
    candidate.network.overlap = overlapCounts["Non-overlapping"] and "Non-overlapping"
        or overlapCounts["Partially overlapping"] and "Partially overlapping"
        or overlapCounts["Overlapping"] and "Overlapping"
        or overlapCounts["Network only"] and "Network only"
        or "Unknown"
    candidate.network.summary = {
        messageCount = messageTotal,
        averageRollingEntropy = peerCount > 0 and rollingEntropyTotal / peerCount or 1,
        averageGlobalEntropy = peerCount > 0 and globalEntropyTotal / peerCount or 1,
        averageTemplateReusePercent = peerCount > 0 and templateReuseTotal / peerCount or 0,
        averageShingleReusePercent = peerCount > 0 and shingleReuseTotal / peerCount or 0,
        averagePostsPerHour = peerCount > 0 and postsPerHourTotal / peerCount or 0,
        cadenceSwitchCount = cadenceSwitchTotal,
    }

    local hadLocalEvidence = (candidate.totalMessages or 0) > 0
    local previousScore = hadLocalEvidence and Util.Clone(candidate.score or {}) or nil
    Scoring.Recalculate(candidate, Storage.GetSettings())
    if hadLocalEvidence and previousScore then
        candidate.score.localScore = previousScore.localScore or candidate.score.localScore
        candidate.score.displayScore = previousScore.displayScore
            or previousScore.localScore
            or candidate.score.displayScore
        candidate.score.networkAdjustedScore = previousScore.networkAdjustedScore
            or previousScore.displayScore
            or previousScore.localScore
            or candidate.score.networkAdjustedScore
        candidate.score.tier = previousScore.tier or candidate.score.tier
        candidate.score.status = previousScore.status or previousScore.tier or candidate.score.status
        candidate.score.statusCapReasons = previousScore.statusCapReasons or candidate.score.statusCapReasons
        candidate.score.confidence = previousScore.confidence or candidate.score.confidence
        candidate.score.evidenceFamilyCount = previousScore.evidenceFamilyCount or candidate.score.evidenceFamilyCount
        candidate.score.familyScores = previousScore.familyScores or candidate.score.familyScores
        candidate.score.reasons = previousScore.reasons or candidate.score.reasons
    end
    if BBT.UI and BBT.UI.MarkDirty then
        BBT.UI.MarkDirty("network")
    end
    return candidate, nil
end

function Storage.ClearRuntimeBuffers()
    if BBT.runtime then
        BBT.runtime.pretrack = {}
        BBT.runtime.recentNormalized = {}
        BBT.runtime.seenLines = {}
        BBT.runtime.baselineSampled = {}
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
    BBT.DB.baselines = { realms = {} }
    BBT.DB.peers = {}
    if BBT.DB.settings then
        BBT.DB.settings.lastDebugSummary = nil
    end
    Storage.ClearRuntimeBuffers()
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
        local baseline = candidate.baseline or {}
        rows[#rows + 1] = string.format(
            "%d. %s | status=%s patternStrength=%d localEvidence=%d families=%d messages=%d lastSeen=%s avgInterval=%ds reuse=%d%% shingle=%d%% baseline=%s peers=%d",
            index,
            candidate.displayName or "?",
            score.status or score.tier or "Observing",
            math.floor((score.networkAdjustedScore or 0) + 0.5),
            math.floor((score.confidence or 0) + 0.5),
            score.evidenceFamilyCount or 0,
            candidate.totalMessages or 0,
            Util.FormatTimestamp(candidate.lastSeen),
            math.floor((timing.averageInterval or 0) + 0.5),
            math.floor((content.templateReusePercent or 0) + 0.5),
            math.floor((content.shingleReusePercent or 0) + 0.5),
            baseline.label or "-",
            candidate.network and candidate.network.peerCount or 0
        )
    end

    return table.concat(rows, "\n")
end
