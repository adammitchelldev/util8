--level
--this spawnlist gets populated
--later
local spawnlist = {}
local function spawn(c,x,y)
	--look into the spawnlist
 local f=spawnlist[c]
 --if we found something
 --then it's our spawn function
	if f then
		local o=f() --call it!
		if o then
			o.x,o.y = x,y --set the pos
			o.respawn={
				x=x,
				y=y
			}
		end
		return o --return it
	end
end

--temp, should decode
--[[
local function loadlevel(n)
	local lx=((n%8)*16)
	local ly=flr(n/8)*16
	for x=0,16 do
		for y=0,14 do
			local c=mget(lx+x,ly+y)
			if spawn(c,x,y) then
				mset(x,y,0)
			else
				mset(x,y,c)
			end
		end
	end
end
]]
