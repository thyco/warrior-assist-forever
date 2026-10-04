local _, addon = ...
local Icon = { preview = false }
addon.StanceIcon = Icon

local stanceSpells = { battle = 2457, defensive = 71, berserker = 2458 }
local unknownTexture = "Interface\\Icons\\INV_Misc_QuestionMark"

local function position(frame)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER",
        addon.Config.Get("stanceIconX"), addon.Config.Get("stanceIconY"))
end

function Icon:Initialize()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "WarriorAssistForeverStanceIcon", UIParent)
    self.frame = frame
    frame:SetSize(64, 64)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(false)

    self.texture = frame:CreateTexture(nil, "ARTWORK")
    self.texture:SetAllPoints(frame)

    frame:SetScript("OnDragStart", function(target)
        if self.preview and not addon.Client.InCombat() then
            target:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(target)
        target:StopMovingOrSizing()
        if not self.preview or addon.Client.InCombat() then
            return
        end

        local x, y = target:GetCenter()
        local centerX, centerY = UIParent:GetCenter()
        if addon.Client.Number(x) and addon.Client.Number(y)
            and addon.Client.Number(centerX) and addon.Client.Number(centerY) then
            addon.Config.Set("stanceIconX", math.max(-4096, math.min(4096, x - centerX)))
            addon.Config.Set("stanceIconY", math.max(-4096, math.min(4096, y - centerY)))
        end
    end)

    for _, event in ipairs({
        "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS",
        "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED",
    }) do
        frame:RegisterEvent(event)
    end
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            self:SetPreview(false)
        else
            self:Refresh()
        end
    end)

    self:ApplySettings()
    self:Refresh()
end

function Icon:ApplySettings()
    if not self.frame then
        return
    end

    local size = addon.Config.Get("stanceIconSize")
    self.frame:SetSize(size, size)
    position(self.frame)

    if not addon.Config.Get("stanceIconEnabled") then
        self:SetPreview(false)
    end
    self.frame:SetShown(addon.Config.Get("stanceIconEnabled"))
end

function Icon:Refresh()
    if not self.frame then
        return
    end

    local spellID = stanceSpells[addon.Stance.Current()]
    local texture
    if spellID then
        local ok, result = pcall(addon.Client.SpellTexture, spellID)
        if ok and addon.Client.Readable(result)
            and (type(result) == "number" or type(result) == "string") then
            texture = result
        end
    end

    self.texture:SetTexture(texture or unknownTexture)
end

function Icon:SetPreview(enabled)
    self.preview = enabled and self.frame ~= nil and not addon.Client.InCombat()
        and addon.Config.Get("stanceIconEnabled")
    if not self.frame then
        return
    end

    if not self.preview then
        self.frame:StopMovingOrSizing()
        position(self.frame)
    end

    self.frame:SetFrameStrata(self.preview and "TOOLTIP" or "DIALOG")
    self.frame:EnableMouse(self.preview)
end
