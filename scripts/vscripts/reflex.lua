print ('[REFLEX] reflex.lua' )

USE_LOBBY=true
DEBUG=false

REFLEX_VERSION = "0.02"

ROUNDS_TO_WIN = 10
ROUND_TIME = 150 --240
PRE_GAME_TIME = 30 -- 30
PRE_ROUND_TIME = 30 --30
POST_ROUND_TIME = 2
POST_GAME_TIME = 30

STARTING_GOLD = 650--500
GOLD_PER_ROUND_LOSER = 600
GOLD_PER_ROUND_WINNER = 1100
GOLD_PER_KILL = 300
GOLD_PER_MVP = 500
GOLD_PER_SURVIVE = 250
GOLD_TIME_BONUS_1 = 250
GOLD_TIME_BONUS_2 = 150
GOLD_TIME_BONUS_3 = 100

LEVELS_PER_ROUND_LOSER = 2
LEVELS_PER_ROUND_WINNER = 1
MAX_LEVEL = 50

XP_PER_LEVEL_TABLE = {}

for i=1,MAX_LEVEL do
  XP_PER_LEVEL_TABLE[i] = i * 100
end

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
  print('[REFLEX] entity_killed event set')
  ListenToGameEvent('player_connect_full', Dynamic_Wrap(ReflexGameMode, 'AutoAssignPlayer'), self)
  ListenToGameEvent('player_disconnect', Dynamic_Wrap(ReflexGameMode, 'CleanupPlayer'), self)
  ListenToGameEvent('dota_item_purchased', Dynamic_Wrap(ReflexGameMode, 'ShopReplacement'), self)
  ------
  --ListenToGameEvent('dota_player_used_ability', Dynamic_Wrap(ReflexGameMode, 'AbilityUsed'), self)

  local function _boundWatConsoleCommand(...)
    return self:_WatConsoleCommand(...)
  end
  Convars:RegisterCommand( "reflex_wat", _boundWatConsoleCommand, "Report the status of Reflex", 0 )
  print('[REFLEX] reflex_wat set')

  local function _boundSetAbilityConsoleCommand(...)
    return self:_SetAbilityConsoleCommand(...)
  end
  Convars:RegisterCommand( "reflex_set_ability", _boundSetAbilityConsoleCommand, "Set a hero ability", 0 )
  print('[REFLEX] reflex_set_ability set')

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
        
      self:CreateTimer('assign_fakes', {
        endTime = Time(),
        callback = function(reflex, args)
          for i=0, 9 do
            -- Check if this player is a fake one
            if PlayerResource:IsFakeClient(i) then
              -- Grab player instance
              local ply = PlayerResource:GetPlayer(i)
              -- Make sure we actually found a player instance
              if ply then
                CreateHeroForPlayer('npc_dota_hero_axe', ply)
              end
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
  self.nLastKill = nil
  self.fRoundStartTime = 0

  -- Timers
  self.timers = {}

  -- userID map
  self.vUserIds = {}
  self.vSteamIds = {}

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

    GameRules:SetHeroMinimapIconSize( 300 )

    GameMode:SetCustomXPRequiredToReachNextLevel( XP_PER_LEVEL_TABLE )

    print( '[REFLEX] Beginning Think' ) 
    GameMode:SetContextThink("ReflexThink", Dynamic_Wrap( ReflexGameMode, 'Think' ), 0.25 )
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

function ReflexGameMode:CloseServer()
  -- Just exit
  SendToServerConsole('exit')
end

function ReflexGameMode:AutoAssignPlayer(keys)
  print ('[REFLEX] AutoAssignPlayer')
  self:CaptureGameMode()
  print ('[REFLEX] getting index')
  --print(keys.index)
  local entIndex = keys.index+1
  local ply = EntIndexToHScript(entIndex)
  local playerID = ply:GetPlayerID()

  self.nConnected = self.nConnected + 1
  self:RemoveTimer('all_disconnect')
  
  if PlayerResource:IsBroadcaster(playerID) then
    return
  end

  playerID = ply:GetPlayerID()
  if self.vPlayers[playerID] ~= nil then
    self.vUserIds[playerID] = nil
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
  
  --PrintTable(PlayerResource)
  --PrintTable(getmetatable(PlayerResource))
  
  print('[REFLEX] SteamID: ' .. PlayerResource:GetSteamAccountID(playerID))
  self.vUserIds[keys.userid] = ply
  self.vSteamIds[PlayerResource:GetSteamAccountID(playerID)] = ply

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
          nTeam = ply:GetTeam(),
          bRoundInit = false,
          nUnspentAbilityPoints = 1,
          bConnected = true
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

  -- Prevent rebuying existing items
  local baseName = item:GetAbilityName()
  local count = 0
  if string.find(baseName:sub(-1), "2") ~= nil or string.find(baseName:sub(-1), "3") ~= nil or string.find(baseName:sub(-1), "4") ~= nil then
    baseName = baseName:sub(1, -2)
  end
  for i=0,11 do
    --print ( '\t[REFLEX] finding item ' .. i)
    local item2 = player.hero:GetItemInSlot( i )
    --print ( '\t[REFLEX] item: ' .. tostring(item) )
    if item2 ~= nil then
      --print ( '\t[REFLEX] getting ability name' .. i)
      local lname = item2:GetAbilityName()
      --print ( string.format ('[REFLEX] item slot %d: %s', i, lname) )
      if string.find(lname, baseName) then
        count = count + 1
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
  if string.find(item:GetAbilityName(), "item_ability_reflex_") == nil then return end

  --local abilityToAdd = ABILITY_ITEM_TABLE[item:GetAbilityName()]
  local abilityToAdd = string.gsub(item:GetAbilityName(), "item_ability_", "")

  local cost = item:GetCost()
  item:Remove()

  if player.hero:FindAbilityByName (abilityToAdd) ~= nil then 
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
          found = true
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
          found = true
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

        if not player.hero:HasModifier("modifier_stunned") then
          player.hero:AddNewModifier( player.hero, nil , "modifier_stunned", {})
        end

        if not player.hero:HasModifier("modifier_invulnerable") then
          player.hero:AddNewModifier(player.hero, nil , "modifier_invulnerable", {})
        end

        local curXP = PlayerResource:GetTotalEarnedXP(plyID)
        local nextXP = player.fLevel * 100
        print ( '[REFLEX] NextXP: ' .. tostring(nextXP))
        if nextXP > curXP then
          print ( '[REFLEX] XP Boost ' .. tostring(nextXP - curXP))
          --PrintTable(player.hero)
          --PrintTable(getmetatable(player.hero))
          --local diff = math.floor((nextXP - curXP) / 100)
          --local remainder = (nextXP - curXP) % 100

          --player.hero:AddExperience(remainder, true)
          player.hero:AddExperience(nextXP - curXP, false)
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
        player.nUnspentAbilityPoints = player.hero:GetAbilityPoints()
        player.hero:SetAbilityPoints(0)

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
    if self.nLastKill == nil then 
      if self.nRadiantScore > self.nDireScore then
        victor = DOTA_TEAM_BADGUYS
        s = "Dire"
      end
    -- Victor is whoever has least dead
    elseif self.nDireDead < self.nRadiantDead then
      victor = DOTA_TEAM_BADGUYS
      s = "Dire"
      -- If both have same number of dead go by last team that got a kill
    elseif self.nDireDead == self.nRadiantDead and self.nLastKill == DOTA_TEAM_BADGUYS then
      victor = DOTA_TEAM_BADGUYS
      s = "Dire"
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
  self.nLastKill = nil

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

  return 0.25
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
  Say(nil, name .. ' threw an error on event '..event, false)
  Say(nil, err, false)

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

function ReflexGameMode:_SetAbilityConsoleCommand( ... )
  --[[local nArgs = select( '#', ... )
  if nArgs < 3 then
  print ('reflex_set_ability <ability_slot_number> <ability_name>')
  return
  end
  local nSlot = tonumber (select ( 1, ... ))
  local sAbName = select ( 2, ... ))
  print ( 'Set Ability called %d %s', nSlot, sAbName )]]
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
      self.vPlayers[killerID].nKillsThisRound = self.vPlayers[killerID].nKillsThisRound + 1
      print( string.format( '%s killed %s', killerEntity:GetPlayerOwnerID(), killedUnit:GetPlayerOwnerID()) )
    end

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
      player.hero:SetGold(0, false)
      --PlayerResource:SetGold(plyID, 0, true)
      --PlayerResource:SetGold(plyID, 0, false)
    end)

    if killedUnit:GetTeam() == DOTA_TEAM_GOODGUYS then
      self.nRadiantDead = self.nRadiantDead + 1
      self.nLastKill = DOTA_TEAM_GOODGUYS
    else
      self.nDireDead = self.nDireDead + 1
      self.nLastKill = DOTA_TEAM_BADGUYS
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
            print(tostring(1 + ((scale - 1) * (ability:GetLevel() / 4))))
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
      -- Cancel LMS buffs
      self:LoopOverPlayers(function(player, plyID)
        if player.bDead == false then
          self:FindAndRemoveMod(player.hero, 'reflex_lms_friendly')
          self:FindAndRemoveMod(player.hero, 'reflex_lms_enemy_1')
          self:FindAndRemoveMod(player.hero, 'reflex_lms_enemy_2')
          self:FindAndRemoveMod(player.hero, 'reflex_lms_enemy_3')
          self:FindAndRemoveMod(player.hero, 'reflex_lms_enemy_4')
        end
      end)
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
