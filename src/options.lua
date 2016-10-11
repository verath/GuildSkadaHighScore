-- 
-- options.lua
-- 
-- Contains options setup and management
--


local addonName, addonTable = ...

-- Cached globals
local format = format;
local wipe = wipe;

-- Non-cached globals (for mikk's FindGlobals script)
-- GLOBALS: LibStub, InterfaceOptionsFrame_OpenToCategory

-- Set up module
local addon = addonTable[1];
local options = addon:NewModule("options");
addon.options = options;


addon.dbDefaults.realm.options = {
	purgeEnabled = false,
	purgeMaxParseAge = 30,
	purgeMinPlayerParsesPerFight = 2,
}

local optionsTable;
local function createOptionsTable()
	optionsTable = {
		name = "Guild Skada High Score",
		handler = options,
		get = "GetRealmOptionValue",
		set = "SetRealmOptionValue",
		type = 'group',
		args = {
			versionHeader = {
				order = 1,
				type = "header",
				name = format("Version: %s", addon.versionName),
				width = "Full",
			},
			generalSettings = {
				name = "General",
				type = "group",
				inline = true,
				order = 5,
				args = {
					ShowMinimapIcon = {
						name = "Minimap Icon",
						desc = "Toggles the icon on the minimap.",
						type = "toggle",
						width = "full",
						order = 10,
						get = function()
							return addon.ldb:IsMinimapIconShown();
						end,
						set = function(info, v)
							addon.ldb:SetMinimapIconShown(v);
						end,
					},
				},
			},
			actions = {
				name = "Actions",
				type = "group",
				inline = true,
				order = 10,
				args = {
					RemoveParses = {
						order = 10,
						type = 'execute',
						name = 'Remove All Parses',
						desc = 'Removes ALL stored parses.',
						confirm = function()
							return 'Are you sure you want to remove ALL stored parses?'
								.. ' This cannot be undone!';
						end,
						func = function()
							wipe(addon.highscore:GetDB());
							addon:SetupDatabase();
							addon:Print("All parses have been removed.");
						end,
					},
				},
			},
			purgeSettings = {
				name = "Purge Settings",
				type = "group",
				inline = true,
				order = 20,
				args = {
					purgeEnabled = {
						order = 1,
						type = "toggle",
						name = "Enable Purging of Parses",
						desc = "Enables purging of parses matching some specified condition.",
					},
					purgeMaxParseAge = {
						order = 3,
						type = "range",
						min = 0,
						max = 60,
						step = 1,
						name = "Max Parse Age (days)",
						desc = "Number of days to keep parses.",
						disabled = function() return not addon.db.realm.options.purgeEnabled; end,
					},
					purgeMinPlayerParsesPerFight = {
						order = 5,
						type = "range",
						min = 0,
						softMax = 20,
						max = 100,
						step = 1,
						name = "Min Parses Per Player/Fight",
						desc = "The minimum number of parses to keep for a specific player, spec and fight. These parses will not be removed even if they are older than the max parse age.",
						disabled = function() return not addon.db.realm.options.purgeEnabled; end,
					}
				},
			},
			creditsSeparator = {
				name = "",
				order = -1,
				type = "header",
				width = "Full",
			},
			credits = {
				name = "Credits",
				order = -1,
				type = "group",
				inline = true,
				args = {
					text = {
						order = 1,
						type = "description",
						name = "Big thanks to Zalk for helping me test the addon!",
					},
				},
			},
		},
	};
end

function options.GetRealmOptionValue(self, info)
	local key = info[#info];
	return addon.db.realm.options[key];
end

function options.SetRealmOptionValue(self, info, value)
	local key = info[#info];
	addon.db.realm.options[key] = value;
end

function options:GetOptionsTable()
	if not optionsTable then
		createOptionsTable()
	end
	return optionsTable
end

function options:ShowOptionsFrame()
	InterfaceOptionsFrame_OpenToCategory(self.optionsFrame);
end

--
-- Helper Methods for accessing db option properties
--

function options:GetPurgeEnabled()
	return addon.db.realm.options["purgeEnabled"];
end

function options:GetPurgeMaxParseAge()
	return addon.db.realm.options["purgeMaxParseAge"];
end

function options:GetPurgeMinPlayerParsesPerFight()
	return addon.db.realm.options["purgeMinPlayerParsesPerFight"];
end

function options:OnEnable()
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(addonName, options.GetOptionsTable);
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName);
end
