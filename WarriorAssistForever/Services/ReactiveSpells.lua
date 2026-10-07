local _, addon = ...
local ReactiveSpells = { ids = { overpower = {}, revenge = {}, execute = {} }, gcdOnly = {} }
addon.ReactiveSpells = ReactiveSpells

local seeds = { overpower = 7384, revenge = 6572, execute = 5308 }
local gcdEvidenceSeconds = 1.6

local function read(api, ...)
    if type(api) ~= "function" then return nil end

    local ok, value = pcall(api, ...)
    if ok and addon.Client.Readable(value) then return value end
end

local function member(container, key)
    if not addon.Client.Readable(container) or type(container) ~= "table" then
        return nil
    end

    local ok, value = pcall(function() return container[key] end)
    if ok and addon.Client.Readable(value) then return value end
end

local function spellAPI(name)
    return member(C_Spell, name)
end

local function spellName(id)
    local info = read(spellAPI("GetSpellInfo"), id)
    local name = member(info, "name")

    if type(name) == "string" and name ~= "" then
        return name
    end
end

local function nonnegative(value)
    local number = addon.Client.Number(value)
    if number and number >= 0 then return number end
end

local function durationBoolean(duration, name)
    local ok, method = pcall(function() return duration[name] end)
    if not ok or not addon.Client.Readable(method) or type(method) ~= "function" then
        return nil
    end

    return addon.Client.Boolean(read(method, duration))
end

function ReactiveSpells.Rebuild()
    local names = {}
    local seen = { overpower = {}, revenge = {}, execute = {} }
    ReactiveSpells.ids = { overpower = {}, revenge = {}, execute = {} }
    ReactiveSpells.gcdOnly = {}

    for kind, seed in pairs(seeds) do
        names[kind] = spellName(seed)
    end

    local entries = addon.Client.PlayerSpells()
    if not addon.Client.Readable(entries) or type(entries) ~= "table" then
        return
    end

    for _, entry in ipairs(entries) do
        local id = nonnegative(member(entry, "id"))
        if id and id == math.floor(id) then
            local name = spellName(id)

            for kind, localizedName in pairs(names) do
                if name and name == localizedName and not seen[kind][id] then
                    ReactiveSpells.ids[kind][#ReactiveSpells.ids[kind] + 1] = id
                    seen[kind][id] = true
                end
            end
        end
    end
end

function ReactiveSpells.ObserveCooldownEvent()
    ReactiveSpells.gcdOnly = {}

    local now = nonnegative(read(GetTime))
    local deadline = now and addon.Client.Number(now + gcdEvidenceSeconds)
    if not deadline then return end

    -- Like Hunter's reactive glow, sample isOnGCD only inside this event.
    for kind, ranks in pairs(ReactiveSpells.ids) do
        if kind ~= "execute" then
            for _, id in ipairs(ranks) do
                local info = read(spellAPI("GetSpellCooldown"), id)
                if addon.Client.Boolean(member(info, "isOnGCD")) == true then
                    ReactiveSpells.gcdOnly[id] = deadline
                end
            end
        end
    end
end

local function signalFor(id, kind, mode)
    if mode == "usable" then
        local api = spellAPI("IsSpellUsable")
        if type(api) ~= "function" then return "unknown" end

        local ok, usableValue, powerValue = pcall(api, id)
        if not ok then return "unknown" end

        local usable = addon.Client.Boolean(usableValue)
        if usable == true then return "usable" end
        if usable == false then
            if not addon.Client.Readable(powerValue) then return "unknown" end

            local insufficientPower = addon.Client.Boolean(powerValue)
            if insufficientPower == true then return "low-rage" end
            if insufficientPower == false or powerValue == nil then return "inactive" end
        end

        return "unknown"
    end

    local overlayAPI = member(C_SpellActivationOverlay, "IsSpellOverlayed")
    local learned = addon.Client.Boolean(read(overlayAPI, id))
    local seed = addon.Client.Boolean(read(overlayAPI, seeds[kind]))
    if learned == true or seed == true then return "overlay" end
    if learned == false and seed == false then return "inactive" end

    return "unknown"
end

local function rangeFor(id)
    local inRange = addon.Client.Boolean(read(spellAPI("IsSpellInRange"), id, "target"))
    if inRange == true then return "in" end
    if inRange == false then return "out" end

    return "unknown"
end

local function eventGCDReady(id)
    local deadline = ReactiveSpells.gcdOnly[id]
    if not deadline then return false end

    local now = nonnegative(read(GetTime))
    if not now or now >= deadline then
        ReactiveSpells.gcdOnly[id] = nil

        return false
    end

    return true
end

local function cooldownFor(id)
    local info = read(spellAPI("GetSpellCooldown"), id)

    if type(info) ~= "table" then
        return "unknown"
    end

    local enabled = addon.Client.Boolean(member(info, "isEnabled"))
    if enabled == false then return "blocked" end

    local active = addon.Client.Boolean(member(info, "isActive"))
    if active == false then return "ready" end

    local ownDuration = read(spellAPI("GetSpellCooldownDuration"), id, true)
    if ownDuration then
        if durationBoolean(ownDuration, "HasSecretValues") == false then
            local zero = durationBoolean(ownDuration, "IsZero")
            if zero == true then return "ready" end

            if zero == false then
                local expired = durationBoolean(ownDuration, "HasExpired")
                if expired == true then return "ready" end
                if expired == false then
                    ReactiveSpells.gcdOnly[id] = nil

                    return "blocked"
                end
            end
        end

        -- Follow Hunter's event signal when the own-cooldown query is inconclusive.
        if eventGCDReady(id) then return "ready" end

        return "unknown"
    end

    if eventGCDReady(id) then return "ready" end

    local start = nonnegative(member(info, "startTime"))
    local duration = nonnegative(member(info, "duration"))
    if not start or not duration then return "unknown" end
    if start == 0 or duration == 0 then return "ready" end

    local gcd = read(spellAPI("GetSpellCooldown"), 61304)
    local gcdStart = nonnegative(member(gcd, "startTime"))
    local gcdDuration = nonnegative(member(gcd, "duration"))
    if gcdStart and gcdDuration and gcdDuration > 0
        and start == gcdStart and duration == gcdDuration then
        return "ready"
    end

    local now = nonnegative(read(GetTime))
    local expires = addon.Client.Number(start + duration)
    if not now or not expires then return "unknown" end
    if now >= expires then return "ready" end

    return "blocked"
end

function ReactiveSpells.Evaluate(kind, mode)
    local result = { ready = false, learned = false, id = nil, signal = "unknown",
        cooldown = "unknown", range = "unknown" }
    if not addon.Client.Readable(kind) or not addon.Client.Readable(mode)
        or type(kind) ~= "string" or type(mode) ~= "string"
        or not seeds[kind] or (mode ~= "usable" and mode ~= "overlay") then
        return result
    end

    local ranks = ReactiveSpells.ids[kind]
    if #ranks == 0 then return result end

    result.learned = true
    local inCombat = kind == "execute" and addon.Client.InCombat()

    for _, id in ipairs(ranks) do
        local signal = signalFor(id, kind, mode)
        local cooldown = kind == "execute" and "n/a" or cooldownFor(id)
        local range = kind == "execute" and (inCombat and "skipped" or rangeFor(id)) or "n/a"
        local opportunity = signal == mode or (mode == "usable" and signal == "low-rage")
        local cooldownAllows = kind == "overpower" or kind == "execute" or cooldown == "ready"
        local rangeAllows = kind ~= "execute" or range == "skipped" or range == "in"

        if result.id == nil or (opportunity and cooldownAllows) then
            result.id = id
            result.signal = signal
            result.cooldown = cooldown
            result.range = range
        end

        if opportunity and cooldownAllows and rangeAllows then
            result.ready = true
            break
        end
    end

    return result
end
