local H = dofile("tests/helpers.lua")

local world = H.new()
world.stanceID = 17
world.env.GetShapeshiftFormID = function() return world.stanceID end

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
H.equal(frame.events.UPDATE_SHAPESHIFT_FORM, true)

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
settings.stanceIconSize:SetValue(36)
H.equal(frame.width, 36)
H.equal(frame.height, 36)
H.equal(world.env.WarriorAssistForeverDB.stanceIconSize, 36)

addon.SettingsPanel.moveStanceIconButton.scripts.OnClick()
H.equal(icon.preview, true)
H.equal(frame.mouse, true)
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
H.equal(frame:IsVisible(), true, "combat does not hide stance")
H.equal(frame.point[4], 120, "combat interruption restores saved x")
H.equal(frame.point[5], -130, "combat interruption restores saved y")

local reloaded = H.new()
reloaded.env.WarriorAssistForeverDB = world.env.WarriorAssistForeverDB
local reloadedAddon = reloaded:loadManifest()
reloaded:fire("PLAYER_LOGIN")
H.equal(reloadedAddon.StanceIcon.frame.width, 36, "size survives reload")
H.equal(reloadedAddon.StanceIcon.frame.point[4], 120, "x survives reload")
H.equal(reloadedAddon.StanceIcon.frame.point[5], -130, "y survives reload")
H.equal(reloadedAddon.StanceIcon.frame:IsVisible(), true, "enabled state survives reload")

print("stance icon: PASS")
