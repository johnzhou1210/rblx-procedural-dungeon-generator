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

--[[   External dependencies   --]]
local Util = require(misc.Util);

--[[   Useful variables   --]]
local numRows = math.floor(config.CanvasY.Value / config.CellSize.Value);
local numCols = math.floor(config.CanvasX.Value / config.CellSize.Value);

local Region = GameObject:extend();

--[[   Constructor   --]]
function Region:new(roomBool)
	self.cells = {};
	self.color = Color3.new(Util:RandBias(.15,1,1), Util:RandBias(.15,1,1), Util:RandBias(.15,1,1)); 
	self.isRoom = roomBool;
	self.recursivelyConnectedRegions = {};
end

--[[   Getter methods   --]]
function Region:GetCells()
	return self.cells;
end

function Region:GetSize()
	return #self.cells;
end

function Region:GetCellPart(indx)
	local cell = self.cells[indx];
	return workspace.CellDrawings[cell:GetRow().." | "..cell:GetCol()];
end

function Region:GetPeripheryCells(grid)
	local result = {};
	for i,v in pairs(self.cells) do
		local top = v:GetNeighboringCell(grid, "TOP");
		local right = v:GetNeighboringCell(grid, "RIGHT");
		local down = v:GetNeighboringCell(grid, "BOTTOM");
		local left = v:GetNeighboringCell(grid, "LEFT");
		-- a cell is a periphery cell when at least one of their neighboring cells are rock or nil.
		if top == nil or Util:IndexOf(self.cells, top) == -1 or right == nil or Util:IndexOf(self.cells, right) == -1 or down == nil or Util:IndexOf(self.cells, down) == -1 or left == nil or Util:IndexOf(self.cells, left) == -1 then
			table.insert(result, v);
		end
	end
	return result;
end

function Region:GetColor()
	return self.color;
end

function Region:GetPotentialPassageways(grid)
	local result = {};
	local periCells = self:GetPeripheryCells(grid);
	for i,v in pairs(periCells) do
		local adjs = v:GetAdjacentCells(grid)
		for j,k in pairs(adjs) do
			if k:IsRock() and k:GetPassageStatus() ~= 1 then
				-- see if the direction of the current cell and the rock cell are vertical or horizontal
				local function getCellPairDir(cellA, cellB)
					local aRow = cellA:GetRow(); local bRow = cellB:GetRow();
					local aCol = cellA:GetCol(); local bCol = cellB:GetCol();
					if aRow == bRow then return "Horizontal"; end
					if aCol == bCol then return "Vertical"; end
					error("cannot get cardinal direction of cellA and cellB!");
				end
				local dir = getCellPairDir(v, k);
				local above = k:GetNeighboringCell(grid, "TOP");
				local below = k:GetNeighboringCell(grid, "BOTTOM");
				local left = k:GetNeighboringCell(grid, "LEFT");
				local right = k:GetNeighboringCell(grid, "RIGHT");
				if dir == "Horizontal" then
					-- look above and below k
					-- there also has to be cells that belong to a region to the left and right
					local connecteesPresent = left and left:GetRegion() ~= nil and right and right:GetRegion() ~= nil;
					if (above == nil or  (above and above:IsRock())) and (below == nil or (below and below:IsRock())) and connecteesPresent then -- passage way is horizontal
						table.insert(result, k);
						k:SetPassageStatus(0);
					end
				else -- must be vertical
					-- look to the left and right of k
					-- there also has to be cells that belong to a region above and below
					local connecteesPresent = above and above:GetRegion() ~= nil and below and below:GetRegion() ~= nil;
					if (left == nil or (left and left:IsRock())) and (right == nil or (right and right:IsRock())) and connecteesPresent then -- passage way is vertical
						table.insert(result, k);
						k:SetPassageStatus(0);
					end
				end

			end
		end
	end
	return result;
end

function Region:IsRoom()
	return self.isRoom;
end

--[[   Mutator methods   --]]
function Region:ClearCells()
	while #self.cells > 0 do
		local removedElem = table.remove(self.cells, #self.cells);
		removedElem:SetRegion(nil);
		removedElem:Rockify();
		removedElem:Highlight(Color3.new(0,0,0));
		removedElem:SetPassageStatus(-1);
	end
end

function Region:Destroy()
	self:ClearCells();
	self = nil;
end

function Region:AddCell(cell)
	table.insert(self.cells, cell);
	cell:SetRegion(self);
	cell:Highlight(self.color);
end

function Region:Highlight(color3)
	self.color = color3;
	for i,v in pairs(self.cells) do
		v:Highlight(color3);
	end
end

function Region:AddConnectedRegion(other)
	table.insert(self.recursivelyConnectedRegions, other);
end

function Region:ConnectRegion(other)
	self:AddConnectedRegion(other);
	other:AddConnectedRegion(self);
end


return Region;