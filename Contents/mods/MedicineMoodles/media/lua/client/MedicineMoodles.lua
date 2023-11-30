require "MF_ISMoodle"

ModMedicineMoodles = {
    Medicines = {},
    MoodleLevels = { Bad = {}, Good = {}, },
    MoodleThresholds = { Bad = {}, Good = { 0, 0.1, 0.4, 0.7, 1 }, },
    MoodleType = { Good = 1, Bad = 2, Special = 3, },
    PlayerMoodles = {},
    SandboxVars = {},
    SkillRequirements = {},
    EffectiveEdibleBuffTimer = {
        Default = 280,
        IronGut = 150,
        WeakStomach = 230,
    },
}

function ModMedicineMoodles:addMedicine(name, item, getValue)
    self.Medicines[name] = {
        item = item,
        getValue = getValue,
    }
    for playerNum, moodles in pairs(self.PlayerMoodles) do
        self:addMoodle(name, playerNum)
    end
end

function ModMedicineMoodles:addMoodle(name, playerNum)
    local moodles = self.PlayerMoodles[playerNum]
    local moodle = moodles[name]
    if moodle == nil then
        local player = getSpecificPlayer(playerNum)
        moodle = MF.ISMoodle:new(name, player)
        moodles[name] = moodle
    end
    self:setupMoodle(moodle)
end

function ModMedicineMoodles:checkSkillRequirements(moodle)
    local requirements = self.SkillRequirements[moodle.name]
    if requirements then
        for skill, level in pairs(requirements) do
            if moodle.char:getPerkLevel(Perks[skill]) < level then
                return false
            end
        end
    end
    return true
end

function ModMedicineMoodles:flipGoodBad(value)
    return -value - 1
end

function ModMedicineMoodles:onMoodleThresholdsChange()
    self:setupConstants()
    for playerNum, moodles in pairs(self.PlayerMoodles) do
        for name, moodle in pairs(moodles) do
            self:setupMoodle(moodle)
        end
    end
end

function ModMedicineMoodles:setupConstants()
    local bad = self.MoodleThresholds.Bad
    local good = self.MoodleThresholds.Good
    for level = 1, 5 do
        bad[level] = self:flipGoodBad(good[level])
    end
    self.MoodleLevels.Hidden = (bad[1] + good[1]) / 2
    for level = 1, 4 do
        self.MoodleLevels.Bad[level] = (bad[level] + bad[level + 1]) / 2
        self.MoodleLevels.Good[level] = (good[level] + good[level + 1]) / 2
    end
    local timer = self.EffectiveEdibleBuffTimer
    timer.Max = math.max(timer.Default, timer.IronGut, timer.WeakStomach)
end

function ModMedicineMoodles:setupMoodle(moodle)
    if moodle == nil then return end
    local medicine = self.Medicines[moodle.name]
    if medicine == nil then return end
    local bad = self.MoodleThresholds.Bad
    local good = self.MoodleThresholds.Good
    moodle:setThresholds(
        bad[4], bad[3], bad[2], bad[1],
        good[1], good[2], good[3], good[4]
    )
    local itemName = getItemNameFromFullType(medicine.item)
    for level = 1, 4 do
        moodle:setTitle(self.MoodleType.Good, level, itemName)
        moodle:setTitle(self.MoodleType.Bad, level, itemName)
    end
end

function ModMedicineMoodles:setupPlayer(playerNum)
    self.PlayerMoodles[playerNum] = {}
    for name, medicine in pairs(self.Medicines) do
        self:addMoodle(name, playerNum)
    end
end

function ModMedicineMoodles:setupSandboxVars()
    self.SandboxVars = {}
    self.SkillRequirements = {}
    for key, value in pairs(SandboxVars.MedicineMoodles or {}) do
        local tokens = luautils.split(key, "_")
        if #tokens == 2 then
            local moodleName = tokens[1]
            local skill = tokens[2]
            local requirements = self.SkillRequirements[moodleName] or {}
            requirements[skill] = value
            self.SkillRequirements[moodleName] = requirements
        else
            self.SandboxVars[key] = value
        end
    end
end

function ModMedicineMoodles:toMoodleValue(value, moodleType)
    if moodleType == self.MoodleType.Special then
        return value
    end
    if value > 0 then
        if moodleType == self.MoodleType.Bad then
            value = self:flipGoodBad(value)
        end
        return value
    end
    return self.MoodleLevels.Hidden
end

function ModMedicineMoodles:updateMoodle(moodle)
    if moodle == nil then return end
    if not self:checkSkillRequirements(moodle) then
        moodle:setValue(self.MoodleLevels.Hidden)
        return
    end
    local medicine = self.Medicines[moodle.name]
    if medicine == nil then return end
    local value, moodleType, intensity = medicine.getValue(self, moodle.char)
    moodleType = moodleType or self.MoodleType.Good
    moodle:setValue(self:toMoodleValue(value, moodleType))
    local level = moodle:getLevel()
    if level > 0 and moodleType ~= self.MoodleType.Special then
        local text = getText("IGUI_RemainingPercent", round(value * 100))
        if intensity and intensity > 0 then
            text = getText("IGUI_climate_intensity") .. ": " .. round(intensity, 2) .. " / " .. text
        end
        moodle:setDescription(moodleType, level, text)
    end
end

function ModMedicineMoodles.onCreatePlayer(playerNum, player)
    local self = ModMedicineMoodles
    self:setupPlayer(playerNum)
end

function ModMedicineMoodles.onPlayerUpdate(player)
    local self = ModMedicineMoodles
    local playerNum = player:getPlayerNum()
    if self.PlayerMoodles[playerNum] == nil then
        self:setupPlayer(playerNum)
    end
    for name, moodle in pairs(self.PlayerMoodles[playerNum]) do
        self:updateMoodle(moodle)
    end
end

ModMedicineMoodles:setupSandboxVars()
ModMedicineMoodles:onMoodleThresholdsChange()
ModMedicineMoodles:addMedicine("Antibiotics", "Base.Antibiotics", function(self, player)
    return player:getReduceInfectionPower() / 50
end)
ModMedicineMoodles:addMedicine("Antidepressants", "Base.PillsAntiDep", function(self, player)
    local value = player:getDepressEffect() / 6600
    if value >= 1 then return self.MoodleLevels.Bad[1], self.MoodleType.Special end -- before taking effect
    return value
    -- , nil, player:getDepressDelta() / 0.3
end)
ModMedicineMoodles:addMedicine("BetaBlockers", "Base.PillsBeta", function(self, player)
    return player:getBetaEffect() / 6600
    -- , nil, player:getBetaDelta() / 0.3
end)
ModMedicineMoodles:addMedicine("Painkillers", "Base.Pills", function(self, player)
    return player:getPainEffect() / 5400
    -- , nil, player:getPainDelta() / 0.45
end)
ModMedicineMoodles:addMedicine("SleepingTablets", "Base.PillsSleepingTablets", function(self, player)
    return player:getSleepingTabletEffect() / 6600, nil,
        player:getSleepingTabletDelta() / 0.1
end)

Events.OnCreatePlayer.Add(ModMedicineMoodles.onCreatePlayer)
Events.OnPlayerUpdate.Add(ModMedicineMoodles.onPlayerUpdate)

-- Change Sandbox Options (by Star)
-- https://steamcommunity.com/sharedfiles/filedetails/?id=2894296454
if Events.OnSandboxOptionsChanged then
    Events.OnSandboxOptionsChanged.Add(function()
        ModMedicineMoodles:setupSandboxVars()
    end)
end
