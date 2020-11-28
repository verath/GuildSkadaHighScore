--
-- ldb.lua
--
-- LDB launcher and minimap icon setup using LibDBIcon
--

local addonName, addonTable = ...

local LibDataBroker = LibStub:GetLibrary("LibDataBroker-1.1");
local LibDBIcon = LibStub("LibDBIcon-1.0");

-- Set up module
local addon = addonTable[1];
local ldb = addon:NewModule("ldb", "AceEvent-3.0")
addon.ldb = ldb;

-- DB defaults
addon.dbDefaults.profile = addon.dbDefaults.profile or {};
addon.dbDefaults.profile.ldbIcon = {
	hide = false,
};

-- Constants
local LDB_DATA_OBJECT_NAME = "GSHS";
local LDB_ICON_NAME = "GSHS";


function ldb:SetMinimapIconShown(show)
	if show then
		addon.db.profile.ldbIcon.hide = nil;
		LibDBIcon:Show(LDB_ICON_NAME)
	else
		addon.db.profile.ldbIcon.hide = true;
		LibDBIcon:Hide(LDB_ICON_NAME)
	end
end

function ldb:IsMinimapIconShown()
	return (not addon.db.profile.ldbIcon.hide);
end

function ldb:OnClick(clickedframe, button)
	if button == "RightButton" then
		addon.options:ShowOptionsFrame();
	else
		addon.gui:ToggleMainFrame();
	end
end

function ldb:UpdateByZoneTrackDecision()
	local instanceId = select(8, GetInstanceInfo());
	local trackDecision = addon.options:GetInstanceTrackDecision(instanceId);
	self.inTrackedZone = trackDecision and trackDecision.shouldTrack;
	if self.inTrackedZone then
		self.dataObject.iconR = 1;
		self.dataObject.iconG = 1;
		self.dataObject.iconB = 1;
	else
		self.dataObject.iconR = 0.5;
		self.dataObject.iconG = 0.5;
		self.dataObject.iconB = 0.5;
	end
end

function ldb:OnZoneChanged()
	self:UpdateByZoneTrackDecision();
end

function ldb:GSHS_OPTION_CHANGED()
	self:UpdateByZoneTrackDecision();
end

function ldb:OnEnable()
	local dataObject = LibDataBroker:NewDataObject(LDB_DATA_OBJECT_NAME, {
		type = "launcher",
		icon = "Interface\\Icons\\Ability_ThunderKing_LightningWhip",
		iconR = 1,
		iconG = 1,
		iconB = 1,
	});

	function dataObject.OnClick(clickedframe, button)
		if addon:IsEnabled() then
			ldb:OnClick(clickedframe, button);
		end
	end

	function dataObject.OnTooltipShow(tt)
		tt:AddLine("Guild Skada High Score");
		if ldb.inTrackedZone then
			tt:AddLine("[Tracked Zone]");
		else
			tt:AddLine("[Untracked Zone]");
		end
		tt:AddLine("|cffeda55fClick|r to show window.\n" ..
			"|cffeda55fRight-Click|r to show options.", 0.2, 1, 0.2, true);
	end

	LibDBIcon:Register(LDB_ICON_NAME, dataObject, addon.db.profile.ldbIcon);

	-- HACK: Possible workaround for ticket 5, copied from Skada.
	-- The above Register call should already handle this, but
	-- for some reason does not always do so.
	LibDBIcon:Refresh(LDB_ICON_NAME, addon.db.profile.ldbIcon)
	if addon.db.profile.ldbIcon.hide then
		LibDBIcon:Hide(LDB_ICON_NAME)
	else
		LibDBIcon:Show(LDB_ICON_NAME)
	end

	self.dataObject = dataObject;
	self.inTrackedZone = false;
	self:RegisterEvent("ZONE_CHANGED", "OnZoneChanged");
	self:RegisterEvent("ZONE_CHANGED_INDOORS", "OnZoneChanged");
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnZoneChanged");
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnZoneChanged");
	self:RegisterMessage("GSHS_OPTION_CHANGED");
	self:UpdateByZoneTrackDecision();
end

function ldb:OnDisable()
	self.dataObject = nil;
	self:UnregisterEvent("ZONE_CHANGED");
	self:UnregisterEvent("ZONE_CHANGED_INDOORS");
	self:UnregisterEvent("ZONE_CHANGED_NEW_AREA");
	self:UnregisterEvent("PLAYER_ENTERING_WORLD");
	self:UnregisterMessage("GSHS_OPTION_CHANGED");
end
