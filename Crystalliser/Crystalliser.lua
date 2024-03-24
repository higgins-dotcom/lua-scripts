--[[
    Script: Crystalliser
    Description: Casts Crystallise onto trees and keeps popular woodcutting buffs active

    Author: Higgins
    Version: 1.1
    Release Date: 

    Release Notes:
    - Version 1.1 : Fixes
    - Version 1.0 : Initial Development
]]

local API                   = require('api')

local ID                    = {
    -- TREE = {70075},     -- Mahogany
    -- TREE = {92442},  -- Yew
    TREE = {109001, 109003, 109005, 109007}, -- Acadia
    EXCALIBUR = 14632,
    EXCALIBUR_AUGMENTED = 36619,
    ELVEN_SHARD = 43358,
    BEAVER_POUCH = 12021,
    TORSTOL = 47715,
    POTIONS = { 3030, 3028, 3026, 3024, 23409, 23407, 23405, 23403, 23401, 23399 },
    PERFECT_PLUS = { 33224, 33224, 33226, 33228, 33230, 33232, 33234 },
    PERFECT_JUJU = { 32753, 32755, 32757, 32759, 32849, 32851, 32853, 32855, 32857, 32859 },
}

local AREA                  = {
    JUNGLE = { x = 1, y = 1, z = 0 }
}

local skill                 = "WOODCUTTING"
local startXp               = API.GetSkillXP(skill)
local startTime, afk        = os.time(), os.time()
local MAX_IDLE_TIME_MINUTES = 15

local function round(val, decimal)
    if decimal then
        return math.floor((val * 10 ^ decimal) + 0.5) / (10 ^ decimal)
    else
        return math.floor(val + 0.5)
    end
end

local function formatNumber(num)
    if num >= 1e6 then
        return string.format("%.1fM", num / 1e6)
    elseif num >= 1e3 then
        return string.format("%.1fK", num / 1e3)
    else
        return tostring(num)
    end
end

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
    local currentXp = API.GetSkillXP(skill)
    local elapsedMinutes = (os.time() - startTime) / 60
    local diffXp = math.abs(currentXp - startXp);
    local xpPH = round((diffXp * 60) / elapsedMinutes);
    local time = formatElapsedTime(startTime)
    local currentLevel = API.XPLevelTable(API.GetSkillXP(skill))
    IGP.radius = calcProgressPercentage(skill, API.GetSkillXP(skill)) / 100
    IGP.string_value = time ..
        " | " ..
        string.lower(skill):gsub("^%l", string.upper) ..
        ": " .. currentLevel .. " | XP/H: " .. formatNumber(xpPH) .. " | XP: " .. formatNumber(diffXp)
end

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

local function setupGUI()
    IGP = API.CreateIG_answer()
    IGP.box_start = FFPOINT.new(5, 5, 0)
    IGP.box_name = "PROGRESSBAR"
    IGP.colour = ImColor.new(75, 0, 130)
    IGP.string_value = "WOODCUTTING"

    API.DrawProgressBar(IGP)
end

local function hasFam()
    return API.Buffbar_GetIDstatus(26095).id > 0
end

local function hasPouches()
    return API.InvItemcount_1(ID.BEAVER_POUCH) > 0
end

local function findCrystallise()
    local objects = API.ReadAllObjectsArray({4}, {5802}, {})
    for _, obj in ipairs(objects) do
        if obj.Id == 5802 then
            return obj
        end
    end
    return nil
end

local function findTree()
    local trees = API.ReadAllObjectsArray({0, 12}, ID.TREE, {})
    local crystallise = findCrystallise()
    if crystallise then
        local crystalliseTile = WPOINT.new(math.floor(crystallise.TileX / 512), math.floor(crystallise.TileY / 512), 0)
        for _, treeObj in ipairs(trees) do
            if treeObj.Bool1 == 0 then
                if math.floor(treeObj.TileX / 512) == crystalliseTile.x and math.floor(treeObj.TileY / 512) == crystalliseTile.y then
                    return treeObj
                end
            end
        end
    end
    return false
end

local function healthCheck()
    local doneAction = false
    local prayer = API.GetPrayPrecent()
    local elvenCD = API.DeBuffbar_GetIDstatus(ID.ELVEN_SHARD, false)
    local lightForm = API.Buffbar_GetIDstatus(26048, false)
    local lumberjackAura = API.Buffbar_GetIDstatus(26098, false)
    local elvenFound = API.InvItemcount_1(ID.ELVEN_SHARD)
    local torstol = API.Buffbar_GetIDstatus(ID.TORSTOL, false)
    local perfectPlus = API.Buffbar_GetIDstatus(33234, false)
    local perfectJuJu = API.Buffbar_GetIDstatus(32757, false)

    if not elvenCD.found and elvenFound > 0 then
        API.DoAction_Inventory1(ID.ELVEN_SHARD, 43358, 1, API.OFF_ACT_GeneralInterface_route)
        doneAction = true
    elseif prayer <= 12 then
        API.DoAction_Inventory2(ID.POTIONS, 0, 1, API.OFF_ACT_GeneralInterface_route)
        doneAction = true
    elseif prayer > 50 and not lightForm.found then
        local lf = API.GetABs_name1("Light Form")
        API.DoAction_Ability_Direct(lf, 1, API.OFF_ACT_GeneralInterface_route)
        doneAction = true
    elseif not perfectPlus.found and API.InvItemFound2(ID.PERFECT_PLUS) then
        API.DoAction_Inventory2(ID.PERFECT_PLUS, 0, 1, API.OFF_ACT_GeneralInterface_route)
        doneAction = true
    elseif not perfectPlus.found and not perfectJuJu.found and API.InvItemFound2(ID.PERFECT_JUJU) then
        API.DoAction_Inventory2(ID.PERFECT_JUJU, 0, 1, API.OFF_ACT_GeneralInterface_route)
        doneAction = true
    -- elseif not lumberjackAura.found then
        -- API.DoAction_Interface(0xffffffff, 0xffffffff, 5, 1464, 15, 14, API.OFF_ACT_GeneralInterface_route)
    elseif not torstol.found and API.InvStackSize(ID.TORSTOL) >= 10 then
        API.DoAction_Inventory1(ID.TORSTOL, 0, 2, API.OFF_ACT_GeneralInterface_route)
        doneAction = true
    elseif torstol.found and torstol.conv_text > 0 and torstol.conv_text == 50 and API.InvStackSize(ID.TORSTOL) >= 1 then
        API.DoAction_Inventory1(ID.TORSTOL, 0, 1, API.OFF_ACT_GeneralInterface_route)
        doneAction = true
    elseif not hasFam() and hasPouches() then
        if API.GetSummoningPoints_() < 40 and API.InvItemFound2(ID.POTIONS) then
            API.DoAction_Inventory2(ID.POTIONS, 0, 1, API.OFF_ACT_GeneralInterface_route)
            doneAction = true
        elseif API.GetSummoningPoints_() > 40 then
            API.DoAction_Inventory1(ID.BEAVER_POUCH, 0, 1, API.OFF_ACT_GeneralInterface_route)
            doneAction = true
        end
    end
    if doneAction then
        API.RandomSleep2(600, 500, 500)
    end
end

local function castCrystallise()
    local c = API.GetABs_name1("Crystallise")
    if c.enabled then
        API.DoAction_Ability_Direct(c, 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(300, 300, 300)
        if API.DoAction_Object_valid1(0x9D, API.OFF_ACT_GeneralObject_route00, ID.TREE, 20, true) then
            API.RandomSleep2(200, 300, 300)
        end
        return true
    end
    return false
end

local function chopTree()
    local tree2 = findTree()
    if tree2 then
        API.DoAction_Object_Direct(0x3B, API.OFF_ACT_GeneralObject_route0, tree2)
        API.RandomSleep2(600, 600, 600)
    end
end

local function checkRunes()

    local runes = {5887, 5898, 5888, 5905}
    local pass = true
    for index, rune in ipairs(runes) do
        local psett = VB_FindPSettinOrder(rune, -1)
        if psett.state <= 10 then
            pass = false
        end
    end
    return pass
end

setupGUI()

while API.Read_LoopyLoop() do
    idleCheck()
    API.DoRandomEvents()

    if startTime <= 1706408695 and os.time() >= 1706408695 then
        os.exit()
        break
    end

    healthCheck()
    if not checkRunes() then break end

    if API.ReadPlayerMovin2() or (API.CheckAnim(40) and findCrystallise()) then
        goto continue
    end

    if findCrystallise() then
        chopTree()
    else
        if not castCrystallise() then
            print("Error: Something wrong with casting Crystallise")
            break
        end
    end

    ::continue::
    printProgressReport()
    API.RandomSleep2(100, 100, 100)
end