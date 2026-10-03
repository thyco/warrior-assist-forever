local H = dofile("tests/helpers.lua")

local function setup()
    local world = H.new()
    world.env.C_Spell.GetSpellInfo = function(id)
        local names = { [6673] = "Battle Shout", [5242] = "Battle Shout", [12345] = "Other" }
        return { name = names[id] }
    end

    local addon = world:load({ "Core", "Services/Client", "Services/Glow", "Services/CDM" })
    return world, addon
end

local function expectResolution(addon, name, expected, expectedStatus)
    local found, status = addon.CDM.Resolve(name)

    H.equal(found, expected)
    H.equal(status, expectedStatus)
end

-- A matching configured item is prepared and reused without duplicate hooks.
do
    local world, addon = setup()
    local item = world:newCDMItem(42, 6673, true)
    world:setCDMItems({ item })

    expectResolution(addon, "Battle Shout", item, "visible")
    expectResolution(addon, "Battle Shout", item, "visible")
    addon.Glow.Set(item, "battle-shout", true)

    H.equal(world.glowActive[item], true)
    H.equal(#item.hooks.OnHide, 1)
    H.equal(addon.Glow.IsPrepared(item), true)

    item:Hide()

    H.equal(world.glowActive[item], false)
    expectResolution(addon, "Battle Shout", nil, "hidden")

    item.spellID = 12345
    expectResolution(addon, "Battle Shout", nil, "not-configured")
end

-- Identity changes without hiding must release the previous glow.
do
    local world, addon = setup()
    local old = world:newCDMItem(42, 6673, true)
    local replacement = world:newCDMItem(43, 5242, true)
    world:setCDMItems({ old })
    addon.CDM.Resolve("Battle Shout")
    addon.Glow.Set(old, "battle-shout", true)

    old.spellID = 12345
    world:setCDMItems({ replacement, old })
    expectResolution(addon, "Battle Shout", replacement, "visible")

    H.equal(world.glowActive[old], false)
end

-- A lost viewer releases a previously active glow.
do
    local world, addon = setup()
    local item = world:newCDMItem(42, 6673, true)
    world:setCDMItems({ item })
    addon.CDM.Resolve("Battle Shout")
    addon.Glow.Set(item, "battle-shout", true)

    world.env.BuffIconCooldownViewer = nil
    expectResolution(addon, "Battle Shout", nil, "unavailable")

    H.equal(world.glowActive[item], false)
end

-- Configuration names support every safe ID source, including other ranks.
local function checkInfo(info)
    local world, addon = setup()
    local item = world:newCDMItem(42, 12345, true)
    item.info = info
    world:setCDMItems({ item })

    expectResolution(addon, "Battle Shout", item, "visible")
end

checkInfo({ spellID = 5242 })
checkInfo({ overrideSpellID = 5242 })
checkInfo({ overrideTooltipSpellID = 5242 })
checkInfo({ linkedSpellIDs = { 12345, 5242 } })

-- Texture and live aura identity cannot turn another configured spell into a match.
do
    local world, addon = setup()
    local item = world:newCDMItem(42, 12345, true)
    item.texture = 6673
    world:setCDMItems({ item })

    expectResolution(addon, "Battle Shout", nil, "not-configured")
    expectResolution(addon, nil, nil, "not-configured")
end

-- Unreadable or absent configuration identity cannot match.
do
    local world, addon = setup()
    local item = world:newCDMItem(nil, 6673, true)
    world:setCDMItems({ item })

    expectResolution(addon, "Battle Shout", nil, "not-configured")

    item.cooldownID = {}
    world.secret[item.cooldownID] = true
    expectResolution(addon, "Battle Shout", nil, "not-configured")

    item.cooldownID = 42
    item.spellID = {}
    world.secret[item.spellID] = true
    item.info = { spellID = item.spellID, linkedSpellIDs = { item.spellID } }
    expectResolution(addon, "Battle Shout", nil, "not-configured")

    world.secret[item.info] = true
    expectResolution(addon, "Battle Shout", nil, "not-configured")
end

-- Method and iteration errors are contained during changing layouts.
do
    local world, addon = setup()
    local item = world:newCDMItem(42, 6673, true)
    item.GetBaseSpellID = function() error("layout changed") end
    item.GetCooldownInfo = function() error("layout changed") end
    world:setCDMItems({ item })

    expectResolution(addon, "Battle Shout", nil, "not-configured")

    world.env.BuffIconCooldownViewer.itemFramePool.EnumerateActive = function()
        return function() error("pool changed") end
    end
    expectResolution(addon, "Battle Shout", nil, "unavailable")
end

-- Unprepared combat items use fallback and cannot create overlays or hooks.
do
    local world, addon = setup()
    local item = world:newCDMItem(42, 6673, true)
    world:setCDMItems({ item })
    world.combat = true

    addon.CDM.Prepare("Battle Shout")
    expectResolution(addon, "Battle Shout", nil, "unprepared")

    H.equal(#world.frames, 1)
    H.equal(item.hooks.OnHide, nil)
end

-- All active matching items, including hidden ones, are prepared out of combat.
do
    local world, addon = setup()
    local hidden = world:newCDMItem(42, 6673, false)
    local visible = world:newCDMItem(43, 5242, true)
    local other = world:newCDMItem(44, 12345, true)
    world:setCDMItems({ hidden, visible, other })

    addon.CDM.Prepare("Battle Shout")
    world.combat = true
    world:setCDMItems({ visible })
    expectResolution(addon, "Battle Shout", visible, "visible")

    H.equal(addon.Glow.IsPrepared(hidden), true)
    H.equal(addon.Glow.IsPrepared(other), false)

    addon.Glow.Set(hidden, "battle-shout", true)
    hidden:Hide()
    H.equal(world.glowActive[hidden], false)
end

-- A failed lifecycle hook cannot yield a usable target with stale glow risk.
do
    local world, addon = setup()
    local item = world:newCDMItem(42, 6673, true)
    item.HookScript = function() error("hook unavailable") end
    world:setCDMItems({ item })

    expectResolution(addon, "Battle Shout", nil, "unprepared")
end

print("cdm: PASS")
