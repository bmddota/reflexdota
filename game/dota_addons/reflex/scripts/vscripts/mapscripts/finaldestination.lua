require('internal/util')
require('libraries/timers')

MapScript = {}

PHASE_TEST = 0
PHASE_COMETS = 1
PHASE_SUN = 2
--PHASE_COMETS2 = 3
PHASE_TRAVEL = 3
PHASE_BLACKHOLE = 4

DANGER_INDICATOR_OVERRIDE = "particles/reflex_particles/generic_aoe_shockwave_2.vpcf"

function MapScript:Initialize()
	print("INITIALIZE MAP")
	local stars = {}
	local attachEnt = CreateUnitByName("npc_reflex_dummy_grip", Vector(0,0,0), false, nil, nil, DOTA_TEAM_NOTEAM)
  	attachEnt:FindAbilityByName("reflex_dummy_unit"):SetLevel(1)
  	attachEnt:AddNewModifier(attachEnt, nil, "modifier_phased", {})

  	Timers:CreateTimer(45, function()
  		for i=-1,1,2 do
			for j=-1,1,2 do
				print("Creating star " .. i .. "," .. j)
				local vec = Vector(i * 2600, j * 2000, -50)
				local particle = ParticleManager:CreateParticle("particles/stargen2.vpcf", PATTACH_POINT, attachEnt)
				ParticleManager:SetParticleControl(particle, 0, vec)--Vector(0,0,0))
				ParticleManager:SetParticleControl(particle, 1, Vector(-50,-50,0))--Vector(0,0,0))
				ParticleManager:SetParticleControl(particle, 2, Vector(1,0,0))
				--ParticleManager:ReleaseParticleIndex(particle)
				table.insert(stars, particle)
			end
		end

		local rotation = Vector(-1,-1,0)
		local autoRotate = true
		local rotateWait = 1
		local galaxypart = nil
		local sunpart = nil
		--local phase = PHASE_TEST 
		local phase = PHASE_COMETS
		local inphaseTimer = nil

		local rotateTimer = Timers:CreateTimer(1, function()
			if autoRotate then
				rotation = RotatePosition(Vector(0,0,0), QAngle(0,1,0), rotation):Normalized()
			end
			for k,part in pairs(stars) do
				ParticleManager:SetParticleControl(part, 1, rotation * 70)
			end
			if galaxypart then
				ParticleManager:SetParticleControl(galaxypart, 3, rotation * 225)
			end
			if sunpart then
				ParticleManager:SetParticleControl(sunpart, 1, rotation * 150)
			end
				
			return rotateWait
		end)

		local phaseTimer = Timers:CreateTimer(function()
			local wait = 120
			if phase == PHASE_TRAVEL then
				wait = 50
				autoRotate = false
				rotateWait = .1
				local step = rotation / -10
				local count = 0
				local partscale = 1

				Timers:CreateTimer(1, function()
					rotation = rotation + step
					partscale = partscale + .15
					for k,part in pairs(stars) do
						ParticleManager:SetParticleControl(part, 2, Vector(partscale,0,0))
					end

					count = count + 1
					if count == 10 then count = 0; return end
					return .2
				end)

				-- shoot left
				Timers:CreateTimer(3.2, function()
					rotation = rotation + Vector(-3,0,0)
					count = count + 1
					if count == 10 then count = 0; return end
					return .2
				end)

				Timers:CreateTimer(15.4, function()
					rotation = rotation + Vector(3,0,0)
					count = count + 1
					if count == 10 then count = 0; return end
					return .2
				end)

				Timers:CreateTimer(17.6, function()
					rotation = rotation + Vector(0,-3,0)
					count = count + 1
					if count == 10 then count = 0; return end
					return .2
				end)

				Timers:CreateTimer(29.8, function()
					rotation = rotation + Vector(0,3,0)
					count = count + 1
					if count == 10 then count = 0; return end
					return .2
				end)

				Timers:CreateTimer(32.0, function()
					rotation = rotation + Vector(0,0,1.5)
					count = count + 1
					if count == 10 then count = 0; return end
					return .2
				end)

				Timers:CreateTimer(44.2, function()
					rotation = rotation + Vector(0,0,-1.5)
					count = count + 1
					if count == 10 then count = 0; return end
					return .2
				end)

				Timers:CreateTimer(46.4, function()
					rotation = rotation - step
					partscale = partscale - .15
					rotateWait = 1
					for k,part in pairs(stars) do
						ParticleManager:SetParticleControl(part, 2, Vector(partscale,0,0))
					end

					count = count + 1
					if count == 10 then 
						count = 0
						autoRotate = true
						return 
					end
					return .2
				end)
			elseif phase == PHASE_COMETS then --or phase == PHASE_COMETS2 then
				if galaxypart then
					ParticleManager:DestroyParticle(galaxypart, false)
				end
				if sunpart then
					ParticleManager:DestroyParticle(sunpart, false)
				end

				inphaseTimer = Timers:CreateTimer(function ()
					local vec = Vector(RandomInt(-2600,2600), RandomInt(-2000,2000), -10) + -800 * rotation
					local particle = ParticleManager:CreateParticle("particles/reflex_particles/tinker_base_attack_linear.vpcf", PATTACH_POINT, attachEnt)
					ParticleManager:SetParticleControl(particle, 0, vec)--Vector(0,0,0))
					ParticleManager:SetParticleControl(particle, 1, -1 * Vector((1000 + RandomInt(-50,50)) * rotation.x, (1000 + RandomInt(-50,50)) * rotation.y, 0))
					ParticleManager:ReleaseParticleIndex(particle)

					return .25
				end)			
			elseif phase == PHASE_SUN then
				Timers:RemoveTimer(inphaseTimer)

				sunpart = ParticleManager:CreateParticle("particles/sun.vpcf", PATTACH_POINT, attachEnt)
				ParticleManager:SetParticleControl(sunpart, 0, Vector(0,0,-1000) + -2600 * rotation + Vector(RandomInt(-300,300), RandomInt(-300,300), 0))--Vector(0,0,0))
				ParticleManager:SetParticleControl(sunpart, 1, rotation * 200)--Vector(0,0,0))
				wait = 45
			elseif phase == PHASE_BLACKHOLE then
				Timers:RemoveTimer(inphaseTimer)

				galaxypart = ParticleManager:CreateParticle("particles/enigma_blackhole_n.vpcf", PATTACH_POINT, attachEnt)
				ParticleManager:SetParticleControl(galaxypart, 0, Vector(0,0,-100) + -2600 * rotation + Vector(RandomInt(-300,300), RandomInt(-300,300), 0))--Vector(0,0,0))
				ParticleManager:SetParticleControl(galaxypart, 3, rotation * 200)--Vector(0,0,0))
				wait = 45
			end

			phase = phase + 1
			if phase == 5 then
				phase = PHASE_COMETS
			end
			return wait
		end)
  	end)
end