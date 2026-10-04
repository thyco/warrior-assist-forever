local H = dofile("tests/helpers.lua")
local count = 0
local function test(name, run)
    run()
    count = count + 1
    print("PASS: " .. name)
end

local function setup()
    local world = H.new()
    local addon = world:load({ "Core", "Services/Client", "Services/Timers", "Services/BattleShoutAura" })
    addon.BattleShoutAura.Initialize()

    return world, addon.BattleShoutAura
end

local function buff(world, expiration)
    world.auras = { { name = "Battle Shout", spellId = 2048, sourceUnit = "party1",
        auraInstanceID = 7, expirationTime = expiration, isHelpful = true } }
end

test("other caster rank uses exact expiration", function()
    local world, aura = setup()
    buff(world, 180)

    local status = aura.Refresh({ addedAuras = world.auras })

    H.equal(status.state, "present")
    H.equal(status.deadline, 180)
    H.equal(status.quality, "exact")
end)

test("readable complete absence is missing", function()
    local _, aura = setup()

    local status = aura.Refresh()

    H.equal(status.state, "missing")
    H.equal(status.quality, "none")
end)

test("secret unrelated name prevents absence", function()
    local world, aura = setup()
    world.secret[world.secret] = true
    world.auras = { { name = world.secret } }

    H.equal(aura.Refresh().state, "unknown")
end)

test("failed enumeration prevents absence", function()
    local world, aura = setup()
    world.enumerationError = true

    H.equal(aura.Refresh().state, "unknown")
end)

test("party2 localized rank is accepted", function()
    local world, aura = setup()
    world.spellName = "Schlachtruf"
    world.auras = { { name = "Schlachtruf", sourceUnit = "party2", spellId = 999, expirationTime = 250 } }
    aura.Initialize()

    H.equal(aura.Refresh().deadline, 250)
end)

test("same instance refresh restarts estimate", function()
    local world, aura = setup()
    buff(world, 180)
    aura.Refresh()
    world.secret[world.secret] = true
    world.auras[1].expirationTime = world.secret
    world.time = 30

    local status = aura.Refresh({ updatedAuraInstanceIDs = { 7 } })

    H.equal(status.deadline, 210)
    H.equal(status.quality, "estimated")
    world.time = 60

    H.equal(aura.Refresh({ updatedAuraInstanceIDs = { 7 } }).deadline, 240)
end)

test("login unreadable expiration has no invented deadline", function()
    local world, aura = setup()
    buff(world, nil)

    H.equal(aura.Refresh().deadline, nil)
    H.equal(aura.Status().state, "present")
    H.equal(aura.Status().quality, "none")
end)

test("restricted query retains prior deadline as estimated", function()
    local world, aura = setup()
    buff(world, 180)
    aura.Refresh()
    world.auraError = true

    local status = aura.Refresh()

    H.equal(status.state, "unknown")
    H.equal(status.deadline, 180)
    H.equal(status.quality, "estimated")
end)

test("restricted query clears previous missing state", function()
    local world, aura = setup()
    aura.Refresh()
    world.auraError = true

    H.equal(aura.Refresh().state, "unknown")
    H.equal(aura.Status().deadline, nil)
end)

test("matching added aura starts estimate", function()
    local world, aura = setup()
    buff(world, 0)
    world.time = 10

    H.equal(aura.Refresh({ addedAuras = world.auras }).deadline, 190)
end)

test("missing to present starts estimate", function()
    local world, aura = setup()
    aura.Refresh()
    buff(world, nil)
    world.time = 40

    H.equal(aura.Refresh().deadline, 220)
end)

test("changed known instance starts estimate", function()
    local world, aura = setup()
    buff(world, nil)
    aura.Refresh()
    world.auras[1].auraInstanceID = 8
    world.time = 50

    H.equal(aura.Refresh().deadline, 230)
end)

test("unrelated update does not start estimate", function()
    local world, aura = setup()
    buff(world, nil)
    aura.Refresh()

    H.equal(aura.Refresh({ updatedAuraInstanceIDs = { 99 } }).deadline, nil)
end)

test("confirmed removal clears deadline", function()
    local world, aura = setup()
    buff(world, 180)
    aura.Refresh()
    world.auras = {}

    H.equal(aura.Refresh().state, "missing")
    H.equal(aura.Status().deadline, nil)
end)

test("known aura removal clears timing when combat lookup is restricted", function()
    local world, aura = setup()
    buff(world, 180)
    aura.Refresh()
    world.auraError = true

    local status = aura.Refresh({ removedAuraInstanceIDs = { 7 } })

    H.equal(status.state, "unknown")
    H.equal(status.deadline, nil)
    H.equal(status.quality, "none")
end)

test("harmful same-name aura event does not confirm Battle Shout", function()
    local world, aura = setup()
    world.auraError = true

    local status = aura.Refresh({ addedAuras = {
        { name = "Battle Shout", isHelpful = false, expirationTime = 180 },
    } })

    H.equal(status.state, "unknown")
    H.equal(status.deadline, nil)
end)

test("cast fallback invalidates an old aura instance", function()
    local world, aura = setup()
    buff(world, 180)
    aura.Refresh()
    world.time = 170
    world.auraError = true

    H.equal(aura.ObservePlayerCast(2048), true)
    H.equal(aura.Status().state, "unknown")
    H.equal(aura.Status().deadline, 350)

    local status = aura.Refresh({ removedAuraInstanceIDs = { 7 } })

    H.equal(status.state, "unknown")
    H.equal(status.deadline, 350)
end)

test("aura event before cast keeps exact timing", function()
    local world, aura = setup()
    world.time = 170
    buff(world, 350)
    aura.Refresh({ addedAuras = world.auras })
    world.time = 171
    world.auraError = true

    H.equal(aura.ObservePlayerCast(2048), true)
    H.equal(aura.Status().state, "present")
    H.equal(aura.Status().deadline, 350)
    H.equal(aura.Status().quality, "exact")
end)

test("secret enumeration table is unknown", function()
    local world, aura = setup()
    world.secret[world.auras] = true

    H.equal(aura.Refresh().state, "unknown")
end)

test("secret entry is unknown", function()
    local world, aura = setup()
    world.auras = { {} }
    world.secret[world.auras[1]] = true

    H.equal(aura.Refresh().state, "unknown")
end)

test("direct presence survives failed enumeration", function()
    local world, aura = setup()
    buff(world, 180)
    world.enumerationError = true

    H.equal(aura.Refresh().state, "present")
end)

test("enumeration presence survives failed direct lookup", function()
    local world, aura = setup()
    buff(world, 180)
    world.directError = true

    H.equal(aura.Refresh().deadline, 180)
end)

test("past expiration gets estimate on application", function()
    local world, aura = setup()
    buff(world, 10)
    world.time = 20

    H.equal(aura.Refresh({ addedAuras = world.auras }).deadline, 200)
end)

test("nonfinite expiration gets estimate on application", function()
    local world, aura = setup()
    buff(world, math.huge)

    H.equal(aura.Refresh({ addedAuras = world.auras }).deadline, 180)
end)

test("secret instance and update payload stay safe", function()
    local world, aura = setup()
    buff(world, nil)
    world.secret[world.secret] = true
    world.auras[1].auraInstanceID = world.secret

    H.equal(aura.Refresh(world.secret).deadline, nil)
    H.equal(aura.Refresh({ updatedAuraInstanceIDs = { world.secret } }).deadline, nil)
end)

test("timed enumeration takes priority over untimed direct presence", function()
    local world, aura = setup()
    buff(world, 250)
    world.directResult = { name = "Battle Shout", auraInstanceID = 7 }

    local status = aura.Refresh()

    H.equal(status.state, "present")
    H.equal(status.deadline, 250)
    H.equal(status.quality, "exact")
end)

print("aura: PASS (" .. count .. " tests)")
