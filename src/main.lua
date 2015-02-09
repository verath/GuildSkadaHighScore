-- 
-- main.lua
-- 
-- Contains the main setup code for the addon and the modules and
-- some shared code that is used throughout the addon.
-- Also handles the quering of the parse module on ENCOUNTER_END
-- and forwarding these results, via the inspect module, to the
-- highscore module.
--

local addonName, addonTable = ...

local tinsert = tinsert;
local tremove = tremove;

-- Create ACE3 addon
local addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

tinsert(addonTable, addon);
_G[addonName] = addon;

-- Grab the current version string
addon.versionName = GetAddOnMetadata(addonName, "Version");
--@debug@
addon.versionName = '0.0.0-debug';
--@end-debug@

-- Set up a default prototype for all modules
local modPrototype = { Debug = function(self, ...) addon:Debug(...) end }
addon:SetDefaultModulePrototype(modPrototype)

-- Db default settings
addon.dbDefaults = {
	realm = {
		modules = {},
		options = {},
		dbVersion = 1
	},
}

-- The current db version. Migrate the database if 
-- version of database doesn't match this version.
addon.dbVersion = 10;

-- Constants
DEBUG_PRINT = false;
--@debug@
DEBUG_PRINT = true;
--@end-debug@


-- Takes a difficulty ID and attempts to return a string
-- representation of that difficulty.
local function getDifficultyNameById(difficultyId)
	if difficultyId == 7 or difficultyId == 17 then
		return "LFR";
	elseif difficultyId == 1 or difficultyId == 3 or difficultyId == 4 or difficultyId == 14 then
		return "Normal";
	elseif difficultyId == 2 or difficultyId == 5 or difficultyId == 6 or difficultyId == 15 then
		return "Heroic";
	elseif difficultyId == 16 then
		return "Mythic";
	end

	return nil
end

-- A wrapper around :Pring that only prints if the
-- DEBUG_PRINT flag is set to true.
function addon:Debug(...)
	if DEBUG_PRINT then
		self:Print(...)
	end
end

-- Function that updates the guild name of the player
-- by quering the GetGuildInfo method for the player.
function addon:UpdateMyGuildName()
	if IsInGuild() then
		local guildName, _, _ = GetGuildInfo("player")
		if guildName ~= nil then
			self.guildName = guildName
		end
	else
		self.guildName = nil
	end
end

-- Sets the current zone to the zone the player
-- is currently in.
function addon:UpdateCurrentZone()
	local zoneId, _ = GetCurrentMapAreaID()
	local zoneName = GetRealZoneText();
	self.currentZone = {id = zoneId, name = zoneName};
end

-- Tests if a player with name playerName is in the same
-- guild as the player running this addon.
function addon:IsInMyGuild(playerName)
	if self.guildName then
		local guildName, _, _ = GetGuildInfo(playerName)
		return guildName == self.guildName
	else
		return false
	end
end

-- Method called when ENCOUNTER_END was called and the success
-- status was true. 
-- This method uses the parse module to get a list of all valid 
-- parses. It then uses the inspect module to get additional 
-- information for the players with parses. Finally it forwards 
-- the results to the highscore module for it to store the data 
-- in the database.
function addon:OnEncounterEndSuccess(encounterId, encounterName, difficultyId, raidSize)
	self:Debug("OnEncounterEndSuccess")

	local difficultyName = getDifficultyNameById(difficultyId);
	if not difficultyName then
		self:Debug(format("Could not map difficultyId %d to a name", difficultyId));
		return;
	end

	local guildName = self.guildName;
	if not guildName then
		self:Debug("Not in a guild");
		return;
	end

	local encounter = {
		zoneId = self.currentZone.id,
		zoneName = self.currentZone.name,
		id = encounterId,
		name = encounterName,
		difficultyId = difficultyId,
		difficultyName = difficultyName,
		raidSize = raidSize
	};


	local function handleParses(success, startTime, duration, players)
		if not success then return end;
		encounter.startTime = startTime;
		encounter.duration = duration;

		addon.inspect:GetInspectDataForPlayers(players, function()
			addon.highscore:AddEncounterParsesForPlayers(guildName, encounter, players);
		end);
	end

	-- Get parses from the parse provider
	local pmc = self.parseModulesCore;
	pmc:GetParsesForEncounter(encounter, handleParses);
end

function addon:PLAYER_GUILD_UPDATE(evt, unitId)
	if unitId == "player" then
		self:UpdateMyGuildName()
	end
end

function addon:ENCOUNTER_END(evt, encounterId, encounterName, difficultyId, raidSize, endStatus)
	self:Debug("ENCOUNTER_END", encounterId, encounterName, difficultyId, raidSize, endStatus)
	if endStatus == 1 then 
		-- Encounter killed successful
		self:OnEncounterEndSuccess(encounterId, encounterName, difficultyId, raidSize);
	end
end

function addon:ZONE_CHANGED_NEW_AREA(evt)
	self:UpdateCurrentZone();
end

function addon:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("GuildSkadaHighScoreDB", addon.dbDefaults, true)
	
	-- Make sure db version is in sync
	self.migrate:DoMigration();
end

function addon:OnEnable()
	self.currentZone = {};
	self.guildName = nil;

	self:RegisterEvent("ENCOUNTER_END")	
	self:RegisterEvent("PLAYER_GUILD_UPDATE")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")

	self:RegisterChatCommand("gshs", function(arg)
		if arg == "config" then
			self.options:ShowOptionsFrame();
		else
			self.gui:ShowMainFrame();
		end
	end)

	self:UpdateMyGuildName();
	self:UpdateCurrentZone();
end

function addon:OnDisable()
	self.currentZone = {};
	self.guildName = nil;

	self:UnregisterEvent("ENCOUNTER_END")
	self:UnregisterEvent("PLAYER_GUILD_UPDATE")
	self:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
	
	self:UnregisterChatCommand("gshs");
end
