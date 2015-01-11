local addonName, addonTable = ...

local tinsert = tinsert;
local tremove = tremove;
local tContains = tContains;
local floor = floor;

-- Create ACE3 addon
local addon = LibStub("AceAddon-3.0"):NewAddon(addonName, 
	"AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0")

tinsert(addonTable, addon);
_G[addonName] = addon

addon.currentEncounter = nil;
addon.currentZoneId = nil;
addon.guildName = nil;
addon.inspect = {};

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
	self:Print(...)
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

function addon:SetCurrentEncounter(encounterId, encounterName, difficultyId, raidSize)
	self.currentEncounter = {
		id = encounterId, 
		name = encounterName, 
		difficultyId = difficultyId,
		difficultyName = getDifficultyNameById(difficultyId),
		raidSize = raidSize
	}
end

function addon:UnsetCurrentEncounter()
	self.currentEncounter = nil
end

function addon:IsInMyGuild(playerName)
	if 1 then return true end
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

function addon:SetRoleForPlayers(players)
	for _, player in ipairs(players) do
		player.role = UnitGroupRolesAssigned(player.name);
	end
end

function addon:INSPECT_READY(evt, GUID)
	self:Debug("INSPECT_READY (" .. GUID .. ")")

	self.inspect:INSPECT_READY(evt, GUID);
end

function addon:PLAYER_GUILD_UPDATE(evt, unitId)
	if unitId == "player" then
		self:Debug("PLAYER_GUILD_UPDATE (player)");
		self:UpdateMyGuildName()
	end
end

function addon:ENCOUNTER_START(evt, encounterId, encounterName, difficultyId, raidSize)
	self:Debug("ENCOUNTER_START")
	self:SetCurrentEncounter(encounterId, encounterName, difficultyId, raidSize)
end

function addon:ENCOUNTER_END(evt, encounterId, encounterName, difficultyId, raidSize, endStatus)
	self:Debug("ENCOUNTER_END")
	if endStatus == 1 then -- Success
		self:SetCurrentEncounter(encounterId, encounterName, difficultyId, raidSize)
	else
		self:UnsetCurrentEncounter()
	end
end

function addon:EndSegment()
	self:Debug("EndSegment")
	
	if not self.currentEncounter or not Skada.last.gotboss then
		self:Debug("Not a boss")
		return
	end

	local encounter = self.currentEncounter
	local players = self:GetGuildPlayersFromSet(Skada.last);
	self:SetRoleForPlayers(players);
	self.inspect:GetInspectDataForPlayers(players, function()
		for i, player in ipairs(players) do
			local name = player.name;
			local damage = Skada:FormatNumber(player.damage);
			local role = player.role;
			local itemLevel = player.itemLevel and player.itemLevel or "N/A"
			local specName = player.specName and player.specName or "N/A"
			-- "(DAMAGE) Saniera - 20.1k (560 Shadow)"
			self:Debug(format("(%s) %s - %s (%d %s)", role, name, damage, itemLevel, specName));
		end
	end)

	--[[
	self:Printf("%s (%s - %d) %dm", 
		encounter.name, 
		encounter.difficultyName and encounter.difficultyName or "Unknown",
		encounter.difficultyId,
		encounter.raidSize);
	]]--
	self:UnsetCurrentEncounter();
end


function addon:OnInitialize()
end

function addon:OnEnable()
	self:RegisterEvent("ENCOUNTER_START")
	self:RegisterEvent("ENCOUNTER_END")	
	self:RegisterEvent("PLAYER_GUILD_UPDATE")
	self:RegisterEvent("INSPECT_READY")

	self:SecureHook(Skada, "EndSegment")

	self:UpdateMyGuildName()
end

function addon:OnDisable()
	self:UnRegisterEvent("ENCOUNTER_START")
	self:UnRegisterEvent("ENCOUNTER_END")
	self:UnRegisterEvent("PLAYER_GUILD_UPDATE")
	self:UnRegisterEvent("INSPECT_READY")

	self:StopNotifyInspectTimer();
    
    self:UnHook(Skada, "EndSegment")
end
