local addonName, addonTable = ...

-- Global functions for faster access
local tinsert = tinsert;
local floor = floor;
local wipe = wipe;

-- Set up module
local addon = addonTable[1];
local inspect = addon:NewModule("inspect", "AceEvent-3.0", "AceTimer-3.0")
addon.inspect = inspect;

-- How many seconds before a cached inspect is considered invalid.
local INSPECT_CACHE_TIMEOUT = 60*60;

local INVENTORY_SLOT_NAMES = {
	"HeadSlot","NeckSlot","ShoulderSlot","BackSlot","ChestSlot","WristSlot",
	"HandsSlot","WaistSlot","LegsSlot","FeetSlot","Finger0Slot","Finger1Slot",
	"Trinket0Slot","Trinket1Slot","MainHandSlot","SecondaryHandSlot"
}

local NOOP = function() end

-- UnitGUID("player") seems to not always be available here,
-- so PLAYER_GUID is set in OnEnable.
local PLAYER_GUID = nil;


-- A map from player GUID to an object {itemLevel, specName, time}
local inspectCache = {};


local function isInPVEInstance()
	local isInstance, instanceType = IsInInstance();
	return inInstance and (instanceType == "party" or instanceType == "raid")
end

local function getTalentSpec(unitName)
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

local function getItemLevel(unitName) 
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

local function hasPlayerInspectCache(playerId, ignoreExpired)
	if inspectCache[playerId] and ignoreExpired then
		return true -- We have a cache, might be expired
	elseif inspectCache[playerId] and inspectCache[playerId].time then
		local isExpired = (GetTime() - inspectCache[playerId].time) > INSPECT_CACHE_TIMEOUT
		local hasAllAttributes = inspectCache[playerId].specName and inspectCache[playerId].itemLevel;

		return (not isExpired and hasAllAttributes)
	else
		return false; -- No entry for player id
	end 
end

local function unsetPlayerInspectCache(playerId)
	inspectCache[playerId] = nil;
end

local function setPlayerInspectCache(playerId, specName, itemLevel)
	inspectCache[playerId] = {};
	inspectCache[playerId].specName = specName;
	inspectCache[playerId].itemLevel = itemLevel;
	if specName and itemLevel then
		-- Dont set time if not all values are provided, as that would
		-- make this entry valid and prevent inspections of the player
		-- for the duration of the INSPECT_CACHE_TIMEOUT.
		inspectCache[playerId].time = GetTime();
	end
end

function inspect:StartNotifyInspectTimer()
	if not self.notifyInspectTimer then
		self:Debug("Starting notifyInspectTimer");

		self.notifyInspectTimer = self:ScheduleRepeatingTimer(function()
			self:OnNotifyInspectTimerDone()
		end, 1);
	end
end

function inspect:StopNotifyInspectTimer()
	if self.notifyInspectTimer then
		self:Debug("Stopping notifyInspectTimer");

		self:CancelTimer(self.notifyInspectTimer);
		self.notifyInspectTimer = nil;
	end
end

function inspect:QueueInspect(player, callback)
	self:Debug("QueueInspect", player.name)

	if not self.inspectQueue[player.id] then
		self.inspectQueue[player.id] = {player = player, callbacks = {}};
	end
	tinsert(self.inspectQueue[player.id].callbacks, callback);

	self:StartNotifyInspectTimer();
end

function inspect:SetCachedInspectDataForPlayer(player)
	if player.id == PLAYER_GUID then
		player.specName = getTalentSpec("player")
		player.itemLevel = getItemLevel("player");
		return true
	elseif hasPlayerInspectCache(player.id, false) then
		player.specName = inspectCache[player.id].specName;
		player.itemLevel = inspectCache[player.id].itemLevel;
		return true
	elseif hasPlayerInspectCache(player.id, true) then
		-- Expired cache, but better than nothing
		player.specName = inspectCache[player.id].specName;
		player.itemLevel = inspectCache[player.id].itemLevel;
		return false
	else
		return false
	end
end

function inspect:GetInspectDataForPlayer(player, callback)
	-- Make sure we always have a callback
	callback = callback and callback or NOOP;

	if self:SetCachedInspectDataForPlayer(player) then
		return callback()
	elseif not CanInspect(player.name, false) then
		return callback()
	else
		self:QueueInspect(player, callback);
	end
end

function inspect:GetInspectDataForPlayers(players, callback)
	local totalCallbacks = #players;
	local doneCallbacks = 0;

	for _, player in ipairs(players) do		
		self:GetInspectDataForPlayer(player, function()
			doneCallbacks = doneCallbacks + 1;
			if doneCallbacks == totalCallbacks then
				callback();
			end
		end)
	end
end

function inspect:PreInspectGroup()
	for i=1, GetNumGroupMembers() do

		local playerName = GetRaidRosterInfo(i);
		if playerName and addon:IsInMyGuild(playerName) then

			local playerId = UnitGUID(playerName)
			if playerId and playerId ~= PLAYER_GUID and not hasPlayerInspectCache(playerId) then 
				local player = {name = playerName, id = playerId}
				self:QueueInspect(player, NOOP);
			end
		end
	end
end

function inspect:ResolveInspect(playerId, success)
	if not self.inspectQueue[playerId] then
		return
	end

	local player = self.inspectQueue[playerId].player;
	local callbacks = self.inspectQueue[playerId].callbacks;
	self.inspectQueue[playerId] = nil;

	self:Debug("ResolveInspect", player.name, (success and "success" or "fail"))

	if success then 
		if not hasPlayerInspectCache(player.id) then
			local specName = getTalentSpec(player.name);
			local itemLevel = getItemLevel(player.name);
			setPlayerInspectCache(player.id, specName, itemLevel);
		end

		player.specName = inspectCache[player.id].specName;
		player.itemLevel = inspectCache[player.id].itemLevel;

		ClearInspectPlayer();
	end

	for _,callback in ipairs(callbacks) do
		callback();
	end
end

function inspect:OnNotifyInspectTimerDone()
	-- Timeout any current inspection
	if self.currentInspectPlayerId then
		self:ResolveInspect(self.currentInspectPlayerId, false);
		self.currentInspectPlayerId = nil;
	end

	local playerId, inspectData = next(self.inspectQueue);
	if playerId then
		NotifyInspect(inspectData.player.name);
		self.currentInspectPlayerId = playerId;
	else
		self:StopNotifyInspectTimer();
	end
end

function inspect:INSPECT_READY(evt, GUID) 
	if self.currentInspectPlayerId == GUID then
		self:ResolveInspect(self.currentInspectPlayerId, true)
		self.currentInspectPlayerId = nil;
	end
end

function inspect:GROUP_ROSTER_UPDATE(evt)
	if not IsInGroup() then
		self:Debug("Left group, wiping inspect cache");
		wipe(inspectCache);
		wipe(inspect.inspectQueue);
		inspect.currentInspectPlayerId = nil;
	end
end

function inspect:ZONE_CHANGED_NEW_AREA(evt)
	if isInPVEInstance() then
		-- We just zoned into an instance, try pre-inspecting the group
		self:PreInspectGroup();
	end
end

function inspect:PLAYER_SPECIALIZATION_CHANGED(evt, unitId)
	if unitId and unitId ~= "player" then
		local playerId = UnitGUID(unitId);
		unsetPlayerInspectCache(playerId);
	end
end

function inspect:OnEnable()
	PLAYER_GUID = UnitGUID("player");

	inspect.inspectQueue = {};
	inspect.notifyInspectTimer = nil;
	inspect.currentInspectPlayerId = nil;

	self:RegisterEvent("INSPECT_READY");
	self:RegisterEvent("GROUP_ROSTER_UPDATE");
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
end

function inspect:OnDisable()
	self:UnregisterEvent("INSPECT_READY");
	self:UnregisterEvent("GROUP_ROSTER_UPDATE");
	self:UnregisterEvent("ZONE_CHANGED_NEW_AREA");
	self:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED");
	
	self:StopNotifyInspectTimer();

	wipe(inspectCache);
	wipe(inspect.inspectQueue);
	inspect.currentInspectPlayerId = nil;
end