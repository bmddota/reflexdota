print ('[REFLEX] reflex.lua' )

USE_LOBBY=true
DEBUG=false
THINK_TIME = 0.1

REFLEX_VERSION = "0.05.11"

ROUNDS_TO_WIN = 8
ROUND_TIME = 150 --240
PRE_GAME_TIME = 30 -- 30
PRE_ROUND_TIME = 30 --30
POST_ROUND_TIME = 2
POST_GAME_TIME = 30

STARTING_GOLD = 500--650
GOLD_PER_ROUND_LOSER = 1250--750
GOLD_PER_ROUND_WINNER = 1250--1100
GOLD_PER_KILL = 200
GOLD_PER_MVP = 500
GOLD_PER_SURVIVE = 250
GOLD_TIME_BONUS_1 = 250
GOLD_TIME_BONUS_2 = 150
GOLD_TIME_BONUS_3 = 100

LEVELS_PER_ROUND_LOSER = 2.5 -- 2
LEVELS_PER_ROUND_WINNER = 1.25 -- 1
MAX_LEVEL = 50

MAX_TIPS = 21
TIP_TIMEOUT = 2

XP_PER_LEVEL_TABLE = {}

for i=1,MAX_LEVEL do
  XP_PER_LEVEL_TABLE[i] = i * 100
end

MAP_DATA = {
  reflex = {
    bounds = {
      left = -2700,
      right = 2700,
      bottom = -2260,
      top = 2140
    }
  },
  glacier = {
    bounds = {
      left = -2760,
      right = 2760,
      bottom = -2300,
      top = 2200
    }
  }
}

ADDED_ABILITIES = {
  "reflex_dash",
  "reflex_sun_strike",
  "reflex_illuminate_1",
  "reflex_illuminate_2",
  "reflex_illuminate_3",
  "reflex_illuminate_4",
  "reflex_mystic_flare",
  "reflex_earthbind"
}

ABILITY_ON_DEATH = {
  reflex_vengeance = 1.50,
  reflex_scaredy_cat = 0.6
}

bInPreRound = true
roundOne = true

ABILITY_ITEM_TABLE = {
  reflex_haste = 0,
  reflex_phase_shift = 0,
  reflex_power_cogs = 0,
  reflex_kinetic_field = 0,
  reflex_borrowed_time = 0,
  reflex_power_shot = 0,
  reflex_flame_breath = 0,
  reflex_wisp_spirits = 0,
  reflex_energy_drain = 0,
  reflex_magnetic_orb = 0,
  reflex_flame_sword = 0,
  reflex_bristleback = 1,
  reflex_hp_boost = 1,
  reflex_energy_boost = 1,
  reflex_energy_regen_boost = 1,
  reflex_bulk_up = 1,
  reflex_vengeance = 1,
  reflex_scaredy_cat = 1
}


if ReflexGameMode == nil then
  print ( '[REFLEX] creating reflex game mode' )
  ReflexGameMode = {}
  ReflexGameMode.szEntityClassName = "reflex"
  ReflexGameMode.szNativeClassName = "dota_base_game_mode"
  ReflexGameMode.__index = ReflexGameMode
end

function ReflexGameMode:new( o )
  print ( '[REFLEX] ReflexGameMode:new' )
  o = o or {}
  setmetatable( o, ReflexGameMode )
  return o
end

function ReflexGameMode:InitGameMode()
  print('[REFLEX] Starting to load Reflex gamemode...')

  -- Setup rules
  GameRules:SetHeroRespawnEnabled( false )
  GameRules:SetUseUniversalShopMode( true )
  GameRules:SetSameHeroSelectionEnabled( false )
  GameRules:SetHeroSelectionTime( 30.0 )
  GameRules:SetPreGameTime( PRE_ROUND_TIME + PRE_GAME_TIME)
  GameRules:SetPostGameTime( 60.0 )
  GameRules:SetTreeRegrowTime( 60.0 )
  GameRules:SetUseCustomHeroXPValues ( true )
  GameRules:SetGoldPerTick(0)
  print('[REFLEX] Rules set')

  InitLogFile( "log/reflex.txt","")

  -- Hooks
  ListenToGameEvent('entity_killed', Dynamic_Wrap(ReflexGameMode, 'OnEntityKilled'), self)
  --ListenToGameEvent('dota_player_kill', Dynamic_Wrap(ReflexGameMode, 'OnPlayerKilled'), self)
  print('[REFLEX] entity_killed event set')
  ListenToGameEvent('player_connect_full', Dynamic_Wrap(ReflexGameMode, 'AutoAssignPlayer'), self)
  ListenToGameEvent('player_disconnect', Dynamic_Wrap(ReflexGameMode, 'CleanupPlayer'), self)
  ListenToGameEvent('dota_item_purchased', Dynamic_Wrap(ReflexGameMode, 'ShopReplacement'), self)
  ListenToGameEvent('player_say', Dynamic_Wrap(ReflexGameMode, 'PlayerSay'), self)
  ListenToGameEvent('player_connect', Dynamic_Wrap(ReflexGameMode, 'PlayerConnect'), self)
  --ListenToGameEvent('dota_inventory_changed', Dynamic_Wrap(ReflexGameMode, 'InventoryChanged'), self)
  --ListenToGameEvent('dota_inventory_item_changed', Dynamic_Wrap(ReflexGameMode, 'InventoryItemChanged'), self)
  --ListenToGameEvent('dota_action_item', Dynamic_Wrap(ReflexGameMode, 'ActionItem'), self)
  
  ------
  --ListenToGameEvent('player_info', Dynamic_Wrap(ReflexGameMode, 'PlayerInfo'), self)
  --ListenToGameEvent('dota_player_used_ability', Dynamic_Wrap(ReflexGameMode, 'AbilityUsed'), self)

  local function _boundWatConsoleCommand(...)
    return self:_WatConsoleCommand(...)
  end
  Convars:RegisterCommand( "reflex_wat", _boundWatConsoleCommand, "Report the status of Reflex", 0 )
  print('[REFLEX] reflex_wat set')

  Convars:RegisterCommand('reflex_reset_all', function()
    if not Convars:GetCommandClient() or DEBUG then      
      self:LoopOverPlayers(function(player, plyID)
        print ( '[REFLEX] Resetting player ' .. plyID)
        --PlayerResource:SetGold(plyID, 30000, true)
        player.hero:SetGold(30000, true)
        player.hero:AddExperience(1000, true)

        --Remove dangerous abilities
        for i=1,#ADDED_ABILITIES do
          local ability = ADDED_ABILITIES[i]
          self:FindAndRemove(player.hero, ability)
        end

        if player.hero:HasModifier("modifier_stunned") then
          player.hero:RemoveModifierByName("modifier_stunned")
        end

        if player.hero:HasModifier("modifier_invulnerable") then
          player.hero:RemoveModifierByName("modifier_invulnerable")
        end

        for i=0,11 do
          local item = player.hero:GetItemInSlot( i )
          if item ~= nil then
            local name = item:GetAbilityName()
            if string.find(name, "item_reflex_dash") == nil and string.find(name, "item_simple_shooter") == nil then
              item:Remove()
            end
            --item:SetCurrentCharges(item:GetInitialCharges())
          end
        end
      end)
    end
  end, 'Resets all players.', 0)
  
  -- Fill server with fake clients
  Convars:RegisterCommand('fake', function()
    -- Check if the server ran it
    if not Convars:GetCommandClient() or DEBUG then
      -- Create fake Players
      SendToServerConsole('dota_create_fake_clients')
      
      local fakes = {
        "npc_dota_hero_ancient_apparition",
        "npc_dota_hero_antimage",
        "npc_dota_hero_bane",
        "npc_dota_hero_beastmaster",
        "npc_dota_hero_bloodseeker",
        "npc_dota_hero_chen",
        "npc_dota_hero_crystal_maiden",
        "npc_dota_hero_dark_seer",
        "npc_dota_hero_dazzle",
        "npc_dota_hero_dragon_knight",
        "npc_dota_hero_doom_bringer"
      }
        
      self:CreateTimer('assign_fakes', {
        endTime = Time(),
        callback = function(reflex, args)
          local userID = 20
          for i=0, 9 do
            userID = userID + 1
            -- Check if this player is a fake one
            if PlayerResource:IsFakeClient(i) then
              -- Grab player instance
              local ply = PlayerResource:GetPlayer(i)
              -- Make sure we actually found a player instance
              if ply then
                CreateHeroForPlayer(fakes[i], ply)
                self:AutoAssignPlayer({
                  userid = userID,
                  index = ply:entindex()-1
                })
              end
            end
          end
          
          local ply = Convars:GetCommandClient()
          local plyID = ply:GetPlayerID()
          local hero = ply:GetAssignedHero()
          for k,v in pairs(HeroList:GetAllHeroes()) do
            if v ~= hero then
              v:SetControllableByPlayer(plyID, true)
              local dash = CreateItem("item_reflex_dash", v, v)
              v:AddItem(dash)
              local shooter = CreateItem("item_simple_shooter", v, v)
              v:AddItem(shooter)
            end
          end
        end})
    end
  end, 'Connects and assigns fake Players.', 0)
  
  Convars:RegisterCommand('reflex_test_death', function()
    local cmdPlayer = Convars:GetCommandClient()
    if DEBUG and cmdPlayer ~= nil then
      local playerID = cmdPlayer:GetPlayerID()
      local player = self.vPlayers[playerID]
      for onDeath,scale in pairs(ABILITY_ON_DEATH) do
        local ability = player.hero:FindAbilityByName(onDeath)
        --print('     ' .. onDeath .. ' -- ' .. tostring(ability or 'NOPE'))
        if ability ~= nil and ability:GetLevel() ~= 0 then
          callModApplier(player.hero, onDeath, ability:GetLevel())
          print(tostring(1 + ((scale - 1) * (ability:GetLevel() / 4))))
          print(tostring(ability:GetSpecialValueFor("duration")) + (ability:GetLevel() - 1))
          player.hero:SetModelScale(1 + ((scale - 1) * (ability:GetLevel() / 4)), 1)
          self:CreateTimer('resetScale' .. playerID,{
            endTime = GameRules:GetGameTime() + ability:GetSpecialValueFor("duration") + (ability:GetLevel() - 1),
            useGameTime = true,
            callback = function() 
              player.hero:SetModelScale(1, 1)
            end})
        end
      end
    end
  end, 'Tests the death function', 0)
  
  Convars:RegisterCommand('reflex_test_round_complete', function()
    local cmdPlayer = Convars:GetCommandClient()
    if DEBUG then
      self:RoundComplete(true)
    end
  end, 'Tests the death function', 0)

  -- Change random seed
  local timeTxt = string.gsub(string.gsub(GetSystemTime(), ':', ''), '0','')
  math.randomseed(tonumber(timeTxt))

  self.nRadiantScore = 0
  self.nDireScore = 0
  self.nConnected = 0

  -- Round stuff
  self.nCurrentRound = 1
  self.nRadiantDead = 0
  self.nDireDead = 0
  self.nLastKilled = nil
  self.fRoundStartTime = 0

  -- Timers
  self.timers = {}
  
  -- Tip stuff
  self.bTipsActive = false
  self.nLastTipTime = 0

  -- userID map
  self.vUserNames = {}
  self.vUserIds = {}
  self.vSteamIds = {}
  self.vBots = {}
  self.vBroadcasters = {}

  self.vPlayers = {}
  self.vRadiant = {}
  self.vDire = {}

  -- Active Hero Map
  self.vPlayerHeroData = {}
  self.bPlayersInit = false
  print('[REFLEX] values set')

  print('[REFLEX] Precaching stuff...')
  PrecacheUnitByName('npc_precache_everything')
  print('[REFLEX] Done precaching!') 

  self.thinkState = Dynamic_Wrap( ReflexGameMode, '_thinkState_Prep' )

  print('[REFLEX] Done loading Reflex gamemode!\n\n')
end

GameMode = nil

function ReflexGameMode:CaptureGameMode()
  if GameMode == nil then
    print('[REFLEX] Capturing game mode...')
    GameMode = GameRules:GetGameModeEntity()		
    GameMode:SetRecommendedItemsDisabled( true )
    GameMode:SetCameraDistanceOverride( 1504.0 )
    GameMode:SetCustomBuybackCostEnabled( true )
    GameMode:SetCustomBuybackCooldownEnabled( true )
    GameMode:SetBuybackEnabled( false )
    GameMode:SetUseCustomHeroLevels ( true )
    GameMode:SetCustomHeroMaxLevel ( MAX_LEVEL )
    GameMode:SetTopBarTeamValuesOverride ( true )
    GameMode:SetRemoveIllusionsOnDeath( false )

    GameRules:SetHeroMinimapIconSize( 300 )

    GameMode:SetCustomXPRequiredToReachNextLevel( XP_PER_LEVEL_TABLE )

    print( '[REFLEX] Beginning Think' ) 
    GameMode:SetContextThink("ReflexThink", Dynamic_Wrap( ReflexGameMode, 'Think' ), 0.1 )
  end
end

--[[function ReflexGameMode:AbilityUsed(keys)
  print('[REFLEX] AbilityUsed')
  PrintTable(keys)
  PrintTable(getmetatable(keys))
  
  local ent = Entities:First()
  repeat
    print('\t[REFLEX] ENTName: ' .. tostring(ent:GetName()) .. " -- ClassName: " .. tostring(ent:GetClassname()) .. " -- entindex: " .. tostring(ent:entindex()))
    PrintTable(ent)
    PrintTable(getmetatable(ent))
    ent = Entities:Next(ent)
  until ent == nil
end]]

-- Cleanup a player when they leave
function ReflexGameMode:CleanupPlayer(keys)
  print('[REFLEX] Player Disconnected ' .. tostring(keys.userid))
  self.nConnected = self.nConnected - 1
end

function ReflexGameMode:ActionItem(keys)
  print('ActionItem')
  PrintTable(keys)
  PrintTable(getmetatable(keys))
end

function ReflexGameMode:InventoryItemChanged(keys)
  print('InventoryItemChanged')
  PrintTable(keys)
  PrintTable(getmetatable(keys))
end

function ReflexGameMode:InventoryChanged(keys)
  print('InventoryChanged')
  PrintTable(keys)
  PrintTable(getmetatable(keys))
end

function ReflexGameMode:CloseServer()
  -- Just exit
  --SendToServerConsole('exit')
end

function ReflexGameMode:PlayerConnect(keys)
  --print('[REFLEX] PlayerConnect')
  --PrintTable(keys)
  self.vUserNames[keys.userid] = keys.name
  if keys.bot == 1 then
    self.vBots[keys.userid] = 1
  end
end

local hook = nil
local attach = 0
local controlPoints = {}
local particleEffect = ""
local abilPoints = false
local particle = nil
local paused = nil
local unitNum = 0
local units = {}

function ReflexGameMode:PlayerSay(keys)
  --print ('[REFLEX] PlayerSay')
  --PrintTable(keys)
  
  local ply = self.vUserIds[keys.userid]
  if ply == nil then
    return
  end
  
  local plyID = ply:GetPlayerID()
  if not PlayerResource:IsValidPlayer(plyID) then
    return
  end
  
  local player = self.vPlayers[plyID]
  if player == nil then
    return
  end
  
  -- Should have a valid, in-game player saying something at this points/gold
  local text = keys.text
  local matchA, matchB = string.match(text, "^-swap%s+(%d)%s+(%d)")
  
  if matchA ~= nil and matchB ~= nil then
    -- Found a match, let's do the ability swap
    --print('[REFLEX] matches: ' .. tostring(matchA) .. '  --  ' .. tostring(matchB))
    local a = tonumber(matchA)
    local b = tonumber(matchB)
    --print('[REFLEX] a: ' .. a .. "    -- b: " .. b)
    
    if a > 6 or a < 1 or b > 6 or b < 1 or a == b then
      -- Invalid Swap values provided
      return
    end
    
    local abilityA = player.vAbilities[a]
    local levelA = player.hero:FindAbilityByName(abilityA):GetLevel()
    local abilityB = player.vAbilities[b]
    local levelB = player.hero:FindAbilityByName(abilityB):GetLevel()
    
    player.hero:RemoveAbility(abilityA)
    player.hero:RemoveAbility(abilityB)
    
    -- Place emptys back with the correct index name value for ShopReplacement functionality
    if string.find(abilityA, "reflex_empty") then
      abilityA = "reflex_empty" .. b
    end
    if string.find(abilityB, "reflex_empty") then
      abilityB = "reflex_empty" .. a
    end
    
    if a < b then
      --Add B first
      player.hero:AddAbility(abilityB)
      player.hero:AddAbility(abilityA)
    else
      --Add A first
      player.hero:AddAbility(abilityA)
      player.hero:AddAbility(abilityB)
    end
    
    player.hero:FindAbilityByName(abilityA):SetLevel(levelA)
    player.hero:FindAbilityByName(abilityB):SetLevel(levelB)
    
    player.vAbilities[a] = abilityB
    player.vAbilities[b] = abilityA
    
    return
  end
  
  if string.find(text, "^-dmg") then
    if string.find(text, "all") then
      local team = player.nTeam
      self:LoopOverPlayers(function(player, plyID)
        if player.nTeam == team then
          local name = player.name
          local total = PlayerResource:GetRawPlayerDamage(plyID)
          local roundDamage = player.nRoundDamage
          Say(ply, " _ " .. name .. ":  Last Round: " .. roundDamage .. "  --  Total: " .. total, true)
        end
      end)
    else
      local name = player.name
      local total = PlayerResource:GetRawPlayerDamage(plyID)
      local roundDamage = player.nRoundDamage
      Say(ply, " _ " .. name .. ":  Last Round: " .. roundDamage .. "  --  Total: " .. total, true)
    end
  end
  
  if DEBUG and string.find(text, "-reset") then
    for k,v in pairs(HeroList:GetAllHeroes()) do
      if v ~= player.hero then
        for k2,ab in pairs(player.vAbilities) do
          v:RemoveAbility(ab)
        end
        for k2,ab in pairs(player.vAbilities) do
          v:AddAbility('reflex_empty' .. k2)
        end
      end
    end
    
    for k2,ab in pairs(player.vAbilities) do
      player.hero:RemoveAbility(ab)
    end
    for k2,ab in pairs(player.vAbilities) do
      player.hero:AddAbility('reflex_empty' .. k2)
    end
    player.vAbilities = {
      "reflex_empty1",
      "reflex_empty2",
      "reflex_empty3",
      "reflex_empty4",
      "reflex_empty5",
      "reflex_empty6"
    }
  end
  
  if string.find(text, "^-mod") and DEBUG then
    local m = string.match(text, "(%d)")
    if m ~= nil then
      local p = PlayerResource:GetPlayer(tonumber(m))
      local v = p:GetAssignedHero()
      callModApplier(v, "reflex_vengeance", 2)
      callModApplier(v, "reflex_scaredy_cat", 3)
      callModApplier(v, "reflex_holy_shield", 4)
      v:AddNewModifier(v,nil,"modifier_faceless_void_chronosphere_speed", {duration = 2.5})
      callModApplier(v, "reflex_charge_turn")
    else 
      for k,v in pairs(HeroList:GetAllHeroes()) do
        if v ~= player.hero then
          callModApplier(v, "reflex_vengeance", 2)
          callModApplier(v, "reflex_scaredy_cat", 3)
          callModApplier(v, "reflex_holy_shield", 4)
          v:AddNewModifier(v,nil,"modifier_faceless_void_chronosphere_speed", {duration = 2.5})
          callModApplier(v, "reflex_charge_turn")
        end
      end
    end
  end
  
  if string.find(text, "^-colorblind") then
    player.bColorblind = not player.bColorblind
  end
  
  if string.find(text, "^-curveshot") and DEBUG then
    local hero = player.hero
    
    local targetEntity = nil
  
    targetEntity = CreateUnitByName("npc_dota_danger_indicator", Vector(0,0,128), false, nil, nil, DOTA_TEAM_NOTEAM)
    targetEntity:AddNewModifier(unit, nil, "modifier_invulnerable", {})
    targetEntity:AddNewModifier(unit, nil, "modifier_phased", {})
    
    local info = {
      EffectName = "magnataur_shockwave", --"obsidian_destroyer_arcane_orb", --,
      Ability = self:getItemByName(hero, "item_reflex_meteor_cannon"),
      vSpawnOrigin = hero:GetOrigin(),
      fDistance = 5000,
      fStartRadius = 125,
      fEndRadius = 125,
      --Target = targetEntity,
      Source = hero,
      iMoveSpeed = 500,
      bReplaceExisting = true,
      bHasFrontalCone = false,
      iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
      iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
      iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC + DOTA_UNIT_TARGET_OTHER,
      --fMaxSpeed = 5200,
      fExpireTime = GameRules:GetGameTime() + 10.0,
    }
    
    --info.vAcceleration
    --APM:CreateProjectile(info, hero:GetAbsOrigin(), Vector(0,0,0), 600)
    APM:CreateCurvedProjectile(info, hero:GetAbsOrigin(), Vector(0,0,0), 15, 0.2, 10, 2000)
    --ProjectileManager:CreateTrackingProjectile(info)
  end
  
  
  if string.find(text, "^-tip") then
    local tip1 = string.match(text, "(%d+)")
    if tip1 == nil then
      tip1 = RandomInt(1, MAX_TIPS)
      
    else
      tip1 = tonumber(tip1)
      if tip1 > MAX_TIPS then
        tip1 = MAX_TIPS
      end
      if tip1 < 1 then
        tip1 = 1
      end
    end
    
    local nTime = Time() - TIP_TIMEOUT
    if self.bTipsActive and nTime > self.nLastTipTime then
      GameRules:SendCustomMessage("#Reflex_Tip" .. tip1, 0, 0)
      self.nLastTipTime = Time()
    end
  end
  
  local lvl1 = string.match(text, "^-lvl%s+(%d+)")
  if DEBUG and lvl1 ~= nil then
    local num = tonumber(lvl1)
    for k,v in pairs(HeroList:GetAllHeroes()) do
      for i=1,num do
        v:HeroLevelUp(false)
      end
    end
  end
  
  local ap = abilPoints
  
  if DEBUG and string.find(text, "^-points") then
    for k,v in pairs(HeroList:GetAllHeroes()) do
      if ap then
        abilPoints = false
        v:SetAbilityPoints(0)
      else
        abilPoints = true
        v:SetAbilityPoints(25)
      end
    end
  end
  
  if DEBUG and string.find(text, "^-res") then
    local m = string.match(text, "(%d)")
    if m ~= nil then
      local p = PlayerResource:GetPlayer(tonumber(m))
      local v = p:GetAssignedHero()
      v:SetRespawnPosition(v:GetAbsOrigin())
      v:RespawnHero(false, false, false)
    else 
      for k,v in pairs(HeroList:GetAllHeroes()) do
        if not v:IsAlive() then
          v:SetRespawnPosition(v:GetAbsOrigin())
          v:RespawnHero(false, false, false)
        end
      end
    end
  end

  local mDam = string.match(text, "^-dam%s(%d+)")
  if DEBUG and mDam ~= nil then
    local dam = tonumber(mDam)
    for k,v in pairs(HeroList:GetAllHeroes()) do
      if v ~= player.hero then
        dealDamage(player.hero, v, dam)
      end
    end
  end
  
  if DEBUG and string.find(text, "^-units") then
    local m = string.match(text, "(%d+)")
    if m ~= nil then
      unitNum = unitNum + m
      print (unitNum)
      for i=1,m do 
        local unit = CreateUnitByName('npc_dummy_blank', player.hero:GetAbsOrigin(), true, player.hero, player.hero, player.hero:GetTeamNumber())
        unit:AddNewModifier(unit, nil, "modifier_phased", {})
        unit:SetModel('models/heroes/lycan/lycan_wolf.mdl')
        unit:SetOriginalModel('models/heroes/lycan/lycan_wolf.mdl')
        
        Physics:Unit(unit)
        unit:SetPhysicsFriction(0)
        unit:SetPhysicsVelocity(RandomVector(2000))
        unit:SetNavCollisionType(PHYSICS_NAV_BOUNCE)
      end
    end
  end
  
  if DEBUG and string.find(text, "^-entprint") then
    local m = string.match(text, "(%d+)")
    if m == nil then
      local ent = Entities:First()
      while ent ~= nil do
        print(tostring(ent:entindex()) .. " -- " .. ent:GetClassname() .. " -- " .. ent:GetName())
        ent = Entities:Next(ent)
      end
    else
      local ent = Entities:FindInSphere(nil, player.hero:GetAbsOrigin(), tonumber(m))
      while ent ~= nil do
        print(tostring(ent:entindex()) .. " -- " .. ent:GetClassname() .. " -- " .. ent:GetName())
        ent = Entities:FindInSphere(ent, player.hero:GetAbsOrigin(), tonumber(m))
      end
    end
  end

  if DEBUG and string.find(text, "^-plyprint") then
    for i=-1,32 do
      local valid = "valid"
      local teamvalid = "teamvalid"
      local team = PlayerResource:GetTeam(i)
      local acct = PlayerResource:GetSteamAccountID(i)
      local fake = "fake"
      local ply = PlayerResource:GetPlayer(i)

      if not PlayerResource:IsValidPlayer(i) then
        valid = "invalid"
      end
      if not PlayerResource:IsValidTeamPlayer(i) then
        teamvalid = "teaminvalid"
      end
      if not PlayerResource:IsFakeClient(i) then
        fake = "notfake"
      end

      local userId = "N"
      for k,v in pairs(self.vUserIds) do
        if v == ply then
          userId = k
        end
      end

      local name="N"
      if userId ~= "N" then
        name = self.vUserNames[userId]
      end

      print(i .. ": " .. valid .. ", " .. teamvalid .. ", " .. tostring(team) .. ", " .. tostring(acct) .. ", " .. tostring(userId) .. ", " .. tostring(name))
    end
  end

  if DEBUG and string.find(text, "^-botprint") then
    for k,v in pairs(self.vBots) do
      local name = self.vUserNames[k]
      print(k .. " -- " .. v .. " -- " .. tostring(name))
    end
  end
  
  if DEBUG and string.find(text, "^-hibtest") then
    local m = string.match(text, "(%d+)")
    if m ~= nil and m == "0" then
      self:CreateTimer('units2',{
        useGameTime = true,
        endTime = GameRules:GetGameTime(),
        callback = function(reflex, args)
          local pushNum = math.floor(#units / 10) + 1
          for i=1,pushNum do
            local unit = units[RandomInt(1, #units)]
            unit:AddPhysicsVelocity(RandomVector(RandomInt(1000,2000)))
          end
          
          return GameRules:GetGameTime() + 1
        end
      })
    elseif m ~= nil then
      unitNum = unitNum + m
      print (unitNum)
      for i=1,m do 
        local unit = CreateUnitByName('npc_dummy_blank', player.hero:GetAbsOrigin(), true, player.hero, player.hero, player.hero:GetTeamNumber())
        unit:AddNewModifier(unit, nil, "modifier_phased", {})
        unit:SetModel('models/heroes/lycan/lycan_wolf.mdl')
        unit:SetOriginalModel('models/heroes/lycan/lycan_wolf.mdl')
        
        Physics:Unit(unit)
        unit:SetNavCollisionType(PHYSICS_NAV_BOUNCE)
        
        units[#units + 1] = unit
      end
    end
  end
  
  if DEBUG and string.find(text, "^-tractor") then
    print('tractor')
    local m = string.match(text, "(%d)")
    if m ~= nil then
      local p = PlayerResource:GetPlayer(tonumber(m))
      local target = p:GetAssignedHero()
      local source = player.hero
      
      target:SetPhysicsVelocityMax(500)
      target:PreventDI()
      
      local direction = source:GetAbsOrigin() - target:GetAbsOrigin()
      direction = direction:Normalized()
      target:SetPhysicsAcceleration(direction * 50)
      
      target:OnPhysicsFrame(function(unit)
        -- Retarget acceleration vector
        local distance = source:GetAbsOrigin() - target:GetAbsOrigin()
        local direction = distance:Normalized()
        target:SetPhysicsAcceleration(direction * 50)
        
        -- Stop if reached the unit
        if distance:Length() < 100 then
          target:SetPhysicsAcceleration(Vector(0,0,0))
          target:SetPhysicsVelocity(Vector(0,0,0))
          target:OnPhysicsFrame(nil)
        end
      end)
    end
  end
  
  if DEBUG and string.find(text, "^-gold") then
    for k,v in pairs(HeroList:GetAllHeroes()) do
      v:SetGold(50000, true)
      GameRules:SetUseUniversalShopMode( true )
    end
  end
  
  if DEBUG and string.find(text, "^-phys") then
    Physics:Unit(player.hero)
    player.hero:SetPhysicsVelocity(Vector(1000,0,0))
    for k,v in pairs(HeroList:GetAllHeroes()) do
      if v ~= hero then
        Physics:Unit(v)
        v:SetPhysicsVelocity(Vector(1000,0,0))
        v:OnPhysicsFrame(function(unit)
          local pos = unit:GetAbsOrigin()
          local groundPos = GetGroundPosition(pos, unit)
          print(tostring(pos) .. " -- " .. tostring(groundPos))
          if pos.z > groundPos.z then
            unit:PreventDI(true)
            unit:SetPhysicsFriction(0)
          else
            unit:PreventDI(false)
            unit:SetPhysicsFriction(0.05)
          end
        end)
      end
    end
  end
  
  local vel1,vel2,vel3 = string.match(text, "^-vel%s+(-?%d+)%s+(-?%d+)%s+(-?%d+)")
  if DEBUG and vel1 ~= nil and vel2 ~= nil and vel3 ~= nil then
    player.hero:AddPhysicsVelocity(Vector(tonumber(vel1), tonumber(vel2), tonumber(vel3)))
  end
  
  local velmax1 = string.match(text, "^-velmax%s+(%d+)")
  if DEBUG and velmax1 ~= nil then
    player.hero:SetPhysicsVelocityMax(tonumber(velmax1))
    print('-velmax' .. tonumber(velmax1))
  end
  
  local acc1,acc2,acc3 = string.match(text, "^-acc%s+(-?%d+)%s+(-?%d+)%s+(-?%d+)")
  if DEBUG and acc1 ~= nil and acc2 ~= nil and acc3 ~= nil then
    player.hero:SetPhysicsAcceleration(Vector(tonumber(acc1), tonumber(acc2), tonumber(acc3)))
  end
  
  local fric1 = string.match(text, "^-fric%s+(-?%d+)")
  if DEBUG and fric1 ~= nil then
    player.hero:SetPhysicsFriction(tonumber(fric1) / 100 )
  end
  
  local slide1 = string.match(text, "^-slidemult%s+(-?%d+)")
  if DEBUG and slide1 ~= nil then
    player.hero:SetSlideMultiplier(tonumber(slide1) / 100 )
  end
  
  if DEBUG and string.find(text, "^-prevent") then
    player.hero:PreventDI(not player.hero:IsPreventDI())
  end
  
  if DEBUG and string.find(text, "^-onframe") then
    player.hero:OnPhysicsFrame(function(unit)
      PrintTable(unit)
      print('----------------')
    end)
  end
  
  if DEBUG and string.find(text, "^-slide$") then
    player.hero:Slide(not player.hero:IsSlide())
    print(player.hero:IsSlide())
  end
  
  if DEBUG and string.find(text, "^-nav$") then
    player.hero:FollowNavMesh(not player.hero:IsFollowNavMesh())
  end
  
  local clamp1 = string.match(text, "^-clamp%s+(%d+)")
  if DEBUG and clamp1 ~= nil then
    player.hero:SetVelocityClamp( tonumber(clamp1))
  end
  
  if DEBUG and string.find(text, "^-hibernate") then
    player.hero:Hibernate(not player.hero:IsHibernate())
    print(player.hero:IsHibernate())
  end
  
  if DEBUG and string.find(text, "^-navtype") then
      local navType = player.hero:GetNavCollisionType()
      navType = (navType + 1) % 4
      print('navtype: ' .. tostring(navType))
      player.hero:SetNavCollisionType(navType)
  end
  
  if DEBUG and string.find(text, "^-ground") then
    local ground = player.hero:GetGroundBehavior()
    ground = (ground + 1) % 3
    print('ground: ' .. tostring(ground))
    player.hero:SetGroundBehavior(ground)
  end
  
  if DEBUG and string.find(text, "^-pause") then
    paused = self.timers['round_time_out']
    self:RemoveTimer('round_time_out')
  end
  
  if DEBUG and string.find(text, "^-unpause") and paused ~= nil then
    self.timers['round_time_out'] = paused
    paused = nil
  end
  
  local abil1 = string.match(text, "^-abil%s+(.+)")
  if DEBUG and abil1 ~= nil then
    for k,v in pairs(HeroList:GetAllHeroes()) do
      if player.hero ~= v then
        local found = false
        for k2,i in pairs({1,2,3,6,4,5}) do
          if not found then
            local ability = v:FindAbilityByName( 'reflex_empty' .. i)
            if ability ~= nil then
              --print ( '[REFLEX] found empty' .. i .. " replacing")
              v:RemoveAbility('reflex_empty' .. i)
              v:AddAbility(abil1)
              found = true
            end
          end
        end
      end
    end
  end
  
  local item1 = string.match(text, "^-item%s+(.+)")
  if DEBUG and item1 ~= nil then
    for k,v in pairs(HeroList:GetAllHeroes()) do
      if player.hero ~= v then
        local item = CreateItem(item1, v, v)
        v:AddItem(item)
      end
    end
  end
  
  if DEBUG and string.find(text, "^-heal") then
    local m = string.match(text, "(%d)")
    if m ~= nil then
      local p = PlayerResource:GetPlayer(tonumber(m))
      local v = p:GetAssignedHero()
      v:SetHealth(v:GetMaxHealth()) 
    else 
      for k,v in pairs(HeroList:GetAllHeroes()) do
        if v ~= player.hero then
          v:SetHealth(v:GetMaxHealth())
        end
      end
    end
  end
  
  local mh1,mh2,mh3 = string.match(text, "^-mh%s+(-?%d+)%s+(%d)%s+(-?%d+)")
  if DEBUG and mh1 ~= nil and mh2 ~= nil and mh3 ~= nil then
    local bool = true
    if mh2 == "0" then
      bool = false
    end
    GameRules:SendCustomMessage("#Reflex_Tip", tonumber(mh1), tonumber(mh2))
    ShowGenericPopup("#Reflex_Tip", "#Reflex_Tip", "#Reflex_Tip", "#Reflex_Tip", tonumber(mh1) )
    ShowMessage("#Reflex_Tip")
    --player.hero:ModifyHealth(tonumber(mh1), player.hero, bool, tonumber(mh3))
  end
  
  local sAttach = string.match(text, "^-attach%s+(%d+)")
  if DEBUG and sAttach ~= nil then
    attach = tonumber(sAttach)
    Say(nil, 'Attach set ' .. sAttach, false)
  end
  
  local cp,nill = string.match(text, "^-cp%s+(%d+)%s+nil")
  if DEBUG and cp ~= nil and nill ~= nil then
    controlPoints[tonumber(cp)] = nil
    Say(nil, 'CP ' .. cp .. ' set to nil', false)
  else
    local cp,c1,c2,c3 = string.match(text, "^-cp%s+(%d+)%s+(-?%d+)%s+(-?%d+)%s+(-?%d+)")
    if DEBUG and cp ~= nil and c1 ~= nil and c2 ~= nil and c3 ~= nil then
      controlPoints[tonumber(cp)] = Vector(tonumber(c1), tonumber(c2), tonumber(c3))
      if particle ~= nil then
        ParticleManager:SetParticleControl(particle, tonumber(cp), controlPoints[tonumber(cp)])
      end
      Say(nil, 'CP ' .. cp .. ' set to Vector(' .. c1 .. ', ' .. c2 .. ', ' .. c3 .. ')', false)
    end
  end
  
  if DEBUG and string.find(text, "^-newp") then
    particle = nil
  end
  
  if DEBUG and string.find(text, "^-rpi") and particle ~= nil then
    ParticleManager:ReleaseParticleIndex(particle)
  end
  
  local effect = string.match(text, "^-particle%s*(.*)")
  if DEBUG and effect ~= nil and effect ~= "" then
    particleEffect = effect
    particle = ParticleManager:CreateParticle(effect, attach, player.hero)--cmdPlayer:GetAssignedHero())
    for cp,vec in pairs(controlPoints) do
      ParticleManager:SetParticleControl(particle, cp, vec)--Vector(0,0,0)) -- something
    end
  elseif DEBUG and effect ~= nil and effect == "" then
    particle = ParticleManager:CreateParticle(particleEffect, attach, player.hero)--cmdPlayer:GetAssignedHero())
    for cp,vec in pairs(controlPoints) do
      ParticleManager:SetParticleControl(particle, cp, vec)--Vector(0,0,0)) -- something
    end
  end

  local mA, mB, mC = string.match(text, "^-sequence%s+(-?%d+)%s+(-?%d+)%s+(-?%d+)")
  
  local hooks = {}
  local speed = 1500
  local distance = 10000
  local radius = 150
  local hookCount = 1
  local hooked = nil
  local dropped = false
  local damage = 400
  local topBound = 700
  local bottomBound = -700
  local leftBound = -700
  local rightBound = 700
  local centerRadius = 150
  local rebounceTolerance = 0
  local ancientPosition = Vector(0,-10,0)
  local linkCreationTolerance = 250
  local linkFollowDistance = 200
  local linkDeletionTolerance = 150
  
  --[[local topBound = 1600
  local bottomBound = -1600
  local leftBound = -1472
  local rightBound = 1472]]
  
  local complete = false
  
  if mA ~= nil and mB ~= nil and mC ~= nil and DEBUG then
    local hero = player.hero
    
    local dir = Vector(tonumber(mA),tonumber(mB),tonumber(mC)) - hero:GetAbsOrigin()
    dir = dir:Normalized()
    
    hooks[hookCount] = CreateUnitByName("npc_reflex_hook_test", hero:GetOrigin() + dir * 75, false, hero, hero, hero:GetTeamNumber())
    hooks[hookCount]:FindAbilityByName("reflex_dummy_unit"):SetLevel(1)
    hookCount = hookCount + 1
    
    local particle = ParticleManager:CreateParticle("ref_pudge_meathook_chain", PATTACH_RENDERORIGIN_FOLLOW, hooks[1])
    local position = hero:GetAbsOrigin()
    local endPosition = hooks[1]:GetAbsOrigin()
    local pu = ParticleUnit.new(particle, position, endPosition, 6, 0, 10) --cpStart, cpEnd, cpDelete)
    
    hooks[hookCount] = pu
    
    hookCount = hookCount + 1
    
    local timeout = GameRules:GetGameTime() + distance / speed
    
    self:CreateTimer(DoUniqueString('hook_test2'), {
      endTime = GameRules:GetGameTime(),
      callback = function(reflex, args)
        
        if complete then
          if hooked ~= nil then
            hooked:SetAbsOrigin(hooks[1]:GetAbsOrigin())
            local diff = hero:GetAbsOrigin() - hooked:GetAbsOrigin()
            if diff:Length() < linkDeletionTolerance then
              hooked:RemoveModifierByName("modifier_rooted")
              hooked = nil
              dropped = true
            end
          end
          
          --Move close chain
          if #hooks > 1 then
            local direction = hero:GetAbsOrigin() - hooks[#hooks]:GetEnd()
            direction.z = 0
            direction = direction:Normalized()
            hooks[#hooks]:SetStart(hero:GetAbsOrigin() + Vector(0,0,140))
            hooks[#hooks]:SetEnd(hooks[#hooks]:GetEnd() + direction * speed / 30)
          else
            local direction = hero:GetAbsOrigin() - hooks[#hooks]:GetAbsOrigin()
            direction.z = 0
            direction = direction:Normalized()
            hooks[#hooks]:SetAbsOrigin(hooks[#hooks]:GetAbsOrigin() + direction * speed / 30)
          end
        
          for i=#hooks - 1,2,-1 do
            local diff = hooks[i+1]:GetEnd() - hooks[i]:GetEnd()
            if diff:Length() > linkFollowDistance then
              diff.z = 0
              hooks[i]:SetEnd(hooks[i]:GetEnd() + diff:Normalized() * (diff:Length() - linkFollowDistance))
            end
            if hooks[i]:GetStart() ~= hooks[i+1]:GetEnd() then
              hooks[i]:SetStart(hooks[i+1]:GetEnd())
            end
          end
          
          if #hooks > 1 then
            local diff = hooks[2]:GetAbsOrigin() - hooks[1]:GetAbsOrigin()
            diff.z = 0
            hooks[1]:SetAbsOrigin(hooks[1]:GetAbsOrigin() + diff:Normalized() * (diff:Length() - linkFollowDistance))
            hooks[1]:SetForwardVector(-1 * diff:Normalized())
          end
          
          local diff = nil
          if #hooks > 1 then
            diff = hooks[#hooks]:GetEnd() - hero:GetAbsOrigin()
          else
            diff = hooks[#hooks]:GetAbsOrigin() - hero:GetAbsOrigin()
          end
          diff.z = 0
          if diff:Length() < linkDeletionTolerance then
            hooks[#hooks]:Destroy()
            hooks[#hooks] = nil
            if #hooks > 1 then
              hooks[#hooks]:SetStart(hero:GetAbsOrigin() + Vector(0,0,140))
            end
          end
          
          if #hooks == 0 then
            if hooked ~= nil then
              hooked:RemoveModifierByName("modifier_rooted")
              dropped = true
            end
            return
          end
          
          --print(tostring(hooks[#hooks]:GetAbsOrigin()) .. " -- " .. tostring(dir) .. " -- " .. speed .. " -- " .. tostring(#hooks))
          
          if hooked == nil and not dropped then
            local entities = Entities:FindAllInSphere(hooks[1]:GetAbsOrigin(), radius)
            if entities ~= nil then
              for k,v in pairs(entities) do
                --if string.find(v:GetClassname(), "pudge") or string.find(v:GetClassname(), "mine") then
                if string.find(v:GetClassname(), "axe") and v ~= hero then
                  print(k .. " -- " .. v:GetClassname() .. " -- " .. v:GetName())
                  complete = true
                  v:AddNewModifier(hero, nil, "modifier_rooted", {})
                  if (hero:GetTeamNumber() ~= v:GetTeamNumber()) then
                    dealDamage(hero, v, damage)
                  end
                  hooked = v
                end
              end
            end
          end
        else
          -- Move hook
          dir.z = 0
          hooks[1]:SetAbsOrigin(hooks[1]:GetAbsOrigin() + dir * speed / 30)
          dir.z = 0
          hooks[1]:SetForwardVector(dir)
          
          local diff = hooks[1]:GetAbsOrigin() - hooks[2]:GetAbsOrigin()
          diff.z = 0
          if diff:Length() > linkFollowDistance then
            hooks[2]:SetStart(hooks[2]:GetAbsOrigin() + diff:Normalized() * (diff:Length() - linkFollowDistance))
          end
          if hooks[2]:GetEnd() ~= hooks[1]:GetAbsOrigin() then
            hooks[2]:SetEnd(hooks[1]:GetAbsOrigin())
          end
          
          -- Move chains
          for i=3,#hooks do
            local diff = hooks[i-1]:GetAbsOrigin() - hooks[i]:GetAbsOrigin()
            diff.z = 0
            if diff:Length() > linkFollowDistance then
              hooks[i]:SetStart(hooks[i]:GetAbsOrigin() + diff:Normalized() * (diff:Length() - linkFollowDistance))
            end
            if hooks[i]:GetEnd() ~= hooks[i-1]:GetAbsOrigin() then
              hooks[i]:SetEnd(hooks[i-1]:GetAbsOrigin())
            end
          end
          
          -- Create New Chain link
          local diff = hooks[#hooks]:GetAbsOrigin() - hero:GetAbsOrigin()
          if diff:Length() > linkCreationTolerance then
            diff.z = 0
            local direction = diff:Normalized()
            local particle = ParticleManager:CreateParticle("ref_pudge_meathook_chain", PATTACH_ABSORIGIN, hero)
            local position = hero:GetAbsOrigin() + Vector(0,0,140)
            local endPosition = hero:GetAbsOrigin() + direction * 75 + Vector(0,0,140)
            local pu = ParticleUnit.new(particle, position, endPosition) --cpStart, cpEnd, cpDelete)
            
            hooks[hookCount] = pu
            
            hookCount = hookCount + 1
          elseif #hooks > 1 then
            hooks[#hooks]:SetStart(hero:GetAbsOrigin() + Vector(0,0,140))
          end
          
          --Collision detection
          if hooked == nil then
            local entities = Entities:FindAllInSphere(hooks[1]:GetAbsOrigin(), radius)
            if entities ~= nil then
              for k,v in pairs(entities) do
                -- Bounce entities
                
                if hooked == nil then
                  --if string.find(v:GetClassname(), "pudge") or string.find(v:GetClassname(), "mine") then
                  if string.find(v:GetClassname(), "axe") and v ~= hero then
                    print(k .. " -- " .. v:GetClassname() .. " -- " .. v:GetName())
                    complete = true
                    v:AddNewModifier(hero, nil, "modifier_rooted", {})
                    if (hero:GetTeamNumber() ~= v:GetTeamNumber()) then
                      dealDamage(hero, v, damage)
                    end
                    hooked = v
                  end
                end
              end
            end
          end
          
          -- Bounce wall checks
          local hookPos = hooks[1]:GetAbsOrigin()
          local angx = (math.acos(dir.x)/ math.pi * 180)
          local angy = (math.acos(dir.y)/ math.pi * 180)
          if hookPos.x > rightBound and dir.x > 0 then
            local rotAngle = 180 - angx * 2
            if angy > 90 then
              rotAngle = 360 - rotAngle
            end
            dir = RotatePosition(Vector(0,0,0), QAngle(0,rotAngle,0), dir)
          elseif hookPos.x < leftBound and dir.x < 0 then
            local rotAngle =  angx * 2 - 180
            if angy < 90 then
              rotAngle = 360 - rotAngle
            end
            dir = RotatePosition(Vector(0,0,0), QAngle(0,rotAngle,0), dir)
          elseif hookPos.y > topBound and dir.y > 0 then
            local rotAngle =  180 - angy * 2
            if angx < 90 then
              rotAngle = 360 - rotAngle
            end
            dir = RotatePosition(Vector(0,0,0), QAngle(0,rotAngle,0), dir)
          elseif hookPos.y < bottomBound and dir.y < 0 then
            local rotAngle =  angy * 2 - 180
            if angx > 90 then
              rotAngle = 360 - rotAngle
            end
            dir = RotatePosition(Vector(0,0,0), QAngle(0,rotAngle,0), dir)
          end
          
          -- Bounce center
          hookPos.z = 0
          diff = ancientPosition - hookPos
          rebounceTolerance = rebounceTolerance - 1
          if diff:Length() < centerRadius and rebounceTolerance < 1 then
            rebounceTolerance = 3
            diff = diff:Normalized()
            --diff = RotatePosition(Vector(0,0,0), QAngle(0, 90, 0), diff)
            local diffx = (math.acos(diff.x)/ math.pi * 180)
            local diffy = (math.acos(diff.y)/ math.pi * 180)
            local angx = (math.acos(dir.x)/ math.pi * 180)
            local angy = (math.acos(dir.y)/ math.pi * 180)
            local dx = diffx - angx
            local dy = diffy - angy
            
            local rotAngle = 180 - math.abs(dx) - math.abs(dy)
            
            if (math.abs(dir.x) > math.abs(dir.y) and dir.y > 0) or (math.abs(dir.x) < math.abs(dir.y) and dir.y < 0) then
              rotAngle = 360 - rotAngle
            end

            if (dx < 0 and dy  < 0 and dir.x > 0 and dir.y < 0) or
              (dx > 0 and dy < 0 and dir.x > 0 and dir.y > 0) or
              (dx > 0 and dy > 0 and dir.x < 0 and dir.y > 0) or 
              (dx < 0 and dy > 0 and dir.x < 0 and dir.y < 0) then
              rotAngle = 360 - rotAngle
            end
            print (rotAngle)
            print ("****")
            dir = RotatePosition(Vector(0,0,0), QAngle(0,rotAngle,0), dir)
          end
          
          
          if GameRules:GetGameTime() > timeout then
            complete = true
            return GameRules:GetGameTime()
          end
        end
        return GameRules:GetGameTime()
      end})
    
    
  end
  
  --[[if mA ~= nil and mB ~= nil and mC ~= nil and DEBUG then
    local hero = player.hero
    local info = {
      EffectName = "hlw_phoenix_sunray", -- "pudge_meathook_chain", -- "magnataur_shockwave", --"windrunner_spell_powershot",
      Ability = self:getItemByName(hero, "item_reflex_meteor_cannon"),
      vSpawnOrigin = hero:GetOrigin(),
      fDistance = 5000,
      fStartRadius = 800,
      fEndRadius = 800,
      Source = hero,
      bReplaceExisting = true,
      bHasFrontalCone = false,
      iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
      iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
      iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC + DOTA_UNIT_TARGET_OTHER,
      --fMaxSpeed = 5200,
      fExpireTime = GameRules:GetGameTime() + 10.0,
      --Target = hook, 
    }
    
    local direction = Vector(0,0,0) - hero:GetAbsOrigin()
    direction = direction:Normalized()
    --info.vVelocity = direction * 1000

    local timeout = GameRules:GetGameTime() + 10
    
    self:CreateTimer(DoUniqueString('sequence'), {
      endTime = GameRules:GetGameTime(),
      callback = function(reflex, args)
        
        
        if GameRules:GetGameTime() > timeout then
          return
        end
        return GameRules:GetGameTime()
      end})
    
    local proj = ProjectileManager:CreateLinearProjectile(info)
    --local proj = APM:CreateProjectile(info, {
      --{type=APM_LINEAR, distance=1000, speed=1000, toward=vector},
      --{type=APM_LINEAR, time=2, toward=function() return hero:GetOrigin() end}}, nil, nil, nil)
    
  end]]
  
  if string.find(text, "^-hook") and DEBUG then
    local hero = player.hero
    
    local particle = ParticleManager:CreateParticle("ref_pudge_meathook_chain", PATTACH_POINT, hero)
    local position = hero:GetAbsOrigin()
    local endPosition = position + Vector(200,200,0)
    local pu = ParticleUnit.new(particle, position, endPosition) --cpStart, cpEnd, cpDelete)
    PrintTable(pu)
    PrintTable(getmetatable(pu))
    local timeout = GameRules:GetGameTime() + 5
    
    self:CreateTimer('hook_test', {
      endTime = GameRules:GetGameTime(),
      callback = function(reflex, args)
        print('---------------')
        PrintTable(pu)
        local speed = 500 / 30
        local dir = Vector(200,200,0):Normalized()
        pu:SetEnd(pu:GetEnd() + dir * speed)
        
        if GameRules:GetGameTime() > timeout then
          pu:Destroy()
          return
        end
        return GameRules:GetGameTime()
      end})
    
    --[[hook = CreateUnitByName("npc_reflex_hook_test", hero:GetOrigin(), false, hero, hero, hero:GetTeamNumber())
    --hook:FindAbilityByName("reflex_dummy_unit"):SetLevel(1)
    local direction = Vector(0,0,128) - hero:GetAbsOrigin()
    direction = direction:Normalized()
     
    --hook:SetForwardVector(direction)
    hero:SetForwardVector(Vector(direction.x, direction.y,0))
    
    local origin = hero:GetAbsOrigin()
    
    local timeout = GameRules:GetGameTime() + 1.2
    local complete = false

    player.hero:AddNewModifier( player.hero, nil , "modifier_stunned", {duration = 0.75})
    local particle = ParticleManager:CreateParticle("pudge_meathook_chain", PATTACH_RENDERORIGIN_FOLLOW, hero)
    local hookPos = hero:GetAbsOrigin()
    hookPos.z = hookPos.z + 128
    
    self:CreateTimer('hook_test', {
      endTime = GameRules:GetGameTime(),
      callback = function(reflex, args)
        local speed = 1000 / 30
        --local hookPos = hook:GetAbsOrigin() + hero:GetAbsOrigin() - origin
        hookPos = hookPos + hero:GetAbsOrigin() - origin
        origin = hero:GetAbsOrigin()
        local vector = direction * speed
        
        --hook:SetAbsOrigin(hookPos + vector)
        hookPos = hookPos + vector
        
        
        --ParticleManager:SetParticleControl(particle, 0, hero:GetAbsOrigin()) -- something
        --ParticleManager:SetParticleControl(particle, 1, Vector(mA, mB, mC)) -- radius
        ParticleManager:SetParticleControl(particle, 2, Vector(5, 0, 0)) -- something
        ParticleManager:SetParticleControl(particle, 3, hookPos) -- end point of hook vector
        ParticleManager:SetParticleControl(particle, 4, Vector(1, 0, 0)) -- X= spins per second, Y-z nothing
        --ParticleManager:SetParticleControl(particle, 5, Vector(1, 0, 0)) -- X= spins per second, Y-z nothing
        ParticleManager:SetParticleControl(particle, 6, hookPos) -- X= spins per second, Y-z nothing
        
        if complete and GameRules:GetGameTime() > timeout then
          --hook:Destroy()
          ParticleManager:SetParticleControl(particle, 2, Vector(0.1, 0, 0)) -- something
          return
        end
        if GameRules:GetGameTime() > timeout then
          timeout = GameRules:GetGameTime() + 1.1
          complete = true
          direction.x = -1 * direction.x
          direction.y = -1 * direction.y
          direction.z = -1 * direction.z
          return GameRules:GetGameTime()
        end
        return GameRules:GetGameTime()
      end})]]
    
  end
end

function ReflexGameMode:AutoAssignPlayer(keys)
  print ('[REFLEX] AutoAssignPlayer')
  self:CaptureGameMode()
  --PrintTable(keys)
  print ('[REFLEX] getting index')
  --print(keys.index)
  local entIndex = keys.index+1
  local ply = EntIndexToHScript(entIndex)
  
  --[[print('team: ' .. tostring(ply:GetTeam()))
  print('owner: ' .. tostring(ply:GetOwner()))
  print('isalive: ' .. tostring(ply:IsAlive()))
  print('gh: ' .. tostring(ply:GetHealth()))
  print('gmh: ' .. tostring(ply:GetMaxHealth()))
  print('classname: ' .. tostring(ply:GetClassname()))
  print('name: ' .. tostring(ply:GetName()))
  print('name: ' .. tostring(ply:GetName()))]]
  
  local playerID = ply:GetPlayerID()
  
  --[[print('IsValidPID: '  .. tostring(PlayerResource:IsValidPlayerID(playerID)))
  print('IsValidP: '  .. tostring(PlayerResource:IsValidPlayer(playerID)))
  print('IsValidP: '  .. tostring(PlayerResource:IsValidPlayer(playerID)))
  print('IsFakeClient: '  .. tostring(PlayerResource:IsFakeClient(playerID)))
  print('IsBroadcaster: '  .. tostring(PlayerResource:IsBroadcaster(playerID)))
  print('GetBroadcasterChannel: '  .. tostring(PlayerResource:GetBroadcasterChannel(playerID)))
  print('GetBroadcasterChannelSlot: '  .. tostring(PlayerResource:GetBroadcasterChannelSlot(playerID)))
  print('SteamAccountID: '  .. tostring(PlayerResource:GetSteamAccountID(playerID)))
  print('PlayerName: '  .. tostring(PlayerResource:GetPlayerName(playerID)))]]

  self.nConnected = self.nConnected + 1
  self:RemoveTimer('all_disconnect')
  
  self.vUserIds[keys.userid] = ply
  
  --print('--UserIds--')
  --PrintTable(vUserIds)
  --print('--SteamIDs--')
  --PrintTable(vSteamIds)
  
  if PlayerResource:IsBroadcaster(playerID) then
    self.vBroadcasters[keys.userid] = 1
    return
  end
  
  if self.vBots[keys.userid] ~= nil then
    return
  end

  playerID = ply:GetPlayerID()
  if self.vPlayers[playerID] ~= nil then
    --self.vUserIds[playerID] = nil
    self.vUserIds[keys.userid] = ply
    return
  end
  
  if not USE_LOBBY and playerID == -1 then
    print ('[REFLEX] team sizes ' ..  #self.vRadiant .. "  --  " .. #self.vDire)
    if #self.vRadiant > #self.vDire then
      print ('[REFLEX] setting to bad guys')
      ply:SetTeam(DOTA_TEAM_BADGUYS)
      ply:__KeyValueFromInt('teamnumber', DOTA_TEAM_BADGUYS)
      table.insert (self.vDire, ply)
    else
      print ('[REFLEX] setting to good guys')
      ply:SetTeam(DOTA_TEAM_GOODGUYS)
      ply:__KeyValueFromInt('teamnumber', DOTA_TEAM_GOODGUYS)
      table.insert (self.vRadiant, ply)
    end
    playerID = ply:GetPlayerID()
  end

  print ('[REFLEX] playerID: ' .. playerID)
  self.vSteamIds[PlayerResource:GetSteamAccountID(playerID)] = ply
  
  --PrintTable(PlayerResource)
  --PrintTable(getmetatable(PlayerResource))
  
  print('[REFLEX] SteamID: ' .. PlayerResource:GetSteamAccountID(playerID))

  --Autoassign player
  self:CreateTimer('assign_player_'..entIndex, {
  endTime = Time(),
  callback = function(reflex, args)
    if GameRules:State_Get() >= DOTA_GAMERULES_STATE_PRE_GAME then
      print ('[REFLEX] in pregame')
      -- Assign a hero to a fake client
      local heroEntity = ply:GetAssignedHero()
      if PlayerResource:IsFakeClient(playerID) then
        if heroEntity == nil then
          CreateHeroForPlayer('npc_dota_hero_axe', ply)
        else
          PlayerResource:ReplaceHeroWith(playerID, 'npc_dota_hero_axe', 0, 0)
        end
      end
      heroEntity = ply:GetAssignedHero()
      print ('[REFLEX] got assigned hero')
      -- Check if we have a reference for this player's hero
      if heroEntity ~= nil and IsValidEntity(heroEntity) then
        print ('[REFLEX] setting hero assignment')
        local heroTable = {
          hero = heroEntity,
          nKillsThisRound = 0,
          bDead = false,
          nUnspentGold = STARTING_GOLD,
          fLevel = 1.0,
          nCurXP = 100,
          nTeam = ply:GetTeam(),
          bRoundInit = false,
          nUnspentAbilityPoints = 1,
          bConnected = true,
          nLastRoundDamage = 0,
          nRoundDamage = 0,
          name = self.vUserNames[keys.userid],
          bColorblind = false,
          vAbilities = {
            "reflex_empty1",
            "reflex_empty2",
            "reflex_empty3",
            "reflex_empty4",
            "reflex_empty5",
            "reflex_empty6"
          }
        }
        print ('[REFLEX] playerID: ' .. playerID)
        self.vPlayers[playerID] = heroTable

        print ( "[REFLEX] setting stuff for player"  .. playerID)
        --heroEntity:__KeyValueFromInt('StatusManaRegen', 100)
        local dash = CreateItem("item_reflex_dash", heroEntity, heroEntity)
        heroEntity:AddItem(dash)
        local shooter = CreateItem("item_simple_shooter", heroEntity, heroEntity)
        heroEntity:AddItem(shooter)
        heroEntity:SetCustomDeathXP(0)

        heroEntity:SetGold(0, false)
        heroEntity:SetGold(STARTING_GOLD, true)
        --PlayerResource:SetGold( playerID, 0, false )
        --PlayerResource:SetGold( playerID, STARTING_GOLD, true )
        print ( "[REFLEX] GOLD SET FOR PLAYER "  .. playerID)
        PlayerResource:SetBuybackCooldownTime( playerID, 0 )
        PlayerResource:SetBuybackGoldLimitTime( playerID, 0 )
        PlayerResource:ResetBuybackCostTime( playerID )

        if GameRules:State_Get() > DOTA_GAMERULES_STATE_PRE_GAME then

          if heroTable.bRoundInit == false then
            print ( '[REFLEX] Initializing player ' .. playerID)
            heroTable.bRoundInit = true
            heroTable.hero:RespawnHero(false, false, false)
            --player.hero:RespawnUnit()
            heroTable.nKillsThisRound = 0
            heroTable.bDead = false

            --PlayerResource:SetGold(playerID, 0, true)
            heroTable.hero:SetGold(0, true)
            heroTable.nUnspentAbilityPoints = heroTable.hero:GetAbilityPoints()
            heroTable.hero:SetAbilityPoints(0)

            --if has modifier remove it
            if heroTable.hero:HasModifier("modifier_stunned") then
              heroTable.hero:RemoveModifierByName("modifier_stunned")
            end
          end
        end

        return
      end
    end

    return Time() + 1.0
  end
  --persist = true
})
end

function ReflexGameMode:LoopOverPlayers(callback)
  for k, v in pairs(self.vPlayers) do
    -- Validate the player
    if IsValidEntity(v.hero) then
      -- Run the callback
      if callback(v, v.hero:GetPlayerID()) then
        break
      end
    end
  end
end

function ReflexGameMode:ShopReplacement( keys )
  --print ( '[REFLEX] ShopReplacement' )
  PrintTable(keys)

  local plyID = keys.PlayerID
  if not plyID then return end

  local player = self.vPlayers[plyID]
  if not player then return end

  local item = self:getItemByName(player.hero, keys.itemname)
  if not item then return end

  print ( item:GetAbilityName())
  --print ( ABILITY_ITEM_TABLE[item:GetAbilityName()] )

  if item:GetAbilityName() == "item_reflex_dash" or item:GetAbilityName() == "item_simple_shooter" then
    local cost = item:GetCost()
    player.hero:SetGold(player.hero:GetGold() + cost, true)
    item:Remove()
    return
  end
  
  if (string.find(item:GetAbilityName(), "item_recipe_") ~= nil) then
    local cost = item:GetCost()
    player.hero:SetGold(player.hero:GetGold() + cost, true)
    item:Remove()
    return
  end

  -- Prevent rebuying existing items
  local baseName = item:GetAbilityName()
  local count = 0
  if string.find(baseName:sub(-1), "2") ~= nil or string.find(baseName:sub(-1), "3") ~= nil or string.find(baseName:sub(-1), "4") ~= nil then
    --print('[REFLEX] BaseName: ' .. baseName)
    baseName = baseName:sub(1, -3)
    --print('[REFLEX] BaseName: ' .. baseName)
  end
  
  for i=0,11 do
    --print ( '\t[REFLEX] finding item ' .. i)
    local item2 = player.hero:GetItemInSlot( i )
    --print ( '\t[REFLEX] item: ' .. tostring(item) )
    if item2 ~= nil then
      --print ( '\t[REFLEX] getting item name' .. i)
      local lname = item2:GetAbilityName()
      --print ( string.format ('[REFLEX] item slot %d: %s', i, lname) )
      if string.find(lname, baseName) then
        count = count + 1
        --print (tostring(count))
        if count > 1 then
          local cost = item:GetCost()
          player.hero:SetGold(player.hero:GetGold() + cost, true)
          item:Remove()
          return
        end
      end
    end
  end

  -- We're done if it's not an ability item
  if string.find(item:GetAbilityName(), "item_ability_reflex_") == nil then 
    -- Copy to debug heroes
    if DEBUG then
      for i=0,9 do
        if PlayerResource:IsFakeClient(i) then
          local v = PlayerResource:GetPlayer(i):GetAssignedHero()
          local item2 = CreateItem(item:GetAbilityName(), v, v)
          v:AddItem(item2)
        end
      end
    end
    return
  end

  --local abilityToAdd = ABILITY_ITEM_TABLE[item:GetAbilityName()]
  local abilityToAdd = string.gsub(item:GetAbilityName(), "item_ability_", "")

  local cost = item:GetCost()
  item:Remove()
  
  -- Make sure we have an empty space
  local noEmptySpace = true
  for k,abil in pairs(player.vAbilities) do
    if string.find(abil, "reflex_empty") then
      noEmptySpace = false
    end
  end

  if player.hero:FindAbilityByName (abilityToAdd) ~= nil or noEmptySpace then 
    player.hero:SetGold(player.hero:GetGold() + cost, true)
    return 
  end

  if ABILITY_ITEM_TABLE[abilityToAdd] == 1 then
    --Is passive, Reverse order
    local found = false
    for k,i in pairs({5,4,6,3,2,1}) do
      if not found then
        local ability = player.hero:FindAbilityByName( 'reflex_empty' .. i)
        if ability ~= nil then
          --print ( '[REFLEX] found empty' .. i .. " replacing")
          player.hero:RemoveAbility('reflex_empty' .. i)
          player.hero:AddAbility(abilityToAdd)
          player.vAbilities[i] = abilityToAdd
          found = true
          
          if DEBUG then
            for j=0,9 do
              if PlayerResource:IsFakeClient(j) then
                local v = PlayerResource:GetPlayer(j):GetAssignedHero()
                v:RemoveAbility('reflex_empty' .. i)
                v:AddAbility(abilityToAdd)
              end
            end
          end
        end
      end
    end
  else
    --Not passive, normal order
    local found = false
    for k,i in pairs({1,2,3,6,4,5}) do
      if not found then
        local ability = player.hero:FindAbilityByName( 'reflex_empty' .. i)
        if ability ~= nil then
          --print ( '[REFLEX] found empty' .. i .. " replacing")
          player.hero:RemoveAbility('reflex_empty' .. i)
          player.hero:AddAbility(abilityToAdd)
          player.vAbilities[i] = abilityToAdd
          found = true
          
          if DEBUG then
            for j=0,9 do
              if PlayerResource:IsFakeClient(j) then
                local v = PlayerResource:GetPlayer(j):GetAssignedHero()
                v:RemoveAbility('reflex_empty' .. i)
                v:AddAbility(abilityToAdd)
              end
            end
          end
        end
      end
    end
  end
end

function ReflexGameMode:getItemByName( hero, name )
  --if not hero:HasItemInInventory ( name ) then
  --	return nil
  --end

  --print ( '[REFLEX] find item in inventory' )
  -- Find item by slot
  for i=0,11 do
    --print ( '\t[REFLEX] finding item ' .. i)
    local item = hero:GetItemInSlot( i )
    --print ( '\t[REFLEX] item: ' .. tostring(item) )
    if item ~= nil then
      --print ( '\t[REFLEX] getting ability name' .. i)
      local lname = item:GetAbilityName()
      --print ( string.format ('[REFLEX] item slot %d: %s', i, lname) )
      if lname == name then
        return item
      end
    end
  end

  return nil
end

function ReflexGameMode:_thinkState_Prep( dt )
  --print ( '[REFLEX] _thinkState_Prep' )
  if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_PRE_GAME then
    -- Waiting on the game to start...
    return
  end

  self.thinkState = Dynamic_Wrap( ReflexGameMode, '_thinkState_None' )
  self:InitializeRound()


end

function ReflexGameMode:_thinkState_None( dt )
  return
end

function ReflexGameMode:InitializeRound()
  print ( '[REFLEX] InitializeRound called' )
  bInPreRound = true
  GameRules:SetUseUniversalShopMode( true )

  --cancelTimer = false
  --Init Round (give level ups/points/gold back)
  self:RemoveTimer('playerInit')
  self:CreateTimer('playerInit', {
  endTime = Time(),
  callback = function(reflex, args)
    if not bInPreRound then
      return Time() + 0.5
    end
    self:LoopOverPlayers(function(player, plyID)
      if player.bRoundInit == false then
        print ( '[REFLEX] Initializing player ' .. plyID)
        player.bRoundInit = true
        player.hero:RespawnHero(false, false, false)
        --player.hero:RespawnUnit()
        player.nKillsThisRound = 0
        player.bDead = false
        player.nRoundDamage = PlayerResource:GetRawPlayerDamage(plyID) - player.nLastRoundDamage
        player.nLastRoundDamage = PlayerResource:GetRawPlayerDamage(plyID)
        --PlayerResource:SetGold(plyID, player.nUnspentGold, true)
        player.hero:SetGold(player.nUnspentGold, true)
        player.hero:SetAbilityPoints(player.nUnspentAbilityPoints)

        for i=0,11 do
          local item = player.hero:GetItemInSlot( i )
          if item ~= nil then
            local name = item:GetAbilityName()
            local charge = item:GetInitialCharges()
            if charge ~= nil then
              item:SetCurrentCharges(charge)
            end
          end
        end

        --ASLKJALSKFJAKLSFJ
        --player.hero:SetAbilityPoints(10)

        --Remove dangerous abilities
        for i=1,#ADDED_ABILITIES do
          local ability = ADDED_ABILITIES[i]
          self:FindAndRemove(player.hero, ability)
        end
        
        if player.hero:HasModifier("modifier_blade_charge") then
          callModRemover(player.hero, "modifier_blade_charge")
        end

        if not player.hero:HasModifier("modifier_stunned") then
          player.hero:AddNewModifier( player.hero, nil , "modifier_stunned", {})
        end

        if not player.hero:HasModifier("modifier_invulnerable") then
          player.hero:AddNewModifier(player.hero, nil , "modifier_invulnerable", {})
        end

        local remainder = player.nCurXP % 100
        local curXP = player.nCurXP --PlayerResource:GetTotalEarnedXP(plyID)
        local nextXP = player.fLevel * 100
        player.nCurXP = nextXP
        print ( '[REFLEX] NextXP: ' .. tostring(nextXP))
        if nextXP > curXP then
          print ( '[REFLEX] XP Boost ' .. tostring(nextXP - curXP))
          for i=1,math.floor((nextXP - curXP + remainder) / 100) do
            player.hero:HeroLevelUp(true)
          end
          --player.hero:AddExperience(remainder, true)
          --player.hero:AddExperience(nextXP - curXP, false)
          --PlayerResource:IncrementTotalEarnedXP(plyID, nextXP - curXP)
        end
      end
    end)

    --[[if count == #self.vRadiant + #self.vDire then
    print ( '[REFLEX] All Initialized' )
    return
    end
    return Time() + 0.5]]
    --if cancelTimer then
    --	return
    --end
    return Time() + 0.5
  end})

  local roundTime = PRE_ROUND_TIME + PRE_GAME_TIME
  PRE_GAME_TIME = 0
  
  Say(nil, string.format("Round %d starts in %d seconds!", self.nCurrentRound, roundTime), false)
  
  if roundOne then
    self:CreateTimer('reflexDetail', {
      endTime = GameRules:GetGameTime() + 10,
      useGameTime = true,
      callback = function(reflex, args)
        GameRules:SendCustomMessage("Welcome to <font color='#70EA72'>Reflex!</font>", 0, 0)
        GameRules:SendCustomMessage("Version: " .. REFLEX_VERSION, 0, 0)
        GameRules:SendCustomMessage("Created by <font color='#70EA72'>BMD</font>", 0, 0)
        GameRules:SendCustomMessage("Map by <font color='#70EA72'>Azarak</font>", 0, 0)
        GameRules:SendCustomMessage("Send feedback to <font color='#70EA72'>bmddota@gmail.com</font>", 0, 0)
      end
    })
    
    self:CreateTimer('reflexDetail1', {
      endTime = GameRules:GetGameTime() + 20,
      useGameTime = true,
      callback = function(reflex, args)
        GameRules:SendCustomMessage("#Reflex_Tip", 0, 0)
        self.bTipsActive = true
        self.nLastTipTime = Time() - TIP_TIMEOUT
      end
    })
    
    self:CreateTimer('reflexDetail2', {
      endTime = GameRules:GetGameTime() + 30,
      useGameTime = true,
      callback = function(reflex, args)
        local tip1 = RandomInt(1, MAX_TIPS)
    
        local nTime = Time() - TIP_TIMEOUT
        if self.bTipsActive and nTime > self.nLastTipTime then
          GameRules:SendCustomMessage("#Reflex_Tip" .. tip1, 0, 0)
          self.nLastTipTime = Time()
        end
      end
    })
  else
    self:CreateTimer('reflexDetail3', {
      endTime = GameRules:GetGameTime() + 10,
      useGameTime = true,
      callback = function(reflex, args)
        local tip1 = RandomInt(1, MAX_TIPS)
    
        local nTime = Time() - TIP_TIMEOUT
        if self.bTipsActive and nTime > self.nLastTipTime then
          GameRules:SendCustomMessage("#Reflex_Tip" .. tip1, 0, 0)
          self.nLastTipTime = Time()
        end
      end
    })
  end
 
  roundOne = false
  
  local startCount = 7
  --Set Timers for round start announcements
  self:CreateTimer('round_start_timer', {
  endTime = GameRules:GetGameTime() + roundTime - 10,
  useGameTime = true,
  callback = function(reflex, args)
    startCount = startCount - 1
    if startCount == 0 then
      self.fRoundStartTime = GameRules:GetGameTime()
      self:LoopOverPlayers(function(player, plyID)
        -- Refund any recipes left
        for i=0,11 do
          local item = player.hero:GetItemInSlot( i )
          if item ~= nil then
            local name = item:GetAbilityName()
            if string.find(name, "item_recipe_") ~= nil then
              local cost = item:GetCost()
              player.hero:SetGold(player.hero:GetGold() + cost, true)
              item:Remove()
            end
          end
        end

        player.nUnspentGold = PlayerResource:GetGold(plyID)
        --PlayerResource:SetGold(plyID, 0, true)
        player.hero:SetGold(0, true)
        player.hero:SetGold(0, false)
        player.nUnspentAbilityPoints = player.hero:GetAbilityPoints()
        player.hero:SetAbilityPoints(0)
        GameRules:SetUseUniversalShopMode( false )

        --if has modifier remove it
        if player.hero:HasModifier("modifier_stunned") then
          player.hero:RemoveModifierByName("modifier_stunned")
        end
        
        if player.hero:HasModifier("modifier_invulnerable") then
          player.hero:RemoveModifierByName("modifier_invulnerable")
        end

        local timeoutCount = 14
        self:CreateTimer('round_time_out',{
        endTime = GameRules:GetGameTime() + ROUND_TIME - 120,
        useGameTime = true,
        callback = function(reflex, args)
          timeoutCount = timeoutCount - 1
          if timeoutCount == 0 then 
            -- TIME OUT
            self:LoopOverPlayers(function(player, plyID)
              player.hero:AddNewModifier( player.hero, nil , "modifier_stunned", {})
              player.hero:AddNewModifier( player.hero, nil , "modifier_invulnerable", {})
            end)
            self:CreateTimer('victory', {
              endTime = Time() + POST_ROUND_TIME,
              callback = function(reflex, args)
                ReflexGameMode:RoundComplete(true)
              end})

            return
          elseif timeoutCount == 13 then
            Say(nil, "2 minutes remaining!", false)
            return GameRules:GetGameTime() + 60
          elseif timeoutCount == 12 then
            Say(nil, "1 minute remaining!", false)
            return GameRules:GetGameTime() + 30
          elseif timeoutCount == 11 then
            Say(nil, "30 seconds remaining!", false)
            return GameRules:GetGameTime() + 20
          else
            local msg = {
							message = tostring(timeoutCount),
							duration = 0.9
            }
            FireGameEvent("show_center_message",msg)
            return GameRules:GetGameTime() + 1
          end
        end})
      end)

      bInPreRound = false;
      local msg = {
			  message = "FIGHT!",
				duration = 0.9
			}
			FireGameEvent("show_center_message",msg)
      return
    elseif startCount == 6 then
      Say(nil, "10 seconds remaining!", false)
      return GameRules:GetGameTime() + 5
    else
			local msg = {
			  message = tostring(startCount),
			  duration = 0.9
			}
			FireGameEvent("show_center_message",msg)
      return GameRules:GetGameTime() + 1
    end
  end})

end

function ReflexGameMode:RoundComplete(timedOut)
  print ('[REFLEX] Round Complete')
  
  self:RemoveTimer('round_start_timer')
  self:RemoveTimer('round_time_out')
  self:RemoveTimer('victory')

  local elapsedTime = GameRules:GetGameTime() - self.fRoundStartTime - POST_ROUND_TIME

  -- Determine Victor and boost Dire/Radiant score
  local victor = DOTA_TEAM_GOODGUYS
  local s = "Radiant"
  if timedOut then
    --If noteam score any kill, the team on inferior position win this round to prevent from negative attitude
    if self.nLastKilled == nil then 
      if self.nRadiantScore > self.nDireScore then
        victor = DOTA_TEAM_BADGUYS
        s = "Dire"
      end
    -- Victor is whoever has least dead
    elseif self.nDireDead < self.nRadiantDead then
      victor = DOTA_TEAM_BADGUYS
      s = "Dire"
      -- If both have same number of dead go by final hp percent of heroes
    elseif self.nDireDead == self.nRadiantDead then 
      local radiantHPpercent = 0
      local direHPpercent = 0
      self:LoopOverPlayers(function(player, plyID)
        if player.bDead == false then
          if player.nTeam == DOTA_TEAM_GOODGUYS then
            radiantHPpercent = radiantHPpercent + player.hero:GetHealthPercent()
          else
            direHPpercent = direHPpercent + player.hero:GetHealthPercent()
          end
        end
      end)
      
      if direHPpercent >= radiantHPpercent then
        victor = DOTA_TEAM_BADGUYS
        s = "Dire"
      end
    end
  else
    -- Find someone alive and declare that team the winner (since all other team is dead)
    self:LoopOverPlayers(function(player, plyID)
      if player.bDead == false then
        victor = player.nTeam
        if victor == DOTA_TEAM_BADGUYS then
          s = "Dire"
        end
      end
    end)
  end

  local timeBonus = 0
  if elapsedTime < ROUND_TIME / 8 then
    timeBonus = GOLD_TIME_BONUS_1
  elseif elapsedTime < ROUND_TIME / 4 then
    timeBonus = GOLD_TIME_BONUS_2
  elseif elapsedTime < ROUND_TIME / 2 then
    timeBonus = GOLD_TIME_BONUS_3
  end

  if victor == DOTA_TEAM_GOODGUYS then
    self.nRadiantScore = self.nRadiantScore + 1
  else
    self.nDireScore = self.nDireScore + 1
  end

  GameMode:SetTopBarTeamValue ( DOTA_TEAM_BADGUYS, self.nDireScore )
  GameMode:SetTopBarTeamValue ( DOTA_TEAM_GOODGUYS, self.nRadiantScore )

  Say(nil, s .. " WINS the round!         TimeBonus: " .. tostring(timeBonus) .. "g", false)
  --Say(nil, "Overall Score:  " .. self.nRadiantScore .. " - " .. self.nDireScore, false)

  -- Check if at max round
  -- Complete game entirely and declare an overall victor
  if self.nRadiantScore == ROUNDS_TO_WIN then
    Say(nil, "RADIANT WINS!!  Well Played!", false)
    GameRules:SetSafeToLeave( true )
    GameRules:SetGameWinner( DOTA_TEAM_GOODGUYS )
    self:CreateTimer('endGame', {
    endTime = Time() + POST_GAME_TIME,
    callback = function(reflex, args)
      ReflexGameMode:CloseServer()
    end})
    return
  elseif self.nDireScore == ROUNDS_TO_WIN then
    Say(nil, "DIRE WINS!!  Well Played!", false)
    GameRules:SetSafeToLeave( true )
    GameRules:SetGameWinner( DOTA_TEAM_BADGUYS )
    self:CreateTimer('endGame', {
    endTime = Time() + POST_GAME_TIME,
    callback = function(reflex, args)
      ReflexGameMode:CloseServer()
    end})
    return
  end

  -- Figure out how much gold per team
  -- Figure out how many levels per team
  -- Grant gold and levels
  -- Go through players and flag for re-init
  -- Maybe halt playerInit functionality until done?

  local baseGoldRadiant = 0
  local baseGoldDire = 0
  local baseLevelsRadiant = 0
  local baselevelsDire = 0

  -- TODO
  -- MVP Tracking?

  self:LoopOverPlayers(function(player, plyID)
    local gold = 0
    local levels = 0

    if player.nTeam == victor then
      gold = GOLD_PER_ROUND_WINNER + timeBonus
      levels = LEVELS_PER_ROUND_WINNER
    else
      gold = GOLD_PER_ROUND_LOSER
      levels = LEVELS_PER_ROUND_LOSER
    end

    -- Player survived
    if player.nTeam ~= victor and player.bDead == false then
      gold = gold + GOLD_PER_SURVIVE
    end

    gold = gold + GOLD_PER_KILL * player.nKillsThisRound

    player.nUnspentGold = player.nUnspentGold + gold
    player.fLevel = player.fLevel + levels
    player.bRoundInit = false
  end)


  self.nCurrentRound = self.nCurrentRound + 1
  self.nRadiantDead = 0
  self.nDireDead = 0
  self.nLastKilled = nil

  self:InitializeRound()
end

function ReflexGameMode:Think()
  --print ( '[REFLEX] Thinking' )
  -- If the game's over, it's over.
  if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
    -- self._scriptBind:EndThink( "GameThink" )
    --ReflexGameMode:EndThink( "GameThink" )
    return
  end

  -- Track game time, since the dt passed in to think is actually wall-clock time not simulation time.
  local now = GameRules:GetGameTime()
  --print("now: " .. now)
  if ReflexGameMode.t0 == nil then
    ReflexGameMode.t0 = now
  end
  local dt = now - ReflexGameMode.t0
  ReflexGameMode.t0 = now

  ReflexGameMode:thinkState( dt )

  -- Process timers
  for k,v in pairs(ReflexGameMode.timers) do
    local bUseGameTime = false
    if v.useGameTime and v.useGameTime == true then
      bUseGameTime = true;
    end
    -- Check if the timer has finished
    if (bUseGameTime and GameRules:GetGameTime() > v.endTime) or (not bUseGameTime and Time() > v.endTime) then
      -- Remove from timers list
      ReflexGameMode.timers[k] = nil

      --print ( '[REFLEX] Running timer: ' .. k)

      -- Run the callback
      local status, nextCall = pcall(v.callback, ReflexGameMode, v)

      -- Make sure it worked
      if status then
        -- Check if it needs to loop
        if nextCall then
          -- Change it's end time
          v.endTime = nextCall
          ReflexGameMode.timers[k] = v
        end

        -- Update timer data
        --self:UpdateTimerData()
      else
        -- Nope, handle the error
        ReflexGameMode:HandleEventError('Timer', k, nextCall)
      end
    end
  end

  return THINK_TIME
end

function ReflexGameMode:HandleEventError(name, event, err)
  -- This gets fired when an event throws an error

  -- Log to console
  print(err)

  -- Ensure we have data
  name = tostring(name or 'unknown')
  event = tostring(event or 'unknown')
  err = tostring(err or 'unknown')

  -- Tell everyone there was an error
  print("[REFLEX] " .. name .. ' threw an error on event ' .. event)
  print("[REFLEX] " .. err)
  --Say(nil, name .. ' threw an error on event '..event, false)
  --Say(nil, err, false)

  -- Prevent loop arounds
  if not self.errorHandled then
    -- Store that we handled an error
    self.errorHandled = true

    -- End the gamemode
    --self:EndGamemode()
  end
end

function ReflexGameMode:CreateTimer(name, args)
  --[[
  args: {
  endTime = Time you want this timer to end: Time() + 30 (for 30 seconds from now),
  useGameTime = use Game Time instead of Time()
  callback = function(frota, args) to run when this timer expires,
  text = text to display to clients,
  send = set this to true if you want clients to get this,
  persist = bool: Should we keep this timer even if the match ends?
  }

  If you want your timer to loop, simply return the time of the next callback inside of your callback, for example:

  callback = function()
  return Time() + 30 -- Will fire again in 30 seconds
  end
  ]]

  if not args.endTime or not args.callback then
    print("Invalid timer created: "..name)
    return
  end

  -- Store the timer
  self.timers[name] = args

  -- Update the timer
  --self:UpdateTimerData()
end

function ReflexGameMode:RemoveTimer(name)
  -- Remove this timer
  self.timers[name] = nil

  -- Update the timers
  --self:UpdateTimerData()
end

function ReflexGameMode:RemoveTimers(killAll)
  local timers = {}

  -- If we shouldn't kill all timers
  if not killAll then
    -- Loop over all timers
    for k,v in pairs(self.timers) do
      -- Check if it is persistant
      if v.persist then
        -- Add it to our new timer list
        timers[k] = v
      end
    end
  end

  -- Store the new batch of timers
  self.timers = timers
end

function ReflexGameMode:_WatConsoleCommand()
  print( '******* Reflex Game Status ***************' )
  local cmdPlayer = Convars:GetCommandClient()
  if cmdPlayer then
    local playerID = cmdPlayer:GetPlayerID()
    if playerID ~= nil and playerID ~= -1 then
      print ( string.format ( 'PlayerdID: %d called wat', playerID ) )
    end
  end

  PrintTable(self.vPlayers)
  print( '*********************************************' )
end

function ReflexGameMode:OnPlayerKilled(keys)
  print('[REFLEX] OnPlayerKilled')
  PrintTable(keys)
  PrintTable(getmetatable(keys))
  print('-----------------------')
end

function ReflexGameMode:OnEntityKilled( keys )
  print( '[REFLEX] OnEntityKilled Called' )
  PrintTable( keys )
  local killedUnit = EntIndexToHScript( keys.entindex_killed )
  print( '[REFLEX] Got KilledUnit' )
  local killerEntity = nil

  if keys.entindex_attacker ~= nil then
    killerEntity = EntIndexToHScript( keys.entindex_attacker )
  end

  print( '[REFLEX] Got KillerEntity if exists' )

  -- Clean up units remaining...
  local enemyData = nil
  if killedUnit then
    print( '[REFLEX] KilledUnit exists' )
    if killerEntity then
      local killerID = killerEntity:GetPlayerOwnerID()
      if self.vPlayers[killerID] ~= nil then
        self.vPlayers[killerID].nKillsThisRound = self.vPlayers[killerID].nKillsThisRound + 1
        print( string.format( '%s killed %s', killerEntity:GetPlayerOwnerID(), killedUnit:GetPlayerOwnerID()) )
      end
    end
    
    -- Trigger OnDeath abilities
    self:LoopOverPlayers(function(player, plyID)
      --print('Player ' .. plyID .. ' -- Dead: ' .. tostring(player.bDead) .. ' -- Team: ' .. tostring(player.nTeam))
      if player.bDead == false and player.nTeam == killedUnit:GetTeam() then
        for onDeath,scale in pairs(ABILITY_ON_DEATH) do
          local ability = player.hero:FindAbilityByName(onDeath)
          --print('     ' .. onDeath .. ' -- ' .. tostring(ability or 'NOPE'))
          if ability ~= nil and ability:GetLevel() ~= 0 then
            callModApplier(player.hero, onDeath, ability:GetLevel())
            player.hero:SetModelScale(1 + ((scale - 1) * (ability:GetLevel() / 4)), 1)
            self:CreateTimer('resetScale' .. plyID,{
              endTime = GameRules:GetGameTime() + ability:GetSpecialValueFor("duration") + (ability:GetLevel() - 1),
              useGameTime = true,
              callback = function() 
                player.hero:SetModelScale(1, 1)
              end})
          end
        end
      end
    end)

    local killedID = killedUnit:GetPlayerOwnerID()
    self.vPlayers[killedID].bDead = true
    if killedUnit:GetUnitName() then
      print( string.format( '[REFLEX] %s died', killedUnit:GetUnitName() ) )
    else
      print ( "[REFLEX] couldn't get unit name")
    end

    -- Fix Gold
    self:LoopOverPlayers(function(player, plyID)
      player.hero:SetGold(0, true)
      --player.hero:SetGold(0, false)
      --PlayerResource:SetGold(plyID, 0, true)
      --PlayerResource:SetGold(plyID, 0, false)
    end)

    if killedUnit:GetTeam() == DOTA_TEAM_GOODGUYS then
      self.nRadiantDead = self.nRadiantDead + 1
      self.nLastKilled = DOTA_TEAM_GOODGUYS
    else
      self.nDireDead = self.nDireDead + 1
      self.nLastKilled = DOTA_TEAM_BADGUYS
    end

    -- Victory Check
    local nRadiantAlive = 0
    local nDireAlive = 0
    self:LoopOverPlayers(function(player, plyID)
      if player.bDead == false then
        if player.nTeam == DOTA_TEAM_GOODGUYS then
          nRadiantAlive = nRadiantAlive + 1
        else
          nDireAlive = nDireAlive + 1
        end
      end
    end)

    print ('RAlive: ' .. tostring(nRadiantAlive) .. ' -- DAlive: ' .. tostring(nDireAlive))

    if nRadiantAlive == 0 or nDireAlive == 0 then
      self:RemoveTimer('round_time_out')
    
      self:LoopOverPlayers(function(player, plyID)
        if player.bDead == false then
          player.hero:AddNewModifier( player.hero, nil , "modifier_invulnerable", {})
        end
      end)  
      self:CreateTimer('victory', {
        endTime = Time() + POST_ROUND_TIME,
        callback = function(reflex, args)
          ReflexGameMode:RoundComplete(false)
        end})
      return
    end

    -- Trigger Last Man Standing buff(s)
    if nRadiantAlive == 1 and nDireAlive == 1 then
      --[[ Cancel LMS buffs
      self:LoopOverPlayers(function(player, plyID)
        if player.bDead == false then
          self:FindAndRemoveMod(player.hero, 'reflex_lms_friendly')
          self:FindAndRemoveMod(player.hero, 'reflex_lms_enemy_1')
          self:FindAndRemoveMod(player.hero, 'reflex_lms_enemy_2')
          self:FindAndRemoveMod(player.hero, 'reflex_lms_enemy_3')
          self:FindAndRemoveMod(player.hero, 'reflex_lms_enemy_4')
          self:FindAndRemoveMod(player.hero, 'reflex_lms_enemy_5')
        end
      end)]]
    elseif killedUnit:GetTeam() == DOTA_TEAM_GOODGUYS and nRadiantAlive == 1 then
      self:LoopOverPlayers(function(player, plyID)
        --print('Player ' .. plyID .. ' -- Dead: ' .. tostring(player.bDead) .. ' -- Team: ' .. tostring(player.nTeam))
        if player.bDead == false and player.nTeam == DOTA_TEAM_GOODGUYS then
          callModApplier(player.hero, "reflex_lms_friendly")
        elseif player.bDead == false and player.nTeam == DOTA_TEAM_BADGUYS then
          --print ('     Rad Dead:' .. self.nRadiantDead)
          callModApplier(player.hero, "reflex_lms_enemy", nDireAlive)
        end
      end)
    elseif killedUnit:GetTeam() == DOTA_TEAM_BADGUYS and nDireAlive == 1 then
      self:LoopOverPlayers(function(player, plyID)
        --print('Player ' .. plyID .. ' -- Dead: ' .. tostring(player.bDead) .. ' -- Team: ' .. tostring(player.nTeam))
        if player.bDead == false and player.nTeam == DOTA_TEAM_BADGUYS then
          callModApplier(player.hero, "reflex_lms_friendly")
        elseif player.bDead == false and player.nTeam == DOTA_TEAM_GOODGUYS then
          --print ('     Dire Dead:' .. self.nDireDead)
          callModApplier(player.hero, "reflex_lms_enemy", nRadiantAlive)
        end
      end)
    end
  end
end

function ReflexGameMode:FindAndRemove(hero, abilityName)
  if hero == nil or abilityName == nil then
    return
  end

  local ability = hero:FindAbilityByName(abilityName)
  if ability == nil then
    return
  end

  hero:RemoveAbility(abilityName)
end

function ReflexGameMode:FindAndRemoveMod(hero, modName)
  if hero:HasModifier(modName) then
    hero:RemoveModifierByName(modName)
  end
end

function callModRemover( caster, modName, abilityLevel)
  if abilityLevel == nil then
    abilityLevel = ""
  else
    abilityLevel = "_" .. abilityLevel
  end
  local applier = modName .. abilityLevel .. "_applier"
  local ab = caster:FindAbilityByName(applier)
  if ab == nil then
    caster:AddAbility(applier)
    ab = caster:FindAbilityByName( applier )
  end
  ab:OnChannelFinish(true)
  --caster:CastAbilityNoTarget(ab, -1)
  caster:RemoveAbility(applier)
end

function callModApplier( caster, modName, abilityLevel)
  if abilityLevel == nil then
    abilityLevel = ""
  else
    abilityLevel = "_" .. abilityLevel
  end
  local applier = modName .. abilityLevel .. "_applier"
  local ab = caster:FindAbilityByName(applier)
  if ab == nil then
    caster:AddAbility(applier)
    ab = caster:FindAbilityByName( applier )
  end
  caster:CastAbilityNoTarget(ab, -1)
  caster:RemoveAbility(applier)
end

-- A helper function for dealing damage from a source unit to a target unit.  Damage dealt is pure damage
function dealDamage(source, target, damage)
    if damage <= 0 or source == nil or target == nil then
      return
    end
    -- target:AddNewModifier(source, nil, "modifier_invoker_tornado", {land_damage = damage, duration = 0} )
    local dmgTable = {4096,2048,1024,512,256,128,64,32,16,8,4,2,1}
    local item = CreateItem( "item_deal_damage", source, source) --creates an item
    for i=1,#dmgTable do
      local val = dmgTable[i]
      local count = math.floor(damage / val)
      if count >= 1 then
          item:ApplyDataDrivenModifier( source, target, "dealDamage" .. val, {duration=0} )
          damage = damage - val
      end
    end
    UTIL_RemoveImmediate(item)
    item = nil
    --print("removed")
end


function dealDamage2(source, target, damage)
  local unit = nil
  if damage == 0 then
    return
  end
  
  if source ~= nil then
    unit = CreateUnitByName("npc_dota_danger_indicator", target:GetAbsOrigin(), false, source, source, source:GetTeamNumber())
  else
    unit = CreateUnitByName("npc_dota_danger_indicator", target:GetAbsOrigin(), false, nil, nil, DOTA_TEAM_NOTEAM)
  end
  unit:AddNewModifier(unit, nil, "modifier_invulnerable", {})
  unit:AddNewModifier(unit, nil, "modifier_phased", {})
  --local dummy = unit:FindAbilityByName("reflex_dummy_unit")
  --dummy:SetLevel(1)
  
  local maxTimes = math.floor(damage / 2000)
  local remainder = math.floor(damage % 2000)
  local abilIndex = math.floor((remainder-1) / 20) + 1
  local abilLevel = math.floor(((remainder-1) % 20)) + 1
  
  local hp = target:GetHealth()
  
  if remainder ~= 0 then
    local abilityName = "modifier_damage_applier" .. abilIndex
    unit:AddAbility(abilityName)
    local ability = unit:FindAbilityByName( abilityName )
    ability:SetLevel(abilLevel)
    
    local diff = nil
    
    diff = target:GetAbsOrigin() - unit:GetAbsOrigin()
    diff.z = 0
    unit:SetForwardVector(diff:Normalized())
    unit:CastAbilityOnTarget(target, ability, 0 )
  end
  
  for i=1,maxTimes do
    unit:AddAbility("modifier_damage_applier100")
    local ability = unit:FindAbilityByName( "modifier_damage_applier100" )
    ability:SetLevel(20)
    diff = target:GetAbsOrigin() - unit:GetAbsOrigin()
    diff.z = 0
    unit:SetForwardVector(diff:Normalized())
    unit:CastAbilityOnTarget(target, ability, 0 )
  end
  
  ReflexGameMode:CreateTimer(DoUniqueString("damage"), {
    endTime = GameRules:GetGameTime() + 0.2,
    useGameTime = true,
    callback = function(reflex, args)
      unit:Destroy()
      if IsValidEntity(target) and target:GetHealth() == hp and hp ~= 0 and damage ~= 0 then
        print ("[REFLEX] WARNING: dealDamage did no damage -- retrying : " .. hp)
        dealDamage(source, target, damage)
      end
    end
  })
end