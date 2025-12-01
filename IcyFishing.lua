--[[

@title Icy Fishing
@description Fishes at the Icy Fishing spot at Christmas Village
@author Higgins <discord@higginshax>
@date 02/12/2023
@version 1.3

--]]

-- ## USER SETTINGS ## --
local MAX_IDLE_TIME_MINUTES = 10
-- ##      END      ## --

local API = require("api")

local ID = {
    ICY_FISHING_SPOT = 30755,
    FROZEN_FISH = {56165,56166,56167},
    BARREL_OF_FISH = 128783
}

local MAX_IDLE_TIME_MINUTES = 10

local function hasFrozenFish()
    return Inventory:ContainsAny(ID.FROZEN_FISH)
end

local function depositFish()
    Interact:Object("Barrel of fish", "Deposit all")
    API.RandomSleep2(800, 300, 300)
end

local function catch()
    Interact:NPC("Icy fishing spot", "Catch")
    API.RandomSleep2(2200, 300, 300)
end

API.SetDrawTrackedSkills(true)
API.SetMaxIdleTime(MAX_IDLE_TIME_MINUTES)

while (API.Read_LoopyLoop()) do

    if API.ReadPlayerMovin2() or (API.ReadPlayerAnim() > 0) then
        goto continue
    end

    if not API.InventoryInterfaceCheckvarbit() then
        API.KeyboardPress2(0x42, 60, 100)
        API.RandomSleep2(600, 300, 300)
        goto continue
    end

    if Inventory:IsFull() then
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
