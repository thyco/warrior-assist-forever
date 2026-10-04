local addonName, addon = ...

addon.name = addonName
addon.features = {}
addon.started = false

function addon:RegisterFeature(feature)
    self.features[#self.features + 1] = feature
end

function addon:Start()
    if self.started then
        return
    end

    self.started = true
    self.Config.Initialize()
    self.SettingsPanel:Initialize()
    self.active = self.Client.IsWarrior()
    if not self.active then
        return
    end

    self.BattleShoutAura.Initialize()
    self.BattleShoutIcon:Initialize()
    self.StanceIcon:Initialize()
    self:RegisterFeature(self.BattleShoutReminder)
    self.BattleShoutReminder:Initialize()
    self.ReactiveAbilities:Initialize()

    self.Config.Subscribe(function()
        self.BattleShoutIcon:ApplySettings()
        self.StanceIcon:ApplySettings()
        self.BattleShoutReminder:Refresh(false)
        self.ReactiveAbilities:Refresh()
    end)
    self.BattleShoutReminder:Refresh()
end
