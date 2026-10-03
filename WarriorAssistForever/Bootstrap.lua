local _, addon = ...
local frame = CreateFrame("Frame")
local elapsedCheck, elapsedDiscovery = 0, 0

for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "COOLDOWN_VIEWER_DATA_LOADED",
}) do
    frame:RegisterEvent(event)
end
frame:RegisterUnitEvent("UNIT_AURA", "player")

function addon:OnEvent(event, unit, updateInfo)
    if event == "PLAYER_LOGIN" then
        self:Start()
        return
    end

    if not self.started or not self.active then
        return
    end

    local reminder = self.BattleShoutReminder
    if event == "PLAYER_LEAVING_WORLD" then
        reminder:Stop()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        reminder:Initialize()
    elseif event == "UNIT_AURA" then
        if unit == "player" then
            reminder:OnAuraUpdate(updateInfo)
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED"
        or event == "COOLDOWN_VIEWER_DATA_LOADED" then
        self.CDM.Prepare(self.BattleShoutAura.name)
        self.BattleShoutIcon:ApplySettings()
    end

    reminder:Refresh()
end

frame:SetScript("OnEvent", function(_, event, ...)
    addon:OnEvent(event, ...)
end)
frame:SetScript("OnUpdate", function(_, elapsed)
    if not addon.active or not addon.BattleShoutReminder.running or not addon.Client.InCombat() then
        elapsedCheck, elapsedDiscovery = 0, 0
        return
    end

    elapsedCheck = elapsedCheck + elapsed
    elapsedDiscovery = elapsedDiscovery + elapsed
    if elapsedCheck < 0.1 then
        return
    end

    local discover = elapsedDiscovery >= 0.5
    elapsedCheck = 0
    if discover then
        elapsedDiscovery = 0
    end

    addon.BattleShoutReminder:Refresh(false, discover)
end)
