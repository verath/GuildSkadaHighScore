local addonName, addonTable = ...

-- Global functions for faster access
local tinsert = tinsert;
local tContains = tContains;

-- Set up module
local addon = addonTable[1];
local gui = addon:NewModule("gui")
addon.gui = gui;

-- AceGUI
local AceGUI = LibStub("AceGUI-3.0");

function gui:OnEnable()

end

function gui:OnDisable()

end