--[[

@title Basic Necromancy Rituals
@description Peforms rituals
@author Higgins <discord@higginshax>
@date 08/08/2023
@version 1.0

Change settings below - required items, max idle time check, dismiss wandering souls...
Setup the "Place Focus" as required (the script will just click Start)
Ensure that ALL tiles are fully repaired
Start script

** BASIC/EARLY RELEASE - PLEASE WATCH BOT AND BE HAPPY BEFORE LEAVING ON ITS OWN **
** GREAT FOR LESSER NECROPLASM RITUAL **

--]]

local API = require("api")

-- [[ ID & SETTINGS ]] --

ID = {
    PEDESTAL = {
        NOT_FOCUSED = 127319,
        FOCUSED = 127320
    },
    PLATFORM = { 127315, 127316 },
    WANDERING_SOUL = 30493,
    BASIC_GHOSTLY_INK = 55594,
    WEAK_NECROPLASM = 55599
}

-- MAX OF TWO ITEMS TO CHECK - SCRIPT WILL STOP IF QUANTIY DROPS BELOW
-- ID, QUANTITY
REQUIRED_ITEMS = {
    [1] = {
        ID.BASIC_GHOSTLY_INK, 30
    },
    [2] = {
        ID.WEAK_NECROPLASM, 250
    }
}

DISMISS_WANDERING_SOULS = true
MAX_IDLE_TIME_MINUTES = 5

--[[ NO CHANGES ARE NEEDED BELOW ]]
--

CURRENT_CYCLE, SOUL_DIMISSED = 0, false
PLATFORM_TILE = {1038.5, 1770.5}
AFK_CHECK_TIME = os.time()

local function clickPedestal()
    if API.DoAction_Object1(0x29, 0, { ID.PEDESTAL.NOT_FOCUSED }, 50) then
        API.RandomSleep2(1800, 500, 500)
    end
end

local function clickPlatform(soulDismissed)
    if API.DoAction_Object1(0x29, 0, ID.PLATFORM, 50) then
        API.RandomSleep2(4500, 500, 500)
        if not soulDismissed then
            CURRENT_CYCLE = CURRENT_CYCLE + 1
        end
    end
end

local function isRitualOpen()
    return (API.VB_FindPSett(2874, 0).state == 589923)
end

local function findObj(objectid, distance)
    local distance = distance or 20
    return #API.GetAllObjArrayInteract({ objectid }, distance, 0) > 0
end

local function findNPC(npcid, distance)
    local distance = distance or 20
    return #API.GetAllObjArrayInteract({ npcid }, distance, 1) > 0
end

local function performRitual()
    API.DoAction_Interface(0x24, 0xffffffff, 1, 1224, 44, -1, 5392)
    API.RandomSleep2(300, 300, 200)
end

local function repairGlyphs()
    if API.DoAction_Object1(0x29, 160, { ID.PEDESTAL.NOT_FOCUSED, ID.PEDESTAL.FOCUSED }, 50) then
        CURRENT_CYCLE = 0
        API.RandomSleep2(1000, 300, 200)
    end
end

local function watchForSoul()
    if DISMISS_WANDERING_SOULS and findNPC(ID.WANDERING_SOUL) then
        API.DoAction_NPC(0x29, 3120, { ID.WANDERING_SOUL }, 50)
        SOUL_DIMISSED = true
        API.RandomSleep2(5000, 300, 200)
    end
end

local function idleCheck()
    local timeDiff = os.difftime(os.time(), AFK_CHECK_TIME)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        AFK_CHECK_TIME = os.time()
    end
end


while (API.Read_LoopyLoop()) do
    idleCheck()

    if API.InvStackSize(REQUIRED_ITEMS[1][1]) <= REQUIRED_ITEMS[1][2] or API.InvStackSize(REQUIRED_ITEMS[1][1]) <= REQUIRED_ITEMS[1][2] then
        API.Write_LoopyLoop(false)
        break;
    end

    if API.CheckAnim(10) or API.ReadPlayerMovin2() then
        if not API.ReadPlayerMovin2() then
            local p = API.PlayerCoordfloat()
            if (p.x == PLATFORM_TILE[1] and p.y == PLATFORM_TILE[2]) and API.VB_FindPSett(10937).state > 0 then
                API.RandomSleep2(100, 200, 200)
                watchForSoul()
                goto continue
            end
        end
        API.RandomSleep2(200, 200, 200)
    end

    if CURRENT_CYCLE <= 6 then
        if findObj(ID.PEDESTAL.NOT_FOCUSED, 30) then
            if isRitualOpen() then
                performRitual()
            else
                clickPedestal()
            end
        elseif findObj(ID.PEDESTAL.FOCUSED, 30) then
            clickPlatform(SOUL_DIMISSED)
            SOUL_DIMISSED = false
        end
    else
        repairGlyphs()
    end

    ::continue::

    API.RandomSleep2(100, 200, 200)
end