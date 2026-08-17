local API = require("API")

local GUI = {
	open = true,
	selectedSkill = 0,
	targetLevel = 99,
	actions = {},
	draftDirty = false,
}

local SCRIPT_DIR = ""
local CONFIG_DIR = ""
local CONFIG_PATH = ""
local persistenceAdapter = nil

local THEME = {
	dark = { 0.055, 0.065, 0.105 },
	medium = { 0.105, 0.125, 0.195 },
	light = { 0.24, 0.28, 0.43 },
	accent = { 0.68, 0.38, 1.00 },
	accentHi = { 0.82, 0.60, 1.00 },
	gold = { 1.00, 0.76, 0.30 },
	green = { 0.25, 0.88, 0.52 },
	red = { 0.96, 0.28, 0.34 },
	amber = { 1.00, 0.64, 0.22 },
	muted = { 0.56, 0.60, 0.72 },
	text = { 0.92, 0.94, 1.00 },
}

local function clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

local function queueAction(kind, payload)
	GUI.actions[#GUI.actions + 1] = { kind = kind, payload = payload }
end

local function sanitizeFilePart(value)
	return tostring(value or "default"):gsub('[%\\%/%:%*%?%"%<%>%|]', "_")
end

local function jsonEncode(value)
	if type(API.JsonEncode) == "function" then
		return API.JsonEncode(value)
	end
	local ok, json = pcall(require, "lib.json.json")
	if ok and json and type(json.encode) == "function" then return json.encode(value) end
	return nil
end

local function jsonDecode(value)
	if type(API.JsonDecode) == "function" then
		return API.JsonDecode(value)
	end
	local ok, json = pcall(require, "lib.json.json")
	if ok and json and type(json.decode) == "function" then return json.decode(value) end
	return nil
end

local function canWriteConfigDirectory()
	if persistenceAdapter and type(persistenceAdapter.canWriteDirectory) == "function" then
		return persistenceAdapter.canWriteDirectory(CONFIG_DIR) == true
	end
	if CONFIG_DIR == "" then return false end
	local probePath = CONFIG_DIR .. ".lampstall_probe"
	local file = io.open(probePath, "w")
	if not file then return false end
	file:close()
	os.remove(probePath)
	return true
end

local function ensureConfigDirectory()
	if persistenceAdapter and type(persistenceAdapter.ensureDirectory) == "function" then
		return persistenceAdapter.ensureDirectory(CONFIG_DIR) == true
	end
	if canWriteConfigDirectory() then return true end
	local separator = package.config and package.config:sub(1, 1) or "\\"
	local command
	if separator == "\\" then
		command = 'mkdir "' .. CONFIG_DIR:gsub("/", "\\") .. '" >nul 2>nul'
	else
		command = 'mkdir -p "' .. CONFIG_DIR .. '" >/dev/null 2>&1'
	end
	pcall(os.execute, command)
	return canWriteConfigDirectory()
end

function GUI.setScriptDirectory(dir)
	SCRIPT_DIR = dir or ""
	CONFIG_DIR = SCRIPT_DIR .. "configs/"
	local playerName = "default"
	if type(API.GetLocalPlayerName) == "function" then
		local ok, value = pcall(API.GetLocalPlayerName)
		if ok and value and value ~= "" then playerName = value end
	end
	CONFIG_PATH = CONFIG_DIR .. "lampstall." .. sanitizeFilePart(playerName) .. ".config.json"
end

function GUI.setPersistenceAdapter(adapter)
	persistenceAdapter = adapter
end

function GUI.getConfigPath()
	return CONFIG_PATH
end

function GUI.loadConfig()
	if CONFIG_PATH == "" then return nil end
	local content
	if persistenceAdapter and type(persistenceAdapter.read) == "function" then
		local ok, value = pcall(persistenceAdapter.read, CONFIG_PATH)
		if not ok then return nil end
		content = value
	else
		local file = io.open(CONFIG_PATH, "r")
		if not file then return nil end
		content = file:read("*a")
		file:close()
	end
	if not content or content == "" then return nil end
	local ok, data = pcall(jsonDecode, content)
	if not ok or type(data) ~= "table" then return nil end
	return data
end

function GUI.saveConfig(state)
	if type(state) ~= "table" or CONFIG_PATH == "" then return false end
	local data = {
		queue = state.queue or {},
		implings = state.implings or {},
		catchButterfly = state.catchButterfly ~= false,
		selectedSkill = state.selectedSkill,
		targetLevel = state.targetLevel,
	}
	local ok, encoded = pcall(jsonEncode, data)
	if not ok or type(encoded) ~= "string" then return false end
	if not ensureConfigDirectory() then return false end
	if persistenceAdapter and type(persistenceAdapter.write) == "function" then
		local writeOk, result = pcall(persistenceAdapter.write, CONFIG_PATH, encoded)
		return writeOk and result == true
	end
	local file = io.open(CONFIG_PATH, "w")
	if not file then return false end
	file:write(encoded)
	file:close()
	return true
end

function GUI.setDraft(selectedSkillKey, targetLevel, skills)
	if type(skills) == "table" then
		for index, skill in ipairs(skills) do
			if skill.key == selectedSkillKey then
				GUI.selectedSkill = index - 1
				break
			end
		end
	end
	GUI.targetLevel = clamp(tonumber(targetLevel) or 99, 1, 120)
	GUI.draftDirty = false
end

function GUI.getDraft(skills)
	local skill = skills and skills[GUI.selectedSkill + 1]
	return {
		selectedSkill = skill and skill.key or nil,
		targetLevel = clamp(GUI.targetLevel, 1, 120),
	}
end

function GUI.consumeDraftDirty()
	local dirty = GUI.draftDirty
	GUI.draftDirty = false
	return dirty
end

function GUI.popActions()
	local actions = GUI.actions
	GUI.actions = {}
	return actions
end

local function formatNumber(value)
	local text = tostring(math.floor(tonumber(value) or 0))
	while true do
		local replaced, count = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
		if count == 0 then return text end
		text = replaced
	end
end

local function formatCompactNumber(value)
	value = tonumber(value) or 0
	local absolute = math.abs(value)
	local divisor, suffix
	if absolute >= 1000000000 then
		divisor, suffix = 1000000000, "B"
	elseif absolute >= 1000000 then
		divisor, suffix = 1000000, "M"
	elseif absolute >= 1000 then
		divisor, suffix = 1000, "K"
	else
		return formatNumber(value)
	end
	local formatted = string.format("%.1f%s", value / divisor, suffix)
	return (string.gsub(formatted, "%.0([KMB])", "%1"))
end

local function formatXpSummary(xp, perHour)
	return formatNumber(xp) .. " (" .. formatCompactNumber(perHour) .. " XP/H)"
end

local function formatRuntime(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end

local function pushTextColor(color)
	ImGui.PushStyleColor(ImGuiCol.Text, color[1], color[2], color[3], 1.0)
end

local function textColored(color, value)
	pushTextColor(color)
	ImGui.Text(tostring(value))
	ImGui.PopStyleColor(1)
end

local function sectionHeading(label)
	pushTextColor(THEME.gold)
	ImGui.Text(label)
	ImGui.PopStyleColor(1)
	ImGui.Separator()
end

local function infoRow(label, value, color)
	ImGui.TableNextRow()
	ImGui.TableNextColumn()
	ImGui.Text(label)
	ImGui.TableNextColumn()
	if color then
		textColored(color, value)
	else
		ImGui.Text(tostring(value))
	end
end

local function drawControlTab(model)
	ImGui.Spacing()
	local runtime = model.runtime or {}
	local statusColor = THEME.accentHi
	if runtime.state == "QUEUE_COMPLETE" then statusColor = THEME.gold end
	if runtime.state == "PAUSED" then statusColor = THEME.amber end
	if runtime.error then statusColor = THEME.red end

	sectionHeading("STATUS")
	if model.inLampStallArea == false then
		textColored(THEME.red, "Move within 25 tiles of the Lamp stall to start.")
		if model.lampStallDistance then
			textColored(THEME.muted, string.format("Current distance: %.1f tiles", model.lampStallDistance))
		end
	else
		textColored(statusColor, tostring(runtime.status or "Ready."))
	end

	ImGui.Spacing()
	if model.running then
		sectionHeading("SESSION")
		if ImGui.BeginTable("##lampStats", 2) then
			ImGui.TableSetupColumn("Metric", ImGuiTableColumnFlags.WidthStretch, 0.35)
			ImGui.TableSetupColumn("Value", ImGuiTableColumnFlags.WidthStretch, 0.65)
			infoRow("Runtime", formatRuntime(model.runtimeSeconds or 0), THEME.accentHi)
			infoRow("Hunter level", model.hunterLevel or 1, THEME.green)
			infoRow("Lamps redeemed", formatNumber(runtime.lampsRedeemed or 0), THEME.gold)
			infoRow("Implings caught", formatNumber(runtime.implingsCaught or 0), THEME.accentHi)
			ImGui.EndTable()
		end

		ImGui.Spacing()
		sectionHeading("EXPERIENCE")
		if ImGui.BeginTable("##lampExperience", 2) then
			ImGui.TableSetupColumn("Skill", ImGuiTableColumnFlags.WidthStretch, 0.35)
			ImGui.TableSetupColumn("XP gained", ImGuiTableColumnFlags.WidthStretch, 0.65)
			infoRow("Thieving XP", formatXpSummary(model.thievingXpGained, model.thievingXpPerHour), THEME.accentHi)
			infoRow("Hunter XP", formatXpSummary(model.hunterXpGained, model.hunterXpPerHour), THEME.green)
			ImGui.EndTable()
		end
	end

	ImGui.Spacing()
	sectionHeading("CURRENT TARGET")
	if model.activeTarget then
		textColored(THEME.muted,
			"Active target: " .. model.activeTarget.name .. " " .. tostring(model.activeTarget.targetLevel))
	else
		textColored(THEME.muted, "Active target: none")
	end

	ImGui.Spacing()
	ImGui.TextWrapped("The queue runs from top to bottom. Completed rows stay visible and are skipped automatically.")
	ImGui.Spacing()

	local buttonColor = model.running and THEME.amber or THEME.green
	local buttonLabel = model.running and "Pause Script##lampPause" or "Start Script##lampStart"
	local startDisabled = not model.running and model.inLampStallArea == false
	ImGui.PushStyleColor(ImGuiCol.Button, buttonColor[1], buttonColor[2], buttonColor[3], 1.0)
	ImGui.PushStyleColor(ImGuiCol.ButtonHovered,
		clamp(buttonColor[1] + 0.12, 0, 1), clamp(buttonColor[2] + 0.12, 0, 1), clamp(buttonColor[3] + 0.12, 0, 1), 1.0)
	ImGui.PushStyleColor(ImGuiCol.Text, 0.02, 0.02, 0.02, 1.0)
	if startDisabled then ImGui.BeginDisabled(true) end
	if ImGui.Button(buttonLabel, -1, 30) then
		queueAction(model.running and "PAUSE" or "START")
	end
	if startDisabled then ImGui.EndDisabled() end
	ImGui.PopStyleColor(3)

	ImGui.Spacing()
	ImGui.PushStyleColor(ImGuiCol.Button, THEME.red[1], THEME.red[2], THEME.red[3], 0.9)
	ImGui.PushStyleColor(ImGuiCol.ButtonHovered,
		clamp(THEME.red[1] + 0.12, 0, 1), clamp(THEME.red[2] + 0.08, 0, 1), clamp(THEME.red[3] + 0.08, 0, 1), 1.0)
	ImGui.PushStyleColor(ImGuiCol.Text, 0.02, 0.02, 0.02, 1.0)
	if ImGui.Button("Exit##lampExit", -1, 28) then queueAction("STOP") end
	ImGui.PopStyleColor(3)
end

local function drawQueueTab(model)
	ImGui.Spacing()
	ImGui.Text("Build your lamp route")
	ImGui.TextColored(THEME.muted[1], THEME.muted[2], THEME.muted[3], 1.0,
		"Choose a skill, set the maximum level, then add it to the priority list.")
	ImGui.Spacing()

	local skillNames = {}
	for _, skill in ipairs(model.skills or {}) do skillNames[#skillNames + 1] = skill.name end
	local comboChanged, selected = ImGui.Combo("Skill##lampSkill", GUI.selectedSkill, skillNames, #skillNames)
	if comboChanged then
		GUI.selectedSkill = clamp(selected, 0, math.max(0, #skillNames - 1))
		GUI.draftDirty = true
	end

	local sliderChanged, sliderValue = ImGui.SliderInt("Target level##lampTarget", GUI.targetLevel, 1, 120, "%d", 0)
	if sliderChanged then
		GUI.targetLevel = clamp(sliderValue, 1, 120)
		GUI.draftDirty = true
	end
	local inputChanged, inputValue = ImGui.InputInt("Exact level##lampTargetExact", GUI.targetLevel, 1, 10, 0)
	if inputChanged then
		GUI.targetLevel = clamp(inputValue, 1, 120)
		GUI.draftDirty = true
	end

	if ImGui.Button("Add to priority queue##lampAdd", -1, 28) then
		local skill = model.skills and model.skills[GUI.selectedSkill + 1]
		if skill then
			queueAction("ADD_QUEUE", { skill = skill.key, targetLevel = GUI.targetLevel })
		end
	end

	ImGui.Spacing()
	if ImGui.BeginTable("##lampQueue", 5) then
		ImGui.TableSetupColumn("#", ImGuiTableColumnFlags.WidthFixed, 24)
		ImGui.TableSetupColumn("Skill", ImGuiTableColumnFlags.WidthStretch, 0.35)
		ImGui.TableSetupColumn("Target", ImGuiTableColumnFlags.WidthFixed, 58)
		ImGui.TableSetupColumn("Progress", ImGuiTableColumnFlags.WidthStretch, 0.35)
		ImGui.TableSetupColumn("Move", ImGuiTableColumnFlags.WidthFixed, 88)
		ImGui.TableHeadersRow()
		for index, entry in ipairs(model.queue or {}) do
			local current = (model.currentLevels or {})[entry.skill] or 1
			local complete = current >= entry.targetLevel
			local active = index == model.activeQueueIndex
			ImGui.TableNextRow()
			ImGui.PushID("queue" .. index)
			ImGui.TableNextColumn()
			if active then textColored(THEME.accentHi, index) else ImGui.Text(tostring(index)) end
			ImGui.TableNextColumn()
			local label = entry.skill
			if complete then label = label .. "  ✓" end
			if active then textColored(THEME.accentHi, label) elseif complete then textColored(THEME.muted, label) else ImGui.Text(label) end
			ImGui.TableNextColumn()
			ImGui.Text(tostring(entry.targetLevel))
			ImGui.TableNextColumn()
			ImGui.ProgressBar(clamp(current / math.max(1, entry.targetLevel), 0, 1), -1, 16,
				string.format("%d / %d", current, entry.targetLevel))
			ImGui.TableNextColumn()
			if ImGui.ArrowButton("up##queue", 2) then queueAction("MOVE_QUEUE_UP", index) end
			ImGui.SameLine()
			if ImGui.ArrowButton("down##queue", 3) then queueAction("MOVE_QUEUE_DOWN", index) end
			ImGui.SameLine()
			if ImGui.SmallButton("x##queue") then queueAction("REMOVE_QUEUE", index) end
			ImGui.PopID()
		end
		ImGui.EndTable()
	end

	ImGui.Spacing()
	if ImGui.Button("Clear queue##lampClear", -1, 25) then queueAction("CLEAR_QUEUE") end
end

local function drawImplingsTab(model)
	ImGui.Spacing()
	ImGui.Text("Bare-handed impling and butterfly capture")
	ImGui.TextColored(THEME.muted[1], THEME.muted[2], THEME.muted[3], 1.0,
		"Enabled types are checked by default. Implings use the nearest NPC; butterflies are detected separately.")
	ImGui.Spacing()
	if ImGui.Button("Select all##implings", -1, 25) then queueAction("SELECT_ALL_IMPLINGS") end
	if ImGui.Button("Clear all##implings", -1, 25) then queueAction("CLEAR_ALL_IMPLINGS") end
	ImGui.Spacing()
	local butterflyChanged, butterflyEnabled = ImGui.Checkbox("Guthixian butterfly##catchButterfly", model.catchButterfly == true)
	if butterflyChanged then queueAction("SET_BUTTERFLY", butterflyEnabled) end
	ImGui.Spacing()

	if ImGui.BeginTable("##implingGrid", 4) then
		ImGui.TableSetupColumn("Type", ImGuiTableColumnFlags.WidthStretch, 0.40)
		ImGui.TableSetupColumn("Level", ImGuiTableColumnFlags.WidthFixed, 48)
		ImGui.TableSetupColumn("Type", ImGuiTableColumnFlags.WidthStretch, 0.40)
		ImGui.TableSetupColumn("Level", ImGuiTableColumnFlags.WidthFixed, 48)
		for i = 1, #(model.implings or {}), 2 do
			ImGui.TableNextRow()
			for offset = 0, 1 do
				local impling = model.implings[i + offset]
				if impling then
					ImGui.TableNextColumn()
					ImGui.PushID(impling.key)
					local changed, value = ImGui.Checkbox(impling.name, impling.enabled)
					if changed then queueAction("SET_IMPLING", { key = impling.key, enabled = value }) end
					ImGui.PopID()
					ImGui.TableNextColumn()
					if impling.eligible then textColored(THEME.green, impling.level) else textColored(THEME.muted, impling.level) end
				end
			end
		end
		ImGui.EndTable()
	end
	ImGui.Spacing()
	ImGui.TextColored(THEME.muted[1], THEME.muted[2], THEME.muted[3], 1.0,
		"Loot is compared against the pre-catch inventory and only newly introduced non-lamp items are dropped.")
end

function GUI.draw(model)
	model = model or {}
	ImGui.SetNextWindowSize(350, 0, ImGuiCond.FirstUseEver)
	ImGui.SetNextWindowPos(120, 80, ImGuiCond.FirstUseEver)

	ImGui.PushStyleColor(ImGuiCol.WindowBg, THEME.dark[1], THEME.dark[2], THEME.dark[3], 0.98)
	ImGui.PushStyleColor(ImGuiCol.TitleBg, THEME.medium[1], THEME.medium[2], THEME.medium[3], 1.0)
	ImGui.PushStyleColor(ImGuiCol.TitleBgActive, THEME.accent[1], THEME.accent[2], THEME.accent[3], 1.0)
	ImGui.PushStyleColor(ImGuiCol.Separator, THEME.light[1], THEME.light[2], THEME.light[3], 0.65)
	ImGui.PushStyleColor(ImGuiCol.Text, THEME.text[1], THEME.text[2], THEME.text[3], 1.0)
	ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 14, 10)
	ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 8, 6)
	ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 5)
	ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 8)

	local isOpen, visible = ImGui.Begin("Lamp Stall###LampStallGUI", GUI.open)
	if not isOpen then GUI.open = false end
	if visible then
		local ok, err = pcall(function()
			if ImGui.BeginTabBar("##lampTabs", ImGuiTabBarFlags.None) then
				if ImGui.BeginTabItem("Control") then drawControlTab(model); ImGui.EndTabItem() end
				if ImGui.BeginTabItem("Lamp Queue") then drawQueueTab(model); ImGui.EndTabItem() end
				if ImGui.BeginTabItem("Implings") then drawImplingsTab(model); ImGui.EndTabItem() end
				ImGui.EndTabBar()
			end
		end)
		if not ok then
			textColored(THEME.red, "GUI error: " .. tostring(err))
		end
	end
	ImGui.End()

	ImGui.PopStyleVar(4)
	ImGui.PopStyleColor(5)
end

return GUI
