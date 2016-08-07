local addonName, addonTable = ...
local addon = addonTable[1];
local pmc = addon.parseModulesCore;

local mod = pmc:NewModule("Skada", "AceHook-3.0");
if not mod then return end;

-- Global functions
local wipe = wipe;
local tinsert = tinsert;
local ipairs = ipairs;
local next = next;
local IsAddOnLoaded = IsAddOnLoaded;

-- Non-cached globals (for mikk's FindGlobals script)
-- GLOBALS: Skada


function mod:IsActivatable()
	return IsAddOnLoaded("Skada");
end

function mod:GetPlayersFromSet(skadaSet)
	local players = {}

	-- Have to copy the data as skadaSet.players is a direct reference
	-- to the skada set.
	for i, player in ipairs(skadaSet.players) do
		if self:ShouldIncludePlayer(player.id, player.name) then
			local playerData = {
				id = player.id, 
				name = player.name, 
				damage = player.damage,
				healing = player.healing,
				role = player.role,
				class = player.class
			};
			tinsert(players, playerData);
		end
	end
	return players
end

function mod:ProcessParseRequest(encounter, callback)
	-- Find the skada set matching the encounter. Looking only 
	-- at the lastest set should make sense, as that set 
	-- should be the boss segment we just ended.
	local _, skadaSet = next(Skada:GetSets());

	if not skadaSet or not skadaSet.gotboss or skadaSet.mobname ~= encounter.name then
		self:Debug("No Skada set found for boss");
		return callback(false);
	end

	local duration = skadaSet.time;
	local startTime = skadaSet.starttime;
	local playerParses = self:GetPlayersFromSet(skadaSet);

	return callback(true, startTime, duration, playerParses);
end


function mod:GetParsesForEncounter(encounter, callback)
	-- If Skada hasn't finshed the segment, wait for it
	if Skada.current then
		tinsert(self.pendingParseRequests, {encounter = encounter, callback = callback});
	else
		self:ProcessParseRequest(encounter, callback);
	end
end

function mod:EndSegment()
	self:Debug("Skada: EndSegment")

	-- If we have requests waiting for EndSegment, process them now.
	if #self.pendingParseRequests then
		for _, pendingRequest in ipairs(self.pendingParseRequests) do
			local encounter = pendingRequest.encounter;
			local callback = pendingRequest.callback;
			self:ProcessParseRequest(encounter, callback);
		end
		wipe(self.pendingParseRequests);
	end
end

function mod:OnEnable()
	self.pendingParseRequests = {};

	self:SecureHook(Skada, "EndSegment");
end

function mod:OnDisable()
	wipe(self.pendingParseRequests);

	self:Unhook(Skada, "EndSegment");
end
