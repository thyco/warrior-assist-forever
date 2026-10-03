local _, addon = ...
local Widgets = {}
addon.SettingsWidgets = Widgets
local dropdownSerial = 0

function Widgets.Text(parent, text, x, y, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

function Widgets.Section(parent, title, description, y, height)
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y)
    section:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, y)
    section:SetHeight(height)
    section:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    section:SetBackdropColor(0.035, 0.035, 0.045, 0.8)
    section:SetBackdropBorderColor(0.35, 0.31, 0.22, 1)

    Widgets.Text(section, title, 16, -14, "GameFontNormalLarge")
    local subtitle = Widgets.Text(section, description, 16, -38)
    subtitle:SetPoint("TOPRIGHT", section, "TOPRIGHT", -16, -38)
    subtitle:SetTextColor(0.7, 0.7, 0.7)
    return section
end

function Widgets.Checkbox(parent, label, y, setting)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
    check.Text:SetText(label)
    check.Text:SetFontObject("GameFontHighlight")
    check:SetScript("OnClick", function(self)
        setting:SetValue(not not self:GetChecked())
    end)
    check.refresh = function()
        check:SetChecked(setting:GetValue())
    end
    return check
end

function Widgets.Dropdown(parent, label, y, setting, options)
    Widgets.Text(parent, label, 20, y - 7, "GameFontHighlight")
    dropdownSerial = dropdownSerial + 1
    local dropdown = CreateFrame("Frame", "WarriorAssistForeverDropdown" .. dropdownSerial,
        parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 250, y)
    UIDropDownMenu_SetWidth(dropdown, 210)
    dropdown.options = options
    UIDropDownMenu_Initialize(dropdown, function()
        for _, option in ipairs(options) do
            local value, text = option.value, option.label
            local info = UIDropDownMenu_CreateInfo()
            info.text = text
            info.value = value
            info.checked = setting:GetValue() == value
            info.func = function()
                setting:SetValue(value)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    dropdown.refresh = function()
        local value = setting:GetValue()
        dropdown.selectedName = nil
        dropdown.selectedID = nil
        dropdown.selectedValue = value

        for _, option in ipairs(options) do
            if option.value == value then
                UIDropDownMenu_SetText(dropdown, option.label)
                break
            end
        end
    end
    return dropdown
end

function Widgets.Color(parent, label, y, setting)
    Widgets.Text(parent, label, 20, y - 5, "GameFontHighlight")
    local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
    swatch:SetPoint("TOPLEFT", parent, "TOPLEFT", 266, y)
    swatch:SetSize(26, 24)
    swatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    swatch:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
    local fill = swatch:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", swatch, "TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -3, 3)

    local function rgb()
        local hex = setting:GetValue()
        return tonumber(hex:sub(3, 4), 16) / 255,
            tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255
    end

    swatch.refresh = function()
        local r, g, b = rgb()
        fill:SetColorTexture(r, g, b, 1)
    end
    swatch:SetScript("OnClick", function()
        local previous = setting:GetValue()
        local r, g, b = rgb()
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = function()
                local red, green, blue = ColorPickerFrame:GetColorRGB()
                setting:SetValue(string.format("ff%02x%02x%02x",
                    math.floor(red * 255 + 0.5), math.floor(green * 255 + 0.5), math.floor(blue * 255 + 0.5)))
            end,
            cancelFunc = function()
                setting:SetValue(previous)
            end,
        })
    end)
    return swatch
end
