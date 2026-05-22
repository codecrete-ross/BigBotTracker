local addonName, BBT = ...
BBT = BBT or _G.BigBotTracker or {}
_G.BigBotTracker = BBT

BBT.Scoring = BBT.Scoring or {}

local Scoring = BBT.Scoring
local Util = BBT.Util

local LOG_2 = math.log(2)

local function log2(value)
    if value <= 0 then
        return 0
    end
    return math.log(value) / LOG_2
end

local function bucketInterval(seconds, binSize)
    binSize = binSize or 10
    return math.floor((seconds + (binSize / 2)) / binSize) * binSize
end

local function calculateAverage(values)
    if #values == 0 then
        return 0
    end

    local total = 0
    for _, value in ipairs(values) do
        total = total + value
    end
    return total / #values
end

local function calculateVariance(values, average)
    if #values <= 1 then
        return 0
    end

    local total = 0
    for _, value in ipairs(values) do
        local delta = value - average
        total = total + (delta * delta)
    end
    return total / (#values - 1)
end

local function calculateEntropyFromCounts(counts, total)
    if total <= 0 then
        return 1
    end

    local bucketCount = 0
    local entropy = 0

    for _, count in pairs(counts) do
        if count > 0 then
            bucketCount = bucketCount + 1
            local p = count / total
            entropy = entropy - (p * log2(p))
        end
    end

    if bucketCount <= 1 then
        return 0
    end

    return entropy / log2(bucketCount)
end

local function buildBucketSummary(intervalRecords, binSize)
    local counts = {}
    local total = 0
    for _, record in ipairs(intervalRecords or {}) do
        local bucket = record.b or bucketInterval(record.s or 0, binSize)
        counts[bucket] = (counts[bucket] or 0) + 1
        total = total + 1
    end

    local buckets = {}
    for bucket, count in pairs(counts) do
        buckets[#buckets + 1] = {
            bucket = bucket,
            count = count,
            percent = total > 0 and (count / total * 100) or 0,
        }
    end

    table.sort(buckets, function(left, right)
        if left.count == right.count then
            return left.bucket < right.bucket
        end
        return left.count > right.count
    end)

    return buckets, counts, total
end

local function calculateRollingEntropy(intervalRecords, windowSize, binSize)
    local count = #intervalRecords
    if count < 2 then
        return 1
    end

    local startIndex = math.max(1, count - windowSize + 1)
    local counts = {}
    local total = 0

    for index = startIndex, count do
        local record = intervalRecords[index]
        local bucket = record.b or bucketInterval(record.s or 0, binSize)
        counts[bucket] = (counts[bucket] or 0) + 1
        total = total + 1
    end

    return calculateEntropyFromCounts(counts, total)
end

local function buildCadencePhases(intervalRecords, minPhaseLength)
    local phases = {}
    minPhaseLength = minPhaseLength or 3

    local currentBucket
    local phaseStart
    local phaseCount = 0
    local phaseFirstTime
    local phaseLastTime

    local function flush()
        if currentBucket and phaseCount >= minPhaseLength then
            phases[#phases + 1] = {
                bucket = currentBucket,
                count = phaseCount,
                startTime = phaseFirstTime,
                endTime = phaseLastTime,
            }
        end
    end

    for index, record in ipairs(intervalRecords or {}) do
        local bucket = record.b
        if bucket == currentBucket then
            phaseCount = phaseCount + 1
            phaseLastTime = record.t
        else
            flush()
            currentBucket = bucket
            phaseStart = index
            phaseCount = 1
            phaseFirstTime = (record.t or 0) - (record.s or 0)
            phaseLastTime = record.t
        end
    end

    flush()

    local switches = 0
    local lastBucket
    for _, phase in ipairs(phases) do
        if lastBucket and lastBucket ~= phase.bucket then
            switches = switches + 1
        end
        lastBucket = phase.bucket
    end

    return phases, switches
end

local function classifyConsistency(coefficientVariation, rollingEntropy, topBucketPercent)
    if topBucketPercent >= 75 and rollingEntropy <= 0.25 and coefficientVariation <= 0.12 then
        return "Very Regular"
    end
    if topBucketPercent >= 55 and rollingEntropy <= 0.45 and coefficientVariation <= 0.25 then
        return "Regular"
    end
    if topBucketPercent >= 40 or rollingEntropy <= 0.65 then
        return "Some Pattern"
    end
    return "Variable"
end

function Scoring.BucketInterval(seconds, binSize)
    return bucketInterval(seconds, binSize)
end

function Scoring.CalculateEntropy(counts, total)
    return calculateEntropyFromCounts(counts, total)
end

function Scoring.UpdateMetrics(candidate, settings)
    settings = settings or {}
    local timingSettings = settings.timing or {}
    local intervalBin = timingSettings.intervalBin or 10
    local intervals = candidate.timing and candidate.timing.intervals or {}
    local intervalValues = {}

    for _, record in ipairs(intervals) do
        intervalValues[#intervalValues + 1] = record.s or 0
        record.b = record.b or bucketInterval(record.s or 0, intervalBin)
    end

    local average = calculateAverage(intervalValues)
    local variance = calculateVariance(intervalValues, average)
    local coefficientVariation = average > 0 and (math.sqrt(variance) / average) or 1
    local buckets, bucketCounts, intervalCount = buildBucketSummary(intervals, intervalBin)
    local globalEntropy = calculateEntropyFromCounts(bucketCounts, intervalCount)

    local rolling = {}
    local rollingWindows = timingSettings.rollingWindows or { 5, 10, 20 }
    local lowestRollingEntropy = 1
    for _, windowSize in ipairs(rollingWindows) do
        local entropy = calculateRollingEntropy(intervals, windowSize, intervalBin)
        rolling["w" .. tostring(windowSize)] = entropy
        if entropy < lowestRollingEntropy then
            lowestRollingEntropy = entropy
        end
    end

    local phases, cadenceSwitches = buildCadencePhases(intervals, timingSettings.minPhaseLength or 3)
    local topBucketPercent = buckets[1] and buckets[1].percent or 0

    candidate.timing.averageInterval = average
    candidate.timing.intervalVariance = variance
    candidate.timing.coefficientVariation = coefficientVariation
    candidate.timing.globalEntropy = globalEntropy
    candidate.timing.rollingEntropy = rolling
    candidate.timing.lowestRollingEntropy = lowestRollingEntropy
    candidate.timing.dominantBuckets = buckets
    candidate.timing.cadencePhases = phases
    candidate.timing.cadenceSwitchCount = cadenceSwitches
    candidate.timing.intervalConsistency =
        classifyConsistency(coefficientVariation, lowestRollingEntropy, topBucketPercent)

    local content = candidate.content or {}
    local templateTotal = content.templateTotal or candidate.totalMessages or 0
    local topTemplateCount = 0
    local uniqueTemplates = 0

    for _, count in pairs(content.templateCounts or {}) do
        uniqueTemplates = uniqueTemplates + 1
        if count > topTemplateCount then
            topTemplateCount = count
        end
    end

    content.uniqueTemplateCount = uniqueTemplates
    content.templateReusePercent = templateTotal > 0 and (topTemplateCount / templateTotal * 100) or 0
    content.uniqueTemplateRatio = templateTotal > 0 and (uniqueTemplates / templateTotal) or 0

    candidate.content = content

    local now = Util.GetNow()
    local firstSeen = candidate.firstSeen or now
    local lastSeen = candidate.lastSeen or now
    candidate.behavior = candidate.behavior or {}
    candidate.behavior.activeSpan = math.max(0, lastSeen - firstSeen)
    candidate.behavior.postsPerHour = candidate.behavior.activeSpan > 0
            and ((candidate.totalMessages or 0) / (candidate.behavior.activeSpan / 3600))
        or (candidate.totalMessages or 0)
end

local function addReason(reasons, text)
    if #reasons < 5 then
        reasons[#reasons + 1] = text
    end
end

local function calculateConfidence(candidate)
    local messageCount = candidate.totalMessages or 0
    local intervalCount = candidate.timing and candidate.timing.intervalCount or 0
    local dayCount = Util.CountMap(candidate.daysSeen)
    local peerCount = candidate.network and candidate.network.peerCount or 0
    local networkSummary = candidate.network and candidate.network.summary or {}

    local confidence = 0
    confidence = confidence + math.min(messageCount / 12, 1) * 30
    confidence = confidence + math.min(intervalCount / 8, 1) * 30
    confidence = confidence + math.min(dayCount / 3, 1) * 15
    confidence = confidence + math.min(peerCount / 3, 1) * 15
    if peerCount >= 2 then
        confidence = confidence + math.min((networkSummary.messageCount or 0) / 30, 1) * 20
    end

    return Util.Clamp(confidence, 0, 100)
end

local function getTier(score, confidence)
    if confidence < 35 then
        return "Insufficient Data"
    end
    if score >= 85 then
        return "Critical"
    end
    if score >= 70 then
        return "High"
    end
    if score >= 45 then
        return "Medium"
    end
    if score >= 20 then
        return "Low"
    end
    return "Insufficient Data"
end

local function getRecencyFactor(candidate)
    local lastSeen = candidate.lastSeen or Util.GetNow()
    local age = math.max(0, Util.GetNow() - lastSeen)
    local gracePeriod = 7 * 86400
    local fullDecayWindow = 53 * 86400

    if age <= gracePeriod then
        return 1
    end

    local decayProgress = math.min(1, (age - gracePeriod) / fullDecayWindow)
    return math.max(0.55, 1 - (decayProgress * 0.45))
end

function Scoring.Recalculate(candidate, settings)
    if type(candidate) ~= "table" then
        return nil
    end

    settings = settings or {}
    Scoring.UpdateMetrics(candidate, settings)

    local score = 0
    local reasons = {}
    local timing = candidate.timing or {}
    local content = candidate.content or {}
    local behavior = candidate.behavior or {}
    local network = candidate.network or {}
    local networkSummary = network.summary or {}

    local intervalCount = timing.intervalCount or #(timing.intervals or {})
    local topBucket = timing.dominantBuckets and timing.dominantBuckets[1]
    local topBucketPercent = topBucket and topBucket.percent or 0
    local rollingEntropy = timing.lowestRollingEntropy or 1
    local globalEntropy = timing.globalEntropy or 1
    local cv = timing.coefficientVariation or 1

    if intervalCount >= 4 then
        if rollingEntropy <= 0.20 then
            score = score + 16
            addReason(reasons, "Recent posting windows have very low interval entropy.")
        elseif rollingEntropy <= 0.40 then
            score = score + 11
            addReason(reasons, "Recent posting windows show regular timing.")
        elseif rollingEntropy <= 0.60 then
            score = score + 6
        end

        if topBucketPercent >= 75 then
            score = score + 12
            addReason(
                reasons,
                string.format(
                    "%d%% of intervals fall near %ds.",
                    math.floor(topBucketPercent + 0.5),
                    topBucket.bucket or 0
                )
            )
        elseif topBucketPercent >= 55 then
            score = score + 8
            addReason(
                reasons,
                string.format("%d%% of intervals share one cadence.", math.floor(topBucketPercent + 0.5))
            )
        end

        if cv <= 0.08 then
            score = score + 8
            addReason(
                reasons,
                string.format(
                    "Average interval %ds with very low variation.",
                    math.floor((timing.averageInterval or 0) + 0.5)
                )
            )
        elseif cv <= 0.18 then
            score = score + 5
        end

        if globalEntropy <= 0.35 then
            score = score + 5
        end

        if (timing.cadenceSwitchCount or 0) > 0 and rollingEntropy <= 0.45 then
            score = score + math.min(6, timing.cadenceSwitchCount * 3)
            addReason(reasons, "Cadence changed between stable posting schedules.")
        end
    end

    local templateReuse = content.templateReusePercent or 0
    if (candidate.totalMessages or 0) >= 3 then
        if templateReuse >= 80 then
            score = score + 18
            addReason(
                reasons,
                string.format("%d%% of messages match the top template.", math.floor(templateReuse + 0.5))
            )
        elseif templateReuse >= 60 then
            score = score + 13
            addReason(reasons, "Most messages reuse the same template.")
        elseif templateReuse >= 40 then
            score = score + 7
        end

        local nearDuplicateRate = (candidate.totalMessages or 0) > 0
                and ((content.nearDuplicateCount or 0) / candidate.totalMessages * 100)
            or 0
        if nearDuplicateRate >= 60 then
            score = score + 10
            addReason(reasons, string.format("%d near-duplicate messages observed.", content.nearDuplicateCount or 0))
        elseif nearDuplicateRate >= 30 then
            score = score + 5
        end
    end

    if (behavior.activeSpan or 0) >= 3600 then
        score = score + 8
        addReason(reasons, "Posting pattern spans more than an hour.")
    elseif (behavior.activeSpan or 0) >= 1800 then
        score = score + 5
    end

    if (behavior.postsPerHour or 0) >= 20 then
        score = score + 6
        addReason(reasons, string.format("%.1f posts per hour observed.", behavior.postsPerHour or 0))
    elseif (behavior.postsPerHour or 0) >= 10 then
        score = score + 3
    end

    local dayCount = Util.CountMap(candidate.daysSeen)
    if dayCount >= 3 then
        score = score + 8
        addReason(reasons, string.format("Observed on %d separate days.", dayCount))
    elseif dayCount >= 2 then
        score = score + 4
    end

    if (behavior.burstCount or 0) >= 2 then
        score = score + 4
        addReason(reasons, string.format("%d burst windows detected.", behavior.burstCount or 0))
    end

    local peerCount = network.peerCount or 0
    local networkBonus = math.min(12, peerCount * 4)
    if peerCount >= 2 then
        if (networkSummary.averageRollingEntropy or 1) <= 0.40 then
            networkBonus = networkBonus + 4
        end
        if (networkSummary.averageTemplateReusePercent or 0) >= 60 then
            networkBonus = networkBonus + 4
        end
        if (networkSummary.messageCount or 0) >= 20 then
            networkBonus = networkBonus + 3
        end
        if (networkSummary.cadenceSwitchCount or 0) > 0 then
            networkBonus = networkBonus + 2
        end
    end
    networkBonus = math.min(24, networkBonus)
    if peerCount >= 2 then
        addReason(reasons, string.format("Seen by %d peers in the sync channel.", peerCount))
    end

    local recencyFactor = getRecencyFactor(candidate)
    if recencyFactor < 1 then
        score = score * recencyFactor
        networkBonus = networkBonus * recencyFactor
        addReason(reasons, "Older evidence has been decayed in the score.")
    end

    local confidence = calculateConfidence(candidate)
    local localScore = Util.Clamp(score, 0, 100)
    local networkAdjustedScore = Util.Clamp(score + networkBonus, 0, 100)

    candidate.score = {
        localScore = localScore,
        networkAdjustedScore = networkAdjustedScore,
        tier = getTier(networkAdjustedScore, confidence),
        confidence = confidence,
        reasons = reasons,
        updatedAt = Util.GetNow(),
    }

    return candidate.score
end
