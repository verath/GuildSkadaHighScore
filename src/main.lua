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

-- Cached globals
local tinsert = tinsert;
local format = format;
local time = time;
local tContains = tContains;
local IsInGuild = IsInGuild;
local GetGuildInfo = GetGuildInfo;
local GetInstanceInfo = GetInstanceInfo;
local GetRealZoneText = GetRealZoneText;
local UnitIsUnit = UnitIsUnit;
local GetExpansionLevel = GetExpansionLevel;
local GetDifficultyInfo = GetDifficultyInfo;
local UnitRealmRelationship = UnitRealmRelationship;
local FULL_PLAYER_NAME = FULL_PLAYER_NAME;
local LE_REALM_RELATION_SAME = LE_REALM_RELATION_SAME;
local LE_REALM_RELATION_VIRTUAL = LE_REALM_RELATION_VIRTUAL;

-- Non-cached globals (for mikk's FindGlobals script)
-- GLOBALS: LibStub

-- Create ACE3 addon
local addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

-- Add to addonTable, so our other files can access it (via ... at start of file)
tinsert(addonTable, addon);

-- Add to the global env, so other can access our addon as `GuildSkadaHighScore`
-- and also as "gshs" in debug mode
_G[addonName] = addon;
--@debug@
_G["gshs"] = addon;
--@end-debug@

-- Grab the current version string
addon.versionName = GetAddOnMetadata(addonName, "Version");
--@debug@
addon.versionName = '0.0.0-debug';
--@end-debug@

-- Set up a default prototype for all modules
local modPrototype = { Debug = function(self, ...) addon:Debug(...) end }
addon:SetDefaultModulePrototype(modPrototype)

-- The current db version. Migrate the database if 
-- version of database doesn't match this version.
addon.dbVersion = 11;

-- Db default settings
addon.dbDefaults = {
	realm = {
		modules = {},
		options = {},
		dbVersion = 1
	},
}


-- A flag for if debug information should be printed
local DEBUG_PRINT = false
--@debug@
DEBUG_PRINT = true;
--@end-debug@

-- A wrapper around :Pring that only prints if the
-- DEBUG_PRINT flag is set to true.
function addon:Debug(...)
	if DEBUG_PRINT then
		self:Print(...)
	end
end


-- Returns the name of the playerName's guild.
function addon:GetGuildName(playerName)
	playerName = playerName or "player";

	-- If the guild is cross-realm, add the realm to the name.
	-- From Blizzard_GuildUI.lua:21
	local guildName, _, _, realm = GetGuildInfo(playerName);
	if realm then
		return format(FULL_PLAYER_NAME, guildName, realm);
	else
		return guildName
	end
end

-- Tests if a player with name playerName is in the same
-- guild as the player running this addon.
function addon:IsInMyGuild(playerName)
	if UnitIsUnit(playerName, "player") then
		-- We are always in our own guild, even when
		-- we are not in a guild.
		return true;
	end

	if not IsInGuild() then
		return false;
	end

	local relation = UnitRealmRelationship(playerName)
	if not (relation == LE_REALM_RELATION_SAME or relation == LE_REALM_RELATION_VIRTUAL) then
		-- A player not on the same (connected) realm cannot be in our guild
		return false;
	end

	return (self:GetGuildName("player") == self:GetGuildName(playerName));
end

-- Tests if a zone is in the addon's tracked zones.
function addon:IsTrackedZone(instanceId)
	local trackDecision = self.options:GetInstanceTrackDecision(instanceId);
	if trackDecision then
		self:Debug("IsTrackedZone: trackDecision.shouldTrack = ", trackDecision.shouldTrack);
		return (trackDecision.shouldTrack == true);
	else
		self:Debug("IsTrackedZone: no trackDecision.");
		return false;
	end
end

-- Creates the "database" via AceDB
function addon:SetupDatabase()
	self.db = LibStub("AceDB-3.0"):New("GuildSkadaHighScoreDB", addon.dbDefaults, true)
	-- Make sure db version is in sync
	self.migrate:DoMigration();
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

	local difficultyName = GetDifficultyInfo(difficultyId);
	if not difficultyName then
		self:Debug(format("Could not map difficultyId %d to a name", difficultyId));
		return;
	end

	local guildName;
	if IsInGuild() then
		guildName = self:GetGuildName("player");
		if not guildName then
			self:Debug("Could not get the guild name of the player")
			return;
		end
	else
		-- A dummy name for a guild used to group entries for when
		-- not part of a guild.
		guildName = "<No Guild>";
		self:Debug("Not part of guild, adding entry to <No Guild>");
	end

	-- Get the current zone and make sure it is a tracked zone
	local zoneName, _, _, _, _, _, _, zoneId = GetInstanceInfo();
	if not zoneName then
		self:Debug("Could not find the name of the current zone");
		return;
	end
	if not self:IsTrackedZone(zoneId) then
		self:Debug("Not in a tracked zone");
		return;
	end

	local encounter = {
		guildName = guildName,
		zoneId = zoneId,
		zoneName = zoneName,
		id = encounterId,
		name = encounterName,
		difficultyId = difficultyId,
		difficultyName = difficultyName,
		raidSize = raidSize
	};

	-- Get parses from the parse provider
	local pmc = self.parseModulesCore;
	pmc:GetParsesForEncounter(encounter, function(success, startTime, duration, players)
		if not success then
			self:Debug("Skipping parse, success was false.");
			return;
		end

		encounter.startTime = startTime;
		encounter.duration = duration;

		addon.inspect:GetInspectDataForPlayers(players, function()
			addon.highscore:AddEncounterParsesForPlayers(encounter, players);
		end);
	end);
end

function addon:ENCOUNTER_END(evt, encounterId, encounterName, difficultyId, raidSize, endStatus)
	self:Debug("ENCOUNTER_END", encounterId, encounterName, difficultyId, raidSize, endStatus)
	if endStatus == 1 then 
		-- Encounter killed successful
		self:OnEncounterEndSuccess(encounterId, encounterName, difficultyId, raidSize);
	end
end

function addon:OnZoneChanged(evt)
	local instanceName, instanceType, _, _, _, _, _, instanceId = GetInstanceInfo();
	if instanceType ~= "raid" then
		return;
	end
	if self.options:HasInstanceTrackDecision(instanceId) then
		self:Debug("OnZoneChanged: Already has instance track decision");
	else
		self.options:SetInstanceTrackDecision(instanceId, instanceName, true)
		self:Printf("Added '%s' (%d) to Tracked Raids, it can be deselected in GSHS config.", instanceName, instanceId)
	end
end

function addon:OnInitialize()
	self:SetupDatabase();
end

function addon:OnEnable()
	self:RegisterEvent("ENCOUNTER_END")	
	self:RegisterEvent("ZONE_CHANGED", "OnZoneChanged")
	self:RegisterEvent("ZONE_CHANGED_INDOORS", "OnZoneChanged")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnZoneChanged")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnZoneChanged")
	self:RegisterChatCommand("gshs", function(arg)
		if arg == "config" then
			self.options:ShowOptionsFrame();
		else
			self.gui:ShowMainFrame();
		end
	end)

	if self.options:GetPurgeEnabled() then
		local maxDaysAge = self.options:GetPurgeMaxParseAge();
		local olderThanDate = time() - (maxDaysAge * 24 * 60 * 60);
		local minPlayerParsesPerFight = self.options:GetPurgeMinPlayerParsesPerFight();

		self:Debug("Purging old parses", olderThanDate, minPlayerParsesPerFight);
		self.highscore:PurgeParses(olderThanDate, minPlayerParsesPerFight);
	end
end

function addon:OnDisable()
	self:UnregisterEvent("ENCOUNTER_END")
	self:UnregisterEvent("ZONE_CHANGED")
	self:UnregisterEvent("ZONE_CHANGED_INDOORS")
	self:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self:UnregisterChatCommand("gshs");
end
