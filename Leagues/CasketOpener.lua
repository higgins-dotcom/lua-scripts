--[[
====================================================================================================
Reward Casket Opener Script
====================================================================================================
Version: 1.0
Author: Higgins
Description: Opens reward caskets and extracts the reward value from the interface

Requirements:
- Reward caskets in inventory

How it works:
1. Finds "Reward casket" items in inventory
2. Opens the casket
3. Reads the reward value from interface {364, 11, -1, 0}
4. Extracts numerical value from "Current reward value: X,XXX,XXX" format
5. Logs the reward value

====================================================================================================
]]

local API = require("API")

-- Configuration
local CONFIG = {
	MIN_REROLL_VALUE = 1000000, -- Minimum reward value to accept (1M coins)
	USE_REROLLS = true, -- Set to false to disable rerolling
}

-- Interface path for reward casket results
local REWARD_INTERFACE = { { 364, 11, -1, 0 }, { 364, 13, -1, 0 }, { 364, 14, -1, 0 }, { 364, 16, -1, 0 } }

-- Casket type to reroll varbit mapping
local REROLL_VARBITS = {
	easy = 39450,
	medium = 39451,
	hard = 39452,
	elite = 39453,
	master = 39454,
}

-- Metrics tracking
local metrics = {
	startTime = os.time(),
	casketsOpened = 0,
	totalRewardValue = 0,
	highestReward = 0,
	lowestReward = math.huge,
	averageReward = 0,
	rerollsUsed = 0,
	rerollsAvailable = 0,
}

-- State tracking
local stateTracking = {
	lastProcessedCasketId = nil,
	hasOpenedCasketThisLoop = false,
	waitingForInterface = false,
	interfaceOpenTime = 0,
	lastRewardValue = 0,
	hasRerolledThisReward = false,
	currentCasketType = nil,
	waitingForRerollConfirmation = false,
}

-- Format numbers with commas
local function formatNumber(num)
	if not num or num == 0 then
		return "0"
	end
	local formatted = tostring(num)
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return formatted
end

-- Calculate and display metrics
local function calculateMetrics()
	local timeElapsed = os.time() - metrics.startTime
	local casketsPerHour = timeElapsed > 0 and math.floor((metrics.casketsOpened * 3600) / timeElapsed) or 0

	-- Calculate average reward
	if metrics.casketsOpened > 0 then
		metrics.averageReward = math.floor(metrics.totalRewardValue / metrics.casketsOpened)
	end

	-- Handle case where no caskets opened yet
	local lowestDisplay = metrics.lowestReward == math.huge and 0 or metrics.lowestReward

	-- Update rerolls available (show only for current casket type)
	metrics.rerollsAvailable = 0
	if stateTracking.currentCasketType and REROLL_VARBITS[stateTracking.currentCasketType] then
		local varbitId = REROLL_VARBITS[stateTracking.currentCasketType]
		local rerollVarbit = API.GetVarbitValue(varbitId)
		if rerollVarbit > 0 then
			metrics.rerollsAvailable = rerollVarbit
		end
	end

	local metricsTable = {
		{ "=== CASKET OPENER METRICS ===", "" },
		{
			"Runtime:",
			string.format("%d:%02d:%02d", timeElapsed // 3600, (timeElapsed % 3600) // 60, timeElapsed % 60),
		},
		{ "", "" },
		{ "=== CONFIGURATION ===", "" },
		{ "Min Reroll Value:", formatNumber(CONFIG.MIN_REROLL_VALUE) },
		{ "Use Rerolls:", CONFIG.USE_REROLLS and "Yes" or "No" },
		{ "", "" },
		{ "=== CASKETS ===", "" },
		{ "Caskets Opened:", formatNumber(metrics.casketsOpened) .. " (" .. casketsPerHour .. "/h)" },
		{ "Current Type:", stateTracking.currentCasketType or "None" },
		{ "", "" },
		{ "=== REROLLS ===", "" },
		{
			"Rerolls Available:",
			formatNumber(metrics.rerollsAvailable) .. " (" .. (stateTracking.currentCasketType or "none") .. ")",
		},
		{ "Rerolls Used:", formatNumber(metrics.rerollsUsed) },
		{ "", "" },
		{ "=== REWARDS ===", "" },
		{ "Total Value:", formatNumber(metrics.totalRewardValue) },
		{ "Average Value:", formatNumber(metrics.averageReward) },
		{ "Highest Reward:", formatNumber(metrics.highestReward) },
		{ "Lowest Reward:", formatNumber(lowestDisplay) },
	}

	return metricsTable
end

-- Extract casket type from name
local function getCasketType(casketName)
	if not casketName then
		return nil
	end

	local casketType = string.match(casketName, "Reward casket %((%w+)%)")
	if casketType then
		return casketType:lower()
	end

	-- Default to medium if no type specified
	return "medium"
end

-- Find reward casket in inventory and get its type
local function findRewardCasket()
	local inv = API.ReadInvArrays33()
	for _, item in ipairs(inv) do
		print(item.textitem, item.id)
		if item.itemid1 > 0 and item.textitem and string.find(item.textitem, "Reward casket") then
			local casketType = getCasketType(item.textitem)
			print("Found reward casket with ID:", item.itemid1, "Name:", item.textitem, "Type:", casketType)
			stateTracking.currentCasketType = casketType
			return item.itemid1, casketType
		end
	end
	return nil, nil
end

-- Extract reward value from interface text
local function extractRewardValue(text)
	if not text then
		return nil
	end

	-- Convert to string if it's not already
	local textStr = tostring(text)
	print("Attempting to extract from text:", textStr)

	-- Look for pattern "Current Reward Value: X,XXX,XXX coins!" (case insensitive)
	local valueStr = string.match(textStr, "[Cc]urrent [Rr]eward [Vv]alue:%s*([%d,]+)")
	if not valueStr then
		-- Try alternative patterns
		valueStr = string.match(textStr, "[Rr]eward [Vv]alue:%s*([%d,]+)")
		if not valueStr then
			valueStr = string.match(textStr, "[Vv]alue:%s*([%d,]+)")
			if not valueStr then
				-- Try to find any number with commas followed by "coins"
				valueStr = string.match(textStr, "([%d,]+)%s*coins")
				if not valueStr then
					-- Last resort: find any comma-separated number
					valueStr = string.match(textStr, "([%d,]+)")
				end
			end
		end
	end

	if valueStr then
		-- Remove commas and convert to number
		local cleanValue = string.gsub(valueStr, ",", "")
		local numValue = tonumber(cleanValue)
		if numValue then
			print("Extracted reward value:", formatNumber(numValue))
			return numValue
		end
	end

	print("Could not extract reward value from text:", textStr)
	return nil
end

-- Read reward value from interface
local function readRewardValue()
	print("Reading reward value from interface...")

	local interfaces = API.ScanForInterfaceTest2Get(false, REWARD_INTERFACE)
	if interfaces and #interfaces > 0 then
		print("Found reward interface")
		local rewardValue = extractRewardValue(interfaces[1].textids)
		if rewardValue then
			return rewardValue
		end
	end

	print("Could not read reward value from interface")
	return nil
end

-- Check if reward interface is open
local function isRewardInterfaceOpen()
	local interfaces = API.ScanForInterfaceTest2Get(true, { { 364, 11, -1, 0 } })
	return interfaces and #interfaces > 0
end

-- Get available rerolls for casket type
local function getAvailableRerolls(casketType)
	if not casketType or not REROLL_VARBITS[casketType] then
		print("Unknown casket type for rerolls:", casketType)
		return 0
	end

	local varbitId = REROLL_VARBITS[casketType]
	local rerollVarbit = API.GetVarbitValue(varbitId)

	if rerollVarbit > -1 then
		return rerollVarbit
	end

	return 0
end

-- Check if reroll confirmation screen is open
local function isRerollConfirmationOpen()
	local inf = {
		{ 364, 11, -1, 0 },
		{ 364, 13, -1, 0 },
		{ 364, 14, -1, 0 },
		{ 364, 18, -1, 0 },
		{ 364, 37, -1, 0 },
		{ 364, 39, -1, 0 },
		{ 364, 46, -1, 0 },
		{ 364, 47, -1, 0 },
	}
	local i = API.ScanForInterfaceTest2Get(false, inf)
	if i and #i > 0 then
		local value = i[1]
		local color = API.ReadDCColor(value.x + 19, value.y + 6)
		return color and color[4] == 4968186
	end
	return false
end

-- Click confirm on reroll confirmation screen
local function clickRerollConfirm()
	print("Clicking reroll confirm button...")
	API.DoAction_Interface(0x24, 0xffffffff, 1, 364, 44, -1, API.OFF_ACT_GeneralInterface_route)
	API.RandomSleep2(300, 400, 400)
	print("Reroll confirmed!")
end

-- Check if reroll button is available
local function isRerollButtonAvailable()
	-- Check if we have rerolls available for the current casket type
	if not stateTracking.currentCasketType then
		return false
	end
	return getAvailableRerolls(stateTracking.currentCasketType) > 0
end

-- Click reroll button
local function clickRerollButton()
	print("Clicking reroll button...")
	API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 364, 2, -1, API.OFF_ACT_GeneralInterface_route)
	API.RandomSleep2(400, 300, 300)

	-- Update metrics
	metrics.rerollsUsed = metrics.rerollsUsed + 1
	stateTracking.hasRerolledThisReward = true

	print("Reroll used! Total rerolls used:", metrics.rerollsUsed)
end

-- Check if reward should be rerolled
local function shouldRerollReward(rewardValue, casketType)
	if not CONFIG.USE_REROLLS then
		print("Rerolls disabled in config")
		return false
	end

	if stateTracking.hasRerolledThisReward then
		print("Already rerolled this reward")
		return false
	end

	if rewardValue >= CONFIG.MIN_REROLL_VALUE then
		print(
			"Reward value",
			formatNumber(rewardValue),
			"meets minimum threshold",
			formatNumber(CONFIG.MIN_REROLL_VALUE)
		)
		return false
	end

	local availableRerolls = getAvailableRerolls(casketType)
	if availableRerolls <= 0 then
		print("No rerolls available for", casketType, "caskets")
		return false
	end

	if not isRerollButtonAvailable() then
		print("Reroll button not available")
		return false
	end

	print("Reward value", formatNumber(rewardValue), "is below threshold", formatNumber(CONFIG.MIN_REROLL_VALUE))
	print("Available rerolls for", casketType, ":", availableRerolls)
	return true
end

-- Open reward casket
local function openRewardCasket(casketId)
	print("Opening reward casket with ID:", casketId)

	-- Only increment if we haven't opened a casket this loop
	print(stateTracking.hasOpenedCasketThisLoop)
	if not stateTracking.hasOpenedCasketThisLoop then
		API.DoAction_Inventory1(casketId, 0, 1, API.OFF_ACT_GeneralInterface_route)
		stateTracking.hasOpenedCasketThisLoop = true
		stateTracking.waitingForInterface = true
		stateTracking.interfaceOpenTime = os.time()
		API.RandomSleep2(300, 400, 600)
		return true
	end

	return false
end

-- Update metrics with reward value
local function updateMetrics(rewardValue)
	metrics.casketsOpened = metrics.casketsOpened + 1
	metrics.totalRewardValue = metrics.totalRewardValue + rewardValue

	if rewardValue > metrics.highestReward then
		metrics.highestReward = rewardValue
	end

	if rewardValue < metrics.lowestReward then
		metrics.lowestReward = rewardValue
	end

	print("Casket #" .. metrics.casketsOpened .. " opened! Reward value:", formatNumber(rewardValue))
	print("Total value so far:", formatNumber(metrics.totalRewardValue))
end

-- Close reward interface
local function closeRewardInterface()
	print("Closing reward interface...")
	API.KeyboardPress2(0x1B, 50, 60) -- ESC key
	API.RandomSleep2(300, 200, 200)
	stateTracking.waitingForInterface = false
end

-- Main processing function
local function processCaskets()
	-- Reset loop state
	stateTracking.hasOpenedCasketThisLoop = false

	-- Check if we're waiting for reroll confirmation
	if stateTracking.waitingForRerollConfirmation then
		if isRerollConfirmationOpen() then
			print("Reroll confirmation screen is open, clicking confirm...")
			clickRerollConfirm()
			stateTracking.waitingForRerollConfirmation = false
			-- Set up to wait for the new reward interface after reroll
			stateTracking.waitingForInterface = true
			stateTracking.interfaceOpenTime = os.time()
			return true
		else
			print("Waiting for reroll confirmation screen...")
			return true
		end
	end

	-- Check if we're waiting for interface to appear
	if stateTracking.waitingForInterface then
		local waitTime = os.time() - stateTracking.interfaceOpenTime

		if isRewardInterfaceOpen() then
			print("Reward interface is open, reading value...")
			local rewardValue = readRewardValue()

			if rewardValue then
				stateTracking.lastRewardValue = rewardValue

				-- Check if we should reroll this reward
				if shouldRerollReward(rewardValue, stateTracking.currentCasketType) then
					print("Rerolling reward of", formatNumber(rewardValue), "coins...")
					clickRerollButton()
					-- Set state to wait for confirmation screen
					stateTracking.waitingForRerollConfirmation = true
					return true
				else
					-- Accept the reward
					print("Accepting reward of", formatNumber(rewardValue), "coins")
					updateMetrics(rewardValue)
					-- Reset states for next casket
					stateTracking.hasRerolledThisReward = false
					stateTracking.waitingForInterface = false
					stateTracking.lastProcessedCasketId = nil -- Reset so we can process next casket
					return true
				end
			else
				print("Could not read reward value, continuing...")
				stateTracking.hasRerolledThisReward = false
				stateTracking.waitingForInterface = false
				stateTracking.lastProcessedCasketId = nil -- Reset so we can try again
				return false
			end
		elseif waitTime > 5 then
			print("Timeout waiting for reward interface, continuing...")
			stateTracking.waitingForInterface = false
			return false
		else
			print("Waiting for reward interface to appear... (" .. waitTime .. "s)")
			return true
		end
	end

	-- Look for reward caskets to open
	local casketId, casketType = findRewardCasket()
	if casketId then
		if casketId ~= stateTracking.lastProcessedCasketId then
			stateTracking.lastProcessedCasketId = casketId
			stateTracking.currentCasketType = casketType
			stateTracking.hasRerolledThisReward = false -- Reset for new casket
			return openRewardCasket(casketId)
		else
			print("Same casket ID as last processed, waiting...")
			return true
		end
	else
		print("No reward caskets found in inventory")
		return false
	end
end

-- Check if player is ready
local function isPlayerReady()
	return not API.ReadPlayerMovin2() and not API.CheckAnim(8)
end

API.SetMaxIdleTime(12)

-- Main script loop
local function main()
	print("Starting Reward Casket Opener...")
	print("Looking for reward caskets in inventory...")

	while API.Read_LoopyLoop() do
		-- Display metrics
		local metricsTable = calculateMetrics()
		API.DrawTable(metricsTable)

		-- Check if player is ready
		if not isPlayerReady() then
			print("Player is moving or animating, waiting...")
			API.RandomSleep2(600, 300, 300)
			goto continue
		end

		-- Process caskets
		local success = processCaskets()
		if not success and not stateTracking.waitingForInterface then
			print("No more caskets to process or error occurred")
			API.RandomSleep2(2000, 1000, 1000)
		else
			API.RandomSleep2(100, 100, 100)
		end

		::continue::
	end

	print("Script ended. Final metrics:")
	local finalMetrics = calculateMetrics()
	for _, row in ipairs(finalMetrics) do
		print(row[1], row[2])
	end
end

-- -- Start the script
main()
