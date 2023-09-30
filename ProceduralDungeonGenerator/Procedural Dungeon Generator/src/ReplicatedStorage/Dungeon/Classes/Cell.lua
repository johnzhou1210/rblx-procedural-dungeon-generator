--[[   Service dependencies   --]]
local RS = game:GetService("ReplicatedStorage");
local SvrSto = game:GetService("ServerStorage");
local CollS = game:GetService("CollectionService");

--[[   Folder references   --]]
local dungeonFolder = RS.Dungeon;
local config = dungeonFolder.Configuration;
local classes = dungeonFolder.Classes;
local cellDrawings = workspace.CellDrawings;
local nonClassModules = dungeonFolder.NonClassModules;
local misc = RS.Misc;

--[[   Class dependencies   --]]
local GameObject = require(misc.GameObject);

--[[   External dependencies   --]]
local Util = require(misc.Util);

--[[   Useful variables   --]]
local numRows = math.floor(config.CanvasY.Value / config.CellSize.Value);
local numCols = math.floor(config.CanvasX.Value / config.CellSize.Value);

local Cell = GameObject:extend();

--[[   Constructor   --]]
function Cell:new(r, c, gid)
	self.row = r;
	self.col = c;
	self.walls = {true, true, true, true}; -- true means that wall exists. Order is clockwise (top, right, bottom, left).
	self.visited = false;
	self.color3 = Color3.new(1,1,1);
	self.region = nil;
	self.gridIndex = gid;
	self.passageStatus = -1; -- -1 means that it is not passage, 0 means it is potential passage, 1 means it is passage
	self.superRegionId = -1;
	self.passageDirection = nil;
	self.passageType = nil;
	self.stairStatus = -1; -- -1 means it is not stair, 0 means that it is down stairs, 1 mean it is up stairs
end

--[[   Getter methods   --]]
function Cell:GetRow()
	return self.row;
end

function Cell:GetCol()
	return self.col;
end

function Cell:GetPassageStatus()
	return self.passageStatus;
end

function Cell:GetStairStatus()
	return self.stairStatus;
end

function Cell:GetRCStr()
	return self.row..","..self.col;
end

function Cell:GetWalls()
	return self.walls;
end

function Cell:IsVisited()
	return self.visited;
end

function Cell:IsCorridor() -- a cell is a corridor when it is not rocked and region is nil
	return self.color3 == Color3.new(1,1,0) or not (self:IsRock() and self.region == nil);
end

function Cell:GetPassageType()
	return self.passageType;
end

function Cell:Index(colNum, rowNum)
	if colNum < 1 or rowNum < 1 or colNum > numCols or rowNum > numRows then -- invalid indices
		return -1;
	end
	return numCols * (rowNum - 1) + colNum;
end

function Cell:GetPassageDirection()
	return self.passageDirection;
end

function Cell:CheckNeighbors(grid)
	local neighbors = {};
	local top = grid[self:Index(self.col, self.row - 1)];
	local right = grid[self:Index(self.col + 1, self.row)];
	local bottom = grid[self:Index(self.col, self.row + 1)];
	local left = grid[self:Index(self.col - 1, self.row)];
	if top ~=nil and not top.visited then
		table.insert(neighbors, top);
	end
	if right ~=nil and not right.visited then
		table.insert(neighbors, right);
	end
	if bottom ~=nil and not bottom.visited then
		table.insert(neighbors, bottom);
	end
	if left ~=nil and not left.visited then
		table.insert(neighbors, left);
	end
	
	if #neighbors > 0 then
		local rng = Random.new():NextInteger(1, #neighbors);
		return neighbors[rng];
	end
	return nil;
end

function Cell:GetRandomNeighbor(grid)
	local neighbors = {};
	local top = grid[self:Index(self.col, self.row - 1)];
	local right = grid[self:Index(self.col + 1, self.row)];
	local bottom = grid[self:Index(self.col, self.row + 1)];
	local left = grid[self:Index(self.col - 1, self.row)];
	if top ~=nil then
		table.insert(neighbors, top);
	end
	if right ~=nil then
		table.insert(neighbors, right);
	end
	if bottom ~=nil then
		table.insert(neighbors, bottom);
	end
	if left ~=nil then
		table.insert(neighbors, left);
	end
	if #neighbors > 0 then
		local rng = Random.new():NextInteger(1, #neighbors);
		return neighbors[rng];
	end
	return nil;
end

function Cell:GetAdjacentRockedRoomCells(grid)
	local adjacents = {};
	local top = grid[self:Index(self.col, self.row - 1)];
	local right = grid[self:Index(self.col + 1, self.row)];
	local bottom = grid[self:Index(self.col, self.row + 1)];
	local left = grid[self:Index(self.col - 1, self.row)];
	if top ~= nil and top:GetRegion() == self:GetRegion() and top:IsRock() then
		table.insert(adjacents, top);
	end
	if right ~= nil and right:GetRegion() == self:GetRegion() and right:IsRock() then
		table.insert(adjacents, right);
	end
	if bottom ~= nil and bottom:GetRegion() == self:GetRegion() and bottom:IsRock() then
		table.insert(adjacents, bottom);
	end
	if left ~= nil and left:GetRegion() == self:GetRegion() and left:IsRock() then
		table.insert(adjacents, left);
	end
	return adjacents;
end

function Cell:IsOtherRoom(roomCells)
	local bool =  Util:IndexOf(roomCells, self) == -1 and not self:IsRock();
	if bool then self:Highlight(Color3.new(1,1,1)); end
	return Util:IndexOf(roomCells, self) == -1;
end

function Cell:GetAdjacentCells(grid)
	local adjacents = {};
	local top = grid[self:Index(self.col, self.row - 1)];
	local right = grid[self:Index(self.col + 1, self.row)];
	local bottom = grid[self:Index(self.col, self.row + 1)];
	local left = grid[self:Index(self.col - 1, self.row)];
	if top ~= nil then
		table.insert(adjacents, top);
	end
	if right ~= nil then
		table.insert(adjacents, right);
	end
	if bottom ~= nil then
		table.insert(adjacents, bottom);
	end
	if left ~= nil then
		table.insert(adjacents, left);
	end
	return adjacents;
end

function Cell:GetNeighboringCell(grid, dir)
	local top = grid[self:Index(self.col, self.row - 1)];
	local topLeft = grid[self:Index(self.col - 1, self.row - 1)];
	local topRight = grid[self:Index(self.col + 1, self.row - 1)];
	local right = grid[self:Index(self.col + 1, self.row)];
	local left = grid[self:Index(self.col - 1, self.row)];
	local bottom = grid[self:Index(self.col, self.row + 1)];
	local bottomLeft = grid[self:Index(self.col - 1, self.row + 1)];
	local bottomRight = grid[self:Index(self.col + 1, self.row + 1)];
	if dir == "TOP" then return top; end
	if dir == "TOPLEFT" then return topLeft; end
	if dir == "TOPRIGHT" then return topRight; end
	if dir == "RIGHT" then return right; end
	if dir == "LEFT" then return left; end
	if dir == "BOTTOM" then return bottom; end
	if dir == "BOTTOMLEFT" then return bottomLeft; end
	if dir == "BOTTOMRIGHT" then return bottomRight; end
	error("Invalid dir!");
end


function Cell:RadialCheck(grid) -- as in surrounding cells
	local radials = {};
	local top = grid[self:Index(self.col, self.row - 1)];
	local topLeft = grid[self:Index(self.col - 1, self.row - 1)];
	local topRight = grid[self:Index(self.col + 1, self.row - 1)];
	local right = grid[self:Index(self.col + 1, self.row)];
	local left = grid[self:Index(self.col - 1, self.row)];
	local bottom = grid[self:Index(self.col, self.row + 1)];
	local bottomLeft = grid[self:Index(self.col - 1, self.row + 1)];
	local bottomRight = grid[self:Index(self.col + 1, self.row + 1)];
	if top ~= nil then
		table.insert(radials, top);
	end
	if right ~= nil then
		table.insert(radials, right);
	end
	if bottom ~= nil then
		table.insert(radials, bottom);
	end
	if left ~= nil then
		table.insert(radials, left);
	end
	if topLeft ~= nil then
		table.insert(radials, topLeft);
	end
	if topRight ~= nil then
		table.insert(radials, topRight);
	end
	if bottomLeft ~= nil then
		table.insert(radials, bottomLeft);
	end
	if bottomRight ~= nil then
		table.insert(radials, bottomRight);
	end
	return radials;
end

function Cell:GetAdjacentCellsOfSameRoom(grid, goodCells)
	local adjacents = {};
	local top = grid[self:Index(self.col, self.row - 1)];
	local right = grid[self:Index(self.col + 1, self.row)];
	local bottom = grid[self:Index(self.col, self.row + 1)];
	local left = grid[self:Index(self.col - 1, self.row)];
	if top ~= nil and Util:IndexOf(goodCells, top) ~= -1 then
		table.insert(adjacents, top);
	end
	if right ~= nil and Util:IndexOf(goodCells, right) ~= -1 then
		table.insert(adjacents, right);
	end
	if bottom ~= nil and Util:IndexOf(goodCells, bottom) ~= -1 then
		table.insert(adjacents, bottom);
	end
	if left ~= nil and Util:IndexOf(goodCells, left) ~= -1 then
		table.insert(adjacents, left);
	end
	return adjacents;
end

function Cell:IsRock()
	-- a cell is rock if it has walls on 4 sides.
	return self.walls[1] == true and self.walls[2] == true and self.walls[3] == true and self.walls[4] == true;
end

function Cell:GetSuperRegionId()
	return self.superRegionId;
end

function Cell:IsDeadEnd(grid)
	-- a cell is a dead end when it has walls on 3 sides.
	local wallCount = 0;
	for i = 1, 4 do
		if self.walls[i] == true then
			wallCount = wallCount + 1;
		end
	end
	if wallCount == 3 then
		return true;
	end
	return false;
end

function Cell:GetRegion()
	return self.region;
end

function Cell:GetNextDeadEnd(grid)
	-- a cell is a dead end when it has walls on 3 sides.
	--return the cell that came before it
	-- we know that the current cell is a dead end, but we don't know which wall is open.
	--make current cell a rock
	local openCell;
	if not self.walls[1] then
		openCell = grid[self:Index(self.col, self.row-1)];
		if (openCell ~= nil) then
			openCell:SetWall(3, true);
			return openCell;	
		end
		return nil;
	end
	if not self.walls[2] then
		openCell = grid[self:Index(self.col+1, self.row)]; 
		if (openCell ~= nil) then
			openCell:SetWall(4, true);
			return openCell;	
		end
		return nil;
	end
	if not self.walls[3] then
		openCell = grid[self:Index(self.col, self.row+1)]; 
		if (openCell ~= nil) then
			openCell:SetWall(1, true);
			return openCell;		
		end
		return nil;
	end
	if not self.walls[4] then
		openCell = grid[self:Index(self.col-1, self.row)];
		if (openCell ~= nil) then
			openCell:SetWall(2, true);
			return openCell;		
		end
		return nil;
	end
	--print("dodged other statements")
	return nil;
end

function Cell:GetWorldPos()
	local x = self.col * config.CellSize.Value;
	local z = self.row * config.CellSize.Value;
	return Vector3.new(x,1,z+(config.CellSize.Value/2));
end

function Cell:GetColor3()
	return self.color3;
end

--[[   Mutator methods   --]]
function Cell:Highlight(color3)
	self.color3 = color3;
	cellDrawings[self.row.." | "..self.col].Color = self.color3;			
end

function Cell:SetDecal(id, color3)
	local currCell = cellDrawings[self.row.." | "..self.col];
	if id == nil then
		if currCell:FindFirstChild("Decal") ~= nil then
			currCell:FindFirstChild("Decal"):Remove();
		end
		return;
	end
	local decal;
	if currCell and currCell:FindFirstChild("Decal") == nil then
		decal = Instance.new("Decal");
		decal.Parent = currCell;
		decal.Face = Enum.NormalId.Top;
	else
		decal = currCell:FindFirstChild("Decal");
	end
	decal.Texture = "rbxassetid://"..id;
	if color3 == nil then
		color3 = Color3.new(1,1,1);
	else
		decal.Color3 = color3;	
	end
end

function Cell:WallVisual(trans, indx)
	cellDrawings["("..self.row..","..self.col.."): "..tostring((indx-1) * 90)].Transparency = trans;
	if self.walls[indx] == false then -- hide wall from visual
		cellDrawings["("..self.row..","..self.col.."): "..tostring((indx-1) * 90)].CanCollide = false;
	else
		cellDrawings["("..self.row..","..self.col.."): "..tostring((indx-1) * 90)].CanCollide = true;
	end
end

function Cell:MarkWalls(effect)
	effect:Clone().Parent = cellDrawings["("..self.row..","..self.col.."): ".."0"];
	effect:Clone().Parent = cellDrawings["("..self.row..","..self.col.."): ".."90"];
	effect:Clone().Parent = cellDrawings["("..self.row..","..self.col.."): ".."180"];
	effect:Clone().Parent = cellDrawings["("..self.row..","..self.col.."): ".."270"];
end

function Cell:SetPassageType(newType)
	self.passageType = newType;
end

function Cell:SetStairStatus(int)
	self.stairStatus = int;
end

function Cell:Show()
	local x = self.col * config.CellSize.Value;
	local z = self.row * config.CellSize.Value;
	-- draw a square at this location
	local sq = Instance.new("Part");
	sq.Parent = cellDrawings;
	sq.Size = Vector3.new(config.CellSize.Value, 1, config.CellSize.Value);
	sq.CFrame = (CFrame.new(x, 0, z+(config.CellSize.Value/2))) * CFrame.Angles(0,math.rad(180),0);
	sq.Name = self.row.." | "..self.col;
	sq.Color = self.color3;
	sq.Anchored = true;
	local att = Instance.new("IntValue");
	att.Parent = sq;
	att.Value = self.gridIndex;
	att.Name = "GridIndex";
	-- draw 4 lines starting at this location
	local function mark(color3)
		local part = Instance.new("Part");
		part.Parent = cellDrawings;
		part.Name = "Marker";
		part.Anchored = true;
		part.CanCollide = false;
		part.Size = Vector3.new(config.CellSize.Value,0,config.CellSize.Value);
		part.CFrame = CFrame.new(Vector3.new(x,1,z+(config.CellSize.Value/2)));
		part.Color = color3;
	end
	local function placeWall(startX, startZ, theta)
		local line = Instance.new("Part");
		line.Parent = cellDrawings;
		line.Anchored = true;
		line.Size = Vector3.new(config.CellSize.Value, config.WallHeight.Value, config.WallThickness.Value);
		line.CFrame = CFrame.new(Vector3.new(startX, (config.WallHeight.Value/2), startZ)) * CFrame.Angles(0, math.rad(theta), 0);
		line.Name = "("..self.row..","..self.col.."): "..theta;
		line.Color = Color3.new(0, 0.211765, 0.25098);
	end
	if self.walls[1] then
		placeWall(x, z, 0); -- north wall
	end
	if self.walls[2] then
		placeWall(x + (config.CellSize.Value/2) , z + (config.CellSize.Value/2), 90); -- east wall
	end
	if self.walls[3] then
		placeWall(x, z + (config.CellSize.Value), 180); -- south wall
	end
	if self.walls[4] then
		placeWall(x - (config.CellSize.Value/2), z + (config.CellSize.Value/2), 270); -- west wall
	end
end

function Cell:SetPassageDirection(newDir)
	self.passageDirection = newDir;
end

function Cell:SetVisited(bool)
	self.visited = bool;
end

function Cell:SetSuperRegionId(id)
	self.superRegionId = id;
end

function Cell:SetWall(indx, bool)
	self.walls[indx] = bool;
	local trans;
	if bool == true then trans = 0; else trans = .9; end
	self:WallVisual(trans, indx);
end

function Cell:Rockify()
	for i,v in pairs(self.walls) do
		self.walls[i] = true;
		self:WallVisual(0, i);
	end
end

function Cell:SetRegion(room) 
	self.region = room;
end

function Cell:SetPassageStatus(int)
	self.passageStatus = int;
end

return Cell;