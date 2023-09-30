--[[   Service dependencies   --]]
local RS = game:GetService("ReplicatedStorage");
local Plrs = game:GetService("Players");
local CAS = game:GetService("ContextActionService");

--[[   Folder references   --]]
local dungeonFolder = RS.Dungeon;
local config = dungeonFolder.Configuration;
local classes = dungeonFolder.Classes;
local nonClassModules = dungeonFolder.NonClassModules;
local remoteEvents = dungeonFolder.RemoteEvents;
local misc = RS.Misc;

--[[   Class dependencies   --]]

--[[   External dependencies   --]]
local Util = require(misc.Util);

--[[   Key variables   --]]
local lPlr = Plrs.LocalPlayer;

function genRequest()
	remoteEvents.DunGen:FireServer();
end

function handleAction(actionName, inputState, inputObj)
	if actionName == "GenerateDungeon" and inputState == Enum.UserInputState.Begin then
		genRequest();
	end
end


CAS:BindAction("GenerateDungeon", handleAction, true, Enum.KeyCode.G);