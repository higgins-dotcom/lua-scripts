--[[

@title Necromancy Lesser Necroplasm Ritual
@description Peforms Lesser Necroplasm Ritual
@author Higgins <discord@higginshax>
@date 08/08/2023
@version 1.2

Change settings below - max idle time check, dismiss wandering souls...
Setup the "Place Focus" as required
Ensure that ALL tiles are fully repaired
Start script

** BASIC/EARLY RELEASE - PLEASE WATCH BOT AND BE HAPPY BEFORE LEAVING ON ITS OWN **

--]]

local API = require("api")

-- [[ IDS & SETTINGS ]] --

DISMISS_WANDERING_SOULS = true
MAX_IDLE_TIME_MINUTES = 5

ID = {
    PEDESTAL = {
        NOT_FOCUSED = 127319,
        FOCUSED = 127320
    },
    PLATFORM = { 127315, 127316, 127314 },
    WANDERING_SOUL = 30493,
    BASIC_GHOSTLY_INK = 55594,
    WEAK_NECROPLASM = 55599
}

--[[ NO CHANGES ARE NEEDED BELOW ]]

CURRENT_CYCLE = 0
PLATFORM_TILE = { 1038.5, 1770.5 }
LAST_FOUND = os.time()
REPAIR_CHECK, SOUL_DIMISSED = false, false
startXp = API.VB_FindPSett(7224).state
startTime, afk = os.time(), os.time()

LAST_FOUND = {
    ["necroplasm for this ritual"] = startTime + 10,
    ["durability of 1"] = startTime + 10,
    ["have the materials to repair the following"] = startTime + 10
}

local function clickPlatform(soulDismissed)
    if API.DoAction_Object1(0x29, 0, ID.PLATFORM, 50) then
        API.RandomSleep2(4500, 500, 500)
        if not soulDismissed then
            CURRENT_CYCLE = CURRENT_CYCLE + 1
        else
            SOUL_DIMISSED = false
        end
    end
end

local function scanForInterface(interfaceComps)
    return #(ScanForInterfaceTest2Get(true, interfaceComps)) > 0
end

local function isRitualOpen()
    return scanForInterface {
        InterfaceComp5.new(1224, 0, -1, -1, 0),
        InterfaceComp5.new(1224, 2, -1, 0, 0),
        InterfaceComp5.new(1224, 3, -1, 2, 0),
        InterfaceComp5.new(1224, 6, -1, 3, 0),
        InterfaceComp5.new(1224, 11, -1, 6, 0),
        InterfaceComp5.new(1224, 43, -1, 11, 0),
        -- InterfaceComp5.new(1224,43,3,43,0 )
    }
    -- return (API.VB_FindPSett(2874, 0).state == 589923) or (API.VB_FindPSett(2874, 0).state == 3244050)
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

local function findObj(objectid, distance)
    local distance = distance or 20
    return #API.GetAllObjArrayInteract({ objectid }, distance, 0) > 0
end

local function findNpc(npcid, distance)
    local distance = distance or 20
    return #API.GetAllObjArrayInteract({ npcid }, distance, 1) > 0
end

local function findRestore()
    local objs = API.ReadAllObjectsArray(true, 1)
    if #objs > 0 then
        for _, a in ipairs(objs) do
            if string.find(a.Action, "Restore") or string.find(a.Name, "Sparkling glyph") then
                return a
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

local function performRitual()
    local r = API.VB_FindPSett(11181, 0).state
    if r == 10 then
        API.DoAction_Interface(0x24, 0xffffffff, 1, 1224, 44, -1, 5392)
        API.RandomSleep2(300, 300, 200)
    else
        API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1224, 34, 10, 5392);
        API.RandomSleep2(300, 300, 200)
    end
end

local function repairGlyphs()
    local pedestal = findPedestal()
    if API.DoAction_Object1(0x29, 160, { pedestal.Id }, 50) then
        REPAIR_CHECK = false
        API.RandomSleep2(200, 200, 200)
    end
end

local function watchForSoul()
    if DISMISS_WANDERING_SOULS and findNpc(ID.WANDERING_SOUL) then
        API.RandomSleep2(400, 300, 200)
        API.DoAction_NPC(0x29, 3120, { ID.WANDERING_SOUL }, 50)
        API.RandomSleep2(300, 300, 200)
        API.WaitUntilMovingEnds()
        API.RandomSleep2(300, 300, 200)
        SOUL_DIMISSED = true
    end
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

-- Format a number with commas as thousands separator
local function formatNumberWithCommas(amount)
    local formatted = tostring(amount)
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k == 0) then
            break
        end
    end
    return formatted
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

local function printProgressReport(final)
    local currentXp = API.VB_FindPSett(7224).state
    local elapsedMinutes = (os.time() - startTime) / 60
    local diffXp = math.abs(currentXp - startXp);
    local xpPH = round((diffXp * 60) / elapsedMinutes);
    local time = formatElapsedTime(startTime)
    IG.string_value = "Necromancy XP : " .. formatNumberWithCommas(diffXp) .. " (" .. formatNumberWithCommas(xpPH) .. ")"
    IG2.string_value = ""
    IG4.string_value = time
    if final then
        print(os.date("%H:%M:%S") ..
        " Script Finished\nRuntime : " .. time .. "\nNecromancy XP : " .. formatNumberWithCommas(diffXp))
    end
end

local function setupGUI()
    IG = API.CreateIG_answer()
    IG.box_start = FFPOINT.new(15, 40, 0)
    IG.box_name = "NECRO"
    IG.colour = ImColor.new(255, 255, 255);
    IG.string_value = "Necromancy XP : 0 (0)"

    IG2 = API.CreateIG_answer()
    IG2.box_start = FFPOINT.new(15, 55, 0)
    IG2.box_name = "STRING"
    IG2.colour = ImColor.new(255, 255, 255);
    IG2.string_value = ""

    IG3 = API.CreateIG_answer()
    IG3.box_start = FFPOINT.new(40, 5, 0)
    IG3.box_name = "TITLE"
    IG3.colour = ImColor.new(0, 255, 0);
    IG3.string_value = "- Necromancy Rituals -"

    IG4 = API.CreateIG_answer()
    IG4.box_start = FFPOINT.new(70, 21, 0)
    IG4.box_name = "TIME"
    IG4.colour = ImColor.new(255, 255, 255);
    IG4.string_value = "[00:00:00]"

    IG_Back = API.CreateIG_answer();
    IG_Back.box_name = "back";
    IG_Back.box_start = FFPOINT.new(0, 0, 0)
    IG_Back.box_size = FFPOINT.new(235, 80, 0)
    IG_Back.colour = ImColor.new(15, 13, 18, 255)
    IG_Back.string_value = ""
end

function drawGUI()
    API.DrawSquareFilled(IG_Back)
    API.DrawTextAt(IG)
    API.DrawTextAt(IG2)
    API.DrawTextAt(IG3)
    API.DrawTextAt(IG4)
end

setupGUI()

while (API.Read_LoopyLoop()) do
    idleCheck()
    drawGUI()

    -- if CheckForNewMessages("necroplasm for this ritual") then
    --     API.Write_LoopyLoop(false)
    --     break;
    -- end

    if API.CheckAnim(10) or API.ReadPlayerMovin2() then
        if not API.ReadPlayerMovin2() then
            local p = API.PlayerCoordfloat()
            if (p.x == PLATFORM_TILE[1] and p.y == PLATFORM_TILE[2]) and API.VB_FindPSett(10937).state > 0 then
                API.RandomSleep2(100, 200, 200)
                watchForSoul()
                local restore = findRestore()
                if restore then
                    API.DoAction_NPC(0x29, 3120, { restore.Id }, 50)
                    API.RandomSleep2(400, 200, 200)
                    API.WaitUntilMovingEnds()
                    API.RandomSleep2(700, 200, 200)
                end
                goto continue
            end
        end
        API.RandomSleep2(400, 200, 200)
    end

    -- CheckForNewMessages("durability of 1")

    if API.VB_FindPSett(10937).state == 0 then
        if not findDepleted() then
            if not findPedestal() then
                API.Write_LoopyLoop(false)
                print("Focused Pedestal not found.. exiting")
                break;
            else
                clickPlatform(SOUL_DIMISSED)
            end
        else
            repairGlyphs()
            if CheckForNewMessages("have the materials to repair the following") then
                print("No materials for repair")
                break;
            end
            API.RandomSleep2(600, 300, 300)
        end
    else
        if findPedestal() then
            clickPlatform(SOUL_DIMISSED)
        end
    end

    ::continue::
    printProgressReport()
    API.RandomSleep2(100, 200, 200)
end