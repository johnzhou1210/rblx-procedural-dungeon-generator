--[[   Service dependencies   --]]
local RS = game:GetService("ReplicatedStorage");
local ServStor = game:GetService("ServerStorage");

--[[   Folder references   --]]
local dungeonFolder = RS.Dungeon;
local config = dungeonFolder.Configuration;
local classes = dungeonFolder.Classes;
local nonClassModules = dungeonFolder.NonClassModules;
local remoteEvents = dungeonFolder.RemoteEvents;
local particleEffetcs = ServStor.ParticleEffects;
local misc = RS.Misc;

--[[   Class dependencies   --]]
local Cell = require(classes.Cell);
local Region = require(classes.Region);
local SuperRegion = require(classes.SuperRegion);

--[[   External dependencies   --]]
local Util = require(misc.Util);
local DecalLib = require(nonClassModules.DecalLib);

--[[   Key variables   --]]
local numRows = math.floor(config.CanvasY.Value / config.CellSize.Value);
local numCols = math.floor(config.CanvasX.Value / config.CellSize.Value);
local grid = {};
local regions = {};
local superRegion = nil;
local currCell;
local stack = {};
local genDone = false;
local endCell, startCell;
local stackPeakSize = 0;
local largestStack;
local corridorsRemaining;
local corridorsRemoved;
local initialDeadEnds = {};
local deadEnds = {};
local roomTries = config.RoomTries.Value;

--[[   Key functions   --]]
function wallCheck()
	for i,v in pairs(grid) do
		if (v:GetColor3() == Color3.new(0,0,0) or v:GetColor3() == Color3.new(1,0,0)) and v:IsRock() == false then
			error("wallCheck() FAIL!: "..v:GetRCStr());
		end 
	end
end

function clearCellDrawings()
	workspace.CellDrawings:ClearAllChildren();
end

function RemoveWalls(cellA, cellB)
	local cellDiffX = cellA:GetCol() - cellB:GetCol();
	if cellDiffX == 1 then -- (cellB came before cellA because cellA index is greater than cellB index by 1)
		cellA:SetWall(4, false); -- remove left wall
		cellB:SetWall(2, false) -- remove right wall
		cellA:WallVisual(.9, 4); cellB:WallVisual(.9, 2); -- for visual purposes
	elseif cellDiffX == -1 then -- (cellB came after cellA because cellA index is less than cellB index by 1)
		cellA:SetWall(2, false); -- remove right wall
		cellB:SetWall(4, false); -- remove left wall
		cellA:WallVisual(.9, 2); cellB:WallVisual(.9, 4); -- for visual purposes
	end
	local cellDiffY = cellA:GetRow() - cellB:GetRow();
	if cellDiffY == 1 then -- (cellA has greater Y val than cellB)
		cellA:SetWall(1, false); -- remove top wall of cellA
		cellB:SetWall(3, false) -- remove bottom wall of cellB
		cellA:WallVisual(.9, 1); cellB:WallVisual(.9, 3); -- for visual purposes
	elseif cellDiffY == -1 then -- (cellB has greater Y val than cellA)
		cellA:SetWall(3, false); -- remove bottom wall of cellA
		cellB:SetWall(1, false); -- remove top wall of cellB
		cellA:WallVisual(.9, 3); cellB:WallVisual(.9, 1); -- for visual purposes
	end
end


function ConnectWalls(cellA, cellB)
	local cellDiffX = cellA:GetCol() - cellB:GetCol();
	if cellDiffX == 1 then -- (cellB came before cellA because cellA index is greater than cellB index by 1)
		cellA:SetWall(4, true); -- remove left wall
		cellB:SetWall(2, true) -- remove right wall
		cellA:WallVisual(0, 4); cellB:WallVisual(0, 2); -- for visual purposes
	elseif cellDiffX == -1 then -- (cellB came after cellA because cellA index is less than cellB index by 1)
		cellA:SetWall(2, true); -- remove right wall
		cellB:SetWall(4, true); -- remove left wall
		cellA:WallVisual(0, 2); cellB:WallVisual(0, 4); -- for visual purposes
	end
	local cellDiffY = cellA:GetRow() - cellB:GetRow();
	if cellDiffY == 1 then -- (cellA has greater Y val than cellB)
		cellA:SetWall(1, true); -- remove top wall of cellA
		cellB:SetWall(3, true) -- remove bottom wall of cellB
		cellA:WallVisual(0, 1); cellB:WallVisual(0, 3); -- for visual purposes
	elseif cellDiffY == -1 then -- (cellB has greater Y val than cellA)
		cellA:SetWall(3, true); -- remove bottom wall of cellA
		cellB:SetWall(1, true); -- remove top wall of cellB
		cellA:WallVisual(0, 3); cellB:WallVisual(0, 1); -- for visual purposes
	end
end

function CellDist(cellA, cellB)
	local cellAPosX = cellA:GetWorldPos().x;
	local cellAPosZ = cellA:GetWorldPos().z;
	local cellBPosX = cellB:GetWorldPos().x;
	local cellBPosZ = cellB:GetWorldPos().z;
	return Util:Dist2D(cellAPosX, cellAPosZ, cellBPosX, cellBPosZ);
end

function getCanvasDiagDist()
	return CellDist(grid[1], grid[#grid]);
end

function getCellPairDir(cellA, cellB)
	local aRow = cellA:GetRow(); local bRow = cellB:GetRow();
	local aCol = cellA:GetCol(); local bCol = cellB:GetCol();
	if aRow == bRow then return "Horizontal"; end
	if aCol == bCol then return "Vertical"; end
	error("cannot get cardinal direction of cellA and cellB!");
end

function scanCells(start, en)
	local indx = start;
	local colStart = grid[start]:GetCol();
	local colEnd = grid[en]:GetCol();
	local rowStart = grid[start]:GetRow();
	local rowEnd = grid[en]:GetRow();
	local goodCells = {};
	--print("startCol is ",colStart," and endCol is ",colEnd);
	--determine if all cells adjacent to periphery cells are rocks. A cell is a periphery cell when not all adjacent cells are cells of the same room.
	local function getAllPeripheryCells()
		-- first get all periphery cells
		local peripheryCells = {};
		local i = start;
		local e = en;
		while (i <= e) do
			local v = grid[i]; -- v is the current cell
			local vCellRow = v:GetRow();
			local vCellCol = v:GetCol();
			if not (vCellCol > colEnd or vCellCol < colStart or vCellRow > rowEnd or vCellRow < rowStart) then
				local adjRoomCells = v:GetAdjacentCellsOfSameRoom(grid, goodCells); -- we know that v is now a good cell		
				for a,b in pairs(adjRoomCells) do -- b is the current adjacent cell
					table.insert(peripheryCells, v);
				end					
			else
				-- skip this cell
			end				
			i = i + 1;
		end
		return peripheryCells;
	end
	local function determineIfAllCellsAdjacentPeripheryCellsAreRocksAndAtLeastOneRockCellHasCorridorAdjacentToIt()
		-- mark all periphery cells for testing
		local peripheryCells = getAllPeripheryCells(goodCells);
		local rockPeripheryCells = {};
		for i,v in pairs(peripheryCells) do
			local adjacentCells = v:GetAdjacentCells(grid);
			for j,k in pairs(adjacentCells) do
				if not k:IsRock() or (k:GetColor3() ~= Color3.new(.5,0,1) and k:GetColor3() ~= Color3.new(0,0,0)) then
					-- it is not a rock
					return false;
				else
					table.insert(rockPeripheryCells, k);
					-- it is a rock
				end
			end
		end
		-- also return false if there is no rock cell that has a corridor adjacent to it. 
		for i,v in pairs(rockPeripheryCells) do
			local adj = v:GetAdjacentCells(grid);
			for j,k in pairs(adj) do
				if k:IsCorridor() then -- check to see if this rock's periphery cell from which it came from is a corner or not
					local function isCorner(r,c)
						--[[
							a cell of a room is a corner IF:
							(row,col) = (startRow,startCol) : Top left
							OR
							(row,col) = (EndRow,startCol) : Bottom left
							OR
							(row,col) = (startRow,endCol) : Top right
							OR
							(row,col) = (endRow,endCol) : Bottom right
						--]]
						local topLeft = (r == rowStart and c == colStart);
						local bottomLeft = (r == rowEnd and c == colStart);
						local topRight = (r == rowStart and c == colEnd);
						local bottomRight = (r == rowEnd and c == colEnd);
						return topLeft or bottomLeft or topRight or bottomRight;
					end
					-- get periphery cell from which the rock came from (find an adjacent cell that is in the goodCells array)
					local cellFromWhichRockCameFromArr = v:GetAdjacentCells(grid);
					if cellFromWhichRockCameFromArr == nil then
						error("cellFromWhichRockCameFromArr is nil!");
					end
					-- now use a loop to find the cell from where the rock came from
					local adjElem;
					for f,g in pairs(cellFromWhichRockCameFromArr) do
						if Util:IndexOf(goodCells, g) ~= -1  then
							adjElem = g;
							break;
						end
					end
					local row = adjElem:GetRow();
					local col = adjElem:GetCol();
					if isCorner(row,col) and Util:IndexOf(goodCells, adjElem) ~= -1 then
						-- perform a radial check on adjElem. If it detects a corridor or room, then ignore. Otherwise, return true.
						local radials = adjElem:RadialCheck(grid);
						local violation = false;
						for phi, epsilon in pairs(radials) do
							if not epsilon:IsRock() and Util:IndexOf(goodCells, epsilon) == -1 then -- if the radial cell is not a rock and it is not part of the room
								violation = true
							else -- the radial cell was a rock or it was a part of the room
							end
						end
						if violation == true then return false; end
						return true;	

					else
						return true;	
					end					
				end	
			end
		end
		return false;
	end
	while (indx <= en) do
		local currCell = grid[indx];
		local currCellRow = currCell:GetRow();
		local currCellCol = currCell:GetCol();
		if currCellCol > colEnd or currCellCol < colStart or currCellRow > rowEnd or currCellRow < rowStart then -- skip this one
			-- do nothing
		else -- it is a good cell 
			if not (currCell == nil or not currCell:IsRock() or currCell:GetRegion() ~= nil) then -- it is a good cell
				table.insert(goodCells, currCell);
			else
				return Vector2.new(-1,-1);
			end 
		end
		indx = indx + 1;
	end
	-- now you have a way to distinguish good cells from bad cells
	if not determineIfAllCellsAdjacentPeripheryCellsAreRocksAndAtLeastOneRockCellHasCorridorAdjacentToIt() then
		return Vector2.new(-1,-1);
	end
	return Vector2.new(colEnd - colStart + 1, rowEnd - rowStart + 1);
end

function roomTryPlace()
	for i = 1, roomTries do
		local roomX; local roomY;
		local rng = Random.new():NextNumber(0,4.5);
		if rng <= 2.5 and rng >= 1.5 then
			local thing = Random.new():NextInteger(4,7);
			roomX = thing;
			roomY = thing;
		elseif rng < 1.5 then
			roomX = math.floor(Util:RandBias(.45,12,.8));
			roomY = math.floor(Util:RandBias(.45,12,.8));
		else
			roomX = math.floor(Util:RandBias(3,6,.8));
			roomY = math.floor(Util:RandBias(3,6,.8));
		end
		local spawnX = Random.new():NextInteger(1, numCols);
		local spawnY = Random.new():NextInteger(1, numRows);
		-- try to place. determine if can place or not by scanning cells
		local startIndx = Cell():Index(spawnX, spawnY);
		local endIndx = Cell():Index(spawnX + (roomX-1), spawnY + (roomY-1));
		if startIndx ~= -1 and endIndx ~= -1 and startIndx < endIndx and scanCells(startIndx, endIndx) ~= Vector2.new(-1,-1) then -- also if adjacent tiles are not rocks or same room cells
			-- scan success, can place
			local sizeVector = scanCells(startIndx, endIndx);
			local currRoom = Region(true);
			table.insert(regions, currRoom);
			local indx = startIndx;
			local colStart = grid[startIndx]:GetCol();
			local colEnd = grid[endIndx]:GetCol();
			local rowStart = grid[startIndx]:GetRow();
			local rowEnd = grid[endIndx]:GetRow();
			while (indx <= endIndx) do
				local currCell = grid[indx];
				local currCellRow = currCell:GetRow();
				local currCellCol = currCell:GetCol();
				if currCellCol > colEnd or currCellCol < colStart or currCellRow > rowEnd or currCellRow < rowStart then -- skip this one
				else
					currRoom:AddCell(currCell);
					currCell:SetRegion(currRoom);
				end
				indx = indx + 1;
			end
			-- now turn the rocked rooms into open ones. For one room cell, get its adjacent cells and remove the walls between them.
			local function freeAdjacents(adjacentCell)
				-- base case: if there is no freeable adjacent cell
				if #adjacentCell:GetAdjacentRockedRoomCells(grid) == 0 then
				else
					for i,v in pairs(adjacentCell:GetAdjacentRockedRoomCells(grid)) do
						RemoveWalls(adjacentCell, v);
						freeAdjacents(v);	
					end
				end
			end
			freeAdjacents(grid[startIndx]);
		else
			-- scan failed, cannot place
		end
	end
end

function setup()
	-- fill up grid with Cell objects
	for j = 1, numRows do -- j is row
		for i = 1, numCols do -- i is col
			-- create a Cell object and append it to grid
			local cell = Cell(j, i, (j*numRows) + i); -- row then col
			table.insert(grid, cell);
		end
	end
	for i = 1, #grid do
		grid[i]:Show();
	end
	-- initialize starting cell
	local rng = Random.new():NextInteger(1, #grid);
	currCell = grid[1];
	currCell:SetVisited(true);
	startCell = currCell;
	startCell:Highlight(Color3.new(1,0,0));
end

function generate()
	currCell:SetVisited(true);
	currCell:Highlight(Color3.new(1,1,0));	
	local nxt = currCell:CheckNeighbors(grid); -- nxt is next valid random neighbor
	if nxt ~= nil then -- if the next valid random neighbor exists
		-- STEP 1
		nxt:SetVisited(true); -- mark cell as visited
		nxt:Highlight(Color3.new(0,0,1));
		if nxt:CheckNeighbors(grid) == nil and #stack == stackPeakSize then
			endCell = nxt;
		end
		-- STEP 2
		table.insert(stack, currCell) -- push to stack
		if #stack > stackPeakSize then
			stackPeakSize = #stack;
			largestStack = Util:TableCopy(stack);
		end
		-- STEP 3
		RemoveWalls(currCell, nxt); -- remove walls between currCell and nxt
		-- STEP 4
		currCell = nxt; -- set current cell to next cell
	elseif #stack > 0 then -- if we reached a dead end and there are still cells in the stack
		local removedElem = table.remove(stack, #stack); -- take last cell element off (pop) from stack and stores removed cell element into removedElem
		currCell = removedElem; -- makes the popped cell the current cell
		currCell:Highlight(Color3.new(1,0,1))
		if #stack == 0 then -- if stack is empty
			genDone = true; -- we are done!
		end
	end	
end

function uncarve2(cell)
	local nextDeadEnd = cell:GetNextDeadEnd(grid);
	cell:Rockify();
	corridorsRemaining = corridorsRemaining - 1;
	cell:Highlight(Color3.new(0,0,0));
	table.remove(deadEnds, 1); -- deadEnds[1] should be the rockified cell
	table.insert(deadEnds, nextDeadEnd); -- should be at end of array
end

function sparsen()
	local function countCorridors()
		local count = 0;
		for i,v in pairs(grid) do
			if v:IsCorridor() then
				count = count + 1;
			end
		end
		return count;
	end
	corridorsRemaining = countCorridors();
	-- get all dead ends
	-- call uncarve on each dead end and also call uncarve on the cells before them if those are dead ends too
	local function wrap(n)
		local result = n;
		if n > #grid then
			local excess = n - #grid;
			result = excess;
		end
		return result;
	end
	local genIndx = Random.new():NextInteger(1,#grid);
	for i = 1, #grid, 1 do
		local v = grid[genIndx]; 
		if v:IsDeadEnd(grid) then
			v:Highlight(Color3.new(1,.5,0));
			table.insert(initialDeadEnds, v);
		end
		genIndx = wrap(genIndx + 1);
	end
	deadEnds = Util:TableCopy(initialDeadEnds);
	local pointer = 1;
	while corridorsRemaining > ((numRows*numCols) * ((config.PercentCorridorsToKeep.Value) / 100)) do
		local v;
		if Util:GetFirstExistingElement(deadEnds) == nil then
			break; 
		else
			v = Util:GetFirstExistingElement(deadEnds);
			uncarve2(v); -- uncarve2 adds another dead end to deadEnds arr
		end
	end
end


function invalidateRocks()
	for i = 1, #grid do
		local v = grid[i];
		if v:IsRock() then
			v:Highlight(Color3.new(0,0,0));
		end
	end
end

function freeCorridors()
	local i = 1;
	local corridors = {};
	for a,b in pairs(grid) do
		if b:IsCorridor() then
			table.insert(corridors, b);
		end
	end
	for j,k in pairs(corridors) do
		local adjs = k:GetAdjacentCells(grid);
		for l,m in pairs(adjs) do
			if m:IsCorridor() then
				RemoveWalls(m,k);
			end
		end
	end
end

function markCorridors()
	local function getCorridors(c)
		local result = {};
		local function floodCorridorAdd(cell)
			if cell == nil or cell:IsCorridor() == false or cell:GetRegion() ~= nil or Util:IndexOf(result, cell) ~= -1 then
				return;
			end
			--print("in here");
			table.insert(result, cell);
			floodCorridorAdd(cell:GetNeighboringCell(grid, "TOP"));
			floodCorridorAdd(cell:GetNeighboringCell(grid, "RIGHT"));
			floodCorridorAdd(cell:GetNeighboringCell(grid, "BOTTOM"));
			floodCorridorAdd(cell:GetNeighboringCell(grid, "LEFT"));
		end
		floodCorridorAdd(c);
		return result;
	end
	local i = 1;
	while (i < #grid) do
		local currCell = grid[i];
		if currCell:IsCorridor() and currCell:GetRegion() == nil then
			local floodCorridors = getCorridors(currCell);
			local corridorRegion = Region(false);
			for j,k in pairs(floodCorridors) do
				corridorRegion:AddCell(k);
			end
			table.insert(regions, corridorRegion);
		end
		i = i + 1;
	end
end

function sortRegionsAsc()
	for j = 1, #regions do
		local minElemIndex = j;
		for i = j, #regions do
			local currElem = regions[i];
			if currElem:GetSize() < regions[minElemIndex]:GetSize() then
				minElemIndex = i;
			end
		end
		local temp = regions[j];
		regions[j] = regions[minElemIndex];
		regions[minElemIndex] = temp;
	end
	for a,b in pairs(regions) do
		b:GetPotentialPassageways(grid);
	end
end

function removeIsolatedRegions1()
	local i = 1;
	while (i <= #regions) do
		local v = regions[i];
		if #v:GetPotentialPassageways(grid) == 0 then
			--warn("destroying isolated region");
			local removedRegion = table.remove(regions, i);
			removedRegion:Destroy();
			i = i - 1;
		end
		i = i + 1;
	end
end

function removeIsolatedRegions2() -- this is when the superRegion is initiailized
	local i = 1;
	while (i <= #regions) do
		local v = regions[i];
		if #v:GetPotentialPassageways(grid) == 0 and Util:IndexOf(superRegion:GetRegions(), v) == -1 then -- delete this isolated region if it is not part of the superregion
			--warn("destroying isolated region");
			local removedRegion = table.remove(regions, i);
			removedRegion:Destroy();
			i = i - 1;
		end
		i = i + 1;
	end
end

function tieRegions()
	if superRegion == nil then -- initialize it
		-- pick random region (I picked largest one)
		local rng = Random.new():NextInteger(1,#regions);
		local mainRegion = regions[#regions];
		-- pick a random connector that touches the main region and open it up
		local mainRegionConnectors = mainRegion:GetPotentialPassageways(grid);
		rng = Random.new():NextInteger(1,#mainRegionConnectors);
		local randConnector = table.remove(mainRegionConnectors, rng); -- takes one out and returns the elem taken out
		randConnector:Highlight(Color3.new(0,1,1));
		-- mark this randomly chosen passage as real
		randConnector:SetPassageStatus(1);
		-- get the region this connector connects to
		local otherRegion;
		local top = randConnector:GetNeighboringCell(grid, "TOP");
		local right = randConnector:GetNeighboringCell(grid, "RIGHT");
		local bottom = randConnector:GetNeighboringCell(grid, "BOTTOM");
		local left = randConnector:GetNeighboringCell(grid, "LEFT");
		if top and top:GetRegion() ~= mainRegion and not top:IsRock() then
			otherRegion = top:GetRegion();
		elseif right and right:GetRegion() ~= mainRegion and not right:IsRock() then
			otherRegion = right:GetRegion();
		elseif bottom and bottom:GetRegion() ~= mainRegion and not bottom:IsRock() then
			otherRegion = bottom:GetRegion();
		elseif left and left:GetRegion() ~= mainRegion and not left:IsRock() then
			otherRegion = left:GetRegion();
		else
			--warn("extraneous connector detected")
			randConnector:Highlight(Color3.new(.5,0,1));
			otherRegion = nil;
		end
		-- merge two regions into a superregion
		superRegion = SuperRegion(1);
		superRegion:AddRegion(mainRegion);
		if otherRegion ~= nil then
			superRegion:AddRegion(otherRegion);
		else
		end
	end
	-- now superRegion has been initialized
	--remove extraneous connectors (connectors that connect to this superregion)
	local superRegPassages = superRegion:GetPotentialPassageways(grid);
	while #superRegPassages > 0 do -- while #superRegPassages > 0 ?
		local rng = Random.new():NextInteger(1,#superRegPassages);
		local randConnector = table.remove(superRegPassages, rng);
		randConnector:Highlight(Color3.new(0,1,1));
		-- mark this randomly chosen passage as real
		randConnector:SetPassageStatus(1);
		-- get the region this connector connects to
		local otherRegion;
		local top = randConnector:GetNeighboringCell(grid, "TOP");
		local right = randConnector:GetNeighboringCell(grid, "RIGHT");
		local bottom = randConnector:GetNeighboringCell(grid, "BOTTOM");
		local left = randConnector:GetNeighboringCell(grid, "LEFT");
		if top and Util:IndexOf(superRegion:GetRegions(), top:GetRegion()) == -1 and not top:IsRock() then
			otherRegion = top:GetRegion();
		elseif right and Util:IndexOf(superRegion:GetRegions(), right:GetRegion()) == -1 and not right:IsRock() then
			otherRegion = right:GetRegion();
		elseif bottom and Util:IndexOf(superRegion:GetRegions(), bottom:GetRegion()) == -1 and not bottom:IsRock() then
			otherRegion = bottom:GetRegion();
		elseif left and Util:IndexOf(superRegion:GetRegions(), left:GetRegion()) == -1 and not left:IsRock() then
			otherRegion = left:GetRegion();
		else
			--warn("extraneous connector detected")
			randConnector:SetPassageStatus(-1);
			randConnector:Highlight(Color3.new(1,.5,0));
			otherRegion = nil;
		end
		if otherRegion ~= nil and Util:IndexOf(superRegion:GetRegions(), otherRegion) == -1 then
			superRegion:AddRegion(otherRegion);
		else
		end
		--remove extraneous connectors (connectors that connect to this superregion)
		superRegPassages = superRegion:GetPotentialPassageways(grid);
		--warn("size: "..#superRegPassages);
	end
	--warn("exit loop. superRegion "..superRegion:GetId().." size was "..superRegion:GetSize());
	-- if there are still some regions that are not part of this superRegion, then we have to make more than 1 superregion.
	-- naw, instead, get rid of every region is not part of superRegion and do try place rooms again.
	local i = 1;
	while i <= #regions do
		local v = regions[i];
		if Util:IndexOf(superRegion:GetRegions(), v) == -1 then
			-- destroy this region
			local removedReg = table.remove(regions, i);
			-- visually destroy them
			removedReg:Destroy();
			i = i - 1;
		end
		i = i + 1;
	end
	---- just to make sure all uneeded regions were removed...
	if superRegion:GetSize() ~= #regions then error("Failed superRegion region size comparison! superRegion:GetSize() is "..superRegion:GetSize().." and #regions is "..#regions); end
end

function rngOpenExtraneous() -- one way passages can only be extraneous ones
	local counter = 0;
	local extraneouses = {};
	for i,v in pairs(grid) do
		if v:GetColor3() == Color3.new(1,.5,0) then
			table.insert(extraneouses, v);
		end
	end
	for i,v in pairs(extraneouses) do
		local top = v:GetNeighboringCell(grid, "TOP");
		local right = v:GetNeighboringCell(grid, "RIGHT");
		local bottom = v:GetNeighboringCell(grid, "BOTTOM");
		local left = v:GetNeighboringCell(grid, "LEFT");
		local function checkAdjacentCyanOrOrangeOrPurple()
			if top and (top:GetColor3() == Color3.new(0,1,1) or top:GetColor3() == Color3.new(1,.5,0) or top:GetColor3() == Color3.new(.5,0,1)) then return true; end
			if right and (right:GetColor3() == Color3.new(0,1,1) or right:GetColor3() == Color3.new(1,.5,0) or right:GetColor3() == Color3.new(.5,0,1)) then return true; end
			if bottom and (bottom:GetColor3() == Color3.new(0,1,1) or bottom:GetColor3() == Color3.new(1,.5,0) or bottom:GetColor3() == Color3.new(.5,0,1)) then return true; end
			if left and (left:GetColor3() == Color3.new(0,1,1) or left:GetColor3() == Color3.new(1,.5,0) or left:GetColor3() == Color3.new(.5,0,1)) then return true; end
			return false;
		end

		local rng = Random.new():NextInteger(1,100);
		if rng <= config.PercentExtraPassage.Value and not checkAdjacentCyanOrOrangeOrPurple() then -- adjacents also cannot be cyan
			v:Highlight(Color3.new(.5,0,1));
			counter = counter + 1;
		else
			v:Rockify();
			v:Highlight(Color3.new(0,0,0));
			v:SetPassageStatus(-1);
		end
	end
	--warn(counter.." out of "..#extraneouses.." extra passages placed!");
end

function unwallRockAdjs()
	for i,v in pairs(grid) do
		if v:GetColor3() == Color3.new(0,0,0) then
			v:Highlight(Color3.new(1, 0.976471, 0.85098))
			local adjs = v:GetAdjacentCells(grid);
			for j,k in pairs(adjs) do
				if k:GetColor3() == Color3.new(0,0,0) then
					RemoveWalls(v,k);
				end
			end
		end
	end
end

function markPassages() -- we should also have a two way passage that requires you to activate one side first before you can use both.
	local function getCellPair(passageCell)
		local cellPair = {};
		for i,v in pairs(passageCell:GetAdjacentCells(grid)) do
			if v:GetSuperRegionId() ~= -1 then
				table.insert(cellPair, v);
			end
		end
		--warn(passageCell:GetRow()..", "..passageCell:GetCol());
		if #cellPair == 0 then error("getCellPair does properly return cell pair!"); end
		return cellPair;
	end
	for i,v in pairs(grid) do
		if v:GetColor3() == Color3.new(0,1,1) or v:GetColor3() == Color3.new(.5,0,1) then
			local rng = Random.new():NextInteger(1,100);
			if v:GetColor3() == Color3.new(.5,0,1) then -- make the passage a random one way one
				-- determine direction of passage (vertical or horizontal)
				local cellPair = getCellPair(v);
				local k = cellPair[1];
				local dir = getCellPairDir(k, v);
				if dir == "Horizontal" then
					v:SetPassageDirection("Horizontal");
					if rng >= 50 then
						v:SetPassageType("LeftPassage");
						v:SetDecal(DecalLib.Decals["LeftArrow"]);
					else
						v:SetPassageType("RightPassage");
						v:SetDecal(DecalLib.Decals["RightArrow"]);
					end
				else -- must be vertical
					v:SetPassageDirection("Vertical");
					if rng >= 50 then
						v:SetPassageType("UpPassage");
						v:SetDecal(DecalLib.Decals["UpArrow"]);
					else
						v:SetPassageType("DownPassage");
						v:SetDecal(DecalLib.Decals["DownArrow"]);
					end
				end
			else -- it is a critical passage
				local rng2 = Random.new():NextInteger(1,100);
				local cellPair = getCellPair(v);
				local k = cellPair[1];
				local dir = getCellPairDir(k, v);
				if dir == "Horizontal" then 
					v:SetPassageDirection("Horizontal");
					if rng2 < config.PercentPassageChance.Value then -- insert passage icon
						v:SetPassageType("LeftRightPassage");
						v:SetDecal(DecalLib.Decals["LeftRightArrow"]);
					else -- insert door icon
						v:SetPassageType("Door")
						v:SetDecal(DecalLib.Decals["Door"]);
					end
				else -- must be vertical
					v:SetPassageDirection("Vertical");
					if rng2 < config.PercentPassageChance.Value then -- insert passage icon
						v:SetPassageType("UpDownPassage");
						v:SetDecal(DecalLib.Decals["UpDownArrow"]);
					else -- insert door icon
						v:SetPassageType("Door");
						v:SetDecal(DecalLib.Decals["Door"]);
					end
				end
			end
			v:SetPassageStatus(1);
			v:MarkWalls(particleEffetcs.Debug.WallMarker);
		end
	end
end

function reduceCriticalPassages() -- by turning them into a superregion cell
	for i,v in pairs(grid) do
		if v:GetColor3() == Color3.new(0,1,1) then
			local rng = Random.new():NextNumber(0,99);
			if rng <= config.PercentPassageRemove.Value then
				-- turn it into superregion cell
				-- by first turning it into a region
				v:SetPassageStatus(-1);
				local reg = Region(false);
				reg:AddCell(v);
				superRegion:AddRegion(reg);
				table.insert(regions, reg);
			else 
				-- leave them be
			end
		end
	end
	-- do a flood fill remove walls thing
	for i,v in pairs(grid) do
		if v:GetSuperRegionId() == superRegion:GetId() then
			for j,k in pairs(v:GetAdjacentCells(grid)) do
				if k:GetSuperRegionId() == v:GetSuperRegionId() and k:GetSuperRegionId() ~= -1 then
					RemoveWalls(v,k);
				end
			end
		end
	end
end

function markPotentialStaircases()
	local potentialStaircases = {};
	local function isPeripheryRockCell(v)
		local adj = v:GetAdjacentCells(grid);
		local adjContainPassage = false;
		local counter = 0;
		for i,v in pairs(adj) do
			if v:GetSuperRegionId() ~= -1  then
				counter = counter + 1;
			end
			if v:GetPassageType() ~= nil then
				adjContainPassage = true;
			end
		end
		return counter == 1 and not adjContainPassage;
	end
	for i,v in pairs(grid) do
		if v:GetColor3() == Color3.new(0,0,0) and isPeripheryRockCell(v) then		
			table.insert(potentialStaircases, v);
		end
	end
	local rng = Random.new():NextInteger(1,#potentialStaircases);
	local startStaircase = table.remove(potentialStaircases, rng);
	startStaircase:Highlight(Color3.new(0,1,0));
	startStaircase:SetStairStatus(0);
	startStaircase:SetDecal(DecalLib.Decals['DownStairs']);
	-- now choose an exit passage by eliminating passages in potentialStaircases that have a distance longer than a certain number from the start staircase.
	local i = 1;
	local furthestCell = nil;
	local furthestDistance = 0;
	for i,v in pairs(potentialStaircases) do
		local currDist = CellDist(startStaircase, v);
		if currDist > furthestDistance then
			furthestCell = v;
			furthestDistance = currDist;
		end
	end
	local endStaircase = furthestCell;
	endStaircase:Highlight(Color3.new(1,0,0));
	endStaircase:SetStairStatus(1);
	endStaircase:SetDecal(DecalLib.Decals['UpStairs']);
end

function dungeon()
	setup();
	Util:Sleep(.5, not config.FastGen.Value);
	while not genDone do
		generate();	
	end
	Util:Sleep(.5, not config.FastGen.Value);
	sparsen();
	Util:Sleep(.5, not config.FastGen.Value);
	invalidateRocks();
	Util:Sleep(.5, not config.FastGen.Value);
	wallCheck();
	Util:Sleep(.5, not config.FastGen.Value);
	roomTryPlace();
	Util:Sleep(.5, not config.FastGen.Value);
	freeCorridors()
	Util:Sleep(.5, not config.FastGen.Value);
	markCorridors();
	Util:Sleep(.5, not config.FastGen.Value);
	sortRegionsAsc();
	Util:Sleep(.5, not config.FastGen.Value);
	removeIsolatedRegions1();
	Util:Sleep(.5, not config.FastGen.Value);
	tieRegions();
	Util:Sleep(.5, not config.FastGen.Value);
	roomTryPlace();
	Util:Sleep(.5, not config.FastGen.Value);
	sortRegionsAsc();
	Util:Sleep(.5, not config.FastGen.Value);
	removeIsolatedRegions2();
	Util:Sleep(.5, not config.FastGen.Value);
	tieRegions();
	Util:Sleep(.5, not config.FastGen.Value);
	rngOpenExtraneous();
	Util:Sleep(.5, not config.FastGen.Value);
	Util:Sleep(.5, not config.FastGen.Value);
	reduceCriticalPassages()
	Util:Sleep(.5, not config.FastGen.Value);
	markPassages();
	Util:Sleep(.5, not config.FastGen.Value);
	markPotentialStaircases();
	unwallRockAdjs();
	print("gen done")
	Util:Sleep(2, not config.FastGen.Value);
end

local dungDone = true;
local rept = config.StressTest.Value;

function stressTest()
	while wait(1) do
		if dungDone == true then
			dungDone = false;
			grid = {};
			currCell = nil;
			stack = {};
			genDone = false;
			endCell = nil; startCell = nil;
			stackPeakSize = 0;
			largestStack = nil;
			corridorsRemoved = nil;
			initialDeadEnds = {};
			deadEnds = {};
			regions = {};
			superRegion = nil;
			dungeon();
			if not rept then break; end
			repeat wait(.25) until dungDone;
			clearCellDrawings();
		end
	end
end

--[[   Key events   --]]
remoteEvents.DunGen.OnServerEvent:Connect(function(plr)
	dungDone = true;
end)
stressTest();