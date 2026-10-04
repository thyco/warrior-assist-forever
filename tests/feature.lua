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

-- A prepared CDM item wins; hiding/repooling releases its glow.
do
    local item
    local world, addon = setup(function(w)
        present(w, 180)
        item = w:newCDMItem(42, 6673, true)
        w:setCDMItems({ item })
        w.env.C_Spell.GetSpellInfo = function(id) return { name = id == 6673 and "Battle Shout" or "Other" } end
    end)
    H.equal(addon.Glow.IsPrepared(item), true)
    world.time, world.combat = 170, true
    world:fire("PLAYER_REGEN_DISABLED")
    output(addon, "cdm")
    H.equal(world.glowActive[item], true)

    item:Hide()
    world:tick(0.1)
    H.equal(world.glowActive[item], false)
    world:tick(0.5)
    output(addon, "icon-late")
    H.equal(addon.BattleShoutReminder:Status().cdmStatus, "hidden")
    H.equal(world.glowActive[item], false)

    item:Show()
    world:tick(0.5)
    output(addon, "cdm")
    item.spellID = 12345
    world:tick(0.5)
    output(addon, "icon-late")
    H.equal(world.glowActive[item], false)
end

-- A CDM frame first discovered during combat cannot allocate overlays.
do
    local world, addon = setup()
    world.combat, world.time = true, 170
    present(world, 180)
    local item = world:newCDMItem(42, 6673, true)
    world:setCDMItems({ item })
    world:fire("PLAYER_REGEN_DISABLED")

    output(addon, "icon-late")
    H.equal(addon.BattleShoutReminder:Status().cdmStatus, "unprepared")
    H.equal(world.combatFrameCreations, 0)

    world.combat = false
    world:fire("PLAYER_REGEN_ENABLED")
    output(addon, "none")
    H.equal(addon.Glow.IsPrepared(item), true)
    world.combat = true
    world:fire("PLAYER_REGEN_DISABLED")
    output(addon, "cdm")
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

-- Combat entry samples fresh auras; data load prepares late CDM items.
do
    local world, addon = setup(function(w) present(w, 180) end)
    local item = world:newCDMItem(42, 6673, true)
    world:setCDMItems({ item })
    world:fire("COOLDOWN_VIEWER_DATA_LOADED")
    H.equal(addon.Glow.IsPrepared(item), true)

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
    icon:SetPreview(true)
    H.equal(icon.preview, false)
end

-- CDM consumes the exact localized aura name established by initialization.
do
    local world, addon = setup(function(w)
        w.spellName = "Schlachtruf"
        w.auras = { { name = "Schlachtruf", expirationTime = 180 } }
        w:setCDMItems({ w:newCDMItem(42, 6673, true) })
    end)
    H.equal(addon.BattleShoutAura.name, "Schlachtruf")
    world.combat, world.time = true, 170
    world:fire("PLAYER_REGEN_DISABLED")
    output(addon, "cdm")
end

-- Missing CDM fallback discovery is throttled even while the threshold tick runs.
do
    local world, addon = setup(function(w) present(w, 180) end)
    world.time, world.combat = 170, true
    world:fire("PLAYER_REGEN_DISABLED")
    local scans = 0
    world.env.BuffIconCooldownViewer = {
        itemFramePool = {
            EnumerateActive = function()
                scans = scans + 1
                return function() return nil end
            end,
        },
    }

    world:tick(0.1)
    world:tick(0.1)
    world:tick(0.1)
    world:tick(0.1)
    H.equal(scans, 0)
    world:tick(0.1)
    H.equal(scans, 1)
    output(addon, "icon-late")
end

-- Disabled CDM output releases its glow, and configured color reaches both outputs.
do
    local item
    local world, addon = setup(function(w)
        present(w, 180)
        item = w:newCDMItem(42, 6673, true)
        w:setCDMItems({ item })
    end)
    world.time, world.combat = 170, true
    world:fire("PLAYER_REGEN_DISABLED")
    addon.Config.Set("glowColor", "ffff0000")
    local entry = addon.Glow.Prepare(item)
    H.equal(world.glows[entry.frame].color[1], 1)
    H.equal(world.glows[entry.frame].color[2], 0)

    addon.Config.Set("battleShoutEnabled", false)
    output(addon, "none")
    H.equal(world.glowActive[item], false)
    addon.Config.Set("battleShoutEnabled", true)
    output(addon, "cdm")
    world.auras = {}
    world:fire("UNIT_AURA", "player")
    output(addon, "icon-missing")
    H.equal(world.glowActive[item], false)
    entry = addon.Glow.Prepare(addon.BattleShoutIcon.frame)
    H.equal(world.glows[entry.frame].color[1], 1)
    H.equal(world.glows[entry.frame].color[2], 0)
end

print("feature: PASS")
