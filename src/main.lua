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
		options = {}
	},
	global = {
		dbVersion = 1
	}
}

-- The current db version. Clear (migrate?) the database if 
-- version of database doesn't match this version.
addon.dbVersion = 2;

-- Constants
DEBUG_PRINT = false;
--@debug@
DEBUG_PRINT = true;
--@end-debug@

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

function addon:Debug(...)
	if DEBUG_PRINT then
		self:Print(...)
	end
end

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

function addon:UpdateCurrentZone()
	local zoneId, _ = GetCurrentMapAreaID()
	local zoneName = GetRealZoneText();
	self.currentZone = {id = zoneId, name = zoneName};
end

function addon:IsInMyGuild(playerName)
	if self.guildName then
		local guildName, _, _ = GetGuildInfo(playerName)
		return guildName == self.guildName
	else
		return false
	end
end

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

	local pmc = self.parseModulesCore;
	pmc:GetParsesForEncounter(encounter, function(success, startTime, duration, players)
		if not success then return end;

		encounter.startTime = startTime;
		encounter.duration = duration;
		self.inspect:GetInspectDataForPlayers(players, function()
			self.highscore:AddEncounterParsesForPlayers(guildName, encounter, players);
		end)
	end)
end

function addon:PLAYER_GUILD_UPDATE(evt, unitId)
	if unitId == "player" then
		self:UpdateMyGuildName()
	end
end

function addon:ENCOUNTER_END(evt, encounterId, encounterName, difficultyId, raidSize, endStatus)
	self:Debug("ENCOUNTER_END", encounterId, encounterName, difficultyId, raidSize, endStatus)
	if endStatus == 1 then -- Success
		self:OnEncounterEndSuccess(encounterId, encounterName, difficultyId, raidSize);
	end
end

function addon:ZONE_CHANGED_NEW_AREA(evt)
	self:UpdateCurrentZone();
end

function addon:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("GuildSkadaHighScoreDB", addon.dbDefaults, true)
	
	-- Make sure db version is in sync
	if self.db.global.dbVersion ~= self.dbVersion then
		self:Debug(format("Found not matching db versions: db=%d, addon=%d", 
			self.db.global.dbVersion, self.dbVersion));
		self:Debug("Resetting db");
		self.db:ResetDB();
		self.db.global.dbVersion = self.dbVersion;
	end
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
