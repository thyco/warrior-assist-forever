local _, addon = ...
local CDM = {}
addon.CDM = CDM

local hooked = setmetatable({}, { __mode = "k" })
local previousItem
local owner = "battle-shout"

local function safeMethod(item, name)
    local ok, value = pcall(function()
        local method = item and item[name]
        if type(method) == "function" then
            return method(item)
        end
    end)

    if ok and addon.Client.Readable(value) then
        return value
    end
end

local function matchesSpell(item, spellName)
    if safeMethod(item, "GetCooldownID") == nil then
        return false
    end

    local baseID = safeMethod(item, "GetBaseSpellID")
    if addon.Client.Number(baseID) and addon.Client.SpellName(baseID) == spellName then
        return true
    end

    local info = safeMethod(item, "GetCooldownInfo")
    if type(info) ~= "table" then
        return false
    end

    for _, field in ipairs({ "spellID", "overrideSpellID", "overrideTooltipSpellID" }) do
        local spellID = info[field]
        if addon.Client.Number(spellID) and addon.Client.SpellName(spellID) == spellName then
            return true
        end
    end

    local linked = info.linkedSpellIDs
    if addon.Client.Readable(linked) and type(linked) == "table" then
        for _, spellID in ipairs(linked) do
            if addon.Client.Number(spellID) and addon.Client.SpellName(spellID) == spellName then
                return true
            end
        end
    end

    return false
end

local function prepareItem(item)
    if hooked[item] and addon.Glow.IsPrepared(item) then
        return true
    end

    if InCombatLockdown() then
        return false
    end

    if not hooked[item] then
        local ok = pcall(function()
            item:HookScript("OnHide", function()
                addon.Glow.Set(item, owner, false)
            end)
        end)
        if not ok then
            return false
        end

        hooked[item] = true
    end

    return addon.Glow.IsPrepared(item) or addon.Glow.Prepare(item) ~= nil
end

local function discover(spellName, prepareAll)
    local viewer = _G.BuffIconCooldownViewer
    if not viewer or not viewer.itemFramePool then
        return nil, "unavailable"
    end

    if not addon.Client.Readable(spellName) or type(spellName) ~= "string" or spellName == "" then
        return nil, "not-configured"
    end

    local status = "not-configured"
    for item in viewer.itemFramePool:EnumerateActive() do
        if matchesSpell(item, spellName) then
            if prepareAll then
                prepareItem(item)
            elseif safeMethod(item, "IsVisible") ~= true then
                status = "hidden"
            elseif prepareItem(item) then
                return item, "visible"
            else
                status = "unprepared"
            end
        end
    end

    return nil, status
end

function CDM.Resolve(spellName)
    local ok, item, status = pcall(discover, spellName, false)
    if not ok then
        item, status = nil, "unavailable"
    end

    if previousItem and previousItem ~= item then
        addon.Glow.Set(previousItem, owner, false)
    end

    previousItem = item
    return item, status
end

function CDM.Prepare(spellName)
    if InCombatLockdown() then
        return
    end

    pcall(discover, spellName, true)
end
