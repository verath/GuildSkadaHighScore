local addonName, addonTable = ...

-- Global functions for faster access
local format = format;
local tinsert = tinsert;

-- Set up module
local addon = addonTable[1];
local report = addon:NewModule("report", "AceHook-3.0")
addon.report = report;

-- AceGUI
local AceGUI = LibStub("AceGUI-3.0");

-- Constants
-- [25/02/01] #1. 24.5k - Saniera (Shadow, 680ilvl)
local PARSE_OUTPUT_FORMAT_NO_ILVL_SPEC = "[%s] #%d. %s - %s";
local PARSE_OUTPUT_FORMAT_NO_SPEC = PARSE_OUTPUT_FORMAT_NO_ILVL_SPEC .. " (%d ilvl)";
local PARSE_OUTPUT_FORMAT_NO_ILVL = PARSE_OUTPUT_FORMAT_NO_ILVL_SPEC .. " (%s)";
local PARSE_OUTPUT_FORMAT 		  = PARSE_OUTPUT_FORMAT_NO_ILVL_SPEC .. " (%s, %d ilvl)";

local PARSE_TIME_FORMAT = "%x";

local FILTER_TIME_FORMAT = "%m/%d/%y %H:%M";
local SEND_TO_CHANNELS_LIST = {
	SELF = "Self",
	SAY = "Say",
	PARTY = "Party",
	RAID = "Raid",
	GUILD = "Guild",
	INSTANCE_CHAT = "Instance",
	WHISPER = "Whisper"
};
local SEND_TO_CHANNELS_LIST_ORDER = {"SELF", "SAY", "PARTY", "RAID", "GUILD", "INSTANCE_CHAT", "WHISPER"};

local MAX_PARSES_TO_SEND = 30;

local function getParseStringFromParse(rank, parse)
	local dataNum = (parse.role == "HEALER") and parse.hps or parse.dps;
	dataNum = addon.gui:FormatNumber(dataNum);
	local name = parse.name;
	local spec = parse.specName;
	local itemLevel = parse.itemLevel;
	local time = date(PARSE_TIME_FORMAT, parse.startTime);

	if spec and itemLevel then
		return format(PARSE_OUTPUT_FORMAT, time, rank, dataNum, name, spec, itemLevel);
	elseif spec then
		return format(PARSE_OUTPUT_FORMAT_NO_ILVL, time, rank, dataNum, name, spec);
	elseif itemLevel then
		return format(PARSE_OUTPUT_FORMAT_NO_SPEC, time, rank, dataNum, name, itemLevel);
	else
		return format(PARSE_OUTPUT_FORMAT_NO_ILVL_SPEC, time, rank, dataNum, name);
	end
end


function report:SendData(channelId, whisperToName, dataTitle, filterString, parses, numParses)
	numParses = min(numParses, MAX_PARSES_TO_SEND);
	channelId = string.upper(channelId);

	local lines = {"--Guild Skada High Score--", dataTitle};

	if filterString then
		tinsert(lines, format("Filtered by [%s]", filterString));
	end

	for rank, parse in ipairs(parses) do
		local parseString = getParseStringFromParse(rank, parse);
		tinsert(lines, parseString);
		if(rank >= numParses) then
			break;
		end
	end

	if channelId == "SELF" then
		for _, line in ipairs(lines) do
			addon:Print(line);
		end
	elseif channelId == "WHISPER" then
		for _, line in ipairs(lines) do
			SendChatMessage(line, "WHISPER", nil, whisperToName);
		end
	else
		if channelId == "PARTY" and not IsInGroup() then
			return 
		end
		if channelId == "RAID" and not IsInRaid() then
			return
		end
		if channelId == "GUILD" and not IsInGuild() then
			return
		end

		for _, line in ipairs(lines) do
			SendChatMessage(line, channelId);
		end
	end
end


function report:ShowReportWindow(guildId, zoneId, difficultyId, encounterId, roleId, parses, filters)
	if self.currentFrame then
		self.currentFrame:Release();
		self.currentFrame = nil;
	end

	local channelId = self.lastChannelId or "SELF";

	local guildName = addon.highscore:GetGuildNameById(guildId);
	local zoneName = addon.highscore:GetZoneNameById(zoneId);
	local difficultyName = addon.highscore:GetDifficultyNameById(difficultyId);
	local encounterName = addon.highscore:GetEncounterNameById(encounterId);
	
	local dataTypeName;
	if roleId == "DAMAGER" then
		dataTypeName = "DPS"
	elseif roleId == "HEALER" then
		dataTypeName = "HPS"
	elseif roleId == "TANK" then
		dataTypeName = "DPS (Tanks)"
	else
		return;
	end
	
	local filterString;
	for filterKey, filterValue in pairs(filters) do
		if filterString then 
			filterString = filterString .. ", ";
		else
			filterString = "";
		end
		if filterKey == "name" then
			filterString = filterString .. "Name: " .. filterValue;
		elseif filterKey == "startTime" then
			filterString = filterString .. "Time: " .. date(FILTER_TIME_FORMAT, filterValue);
		else
			filterString = filterString .. filterKey .. ": " .. filterValue;
		end
	end

	local dataTitle = format("<%s> %s (%s) - %s", guildName, encounterName, difficultyName, dataTypeName);

	local frame = AceGUI:Create("Frame")
	frame:Hide();
	frame:EnableResize(false)
	frame:SetWidth(300);
	frame:SetHeight(300);
	frame:SetTitle("Report Data");
	frame:SetLayout("Flow");

	local dataTitleLabel = AceGUI:Create("Label");
	dataTitleLabel:SetText(dataTitle);
	dataTitleLabel:SetFullWidth(true);

	local filteredByLabel = AceGUI:Create("Label");
	filteredByLabel:SetText(format("Filtered by [%s]", filterString or ""));
	filteredByLabel:SetFullWidth(true);

	local channelDropdown = AceGUI:Create("Dropdown");
	channelDropdown:SetLabel("Channel");
	channelDropdown:SetList(SEND_TO_CHANNELS_LIST, SEND_TO_CHANNELS_LIST_ORDER);
	channelDropdown:SetValue(channelId);
	channelDropdown:SetFullWidth(true);
	channelDropdown:SetCallback("OnValueChanged", function(widget, evt, newChanId) 
		channelId = newChanId;
		self.lastChannelId = channelId;
	end);

	local whisperToNameEditBox = AceGUI:Create("EditBox");
	whisperToNameEditBox:SetFullWidth(true);
	whisperToNameEditBox:SetLabel("Whisper to");

	local numToSendSlider = AceGUI:Create("Slider");
	numToSendSlider:SetLabel("Number of Parses");
	numToSendSlider:SetFullWidth(true);
	numToSendSlider:SetSliderValues(1, min(#parses, MAX_PARSES_TO_SEND), 1);
	numToSendSlider:SetValue(min(#parses, MAX_PARSES_TO_SEND));

	local sendButton = AceGUI:Create("Button");
	sendButton:SetText("Send");
	sendButton:SetFullWidth(true);
	sendButton:SetCallback("OnClick", function()
		local numParses = numToSendSlider:GetValue();
		local whisperToName = whisperToNameEditBox:GetText();
		self:SendData(channelId, whisperToName, dataTitle, filterString, parses, numParses);
		report.currentFrame = nil;
		frame:Release();
	end);

	frame:AddChild(dataTitleLabel);
	if filterString then
		frame:AddChild(filteredByLabel);
	end
	frame:AddChild(channelDropdown);
	frame:AddChild(whisperToNameEditBox);
	frame:AddChild(numToSendSlider);
	frame:AddChild(sendButton);

	self.currentFrame = frame;
	frame:Show();
end