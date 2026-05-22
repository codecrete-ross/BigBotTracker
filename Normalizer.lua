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

local function uniqueSorted(list)
    local seen = {}
    local unique = {}
    for _, value in ipairs(list or {}) do
        if value and not seen[value] then
            seen[value] = true
            unique[#unique + 1] = value
        end
    end
    table.sort(unique)
    return unique
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

function Normalizer.Tokenize(normalized)
    return tokenize(normalized)
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

function Normalizer.ShingleSignature(normalized, size)
    size = size or 3
    local tokens = tokenize(normalized)
    local shingles = {}

    if #tokens == 0 then
        return shingles
    end

    if #tokens < size then
        shingles[#shingles + 1] = Normalizer.Hash(table.concat(tokens, " "))
        return shingles
    end

    for index = 1, #tokens - size + 1 do
        local parts = {}
        for offset = 0, size - 1 do
            parts[#parts + 1] = tokens[index + offset]
        end
        shingles[#shingles + 1] = Normalizer.Hash(table.concat(parts, " "))
    end

    return uniqueSorted(shingles)
end

function Normalizer.ShingleJaccard(left, right)
    left = left or {}
    right = right or {}

    if #left == 0 and #right == 0 then
        return 1
    end
    if #left == 0 or #right == 0 then
        return 0
    end

    local leftSet = {}
    local union = 0
    local intersection = 0

    for _, hash in ipairs(left) do
        if not leftSet[hash] then
            leftSet[hash] = true
            union = union + 1
        end
    end

    for _, hash in ipairs(right) do
        if leftSet[hash] then
            intersection = intersection + 1
        else
            union = union + 1
        end
    end

    if union == 0 then
        return 0
    end
    return intersection / union
end

function Normalizer.SignatureKey(signature, limit)
    local parts = uniqueSorted(signature)
    local kept = {}
    for index = 1, math.min(limit or #parts, #parts) do
        kept[#kept + 1] = parts[index]
    end
    return table.concat(kept, ",")
end

function Normalizer.DetectAdIntent(text, normalized)
    local raw = tostring(text or ""):lower()
    normalized = tostring(normalized or Normalizer.NormalizeMessage(text))
    local source = raw .. " " .. normalized
    local categories = {}
    local score = 0

    local function add(category)
        if not categories[category] then
            categories[category] = true
            score = score + 1
        end
    end

    if source:find("wts", 1, true) or source:find("selling", 1, true) or source:find("sell", 1, true) then
        add("wts")
    end
    if source:find("wtb", 1, true) or source:find("buying", 1, true) or source:find("buy", 1, true) then
        add("wtb")
    end
    if source:find("lf ", 1, true) or source:find("looking for", 1, true) or source:find("need ", 1, true) then
        add("looking")
    end
    if source:find("carry", 1, true) or source:find("boost", 1, true) or source:find("run", 1, true) then
        add("carry")
    end
    if source:find("mythic", 1, true) or source:find(" m ", 1, true) or source:find("raid", 1, true) then
        add("pve")
    end
    if
        source:find("craft", 1, true)
        or source:find("recraft", 1, true)
        or source:find("work order", 1, true)
        or source:find("profession", 1, true)
    then
        add("craft")
    end
    if source:find("|hitem:", 1, true) or raw:find("|hitem:", 1, true) or raw:find("|Hitem:", 1, true) then
        add("itemlink")
    end
    if raw:find("https?://") or raw:find("www%.") then
        add("url")
    end
    if raw:find("%d+[,.]?%d*%s*[kKmMgG]") or source:find("gold", 1, true) then
        add("price")
    end
    if source:find("pst", 1, true) or source:find("whisper", 1, true) or source:find("dm ", 1, true) then
        add("contact")
    end

    local categoryList = {}
    for category in pairs(categories) do
        categoryList[#categoryList + 1] = category
    end
    table.sort(categoryList)

    return {
        score = score,
        categories = categories,
        categoryList = categoryList,
        categoryKey = #categoryList > 0 and table.concat(categoryList, ",") or "none",
        hasIntent = score > 0,
    }
end

function Normalizer.IsNearDuplicate(normalized, recentMessages, threshold, shingleThreshold, shingles)
    threshold = threshold or 0.82
    shingleThreshold = shingleThreshold or 0.66
    shingles = shingles or Normalizer.ShingleSignature(normalized)

    if type(recentMessages) ~= "table" then
        return false, 0
    end

    local best = 0
    local bestMethod = "token"
    for _, prior in ipairs(recentMessages) do
        local priorNormalized = type(prior) == "table" and prior.normalized or prior
        local priorShingles = type(prior) == "table" and prior.shingles or nil
        local tokenSimilarity = Normalizer.TokenJaccard(normalized, priorNormalized)
        local shingleSimilarity =
            Normalizer.ShingleJaccard(shingles, priorShingles or Normalizer.ShingleSignature(priorNormalized))

        if tokenSimilarity > best then
            best = tokenSimilarity
            bestMethod = "token"
        end
        if shingleSimilarity > best then
            best = shingleSimilarity
            bestMethod = "shingle"
        end
        if tokenSimilarity >= threshold then
            return true, tokenSimilarity, "token"
        end
        if shingleSimilarity >= shingleThreshold then
            return true, shingleSimilarity, "shingle"
        end
    end

    return false, best, bestMethod
end
