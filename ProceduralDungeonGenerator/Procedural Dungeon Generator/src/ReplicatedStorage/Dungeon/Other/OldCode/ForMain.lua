--[[

function uncarve(cell, times) -- uncarve means adding walls, carve means removing walls. It stops uncarving when the next cell is not a dead end.
	wait()
	-- base case
	if (cell == nil or cell:IsDeadEnd() == false) then -- stop when the cell is no longer a dead end
		--print(cell,cell:IsDeadEnd())
		--print("in base case")
	else
		local nextCell = cell:GetNextDeadEnd(grid);
		if not (nextCell == nil or nextCell:IsDeadEnd() == false or corridorsRemoved >= math.floor(corridorsToRemove / #initialDeadEnds)) then -- if the next cell is not the base case
			cell:Highlight(Color3.new(0.3,0.3,0.3));

		else
			cell:Highlight(Color3.new(1,1,1)); -- means that the next cell will be the base case

		end
		cell:Rockify();
		corridorsRemaining = corridorsRemaining - 1;
		--print("calling carve of next cell")
		uncarve(nextCell);
	end
end

--]]

