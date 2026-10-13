local H = dofile("tests/helpers.lua")

local world = H.new()
world.stanceID = 17
world.env.GetShapeshiftFormID = function() return world.stanceID end
world.offhandID = 12345
world.offhandType = "INVTYPE_SHIELD"
world.env.GetInventoryItemID = function(unit, slot)
    H.equal(unit, "player")
    H.equal(slot, 17)

    return world.offhandID
end
world.env.C_Item = {
    GetItemInfoInstant = function(itemID)
        H.equal(itemID, 12345)

        return itemID, "Armor", "Shields", world.offhandType
    end,
}

local textures = { [2457] = 101, [71] = 102, [2458] = 103 }
world.env.C_Spell.GetSpellTexture = function(spellID)
    return textures[spellID]
end

local addon = world:loadManifest()
world:fire("PLAYER_LOGIN")

local icon = assert(addon.StanceIcon, "stance icon module loads")
local frame = assert(icon.frame, "Warrior stance icon initializes")
H.equal(frame:IsVisible(), true, "stance icon is visible without combat or target")
H.equal(icon.texture.path, 101, "Battle Stance artwork")
H.equal(frame.width, 64, "default stance icon size")
H.equal(frame.point[4], 0, "independent default x")
H.equal(frame.point[5], -180, "independent default y")
H.equal(frame.mouse, false, "icon is click through outside move mode")
H.equal(frame.strata, "LOW", "normal stance icon stays behind the world map")
H.equal(frame.events.UPDATE_SHAPESHIFT_FORM, true)
H.equal(frame.events.PLAYER_EQUIPMENT_CHANGED, true, "equipment swaps refresh shield corner")
H.equal(icon.corner:IsShown(), true, "confirmed shield shows the corner in Battle Stance")
H.equal(icon.corner.path, "Interface\\AddOns\\WarriorAssistForever\\Media\\ShieldCorner.tga")
H.equal(icon.corner.width, 24, "default corner is 50 percent larger on a 64-pixel stance icon")
H.equal(icon.corner.point[1], "TOPLEFT")
H.equal(icon.corner.vertexColor[1], 148 / 255, "default corner is purple")

world.offhandID = nil
frame.scripts.OnEvent(frame, "PLAYER_EQUIPMENT_CHANGED")
H.equal(icon.corner:IsShown(), false, "no shield leaves the stance icon unmarked")

world.offhandID = 12345
frame.scripts.OnEvent(frame, "PLAYER_EQUIPMENT_CHANGED")
H.equal(icon.corner:IsShown(), true, "re-equipping a shield restores the corner")

local function stanceEvent()
    frame.scripts.OnEvent(frame, "UPDATE_SHAPESHIFT_FORM")
end

world.stanceID = 18
stanceEvent()
H.equal(icon.texture.path, 102, "Defensive Stance artwork")

world.combat = true
frame.scripts.OnEvent(frame, "PLAYER_REGEN_DISABLED")
world.stanceID = 19
stanceEvent()
H.equal(frame:IsVisible(), true, "stance icon persists through combat")
H.equal(icon.texture.path, 103, "Berserker Stance artwork updates in combat")

world.stanceID = 99
stanceEvent()
H.equal(icon.texture.path, "Interface\\Icons\\INV_Misc_QuestionMark", "unknown stance clears old artwork")
H.equal(frame:IsVisible(), true, "unknown stance remains visible")

world.stanceID = 17
world.env.C_Spell.GetSpellTexture = function() error("restricted texture") end
stanceEvent()
H.equal(icon.texture.path, "Interface\\Icons\\INV_Misc_QuestionMark", "restricted texture uses fallback")

world.combat = false
local settings = addon.SettingsPanel.settings
settings.stanceIconSize:SetValue(16)
H.equal(icon.corner.width, 6, "small stance icons keep a proportional corner")

settings.stanceIconSize:SetValue(128)
H.equal(icon.corner.width, 48, "large stance icons keep a proportional corner")

settings.stanceIconSize:SetValue(36)
H.equal(frame.width, 36)
H.equal(frame.height, 36)
H.equal(icon.corner.width, 13.5, "corner follows configured stance icon size")
H.equal(world.env.WarriorAssistForeverDB.stanceIconSize, 36)

settings.shieldCornerPosition:SetValue("TOPRIGHT")
H.equal(icon.corner.point[1], "TOPRIGHT")
H.equal(icon.corner.texCoords[1], 1, "top-right corner mirrors the triangle")

settings.shieldCornerPosition:SetValue("BOTTOMLEFT")
H.equal(icon.corner.point[1], "BOTTOMLEFT")
H.equal(icon.corner.texCoords[3], 1, "bottom-left corner mirrors vertically")

settings.shieldCornerPosition:SetValue("BOTTOMRIGHT")
H.equal(icon.corner.point[1], "BOTTOMRIGHT")
H.equal(icon.corner.texCoords[1], 1)
H.equal(icon.corner.texCoords[3], 1)

settings.shieldCornerColor:SetValue("ff8000ff")
H.equal(icon.corner.vertexColor[1], 128 / 255, "picker updates corner red component")
H.equal(icon.corner.vertexColor[3], 1, "picker updates corner blue component")

settings.shieldCornerEnabled:SetValue(false)
H.equal(icon.corner:IsShown(), false, "corner can be disabled independently")
settings.shieldCornerEnabled:SetValue(true)
H.equal(icon.corner:IsShown(), true)

world.offhandType = "INVTYPE_HOLDABLE"
frame.scripts.OnEvent(frame, "PLAYER_EQUIPMENT_CHANGED")
H.equal(icon.corner:IsShown(), false, "non-shield offhand leaves icon unmarked")

world.offhandType = "INVTYPE_SHIELD"
world.secret[world.offhandType] = true
frame.scripts.OnEvent(frame, "PLAYER_EQUIPMENT_CHANGED")
H.equal(icon.corner:IsShown(), false, "unreadable shield evidence leaves icon unmarked")

world.secret[world.offhandType] = nil
frame.scripts.OnEvent(frame, "PLAYER_EQUIPMENT_CHANGED")
H.equal(icon.corner:IsShown(), true)

addon.SettingsPanel.moveStanceIconButton.scripts.OnClick()
H.equal(icon.preview, true)
H.equal(frame.mouse, true)
H.equal(frame.strata, "TOOLTIP", "move mode raises the stance icon for dragging")
frame.scripts.OnDragStart(frame)
H.equal(frame.moving, true)
frame.x, frame.y = 620, 270
frame.scripts.OnDragStop(frame)
H.equal(addon.Config.Get("stanceIconX"), 120)
H.equal(addon.Config.Get("stanceIconY"), -130)
H.equal(frame.point[4], 120)
H.equal(frame.point[5], -130)

addon.SettingsPanel.canvas.scripts.OnHide()
H.equal(icon.preview, false)
H.equal(frame.mouse, false)
H.equal(frame.strata, "LOW", "closing settings restores map-safe layering")
H.equal(frame:IsVisible(), true, "closing settings does not hide stance")

settings.stanceIconEnabled:SetValue(false)
H.equal(frame:IsVisible(), false)
settings.stanceIconEnabled:SetValue(true)
H.equal(frame:IsVisible(), true)

addon.SettingsPanel.moveStanceIconButton.scripts.OnClick()
frame.scripts.OnDragStart(frame)
H.equal(frame.moving, true)
frame.point = { "CENTER", world.env.UIParent, "CENTER", 300, 300 }
world.combat = true
frame.scripts.OnEvent(frame, "PLAYER_REGEN_DISABLED")
H.equal(icon.preview, false, "combat stops dragging")
H.equal(frame.mouse, false)
H.equal(frame.strata, "LOW", "combat interruption restores map-safe layering")
H.equal(frame:IsVisible(), true, "combat does not hide stance")
H.equal(frame.point[4], 120, "combat interruption restores saved x")
H.equal(frame.point[5], -130, "combat interruption restores saved y")

local reloaded = H.new()
reloaded.env.WarriorAssistForeverDB = world.env.WarriorAssistForeverDB
reloaded.env.GetInventoryItemID = function() return 12345 end
reloaded.env.C_Item = {
    GetItemInfoInstant = function(itemID)
        return itemID, "Armor", "Shields", "INVTYPE_SHIELD"
    end,
}
local reloadedAddon = reloaded:loadManifest()
reloaded:fire("PLAYER_LOGIN")
H.equal(reloadedAddon.StanceIcon.frame.width, 36, "size survives reload")
H.equal(reloadedAddon.StanceIcon.frame.point[4], 120, "x survives reload")
H.equal(reloadedAddon.StanceIcon.frame.point[5], -130, "y survives reload")
H.equal(reloadedAddon.StanceIcon.frame:IsVisible(), true, "enabled state survives reload")
H.equal(reloadedAddon.StanceIcon.corner:IsShown(), true, "equipped shield corner returns after reload")
H.equal(reloadedAddon.StanceIcon.corner.point[1], "BOTTOMRIGHT", "corner position survives reload")
H.equal(reloadedAddon.StanceIcon.corner.vertexColor[1], 128 / 255,
    "custom corner color survives reload")

local malformed = H.new()
malformed.env.WarriorAssistForeverDB = {
    shieldCornerEnabled = "yes",
    shieldCornerColor = "purple",
    shieldCornerPosition = "CENTER",
}
local malformedAddon = malformed:loadManifest()
malformed:fire("PLAYER_LOGIN")
H.equal(malformedAddon.Config.Get("shieldCornerEnabled"), true)
H.equal(malformedAddon.Config.Get("shieldCornerColor"), "ff9461df")
H.equal(malformedAddon.Config.Get("shieldCornerPosition"), "TOPLEFT")
H.equal(pcall(malformedAddon.Config.Set, "shieldCornerPosition", "CENTER"), false)

print("stance icon: PASS")
