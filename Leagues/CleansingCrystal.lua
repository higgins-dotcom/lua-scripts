--[[
====================================================================================================
Cleansing Crystal Script
====================================================================================================
Version: 1.0
Author: Higgins
Description: Uses Cleansing crystal to cleanse the Corrupted Seren Stone in Hefin cathedral, Prifddinas

Requirements:
- Cleansing crystal (item ID: 32615) in inventory
- 75 Prayer level
- Access to Hefin cathedral in Prifddinas

How it works:
1. Uses cleansing crystal on Corrupted Seren Stone (first time)
2. Waits 1 second
3. Uses cleansing crystal on Corrupted Seren Stone (second time)
4. Waits 2.5 seconds
5. Uses cleansing crystal on Corrupted Seren Stone (third time)
6. Repeats the cycle continuously

Note: The Cleansing crystal is used to cleanse the Corrupted Seren Stone for Prayer training

====================================================================================================
]]
--

local API = require("API")

-- Constants
local OBJECT_IDS = { 94048 }
local REQUIRED_ITEM_ID = 32615
local ACTION_COUNT = 3
local WAIT_TIMES = { 800, 2500 }

-- Utility Functions
local function hasRequiredItem()
	return Inventory:Contains(REQUIRED_ITEM_ID)
end

-- Preflight checks
if not hasRequiredItem() then
	print("ERROR: Required item with ID " .. REQUIRED_ITEM_ID .. " not found in inventory!")
	return
end

-- Main Script
print("Starting Object Action Script")
print("Required item found in inventory!")
API.SetDrawTrackedSkills(true)

while API.Read_LoopyLoop() do
	-- Check if we still have the required item
	if not hasRequiredItem() then
		print("ERROR: Required item no longer in inventory! Stopping script.")
		break
	end
	for i = 1, ACTION_COUNT do
		print("Performing object action " .. i .. "/" .. ACTION_COUNT)

		API.DoAction_Object1(0x3d, API.OFF_ACT_GeneralObject_route0, OBJECT_IDS, 50)

		if i < ACTION_COUNT then
			local waitTime = WAIT_TIMES[i]
			print("Waiting " .. (waitTime / 1000) .. " seconds...")
			API.RandomSleep2(waitTime, 100, 200)
		end
	end

	print("Object Action cycle completed!")
	API.RandomSleep2(1000, 300, 300)
end
