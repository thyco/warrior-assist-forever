local H = {}

function H.equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

function H.new()
    local world = { auras = {}, time = 0, combat = false, class = "WARRIOR", secret = {}, addon = {}, frames = {}, glows = {}, glowActive = {}, combatFrameCreations = 0, auraQueries = 0, printed = {}, settings = {} }

    local function frame(parent)
        local value = { parent = parent, visible = true, level = 0, scripts = {}, events = {} }

        function value:SetSize(width, height) self.width, self.height = width, height end
        function value:SetHeight(height) self.height = height end
        function value:SetWidth(width) self.width = width end
        function value:GetWidth() return self.width or 580 end
        function value:SetFrameStrata(strata) self.strata = strata end
        function value:SetMovable(movable) self.movable = movable end
        function value:SetClampedToScreen(clamped) self.clamped = clamped end
        function value:RegisterForDrag(button) self.dragButton = button end
        function value:SetScript(event, callback) self.scripts[event] = callback end
        function value:RegisterEvent(event) self.events[event] = true end
        function value:RegisterUnitEvent(event, unit) self.events[event] = unit end
        function value:StartMoving() self.moving = true end
        function value:StopMovingOrSizing() self.moving = false end
        function value:GetCenter() return self.x or 500, self.y or 400 end
        function value:ClearAllPoints() self.point = nil end
        function value:SetPoint(...) self.point = { ... } end
        function value:SetShown(shown) self.visible = shown end
        function value:IsVisible() return self.visible end
        function value:SetText(text) self.text = text end
        function value:SetChecked(checked) self.checked = checked end
        function value:GetChecked() return self.checked end
        function value:SetFontObject(font) self.font = font end
        function value:SetJustifyH(justify) self.justify = justify end
        function value:SetTextColor(...) self.textColor = { ... } end
        function value:SetBackdrop(backdrop) self.backdrop = backdrop end
        function value:SetBackdropColor(...) self.backdropColor = { ... } end
        function value:SetBackdropBorderColor(...) self.borderColor = { ... } end
        function value:SetScrollChild(child) self.scrollChild = child end
        function value:CreateFontString()
            return frame(self)
        end
        function value:CreateTexture()
            return {
                SetAllPoints = function() end,
                SetTexture = function(texture, path) texture.path = path end,
                SetPoint = function() end,
                SetColorTexture = function(texture, ...) texture.color = { ... } end,
            }
        end

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
            self.showCount = (self.showCount or 0) + 1
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
            local key = "_ProcGlow" .. options.key
            if not target[key] then
                target[key] = {
                    Hide = function()
                        world.glows[target] = nil
                        world.glowActive[target.parent] = false
                    end,
                }
            end

            world.glows[target] = options
            world.glowActive[target.parent] = true
        end,
        ProcGlow_Stop = function(target)
            world.glows[target] = nil
            world.glowActive[target.parent] = false
        end,
    }

    world.env = setmetatable({
        GetTime = function() return world.time end,
        C_Spell = { GetSpellInfo = function() return { name = world.spellName or "Battle Shout" } end },
        C_UnitAuras = {
            GetAuraDataBySpellName = function(unit, name, filter)
                world.auraQueries = world.auraQueries + 1
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
        CreateFrame = function(kind, _, parent)
            if world.combat then
                world.combatFrameCreations = world.combatFrameCreations + 1
            end

            local created = frame(parent)
            if kind == "CheckButton" then
                created.Text = frame(created)
            end
            return created
        end,
        LibStub = function() return library end,
        print = function(message) world.printed[#world.printed + 1] = message end,
        SlashCmdList = {},
        UIDropDownMenu_SetWidth = function(dropdown, width) dropdown.width = width end,
        UIDropDownMenu_Initialize = function(dropdown, callback) dropdown.initialize = callback end,
        UIDropDownMenu_SetText = function(dropdown, value) dropdown.text = value end,
        UIDropDownMenu_CreateInfo = function() return {} end,
        UIDropDownMenu_AddButton = function() end,
        Settings = {
            VarType = { Boolean = "boolean", Number = "number", String = "string" },
            RegisterCanvasLayoutCategory = function(canvas, name)
                local category = { canvas = canvas, name = name, id = 7 }
                function category:GetID() return self.id end
                world.category = category
                return category
            end,
            RegisterProxySetting = function(category, variable, valueType, label, default, getter, setter)
                local setting = { variable = variable, valueType = valueType, label = label, default = default }
                function setting:GetValue() return getter() end
                function setting:SetValue(value) setter(value) end
                world.settings[variable] = setting
                return setting
            end,
            RegisterAddOnCategory = function(category) world.registeredCategory = category end,
            OpenToCategory = function(id) world.openedCategory = id end,
        },
        ColorPickerFrame = {
            SetupColorPickerAndShow = function(self, options) self.options = options end,
            GetColorRGB = function() return 0, 1, 0 end,
        },
    }, { __index = _G })

    world.env._G = world.env
    world.env.UIParent = { GetCenter = function() return 500, 400 end }
    world.env.C_Spell.GetSpellTexture = function() return 132333 end

    function world:newCDMItem(cooldownID, spellID, visible)
        local item = self:newFrame()
        item.cooldownID = cooldownID
        item.spellID = spellID
        item.visible = visible
        item.hooks = {}

        function item:GetCooldownID() return self.cooldownID end
        function item:GetBaseSpellID() return self.spellID end
        function item:GetCooldownInfo() return self.info end
        function item:IsVisible() return self.visible end
        function item:GetSpellID() error("live aura identity must not be read") end

        function item:HookScript(event, callback)
            self.hooks[event] = self.hooks[event] or {}
            table.insert(self.hooks[event], callback)
        end

        function item:Hide()
            self.visible = false
            for _, callback in ipairs(self.hooks.OnHide or {}) do
                callback(self)
            end
        end

        return item
    end

    function world:setCDMItems(items)
        self.env.BuffIconCooldownViewer = {
            itemFramePool = {
                EnumerateActive = function()
                    local index = 0
                    return function()
                        index = index + 1
                        return items[index]
                    end
                end,
            },
        }
    end

    function world:load(files)
        for _, name in ipairs(files) do
            local chunk = assert(loadfile("WarriorAssistForever/" .. name .. ".lua", "t", self.env))
            chunk("WarriorAssistForever", self.addon)
        end

        return self.addon
    end

    function world:loadManifest()
        for line in io.lines("WarriorAssistForever/WarriorAssistForever.toc") do
            if line:match("%.lua$") and not line:match("^Libs/") then
                self:load({ (line:gsub("%.lua$", "")) })
            end
        end

        return self.addon
    end

    function world:tick(elapsed)
        self.time = self.time + elapsed
        for _, target in ipairs(self.frames) do
            if target.scripts.OnUpdate then
                target.scripts.OnUpdate(target, elapsed)
            end
        end
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
