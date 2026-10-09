local _, addon = ...
local ReactiveAbilities = { running = false, elapsed = 0 }
addon.ReactiveAbilities = ReactiveAbilities

local executeStyle = { native = "executeNativeColor", custom = "executeGlowColor" }
local victoryRushStyle = { native = "victoryRushNativeColor", custom = "victoryRushGlowColor" }
local definitions = {
    overpower = { owner = "overpower", enabled = "overpowerEnabled",
        bar = "overpowerBar", button = "overpowerButton",
        modes = { battle = "usable", berserker = "overlay" },
        colors = {
            battle = { native = "overpowerBattleNativeColor", custom = "overpowerBattleGlowColor" },
            berserker = { native = "overpowerBerserkerNativeColor", custom = "overpowerBerserkerGlowColor" },
        } },
    revenge = { owner = "revenge", enabled = "revengeEnabled",
        bar = "revengeBar", button = "revengeButton",
        modes = { defensive = "usable" },
        colors = {
            defensive = { native = "revengeNativeColor", custom = "revengeGlowColor" },
        } },
    execute = { owner = "execute", enabled = "executeEnabled",
        bar = "executeBar", button = "executeButton",
        modes = { battle = "usable", berserker = "usable" },
        colors = { battle = executeStyle, berserker = executeStyle } },
    victoryRush = { owner = "victoryRush", enabled = "victoryRushEnabled",
        bar = "victoryRushBar", button = "victoryRushButton", combatOnly = true,
        modes = { battle = "usable", defensive = "usable", berserker = "usable" },
        colors = { battle = victoryRushStyle, defensive = victoryRushStyle,
            berserker = victoryRushStyle } },
}
local order = { "overpower", "revenge", "execute", "victoryRush" }
local events = {
    "UPDATE_SHAPESHIFT_FORM", "SPELL_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN",
    "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
    "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "SPELL_DATA_LOAD_RESULT",
    "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "ACTIONBAR_PAGE_CHANGED", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_UPDATE_STATE",
}
local rebuildEvents = {
    SPELLS_CHANGED = true,
    PLAYER_TALENT_UPDATE = true,
    SPELL_DATA_LOAD_RESULT = true,
}

local function emptyStatus()
    return { ready = false, signal = "unknown", cooldown = "unknown", range = "unknown", active = false }
end

local function selected(definition)
    local bar = addon.Config.Get(definition.bar)
    local index = addon.Config.Get(definition.button)
    if bar == 0 then
        return nil
    end

    return addon.Buttons.Selected(bar, index)
end

local function pollingNeeded()
    for _, kind in ipairs(order) do
        local definition = definitions[kind]
        if addon.Config.Get(definition.enabled) and addon.Config.Get(definition.bar) ~= 0 then
            return true
        end
    end

    return false
end

local function visible(button)
    if not addon.Client.Readable(button) then
        return false
    end

    local ok, shown = pcall(function() return button:IsVisible() end)
    return ok and addon.Client.Boolean(shown) == true
end

function ReactiveAbilities:Initialize()
    if not self.frame then
        self.frame = CreateFrame("Frame")
        for _, event in ipairs(events) do
            self.frame:RegisterEvent(event)
        end

        self.frame:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_LEAVING_WORLD" then
                self:Stop()
                return
            end

            if event == "PLAYER_ENTERING_WORLD" then
                self:Initialize()
                return
            end

            if rebuildEvents[event] then
                addon.ReactiveSpells.Rebuild()
            end

            if event == "SPELL_UPDATE_COOLDOWN" then
                addon.ReactiveSpells.ObserveCooldownEvent()
            end

            self:Refresh()
        end)
    end

    self.running = true
    addon.ReactiveSpells.Rebuild()
    for _, kind in ipairs(order) do
        addon.Glow.ConfigureOwner(definitions[kind].owner, {})
    end

    self:Refresh()
end

function ReactiveAbilities:Refresh()
    if not self.running then
        return
    end

    local stance = addon.Stance.Current()
    self.status = { stance = stance }
    local canPrepare = not InCombatLockdown()

    for _, kind in ipairs(order) do
        local definition = definitions[kind]
        local style = definition.colors[stance]
        local color
        if style and not addon.Config.Get(style.native) then
            color = addon.Config.GetColor(style.custom)
        end

        addon.Glow.ConfigureOwner(definition.owner, { color = color })

        local button = selected(definition)
        local previous = self.buttons and self.buttons[kind]
        if previous and previous ~= button then
            addon.Glow.Set(previous, definition.owner, false)
        end

        self.buttons = self.buttons or {}
        self.buttons[kind] = button

        local shown = button and visible(button)
        if button and shown and canPrepare then
            addon.Glow.Prepare(button)
        end

        local status = emptyStatus()
        local mode = definition.modes[stance]
        if addon.Config.Get(definition.enabled) and mode and shown
            and (not definition.combatOnly or addon.Client.InCombat()) then
            local result = addon.ReactiveSpells.Evaluate(kind, mode)
            status.ready = result.ready
            status.signal = result.signal
            status.cooldown = result.cooldown
            status.range = result.range
            status.active = result.ready and addon.Glow.IsPrepared(button)
        end

        if button then
            addon.Glow.Set(button, definition.owner, status.active)
        end

        self.status[kind] = status
    end

    if pollingNeeded() then
        if not self.polling then
            self.elapsed = 0
            self.frame:SetScript("OnUpdate", function(_, elapsed)
                self.elapsed = self.elapsed + elapsed
                if self.elapsed >= 0.1 then
                    self.elapsed = 0
                    self:Refresh()
                end
            end)
            self.polling = true
        end
    elseif self.polling then
        self.frame:SetScript("OnUpdate", nil)
        self.polling = false
        self.elapsed = 0
    end
end

function ReactiveAbilities:Stop()
    self.running = false
    self.elapsed = 0
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
    end
    self.polling = false

    for _, kind in ipairs(order) do
        addon.Glow.ClearOwner(definitions[kind].owner)
    end

    self.buttons = {}
    self.status = { stance = "unknown", overpower = emptyStatus(),
        revenge = emptyStatus(), execute = emptyStatus(), victoryRush = emptyStatus() }
end

function ReactiveAbilities:Status()
    return self.status or { stance = "unknown", overpower = emptyStatus(),
        revenge = emptyStatus(), execute = emptyStatus(), victoryRush = emptyStatus() }
end
