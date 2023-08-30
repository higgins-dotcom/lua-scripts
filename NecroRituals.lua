--[[

@title Necromancy Rituals
@description Peforms Rituals
@author Higgins <discord@higginshax>
@date 08/08/2023
@version 2.1

Disturbances handled
0-300%
[X] Moth
[X] Wandering Soul
[X] Sparking Glyph
[X] Shambling Horror
[X] Corrupt Glyphs
[X] Soul Storm

Change settings below - max idle time check
Setup the "Place Focus" as required
Ensure that ALL tiles are fully repaired
Start script

--]]

local API = require("api")

-- [[ IDS & SETTINGS ]] --

MAX_IDLE_TIME_MINUTES = 5

ID = {
    PLATFORM = { 127315, 127316, 127314 },
    WANDERING_SOUL = 30493,
    SHAMBLING_HORROR = 30494,
    MOTH = 30419
}

startXp = API.GetSkillXP("NECROMANCY")

--[[ NO CHANGES ARE NEEDED BELOW ]]

PLATFORM_TILE = { 1038.5, 1770.5 }
REPAIR_CHECK = false
startTime, afk = os.time(), os.time()

LAST_FOUND = {
    ["necroplasm for this ritual"] = startTime + 10,
    ["durability of 1"] = startTime + 10,
    ["have the materials to repair the following"] = startTime + 10
}

local function clickPlatform()
    if API.DoAction_Object1(0x29, 0, ID.PLATFORM, 50) then
        API.RandomSleep2(4500, 500, 500)
    end
end

local function findPedestal()
    local objs = API.ReadAllObjectsArray(true, 0)
    for _, obj in pairs(objs) do
        if obj.CalcX == 1038 and obj.CalcY == 1776 and obj.Id ~= 127319 then
            return obj
        end
    end
    return false
end

local function findNpc(npcid, distance)
    local distance = distance or 20
    return #API.GetAllObjArrayInteract({ npcid }, distance, 1) > 0
end

local function findNpcByAction(action)
    local npcs = API.ReadAllObjectsArray(true, 1)
    if #npcs > 0 then
        for _, npc in ipairs(npcs) do
            if string.find(tostring(npc.Action), action) then
                return npc
            end
        end
    end
    return false
end

local function findDepleted()
    local objs = API.ReadAllObjectsArray(true, 1)
    if #objs > 0 then
        for _, a in ipairs(objs) do
            if string.find(tostring(a.Name), "depleted") then
                return true
            end
        end
    end
    return false
end

local function findRestore()
    return findNpcByAction("Restore")
end

local function findDissipate()
    return findNpcByAction("Dissipate")
end

local function findCorrupt()
    return findNpcByAction("Deactivate")
end

local function repairGlyphs()
    local pedestal = findPedestal()
    if API.DoAction_Object1(0x29, 160, { pedestal.Id }, 50) then
        REPAIR_CHECK = false
        API.RandomSleep2(200, 200, 200)
    end
end

local function findStorm()
    local objs = API.ReadAllObjectsArray(true, 4)
    for _, obj in ipairs(objs) do
        if obj.Id == 7917 or obj.Id == 7916 then
            return true
        end
    end
    return false
end

local function watchForStorm()
    if findStorm() then
        for i = 1, 5, 1 do
            local dissipate = findDissipate()
            if dissipate then
                API.DoAction_NPC(0x29, 3120, { dissipate.Id }, 50)
                API.RandomSleep2(500, 400, 400)
                API.WaitUntilMovingEnds()
                API.RandomSleep2(300, 400, 400)
            end
        end
        API.RandomSleep2(100, 200, 200)
    end
end

local function watchForSoul()
    if findNpc(ID.WANDERING_SOUL, 15) then
        API.RandomSleep2(400, 300, 200)
        API.DoAction_NPC(0x29, 3120, { ID.WANDERING_SOUL }, 15)
        API.RandomSleep2(600, 300, 200)
        API.WaitUntilMovingEnds()
        API.RandomSleep2(300, 300, 200)
    end
end

local function watchForMoth()
    if API.DoAction_NPC(0x29, 3120, { ID.MOTH }, 12) then
        API.RandomSleep2(600, 200, 200)
        API.WaitUntilMovingEnds()
        API.RandomSleep2(400, 200, 200)
    end
end

local function watchForSparkling()
    local restore = findRestore()
    if restore then
        API.DoAction_NPC(0x29, 3120, { restore.Id }, 50)
        API.RandomSleep2(400, 200, 200)
        API.WaitUntilMovingEnds()
        API.RandomSleep2(1000, 200, 200)
    end
end

local function waitForCondition(condition, maxIterations, interval)
    for _ = 1, maxIterations do
        local result = condition()
        if result then
            return result
        end
        API.RandomSleep2(interval, interval, interval)
    end
    return false
end

local function watchForCorrupt()
    while findCorrupt() do
        API.RandomSleep2(500, 500, 500)

        local npcIDs = { 30495, 30496, 30497 }
        local npcFound = false

        for _, npcID in ipairs(npcIDs) do
            if API.DoAction_NPC(0x29, 3120, { npcID }, 20) then
                API.RandomSleep2(400, 500, 600)
                npcFound = true
                break
            end
        end

        API.RandomSleep2(200, 200, 200)

        if not npcFound then
            break
        end
    end
end

local function findNpcAtTile(tile)
    local allNpc = API.ReadAllObjectsArray(true, 1)
    for _, v in pairs(allNpc) do
        if math.floor(v.TileX / 512) == tile.x and math.floor(v.TileY / 512) == tile.y then
            return v
        end
    end
    return false
end

local function findGlint()
    local objects = API.ReadAllObjectsArray(true, 4)
    for _, obj in ipairs(objects) do
        if obj.Id == 7977 then
            return obj
        end
    end
    return nil
end

local function clickTile(tile)
    local action = string.find(tile.Action, "depleted") and 0xAE or 0x29
    API.DoAction_NPC(action, 3120, { tile.Id }, 50)
    API.RandomSleep2(300, 300, 300)
end

local function processGlintTile(glintTile)
    local tile = findNpcAtTile(glintTile)
    if tile then
        clickTile(tile)
        API.RandomSleep2(800, 600, 600)
        return true
    end
    return false
end

local function watchForHorror()
    if findNpc(ID.SHAMBLING_HORROR, 50) then
        API.RandomSleep2(600, 800, 1200)
        API.DoAction_NPC(0x29, 3120, { ID.SHAMBLING_HORROR }, 50)
        API.RandomSleep2(400, 600, 900)
        local glint = waitForCondition(findGlint, 12, 100)
        if glint then
            local glintTile = WPOINT.new(math.floor(glint.TileX / 512), math.floor(glint.TileY / 512), 0)
            if processGlintTile(glintTile) then
                return true
            end
        end
        API.RandomSleep2(200, 200, 400)
    end
    return false
end

local function watchForDisturbances()
    watchForCorrupt()
    watchForSoul()
    watchForHorror()
    watchForMoth()
    watchForSparkling()
    watchForStorm()
end

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

local function CheckForNewMessages(searchString)
    local chatTexts = ChatGetMessages()
    if chatTexts then
        for k, v in pairs(chatTexts) do
            if k > 5 then break end
            if string.find(tostring(v.text), searchString) then
                local hour, min, sec = string.match(v.text, "(%d+):(%d+):(%d+)")
                local currentDate = os.date("*t")
                currentDate.hour, currentDate.min, currentDate.sec = tonumber(hour), tonumber(min), tonumber(sec)
                local timestamp = os.time(currentDate)

                print(timestamp, LAST_FOUND[searchString])
                if timestamp > LAST_FOUND[searchString] then
                    LAST_FOUND[searchString] = timestamp
                    if searchString == "durability of 1" then
                        REPAIR_CHECK = true
                    end
                    return true
                end
            end
        end
    end
    return false
end


-- Rounds a number to the nearest integer or to a specified number of decimal places.
local function round(val, decimal)
    if decimal then
        return math.floor((val * 10 ^ decimal) + 0.5) / (10 ^ decimal)
    else
        return math.floor(val + 0.5)
    end
end

function formatNumber(num)
    if num >= 1e6 then
        return string.format("%.1fM", num / 1e6)
    elseif num >= 1e3 then
        return string.format("%.1fK", num / 1e3)
    else
        return tostring(num)
    end
end

-- Format script elapsed time to [hh:mm:ss]
local function formatElapsedTime(startTime)
    local currentTime = os.time()
    local elapsedTime = currentTime - startTime
    local hours = math.floor(elapsedTime / 3600)
    local minutes = math.floor((elapsedTime % 3600) / 60)
    local seconds = elapsedTime % 60
    return string.format("[%02d:%02d:%02d]", hours, minutes, seconds)
end

local function calcProgressPercentage(skill, currentExp)
    local currentLevel = API.XPLevelTable(API.GetSkillXP(skill))
    if currentLevel == 120 then return 100 end
    local nextLevelExp = XPForLevel(currentLevel + 1)
    local currentLevelExp = XPForLevel(currentLevel)
    local progressPercentage = (currentExp - currentLevelExp) / (nextLevelExp - currentLevelExp) * 100
    return math.floor(progressPercentage)
end

local function printProgressReport(final)
    local skill = "NECROMANCY"
    local currentXp = API.GetSkillXP(skill)
    local elapsedMinutes = (os.time() - startTime) / 60
    local diffXp = math.abs(currentXp - startXp);
    local xpPH = round((diffXp * 60) / elapsedMinutes);
    local time = formatElapsedTime(startTime)
    local currentLevel = API.XPLevelTable(API.GetSkillXP(skill))
    IGP.radius = calcProgressPercentage(skill, API.GetSkillXP(skill)) / 100
    IGP.string_value = time .. " | " .. string.lower(skill):gsub("^%l", string.upper) .. ": " .. currentLevel .." | XP/H: " .. formatNumber(xpPH) .. " | XP: " .. formatNumber(diffXp)
end

local function setupGUI()
    IGP = API.CreateIG_answer()
    IGP.box_start = FFPOINT.new(5, 5, 0)
    IGP.box_name = "PROGRESSBAR"
    IGP.colour = ImColor.new(116, 2, 179);
    IGP.string_value = "NECROMANY RITUALS"
end

function drawGUI()
    DrawProgressBar(IGP)
end

setupGUI()

while (API.Read_LoopyLoop()) do
    idleCheck()
    drawGUI()

    if API.VB_FindPSett(10937).state > 0 then
        watchForDisturbances()
    end

    if API.CheckAnim(10) or API.ReadPlayerMovin2() then
        if not API.ReadPlayerMovin2() then
            local p = API.PlayerCoordfloat()
            if (p.x == PLATFORM_TILE[1] and p.y == PLATFORM_TILE[2]) and API.VB_FindPSett(10937).state > 0 then
                API.RandomSleep2(100, 200, 200)
                goto continue
            end
        end
        API.RandomSleep2(400, 200, 200)
    end

    if API.VB_FindPSett(10937).state == 0 then
        if not findDepleted() then
            if not findPedestal() then
                API.Write_LoopyLoop(false)
                print("Focused Pedestal not found.. exiting")
                break;
            else
                clickPlatform()
            end
        else
            repairGlyphs()
            if CheckForNewMessages("You need the following materials to repair") then
                print("No materials for repair")
                break;
            end
            API.RandomSleep2(600, 300, 300)
        end
    else
        if findPedestal() then
            clickPlatform()
        end
    end

    ::continue::
    printProgressReport()
    API.RandomSleep2(100, 200, 200)
end