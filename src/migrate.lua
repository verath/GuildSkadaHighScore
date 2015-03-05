-- 
-- migrate.lua
-- 
-- Contains database migration
--

local addonName, addonTable = ...

-- Global functions for faster access
local tinsert = tinsert;

-- Set up module
local addon = addonTable[1];
local migrate = addon:NewModule("migrate");
addon.migrate = migrate;


local function migrate7to8(db)
	-- dbVersion is now saved per realm, as every other
	-- options is stored per realm.
	local version = db.global.dbVersion;
	db.realm.dbVersion = version;
	return 8;
end

local function migrate8to9(db)
	-- Each highscore groupParse should have the
	-- guildName, zoneId, difficultyId and encounterId
	-- it is associated with, so that it is possible to
	-- find parses that is connected to a groupParse without
	-- having to look trough all parses.

	local highscoreDb = db.realm.modules["highscore"];

	for guildName, guildData in pairs(highscoreDb.guilds) do
		for zoneId, zoneData in pairs(guildData.zones) do
			for diffId, diffData in pairs(zoneData.difficulties) do
				for encId, encData in pairs(diffData.encounters) do
					for _, parse in pairs(encData.playerParses) do
						local groupParseId = parse.groupParseId;
						local groupParse = highscoreDb.groupParses[groupParseId];
						groupParse.guildName = guildName;
						groupParse.zoneId = zoneId;
						groupParse.difficultyId = diffId;
						groupParse.encounterId = encId;
					end
				end
			end
		end
	end

	return 9;
end


local function migrate9to10(db)
	-- Removed data not used by roles.
	-- * No longer storing damage done by healers.
	-- * No longer storing healing done by dps/tanks.
	-- * Parses must have a valid role (dps, heal, tank).
	--
	-- These changes were all made to remove data that is
	-- not used.

	local highscoreDb = db.realm.modules["highscore"];

	for _, guildData in pairs(highscoreDb.guilds) do
		for _, zoneData in pairs(guildData.zones) do
			for _, diffData in pairs(zoneData.difficulties) do
				for _, encData in pairs(diffData.encounters) do
					for id, parse in pairs(encData.playerParses) do
						if parse.role == "DAMAGER" or parse.role == "TANK" then
							parse.healing = nil;
						elseif parse.role == "HEALER" then
							parse.damage = nil;
						else
							encData.playerParses[id] = nil;
						end
					end
				end
			end
		end
	end

	return 10;
end

local migrateTable = {
	[7] = migrate7to8,
	[8] = migrate8to9,
	[9] = migrate9to10
}

local function resetDb()
	addon:Debug("Resetting db");
	addon.db:ResetDB();
end

function migrate:DoMigration()
	local db = addon.db;
	local targetVersion = addon.dbVersion;

	local currentVersion = 1;
	if db.global.dbVersion then
		-- dbVersion used to be stored in global
		currentVersion = db.global.dbVersion;
	end

	if db.realm.dbVersion and db.realm.dbVersion > currentVersion then
		currentVersion = db.realm.dbVersion
	end

	if currentVersion == targetVersion then
		return;
	end

	self:Debug(format("Attempting to migrate from dbVersion: %d to %d.", 
		currentVersion, targetVersion));

	while currentVersion < targetVersion do
		local migrateFunction = migrateTable[currentVersion];
		if migrateFunction then
			currentVersion = migrateFunction(db);
		else
			self:Debug(format("Could not migrate from dbVersion: %d!", currentVersion));
			resetDb();
			break;
		end
	end

	db.realm.dbVersion = targetVersion;
	self:Debug(format("Migration to dbVersion: %d completed.", 
		targetVersion));
end