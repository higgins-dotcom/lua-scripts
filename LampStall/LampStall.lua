--[[
# Script Name:   LampStall
# Description:  Steals XP lamps, redeems an ordered skill queue, and catches eligible implings.
# Author:        Higgins
# Version:       1.0
# Date:          2026.08.16
--]]

local API = require("API")
local LampStall = {}

local ID = {
    SMALL_XP_LAMP = 36073,
    LAMP_INTERFACE = 1263,
    LAMP_CONFIRM_COMPONENT = 74,
    LAMP_USE_ALL_INTERFACE = 678,
    LAMP_USE_ALL_COMPONENT = 19,
    LAMP_USE_ALL_CHECKED_SPRITE = 18543,
    GUTHIX_BUTTERFLY = 19884,
    PIRATE_UNLOCK_VARBIT = 12462,
}

local LAMP_USE_ALL_CHECKBOX = {
    { 678, 3, -1, 0 },
    { 678, 1, -1, 0 },
    { 678, 5, -1, 0 },
    { 678, 7, -1, 0 },
}

local LAMP_STALL_AREA = {
    x = 3232,
    y = 2787,
    z = 0,
    radius = 25,
    outsideMessage = "Move within 25 tiles of the Lamp stall to start.",
}

local SKILLS = {
    { name = "Agility",       key = "AGILITY",       component = 22, choice = 8 },
    { name = "Archaeology",   key = "ARCHAEOLOGY",   component = 68, choice = 28 },
    { name = "Attack",        key = "ATTACK",        component = 14, choice = 1 },
    { name = "Constitution",  key = "CONSTITUTION",  component = 16, choice = 6 },
    { name = "Construction",  key = "CONSTRUCTION",  component = 56, choice = 22 },
    { name = "Cooking",       key = "COOKING",       component = 36, choice = 15 },
    { name = "Crafting",      key = "CRAFTING",      component = 40, choice = 11 },
    { name = "Defence",       key = "DEFENCE",       component = 26, choice = 5 },
    { name = "Divination",    key = "DIVINATION",    component = 64, choice = 26 },
    { name = "Dungeoneering", key = "DUNGEONEERING", component = 62, choice = 25 },
    { name = "Farming",       key = "FARMING",       component = 54, choice = 21 },
    { name = "Firemaking",    key = "FIREMAKING",    component = 42, choice = 17 },
    { name = "Fishing",       key = "FISHING",       component = 30, choice = 16 },
    { name = "Fletching",     key = "FLETCHING",     component = 46, choice = 19 },
    { name = "Herblore",      key = "HERBLORE",      component = 28, choice = 9 },
    { name = "Hunter",        key = "HUNTER",        component = 58, choice = 23 },
    { name = "Invention",     key = "INVENTION",     component = 66, choice = 27 },
    { name = "Magic",         key = "MAGIC",         component = 44, choice = 4 },
    { name = "Mining",        key = "MINING",        component = 18, choice = 13 },
    { name = "Necromancy",    key = "NECROMANCY",    component = 69, choice = 29 },
    { name = "Prayer",        key = "PRAYER",        component = 38, choice = 7 },
    { name = "Ranged",        key = "RANGED",        component = 32, choice = 3 },
    { name = "Runecrafting",  key = "RUNECRAFTING",  component = 50, choice = 12 },
    { name = "Slayer",        key = "SLAYER",        component = 52, choice = 20 },
    { name = "Smithing",      key = "SMITHING",      component = 24, choice = 14 },
    { name = "Strength",      key = "STRENGTH",      component = 20, choice = 2 },
    { name = "Summoning",     key = "SUMMONING",     component = 60, choice = 24 },
    { name = "Thieving",      key = "THIEVING",      component = 34, choice = 10 },
    { name = "Woodcutting",   key = "WOODCUTTING",   component = 48, choice = 18 },
}

local IMPLINGS = {
    { key = "BABY",     name = "Baby",     level = 17, ids = { 1028, 6055 } },
    { key = "YOUNG",    name = "Young",    level = 22, ids = { 1029, 6056 } },
    { key = "GOURMET",  name = "Gourmet",  level = 28, ids = { 1030, 6057 } },
    { key = "EARTH",    name = "Earth",    level = 36, ids = { 1031, 6058 } },
    { key = "ESSENCE",  name = "Essence",  level = 42, ids = { 1032, 6059 } },
    { key = "ECLECTIC", name = "Eclectic", level = 50, ids = { 1033, 6060 } },
    { key = "SPIRIT",   name = "Spirit",   level = 54, ids = { 7866, 7904 } },
    { key = "NATURE",   name = "Nature",   level = 58, ids = { 1034, 6061 } },
    { key = "MAGPIE",   name = "Magpie",   level = 65, ids = { 1035, 6062 } },
    { key = "NINJA",    name = "Ninja",    level = 74, ids = { 6053, 6063 } },
    { key = "PIRATE",   name = "Pirate",   level = 76, ids = { 7845, 7846, 7867 } },
    { key = "DIVINE",   name = "Divine",   level = 79, ids = { 14932, 14933 } },
    { key = "DRAGON",   name = "Dragon",   level = 83, ids = { 6054, 6064 } },
    { key = "ZOMBIE",   name = "Zombie",   level = 87, ids = { 7902, 7905, 31307 } },
    { key = "KINGLY",   name = "Kingly",   level = 91, ids = { 7903, 7906 } },
    { key = "CRYSTAL",  name = "Crystal",  level = 95, ids = { 20102, 20103 } },
}

function LampStall.findActiveQueueEntry(queue, levels)
    for index, entry in ipairs(queue or {}) do
        if (levels[entry.skill] or 1) < entry.targetLevel then
            return entry, index
        end
    end
    return nil, nil
end

function LampStall.isPirateUnlocked(value)
    return tonumber(value) == 100
end

function LampStall.readPirateUnlock(readVarbit)
    if type(readVarbit) ~= "function" then return false end
    local ok, value = pcall(readVarbit)
    return ok and LampStall.isPirateUnlocked(value)
end

function LampStall.isWithinArea(distance, radius)
    distance = tonumber(distance)
    radius = tonumber(radius) or LAMP_STALL_AREA.radius
    return distance ~= nil and distance <= radius
end

function LampStall.readLampStallArea(readDistance, radius)
    if type(readDistance) ~= "function" then return false, nil end
    local ok, distance = pcall(readDistance)
    distance = tonumber(distance)
    return ok and LampStall.isWithinArea(distance, radius), distance
end

function LampStall.buildEligibleImplingIds(definitions, enabled, hunterLevel, pirateUnlocked)
    local ids = {}
    if pirateUnlocked == nil then pirateUnlocked = true end
    for _, impling in ipairs(definitions or {}) do
        local isPirateLocked = impling.key == "PIRATE" and not pirateUnlocked
        if enabled[impling.key] and hunterLevel >= impling.level and not isPirateLocked then
            for _, id in ipairs(impling.ids) do
                ids[#ids + 1] = id
            end
        end
    end
    return ids
end

function LampStall.snapshotInventory(items)
    local snapshot = {}
    for _, item in ipairs(items or {}) do
        if item.id and item.id > 0 then
            snapshot[item.id] = (snapshot[item.id] or 0) + (item.amount or 1)
        end
    end
    return snapshot
end

function LampStall.findItemIdsByName(items, needle)
    local ids = {}
    needle = string.lower(tostring(needle or ""))
    if needle == "" then return ids end
    for _, item in ipairs(items or {}) do
        local id = tonumber(item.id)
        local name = item.name or item.item_name
        if id and id > 0 and type(name) == "string" and string.find(string.lower(name), needle, 1, true) then
            ids[id] = true
        end
    end
    return ids
end

function LampStall.findNewLootIds(before, after, protected)
    local ids = {}
    protected = protected or {}
    for id, amount in pairs(after or {}) do
        if amount > 0 and not protected[id] and (before[id] or 0) == 0 then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    return ids
end

function LampStall.normalizeConfig(raw, skills, implings)
    raw = type(raw) == "table" and raw or {}
    skills = skills or SKILLS
    implings = implings or IMPLINGS

    local skillKeys = {}
    for _, skill in ipairs(skills) do
        if type(skill.key) == "string" then skillKeys[skill.key] = true end
    end

    local normalized = {
        queue = {},
        implings = {},
        catchButterfly = true,
        selectedSkill = skills[1] and skills[1].key or nil,
        targetLevel = 99,
    }
    for _, impling in ipairs(implings) do
        normalized.implings[impling.key] = true
    end

    if type(raw.queue) == "table" then
        for _, entry in ipairs(raw.queue) do
            if type(entry) == "table" and skillKeys[entry.skill] then
                local target = tonumber(entry.targetLevel)
                if target then
                    normalized.queue[#normalized.queue + 1] = {
                        skill = entry.skill,
                        targetLevel = math.max(1, math.min(120, math.floor(target))),
                    }
                end
            end
        end
    end
    if type(raw.implings) == "table" then
        for _, impling in ipairs(implings) do
            if type(raw.implings[impling.key]) == "boolean" then
                normalized.implings[impling.key] = raw.implings[impling.key]
            end
        end
    end
    if type(raw.catchButterfly) == "boolean" then
        normalized.catchButterfly = raw.catchButterfly
    end
    if type(raw.selectedSkill) == "string" and skillKeys[raw.selectedSkill] then
        normalized.selectedSkill = raw.selectedSkill
    end
    local targetLevel = tonumber(raw.targetLevel)
    if targetLevel then
        normalized.targetLevel = math.max(1, math.min(120, math.floor(targetLevel)))
    end
    return normalized
end

LampStall.ID = ID
LampStall.SKILLS = SKILLS
LampStall.IMPLINGS = IMPLINGS
LampStall.LAMP_STALL_AREA = LAMP_STALL_AREA

local STATE = {
    PAUSED = "PAUSED",
    STEAL = "STEAL",
    CATCH_IMPLING = "CATCH_IMPLING",
    WAIT_FOR_CATCH = "WAIT_FOR_CATCH",
    DROP_IMPLING_LOOT = "DROP_IMPLING_LOOT",
    OPEN_LAMP = "OPEN_LAMP",
    SELECT_SKILL = "SELECT_SKILL",
    USE_ALL = "USE_ALL",
    CONFIRM_LAMP = "CONFIRM_LAMP",
    QUEUE_COMPLETE = "QUEUE_COMPLETE",
    CATCH_BUTTERFLY = "CATCH_BUTTERFLY",
}

LampStall.STATE = STATE

function LampStall.chooseStealTransition(snapshot)
    if not snapshot.hasActiveQueue then return STATE.QUEUE_COMPLETE end
    if snapshot.inventoryFull and snapshot.hasLamp then return STATE.OPEN_LAMP end
    if snapshot.inventoryFull then return STATE.PAUSED end
    if snapshot.hasButterfly then return STATE.CATCH_BUTTERFLY end
    if snapshot.hasImpling then return STATE.CATCH_IMPLING end
    return STATE.STEAL
end

function LampStall.getCatchOutcome(targetKind)
    if targetKind == "BUTTERFLY" then
        return { countImpling = false, dropLoot = false, nextState = STATE.STEAL }
    end
    return { countImpling = true, dropLoot = true, nextState = STATE.DROP_IMPLING_LOOT }
end

if rawget(_G, "LAMP_STALL_TEST_MODE") then
    return LampStall
end

local CAPTURE_RANGE = 15
local CATCH_TIMEOUT = 4
local IMPLING_RECLICK_COOLDOWN = 0.75
local LAMP_TIMEOUT = 6
local ACTION_RETRIES = 4

local config = {
    running = false,
    queue = {},
    implings = {},
    catchButterfly = true,
}
for _, impling in ipairs(IMPLINGS) do
    config.implings[impling.key] = true
end

local runtime = {
    state = STATE.PAUSED,
    status = "Configure a lamp queue, then press Start.",
    error = false,
    stateSince = os.clock(),
    startTime = os.time(),
    startThievingXp = API.GetSkillXP("THIEVING") or 0,
    startHunterXp = API.GetSkillXP("HUNTER") or 0,
    beforeCatch = nil,
    catchKind = nil,
    catchStartXp = 0,
    catchDeadline = 0,
    dropIds = {},
    catchCooldownUntil = 0,
    lampCountBefore = 0,
    lampDeadline = 0,
    lampActionSent = false,
    useAllActionSent = false,
    activeSkill = nil,
    pauseRequested = false,
    stopRequested = false,
    retries = 0,
    lampsRedeemed = 0,
    implingsCaught = 0,
    cleanedUp = false,
}

local GUI = require("Skilling.LampStallGUI")

local function getScriptDir()
    local info = debug.getinfo(1, "S")
    local source = info and info.source or ""
    if source:sub(1, 1) == "@" then source = source:sub(2) end
    return source:match("(.*[/\\])") or ""
end

GUI.setScriptDirectory(getScriptDir())
local savedConfig = LampStall.normalizeConfig(GUI.loadConfig(), SKILLS, IMPLINGS)
config.queue = savedConfig.queue
config.implings = savedConfig.implings
config.catchButterfly = savedConfig.catchButterfly
GUI.setDraft(savedConfig.selectedSkill, savedConfig.targetLevel, SKILLS)

local function setState(nextState, status)
    runtime.state = nextState
    runtime.stateSince = os.clock()
    runtime.status = status or nextState
    runtime.error = false
    runtime.retries = 0
end

local function failState(message)
    runtime.status = message
    runtime.error = true
    runtime.retries = runtime.retries + 1
    if runtime.retries >= ACTION_RETRIES then
        config.running = false
        runtime.pauseRequested = false
        setState(STATE.PAUSED, message .. " Automation paused.")
        runtime.error = true
    end
end

local function getSkillXp(skill)
    local ok, xp = pcall(API.GetSkillXP, skill)
    if not ok then return 0 end
    return tonumber(xp) or 0
end

local function getBaseLevel(skill)
    local ok, level = pcall(API.XPLevelTable, getSkillXp(skill))
    if not ok then return 1 end
    return tonumber(level) or 1
end

local function getHunterLevel()
    return getBaseLevel("HUNTER")
end

local function skillByKey(key)
    for _, skill in ipairs(SKILLS) do
        if skill.key == key then return skill end
    end
    return nil
end

local function currentLevels()
    local levels, seen = {}, {}
    for _, entry in ipairs(config.queue) do
        if not seen[entry.skill] then
            levels[entry.skill] = getBaseLevel(entry.skill)
            seen[entry.skill] = true
        end
    end
    return levels
end

local function activeQueueEntry(levels)
    local entry, index = LampStall.findActiveQueueEntry(config.queue, levels)
    return entry, index
end

local function pirateUnlocked()
    return LampStall.readPirateUnlock(function()
        return API.GetVarbitValue(ID.PIRATE_UNLOCK_VARBIT)
    end)
end

local function eligibleImplingIds()
    return LampStall.buildEligibleImplingIds(IMPLINGS, config.implings, getHunterLevel(), pirateUnlocked())
end

local function hasLamp()
    return (Inventory:GetItemAmount(ID.SMALL_XP_LAMP) or 0) > 0
end

local function interfaceOpen()
    return GetInterfaceOpenBySize(ID.LAMP_INTERFACE)
end

local function lampStallAreaStatus()
    return LampStall.readLampStallArea(function()
        return API.Math_DistanceW(API.PlayerCoord(), WPOINT.new(
            LAMP_STALL_AREA.x, LAMP_STALL_AREA.y, LAMP_STALL_AREA.z))
    end, LAMP_STALL_AREA.radius)
end

local function selectedLampChoice()
    local ok, setting = pcall(VC_FindPSett, 1796)
    if not ok or not setting then return -1 end
    return tonumber(setting.state) or -1
end

local function isSmallLampUseAllChecked()
    local checkbox = API.ScanForInterfaceTest2Get(false, LAMP_USE_ALL_CHECKBOX) or {}
    for _, component in ipairs(checkbox) do
        if component.itemid1 == ID.LAMP_USE_ALL_CHECKED_SPRITE then
            return true
        end
    end
    return false
end

local function transitionAfterTransaction(nextState, status)
    if runtime.pauseRequested then
        runtime.pauseRequested = false
        config.running = false
        setState(STATE.PAUSED, "Paused safely after the current action.")
    else
        setState(nextState, status)
    end
end

local function buildGUIModel()
    local levels = currentLevels()
    local active, activeIndex = activeQueueEntry(levels)
    local hunterLevel = getHunterLevel()
    local pirateIsUnlocked = pirateUnlocked()
    local inLampStallArea, lampStallDistance = lampStallAreaStatus()
    local runtimeSeconds = math.max(1, os.difftime(os.time(), runtime.startTime))
    local thievingXpGained = math.max(0, getSkillXp("THIEVING") - runtime.startThievingXp)
    local hunterXpGained = math.max(0, getSkillXp("HUNTER") - runtime.startHunterXp)
    local implingModel = {}
    for _, impling in ipairs(IMPLINGS) do
        implingModel[#implingModel + 1] = {
            key = impling.key,
            name = impling.name,
            level = impling.level,
            enabled = config.implings[impling.key] == true,
            eligible = hunterLevel >= impling.level and (impling.key ~= "PIRATE" or pirateIsUnlocked),
        }
    end
    return {
        running = config.running,
        runtime = runtime,
        runtimeSeconds = runtimeSeconds,
        hunterLevel = hunterLevel,
        thievingXpGained = thievingXpGained,
        hunterXpGained = hunterXpGained,
        thievingXpPerHour = thievingXpGained * 3600 / runtimeSeconds,
        hunterXpPerHour = hunterXpGained * 3600 / runtimeSeconds,
        inLampStallArea = inLampStallArea,
        lampStallDistance = lampStallDistance,
        catchButterfly = config.catchButterfly,
        queue = config.queue,
        currentLevels = levels,
        activeQueueIndex = activeIndex,
        activeTarget = active and {
            name = (skillByKey(active.skill) or {}).name or active.skill,
            targetLevel = active.targetLevel,
        } or nil,
        skills = SKILLS,
        implings = implingModel,
    }
end

local function swapQueue(indexA, indexB)
    if config.queue[indexA] and config.queue[indexB] then
        config.queue[indexA], config.queue[indexB] = config.queue[indexB], config.queue[indexA]
    end
end

local function saveConfiguration()
    local draft = GUI.getDraft(SKILLS)
    GUI.saveConfig({
        queue = config.queue,
        implings = config.implings,
        catchButterfly = config.catchButterfly,
        selectedSkill = draft.selectedSkill,
        targetLevel = draft.targetLevel,
    })
end

local function applyGuiActions()
    local configurationChanged = GUI.consumeDraftDirty()
    for _, action in ipairs(GUI.popActions()) do
        local kind, payload = action.kind, action.payload
        if kind == "START" then
            local inLampStallArea = lampStallAreaStatus()
            if not inLampStallArea then
                config.running = false
                setState(STATE.PAUSED, LAMP_STALL_AREA.outsideMessage)
            else
                local levels = currentLevels()
                local active = activeQueueEntry(levels)
                if active then
                    runtime.pauseRequested = false
                    config.running = true
                    setState(STATE.STEAL, "Running lamp stall automation.")
                else
                    config.running = false
                    setState(STATE.QUEUE_COMPLETE, "Lamp queue is complete. Add another target to continue.")
                end
            end
        elseif kind == "PAUSE" then
            config.running = false
            if runtime.state == STATE.STEAL or runtime.state == STATE.PAUSED or runtime.state == STATE.QUEUE_COMPLETE then
                runtime.pauseRequested = false
                setState(STATE.PAUSED, "Paused by user.")
            else
                runtime.pauseRequested = true
                runtime.status = "Finishing the current action before pausing..."
            end
        elseif kind == "STOP" then
            config.running = false
            runtime.stopRequested = true
            API.Write_LoopyLoop(false)
        elseif kind == "ADD_QUEUE" and payload and skillByKey(payload.skill) then
            local target = math.floor(tonumber(payload.targetLevel) or 1)
            config.queue[#config.queue + 1] = { skill = payload.skill, targetLevel = math.max(1, math.min(120, target)) }
            runtime.status = "Added " .. payload.skill .. " to the lamp queue."
            configurationChanged = true
        elseif kind == "MOVE_QUEUE_UP" and tonumber(payload) and payload > 1 then
            swapQueue(payload, payload - 1)
            configurationChanged = true
        elseif kind == "MOVE_QUEUE_DOWN" and tonumber(payload) and payload < #config.queue then
            swapQueue(payload, payload + 1)
            configurationChanged = true
        elseif kind == "REMOVE_QUEUE" and config.queue[payload] then
            table.remove(config.queue, payload)
            configurationChanged = true
        elseif kind == "CLEAR_QUEUE" then
            config.queue = {}
            config.running = false
            setState(STATE.PAUSED, "Queue cleared. Add a target to begin.")
            configurationChanged = true
        elseif kind == "SET_IMPLING" and payload and config.implings[payload.key] ~= nil then
            config.implings[payload.key] = payload.enabled == true
            configurationChanged = true
        elseif kind == "SET_BUTTERFLY" and payload ~= nil then
            config.catchButterfly = payload == true
            configurationChanged = true
        elseif kind == "SELECT_ALL_IMPLINGS" then
            for _, impling in ipairs(IMPLINGS) do config.implings[impling.key] = true end
            configurationChanged = true
        elseif kind == "CLEAR_ALL_IMPLINGS" then
            for _, impling in ipairs(IMPLINGS) do config.implings[impling.key] = false end
            configurationChanged = true
        end
    end
    if configurationChanged then saveConfiguration() end
end

local function enforceLampStallArea()
    if config.running and not lampStallAreaStatus() then
        config.running = false
        runtime.pauseRequested = false
        setState(STATE.PAUSED, LAMP_STALL_AREA.outsideMessage)
    end
end

local function beginCatch(targetKind, eligibleIds)
    if #eligibleIds == 0 then
        transitionAfterTransaction(STATE.STEAL, "Target moved away; returning to the Lamp stall.")
        return
    end
    runtime.catchKind = targetKind
    runtime.beforeCatch = targetKind == "IMPLING" and LampStall.snapshotInventory(Inventory:GetItems()) or nil
    runtime.catchStartXp = getSkillXp("HUNTER")
    runtime.catchDeadline = os.clock() + CATCH_TIMEOUT
    local actionSucceeded
    if targetKind == "BUTTERFLY" then
        actionSucceeded = API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0,
            { ID.GUTHIX_BUTTERFLY }, CAPTURE_RANGE)
    else
        actionSucceeded = API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, eligibleIds, CAPTURE_RANGE)
    end
    if actionSucceeded then
        local message = targetKind == "BUTTERFLY" and "Catching the Guthixian butterfly." or
        "Catching the nearest enabled impling."
        setState(STATE.WAIT_FOR_CATCH, message)
    else
        local message = targetKind == "BUTTERFLY" and "Could not click the Guthixian butterfly." or
        "Could not click an eligible impling."
        failState(message)
        transitionAfterTransaction(STATE.STEAL, "Returning to the Lamp stall.")
    end
end

local function finishCatch(success)
    local catchKind = runtime.catchKind
    local outcome = LampStall.getCatchOutcome(catchKind)
    if success and outcome.countImpling then
        runtime.implingsCaught = runtime.implingsCaught + 1
        local afterItems = Inventory:GetItems()
        local protectedLoot = { [ID.SMALL_XP_LAMP] = true }
        for itemId in pairs(LampStall.findItemIdsByName(afterItems, "exquisite hunter urn")) do
            protectedLoot[itemId] = true
        end
        runtime.dropIds = LampStall.findNewLootIds(
            runtime.beforeCatch,
            LampStall.snapshotInventory(afterItems),
            protectedLoot
        )
    elseif not success or not outcome.dropLoot then
        runtime.dropIds = {}
    end
    runtime.beforeCatch = nil
    runtime.catchKind = nil
    if success and catchKind == "IMPLING" then
        runtime.catchCooldownUntil = os.clock() + IMPLING_RECLICK_COOLDOWN
    end
    if success and outcome.dropLoot then
        setState(STATE.DROP_IMPLING_LOOT, "Cleaning up impling loot.")
    else
        local message
        if not success then
            message = catchKind == "BUTTERFLY" and "No butterfly XP drop; resuming the Lamp stall."
                or "No Hunter XP drop; resuming the Lamp stall."
        else
            message = catchKind == "BUTTERFLY" and "Butterfly caught; resuming the Lamp stall." or
            "Impling left; resuming the Lamp stall."
        end
        transitionAfterTransaction(outcome.nextState, message)
    end
end

local function waitForCatch()
    local success = getSkillXp("HUNTER") > runtime.catchStartXp
    if not success and os.clock() >= runtime.catchDeadline then
        finishCatch(false)
        return
    end
    if success then finishCatch(true) end
end

local function dropImplingLoot()
    local itemId = runtime.dropIds[1]
    if not itemId then
        runtime.dropIds = {}
        transitionAfterTransaction(STATE.STEAL, "Impling loot cleared; returning to the Lamp stall.")
        return
    end
    if not Inventory:Contains(itemId) then
        table.remove(runtime.dropIds, 1)
        return
    end
    runtime.status = "Dropping impling loot."
    if Inventory:Drop(itemId) then
        API.RandomSleep2(100, 50, 75)
    else
        failState("Could not drop impling loot item " .. tostring(itemId) .. ".")
        if runtime.retries >= ACTION_RETRIES then table.remove(runtime.dropIds, 1) end
    end
end

local function openLamp()
    if not hasLamp() then
        config.running = false
        setState(STATE.PAUSED, "Inventory is full and no XP lamp is available.")
        return
    end
    runtime.lampCountBefore = Inventory:GetItemAmount(ID.SMALL_XP_LAMP) or 0
    if interfaceOpen() then
        runtime.activeSkill = nil
        runtime.lampActionSent = false
        runtime.useAllActionSent = false
        setState(STATE.SELECT_SKILL, "Selecting the next lamp skill.")
        return
    end
    if runtime.lampDeadline == 0 then
        if API.DoAction_Inventory1(36073, 0, 1, API.OFF_ACT_GeneralInterface_route) then
            runtime.lampDeadline = os.clock() + LAMP_TIMEOUT
            runtime.lampActionSent = false
            runtime.status = "Opening an XP lamp."
        else
            failState("Could not rub the XP lamp.")
        end
    elseif os.clock() >= runtime.lampDeadline then
        failState("XP lamp interface did not open.")
    end
end

local function selectLampSkill()
    if not interfaceOpen() then
        if hasLamp() then
            runtime.lampDeadline = 0
            setState(STATE.OPEN_LAMP, "Re-opening the XP lamp.")
        else
            setState(STATE.STEAL, "Returning to the Lamp stall.")
        end
        return
    end
    local levels = currentLevels()
    local entry = activeQueueEntry(levels)
    if not entry then
        config.running = false
        setState(STATE.QUEUE_COMPLETE, "Lamp queue is complete.")
        return
    end
    local skill = skillByKey(entry.skill)
    runtime.activeSkill = skill
    if os.clock() - runtime.stateSince >= LAMP_TIMEOUT then
        failState("XP lamp skill selection timed out.")
        return
    end
    if selectedLampChoice() ~= skill.choice then
        runtime.status = "Selecting " .. skill.name .. " on the XP lamp."
        if API.DoAction_Interface(0xffffffff, 0xffffffff, 1, ID.LAMP_INTERFACE, skill.component, -1,
                API.OFF_ACT_GeneralInterface_route) then
            API.RandomSleep2(400, 150, 250)
        else
            failState("Could not select " .. skill.name .. " on the XP lamp.")
        end
        return
    end
    runtime.lampActionSent = false
    runtime.useAllActionSent = false
    setState(STATE.USE_ALL, "Checking the small lamp 'Use all' option.")
end

local function ensureUseAll()
    if not runtime.activeSkill then
        setState(STATE.SELECT_SKILL, "Selecting the next lamp skill.")
        return
    end
    if not interfaceOpen() then
        setState(STATE.OPEN_LAMP, "Re-opening the XP lamp.")
        return
    end
    if isSmallLampUseAllChecked() then
        setState(STATE.CONFIRM_LAMP, "Confirming " .. runtime.activeSkill.name .. " XP.")
        return
    end
    if not runtime.useAllActionSent then
        runtime.status = "Enabling the small lamp 'Use all' option."
        if API.DoAction_Interface(0xffffffff, 0xffffffff, 0, ID.LAMP_USE_ALL_INTERFACE,
                ID.LAMP_USE_ALL_COMPONENT, -1, API.OFF_ACT_GeneralInterface_Choose_option) then
            runtime.useAllActionSent = true
            API.RandomSleep2(400, 150, 250)
            setState(STATE.CONFIRM_LAMP, "Confirming " .. runtime.activeSkill.name .. " XP.")
        else
            failState("Could not enable the small lamp 'Use all' option.")
        end
        return
    end
end

local function confirmLamp()
    if not runtime.activeSkill then
        setState(STATE.SELECT_SKILL, "Selecting the next lamp skill.")
        return
    end
    if not runtime.lampActionSent then
        if API.DoAction_Interface(0xffffffff, 0xffffffff, 0, ID.LAMP_INTERFACE, ID.LAMP_CONFIRM_COMPONENT,
                28, API.OFF_ACT_GeneralInterface_Choose_option) then
            runtime.lampActionSent = true
            runtime.lampDeadline = os.clock() + LAMP_TIMEOUT
        else
            failState("Could not confirm the XP lamp choice.")
        end
        return
    end
    local currentCount = Inventory:GetItemAmount(ID.SMALL_XP_LAMP) or 0
    if currentCount < runtime.lampCountBefore or not interfaceOpen() then
        local redeemedCount = math.max(0, runtime.lampCountBefore - currentCount)
        runtime.lampsRedeemed = runtime.lampsRedeemed + redeemedCount
        runtime.activeSkill = nil
        runtime.lampDeadline = 0
        transitionAfterTransaction(STATE.STEAL, "Lamp redeemed; resuming the Lamp stall.")
    elseif os.clock() >= runtime.lampDeadline then
        -- The client can leave the interface/count stale after a successful use-all action.
        -- Avoid retrying confirmation, which could consume another lamp stack.
        runtime.lampsRedeemed = runtime.lampsRedeemed + runtime.lampCountBefore
        runtime.activeSkill = nil
        runtime.lampDeadline = 0
        transitionAfterTransaction(STATE.STEAL, "Lamp redeemed; resuming the Lamp stall.")
    end
end

local function steal(eligibleIds)
    local tick = API.VB_FindPSett(3513, 0)
    if tick and tick.state ~= runtime.lastTick then
        runtime.lastTick = tick.state
        runtime.status = "Clicking the Lamp stall."
        Interact:Object("Lamp stall", "Steal from")
    else
        runtime.status = "Waiting for the Lamp stall."
    end
end

local function runMainLoop()
    API.SetDrawTrackedSkills(true)
    while API.Read_LoopyLoop() and not runtime.stopRequested do
        if not GUI.open then
            saveConfiguration()
            runtime.stopRequested = true
            API.Write_LoopyLoop(false)
            break
        end
        applyGuiActions()
        enforceLampStallArea()
        API.DoRandomEvents(math.random(300, 1200))
        local waitingForCatch = runtime.state == STATE.WAIT_FOR_CATCH

        if runtime.state == STATE.PAUSED or runtime.state == STATE.QUEUE_COMPLETE then
            API.RandomSleep2(250, 100, 200)
        elseif runtime.state == STATE.STEAL then
            if os.clock() < runtime.catchCooldownUntil then
                runtime.status = "Waiting for the captured impling to leave."
            else
                local levels = currentLevels()
                local active = activeQueueEntry(levels)
                local eligibleIds = eligibleImplingIds()
                local implingObjects = #eligibleIds > 0 and (API.ReadAllObjectsArray({ 1 }, eligibleIds, {}) or {}) or {}
                local butterflyObjects = config.catchButterfly and
                    (API.ReadAllObjectsArray({ 0 }, { ID.GUTHIX_BUTTERFLY }, {}) or {}) or {}
                local transition = LampStall.chooseStealTransition({
                    hasActiveQueue = active ~= nil,
                    inventoryFull = Inventory:IsFull(),
                    hasLamp = hasLamp(),
                    hasButterfly = #butterflyObjects > 0,
                    hasImpling = #implingObjects > 0,
                })
                if transition == STATE.QUEUE_COMPLETE then
                    config.running = false
                    setState(STATE.QUEUE_COMPLETE, "Lamp queue is complete. Add another target to continue.")
                elseif transition == STATE.OPEN_LAMP then
                    runtime.lampDeadline = 0
                    setState(STATE.OPEN_LAMP, "Inventory full; redeeming a lamp.")
                elseif transition == STATE.CATCH_IMPLING then
                    beginCatch("IMPLING", eligibleIds)
                elseif transition == STATE.CATCH_BUTTERFLY then
                    beginCatch("BUTTERFLY", { ID.GUTHIX_BUTTERFLY })
                elseif transition == STATE.PAUSED then
                    config.running = false
                    setState(STATE.PAUSED, "Inventory is full and needs attention.")
                else
                    steal(eligibleIds)
                end
            end
        elseif runtime.state == STATE.CATCH_IMPLING then
            beginCatch("IMPLING", eligibleImplingIds())
        elseif runtime.state == STATE.CATCH_BUTTERFLY then
            local butterflyObjects = API.ReadAllObjectsArray({ 0 }, { ID.GUTHIX_BUTTERFLY }, {}) or {}
            if #butterflyObjects > 0 then
                beginCatch("BUTTERFLY", { ID.GUTHIX_BUTTERFLY })
            else
                transitionAfterTransaction(STATE.STEAL, "Butterfly moved away; resuming the Lamp stall.")
            end
        elseif runtime.state == STATE.WAIT_FOR_CATCH then
            waitForCatch()
        elseif runtime.state == STATE.DROP_IMPLING_LOOT then
            dropImplingLoot()
        elseif runtime.state == STATE.OPEN_LAMP then
            openLamp()
        elseif runtime.state == STATE.SELECT_SKILL then
            selectLampSkill()
        elseif runtime.state == STATE.USE_ALL then
            ensureUseAll()
        elseif runtime.state == STATE.CONFIRM_LAMP then
            confirmLamp()
        end
        local finishingCatch = waitingForCatch or runtime.state == STATE.DROP_IMPLING_LOOT
        local waitingForImplingCooldown = runtime.state == STATE.STEAL
            and os.clock() < runtime.catchCooldownUntil
        if finishingCatch or waitingForImplingCooldown then
            API.RandomSleep2(75, 25, 50)
        else
            API.RandomSleep2(200, 100, 200)
        end
    end
end

local function cleanup()
    if runtime.cleanedUp then return end
    runtime.cleanedUp = true
    ClearRender()
end

ClearRender()
DrawImGui(function()
    if GUI.open then
        GUI.draw(buildGUIModel())
    end
end)

local ok, err = xpcall(runMainLoop, debug.traceback)
cleanup()
if not ok then
    print("LampStall error: " .. tostring(err))
    API.Write_LoopyLoop(false)
end
