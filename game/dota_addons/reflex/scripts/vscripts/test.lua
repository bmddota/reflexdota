
Notifications:TopToAll("asdfasdf", 5.0)

local heroes = HeroList:GetAllHeroes()

for i=1,#heroes do
  local hero = heroes[i]
  hero:RemoveModifierByName("modifier_ability_layout_6")
  hero:RemoveModifierByName("modifier_ability_layout_5")
  --ApplyModifier(hero, hero, "modifier_ability_layout_6", {})
  ApplyModifier(hero, hero, "modifier_ability_layout_5", {})
end