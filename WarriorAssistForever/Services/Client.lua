local _, addon = ...
local Client = {}
addon.Client = Client

function Client.Readable(value)
    return not issecretvalue or not issecretvalue(value)
end

function Client.Number(value)
    if not Client.Readable(value) or type(value) ~= "number" then
        return nil
    end

    if value ~= value or value == math.huge or value == -math.huge then
        return nil
    end

    return value
end

function Client.SpellName(id)
    if not Client.Readable(id) then
        return nil
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        if Client.Readable(info) and info and Client.Readable(info.name) then
            return info.name
        end
    elseif GetSpellInfo then
        local name = GetSpellInfo(id)
        if Client.Readable(name) then
            return name
        end
    end
end

function Client.SpellTexture(id)
    if not Client.Readable(id) then
        return nil
    end

    if C_Spell and C_Spell.GetSpellTexture then
        local texture = C_Spell.GetSpellTexture(id)
        if Client.Readable(texture) then
            return texture
        end
    elseif GetSpellTexture then
        local texture = GetSpellTexture(id)
        if Client.Readable(texture) then
            return texture
        end
    end
end

function Client.InCombat()
    if not UnitAffectingCombat then
        return false
    end

    local combat = UnitAffectingCombat("player")
    return Client.Readable(combat) and combat == true
end

function Client.IsWarrior()
    if not UnitClass then
        return false
    end

    local _, class = UnitClass("player")
    return Client.Readable(class) and class == "WARRIOR"
end
