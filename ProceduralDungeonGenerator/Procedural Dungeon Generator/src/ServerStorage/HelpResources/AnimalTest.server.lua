local Animal = require(game.ReplicatedStorage.Animal);

local animalA = Animal("Caesar", "Chonk", "Doge");--dont do Animal.new(params) here!

animalA:print();
print(animalA:isDoge());