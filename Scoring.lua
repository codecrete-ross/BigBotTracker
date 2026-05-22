local addonName, BBT = ...
BBT = BBT or _G.BigBotTracker or {}
_G.BigBotTracker = BBT

BBT.Scoring = BBT.Scoring or {}

local Scoring = BBT.Scoring
local Util = BBT.Util

local FEATURE_VERSION = 3
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

local function sortedCopy(values)
    local copy = {}
    for _, value in ipairs(values or {}) do
        copy[#copy + 1] = tonumber(value) or 0
    end
    table.sort(copy)
    return copy
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

local function calculatePercentile(values, percentile)
    values = sortedCopy(values)
    if #values == 0 then
        return 0
    end
    if #values == 1 then
        return values[1]
    end

    local rank = (percentile / 100) * (#values - 1) + 1
    local lower = math.floor(rank)
    local upper = math.ceil(rank)
    if lower == upper then
        return values[lower]
    end

    local fraction = rank - lower
    return values[lower] + ((values[upper] - values[lower]) * fraction)
end

local function calculateMedian(values)
    return calculatePercentile(values, 50)
end

local function calculateRobustStats(values)
    values = values or {}
    if #values == 0 then
        return {
            median = 0,
            mad = 0,
            iqr = 0,
            robustCoefficientVariation = 1,
        }
    end

    local median = calculateMedian(values)
    local deviations = {}
    for _, value in ipairs(values) do
        deviations[#deviations + 1] = math.abs(value - median)
    end

    local mad = calculateMedian(deviations)
    local q1 = calculatePercentile(values, 25)
    local q3 = calculatePercentile(values, 75)
    local scaledMad = mad * 1.4826
    local robustCoefficientVariation = median > 0 and (scaledMad / median) or 1

    return {
        median = median,
        mad = mad,
        iqr = math.max(0, q3 - q1),
        robustCoefficientVariation = robustCoefficientVariation,
    }
end

local function calculateEntropyFromCounts(counts, total)
    if total <= 0 then
        return 1
    end

    local bucketCount = 0
    local entropy = 0

    for _, count in pairs(counts or {}) do
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
                duration = math.max(0, (phaseLastTime or 0) - (phaseFirstTime or 0)),
            }
        end
    end

    for _, record in ipairs(intervalRecords or {}) do
        local bucket = record.b
        if bucket == currentBucket then
            phaseCount = phaseCount + 1
            phaseLastTime = record.t
        else
            flush()
            currentBucket = bucket
            phaseCount = 1
            phaseFirstTime = (record.t or 0) - (record.s or 0)
            phaseLastTime = record.t
        end
    end

    flush()

    local switches = 0
    local lastBucket
    local totalDuration = 0
    for _, phase in ipairs(phases) do
        if lastBucket and lastBucket ~= phase.bucket then
            switches = switches + 1
        end
        totalDuration = totalDuration + (phase.duration or 0)
        lastBucket = phase.bucket
    end

    return phases, switches, totalDuration
end

local function buildWindowSummary(intervalRecords, windowSeconds, binSize, anchorTime)
    local records = {}
    local values = {}
    anchorTime = anchorTime or 0

    for _, record in ipairs(intervalRecords or {}) do
        if anchorTime <= 0 or anchorTime - (record.t or 0) <= windowSeconds then
            records[#records + 1] = record
            values[#values + 1] = record.s or 0
        end
    end

    local buckets, counts, intervalCount = buildBucketSummary(records, binSize)
    local robust = calculateRobustStats(values)
    local messageCount = intervalCount > 0 and intervalCount + 1 or 0

    return {
        seconds = windowSeconds,
        intervalCount = intervalCount,
        messageCount = messageCount,
        entropy = calculateEntropyFromCounts(counts, intervalCount),
        topBucket = buckets[1] and buckets[1].bucket or 0,
        topBucketPercent = buckets[1] and buckets[1].percent or 0,
        medianInterval = robust.median,
        robustCoefficientVariation = robust.robustCoefficientVariation,
        postsPerHour = windowSeconds > 0 and (messageCount / (windowSeconds / 3600)) or 0,
    }
end

local function classifyCadence(timing, behavior)
    local intervalCount = timing.intervalCount or 0
    local buckets = timing.dominantBuckets or {}
    local topBucket = buckets[1]
    local topBucketPercent = topBucket and (topBucket.percent or 0) or 0
    local rollingEntropy = timing.lowestRollingEntropy or 1
    local robustCv = timing.robustCoefficientVariation or 1
    local cadenceSwitches = timing.cadenceSwitchCount or 0
    local phaseCount = #(timing.cadencePhases or {})

    if intervalCount < 3 then
        return "Sparse"
    end
    if cadenceSwitches > 0 and phaseCount >= 2 then
        return "Mixed Regular"
    end
    if topBucketPercent >= 75 and rollingEntropy <= 0.25 and robustCv <= 0.16 then
        return "Fixed Cadence"
    end
    if
        (topBucketPercent >= 60 and rollingEntropy <= 0.45 and robustCv <= 0.35)
        or (topBucketPercent >= 35 and robustCv <= 0.18)
    then
        return "Jittered Cadence"
    end
    if
        (behavior and (behavior.burstCount or 0) > 0)
        and (behavior.activeSpan or 0) <= 600
        and topBucketPercent < 55
    then
        return "Burst-Only"
    end
    return "Variable"
end

local function addWeightedReason(reasons, weight, text)
    if text and text ~= "" then
        reasons[#reasons + 1] = {
            weight = weight or 0,
            text = text,
        }
    end
end

local function finalizeReasons(reasons)
    table.sort(reasons, function(left, right)
        if left.weight == right.weight then
            return left.text < right.text
        end
        return left.weight > right.weight
    end)

    local finalized = {}
    for index = 1, math.min(5, #reasons) do
        finalized[index] = reasons[index].text
    end
    return finalized
end

local function calculateNetworkContext(network)
    network = network or {}
    local peerCount = network.peerCount or 0
    local summary = network.summary or {}
    local score = math.min(12, peerCount * 4)

    if peerCount >= 2 then
        if (summary.averageRollingEntropy or 1) <= 0.40 then
            score = score + 8
        end
        if (summary.averageTemplateReusePercent or 0) >= 60 then
            score = score + 8
        end
        if (summary.messageCount or 0) >= 20 then
            score = score + 6
        end
        if (summary.cadenceSwitchCount or 0) > 0 then
            score = score + 3
        end
        if (summary.averagePostsPerHour or 0) >= 10 then
            score = score + 3
        end
    end

    local confidence = network.confidence or 0
    if peerCount > 0 then
        confidence = math.max(confidence, math.min(peerCount / 3, 1) * 30)
    end

    return {
        score = Util.Clamp(score, 0, 44),
        confidence = Util.Clamp(confidence, 0, 100),
    }
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

local function countEvidenceFamilies(familyScores)
    local count = 0
    if (familyScores.timing or 0) >= 8 then
        count = count + 1
    end
    if (familyScores.content or 0) >= 8 then
        count = count + 1
    end
    if (familyScores.activity or 0) >= 6 then
        count = count + 1
    end
    if (familyScores.persistence or 0) >= 4 then
        count = count + 1
    end
    if (familyScores.baseline or 0) >= 5 then
        count = count + 1
    end
    return count
end

local function calculateConfidence(candidate, familyCount)
    local messageCount = candidate.totalMessages or 0
    local timing = candidate.timing or {}
    local intervalCount = timing.intervalCount or 0
    local dayCount = Util.CountMap(candidate.daysSeen)
    local activeWindows = 0

    for _, summary in pairs(timing.windowSummaries or {}) do
        if (summary.messageCount or 0) >= 3 then
            activeWindows = activeWindows + 1
        end
    end

    local confidence = 0
    confidence = confidence + math.min(messageCount / 18, 1) * 30
    confidence = confidence + math.min(intervalCount / 12, 1) * 28
    confidence = confidence + math.min(activeWindows / 3, 1) * 14
    confidence = confidence + math.min(dayCount / 3, 1) * 16
    confidence = confidence + math.min((familyCount or 0) / 3, 1) * 12

    return Util.Clamp(confidence, 0, 100)
end

local function getTier(score, confidence, familyCount, familyScores, hasMeaningfulEvidence)
    if not hasMeaningfulEvidence then
        return "Insufficient Data"
    end

    local strongTimingAndContent = (familyScores.timing or 0) >= 30 and (familyScores.content or 0) >= 25
    if score >= 85 and confidence >= 70 and (familyCount >= 3 or strongTimingAndContent) then
        return "Critical"
    end
    if score >= 70 and confidence >= 55 and familyCount >= 2 then
        return "High"
    end
    if score >= 45 and confidence >= 35 and familyCount >= 1 then
        return "Medium"
    end
    if score >= 20 then
        return "Low"
    end
    return "Insufficient Data"
end

local function scoreTiming(candidate, reasons)
    local timing = candidate.timing or {}
    local intervalCount = timing.intervalCount or 0
    if intervalCount < 4 then
        return 0
    end

    local score = 0
    local topBucket = timing.dominantBuckets and timing.dominantBuckets[1]
    local topBucketPercent = topBucket and (topBucket.percent or 0) or 0
    local rollingEntropy = timing.lowestRollingEntropy or 1
    local robustCv = timing.robustCoefficientVariation or 1
    local cadenceClass = timing.cadenceClass or "Variable"

    if cadenceClass == "Fixed Cadence" then
        score = score + 15
        addWeightedReason(reasons, 15, "Timing matches a fixed posting cadence.")
    elseif cadenceClass == "Jittered Cadence" then
        score = score + 11
        addWeightedReason(reasons, 11, "Timing looks jittered but still cadence-bound.")
    elseif cadenceClass == "Mixed Regular" then
        score = score + 12
        addWeightedReason(reasons, 12, "Cadence changed between stable posting schedules.")
    end

    if topBucketPercent >= 75 then
        score = score + 8
        addWeightedReason(
            reasons,
            8,
            string.format("%d%% of intervals fall near %ds.", math.floor(topBucketPercent + 0.5), topBucket.bucket or 0)
        )
    elseif topBucketPercent >= 60 then
        score = score + 5
        addWeightedReason(reasons, 5, string.format("%d%% of intervals share one cadence.", topBucketPercent))
    end

    if rollingEntropy <= 0.20 then
        score = score + 7
        addWeightedReason(reasons, 7, "Recent posting windows have very low interval entropy.")
    elseif rollingEntropy <= 0.40 then
        score = score + 4
    end

    if robustCv <= 0.12 then
        score = score + 5
        addWeightedReason(
            reasons,
            5,
            string.format(
                "Median interval %ds with very low robust variation.",
                math.floor((timing.medianInterval or 0) + 0.5)
            )
        )
    elseif robustCv <= 0.25 then
        score = score + 3
    end

    if (timing.cadencePhaseDuration or 0) >= 600 then
        score = score + 3
    end

    return Util.Clamp(score, 0, 35)
end

local function scoreContent(candidate, reasons)
    local content = candidate.content or {}
    local messageCount = candidate.totalMessages or 0
    if messageCount < 3 then
        return 0
    end

    local score = 0
    local templateReuse = content.templateReusePercent or 0
    local shingleReuse = content.shingleReusePercent or 0
    local nearDuplicateRate = messageCount > 0 and ((content.nearDuplicateCount or 0) / messageCount * 100) or 0
    local intentRepeat = content.dominantIntentPercent or 0

    if templateReuse >= 80 then
        score = score + 13
        addWeightedReason(reasons, 13, string.format("%d%% of local messages reuse the same text pattern.", templateReuse))
    elseif templateReuse >= 60 then
        score = score + 9
        addWeightedReason(reasons, 9, "Most messages reuse the same exact template.")
    elseif templateReuse >= 40 then
        score = score + 5
    end

    if shingleReuse >= 75 then
        score = score + 10
        addWeightedReason(reasons, 10, "Similar ad wording clusters even when text is rearranged.")
    elseif shingleReuse >= 55 then
        score = score + 6
    end

    if nearDuplicateRate >= 60 then
        score = score + 5
        addWeightedReason(
            reasons,
            5,
            string.format("%d near-duplicate messages observed.", content.nearDuplicateCount or 0)
        )
    elseif nearDuplicateRate >= 30 then
        score = score + 3
    end

    if intentRepeat >= 75 and (content.adIntentTotal or 0) >= 3 then
        score = score + 4
    end

    return Util.Clamp(score, 0, 30)
end

local function scoreActivity(candidate, reasons)
    local behavior = candidate.behavior or {}
    local timing = candidate.timing or {}
    local score = 0
    local rate = behavior.postsPerHour or 0

    for _, summary in pairs(timing.windowSummaries or {}) do
        rate = math.max(rate, summary.postsPerHour or 0)
    end

    if rate >= 60 then
        score = score + 10
        addWeightedReason(reasons, 10, string.format("Peak active-window rate was %.1f posts/hour.", rate))
    elseif rate >= 30 then
        score = score + 7
        addWeightedReason(reasons, 7, string.format("Posting rate was %.1f posts/hour.", rate))
    elseif rate >= 15 then
        score = score + 4
    end

    if (behavior.burstCount or 0) >= 2 then
        score = score + 6
        addWeightedReason(reasons, 6, string.format("%d burst windows detected.", behavior.burstCount or 0))
    elseif (behavior.burstCount or 0) == 1 then
        score = score + 3
    end

    if (behavior.longestActiveSpan or 0) >= 1800 then
        score = score + 4
    end

    return Util.Clamp(score, 0, 20)
end

local function scorePersistence(candidate, reasons)
    local score = 0
    local dayCount = Util.CountMap(candidate.daysSeen)
    local behavior = candidate.behavior or {}

    if dayCount >= 3 then
        score = score + 6
        addWeightedReason(reasons, 6, string.format("Observed on %d separate days.", dayCount))
    elseif dayCount >= 2 then
        score = score + 4
    end

    if (behavior.activeSpan or 0) >= 3600 then
        score = score + 4
        addWeightedReason(reasons, 4, "Posting pattern spans more than an hour.")
    elseif (behavior.activeSpan or 0) >= 1800 then
        score = score + 2
    end

    return Util.Clamp(score, 0, 10)
end

local function scoreBaseline(candidate, reasons)
    local baseline = candidate.baseline or {}
    if (baseline.sampleCount or 0) < 8 then
        return 0
    end

    local score = 0
    local ratePercentile = baseline.postsPerHourPercentile or 0
    local regularityPercentile = baseline.regularityPercentile or 0
    local reusePercentile = baseline.templateReusePercentile or 0

    if regularityPercentile >= 95 then
        score = score + 6
        addWeightedReason(reasons, 6, "Timing regularity is above the 95th percentile for the local channel baseline.")
    elseif regularityPercentile >= 90 then
        score = score + 4
    end

    if ratePercentile >= 95 then
        score = score + 5
        addWeightedReason(reasons, 5, "Posting rate is unusually high for the local channel baseline.")
    elseif ratePercentile >= 90 then
        score = score + 3
    end

    if reusePercentile >= 95 then
        score = score + 4
    elseif reusePercentile >= 90 then
        score = score + 2
    end

    return Util.Clamp(score, 0, 15)
end

function Scoring.BucketInterval(seconds, binSize)
    return bucketInterval(seconds, binSize)
end

function Scoring.CalculateEntropy(counts, total)
    return calculateEntropyFromCounts(counts, total)
end

function Scoring.CalculateRobustStats(values)
    return calculateRobustStats(values)
end

function Scoring.UpdateMetrics(candidate, settings)
    settings = settings or {}
    local timingSettings = settings.timing or {}
    local intervalBin = timingSettings.intervalBin or 10
    local intervals = candidate.timing and candidate.timing.intervals or {}
    local intervalValues = {}

    candidate.featureVersion = FEATURE_VERSION
    candidate.timing = candidate.timing or {}
    candidate.content = candidate.content or {}
    candidate.behavior = candidate.behavior or {}

    for _, record in ipairs(intervals) do
        intervalValues[#intervalValues + 1] = record.s or 0
        record.b = record.b or bucketInterval(record.s or 0, intervalBin)
    end

    local average = calculateAverage(intervalValues)
    local variance = calculateVariance(intervalValues, average)
    local robust = calculateRobustStats(intervalValues)
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

    local phases, cadenceSwitches, cadencePhaseDuration =
        buildCadencePhases(intervals, timingSettings.minPhaseLength or 3)
    local anchorTime = candidate.lastSeen or Util.GetNow()
    local windowSummaries = {}
    for _, seconds in ipairs(timingSettings.featureWindows or { 600, 1800, 7200 }) do
        windowSummaries["w" .. tostring(seconds)] = buildWindowSummary(intervals, seconds, intervalBin, anchorTime)
    end

    local timing = candidate.timing
    timing.averageInterval = average
    timing.intervalVariance = variance
    timing.coefficientVariation = coefficientVariation
    timing.medianInterval = robust.median
    timing.madInterval = robust.mad
    timing.iqrInterval = robust.iqr
    timing.robustCoefficientVariation = robust.robustCoefficientVariation
    timing.globalEntropy = globalEntropy
    timing.rollingEntropy = rolling
    timing.lowestRollingEntropy = lowestRollingEntropy
    timing.dominantBuckets = buckets
    timing.cadencePhases = phases
    timing.cadenceSwitchCount = cadenceSwitches
    timing.cadencePhaseDuration = cadencePhaseDuration
    timing.windowSummaries = windowSummaries
    timing.cadenceClass = classifyCadence(timing, candidate.behavior)
    timing.intervalConsistency = timing.cadenceClass

    local content = candidate.content
    local templateTotal = content.templateTotal or candidate.totalMessages or 0
    local topTemplateCount = 0
    local uniqueTemplates = 0
    for _, count in pairs(content.templateCounts or {}) do
        uniqueTemplates = uniqueTemplates + 1
        if count > topTemplateCount then
            topTemplateCount = count
        end
    end

    local topShingleCount = 0
    local uniqueShingles = 0
    for _, count in pairs(content.shingleCounts or {}) do
        uniqueShingles = uniqueShingles + 1
        if count > topShingleCount then
            topShingleCount = count
        end
    end

    local topIntentCount = 0
    for _, count in pairs(content.adIntentCounts or {}) do
        if count > topIntentCount then
            topIntentCount = count
        end
    end

    content.uniqueTemplateCount = uniqueTemplates
    content.templateReusePercent = templateTotal > 0 and (topTemplateCount / templateTotal * 100) or 0
    content.uniqueTemplateRatio = templateTotal > 0 and (uniqueTemplates / templateTotal) or 0
    content.uniqueShingleCount = uniqueShingles
    content.shingleReusePercent = (content.shingleTotal or 0) > 0 and (topShingleCount / content.shingleTotal * 100)
        or 0
    content.dominantIntentPercent = (content.adIntentTotal or 0) > 0 and (topIntentCount / content.adIntentTotal * 100)
        or 0

    local now = Util.GetNow()
    local firstSeen = candidate.firstSeen or now
    local lastSeen = candidate.lastSeen or now
    local behavior = candidate.behavior
    behavior.activeSpan = math.max(0, lastSeen - firstSeen)
    behavior.postsPerHour = behavior.activeSpan > 0 and ((candidate.totalMessages or 0) / (behavior.activeSpan / 3600))
        or (candidate.totalMessages or 0)

    if BBT.Storage and BBT.Storage.GetBaselineComparison then
        candidate.baseline = BBT.Storage.GetBaselineComparison(candidate)
    end
end

function Scoring.HasMeaningfulLocalEvidence(candidate, settings)
    settings = settings or {}
    local promotion = settings.promotion or {}
    local messageCount = candidate.totalMessages or 0
    local content = candidate.content or {}
    local timing = candidate.timing or {}
    local behavior = candidate.behavior or {}
    local baseline = candidate.baseline or {}
    local intervalCount = timing.intervalCount or #(timing.intervals or {})
    local topBucket = timing.dominantBuckets and timing.dominantBuckets[1]
    local activeSpan = behavior.activeSpan or 0

    if messageCount >= (promotion.messageCount or 3) then
        if (content.templateReusePercent or 0) >= (promotion.templateReusePercent or 67) then
            return true
        end
        if (content.nearDuplicateCount or 0) >= (promotion.nearDuplicateClusterCount or 3) then
            return true
        end
        if (content.shingleReusePercent or 0) >= (promotion.shingleReusePercent or 67) then
            return true
        end
    end

    if
        messageCount >= (promotion.timingSampleCount or 4) + 1
        and intervalCount >= (promotion.timingSampleCount or 4)
        and topBucket
        and (topBucket.percent or 0) >= 75
        and ((timing.lowestRollingEntropy or 1) <= 0.40 or (timing.robustCoefficientVariation or 1) <= 0.18)
    then
        return true
    end

    if
        messageCount >= (promotion.highVolumeCount or 6)
        and activeSpan <= (promotion.highVolumeWindowSeconds or 600)
    then
        if
            (content.adIntentTotal or 0) >= 3
            or (content.dominantIntentPercent or 0) >= 50
            or (content.uniqueTemplateRatio or 1) <= 0.5
            or (baseline.postsPerHourPercentile or 0) >= 90
        then
            return true
        end
    end

    return false
end

function Scoring.Recalculate(candidate, settings)
    if type(candidate) ~= "table" then
        return nil
    end

    settings = settings or {}
    Scoring.UpdateMetrics(candidate, settings)

    local weightedReasons = {}
    local familyScores = {
        timing = scoreTiming(candidate, weightedReasons),
        content = scoreContent(candidate, weightedReasons),
        activity = scoreActivity(candidate, weightedReasons),
        persistence = scorePersistence(candidate, weightedReasons),
        baseline = scoreBaseline(candidate, weightedReasons),
    }
    local familyCount = countEvidenceFamilies(familyScores)
    local rawLocalScore = familyScores.timing
        + familyScores.content
        + familyScores.activity
        + familyScores.persistence
        + familyScores.baseline

    local recencyFactor = getRecencyFactor(candidate)
    if recencyFactor < 1 then
        rawLocalScore = rawLocalScore * recencyFactor
        addWeightedReason(weightedReasons, 1, "Older evidence has been decayed in the score.")
    end

    local localScore = Util.Clamp(rawLocalScore, 0, 100)
    local confidence = calculateConfidence(candidate, familyCount)
    local network = candidate.network or {}
    local networkContext = calculateNetworkContext(network)
    local networkOnly = (candidate.totalMessages or 0) == 0 and (network.peerCount or 0) > 0
    local displayScore = networkOnly and networkContext.score or localScore
    local meaningful = Scoring.HasMeaningfulLocalEvidence(candidate, settings)
    local tier = networkOnly and "Preliminary" or getTier(localScore, confidence, familyCount, familyScores, meaningful)
    local reasons = finalizeReasons(weightedReasons)

    candidate.features = {
        version = FEATURE_VERSION,
        updatedAt = Util.GetNow(),
        familyScores = familyScores,
        familyCount = familyCount,
        rawLocalScore = rawLocalScore,
        meaningfulLocalEvidence = meaningful,
    }

    candidate.score = {
        localScore = localScore,
        displayScore = displayScore,
        networkAdjustedScore = displayScore,
        networkScore = networkContext.score,
        networkConfidence = networkContext.confidence,
        tier = tier,
        confidence = networkOnly and 0 or confidence,
        evidenceFamilyCount = familyCount,
        familyScores = familyScores,
        reasons = reasons,
        updatedAt = Util.GetNow(),
    }

    return candidate.score
end
