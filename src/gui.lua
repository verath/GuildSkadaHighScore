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


local classIdToClassName = {};
FillLocalizedClassList(classIdToClassName);

function gui:CreateHighScoreParseEntry(parse, role, rank)
	local entryWidget = AceGUI:Create("SimpleGroup");
	entryWidget:SetFullWidth(true);
	entryWidget:SetLayout("Flow");
	entryWidget:SetHeight(30);
	
	local classId = parse.class;
	local classColor = RAID_CLASS_COLORS[classId];
	local className = classIdToClassName[classId];

	local relativeWidth = floor((1/6)*100)/100;

	local rankLabel = AceGUI:Create("Label");
	rankLabel:SetText(rank);
	rankLabel:SetFontObject(GameFontHighlightLarge);
	rankLabel:SetRelativeWidth(relativeWidth);
	
	local dpsHpsLabel = AceGUI:Create("Label");
	local dpsHps = Skada:FormatNumber((role == "HEALER") and parse.hps or parse.dps);
	dpsHpsLabel:SetText(dpsHps);
	dpsHpsLabel:SetFontObject(GameFontHighlightLarge);
	dpsHpsLabel:SetRelativeWidth(relativeWidth);
	
	local nameLabel = AceGUI:Create("Label");
	nameLabel:SetText(parse.name);
	nameLabel:SetColor(classColor.r, classColor.g, classColor.b);
	nameLabel:SetFontObject(GameFontHighlightLarge);
	nameLabel:SetRelativeWidth(relativeWidth);

	local specLabel = AceGUI:Create("Label");
	specLabel:SetText(parse.specName or "");
	specLabel:SetFontObject(GameFontHighlightLarge);
	specLabel:SetRelativeWidth(relativeWidth);
	
	local ilvlLabel = AceGUI:Create("Label");
	ilvlLabel:SetText(parse.itemLevel or "");
	ilvlLabel:SetFontObject(GameFontHighlightLarge);
	ilvlLabel:SetRelativeWidth(relativeWidth);

	local dateLabel = AceGUI:Create("Label");
	dateLabel:SetText(date("%m/%d/%y", parse.startTime));
	dateLabel:SetFontObject(GameFontHighlightLarge);
	dateLabel:SetRelativeWidth(relativeWidth);
	
	entryWidget:AddChild(rankLabel);
	entryWidget:AddChild(dpsHpsLabel);
	entryWidget:AddChild(nameLabel);
	entryWidget:AddChild(specLabel);
	entryWidget:AddChild(ilvlLabel);
	entryWidget:AddChild(dateLabel);

	return entryWidget;
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

function gui:CreateHighScoreScrollFrame()
	local scrollFrame = AceGUI:Create("ScrollFrame");
	scrollFrame:SetLayout("Flow");
	scrollFrame:SetFullWidth(true);
	scrollFrame:SetFullHeight(true);

	self.highScoreParsesScrollFrame = scrollFrame;

	local relativeWidth = floor((1/6)*100)/100;

	-- Header:
	-- Rank | DPS/HPS | Name | Class | Spec | Item Level | Date
	local headerContainer = AceGUI:Create("SimpleGroup");
	headerContainer:SetFullWidth(true);
	headerContainer:SetLayout("Flow");
	
	local rankLabel = AceGUI:Create("Label");
	rankLabel:SetText("Rank");
	rankLabel:SetFontObject(GameFontHighlightLarge);
	rankLabel:SetRelativeWidth(relativeWidth);
	
	local dpsHpsLabel = AceGUI:Create("Label");
	dpsHpsLabel:SetText("DPS/HPS");
	dpsHpsLabel:SetFontObject(GameFontHighlightLarge);
	dpsHpsLabel:SetRelativeWidth(relativeWidth);
	
	local nameLabel = AceGUI:Create("Label");
	nameLabel:SetText("Name");
	nameLabel:SetFontObject(GameFontHighlightLarge);
	nameLabel:SetRelativeWidth(relativeWidth);
	
	local specLabel = AceGUI:Create("Label");
	specLabel:SetText("Spec");
	specLabel:SetFontObject(GameFontHighlightLarge);
	specLabel:SetRelativeWidth(relativeWidth);
	
	local ilvlLabel = AceGUI:Create("Label");
	ilvlLabel:SetText("Item Level");
	ilvlLabel:SetFontObject(GameFontHighlightLarge);
	ilvlLabel:SetRelativeWidth(relativeWidth);
	
	local dateLabel = AceGUI:Create("Label");
	dateLabel:SetText("Date");
	dateLabel:SetFontObject(GameFontHighlightLarge);
	dateLabel:SetRelativeWidth(relativeWidth);
	
	headerContainer:AddChild(rankLabel);
	headerContainer:AddChild(dpsHpsLabel);
	headerContainer:AddChild(nameLabel);
	headerContainer:AddChild(specLabel);
	headerContainer:AddChild(ilvlLabel);
	headerContainer:AddChild(dateLabel);

	local parsesContainer = AceGUI:Create("SimpleGroup");
	self.highScoreParsesContainer = parsesContainer;
	parsesContainer:SetFullWidth(true);
	parsesContainer:SetLayout("Flow");

	scrollFrame:AddChild(headerContainer);
	scrollFrame:AddChild(parsesContainer);

	return scrollFrame;
end

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

function gui:CreateMainFrame()
	local frame = AceGUI:Create("Frame")
	self.mainFrame = frame;

	frame:Hide()
	frame:SetWidth(800)
	frame:SetHeight(600)
	frame:SetTitle("Guild Skada High Score")
	frame:SetLayout("Flow")
	frame:SetCallback("OnClose", function()
		gui:HideMainFrame()
	end)

	frame:AddChild(self:CreateGuildDropdown());
	frame:AddChild(self:CreateZoneDropdown());
	frame:AddChild(self:CreateDifficultyDropdown());
	frame:AddChild(self:CreateEncounterDropdown());
	frame:AddChild(self:CreateHighScoreTabGroup());

	return frame;
end

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
		local parses, numParses = addon.highscore:GetParses(guildName, 
			zoneId, difficultyId, encounter, roleId);
		if numParses > 0 then
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
		self.highScoreTabGroup = nil;
		self.highScoreParsesContainer = nil;
		self.highScoreParsesScrollFrame = nil;
	end
end

function gui:OnCloseSpecialWindows()
	if self.mainFrame then
		self:HideMainFrame()
		return true
	else
		return self.hooks["CloseSpecialWindows"]();
	end
end


function gui:OnEnable()
	self:RawHook("CloseSpecialWindows", "OnCloseSpecialWindows");
end

function gui:OnDisable()
	self:HideMainFrame();
	self:UnHook("CloseSpecialWindows");
end