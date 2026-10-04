local _, addon = ...
local Reminder = { output = "none", running = false }
addon.BattleShoutReminder = Reminder

function Reminder:Initialize()
    self.running = true
end

function Reminder:OnAuraUpdate(updateInfo)
    addon.BattleShoutAura.Refresh(updateInfo)
    self:Refresh(false)
end

function Reminder:OnPlayerCast(spellID)
    if self.running and addon.BattleShoutAura.ObservePlayerCast(spellID) then
        self:Refresh(false)
    end
end

function Reminder:Refresh(sampleAura)
    if not self.running then
        return
    end

    local status = sampleAura == false and addon.BattleShoutAura.Status() or addon.BattleShoutAura.Refresh()
    local enabled = addon.Config.Get("battleShoutEnabled")
    local output = "none"

    if addon.Client.InCombat() and enabled then
        if status.state == "missing" or (status.state == "unknown" and status.lastConfirmedMissing) then
            output = "icon-missing"
        elseif status.deadline and GetTime() >= status.deadline - addon.Config.Get("leadSeconds") then
            output = "icon-late"
        end
    end

    self.output = output

    if not enabled or addon.Client.InCombat() then
        addon.BattleShoutIcon:SetPreview(false)
    end

    addon.BattleShoutIcon:SetVisible(output == "icon-late" or output == "icon-missing")
end

function Reminder:Stop()
    self.running = false
    self.output = "none"

    addon.BattleShoutIcon:SetPreview(false)
    addon.BattleShoutIcon:SetVisible(false)
end

function Reminder:Status()
    return { output = self.output }
end
