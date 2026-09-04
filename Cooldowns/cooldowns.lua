local API = require("api")

local Cooldowns = {
    VERSION = "1.0.0",
    CYCLES_PER_TICK = 30,
    MILLISECONDS_PER_CYCLE = 20,
    QUEUE_WINDOW_CYCLES = 18,
}

local MAX_FILE_SIZE = 4 * 1024 * 1024
local UINT32_MODULUS = 0x100000000
local UINT32_HALF_RANGE = 0x80000000

local dataset = nil
local loadAttempted = false
local loadStatus = {
    loaded = false,
    path = "",
    schema_version = 0,
    client_build = -1,
    ability_count = 0,
    last_error = "",
}

local function isInteger(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
        and value == math.floor(value)
end

local function isPositiveInteger(value)
    return isInteger(value) and value > 0 and value <= 0x7fffffff
end

local function toUint32(value)
    if not isInteger(value) then
        return nil
    end
    return value % UINT32_MODULUS
end

local function forwardDelta(finish, start)
    local delta = (finish - start) % UINT32_MODULUS
    if delta >= UINT32_HALF_RANGE then
        return 0
    end
    return delta
end

local function normalizeName(name)
    if type(name) ~= "string" then
        return ""
    end

    local normalized = {}
    local insideTag = false
    local pendingSpace = false

    for index = 1, #name do
        local byte = name:byte(index)

        if byte == 60 then -- <
            insideTag = true
        elseif insideTag then
            if byte == 62 then -- >
                insideTag = false
            end
        else
            local isDigit = byte >= 48 and byte <= 57
            local isUpper = byte >= 65 and byte <= 90
            local isLower = byte >= 97 and byte <= 122

            if isDigit or isUpper or isLower then
                if pendingSpace and #normalized > 0 then
                    normalized[#normalized + 1] = " "
                end
                if isUpper then
                    byte = byte + 32
                end
                normalized[#normalized + 1] = string.char(byte)
                pendingSpace = false
            elseif #normalized > 0 then
                pendingSpace = true
            end
        end
    end

    return table.concat(normalized)
end

local function defaultPath()
    if type(os) ~= "table" or type(os.getenv) ~= "function" then
        return nil, "USERPROFILE is unavailable"
    end

    local profile = os.getenv("USERPROFILE")
    if type(profile) ~= "string" or profile == "" then
        return nil, "USERPROFILE is unavailable"
    end

    profile = profile:gsub("[/\\]+$", "")
    return profile .. "\\MemoryError\\ability_cooldowns.json"
end

local function readFile(path)
    local file, openError = io.open(path, "rb")
    if not file then
        return nil, "unable to open mapping file: " .. tostring(openError)
    end

    local contents, readError = file:read(MAX_FILE_SIZE + 1)
    file:close()

    if not contents then
        return nil, "unable to read mapping file: " .. tostring(readError)
    end
    if #contents == 0 then
        return nil, "mapping file is empty"
    end
    if #contents > MAX_FILE_SIZE then
        return nil, "mapping file exceeds 4 MiB"
    end

    return contents
end

local function decodeJson(contents)
    if type(JsonDecode) ~= "function" then
        return nil, "JsonDecode is unavailable"
    end

    local ok, decoded = pcall(JsonDecode, contents)
    if not ok then
        return nil, "invalid mapping JSON: " .. tostring(decoded)
    end
    if type(decoded) ~= "table" then
        return nil, "mapping root must be an object"
    end

    return decoded
end

local function validateOptionalPositiveInteger(entry, field, prefix)
    local value = entry[field]
    if value == nil then
        return nil
    end
    if not isPositiveInteger(value) then
        return nil, prefix .. field .. " must be a positive integer"
    end
    return value
end

local function validateDataset(root, path)
    if root.schema_version ~= 1 then
        return nil, "unsupported schema_version"
    end
    if root.client_build ~= nil and not isPositiveInteger(root.client_build) then
        return nil, "client_build must be a positive integer"
    end
    if not isPositiveInteger(root.global_cooldown_end_varc) then
        return nil, "global_cooldown_end_varc must be a positive integer"
    end
    if type(root.abilities) ~= "table" then
        return nil, "abilities must be an array"
    end

    local count = 0
    local maximumIndex = 0
    for key in pairs(root.abilities) do
        if not isPositiveInteger(key) then
            return nil, "abilities must be a dense array"
        end
        count = count + 1
        maximumIndex = math.max(maximumIndex, key)
    end
    if count == 0 or count ~= maximumIndex then
        return nil, "abilities must be a non-empty dense array"
    end

    local abilities = {}
    local byName = {}

    for index = 1, maximumIndex do
        local entry = root.abilities[index]
        local prefix = "abilities[" .. index .. "]."

        if type(entry) ~= "table" then
            return nil, "abilities[" .. index .. "] must be an object"
        end
        if not isPositiveInteger(entry.struct_id) then
            return nil, prefix .. "struct_id must be a positive integer"
        end
        if type(entry.name) ~= "string" or entry.name == "" then
            return nil, prefix .. "name must be a non-empty string"
        end
        if type(entry.gameval) ~= "nil" and type(entry.gameval) ~= "string" then
            return nil, prefix .. "gameval must be a string"
        end
        if not isPositiveInteger(entry.end_varc) then
            return nil, prefix .. "end_varc must be a positive integer"
        end

        local startVarc, startError =
            validateOptionalPositiveInteger(entry, "start_varc", prefix)
        if startError then
            return nil, startError
        end

        local spriteId, spriteError =
            validateOptionalPositiveInteger(entry, "sprite_id", prefix)
        if spriteError then
            return nil, spriteError
        end

        local normalizedName = normalizeName(entry.name)
        if normalizedName == "" then
            return nil, prefix .. "name is empty after normalization"
        end
        if byName[normalizedName] then
            return nil, prefix .. "duplicate normalized name: " .. normalizedName
        end

        local mapping = {
            struct_id = entry.struct_id,
            name = entry.name,
            gameval = entry.gameval or "",
            start_varc = startVarc,
            end_varc = entry.end_varc,
            sprite_id = spriteId,
        }

        abilities[index] = mapping
        byName[normalizedName] = mapping
    end

    return {
        path = path,
        schema_version = root.schema_version,
        client_build = root.client_build or -1,
        global_cooldown_end_varc = root.global_cooldown_end_varc,
        abilities = abilities,
        by_name = byName,
    }
end

local function loadDataset(path)
    local contents, readError = readFile(path)
    if not contents then
        return nil, readError
    end

    local root, decodeError = decodeJson(contents)
    if not root then
        return nil, decodeError
    end

    return validateDataset(root, path)
end

local function recordLoadFailure(path, message)
    loadStatus.last_error = message
    if not dataset and path then
        loadStatus.path = path
    end
end

function Cooldowns.reload(path)
    local selectedPath = path

    if selectedPath == nil and dataset then
        selectedPath = dataset.path
    elseif selectedPath == nil then
        local pathError
        selectedPath, pathError = defaultPath()
        if not selectedPath then
            loadAttempted = true
            recordLoadFailure(nil, pathError)
            return false, pathError
        end
    elseif type(selectedPath) ~= "string" or selectedPath == "" then
        local message = "mapping path must be a non-empty string"
        loadAttempted = true
        recordLoadFailure(nil, message)
        return false, message
    end

    loadAttempted = true
    local candidate, loadError = loadDataset(selectedPath)
    if not candidate then
        recordLoadFailure(selectedPath, loadError)
        return false, loadError
    end

    dataset = candidate
    loadStatus = {
        loaded = true,
        path = candidate.path,
        schema_version = candidate.schema_version,
        client_build = candidate.client_build,
        ability_count = #candidate.abilities,
        last_error = "",
    }

    return true
end

local function ensureLoaded()
    if dataset then
        return true
    end
    if loadAttempted then
        return false, loadStatus.last_error
    end
    return Cooldowns.reload()
end

function Cooldowns.status()
    return {
        loaded = loadStatus.loaded,
        path = loadStatus.path,
        schema_version = loadStatus.schema_version,
        client_build = loadStatus.client_build,
        ability_count = loadStatus.ability_count,
        last_error = loadStatus.last_error,
    }
end

local function identityFields(mapping, requestedName)
    return {
        struct_id = mapping and mapping.struct_id or -1,
        name = mapping and mapping.name or requestedName or "",
        gameval = mapping and mapping.gameval or "",
        start_varc = mapping and mapping.start_varc or -1,
        end_varc = mapping and mapping.end_varc or -1,
        sprite_id = mapping and mapping.sprite_id or -1,
    }
end

local function invalidResult(mapping, requestedName, errorCode, message)
    local result = identityFields(mapping, requestedName)
    result.valid = false
    result.error_code = errorCode
    result.error = message
    result.current_cycle = 0
    result.start_cycle = 0
    result.end_cycle = 0
    result.global_end_cycle = 0
    result.total_cycles = 0
    result.elapsed_cycles = 0
    result.remaining_cycles = 0
    result.remaining_ticks = 0
    result.remaining_ms = 0
    result.remaining_seconds = 0
    result.global_remaining_cycles = 0
    result.global_remaining_ms = 0
    result.personal_ready = false
    result.global_ready = false
    result.ready = false
    result.ready_now = false
    result.queueable = false
    return result
end

local function readClientCycle()
    if type(GetClientCycle) ~= "function" then
        return nil, "GetClientCycle is unavailable"
    end

    local ok, value = pcall(GetClientCycle)
    if not ok then
        return nil, "unable to read client cycle: " .. tostring(value)
    end

    value = toUint32(value)
    if value == nil then
        return nil, "client cycle is unavailable"
    end
    return value
end

local function readVarcCycle(varcId)
    if not isPositiveInteger(varcId) then
        return nil, "invalid varc ID"
    end
    if type(VC_FindPSett) ~= "function" then
        return nil, "VC_FindPSett is unavailable"
    end

    local ok, value = pcall(VC_FindPSett, varcId)
    if not ok then
        return nil, "unable to read varc " .. varcId .. ": " .. tostring(value)
    end
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return nil, "varc " .. varcId .. " returned an invalid value"
    end

    local fieldsOk, valid, found, state, returnedId = pcall(function()
        return value.valid, value.found, value.state, value.id
    end)
    if not fieldsOk or type(valid) ~= "boolean" or type(found) ~= "boolean" then
        return nil, "varc " .. varcId .. " returned malformed fields"
    end

    if not valid then
        return nil, "varc table is unavailable"
    end
    if not found then
        return 0
    end
    if not isInteger(state) or not isInteger(returnedId) or returnedId ~= varcId then
        return nil, "varc " .. varcId .. " returned inconsistent fields"
    end

    local normalized = toUint32(state)
    if normalized == nil then
        return nil, "varc " .. varcId .. " returned an invalid cycle"
    end
    return normalized
end

local function createQueryContext()
    local currentCycle, currentError = readClientCycle()
    if currentCycle == nil then
        return nil, currentError
    end

    local globalEndCycle, globalError =
        readVarcCycle(dataset.global_cooldown_end_varc)
    if globalEndCycle == nil then
        return nil, globalError
    end

    return {
        current_cycle = currentCycle,
        global_end_cycle = globalEndCycle,
        global_remaining_cycles = forwardDelta(globalEndCycle, currentCycle),
    }
end

local function queryMapping(mapping, context)
    local endCycle, endError = readVarcCycle(mapping.end_varc)
    if endCycle == nil then
        return invalidResult(mapping, nil, "unavailable", endError)
    end

    local startCycle = 0
    if mapping.start_varc then
        local startError
        startCycle, startError = readVarcCycle(mapping.start_varc)
        if startCycle == nil then
            return invalidResult(mapping, nil, "unavailable", startError)
        end
    end

    local remainingCycles = forwardDelta(endCycle, context.current_cycle)
    local totalCycles = 0
    if mapping.start_varc and startCycle ~= 0 then
        totalCycles = forwardDelta(endCycle, startCycle)
    end
    local elapsedCycles = math.max(0, math.min(totalCycles, totalCycles - remainingCycles))
    local personalReady = remainingCycles == 0
    local globalReady = context.global_remaining_cycles == 0
    local ready = personalReady and globalReady

    local result = identityFields(mapping)
    result.valid = true
    result.error_code = nil
    result.error = nil
    result.current_cycle = context.current_cycle
    result.start_cycle = startCycle
    result.end_cycle = endCycle
    result.global_end_cycle = context.global_end_cycle
    result.total_cycles = totalCycles
    result.elapsed_cycles = elapsedCycles
    result.remaining_cycles = remainingCycles
    result.remaining_ticks = remainingCycles / Cooldowns.CYCLES_PER_TICK
    result.remaining_ms = remainingCycles * Cooldowns.MILLISECONDS_PER_CYCLE
    result.remaining_seconds = result.remaining_ms / 1000
    result.global_remaining_cycles = context.global_remaining_cycles
    result.global_remaining_ms =
        context.global_remaining_cycles * Cooldowns.MILLISECONDS_PER_CYCLE
    result.personal_ready = personalReady
    result.global_ready = globalReady
    result.ready = ready
    result.ready_now = ready
    result.queueable = personalReady
        and context.global_remaining_cycles <= Cooldowns.QUEUE_WINDOW_CYCLES
    return result
end

function Cooldowns.get(name)
    if type(name) ~= "string" or normalizeName(name) == "" then
        return invalidResult(nil, type(name) == "string" and name or "",
            "invalid_name", "ability name must be a non-empty string")
    end

    local loaded, loadError = ensureLoaded()
    if not loaded then
        return invalidResult(nil, name, "not_loaded", loadError)
    end

    local mapping = dataset.by_name[normalizeName(name)]
    if not mapping then
        return invalidResult(nil, name, "unknown_ability",
            "ability is not present in the cooldown mapping")
    end

    local context, contextError = createQueryContext()
    if not context then
        return invalidResult(mapping, nil, "unavailable", contextError)
    end

    return queryMapping(mapping, context)
end

function Cooldowns.getAll()
    local loaded, loadError = ensureLoaded()
    if not loaded then
        return {}, loadError
    end

    local context, contextError = createQueryContext()
    if not context then
        local results = {}
        for index, mapping in ipairs(dataset.abilities) do
            results[index] = invalidResult(mapping, nil, "unavailable", contextError)
        end
        return results, contextError
    end

    local results = {}
    for index, mapping in ipairs(dataset.abilities) do
        results[index] = queryMapping(mapping, context)
    end
    return results
end

function Cooldowns.isReady(name)
    local result = Cooldowns.get(name)
    return result.valid and result.ready
end

function Cooldowns.isQueueable(name)
    local result = Cooldowns.get(name)
    return result.valid and result.queueable
end

return Cooldowns
