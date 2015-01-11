local addonName, addonTable = ...

local addon = addonTable[1];
local inspect = addon.inspect;

-- Constants
local INSPECT_CACHE_TIMEOUT = 900;
local INVENTORY_SLOT_NAMES = {
	"HeadSlot","NeckSlot","ShoulderSlot","BackSlot","ChestSlot","WristSlot",
	"HandsSlot","WaistSlot","LegsSlot","FeetSlot","Finger0Slot","Finger1Slot",
	"Trinket0Slot","Trinket1Slot","MainHandSlot","SecondaryHandSlot"
}

inspect.inspectQueue = {};
inspect.notifyInspectTimer = nil;
inspect.currentInspectPlayerId = nil;

local playerGUID = UnitGUID("player");
local inspectCache = {};

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
	if not inspectCache[playerId] then
		return false; -- No entry for player id
	elseif not ignoreExpired and ((GetTime() - inspectCache[playerId].time) > INSPECT_CACHE_TIMEOUT) then
		return false; -- Cache entry is too old
	else
		return true;
	end 
end

local function setPlayerInspectCache(playerId, specName, itemLevel)
	inspectCache[playerId] = {};
	inspectCache[playerId].time = GetTime();
	inspectCache[playerId].specName = specName;
	inspectCache[playerId].itemLevel = itemLevel;
end

function inspect:StartNotifyInspectTimer()
	if not self.notifyInspectTimer then
		self.notifyInspectTimer = addon:ScheduleRepeatingTimer(function()
			self:NOTIFY_INSPECT_TIMER_DONE();
		end, 1)
	end
end

function inspect:StopNotifyInspectTimer()
	if self.notifyInspectTimer then
		addon:CancelTimer(self.notifyInspectTimer);
		self.notifyInspectTimer = nil;
	end
end

function inspect:IsPlayerInInspectQueue(player)
	local playerInQueue = false
	for _, p in ipairs(self.notifyInspectQueue) do
		if p.name == player.name then
			playerInQueue = true;
			break;
		end
	end
	return playerInQueue;
end

function inspect:QueueInspect(player, callback)
	addon:Debug("QueueNotifyInspect " .. player.name)

	if not self.inspectQueue[player.id] then
		self.inspectQueue[player.id] = {player = player, callbacks = {}};
	end
	tinsert(self.inspectQueue[player.id].callbacks, callback);

	self:StartNotifyInspectTimer();
end

function inspect:SetCachedInspectDataForPlayer(player)
	if player.id == playerGUID then
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

function inspect:ResolveInspect(playerId, success)
	addon:Debug("ResolveInspect " .. playerId .. " " .. (success and "success" or "fail"))

	if not self.inspectQueue[playerId] then
		return
	end

	local player = self.inspectQueue[playerId].player;
	local callbacks = self.inspectQueue[playerId].callbacks;
	self.inspectQueue[playerId] = nil;

	if success then 
		if not hasPlayerInspectCache(player.id) then
			local specName = getTalentSpec(player.name);
			local itemLevel = getItemLevel(player.name);
			setPlayerInspectCache(player.id, specName, itemLevel);
		end

		player.specName = inspectCache[player.id].specName;
		player.itemLevel = inspectCache[player.id].itemLevel;
	end

	for _,callback in ipairs(callbacks) do
		callback();
	end
end

function inspect:NOTIFY_INSPECT_TIMER_DONE()
	addon:Debug("NOTIFY_INSPECT_TIMER_DONE");

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