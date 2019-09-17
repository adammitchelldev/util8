--hex debugging
local _hex_lut = {"1","2","3","4",
		"5","6","7","8","9","a","b",
		"c","d","e","f",[0]="0"}

local function hexdig(num,pos)
	return _hex_lut[band(shr(num,pos),0xf)]
end

local function hexint(num)
	return hexdig(num,12)..hexdig(num,8)..hexdig(num,4)..hexdig(num,0)
end

local function hexdec(num)
	return hexint(shl(num,16))
end

local function hex(num)
	--return _hex_lut[band(shr(num,12),0xf)].._hex_lut[band(shr(num,8),0xf)].._hex_lut[band(shr(num,4),0xf)].._hex_lut[band(shr(num,0),0xf)].."."..hexlut[band(shl(num,4),0xf)]..hexlut[band(shl(num,8),0xf)]..hexlut[band(shl(num,12),0xf)]..hexlut[band(shl(num,16),0xf)]
	return hexint(num).."."..hexdec(num)
end
