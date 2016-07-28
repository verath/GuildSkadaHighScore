-- 
-- parse_modules_core.lua
-- 
-- Contains the core module for the parse modules. This module
-- is responsible for picking one of the parse modules that
-- can be activated and then forwarding requests for parses to
-- the selected parse provider.
--
-- A parse provider is a module that uses some damage mod (e.g. Skada)
-- and returns parses from the last encounter when asked for.
--

local addonName, addonTable = ...
local addon = addonTable[1];

-- Global functions for faster access
local tinsert = tinsert;

-- Create the parseModulesCore
local pmc = addon:NewModule("parseModulesCore")
addon.parseModulesCore = pmc;

-- Set up the prototype for parse providers
do
	local proto = {}

	function proto:Debug(...)
		pmc:Debug(...);
	end

	-- Function called by the Parse Module Core to determine
	-- if this module can be enabled or not. Should test that
	-- all dependencies are loaded.
	function proto:IsActivatable()
		return false;
	end

	-- Function that must be called for each player before it
	-- can be included in the parses returned.
	-- Returns true if the player should be included.
	function proto:ShouldIncludePlayer(playerId, playerName)
		return addon:IsInMyGuild(playerName);
	end

	-- Should get a list of player parses for the specified encounter.
	-- 
	-- The callback function should be called with (success, startTime, duration, parses)
	-- 		success 	- boolean indicating if parses were found.
	--		startTime 	- the time when the encounter started.
	--		duration 	- the time in seconds of the encounter.
	-- 		players 	- list of player parse objects ({id="", name="", damage=0, healing=0})
	--					  of players passing the ShouldIncludePlayer test.
	-- 
	-- Params:
	-- 		encounter - An object describing the encounter with the following keys:
	--					zoneId, zoneName, id, name, difficultyId, difficultyName, raidSize
	--		callback  - The function to be called when the parse is ready.
	function proto:GetParsesForEncounter(encounter, callback)
		callback(false);
	end

	pmc:SetDefaultModulePrototype(proto);
	-- Parse provider modules are disabled by default,
	-- as only one should be used at a time
	pmc:SetDefaultModuleState(false);
end


local function setAdditionalDataForPlayers(players)
	for _, player in ipairs(players) do
		if not player.role then
			player.role = UnitGroupRolesAssigned(player.name);
		end
		if not player.class then
			_, player.class = UnitClass(player.name);
		end
	end
end

-- Function for getting parses for an encounter. This
-- function will forward the call to the selected parse
-- provider if available. Will also add additional information
-- like class and role to successful parse fetches
function pmc:GetParsesForEncounter(encounter, callback)
	local parseProvider = self.selectedParseProvider
	if parseProvider then
		parseProvider:GetParsesForEncounter(encounter, function(success, startTime, duration, players)
			if success then
				setAdditionalDataForPlayers(players);
			end
			callback(success, startTime, duration, players);
		end);
	else
		callback(false);
	end
end

function pmc:SelectParseProvider()
	for name, mod in self:IterateModules() do
		if mod:IsActivatable() then
			self:Debug("Using " .. name .. " as parse provider.");
			self.selectedParseProvider = mod;
			mod:Enable();
			break;
		end
	end
end

function pmc:OnEnable()
	self.selectedParseProvider = nil;
	self:SelectParseProvider();
end

function pmc:OnDisable()
	self.selectedParseProvider = nil;
end