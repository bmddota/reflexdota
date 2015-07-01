-- This file contains all barebones-registered events and has already set up the passed-in parameters for your use.
-- Do not remove the GameMode:_Function calls in these events as it will mess with the internal barebones systems.

-- Cleanup a player when they leave
function GameMode:OnDisconnect(keys)
  DebugPrint('[BAREBONES] Player Disconnected ' .. tostring(keys.userid))
  DebugPrintTable(keys)

  local name = keys.name
  local networkid = keys.networkid
  local reason = keys.reason
  local userid = keys.userid

end
-- The overall game state has changed
function GameMode:OnGameRulesStateChange(keys)
  DebugPrint("[BAREBONES] GameRules State Changed")
  DebugPrintTable(keys)

  -- This internal handling is used to set up main barebones functions
  GameMode:_OnGameRulesStateChange(keys)

  local newState = GameRules:State_Get()

  if newState == DOTA_GAMERULES_STATE_PRE_GAME then
    print("[REFLEX] The pre-game has officially begun")
    GameMode:InitializeRound()
  end
end

-- An NPC has spawned somewhere in game.  This includes heroes
function GameMode:OnNPCSpawned(keys)
  DebugPrint("[BAREBONES] NPC Spawned")
  DebugPrintTable(keys)

  -- This internal handling is used to set up main barebones functions
  GameMode:_OnNPCSpawned(keys)

  local npc = EntIndexToHScript(keys.entindex)
end

-- An entity somewhere has been hurt.  This event fires very often with many units so don't do too many expensive
-- operations here
function GameMode:OnEntityHurt(keys)
  --DebugPrint("[BAREBONES] Entity Hurt")
  --DebugPrintTable(keys)

  local damagebits = keys.damagebits -- This might always be 0 and therefore useless
  local entCause = EntIndexToHScript(keys.entindex_attacker)
  local entVictim = EntIndexToHScript(keys.entindex_killed)
end

-- An item was picked up off the ground
function GameMode:OnItemPickedUp(keys)
  DebugPrint( '[BAREBONES] OnItemPickedUp' )
  DebugPrintTable(keys)

  local heroEntity = EntIndexToHScript(keys.HeroEntityIndex)
  local itemEntity = EntIndexToHScript(keys.ItemEntityIndex)
  local player = PlayerResource:GetPlayer(keys.PlayerID)
  local itemname = keys.itemname
end

-- A player has reconnected to the game.  This function can be used to repaint Player-based particles or change
-- state as necessary
function GameMode:OnPlayerReconnect(keys)
  DebugPrint( '[BAREBONES] OnPlayerReconnect' )
  DebugPrintTable(keys) 
end

-- An item was purchased by a player
function GameMode:OnItemPurchased( keys )
  DebugPrint( '[BAREBONES] OnItemPurchased' )
  DebugPrintTable(keys)

  -- The playerID of the hero who is buying something
  local plyID = keys.PlayerID
  if not plyID or not PlayerResource:IsValidPlayer(plyID) then return end

  local player = PlayerResource:GetPlayer(plyID)

  local hero = player:GetAssignedHero()

  -- The name of the item purchased
  local itemName = keys.itemname 
  
  -- The cost of the item purchased
  local itemcost = keys.itemcost
  
  local item = GameMode:GetItemByName(hero, keys.itemname)
  if not item then 
    return
  end

  if hero.skipPurchase and GameRules:GetGameTime() <= hero.skipPurchase then
    local cost = item:GetCost()
    hero:SetGold(PlayerResource:GetReliableGold(hero:GetPlayerID()) + cost, true)

    item:RemoveSelf()
    return
  end

  local recipe1 = string.match(itemName, "^item_recipe_(.*)$")
  local baseName = itemName
  if recipe1 ~= nil then
    baseName = "item_" .. recipe1
  end
  local power = 1

  if string.find(baseName:sub(-1), "2") ~= nil or string.find(baseName:sub(-1), "3") ~= nil or string.find(baseName:sub(-1), "4") ~= nil then
    baseName = baseName:sub(1, -3)
  end
  baseName = baseName:sub(6)

  local count = 0

  print('purchasing ' .. itemName)

  for i=0,11 do
    local item2 = hero:GetItemInSlot( i )
    if item2 ~= nil then
      local lname = item2:GetAbilityName()
      if string.find(lname, baseName) then
        count = count + 1
        if string.find(lname, "^item_recipe") == nil and (string.find(lname:sub(-1), "2") ~= nil or string.find(lname:sub(-1), "3") ~= nil or string.find(lname:sub(-1), "4") ~= nil) then
          local npower = tonumber(lname:sub(-1))
          if npower > power then
            power = npower 
          end
        end
      end
    end
  end

  if count > 1 then
    local cost = item:GetCost()
    hero:SetGold(PlayerResource:GetReliableGold(hero:GetPlayerID())  + cost, true)

    item:RemoveSelf()

    local nextpower = "item_recipe_" .. baseName .. "_" .. (power+1)
    local nextcost = GetItemCost(nextpower)
    if nextcost > 0 and hero:GetGold() >= nextcost then
      --local newitem = CreateItem(nextpower, hero, hero)
      hero:SetGold(PlayerResource:GetReliableGold(hero:GetPlayerID())  - nextcost, true)
      hero:AddItemByName(nextpower)
      hero.skipPurchase = GameRules:GetGameTime() + .2
    end

    return
  end

  if recipe1 ~= nil then
    local cost = item:GetCost()
    hero:SetGold(PlayerResource:GetReliableGold(hero:GetPlayerID()) + cost, true)

    item:RemoveSelf()
    return
  end


  -- We're done if it's not an ability item
  if string.find(item:GetAbilityName(), "item_ability_reflex_") == nil then 
    return
  end

  local abilityToAdd = string.gsub(item:GetAbilityName(), "item_ability_", "")

  local cost = item:GetCost()
  item:RemoveSelf()
  
  -- Make sure we have an empty space
  local noEmptySpace = true
  for i=0,5 do
    local abil = hero:GetAbilityByIndex(i)
    if string.find(abil:GetAbilityName(), "reflex_empty") then
      noEmptySpace = false
    end
  end

  if hero:FindAbilityByName (abilityToAdd) ~= nil or noEmptySpace then 
    hero:SetGold(PlayerResource:GetReliableGold(hero:GetPlayerID()) + cost, true)
    return 
  end

  local order = {0,1,2,5,3,4}

  if ABILITY_ITEM_TABLE[abilityToAdd] == 1 then
    order = {4,3,5,2,1,0}
  end

  local found = false
  for k,i in pairs(order) do
    if not found then
      local ability = hero:GetAbilityByIndex(i)
      if string.find(ability:GetAbilityName(), "reflex_empty") then
        --print ( '[REFLEX] found empty' .. i .. " replacing")
        hero:RemoveAbility(ability:GetAbilityName())
        hero:AddAbility(abilityToAdd)
        found = true
      end
    end
  end

end

-- An ability was used by a player
function GameMode:OnAbilityUsed(keys)
  DebugPrint('[BAREBONES] AbilityUsed')
  DebugPrintTable(keys)

  local player = PlayerResource:GetPlayer(keys.PlayerID)
  local abilityname = keys.abilityname
end

-- A non-player entity (necro-book, chen creep, etc) used an ability
function GameMode:OnNonPlayerUsedAbility(keys)
  DebugPrint('[BAREBONES] OnNonPlayerUsedAbility')
  DebugPrintTable(keys)

  local abilityname=  keys.abilityname
end

-- A player changed their name
function GameMode:OnPlayerChangedName(keys)
  DebugPrint('[BAREBONES] OnPlayerChangedName')
  DebugPrintTable(keys)

  local newName = keys.newname
  local oldName = keys.oldName
end

-- A player leveled up an ability
function GameMode:OnPlayerLearnedAbility( keys)
  DebugPrint('[BAREBONES] OnPlayerLearnedAbility')
  DebugPrintTable(keys)

  local player = EntIndexToHScript(keys.player)
  local abilityname = keys.abilityname
end

-- A channelled ability finished by either completing or being interrupted
function GameMode:OnAbilityChannelFinished(keys)
  DebugPrint('[BAREBONES] OnAbilityChannelFinished')
  DebugPrintTable(keys)

  local abilityname = keys.abilityname
  local interrupted = keys.interrupted == 1
end

-- A player leveled up
function GameMode:OnPlayerLevelUp(keys)
  DebugPrint('[BAREBONES] OnPlayerLevelUp')
  DebugPrintTable(keys)

  local player = EntIndexToHScript(keys.player)
  local level = keys.level
end

-- A player last hit a creep, a tower, or a hero
function GameMode:OnLastHit(keys)
  DebugPrint('[BAREBONES] OnLastHit')
  DebugPrintTable(keys)

  local isFirstBlood = keys.FirstBlood == 1
  local isHeroKill = keys.HeroKill == 1
  local isTowerKill = keys.TowerKill == 1
  local player = PlayerResource:GetPlayer(keys.PlayerID)
  local killedEnt = EntIndexToHScript(keys.EntKilled)
end

-- A tree was cut down by tango, quelling blade, etc
function GameMode:OnTreeCut(keys)
  DebugPrint('[BAREBONES] OnTreeCut')
  DebugPrintTable(keys)

  local treeX = keys.tree_x
  local treeY = keys.tree_y
end

-- A rune was activated by a player
function GameMode:OnRuneActivated (keys)
  DebugPrint('[BAREBONES] OnRuneActivated')
  DebugPrintTable(keys)

  local player = PlayerResource:GetPlayer(keys.PlayerID)
  local rune = keys.rune

  --[[ Rune Can be one of the following types
  DOTA_RUNE_DOUBLEDAMAGE
  DOTA_RUNE_HASTE
  DOTA_RUNE_HAUNTED
  DOTA_RUNE_ILLUSION
  DOTA_RUNE_INVISIBILITY
  DOTA_RUNE_BOUNTY
  DOTA_RUNE_MYSTERY
  DOTA_RUNE_RAPIER
  DOTA_RUNE_REGENERATION
  DOTA_RUNE_SPOOKY
  DOTA_RUNE_TURBO
  ]]
end

-- A player took damage from a tower
function GameMode:OnPlayerTakeTowerDamage(keys)
  DebugPrint('[BAREBONES] OnPlayerTakeTowerDamage')
  DebugPrintTable(keys)

  local player = PlayerResource:GetPlayer(keys.PlayerID)
  local damage = keys.damage
end

-- A player picked a hero
function GameMode:OnPlayerPickHero(keys)
  DebugPrint('[BAREBONES] OnPlayerPickHero')
  DebugPrintTable(keys)

  local heroClass = keys.hero
  local heroEntity = EntIndexToHScript(keys.heroindex)
  local player = EntIndexToHScript(keys.player)
end

-- A player killed another player in a multi-team context
function GameMode:OnTeamKillCredit(keys)
  DebugPrint('[BAREBONES] OnTeamKillCredit')
  DebugPrintTable(keys)

  local killerPlayer = PlayerResource:GetPlayer(keys.killer_userid)
  local victimPlayer = PlayerResource:GetPlayer(keys.victim_userid)
  local numKills = keys.herokills
  local killerTeamNumber = keys.teamnumber
end

-- An entity died
function GameMode:OnEntityKilled( keys )
  DebugPrint( '[BAREBONES] OnEntityKilled Called' )
  DebugPrintTable( keys )

  GameMode:_OnEntityKilled( keys )
  

  -- The Unit that was Killed
  local killedUnit = EntIndexToHScript( keys.entindex_killed )
  -- The Killing entity
  local killerEntity = nil

  if keys.entindex_attacker ~= nil then
    killerEntity = EntIndexToHScript( keys.entindex_attacker )
  end

  local damagebits = keys.damagebits -- This might always be 0 and therefore useless

  -- Clean up units remaining...
  if killedUnit then
    print( '[REFLEX] KilledUnit exists' )
    if killerEntity then
      local killerID = killerEntity:GetPlayerOwnerID()
      killerEntity = PlayerResource:GetPlayer(killerID):GetAssignedHero()
      print( string.format( '%s killed %s', killerEntity:GetPlayerOwnerID(), killedUnit:GetPlayerOwnerID()) )
    end
    
    -- Trigger OnDeath abilities
    local nAlive = {[DOTA_TEAM_GOODGUYS]=0,[DOTA_TEAM_BADGUYS]=0}

    local heroes = HeroList:GetAllHeroes()
    for i=1,#heroes do
      local hero = heroes[i]
      if hero:IsAlive() and hero:GetTeam() == killedUnit:GetTeam() then
        for onDeath,scale in pairs(ABILITY_ON_DEATH) do
          local ability = hero:FindAbilityByName(onDeath)
          if ability ~= nil and ability:GetLevel() ~= 0 then
            hero:SetModelScale((1 + ((scale - 1) * (ability:GetLevel() / 4))) * hero.originalModelScale)--, 1)

            Timers:CreateTimer(ability:GetSpecialValueFor("duration") + (ability:GetLevel() - 1),
              function() 
                hero:SetModelScale(hero.originalModelScale)--, 1)
              end)

            callModApplier(hero, "modifier_" .. onDeath, ability:GetLevel())
          end
        end
      end

      if hero:IsAlive() then
        nAlive[hero:GetTeam()] = nAlive[hero:GetTeam()] + 1
      end
    end

    local killedID = killedUnit:GetPlayerOwnerID()

    if killedUnit.GetUnitName then
      print( string.format( '[REFLEX] %s died', killedUnit:GetUnitName() ) )
    else
      print ( "[REFLEX] couldn't get unit name")
    end

    -- Fix Gold
    --killerEntity:SetGold(killerEntity:GetGold() + GOLD_PER_KILL, true)
    killerEntity:ModifyGold(GOLD_PER_KILL, true, DOTA_ModifyGold_Unspecified)

    self.nLastKilled = killedUnit:GetTeam()

    -- Victory Check
    print ('RAlive: ' .. tostring(nAlive[DOTA_TEAM_GOODGUYS]) .. ' -- DAlive: ' .. tostring(nAlive[DOTA_TEAM_BADGUYS]))

    if nAlive[DOTA_TEAM_GOODGUYS] == 0 or nAlive[DOTA_TEAM_BADGUYS] == 0 then
      Timers:RemoveTimer('round_time_out')
    
      for i=1,#heroes do
        local hero = heroes[i]
        if hero:IsAlive() then
          hero:AddNewModifier(hero, nil , "modifier_invulnerable", {})
        end
      end

      Timers:CreateTimer('victory', {
        endTime = POST_ROUND_TIME,
        callback = function()
          GameMode:RoundComplete(false)
        end})
      return
    end

    -- Trigger Last Man Standing buff(s)
    local killedTeam = killedUnit:GetTeam()
    local killerTeam = killerEntity:GetTeam()
    if nAlive[killedTeam] == 1 then
      for i=1,#heroes do
        local hero = heroes[i]
        if hero:IsAlive() and hero:GetTeam() == killedTeam then
          Notifications:Top(hero:GetPlayerID(), "LAST MAN STANDING", 3, nil, {color="red", ["font-size"]="60px"})
          Notifications:Top(hero:GetPlayerID(), "DAMAGE INCREASED", 3, nil, {color="purple", ["font-size"]="40px"})
          callModApplier(hero, "modifier_lms_friendly")
        elseif hero:IsAlive() and hero:GetTeam() == killerTeam then
          callModApplier(hero, "modifier_lms_enemy", nAlive[killerTeam])
        end
      end
    end
  end
end



-- This function is called 1 to 2 times as the player connects initially but before they 
-- have completely connected
function GameMode:PlayerConnect(keys)
  DebugPrint('[BAREBONES] PlayerConnect')
  DebugPrintTable(keys)
end

-- This function is called once when the player fully connects and becomes "Ready" during Loading
function GameMode:OnConnectFull(keys)
  DebugPrint('[BAREBONES] OnConnectFull')
  DebugPrintTable(keys)

  GameMode:_OnConnectFull(keys)
  
  local entIndex = keys.index+1
  -- The Player entity of the joining user
  local ply = EntIndexToHScript(entIndex)
  
  -- The Player ID of the joining player
  local playerID = ply:GetPlayerID()
end

-- This function is called whenever illusions are created and tells you which was/is the original entity
function GameMode:OnIllusionsCreated(keys)
  DebugPrint('[BAREBONES] OnIllusionsCreated')
  DebugPrintTable(keys)

  local originalEntity = EntIndexToHScript(keys.original_entindex)
end

-- This function is called whenever an item is combined to create a new item
function GameMode:OnItemCombined(keys)
  DebugPrint('[BAREBONES] OnItemCombined')
  DebugPrintTable(keys)

  -- The playerID of the hero who is buying something
  local plyID = keys.PlayerID
  if not plyID then return end
  local player = PlayerResource:GetPlayer(plyID)

  -- The name of the item purchased
  local itemName = keys.itemname 
  
  -- The cost of the item purchased
  local itemcost = keys.itemcost
end

-- This function is called whenever an ability begins its PhaseStart phase (but before it is actually cast)
function GameMode:OnAbilityCastBegins(keys)
  DebugPrint('[BAREBONES] OnAbilityCastBegins')
  DebugPrintTable(keys)

  local player = PlayerResource:GetPlayer(keys.PlayerID)
  local abilityName = keys.abilityname
end

-- This function is called whenever a tower is killed
function GameMode:OnTowerKill(keys)
  DebugPrint('[BAREBONES] OnTowerKill')
  DebugPrintTable(keys)

  local gold = keys.gold
  local killerPlayer = PlayerResource:GetPlayer(keys.killer_userid)
  local team = keys.teamnumber
end

-- This function is called whenever a player changes there custom team selection during Game Setup 
function GameMode:OnPlayerSelectedCustomTeam(keys)
  DebugPrint('[BAREBONES] OnPlayerSelectedCustomTeam')
  DebugPrintTable(keys)

  local player = PlayerResource:GetPlayer(keys.player_id)
  local success = (keys.success == 1)
  local team = keys.team_id
end

-- This function is called whenever an NPC reaches its goal position/target
function GameMode:OnNPCGoalReached(keys)
  DebugPrint('[BAREBONES] OnNPCGoalReached')
  DebugPrintTable(keys)

  local goalEntity = EntIndexToHScript(keys.goal_entindex)
  local nextGoalEntity = EntIndexToHScript(keys.next_goal_entindex)
  local npc = EntIndexToHScript(keys.npc_entindex)
end