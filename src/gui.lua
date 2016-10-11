-- 
-- gui.lua
-- 
-- Contains the main GUI module. This module is responsible
-- for the main frame of the addon.
--

local addonName, addonTable = ...

-- Cached globals
local tinsert = tinsert;
local floor = floor;
local pairs = pairs;
local unpack = unpack;
local date = date;
local ipairs = ipairs;
local format = format;
local wipe = wipe;
local next = next;

-- Non-cached globals (for mikk's FindGlobals script)
-- GLOBALS: Skada, RAID_CLASS_COLORS


-- Set up module
local addon = addonTable[1];
local gui = addon:NewModule("gui", "AceHook-3.0")
addon.gui = gui;

-- AceGUI
local AceGUI = LibStub("AceGUI-3.0");

-- Constants
local RAID_TIME_FORMAT = "%m/%d/%y %H:%M";


-- Takes an ace3 dropdown table (table of key=>value pairs)
-- and returns an ordering table that sorts the dropdown
-- in lexographical order
local function createDropdownOrderTable(dropdownTable)
	local data = {}
	for key, value in pairs(dropdownTable) do
		tinsert(data, {value=value, key=key})
	end
	sort(data, function(a, b)
		return a.value < b.value;
	end)
	local order = {}
	for i, v in ipairs(data) do
		tinsert(order, v.key);
	end
	return order;
end

-- Creats a row of labels taking up 1/numLabels relative
-- width per label and adds each label to the container.
-- The labels data should be a list of objects:
-- {name, text, modifyFunction, onClick}
function gui:CreateLabelRow(container, labelDatas)
	local relativeWidth = floor((1/#labelDatas)*100)/100;
	for _, labelData in pairs(labelDatas) do
		local _, text, modifyFunction, onClick = unpack(labelData);
		local label;
		if onClick then 
			label = AceGUI:Create("InteractiveLabel");
			label:SetCallback("OnClick", onClick);
		else
			label = AceGUI:Create("Label");
		end
		label:SetText(text);
		label:SetRelativeWidth(relativeWidth);
		if modifyFunction then
			modifyFunction(label)
		end
		container:AddChild(label);
	end
end

function gui:CreateGuildDropdown()
	local dropdown = AceGUI:Create("Dropdown");
	self.guildDropdown = dropdown;

	dropdown:SetLabel("Guild");
	dropdown:SetRelativeWidth(0.25);
	dropdown:SetCallback("OnValueChanged", function(widget, evt, guildId) 
		gui:SetSelectedGuild(guildId);
	end)

	local guilds, numGuilds = addon.highscore:GetGuilds();
	if numGuilds > 0 then
		local order = createDropdownOrderTable(guilds)
		dropdown:SetList(guilds, order);
	else
		dropdown:SetDisabled(true);
		dropdown:SetText("No Guilds.");
	end

	return dropdown;
end

function gui:CreateZoneDropdown()
	local dropdown = AceGUI:Create("Dropdown");
	self.zoneDropdown = dropdown;

	dropdown:SetLabel("Zone");
	dropdown:SetRelativeWidth(0.25);
	dropdown:SetList(nil);
	dropdown:SetDisabled(true);
	dropdown:SetCallback("OnValueChanged", function(widget, evt, zoneId) 
		gui:SetSelectedZone(zoneId);
	end)

	return dropdown;
end

function gui:CreateDifficultyDropdown()
	local dropdown = AceGUI:Create("Dropdown");
	self.difficultyDropdown = dropdown;

	dropdown:SetLabel("Difficulty");
	dropdown:SetRelativeWidth(0.25);
	dropdown:SetList(nil);
	dropdown:SetDisabled(true);
	dropdown:SetCallback("OnValueChanged", function(widget, evt, difficultyId) 
		gui:SetSelectedDifficulty(difficultyId);
	end)

	return dropdown;
end

function gui:CreateEncounterDropdown()
	local dropdown = AceGUI:Create("Dropdown");
	self.encounterDropdown = dropdown;

	dropdown:SetLabel("Encounter");
	dropdown:SetRelativeWidth(0.25);
	dropdown:SetList(nil);
	dropdown:SetDisabled(true);
	dropdown:SetCallback("OnValueChanged", function(widget, evt, encounterId) 
		gui:SetSelectedEncounter(encounterId);
	end)

	return dropdown;
end

function gui:CreateNoFilterSelectedLabel()
	local label = AceGUI:Create("Label");
	label:SetText("Nothing, click on a name or a time to filter.");
	label:SetFullWidth(true);

	return label;
end

function gui:CreateFilterEntry(filterId, filterValue)
	local filterText;
	if filterId == "startTime" then
		filterText = "Time: " .. date(RAID_TIME_FORMAT, filterValue);
	elseif filterId == "name" then
		filterText = "Name: " .. filterValue;
	elseif filterId == "specName" then
		filterText = "Spec: " .. filterValue
	else
		return nil;
	end

	local entryBtn = AceGUI:Create("Button")
	entryBtn:SetText(filterText);
	entryBtn:SetRelativeWidth(0.3);
	entryBtn:SetCallback("OnClick", function()
		self:UnsetParseFilter(filterId);
	end);

	return entryBtn;
end

-- Create the filter container, a row below the dropdowns
-- that displays the current selected filters.
-- Filtering by: "NameOfPlayer", "1/2/3 04:05"
function gui:CreateFilterContainer()
	local filterContainer = AceGUI:Create("InlineGroup");
	self.filterContainer = filterContainer;
	filterContainer:SetRelativeWidth(0.75);
	filterContainer:SetAutoAdjustHeight(false);
	filterContainer:SetHeight(60);
	filterContainer:SetLayout("Flow");
	filterContainer:SetTitle("Filtered by");
	
	filterContainer:AddChild(self:CreateNoFilterSelectedLabel());

	return filterContainer;
end

-- Creates the container for the action buttons, i.e.
-- Report/Purge.
function gui:CreateActionContainer()
	local actionContainer = AceGUI:Create("InlineGroup");
	actionContainer:SetRelativeWidth(0.25);
	actionContainer:SetAutoAdjustHeight(false);
	actionContainer:SetHeight(60);
	actionContainer:SetLayout("Flow");
	actionContainer:SetTitle("Actions");

	local reportBtn = AceGUI:Create("Button");
	self.reportButton = reportBtn;
	reportBtn:SetText("Report...");
	reportBtn:SetDisabled(true);
	reportBtn:SetRelativeWidth(1);
	reportBtn:SetCallback("OnClick", function()
		addon.report:ShowReportFrame(
			self.selectedGuild,
			self.selectedZone,
			self.selectedDifficulty,
			self.selectedEncounter,
			self.selectedRole,
			self.displayedParses,
			self.parseFilters);
	end);

	actionContainer:AddChild(reportBtn);
	return actionContainer;
end

-- Creates the headers for the parses:
-- Rank | DPS/HPS | Name | Spec | Item Level | Time
function gui:CreateHeaderRow(headerContainer, role)
	local dpsHpsText = (role == "HEALER") and "HPS" or "DPS";
	local labelDatas = {
		{"rank", "Rank"},
		{"dpsHps", dpsHpsText},
		{"name", "Name"},
		{"spec", "Spec"},
		{"ilvl", "Item Level"},
		{"time", "Time"}
	}
	self:CreateLabelRow(headerContainer, labelDatas);
	return headerContainer;
end

-- Creates a row for a parse entry. 
-- Rank | DPS/HPS | Name | Spec | Item Level | Time
function gui:CreateHighScoreParseEntry(parse, role, rank)
	local entryWidget = AceGUI:Create("SimpleGroup");
	entryWidget:SetFullWidth(true);
	entryWidget:SetLayout("Flow");
	entryWidget:SetHeight(30);
	
	local classColor = {RAID_CLASS_COLORS[parse.class].r, 
						RAID_CLASS_COLORS[parse.class].g, 
						RAID_CLASS_COLORS[parse.class].b};
	local dpsHps = self:FormatNumber((role == "HEALER") and parse.hps or parse.dps);

	local labelDatas = {
		{"rank", rank},
		{"dpsHps", dpsHps},
		{"name", 
			parse.name, 
			function(label) 
				label:SetColor(unpack(classColor));
			end, 
			function()
				self:ToggleParseFilter("name", parse.name);
			end
		},
		{"spec",
			parse.specName,
			nil,
			function()
				self:ToggleParseFilter("specName", parse.specName)
			end
		},
		{"ilvl", parse.itemLevel},
		{"time", 
			date(RAID_TIME_FORMAT, parse.startTime),
			nil,
			function()
				self:ToggleParseFilter("startTime", parse.startTime)
			end
		}
	}

	self:CreateLabelRow(entryWidget, labelDatas);
	return entryWidget;
end

function gui:CreateHighScoreScrollFrame()
	local scrollFrame = AceGUI:Create("ScrollFrame");
	scrollFrame:SetLayout("Flow");
	scrollFrame:SetFullWidth(true);
	scrollFrame:SetFullHeight(true);
	self.highScoreParsesScrollFrame = scrollFrame;

	local headerContainer = AceGUI:Create("SimpleGroup");
	headerContainer:SetFullWidth(true);
	headerContainer:SetLayout("Flow");
	self:CreateHeaderRow(headerContainer, "DAMAGER");
	self.highScoreHeaderContainer = headerContainer;

	local parsesContainer = AceGUI:Create("SimpleGroup");
	parsesContainer:SetFullWidth(true);
	parsesContainer:SetLayout("Flow");
	self.highScoreParsesContainer = parsesContainer;

	scrollFrame:AddChild(headerContainer);
	scrollFrame:AddChild(parsesContainer);

	return scrollFrame;
end

-- Creates container in the center of the GUI holding the parses.
-- The group has 3 tabs, one for each of DPSers, Healers and Tanks.
function gui:CreateHighScoreTabGroup()
	local container = AceGUI:Create("TabGroup");
	self.highScoreTabGroup = container;

	container:SetFullWidth(true);
	container:SetFullHeight(true);
	container:SetLayout("Fill");
	container:SetTabs({
		{value = "DAMAGER", text = "DPSers"},
		{value = "HEALER", text = "Healers"},
		{value = "TANK", text = "Tanks"}
	});
	container:SetCallback("OnGroupSelected", function(widget, evt, roleId)
		gui:SetSelectedRole(roleId);
	end)

	container:AddChild(self:CreateHighScoreScrollFrame());

	return container;
end

-- Creates the main GUI frame.
function gui:CreateMainFrame()
	local frame = AceGUI:Create("Frame")
	self.mainFrame = frame;

	frame:Hide();
	frame:SetWidth(800);
	frame:SetHeight(600);
	frame:SetTitle(format("Guild Skada High Score (%s)", addon.versionName));
	frame:SetLayout("Flow");
	frame:SetCallback("OnClose", function()
		gui:HideMainFrame();
	end)

	local dropdownContainer = AceGUI:Create("InlineGroup");
	dropdownContainer:SetLayout("Flow");
	dropdownContainer:SetFullWidth(true);
	dropdownContainer:SetTitle("Select an Encounter");

	dropdownContainer:AddChild(self:CreateGuildDropdown());
	dropdownContainer:AddChild(self:CreateZoneDropdown());
	dropdownContainer:AddChild(self:CreateDifficultyDropdown());
	dropdownContainer:AddChild(self:CreateEncounterDropdown());

	frame:AddChild(dropdownContainer);

	frame:AddChild(self:CreateFilterContainer());
	frame:AddChild(self:CreateActionContainer());
	frame:AddChild(self:CreateHighScoreTabGroup());

	return frame;
end

-- Formats a long number as a more human-readable version.
function gui:FormatNumber(number)
	if Skada and Skada.FormatNumber then
		return Skada:FormatNumber(number)
	else
		-- Default to Skada's implementation with numberformat enabled
		if number > 1000000 then
			return ("%02.2fM"):format(number / 1000000)
		else
			return ("%02.1fK"):format(number / 1000)
		end
	end
end

-- Takes a list of parse objects and applies filters them
-- by the attribute filters defined in parseFilters,
-- returning those passing all filters.
function gui:FilterParses(parses)
	if not self.parseFilters then 
		return parses 
	end;

	local filteredParses = {}
	for _, parse in ipairs(parses) do
		local passedAll = true;
		for attribute, matchValue in pairs(self.parseFilters) do
			if not parse[attribute] or parse[attribute] ~= matchValue then
				passedAll = false;
				break;
			end
		end
		if passedAll then
			tinsert(filteredParses, parse);
		end
	end
	return filteredParses;
end

function gui:SetParseFilter(attribute, value)
	self.parseFilters[attribute] = value;
	self:DisplayParses();
	self:DisplayParseFilters();
end

function gui:UnsetParseFilter(attribute)
	self:SetParseFilter(attribute, nil);
end

function gui:ToggleParseFilter(attribute, value)
	if self.parseFilters[attribute] ~= value then
		self:SetParseFilter(attribute, value);
	else
		self:UnsetParseFilter(attribute, value);
	end
end

-- Updates the currently selected filters box to match
-- the filters selected.
function gui:DisplayParseFilters()
	self.filterContainer:ReleaseChildren();

	local filterEntries = {}
	for filterId, filterValue in pairs(self.parseFilters) do
		local filterEntry = self:CreateFilterEntry(filterId, filterValue);
		if filterEntry then
			tinsert(filterEntries, filterEntry);
		end
	end

	if #filterEntries > 0 then		
		for _, filterEntry in ipairs(filterEntries) do
			self.filterContainer:AddChild(filterEntry)
		end
	else
		self.filterContainer:AddChild(self:CreateNoFilterSelectedLabel());
	end
end

-- Uses the currently selected guild/zone/diff/encounter/role
-- and attempts to fetch all parses for this combination. The
-- parses are also run trough #FilterParses before being displayed.
function gui:DisplayParses()
	local guildName = self.selectedGuild;
	local zoneId = self.selectedZone;
	local difficultyId = self.selectedDifficulty;
	local encounter = self.selectedEncounter;
	local roleId = self.selectedRole;
	
	self.reportButton:SetDisabled(true);

	local headerContainer = self.highScoreHeaderContainer;
	local parsesContainer = self.highScoreParsesContainer;
	local scrollFrame = self.highScoreParsesScrollFrame;
	headerContainer:ReleaseChildren();
	parsesContainer:ReleaseChildren();

	self:CreateHeaderRow(headerContainer, roleId);

	if guildName and zoneId and difficultyId and encounter and roleId then
		local parses, _ = addon.highscore:GetParses(guildName, zoneId, difficultyId, encounter, roleId);
		self.displayedParses = self:FilterParses(parses);

		if #self.displayedParses > 0 then
			self.reportButton:SetDisabled(false);
			parsesContainer:PauseLayout();
			scrollFrame:PauseLayout();
			
			for rank, parse in ipairs(self.displayedParses) do
				local entryWidget = self:CreateHighScoreParseEntry(parse, roleId, rank);
				parsesContainer:AddChild(entryWidget);
			end
			
			parsesContainer:ResumeLayout();
			parsesContainer:DoLayout();
			scrollFrame:ResumeLayout();
			scrollFrame:DoLayout();
			return;
		end
	end	

	local noParsesLabel = AceGUI:Create("Label");
	noParsesLabel:SetText("No parses found.");
	parsesContainer:AddChild(noParsesLabel);
end

function gui:SetSelectedRole(roleId, noPropagation)
	-- SelectTab, unlike SetValue for dropdowns, triggers the callback
	if self.selectedRole ~= roleId then
		self.selectedRole = roleId;
		self.highScoreTabGroup:SelectTab(roleId);
		self:DisplayParses();
	end
end

function gui:SetSelectedEncounter(encounterId, noPropagation)
	self.selectedEncounter = encounterId;
	self.encounterDropdown:SetValue(encounterId);
	self:DisplayParses();
end

function gui:SetSelectedDifficulty(difficultyId, noPropagation)
	self.selectedDifficulty = difficultyId;
	self.difficultyDropdown:SetValue(difficultyId);

	-- Update encounter dropdown with new guild, zone, difficulty
	local encounters, numEncounters = addon.highscore:GetEncounters(self.selectedGuild, self.selectedZone, self.selectedDifficulty);
	if numEncounters > 0 then
		local order = createDropdownOrderTable(encounters)
		self.encounterDropdown:SetDisabled(false);
		self.encounterDropdown:SetList(encounters, order);
	else
		self.encounterDropdown:SetDisabled(true);
		self.encounterDropdown:SetList(nil);
		self.encounterDropdown:SetText(nil);
	end

	if not noPropagation then
		if numEncounters == 1 then
			-- If only one option, select it.
			local encounterId, _ = next(encounters);
			self:SetSelectedEncounter(encounterId);
		else
			self:SetSelectedEncounter(nil);
		end
	end
end

function gui:SetSelectedZone(zoneId, noPropagation)
	self.selectedZone = zoneId;
	self.zoneDropdown:SetValue(zoneId);

	-- Update difficulty dropdown with new guild, zone
	local difficulties, numDifficulties = addon.highscore:GetDifficulties(self.selectedGuild, self.selectedZone);
	if numDifficulties > 0 then
		local order = createDropdownOrderTable(difficulties)
		self.difficultyDropdown:SetDisabled(false);
		self.difficultyDropdown:SetList(difficulties, order);
	else
		self.difficultyDropdown:SetDisabled(true);
		self.difficultyDropdown:SetList(nil);
		self.difficultyDropdown:SetText(nil);
	end

	if not noPropagation then
		if numDifficulties == 1 then
			-- If only one option, select it.
			local difficultyId, _ = next(difficulties);
			self:SetSelectedDifficulty(difficultyId);
		else
			self:SetSelectedDifficulty(nil);
		end
	end
end

function gui:SetSelectedGuild(guildId, noPropagation) 
	self.selectedGuild = guildId;
	self.guildDropdown:SetValue(guildId);

	-- Update zone dropdown for the new guild
	local zones, numZones = addon.highscore:GetZones(guildId);
	if numZones > 0 then
		local order = createDropdownOrderTable(zones)
		self.zoneDropdown:SetDisabled(false);
		self.zoneDropdown:SetList(zones, order);
	else
		self.zoneDropdown:SetDisabled(true);
		self.zoneDropdown:SetList(nil);
		self.zoneDropdown:SetText(nil);
	end

	if not noPropagation then
		if numZones == 1 then
			-- If only one option, select it.
			local zoneId, _ = next(zones);
			self:SetSelectedZone(zoneId);
		else
			self:SetSelectedZone(nil);
		end
	end
end

function gui:ShowMainFrame()
	if not self.mainFrame then
		-- Only show if not already shown
		self:CreateMainFrame():Show();

		-- Wipe previous session's parse filters if any
		-- as the filter container is always created as
		-- if no filters are selected.
		-- TODO: Create the gui differently to reflect
		-- selected parseFilters set already?
		wipe(self.parseFilters);

		if self.selectedGuild then
			-- Try to restore to same values as before
			gui:SetSelectedGuild(self.selectedGuild, true);
			gui:SetSelectedZone(self.selectedZone, true);
			gui:SetSelectedDifficulty(self.selectedDifficulty, true);
			gui:SetSelectedEncounter(self.selectedEncounter, true);
			gui:SetSelectedRole(self.selectedRole, true);
		else
			-- Try pre-selecting own guild if we have one and it exists
			-- in the database.
			local myGuildName = addon:GetGuildName("player");
			for guildId in pairs(addon.highscore:GetGuilds()) do
				if guildId == myGuildName then
					gui:SetSelectedGuild(guildId);
					break;
				end
			end
		end

		-- Have to do special for our tab group as it is never disabled
		gui:SetSelectedRole(self.selectedRole or "DAMAGER");
	end
end

function gui:HideMainFrame()
	if self.mainFrame then
		self.mainFrame:Release();
		
		-- Unset references
		self.mainFrame = nil;
		self.guildDropdown = nil;
		self.zoneDropdown = nil;
		self.difficultyDropdown = nil;
		self.encounterDropdown = nil;
		self.filterContainer = nil;
		self.highScoreTabGroup = nil;
		self.highScoreHeaderContainer = nil;
		self.highScoreParsesContainer = nil;
		self.highScoreParsesScrollFrame = nil;
		self.reportButton = nil;
	end
end

function gui:ToggleMainFrame()
	if self.mainFrame then self:HideMainFrame() else self:ShowMainFrame() end
end

function gui:OnCloseSpecialWindows()
	local found;
	if self.mainFrame then
		self:HideMainFrame()
		found = 1
	end
	return self.hooks["CloseSpecialWindows"]() or found;
end


function gui:OnEnable()
	self.parseFilters = {};

	self:RawHook("CloseSpecialWindows", "OnCloseSpecialWindows", true);
end

function gui:OnDisable()
	wipe(self.parseFilters);

	self:HideMainFrame();
	self:Unhook("CloseSpecialWindows");
end