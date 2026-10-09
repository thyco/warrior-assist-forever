local _, addon = ...
local panel = { controls = {}, settings = {}, sections = {} }
addon.SettingsPanel = panel

local function registerSetting(key, label, valueType)
    local setting = Settings.RegisterProxySetting(panel.category, "WarriorAssistForever_" .. key,
        valueType, label, addon.Config.GetDefault(key),
        function()
            return addon.Config.Get(key)
        end,
        function(value)
            addon.Config.Set(key, value)
        end)
    panel.settings[key] = setting
    return setting
end

function panel:Refresh()
    for _, control in pairs(self.controls) do
        control.refresh()
    end
end

function panel:Initialize()
    if self.category then
        return
    end

    local widgets = addon.SettingsWidgets
    local canvas = CreateFrame("Frame")
    self.canvas = canvas
    canvas:Hide()
    self.category = Settings.RegisterCanvasLayoutCategory(canvas, "Warrior Assist Forever")

    local scroll = CreateFrame("ScrollFrame", nil, canvas, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -28, 8)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(580, 2040)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(math.max(1, width))
    end)

    widgets.Text(content, "Warrior Assist Forever", 8, -8, "GameFontNormalLarge")
    local section = widgets.Section(content, "Battle Shout", "Combat reminder for your Battle Shout buff", -48, 340)
    self.sections = { section }

    local enabled = registerSetting("battleShoutEnabled", "Enable Battle Shout reminder", Settings.VarType.Boolean)
    self.controls.battleShoutEnabled = widgets.Checkbox(section, "Enable Battle Shout reminder", -62, enabled)

    local leads = {}
    for seconds = 1, 60 do
        leads[#leads + 1] = { value = seconds, label = seconds .. (seconds == 1 and " second" or " seconds") }
    end

    local lead = registerSetting("leadSeconds", "Remind before expiry", Settings.VarType.Number)
    self.controls.leadSeconds = widgets.Dropdown(section, "Remind before expiry", -104, lead, leads)

    local native = registerSetting("battleShoutNativeColor", "Use Blizzard native glow", Settings.VarType.Boolean)
    self.controls.battleShoutNativeColor = widgets.Checkbox(section, "Use Blizzard native glow", -148, native)

    local color = registerSetting("glowColor", "Custom glow color", Settings.VarType.String)
    self.controls.glowColor = widgets.Color(section, "Custom glow color", -188, color)

    local sizes = {}
    for pixels = 16, 128, 4 do
        sizes[#sizes + 1] = { value = pixels, label = pixels .. " pixels" }
    end

    local size = registerSetting("iconSize", "Icon size", Settings.VarType.Number)
    self.controls.iconSize = widgets.Dropdown(section, "Icon size", -232, size, sizes)

    local hideIcon = registerSetting("battleShoutHideIcon", "Hide icon artwork (keep glow)", Settings.VarType.Boolean)
    self.controls.battleShoutHideIcon = widgets.Checkbox(section,
        "Hide icon artwork (keep glow)", -269, hideIcon)

    local move = CreateFrame("Button", nil, section, "UIPanelButtonTemplate")
    move:SetPoint("TOPLEFT", section, "TOPLEFT", 20, -306)
    move:SetSize(140, 28)
    move:SetText("Move icon")
    move:SetScript("OnClick", function()
        addon.BattleShoutIcon:SetPreview(true)
    end)
    self.moveIconButton = move

    local bars = { { value = 0, label = "Not selected" } }
    for index, name in ipairs(addon.Buttons.Bars()) do
        bars[#bars + 1] = { value = index, label = name }
    end

    local buttons = {}
    for index = 1, 12 do
        buttons[#buttons + 1] = { value = index, label = "Button " .. index }
    end

    local abilities = {
        { name = "Overpower", key = "overpower", y = -404, height = 390,
            description = "Battle Stance usability or Berserker Stance proc overlay" },
        { name = "Revenge", key = "revenge", y = -810, height = 300,
            description = "Defensive Stance usability" },
        { name = "Execute", key = "execute", y = -1126, height = 300,
            description = "Battle or Berserker Stance usability" },
        { name = "Victory Rush", key = "victoryRush", y = -1442, height = 300,
            description = "In combat: usable and off its own cooldown" },
    }

    for _, ability in ipairs(abilities) do
        local group = widgets.Section(content, ability.name, ability.description, ability.y, ability.height)
        self.sections[#self.sections + 1] = group

        local enabledKey = ability.key .. "Enabled"
        local enabledSetting = registerSetting(enabledKey, "Enable " .. ability.name .. " glow", Settings.VarType.Boolean)
        self.controls[enabledKey] = widgets.Checkbox(group, "Enable " .. ability.name .. " glow", -70, enabledSetting)

        local barKey = ability.key .. "Bar"
        local barSetting = registerSetting(barKey, ability.name .. " action bar", Settings.VarType.Number)
        self.controls[barKey] = widgets.Dropdown(group, "Action bar", -116, barSetting, bars)

        local buttonKey = ability.key .. "Button"
        local buttonSetting = registerSetting(buttonKey, ability.name .. " button", Settings.VarType.Number)
        self.controls[buttonKey] = widgets.Dropdown(group, "Button", -166, buttonSetting, buttons)

        if ability.key == "overpower" then
            local battleNative = registerSetting("overpowerBattleNativeColor",
                "Battle Stance: Blizzard native glow", Settings.VarType.Boolean)
            self.controls.overpowerBattleNativeColor = widgets.Checkbox(group,
                "Battle Stance: Blizzard native glow", -218, battleNative)

            local battleColor = registerSetting("overpowerBattleGlowColor",
                "Battle Stance color", Settings.VarType.String)
            self.controls.overpowerBattleGlowColor = widgets.Color(group,
                "Battle Stance color", -260, battleColor)

            local berserkerNative = registerSetting("overpowerBerserkerNativeColor",
                "Berserker Stance: Blizzard native glow", Settings.VarType.Boolean)
            self.controls.overpowerBerserkerNativeColor = widgets.Checkbox(group,
                "Berserker Stance: Blizzard native glow", -304, berserkerNative)

            local berserkerColor = registerSetting("overpowerBerserkerGlowColor",
                "Berserker Stance color", Settings.VarType.String)
            self.controls.overpowerBerserkerGlowColor = widgets.Color(group,
                "Berserker Stance color", -346, berserkerColor)
        else
            local nativeKey = ability.key .. "NativeColor"
            local colorKey = ability.key .. "GlowColor"
            local native = registerSetting(nativeKey,
                "Use Blizzard native glow", Settings.VarType.Boolean)
            self.controls[nativeKey] = widgets.Checkbox(group,
                "Use Blizzard native glow", -218, native)

            local color = registerSetting(colorKey,
                "Custom glow color", Settings.VarType.String)
            self.controls[colorKey] = widgets.Color(group,
                "Custom glow color", -260, color)
        end
    end

    local stance = widgets.Section(content, "Current Stance",
        "Always-visible icon for Battle, Defensive, or Berserker Stance", -1758, 235)
    self.sections[#self.sections + 1] = stance

    local stanceEnabled = registerSetting("stanceIconEnabled", "Show current stance icon", Settings.VarType.Boolean)
    self.controls.stanceIconEnabled = widgets.Checkbox(stance,
        "Show current stance icon", -70, stanceEnabled)

    local stanceSize = registerSetting("stanceIconSize", "Stance icon size", Settings.VarType.Number)
    self.controls.stanceIconSize = widgets.Dropdown(stance,
        "Stance icon size", -116, stanceSize, sizes)

    local stanceMove = CreateFrame("Button", nil, stance, "UIPanelButtonTemplate")
    stanceMove:SetPoint("TOPLEFT", stance, "TOPLEFT", 20, -170)
    stanceMove:SetSize(160, 28)
    stanceMove:SetText("Move stance icon")
    stanceMove:SetScript("OnClick", function()
        addon.StanceIcon:SetPreview(true)
    end)
    self.moveStanceIconButton = stanceMove

    canvas:SetScript("OnShow", function()
        content:SetWidth(math.max(1, scroll:GetWidth()))
        self:Refresh()
    end)
    canvas:SetScript("OnHide", function()
        addon.BattleShoutIcon:SetPreview(false)
        addon.StanceIcon:SetPreview(false)
    end)
    addon.Config.Subscribe(function()
        self:Refresh()
    end)
    self:Refresh()
    Settings.RegisterAddOnCategory(self.category)
end

function panel:Open()
    if self.category then
        Settings.OpenToCategory(self.category:GetID())
    end
end
