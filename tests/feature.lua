local H = dofile("tests/helpers.lua")

local function setup(options)
    local world = H.new()
    if options then options(world) end

    local addon = world:loadManifest()
    world:fire("PLAYER_LOGIN")
    assert(addon.BattleShoutIcon and addon.BattleShoutReminder, "feature, icon, and bootstrap must be loaded")
    return world, addon
end

local function present(world, expiration)
    world.auras = { { name = "Battle Shout", expirationTime = expiration, auraInstanceID = 9, sourceUnit = "party1" } }
end

local function output(addon, expected)
    H.equal(addon.BattleShoutReminder:Status().output, expected)
    H.equal(addon.BattleShoutIcon.frame:IsVisible(), expected == "icon-late" or expected == "icon-missing")
end

-- Timer ticks cross the inclusive threshold without requerying the aura.
do
    local world, addon = setup(function(w) present(w, 180) end)
    world.combat = true
    world:fire("PLAYER_REGEN_DISABLED")
    output(addon, "none")

    local queries = world.auraQueries
    world:tick(169.9)
    output(addon, "none")
    world:tick(0.1)
    output(addon, "icon-late")
    H.equal(world.auraQueries, queries)
    H.equal(world.glowActive[addon.BattleShoutIcon.frame], true)

    addon.Config.Set("leadSeconds", 5)
    output(addon, "none")
    H.equal(addon.BattleShoutAura.Status().deadline, 180)
    addon.Config.Set("leadSeconds", 20)
    output(addon, "icon-late")
end

-- A visible CDM buff never replaces the movable screen reminder.
do
    local item
    local world, addon = setup(function(w)
        present(w, 180)
        item = w:newCDMItem(42, 6673, true)
        w:setCDMItems({ item })
    end)

    world.time, world.combat = 170, true
    world:fire("PLAYER_REGEN_DISABLED")

    output(addon, "icon-late")
    H.equal(world.glowActive[addon.BattleShoutIcon.frame], true)
    H.equal(world.glowActive[item], nil, "CDM buff icon receives no glow")
end

-- Confirmed missing requires combat but never a target; unknown clears it.
do
    local world, addon = setup()
    output(addon, "none")
    world.combat = true
    world:fire("PLAYER_REGEN_DISABLED")
    output(addon, "icon-missing")
    world.env.UnitExists = function() return true end
    world:fire("PLAYER_REGEN_DISABLED")
    output(addon, "icon-missing")

    world.auraError = true
    world:fire("UNIT_AURA", "player")
    output(addon, "none")
    H.equal(addon.BattleShoutAura.Status().deadline, nil)
end

-- Unknown retains a known deadline, and another Warrior refresh resets it.
do
    local world, addon = setup(function(w) present(w, 180) end)
    world.combat, world.time, world.auraError = true, 170, true
    world:fire("PLAYER_REGEN_DISABLED")
    output(addon, "icon-late")
    H.equal(addon.BattleShoutAura.Status().quality, "estimated")

    world.auraError = false
    present(world, 350)
    local opaqueUnit = {}
    world.secret[opaqueUnit] = true
    world:fire("UNIT_AURA", opaqueUnit, { updatedAuraInstanceIDs = { 9 } })

    output(addon, "none")
    H.equal(addon.BattleShoutAura.Status().deadline, 350)
end

-- Disabling clears output, observes new auras, and reenabling is immediate.
do
    local world, addon = setup()
    world.combat = true
    world:fire("PLAYER_REGEN_DISABLED")
    addon.Config.Set("battleShoutEnabled", false)
    output(addon, "none")
    present(world, 180)
    world:fire("UNIT_AURA", "player")
    world.time = 170
    addon.Config.Set("battleShoutEnabled", true)
    output(addon, "icon-late")

    world:fire("PLAYER_LEAVING_WORLD")
    output(addon, "none")
    world:tick(1)
    output(addon, "none")
    addon.Config.Set("leadSeconds", 20)
    output(addon, "none")
    world:fire("PLAYER_ENTERING_WORLD")
    output(addon, "icon-late")
end

-- Combat entry samples fresh auras and combat exit clears the reminder.
do
    local world, addon = setup(function(w) present(w, 180) end)

    world.auras, world.combat = {}, true
    world:fire("PLAYER_REGEN_DISABLED")
    output(addon, "icon-missing")
    world.combat = false
    world:fire("PLAYER_REGEN_ENABLED")
    output(addon, "none")
end

-- Class gating avoids feature initialization and aura queries entirely.
do
    local world, addon = setup(function(w) w.class = "MAGE" end)
    H.equal(#addon.features, 0)
    H.equal(addon.BattleShoutIcon.frame, nil)
    world.combat = true
    world:fire("PLAYER_REGEN_DISABLED")
    world:fire("UNIT_AURA", "player")
    world:tick(1)
    H.equal(world.auraQueries, 0)
end

-- Preview moves the saved icon outside combat and ends on combat entry.
do
    local world, addon = setup()
    local icon = addon.BattleShoutIcon
    H.equal(icon.frame.strata, "DIALOG", "reminder stays above CDM after placement")
    icon:SetPreview(true)
    H.equal(icon.frame:IsVisible(), true)
    H.equal(icon.frame.mouse, true)
    icon.frame.scripts.OnDragStart(icon.frame)
    H.equal(icon.frame.moving, true)
    icon.frame.x, icon.frame.y = 550, 480
    icon.frame.scripts.OnDragStop(icon.frame)
    H.equal(addon.Config.Get("iconX"), 50)
    H.equal(addon.Config.Get("iconY"), 80)

    world.combat = true
    world:fire("PLAYER_REGEN_DISABLED")
    H.equal(icon.frame.mouse, false)
    H.equal(icon.frame.strata, "DIALOG", "combat reminder retains display layer")
    icon:SetPreview(true)
    H.equal(icon.preview, false)
end

-- The localized aura name drives the independent screen reminder.
do
    local world, addon = setup(function(w)
        w.spellName = "Schlachtruf"
        w.auras = { { name = "Schlachtruf", expirationTime = 180 } }
    end)
    H.equal(addon.BattleShoutAura.name, "Schlachtruf")
    world.combat, world.time = true, 170
    world:fire("PLAYER_REGEN_DISABLED")
    output(addon, "icon-late")
end

-- Disabling the reminder clears the icon; custom color persists when it returns.
do
    local world, addon = setup(function(w) present(w, 180) end)
    world.time, world.combat = 170, true
    world:fire("PLAYER_REGEN_DISABLED")
    addon.Config.Set("glowColor", "ffff0000")

    local entry = addon.Glow.Prepare(addon.BattleShoutIcon.frame)
    H.equal(world.glows[entry.frame].color[1], 1)
    H.equal(world.glows[entry.frame].color[2], 0)

    addon.Config.Set("battleShoutEnabled", false)
    output(addon, "none")
    addon.Config.Set("battleShoutEnabled", true)
    output(addon, "icon-late")
    world.auras = {}
    world:fire("UNIT_AURA", "player")
    output(addon, "icon-missing")
    H.equal(world.glows[entry.frame].color[1], 1)
    H.equal(world.glows[entry.frame].color[2], 0)
end

print("feature: PASS")
