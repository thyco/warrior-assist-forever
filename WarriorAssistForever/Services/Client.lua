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

function Client.Boolean(value)
    if not Client.Readable(value) then
        return nil
    end

    if value == true or value == 1 then
        return true
    elseif value == false or value == 0 then
        return false
    end
end

function Client.PlayerSpells()
    local spells = {}
    if not C_SpellBook or not Enum or not Client.Readable(C_SpellBook) or not Client.Readable(Enum) then
        return spells
    end

    local bookBank = Enum.SpellBookSpellBank
    local itemTypes = Enum.SpellBookItemType
    local countSpells = C_SpellBook.GetNumSpellBookSkillLines
    local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo
    local itemInfo = C_SpellBook.GetSpellBookItemInfo

    if not bookBank or not itemTypes or not Client.Readable(bookBank) or not Client.Readable(itemTypes)
        or not Client.Readable(countSpells) or not Client.Readable(lineInfo) or not Client.Readable(itemInfo)
        or type(countSpells) ~= "function" or type(lineInfo) ~= "function" or type(itemInfo) ~= "function" then
        return spells
    end

    local bank = bookBank.Player
    local spellType = itemTypes.Spell
    if not Client.Readable(bank) or not Client.Readable(spellType) then
        return spells
    end

    local ok, count = pcall(countSpells)
    if not ok or not Client.Number(count) or count < 0 or count > 100 or count ~= math.floor(count) then
        return spells
    end

    for lineIndex = 1, count do
        local lineOK, line = pcall(lineInfo, lineIndex)
        if lineOK and Client.Readable(line) and type(line) == "table" then
            local offset = line.itemIndexOffset
            local length = line.numSpellBookItems

            if Client.Number(offset) and Client.Number(length) and offset >= 0 and length >= 0
                and offset == math.floor(offset) and length == math.floor(length) and length <= 1000 then
                for index = offset + 1, offset + length do
                    local itemOK, item = pcall(itemInfo, index, bank)
                    if itemOK and Client.Readable(item) and type(item) == "table"
                        and Client.Readable(item.itemType) and item.itemType == spellType
                        and Client.Boolean(item.isPassive) == false
                        and Client.Boolean(item.isOffSpec) == false
                        and Client.Number(item.spellID) then
                        spells[#spells + 1] = { id = item.spellID }
                    end
                end
            end
        end
    end

    return spells
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
