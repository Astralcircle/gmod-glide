AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Gib"

ENT.Spawnable = false
ENT.AdminOnly = false

ENT.PhysgunDisabled = true
ENT.DoNotDuplicate = true
ENT.DisableDuplicator = true

local lifetimeCvar = GetConVar( "glide_gib_lifetime" )

function ENT:SetupDataTables()
    self:NetworkVar( "Bool", "IsOnFire" )
end

if CLIENT then
    function ENT:OnRemove()
        if self.fireSound then
            self.fireSound:Stop()
        end
    end

    function ENT:Think()
        if self:GetIsOnFire() then
            if not self.fireSound then
                self.fireSound = CreateSound( self, "glide/fire/fire_loop_2.wav" )
                self.fireSound:SetSoundLevel( 60 )
                self.fireSound:PlayEx( 1.0, 100 )
            end

        elseif self.fireSound then
            self.fireSound:Stop()
            self.fireSound = nil
        end

        self:SetNextClientThink( CurTime() + 0.1 )

        return true
    end
end

if not SERVER then return end

function ENT:Initialize()
    self:SetSolid( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
    self:PhysicsInit( SOLID_VPHYSICS )

    self:SetMaterial( "glide/vehicles/generic_burnt" )
    self:DrawShadow( false )

    local phys = self:GetPhysicsObject()

    if IsValid( phys ) then
        phys:Wake()
        phys:SetAngleDragCoefficient( 1 )
        phys:SetDragCoefficient( 1 )
    end

    self.lifeTime = RealTime() + lifetimeCvar:GetFloat()
end

function ENT:OnRemove()
    self:StopFire()
end

--- Copy the momentum from another entity.
function ENT:CopyVelocities( otherEnt )
    local phys = self:GetPhysicsObject()
    if not IsValid( phys ) then return end

    local otherPhys = otherEnt:GetPhysicsObject()
    if not IsValid( otherPhys ) then return end

    phys:SetVelocity( otherPhys:GetVelocity() )
    phys:SetAngleVelocity( otherPhys:GetAngleVelocity() )
end

function ENT:SetOnFire()
    if IsValid( self.fire ) then return end

    self.fire = ents.Create( "env_fire" )
    self.fire:SetKeyValue( "firesize", 128 )
    self.fire:SetKeyValue( "damagescale", "5" )
    self.fire:Spawn()
    self.fire:SetPos( self:GetPos() )
    self.fire:SetParent( self )
    self.fire:Fire( "StartFire", "", 0 )

    self:DeleteOnRemove( self.fire )
    self:SetIsOnFire( true )
end

function ENT:StopFire()
    self:SetIsOnFire( false )

    if IsValid( self.fire ) then
        self.fire:Remove()
        self.fire = nil
    end
end

function ENT:Think()
    local t = RealTime()

    if t > self.lifeTime and self.lifeTime ~= 0 then
        self:Remove()
        return
    end

    if IsValid( self.fire ) then
        self.fire:SetPos( self:GetPos() )

        if self:WaterLevel() > 0 then
            self:StopFire()
        end
    end

    self:NextThink( CurTime() )

    return true
end

local PlaySoundSet = Glide.PlaySoundSet

function ENT:PhysicsCollide( data, _phys )
    local speed = data.Speed

    if speed > 80 then
        PlaySoundSet( speed < 200 and "Glide.Collision.GibSoft" or "Glide.Collision.GibHard", self )
    end
end
