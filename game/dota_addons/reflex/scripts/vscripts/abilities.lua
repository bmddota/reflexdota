
vPlayerIlluminate = {}
vPlayerProjectiles = {}
vPlayerDummies = {}
vPlayerToggles = {}

function warpToPoint(keys)
  local target = keys.Target
  local caster = keys.caster
  
  if caster == nil then
    return
  end

  local point = nil
  if target == "POINT" and keys.target_points[1] then
    point = keys.target_points[1]
  else
    return
  end
  
  --print(tostring(point))
  --prevent top left
  --[   VScript              ]: Vector 0000000000191460 [-2285.906250 1486.625000 181.593750]
  if point.x < -2080 and point.y > 1368 then
    point = Vector(-2180, 1368, 0)
  end
  
  -- prevent top right
  if point.x > 2080 and point.y > 1368 then
    point = Vector(2180, 1368, 0)
  end

  FindClearSpaceForUnit(caster, point, false)
end

function toggleStart(keys)
  local caster = keys.caster
  local toggles = vPlayerDummies[caster:GetPlayerID()]
  local delay = tonumber(keys.MaxCharge)
  
  if toggles == nil then
    toggles = {}
    vPlayerDummies[caster:GetPlayerID()] = toggles
  end 
  
  toggles[keys.ability:GetAbilityName()] = GameRules:GetGameTime()
  
  caster.dingTimer = Timers:CreateTimer(delay, function()
      EmitSoundOnClient("Hero_EmberSpirit.FireRemnant.Stop", caster:GetPlayerOwner()) -- "General.Ping"
    end)
end

function swordHit(keys)
  local target = keys.target
  local caster = keys.caster
  local damagePerCharge = tonumber(keys.DamagePerSecond)
  local maxCharge = tonumber(keys.MaxCharge)
  
  local toggles = vPlayerDummies[caster:GetPlayerID()]
  if toggles == nil then
    return
  end 
  
  local chargeTime = toggles[keys.ability:GetAbilityName()]
  if chargeTime == nil then
    chargeTime = 0.2
  else
    chargeTime = GameRules:GetGameTime() - chargeTime
  end
  
  if chargeTime > maxCharge then
    chargeTime = maxCharge
  end
  
  local damage = chargeTime * damagePerCharge
  dealDamage(caster, target, damage)
end

function startFire(keys)
  local target = keys.Target
  local caster = keys.caster
  local duration = keys.Duration
  local distPerCharge = tonumber(keys.DistancePerCharge)
  local maxCharge = tonumber(keys.MaxCharge)
  
  if caster.dingTimer then
    Timers:RemoveTimer(caster.dingTimer)
  end
  
  if caster == nil then
    return
  end
  
  local toggles = vPlayerDummies[caster:GetPlayerID()]
  if toggles == nil then
    return
  end 
  
  local chargeTime = toggles[keys.ability:GetAbilityName()]
  if chargeTime == nil then
    chargeTime = 0.2
  else
    chargeTime = GameRules:GetGameTime() - chargeTime
  end
  
  if chargeTime > maxCharge then
    chargeTime = maxCharge
  end
  
  local diff = caster:GetForwardVector()
  --ref_ember_spirit_weapon_blur
  local particle = ParticleManager:CreateParticle("particles/reflex_particles/ref_ember_spirit_weapon_blur.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)--cmdPlayer:GetAssignedHero())
  ParticleManager:ReleaseParticleIndex(particle)
  
  local unit = CreateUnitByName("npc_firefly_dummy", caster:GetAbsOrigin(), false, caster, caster, caster:GetTeamNumber())
  local ability = unit:FindAbilityByName("reflex_dummy_unit")
  ability:SetLevel(1)
  
  unit:AddNewModifier(unit, nil, "modifier_faceless_void_chronosphere_speed", {})
  unit:SetAbsOrigin(caster:GetAbsOrigin() + diff * 100)
  unit:SetForwardVector(diff)
  ability = unit:FindAbilityByName("reflex_firefly")
  ability:SetLevel(keys.ability:GetLevel())
  unit:CastAbilityImmediately(ability, 0)

  local bounds = nil
  if MAP_DATA[GetMapName()] == nil then
    bounds = MAP_DATA["default"].bounds
  else  
    bounds = MAP_DATA[GetMapName()].bounds
  end
  local dist = distPerCharge * chargeTime
  local pos = caster:GetAbsOrigin() + diff * dist
  
  if pos.y < bounds.bottom then
    pos.y = bounds.bottom
  elseif pos.y > bounds.top then
    pos.y = bounds.top
  end
  
  if pos.x < bounds.left then
    pos.x = bounds.left
  elseif pos.x > bounds.right then
    pos.x = bounds.right
  end

  ExecuteOrderFromTable({
    UnitIndex = unit:entindex(),
    OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
    Position = pos,
    Queue = true
  })
  
  Timers:CreateTimer(tonumber(duration), function()
      --unit:MoveToPosition(caster:GetAbsOrigin() + diff * 800)
      unit:StopSound("Hero_Batrider.Firefly.Cast")
      unit:StopSound("Hero_Batrider.Firefly.loop")
      unit:RemoveSelf()
      unit = nil
    end)
  
  local lastplace = unit:GetAbsOrigin()
  local oldplace = nil
  Timers:CreateTimer(0.166, function()
      local dur = tonumber(duration)
      if dur <= 0 or unit == nil or unit:GetAbsOrigin() == oldplace then
        return
      end
      oldplace = unit:GetAbsOrigin()
      
      dangerIndicator({
        caster = caster,
        Target = "POINT",
        target_points = { oldplace },
        target_entities = {},
        Radius = 115,
        Duration = dur
        --NoEnemy = true
      })
      
      return 0.166
    end)
end

function removeCharge(keys)
  local target = keys.target
  local caster = keys.caster
  
  if caster == nil or target == nil then
    return
  end
  
  if target:HasModifier("modifier_faceless_void_chronosphere_speed") then
    target:RemoveModifierByName("modifier_faceless_void_chronosphere_speed")
    callModRemover(target, "reflex_charge_turn")
  end
  
end

function teamBasedCircle(keys)
  local target = keys.Target
  local caster = keys.caster
  local duration = tonumber(keys.Duration) or 6
  local safeEffect = keys.SafeEffect
  local dangerEffect = keys.DangerEffect
  local sound = keys.Sound or nil
  
  if caster == nil or keys.Radius == nil then
    return
  end
  
  local radius = tonumber(keys.Radius)
  
  local targetEntity = nil
    
  local attach = PATTACH_ABSORIGIN_FOLLOW
  
  local point = keys.target_points[1]
  local team = caster:GetTeam()
  
  targetEntity = CreateUnitByName("npc_dota_danger_indicator", point, false, caster, caster, team)
  targetEntity:AddNewModifier(unit, nil, "modifier_invulnerable", {})
  targetEntity:AddNewModifier(unit, nil, "modifier_phased", {})
  local ability = targetEntity:FindAbilityByName("reflex_dummy_unit")
  ability:SetLevel(1)
  
  if sound ~= nil then
    targetEntity:EmitSound(sound)
  end
  
  for i=0,9 do 
    if PlayerResource:IsValidPlayer(i) then
      local hero = PlayerResource:GetPlayer(i):GetAssignedHero()
      if hero == nil then
        return
      end

      local particle = nil
      if hero:GetTeam() == team then
        particle = ParticleManager:CreateParticleForPlayer(safeEffect, attach, targetEntity, PlayerResource:GetPlayer(i))--cmdPlayer:GetAssignedHero())
      else
        particle = ParticleManager:CreateParticleForPlayer(dangerEffect, attach, targetEntity, PlayerResource:GetPlayer(i))--cmdPlayer:GetAssignedHero())
      end
      ParticleManager:SetParticleControl(particle, 0, Vector(0,0,0)) -- something
      ParticleManager:SetParticleControl(particle, 1, Vector(radius,1,1)) -- endpoint
      ParticleManager:SetParticleControl(particle, 2, Vector(duration,0,0)) -- something
      ParticleManager:ReleaseParticleIndex(particle)
    end
  end
  -- Test Lua-particle generation

  --[[ Bots
  for k,v in pairs(ReflexGameMode.vBots) do
    local particle = nil
    if team == DOTA_TEAM_GOODGUYS then
      particle = ParticleManager:CreateParticleForPlayer(safeEffect, attach, targetEntity, ReflexGameMode.vUserIds[k])--cmdPlayer:GetAssignedHero())
    else
      particle = ParticleManager:CreateParticleForPlayer(dangerEffect, attach, targetEntity, ReflexGameMode.vUserIds[k])--cmdPlayer:GetAssignedHero())
    end
    ParticleManager:SetParticleControl(particle, 0, Vector(0,0,0)) -- something
    ParticleManager:SetParticleControl(particle, 1, Vector(radius,1,1)) -- endpoint
    ParticleManager:SetParticleControl(particle, 2, Vector(0,0,0)) -- something
  end]]
  
  local particle = nil
  if team == DOTA_TEAM_GOODGUYS then
    particle = ParticleManager:CreateParticleForPlayer(safeEffect, attach, targetEntity, PlayerResource:GetPlayer(-1))--cmdPlayer:GetAssignedHero())
  else
    particle = ParticleManager:CreateParticleForPlayer(dangerEffect, attach, targetEntity, PlayerResource:GetPlayer(-1))--cmdPlayer:GetAssignedHero())
  end
  ParticleManager:SetParticleControl(particle, 0, Vector(0,0,0)) -- something
  ParticleManager:SetParticleControl(particle, 1, Vector(radius,1,1)) -- endpoint
  ParticleManager:SetParticleControl(particle, 2, Vector(duration,0,0)) -- something
  ParticleManager:ReleaseParticleIndex(particle)
  
  -- Broadcasters
  --for k,v in pairs(ReflexGameMode.vBroadcasters) do
  for i=10,32 do 
  	if PlayerResource:IsValidPlayer(i) then
  		local particle = nil
  		if team == DOTA_TEAM_GOODGUYS then
  		  particle = ParticleManager:CreateParticleForPlayer(safeEffect, attach, targetEntity, PlayerResource:GetPlayer(i))--ReflexGameMode.vUserIds[k]--cmdPlayer:GetAssignedHero())
  		else
  		  particle = ParticleManager:CreateParticleForPlayer(dangerEffect, attach, targetEntity, PlayerResource:GetPlayer(i))--cmdPlayer:GetAssignedHero())
  		end
  		ParticleManager:SetParticleControl(particle, 0, Vector(0,0,0)) -- something
  		ParticleManager:SetParticleControl(particle, 1, Vector(radius,1,1)) -- endpoint
  		ParticleManager:SetParticleControl(particle, 2, Vector(duration,0,0)) -- something
      ParticleManager:ReleaseParticleIndex(particle)
  	end
  end
 
  Timers:CreateTimer(duration, function()
      if sound ~= nil then
        targetEntity:StopSound(sound)
      end
      targetEntity:RemoveSelf()
    end)
end

function createWallOfPain(keys)
  local point = keys.target_points[1]
  local caster = keys.caster

  local unit = CreateUnitByName("npc_dota_danger_indicator", caster:GetAbsOrigin(), false, caster, caster, caster:GetTeamNumber())
  unit:AddNewModifier(unit, nil, "modifier_invulnerable", {})
  unit:AddNewModifier(unit, nil, "modifier_phased", {})
  local ability = unit:FindAbilityByName("reflex_dummy_unit")
  ability:SetLevel(1)

  local level = keys.ability:GetLevel()

  unit:AddAbility("reflex_wall_of_pain_" .. level)
  ability = unit:FindAbilityByName("reflex_wall_of_pain_" .. level)
  ability:SetLevel(level)

  unit:SetForwardVector((point - caster:GetAbsOrigin()):Normalized())

  ExecuteOrderFromTable({
    UnitIndex = unit:entindex(),
    AbilityIndex = ability:entindex(),
    OrderType = DOTA_UNIT_ORDER_CAST_POSITION,
    Position = point,
    Queue = true
  })

  Timers:CreateTimer(10.0, function()
      unit:RemoveSelf()
    end)
end

function teamBasedWall(keys)
  local target = keys.Target
  local caster = keys.caster
  local duration = tonumber(keys.Duration) or 6
  
  if caster == nil or keys.EffectLineLength == nil then
    return
  end
  
  local length = tonumber(keys.EffectLineLength)
  
  local targetEntity = nil
    
  local attach = PATTACH_ABSORIGIN_FOLLOW
  
  local point = keys.target_points[1]
  local diff = point - caster:GetAbsOrigin()
  diff.z = 0
  diff = diff:Normalized()
  
  local vec = RotatePosition( Vector(0,0,0), QAngle(0, 90, 0), diff )
  local team = caster:GetTeam()
  
  targetEntity = CreateUnitByName("npc_dota_danger_indicator", point + (vec * length / 2), false, caster, caster, team)
  targetEntity:AddNewModifier(unit, nil, "modifier_invulnerable", {})
  targetEntity:AddNewModifier(unit, nil, "modifier_phased", {})
  local ability = targetEntity:FindAbilityByName("reflex_dummy_unit")
  ability:SetLevel(1)
  
  for i=0,9 do 
    if PlayerResource:IsValidPlayer(i) then
      local particle = nil
      local hero = PlayerResource:GetPlayer(i):GetAssignedHero()
      if hero == nil then
        return
      end

      if hero:GetTeam() == team then
        --particles/reflex_particles/ref_dark_seer_wall_of_replica.vpcf
        particle = ParticleManager:CreateParticleForPlayer("particles/newplayer_fx/npx_barrier.vpcf", attach, targetEntity, PlayerResource:GetPlayer(i))--cmdPlayer:GetAssignedHero())
      else
        particle = ParticleManager:CreateParticleForPlayer("particles/units/heroes/hero_dark_seer/dark_seer_wall_of_replica.vpcf", attach, targetEntity, PlayerResource:GetPlayer(i))--cmdPlayer:GetAssignedHero())
      end
      ParticleManager:SetParticleControl(particle, 0, Vector(0,0,0)) -- something
      ParticleManager:SetParticleControl(particle, 1, point + (vec * length / -2)) -- endpoint
      ParticleManager:SetParticleControl(particle, 2, Vector(0,0,0)) -- something
      ParticleManager:SetParticleControl(particle, 3, point) -- point to alpha alternate
      ParticleManager:ReleaseParticleIndex(particle)
    end
  end
  -- Test Lua-particle generation

  -- Bots
  local particle = nil
  if team == DOTA_TEAM_GOODGUYS then
    particle = ParticleManager:CreateParticleForPlayer("particles/newplayer_fx/npx_barrier.vpcf", attach, targetEntity, PlayerResource:GetPlayer(-1))--cmdPlayer:GetAssignedHero())
  else
    particle = ParticleManager:CreateParticleForPlayer("particles/units/heroes/hero_dark_seer/dark_seer_wall_of_replica.vpcf", attach, targetEntity, PlayerResource:GetPlayer(-1))--cmdPlayer:GetAssignedHero())
  end
  ParticleManager:SetParticleControl(particle, 0, Vector(0,0,0)) -- something
  ParticleManager:SetParticleControl(particle, 1, point + (vec * length / -2)) -- endpoint
  ParticleManager:SetParticleControl(particle, 2, Vector(0,0,0)) -- something
  ParticleManager:SetParticleControl(particle, 3, point) -- point to alpha alternate
  ParticleManager:ReleaseParticleIndex(particle)
  
  -- Broadcasters
  --for k,v in pairs(ReflexGameMode.vBroadcasters) do
  for i=10,32 do 
  	if PlayerResource:IsValidPlayer(i) then
  		local particle = nil
  		if team == DOTA_TEAM_GOODGUYS then
  		  particle = ParticleManager:CreateParticleForPlayer("particles/newplayer_fx/npx_barrier.vpcf", attach, targetEntity, PlayerResource:GetPlayer(i))--ReflexGameMode.vUserIds[k]--cmdPlayer:GetAssignedHero())
  		else
  		  particle = ParticleManager:CreateParticleForPlayer("particles/units/heroes/hero_dark_seer/dark_seer_wall_of_replica.vpcf", attach, targetEntity, PlayerResource:GetPlayer(i))--cmdPlayer:GetAssignedHero())
  		end
  		ParticleManager:SetParticleControl(particle, 0, Vector(0,0,0)) -- something
  		ParticleManager:SetParticleControl(particle, 1, point + (vec * length / -2)) -- endpoint
  		ParticleManager:SetParticleControl(particle, 2, Vector(0,0,0)) -- something
  		ParticleManager:SetParticleControl(particle, 3, point) -- point to alpha alternate
      ParticleManager:ReleaseParticleIndex(particle)
  	end
  end
  
  local endPoint = point + (vec * length / 2)
  
  for i=0,length,200 do
    dangerIndicator({
        caster = caster,
        Target = "POINT",
        target_points = { endPoint - vec * i },
        target_entities = {},
        Radius = 90,
        Duration = duration
      })
  end
 
  Timers:CreateTimer(duration, function()
      targetEntity:RemoveSelf()
    end)
end

function dangerIndicator(keys)
  local target = keys.Target
  local caster = keys.caster
  local duration = tonumber(keys.Duration) or 6
  local noEnemy = keys.NoEnemy or nil
  
  if caster == nil or keys.Radius == nil then
    return
  end
  
  local radius = tonumber(keys.Radius)
  
  local targetEntity = nil
    
  local attach = PATTACH_ABSORIGIN_FOLLOW
  
  local point = nil
  if target == "POINT" and keys.target_points[1] then
    point = keys.target_points[1]
    targetEntity = CreateUnitByName("npc_dota_danger_indicator", point, false, nil, nil, DOTA_TEAM_NOTEAM)
    targetEntity:AddNewModifier(unit, nil, "modifier_invulnerable", {})
    targetEntity:AddNewModifier(unit, nil, "modifier_phased", {})
    local ability = targetEntity:FindAbilityByName("reflex_dummy_unit")
    ability:SetLevel(1)
  end
  if keys.target_entities[1] then
    targetEntity = keys.target_entities[1]
    attach = PATTACH_ABSORIGIN_FOLLOW
  end
  if target == "CASTER" then
    targetEntity = caster
    attach = PATTACH_ABSORIGIN_FOLLOW
  end
  
  local team = caster:GetTeam()
  --print ('team: ' .. team)
  
  for i=0,9 do
    if PlayerResource:IsValidPlayer(i) then
      if noEnemy ~= nil and PlayerResource:GetTeam(i) ~= team then
        return
      end
      local hero = PlayerResource:GetPlayer(i):GetAssignedHero()
      if hero == nil then
        return
      end
      local particle = ParticleManager:CreateParticleForPlayer(DANGER_INDICATOR_OVERRIDE or "particles/reflex_particles/generic_aoe_shockwave_1.vpcf", attach, targetEntity, PlayerResource:GetPlayer(i))
      --ParticleManager:SetParticleAlwaysSimulate(particle)

      --ParticleManager:SetParticleControlEnt(particle, 0, targetEntity, attach, nil, Vector(0,0,0), true)
      ParticleManager:SetParticleControl(particle, 1, Vector(radius,0,0)) -- radius
      ParticleManager:SetParticleControl(particle, 2, Vector(duration,0,1)) -- something
      if hero:GetTeam() == team and not hero.bColorblind then
        ParticleManager:SetParticleControl(particle, 3, Vector(0,200,0)) -- color
      elseif hero:GetTeam() == team and hero.bColorblind then
        ParticleManager:SetParticleControl(particle, 3, Vector(0,0,200)) -- color
      else
        ParticleManager:SetParticleControl(particle, 3, Vector(200,0,0)) -- color
      end
      ParticleManager:SetParticleControl(particle, 4, Vector(0,0,0)) -- something
      ParticleManager:ReleaseParticleIndex(particle)
    end
  end
  -- Test Lua-particle generation

  -- Bots
  local particle = ParticleManager:CreateParticleForPlayer(DANGER_INDICATOR_OVERRIDE or "particles/reflex_particles/generic_aoe_shockwave_1.vpcf", attach, targetEntity, PlayerResource:GetPlayer(-1))--cmdPlayer:GetAssignedHero())
  --ParticleManager:SetParticleAlwaysSimulate(particle)
  --ParticleManager:SetParticleControlEnt(particle, 0, targetEntity, PATTACH_POINT_FOLLOW, nil, Vector(0,0,0), true)
  ParticleManager:SetParticleControl(particle, 1, Vector(radius,0,0)) -- radius
  ParticleManager:SetParticleControl(particle, 2, Vector(duration,0,1)) -- something
  if team == DOTA_TEAM_GOODGUYS then
    ParticleManager:SetParticleControl(particle, 3, Vector(0,200,0)) -- color
  else
    ParticleManager:SetParticleControl(particle, 3, Vector(200,0,0)) -- color
  end
  ParticleManager:SetParticleControl(particle, 4, Vector(0,0,0)) -- something
  ParticleManager:ReleaseParticleIndex(particle)
  
  -- Broadcasters
  --for k,v in pairs(ReflexGameMode.vBroadcasters) do
  for i=10,32 do 
  	if PlayerResource:IsValidPlayer(i) then
  		local particle = ParticleManager:CreateParticleForPlayer(DANGER_INDICATOR_OVERRIDE or "particles/reflex_particles/generic_aoe_shockwave_1.vpcf", attach, targetEntity, PlayerResource:GetPlayer(i))--cmdPlayer:GetAssignedHero())
      --ParticleManager:SetParticleAlwaysSimulate(particle)
      --ParticleManager:SetParticleControlEnt(particle, 0, targetEntity, PATTACH_POINT_FOLLOW, nil, Vector(0,0,0), true)
  		ParticleManager:SetParticleControl(particle, 1, Vector(radius,0,0)) -- radius
  		ParticleManager:SetParticleControl(particle, 2, Vector(duration,0,1)) -- something
  		if team == DOTA_TEAM_GOODGUYS then
  		  ParticleManager:SetParticleControl(particle, 3, Vector(0,200,0)) -- color
  		else
  		  ParticleManager:SetParticleControl(particle, 3, Vector(200,0,0)) -- color
  		end
  		ParticleManager:SetParticleControl(particle, 4, Vector(0,0,0)) -- something
      ParticleManager:ReleaseParticleIndex(particle)
  	end
  end

  if target == "POINT" then
    Timers:CreateTimer(0.5,
      function()
        targetEntity:RemoveSelf()
      end
    )
  end
end

function itemSpellStart (keys)
  --PrintTable(keys)
  
  local target = keys.Target
  local caster = keys.caster
  local abilityName = keys.Ability
  local itemName = keys.ability:GetAbilityName()
  local chargeModifier = keys.ChargeModifier
  
  local chargeType = keys.ChargeType or "UNLINKED"
  
  if caster == nil or itemName == nil then
    return
  end
  
  --PrintTable(caster)
  --PrintTable(getmetatable(caster))
  --print(caster:GetMana())
  
  local item = GameMode:GetItemByName(caster, itemName )
  --print ('Item')
  --PrintTable(item)
  --PrintTable(getmetatable(item))
  if item == nil then
    item = caster:FindAbilityByName(itemName)
    if item == nil then 
      return
    end
  end
  
    
  if string.find(itemName, "item_reflex_dash") ~= nil then
    if caster:HasModifier("modifier_hamstring") or caster:HasModifier("modifier_hamstring_2") 
      or caster:HasModifier("modifier_hamstring_3") or caster:HasModifier("modifier_hamstring_4") 
      or caster:HasModifier("modifier_blade_charge") or caster:HasModifier("modifier_disruptor_kinetic_field") then
      local charges = item:GetCurrentCharges()
      local maxCharges = item:GetInitialCharges()
  
      if charges + 1 <= maxCharges then
        item:SetCurrentCharges(charges + 1)
      end
      
      EmitSoundOnClient("General.CantAttack" , caster:GetPlayerOwner())
      
      local mana = caster:GetMana() + 80
      if mana > caster:GetMaxMana() then
        caster:SetMana(caster:GetMaxMana())
      else
        caster:SetMana(mana)
      end
      return
    end
  end
  
  local abilityLevel = keys.AbilityLevel or item:GetLevel()
  
  local point = nil
  if keys.target_points[1] then
    point = keys.target_points[1]
  end
  --if point == nil then
  --  return  
  --end
  
  local targetEntity = nil
  if keys.target_entities[1] then
    targetEntity = keys.target_entities[1]
  end
  if target == "CASTER" then
    targetEntity = caster
  end
  
  if chargeModifier ~= nil then
    --print (chargeModifier .. ": " .. tostring(caster:HasModifier(chargeModifier)))
    if chargeType == "UNLINKED" and string.find(itemName, "item_reflex_dash") then
      callModApplier(caster, chargeModifier)
    elseif chargeType == "HALF" then
      --print(' HALF ')
      if caster:HasModifier(chargeModifier) == false then
        --print (" doesn't have mod " )
        callModApplier(caster, chargeModifier)
      end
    elseif chargeType == "FULL" then
      caster:RemoveModifierByName(chargeModifier)
      callModApplier(caster, chargeModifier)
    elseif chargeType == "ALL" then
      --print(' ALL ')
      if caster:HasModifier(chargeModifier) == false then
        --print (" doesn't have mod " )
        callModApplier(caster, chargeModifier)
      end
    end
  end
  
  if abilityName ~= nil then
    if string.find(abilityName, "reflex_illuminate") ~= nil then
      local plyID = caster:GetPlayerOwner():GetPlayerID()
      if (plyID ~= nil) then
        if vPlayerIlluminate[plyID] == nil then
          vPlayerIlluminate[plyID] = 1
        else
          vPlayerIlluminate[plyID] = (vPlayerIlluminate[plyID] % 4) + 1
        end
        
        abilityName = "reflex_illuminate_" .. vPlayerIlluminate[plyID]
      end
      
      local diff = point - caster:GetAbsOrigin()
      diff.z = 0
      diff = diff:Normalized()
      
      local unit = CreateUnitByName('npc_firefly_dummy', caster:GetAbsOrigin(), false, caster, caster, caster:GetTeamNumber())
      local dummy = unit:FindAbilityByName("reflex_dummy_unit")
      dummy:SetLevel(1)
      unit:AddNewModifier(unit, nil, "modifier_invulnerable", {})
      unit:AddNewModifier(unit, nil, "modifier_item_ethereal_blade_ethereal", {duration = 10})
      unit:AddNewModifier(unit, nil, "modifier_phased", {})
      unit:SetModel('models/heroes/lycan/lycan_wolf.mdl')
      unit:SetOriginalModel('models/heroes/lycan/lycan_wolf.mdl')
      
      unit:SetForwardVector(diff)
      
      local unit2 = CreateUnitByName('npc_firefly_dummy', caster:GetAbsOrigin(), false, caster, caster, caster:GetTeamNumber())
      local dummy2 = unit:FindAbilityByName("reflex_dummy_unit")
      dummy2:SetLevel(1)
      unit2:AddNewModifier(unit2, nil, "modifier_invulnerable", {})
      unit2:AddNewModifier(unit2, nil, "modifier_item_ethereal_blade_ethereal", {duration = 10})
      unit2:AddNewModifier(unit2, nil, "modifier_phased", {})
      unit2:SetModel('models/heroes/lycan/lycan_wolf.mdl')
      unit2:SetOriginalModel('models/heroes/lycan/lycan_wolf.mdl')
      
      unit2:SetForwardVector(diff)
      
      local ability = unit:FindAbilityByName( abilityName )
      if ability == nil then
        unit:AddAbility(abilityName)
        ability = unit:FindAbilityByName( abilityName )
      end
      
      ability:SetLevel( abilityLevel )
      
      if not ability:IsFullyCastable() then
        local charges = item:GetCurrentCharges()
        item:SetCurrentCharges(charges + 1)
        return
      end

      unit:CastAbilityOnPosition ( point, ability, 0 )
      
      dangerIndicator({
        caster = caster,
        Target = "POINT",
        target_points = { unit:GetAbsOrigin() },
        target_entities = {},
        Radius = 200,
        Duration = tonumber(keys.Duration)
      })

      local dir = RotatePosition(Vector(0,0,0), QAngle(0,90,0), diff)
      unit:SetAbsOrigin(unit:GetAbsOrigin() + 180 * dir)
      unit2:SetAbsOrigin(unit2:GetAbsOrigin() + -180 * dir)

      local bounds = nil
      if MAP_DATA[GetMapName()] == nil then
        bounds = MAP_DATAT["default"].bounds
      else
        bounds = MAP_DATA[GetMapName()].bounds
      end

      local dist = 1500
      
      Timers:CreateTimer(tonumber(keys.Duration) - 0.3, function()
          --unit:SetModel("models/development/invisiblebox.mdl")
          --unit:SetOriginalModel("models/development/invisiblebox.mdl")
          --unit2:SetModel("models/development/invisiblebox.mdl")
          --unit2:SetOriginalModel("models/development/invisiblebox.mdl")
          unit:AddNewModifier(unit, nil, "modifier_faceless_void_chronosphere_speed", {})
          unit2:AddNewModifier(unit2, nil, "modifier_faceless_void_chronosphere_speed", {})
          
          local pos = unit:GetAbsOrigin() + diff * dist
      
          if pos.y < bounds.bottom then
            pos.y = bounds.bottom
          elseif pos.y > bounds.top then
            pos.y = bounds.top
          elseif pos.x < bounds.left then
            pos.x = bounds.left
          elseif pos.x > bounds.right then
            pos.x = bounds.right
          end

          ExecuteOrderFromTable({
            UnitIndex = unit:entindex(),
            OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
            Position = pos,
            Queue = true
          })
          
          pos = unit2:GetAbsOrigin() + diff * dist
      
          if pos.y < bounds.bottom then
            pos.y = bounds.bottom
          elseif pos.y > bounds.top then
            pos.y = bounds.top
          elseif pos.x < bounds.left then
            pos.x = bounds.left
          elseif pos.x > bounds.right then
            pos.x = bounds.right
          end

          ExecuteOrderFromTable({
            UnitIndex = unit2:entindex(),
            OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
            Position = pos,
            Queue = true
          })
        end)
      
      Timers:CreateTimer(tonumber(keys.Duration) + 1.3, function()
          unit:RemoveSelf()
          unit2:RemoveSelf()
        end)
    else
      if string.find(abilityName, "reflex_dash") ~= nil then
        caster:AddNewModifier(caster, nil, 'modifier_item_forcestaff_active', {push_length = 600})
        EmitSoundOn('DOTA_Item.ForceStaff.Activate', caster)
        return
      end
      
      local ability = caster:FindAbilityByName( abilityName )
      if ability == nil then
        caster:AddAbility(abilityName)
        ability = caster:FindAbilityByName( abilityName )
      end
      --print(ability:GetLevel())
      
      ability:SetLevel( abilityLevel )
      
      if not ability:IsFullyCastable() then
        local charges = item:GetCurrentCharges()
        item:SetCurrentCharges(charges + 1)
        return
      end
      
      --print ("[REFLEX] " ..target .. " -- " ..abilityName  .. " -- " .. tostring(point))
      --PrintTable(ability)
      if target == nil then
        caster:CastAbilityNoTarget (ability, -1 )
      elseif target == "POINT" then
        caster:CastAbilityOnPosition ( point, ability, 1 )
      else
        caster:CastAbilityOnTarget (targetEntity, ability, -1 )
      end
    end
  end
  
  --print ( '[REFLEX] removing dash ability' )
  --caster:RemoveAbility('reflex_dash')
  
  --local charges = item:GetCurrentCharges()
  --if charges ~= 0 then
  --  item:EndCooldown()
  --end
end

--[[
  "RunScript"
      {
        "ScriptFile"      "scripts/vscripts/abilities.lua"
        "Function"        "itemChargeThink"
        "Item"          "item_reflex_dash"
        "ChargeModifier"    "modifier_item_reflex_dash" // Optional for UNLINKED/ALL
        "ChargeType"      "UNLINKED"  // Optional: "UNLINKED", "HALF", "FULL", "ALL"
      }
]]
function itemChargeThink (keys)
  --print ('[REFLEX] itemChargeThink called')
  --PrintTable(keys)
  local chargeType = keys.ChargeType or "UNLINKED"
  --print ('[REFLEX] ' .. (keys.ChargeModifier or "nil") .. " -- " .. keys.Item .. " -- " .. chargeType)

  local itemName = keys.Item
  local caster = keys.caster
  local chargeModifier = keys.ChargeModifier
  
  if caster == nil or itemName == nil then
    return
  end

  local item = GameMode:GetItemByName(caster, itemName )
  if item == nil then
    return
  end 
  
  local charges = item:GetCurrentCharges()
  local maxCharges = item:GetInitialCharges()
  
  if charges + 1 <= maxCharges then
    item:SetCurrentCharges(charges + 1)
  end
  
  if chargeType == "UNLINKED" then
    
  elseif chargeType == "HALF" or chargeType == "FULL" then
    if charges + 1 < maxCharges then
      callModApplier(caster, chargeModifier)
    end
  elseif chargeType == "ALL" then
    item:SetCurrentCharges(maxCharges)
  end
  
  --item:EndCooldown()
end

channelTable = {}
channelTimeTable = {}

function itemChannelStart( keys )
  local now = GameRules:GetGameTime()
  -- print ('[REFLEX] itemChannelStart called: ' .. now)
  -- PrintTable(keys)
  
  local caster = keys.caster
  local itemName = keys.ability:GetAbilityName()
  
  if caster == nil or itemName == nil then
    return
  end
  
  local ID = tostring(caster:GetPlayerID()) .. itemName
  channelTable[ID] = now
end

function itemChannelEnd( keys )
  local now = GameRules:GetGameTime()
  --print ('[REFLEX] itemChannelEnd called: ' .. now)
  --PrintTable(keys)
  
  local caster = keys.caster
  local itemName = keys.ability:GetAbilityName()
  
  if caster == nil or itemName == nil then
    return
  end
  
  local item = keys.ability--getItemByName(caster, itemName )
  --if item == nil then
--    return
--  end
  local abilityLevel = keys.AbilityLevel or item:GetLevel()
  
  local point = nil
  if keys.target_points[1] then
    point = keys.target_points[1]
  end
  
  local targetEntity = nil
  if keys.target_entities[1] then
    targetEntity = keys.target_entities[1]
  end
  if target == "CASTER" then
    targetEntity = caster
  end
  
  local ID = tostring(caster:GetPlayerID()) .. itemName
  
  local start = channelTable[ID]
  channelTable[ID] = nil
  
  if start == nil then
    start = now + 0.3
  end
  
  local channelTime = now - start
  channelTimeTable[ID] = channelTime
  
  if string.find(itemName, "item_reflex_meteor_cannon") ~= nil then
    itemMeteorCannon(channelTime, point, keys.ability, caster)
  end
end

STEALABLE_MODIFIERS = {
  modifier_reflex_vengeance_1 = "reflex_vengeance_1",
  modifier_reflex_vengeance_2 = "reflex_vengeance_2",
  modifier_reflex_vengeance_3 = "reflex_vengeance_3",
  modifier_reflex_vengeance_4 = "reflex_vengeance_4",
  modifier_reflex_scaredy_cat_1 = "reflex_scaredy_cat_1",
  modifier_reflex_scaredy_cat_2 = "reflex_scaredy_cat_2",
  modifier_reflex_scaredy_cat_3 = "reflex_scaredy_cat_3",
  modifier_reflex_scaredy_cat_4 = "reflex_scaredy_cat_4",
  modifier_item_shield_1 = "reflex_holy_shield_1",
  modifier_item_shield_2 = "reflex_holy_shield_2",
  modifier_item_shield_3 = "reflex_holy_shield_3",
  modifier_item_shield_4 = "reflex_holy_shield_4"
}

function projectileHit(keys)
  --PrintTable(keys)
  local caster = keys.caster
  local ability = keys.ability
  local projectiles = vPlayerProjectiles[caster:GetPlayerID()]
  local dummies = vPlayerDummies[caster:GetPlayerID()]
  local projID = projectiles[ability:GetAbilityName()]
  local dummy = dummies[ability:GetAbilityName()]
  
  local targetEntity = keys.target_entities[1]
  if caster == nil or targetEntity == nil or targetEntity == caster then
    return
  end

  Timers:RemoveTimer(caster.gripTimer)
    
  ProjectileManager:DestroyLinearProjectile(projID)
  
  if targetEntity:GetTeamNumber() ~= caster:GetTeamNumber() then
    local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_zuus/zuus_static_field.vpcf", PATTACH_ABSORIGIN_FOLLOW, targetEntity)
    ParticleManager:SetParticleControl(particle, 0, Vector(0,0,0))
    ParticleManager:SetParticleControl(particle, 1, Vector(0,0,0)) -- radius, thickness, speed
    ParticleManager:ReleaseParticleIndex(particle)
    
    targetEntity:EmitSound("Hero_Zuus.StaticField")
    targetEntity:SetModelScale(targetEntity.originalModelScale)--, 1)
    
    if targetEntity:HasModifier("modifier_faceless_void_chronosphere_speed") then
      targetEntity:RemoveModifierByName("modifier_faceless_void_chronosphere_speed")
      callModRemover(targetEntity, "reflex_charge_turn")
      
      caster:AddNewModifier(caster, nil, "modifier_faceless_void_chronosphere_speed", {duration = 2.5})
      callModApplier(caster, "reflex_charge_turn")
    end
    for k,v in pairs(STEALABLE_MODIFIERS) do
      if targetEntity:HasModifier(k) then
        --Remove mod
        callModRemover(targetEntity, k)
        
        --Add mod
        callModApplier(caster, k)
      end
    end
    return
  end
  
  --local dummy = CreateUnitByName("npc_reflex_dummy_grip", caster:GetAbsOrigin(), false, caster, caster, caster:GetTeamNumber())
  --dummy:FindAbilityByName("reflex_dummy_unit"):SetLevel(1)
  --dummy:AddNewModifier(dummy, nil, "modifier_phased", {})
  
  local grip = dummy:FindAbilityByName("reflex_grip")
  grip:SetLevel(ability:GetLevel())
  local burst = dummy:FindAbilityByName("reflex_magnetic_burst")
  burst:SetLevel(ability:GetLevel())
  
  local diff = targetEntity:GetAbsOrigin() - dummy:GetAbsOrigin()
  diff.z = 0
  dummy:SetAbsOrigin(caster:GetAbsOrigin())
  dummy:SetForwardVector(diff:Normalized())
  
  local point = targetEntity:GetAbsOrigin()
  --dummy:SetCursorCastTarget(targetEntity)
  --grip:OnSpellStart()
  dummy:CastAbilityOnTarget(targetEntity, grip, 0 )
  
  dummy:CastAbilityOnPosition(point, burst, 0)
  
  --particles/reflex_particles/nian_roar_prj_gasexplode_shockwave.vpcf
  local particle = ParticleManager:CreateParticle("particles/frostivus_gameplay/frostivus_throne_wraith_king_explode.vpcf", PATTACH_POINT_FOLLOW, targetEntity)
  ParticleManager:SetParticleControl(particle, 0, targetEntity:GetAbsOrigin())--Vector(0,0,0))
  ParticleManager:SetParticleControl(particle, 1, Vector(100,5,1)) -- radius, thickness, speed
  ParticleManager:SetParticleControl(particle, 3, targetEntity:GetAbsOrigin()) -- position
  ParticleManager:ReleaseParticleIndex(particle)
  
  Timers:CreateTimer(5, function()
      --dummy:CastAbilityOnTarget(caster, grip, 0 )
      if IsValidEntity(dummy) then
        dummy:RemoveSelf()
        dummy = nil
      end
    end)
  
end
--[["Target"        "POINT"
        "EffectName"      "nian_roar_projectile_no_explode"
        "MoveSpeed"       "%speed"
        "StartPosition"     "attach_attack1"
        "FixedDistance"   "%distance"
        "StartRadius"     "%radius"
        "EndRadius"       "%radius"
        "TargetTeams"     "DOTA_UNIT_TARGET_TEAM_FRIENDLY"
        "TargetTypes"     "DOTA_UNIT_TARGET_HERO"
        "TargetFlags"     "DOTA_UNIT_TARGET_FLAG_NONE"
        "ExcludeFlags"    "DOTA_UNIT_TARGET_FLAG_PLAYER_CONTROLLED"
        "HasFrontalCone"    "0"
        "ProvidesVision"    "0"
        "VisionRadius"      "0"]]


function makeForwardProjectile(keys)
  --PrintTable(keys)
  local caster = keys.caster
  local ability = keys.ability
  local origin = caster:GetOrigin()
  origin.z = origin.z + 60
  local projectiles = vPlayerProjectiles[caster:GetPlayerID()]
  if projectiles == nil then
    projectiles = {}
    vPlayerProjectiles[caster:GetPlayerID()] = projectiles
  end
  
  local info = {
    EffectName = keys.EffectName,
    Ability = ability,
    vSpawnOrigin = caster:GetAbsOrigin(),
    fDistance = tonumber(keys.FixedDistance),
    fStartRadius = tonumber(keys.StartRadius),
    fEndRadius = tonumber(keys.EndRadius),
    Source = caster,
    bHasFrontalCone = false,
    iMoveSpeed = tonumber(keys.MoveSpeed),
    bReplaceExisting = true,
    iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
    iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
    iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
    --iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_FRIENDLY,
    --iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
    --iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC + DOTA_UNIT_TARGET_OTHER,
    --fMaxSpeed = 5200,
    fExpireTime = GameRules:GetGameTime() + 8.0,
  }
  
  --print ('0-------------0')
  --PrintTable(info)
  --print ('0--------------0')
  local speed = keys.MoveSpeed
  
  info.vVelocity = caster:GetForwardVector() * speed
  
  projectiles[ability:GetAbilityName()] = ProjectileManager:CreateLinearProjectile( info )
end        

function makeProjectile(keys)
  --PrintTable(keys)
  local caster = keys.caster
  local ability = keys.ability
  local origin = caster:GetOrigin()
  origin.z = origin.z + 60
  local projectiles = vPlayerProjectiles[caster:GetPlayerID()]
  if projectiles == nil then
    projectiles = {}
    vPlayerProjectiles[caster:GetPlayerID()] = projectiles
  end
  
  local dummies = vPlayerDummies[caster:GetPlayerID()]
  if dummies == nil then
    dummies = {}
    vPlayerDummies[caster:GetPlayerID()] = dummies
  end 
  
  local info = {
    EffectName = keys.EffectName,
    Ability = ability,
    vSpawnOrigin = caster:GetAbsOrigin(),
    fDistance = tonumber(keys.FixedDistance),
    fStartRadius = tonumber(keys.StartRadius),
    fEndRadius = tonumber(keys.EndRadius),
    Source = caster,
    bHasFrontalCone = false,
    iMoveSpeed = tonumber(keys.MoveSpeed),
    bReplaceExisting = true,
    iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_BOTH,
    iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
    iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
    --iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_FRIENDLY,
    --iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
    --iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC + DOTA_UNIT_TARGET_OTHER,
    --fMaxSpeed = 5200,
    fExpireTime = GameRules:GetGameTime() + 8.0,
  }
  
  --print ('0-------------0')
  --PrintTable(info)
  --print ('0--------------0')
  local speed = keys.MoveSpeed
  
  local point = keys.target_points[1]
  point.z = 0
  local pos = caster:GetAbsOrigin()
  pos.z = 0
  --print ('[REFLEX] ' .. tostring(pos))
  local diff = point - pos
  
  info.vVelocity = diff:Normalized() * speed
  
  local dummy = CreateUnitByName("npc_reflex_dummy_grip", caster:GetAbsOrigin(), false, nil, nil, caster:GetTeamNumber())
  dummy:FindAbilityByName("reflex_dummy_unit"):SetLevel(1)
  dummy:AddNewModifier(dummy, nil, "modifier_phased", {})
  
  caster.gripTimer = Timers:CreateTimer(5, function()
      --dummy:CastAbilityOnTarget(caster, grip, 0 )
      print('removing dummy')
      if IsValidEntity(dummy) then
        dummy:RemoveSelf()
        dummy = nil
      end
    end)
  
  dummies[ability:GetAbilityName()] = dummy
  projectiles[ability:GetAbilityName()] = ProjectileManager:CreateLinearProjectile( info )
end

function itemMeteorCannon( channelTime, point, item , caster)
  --print ('[REFLEX] itemMeteorCannon called: ' .. channelTime .. " -- point: " .. tostring(point) .. " -- item: " ..item:GetAbilityName())
  
  local info = {
    EffectName = "particles/units/heroes/hero_invoker/invoker_chaos_meteor.vpcf",
    Ability = item,
    vSpawnOrigin = caster:GetOrigin(),
    fDistance = 5000,
    fStartRadius = 125,
    fEndRadius = 125,
    Source = caster,
    bHasFrontalCone = false,
    iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
    iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
    iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC + DOTA_UNIT_TARGET_OTHER,
    --fMaxSpeed = 5200,
    fExpireTime = GameRules:GetGameTime() + 8.0,
  }

  local speed = tonumber(item:GetSpecialValueFor("speed")) + (item:GetLevel() - 1) * 100 --1000
  --print ('[REFLEX] Meteor Speed: ' .. tostring(speed))
  --print ('[REFLEX] ' .. tostring(point))
  --PrintTable(point)
  --PrintTable(getmetatable(point)) 
  -- caster:GetAngles() .y is angle with 270 being straight down i think
  --local angles = caster:GetAngles()
  --print ('[REFLEX] ' .. tostring(angles))
  --PrintTable(angles)
  --PrintTable(getmetatable(angles))
  
  -- x pos is left
  -- y pos is down
  
  point.z = 0
  local pos = caster:GetAbsOrigin()
  pos.z = 0
  --print ('[REFLEX] ' .. tostring(pos))
  local diff = point - pos
  --print ('[REFLEX] ' .. tostring(diff))
  
  --point = point:Normalized()
  info.vVelocity = diff:Normalized() * speed * channelTime
  --info.vVelocity = point:Normalized() * speed * channelTime--( RotatePosition( Vec3( 0, 0, 0 ), angle, Vec3( 1, 0, 0 ) ) ) * speed
  --info.vAcceleration = info.vVelocity * -0.15

  local proj = ProjectileManager:CreateLinearProjectile( info )
end

function itemApplyChannelDamage(keys)
  --print('[REFLEX] itemApplyChannelDamage')
  --PrintTable(keys)
  
  local now = GameRules:GetGameTime()
  
  local caster = keys.caster
  local itemName = keys.ability:GetAbilityName()
  
  if caster == nil or itemName == nil or keys.target == nil then
    return
  end
  
  local item = keys.ability
  
  local ID = tostring(caster:GetPlayerID()) .. itemName
  
  local channelTime = channelTimeTable[ID]
  if channelTime == nil then
    channelTime = 0.3
  end
  --print(channelTime)
  
  local damage = item:GetSpecialValueFor("damage") + (item:GetLevel() - 1) * 40
  local minDamage = damage / 2
  --print('[REFLEX] meteoer damage: ' .. damage)
  local mult = channelTime / 1.5
  if mult > 1 then
    mult = 1
  end
  
  damage = mult * (minDamage) + minDamage
  print('[REFLEX] meteor damage: ' .. damage)
  
  dealDamage(caster, keys.target, damage)
  --keys.target:AddNewModifier(caster, nil, "modifier_kunkka_ghost_ship_damage_delay", {damage = damage, duration = 1})--, duration = 0})
  --keys.target:AddNewModifier(caster, nil, "modifier_item_orb_of_venom_slow", {damage = damage, slow = 0, duration = 1})--, duration = 0})
  --keys.target:AddNewModifier(caster, nil, "modifier_invoker_chaos_meteor_burn", {burn_dps = damage, freeze_damage = damage, damage = damage, hero_slow_duration = 2, duration = 1})--, duration = 0})
  --keys.target:AddNewModifier(caster, nil, "modifier_invoker_chaos_meteor_burn", {burn_dps = damage, freeze_damage = damage, damage = damage, hero_slow_duration = 2, duration = 1})--, duration = 0})
  --keys.target:AddNewModifier(caster, nil, "modifier_roshan_halloween_apocalypse", {damage = damage, duration = 0})
  --keys.target:AddNewModifier(caster, nil, "modifier_invoker_tornado", {land_damage = damage, duration = 0} )
end