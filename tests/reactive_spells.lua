local H = dofile("tests/helpers.lua")

local function setup(learned)
    local world = H.new()
    world.learned = learned or { 7384, 6572 }
    world.usable = {}
    world.overlay = {}
    world.cooldowns = {}
    world.names = { [7384] = "Frappe dominante", [6572] = "Revanche", [11584] = "Frappe dominante" }
    world.time = 100
    world.env.Enum = {
        SpellBookSpellBank = { Player = 0 },
        SpellBookItemType = { Spell = 1 },
    }
    world.env.C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function()
            return { itemIndexOffset = 0, numSpellBookItems = #world.learned }
        end,
        GetSpellBookItemInfo = function(index)
            return { itemType = 1, isPassive = false, isOffSpec = false, spellID = world.learned[index] }
        end,
    }
    world.env.C_Spell.GetSpellInfo = function(id)
        return world.names[id] and { name = world.names[id] }
    end
    world.env.C_Spell.IsSpellUsable = function(id) return world.usable[id] end
    world.env.C_Spell.GetSpellCooldown = function(id) return world.cooldowns[id] end
    world.env.C_SpellActivationOverlay = {
        IsSpellOverlayed = function(id) return world.overlay[id] end,
    }

    local addon = world:load({ "Core", "Services/Client", "Services/ReactiveSpells" })
    addon.ReactiveSpells.Rebuild()

    return world, addon.ReactiveSpells
end

local world, spells = setup()
world.usable[7384] = true
world.cooldowns[7384] = { startTime = 0, duration = 0, isActive = false, isEnabled = true }

local status = spells.Evaluate("overpower", "usable", false)
H.equal(status.ready, true, "readable usability permits learned Overpower")
H.equal(status.id, 7384)
H.equal(status.signal, "usable")
H.equal(status.cooldown, "ready")

world.usable[7384] = false
status = spells.Evaluate("overpower", "usable", false)
H.equal(status.ready, false, "false usability clears readiness")
H.equal(status.signal, "inactive")

world.usable[7384] = true
world.cooldowns[7384] = { startTime = 95, duration = 10, isActive = true, isEnabled = true }
status = spells.Evaluate("overpower", "usable", false)
H.equal(status.ready, false, "own cooldown blocks")
H.equal(status.cooldown, "blocked")

world.time = 106
status = spells.Evaluate("overpower", "usable", false)
H.equal(status.ready, true, "expired own cooldown permits")

local higherWorld, higher = setup({ 11584, 11584 })
higherWorld.usable[11584] = true
higherWorld.cooldowns[11584] = { startTime = 0, duration = 0, isActive = false }
higherWorld.overlay[7384] = true
higherWorld.usable[7384] = false

H.equal(#higher.ids.overpower, 1, "duplicate ranks are removed")
status = higher.Evaluate("overpower", "overlay", false)
H.equal(status.ready, true, "base overlay works with learned higher rank")
H.equal(status.id, 11584)
H.equal(status.signal, "overlay")

higherWorld.overlay[7384] = false
higherWorld.overlay[11584] = false
status = higher.Evaluate("overpower", "overlay", false)
H.equal(status.ready, false, "false overlay clears readiness")
H.equal(status.signal, "inactive")

higherWorld.overlay[11584] = true
higherWorld.usable[11584] = false
status = higher.Evaluate("overpower", "overlay", false)
H.equal(status.ready, true, "overlay does not require castability")

local absentWorld, absent = setup({ 6572 })
absentWorld.overlay[7384] = true
status = absent.Evaluate("overpower", "overlay", false)
H.equal(status.learned, false, "seed overlay cannot create an unlearned spell")
H.equal(status.ready, false)
H.equal(status.id, nil)

local gcdWorld, gcd = setup({ 6572 })
gcdWorld.usable[6572] = true
gcdWorld.cooldowns[6572] = { startTime = 100, duration = 1.5, isActive = true }
gcdWorld.cooldowns[61304] = { startTime = 100, duration = 1.5, isActive = true }
status = gcd.Evaluate("revenge", "usable", true)
H.equal(status.ready, true, "matching global cooldown is not own cooldown")

gcdWorld.cooldowns[6572] = { isOnGCD = true, startTime = 100, duration = 1.5 }
gcdWorld.cooldowns[61304] = nil
status = gcd.Evaluate("revenge", "usable", true)
H.equal(status.ready, true, "explicit GCD flag permits")

gcdWorld.cooldowns[6572] = { isOnGCD = gcdWorld.secret, startTime = gcdWorld.secret, duration = gcdWorld.secret }
status = gcd.Evaluate("revenge", "usable", true)
H.equal(status.ready, false, "unreadable cooldown event clears GCD evidence")
H.equal(status.cooldown, "unknown")

gcdWorld.env.C_Spell.IsSpellUsable = function() error("restricted") end
status = gcd.Evaluate("revenge", "usable", false)
H.equal(status.ready, false, "throwing usability clears signal")
H.equal(status.signal, "unknown")

status = gcd.Evaluate("invalid", "overlay", false)
H.equal(status.ready, false)
H.equal(status.signal, "unknown")

local secretKind = "restricted kind"
gcdWorld.secret[secretKind] = true
status = gcd.Evaluate(secretKind, "usable", false)
H.equal(status.ready, false, "restricted kind is rejected")
H.equal(status.signal, "unknown")

print("reactive spells: PASS")
