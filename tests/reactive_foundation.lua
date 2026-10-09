local H = dofile("tests/helpers.lua")

local function load(world)
    return world:load({ "Core", "Services/Config", "Services/Client", "Services/Buttons", "Services/Stance" })
end

local world = H.new()
local addon = load(world)

addon.Config.Initialize()

H.equal(addon.Config.Get("overpowerEnabled"), true)
H.equal(addon.Config.Get("overpowerBar"), 0)
H.equal(addon.Config.Get("overpowerButton"), 1)
H.equal(addon.Config.Get("revengeEnabled"), true)
H.equal(addon.Config.Get("revengeBar"), 0)
H.equal(addon.Config.Get("revengeButton"), 1)
H.equal(addon.Config.Get("executeEnabled"), true)
H.equal(addon.Config.Get("executeBar"), 0)
H.equal(addon.Config.Get("executeButton"), 1)
H.equal(addon.Config.Get("executeNativeColor"), true)
H.equal(addon.Config.Get("executeGlowColor"), "ffffd24a")
H.equal(addon.Config.Get("victoryRushEnabled"), true)
H.equal(addon.Config.Get("victoryRushCombatOnly"), true)
H.equal(addon.Config.Get("victoryRushBar"), 0)
H.equal(addon.Config.Get("victoryRushButton"), 1)
H.equal(addon.Config.Get("victoryRushNativeColor"), true)
H.equal(addon.Config.Get("victoryRushGlowColor"), "ffffd24a")
H.equal(addon.Config.Get("battleShoutEnabled"), true)

local saved = H.new()
saved.env.WarriorAssistForeverDB = {
    overpowerEnabled = false,
    overpowerBar = 8,
    overpowerButton = 12,
    revengeEnabled = false,
    revengeBar = 1,
    revengeButton = 3,
    executeEnabled = false,
    executeBar = 2,
    executeButton = 6,
    executeNativeColor = false,
    executeGlowColor = "ff112233",
    victoryRushEnabled = false,
    victoryRushCombatOnly = false,
    victoryRushBar = 4,
    victoryRushButton = 8,
    victoryRushNativeColor = false,
    victoryRushGlowColor = "ff112233",
}
local savedAddon = load(saved)

savedAddon.Config.Initialize()

H.equal(savedAddon.Config.Get("overpowerEnabled"), false)
H.equal(savedAddon.Config.Get("overpowerBar"), 8)
H.equal(savedAddon.Config.Get("overpowerButton"), 12)
H.equal(savedAddon.Config.Get("revengeEnabled"), false)
H.equal(savedAddon.Config.Get("revengeBar"), 1)
H.equal(savedAddon.Config.Get("revengeButton"), 3)
H.equal(savedAddon.Config.Get("executeEnabled"), false)
H.equal(savedAddon.Config.Get("executeBar"), 2)
H.equal(savedAddon.Config.Get("executeButton"), 6)
H.equal(savedAddon.Config.Get("executeNativeColor"), false)
H.equal(savedAddon.Config.Get("executeGlowColor"), "ff112233")
H.equal(savedAddon.Config.Get("victoryRushEnabled"), false)
H.equal(savedAddon.Config.Get("victoryRushCombatOnly"), false)
H.equal(savedAddon.Config.Get("victoryRushBar"), 4)
H.equal(savedAddon.Config.Get("victoryRushButton"), 8)
H.equal(savedAddon.Config.Get("victoryRushNativeColor"), false)
H.equal(savedAddon.Config.Get("victoryRushGlowColor"), "ff112233")

local invalid = H.new()
local secretBar = 5
local secretButton = 4
invalid.secret[secretBar] = true
invalid.secret[secretButton] = true
invalid.env.WarriorAssistForeverDB = {
    overpowerBar = secretBar,
    overpowerButton = 0,
    revengeBar = 1.5,
    revengeButton = "4",
    executeBar = 9,
    executeButton = 0,
    executeGlowColor = "invalid",
    victoryRushBar = 9,
    victoryRushButton = 0,
    victoryRushGlowColor = "invalid",
    victoryRushCombatOnly = "off",
}
local invalidAddon = load(invalid)

invalidAddon.Config.Initialize()

H.equal(invalidAddon.Config.Get("overpowerBar"), 0)
H.equal(invalidAddon.Config.Get("overpowerButton"), 1)
H.equal(invalidAddon.Config.Get("revengeBar"), 0)
H.equal(invalidAddon.Config.Get("revengeButton"), 1)
H.equal(invalidAddon.Config.Get("executeBar"), 0)
H.equal(invalidAddon.Config.Get("executeButton"), 1)
H.equal(invalidAddon.Config.Get("executeGlowColor"), "ffffd24a")
H.equal(invalidAddon.Config.Get("victoryRushBar"), 0)
H.equal(invalidAddon.Config.Get("victoryRushButton"), 1)
H.equal(invalidAddon.Config.Get("victoryRushGlowColor"), "ffffd24a")
H.equal(invalidAddon.Config.Get("victoryRushCombatOnly"), true)
H.equal(pcall(invalidAddon.Config.Set, "overpowerBar", 9), false)
H.equal(pcall(invalidAddon.Config.Set, "revengeButton", 13), false)
H.equal(pcall(invalidAddon.Config.Set, "overpowerButton", secretButton), false)
H.equal(pcall(invalidAddon.Config.Set, "executeButton", 13), false)
H.equal(pcall(invalidAddon.Config.Set, "victoryRushButton", 13), false)

local positions = {
    { "ActionButton", "Action bar 1" },
    { "MultiBarBottomLeftButton", "Action bar 2" },
    { "MultiBarBottomRightButton", "Action bar 3" },
    { "MultiBarRightButton", "Action bar 4" },
    { "MultiBarLeftButton", "Action bar 5" },
    { "MultiBar5Button", "Action bar 6" },
    { "MultiBar6Button", "Action bar 7" },
    { "MultiBar7Button", "Action bar 8" },
}
local bars = addon.Buttons.Bars()
H.equal(#bars, 8)
H.equal(addon.Buttons.Selected(0, 1), nil)

for index, position in ipairs(positions) do
    H.equal(bars[index], position[2])

    local button = world:newFrame()
    world.env[position[1] .. "1"] = button

    H.equal(addon.Buttons.Selected(index, 1), button)
end

local selected = world.env.ActionButton1
world.env.CURRENT_ACTIONBAR_PAGE = 2

H.equal(addon.Buttons.Selected(1, 1), selected, "physical button persists across pages")
H.equal(#addon.Buttons.All(), 8)
H.equal(addon.Buttons.Selected(0, 1), nil)
H.equal(addon.Buttons.Selected(1, 13), nil)
H.equal(addon.Buttons.Selected(1.5, 1), nil)

world.secret[2] = true

H.equal(addon.Buttons.Selected(2, 1), nil)

world.secret[2] = nil

world.env.GetShapeshiftFormID = function() return 17 end

H.equal(addon.Stance.Current(), "battle")

world.env.GetShapeshiftFormID = function() return 18 end

H.equal(addon.Stance.Current(), "defensive")

world.env.GetShapeshiftFormID = function() return 19 end

H.equal(addon.Stance.Current(), "berserker")

world.env.GetShapeshiftFormID = function() return nil end

H.equal(addon.Stance.Current(), "unknown")

world.env.GetShapeshiftFormID = function() error("restricted") end

H.equal(addon.Stance.Current(), "unknown")

world.env.GetShapeshiftFormID = function() return 17 end
world.secret[17] = true

H.equal(addon.Stance.Current(), "unknown")

H.equal(addon.Client.Boolean(true), true)
H.equal(addon.Client.Boolean(0), false)
H.equal(addon.Client.Boolean(nil), nil)

world.secret[true] = true

H.equal(addon.Client.Boolean(true), nil)

local spellWorld = H.new()
local spellAddon = load(spellWorld)
local bank = 0
spellWorld.env.Enum = {
    SpellBookSpellBank = { Player = bank },
    SpellBookItemType = { Spell = 1 },
}
spellWorld.env.C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 2 } end,
    GetSpellBookItemInfo = function(index, selectedBank)
        H.equal(selectedBank, bank)
        if index == 1 then
            return { itemType = 1, isPassive = false, isOffSpec = false, spellID = 7384 }
        end

        return { itemType = 1, isPassive = true, isOffSpec = false, spellID = 6572 }
    end,
}

local spells = spellAddon.Client.PlayerSpells()

H.equal(#spells, 1)
H.equal(spells[1].id, 7384)

spellWorld.env.C_SpellBook.GetNumSpellBookSkillLines = function() error("restricted") end

H.equal(#spellAddon.Client.PlayerSpells(), 0)

spellWorld.env.C_SpellBook.GetNumSpellBookSkillLines = function() return 1 end
spellWorld.env.C_SpellBook.GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 1 } end
spellWorld.env.C_SpellBook.GetSpellBookItemInfo = function() return { itemType = 1, isPassive = false, isOffSpec = false, spellID = 7384 } end
spellWorld.secret[7384] = true

H.equal(#spellAddon.Client.PlayerSpells(), 0)

spellWorld.secret[7384] = nil

local restrictedBook = setmetatable({}, { __index = function() error("restricted spellbook") end })
spellWorld.secret[restrictedBook] = true
spellWorld.env.C_SpellBook = restrictedBook

H.equal(#spellAddon.Client.PlayerSpells(), 0)

spellWorld.env.C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 1 } end,
    GetSpellBookItemInfo = function() return { itemType = 1, isPassive = false, isOffSpec = false, spellID = 7384 } end,
}

local restrictedLine = setmetatable({}, { __index = function() error("restricted line") end })
spellWorld.secret[restrictedLine] = true
spellWorld.env.C_SpellBook.GetSpellBookSkillLineInfo = function() return restrictedLine end

H.equal(#spellAddon.Client.PlayerSpells(), 0)

spellWorld.env.C_SpellBook.GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 1 } end
local restrictedItem = setmetatable({}, { __index = function() error("restricted item") end })
spellWorld.secret[restrictedItem] = true
spellWorld.env.C_SpellBook.GetSpellBookItemInfo = function() return restrictedItem end

H.equal(#spellAddon.Client.PlayerSpells(), 0)

spellWorld.env.C_SpellBook.GetSpellBookItemInfo = function()
    return { itemType = 1, isPassive = false, isOffSpec = false, spellID = 7384 }
end
local normalBook = spellWorld.env.C_SpellBook
local normalEnum = spellWorld.env.Enum
spellWorld.secret[normalBook] = true

H.equal(#spellAddon.Client.PlayerSpells(), 0, "secret spellbook global")

spellWorld.secret[normalBook] = nil

spellWorld.secret[normalEnum] = true

H.equal(#spellAddon.Client.PlayerSpells(), 0, "secret enum global")

spellWorld.secret[normalEnum] = nil

local normalBanks = normalEnum.SpellBookSpellBank
spellWorld.secret[normalBanks] = true

H.equal(#spellAddon.Client.PlayerSpells(), 0, "secret bank table")

spellWorld.secret[normalBanks] = nil

spellWorld.env.C_SpellBook.GetSpellBookItemInfo = function()
    return { itemType = 1, isPassive = false, isOffSpec = false, spellID = 7384 }
end
spellWorld.env.Enum = { SpellBookSpellBank = {}, SpellBookItemType = { Spell = 1 } }

H.equal(#spellAddon.Client.PlayerSpells(), 0, "missing player bank constant")

spellWorld.env.C_SpellBook.GetSpellBookItemInfo = function()
    return { itemType = nil, isPassive = false, isOffSpec = false, spellID = 7384 }
end
spellWorld.env.Enum = { SpellBookSpellBank = { Player = bank }, SpellBookItemType = {} }

H.equal(#spellAddon.Client.PlayerSpells(), 0, "missing spell item type constant")

print("reactive foundation: PASS")
