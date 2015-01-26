local addonName, addonTable = ...

-- Global functions for faster access
local tinsert = tinsert;

-- Set up module
local addon = addonTable[1];
local report = addon:NewModule("report", "AceHook-3.0")
addon.report = report;

-- AceGUI
local AceGUI = LibStub("AceGUI-3.0");


function report:ShowReportWindow(guildId, zoneId, difficultyId, encounterId, parses)
	self:Debug(
		addon.highscore:GetGuildNameById(guildId),
		addon.highscore:GetZoneNameById(zoneId),
		addon.highscore:GetDifficultyNameById(difficultyId),
		addon.highscore:GetEncounterNameById(encounterId)
	);
	self.parses = parses;

	-- Using Frame instead of Window because ElvUI does not
	-- currently skin Window (1/24-15)
	--[[
	local frame = AceGUI:Create("Frame")
	frame:EnableResize(false)
	frame:SetWidth(400);
	frame:SetHeight(300);
	frame:SetTitle("Report Data");
	frame:SetLayout("Flow");
	frame:SetCallback("OnClose", function()
	end)
	--]]
end