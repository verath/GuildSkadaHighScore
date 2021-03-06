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
local options = addon:NewModule("options", "AceEvent-3.0");
addon.options = options;


addon.dbDefaults.realm.options = {
	purgeEnabled = false,
	purgeMaxParseAge = 30,
	purgeMinPlayerParsesPerFight = 2,
	instanceTrackDecisions = { 
		-- instanceId => [instanceName, shouldTrack]	
	},
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
							addon.options:SendMessage("GSHS_OPTION_CHANGED");
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
						name = 'Purge All Parses',
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
					RemoveParsesUntrackedRaids = {
						order = 20,
						type = 'execute',
						name = 'Purge Untracked Raids',
						desc = 'Removes all stored parses for unselected Tracked Raids (including Old Expansions).',
						confirm = function()
							return "Are you sure you want to remove ALL stored parses for unselected Tracked Raids?"
								.. " This cannot be undone!";
						end,
						func = function()
							local numRemoved = 0;
							local zoneIdsToRemove = {};
							for instanceId, trackDecision in pairs(addon.db.realm.options["instanceTrackDecisions"]) do
								if not trackDecision.shouldTrack then
									tinsert(zoneIdsToRemove, instanceId);
								end
							end
							for _, zoneId in ipairs(zoneIdsToRemove) do
								addon.highscore:PurgeParsesByZoneId(zoneId);
							end
							addon:Printf("Parses from untracked raids were removed.", #zoneIdsToRemove);
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
			trackDecisions = {
				name = "Tracked Raids (Current Expansion)",
				desc = "Parses are recorded for selected raid zones. Raids are added as you enter them.",
				type = "multiselect",
				width = "full",
				order = 40,
				values = function()
					local expLevel = GetExpansionLevel();
					local trackDecisions = {};
					for instanceId, trackDecision in pairs(addon.db.realm.options["instanceTrackDecisions"]) do
						if not addon.knownRaids:IsRaidForOldExpansion(expLevel, instanceId) then
							trackDecisions[instanceId] = string.format(
								"%s [%d]", trackDecision.instanceName, instanceId);
						end
					end
					return trackDecisions;
				end,
				get = function(_, instanceId)
					return addon.db.realm.options["instanceTrackDecisions"][instanceId].shouldTrack;
				end,
				set = function(_, instanceId, state)
					addon.db.realm.options["instanceTrackDecisions"][instanceId].shouldTrack = state;
					addon.options:SendMessage("GSHS_OPTION_CHANGED");
				end,
			},
			trackDecisionsPreviousExpansions = {
				name = "Tracked Raids (Old Expansions)",
				desc = "Parses are recorded for selected (old) raid zones. Raids are added as you enter them.",
				type = "multiselect",
				width = "full",
				order = 50,
				values = function()
					local expLevel = GetExpansionLevel();
					local trackDecisions = {};
					for instanceId, trackDecision in pairs(addon.db.realm.options["instanceTrackDecisions"]) do
						if addon.knownRaids:IsRaidForOldExpansion(expLevel, instanceId) then
							trackDecisions[instanceId] = string.format(
								"%s [%d]", trackDecision.instanceName, instanceId);
						end
					end
					return trackDecisions;
				end,
				get = function(_, instanceId)
					return addon.db.realm.options["instanceTrackDecisions"][instanceId].shouldTrack;
				end,
				set = function(_, instanceId, state)
					addon.db.realm.options["instanceTrackDecisions"][instanceId].shouldTrack = state;
					addon.options:SendMessage("GSHS_OPTION_CHANGED");
				end,
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
	addon.options:SendMessage("GSHS_OPTION_CHANGED");
end

function options:GetOptionsTable()
	if not optionsTable then
		createOptionsTable()
	end
	return optionsTable
end

function options:ShowOptionsFrame()
	InterfaceOptionsFrame_Show();
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

function options:HasInstanceTrackDecision(instanceId)
	return addon.db.realm.options["instanceTrackDecisions"][instanceId] ~= nil
end

function options:GetInstanceTrackDecision(instanceId)
	local trackDecision = addon.db.realm.options["instanceTrackDecisions"][instanceId]
	local trackDecisionCopy = nil;
	if trackDecision ~= nil then
		trackDecisionCopy = {
			instanceName = trackDecision.instanceName,
			shouldTrack = trackDecision.shouldTrack,
		};
	end
	return trackDecisionCopy;
end

function options:SetInstanceTrackDecision(instanceId, instanceName, shouldTrack)
	local trackDecision = {
		instanceName = instanceName,
		shouldTrack = shouldTrack,
	};
	addon.db.realm.options["instanceTrackDecisions"][instanceId] = trackDecision;
end

function options:OnEnable()
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(addonName, options.GetOptionsTable);
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName);
end
