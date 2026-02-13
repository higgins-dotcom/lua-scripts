--[[

@title Necromancy Rituals
@description Peforms Rituals
@author Higgins <discord@higginshax>
@date 27/11/2023
@version 3.0

Disturbances handled
0-300%
[X] Moth
[X] Wandering Soul
[X] Sparking Glyph
[X] Shambling Horror
[X] Corrupt Glyphs
[X] Soul Storm
[X] Defile

Change settings below - max idle time check
Setup the "Place Focus" as required
Ensure that ALL tiles are fully repaired
Start script

--]]

local API = require("api")

local function getScriptDir()
    local info = debug.getinfo(1, "S")
    local src = info.source:sub(2)
    return src:match("(.*[/\\])") or ""
end

local SCRIPT_DIR = getScriptDir()
local GUI = require("NecromancyRituals.NecroRitualsGUI")
GUI.setScriptDirectory(SCRIPT_DIR)

-- [[ IDS & SETTINGS ]] --

ID = {
    PLATFORM = { 127315, 127316, 127314, 129034, 129033, 129032 },
    WANDERING_SOUL = 30493,
    SHAMBLING_HORROR = 30494,
    MOTH = 30419
}

startXp = API.GetSkillXP("NECROMANCY")

PLATFORM_TILE = {
    { 1038.5, 1770.5 },
    { 5794.5, 6448.5 },
}
REPAIR_CHECK = false
REPAIR_FAIL = 0
startTime, afk = os.time(), os.time()

local STOP_MESSAGES = {
    "necroplasm for this ritual",
    "have the materials to repair the following",
    "need the following materials to repair",
}

local REPAIR_MESSAGES = {
    "durability of 1",
    "nothing to repair",
}

local function clickPlatform()
    if API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, ID.PLATFORM, 50) then
        API.RandomSleep2(4500, 500, 500)
        REPAIR_FAIL = 0
    end
end

local function findPedestal()
    local objs = API.ReadAllObjectsArray({ 0 }, { -1 }, {})
    for _, obj in pairs(objs) do
        if (obj.CalcX == 1038 and obj.CalcY == 1776 and obj.Id ~= 127319 and obj.Action ~= "Place focus") or
            (obj.CalcX == 5787 and obj.CalcY == 6448 and obj.Id ~= 129035 and obj.Action ~= "Place focus") then
            return obj
        end
    end
    return false
end

local function findNpc(npcid, distance)
    local distance = distance or 20
    local npcs = API.GetAllObjArrayInteract({ npcid }, distance, { 1 })
    if #npcs > 0 then return npcs[1] else return false end
end

local function findNpcByAction(action)
    local npcs = API.ReadAllObjectsArray({ 1 }, { -1 }, {})
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
    local objs = API.ReadAllObjectsArray({ 1 }, { -1 }, {})
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
    if pedestal then
        if API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route2, { pedestal.Id }, 50) then
            REPAIR_CHECK = false
            API.RandomSleep2(800, 200, 200)
        end
    end
end

local function waitForGfxChange(targetGfx, timeout)
    local startTime = os.time()
    while os.time() - startTime < timeout do
        local objs = API.ReadAllObjectsArray({ 4 }, { targetGfx }, {})
        for _, obj in ipairs(objs) do
            if obj.Id == targetGfx then
                return true
            end
        end
        API.RandomSleep2(300, 500, 700)
    end
    return false
end

local function watchForDefile()
    if not GUI.getConfig().handleDefile then return false end
    local siphon = findNpcByAction("Siphon")
    if siphon then
        API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, { siphon.Id }, 50)
        API.RandomSleep2(800, 400, 400)
        API.WaitUntilMovingEnds()
        API.RandomSleep2(300, 400, 400)
        if waitForGfxChange(7930, 8) then
            siphon = findNpcByAction("Siphon")
            if API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, { siphon.Id }, 50) then
                API.RandomSleep2(800, 400, 400)
            end
        end
        return true
    end
end

local function watchForStorm()
    if not GUI.getConfig().handleSoulStorm then return false end
    local dissipate = findDissipate()
    if dissipate then
        API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, { dissipate.Id }, 50)
        API.RandomSleep2(800, 400, 400)
        API.WaitUntilMovingEnds()
        API.RandomSleep2(800, 400, 400)
        if waitForGfxChange(7916, 8) then
            dissipate = findDissipate()
            if dissipate then
                API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, { dissipate.Id }, 50)
                API.RandomSleep2(800, 400, 400)
            end
            if waitForGfxChange(7917, 8) then
                if dissipate then
                    API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, { dissipate.Id }, 50)
                    API.RandomSleep2(900, 400, 400)
                end
            end
        end
        return true
    end
end

local function watchForSoul()
    if not GUI.getConfig().handleWanderingSoul then return false end
    local soul = findNpc(ID.WANDERING_SOUL, 15)
    if soul then
        API.RandomSleep2(400, 300, 200)
        API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, { ID.WANDERING_SOUL }, 15)
        API.RandomSleep2(1200, 300, 200)
        API.WaitUntilMovingEnds()
        API.RandomSleep2(300, 300, 200)
    end
end

local function watchForMoth()
    if not GUI.getConfig().handleMoth then return false end
    if API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, { ID.MOTH }, 12) then
        API.RandomSleep2(600, 200, 200)
        API.WaitUntilMovingEnds()
        API.RandomSleep2(400, 200, 200)
    end
end

local function watchForSparkling()
    if not GUI.getConfig().handleSparkingGlyph then return false end
    local restore = findRestore()
    if restore then
        API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, { restore.Id }, 50)
        API.RandomSleep2(400, 200, 200)
        API.WaitUntilMovingEnds()
        API.RandomSleep2(600, 200, 200)
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
    if not GUI.getConfig().handleCorruptGlyphs then return false end
    while findCorrupt() do
        if not API.ReadPlayerMovin2() then
            API.RandomSleep2(500, 500, 500)

            local npcIDs = { 30495, 30496, 30497 }
            local npcFound = false

            for _, npcID in ipairs(npcIDs) do
                if API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, { npcID }, 20) then
                    API.RandomSleep2(400, 500, 600)
                    npcFound = true
                    break
                end
            end

            if not npcFound then
                break
            end
        end
    end
end

local function findNpcAtTile(tile)
    local allNpc = API.ReadAllObjectsArray({ 1 }, { -1 }, {})
    for _, v in pairs(allNpc) do
        if math.floor(v.TileX / 512) == tile.x and math.floor(v.TileY / 512) == tile.y then
            return v
        end
    end
    return false
end

local function findGlint()
    local objects = API.ReadAllObjectsArray({ 4 }, { 7977 }, {})
    for _, obj in ipairs(objects) do
        if obj.Id == 7977 then
            return obj
        end
    end
    return nil
end

local function clickTile(tile)
    local isDepleted = string.find(tile.Name, "depleted") ~= nil
    local action = isDepleted and 0xAE or 0x29
    local offset = isDepleted and API.OFF_ACT_InteractNPC_route2 or API.OFF_ACT_InteractNPC_route

    API.DoAction_NPC(action, offset, { tile.Id }, 50)
    API.RandomSleep2(600, 300, 300)
end

local function processGlintTile(glintTile)
    local tile = findNpcAtTile(glintTile)
    if tile then
        clickTile(tile)
        API.RandomSleep2(300, 300, 300)
        return true
    end
    return false
end

local function watchForHorror()
    if not GUI.getConfig().handleShamblingHorror then return false end
    local horror = findNpc(ID.SHAMBLING_HORROR, 50)
    if horror and horror.Anim < 0 then
        API.RandomSleep2(800, 800, 1200)
        API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, { ID.SHAMBLING_HORROR }, 50)
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
    return watchForCorrupt() or
        watchForSoul() or
        watchForHorror() or
        watchForMoth() or
        watchForSparkling() or
        watchForStorm() or
        watchForDefile()
end

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local cfg = GUI.getConfig()
    local maxIdle = cfg.maxIdleTime or 5
    local randomTime = math.random((maxIdle * 60) * 0.6, (maxIdle * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

local function CheckForNewMessages()
    local chatTexts = API.GatherEvents_chat_check()
    for k, v in pairs(chatTexts) do
        if k > 5 then break end
        local colorCode = string.match(v.text, "<col=EB2F2F>")
        if colorCode then
            for _, searchString in ipairs(STOP_MESSAGES) do
                if string.find(v.text, searchString) then
                    return true
                end
            end
            for _, searchString in ipairs(REPAIR_MESSAGES) do
                if string.find(v.text, searchString) then
                    if searchString == "durability of 1" then
                        REPAIR_CHECK = true
                    elseif searchString == "nothing to repair" then
                        REPAIR_FAIL = REPAIR_FAIL + 1
                    end
                end
            end
        end
    end
    return false
end

API.SetDrawTrackedSkills(true)
API.GatherEvents_chat_check()

local function waitForGUIStart()
    GUI.reset()
    GUI.loadConfig()

    local cfg = GUI.getConfig()
    
    if cfg.autoRun then
        GUI.started = true
        return API.Read_LoopyLoop()
    end

    ClearRender()
    DrawImGui(function()
        if GUI.open then GUI.draw({}) end
    end)

    while API.Read_LoopyLoop() and not GUI.started do
        if not GUI.open or GUI.isCancelled() then
            ClearRender()
            return false
        end
        API.RandomSleep2(100, 50, 0)
    end
    
    return API.Read_LoopyLoop()
end

local function startLiveGUI()
    GUI.selectInfoTab = true
    ClearRender()
    DrawImGui(function()
        if GUI.open then
            GUI.draw({})
        end
    end)
end

if not waitForGUIStart() then return end

startLiveGUI()

local currentStatus = "Idle"

while API.Read_LoopyLoop() do
    API.DoRandomEvents()

    if GUI.isPaused() then
        currentStatus = "Paused"
        API.RandomSleep2(500, 200, 200)
    elseif GUI.isStopped() then
        break
    else
        local cfg = GUI.getConfig()

        if type(API.SetMaxIdleTime) == "function" then
            API.SetMaxIdleTime(cfg.maxIdleTime or 5)
        else
            idleCheck()
        end

        if API.DoAction_Inventory1(55633, 0, 1, API.OFF_ACT_GeneralInterface_route) then
            API.RandomSleep2(400, 400, 400)
        end

        local vState = API.VB_FindPSettinOrder(10937, -1).state
        
        if cfg.disturbancesEnabled and vState > 0 then
            currentStatus = "Handling Disturbance"
            if watchForDisturbances() then
                goto continue
            end
        end

        if API.CheckAnim(10) or API.ReadPlayerMovin2() then
            if not API.ReadPlayerMovin2() then
                local p = API.PlayerCoordfloat()

                local match = false
                for _, tile in ipairs(PLATFORM_TILE) do
                    if p.x == tile[1] and p.y == tile[2] then
                        match = true
                        break
                    end
                end

                if match and cfg.disturbancesEnabled and vState > 0 then
                    currentStatus = "Ritual Active"
                    API.RandomSleep2(100, 200, 200)
                    goto continue
                end
            end
            currentStatus = "Moving"
            API.RandomSleep2(400, 200, 200)
        end

        if vState == 0 then
            if CheckForNewMessages() then
                break
            end

            if not findPedestal() then
                API.Write_LoopyLoop(false)
                print("Focused Pedestal not found.. exiting")
                break
            end

            if not findDepleted() then
                currentStatus = "Performing Ritual"
                clickPlatform()
            else
                currentStatus = "Repairing Glyphs"
                repairGlyphs()
                API.RandomSleep2(600, 300, 300)
            end
        else
            if findPedestal() then
                currentStatus = "Performing Ritual"
                clickPlatform()
            end
        end
        
        if currentStatus == "Idle" or currentStatus == "" then
            currentStatus = "Ritual Active"
        end
    end

    ::continue::
    GUI.draw({state = currentStatus})
    API.RandomSleep2(100, 200, 200)
end

print("Script ended")
