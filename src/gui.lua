local addonName, addonTable = ...

-- Global functions for faster access
local tinsert = tinsert;
local tContains = tContains;

-- Set up module
local addon = addonTable[1];
local gui = addon:NewModule("gui", "AceHook-3.0")
addon.gui = gui;

-- AceGUI
local AceGUI = LibStub("AceGUI-3.0");

-- Constants
local RAID_TIME_FORMAT = "%m/%d/%y %H:%M";

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
		dropdown:SetList(guilds);
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


function gui:CreateFilterEntry(filterId, filterValue)
	local container = AceGUI:Create("SimpleGroup");
	container:SetRelativeWidth(0.5);
	container:SetLayout("Flow");

	local label = AceGUI:Create("Label");
	label:SetRelativeWidth(0.65);
	
	if filterId == "startTime" then
		label:SetText("Time: " .. 
			date(RAID_TIME_FORMAT, filterValue));
	elseif filterId == "name" then
		label:SetText("Name: " .. filterValue);
	else 
		return;
	end


	local removeButton = AceGUI:Create("Button")
	removeButton:SetText("Remove");
	removeButton:SetHeight(18);
	removeButton:SetRelativeWidth(0.30);
	removeButton:SetCallback("OnClick", function()
		self:UnsetParseFilter(filterId);
	end)

	container:AddChild(label);
	container:AddChild(removeButton);

	return container;
end

-- Create the filter container, a row below the dropdowns
-- that displays the current selected filters.
-- Filtering by: "NameOfPlayer", "1/2/3 04:05"
function gui:CreateFilterContainer()
	local filterContainer = AceGUI:Create("InlineGroup");
	self.filterContainer = filterContainer;
	filterContainer:SetFullWidth(true);
	filterContainer:SetLayout("Flow");
	filterContainer:SetTitle("Filtered by");
	
	local nothingLabel = AceGUI:Create("Label");
	nothingLabel:SetText("-- Nothing, click on a player name or a time to filter. --");
	nothingLabel:SetFullWidth(true);
	filterContainer:AddChild(nothingLabel);

	return filterContainer;
end

-- Creates the headers for the parses:
-- Rank | DPS/HPS | Name | Spec | Item Level | Time
function gui:CreateHighScoreParseHeader()
	local headerContainer = AceGUI:Create("SimpleGroup");
	headerContainer:SetFullWidth(true);
	headerContainer:SetLayout("Flow");

	local labelDatas = {
		{"rank", "Rank"},
		{"dpsHps", "DPS/HPS"},
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
		{"spec", parse.specName},
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

	local parsesContainer = AceGUI:Create("SimpleGroup");
	self.highScoreParsesContainer = parsesContainer;
	parsesContainer:SetFullWidth(true);
	parsesContainer:SetLayout("Flow");

	scrollFrame:AddChild(self:CreateHighScoreParseHeader());
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
	frame:AddChild(self:CreateHighScoreTabGroup());

	return frame;
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

function gui:DisplayParseFilters()
	self.filterContainer:ReleaseChildren();

	local filterEntries = {}
	for filterId, filterValue in pairs(self.parseFilters) do
		local filterEntry = self:CreateFilterEntry(filterId, filterValue);
		tinsert(filterEntries, filterEntry);
	end

	if #filterEntries > 0 then		
		for _, filterEntry in ipairs(filterEntries) do
			self.filterContainer:AddChild(filterEntry)
		end
	else
		local nothingLabel = AceGUI:Create("Label");
		nothingLabel:SetText("-- Nothing, click on a name or a time to filter. --");
		nothingLabel:SetFullWidth(true);
		self.filterContainer:AddChild(nothingLabel);
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
	
	local parsesContainer = self.highScoreParsesContainer;
	local scrollFrame = self.highScoreParsesScrollFrame;
	parsesContainer:ReleaseChildren();

	if guildName and zoneId and difficultyId and encounter and roleId then
		local parses, _ = addon.highscore:GetParses(guildName, zoneId, difficultyId, encounter, roleId);
		parses = self:FilterParses(parses);

		if #parses > 0 then
			parsesContainer:PauseLayout();
			scrollFrame:PauseLayout();
			
			for rank, parse in ipairs(parses) do
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
		self.encounterDropdown:SetDisabled(false);
		self.encounterDropdown:SetList(encounters);
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
		self.difficultyDropdown:SetDisabled(false);
		self.difficultyDropdown:SetList(difficulties);
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
		self.zoneDropdown:SetDisabled(false);
		self.zoneDropdown:SetList(zones);
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

		if self.selectedGuild then
			-- Try to restore to same values as before
			gui:SetSelectedGuild(self.selectedGuild, true);
			gui:SetSelectedZone(self.selectedZone, true);
			gui:SetSelectedDifficulty(self.selectedDifficulty, true);
			gui:SetSelectedEncounter(self.selectedEncounter, true);
			gui:SetSelectedRole(self.selectedRole, true);
		elseif addon.guildName then 
			-- Try pre-selecting own guild if has one.
			gui:SetSelectedGuild(addon.guildName);
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
		self.highScoreParsesContainer = nil;
		self.highScoreParsesScrollFrame = nil;
	end
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
	self:UnHook("CloseSpecialWindows");
end