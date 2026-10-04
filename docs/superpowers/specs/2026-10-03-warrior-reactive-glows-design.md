# Warrior Assist Forever: Overpower and Revenge glows

Update for v0.4.4 (2026-10-04): Overpower now glows during its own cooldown
while its Battle Stance usability or Berserker Stance overlay opportunity is
active. The cooldown requirements below record the original design. Revenge
still requires its own cooldown to be ready. See `README.md` for current behavior.

## Purpose and scope

Add two independent reactive ability glows to the existing Warrior Assist Forever addon. The player chooses one fixed default action bar/button position for Overpower and another for Revenge. The Overpower position may contain the player's macro that switches from Berserker Stance to Battle Stance and casts Overpower. A glow marks a supported ability opportunity; it does not cast a spell, change stance, choose a target, modify bindings, or change the action button's protected attributes. Battle Shout's CDM and screen icon reminder keeps its current behavior.

These glows can appear in or out of combat and never require a target or mouseover. This is separate from Battle Shout, which remains combat only. The feature runs only on Warriors and targets the WoW Forever interface 16001 already used by the addon.

## Visual and readiness behavior

Overpower glows only in Battle Stance or Berserker Stance. In Battle Stance, a learned Overpower rank must be reported usable by the client and off its own cooldown. In Berserker Stance, where Overpower itself cannot be cast, the client must report an Overpower spell activation overlay/proc and the learned ability must be off its own cooldown. The Berserker glow tells the player to press their selected stance-switch macro. It does not require the spell to be castable before switching stance. An inactive or unreadable proc signal produces no Berserker glow.

Revenge glows only in Defensive Stance when a learned Revenge rank is reported usable and off its own cooldown. Battle and Berserker stances suppress Revenge, and Defensive Stance suppresses Overpower. Neither feature tests target existence, range, facing, or combat state. The selected button must exist and be visible. An unselected, hidden, or unavailable button produces no glow. A global cooldown alone does not suppress a genuine reactive opportunity; an active ability-specific cooldown does.

Each ability owns its glow independently. Clearing an opportunity, changing stance or button selection, disabling a feature, leaving the world, or losing usable evidence removes the corresponding glow immediately. If both abilities select the same physical button, the existing owner-aware glow service arbitrates, though stance rules normally make their opportunities mutually exclusive. The native proc glow artwork is used without a new color setting; Battle Shout keeps its editable green glow. An activation flashes once and then loops without repeatedly restarting during refreshes.

## Configuration and diagnostics

The AddOns settings panel gains an Overpower group and a Revenge group. Each has its own enabled toggle, default action bar selector, and button selector, following Hunter Assist Forever's Mongoose Bite controls. Both toggles default to enabled, but each action bar defaults to Not selected, so the addon does not highlight an arbitrary button before the player chooses one. Buttons are 1 through 12 on the supported default bars. A selection identifies a physical button position, including when the bar's page changes; the addon does not inspect or rewrite the spell or macro in that slot. Saved preferences apply immediately and survive reloads.

`/waf` retains Battle Shout diagnostics and adds concise, safe labels for current stance, learned Overpower/Revenge ranks, readiness evidence, selected positions, and whether each glow is active. Restricted or failing API results are reported as unknown labels rather than printed or compared directly.

## Architecture and data flow

Add a default-button selection service based on the Hunter addon's stable bar prefixes. Add a reactive-spell service that resolves Overpower and Revenge rank-one spell names (7384 and 6572), scans safely readable learned player spellbook entries, and retains the learned ranks by localized name. Rebuild the catalog on login, spellbook/talent changes, and spell-data completion; never assume a seed rank is learned. An unknown catalog leaves the relevant ability dark.

A stance reader uses the client's form/stance signal to identify Battle, Defensive, and Berserker Stance. Unknown, secret, or failing stance results suppress both glows. A reactive feature coordinates the two owners: it reads the current stance, selected visible buttons, learned ranks, spell usability, spell activation overlay state, and ability cooldown. All client data is guarded before comparison or arithmetic. The feature responds promptly to stance changes, spell usability/cooldown and overlay events, world transitions, spellbook changes, and settings changes. While either ability is enabled and has a selected button, a small periodic refresh catches expiring cooldowns or opportunities even if an event is missed. No target event is required.

Reuse the existing `Glow` service and bundled LibCustomGlow. Prepare selected default buttons and reserve their glow resources outside combat, as the Battle Shout CDM feature does. Never create overlay frames or allocate library effects on a protected button during combat. If a newly available button cannot be prepared safely until combat ends, leave it dark and prepare it on the next safe update. Keep the two glow owners separate from Battle Shout's owners so one feature cannot clear another feature's output. The addon does not require Hunter Assist Forever at runtime.

## Feasibility and limits

WoW Forever's generated API documentation includes `C_SpellActivationOverlay.IsSpellOverlayed` and spell activation show/hide events. It also includes `C_Spell.IsSpellUsable` and `C_Spell.GetSpellCooldown`; the cooldown result may be restricted. This establishes an available proc query, but does not prove the client emits an Overpower overlay in Berserker Stance or exposes all readiness data during combat. The feature must fail closed on secret, nil, malformed, or erroring values and make missing evidence visible in diagnostics. It must not invent a dodge/block/parry timer from combat text or infer an Overpower opportunity merely because the stance-switch macro is usable.

The client may internally make usability depend on target state even though this addon has no target gate. In-game acceptance must confirm that a visible proc still drives the intended glow with no current target. If the client does not expose an Overpower overlay in Berserker Stance, the addon cannot promise that glow from the approved signals; report the observed API state and revisit the detection method with the player instead of displaying false prompts.

Primary client source references:

- [Forever spell activation overlay API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellActivationOverlayDocumentation.lua)
- [Forever spell usability and cooldown API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua)
- [Forever spellbook API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua)
- [Forever stance bar source](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ActionBar/Shared/StanceBar.lua)

## Verification and delivery

Write Lua tests before implementation for defaults and saved selections; class gating; learned and unlearned localized ranks; Battle, Berserker, Defensive, and unknown stance transitions; Overpower usability in Battle versus overlay opportunity in Berserker; Revenge usability in Defensive; true and false ability cooldowns versus GCD-only cooldown; no target and out-of-combat activation; hidden, absent, repaged, changed, and shared selected buttons; restricted/throwing API calls; immediate disable and world-exit cleanup; no combat frame/effect allocation; and coexistence with Battle Shout. Run the full existing Lua suites and package integrity test, then build and inspect the installable ZIP. Update the README with settings, behavior, limitations, and in-game checks. Increment the addon version for this new feature and commit the completed implementation to main, following the user's existing preference.

In WoW Forever, test a real Overpower opportunity in Battle Stance and while a Berserker Stance macro is selected; confirm the overlay query and displayed glow agree after a dodge or Bloodthrill proc. Test Revenge after block, dodge, or parry in Defensive Stance. Repeat with no current target and just after leaving combat, then check ability cooldown, insufficient rage, stance changes, action bar paging, reload, and `/waf` diagnostics. Enable Lua errors during acceptance. Local mocks cannot establish the game's proc overlay behavior, targetless usability, protected-frame behavior, or actual glow rendering.

## Design choice

Use the client's proc overlay signal for the Berserker Overpower opportunity, with learned-spell and cooldown checks, because ordinary usability describes castability and Overpower is Battle Stance only. Use Hunter's usability/cooldown pattern in the stances where each ability can be cast. Separate selected buttons make the two reminders useful on different action bar positions. Combat-log timing would be speculative under Forever's combat-data restrictions and would miss or misattribute some opportunities; it is excluded.
