BAREBONES_DEBUG_SPEW = false 

DEBUG=false
THINK_TIME = 0.1

REFLEX_VERSION = "0.20.02"

ROUNDS_TO_WIN = 8
ROUND_TIME = 210 --150 --240
PRE_GAME_ROUND_TIME = 30 -- 30
PRE_ROUND_TIME = 30 --30
POST_ROUND_TIME = 2

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

MAX_TIPS = 21
TIP_TIMEOUT = 2

ABILITY_ON_DEATH = {
  reflex_vengeance = 1.50,
  reflex_scaredy_cat = 0.6
}

MAP_DATA = LoadKeyValues("scripts/mapdata.kv")

bMapInitialized = false
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


if GameMode == nil then
    DebugPrint( '[BAREBONES] creating barebones game mode' )
    _G.GameMode = class({})
end

-- This library allow for easily delayed/timed actions
require('libraries/timers')
-- This library can be used for advancted physics/motion/collision of units.  See PhysicsReadme.txt for more information.
require('libraries/physics')
-- This library can be used for advanced 3D projectile systems.
require('libraries/projectiles')
-- This library can be used for sending panorama notifications to the UIs of players/teams/everyone
require('libraries/notifications')

-- These internal libraries set up barebones's events and processes.  Feel free to inspect them/change them if you need to.
require('internal/gamemode')
require('internal/events')

-- settings.lua is where you can specify many different properties for your game mode and is one of the core barebones files.
require('settings')
-- events.lua is where you can specify the actions to be taken when any event occurs and is one of the core barebones files.
require('events')

if DEBUG then
  PRE_GAME_TIME = 0 -- 30
  PRE_ROUND_TIME = 15 --30
  PRE_GAME_ROUND_TIME = 0
  ROUND_TIME = 60 --150 --240
end


--[[
  This function should be used to set up Async precache calls at the beginning of the gameplay.

  In this function, place all of your PrecacheItemByNameAsync and PrecacheUnitByNameAsync.  These calls will be made
  after all players have loaded in, but before they have selected their heroes. PrecacheItemByNameAsync can also
  be used to precache dynamically-added datadriven abilities instead of items.  PrecacheUnitByNameAsync will 
  precache the precache{} block statement of the unit and all precache{} block statements for every Ability# 
  defined on the unit.

  This function should only be called once.  If you want to/need to precache more items/abilities/units at a later
  time, you can call the functions individually (for example if you want to precache units in a new wave of
  holdout).

  This function should generally only be used if the Precache() function in addon_game_mode.lua is not working.
]]
function GameMode:PostLoadPrecache()
  DebugPrint("[BAREBONES] Performing Post-Load precache")    
  
  PrecacheUnitByNameAsync("npc_precache_everything", function(...) end)

  if MAP_DATA[GetMapName()].mapscript and not bMapInitialized then
    require(MAP_DATA[GetMapName()].mapscript)
    bMapInitialized = true
    MapScript:Initialize()
  end
end

--[[
  This function is called once and only once as soon as the first player (almost certain to be the server in local lobbies) loads in.
  It can be used to initialize state that isn't initializeable in InitGameMode() but needs to be done before everyone loads in.
]]
function GameMode:OnFirstPlayerLoaded()
  DebugPrint("[BAREBONES] First Player has loaded")

  local globalUnit = CreateUnitByName('npc_dummy_blank', Vector(0,0,0), true, nil, nil, DOTA_TEAM_NOTEAM)
  globalUnit:AddAbility("modifier_applier")
  GameRules.ModApplier = globalUnit:FindAbilityByName("modifier_applier")
  GameRules.ModApplier:SetLevel(1)
  ApplyModifier(globalUnit, globalUnit, "dummy_unit", {})

  GameRules:GetGameModeEntity():SetModifyGoldFilter(Dynamic_Wrap(GameMode, "ModifyGoldFilter"), GameMode)
end

function GameMode:ModifyGoldFilter(event)
  --PrintTable(event)
  --print('--------')
  --print('')
  if event.reason_const == DOTA_ModifyGold_HeroKill then
    return false
  end
end

--[[
  This function is called once and only once after all players have loaded into the game, right as the hero selection time begins.
  It can be used to initialize non-hero player state or adjust the hero selection (i.e. force random etc)
]]
function GameMode:OnAllPlayersLoaded()
  DebugPrint("[BAREBONES] All Players have loaded into the game")
end

--[[
  This function is called once and only once for every player when they spawn into the game for the first time.  It is also called
  if the player's hero is replaced with a new hero for any reason.  This function is useful for initializing heroes, such as adding
  levels, changing the starting gold, removing/adding abilities, adding physics, etc.

  The hero parameter is the hero entity that just spawned in
]]
function GameMode:OnHeroInGame(hero)
  DebugPrint("[BAREBONES] Hero spawned in game for first time -- " .. hero:GetUnitName())

  local playerID = hero:GetPlayerOwnerID()

  local dash = CreateItem("item_reflex_dash", hero, hero)
  hero:AddItem(dash)
  local shooter = CreateItem("item_simple_shooter", hero, hero)
  hero:AddItem(shooter)
  hero:SetCustomDeathXP(0)

  hero:SetGold(0, false)
  hero:SetGold(STARTING_GOLD, true)
  
  print ( "[REFLEX] GOLD SET FOR PLAYER "  .. playerID)
  PlayerResource:SetBuybackCooldownTime( playerID, 0 )
  PlayerResource:SetBuybackGoldLimitTime( playerID, 0 )
  hero:SetMinimumGoldBounty(0)
  hero:SetMaximumGoldBounty(0)
  PlayerResource:ResetBuybackCostTime( playerID )

  hero.originalModelScale = hero:GetModelScale()
  hero.bRoundInit = false
  hero.nLastRoundDamage = 0
  hero.nUnspentAbilityPoints = 1

  self:PlayerRoundInit(hero, playerID) 
  if not bInPreRound then
    self:PlayerRoundStart(hero, playerID)
  end
end

--[[
  This function is called once and only once when the game completely begins (about 0:00 on the clock).  At this point,
  gold will begin to go up in ticks if configured, creeps will spawn, towers will become damageable etc.  This function
  is useful for starting any game logic timers/thinkers, beginning the first round, etc.
]]
function GameMode:OnGameInProgress()
  DebugPrint("[BAREBONES] The game has officially begun")

  Timers:CreateTimer(30, -- Start this timer 30 game-time seconds later
    function()
      DebugPrint("This function is called 30 seconds after the game begins, and every 30 seconds thereafter")
      return 30.0 -- Rerun this timer every 30 game-time seconds 
    end)
end



-- This function initializes the game mode and is called before anyone loads into the game
-- It can be used to pre-initialize any values/tables that will be needed later
function GameMode:InitGameMode()
  GameMode = self
  DebugPrint('[BAREBONES] Starting to load Barebones gamemode...')

  -- Call the internal function to set up the rules/behaviors specified in constants.lua
  -- This also sets up event hooks for all event handlers in events.lua
  -- Check out internals/gamemode to see/modify the exact code
  GameMode:_InitGameMode()

  -- Commands can be registered for debugging purposes or as functions that can be called by the custom Scaleform UI
  Convars:RegisterCommand( "command_example", Dynamic_Wrap(GameMode, 'ExampleConsoleCommand'), "A console command example", FCVAR_CHEAT )

  DebugPrint('[BAREBONES] Done loading Barebones gamemode!\n\n')

   Convars:RegisterCommand('reflex_reset_all', function()
    if not Convars:GetCommandClient() or DEBUG then      
      local heroes = HeroList:GetAllHeroes()
      for i=1,#heroes do
        local hero = heroes[i]
        print ( '[REFLEX] Resetting player ' .. i)
        hero:SetGold(30000, true)
        for i=1,10 do
          hero:HeroLevelUp(false)
        end

        --Remove dangerous abilities
        if hero:HasModifier("modifier_stunned") then
          hero:RemoveModifierByName("modifier_stunned")
        end

        if hero:HasModifier("modifier_invulnerable") then
          hero:RemoveModifierByName("modifier_invulnerable")
        end

        for i=0,11 do
          local item = hero:GetItemInSlot( i )
          if item ~= nil then
            local name = item:GetAbilityName()
            if string.find(name, "item_reflex_dash") == nil and string.find(name, "item_simple_shooter") == nil then
              item:RemoveSelf()
            end
          end
        end
      end
    end
  end, 'Resets all players.', 0)
  
  Convars:RegisterCommand('reflex_test_round_complete', function()
    local cmdPlayer = Convars:GetCommandClient()
    if DEBUG then
      self:RoundComplete(true)
    end
  end, 'Tests the death function', 0)

  Convars:RegisterCommand('player_say', function(...)
    local arg = {...}
    table.remove(arg,1)
    local sayType = arg[1]
    table.remove(arg,1)

    local cmdPlayer = Convars:GetCommandClient()
    keys = {}
    keys.ply = cmdPlayer
    keys.text = table.concat(arg, " ")

    if (sayType == 4) then
      -- Student messages
    elseif (sayType == 3) then
      -- Coach messages
    elseif (sayType == 2) then
      -- Team only
      self:PlayerSay(keys)
    else
      -- All chat
      self:PlayerSay(keys)
    end
  end, 'player say', 0)

  -- Change random seed
  local timeTxt = string.gsub(string.gsub(GetSystemTime(), ':', ''), '0','')
  math.randomseed(tonumber(timeTxt))

  -- Round stuff
  self.nCurrentRound = 1
  self.nLastKilled = nil

  self.bTipsActive = false
  self.nLastTipTime = 0

  self.nRadiantScore = 0
  self.nDireScore = 0
end

function GameMode:PlayerRoundInit(hero, plyID)
  if hero.bRoundInit == false then
    print ( '[REFLEX] Initializing player ' .. plyID)
    hero.bRoundInit = true
    hero:RespawnHero(false, false, false)
    Timers:CreateTimer(1, function()
        FindClearSpaceForUnit(hero, hero:GetAbsOrigin() + RandomVector(100), true)
      end
    )

    hero.nRoundDamage = PlayerResource:GetRawPlayerDamage(plyID) - hero.nLastRoundDamage
    hero.nLastRoundDamage = PlayerResource:GetRawPlayerDamage(plyID)
    --PlayerResource:SetGold(plyID, player.nUnspentGold, true)

    for i=0,11 do
      local item = hero:GetItemInSlot( i )
      if item ~= nil then
        local name = item:GetAbilityName()
        local charge = item:GetInitialCharges()
        if charge ~= nil then
          item:SetCurrentCharges(charge)
        end
      end
    end
    
    if hero:HasModifier("modifier_blade_charge") then
      hero:RemoveModifierByName("modifier_blade_charge")
    end

    if bInPreRound and not hero:HasModifier("modifier_stunned") then
      hero:AddNewModifier( hero, nil , "modifier_stunned", {})
    end

    if bInPreRound and not hero:HasModifier("modifier_invulnerable") then
      hero:AddNewModifier(hero, nil , "modifier_invulnerable", {})
    end
  end
end

function GameMode:PlayerRoundStart(hero, plyID)
  hero.nUnspentAbilityPoints = hero:GetAbilityPoints()
  hero:SetAbilityPoints(0)
  GameRules:SetUseUniversalShopMode( false )

  --if has modifier remove it
  if hero:HasModifier("modifier_stunned") then
    hero:RemoveModifierByName("modifier_stunned")
  end
  
  if hero:HasModifier("modifier_invulnerable") then
    hero:RemoveModifierByName("modifier_invulnerable")
  end
end

function GameMode:InitializeRound()
  print ( '[REFLEX] InitializeRound called' )
  bInPreRound = true
  GameRules:SetUseUniversalShopMode( true )

  if not roundOne then
    local heroes = HeroList:GetAllHeroes()
    for i=1,#heroes do
      local hero = heroes[i]
      self:PlayerRoundInit(hero, hero:GetPlayerID())
    end
  end

  local roundTime = PRE_ROUND_TIME + PRE_GAME_ROUND_TIME
  PRE_GAME_ROUND_TIME = 0
  
  Say(nil, string.format("Round %d starts in %d seconds!", self.nCurrentRound, roundTime), false)
  
  if roundOne then
    Timers:CreateTimer(10,
      function()
        GameRules:SendCustomMessage("Welcome to <font color='#70EA72'>Reflex!</font>", 0, 0)
        GameRules:SendCustomMessage("Version: " .. REFLEX_VERSION, 0, 0)
        GameRules:SendCustomMessage("Created by <font color='#70EA72'>BMD</font>", 0, 0)
        GameRules:SendCustomMessage("Map by <font color='#70EA72'>Azarak</font>", 0, 0)
        GameRules:SendCustomMessage("Send feedback to <font color='#70EA72'>bmddota@gmail.com</font>", 0, 0)

        Notifications:TopToAll("Welcome to ", 8.0, nil, {["font-size"]="72px"})
        Notifications:TopToAll("REFLEX", 8.0, nil, {["font-size"]="72px", color="green"}, true)
        Notifications:TopToAll("!", 8.0, nil, {["font-size"]="72px"}, true)

        Timers:CreateTimer(4, function()
          Notifications:TopToAll("Buy ", 8.0, nil, {["font-size"]="40px"}, false)
          Notifications:TopToAll("ABILITIES ", 8.0, nil, {["font-size"]="40px", color="blue"}, true)
          Notifications:TopToAll("and ", 8.0, nil, {["font-size"]="40px"}, true)
          Notifications:TopToAll("ITEMS ", 8.0, nil, {["font-size"]="40px", color="purple"}, true)
          Notifications:TopToAll("in the ", 8.0, nil, {["font-size"]="40px"}, true)
          Notifications:TopToAll("SHOP", 8.0, nil, {["font-size"]="40px", color="#FFD700"}, true)

          Timers:CreateTimer(6, function()
            Notifications:TopToAll("First to win ", 8.0, nil, {["font-size"]="40px"}, false)
            Notifications:TopToAll("8 ", 8.0, nil, {["font-size"]="72px", color="red"}, true)
            Notifications:TopToAll("rounds is the Winner!", 8.0, nil, {["font-size"]="40px"}, true)
          end)
        end)
      end
    )
    
    Timers:CreateTimer(20, function()
        --GameRules:SendCustomMessage("#Reflex_Tip", 0, 0)
        self.bTipsActive = true
        self.nLastTipTime = Time() - TIP_TIMEOUT
      end
    )
    
    Timers:CreateTimer(30, function()
        local tip1 = RandomInt(1, MAX_TIPS)
    
        local nTime = Time() - TIP_TIMEOUT
        if self.bTipsActive and nTime > self.nLastTipTime then
          GameRules:SendCustomMessage("#Reflex_Tip" .. tip1, 0, 0)
          self.nLastTipTime = Time()
        end
      end
    )
  else
    Timers:CreateTimer(10, function()
        local tip1 = RandomInt(1, MAX_TIPS)
    
        local nTime = Time() - TIP_TIMEOUT
        if self.bTipsActive and nTime > self.nLastTipTime then
          GameRules:SendCustomMessage("#Reflex_Tip" .. tip1, 0, 0)
          self.nLastTipTime = Time()
        end
      end
    )
  end
 
  roundOne = false
  
  local startCount = 7
  --Set Timers for round start announcements
  Timers:CreateTimer('round_start_timer', {
  endTime = roundTime - 10,
  callback = function(reflex, args)
    startCount = startCount - 1
    if startCount == 0 then
      self.fRoundStartTime = GameRules:GetGameTime()
      local heroes = HeroList:GetAllHeroes()
      for i=1,#heroes do
        local hero = heroes[i]
        self:PlayerRoundStart(hero, hero:GetPlayerID())
      end

      local timeoutCount = 14
      Timers:CreateTimer('round_time_out',{
      endTime = ROUND_TIME - 120,
      callback = function(reflex, args)
        timeoutCount = timeoutCount - 1
        if timeoutCount == 0 then 
          -- TIME OUT
          local heroes = HeroList:GetAllHeroes()
          for i=1,#heroes do
            local hero = heroes[i]
            hero:AddNewModifier( hero, nil , "modifier_stunned", {})
            hero:AddNewModifier( hero, nil , "modifier_invulnerable", {})
          end
          Timers:CreateTimer('victory', {
            endTime = POST_ROUND_TIME,
            callback = function(reflex, args)
              GameMode:RoundComplete(true)
            end})

          return
        elseif timeoutCount == 13 then
          Say(nil, "2 minutes remaining!", false)
          return 60
        elseif timeoutCount == 12 then
          Say(nil, "1 minute remaining!", false)
          return 30
        elseif timeoutCount == 11 then
          Say(nil, "30 seconds remaining!", false)
          return 20
        else
          local msg = {
            message = tostring(timeoutCount),
            duration = 0.9
          }
          FireGameEvent("show_center_message",msg)
          return 1
        end
      end})

      bInPreRound = false;
      local msg = {
        message = "FIGHT!",
        duration = 0.9
      }
      FireGameEvent("show_center_message",msg)
      return
    elseif startCount == 6 then
      Say(nil, "10 seconds remaining!", false)
      return 5
    else
      local msg = {
        message = tostring(startCount),
        duration = 0.9
      }
      FireGameEvent("show_center_message",msg)
      return 1
    end
  end})

end

function GameMode:RoundComplete(timedOut)
  print ('[REFLEX] Round Complete')
  
  Timers:RemoveTimer('round_start_timer')
  Timers:RemoveTimer('round_time_out')
  Timers:RemoveTimer('victory')

  local elapsedTime = GameRules:GetGameTime() - self.fRoundStartTime - POST_ROUND_TIME

  -- Determine Victor and boost Dire/Radiant score
  local victor = DOTA_TEAM_GOODGUYS
  local s = "Radiant"
  local heroes = HeroList:GetAllHeroes()
  local nRadiantDead = 0
  local nDireDead = 0

  for i=1,#heroes do
    local hero = heroes[i]
    if hero:GetTeam() == DOTA_TEAM_GOODGUYS and not hero:IsAlive() then
      nRadiantDead = nRadiantDead + 1
    elseif hero:GetTeam() == DOTA_TEAM_BADGUYS and not hero:IsAlive() then
      nDireDead = nDireDead + 1
    end
  end

  if timedOut then
    --If noteam score any kill, the team on inferior position win this round to prevent from negative attitude
    if self.nLastKilled == nil then 
      if self.nRadiantScore > self.nDireScore then
        victor = DOTA_TEAM_BADGUYS
        s = "Dire"
      end
    -- Victor is whoever has least dead
    elseif nDireDead < nRadiantDead then
      victor = DOTA_TEAM_BADGUYS
      s = "Dire"
      -- If both have same number of dead go by final hp percent of heroes
    elseif nDireDead == nRadiantDead then 
      local radiantHPpercent = 0
      local direHPpercent = 0
      for i=1,#heroes do
        local hero = heroes[i]
        if hero:IsAlive() then
          if hero:GetTeam() == DOTA_TEAM_GOODGUYS then
            radiantHPpercent = radiantHPpercent + hero:GetHealthPercent()
          else
            direHPpercent = direHPpercent + hero:GetHealthPercent()
          end
        end
      end
      
      if direHPpercent >= radiantHPpercent then
        victor = DOTA_TEAM_BADGUYS
        s = "Dire"
      end
    end
  else
    -- Find someone alive and declare that team the winner (since all other team is dead)
    for i=1,#heroes do
      local hero = heroes[i]
      if hero:IsAlive() then
        victor = hero:GetTeam()
        if victor == DOTA_TEAM_BADGUYS then
          s = "Dire"
        end
      end
    end
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

  --print("ref_round_complete {round=" .. self.nCurrentRound .. ", victor=" .. victor .. "}")
  GameRules:GetGameModeEntity():SetTopBarTeamValue ( DOTA_TEAM_BADGUYS, self.nDireScore )
  GameRules:GetGameModeEntity():SetTopBarTeamValue ( DOTA_TEAM_GOODGUYS, self.nRadiantScore )

  Say(nil, s .. " WINS the round!         TimeBonus: " .. tostring(timeBonus) .. "g", false)
  --Say(nil, "Overall Score:  " .. self.nRadiantScore .. " - " .. self.nDireScore, false)

  -- Check if at max round
  -- Complete game entirely and declare an overall victor
  if self.nRadiantScore == ROUNDS_TO_WIN then
    Say(nil, "RADIANT WINS!!  Well Played!", false)
    GameRules:SetSafeToLeave( true )
    GameRules:SetGameWinner( DOTA_TEAM_GOODGUYS )
    return
  elseif self.nDireScore == ROUNDS_TO_WIN then
    Say(nil, "DIRE WINS!!  Well Played!", false)
    GameRules:SetSafeToLeave( true )
    GameRules:SetGameWinner( DOTA_TEAM_BADGUYS )
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

  for i=1,#heroes do
    local hero = heroes[i]
    local plyID = hero:GetPlayerID()
    local gold = 0
    local levels = 0

    if hero:GetTeam() == victor then
      gold = GOLD_PER_ROUND_WINNER + timeBonus
      levels = LEVELS_PER_ROUND_WINNER
    else
      gold = GOLD_PER_ROUND_LOSER
      levels = LEVELS_PER_ROUND_LOSER
    end

    -- Player survived
    if hero:GetTeam() ~= victor and hero:IsAlive() then
      gold = gold + GOLD_PER_SURVIVE
    end

    --gold = gold + GOLD_PER_KILL * player.nKillsThisRound

    --player.nUnspentGold = player.nUnspentGold + gold
    hero:SetGold(PlayerResource:GetReliableGold(hero:GetPlayerID()) + gold, true)
    hero:SetAbilityPoints(hero.nUnspentAbilityPoints)
    hero:AddExperience(levels * 100, DOTA_ModifyXP_Unspecified, false, true)
    hero.bRoundInit = false
  end


  self.nCurrentRound = self.nCurrentRound + 1
  self.nLastKilled = nil
  self.fRoundStartTime = 0

  self:InitializeRound()
end


function GameMode:PlayerSay(keys)
  print ('[REFLEX] PlayerSay')
  PrintTable(keys)
  
  local ply = keys.ply--self.vUserIds[keys.userid]
  if ply == nil then
    return
  end
  
  local plyID = ply:GetPlayerID()
  if not PlayerResource:IsValidPlayer(plyID) then
    return
  end
  
  if not PlayerResource:IsValidTeamPlayer(plyID) then
    return
  end

  local hero = PlayerResource:GetPlayer(plyID):GetAssignedHero()
  if hero == nil then
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

    a = a - 1
    b = b - 1
    
    local abilityA = hero:GetAbilityByIndex(a):GetAbilityName()
    local levelA = hero:FindAbilityByName(abilityA):GetLevel()
    local abilityB = hero:GetAbilityByIndex(b):GetAbilityName()
    local levelB = hero:FindAbilityByName(abilityB):GetLevel()
    
    hero:RemoveAbility(abilityA)
    hero:RemoveAbility(abilityB)
    
    if a < b then
      --Add B first
      hero:AddAbility(abilityB)
      hero:AddAbility(abilityA)
    else
      --Add A first
      hero:AddAbility(abilityA)
      hero:AddAbility(abilityB)
    end
    
    hero:FindAbilityByName(abilityA):SetLevel(levelA)
    hero:FindAbilityByName(abilityB):SetLevel(levelB)
    
    return
  end
  
  if string.find(text, "^-dmg") then
    if string.find(text, "all") then
      local team = hero:GetTeam()
      local heroes = HeroList:GetAllHeroes()
      for i=1,#heroes do
        local h = heroes[i]
        local plyID = h:GetPlayerID()
        if h:GetTeam() == team then
          local name = PlayerResource:GetPlayerName(plyID) or "Tools"
          local total = PlayerResource:GetRawPlayerDamage(plyID)
          local roundDamage = hero.nRoundDamage
          Say(PlayerResource:GetPlayer(plyID), " _ " .. name .. ":  Last Round: " .. roundDamage .. "  --  Total: " .. total, true)
        end
      end
    else
      local name = PlayerResource:GetPlayerName(plyID) or "Tools"
      local total = PlayerResource:GetRawPlayerDamage(plyID)
      local roundDamage = hero.nRoundDamage
      Say(PlayerResource:GetPlayer(plyID), " _ " .. name .. ":  Last Round: " .. roundDamage .. "  --  Total: " .. total, true)
    end
  end

  if string.find(text, "^-colorblind") then
    hero.bColorblind = not hero.bColorblind
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
end


--[[TODO Fix these to do DD]]

function callModRemover( caster, modName, abilityLevel)
  if abilityLevel == nil then
    abilityLevel = ""
  else
    abilityLevel = "_" .. abilityLevel
  end
  caster:RemoveModifierByName(modName .. abilityLevel)
end

function callModApplier( caster, modName, abilityLevel)

  if abilityLevel == nil then
    abilityLevel = ""
  else
    abilityLevel = "_" .. abilityLevel
  end
  
  ApplyModifier(caster, caster, modName .. abilityLevel, {})
end

function ApplyModifier(source, target, name, args)
  GameRules.ModApplier:ApplyDataDrivenModifier(source, target, name, args)
end

--===============================================

-- A helper function for dealing damage from a source unit to a target unit.  Damage dealt is pure damage
function dealDamage(source, target, damage)
    if damage <= 0 or source == nil or target == nil then
      return
    end
    local damTable = {
      victim = target,
      attacker = source,
      damage = damage,
      damage_type = DAMAGE_TYPE_PURE,
      damage_flags = 0
    }

    ApplyDamage(damTable)
end



-- This is an example console command
function GameMode:ExampleConsoleCommand()
  print( '******* Example Console Command ***************' )
  local cmdPlayer = Convars:GetCommandClient()
  if cmdPlayer then
    local playerID = cmdPlayer:GetPlayerID()
    if playerID ~= nil and playerID ~= -1 then
      -- Do something here for the player who called this command
      PlayerResource:ReplaceHeroWith(playerID, "npc_dota_hero_viper", 1000, 1000)
    end
  end

  print( '*********************************************' )
end

function GameMode:GetItemByName( hero, name )
  for i=0,11 do
    local item = hero:GetItemInSlot( i )
    if item ~= nil then
      local lname = item:GetAbilityName()
      if lname == name then
        return item
      end
    end
  end

  return nil
end