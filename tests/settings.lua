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
    H.equal(#addon.SettingsPanel.sections, 1)
    H.equal(addon.SettingsPanel.controls.battleShoutEnabled.checked, true)
    H.equal(#addon.SettingsPanel.controls.leadSeconds.options, 60)
    H.equal(addon.SettingsPanel.controls.leadSeconds.options[1].value, 1)
    H.equal(addon.SettingsPanel.controls.leadSeconds.options[60].value, 60)
    H.equal(addon.Config.Get("glowColor"), "ff00ff00")

    H.equal(world.env.SLASH_WARRIORASSISTFOREVER1, "/waf")
    world.env.SlashCmdList.WARRIORASSISTFOREVER("config")
    H.equal(world.openedCategory, addon.SettingsPanel.category.id)
    world.env.SlashCmdList.WARRIORASSISTFOREVER("")
    assert(table.concat(world.printed, "\n"):find("Warrior inactive", 1, true))
end

-- Move preview starts from settings and stops when the panel closes.
do
    local world, addon = setup()

    addon.SettingsPanel.moveIconButton.scripts.OnClick()
    H.equal(addon.BattleShoutIcon.preview, true)
    addon.SettingsPanel.canvas.scripts.OnHide()
    H.equal(addon.BattleShoutIcon.preview, false)
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

-- Diagnostics report the current aura timing and CDM output.
do
    local item
    local world, addon = setup(function(w)
        w.auras = { { name = "Battle Shout", expirationTime = 180 } }
        item = w:newCDMItem(42, 6673, true)
        w:setCDMItems({ item })
    end)
    world.time, world.combat = 170, true
    world:fire("PLAYER_REGEN_DISABLED")

    world.env.SlashCmdList.WARRIORASSISTFOREVER("")
    local result = table.concat(world.printed, "\n")
    assert(result:find("Battle Shout: present / exact / due in 10.0s", 1, true))
    assert(result:find("CDM: visible / output: cdm", 1, true))
end

-- Diagnostics must use bounded labels even if an API status is tainted.
do
    local world, addon = setup()
    addon.BattleShoutAura.Status = function()
        return { state = "secret\nBAD", quality = "secret", deadline = math.huge }
    end
    addon.BattleShoutReminder.Status = function()
        return { cdmStatus = "secret", output = "secret" }
    end

    world.env.SlashCmdList.WARRIORASSISTFOREVER("")
    local result = table.concat(world.printed, "\n")
    assert(result:find("Warrior Assist Forever 0.1.0 / client 16001 / Warrior active", 1, true))
    assert(result:find("Enabled: true / lead: 10s", 1, true))
    assert(result:find("Battle Shout: unknown / none / due in unknown", 1, true))
    assert(result:find("CDM: unavailable / output: none", 1, true))
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
    assert(result:find("output: none", 1, true))
end

-- Malformed persisted values restore independent safe defaults.
do
    local world, addon = setup(function(w)
        w.env.WarriorAssistForeverDB = {
            leadSeconds = -1, glowColor = "zzyyxxww", iconX = math.huge, iconY = 100000,
        }
    end)

    H.equal(addon.Config.Get("leadSeconds"), 10)
    H.equal(addon.Config.Get("glowColor"), "ff00ff00")
    H.equal(addon.Config.Get("iconX"), 0)
    H.equal(addon.Config.Get("iconY"), -270)
end

print("settings: PASS")
