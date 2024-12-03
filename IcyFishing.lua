--[[

@title Icy Fishing
@description Fishes at the Icy Fishing spot at Christmas Village
@author Higgins <discord@higginshax>
@date 02/12/2023
@version 1.2

--]]

-- ## USER SETTINGS ## --
local MAX_IDLE_TIME_MINUTES = 10
-- ##      END      ## --

local API = require("api")

local ID = {
    ICY_FISHING_SPOT = 30755,
    FROZEN_FISH = { 56165, 56166, 56167 },
    BARREL_OF_FISH = 128783
}

local function hasFrozenFish()
    local fish = API.InvItemcount_2(ID.FROZEN_FISH)
    for _, v in ipairs(fish) do
        if v > 0 then
            return true
        end
    end
    return false
end

local function depositFish()
    API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { ID.BARREL_OF_FISH }, 50)
    API.RandomSleep2(800, 300, 300)
end

local function catch()
    API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, { ID.ICY_FISHING_SPOT }, 50)
    API.RandomSleep2(2200, 300, 300)
end

-- startChristmasSpirits = readChristmasSpirits()

API.SetDrawTrackedSkills(true)
API.SetMaxIdleTime(MAX_IDLE_TIME_MINUTES)

while (API.Read_LoopyLoop()) do
    API.DoRandomEvents()

    if API.ReadPlayerMovin2() or (API.ReadPlayerAnim() > 0) then
        goto continue
    end

    -- if not API.InventoryInterfaceCheckvarbit() then
    --     API.KeyboardPress2(0x42, 60, 100)
    --     API.RandomSleep2(600, 300, 300)
    --     goto continue
    -- end

    if API.InvFull_() then
        if hasFrozenFish() then
            depositFish()
        else
            print("InvFull - No frozen fish detected - stopping")
            API.Write_LoopyLoop(false)
            break
        end
    else
        catch()
    end

    ::continue::
    API.RandomSleep2(100, 200, 200)
end
