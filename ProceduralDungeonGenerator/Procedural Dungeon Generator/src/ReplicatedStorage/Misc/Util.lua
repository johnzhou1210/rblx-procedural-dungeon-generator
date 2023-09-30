local Util = {}

function Util:Dist2D(x1, y1, x2, y2)
	return math.sqrt(math.pow(x1 - x2, 2) + math.pow(y1 - y2, 2));
end

function Util:TableCopy(arr)
	local result = {};
	for i,v in pairs(arr) do
		table.insert(result, v);
	end
	return result;
end

function Util:IndexOf(arr, elem)
	for i,v in pairs(arr) do
		if v == elem then
			return i;
		end
	end
	return -1;
end

function Util:RandBias(low, high, bias) -- higher bias favors low number and vice versa where 1 is neutral
	local rng = Random.new():NextNumber(0,1);
	rng = math.pow(rng, bias);
	return low + (high - low) * rng;
end

function Util:GetFirstExistingElement(arr)
	for i,v in pairs(arr) do
		if arr[i] then
			return v;
		end
	end
	return nil;
end

function Util:RgbTo255(color3)
	return math.floor(color3.R * 255)..","..math.floor(color3.G * 255)..","..math.floor(color3.B * 255);
end

function Util:Sleep(seconds, bool)
	if bool then
		wait(seconds);
	end
end

return Util;
