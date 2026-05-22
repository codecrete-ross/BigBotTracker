local addonName, BBT = ...
BBT = BBT or _G.BigBotTracker or {}
_G.BigBotTracker = BBT

BBT.Normalizer = BBT.Normalizer or {}

local Normalizer = BBT.Normalizer

local function tokenize(normalized)
    local tokens = {}
    for token in tostring(normalized or ""):gmatch("%S+") do
        tokens[#tokens + 1] = token
    end
    return tokens
end

function Normalizer.NormalizeMessage(text)
    local value = tostring(text or "")

    value = value:gsub("|c%x%x%x%x%x%x%x%x", "")
    value = value:gsub("|r", "")
    value = value:gsub("|Hitem:[^|]+|h%[[^%]]+%]|h", " <item> ")
    value = value:gsub("|Hbattlepet:[^|]+|h%[[^%]]+%]|h", " <pet> ")
    value = value:gsub("|Hspell:[^|]+|h%[[^%]]+%]|h", " <spell> ")
    value = value:gsub("|Hachievement:[^|]+|h%[[^%]]+%]|h", " <achievement> ")
    value = value:gsub("|H.-|h%[[^%]]+%]|h", " <link> ")
    value = value:gsub("https?://%S+", " <url> ")
    value = value:gsub("www%.%S+", " <url> ")
    value = value:gsub("%d+[,.]?%d*%s*[kKmMgG]?", " <num> ")
    value = value:lower()
    value = value:gsub("[%c%p]+", " ")
    value = value:gsub("%s+", " ")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")

    return value
end

function Normalizer.Hash(value)
    value = tostring(value or "")
    local hash = 5381
    for index = 1, #value do
        hash = (hash * 33 + value:byte(index)) % 4294967296
    end
    return string.format("%08x", hash)
end

function Normalizer.TemplateHash(text)
    return Normalizer.Hash(Normalizer.NormalizeMessage(text))
end

function Normalizer.TokenJaccard(left, right)
    left = tokenize(left)
    right = tokenize(right)

    if #left == 0 and #right == 0 then
        return 1
    end
    if #left == 0 or #right == 0 then
        return 0
    end

    local leftSet = {}
    local rightSet = {}
    local union = 0
    local intersection = 0

    for _, token in ipairs(left) do
        if not leftSet[token] then
            leftSet[token] = true
            union = union + 1
        end
    end

    for _, token in ipairs(right) do
        if not rightSet[token] then
            rightSet[token] = true
            if leftSet[token] then
                intersection = intersection + 1
            else
                union = union + 1
            end
        end
    end

    if union == 0 then
        return 0
    end
    return intersection / union
end

function Normalizer.IsNearDuplicate(normalized, recentNormalized, threshold)
    threshold = threshold or 0.82

    if type(recentNormalized) ~= "table" then
        return false, 0
    end

    local best = 0
    for _, prior in ipairs(recentNormalized) do
        local similarity = Normalizer.TokenJaccard(normalized, prior)
        if similarity > best then
            best = similarity
        end
        if similarity >= threshold then
            return true, similarity
        end
    end

    return false, best
end
