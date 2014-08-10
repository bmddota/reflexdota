if ParticleUnit == nil then
  ParticleUnit = {}
  ParticleUnit.__index = ParticleUnit
end

function ParticleUnit.new( particle, position, endPosition, cpStart, cpEnd, cpDelete)
  --print ( '[ParticleUnit] ParticleUnit:new' )
  local o = {}
  setmetatable( o, ParticleUnit )
  
  o.particle = particle
  o.position = position
  o.endPosition = endPosition
  o.cpStart = cpStart or 0
  o.cpEnd = cpEnd or 6
  o.cpDelete = cpDelete or 10
  
  ParticleManager:SetParticleControl(o.particle, o.cpStart, position)
  ParticleManager:SetParticleControl(o.particle, o.cpEnd, endPosition)
  ParticleManager:SetParticleControl(o.particle, o.cpDelete, Vector(300,0,0))
  
  return o
end

function ParticleUnit:GetAbsOrigin()
  return self.position
end

function ParticleUnit:GetStart()
  return self.position
end

function ParticleUnit:GetEnd()
  return self.endPosition
end

function ParticleUnit:SetStart(vec)
  self.position = vec
  ParticleManager:SetParticleControl(self.particle, self.cpStart, vec)
end

function ParticleUnit:SetEnd(vec)
  self.endPosition = vec
  ParticleManager:SetParticleControl(self.particle, self.cpEnd, vec)
end

function ParticleUnit:Destroy()
  ParticleManager:SetParticleControl(self.particle, self.cpDelete, Vector(0,0,0))
end