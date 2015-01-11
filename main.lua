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
addon.guildName = nil;
addon.inspect = {};
addon.notifyInspectQueue = {};
addon.notifyInspectTimer = nil;
addon.currentInspectPlayer = nil;
addon.pendingInspects = {};

local INSPECT_CACHE_TIMEOUT = 900;
local INVENTORY_SLOT_NAMES = {
	"HeadSlot","NeckSlot","ShoulderSlot","BackSlot","ChestSlot","WristSlot",
	"HandsSlot","WaistSlot","LegsSlot","FeetSlot","Finger0Slot","Finger1Slot",
	"Trinket0Slot","Trinket1Slot","MainHandSlot","SecondaryHandSlot"
}

local playerGUID = UnitGUID("player");
local inspectCache = {};

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

function addon:GetTalentSpec(unitName)
	if unitName == "player" then
		local spec = GetSpecialization();
		if spec and spec > 0 then
			local _, name = GetSpecializationInfo(spec);
			return name;
		end
	else
		local spec = GetInspectSpecialization(unitName)
		if spec and spec > 0 then
			local role = GetSpecializationRoleByID(spec);
			if role then
				local _, name = GetSpecializationInfoByID(spec);
				return name
			end
		end
	end
end

function addon:GetItemLevel(unitName) 
	if unitName == "player" then
		local _, equipped = GetAverageItemLevel();
		return floor(equipped);
	else
		local total, numItems = 0, 0;
		for i = 1, #INVENTORY_SLOT_NAMES do
			local slotName = INVENTORY_SLOT_NAMES[i];
			local slotId = GetInventorySlotInfo(slotName);
			local itemLink = GetInventoryItemLink(unitName, slotId);
			
			if itemLink then
				local _, _, _, itemLevel = GetItemInfo(itemLink)
				if itemLevel and itemLevel > 0 then
					numItems = numItems + 1;
					total = total + itemLevel;
				end
			end
		end
		if total < 1 or numItems < 15 then
			return nil
		else 
			return floor(total / numItems)
		end
	end
end

function addon:UpdatePlayerInspectCache(playerId, unitName)
	if UnitExists(unitName) then	
		inspectCache[playerId] = {}
		inspectCache[playerId].time = GetTime()
		inspectCache[playerId].specName = self:GetTalentSpec(unitName)
		inspectCache[playerId].itemLevel = self:GetItemLevel(unitName)
	end
end

function addon:HasPlayerInspectCache(playerId)
	if not inspectCache[playerId] then
		return false; -- No entry for player id
	elseif (GetTime() - inspectCache[playerId].time) > INSPECT_CACHE_TIMEOUT then
		inspectCache[playerId] = nil;
		return false; -- Cache entry is too old
	else
		return true;
	end 
end

function addon:FetchInformationForPlayers(players, callback)
	local playersToInspect = {}

	for _, player in ipairs(players) do
		if player.id == playerGUID then
			player.specName = self:GetTalentSpec("player");
			player.itemLevel = self:GetItemLevel("player")
		elseif self:HasPlayerInspectCache(player.id) then
			player.specName = inspectCache[player.id].specName;
			player.itemLevel = inspectCache[player.id].itemLevel;
		else
			inspectCache[player.id] = nil;
			if CanInspect(player.name, false) then 
				tinsert(playersToInspect, player)
			end
		end
	end

	if #playersToInspect == 0 then
		callback(players);
	else
		local pendingInspectData = {callback = callback, players = players, pendingIds = {}};
		for _, player in ipairs(playersToInspect) do
			tinsert(pendingInspectData.pendingIds, player.id);
		end
		tinsert(self.pendingInspects, pendingInspectData);

		for _, player in ipairs(playersToInspect) do
			self:QueueInspect(player);
		end
		
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

function addon:StartNotifyInspectTimer()
	if not self.notifyInspectTimer then
		self.notifyInspectTimer = self:ScheduleRepeatingTimer("NOTIFY_INSPECT_TIMER_DONE", 1)
	end
end

function addon:StopNotifyInspectTimer()
	if self.notifyInspectTimer then
		self:CancelTimer(self.notifyInspectTimer)
	end
end

function addon:QueueInspect(player)
	self:Debug("QueueNotifyInspect " .. player.name)

	local playerInQueue = false
	for _, p in ipairs(self.notifyInspectQueue) do
		if p.name == player.name then
			playerInQueue = true;
			break;
		end
	end

	if not playerInQueue then
		tinsert(self.notifyInspectQueue, player);
		self:StartNotifyInspectTimer();
	end	
end

function addon:ResolveInspect(player, success)
	self:Debug("ResolveInspect " .. player.name .. " " .. (success and "success" or "fail"))

	local finishedInspectIndexes = {};

	for inspectIndex, pendingInspectData in ipairs(self.pendingInspects) do
		local players = pendingInspectData.players;
		local pendingIds = pendingInspectData.pendingIds;
		local callback = pendingInspectData.callback;

		-- Search for a pending id matching the inspected player id, remove
		-- if found
		local playerFound = false
		for idx, id in ipairs(pendingIds) do
			if id == player.id then
				tremove(pendingIds, idx);
				playerFound = true;
				break
			end
		end

		if playerFound then
			if success then
				-- Update inspect data, unless already updated
				if not self:HasPlayerInspectCache(player.id) then
					self:UpdatePlayerInspectCache(player.id, player.name);
				end
				ClearInspectPlayer();
				player.specName = inspectCache[player.id].specName;
				player.itemLevel = inspectCache[player.id].itemLevel;
			else
				if self:HasPlayerInspectCache(player.id) then
					player.specName = inspectCache[player.id].specName;
					player.itemLevel = inspectCache[player.id].itemLevel;
				end
			end

			-- If this was the last pending player, this pending inspect
			-- group is now done
			if #pendingIds == 0 then
				tinsert(finishedInspectIndexes, inspectIndex);
			end
		end
	end

	for _, idx in ipairs(finishedInspectIndexes) do
		local finishedInspect = tremove(self.pendingInspects, idx);
		finishedInspect.callback(finishedInspect.players);
	end
end

function addon:NOTIFY_INSPECT_TIMER_DONE()
	self:Debug("NOTIFY_INSPECT_TIMER_DONE");

	if self.currentInspectPlayer then
		addon:ResolveInspect(self.currentInspectPlayer, false)
		self.currentInspectPlayer = nil;
	end

	if #self.notifyInspectQueue > 0 then 
		local inspectPlayer = tremove(self.notifyInspectQueue);
		NotifyInspect(inspectPlayer.name);
		self.currentInspectPlayer = inspectPlayer;
	else
		return
	end
end

function addon:INSPECT_READY(evt, GUID)
	self:Debug("INSPECT_READY (" .. GUID .. ")")

	if self.currentInspectPlayer and self.currentInspectPlayer.id == GUID then
		addon:ResolveInspect(self.currentInspectPlayer, true)
		self.currentInspectPlayer = nil;
	end
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
	
	if not Skada.last.gotboss then
		self:Debug("Not a boss")
		return
	end

	local encounter = self.currentEncounter
	local players = self:GetGuildPlayersFromSet(Skada.last);
	self:FetchInformationForPlayers(players, function(players)
		for i, player in ipairs(players) do
			local name = player.name;
			local damage = player.damage;
			local itemLevel = player.itemLevel and player.itemLevel or "N/A"
			local specName = player.specName and player.specName or "N/A"
			self:Debug(name .. " " .. itemLevel .. " " .. specName .. " " .. damage);
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
