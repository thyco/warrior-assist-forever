local H = {}

function H.equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

function H.new()
    local world = { auras = {}, time = 0, combat = false, class = "WARRIOR", secret = {}, addon = {}, frames = {}, glows = {} }

    local function frame(parent)
        local value = { parent = parent, visible = true, level = 0 }

        function value:SetAllPoints(target)
            self.points = target
        end

        function value:SetFrameLevel(level)
            self.level = level
        end

        function value:GetFrameLevel()
            return self.level
        end

        function value:EnableMouse(enabled)
            self.mouse = enabled
        end

        function value:Show()
            self.visible = true
        end

        function value:Hide()
            self.visible = false
        end

        world.frames[#world.frames + 1] = value
        return value
    end

    local library = {
        ProcGlow_Start = function(target, options)
            world.glows[target] = options
        end,
        ProcGlow_Stop = function(target)
            world.glows[target] = nil
        end,
    }

    world.env = setmetatable({
        GetTime = function() return world.time end,
        C_Spell = { GetSpellInfo = function() return { name = world.spellName or "Battle Shout" } end },
        C_UnitAuras = {
            GetAuraDataBySpellName = function(unit, name, filter)
                assert(unit == "player" and filter == "HELPFUL")
                if world.auraError or world.directError then error("restricted") end
                if world.directResult then return world.directResult end
                if world.secret[world.auras] then return nil end

                for _, aura in ipairs(world.auras) do
                    if not world.secret[aura] and not world.secret[aura.name] and aura.name == name then
                        return aura
                    end
                end
            end,
            GetUnitAuras = function(unit, filter, maxCount)
                assert(unit == "player" and filter == "HELPFUL" and maxCount == nil)
                if world.auraError or world.enumerationError then error("restricted") end

                return world.auras
            end,
        },
        UnitAffectingCombat = function() return world.combat end,
        UnitClass = function() return "Warrior", world.class end,
        issecretvalue = function(value) return world.secret[value] == true end,
        InCombatLockdown = function() return world.combat end,
        CreateFrame = function(_, _, parent) return frame(parent) end,
        LibStub = function() return library end,
    }, { __index = _G })

    function world:load(files)
        for _, name in ipairs(files) do
            local chunk = assert(loadfile("WarriorAssistForever/" .. name .. ".lua", "t", self.env))
            chunk("WarriorAssistForever", self.addon)
        end

        return self.addon
    end

    function world:fire(event, ...)
        if self.addon.OnEvent then
            self.addon:OnEvent(event, ...)
        end
    end

    function world:newFrame()
        return frame(nil)
    end

    return world
end

return H
