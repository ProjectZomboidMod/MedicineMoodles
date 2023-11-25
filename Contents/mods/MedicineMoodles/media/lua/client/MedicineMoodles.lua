require "MF_ISMoodle"

ModMedicineMoodles = {
    Medicines = {},
    MoodleLevels = { Bad = {}, Good = {}, },
    MoodleThresholds = {
        Bad = { -0.2, -0.4, -0.6, -0.8, -1 },
        Good = { 0, 0.1, 0.4, 0.7, 1 },
    },
    PlayerMoodles = {},
}

function ModMedicineMoodles:addMedicine(name, item, getData)
    self.Medicines[name] = {
        item = item,
        getData = getData,
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

function ModMedicineMoodles:duration(value)
    -- if value > 1 then return 1 end
    if value > 0 then return value end
    return self.MoodleLevels.Hidden
end

function ModMedicineMoodles:onMoodleThresholdsChange()
    self:setupMoodleLevels()
    for playerNum, moodles in pairs(self.PlayerMoodles) do
        for name, moodle in pairs(moodles) do
            self:setupMoodle(moodle)
        end
    end
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
        moodle:setTitle(1, level, itemName)
        moodle:setTitle(2, level, itemName)
    end
end

function ModMedicineMoodles:setupMoodleLevels()
    local bad = self.MoodleThresholds.Bad
    local good = self.MoodleThresholds.Good
    self.MoodleLevels.Hidden = (bad[1] + good[1]) / 2
    for level = 1, 4 do
        self.MoodleLevels.Bad[level] = (bad[level] + bad[level + 1]) / 2
        self.MoodleLevels.Good[level] = (good[level] + good[level + 1]) / 2
    end
end

function ModMedicineMoodles:setupPlayer(playerNum)
    self.PlayerMoodles[playerNum] = {}
    for name, medicine in pairs(self.Medicines) do
        self:addMoodle(name, playerNum)
    end
end

function ModMedicineMoodles:updateMoodle(moodle)
    if moodle == nil then return end
    local medicine = self.Medicines[moodle.name]
    if medicine == nil then return end
    local duration, intensity = medicine.getData(self, moodle.char)
    moodle:setValue(duration)
    local level = moodle:getLevel()
    if level > 0 then
        local text = getText("IGUI_RemainingPercent", round(duration * 100))
        if intensity and intensity > 0 then
            text = getText("IGUI_climate_intensity") .. ": " .. round(intensity, 2) .. " / " .. text
        end
        moodle:setDescription(1, level, text)
    end
end

function ModMedicineMoodles.onCreatePlayer(playerNum)
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

ModMedicineMoodles:onMoodleThresholdsChange()
ModMedicineMoodles:addMedicine("Antibiotics", "Base.Antibiotics", function(self, player)
    return self:duration(player:getReduceInfectionPower() / 50)
end)
ModMedicineMoodles:addMedicine("Antidepressants", "Base.PillsAntiDep", function(self, player)
    local value = player:getDepressEffect() / 6600
    if value >= 1 then return self.MoodleLevels.Bad[1] end -- before taking effect
    return self:duration(value)
    -- , player:getDepressDelta() / 0.3
end)
ModMedicineMoodles:addMedicine("BetaBlockers", "Base.PillsBeta", function(self, player)
    return self:duration(player:getBetaEffect() / 6600)
    -- , player:getBetaDelta() / 0.3
end)
ModMedicineMoodles:addMedicine("Painkillers", "Base.Pills", function(self, player)
    return self:duration(player:getPainEffect() / 5400)
    -- , player:getPainDelta() / 0.45
end)
ModMedicineMoodles:addMedicine("SleepingTablets", "Base.PillsSleepingTablets", function(self, player)
    return self:duration(player:getSleepingTabletEffect() / 6600),
        player:getSleepingTabletDelta() / 0.1
end)

Events.OnCreatePlayer.Add(ModMedicineMoodles.onCreatePlayer)
Events.OnPlayerUpdate.Add(ModMedicineMoodles.onPlayerUpdate)
