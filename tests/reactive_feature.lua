local H = dofile("tests/helpers.lua")

local function setup(options)
    local world = H.new()
    world.time = 100
    world.stanceID = 17
    world.usable = { [7384] = true, [6572] = true }
    world.insufficientPower = {}
    world.overlay = { [7384] = false, [6572] = false }
    world.cooldowns = {
        [7384] = { startTime = 0, duration = 0, isActive = false, isEnabled = true },
        [6572] = { startTime = 0, duration = 0, isActive = false, isEnabled = true },
    }
    world.env.WarriorAssistForeverDB = {
        overpowerBar = 1, overpowerButton = 1,
        revengeBar = 1, revengeButton = 2,
    }
    world.overpowerButton = world:newFrame()
    world.revengeButton = world:newFrame()
    world.env.ActionButton1 = world.overpowerButton
    world.env.ActionButton2 = world.revengeButton
    world.env.GetShapeshiftFormID = function() return world.stanceID end
    world.env.Enum = {
        SpellBookSpellBank = { Player = 0 },
        SpellBookItemType = { Spell = 1 },
    }
    world.env.C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 4 } end,
        GetSpellBookItemInfo = function(index)
            return { itemType = 1, isPassive = false, isOffSpec = false,
                spellID = index == 1 and 7384 or (index == 2 and 6572 or
                    (index == 3 and 5308 or 402927)) }
        end,
    }
    world.env.C_Spell.GetSpellInfo = function(id)
        local names = { [7384] = "Overpower", [6572] = "Revenge",
            [5308] = "Execute", [402927] = "Victory Rush", [6673] = "Battle Shout" }
        return names[id] and { name = names[id] }
    end
    world.env.C_Spell.IsSpellUsable = function(id)
        return world.usable[id], world.insufficientPower[id] or false
    end
    world.env.C_Spell.IsSpellInRange = function(id, unit)
        H.equal(unit, "target", "Execute range checks the current target")
        return world.executeRange
    end
    world.env.C_Spell.GetSpellCooldown = function(id) return world.cooldowns[id] end
    world.env.C_SpellActivationOverlay = {
        IsSpellOverlayed = function(id) return world.overlay[id] end,
    }

    if options then options(world) end

    local addon = world:loadManifest()
    world:fire("PLAYER_LOGIN")
    assert(addon.ReactiveAbilities, "ReactiveAbilities must load")
    return world, addon
end

local function setupExecute()
    return setup(function(world)
        world.env.WarriorAssistForeverDB.executeBar = 1
        world.env.WarriorAssistForeverDB.executeButton = 3
        world.executeButton = world:newFrame()
        world.env.ActionButton3 = world.executeButton
        world.usable[5308] = true
        world.executeRange = true
    end)
end

local function setupVictoryRush()
    return setup(function(world)
        world.env.WarriorAssistForeverDB.victoryRushBar = 1
        world.env.WarriorAssistForeverDB.victoryRushButton = 4
        world.victoryRushButton = world:newFrame()
        world.env.ActionButton4 = world.victoryRushButton
        world.usable[402927] = true
        world.cooldowns[402927] = { startTime = 0, duration = 0,
            isActive = false, isEnabled = true }
    end)
end

local function reactiveEvent(world, event, ...)
    local frame = world.addon.ReactiveAbilities.frame
    assert(frame.events[event] == true, "event must be registered: " .. event)
    frame.scripts.OnEvent(frame, event, ...)
end

-- Victory Rush glows only in combat with true usability and a ready own cooldown.
do
    local world, addon = setupVictoryRush()

    H.equal(world.glowActive[world.victoryRushButton], false, "Victory Rush stays dark outside combat")

    world.combat = true
    reactiveEvent(world, "PLAYER_REGEN_DISABLED")
    H.equal(world.glowActive[world.victoryRushButton], true, "usable Victory Rush glows in Battle Stance")
    H.equal(world.glowActive[world.overpowerButton], true, "Victory Rush keeps its own button")

    world.stanceID = 18
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")
    H.equal(world.glowActive[world.victoryRushButton], true, "Victory Rush glows in Defensive Stance")

    world.stanceID = 19
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")
    H.equal(world.glowActive[world.victoryRushButton], true, "Victory Rush glows in Berserker Stance")

    world.usable[402927] = false
    world.insufficientPower[402927] = true
    reactiveEvent(world, "SPELL_UPDATE_USABLE")
    H.equal(world.glowActive[world.victoryRushButton], false, "low power is not a Victory Rush opportunity")

    world.usable[402927] = true
    world.insufficientPower[402927] = false
    world.cooldowns[402927] = { startTime = 100, duration = 30,
        isActive = true, isEnabled = true }
    reactiveEvent(world, "SPELL_UPDATE_COOLDOWN")
    H.equal(world.glowActive[world.victoryRushButton], false, "own cooldown blocks Victory Rush")

    world.cooldowns[402927] = { startTime = 100, duration = 1.5,
        isActive = true, isEnabled = true }
    world.cooldowns[61304] = { startTime = 100, duration = 1.5, isActive = true }
    reactiveEvent(world, "SPELL_UPDATE_COOLDOWN")
    H.equal(world.glowActive[world.victoryRushButton], true, "GCD alone does not hide Victory Rush")

    world.env.SlashCmdList.WARRIORASSISTFOREVER("")
    local diagnostics = table.concat(world.printed, "\n")
    assert(diagnostics:find("Victory Rush: learned / ready / usable / ready / bar 1 button 4 / glow active", 1, true))

    world.combat = false
    reactiveEvent(world, "PLAYER_REGEN_ENABLED")
    H.equal(world.glowActive[world.victoryRushButton], false, "leaving combat clears Victory Rush")

    addon.Config.Set("victoryRushEnabled", false)
    H.equal(world.glowActive[world.victoryRushButton], false, "disabling Victory Rush keeps it dark")
end

-- Execute has a separate selected button and uses the same opportunity in both permitted stances.
do
    local world, addon = setupExecute()

    H.equal(world.glowActive[world.executeButton], true, "Battle Execute glows when usable without combat")
    H.equal(world.glowActive[world.overpowerButton], true, "Execute does not replace Overpower")
    H.equal(addon.ReactiveAbilities:Status().execute.cooldown, "n/a")
    H.equal(addon.ReactiveAbilities:Status().execute.range, "in")

    world.env.SlashCmdList.WARRIORASSISTFOREVER("")
    local diagnostics = table.concat(world.printed, "\n")
    assert(diagnostics:find("Execute: learned / ready / usable / n/a / range in / bar 1 button 3 / glow active", 1, true))

    world.stanceID = 18
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")
    H.equal(world.glowActive[world.executeButton], false, "Defensive Stance suppresses Execute")

    world.stanceID = 19
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")
    H.equal(world.glowActive[world.executeButton], true, "Berserker Execute uses usability")

    world.usable[5308] = false
    world.insufficientPower[5308] = true
    reactiveEvent(world, "SPELL_UPDATE_USABLE")
    H.equal(world.glowActive[world.executeButton], true, "low rage does not hide Execute")

    world.insufficientPower[5308] = false
    reactiveEvent(world, "SPELL_UPDATE_USABLE")
    H.equal(world.glowActive[world.executeButton], false, "no Execute opportunity stays dark")

    world.usable[5308] = true
    world.cooldowns[5308] = { startTime = 100, duration = 2, isActive = true, isEnabled = true }
    reactiveEvent(world, "SPELL_UPDATE_COOLDOWN")
    H.equal(world.glowActive[world.executeButton], true, "Execute does not use cooldown readiness")

    addon.Config.Set("executeEnabled", false)
    H.equal(world.glowActive[world.executeButton], false, "disabling Execute clears its glow")
end

-- Out of combat, Execute needs a confirmed in-range target; combat keeps its opportunity glow.
do
    local world, addon = setupExecute()

    world.executeRange = false
    addon.ReactiveAbilities:Refresh()
    H.equal(world.glowActive[world.executeButton], false, "out-of-range target clears Execute glow")
    H.equal(addon.ReactiveAbilities:Status().execute.range, "out")

    world.executeRange = nil
    addon.ReactiveAbilities:Refresh()
    H.equal(world.glowActive[world.executeButton], false, "missing target stays dark outside combat")

    world.combat = true
    addon.ReactiveAbilities:Refresh()
    H.equal(world.glowActive[world.executeButton], true, "combat opportunity glows without a range result")
    H.equal(addon.ReactiveAbilities:Status().execute.range, "skipped")

    world.combat = false
    addon.ReactiveAbilities:Refresh()
    H.equal(world.glowActive[world.executeButton], false, "leaving combat reapplies the range requirement")

    world.executeRange = true
    addon.ReactiveAbilities:Refresh()
    H.equal(world.glowActive[world.executeButton], true, "in-range target restores Execute glow")
end

-- Resource shortage keeps a reactive opportunity visible in its permitted stance.
do
    local world, addon = setup()
    world.usable[7384] = false
    world.insufficientPower[7384] = true
    reactiveEvent(world, "SPELL_UPDATE_USABLE")

    H.equal(world.glowActive[world.overpowerButton], true, "Battle Overpower glows with low rage")
    H.equal(addon.ReactiveAbilities:Status().overpower.signal, "low-rage")

    world.env.SlashCmdList.WARRIORASSISTFOREVER("")
    local diagnostics = table.concat(world.printed, "\n")
    assert(diagnostics:find("Overpower: learned / ready / low-rage / ready / bar 1 button 1 / glow active", 1, true))

    world.stanceID = 18
    world.usable[6572] = false
    world.insufficientPower[6572] = true
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")

    H.equal(world.glowActive[world.overpowerButton], false)
    H.equal(world.glowActive[world.revengeButton], true, "Defensive Revenge glows with low rage")
    H.equal(addon.ReactiveAbilities:Status().revenge.signal, "low-rage")

    world.insufficientPower[6572] = false
    reactiveEvent(world, "SPELL_UPDATE_USABLE")
    H.equal(world.glowActive[world.revengeButton], false, "Revenge clears without a proc or rage shortage")
end

-- A global cooldown must not hide the currently available ability's glow.
do
    local world = setup(function(state)
        state.cooldowns[7384] = { startTime = 100.02, duration = 1.5, isActive = true, isEnabled = true }
        state.cooldowns[6572] = { startTime = 100.03, duration = 1.5, isActive = true, isEnabled = true }
        state.cooldowns[61304] = { startTime = 100, duration = 1.5, isActive = true }
        state.env.C_Spell.GetSpellCooldownDuration = function()
            return {
                HasSecretValues = function() return false end,
                IsZero = function() return true end,
            }
        end
    end)

    H.equal(world.glowActive[world.overpowerButton], true, "Battle Overpower glows during GCD")

    world.stanceID = 19
    world.overlay[7384] = true
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")
    H.equal(world.glowActive[world.overpowerButton], true, "Berserker Overpower glows during GCD")

    world.stanceID = 18
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")
    H.equal(world.glowActive[world.revengeButton], true, "Defensive Revenge glows during GCD")
end

-- The cooldown event supplies GCD evidence when timestamp and duration data are restricted.
do
    local world = setup(function(state)
        local hiddenTime = {}
        state.secret[hiddenTime] = true
        state.cooldowns[7384] = { startTime = hiddenTime, duration = hiddenTime,
            isActive = true, isEnabled = true, isOnGCD = true }
        state.cooldowns[6572] = { startTime = hiddenTime, duration = hiddenTime,
            isActive = true, isEnabled = true, isOnGCD = true }
        state.env.C_Spell.GetSpellCooldownDuration = function()
            return { HasSecretValues = function() return true end }
        end
    end)

    H.equal(world.glowActive[world.overpowerButton], true, "Overpower opportunity does not require GCD evidence")

    reactiveEvent(world, "SPELL_UPDATE_COOLDOWN")
    H.equal(world.glowActive[world.overpowerButton], true, "Battle Overpower persists after cooldown event")

    world.stanceID = 19
    world.overlay[7384] = true
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")
    H.equal(world.glowActive[world.overpowerButton], true, "Berserker Overpower follows overlay during cooldown")

    world.stanceID = 18
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")
    H.equal(world.glowActive[world.revengeButton], true, "Defensive Revenge uses event GCD evidence")

    world.cooldowns[7384].isOnGCD = false
    world.cooldowns[6572].isOnGCD = false
    reactiveEvent(world, "SPELL_UPDATE_COOLDOWN")
    H.equal(world.glowActive[world.revengeButton], false, "later cooldown event clears GCD evidence")

    world.cooldowns[6572].isOnGCD = true
    reactiveEvent(world, "SPELL_UPDATE_COOLDOWN")
    H.equal(world.glowActive[world.revengeButton], true, "a fresh event restores Revenge GCD evidence")

    world:tick(1.7)
    H.equal(world.glowActive[world.revengeButton], false, "Revenge glow expires without another event")
end

-- Diagnostics identify Berserker overlay evidence without exposing spell IDs.
do
    local world, addon = setup()
    world.stanceID = 19
    world.overlay[7384] = true
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")

    world.env.SlashCmdList.WARRIORASSISTFOREVER("")
    local result = table.concat(world.printed, "\n")
    assert(result:find("Stance: berserker", 1, true))
    assert(result:find("Overpower: learned / ready / overlay / ready / bar 1 button 1 / glow active", 1, true))
    assert(not result:find("7384", 1, true))
end

-- Unreadable readiness evidence stays bounded in diagnostics.
do
    local world, addon = setup()
    local restricted = setmetatable({}, { __index = function() error("restricted status") end })
    world.secret[restricted] = true
    addon.ReactiveAbilities.Status = function() return restricted end

    world.env.SlashCmdList.WARRIORASSISTFOREVER("")
    local result = table.concat(world.printed, "\n")
    assert(result:find("Stance: unknown", 1, true))
    assert(result:find("Overpower: learned / unknown / unknown / unknown / bar 1 button 1 / glow inactive", 1, true))
    assert(not result:find("restricted", 1, true))
end

do
    local world, addon = setup()
    H.equal(world.glowActive[world.overpowerButton], true, "Battle Overpower needs no combat or target")
    H.equal(world.glowActive[world.revengeButton], false)
    H.equal(addon.ReactiveAbilities:Status().stance, "battle")

    world.usable[7384] = false
    reactiveEvent(world, "SPELL_UPDATE_USABLE")
    H.equal(world.glowActive[world.overpowerButton], false)

    world.stanceID = 19
    world.overlay[7384] = true
    reactiveEvent(world, "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 7384)
    H.equal(world.glowActive[world.overpowerButton], true, "Berserker uses overlay")

    world.stanceID = 18
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")
    H.equal(world.glowActive[world.overpowerButton], false)
    H.equal(world.glowActive[world.revengeButton], true)

    world.stanceID = 19
    world.overlay[7384] = false
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")
    H.equal(world.glowActive[world.overpowerButton], false)
    H.equal(world.glowActive[world.revengeButton], false)

    world.stanceID = nil
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")
    H.equal(addon.ReactiveAbilities:Status().stance, "unknown")
    H.equal(world.glowActive[world.overpowerButton], false)
end

-- Spellbook changes remove and restore the learned Overpower opportunity.
do
    local world = setup()

    H.equal(world.glowActive[world.overpowerButton], true)

    world.env.C_SpellBook.GetSpellBookSkillLineInfo = function()
        return { itemIndexOffset = 0, numSpellBookItems = 1 }
    end
    world.env.C_SpellBook.GetSpellBookItemInfo = function()
        return { itemType = 1, isPassive = false, isOffSpec = false, spellID = 6572 }
    end

    reactiveEvent(world, "SPELLS_CHANGED")

    H.equal(world.glowActive[world.overpowerButton], false, "unlearned Overpower clears on spellbook event")

    world.env.C_SpellBook.GetSpellBookItemInfo = function()
        return { itemType = 1, isPassive = false, isOffSpec = false, spellID = 7384 }
    end

    reactiveEvent(world, "SPELLS_CHANGED")

    H.equal(world.glowActive[world.overpowerButton], true, "learned Overpower returns on spellbook event")
end

-- Overlay hide clears the active Berserker glow through the feature event frame.
do
    local world = setup()
    world.stanceID = 19
    world.overlay[7384] = true

    reactiveEvent(world, "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 7384)

    H.equal(world.glowActive[world.overpowerButton], true)

    world.overlay[7384] = false

    reactiveEvent(world, "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 7384)

    H.equal(world.glowActive[world.overpowerButton], false, "overlay hide clears Berserker glow")
end

do
    local world, addon = setup()
    world.cooldowns[7384] = { startTime = 100, duration = 2, isActive = true, isEnabled = true }
    reactiveEvent(world, "SPELL_UPDATE_COOLDOWN")
    H.equal(world.glowActive[world.overpowerButton], true, "Battle Overpower glows during own cooldown")
    H.equal(addon.ReactiveAbilities:Status().overpower.cooldown, "blocked")

    world.env.SlashCmdList.WARRIORASSISTFOREVER("")
    local diagnostics = table.concat(world.printed, "\n")
    assert(diagnostics:find("Overpower: learned / ready / usable / blocked / bar 1 button 1 / glow active", 1, true))

    world:tick(2.1)
    H.equal(world.glowActive[world.overpowerButton], true, "glow remains through cooldown expiry")

    world.overpowerButton:Hide()
    reactiveEvent(world, "ACTIONBAR_SLOT_CHANGED")
    H.equal(world.glowActive[world.overpowerButton], false)

    world.overpowerButton:Show()
    world.env.ActionButton1 = nil
    reactiveEvent(world, "ACTIONBAR_PAGE_CHANGED")
    H.equal(world.glowActive[world.overpowerButton], false)

    local replacement = world:newFrame()
    world.env.ActionButton1 = replacement
    reactiveEvent(world, "ACTIONBAR_SLOT_CHANGED")
    H.equal(world.glowActive[replacement], true)
    H.equal(world.glowActive[world.overpowerButton], false)

    addon.Config.Set("overpowerEnabled", false)
    H.equal(world.glowActive[replacement], false)
    addon.Config.Set("overpowerEnabled", true)
    H.equal(world.glowActive[replacement], true)

    reactiveEvent(world, "PLAYER_LEAVING_WORLD")
    H.equal(world.glowActive[replacement], false)
    world:tick(1)
    H.equal(world.glowActive[replacement], false)
    reactiveEvent(world, "PLAYER_ENTERING_WORLD")
    H.equal(world.glowActive[replacement], true)
end

do
    local world, addon = setup()
    world.secret[17] = true
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")
    H.equal(world.glowActive[world.overpowerButton], false)
    world.secret[17] = nil

    world.env.C_Spell.IsSpellUsable = function() error("restricted") end
    reactiveEvent(world, "SPELL_UPDATE_USABLE")
    H.equal(world.glowActive[world.overpowerButton], false)
    H.equal(addon.ReactiveAbilities:Status().overpower.signal, "unknown")

    world.env.C_Spell.IsSpellUsable = function(id) return world.usable[id] end
    reactiveEvent(world, "SPELL_UPDATE_USABLE")
    H.equal(world.glowActive[world.overpowerButton], true)

    local restrictedCooldown = {}
    world.secret[restrictedCooldown] = true
    world.cooldowns[7384] = restrictedCooldown
    reactiveEvent(world, "SPELL_UPDATE_COOLDOWN")
    H.equal(world.glowActive[world.overpowerButton], true, "unreadable cooldown does not hide Overpower opportunity")
end

do
    local world, addon = setup()
    world.overpowerButton.IsVisible = function() error("restricted") end
    reactiveEvent(world, "ACTIONBAR_SLOT_CHANGED")
    H.equal(world.glowActive[world.overpowerButton], false, "unreadable visibility clears glow")

    addon.Config.Set("overpowerEnabled", false)
    addon.Config.Set("revengeEnabled", false)
    H.equal(addon.ReactiveAbilities.frame.scripts.OnUpdate, nil, "disabled features stop polling")
end

do
    local world, addon = setup()
    addon.Config.Set("revengeButton", 1)
    world.stanceID = 18
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")
    H.equal(world.glowActive[world.overpowerButton], true, "shared button retains Revenge owner")
    addon.Config.Set("revengeEnabled", false)
    H.equal(world.glowActive[world.overpowerButton], false)

    world.combat = true
    local late = world:newFrame()
    world.env.ActionButton3 = late
    addon.Config.Set("overpowerButton", 3)
    world.stanceID = 17
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")
    H.equal(world.glowActive[late], nil, "unprepared combat button stays dark")
    H.equal(world.combatFrameCreations, 0)

    world.combat = false
    reactiveEvent(world, "PLAYER_REGEN_ENABLED")
    H.equal(world.glowActive[late], true)
    H.equal(addon.Glow.IsPrepared(late), true)
end

do
    local world, addon = setup()
    local item = world:newCDMItem(42, 6673, true)
    world:setCDMItems({ item })
    world:fire("COOLDOWN_VIEWER_DATA_LOADED")
    world.auras = { { name = "Battle Shout", expirationTime = 105 } }
    world.time = 100
    world.combat = true
    world:fire("PLAYER_REGEN_DISABLED")
    H.equal(world.glowActive[item], nil, "CDM receives no Battle Shout glow")
    H.equal(world.glowActive[addon.BattleShoutIcon.frame], true, "Battle Shout icon remains active")
    H.equal(world.glowActive[world.overpowerButton], true, "reactive owner remains active")
    H.equal(addon.BattleShoutReminder:Status().output, "icon-late")
end

-- Battle and Berserker Overpower keep independent native/custom choices.
do
    local world, addon = setup()
    local entry = addon.Glow.Prepare(world.overpowerButton)
    H.equal(world.glows[entry.frame].color, nil, "Battle defaults to native glow")

    addon.Config.Set("overpowerBattleNativeColor", false)
    addon.Config.Set("overpowerBattleGlowColor", "ff0000ff")
    H.equal(world.glows[entry.frame].color[3], 1, "Battle uses its blue custom glow")

    world.stanceID = 19
    world.overlay[7384] = true
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")
    H.equal(world.glows[entry.frame].color, nil, "Berserker remains native by default")

    addon.Config.Set("overpowerBerserkerNativeColor", false)
    addon.Config.Set("overpowerBerserkerGlowColor", "ffff0000")
    H.equal(world.glows[entry.frame].color[1], 1, "Berserker uses its red custom glow")

    world.stanceID = 17
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")
    H.equal(world.glows[entry.frame].color[3], 1, "Battle color returns on stance change")
end

-- Revenge can switch between its own custom color and native artwork.
do
    local world, addon = setup()
    world.stanceID = 18
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")
    local entry = addon.Glow.Prepare(world.revengeButton)
    H.equal(world.glows[entry.frame].color, nil, "Revenge defaults to native glow")

    addon.Config.Set("revengeNativeColor", false)
    addon.Config.Set("revengeGlowColor", "ffff0000")
    H.equal(world.glows[entry.frame].color[1], 1, "Revenge uses custom red")

    addon.Config.Set("revengeNativeColor", true)
    H.equal(world.glows[entry.frame].color, nil, "Revenge restores native glow")
end

-- Execute keeps one native or custom color across Battle and Berserker Stance.
do
    local world, addon = setupExecute()
    local entry = addon.Glow.Prepare(world.executeButton)
    H.equal(world.glows[entry.frame].color, nil, "Execute defaults to native glow")

    addon.Config.Set("executeNativeColor", false)
    addon.Config.Set("executeGlowColor", "ff0000ff")
    H.equal(world.glows[entry.frame].color[3], 1, "Battle Execute uses the custom color")

    world.stanceID = 19
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")
    H.equal(world.glows[entry.frame].color[3], 1, "Berserker Execute keeps the same custom color")

    addon.Config.Set("executeNativeColor", true)
    H.equal(world.glows[entry.frame].color, nil, "Execute restores native glow")
end

-- Victory Rush uses one configurable glow color in every stance.
do
    local world, addon = setupVictoryRush()
    world.combat = true
    reactiveEvent(world, "PLAYER_REGEN_DISABLED")

    local entry = addon.Glow.Prepare(world.victoryRushButton)
    H.equal(world.glows[entry.frame].color, nil, "Victory Rush defaults to native glow")

    addon.Config.Set("victoryRushNativeColor", false)
    addon.Config.Set("victoryRushGlowColor", "ff0000ff")
    H.equal(world.glows[entry.frame].color[3], 1, "Victory Rush uses its custom blue")

    world.stanceID = 18
    reactiveEvent(world, "UPDATE_SHAPESHIFT_FORM")
    H.equal(world.glows[entry.frame].color[3], 1, "Defensive Stance keeps Victory Rush color")

    addon.Config.Set("victoryRushNativeColor", true)
    H.equal(world.glows[entry.frame].color, nil, "Victory Rush restores native glow")
end

print("reactive feature: PASS")
