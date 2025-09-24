--[[
====================================================================================================
Sprinklers Manufacturing Script
====================================================================================================
Version: 1.0
Author: Higgins
Description: Automatically manufactures sprinklers using Inventor's workbench with banking support

Recommended Location: Fort Forinthry

Requirements:
- Access to Bank chest and Inventor's workbench
- Materials for sprinkler manufacturing
- Last bank preset configured with required materials

How it works:
1. Loads last bank preset from Bank chest
2. Checks for bucket of water (item 1929) in inventory
3. Uses Inventor's workbench to manufacture sprinklers
4. Configures correct manufacturing settings if needed
5. Handles completion dialogs and repeats the cycle

====================================================================================================
]]
--

local API = require("API")

-- Constants
local ITEM_IDS = {
	BUCKET_OF_WATER = 1929,
	SPRINKLER_COMPLETE = 8847,
}

local VB_SETTINGS = {
	PRODUCT = 1170,
	CATEGORY = 1169,
	SPRINKLER_ID = 37399,
	SKILLING_SUPPORT_ID = 6377,
	INVENTION_INTERFACE = 2874,
	PROCESSING = 2229,
}

local SETTINGS = {
	MAX_PRESET_ATTEMPTS = 3,
}

-- Global state tracking
local presetAttempts = 0

local INTERFACE_IDS = {
	CATEGORY_BUTTON = { component = 1371, subcomponent = 28 },
	SKILLING_OPTION = { component = 1477, subcomponent = 916, option = 3 },
}

-- Utility Functions
local function hasBucketOfWater()
	return Inventory:Contains(ITEM_IDS.BUCKET_OF_WATER)
end

local function hasCompletedSprinkler()
	return Inventory:GetItemAmount(ITEM_IDS.SPRINKLER_COMPLETE) > 0
end

local function isCorrectCategorySelected()
	local vb1169 = API.VB_FindPSettinOrder(VB_SETTINGS.CATEGORY)
	return vb1169 and vb1169.state == VB_SETTINGS.SKILLING_SUPPORT_ID
end

local function isCorrectProductSelected()
	local vb1170 = API.VB_FindPSettinOrder(VB_SETTINGS.PRODUCT)
	return vb1170 and vb1170.state == VB_SETTINGS.SPRINKLER_ID
end

local function isInventionInterfaceOpen()
	local vb2874 = API.VB_FindPSettinOrder(VB_SETTINGS.INVENTION_INTERFACE)
	if vb2874 then
		return vb2874.state == 40 or vb2874.state == 1310738
	end
	return false
end

-- Action Functions
local function loadBankPreset()
	presetAttempts = presetAttempts + 1
	print("Loading last bank preset (attempt " .. presetAttempts .. "/" .. SETTINGS.MAX_PRESET_ATTEMPTS .. ")")

	Interact:Object("Bank chest", "Load Last Preset from", 20)
	API.RandomSleep2(1000, 500, 500)

	-- Check if we got buckets after loading preset
	if not hasBucketOfWater() then
		if presetAttempts >= SETTINGS.MAX_PRESET_ATTEMPTS then
			print("ERROR: Failed to load preset with materials after " .. SETTINGS.MAX_PRESET_ATTEMPTS .. " attempts!")
			print("Bank may be out of materials or preset not configured correctly. Stopping script.")
			API.Write_LoopyLoop(false)
			return false
		else
			print("No bucket of water found, will retry preset loading...")
			return false
		end
	end

	print("Bank preset loaded successfully with materials")
	presetAttempts = 0 -- Reset counter on success
	return true
end

local function openInventorsWorkbench()
	print("Opening Inventor's workbench")
	Interact:Object("Inventor's workbench", "Manufacture", 20)
	API.RandomSleep2(1000, 500, 500)
end

local function configureCategoryAndProduct()
	print("Configuring category and product selection")

	-- Click category dropdown
	API.DoAction_Interface(
		0x2e,
		0xffffffff,
		1,
		INTERFACE_IDS.CATEGORY_BUTTON.component,
		INTERFACE_IDS.CATEGORY_BUTTON.subcomponent,
		-1,
		API.OFF_ACT_GeneralInterface_route
	)
	API.RandomSleep2(200, 50, 50)

	-- Select Skilling Support option
	API.DoAction_Interface(
		0xffffffff,
		0xffffffff,
		1,
		INTERFACE_IDS.SKILLING_OPTION.component,
		INTERFACE_IDS.SKILLING_OPTION.subcomponent,
		INTERFACE_IDS.SKILLING_OPTION.option,
		API.OFF_ACT_GeneralInterface_route
	)
	API.RandomSleep2(500, 200, 200)
end

local function handleCompletionDialog()
	if hasCompletedSprinkler() then
		print("Sprinkler completed, pressing space to continue")
		API.KeyboardPress2(0x20, 60, 100)
		API.RandomSleep2(300, 200, 200)
		return true
	end
	return false
end

local function isPlayerReady()
	return not API.ReadPlayerMovin2()
		and not API.CheckAnim(8)
		and (not API.isProcessing() or API.VB_FindPSettinOrder(VB_SETTINGS.PROCESSING).state == 0)
end

local function startManufacturing()
	print("Starting manufacturing - pressing space")
	API.KeyboardPress2(0x20, 60, 100)
	API.RandomSleep2(500, 200, 200)
end

-- Main Script
print("Starting Sprinklers Manufacturing Script")

API.SetDrawTrackedSkills(true)

while API.Read_LoopyLoop() do
	if isPlayerReady() then
		-- Handle completion dialog first
		if handleCompletionDialog() then
			goto continue
		end

		-- Check if we have materials
		if not hasBucketOfWater() then
			print("No bucket of water found, loading bank preset")
			if not loadBankPreset() then
				break
			end
			goto continue
		end

		-- Check if Invention interface is open
		if isInventionInterfaceOpen() then
			-- Check manufacturing settings
			if not isCorrectCategorySelected() or not isCorrectProductSelected() then
				print("Manufacturing settings need configuration")
				configureCategoryAndProduct()
			else
				print("Manufacturing settings correct, starting manufacturing")
				startManufacturing()
			end
		else
			-- Open Inventor's workbench
			print("Opening Inventor's workbench")
			openInventorsWorkbench()
		end
	end

	::continue::
	API.RandomSleep2(300, 300, 300)
end
