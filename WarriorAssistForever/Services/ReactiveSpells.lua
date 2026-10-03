local _, addon = ...
local ReactiveSpells = { ids = { overpower = {}, revenge = {} }, gcdOnly = {} }
addon.ReactiveSpells = ReactiveSpells

local seeds = { overpower = 7384, revenge = 6572 }

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

function ReactiveSpells.Rebuild()
    local names = {}
    local seen = { overpower = {}, revenge = {} }
    ReactiveSpells.ids = { overpower = {}, revenge = {} }
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

local function signalFor(id, kind, mode)
    if mode == "usable" then
        local usable = addon.Client.Boolean(read(spellAPI("IsSpellUsable"), id))
        if usable == true then return "usable" end
        if usable == false then return "inactive" end

        return "unknown"
    end

    local overlayAPI = member(C_SpellActivationOverlay, "IsSpellOverlayed")
    local learned = addon.Client.Boolean(read(overlayAPI, id))
    local seed = addon.Client.Boolean(read(overlayAPI, seeds[kind]))
    if learned == true or seed == true then return "overlay" end
    if learned == false and seed == false then return "inactive" end

    return "unknown"
end

local function cooldownFor(id, cooldownEvent)
    local info = read(spellAPI("GetSpellCooldown"), id)
    if addon.Client.Boolean(cooldownEvent) == true then
        ReactiveSpells.gcdOnly[id] = nil
    end

    if type(info) ~= "table" then
        ReactiveSpells.gcdOnly[id] = nil
        return "unknown"
    end

    local enabled = addon.Client.Boolean(member(info, "isEnabled"))
    if enabled == false then return "blocked" end

    local active = addon.Client.Boolean(member(info, "isActive"))
    local onGCD = addon.Client.Boolean(member(info, "isOnGCD"))
    if active == false or onGCD == true then
        ReactiveSpells.gcdOnly[id] = onGCD == true or nil
        return "ready"
    end

    ReactiveSpells.gcdOnly[id] = nil

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

function ReactiveSpells.Evaluate(kind, mode, cooldownEvent)
    local result = { ready = false, learned = false, id = nil, signal = "unknown", cooldown = "unknown" }
    if not addon.Client.Readable(kind) or not addon.Client.Readable(mode)
        or type(kind) ~= "string" or type(mode) ~= "string"
        or not seeds[kind] or (mode ~= "usable" and mode ~= "overlay") then
        return result
    end

    local ranks = ReactiveSpells.ids[kind]
    if #ranks == 0 then return result end

    result.learned = true

    for _, id in ipairs(ranks) do
        local signal = signalFor(id, kind, mode)
        local cooldown = cooldownFor(id, cooldownEvent)
        if result.id == nil or (signal == mode and cooldown == "ready") then
            result.id = id
            result.signal = signal
            result.cooldown = cooldown
        end

        if signal == mode and cooldown == "ready" then
            result.ready = true
            break
        end
    end

    return result
end
