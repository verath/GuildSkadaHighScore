-- 
-- inspect.lua
-- 
-- Contains the inspect module. The inspect module
-- is used for getting additional information about
-- players that can only be gotten by doing an inspection
-- of them.
-- 
-- The module uses LibGroupInSpecT for keeping track of
-- the group members and performing the inspects. A local
-- playerInfo table is kept, as we are also interested in 
-- the item levels of the group members.
--
-- The local playerInfo table is index by player guid and
-- may have a value for the following keys:
--  * itemLevel: Avg equiped item level of the player
--  * specName: Name of player's current spec
--  * specRole: Role of the player's current spec
--

local addonName, addonTable = ...

-- Global functions for faster access
local floor = floor;

-- LibGroupInSpecT, lib handling inspection of group members
local LGIST = LibStub:GetLibrary("LibGroupInSpecT-1.1")

-- ItemUpgradeInfo, lib for information about item upgrades applied to items.
local ItemUpgradeInfo = LibStub("LibItemUpgradeInfo-1.0")

-- Set up module
local addon = addonTable[1];
local inspect = addon:NewModule("inspect", "AceEvent-3.0", "AceTimer-3.0")
addon.inspect = inspect;

-- Slots used for calculating item level of a player
local INVENTORY_SLOT_IDS = {
	-- INVSLOT_AMMO,
	INVSLOT_HEAD,
	INVSLOT_NECK,
	INVSLOT_SHOULDER,
	-- INVSLOT_BODY - shirt,
	INVSLOT_CHEST,
	INVSLOT_WAIST,
	INVSLOT_LEGS,
	INVSLOT_FEET,
	INVSLOT_WRIST,
	INVSLOT_HAND,
	INVSLOT_FINGER1,
	INVSLOT_FINGER2,
	INVSLOT_TRINKET1,
	INVSLOT_TRINKET2,
	INVSLOT_BACK,
	INVSLOT_MAINHAND,
	INVSLOT_OFFHAND,
	-- INVSLOT_RANGED,
	-- INVSLOT_TABARD,
}


-- Attempts to get the item level of the provided unitName.
-- The unitName must either be "player" or a unit currently being
-- inspected. 
function inspect:GetItemLevel(unitName)
	if unitName == "player" or UnitIsUnit(unitName, "player") then
		local _, equipped = GetAverageItemLevel();
		return floor(equipped);
	else
		local total, numItems = 0, 0;
		for i = 1, #INVENTORY_SLOT_IDS do
			local slotId = INVENTORY_SLOT_IDS[i];
			local itemLink = GetInventoryItemLink(unitName, slotId);
			if itemLink then
				itemLevel = ItemUpgradeInfo:GetUpgradedItemLevel(itemLink)
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

-- Helper method for getting inspect data for a single player,
-- calling the provided callback on success/error.
function inspect:GetInspectDataForPlayer(player, callback)
	local playerId = player.id;
	local playerInfo = self.playerInfo[playerId]

	if playerInfo then
		-- If the playerInfo object is missing expected values,
		-- make sure that that player is queued for a re-inspect.
		if not (playerInfo["specName"] and playerInfo["itemLevel"] and playerInfo["specRole"]) then
			LGIST:Rescan(playerId)
		end

		-- Set inspect-only data
		player["specName"] = playerInfo["specName"];
		player["itemLevel"] = playerInfo["itemLevel"];

		-- Add role from spec if role is not already a valid role
		if not (role == "TANK" or role == "HEALER" or role == "DAMAGER") then
			player["role"] = playerInfo["specRole"];
		end

		self:Debug("inspect:GetInspectDataForPlayer", "success", 
			player["specName"], player["itemLevel"], player["role"]);
	else
		self:Debug("inspect:GetInspectDataForPlayer", "fail");
	end

	callback()
end

-- Takes a list of player objects and tries to get inspect data
-- for all these objects. The player objects are modified in place.
-- The callback is called when attempt for all players has been
-- performed.
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

-- LGIST event for INSPECT_READY where we can perform our own 
-- inspection handling. In our case, we need to try and grab 
-- the item level here, as that is not provided by LGIST.
function inspect:GroupInSpecT_InspectReady(evt, guid, unit)
	-- As getting the itemLevel can be slow, we don't perform this
	-- action for players that are not currently part of our guild.
	if not addon:IsInMyGuild(unit) then return end

	self.playerInfo[guid] = self.playerInfo[guid] or {};
	local playerInfo = self.playerInfo[guid];

	-- Getting the item level is unreliable, as it requires
	-- proximity to the target (among other things?). Because
	-- of that we keep the old itemLevel if we can not get a 
	-- new one. This might mean that we don't pick up on all
	-- item changes. However, as LGIST might re-inspect players
	-- frequently, we instead optimize for the case where players 
	-- do not change their item levels.
	local itemLevel = self:GetItemLevel(unit);
	if itemLevel then
		playerInfo["itemLevel"] = itemLevel;
	end

	self:Debug("inspect:GroupInSpecT_InspectReady", unit, itemLevel, playerInfo["itemLevel"])
end

-- LGIST event for when info for a player is ready or has been modified.
function inspect:GroupInSpecT_Update(evt, guid, unit, info)
	-- We do not bother checking guild here, as the expensive operation
	-- (the inspection) has already been done. Better then to store the
	-- data, if the player later joins our guild during the raid.

	self.playerInfo[guid] = self.playerInfo[guid] or {};
	local playerInfo = self.playerInfo[guid];

	-- Copy data we are interested in
	playerInfo["specName"] = info.spec_name_localized;
	playerInfo["specRole"] = info.spec_role;
end

-- LGIST event for when a member leaves the group.
function inspect:GroupInSpecT_Remove(evt, guid)
	self.playerInfo[guid] = nil;
end

function inspect:OnEnable()
	self.playerInfo = {};

	LGIST.RegisterCallback(self, "GroupInSpecT_Update");
	LGIST.RegisterCallback(self, "GroupInSpecT_Remove");
	LGIST.RegisterCallback(self, "GroupInSpecT_InspectReady");
end

function inspect:OnDisable()
	LGIST.UnregisterCallback(self, "GroupInSpecT_Update");
	LGIST.UnregisterCallback(self, "GroupInSpecT_Remove");
	LGIST.UnregisterCallback(self, "GroupInSpecT_InspectReady");

	self.playerInfo = nil;
end
