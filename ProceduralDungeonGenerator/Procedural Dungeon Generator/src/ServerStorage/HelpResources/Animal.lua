--THIS IS AN OOP EXAMPLE USING RXI'S MODULE.
--helpful video: https://www.youtube.com/watch?v=UHACUEOepZQ
--documentation: https://github.com/rxi/classic

local GameObject = require(game.ReplicatedStorage.GameObject);

local Animal = GameObject:extend();

function Animal:new(name, size, species)--constructor
	self.name = name or "Unknown";--or is default thing if name does not exist
	self.size = size or "Unknown";
	self.species = species or "Unknown";
end

function Animal:print()
	print("Name: "..self.name.."\nSize: "..self.size.."\nSpecies: "..self.species);
end

function Animal:getName()
	return self.name;
end

function Animal:getSize()
	return self.size;
end

function Animal:getSpecies()
	return self.species;
end

function Animal:isDoge()
	if (self.species == "Doge") then
		return true;
	end
	return false;
end

return Animal;