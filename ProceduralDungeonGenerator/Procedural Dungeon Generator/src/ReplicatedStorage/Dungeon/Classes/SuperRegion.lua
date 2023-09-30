--[[   Service dependencies   --]]
local RS = game:GetService("ReplicatedStorage");
local SvrSto = game:GetService("ServerStorage");

--[[   Folder references   --]]
local dungeonFolder = RS.Dungeon;
local config = dungeonFolder.Configuration;
local classes = dungeonFolder.Classes;
local cellDrawings = workspace.CellDrawings;
local nonClassModules = dungeonFolder.NonClassModules;
local misc = RS.Misc;

--[[   Class dependencies   --]]
local GameObject = require(misc.GameObject);
local Cell = require(classes.Cell);
local Region = require(classes.Region);

--[[   External dependencies   --]]
local Util = require(misc.Util);

--[[   Useful variables   --]]
local numRows = math.floor(config.CanvasY.Value / config.CellSize.Value);
local numCols = math.floor(config.CanvasX.Value / config.CellSize.Value);

local SuperRegion = GameObject:extend();

--[[   Constructor   --]]
function SuperRegion:new(eyedee)
	self.regions = {};
	--self.color = Color3.new(Util:RandBias(.15,1,1), Util:RandBias(.15,1,1), Util:RandBias(.15,1,1)); 
	self.color = Color3.new(0.313725, 0.752941, 0.572549)
	self.id = eyedee; -- starts at 0
end

--[[   Getter methods   --]]
function SuperRegion:GetRegions()
	return self.regions;
end

function SuperRegion:GetSize()
	return #self.regions;
end

function SuperRegion:GetColor()
	return self.color;
end

function SuperRegion:GetId()
	return self.id;
end

function SuperRegion:GetPotentialPassageways(grid) 
	-- first add all non-duplicate passageways into results arr
	-- then remove all the passageways that connect to this superregion
	local result = {};
	for i,v in pairs(self.regions) do
		local currRegPassages = v:GetPotentialPassageways(grid);
		for j,k in pairs(currRegPassages) do
			if Util:IndexOf(result, k) == -1 and k:GetPassageStatus() ~= 1 and k:GetColor3() ~= Color3.new(0,1,1) and k:GetColor3() ~= Color3.new(1,.5,0) then
				table.insert(result, k);
			else
				-- if k is red then make it orange
				k:Highlight(Color3.new(1,.5,0));
			end
		end
	end
	for i,v in pairs(result) do
		local top = v:GetNeighboringCell(grid, "TOP");
		local right = v:GetNeighboringCell(grid, "RIGHT");
		local bottom = v:GetNeighboringCell(grid, "BOTTOM");
		local left = v:GetNeighboringCell(grid, "LEFT");
		if (top and bottom and top:GetSuperRegionId() == bottom:GetSuperRegionId() and top:GetSuperRegionId() ~= -1) or
			(left and right and left:GetSuperRegionId() == right:GetSuperRegionId() and left:GetSuperRegionId() ~= -1)
		then
			v:Highlight(Color3.new(1,.5,0));
			table.remove(result, Util:IndexOf(result, v));
			v:Rockify(); v:SetPassageStatus(-1);
		else
			if top and right and bottom and left then
				--print(v:GetRow(),v:GetCol(),"marked as critical passage because ", top:GetSuperRegionId(), bottom:GetSuperRegionId(), left:GetSuperRegionId(), right:GetSuperRegionId());
			end
			v:Highlight(Color3.new(1,0,0)); -- it is critical passage
		end
	end
	return result;
end

function SuperRegion:PrintRegions()
	for i,v in pairs(self.regions) do
		print(v);
	end
end

--[[   Mutator methods   --]]
function SuperRegion:AddRegion(region)
	table.insert(self.regions, region);
	for i,v in pairs(region:GetCells()) do
		v:SetSuperRegionId(self.id);
	end
	region:Highlight(self.color);
end

return SuperRegion;