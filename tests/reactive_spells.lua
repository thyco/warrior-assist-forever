local H = dofile("tests/helpers.lua")

local function setup(learned)
    local world = H.new()
    world.learned = learned or { 7384, 6572 }
    world.usable = {}
    world.insufficientPower = {}
    world.range = { [20658] = true }
    world.overlay = {}
    world.cooldowns = {}
    world.names = { [7384] = "Frappe dominante", [6572] = "Revanche",
        [11584] = "Frappe dominante", [5308] = "Exécution", [20658] = "Exécution" }
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
    world.env.C_Spell.IsSpellUsable = function(id)
        return world.usable[id], world.insufficientPower[id] or false
    end
    world.env.C_Spell.IsSpellInRange = function(id, unit)
        H.equal(unit, "target", "Execute range checks the current target")
        if world.rangeError then error("restricted range") end
        return world.range[id]
    end
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

local status = spells.Evaluate("overpower", "usable")
H.equal(status.ready, true, "readable usability permits learned Overpower")
H.equal(status.id, 7384)
H.equal(status.signal, "usable")
H.equal(status.cooldown, "ready")

local executeWorld, executeSpells = setup({ 20658 })
executeWorld.usable[20658] = true
executeWorld.cooldowns[20658] = { startTime = 95, duration = 10, isActive = true, isEnabled = true }

status = executeSpells.Evaluate("execute", "usable")
H.equal(status.learned, true, "localized higher Execute rank is learned")
H.equal(status.id, 20658)
H.equal(status.ready, true, "Execute usability drives its opportunity without a cooldown gate")
H.equal(status.signal, "usable")
H.equal(status.cooldown, "n/a")
H.equal(status.range, "in")

executeWorld.range[20658] = false
status = executeSpells.Evaluate("execute", "usable")
H.equal(status.ready, false, "out-of-combat Execute stays dark out of range")
H.equal(status.range, "out")

executeWorld.combat = true
status = executeSpells.Evaluate("execute", "usable")
H.equal(status.ready, true, "combat Execute ignores range")
H.equal(status.range, "skipped")

executeWorld.combat = false
executeWorld.range[20658] = nil
status = executeSpells.Evaluate("execute", "usable")
H.equal(status.ready, false, "no target or unreadable range hides Execute out of combat")
H.equal(status.range, "unknown")

local secretRange = {}
executeWorld.secret[secretRange] = true
executeWorld.range[20658] = secretRange
status = executeSpells.Evaluate("execute", "usable")
H.equal(status.ready, false, "secret range cannot enable an out-of-combat Execute glow")
H.equal(status.range, "unknown")

executeWorld.rangeError = true
status = executeSpells.Evaluate("execute", "usable")
H.equal(status.ready, false, "range API errors cannot enable out-of-combat Execute")
H.equal(status.range, "unknown")

executeWorld.rangeError = false
executeWorld.range[20658] = true

executeWorld.usable[20658] = false
executeWorld.insufficientPower[20658] = true
status = executeSpells.Evaluate("execute", "usable")
H.equal(status.ready, true, "low rage does not hide an Execute opportunity")
H.equal(status.signal, "low-rage")

executeWorld.range[20658] = false
status = executeSpells.Evaluate("execute", "usable")
H.equal(status.ready, false, "low rage does not bypass Execute range out of combat")

executeWorld.range[20658] = true

executeWorld.insufficientPower[20658] = false
status = executeSpells.Evaluate("execute", "usable")
H.equal(status.ready, false, "Execute stays dark when the client reports another unusable reason")
H.equal(status.signal, "inactive")

local unlearnedExecuteWorld, unlearnedExecute = setup({ 6572 })
unlearnedExecuteWorld.usable[5308] = true
status = unlearnedExecute.Evaluate("execute", "usable")
H.equal(status.learned, false)
H.equal(status.ready, false, "unlearned Execute cannot glow")

local rageWorld, rageSpells = setup()
rageWorld.usable[7384] = false
rageWorld.usable[6572] = false
rageWorld.insufficientPower[7384] = true
rageWorld.insufficientPower[6572] = true
rageWorld.cooldowns[7384] = { startTime = 0, duration = 0, isActive = false, isEnabled = true }
rageWorld.cooldowns[6572] = { startTime = 0, duration = 0, isActive = false, isEnabled = true }

status = rageSpells.Evaluate("overpower", "usable")
H.equal(status.ready, true, "Overpower opportunity remains active with insufficient rage")
H.equal(status.signal, "low-rage")

status = rageSpells.Evaluate("revenge", "usable")
H.equal(status.ready, true, "Revenge opportunity remains active with insufficient rage")
H.equal(status.signal, "low-rage")

rageWorld.cooldowns[6572] = { startTime = 95, duration = 10, isActive = true, isEnabled = true }
status = rageSpells.Evaluate("revenge", "usable")
H.equal(status.ready, false, "insufficient rage does not bypass Revenge's own cooldown")

rageWorld.insufficientPower[7384] = false
status = rageSpells.Evaluate("overpower", "usable")
H.equal(status.ready, false, "a missing Overpower proc stays inactive when rage is sufficient")

local hiddenPower = {}
rageWorld.secret[hiddenPower] = true
rageWorld.insufficientPower[7384] = hiddenPower
status = rageSpells.Evaluate("overpower", "usable")
H.equal(status.ready, false, "restricted power reason cannot invent an Overpower proc")
H.equal(status.signal, "unknown")

world.usable[7384] = false
status = spells.Evaluate("overpower", "usable")
H.equal(status.ready, false, "false usability clears readiness")
H.equal(status.signal, "inactive")

world.usable[7384] = true
world.cooldowns[7384] = { startTime = 95, duration = 10, isActive = true, isEnabled = true }
status = spells.Evaluate("overpower", "usable")
H.equal(status.ready, true, "Battle Overpower opportunity glows during its own cooldown")
H.equal(status.cooldown, "blocked")

world.usable[7384] = false
status = spells.Evaluate("overpower", "usable")
H.equal(status.ready, false, "own cooldown does not invent an Overpower opportunity")

world.usable[7384] = true
world.time = 106
status = spells.Evaluate("overpower", "usable")
H.equal(status.ready, true, "expired own cooldown permits")

local higherWorld, higher = setup({ 11584, 11584 })
higherWorld.usable[11584] = true
higherWorld.cooldowns[11584] = { startTime = 0, duration = 0, isActive = false }
higherWorld.overlay[7384] = true
higherWorld.usable[7384] = false

H.equal(#higher.ids.overpower, 1, "duplicate ranks are removed")
status = higher.Evaluate("overpower", "overlay")
H.equal(status.ready, true, "base overlay works with learned higher rank")
H.equal(status.id, 11584)
H.equal(status.signal, "overlay")

higherWorld.overlay[7384] = false
higherWorld.overlay[11584] = false
status = higher.Evaluate("overpower", "overlay")
H.equal(status.ready, false, "false overlay clears readiness")
H.equal(status.signal, "inactive")

higherWorld.overlay[11584] = true
higherWorld.usable[11584] = false
status = higher.Evaluate("overpower", "overlay")
H.equal(status.ready, true, "overlay does not require castability")

higherWorld.cooldowns[11584] = { startTime = 95, duration = 10, isActive = true, isEnabled = true }
status = higher.Evaluate("overpower", "overlay")
H.equal(status.ready, true, "Berserker Overpower overlay glows during its own cooldown")
H.equal(status.cooldown, "blocked")

local absentWorld, absent = setup({ 6572 })
absentWorld.overlay[7384] = true
status = absent.Evaluate("overpower", "overlay")
H.equal(status.learned, false, "seed overlay cannot create an unlearned spell")
H.equal(status.ready, false)
H.equal(status.id, nil)

local gcdWorld, gcd = setup({ 6572 })
gcdWorld.usable[6572] = true
gcdWorld.cooldowns[6572] = { startTime = 100, duration = 1.5, isActive = true }
gcdWorld.cooldowns[61304] = { startTime = 100, duration = 1.5, isActive = true }
status = gcd.Evaluate("revenge", "usable")
H.equal(status.ready, true, "matching global cooldown is not own cooldown")

gcdWorld.cooldowns[6572] = { isOnGCD = true, startTime = 100, duration = 1.5 }
gcdWorld.cooldowns[61304] = nil
status = gcd.Evaluate("revenge", "usable")
H.equal(status.ready, false, "GCD flag outside cooldown event cannot bypass own cooldown")
H.equal(status.cooldown, "blocked")

gcdWorld.cooldowns[6572] = { isOnGCD = gcdWorld.secret, startTime = gcdWorld.secret, duration = gcdWorld.secret }
status = gcd.Evaluate("revenge", "usable")
H.equal(status.ready, false, "unreadable cooldown evidence clears GCD readiness")
H.equal(status.cooldown, "unknown")

local durationWorld, durationSpells = setup()
durationWorld.usable[7384] = true
durationWorld.usable[6572] = true
durationWorld.cooldowns[7384] = { startTime = 100.02, duration = 1.5, isActive = true, isEnabled = true }
durationWorld.cooldowns[6572] = { startTime = 100.03, duration = 1.5, isActive = true, isEnabled = true }
durationWorld.cooldowns[61304] = { startTime = 100, duration = 1.5, isActive = true }

local ownCooldown = { [7384] = false, [6572] = false }
local restrictedDuration = false
durationWorld.env.C_Spell.GetSpellCooldownDuration = function(id, ignoreGCD)
    H.equal(ignoreGCD, true, "own cooldown query excludes the GCD")

    return {
        HasSecretValues = function() return restrictedDuration end,
        IsZero = function() return not ownCooldown[id] end,
        HasExpired = function() return false end,
    }
end

status = durationSpells.Evaluate("overpower", "usable")
H.equal(status.ready, true, "Overpower stays ready during a GCD with differing timestamps")

status = durationSpells.Evaluate("revenge", "usable")
H.equal(status.ready, true, "Revenge stays ready during a GCD with differing timestamps")

ownCooldown[7384] = true
status = durationSpells.Evaluate("overpower", "usable")
H.equal(status.ready, true, "Overpower opportunity ignores readable own cooldown")
H.equal(status.cooldown, "blocked")

ownCooldown[6572] = true
status = durationSpells.Evaluate("revenge", "usable")
H.equal(status.ready, false, "Revenge's own cooldown still blocks")
H.equal(status.cooldown, "blocked")

restrictedDuration = true
ownCooldown[6572] = false
status = durationSpells.Evaluate("revenge", "usable")
H.equal(status.ready, false, "restricted cooldown duration cannot light Revenge")
H.equal(status.cooldown, "unknown")

durationWorld.cooldowns[7384] = { startTime = 0, duration = 0, isActive = false, isEnabled = true }
status = durationSpells.Evaluate("overpower", "usable")
H.equal(status.ready, true, "inactive native cooldown remains ready when duration object is restricted")
H.equal(status.cooldown, "ready")

local hunterWorld, hunterStyle = setup()
local hiddenCooldown = {}
hunterWorld.secret[hiddenCooldown] = true
hunterWorld.usable[7384] = true
hunterWorld.usable[6572] = true
hunterWorld.cooldowns[7384] = { startTime = hiddenCooldown, duration = hiddenCooldown,
    isActive = true, isEnabled = true, isOnGCD = true }
hunterWorld.cooldowns[6572] = { startTime = hiddenCooldown, duration = hiddenCooldown,
    isActive = true, isEnabled = true, isOnGCD = true }
hunterWorld.env.C_Spell.GetSpellCooldownDuration = function()
    return { HasSecretValues = function() return true end }
end

hunterStyle.ObserveCooldownEvent()
status = hunterStyle.Evaluate("overpower", "usable")
H.equal(status.ready, true, "Overpower trusts its event GCD flag without a separate GCD status")

status = hunterStyle.Evaluate("revenge", "usable")
H.equal(status.ready, true, "Revenge trusts its event GCD flag without a separate GCD status")

hunterWorld.time = 102
status = hunterStyle.Evaluate("overpower", "usable")
H.equal(status.ready, true, "Overpower opportunity persists with unknown cooldown timing")
H.equal(status.cooldown, "unknown")

status = hunterStyle.Evaluate("revenge", "usable")
H.equal(status.ready, false, "cached Revenge GCD evidence expires without another event")

local eventWorld, eventSpells = setup({ 6572 })
local hiddenTime = {}
eventWorld.secret[hiddenTime] = true
eventWorld.usable[6572] = true
eventWorld.cooldowns[6572] = { startTime = hiddenTime, duration = hiddenTime,
    isActive = true, isEnabled = true, isOnGCD = true }
eventWorld.cooldowns[61304] = { startTime = hiddenTime, duration = hiddenTime,
    isActive = true }
eventWorld.env.C_Spell.GetSpellCooldownDuration = function()
    return { HasSecretValues = function() return true end }
end

status = eventSpells.Evaluate("revenge", "usable")
H.equal(status.ready, false, "GCD flag is not trusted outside its cooldown event")

eventSpells.ObserveCooldownEvent()
status = eventSpells.Evaluate("revenge", "usable")
H.equal(status.ready, true, "event-confirmed GCD keeps Revenge ready with restricted timing")

eventWorld.env.C_Spell.GetSpellCooldownDuration = function()
    return {
        HasSecretValues = function() return false end,
        IsZero = function() return false end,
        HasExpired = function() return false end,
    }
end
status = eventSpells.Evaluate("revenge", "usable")
H.equal(status.ready, false, "readable own cooldown blocks despite event GCD evidence")

eventWorld.env.C_Spell.GetSpellCooldownDuration = function()
    return { HasSecretValues = function() return true end }
end
status = eventSpells.Evaluate("revenge", "usable")
H.equal(status.ready, false, "confirmed own cooldown clears earlier GCD evidence")

eventWorld.cooldowns[61304].isActive = false
eventWorld.cooldowns[6572].isOnGCD = false
eventSpells.ObserveCooldownEvent()
status = eventSpells.Evaluate("revenge", "usable")
H.equal(status.ready, false, "cooldown event without GCD flag clears readiness")

eventWorld.cooldowns[61304].isActive = true
status = eventSpells.Evaluate("revenge", "usable")
H.equal(status.ready, false, "a later GCD cannot reuse earlier event evidence")

eventWorld.cooldowns[61304].startTime = 100
eventWorld.cooldowns[6572].isOnGCD = true
eventSpells.ObserveCooldownEvent()
status = eventSpells.Evaluate("revenge", "usable")
H.equal(status.ready, true, "a new cooldown event can establish fresh GCD evidence")

gcdWorld.env.C_Spell.IsSpellUsable = function() error("restricted") end
status = gcd.Evaluate("revenge", "usable")
H.equal(status.ready, false, "throwing usability clears signal")
H.equal(status.signal, "unknown")

status = gcd.Evaluate("invalid", "overlay")
H.equal(status.ready, false)
H.equal(status.signal, "unknown")

local secretKind = "restricted kind"
gcdWorld.secret[secretKind] = true
status = gcd.Evaluate(secretKind, "usable")
H.equal(status.ready, false, "restricted kind is rejected")
H.equal(status.signal, "unknown")

print("reactive spells: PASS")
