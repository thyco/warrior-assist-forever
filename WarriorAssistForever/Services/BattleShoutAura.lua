local _, addon = ...
local Client = addon.Client
local BattleShoutAura = {}
addon.BattleShoutAura = BattleShoutAura

local timer = addon.Timers.New()
local spellName
local state = "unknown"
local sampled = false
local instanceID

local function readableTable(value)
    return Client.Readable(value) and type(value) == "table"
end

local function matches(aura)
    if not readableTable(aura) then
        return false, false
    end

    local name = aura.name
    if not Client.Readable(name) or type(name) ~= "string" then
        return false, false
    end

    return name == spellName, true
end

local function matchesAddedAura(aura)
    if not readableTable(aura) or Client.Boolean(aura.isHelpful) ~= true then
        return false
    end

    return matches(aura)
end

local function query(method, ...)
    if not C_UnitAuras or type(C_UnitAuras[method]) ~= "function" then
        return nil
    end

    local ok, result = pcall(C_UnitAuras[method], ...)
    if ok and Client.Readable(result) then
        return result
    end
end

local function hasFutureExpiration(aura)
    local expiration = Client.Number(aura.expirationTime)

    return expiration and expiration > GetTime()
end

local function sample()
    if not spellName then
        return nil, false
    end

    local direct = query("GetAuraDataBySpellName", "player", spellName, "HELPFUL")
    local found = matches(direct) and direct or nil
    local auras = query("GetUnitAuras", "player", "HELPFUL")
    if not readableTable(auras) then
        return found, false
    end

    local complete = true
    local count, largest = 0, 0
    for key, aura in pairs(auras) do
        local index = Client.Number(key)
        if not index or index < 1 or index % 1 ~= 0 then
            complete = false
        else
            count = count + 1
            largest = math.max(largest, index)
        end

        local match, readable = matches(aura)
        if match and (not found or (hasFutureExpiration(aura) and not hasFutureExpiration(found))) then
            found = aura
        end
        if not readable then
            complete = false
        end
    end

    return found, complete and count == largest
end

local function observedRefresh(updateInfo, currentID)
    if sampled and state == "missing" then
        return true
    end
    if instanceID and currentID and instanceID ~= currentID then
        return true
    end
    if not readableTable(updateInfo) then
        return false
    end

    if readableTable(updateInfo.addedAuras) then
        for _, aura in pairs(updateInfo.addedAuras) do
            if matchesAddedAura(aura) then
                return true
            end
        end
    end

    if instanceID and readableTable(updateInfo.updatedAuraInstanceIDs) then
        for _, id in pairs(updateInfo.updatedAuraInstanceIDs) do
            if Client.Number(id) == instanceID then
                return true
            end
        end
    end

    return false
end

local function addedAura(updateInfo)
    if not readableTable(updateInfo) or not readableTable(updateInfo.addedAuras) then
        return nil
    end

    for _, aura in pairs(updateInfo.addedAuras) do
        if matchesAddedAura(aura) then
            return aura
        end
    end
end

local function removedKnownAura(updateInfo)
    if not instanceID or not readableTable(updateInfo)
        or not readableTable(updateInfo.removedAuraInstanceIDs) then
        return false
    end

    for _, id in pairs(updateInfo.removedAuraInstanceIDs) do
        if Client.Number(id) == instanceID then
            return true
        end
    end

    return false
end

function BattleShoutAura.Initialize()
    local ok, name = pcall(Client.SpellName, 6673)
    spellName = ok and Client.Readable(name) and type(name) == "string" and name ~= "" and name or nil
    if not spellName then
        local locale = GetLocale and GetLocale() or "enUS"
        if Client.Readable(locale) and (locale == "enUS" or locale == "enGB") then
            spellName = "Battle Shout"
        end
    end

    BattleShoutAura.name = spellName

    state = "unknown"
    sampled = false
    instanceID = nil
    timer:Clear()
end

function BattleShoutAura.Status()
    return { state = state, deadline = timer.deadline, quality = timer:Quality() or "none" }
end

function BattleShoutAura.ObservePlayerCast(spellID)
    local id = Client.Number(spellID)
    if not spellName or not id then
        return false
    end

    local ok, name = pcall(Client.SpellName, id)
    if not ok or not Client.Readable(name) or name ~= spellName then
        return false
    end

    local now = Client.Number(GetTime())
    if not now then
        return false
    end

    local estimatedDeadline = now + 180
    -- UNIT_AURA may have already supplied the new exact deadline before cast success.
    if state == "present" and timer:Quality() == "exact"
        and timer.deadline and timer.deadline >= estimatedDeadline - 5 then
        return true
    end

    timer:SetDeadline(estimatedDeadline, "estimated")
    state = "unknown"
    instanceID = nil
    sampled = true
    return true
end

function BattleShoutAura.Refresh(updateInfo)
    local ok, aura, complete = pcall(sample)
    if not ok then
        aura, complete = nil, false
    end

    if not aura and not complete then
        local addedOK, added = pcall(addedAura, updateInfo)
        if addedOK then
            aura = added
        end
    end

    if aura then
        local currentID = Client.Number(aura.auraInstanceID)
        local refreshOK, refresh = pcall(observedRefresh, updateInfo, currentID)
        local expiration = Client.Number(aura.expirationTime)
        local now = GetTime()

        if expiration and expiration > now then
            timer:SetDeadline(expiration, "exact")
        elseif refreshOK and refresh then
            timer:StartFrom(now, 180, "estimated")
        elseif timer.deadline then
            timer:SetDeadline(timer.deadline, "estimated")
        end

        state = "present"
        instanceID = currentID
    elseif complete then
        state = "missing"
        instanceID = nil
        timer:Clear()
    else
        state = "unknown"
        local removedOK, removed = pcall(removedKnownAura, updateInfo)
        if removedOK and removed then
            timer:Clear()
            instanceID = nil
        elseif timer.deadline then
            timer:SetDeadline(timer.deadline, "estimated")
        end
    end

    sampled = true
    return BattleShoutAura.Status()
end
