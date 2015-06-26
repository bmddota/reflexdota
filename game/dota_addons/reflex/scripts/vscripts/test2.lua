require('util')
require('timers')

print("===============")
--PrintTable(_G)

--require("mapscripts/" .. GetMapName())
--MapScript:Initialize()

local player = PlayerResource:GetPlayer(0)
local hero = player:GetAssignedHero()

local item = hero:GetItemInSlot( 2 )
local tab = {}
tab[1] = 10;
item:ApplyDataDrivenModifier(hero, hero, "modifier_item_shield_1", tab)

if true then
	return
end

if particle ~= nil then
	ParticleManager:DestroyParticle(particle, false)
end

particle = ParticleManager:CreateParticle("particles/ghost_model.vpcf", PATTACH_ABSORIGIN_FOLLOW, hero)
--ParticleManager:SetParticleControl(particle, 0, vec)--Vector(0,0,0))
ParticleManager:SetParticleControl(particle, 2, Vector(255,0,0))--Vector(0,0,0))
ParticleManager:SetParticleControl(particle, 3, Vector(10,0,0))--Vector(0,0,0))

ParticleManager:SetParticleControlEnt(particle, 1, hero, 1, "follow_origin", hero:GetAbsOrigin(), true)
--ParticleManager:ReleaseParticleIndex(particle)
--table.insert(particles, particle)

if true then
	return
end

if particle == nil then
	particles = {}
end

--hero:DestroyAllSpeechBubbles()
local bubble = hero:AddSpeechBubble(1, "<b>Aderum</b> smells like dog buns.", 5000.0, 0, 0)
UTIL_MessageText(1, "Butt", 255, 255, 255, 255 )

if startimer then
	Timers:RemoveTimer(startimer)
	if sunpart then
		ParticleManager:DestroyParticle(sunpart, false)
	end
	if galaxypart then
		ParticleManager:DestroyParticle(galaxypart, false)
	end

	Timers:RemoveTimer(startimer2)
	--Timers:RemoveTimer(startimer3)
else
	for i=-1,1,2 do
		for j=-1,1,2 do
			local vec = Vector(i * 2600, j * 2000, -50)
			local particle = ParticleManager:CreateParticle("particles/stargen2.vpcf", PATTACH_POINT, hero)
			ParticleManager:SetParticleControl(particle, 0, vec)--Vector(0,0,0))
			ParticleManager:SetParticleControl(particle, 1, Vector(-50,-50,0))--Vector(0,0,0))
			--ParticleManager:ReleaseParticleIndex(particle)
			table.insert(particles, particle)
		end
	end
end

count = 0
sunplace = Vector(0,0,-300)
sunpart = nil
galaxypart = nil
if rotation == nil then
	rotation = Vector(-1,-1,0)
end

startimer2 = Timers:CreateTimer(1, function()
	rotation = RotatePosition(Vector(0,0,0), QAngle(0,1,0), rotation):Normalized()
	for k,part in pairs(particles) do
		ParticleManager:SetParticleControl(part, 1, rotation * 70)
	end
	if galaxypart then
		ParticleManager:SetParticleControl(galaxypart, 3, rotation * 200)
	end
	if sunpart then
		ParticleManager:SetParticleControl(sunpart, 1, rotation * 200)
	end
	
	return 1
end)


startimer = Timers:CreateTimer(.5, function()
	local vec = Vector(RandomInt(-2600,2600), RandomInt(-2000,2000), -10) + -800 * rotation
	--local particle = ParticleManager:CreateParticle("particles/tinker_base_attack.vpcf", PATTACH_POINT, hero)
	--ParticleManager:SetParticleControl(particle, 0, vec)--Vector(0,0,0))
	--ParticleManager:ReleaseParticleIndex(particle)
	count = count + 1

	local particle = ParticleManager:CreateParticle("particles/reflex_particles/tinker_base_attack_linear.vpcf", PATTACH_POINT, hero)
	ParticleManager:SetParticleControl(particle, 0, vec)--Vector(0,0,0))
	ParticleManager:SetParticleControl(particle, 1, -1 * Vector((1000 + RandomInt(-50,50)) * rotation.x, (1000 + RandomInt(-50,50)) * rotation.y, 0))
	ParticleManager:ReleaseParticleIndex(particle)
	

	if count == 20 then
		count = 0
		sunplace = Vector(0,0,-1000)
		if sunpart then
			ParticleManager:DestroyParticle(sunpart, false)
		end
		sunpart = ParticleManager:CreateParticle("particles/sun.vpcf", PATTACH_POINT, hero)
		ParticleManager:SetParticleControl(sunpart, 0, sunplace)--Vector(0,0,0))
		ParticleManager:SetParticleControl(sunpart, 1, Vector(0, -300, 0))--Vector(0,0,0))
		--ParticleManager:ReleaseParticleIndex(sunpart)
	end

	--[[if count == 20 then
		count = 0
		galaxyplace = Vector(0,0,-100)
		if galaxypart then
			ParticleManager:DestroyParticle(galaxypart, false)
		end
		galaxypart = ParticleManager:CreateParticle("particles/enigma_blackhole_n.vpcf", PATTACH_POINT, hero)
		ParticleManager:SetParticleControl(galaxypart, 0, galaxyplace)--Vector(0,0,0))
		ParticleManager:SetParticleControl(galaxypart, 3, Vector(0, -300, 0))--Vector(0,0,0))
		--ParticleManager:ReleaseParticleIndex(sunpart)
	end]]
	return .5
end)

--particles/dire_fx/bad_ancient_sauron.vpcf
--particles/econ/courier/courier_greevil_black/courier_greevil_black_ambient_2_a.vpcf
--particles/econ/courier/courier_greevil_white/courier_greevil_white_ambient_2_a.vpcf
--particles/econ/courier/courier_hwytty/courier_hwytty_loot.vpcf
--particles/econ/items/kunkka/divine_anchor/hero_kunkka_dafx_skills/kunkka_spell_torrent_bubbles_swirl_bottom_fxset.vpcf
--particles/econ/items/kunkka/divine_anchor/hero_kunkka_dafx_skills/kunkka_spell_torrent_bubbles_swirl_caustic_fxset.vpcf
--particles/econ/items/kunkka/divine_anchor/hero_kunkka_dafx_skills/kunkka_spell_torrent_bubbles_swirl_fxset.vpcf

--local bubble = hero:AddSpeechBubble(2, "<font color=\"#ff0000\">Lick my taint</font>.", 5.0, 50, 60)
--local bubble = hero:AddSpeechBubble(3, "<i><font color=\"#00ff00\">Crap Spackle</font></i>\n\n<font color=\"#0000ff\">F</font>\n<font color=\"#00ff00\">U</font>\n<font color=\"#ff0000\">C</font>\n<font color=\"#ffffff\">K</font>\n", 5.0, -100, -10)

--[[
ENTS = {
	"info_target",
	"prop_dyanmic"
}

for k,v in pairs(ENTS) do
	local ent = Entities:CreateByClassname(v)
	print("=====" .. v .. "=====")
	PrintTable(getmetatable(ent))
	print("===============")
	print("===============")

end

PrintTable(player)
print("===============")
PrintTable(getmetatable(player))

print("===============")
print("===============")

PrintTable(hero)
print("===============")
PrintTable(getmetatable(hero))

print("===============")
print("===============")]]


--[[PlayerResource:SetCustomTeamAssignment( 0, DOTA_TEAM_CUSTOM_8 )
--PlayerResource:ReplaceHeroWith(0, "npc_dota_hero_furion", 0, 0)
GameRules:SendCustomMessage("Test", 0, 0)
GameRules:SendCustomMessage("Test1", 1, 0)
GameRules:SendCustomMessage("Test5", DOTA_TEAM_BADGUYS, 0)

for i=0,9 do
	local player = PlayerResource:GetPlayer(i)
	if player ~= nil then
		local hero = player:GetAssignedHero()
		local team = "nil"
		if hero == nil then
			hero = "nil"
		else
			hero = hero:GetClassname()
			team = PlayerResource:GetTeam(i)
		end
		print(i .. "  --  " .. hero .. " -- " .. team)
	end
end

PlayerResource:SetCustomTeamAssignment( 1, DOTA_TEAM_BADGUYS )
PlayerResource:ReplaceHeroWith(1, "npc_dota_hero_axe", 0, 0)
Say(PlayerResource:GetPlayer(1), "balsdfasdf", true)
Say(PlayerResource:GetPlayer(2), "balsdfasdf", true)]]