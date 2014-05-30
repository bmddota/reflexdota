APM_LINEAR = 0
APM_CURVED = 1
APM_SPLIT = 2

if APM == nil then
  print ( '[APM] creating APM' )
  APM = {}
  APM.__index = APM
end

function APM:new( o )
  print ( '[APM] APM:new' )
  o = o or {}
  setmetatable( o, APM )
  return o
end

function APM:start()
  self.timers = {}
  self.reflectGroups = {}
  self.blockGroups = {}
  self.projectiles = {}
  
  local wspawn = Entities:FindByClassname(nil, 'worldspawn')
  wspawn:SetContextThink("APMThink", Dynamic_Wrap( APM, 'Think' ), 0.1 )
end

function APM:Think()
  if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
    return
  end

  -- Track game time, since the dt passed in to think is actually wall-clock time not simulation time.
  local now = GameRules:GetGameTime()
  --print("now: " .. now)
  if APM.t0 == nil then
    APM.t0 = now
  end
  local dt = now - APM.t0
  APM.t0 = now

  -- Process timers
  for k,v in pairs(APM.timers) do
    local bUseGameTime = false
    if v.useGameTime and v.useGameTime == true then
      bUseGameTime = true;
    end
    -- Check if the timer has finished
    if (bUseGameTime and GameRules:GetGameTime() > v.endTime) or (not bUseGameTime and Time() > v.endTime) then
      -- Remove from timers list
      APM.timers[k] = nil
      
      -- Run the callback
      local status, nextCall = pcall(v.callback, APM, v)

      -- Make sure it worked
      if status then
        -- Check if it needs to loop
        if nextCall then
          -- Change it's end time
          v.endTime = nextCall
          APM.timers[k] = v
        end

        -- Update timer data
        --self:UpdateTimerData()
      else
        -- Nope, handle the error
        APM:HandleEventError('Timer', k, nextCall)
      end
    end
  end

  return 0.04
end

function APM:HandleEventError(name, event, err)
  print(err)

  -- Ensure we have data
  name = tostring(name or 'unknown')
  event = tostring(event or 'unknown')
  err = tostring(err or 'unknown')

  -- Tell everyone there was an error
  Say(nil, name .. ' threw an error on event '..event, false)
  Say(nil, err, false)

  -- Prevent loop arounds
  if not self.errorHandled then
    -- Store that we handled an error
    self.errorHandled = true
  end
end

function APM:CreateTimer(name, args)
  if not args.endTime or not args.callback then
    print("Invalid timer created: "..name)
    return
  end

  self.timers[name] = args
end

function APM:RemoveTimer(name)
  self.timers[name] = nil
end

function APM:RemoveTimers(killAll)
  local timers = {}

  if not killAll then
    for k,v in pairs(self.timers) do
      if v.persist then
        timers[k] = v
      end
    end
  end

  self.timers = timers
end

--[[
  sequence:
     {"type",  APM_LINEAR, APM_CURVED, APM_SPLIT
      LINEAR
      "distance" or "time" or "to"
      "toward" or "angle" or "to"
      "from" or nothing
      "speed" or nothing
      CURVED
      "toward" or "angle"
        "angleTick"
        "tick"
        "ticks"
      "around"
      "speed" or nothing
      SPLIT
      "TBD"
]]

function APM:DoSequence(projectile)
  local sequence = projectile.sequence[projectile.sequenceIndex]
  
  if sequence == nil then
    return
  end
  
  local nextSequenceTime = GameRules:GetGameTime()
  local tp = sequence.type
  local projID = nil
  
  local bIgnoreTotalDistance = projectile.options.bIgnoreTotalDistance or false
  local bIgnoreExpireTime = projectile.options.bIgnoreExpireTime or false

  if tp == APM_LINEAR then
    local speed = FuncOrStatic(sequence.speed)
    local dir = FuncOrStatic(sequence.to) or FuncOrStatic(sequence.toward)
    local from = FuncOrStatic(sequence.from) or projectile.info.vSpawnOrigin
    projectile.info.vSpawnOrigin = from
    
    if projectile.info.vVelocity ~= nil and speed == nil then
      speed = projectile.info.vVelocity:Length()
    end
    
    if speed == nil or from == nil then
      --No speed/from given or found
      return
    end
    
    if dir == nil then
      dir = projectile.info.vVelocity
    else
      dir.z = 0
      from.z = 0
      local diff = dir - from
      projectile.info.vVelocity = diff:Normalized() * speed
    end
    
    local nextTime = FuncOrStatic(sequence.time)
    local distance = FuncOrStatic(sequence.distance)
    
    if nextTime ~= nil then
      distance = nextTime * speed
    else
      nextTime = distance / speed
    end
    
    nextSequenceTime = GameRules:GetGameTime() + nextTime
    
    projID = ProjectileManager:CreateLinearProjectile( projectile.info )
    
    projectile.info.vSpawnOrigin = projectile.info.vSpawnOrigin + (projectile.info.vVelocity * nextTime)
    if not bIgnoreTotalDistance then
      projectile.info.fDistance = projectile.info.fDistance - (projectile.info.vVelocity * nextTime):Length()
    end
    if not bIgnoreExpireTime then
      projectile.info.fExpireTime = projectile.info.fExpireTime - nextTime
    end
  elseif tp == APM_CURVED then
  
  elseif tp == APM_SPLIT then
  
  end
  
  projectile.sequenceIndex = projectile.sequenceIndex + 1
  
  -- Kill old projectile
  if projectile.projID ~= nil then
    ProjectileManager:DestroyLinearProjectile(projectile.projID)
  end
  
  projectile.projID = projID
  
  -- Done sequences
  if projectile.sequenceIndex > #projectile.sequence then
    return
  end
  
  self:CreateTimer(projectile.id, {
    endTime = nextSequenceTime,
    useGameTime = true,
    callback = function(apm, args)
      APM:DoSequence(projectile)
    end
  })
end

function FuncOrStatic(val)
  if val == nil then
    return nil
  end
  if type(val) == "function" then
    local status, ret = pcall(val)
    return ret
  else
    return val
  end
end

function APM:CreateProjectile(info, sequence, reflectGroup, blockGroup, options)
  local projectile = {id = DoUniqueString("proj"), info = info, reflectGroup = reflectGroup, blockGroup = blockGroup, sequence = sequence, sequenceIndex = 1, projID = nil, options = options or {}}

  self.projectiles[projectile.id] = projectile
  
  -- Calculate sequence
  
  -- Create Initial timer
  APM:DoSequence(projectile)
  
  return projectile
end

function APM:CreateCurvedProjectile(info, from, toward, angle, tick, ticks, speed)
  toward.z = 0
  from.z = 0
  local pos = toward
  local diff = pos - from
  
  info.vVelocity = diff:Normalized() * speed
  
  local count = 0
  local createTime = GameRules:GetGameTime()
	local curProjectile = ProjectileManager:CreateLinearProjectile( info )
  
  APM:CreateTimer(DoUniqueString('curved'), {
    endTime = GameRules:GetGameTime() + tick,
    useGameTime = true,
    callback = function(apm, args)
      local now = GameRules:GetGameTime()
      --print ('now: ' .. now)
      local elapsed = now - createTime
      
      info.vSpawnOrigin = info.vSpawnOrigin + (info.vVelocity * elapsed)
      info.fDistance = info.fDistance - (info.vVelocity * elapsed):Length()
      info.fExpireTime = info.fExpireTime - elapsed
      
      local ang = QAngle(0, angle, 0)
      local vec = RotatePosition( Vector(0,0,0), ang, info.vVelocity ) 
      --print('Angle: ' .. tostring(ang) .. ' -- lastv: ' .. tostring(info.vVelocity) ..  ' -- vec: ' .. tostring(vec))
      
      vec.z = 0
      info.vVelocity = vec
      createTime = GameRules:GetGameTime()
      local newProjectile = ProjectileManager:CreateLinearProjectile( info )
      ProjectileManager:DestroyLinearProjectile(curProjectile)
      curProjectile = newProjectile
      
      count = count + 1
      if count < ticks then
        return GameRules:GetGameTime() + tick
      end
    end
  })
end

function APM:ReverseProjectile(projectile)
  -- timing fix
  local now = GameRules:GetGameTime()
  local elapsed = now - self.createTime
  
  
  projectile.info.vSpawnOrigin = projectile.info.vSpawnOrigin + (projectile.info.vVelocity * elapsed)
  projectile.info.fDistance = projectile.info.fDistance - (projectile.info.vVelocity * elapsed):Length()
  projectile.info.fExpireTime = projectile.info.fExpireTime - elapsed
  
  projectile.info.vVelocity.x = -1 * projectile.info.vVelocity.x
  projectile.info.vVelocity.y = -1 * projectile.info.vVelocity.y
  
  projectile = ProjectileManager:CreateLinearProjectile( projectile.info )
  ProjectileManager:DestroyLinearProjectile(projectile.projID)
  return projectile
end

APM:start()