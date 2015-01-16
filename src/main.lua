local addonName, addonTable = ...

local tinsert = tinsert;
local tremove = tremove;

-- Create ACE3 addon
local addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

tinsert(addonTable, addon);
_G[addonName] = addon

-- Set up a default prototype for all modules
local modPrototype = { Debug = function(self, ...) addon:Debug(...) end }
addon:SetDefaultModulePrototype(modPrototype)

-- Db default settings
addon.dbDefaults = {
	realm = {
		modules = {}
	},
	global = {
		dbVersion = 1,
		debugLog = {}
	}
}

-- The current db version. Clear (migrate?) the database if 
-- version of database doesn't match this version.
addon.dbVersion = 2

-- Constants
DEBUG_PRINT = true;
DEBUG_LOG = false;
MAX_NUM_DEBUG_LOG_ENTRIES = 300;

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
	if DEBUG_LOG then
		local logData = {date("%d/%m %H:%M:%S")};
		for i=1, select('#', ...) do
			local v = select(i, ...)
			tinsert(logData, v);
		end
		tinsert(self.db.global.debugLog, logData);
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
	
	if IsInInstance() then
		self:Debug("UpdateCurrentZone", zoneId, zoneName)
	else
		self:UnsetCurrentEncounter();
	end
end

function addon:SetCurrentEncounter(encounterId, encounterName, difficultyId, raidSize)
	local difficultyName = getDifficultyNameById(difficultyId);

	self:Debug("SetCurrentEncounter", encounterId, encounterName, difficultyId, raidSize, difficultyName);

	if difficultyName then
		self.currentEncounter = {
			zoneId = self.currentZone.id,
			zoneName = self.currentZone.name,
			id = encounterId, 
			name = encounterName, 
			difficultyId = difficultyId,
			difficultyName = difficultyName,
			raidSize = raidSize
		}
	end
end

function addon:UnsetCurrentEncounter()
	if self.currentEncounter then
		self:Debug("UnsetCurrentEncounter");
		self.currentEncounter = nil
	end
end

function addon:IsInMyGuild(playerName)
	if self.guildName then
		local guildName, _, _ = GetGuildInfo(playerName)
		return guildName == self.guildName
	else
		return false
	end
end

function addon:GetGuildPlayersFromSet(skadaSet)
	local players = {}
	for i, player in ipairs(skadaSet.players) do
		local playerData;
		if self:IsInMyGuild(player.name) then
			playerData = {id = player.id, name = player.name, damage = player.damage, healing = player.healing};
			tinsert(players, playerData);
		end
	end
	return players
end

function addon:OnEncounterEndSuccess()
	self:Debug("OnEncounterEndSuccess")

	local guildName = self.guildName;
	if not guildName then
		self:Debug("Not in a guild");
		return;
	end

	local encounter = self.currentEncounter;
	if not encounter then
		self:Debug("No current encounter");
		return
	end

	local pmc = self.parseModulesCore;
	pmc:GetParsesForEncounter(encounter, function(success, startTime, duration, players)
		if not success then return end;

		encounter.startTime = startTime;
		encounter.duration = duration;
		self.inspect:GetInspectDataForPlayers(players, function()
			self.highscore:AddEncounterParsesForPlayers(guildName, encounter, players);
		end)
	end)

	self:UnsetCurrentEncounter();
end

function addon:PLAYER_GUILD_UPDATE(evt, unitId)
	if unitId == "player" then
		self:UpdateMyGuildName()
	end
end

function addon:ENCOUNTER_START(evt, encounterId, encounterName, difficultyId, raidSize)
	self:Debug("ENCOUNTER_START", encounterId, encounterName, difficultyId, raidSize)
	self:SetCurrentEncounter(encounterId, encounterName, difficultyId, raidSize)
end

function addon:ENCOUNTER_END(evt, encounterId, encounterName, difficultyId, raidSize, endStatus)
	self:Debug("ENCOUNTER_END", encounterId, encounterName, difficultyId, raidSize, endStatus)
	if endStatus == 1 then -- Success
		self:SetCurrentEncounter(encounterId, encounterName, difficultyId, raidSize);
		self:OnEncounterEndSuccess();
	else
		self:UnsetCurrentEncounter();
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

	-- Purge old logs
	if DEBUG_LOG then
		local numLogsToPurge = (#self.db.global.debugLog - MAX_NUM_DEBUG_LOG_ENTRIES);
		while numLogsToPurge >= 0 do
			tremove(self.db.global.debugLog, 1)
			numLogsToPurge = numLogsToPurge - 1;
		end
	else
		wipe(self.db.global.debugLog);
	end
end

function addon:OnEnable()
	self.currentEncounter = nil;
	self.currentZone = {};
	self.guildName = nil;

	self:RegisterEvent("ENCOUNTER_START")
	self:RegisterEvent("ENCOUNTER_END")	
	self:RegisterEvent("PLAYER_GUILD_UPDATE")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")

	self:RegisterChatCommand("gshs", function()
		self.gui:ShowMainFrame();
	end)

	self:UpdateMyGuildName();
	self:UpdateCurrentZone();
end

function addon:OnDisable()
	self.currentEncounter = nil;
	self.currentZone = {};
	self.guildName = nil;

	self:UnregisterEvent("ENCOUNTER_START")
	self:UnregisterEvent("ENCOUNTER_END")
	self:UnregisterEvent("PLAYER_GUILD_UPDATE")
	self:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
	
	self:UnregisterChatCommand("gshs");
end
