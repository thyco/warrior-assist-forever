local _, addon = ...
local Icon = { preview = false }
addon.StanceIcon = Icon

local stanceSpells = { battle = 2457, defensive = 71, berserker = 2458 }
local unknownTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
local cornerTexture = "Interface\\AddOns\\WarriorAssistForever\\Media\\ShieldCorner.tga"
local cornerCoordinates = {
    TOPLEFT = { 0, 1, 0, 1 },
    TOPRIGHT = { 1, 0, 0, 1 },
    BOTTOMLEFT = { 0, 1, 1, 0 },
    BOTTOMRIGHT = { 1, 0, 1, 0 },
}

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
    frame:SetFrameStrata("LOW")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(false)

    self.texture = frame:CreateTexture(nil, "ARTWORK")
    self.texture:SetAllPoints(frame)

    self.corner = frame:CreateTexture(nil, "OVERLAY")
    self.corner:SetTexture(cornerTexture)
    self.corner:Hide()

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
        "PLAYER_EQUIPMENT_CHANGED",
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
end

function Icon:ApplySettings()
    if not self.frame then
        return
    end

    local size = addon.Config.Get("stanceIconSize")
    self.frame:SetSize(size, size)
    position(self.frame)

    local cornerSize = size * 3 / 8
    local cornerInset = size / 16
    local cornerPosition = addon.Config.Get("shieldCornerPosition")
    local coordinates = cornerCoordinates[cornerPosition]
    local color = addon.Config.GetColor("shieldCornerColor")
    local offsetX = cornerPosition:find("LEFT", 1, true) and cornerInset or -cornerInset
    local offsetY = cornerPosition:find("TOP", 1, true) and -cornerInset or cornerInset
    self.corner:SetSize(cornerSize, cornerSize)
    self.corner:ClearAllPoints()
    self.corner:SetPoint(cornerPosition, self.frame, cornerPosition, offsetX, offsetY)
    self.corner:SetTexCoord(coordinates[1], coordinates[2], coordinates[3], coordinates[4])
    self.corner:SetVertexColor(color[1], color[2], color[3], color[4])

    if not addon.Config.Get("stanceIconEnabled") then
        self:SetPreview(false)
    end
    self.frame:SetShown(addon.Config.Get("stanceIconEnabled"))
    self:Refresh()
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

    if addon.Config.Get("shieldCornerEnabled") and addon.Client.HasShield() then
        self.corner:Show()
    else
        self.corner:Hide()
    end
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

    self.frame:SetFrameStrata(self.preview and "TOOLTIP" or "LOW")
    self.frame:EnableMouse(self.preview)
end
