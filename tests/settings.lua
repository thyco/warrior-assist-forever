local H = dofile("tests/helpers.lua")

local function setup(options)
    local world = H.new()
    if options then
        options(world)
    end

    local addon = world:loadManifest()
    world:fire("PLAYER_LOGIN")
    return world, addon
end

-- A missing panel or a skipped non-Warrior registration breaks native settings.
do
    local world, addon = setup(function(w)
        w.class = "MAGE"
    end)

    H.equal(addon.SettingsPanel.category.name, "Warrior Assist Forever")
    H.equal(#addon.SettingsPanel.sections, 4)
    H.equal(addon.SettingsPanel.controls.battleShoutEnabled.checked, true)
    H.equal(#addon.SettingsPanel.controls.leadSeconds.options, 60)
    H.equal(addon.SettingsPanel.controls.leadSeconds.options[1].value, 1)
    H.equal(addon.SettingsPanel.controls.leadSeconds.options[60].value, 60)
    H.equal(addon.Config.Get("glowColor"), "ff00ff00")
    H.equal(addon.SettingsPanel.controls.battleShoutNativeColor.checked, false)
    assert(addon.SettingsPanel.controls.battleShoutHideIcon,
        "Battle Shout hide artwork control exists")
    H.equal(addon.SettingsPanel.controls.battleShoutHideIcon.checked, false)
    H.equal(addon.SettingsPanel.controls.iconSize.selectedValue, 64)
    H.equal(addon.SettingsPanel.controls.iconSize.options[1].value, 16)
    H.equal(addon.SettingsPanel.controls.iconSize.options[29].value, 128)
    H.equal(addon.SettingsPanel.controls.stanceIconEnabled.checked, true)
    H.equal(addon.SettingsPanel.controls.stanceIconSize.selectedValue, 64)
    H.equal(addon.SettingsPanel.controls.stanceIconSize.options[1].value, 16)
    H.equal(addon.SettingsPanel.controls.stanceIconSize.options[29].value, 128)
    H.equal(addon.StanceIcon.frame, nil, "non-Warrior has no stance icon")

    H.equal(world.env.SLASH_WARRIORASSISTFOREVER1, "/waf")
    world.env.SlashCmdList.WARRIORASSISTFOREVER("config")
    H.equal(world.openedCategory, addon.SettingsPanel.category.id)
    world.env.SlashCmdList.WARRIORASSISTFOREVER("")
    assert(table.concat(world.printed, "\n"):find("Warrior inactive", 1, true))
end

-- Reactive abilities expose independent button and color settings.
do
    local world, addon = setup()
    local keys = { "overpowerEnabled", "overpowerBar", "overpowerButton",
        "overpowerBattleNativeColor", "overpowerBattleGlowColor",
        "overpowerBerserkerNativeColor", "overpowerBerserkerGlowColor",
        "revengeEnabled", "revengeBar", "revengeButton",
        "revengeNativeColor", "revengeGlowColor" }

    for _, key in ipairs(keys) do
        assert(world.settings["WarriorAssistForever_" .. key], key .. " setting missing")
        assert(addon.SettingsPanel.controls[key], key .. " control missing")
    end

    H.equal(world.settings.WarriorAssistForever_overpowerEnabled:GetValue(), true)
    H.equal(world.settings.WarriorAssistForever_revengeEnabled:GetValue(), true)
    H.equal(world.settings.WarriorAssistForever_overpowerBar:GetValue(), 0)
    H.equal(world.settings.WarriorAssistForever_revengeBar:GetValue(), 0)
    H.equal(world.settings.WarriorAssistForever_overpowerButton:GetValue(), 1)
    H.equal(world.settings.WarriorAssistForever_revengeButton:GetValue(), 1)
    H.equal(addon.SettingsPanel.controls.overpowerBar.options[1].label, "Not selected")
    H.equal(#addon.SettingsPanel.controls.overpowerBar.options, 9)
    H.equal(#addon.SettingsPanel.controls.revengeButton.options, 12)

    world.settings.WarriorAssistForever_overpowerBar:SetValue(3)
    world.settings.WarriorAssistForever_overpowerButton:SetValue(4)
    world.settings.WarriorAssistForever_revengeBar:SetValue(5)
    world.settings.WarriorAssistForever_revengeButton:SetValue(12)
    world.settings.WarriorAssistForever_overpowerEnabled:SetValue(false)

    H.equal(world.env.WarriorAssistForeverDB.overpowerBar, 3)
    H.equal(world.env.WarriorAssistForeverDB.overpowerButton, 4)
    H.equal(world.env.WarriorAssistForeverDB.revengeBar, 5)
    H.equal(world.env.WarriorAssistForeverDB.revengeButton, 12)
    H.equal(world.env.WarriorAssistForeverDB.overpowerEnabled, false)
    H.equal(world.env.WarriorAssistForeverDB.revengeEnabled, true)
    H.equal(addon.SettingsPanel.controls.revengeBar.text, "Left bar (second right bar)")
    H.equal(addon.SettingsPanel.controls.overpowerBattleNativeColor.checked, true)
    H.equal(addon.SettingsPanel.controls.overpowerBerserkerNativeColor.checked, true)
    H.equal(addon.SettingsPanel.controls.revengeNativeColor.checked, true)
end

-- The stance color picker persists a selection and Cancel restores it.
do
    local world, addon = setup()
    local original = addon.Config.Get("overpowerBattleGlowColor")
    world.env.ColorPickerFrame.GetColorRGB = function() return 0, 0, 1 end

    addon.SettingsPanel.controls.overpowerBattleGlowColor.scripts.OnClick()
    world.env.ColorPickerFrame.options.swatchFunc()
    H.equal(addon.Config.Get("overpowerBattleGlowColor"), "ff0000ff")

    world.env.ColorPickerFrame.options.cancelFunc()
    H.equal(addon.Config.Get("overpowerBattleGlowColor"), original)
end

-- Move preview starts from settings and stops when the panel closes.
do
    local world, addon = setup()

    addon.SettingsPanel.moveIconButton.scripts.OnClick()
    H.equal(addon.BattleShoutIcon.preview, true)
    addon.SettingsPanel.canvas.scripts.OnHide()
    H.equal(addon.BattleShoutIcon.preview, false)
end

-- Battle Shout icon size changes the actual reminder frame and persists.
do
    local world, addon = setup()

    H.equal(addon.BattleShoutIcon.frame.width, 64)
    addon.SettingsPanel.settings.iconSize:SetValue(36)

    H.equal(addon.BattleShoutIcon.frame.width, 36)
    H.equal(addon.BattleShoutIcon.frame.height, 36)
    H.equal(world.env.WarriorAssistForeverDB.iconSize, 36)
end

-- Hiding only the Battle Shout artwork keeps a due reminder and its glow visible.
do
    local world, addon = setup()
    world.combat = true
    world:fire("PLAYER_REGEN_DISABLED")

    local icon = addon.BattleShoutIcon
    local glow = addon.Glow.Prepare(icon.frame)
    H.equal(addon.BattleShoutReminder:Status().output, "icon-missing")
    H.equal(icon.texture.alpha or 1, 1)
    H.equal(world.glowActive[icon.frame], true)
    local shows = glow.frame.showCount

    addon.SettingsPanel.settings.battleShoutHideIcon:SetValue(true)
    H.equal(icon.texture.alpha, 0, "only Battle Shout artwork is transparent")
    H.equal(icon.frame:IsVisible(), true, "reminder frame remains visible")
    H.equal(world.glowActive[icon.frame], true, "glow remains active")
    H.equal(glow.frame.showCount, shows, "changing artwork does not restart the glow")
    H.equal(world.env.WarriorAssistForeverDB.battleShoutHideIcon, true)

    addon.SettingsPanel.settings.battleShoutHideIcon:SetValue(false)
    H.equal(icon.texture.alpha, 1, "artwork returns immediately")
    H.equal(world.glowActive[icon.frame], true)
end

-- A transparent icon can still be moved by its visible preview glow.
do
    local world, addon = setup()
    addon.SettingsPanel.settings.battleShoutHideIcon:SetValue(true)
    addon.SettingsPanel.moveIconButton.scripts.OnClick()

    local icon = addon.BattleShoutIcon
    H.equal(icon.texture.alpha, 0)
    H.equal(icon.frame:IsVisible(), true)
    H.equal(icon.frame.mouse, true)
    H.equal(world.glowActive[icon.frame], true)

    addon.SettingsPanel.canvas.scripts.OnHide()
    H.equal(icon.preview, false)
end

-- Changing the swatch recolors an active glow without showing its overlay again.
do
    local world, addon = setup()
    world.combat = true
    world:fire("PLAYER_REGEN_DISABLED")
    local entry = addon.Glow.Prepare(addon.BattleShoutIcon.frame)
    local shows = entry.frame.showCount
    world.env.ColorPickerFrame.GetColorRGB = function() return 1, 0, 0 end

    addon.SettingsPanel.controls.glowColor.scripts.OnClick()
    world.env.ColorPickerFrame.options.swatchFunc()

    H.equal(addon.Config.Get("glowColor"), "ffff0000")
    H.equal(world.glows[entry.frame].color[1], 1)
    H.equal(world.glows[entry.frame].color[2], 0)
    H.equal(entry.frame.showCount, shows)
    H.equal(world.glowActive[addon.BattleShoutIcon.frame], true)

    addon.SettingsPanel.settings.battleShoutNativeColor:SetValue(true)
    H.equal(world.glows[entry.frame].color, nil, "Battle Shout switches to native glow")
    addon.SettingsPanel.settings.battleShoutNativeColor:SetValue(false)
    H.equal(world.glows[entry.frame].color[1], 1, "custom picker color returns")
end

-- Settings apply immediately, including disabling a visible combat warning.
do
    local world, addon = setup()
    world.combat = true
    world:fire("PLAYER_REGEN_DISABLED")
    H.equal(addon.BattleShoutReminder:Status().output, "icon-missing")

    addon.SettingsPanel.settings.battleShoutEnabled:SetValue(false)
    H.equal(addon.BattleShoutReminder:Status().output, "none")
    H.equal(addon.BattleShoutIcon.frame:IsVisible(), false)

    addon.SettingsPanel.settings.leadSeconds:SetValue(60)
    H.equal(addon.Config.Get("leadSeconds"), 60)
end

-- Diagnostics report current aura timing and icon output.
do
    local world, addon = setup(function(w)
        w.auras = { { name = "Battle Shout", expirationTime = 180 } }
    end)
    world.time, world.combat = 170, true
    world:fire("PLAYER_REGEN_DISABLED")

    world.env.SlashCmdList.WARRIORASSISTFOREVER("")
    local result = table.concat(world.printed, "\n")
    assert(result:find("Battle Shout: present / exact / due in 10.0s", 1, true))
    assert(result:find("Reminder: icon-late", 1, true))
end

-- Diagnostics must use bounded labels even if an API status is tainted.
do
    local world, addon = setup()
    addon.BattleShoutAura.Status = function()
        return { state = "secret\nBAD", quality = "secret", deadline = math.huge }
    end
    addon.BattleShoutReminder.Status = function()
        return { output = "secret" }
    end

    world.env.SlashCmdList.WARRIORASSISTFOREVER("")
    local result = table.concat(world.printed, "\n")
    assert(result:find("Warrior Assist Forever 0.4.3 / client 16001 / Warrior active", 1, true))
    assert(result:find("Enabled: true / lead: 10s", 1, true))
    assert(result:find("Battle Shout: unknown / none / due in unknown", 1, true))
    assert(result:find("Reminder: none", 1, true))
    assert(not result:find("secret", 1, true))
    assert(not result:find("BAD", 1, true))
end

-- A restricted status table cannot be indexed while producing diagnostics.
do
    local world, addon = setup()
    local restricted = setmetatable({}, { __index = function() error("restricted status") end })
    world.secret[restricted] = true
    addon.BattleShoutAura.Status = function() return restricted end
    addon.BattleShoutReminder.Status = function() return restricted end

    world.env.SlashCmdList.WARRIORASSISTFOREVER("")
    local result = table.concat(world.printed, "\n")
    assert(result:find("Battle Shout: unknown / none / due in unknown", 1, true))
    assert(result:find("Reminder: none", 1, true))
end

-- Malformed persisted values restore independent safe defaults.
do
    local world, addon = setup(function(w)
        w.env.WarriorAssistForeverDB = {
            leadSeconds = -1, glowColor = "zzyyxxww", iconX = math.huge, iconY = 100000,
            iconSize = 25, overpowerBattleGlowColor = "bad", revengeNativeColor = "yes",
        }
    end)

    H.equal(addon.Config.Get("leadSeconds"), 10)
    H.equal(addon.Config.Get("glowColor"), "ff00ff00")
    H.equal(addon.Config.Get("iconX"), 0)
    H.equal(addon.Config.Get("iconY"), -270)
    H.equal(addon.Config.Get("iconSize"), 64)
    H.equal(addon.Config.Get("overpowerBattleGlowColor"), "ffffd24a")
    H.equal(addon.Config.Get("revengeNativeColor"), true)
end

print("settings: PASS")
