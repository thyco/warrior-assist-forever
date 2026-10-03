local _, addon = ...
local frame = CreateFrame("Frame")
local elapsedCheck, elapsedDiscovery = 0, 0

local function label(value, allowed, fallback)
    if not addon.Client.Readable(value) or type(value) ~= "string" then
        return fallback
    end

    return allowed[value] and value or fallback
end

local auraStates = { present = true, missing = true, unknown = true }
local auraQualities = { exact = true, estimated = true, none = true }
local cdmStates = { visible = true, hidden = true, unprepared = true,
    unavailable = true, ["not-configured"] = true }
local outputs = { none = true, cdm = true, ["icon-late"] = true, ["icon-missing"] = true }

local function diagnostics()
    local aura = addon.BattleShoutAura.Status()
    local feature = addon.BattleShoutReminder:Status()
    if not addon.Client.Readable(aura) or type(aura) ~= "table" then
        aura = {}
    end
    if not addon.Client.Readable(feature) or type(feature) ~= "table" then
        feature = {}
    end

    local _, discovered = addon.CDM.Resolve(addon.BattleShoutAura.name)
    local deadline = addon.Client.Number(aura.deadline)
    local now = addon.Client.Number(GetTime())
    local remaining = deadline and now
        and string.format("%.1fs", math.max(0, deadline - now)) or "unknown"
    local warrior = addon.Client.IsWarrior() and "active" or "inactive"

    print("Warrior Assist Forever 0.1.0 / client 16001 / Warrior " .. warrior)
    print("Enabled: " .. tostring(addon.Config.Get("battleShoutEnabled"))
        .. " / lead: " .. addon.Config.Get("leadSeconds") .. "s")
    print("Battle Shout: " .. label(aura.state, auraStates, "unknown")
        .. " / " .. label(aura.quality, auraQualities, "none") .. " / due in " .. remaining)
    print("CDM: " .. label(discovered, cdmStates, "unavailable")
        .. " / output: " .. label(feature.output, outputs, "none"))
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
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "COOLDOWN_VIEWER_DATA_LOADED",
}) do
    frame:RegisterEvent(event)
end
frame:RegisterUnitEvent("UNIT_AURA", "player")

function addon:OnEvent(event, unit, updateInfo)
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
        if unit == "player" then
            reminder:OnAuraUpdate(updateInfo)
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED"
        or event == "COOLDOWN_VIEWER_DATA_LOADED" then
        self.CDM.Prepare(self.BattleShoutAura.name)
        self.BattleShoutIcon:ApplySettings()
    end

    reminder:Refresh()
end

frame:SetScript("OnEvent", function(_, event, ...)
    addon:OnEvent(event, ...)
end)
frame:SetScript("OnUpdate", function(_, elapsed)
    if not addon.active or not addon.BattleShoutReminder.running or not addon.Client.InCombat() then
        elapsedCheck, elapsedDiscovery = 0, 0
        return
    end

    elapsedCheck = elapsedCheck + elapsed
    elapsedDiscovery = elapsedDiscovery + elapsed
    if elapsedCheck < 0.1 then
        return
    end

    local discover = elapsedDiscovery >= 0.5
    elapsedCheck = 0
    if discover then
        elapsedDiscovery = 0
    end

    addon.BattleShoutReminder:Refresh(false, discover)
end)
