local addonName, addonTable = ...

-- Set up module
local addon = addonTable[1];
local options = addon:NewModule("options");
addon.options = options;


addon.dbDefaults.realm.options = {
	purgeEnabled = true,
	purgeMaxParseAge = 30,
	purgeMinPlayerParsesPerFight = 2,
}
addon.dbVersion = addon.dbVersion + 0;

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
			purgeSettings = {
				name = "Purge Settings",
				type = "group",
				inline = true,
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
						desc = "The minimum number of parses to keep for a specific player and fight. These parses will not be removed even if they are older than the max parse age.",
						disabled = function() return not addon.db.realm.options.purgeEnabled; end,
					}
				},
				order = 20,
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

function options:OnEnable()
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(addonName, options.GetOptionsTable);
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName);
end
