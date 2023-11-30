require "MedicineMoodles"

local effectiveEdibleBuffTimer = {}
local originalPlayerEat
local function playerEat(player, food, percentage)
    -- // IsoGameCharacter.Eat
    -- if (this.BodyDamage.getFoodSicknessLevel() > 0.0F && (float)food.getReduceFoodSickness() > 0.0F && this.effectiveEdibleBuffTimer <= 0.0F) {
    --     if (this.Traits.IronGut.isSet()) {
    --         this.effectiveEdibleBuffTimer = Rand.Next(80.0F, 150.0F);
    --     } else if (this.Traits.WeakStomach.isSet()) {
    --         this.effectiveEdibleBuffTimer = Rand.Next(120.0F, 230.0F);
    --     } else {
    --         this.effectiveEdibleBuffTimer = Rand.Next(200.0F, 280.0F);
    --     }
    -- }
    local bodyDamage = player:getBodyDamage()
    local foodSicknessBeforeEat = bodyDamage:getFoodSicknessLevel()
    local poisonBeforeEat = bodyDamage:getPoisonLevel()
    originalPlayerEat(player, food, percentage)
    if food:getReduceFoodSickness() > 0 and (
            bodyDamage:getFoodSicknessLevel() < foodSicknessBeforeEat or
            bodyDamage:getPoisonLevel() < poisonBeforeEat
        ) then
        local playerNum = player:getPlayerNum()
        -- use max value as a workaround
        local timer
        if player:HasTrait("IronGut") then
            timer = ModMedicineMoodles.EffectiveEdibleBuffTimer.IronGut
        elseif player:HasTrait("WeakStomach") then
            timer = ModMedicineMoodles.EffectiveEdibleBuffTimer.WeakStomach
        else
            timer = ModMedicineMoodles.EffectiveEdibleBuffTimer.Default
        end
        effectiveEdibleBuffTimer[playerNum] = timer
    end
end

local function onCreatePlayer(playerNum, player)
    effectiveEdibleBuffTimer[playerNum] = 0
    if originalPlayerEat == nil then
        local meta = getmetatable(player).__index
        originalPlayerEat = meta.Eat
        meta.Eat = playerEat
    end
end

local function onPlayerUpdate(player)
    -- // IsoGameCharacter.updateInternal
    -- if (this.effectiveEdibleBuffTimer > 0.0F) {
    --     this.effectiveEdibleBuffTimer -= GameTime.getInstance().getMultiplier() * 0.015F;
    --     if (this.effectiveEdibleBuffTimer < 0.0F) {
    --         this.effectiveEdibleBuffTimer = 0.0F;
    --     }
    -- }
    local playerNum = player:getPlayerNum()
    local timer = effectiveEdibleBuffTimer[playerNum]
    if timer and timer > 0 then
        timer = timer - GameTime:getInstance():getMultiplier() * 0.015
        if timer < 0 then timer = 0 end
        effectiveEdibleBuffTimer[playerNum] = timer
    end
end

Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnPlayerUpdate.Add(onPlayerUpdate)

ModMedicineMoodles:addMedicine("LemonGrass", "Base.LemonGrass", function(self, player)
    return (effectiveEdibleBuffTimer[player:getPlayerNum()] or 0) / self.EffectiveEdibleBuffTimer.Max
    , self.MoodleType.Bad
end)
