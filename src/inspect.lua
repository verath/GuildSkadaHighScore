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

-- Cached globals
local floor = floor;
local max = max;
local ipairs = ipairs;
local pairs = pairs;
local tContains = tContains;
local UnitIsUnit = UnitIsUnit;
local UnitGUID = UnitGUID;
local GetAverageItemLevel = GetAverageItemLevel;
local GetInventoryItemLink = GetInventoryItemLink;


-- LibGroupInSpecT, lib handling inspection of group members
local LGIST = LibStub("LibGroupInSpecT-1.1")

-- Disable the LGIST debug output
LGIST.debug = false

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

-- The number of slots used for item level
local NUM_INVENTORY_SLOT_IDS = #INVENTORY_SLOT_IDS;

-- List of ids for the main hand artifact weapons that
-- also uses an off-hand. Used for item level calculations,
-- as one item in the pair seems to be ilvl 750.
local MAINHAND_OFFHAND_ARTIFACT_IDS = {
	128292, -- Death Knight, Frost (Frostreaper)
	127829, -- Demon Hunter, Havoc (Verus)
	128832, -- Demon Hunter, Vengeance (Aldrachi Warblades)
	128860, -- Druid, Feral (Fangs of Ashamane)
	128821, -- Druid, Guardian (Claws of Ursoc)
	128820, -- Mage, Fire (Felo'melorn)
	128940, -- Monk, Windwalker (Al'burq)
	128867, -- Paladin, Protection (Oathseeker)
	128827, -- Priest, Shadow (Xal'atath, Blade of the Black Empire)
	128870, -- Rogue, Assassination (Anguish)
	128872, -- Rogue, Outlaw (Fate)
	128476, -- Rogue, Subtlety (Gorefang)
	128935, -- Shaman, Elemental (The Fist of Ra-den)
	128819, -- Shaman, Enhancement (Doomhammer)
	128911, -- Shaman, Restoration (Sharas'dal, Scepter of Tides)
	137246, -- Warlock, Demonology (Spine of Thal'kiel)
	128908, -- Warrior, Fury (Odyn's Fury)
	128288, -- Warrior, Protection (Scaleshard)
};


-- Checks if the unitName uses a mh+oh artifact weapon by comparing
-- the itemId of the mainhand to MAINHAND_OFFHAND_ARTIFACT_IDS.
local function hasMainHandOffHandArtifact(unitName)
	local mhItemId = GetInventoryItemID(unitName, INVSLOT_MAINHAND);
	return tContains(MAINHAND_OFFHAND_ARTIFACT_IDS, mhItemId)
end

-- Attempts to get the item level of the provided unitName.
-- The unitName must either be "player" or a unit currently being
-- inspected.
function inspect:GetItemLevel(unitName)
	if unitName == "player" or UnitIsUnit(unitName, "player") then
		local _, equipped = GetAverageItemLevel();
		return floor(equipped);
	else
		local slotItemLevel = {};
		for _, slotId in ipairs(INVENTORY_SLOT_IDS) do
			local itemLevel;
			local itemLink = GetInventoryItemLink(unitName, slotId);
			if itemLink then
				itemLevel = GetDetailedItemLevelInfo(itemLink);
			end
			-- If we cannot get the item level for a slot we consider this
			-- failed, likely due to item information not being available 
			-- yet. An exception is the off-hand slot, which is empty for 
			-- 2h weps.
			if not itemLevel and slotId ~= INVSLOT_OFFHAND then
				return nil;
			end
			slotItemLevel[slotId] = itemLevel;
		end

		-- If we don't have an off-hand, assume we are using a 2h weapon.
		-- Setting the item level of the empty off-hand slot to that of the
		-- 2h weapon seems to match the in-game avg item level.
		if not slotItemLevel[INVSLOT_OFFHAND] then
			slotItemLevel[INVSLOT_OFFHAND] = slotItemLevel[INVSLOT_MAINHAND];
		end

		-- HACK(2016-10-26, 7.1.0): Check for MH+OH artifacts, and set
		-- item level for both to the highest of the two.
		if hasMainHandOffHandArtifact(unitName) then
			local artifactItemLevel = max(slotItemLevel[INVSLOT_MAINHAND], slotItemLevel[INVSLOT_OFFHAND]);
			slotItemLevel[INVSLOT_MAINHAND] = artifactItemLevel;
			slotItemLevel[INVSLOT_OFFHAND] = artifactItemLevel;
		end

		local total = 0;
		for _, itemLevel in pairs(slotItemLevel) do
			total = total + itemLevel;
		end
		return floor(total / NUM_INVENTORY_SLOT_IDS);
	end
end

-- Updates the playerInfo for the local player. This does not require
-- an inspect.
function inspect:UpdateLocalPlayerItemLevel()
	local guid = UnitGUID("player");
	if not guid then return	end

	self.playerInfo[guid] = self.playerInfo[guid] or {};
	local playerInfo = self.playerInfo[guid];

	local itemLevel = self:GetItemLevel("player");
	playerInfo["itemLevel"] = itemLevel;
end

-- Helper method for getting inspect data for a single player,
-- modifying the player object in place.
function inspect:GetInspectDataForPlayer(player)
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
		local role = player["role"];
		if not (role == "TANK" or role == "HEALER" or role == "DAMAGER") then
			player["role"] = playerInfo["specRole"];
		end

		--self:Debug("inspect:GetInspectDataForPlayer", "success", player["specName"], player["itemLevel"], player["role"]);
	else
		self:Debug("inspect:GetInspectDataForPlayer", "fail");
	end
end

-- Takes a list of player objects and tries to get inspect data
-- for all these objects. The player objects are modified in place.
-- The callback is called when attempts for all players have been
-- performed.
function inspect:GetInspectDataForPlayers(players, callback)
	for _, player in ipairs(players) do		
		self:GetInspectDataForPlayer(player);
	end
	callback();
end

-- LGIST event for INSPECT_READY where we can perform our own 
-- inspection handling. In our case, we need to try and grab 
-- the item level here, as that is not provided by LGIST.
function inspect:GroupInSpecT_InspectReady(evt, guid, unit)
	-- As getting the itemLevel can be slow, we don't perform this
	-- action for players that are not currently part of our guild.
	if not addon:IsInMyGuild(unit) then
		return;
	end

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

-- Fires when the player equips or unequips an item. We use this
-- to update the player's stored item level directly, instead of
-- waiting for LGIST to "re-inspect" the player
function inspect:PLAYER_EQUIPMENT_CHANGED(slot, hasItem)
	self:UpdateLocalPlayerItemLevel();
end

function inspect:OnEnable()
	self.playerInfo = {};

	LGIST.RegisterCallback(self, "GroupInSpecT_Update");
	LGIST.RegisterCallback(self, "GroupInSpecT_Remove");
	LGIST.RegisterCallback(self, "GroupInSpecT_InspectReady");
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");

	self:UpdateLocalPlayerItemLevel();
end

function inspect:OnDisable()
	self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED");
	LGIST.UnregisterCallback(self, "GroupInSpecT_Update");
	LGIST.UnregisterCallback(self, "GroupInSpecT_Remove");
	LGIST.UnregisterCallback(self, "GroupInSpecT_InspectReady");

	self.playerInfo = nil;
end
