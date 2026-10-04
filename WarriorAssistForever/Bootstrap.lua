local _, addon = ...
local frame = CreateFrame("Frame")
local elapsedCheck = 0

local function label(value, allowed, fallback)
    if not addon.Client.Readable(value) or type(value) ~= "string" then
        return fallback
    end

    return allowed[value] and value or fallback
end

local auraStates = { present = true, missing = true, unknown = true }
local auraQualities = { exact = true, estimated = true, none = true }
local outputs = { none = true, ["icon-late"] = true, ["icon-missing"] = true }
local stances = { battle = true, defensive = true, berserker = true, unknown = true }
local signals = { usable = true, overlay = true, inactive = true, unknown = true }
local cooldowns = { ready = true, blocked = true, unknown = true }

local function member(container, key)
    if not addon.Client.Readable(container) or type(container) ~= "table" then
        return nil
    end

    local ok, value = pcall(function() return container[key] end)
    if ok and addon.Client.Readable(value) then
        return value
    end
end

local function learnedLabel(kind)
    local ranks = member(addon.ReactiveSpells.ids, kind)
    if type(ranks) ~= "table" then
        return "unknown"
    end

    local ok, count = pcall(function() return #ranks end)
    return ok and count > 0 and "learned" or "unknown"
end

local function selectionLabel(kind)
    local bar = addon.Client.Number(addon.Config.Get(kind .. "Bar"))
    local button = addon.Client.Number(addon.Config.Get(kind .. "Button"))
    if not bar or bar == 0 then
        return "not selected"
    end

    if bar < 1 or bar > 8 or bar ~= math.floor(bar)
        or not button or button < 1 or button > 12 or button ~= math.floor(button) then
        return "unknown"
    end

    return "bar " .. bar .. " button " .. button
end

local function booleanLabel(value, yes, no, fallback)
    local safe = addon.Client.Boolean(value)
    if safe == true then return yes end
    if safe == false then return no end
    return fallback
end

local function reactiveDiagnostics(kind, title, status)
    print(title .. ": " .. learnedLabel(kind)
        .. " / " .. booleanLabel(member(status, "ready"), "ready", "not ready", "unknown")
        .. " / " .. label(member(status, "signal"), signals, "unknown")
        .. " / " .. label(member(status, "cooldown"), cooldowns, "unknown")
        .. " / " .. selectionLabel(kind)
        .. " / glow " .. booleanLabel(member(status, "active"), "active", "inactive", "inactive"))
end

local function diagnostics()
    local aura = addon.BattleShoutAura.Status()
    local feature = addon.BattleShoutReminder:Status()
    if not addon.Client.Readable(aura) or type(aura) ~= "table" then
        aura = {}
    end
    if not addon.Client.Readable(feature) or type(feature) ~= "table" then
        feature = {}
    end

    local deadline = addon.Client.Number(aura.deadline)
    local now = addon.Client.Number(GetTime())
    local remaining = deadline and now
        and string.format("%.1fs", math.max(0, deadline - now)) or "unknown"
    local warrior = addon.Client.IsWarrior() and "active" or "inactive"

    print("Warrior Assist Forever 0.3.1 / client 16001 / Warrior " .. warrior)
    print("Enabled: " .. tostring(addon.Config.Get("battleShoutEnabled"))
        .. " / lead: " .. addon.Config.Get("leadSeconds") .. "s")
    print("Battle Shout: " .. label(aura.state, auraStates, "unknown")
        .. " / " .. label(aura.quality, auraQualities, "none") .. " / due in " .. remaining)
    print("Reminder: " .. label(feature.output, outputs, "none"))

    local reactive = addon.ReactiveAbilities:Status()
    print("Stance: " .. label(member(reactive, "stance"), stances, "unknown"))
    reactiveDiagnostics("overpower", "Overpower", member(reactive, "overpower"))
    reactiveDiagnostics("revenge", "Revenge", member(reactive, "revenge"))
end

SLASH_WARRIORASSISTFOREVER1 = "/waf"
SlashCmdList.WARRIORASSISTFOREVER = function(message)
    if type(message) == "string" and message:match("^%s*[Cc][Oo][Nn][Ff][Ii][Gg]%s*$") then
        addon.SettingsPanel:Open()
        return
    end

    diagnostics()
end

for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
}) do
    frame:RegisterEvent(event)
end
frame:RegisterUnitEvent("UNIT_AURA", "player")

function addon:OnEvent(event, _, updateInfo)
    if event == "PLAYER_LOGIN" then
        self:Start()
        return
    end

    if not self.started or not self.active then
        return
    end

    local reminder = self.BattleShoutReminder
    if event == "PLAYER_LEAVING_WORLD" then
        reminder:Stop()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        reminder:Initialize()
    elseif event == "UNIT_AURA" then
        -- RegisterUnitEvent already limits delivery to the player; the unit
        -- event payload can be secret when auras are restricted.
        reminder:OnAuraUpdate(updateInfo)
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
        self.BattleShoutIcon:ApplySettings()
    end

    reminder:Refresh()
end

frame:SetScript("OnEvent", function(_, event, ...)
    addon:OnEvent(event, ...)
end)
frame:SetScript("OnUpdate", function(_, elapsed)
    if not addon.active or not addon.BattleShoutReminder.running or not addon.Client.InCombat() then
        elapsedCheck = 0
        return
    end

    elapsedCheck = elapsedCheck + elapsed
    if elapsedCheck < 0.1 then
        return
    end

    elapsedCheck = 0
    addon.BattleShoutReminder:Refresh(false)
end)
