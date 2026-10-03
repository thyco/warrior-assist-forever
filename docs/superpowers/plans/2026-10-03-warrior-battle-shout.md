# Warrior Battle Shout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a standalone WoW Forever Warrior addon that tracks Battle Shout from any caster, glows its visible CDM tracked-buff icon near expiration, and shows a movable combat reminder when CDM is unavailable or the buff is missing.

**Architecture:** One aura service owns the present/missing/unknown state and a deadline. A CDM adapter finds the current pooled Battle Shout item; a feature chooses the CDM glow or a movable screen icon. Core and settings follow the sibling addons' private-namespace pattern.

**Tech Stack:** WoW Forever interface 16001, WoW-compatible Lua, LibCustomGlow-1.0/LibStub, native Settings API, Lua 5.4 test doubles, Python 3.9+ ZIP packaging.

**Spec:** `docs/superpowers/specs/2026-10-02-warrior-battle-shout-design.md`

## Global Constraints

- Package path is `WarriorAssistForever/WarriorAssistForever.toc`, with version `0.1.0`, interface `16001`, account-wide `WarriorAssistForeverDB`, and slash command `/waf`.
- Feature logic runs only when `UnitClass("player")` returns `WARRIOR`; settings may register for every character.
- All reminders require combat; they work with or without a target. The lead time is an integer 1–60 seconds, default 10. The green default color is `ff00ff00`.
- Aura matching is rank independent and accepts any caster. Readable aura expiration wins; otherwise a safely observed application/refresh starts a 180-second estimate. Missing requires a complete readable aura enumeration. Unknown never becomes missing.
- CDM's visible Tracked Buffs item is the preferred late output. The 64×64 movable icon is the late fallback and the confirmed-missing output. Clear stale glow when CDM pools or reassigns an item.
- Addon-owned overlays are prepared outside combat. Never cast, edit key bindings, change CDM settings, or write protected action attributes.
- Keep logical Lua blocks separated by blank lines; preserve existing user styling. The AGENTS.md Java rules remain applicable if Java is ever added: explicit types and individual `@Test` methods.
- Read the spec and sibling implementations before starting. Commit each task on `codex/warrior-battle-shout` and inspect `git status` before editing; preserve unrelated changes.

## File map

| File | Single responsibility |
| --- | --- |
| `WarriorAssistForever/WarriorAssistForever.toc` | Manifest and load order. |
| `WarriorAssistForever/Core.lua` | Warrior gate, feature lifecycle, settings notifications. |
| `WarriorAssistForever/Services/Config.lua` | Typed defaults, normalization, saved values. |
| `WarriorAssistForever/Services/Client.lua` | Safe API reads, spell name/texture, combat state. |
| `WarriorAssistForever/Services/Timers.lua` | Deadline storage and lead-time check. |
| `WarriorAssistForever/Services/Glow.lua` | Addon-owned LibCustomGlow overlays. |
| `WarriorAssistForever/Services/BattleShoutAura.lua` | Rank-independent player aura state and timing quality. |
| `WarriorAssistForever/Services/CDM.lua` | Find and validate the current Battle Shout tracked-buff item. |
| `WarriorAssistForever/Services/BattleShoutIcon.lua` | Movable screen icon and preview. |
| `WarriorAssistForever/Features/BattleShoutReminder.lua` | Choose exactly one visible reminder output. |
| `WarriorAssistForever/Services/SettingsWidgets.lua` | Native settings controls reused from siblings. |
| `WarriorAssistForever/SettingsPanel.lua` | Battle Shout settings group and Move icon control. |
| `WarriorAssistForever/Bootstrap.lua` | Events, update ticks, slash diagnostics. |
| `WarriorAssistForever/Libs/*` | Bundled glow renderer and license notices. |
| `tests/helpers.lua`, `tests/foundation.lua`, `tests/aura.lua`, `tests/cdm.lua`, `tests/feature.lua`, `tests/settings.lua`, `tests/integration.lua` | Production-module doubles and behavior checks. |
| `scripts/package.py`, `README.md`, `.gitignore` | Installable ZIP, user instructions, ignored build output. |

## Review Focus

1. An unrelated helpful aura has a secret name: absence is unknown, and no missing icon appears. Pin this in Task 2's aura tests.
2. A different Warrior applies or refreshes another Battle Shout rank: timing updates without a player-caster filter. Pin this in Task 2's aura tests.
3. A CDM frame is reused for another spell while glowing: the old overlay stops before the frame can appear as that spell. Pin this in Task 3's CDM tests.
4. A CDM frame appears during combat before an overlay exists: the movable icon carries the late reminder and no frame creation is attempted in combat. Pin this in Task 4's feature tests.
5. Saved lead time, color, or icon coordinates are malformed: defaults restore without a Lua error. Pin this in Task 1's config tests and Task 5's panel tests.

---

### Task 1: Standalone foundation, safe values, timer, and renderer

**Files:** Create `WarriorAssistForever/WarriorAssistForever.toc`, `Core.lua`, `Services/Config.lua`, `Services/Client.lua`, `Services/Timers.lua`, `Services/Glow.lua`, bundled `Libs/*`, `tests/helpers.lua`, `tests/foundation.lua`.

**Interfaces:** `Config.Initialize/Get/GetDefault/GetColor/Set/Subscribe`; `Client.Readable/Number/SpellName/SpellTexture/InCombat/IsWarrior`; `Timers.New()` returns `SetDeadline(deadline, quality)`, `StartFrom(startedAt, duration, quality)`, `Clear()`, `Remaining()`, `IsDue(lead)`, `Quality()`; `Glow.Prepare(frame)`, `Set(frame, owner, active, options)`, `ClearOwner(owner)`, `ConfigureOwner(owner, options)`.

- [ ] **Step 1: Write a failing foundation test.** Create a small isolated WoW environment in `tests/helpers.lua` with `world.time`, `world.combat`, `world.class`, `world.secret`, `world.env`, `world:load(files)`, `world:fire(event, ...)`, and frame/glow doubles. `world:load` passes `"WarriorAssistForever", world.addon` to each Lua chunk. In `tests/foundation.lua`, use this exact fixture contract:

```lua
local H = dofile("tests/helpers.lua")
local world = H.new()
local addon = world:load({ "Core", "Services/Config", "Services/Client", "Services/Timers" })

addon.Config.Initialize()
H.equal(addon.Config.Get("leadSeconds"), 10)
H.equal(addon.Config.Get("glowColor"), "ff00ff00")
H.equal(addon.Config.Get("iconX"), 0)
H.equal(addon.Config.Get("iconY"), -270)

local timer = addon.Timers.New()
timer:StartFrom(0, 180, "estimated")
world.time = 169.9
H.equal(timer:IsDue(10), false)
world.time = 170
H.equal(timer:IsDue(10), true)
```

Add a second test with `WarriorAssistForeverDB = { leadSeconds = 61, glowColor = "bad", iconX = math.huge }` and assert defaults after `Initialize()`.

- [ ] **Step 2: Run the red test.**

```sh
lua tests/foundation.lua
```

Expected: failure loading the missing addon files.

- [ ] **Step 3: Create the foundation.** Use the Paladin manifest/load-order and `Services/Glow.lua` as references. Copy only `LibStub`, `LibCustomGlow-1.0`, their license/README files, and the renderer adapter; change its key to `WarriorAssistForever`. The manifest starts with the libraries and these foundation modules, leaving feature files to be added in their owning tasks. Implement config validation and the timer with these signatures:

```lua
local defaults = {
    battleShoutEnabled = true,
    leadSeconds = 10,
    glowColor = "ff00ff00",
    iconX = 0,
    iconY = -270,
}

function timer:StartFrom(startedAt, duration, quality)
    self:SetDeadline(startedAt + duration, quality)
end

function timer:IsDue(lead)
    return self.deadline ~= nil and GetTime() >= self.deadline - lead
end

function timer:Remaining()
    return self.deadline and math.max(0, self.deadline - GetTime()) or nil
end
```

Validate lead seconds as an integer in `[1, 60]`, color as eight hex digits with normalized opaque alpha, and coordinates as finite numbers within `[-4096, 4096]`. `Client.Readable(value)` checks `issecretvalue` when available; `Client.Number(value)` requires a readable finite number. `Client.InCombat()` returns true only for a readable true `UnitAffectingCombat("player")`; `Client.IsWarrior()` checks the readable class token returned by `UnitClass("player")` against `"WARRIOR"`. A unit harness may inject `LibStub` as a renderer double; the real library is loaded by Task 6's integration test.

- [ ] **Step 4: Run the green test and syntax check.**

```sh
lua tests/foundation.lua
luac -p WarriorAssistForever/*.lua WarriorAssistForever/Services/*.lua
```

Expected: PASS and no syntax errors.

- [ ] **Step 5: Commit the foundation.**

```sh
git add WarriorAssistForever tests/helpers.lua tests/foundation.lua
git commit -m "feat: scaffold Warrior addon services"
```

### Task 2: Player Battle Shout aura state from any caster

**Files:** Create `WarriorAssistForever/Services/BattleShoutAura.lua`, `tests/aura.lua`; modify the TOC to load the aura service after `Timers.lua`.

**Interfaces:** `BattleShoutAura.Initialize()` resolves the localized name from base spell ID `6673` with the literal name `Battle Shout` only as an English fallback. `BattleShoutAura.Refresh(updateInfo)` samples the player aura and returns a status table. `BattleShoutAura.Status()` returns `{ state = "present"|"missing"|"unknown", deadline = number|nil, quality = "exact"|"estimated"|"none" }`. The module owns a `Timers.New()` instance and never examines `sourceUnit` to reject an aura.

- [ ] **Step 1: Write failing aura tests.** Extend the helper with `world.auras`, `world.auraError`, and doubles for `C_UnitAuras.GetAuraDataBySpellName("player", name, "HELPFUL")` and `GetUnitAuras("player", "HELPFUL")`. Include these scenarios as separate `test(name, fn)` calls; keep preparation, action, and assertions in separate blocks:

```lua
world.auras = { { name = "Battle Shout", spellId = 2048, sourceUnit = "party1",
    auraInstanceID = 7, expirationTime = 180 } }
addon.BattleShoutAura.Initialize()
local status = addon.BattleShoutAura.Refresh({ addedAuras = world.auras })
H.equal(status.state, "present")
H.equal(status.deadline, 180)
H.equal(status.quality, "exact")

world.auras[1].expirationTime = world.secret
world.time = 30
status = addon.BattleShoutAura.Refresh({ updatedAuraInstanceIDs = { 7 } })
H.equal(status.deadline, 210)
H.equal(status.quality, "estimated")
```

Also test: readable helpful enumeration with no match is missing; an unrelated aura with secret `name` makes absence unknown; failed enumeration is unknown; a rank/name match from `party2` is accepted; same-instance refresh resets the estimate; an existing buff at login with unreadable expiration has no invented deadline; a later restricted query retains a prior deadline but clears a prior missing state.

- [ ] **Step 2: Verify the red test.**

```sh
lua tests/aura.lua
```

Expected: failure because `BattleShoutAura` is missing.

- [ ] **Step 3: Implement guarded lookup and state transitions.** Query by localized name for presence, then call `GetUnitAuras("player", "HELPFUL")` without `maxCount`. A readable name match in either result establishes presence; inspect every returned entry before declaring absence. A failed call, secret table, secret entry, or unreadable name makes absence unknown. Guard the table and every `name`, `auraInstanceID`, and `expirationTime` before comparing or printing. If any enumerated name is unreadable, absence remains unknown. Detect a safe refresh from a matching added aura, a known matching `updatedAuraInstanceIDs` entry, a changed readable instance ID, or a missing→present transition after initial sampling. An initial present aura with unreadable expiration has no estimate. The essential transition is:

```lua
if present and Client.Number(aura.expirationTime) and aura.expirationTime > GetTime() then
    timer:SetDeadline(aura.expirationTime, "exact")
elseif present and observedApplicationOrRefresh then
    timer:StartFrom(GetTime(), 180, "estimated")
elseif missing then
    timer:Clear()
end
```

On a restricted query, preserve only a deadline learned from a prior present state; relabel its quality `"estimated"`, set `state = "unknown"`, and do not use a previous `missing` flag to display the icon. If both a direct lookup and enumeration are unavailable, status is unknown. Never use a caster filter. Treat expiration fields that are zero, nonfinite, or in the past as unavailable timing; a safely observed application still gets the 180-second estimate. Keep `quality` tied to the timer.

- [ ] **Step 4: Run aura tests and syntax check.**

```sh
lua tests/aura.lua
luac -p WarriorAssistForever/Services/BattleShoutAura.lua
```

Expected: PASS and no syntax errors.

- [ ] **Step 5: Commit the aura service.**

```sh
git add WarriorAssistForever/WarriorAssistForever.toc WarriorAssistForever/Services/BattleShoutAura.lua tests/aura.lua tests/helpers.lua
git commit -m "feat: track Battle Shout aura from any caster"
```

### Task 3: CDM tracked-buff item discovery and safe glow target

**Files:** Create `WarriorAssistForever/Services/CDM.lua`, `tests/cdm.lua`; modify the TOC to load CDM after Client/Glow.

**Interfaces:** `CDM.Resolve(spellName)` returns `itemFrame|nil, status`, where status is `"visible"`, `"hidden"`, `"not-configured"`, `"unavailable"`, or `"unprepared"`. `CDM.Prepare(spellName)` prepares matching active frames out of combat. The feature calls `Glow.Set(itemFrame, "battle-shout", ...)` and clears its old item before changing targets.

- [ ] **Step 1: Write failing CDM tests.** Double `BuffIconCooldownViewer.itemFramePool:EnumerateActive()` with item frames exposing `GetCooldownID`, `GetBaseSpellID`, `GetCooldownInfo`, `IsVisible`, and `HookScript`. Make `Hide()` invoke registered `OnHide` hooks, and record per-frame `Glow.Set` state in `world.glowActive`. Cover a visible matching item, hidden match, no configured match, unavailable viewer, and the review-focus case: one frame changes from Battle Shout to another spell while a glow is active. A representative identity test is:

```lua
local item = world:newCDMItem(42, 6673, true)
world:setCDMItems({ item })

local found, status = addon.CDM.Resolve("Battle Shout")
H.equal(found, item)
H.equal(status, "visible")

addon.Glow.Set(item, "battle-shout", true)
item:Hide() -- pool release must stop the glow before this frame is reassigned
H.equal(world.glowActive[item], false)

item.spellID = 12345
found, status = addon.CDM.Resolve("Battle Shout")
H.equal(found, nil)
H.equal(status, "not-configured")
```

- [ ] **Step 2: Verify the red test.**

```sh
lua tests/cdm.lua
```

Expected: failure because CDM service is missing.

- [ ] **Step 3: Implement discovery.** Iterate only active pooled frames and require a nonnil readable cooldown ID. Compare the localized name of readable configuration spell IDs from `GetBaseSpellID()` and `GetCooldownInfo()` (`spellID`, `overrideSpellID`, `overrideTooltipSpellID`, and `linkedSpellIDs`) to `spellName`. Do not use `GetSpellID()`, which may read live aura data. Ignore icon textures and physical positions. Guard item method calls and pooled-frame iteration with `pcall` because viewer state may change during layout. Use `Glow.Prepare(item)` only outside `InCombatLockdown()`; return `"unprepared"` if a visible match lacks an overlay in combat. Keep the renderer state outside the item frame; the feature clears its previous item on every identity change. Register a guarded `HookScript("OnHide", ...)` when preparing a matching frame, using a weak-key adapter table to avoid duplicate hooks. That callback clears the Battle Shout owner immediately when CDM pools the frame; ordinary discovery also clears the old frame if CDM changes its identity without hiding it. The helper used by the lookup is:

```lua
local function safeMethod(item, name)
    local method = item and item[name]
    if type(method) ~= "function" then return nil end

    local ok, value = pcall(method, item)
    return ok and addon.Client.Readable(value) and value or nil
end

local function matchesBattleShout(item, spellName)
    local baseID = safeMethod(item, "GetBaseSpellID")
    if addon.Client.Number(baseID) and addon.Client.SpellName(baseID) == spellName then
        return true
    end

    local info = safeMethod(item, "GetCooldownInfo")
    if type(info) ~= "table" then return false end

    for _, field in ipairs({ "spellID", "overrideSpellID", "overrideTooltipSpellID" }) do
        local spellID = addon.Client.Readable(info[field]) and info[field] or nil
        if addon.Client.Number(spellID) and addon.Client.SpellName(spellID) == spellName then
            return true
        end
    end

    local linked = addon.Client.Readable(info.linkedSpellIDs) and info.linkedSpellIDs or nil
    if type(linked) == "table" then
        for _, spellID in ipairs(linked) do
            if addon.Client.Number(spellID) and addon.Client.SpellName(spellID) == spellName then
                return true
            end
        end
    end

    return false
end
```

The guarded discovery loop has this shape; wrap the pool enumeration in `pcall` and treat an error as `"unavailable"`:

```lua
local viewer = _G.BuffIconCooldownViewer
if not viewer or not viewer.itemFramePool then
    return nil, "unavailable"
end

for item in viewer.itemFramePool:EnumerateActive() do
    if matchesBattleShout(item, spellName) then
        if safeMethod(item, "IsVisible") ~= true then return nil, "hidden" end
        if not addon.Glow.IsPrepared(item) then
            if InCombatLockdown() or not addon.Glow.Prepare(item) then
                return nil, "unprepared"
            end
        end
        return item, "visible"
    end
end
return nil, "not-configured"
```

Add `Glow.IsPrepared(frame)` as `return entries[frame] ~= nil` in the renderer. `CDM.Resolve` uses it before trying to prepare an overlay. Polling at Task 4's discovery interval catches repooling without hooking secure CDM code. `CDM.Prepare(spellName)` iterates all active frames with the same identity check while out of combat and prepares every match; call it on login, CDM data load, and combat exit.

- [ ] **Step 4: Run CDM and foundation tests.**

```sh
lua tests/cdm.lua
lua tests/foundation.lua
```

Expected: PASS.

- [ ] **Step 5: Commit the CDM adapter.**

```sh
git add WarriorAssistForever/WarriorAssistForever.toc WarriorAssistForever/Services/CDM.lua WarriorAssistForever/Services/Glow.lua tests/cdm.lua tests/helpers.lua
git commit -m "feat: resolve Battle Shout CDM buff icon"
```

### Task 4: Movable icon and feature output selection

**Files:** Create `WarriorAssistForever/Services/BattleShoutIcon.lua`, `Features/BattleShoutReminder.lua`, `Bootstrap.lua`, `tests/feature.lua`; modify `Core.lua` and the TOC.

**Interfaces:** `BattleShoutIcon.Initialize/ApplySettings/SetVisible/SetPreview`; `BattleShoutReminder.Initialize/OnAuraUpdate/Refresh/Stop/Status`. `Status()` returns `{ output = "none"|"cdm"|"icon-late"|"icon-missing", cdmStatus = "not-checked"|"visible"|"hidden"|"not-configured"|"unavailable"|"unprepared" }`. `Core.Start()` registers the feature only for Warriors and subscribes to config changes.

- [ ] **Step 1: Write failing feature tests.** Use a manifest loader that skips library entries and injects a glow double. Extend `tests/helpers.lua` to increment `world.combatFrameCreations` when `CreateFrame` runs during `world.combat`. Test present early, exact 10-second boundary, changing lead time against the existing deadline, CDM-visible late, CDM-hidden late, confirmed missing, unknown without a timer, unknown retaining a prior timer, combat exit/entry, another Warrior's refresh, immediate disable/re-enable, non-Warrior gating, and both target and no-target combat. Pin the combat-created CDM frame case:

```lua
world.combat = true
world.time = 170
world.auras = { { name = "Battle Shout", expirationTime = 180, auraInstanceID = 9 } }
world:setCDMItems({ world:newCDMItem(42, 6673, true) })
world:fire("PLAYER_REGEN_DISABLED")

H.equal(addon.BattleShoutReminder:Status().output, "icon-late")
H.equal(addon.BattleShoutIcon.frame:IsVisible(), true)
H.equal(world.combatFrameCreations, 0)
```

Pre-prepare the matching CDM item outside combat in another test and assert output `"cdm"` with the screen icon hidden. Reassign that item to another spell and assert its glow clears before the next item refresh. A missing aura shows `"icon-missing"` only in combat.

- [ ] **Step 2: Verify the red test.**

```sh
lua tests/feature.lua
```

Expected: failure because the icon/feature/bootstrap files are missing.

- [ ] **Step 3: Implement the visual state machine.** Adapt Hunter's `AspectIcon.lua` for a 64×64 movable Battle Shout texture using `Client.SpellTexture(6673)` and saved `iconX/iconY`; preview enables dragging and calls `Config.Set` on drag stop. Render the same configured green glow on the icon for both late and missing states. In `BattleShoutReminder:Refresh()`, reevaluate the aura on world/combat/aura events, then choose exactly one output:

```lua
if not addon.Client.InCombat() or not addon.Config.Get("battleShoutEnabled") then
    output = "none"
elseif status.state == "missing" then
    output = "icon-missing"
elseif status.deadline and GetTime() >= status.deadline - addon.Config.Get("leadSeconds") then
    local item = addon.CDM.Resolve(addon.BattleShoutAura.name)
    output = item and "cdm" or "icon-late"
else
    output = "none"
end
```

Clear the previous CDM glow before using a different pooled frame or selecting icon output. `Bootstrap.lua` registers `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, `PLAYER_LEAVING_WORLD`, `UNIT_AURA` for player, `PLAYER_REGEN_DISABLED/ENABLED`, and `COOLDOWN_VIEWER_DATA_LOADED`. It samples aura on those events. An `OnUpdate` check every 0.1 seconds reaches the lead threshold; CDM discovery every 0.5 seconds handles layout changes. Do not query the aura on every timer tick. Call `CDM.Prepare` on out-of-combat startup, CDM data load, and combat exit. Stop and clear visuals on world exit and on disable. Requery aura on combat entry rather than trusting a precombat state.

- [ ] **Step 4: Run feature and prior tests.**

```sh
lua tests/feature.lua
lua tests/aura.lua
lua tests/cdm.lua
```

Expected: PASS.

- [ ] **Step 5: Commit the feature.**

```sh
git add WarriorAssistForever tests/feature.lua tests/helpers.lua
git commit -m "feat: show CDM and screen Battle Shout reminders"
```

### Task 5: Native settings and safe diagnostics

**Files:** Create `WarriorAssistForever/Services/SettingsWidgets.lua`, `SettingsPanel.lua`, `tests/settings.lua`; modify `Bootstrap.lua` and TOC.

**Interfaces:** `SettingsPanel.Initialize/Open/Refresh`; `BattleShoutIcon.SetPreview(bool)`; `/waf config` opens the panel and `/waf` prints safe diagnostic labels from `BattleShoutAura.Status()`, `CDM.Resolve()`, and `BattleShoutReminder:Status()`.

- [ ] **Step 1: Write failing settings tests.** Double `Settings.RegisterProxySetting`, category registration, and `Settings.OpenToCategory`. Verify one section, default-on checkbox, lead choices 1–60, green color, Move icon preview, immediate disable cleanup, and slash diagnostics that include version, Warrior activation, enabled state, lead, aura state/quality, CDM state, and output without raw secret values. Pin malformed saved data:

```lua
world.env.WarriorAssistForeverDB = {
    leadSeconds = -1, glowColor = "zzyyxxww", iconX = math.huge, iconY = 100000,
}
world:fire("PLAYER_LOGIN")

H.equal(addon.Config.Get("leadSeconds"), 10)
H.equal(addon.Config.Get("glowColor"), "ff00ff00")
H.equal(addon.Config.Get("iconX"), 0)
H.equal(addon.Config.Get("iconY"), -270)
```

- [ ] **Step 2: Verify the red test.**

```sh
lua tests/settings.lua
```

Expected: failure because settings modules are missing.

- [ ] **Step 3: Add the panel and slash output.** Adapt only Checkbox, Dropdown, Color, Section, and Text widgets from Paladin, plus Hunter's Move icon button pattern. Register proxy settings with `WarriorAssistForever_` names. Populate the lead dropdown with numeric values 1–60. Set the native panel title to `Warrior Assist Forever`. `/waf` output uses a bounded status mapping rather than concatenating aura fields:

```lua
local aura = addon.BattleShoutAura.Status()
local feature = addon.BattleShoutReminder:Status()
local remaining = aura.deadline and string.format("%.1fs", math.max(0, aura.deadline - GetTime())) or "unknown"
local warrior = addon.Client.IsWarrior() and "active" or "inactive"
print("Warrior Assist Forever 0.1.0 / client 16001 / Warrior " .. warrior)
print("Enabled: " .. tostring(addon.Config.Get("battleShoutEnabled"))
    .. " / lead: " .. addon.Config.Get("leadSeconds") .. "s")
print("Battle Shout: " .. aura.state .. " / " .. aura.quality .. " / due in " .. remaining)
print("CDM: " .. feature.cdmStatus .. " / output: " .. feature.output)
```

Ensure `deadline` is addon-owned and ordinary before formatting. Disable clears CDM and screen overlays immediately; the Move preview stops when the panel closes. Color changes update active glow without replaying the startup flash.

- [ ] **Step 4: Run settings and feature tests.**

```sh
lua tests/settings.lua
lua tests/feature.lua
```

Expected: PASS.

- [ ] **Step 5: Commit settings.**

```sh
git add WarriorAssistForever tests/settings.lua tests/helpers.lua
git commit -m "feat: configure Battle Shout reminder"
```

### Task 6: Package, document, and verify real library integration

**Files:** Create `scripts/package.py`, `README.md`, `.gitignore`, `tests/integration.lua`; modify test doubles or production modules only for failures found by this gate.

**Interfaces:** `python3 scripts/package.py` builds `dist/WarriorAssistForever-0.1.0.zip` from TOC entries and bundled library license files. The ZIP root contains `WarriorAssistForever/WarriorAssistForever.toc`.

- [ ] **Step 1: Write failing package and renderer integration checks.** `tests/integration.lua` loads the actual bundled LibStub and LibCustomGlow files against frame/animation doubles, then the production Glow service. Exercise start, same-color refresh without reflashing, color change, stop, and reusing a CDM frame after its cooldown ID changes. In `scripts/package.py`, validate each TOC path resolves inside the addon directory before zipping. An explicit archive check is:

```python
with zipfile.ZipFile(destination) as archive:
    names = archive.namelist()
    assert "WarriorAssistForever/WarriorAssistForever.toc" in names
    assert len(names) == len(set(names))
    assert archive.testzip() is None
```

- [ ] **Step 2: Verify the red gate.**

```sh
lua tests/integration.lua
python3 scripts/package.py
```

Expected: integration fixture or package script absent.

- [ ] **Step 3: Complete delivery files.** Adapt Range Assist Forever's manifest-driven `scripts/package.py`, changing `ADDON` and archive name to Warrior. Include all bundled library license/README files. Add `.gitignore` entry `dist/`. Write README sections for installation, `/waf config`, 10-second default lead, CDM-first/screen-fallback behavior, external Warrior buffs, unreadable aura limitations, `/waf` diagnostics, and in-game checks. The README must instruct the player to enable Lua errors, have another Warrior apply/refresh Battle Shout, and report `/waf` status if CDM or aura information differs in the real client.

```sh
lua tests/foundation.lua
lua tests/aura.lua
lua tests/cdm.lua
lua tests/feature.lua
lua tests/settings.lua
lua tests/integration.lua
python3 scripts/package.py
```

- [ ] **Step 4: Verify package contents and clean diff.**

```sh
python3 -m zipfile -l dist/WarriorAssistForever-0.1.0.zip
git diff --check
git status --short
```

Expected: manifest, Lua modules, libraries and licenses in the ZIP; no whitespace errors; only intended files changed.

- [ ] **Step 5: Commit delivery files.**

```sh
git add README.md .gitignore scripts/package.py tests/integration.lua WarriorAssistForever tests/helpers.lua
git commit -m "docs: package and verify Warrior addon"
```

## Self-review checklist for the implementer

- The feature covers readable exact expiration, observed 180-second estimate, confirmed absence, and unknown without an invented absence.
- External Warrior buffs and rank changes are tested with `sourceUnit` other than `player`.
- CDM may filter external buffs; a hidden or unprepared item selects the movable icon. A missing buff always selects that icon in combat.
- All configuration paths and slash diagnostics avoid comparing, formatting, or printing secrets.
- Final local verification includes the real bundled glow library and ZIP bytes. WoW Forever in-game checks remain necessary for CDM and aura API behavior.
