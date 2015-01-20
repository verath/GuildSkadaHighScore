local addonName, addonTable = ...
local addon = addonTable[1];
local pmc = addon.parseModulesCore;

local mod = pmc:NewModule("Recount", "AceHook-3.0", "AceEvent-3.0");
if not mod then return end;

-- Global functions
local wipe = wipe;
local tinsert = tinsert;

function mod:IsActivatable()
	return IsAddOnLoaded("Recount");
end

function mod:GetPlayersFromLastFight()
	local players = {};
	-- Pets are not included in player's damage, so keep track
	-- and manually merge them afterwards
	local pets = {};

	local fightData;
	for name, combatant in pairs(Recount.db2.combatants) do
		fightData = combatant.Fights.LastFightData;
		local damage = (fightData and fightData.Damage) or 0;
		local healing = (fightData and fightData.Healing) or 0;

		-- Since Recount groups by combatant instead of fights
		-- we have to verify that the combatant was part of the fight.
		if fightData and (damage > 0 or healing > 0) then
			if combatant.type == "Pet" then
				pets[name] = {damage = damage, healing = healing};
			elseif combatant.type == "Grouped" or combatant.type == "Self" then
				if self:ShouldIncludePlayer(combatant.GUID, combatant.Name) then
					local playerData = {
						id = combatant.GUID,
						name = combatant.Name,
						damage = damage,
						healing = healing,
						pets = combatant.Pet
					};
					tinsert(players, playerData);
				end
			end
		end
	end

	-- Merge pets and players
	for _, playerData in ipairs(players) do
		if playerData.pets then
			for _, petName in ipairs(playerData.pets) do
				if pets[petName] then
					playerData.damage = playerData.damage + pets[petName].damage;
					playerData.healing = playerData.healing + pets[petName].healing;
				end
			end
			playerData.pets = nil;
		end
	end

	return players;
end

function mod:ProcessParseRequest(encounter, callback)
	-- Look at the most recent one, as previous ones might
	-- be wipes at the same boss
	if self.recountFightEncounterId ~= encounter.id then
		self:Debug("No Recount fight found for boss");
		return callback(false);
	end

	-- CombatTimes is an object {startTime, endTime, formatStart, formatEnd, name}
	-- where the times are from GetTime() and not time(). Because of that
	-- we have to calculate our own unix timestamp for startTime.
	local combatInfo = Recount.db2.CombatTimes[#Recount.db2.CombatTimes];
	local duration = combatInfo[2] - combatInfo[1];
	local startTime = floor(time() - duration);

	local playerParses = self:GetPlayersFromLastFight();

	return callback(true, startTime, duration, playerParses);
end

function mod:GetParsesForEncounter(encounter, callback)
	-- If recount hasn't finished the fight, wait for it
	if Recount.InCombat then
		tinsert(self.pendingParseRequests, {encounter = encounter, callback = callback});
	else
		self:ProcessParseRequest(encounter, callback);
	end
end

function mod:LeaveCombat()
	self:Debug("Recount: LeaveCombat")

	-- If we have requests waiting for LeaveCombat, process them now.
	if #self.pendingParseRequests then
		for _, pendingRequest in ipairs(self.pendingParseRequests) do
			local encounter = pendingRequest.encounter;
			local callback = pendingRequest.callback;
			self:ProcessParseRequest(encounter, callback);
		end
		wipe(self.pendingParseRequests);
	end
end

function mod:PutInCombat()
	self:Debug("Recount: PutInCombat");

	self.recountFightEncounterId = self.currentEncounterId;
end

function mod:ENCOUNTER_START(event, encounterID, encounterName, difficultyID, raidSize)
	-- Since recount doesn't track the encounter itself, we have to do it.
	-- We do this by setting the currentEncounterId whenever an encounter
	-- starts. If recount is currently in combat, or if recount starts
	-- combat between ENCOUNTER_START and END, then we track that fight as
	-- the fight against the encounter id.

	self.currentEncounterId = encounterID;

	if Recount.InCombat then
		-- If recount currently is in a fight then track
		-- the current encounter id as the encounter being fighted.
		self.recountFightEncounterId = encounterID;
	end
end

function mod:ENCOUNTER_END(event, encounterId, encounterName, difficultyId, raidSize, endStatus)
	self.currentEncounterId = nil;
end

function mod:OnEnable()
	self.pendingParseRequests = {};
	self.currentEncounterId = nil;
	self.recountFightEncounterId = nil;

	self:RegisterEvent("ENCOUNTER_START");
	self:RegisterEvent("ENCOUNTER_END");

	self:SecureHook(Recount, "LeaveCombat");
	self:SecureHook(Recount, "PutInCombat");
end

function mod:OnDisable()
	wipe(self.pendingParseRequests);
	self.currentEncounterId = nil;
	self.recountFightEncounterId = nil;

	self:UnregisterEvent("ENCOUNTER_START");
	self:UnregisterEvent("ENCOUNTER_END");

	self:UnHook(Recount, "LeaveCombat");
	self:UnHook(Recount, "PutInCombat");
end
