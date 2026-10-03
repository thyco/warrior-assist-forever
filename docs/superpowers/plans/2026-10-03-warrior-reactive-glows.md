# Warrior Reactive Ability Glows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add independent, configurable Overpower and Revenge action-button glows to Warrior Assist Forever, including an Overpower opportunity reminder on the player's Berserker Stance macro.

**Architecture:** A small button selector and stance reader feed a learned-rank readiness service. One feature coordinates two glow owners through the existing prepared LibCustomGlow renderer. Settings and diagnostics expose the selections and safely readable state without changing the Battle Shout feature.

**Tech Stack:** Lua addon for WoW Forever interface 16001, existing LibCustomGlow/LibStub, Lua test doubles in `tests/helpers.lua`, Python ZIP package test.

**Spec:** `docs/superpowers/specs/2026-10-03-warrior-reactive-glows-design.md`

## Global Constraints

- Overpower: Battle Stance needs readable `C_Spell.IsSpellUsable` true and its own cooldown ready; Berserker Stance needs readable `C_SpellActivationOverlay.IsSpellOverlayed` true and its own cooldown ready. Defensive Stance never glows Overpower.
- Revenge: Defensive Stance needs readable spell usability true and its own cooldown ready. Battle and Berserker stances never glow Revenge.
- Both glows can appear in or out of combat and have no explicit target or mouseover condition. The selected button must exist and be visible.
- Each ability has an independent enabled toggle and fixed default action bar/button selection. Enabled defaults true; bar defaults Not selected (`0`); button defaults `1`. Use native proc glow artwork with no new color setting.
- Preserve Battle Shout's current combat-only CDM/screen reminder, saved settings, and editable green glow.
- Resolve learned localized ranks; do not assume rank-one Overpower (`7384`) or Revenge (`6572`) is learned. Unknown/secret/erroring API data means no new glow, never a guessed proc.
- Prepare button overlays and reserve library resources outside combat. No creation of protected-button child frames/effects during combat. Clear owners on disabling, stance changes, hidden/changed buttons, and world exit.
- Follow `AGENTS.md`: separate logical code/test blocks with blank lines; no Java `var` or `@ParameterizedTest` (irrelevant to Lua but project-wide).
- Increment version to `0.2.0`, keep an installable ZIP, and land the verified implementation on local `main` as previously requested. In-game WoW Forever behavior remains an acceptance check, not a local-test claim.

## File map

| File | Responsibility |
| --- | --- |
| `WarriorAssistForever/Services/Client.lua` | Safe boolean and learned spellbook reads. |
| `WarriorAssistForever/Services/Buttons.lua` | Stable default bar/button positions. |
| `WarriorAssistForever/Services/Stance.lua` | Safe Battle/Defensive/Berserker identity. |
| `WarriorAssistForever/Services/ReactiveSpells.lua` | Learned rank catalog, usability/overlay/cooldown evidence. |
| `WarriorAssistForever/Features/ReactiveAbilities.lua` | Independent glow owners, events, polling, cleanup. |
| `WarriorAssistForever/Services/Config.lua` | Six validated saved values. |
| `WarriorAssistForever/Core.lua`, `WarriorAssistForever/WarriorAssistForever.toc` | Warrior-only startup and module order. |
| `WarriorAssistForever/SettingsPanel.lua`, `WarriorAssistForever/Bootstrap.lua` | Controls and safe `/waf` diagnostics. |
| `tests/reactive_foundation.lua`, `tests/reactive_spells.lua`, `tests/reactive_feature.lua`, `tests/settings.lua`, `tests/package.py` | Focused behavior and delivery checks. |
| `README.md` | Player settings, limitations, and in-game acceptance steps. |

## Review Focus

Each item below has a named failing test in its owning task.

1. **Saved data is malformed:** a secret, fractional, out-of-range, or wrong-type bar/button value resets to the documented default rather than selecting an unintended button (Task 1).
2. **Berserker macro is castable but no Overpower proc exists:** no glow appears from macro availability or an unavailable overlay query (Task 2).
3. **Overlay refers to the base rank while a higher rank is learned:** a confirmed base-rank overlay still identifies the learned Overpower opportunity, with an own-cooldown check (Task 2).
4. **Selection changes or a button appears during combat:** the old glow clears; no child frame or library effect is allocated until safe preparation after combat (Task 3).
5. **API outputs become secret or throw after a glow is active:** the glow clears, no Lua error escapes, and diagnostics use `unknown` (Tasks 2–4).

---

### Task 1: Safe settings, stance, spellbook, and button selection

**Files:** Create `WarriorAssistForever/Services/Buttons.lua`, `WarriorAssistForever/Services/Stance.lua`, `tests/reactive_foundation.lua`; modify `WarriorAssistForever/Services/Client.lua`, `WarriorAssistForever/Services/Config.lua`, `WarriorAssistForever/WarriorAssistForever.toc`.

**Interfaces:** `Client.Boolean(value)` returns `true|false|nil`; `Client.PlayerSpells()` returns readable `{ id = number }` records or `{}`. `Buttons.Bars()` returns the eight Hunter-compatible default bar labels; `Buttons.Selected(bar, index)` returns a frame or `nil`; `Buttons.All()` returns existing default button frames. `Stance.Current()` returns `"battle"|"defensive"|"berserker"|"unknown"`. Config keys are `overpowerEnabled`, `overpowerBar`, `overpowerButton`, `revengeEnabled`, `revengeBar`, `revengeButton`.

- [ ] **Step 1: Write the failing foundation tests.** Use `H.new()` from `tests/helpers.lua`; load `Core`, `Config`, `Client`, `Buttons`, and `Stance` directly. Test the exact defaults, persisted valid positions, invalid numeric/string/secret positions, missing buttons, physical button identity across a simulated action-bar page change, all three stance IDs, and nil/secret/throwing stance reads. A core example:

```lua
local H = dofile("tests/helpers.lua")
local world = H.new()
world.env.GetShapeshiftFormID = function() return 19 end
local addon = world:load({ "Core", "Services/Config", "Services/Client",
    "Services/Buttons", "Services/Stance" })

addon.Config.Initialize()
H.equal(addon.Config.Get("overpowerBar"), 0)
H.equal(addon.Config.Get("revengeButton"), 1)
H.equal(addon.Stance.Current(), "berserker")
H.equal(addon.Buttons.Selected(0, 1), nil)
```

- [ ] **Step 2: Verify the tests fail for the missing services/keys.** Run `lua tests/reactive_foundation.lua`; expected failure names the missing `Buttons`/`Stance` service or missing `overpowerBar` default, not a fixture syntax error.

- [ ] **Step 3: Implement the foundation.** Copy Hunter's eight prefix/label mapping into `Buttons.lua`, but return only existing `_G[prefix .. index]` frames. Add the six defaults and key-specific integer bounds in `Config.validValue` (`bar: 0..8`, `button: 1..12`). Add guarded `Client.Boolean` and `Client.PlayerSpells` using the player's `C_SpellBook` bank; wrap client calls in `pcall` and reject secret tables/fields. Use `GetShapeshiftFormID()` under `pcall` in `Stance.Current()`; map `17→battle`, `18→defensive`, `19→berserker`; every other result is `unknown`. Load the two new modules in TOC after `Client.lua`.

Add these exact fields inside the existing `Config.defaults` table; retain its Battle Shout fields:

```lua
overpowerEnabled = true,
overpowerBar = 0,
overpowerButton = 1,
revengeEnabled = true,
revengeBar = 0,
revengeButton = 1,
```

The stance reader is:

```lua
local stanceNames = { [17] = "battle", [18] = "defensive", [19] = "berserker" }
function Stance.Current()
    if type(GetShapeshiftFormID) ~= "function" then return "unknown" end

    local ok, id = pcall(GetShapeshiftFormID)
    if not ok or not addon.Client.Number(id) then return "unknown" end

    return stanceNames[id] or "unknown"
end
```

- [ ] **Step 4: Verify green and regression.** Run `lua tests/reactive_foundation.lua`, then `lua tests/foundation.lua` and `lua tests/settings.lua`; all must exit 0. Check `git diff --check`.
- [ ] **Step 5: Commit the independently tested foundation.** Stage only Task 1 files and commit `feat: add Warrior reactive glow foundations`.

### Task 2: Learned ranks and conservative readiness evidence

**Files:** Create `WarriorAssistForever/Services/ReactiveSpells.lua`, `tests/reactive_spells.lua`; modify `WarriorAssistForever/WarriorAssistForever.toc`.

**Interfaces:** `ReactiveSpells.Rebuild()` refreshes `ids.overpower` and `ids.revenge` arrays from safely readable learned spellbook entries. `ReactiveSpells.Evaluate(kind, mode, cooldownEvent)` returns `{ ready = boolean, learned = boolean, id = number|nil, signal = "usable"|"overlay"|"inactive"|"unknown", cooldown = "ready"|"blocked"|"unknown" }`. `kind` is `"overpower"` or `"revenge"`; `mode` is `"usable"` or `"overlay"`. Invalid kind/mode returns not ready/unknown without throwing. It never reads a target or combat state. Task 3 owns stance gating.

- [ ] **Step 1: Write failing readiness tests.** Load Task 1 services plus `ReactiveSpells` in a fake world with player spellbook entries for rank-one Overpower `7384`, rank-one Revenge `6572`, and a localized higher Overpower rank. Provide `C_Spell.GetSpellInfo`, `C_Spell.IsSpellUsable`, `C_Spell.GetSpellCooldown`, `C_SpellActivationOverlay.IsSpellOverlayed`, and `GetTime` fakes. Cover usable true/false, overlay true/false, higher learned rank, base-ID overlay with learned higher rank, unlearned spell, own cooldown active/expired, GCD-only cooldown, secret/throwing result, and an overlay true with an uncastable Berserker spell. For example:

```lua
local status = addon.ReactiveSpells.Evaluate("overpower", "overlay", false)
H.equal(status.learned, true)
H.equal(status.signal, "overlay")
H.equal(status.cooldown, "ready")
H.equal(status.ready, true)

world.overlay[7384] = false
status = addon.ReactiveSpells.Evaluate("overpower", "overlay", false)
H.equal(status.ready, false)
```

- [ ] **Step 2: Verify red.** Run `lua tests/reactive_spells.lua`; expect a failure at the missing `ReactiveSpells` service or its `Evaluate` behavior.

- [ ] **Step 3: Implement learned-rank evaluation.** Resolve localized names from `C_Spell.GetSpellInfo(7384)` and `(6572)` using protected calls. Match safely readable names against `Client.PlayerSpells()`, deduplicate IDs, and keep kind-specific arrays. For `usable`, require `Client.Boolean(first return of C_Spell.IsSpellUsable(id)) == true`. For `overlay`, query learned ID and the corresponding rank-one seed via `C_SpellActivationOverlay.IsSpellOverlayed`, but only after at least one learned rank is established; require a readable true from either. For every candidate, require an own cooldown that is ready. Treat `isOnGCD == true`, a matching readable global cooldown (`61304`), or `isActive == false` as ready when no own cooldown is present; otherwise validate finite `startTime`/`duration` and compare to `GetTime`. Clear cached GCD-only evidence whenever a cooldown event reports unreadable data, and never keep a prior positive signal across an unreadable query. Return safe status labels and the learned ID; no raw secret value escapes.

Use this guarded call boundary for spell info, usability, overlay, and cooldown queries; branch on the documented `signal` and `cooldown` labels when building the returned table:

```lua
local function read(api, ...)
    if type(api) ~= "function" then return nil end

    local ok, value = pcall(api, ...)
    if ok and addon.Client.Readable(value) then return value end
end
```

- [ ] **Step 4: Verify green and regression.** Run `lua tests/reactive_spells.lua`, `lua tests/reactive_foundation.lua`, `lua tests/foundation.lua`, and `lua tests/aura.lua`; all must exit 0. Check `git diff --check`.
- [ ] **Step 5: Commit the readiness service.** Stage only Task 2 files and commit `feat: detect Warrior reactive opportunities`.

### Task 3: Independent, stance-gated glows without combat or target gates

**Files:** Create `WarriorAssistForever/Features/ReactiveAbilities.lua`, `tests/reactive_feature.lua`; modify `WarriorAssistForever/Core.lua`, `WarriorAssistForever/WarriorAssistForever.toc`, and only the focused test doubles needed in `tests/helpers.lua`.

**Interfaces:** `ReactiveAbilities:Initialize()`, `:Refresh(cooldownEvent)`, `:Stop()`, and `:Status()`; `Status()` returns safe `{ stance, overpower = { ready, signal, cooldown, active }, revenge = { ready, signal, cooldown, active } }`. The feature owns `"overpower"` and `"revenge"` keys in `Glow`, never `"battle-shout"` or `"battle-shout-icon"`.

- [ ] **Step 1: Write failing feature tests.** Add a fixture with two selected visible default buttons, learned spells, stance ID, usability/overlay/cooldowns, and `world.combat=false`. Test Overpower Battle and Berserker, Revenge Defensive, no target/no combat, all wrong stances, stance changes while active, cooldown expiry via tick, hidden/removed/reselected button, feature disable, world exit/entry, a button selected in combat with zero new frame/effect allocation, secret/failing API clearing, shared selected button ownership, and Battle Shout output coexisting. A decisive example:

Dispatch the feature's own registered event frame, since `H.new().fire()` targets the existing Bootstrap handler:

```lua
local function reactiveEvent(world, event, ...)
    local frame = world.addon.ReactiveAbilities.frame
    assert(frame.events[event] == true)
    frame.scripts.OnEvent(frame, event, ...)
end

world.combat = false
world.stanceID = 19
world.usable[7384] = false
world.overlay[7384] = true
reactiveEvent(world, "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 7384)

H.equal(world.glowActive[world.overpowerButton], true)
H.equal(world.glowActive[world.revengeButton], false)
```

- [ ] **Step 2: Verify red.** Run `lua tests/reactive_feature.lua`; expect the missing `ReactiveAbilities` output, not a malformed fixture.

- [ ] **Step 3: Implement the feature and wire startup.** Add definitions with separate owners and settings keys. The mode table is exact: `overpower = { battle = "usable", berserker = "overlay" }`, `revenge = { defensive = "usable" }`. On refresh, prepare only the currently selected existing buttons when `not InCombatLockdown()`. Resolve the stance once, selected button once per ability, and call `ReactiveSpells.Evaluate` only for enabled, supported, visible positions. Clear each previous owner before moving to a new frame; set an owner true only for `result.ready` on a prepared button. Keep at most one 0.1-second OnUpdate poller while either feature is enabled with a selected bar, regardless of combat; stop polling when neither is active. Handle `UPDATE_SHAPESHIFT_FORM`, `SPELL_UPDATE_USABLE`, `SPELL_UPDATE_COOLDOWN`, overlay glow show/hide, `SPELLS_CHANGED`, `PLAYER_TALENT_UPDATE`, `SPELL_DATA_LOAD_RESULT`, `PLAYER_ENTERING_WORLD`, `PLAYER_LEAVING_WORLD`, and action-bar page/slot changes. On world exit clear both owners and stop polling; on entry rebuild spells and re-evaluate. Call `ReactiveAbilities:Initialize()` in `Core:Start()` after Warrior gating; call `:Refresh()` from the existing Config subscription. Load its TOC entry before `SettingsPanel.lua`/`Bootstrap.lua`.

```lua
local definitions = {
    overpower = { owner = "overpower", enabled = "overpowerEnabled",
        bar = "overpowerBar", button = "overpowerButton",
        modes = { battle = "usable", berserker = "overlay" } },
    revenge = { owner = "revenge", enabled = "revengeEnabled",
        bar = "revengeBar", button = "revengeButton",
        modes = { defensive = "usable" } },
}
```

- [ ] **Step 4: Verify green and regressions.** Run `lua tests/reactive_feature.lua`, all Task 1–2 tests, and the six original Lua suites listed in `README.md`; all must exit 0. Inspect `world.combatFrameCreations == 0` after combat-only transitions. Check `git diff --check`.
- [ ] **Step 5: Commit the runtime feature.** Stage only Task 3 files and commit `feat: glow Overpower and Revenge by stance`.

### Task 4: Settings UI, diagnostics, release, and in-game instructions

**Files:** Modify `WarriorAssistForever/SettingsPanel.lua`, `WarriorAssistForever/Bootstrap.lua`, `WarriorAssistForever/WarriorAssistForever.toc`, `README.md`, `tests/settings.lua`, `tests/package.py`; add focused diagnostics assertions to `tests/reactive_feature.lua` if needed. `scripts/package.py` already derives ZIP name from the TOC and should not need a code change.

**Interfaces:** `/waf config` exposes separate Overpower/Revenge sections with enable, bar, and button controls. `/waf` adds safe stance/ready/evidence/selection/output labels. The new ZIP name is `dist/WarriorAssistForever-0.2.0.zip`.

- [ ] **Step 1: Write failing UI and release checks.** In `tests/settings.lua`, assert six new registered settings and controls have correct defaults and independent persistence; select different bars/buttons and check saved DB values. In `tests/reactive_feature.lua`, send `/waf` and assert safe labels for Berserker overlay readiness and unknown/secret evidence without printing a secret value. Change the package fixture's expected path to `WarriorAssistForever-0.2.0.zip` and assert the archive contains `Features/ReactiveAbilities.lua`, new services, and the Warrior icon. Run these checks to observe failure on the old panel/version.

```lua
H.equal(world.settings.WarriorAssistForever_overpowerBar:GetValue(), 0)
H.equal(world.settings.WarriorAssistForever_revengeBar:GetValue(), 0)
world.settings.WarriorAssistForever_overpowerBar:SetValue(3)
world.settings.WarriorAssistForever_revengeBar:SetValue(5)
H.equal(world.env.WarriorAssistForeverDB.overpowerBar, 3)
H.equal(world.env.WarriorAssistForeverDB.revengeBar, 5)
```

- [ ] **Step 2: Verify red.** Run `lua tests/settings.lua`, `lua tests/reactive_feature.lua`, and `python3 tests/package.py`; each new assertion must fail for the missing UI/diagnostics/version, not test setup.

- [ ] **Step 3: Implement UI, diagnostics, and delivery text.** Add two settings sections below Battle Shout. For each, call `Settings.RegisterProxySetting` through the panel's existing `registerSetting` helper, then `widgets.Checkbox` and two `widgets.Dropdown` controls. Bar options are `Not selected` (`0`) plus `Buttons.Bars()`, and button options are 1–12. Increase scroll content height so both groups are reachable. Extend `Bootstrap.diagnostics()` using a safe `label` allowlist for stance, signal, cooldown and active output; do not print restricted IDs or raw API returns. Set TOC `## Version: 0.2.0` and update Notes to mention reactive glows. Update `README.md` with independent selections, macro behavior, out-of-combat/no-target behavior, client signal limitations, `/waf` output, and the concrete in-game acceptance sequence from the spec. Update hardcoded ZIP name in `tests/package.py`; the package script itself reads the new version.

Construct the bar choices as follows and make a 1–12 button choice list with the same `{ value, label }` shape. Bind the six exact keys from Task 1 to their own controls and store each control in `panel.controls[key]` so the existing `Refresh()` loop updates it:

```lua
local bars = { { value = 0, label = "Not selected" } }
for index, name in ipairs(addon.Buttons.Bars()) do
    bars[#bars + 1] = { value = index, label = name }
end

local buttons = {}
for index = 1, 12 do
    buttons[#buttons + 1] = { value = index, label = "Button " .. index }
end
```

- [ ] **Step 4: Run the full gate.** Run `lua tests/foundation.lua`, `lua tests/aura.lua`, `lua tests/cdm.lua`, `lua tests/feature.lua`, `lua tests/settings.lua`, `lua tests/integration.lua`, `lua tests/reactive_foundation.lua`, `lua tests/reactive_spells.lua`, `lua tests/reactive_feature.lua`, `python3 tests/package.py`, `python3 scripts/package.py`, `python3 -m zipfile -l dist/WarriorAssistForever-0.2.0.zip`, and `git diff --check`. Check the ZIP has one `WarriorAssistForever/` root, all TOC files, both library notices, and `Media/Warrior.tga`. Confirm no test or package failures.
- [ ] **Step 5: Review and integrate.** Request an independent read-only code review against the spec, fix material findings, rerun the full gate, then commit Task 4 files. If work was implemented in an isolated worktree, merge its verified branch to local `main` and rerun the full gate on `main`. Do not push unless separately requested. Report commit SHA, ZIP path, passed local checks, and the remaining in-game validation.
