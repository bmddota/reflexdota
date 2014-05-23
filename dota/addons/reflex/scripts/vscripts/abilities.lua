
vPlayerIlluminate = {}

function itemSpellStart (keys)
	
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
	
	local item = getItemByName(caster, itemName )
	--print ('Item')
	--PrintTable(item)
	--PrintTable(getmetatable(item))
	--print(item:GetLevel())
	if item == nil then
		return
	end
	
		
	if string.find(itemName, "item_reflex_dash") ~= nil then
		--print (tostring(caster:HasModifier("modifier_hamstring")))
		if caster:HasModifier("modifier_hamstring") then
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
			-- TODO Maybe add back mana lost?
			return
		end
	end
	
	local abilityLevel = keys.AbilityLevel or item:GetLevel()
	
	local point = nil
	if keys.target_points[1] then
		point = keys.target_points[1]
	end
	--if point == nil then
	--	return	
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
		if chargeType == "UNLINKED" then
		
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
		
		-- print ("[[REFLEX]] " ..target .. " -- " ..abilityName  .. " -- " .. tostring(point))
		-- PrintTable(ability)
		if target == nil then
			caster:CastAbilityNoTarget (ability, -1 )
		elseif target == "POINT" then
			caster:CastAbilityOnPosition ( point, ability, 1 )
		else
			caster:CastAbilityOnTarget (targetEntity, ability, -1 )
		end
	end
	
	--print ( '[[REFLEX]] removing dash ability' )
	--caster:RemoveAbility('reflex_dash')
	
	--local charges = item:GetCurrentCharges()
	--if charges ~= 0 then
	--	item:EndCooldown()
	--end
end

--[[
	"RunScript"
			{
				"ScriptFile"			"scripts/vscripts/abilities.lua"
				"Function"				"itemChargeThink"
				"Item"					"item_reflex_dash"
				"ChargeModifier"		"modifier_item_reflex_dash" // Optional for UNLINKED/ALL
				"ChargeType"			"UNLINKED" 	// Optional: "UNLINKED", "HALF", "FULL", "ALL"
			}
]]
function itemChargeThink (keys)
	--print ('[[REFLEX]] itemChargeThink called')
	--PrintTable(keys)
	local chargeType = keys.ChargeType or "UNLINKED"
	--print ('[[REFLEX]] ' .. (keys.ChargeModifier or "nil") .. " -- " .. keys.Item .. " -- " .. chargeType)

	local itemName = keys.Item
	local caster = keys.caster
	local chargeModifier = keys.ChargeModifier
	
	if caster == nil or itemName == nil then
		return
	end

	local item = getItemByName(caster, itemName )
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
		if charges + 1 ~= maxCharges then
			callModApplier(caster, chargeModifier)
		end
	elseif chargeType == "ALL" then
		item:SetCurrentCharges(maxCharges)
	end
	
	--item:EndCooldown()
end

channelAct = {
	item_tranquil_boots = itemTranquilBoots
}

channelTable = {}

function itemChannelStart( keys )
	local now = GameRules:GetGameTime()
	-- print ('[[REFLEX]] itemChannelStart called: ' .. now)
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
	--print ('[[REFLEX]] itemChannelEnd called: ' .. now)
	--PrintTable(keys)
	
	local caster = keys.caster
	local itemName = keys.ability:GetAbilityName()
	
	if caster == nil or itemName == nil then
		return
	end
	
	local item = keys.ability--getItemByName(caster, itemName )
	--if item == nil then
--		return
--	end
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
		start = now + 0.5
	end
	
	local channelTime = start - now
	if string.find(itemName, "item_reflex_meteor_cannon") ~= nil then
		itemTranquilBoots(channelTime, point, keys.ability, caster)
	end
end

function itemTranquilBoots( channelTime, point, item , caster)
	--print ('[[REFLEX]] itemTranquilBoots called: ' .. channelTime .. " -- point: " .. tostring(point) .. " -- item: " ..item:GetAbilityName())
	
	local info = {
		EffectName = "invoker_chaos_meteor",
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
		fExpireTime = GameRules:GetGameTime() + 10.0,
	}

	local speed = tonumber(item:GetSpecialValueFor("speed")) + (item:GetLevel() - 1) * 100 --1000
  print ('[[REFLEX]] Meteor Speed: ' .. tostring(speed))
	--print ('[[REFLEX]] ' .. tostring(point))
	--PrintTable(point)
	--PrintTable(getmetatable(point))	
	-- caster:GetAngles() .y is angle with 270 being straight down i think
	--local angles = caster:GetAngles()
	--print ('[[REFLEX]] ' .. tostring(angles))
	--PrintTable(angles)
	--PrintTable(getmetatable(angles))
	
	-- x pos is left
	-- y pos is down
	
	point.z = 0
	local pos = caster:GetAbsOrigin()
	--print ('[[Reflex]] ' .. tostring(pos))
	local diff = pos - point
	--print ('[[Reflex]] ' .. tostring(diff))
	
	--point = point:Normalized()
	info.vVelocity = diff:Normalized() * speed * channelTime
	--info.vVelocity = point:Normalized() * speed * channelTime--( RotatePosition( Vec3( 0, 0, 0 ), angle, Vec3( 1, 0, 0 ) ) ) * speed
	--info.vAcceleration = info.vVelocity * -0.15

	ProjectileManager:CreateLinearProjectile( info )
end

function getItemByName( hero, name )
	if not hero:HasItemInInventory ( name ) then
		return nil
	end
	
	--print ( '[[REFLEX]] find item in inventory' )
	-- Find item by slot
	for i=0,11 do
		--print ( '\t[[REFLEX]] finding item ' .. i)
		local item = hero:GetItemInSlot( i )
		--print ( '\t[[REFLEX]] item: ' .. tostring(item) )
		if item ~= nil then
			--print ( '\t[[REFLEX]] getting ability name' .. i)
			local lname = item:GetAbilityName()
			--print ( string.format ('[[REFLEX]] item slot %d: %s', i, lname) )
			if lname == name then
				return item
			end
		end
	end
	
	return nil
end
