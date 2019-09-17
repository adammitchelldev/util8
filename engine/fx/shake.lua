local _shakedir, _shake = 0,0

--screen shake intensity to x
local function shake(x)
	if(x>_shake) _shake = x
end

--update shake
local function shake_update()
	if _shake>0 then
	 _shake-=1
	end
end

--get shake vector
local function shake_get()
	if _shake > 0 then
		local i = flr(rnd(4)) --random cardinal direction
		if(i==_shakedir) i=(i+2)%4 --if same direction is repeated, mirror
		_shakedir = i

		--cardinal angle to vector
		local dx,dy = _shake*(i%2),_shake*((i+1)%2)
		if(i>1) dx,dy=-dx,-dy

		--translate camera
		return dx, dy
	else
		return 0, 0
	end
end

--calculate and apply shake to camera
local function shake_camera(camx,camy)
	cdx,cdy=shake_get()
	acamx=camx+cdx
	acamy=camy-0x10+cdy
	camera(acamx,acamy)
	return acamx,acamy
end
