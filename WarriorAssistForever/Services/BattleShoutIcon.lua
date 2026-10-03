local _, addon = ...
local Icon = { preview = false, visible = false }
local owner = "battle-shout-icon"
addon.BattleShoutIcon = Icon

function Icon:Initialize()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "WarriorAssistForeverBattleShoutIcon", UIParent)
    self.frame = frame
    frame:SetSize(64, 64)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(false)

    self.texture = frame:CreateTexture(nil, "ARTWORK")
    self.texture:SetAllPoints(frame)
    self.texture:SetTexture(addon.Client.SpellTexture(6673) or "Interface\\Icons\\INV_Misc_QuestionMark")
    frame:SetScript("OnDragStart", function(target)
        if self.preview and not addon.Client.InCombat() then
            target:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(target)
        target:StopMovingOrSizing()

        local x, y = target:GetCenter()
        local centerX, centerY = UIParent:GetCenter()
        if addon.Client.Number(x) and addon.Client.Number(y)
            and addon.Client.Number(centerX) and addon.Client.Number(centerY) then
            addon.Config.Set("iconX", math.max(-4096, math.min(4096, x - centerX)))
            addon.Config.Set("iconY", math.max(-4096, math.min(4096, y - centerY)))
        end
    end)

    addon.Glow.Prepare(frame)
    self:ApplySettings()
end

function Icon:ApplySettings()
    if not self.frame then
        return
    end

    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", addon.Config.Get("iconX"), addon.Config.Get("iconY"))
    addon.Glow.ConfigureOwner(owner, { color = addon.Config.GetColor("glowColor") })
    addon.Glow.Prepare(self.frame)
    self:Render()
end

function Icon:SetVisible(visible)
    self.visible = visible
    self:Render()
end

function Icon:SetPreview(enabled)
    self.preview = enabled and not addon.Client.InCombat() and addon.Config.Get("battleShoutEnabled")
    if not self.frame then
        return
    end

    if not self.preview then
        self.frame:StopMovingOrSizing()
    end

    self.frame:SetFrameStrata(self.preview and "TOOLTIP" or "MEDIUM")
    self.frame:EnableMouse(self.preview)
    self:Render()
end

function Icon:Render()
    if not self.frame then
        return
    end

    local visible = self.preview or self.visible
    self.frame:SetShown(visible)
    addon.Glow.Set(self.frame, owner, visible)
end
