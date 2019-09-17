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
