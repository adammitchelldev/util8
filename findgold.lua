--api
local level=0
local levelh=0
local layers = {}
local gravity = 0x0.04
local _delay = 0
local _light = 0
local _shakedir, _shake = 0,0

--game stuff
local player
local players,pickups,bullets,enemies,texts
local bags,triggers
local truck={}
local home={}

deaths=0

local splash=true

local tutorial=0

local number_of_bags=0

local camx=0
local camy=0
local camtx=0
local camty=0

local truckx=1
local trucky=0

local current_level
local level_number
local last_level

local goal_bags=17

local level_data={
	{
		index=2,
		height=1,
		first_bag=1
	},
	{
		index=3,
		height=2,
		first_bag=2
	},
	{
		index=5,
		height=3,
		first_bag=6
	},
	{
		index=10,
		height=4,
		first_bag=11
	},
	{
		index=3,
		height=2,
		first_bag=6
	},
	{
		index=3,
		height=2,
		first_bag=6
	}
}

local function t_home_update(home)
	home_update(home)
end

local function t_home_enter(home)
	home_enter(home)
end

local function t_home_exit(home)
	home_exit(home)
end

level_data.home={
	index=0,
	height=1,
	first_bag=0,
	update=t_home_update,
	enter=t_home_enter,
	exit=t_home_exit
}

function t_world_enter(world)
	world_enter(world)
end

level_data.world={
	index=1,
	height=1,
	first_bag=0,
	enter=t_world_enter
}

--positional sfx
local function psfx(id,x,y)
	local sx=x*8
	local sy=y*8
	if sx>=camx
			and sx<=camx+128
			and sy>=camy
			and sy<=camy+96 then
		sfx(id)
	end
end

--make and return a new layer
local function new_layer()
  local layer = {}
  add(layers,layer)
  return layer
end

--add an object to a layer
local function create(obj,layer)
  obj.layer = layer
  add(layer,obj)
end

--remove an object from its layer
local function destroy(obj)
	del(obj.layer,obj)
end

--add x frames of delay
local function delay(x)
	--if(x>_delay) _delay = x
	_delay += x
end

--flash ligh to x
local function light(x)
	if(x>_light) _light = x
end

--screen shake intensity to x
local function shake(x)
	if(x>_shake) _shake = x
end

--hex debugging
hexlut = {"1","2","3","4",
		"5","6","7","8","9","a","b",
		"c","d","e","f",[0]="0"}
local function hex(num)
	return hexlut[band(shr(num,12),0xf)]..hexlut[band(shr(num,8),0xf)]..hexlut[band(shr(num,4),0xf)]..hexlut[band(num,0xf)].."."..hexlut[band(shl(num,4),0xf)]..hexlut[band(shl(num,8),0xf)]..hexlut[band(shl(num,12),0xf)]..hexlut[band(shl(num,16),0xf)]
end

--director api
local _active_scenes={}

local function scene_update()
  for scene in all(_active_scenes) do
  	assert(coresume(scene))
  end
end

--begin the scene and start it this frame
local function begin_scene(script)
  local scene
  scene=cocreate(function()
    script()
    del(_active_scenes,scene)
  end)
  add(_active_scenes,scene)
  assert(coresume(scene))
end

--run scripts simultaneously
local function multitask(scripts)
 local tasks={}
 for script in all(scripts) do
   add(tasks,cocreate(script))
 end
 repeat
		local complete = true
		for task in all(tasks) do
			if coresume(task) then
			 complete = false
			end
		end
  if complete then
    return
  else
    yield()
  end
	until false
end

--collision
local r_mget=mget
function mget(x,y)
	if(x<0) return 1
	if(y<0) return 1
	local r=flr(y/12)
	local ly=((level+r)%5)*12
	local lx=flr((level+r)/5)*16
	return r_mget(x+lx,(y%12)+ly)
end

--helper function for switching axis
local function mgety(x,y)
	return mget(y,x)
end

local function collide(
		x,y,l,r,u,d,v,m)
	local tu = flr(y+u)
	local td = y+d
	local hit=0

	if v < 0 then --left
		local tl = flr(x+l)
		while tu < td do
		 --spr(3,tl*8,i*8)
			local spriten=m(tl, tu)
			hit=bor(fget(spriten),hit)
			tu += 1
		end
		if band(hit,0x1)!=0 then
			x = tl + 1 - l
		end
	elseif v > 0 then --right
  local tr = x+r
  local trf = flr(tr)
  if trf ~= tr then
   tr = trf
  else
   tr = trf - 1
  end
		while tu < td do
			--spr(3,tr*8,i*8)
			local spriten=m(tr, tu)
			hit=bor(fget(spriten),hit)
   tu += 1
		end
		if band(hit,0x1)!=0 then
			x = tr - r -- 0x0.2
		end
	end

	return hit,x
end

local function movex(o,v)
  v=v or o.vel.x
  o.x+=v
  local c=o.coll
  return collide(
			o.x,o.y,c.l,c.r,c.u,c.d,
			v,mget)
end

local function movey(o,v)
  v=v or o.vel.y
  o.y+=v
  local c=o.coll
  return collide(
			o.y,o.x,c.u,c.d,c.l,c.r,
			v,mgety)
end

local function physics(o)
  local v=o.vel
  v.ox=x
  if o.gravity then
    v.y+=gravity
    --x axis friction
  end
  if o.grounded then
  	if o.frict then
   	v.x*=o.frict
   	if(abs(v.x)<0x0.04) v.x=0
   end
  elseif o.airfrict then
  	v.x*=o.airfrict
  	if(abs(v.x)<0x0.04) v.x=0
  end
  if o.coll then
    if (v.x<-0x0.8) v.y=-0x0.8
    if (v.x>0x0.8) v.y=0x0.8
    if (v.y<-0x0.8) v.y=-0x0.8
    if (v.y>0x0.8) v.y=0x0.8
    local hitx,hity

    --when holding, have to
    --check old body for
    --hurt independently
    if o.hurt and o.holding then
    	local temp=o.coll
    	local ox=o.x
    	o.coll=o.old_coll
    	hitx=movex(o)
    	o.x=ox
    	o.coll=temp
    	if band(hitx,0x4)!=0 then
    		o:hurt()
    	end
    end

    hitx,o.x=movex(o)
    o.walled=(band(hitx,0x1)!=0)
    if o.walled then
     v.x=0
    end
    if (not o.holding) then
     if o.kill and band(hitx,0x10)!=0 then
    		o:kill()
    	elseif o.hurt and band(hitx,0x4)!=0 then
    		o:hurt()
    	end
    end
   	if band(hitx,0x8)!=0 then
    	v.x*=0x0.8
    end
    hity,o.y=movey(o)
    local ovy = v.y
    if band(hity,0x1)!=0 then
    	--bounce?
    	if v.y>0 and band(hity,0x2)==0x2 then
    		v.y=-0x0.5d
    		hity=nil
    		psfx(9,o.x,o.y)
    	else
     	if o.dropsfx
     			and not o.grounded
     			and v.y>0x0.2 then
     		psfx(o.dropsfx,o.x,o.y)
     		if(o.heavy) shake(flr(v.y*4))
     	end
     	v.y=0
     end
    end
				if (not o.holding) or ovy>0 then
   		if o.kill and band(hity,0x10)!=0 then
    		o:kill()
    	elseif o.hurt and band(hity,0x4)!=0 then
    		o:hurt()
    	end
   	end
    o.grounded=(band(hity,0x1)!=0)
    if band(hity,0x8)!=0 then
    	v.y*=0x0.8
    	o.grounded=true
    end
    o.standing=nil
  else
   o.x+=v.x
   o.y+=v.y
  end
end

local function aabb_intersect(o1,o2)
	if o1.coll and o2.coll then
		local c1,c2=o1.coll,o2.coll
		return not(o1.x+c1.l>o2.x+c2.r
				or o1.x+c1.r<o2.x+c2.l
				or o1.y+c1.u>o2.y+c2.d
				or o1.y+c1.d<o2.y+c2.u)
	end
end

local function for_collisions(l1,l2,f)
	for o1 in all(l1) do
		for o2 in all(l2) do
			if aabb_intersect(o1,o2) then
				f(o1,o2)
			end
		end
	end
end

--level
--this spawnlist gets populated
--later
spawnlist = {}
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

local function contains(list,item)
	for oth in all(list) do
		if oth.uid==item.uid and
				oth.level_owner==item.level_owner then
			return true
		end
	end
end

local level_gold=0
local wx=0
local wy=0

local dbg=false

local function loadlevel(l)
	--before loading the next level
	--allow the current level
	--to do exit logic
	if current_level then
		if current_level.exit then
			dbg=true
			current_level:exit()
		end
	end

	layers={}
	texts=new_layer()
 enemies=new_layer()
	pickups=new_layer()
	triggers=new_layer()
	bags=new_layer()
 players=new_layer()
	bullets=new_layer()



	current_level=l
	level=l.index
	levelh=l.height
	level_gold=l.first_bag
	spawn_id=0
	--for every "room"
	for r=0,levelh-1 do
		local ly=((level+r)%5)*12
 	local lx=flr((level+r)/5)*16

		--every cell in that room
		for y=0,11 do
			for x=0,15 do
				--get the sprite number
				--of the cell
				local c=r_mget(x+lx,y+ly)
				--spawn that sprite!
				local obj=spawn(c,x,y+(r*12))
				if obj then
					obj.uid=spawn_id
					obj.level_owner=current_level
					spawn_id+=1

					if contains(truck,obj) or
							contains(home,obj) then
						destroy(obj)
					end
				end
				--optionally delete the cell
				--(i just mask it right now)
			end
		end
	end

	if current_level.enter then
		current_level:enter()
	elseif tutorial!=0 then
		level_enter()
	end
end

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

local function sprite_draw(obj)
	local s = obj.sprite
 if not s.hide then
 	spr(s.n,
 			(obj.x*8)+0x0.8,
 			(obj.y*8)+0x0.8,
 			s.w or 1,s.h or 1,s.fx,s.fy)
 end
 if	obj.gold_id then
 	color(9)
  print(obj.gold_id,
  (obj.x*8)+0x3.8,
  (obj.y*8)+0x2.8)
	end
end
--api end


-->8
--player
local function player_throw(obj)
	local item=obj.holding
	obj.holding=nil
	create(item,item.layer)
	item.vel.x=obj.vel.x
	if obj.sprite.fx then
		item.vel.x-=0x0.1
	else
		item.vel.x+=0x0.1
	end
	item.vel.y=-0x0.44
	obj.held5=true
	obj.coll=obj.old_coll
	item.notthrown=nil
end

local function player_hold(obj,bag)
	obj.holding=bag
	destroy(bag) --don't process
	obj.old_coll=obj.coll
	obj.coll={
		u=obj.old_coll.u+bag.coll.u-bag.coll.d,
		d=obj.old_coll.d,
		l=obj.old_coll.l,
		r=obj.old_coll.r
	}
	--it only changes the u
	--but in a future ver, it
	--could change more
	obj.held5=true

	if bag.gold_id==1 and tutorial==0 then
		tutorial=1
		create_exit_trigger()
		destroy(tutorial_text)
		tutorial_text=text_box("take gold home",30,8)
	end
end

local function player_input(obj)
	local vel = obj.vel
	if btn(o) then
		vel.x -= 0x0.08--0x0.0c
		obj.sprite.fx = true
	elseif btn(1) then
		vel.x += 0x0.08--0x0.0c
		obj.sprite.fx = false
	end

	--jump
	if btn(2) or btn(4) then
		if (not obj.jump)
				and obj.grounded then
			vel.y = -0x0.44
			obj.jump = true
      sfx(3)
		end
	else
		if obj.jump and vel.y > -0x0.34 then
 		obj.jump = false
 		if(vel.y<0) vel.y = 0
 	end
	end

	if btn(3) and vel.y<-0x0.30 then
		obj.jump = false
		vel.y = -0x0.30
	end

	--run ani
 if obj.grounded then
   obj.sprite.n+=abs(obj.oldx-flr(obj.x*8))/4
   if(obj.sprite.n>=69) obj.sprite.n-=4
 end
 obj.oldx=flr(obj.x*8)

	--pickup bags
	--look for nearest bag
	--remove it from bags list and
	--hold it in the player
	if btn(5) then
		if not obj.held5 then
			if not obj.holding then
				local grabbox={
					x=obj.x,
					y=obj.y,
   		coll={
   			u=0x0.2,
   			d=0x1.6,
   			l=0x0.2,
   			r=0x0.e
   		}
   	}
   	local hity=obj.y+obj.coll.u
   	local hitx=obj.x+((obj.coll.l+obj.coll.r)/2)
   	local hitxl=obj.x+obj.coll.l
   	local hitxr=obj.x+obj.coll.r
  		local fail=false
  		for bag in all(bags) do
  			if aabb_intersect(grabbox,bag) then
  				local topy=hity+bag.coll.u-bag.coll.d
  				if not fget(mget(hitx,topy),0) then
   				player_hold(obj,bag)
   				fail=false
   				break
   			else
   				local boty=flr(topy+1)-bag.coll.u+bag.coll.d-obj.coll.u+obj.coll.d
   				--number_of_bags=hitxr--debug
   				if not fget(mget(hitxl,boty),0) and not fget(mget(hitxr,boty),0) then
   					obj.y=boty-obj.coll.d
   					player_hold(obj,bag)
   					fail=false
   					break
   				else
   					fail=true
   				end
   			end
  			end
  		end
  		--if(fail) sfx(11)
  	else
  		--throw
  		player_throw(obj)
  	end
  end
 else
 	obj.held5=nil
 end

	if obj.holding then
		obj.holding.x=obj.x
		obj.holding.y=obj.y+obj.old_coll.u-obj.holding.coll.d
	end
end


local function player_draw(obj)
	if obj.holding then
		sprite_draw(obj.holding)
	end
	sprite_draw(obj)
end

local function pdeath_update(obj)
  physics(obj)
  delay(2)
  if obj.y>14 then
    run()
  end
end

local function iframes(obj)
  if obj.iframes > 0 then
    obj.iframes-=1
    obj.sprite.hide=(obj.iframes%4)>1
  else
    obj.sprite.hide=nil
  end
end

local function player_update(obj)
	if obj.stun>0 then
		obj.stun-=1
	elseif obj.input then
		obj:input()--remove input for dummy char
	end
	physics(obj)
 iframes(obj)
end

local function new_player()
	local player={
  gravity=true,
  frict=0x0.c,
  airfrict=0x0.c,
		x=5,y=4,
		vel={
			x=0,y=0
		},
		coll={
			l=0x0.4,
			r=0x0.c,
			u=0x0.4,
			d=0x1.0
		},
		sprite={
			n=64,
			fx=false,
			fy=false,
		},
		gun={
      wait=0,
      speed=16
    },
  health=3,
  iframes=0,
  stun=0,
  dropsfx=8,
		update=player_update,
		input=player_input,
		draw=player_draw,
		hurt=player_hit,
		kill=player_kill
	}
	create(player,players)
	return player
end

local new_bag

local function make_into_bag(obj)
	destroy(obj)
 --local bag=new_bag()
 local temp=1-obj.coll.d
 obj.coll.d=1-obj.coll.u
 obj.coll.u=temp
 obj.sprite.n+=32
 obj.sprite.hide=nil
 obj.dropsfx=8
 obj.frict=0x0.e
 obj.airfrict=nil
 obj.update=physics
 obj.draw=sprite_draw
 obj.hurt=nil
 obj.kill=kill_corpse
 obj.notthrown=true
 create(obj,bags)
end

function player_die(obj)
 --obj.update=pdeath_update
 --obj.update=nil
 --obj.coll=nil
 obj.sprite.fy=true
 --music(-1,50)
 sfx(4)
 shake(6)
 light(1)
 delay(5)
 deaths+=1

 make_into_bag(obj)

 --begin_scene(death_box)
 begin_scene(delay_spawn_player)
 --player=new_player()


end

function player_hit(player,enemy,amount,kill)
 if (player.iframes>0) return
 if enemy then
  player.vel.x=(player.x-enemy.x)*(rnd(0x0.2)+0x0.3)
 end
 player.vel.y=-rnd(0x0.2)-0x0.1
 player.jump=true
 player.stun=15

	if kill then
		player.health=0
	else
		--hack fix
 	player.health-=1
 end

 if player.holding then
 	player_throw(player)
 end

 if player.health<=0 then
  player_die(player)
 else
  player.iframes=60
  sfx(5)
 end
end

function player_kill()
	player_hit(player,nil,nil,true)
	delay_destroy(player,60)
end

function truck_drive(p)
	p.vel.x=0
	p.vel.y=0
	if btn(0) then
		p.sprite.fx=false
		p.vel.x-=0x0.1
	end
	if btn(1) then
		p.sprite.fx=true
		p.vel.x+=0x0.1
	end
	if(btn(2)) p.vel.y-=0x0.1
	if(btn(3)) p.vel.y+=0x0.1
	physics(p)
end
-->8
--other
--enemies
local function edeath_update(obj)
  physics(obj)
  if obj.y>14 then
    destroy(obj)
  end
end

local function enemy_die(obj,vel)
 if vel then
 	obj.vel.x=vel.x*(rnd(0x0.2)+0x0.3)
 end
 obj.vel.y=-rnd(0x0.2)-0x0.1
 --obj.update=edeath_update
 --obj.coll=nil
 obj.sprite.fy=true
 delay(3)
 psfx(2,obj.x,obj.y)

 make_into_bag(obj)
end

local function enemy_update(obj)
 if obj.sprite.fx then
  obj.vel.x-=obj.speed
 else
  obj.vel.x+=obj.speed
 end
	physics(obj)
 if obj.walled then
   obj.sprite.fx = not obj.sprite.fx
	end
end

function enemy_kill(enemy)
	enemy_die(enemy)
	delay_destroy(enemy,60)
end

local function new_enemy()
	local enemy={
  gravity=true,
  speed=0x0.08,
  frict=0x0.c,
  airfrict=0x0.c,
  --speed=0x0.10,
		vel={
			x=0,
			y=0
		},
		coll={
			l=0x0.2,
			r=0x0.e,
			u=0x0.4,
			d=0x1.0
		},
		sprite={
			n=69
		},
		update=enemy_update,
		draw=sprite_draw,
		hurt=enemy_die,
		kill=enemy_kill
	}
	create(enemy,enemies)
	return enemy
end

spawnlist[69] = new_enemy

--bullet
local function bimpact_update(obj)
	if obj.flash > 0 then
		obj.flash -= 1
	else
		destroy(obj)
	end
end

--[[
local function bullet_impact(obj)
  sfx(0)
  --delay(1)
  --light(0)
  shake(1)
  obj.update = bimpact_update
  obj.flash = 2
  obj.sprite.n = 81
end
]]

local function bullet_update(obj)
	physics(obj)
	if obj.walled then
    bullet_impact(obj)
  end
end

local function bflash_update(obj)
	if obj.flash > 0 then
		obj.flash -= 1
	else
		obj.sprite.n = 80
		obj.update = bullet_update
	end
end

function new_bullet()
  local bullet = {
    coll = {
    	l = 0x0.6,--0x0.2
    	r = 0x0.a,--0x0.e
    	u = 0x0.6,--0x0.6
    	d = 0x0.a --0x0.a
    },
    sprite = {
    	n = 81,
    	w = 1,
    	h = 1
    },
    flash = 2,
    draw = sprite_draw,
    update = bflash_update
  }
  create(bullet,bullets)
  return bullet
end

--crate
local function pickup_text(obj,text)
  begin_scene(rising_box(text,(obj.x*8)+4,(obj.y*8)-2))
end

local function crate_picked_up(crate,player)
	if(player.gun.speed>0) player.gun.speed-=2
  pickup_text(crate,"+1 gun")
end

local function health_picked_up(crate,player)
	player.health+=1
  pickup_text(crate,"+1 h")
end

local function new_pickup(sprite_n,picked_up)
	local crate={
		coll={
			l=0x0.2,
			r=0x0.e,
			u=0x0.4,
			d=0x1.0
		},
		sprite={
			n=sprite_n
		},
		draw=sprite_draw,
		picked_up=picked_up
	}
	create(crate,pickups)
	return crate
end

local function new_gun_crate()
  return new_pickup(70,crate_picked_up)
end
spawnlist[70] = new_gun_crate

local function new_health_crate()
  return new_pickup(70,health_picked_up)
end
spawnlist[71] = new_health_crate

function kill_bag(bag)
	if not bag.respawning then
		psfx(10,bag.x,bag.y)
		delay_respawn(bag,32)
	end
end

function kill_corpse(bag)
	delay_destroy(bag,20)
end

function kill_box(bag)
	delay_respawn(bag,20)
end

function new_bag()
	local bag = {
			vel={
				x=0,
				y=0
			},
   coll={
 			l=0x0.2,
 			r=0x0.e,
 			u=0x0.0,
 			d=0x1.0
 		},
   sprite = {
   	n = 72,
   	w = 1,
   	h = 1
   },
   heavy=true,
   gravity=true,
   frict=0x0.e,
   dropsfx=6,
   draw = sprite_draw,
   update = physics,
   kill = kill_bag,
   gold_id=level_gold
 }
 create(bag,bags)
 level_gold+=1
 return bag
end

spawnlist[72] = new_bag

function new_box()
	local box = {
			vel={
				x=0,
				y=0
			},
   coll={
 			l=0x0.2,
 			r=0x0.e,
 			u=0x0.0,
 			d=0x1.0
 		},
   sprite = {
   	n = 75,
   	w = 1,
   	h = 1
   },
   heavy=true,
   gravity=true,
   frict=0x0.e,
   dropsfx=7,
   draw = sprite_draw,
   update = physics,
   kill = kill_box
 }
 create(box,bags)
 return box
end

spawnlist[75] = new_box

function new_bouncy_box()
	local obj=new_box()
	obj.bounce=0x0.5d
	obj.sprite.n=76
	obj.kill=kill_bag
	return obj
end

function spawn_bouncy_box()
	if band(peek(0x5e00),0x1)==0 then
		return new_bouncy_box()
	end
end

spawnlist[76] = spawn_bouncy_box

--loo brb
--todo, replace this hack with
--goto level select?
function exit_on_b(obj,player)
	if btn(3) and not player.holding then
		if tutorial==1 then
			save_truck()

			local found=false
			for bag in all(truck) do
				if bag.gold_id==1 then
					found=true
				end
			end

			load_truck()

			if not found then
				destroy(tutorial_text)
				tutorial_text=text_box("no gold laoded",8,8)

				--create_exit_trigger()
				return
			end
		end

		destroy(obj)
		exit_level()
	end
end

function create_exit_trigger()
	local box = {
			x=truckx,
			y=trucky+2,
   coll={
 			l=0x0.0,
 			r=0x1.0,
 			u=0x0.0,
 			d=0x1.0
 		},
 		sprite={
 			n=89,
 			w=1,
 			h=1
 		},
 		trigger=exit_on_b,
 		draw=sprite_draw
 }
 create(box,triggers)
 return box
end

--spawnlist[89]=create_exit_trigger

local function enter_trigger(trg)
	if btn(4) or btn(5) then
		loadlevel(trg.level)
	end
end

function create_enter_trigger(level)
	return function()
		local box = {
   coll={
 			l=0x0.0,
 			r=0x1.0,
 			u=0x0.0,
 			d=0x1.0
 		},
 		level=level,
 		trigger=enter_trigger,
  }
  create(box,triggers)
  return box
	end
end

spawnlist[51]=create_enter_trigger(level_data.home)

spawnlist[53]=create_enter_trigger(level_data[1])
spawnlist[54]=create_enter_trigger(level_data[2])
spawnlist[55]=create_enter_trigger(level_data[3])
spawnlist[56]=create_enter_trigger(level_data[4])
spawnlist[57]=create_enter_trigger(level_data[5])
spawnlist[58]=create_enter_trigger(level_data[6])

-->8
--collision handlers
local function shot_enemy(bullet,enemy)
  if bullet.update==bullet_update then
  	bullet_impact(bullet)
  	enemy_die(enemy,bullet.vel)
  end
end

local function player_pickup(player,pickup)
	pickup.picked_up(pickup,player)
	destroy(pickup)
end

local function bag_bag(bag1,bag2)
	--hack so player can jump off of items
	--if(bag1.layer==players) bag1.grounded=true

	if bag1!=bag2 then
		local dx=bag1.x-bag2.x
		local dy=bag1.y-bag2.y
		if abs(dy)>abs(dx) then
			if dy<0 and bag1.vel.y>0 then
				local temp=bag1.y
				local ty=(bag2.y
						+bag2.coll.u
						-bag1.coll.d)-bag1.y
				if band(movey(bag1,ty),0x1)!=0 then
					bag1.y=temp
				end

				--bag1.y=bag2.y
				--		+bag2.coll.u
				--		-bag1.coll.d
				if bag2.bounce then
					bag1.vel.y=-bag2.bounce
					bag1.grounded=false
					psfx(9,bag1.x,bag1.y)
				else
 				if bag1.dropsfx and bag1.vel.y>0x0.2 then
 					psfx(bag1.dropsfx,bag1.x,bag1.y)
 				end
					bag1.vel.y=0
					bag1.grounded=true
				end
			end
		else
 		if dx<0 then
  		if bag1.layer==enemies then
 				bag1.sprite.fx=true
 				if(bag1.vel.x>0) bag1.vel.x=0
 			elseif bag1.vel.x>bag2.vel.x then
 				bag2.vel.x+=0x0.1
 				--local temp=bag1.vel.x
 				--bag1.vel.x=bag2.vel.x
 				--bag2.vel.x=temp
 			end
 		else
 			if bag1.layer==enemies then
 				bag1.sprite.fx=false
 				if(bag1.vel.x<0) bag1.vel.x=0
 			elseif bag1.vel.x<bag2.vel.x then
 				bag2.vel.x-=0x0.1
 				--local temp=bag1.vel.x
 				--bag1.vel.x=bag2.vel.x
 				--bag2.vel.x=temp
 			end
 		end
 	end
	end
end

local function bag_enemy(bag,enemy)
	local dy=bag.y-enemy.y
	if not bag.notthrown and dy<0 and bag.vel.y>0 then
		enemy_die(enemy,bag.vel)
	end
end

local function bag_player(bag,player)
	local dy=bag.y-player.y
	if not player.holding and dy<0 and player.grounded and bag.vel.y>0x0.24 and bag.vel.y-bag.coll.d+player.coll.u>dy then
		if bag.heavy then
			player_die(player,bag.vel)
		else
			player_hit(player,bag)
		end
	else
		bag_bag(bag,player)
	end
end

--wrong place lol
function text_draw(obj)
	if obj.bg then
 	color(obj.bg)
 	rectfill(obj.x-1,obj.y-1,obj.x+(obj.w*4)-1,obj.y+5)
 end
 color(obj.fg)
 cursor(obj.x,obj.y)
 print(obj.text)
end

function trigger_player(trigger,player)
	if trigger.trigger then
		trigger:trigger(player)
	end
end

-->8
--scripts
function wait(t)
  for i=1,t do
    yield()
  end
end

function text_box(text,x,y)
  local obj={
    x=x,y=y,w=#text,
    bg=0,fg=7,
    text=text,
    draw=text_draw
  }
  create(obj,texts)
  return obj
end

function type_text(obj,text,speed)
  for p=1,#text do
  		obj.text=sub(text,1,p)
    wait(speed)
  end
end

function death_box()
		wait(20)
  local t=text_box("game over",46,54)
  type_text(t,"game over",5)
  --destroy(t)
end

function rising_box(text,x,y)
  return function()
		  local t=text_box(text,
		  	x-((#text)*2),
		  	y-3)
		  t.bg=false
		  multitask({function()
		    type_text(t,text,2)
		   end,
		   function()
		    for i=1,5 do
			    wait(2)
			    t.y-=1
			   end
			  end
			 })
			 wait(20)
			 destroy(t)
	 end
end

function delay_destroy(obj,t)
	if not obj.destroying then
		obj.destroying=true
 	begin_scene(function()
 		wait(t)
 		destroy(obj)
 	end)
 end
end

function delay_respawn(bag,t)
	if not bag.respawning then
		bag.respawning=true
 	begin_scene(function()
 		wait(t)
 		if bag.level_owner==current_level and bag.respawn then
  		bag.x=bag.respawn.x
  		bag.y=bag.respawn.y
  	else
  		destroy(bag)
  	end
  	bag.respawning=nil
 	end)
 end
end

function delay_spawn_player()
	wait(60)
	player=new_player()
end

function save_truck()
	truck={}
	local trigger={
		x=truckx,
		y=trucky,
		coll={
			l=0,
			r=4,
			u=0,
			d=5
		}
	}
	for item in all(bags) do
		if aabb_intersect(item,trigger) then
			destroy(item)
			create(item,truck)
			item.x-=truckx
			item.y-=trucky
		end
	end
end

function load_truck()
	for item in all(truck) do
		destroy(item)
		create(item,bags)
		item.x+=truckx
		item.y+=trucky
	end
end

function home_update(home)
	local trigger={
		x=8,
		y=4,
		coll={
			l=0,
			u=0,
			r=6,
			d=6
		}
	}
	number_of_bags=0
	for bag in all(bags) do
		if bag.gold_id and
				aabb_intersect(bag,trigger) then
			number_of_bags+=1
		end
	end
	if tutorial==2 and number_of_bags>0 then
		tutorial=3
		destroy(tutorial_text)
		text_box("find more",12,36)
		text_box("gold!",20,42)
		create_exit_trigger()
	end
	if not gameover and number_of_bags>=goal_bags then
		player.update=nil
		gameover=true
		begin_scene(function()
			for i=0,360 do
				if (i%4)==0 then
					begin_scene(rising_box("♪",rnd(128),rnd(96)))
				end
				_light=flr((-sin(i/36)*2)+0.5)
				yield()
			end
			player.update=player_update
			text_box("thanks for playing!",16,16)
			text_box("thanks for playing!",16,16)
		end)
	end
end

function truck_exit()
	local oldtruckx=truckx
	for i=0,120 do
		truckx=oldtruckx-i*i*0x0.002
		yield()
	end
end

function truck_enter(x,y)
	trucky=y
	for i=120,0,-1 do
		truckx=x-i*i*0x0.002
		yield()
	end
end

function player_enter_truck()
	destroy(player)
	create(player,truck)
	player.x=0x0.2
	player.y=0x3.4
end

function player_exit_truck()
	destroy(player)
	create(player,players)
	player.x=truckx
	player.y=trucky+2
end

function exit_level()
	menuitem(1)
	begin_scene(function()
		save_truck()--must do before

		player_enter_truck()
		truck_exit()

		--dont think this is used
		last_level=current_level

		if current_level!=level_data.home then
			music(3)
		end

		if tutorial==1 then
			tutorial=2
 		loadlevel(level_data.home)
		else
			wx=current_level.x
			wy=current_level.y
			loadlevel(level_data.world)
		end
	end)
end

function level_enter()
	if tutorial>1 and tutorial<10 then
		tutorial+=1
	end
	if tutorial==4 then
		text_box("the truck holds",4,4)
		text_box("more than gold",4,10)
	end
	if tutorial==5 then
		text_box("hold ⬇️ to",4,4)
		text_box("stay low",4,10)
	end
	if tutorial==5 then
		text_box("boxes will protect",4,4)
		text_box("you from spikes",4,10)
	end

	begin_scene(function()
 	truck_enter(1,0)
 	player_exit_truck()
 	load_truck()--must do after
 	menuitem(1,"suicide",player_kill)

 	create_exit_trigger()
 end)
 music(0)
end

function home_enter()
	--load the home
	for bag in all(home) do
		destroy(bag)
		create(bag,bags)
	end
	if tutorial==2 then
		destroy(tutorial_text)
		tutorial_text=text_box("store gold",69,36)
	end
	begin_scene(function()
 	truck_enter(1,4)
 	player_exit_truck()
 	load_truck()--must do after

 	if tutorial>2 then
 		create_exit_trigger()
 	end
 end)
end

function home_exit()
	--save the home
	for bag in all(bags) do
		destroy(bag)
		create(bag,home)
	end
end

function world_enter()
	local p={
		x=wx,
		y=wy,
		vel={
			x=0,
			y=0
		},
		coll={
			l=0x0.2,
			r=0x0.e,
			u=0x0.4,
			d=0x1.0
		},
		sprite={
			n=10,
			w=1,
			h=1
		},
		update=truck_drive,
		draw=sprite_draw
	}
	create(p,players)

end
-->8
--init
function _init()

	--set up world map
	for y=0,11 do
		for x=0,15 do
			--get the sprite number
			--of the cell
			local c=r_mget(x,y+12)-52

			if c>=1 and c<=6 then
				level_data[c].x=x
				level_data[c].y=y
			end
			if c==-1 then
				level_data.home.x=x
				level_data.home.y=y
			end
		end
	end

	music(0)

	loadlevel(level_data[1])

	player=new_player()

	tutorial_text=text_box("find gold!",36,8)

	camera(0,-0x10)
end

-->8
--update
function _update60()

	if(btn(5)) splash=false
  --scene
  scene_update()

	if not splash then
	if _delay>0 then
		_delay-=1
	else
    if _light>0 then
     _light-=1
    end
    if _shake>0 then
     _shake-=1
    end
		for layer in all(layers) do
			update(layer)
		end

		if #bags>25 then
			for bag in all(bags) do
				if not bag.heavy then
					destroy(bag)
					break
				end
			end
		end

  for_collisions(bullets,enemies,shot_enemy)
		for_collisions(players,enemies,player_hit)
		for_collisions(players,pickups,player_pickup)
		for_collisions(players,bags,bag_bag)
		for_collisions(enemies,bags,bag_bag)
		for_collisions(bags,bags,bag_bag)
		for_collisions(bags,enemies,bag_enemy)
		for_collisions(bags,players,bag_player)

		for_collisions(triggers,players,trigger_player)

		--if not enemies[1] then
		--	level+=1
		--	loadlevel(level)
		--end

		if current_level.update then
			current_level:update()
		end

		if player.y<5 and player.health<3 then
			player.health=3
			sfx(12)
		end

		local pcamy=(player.y*8)-48

		if player.grounded and (camy>pcamy+20) then
			camty=pcamy
		end

		if camy>pcamy+48 then
			camty=pcamy
		elseif camy<pcamy then
			camty=pcamy
		end

		if camty<0 then
			camty=0
		elseif camty>(levelh-1)*96 then
			camty=(levelh-1)*96
		end

		camy+=(camty-camy)*0.1
	end
	end
end

-->8
--draw
function _draw()
 cls()
 --memset(0x6000,0xff,0x2000)

	if not splash then

 --gui
	camera(0,0)
	clip(0,0,128,16)
	cursor(0,0)
	color(8)
	for i=1,player.health do
  print("♥",i*6,0)
 end

 if tutorial>2 then
 	color(6)
  print("bags in storage:",1,8)
  color(9)
 	print(number_of_bags,65,8)
 	print("/17",73,8)
 end
 if deaths>0 then
 	color(6)
 	print("deaths:",90,8)
  color(8)
 	print(deaths,118,8)
 end

 clip(0,112,128,16)

 if tutorial>3 then
  color(10)
 	print("find gold!",0,115)
 	color(6)
 	print("by isogash - ludum dare 40",0,122)
	end

	do
		local i=81
 	if(btn(0)) color(7) else color(5)
 	print("⬅️",i,114)
 	if(btn(3)) color(7) else color(5)
 	print("⬇️",i+8,114)
 	if(btn(2)) color(7) else color(5)
 	print("⬆️",i+16,114)
 	if(btn(1)) color(7) else color(5)
 	print("➡️",i+24,114)
 	if(btn(4)) color(7) else color(5)
 	print("🅾️",i+32,114)
 	if(btn(5)) color(7) else color(5)
 	print("❎",i+40,114)
 end


 --level
	clip(0,16,128,96)

 --shake
 local acamx=camx
 local acamy=camy-0x10

	if _shake > 0 then
		local i = flr(rnd(4))
		if(i==_shakedir) i=(i+2)%4

		local dx,dy = _shake*(i%2),_shake*((i+1)%2)
		if(i>1) dx,dy=-dx,-dy
		acamx+=dx
		acamy+=dy
		_shakedir = i
	end

	camera(acamx,acamy)

 --light
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



  --draw layers
  for i=0,levelh-1 do
  	local ly=(level+i)%5
  	local lx=flr((level+i)/5)
  	map(lx*16,ly*12,0,i*96,16,12,0x80)
  end
 	for layer in all(layers) do
 		draw(layer)
 	end
 	for i=0,levelh-1 do
 		local ly=(level+i)%5
  	local lx=flr((level+i)/5)
  	map(lx*16,ly*12,0,i*96,16,12,0x40)
  end

  camera(acamx-(truckx*8),acamy-(trucky*8))
  draw(truck)
  spr(12,0,24,4,2)

 else
 	camera()
 	clip()
 	map(112,48,0,0,16,16)
 	print("press ❎",48,116)
 end
end
