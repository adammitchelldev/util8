local _delay=0

--add x frames of delay
local function delay(x)
	--if(x>_delay) _delay = x
	_delay += x
end

--update delay counter
--returns true if no delay
local function delay_update()
	if _delay>0 then
		_delay-=1
	else
		return true
	end
end
