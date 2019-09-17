local _light = 0

--flash light to x
local function light(x)
	if(x>_light) _light = x
end

--update light
local function light_update()
	if _light>0 then
	 _light-=1
	end
end

--setup palette
local function light_pal()
	if _light > 0 then
		local i = (flr(_light+0.5)-1) * 0x0100
		if(i>0x0100) i = 0x0100
		memcpy(0x5f10,0x0e38+i,4)
		memcpy(0x5f14,0x0e78+i,4)
		memcpy(0x5f18,0x0eb8+i,4)
		memcpy(0x5f1c,0x0ef8+i,4)
	else
		pal()
	end
end
