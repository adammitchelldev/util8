local function update(layer)
	for o in all(layer) do
		if(o.update) o:update()
	end
end

local function draw(layer)
	for o in all(layer) do
		if(o.draw) o:draw()
	end
end
