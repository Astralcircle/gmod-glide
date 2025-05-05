AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

DEFINE_BASECLASS( "base_glide" )

--- Implement this base class function.
function ENT:OnPostInitialize()
    self:SetEngineThrottle( 0 )
    self:SetEnginePower( 0 )
    self:SetIsHonking( false )

    -- Make boats more slidey on land
    local phys = self:GetPhysicsObject()

    if IsValid( phys ) then
        phys:SetMaterial( "glass" )
    end
end

--- Implement this base class function.
function ENT:OnDriverEnter()
    if self.startupTimer then return end

    if self:GetEngineState() < 2 then
        self:TurnOn()
    end
end

--- Implement this base class function.
function ENT:OnDriverExit()
    self:SetIsHonking( false )

    if self.hasRagdolledAllPlayers then
        BaseClass.OnDriverExit( self )
    else
        self:TurnOff()
    end
end

--- Implement this base class function.
function ENT:OnSeatInput( seatIndex, action, pressed )
    if seatIndex > 1 then return end

    if action == "horn" then
        self:SetIsHonking( pressed )
    end

    if not pressed then return end

    if action == "toggle_engine" then
        if self:GetEngineState() == 0 then
            self:TurnOn()
        else
            self:TurnOff()
        end
    end
end

--- Override this base class function.
function ENT:OnTakeDamage( dmginfo )
    BaseClass.OnTakeDamage( self, dmginfo )

    if self:GetEngineHealth() <= 0 and self:GetEngineState() == 2 then
        self:TurnOff()
    end
end

--- Override this base class function.
function ENT:TurnOff()
    BaseClass.TurnOff( self )

    self:SetEnginePower( 0 )
    self:SetEngineThrottle( 0 )
    self:SetIsHonking( false )

    self.startupTimer = nil
end

local Abs = math.abs
local Clamp = math.Clamp
local WORLD_UP = Vector( 0, 0, 1 )

local ExpDecay = Glide.ExpDecay

--- Implement this base class function.
function ENT:OnPostThink( dt, selfTbl )
    local state = self:GetEngineState()
    local health = self:GetEngineHealth()

    -- Attempt to start the engine
    if state == 1 then
        if selfTbl.startupTimer then
            if CurTime() > selfTbl.startupTimer then
                selfTbl.startupTimer = nil

                if health > 0 then
                    self:SetEngineState( 2 )
                else
                    self:SetEngineState( 0 )
                end
            end
        else
            local startupTime = health < 0.5 and math.Rand( 1, 2 ) or selfTbl.StartupTime
            selfTbl.startupTimer = CurTime() + startupTime
        end

    elseif state == 3 then
        -- This vehicle does not do a "shutdown" sequence.
        self:SetEngineState( 0 )
    end

    if self:IsEngineOn() then
        self:UpdateEngine( dt, selfTbl )
    end

    -- Update steer input
    self:SetSteering( ExpDecay( self:GetSteering(), self:GetInputFloat( 1, "steer" ), 8, dt ) )

    -- Check if the vehicle is fully upside down on water
    if self:GetWaterState() > 1 and self:GetUp():Dot( WORLD_UP ) < 0 then
        self:SetEngineThrottle( 0 )
        self:SetEnginePower( 0 )

        -- Damage the engine over time
        if health > 0 then
            self:TakeEngineDamage( dt * 0.2 )

        elseif self:GetEngineState() == 2 then
            self:TurnOff()
        end

        -- Kick passengers
        if #self:GetAllPlayers() > 0 then
            self:RagdollPlayers()
        end
    end
end

function ENT:UpdateEngine( dt, selfTbl )
    local waterState = self:GetWaterState()
    local speed = selfTbl.forwardSpeed
    local throttle = 0

    if Abs( speed ) > 20 or waterState > 0 then
        throttle = self:GetInputFloat( 1, "accelerate" ) - self:GetInputFloat( 1, "brake" )
    end

    self:SetEngineThrottle( ExpDecay( self:GetEngineThrottle(), throttle, 5, dt ) )

    local power = Abs( throttle )

    if throttle < 0 then
        power = power * Clamp( -speed / self.BoatParams.maxSpeed * 4, 0, 1 )
        power = power * 0.4

    elseif waterState > 0 then
        power = power * ( 0.4 + Clamp( Abs( speed ) / self.BoatParams.maxSpeed, 0, 1 ) * 0.6 )
        power = power * ( waterState > 1 and 0.6 or 1 )
    end

    self:SetEnginePower( ExpDecay( self:GetEnginePower(), power, 2 + power * 2, dt ) )
end

--- Implement this base class function.
function ENT:OnSimulatePhysics( phys, dt, outLin, outAng )
    self:SimulateBoat( phys, dt, outLin, outAng, self:GetEngineThrottle(), self:GetInputFloat( 1, "steer" ) )
end
