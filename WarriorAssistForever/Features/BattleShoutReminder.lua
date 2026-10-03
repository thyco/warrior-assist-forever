local _, addon = ...
local Reminder = { output = "none", cdmStatus = "not-checked", running = false }
local owner = "battle-shout"
addon.BattleShoutReminder = Reminder

function Reminder:Initialize()
    self.running = true
    addon.Glow.ConfigureOwner(owner, { color = addon.Config.GetColor("glowColor") })
end

function Reminder:OnAuraUpdate(updateInfo)
    addon.BattleShoutAura.Refresh(updateInfo)
    self:Refresh(false)
end

function Reminder:Refresh(sampleAura, discover)
    if not self.running then
        return
    end

    local status = sampleAura == false and addon.BattleShoutAura.Status() or addon.BattleShoutAura.Refresh()
    local enabled = addon.Config.Get("battleShoutEnabled")
    local output = "none"
    local item
    local resolved = false

    if addon.Client.InCombat() and enabled then
        if status.state == "missing" then
            output = "icon-missing"
        elseif status.deadline and GetTime() >= status.deadline - addon.Config.Get("leadSeconds") then
            if discover ~= false or (self.output ~= "cdm" and self.output ~= "icon-late") then
                resolved = true
                item, self.cdmStatus = addon.CDM.Resolve(addon.BattleShoutAura.name)
            else
                item = self.item
            end

            output = item and "cdm" or "icon-late"
        end
    end

    if self.item and self.item ~= item then
        addon.Glow.Set(self.item, owner, false)
    end

    self.item = item
    self.output = output
    addon.Glow.ConfigureOwner(owner, { color = addon.Config.GetColor("glowColor") })
    if item and resolved then
        addon.Glow.Set(item, owner, true)
    end

    if not enabled or addon.Client.InCombat() then
        addon.BattleShoutIcon:SetPreview(false)
    end

    addon.BattleShoutIcon:SetVisible(output == "icon-late" or output == "icon-missing")
end

function Reminder:Stop()
    self.running = false
    self.output = "none"
    self.cdmStatus = "not-checked"
    if self.item then
        addon.Glow.Set(self.item, owner, false)
        self.item = nil
    end

    addon.BattleShoutIcon:SetPreview(false)
    addon.BattleShoutIcon:SetVisible(false)
end

function Reminder:Status()
    return { output = self.output, cdmStatus = self.cdmStatus }
end
