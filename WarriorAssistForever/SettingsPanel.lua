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
    content:SetSize(580, 850)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(math.max(1, width))
    end)

    widgets.Text(content, "Warrior Assist Forever", 8, -8, "GameFontNormalLarge")
    local section = widgets.Section(content, "Battle Shout", "Combat reminder for your Battle Shout buff", -48, 260)
    self.sections = { section }

    local enabled = registerSetting("battleShoutEnabled", "Enable Battle Shout reminder", Settings.VarType.Boolean)
    self.controls.battleShoutEnabled = widgets.Checkbox(section, "Enable Battle Shout reminder", -62, enabled)

    local leads = {}
    for seconds = 1, 60 do
        leads[#leads + 1] = { value = seconds, label = seconds .. (seconds == 1 and " second" or " seconds") }
    end

    local lead = registerSetting("leadSeconds", "Remind before expiry", Settings.VarType.Number)
    self.controls.leadSeconds = widgets.Dropdown(section, "Remind before expiry", -104, lead, leads)

    local color = registerSetting("glowColor", "Glow color", Settings.VarType.String)
    self.controls.glowColor = widgets.Color(section, "Glow color", -148, color)

    local move = CreateFrame("Button", nil, section, "UIPanelButtonTemplate")
    move:SetPoint("TOPLEFT", section, "TOPLEFT", 20, -192)
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
        { name = "Overpower", key = "overpower", y = -324,
            description = "Battle Stance usability or Berserker Stance proc overlay" },
        { name = "Revenge", key = "revenge", y = -588,
            description = "Defensive Stance usability" },
    }

    for _, ability in ipairs(abilities) do
        local group = widgets.Section(content, ability.name, ability.description, ability.y, 244)
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
    end

    canvas:SetScript("OnShow", function()
        content:SetWidth(math.max(1, scroll:GetWidth()))
        self:Refresh()
    end)
    canvas:SetScript("OnHide", function()
        addon.BattleShoutIcon:SetPreview(false)
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
