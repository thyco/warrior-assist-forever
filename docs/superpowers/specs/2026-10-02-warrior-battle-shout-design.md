# Warrior Assist Forever: Battle Shout reminder design

## Purpose and scope

Build a standalone WoW Forever addon in the existing `warrior-assist-forever` repository. Its first feature reminds a Warrior to refresh Battle Shout. It tracks the buff on the player regardless of which Warrior applied it. The preferred reminder is a green animated proc glow on Battle Shout's tracked buff icon in Blizzard's Cooldown Manager (CDM). A movable Battle Shout screen icon supplies the reminder when CDM's icon is unavailable and whenever the buff is confirmed missing. The addon has no runtime dependency on the Paladin, Hunter, or Range addons.

Feature processing runs only for Warriors. Neither a target nor a mouseover is required. All reminders are combat only. The addon does not cast spells, change key bindings, alter CDM configuration, or modify protected action attributes. The initial version targets the WoW Forever interface used by the sibling addons (16001), subject to in-client validation.

## Buff state and timing

The player's Battle Shout aura is the source of truth. Identify the buff by its localized spell name across ranks, without restricting `sourceUnit` to the player. At login, reload, and `UNIT_AURA` updates for `player`, query the current helpful aura. A readable lookup that finds the buff establishes **present**. A complete, readable enumeration of the player's helpful auras that finds no Battle Shout establishes **missing**. An errored, secret, incomplete, or unreadable result is **unknown**, not missing. On an update that can be safely identified as an application or refresh, update the observed timing even when the caster is another Warrior.

When the aura supplies a readable expiration time, use that expiration as the reminder deadline. If the buff application or refresh is observed but its expiration cannot be read, start a 180-second estimate from that observation. The reminder becomes due when the remaining time is at or below the configured lead time, 10 seconds by default. A confirmed refresh replaces the previous deadline; a confirmed removal overrides the timer immediately. Changing the lead time recalculates the threshold against the same expiration or observed application time. When an existing buff has no readable expiration after login or reload and no application is observed, its timing is unknown until a later readable update; it is not treated as due.

If an aura query later becomes restricted, retain a previously established deadline as an **estimated** late reminder, but do not infer that the buff is missing. An unknown result clears any prior missing display until absence is confirmed again. An unknown state with no deadline produces no reminder. Diagnostics distinguish exact aura timing, an observed 180-second estimate, confirmed missing, and unknown. This behavior avoids a false missing warning while preserving a useful timer when the client hides aura details after they were observed.

## Visual behavior

While in combat with a due deadline from a currently readable buff or a previously observed buff whose later state is unknown, find Battle Shout's configured CDM Tracked Buffs item. If its icon frame is visible and usable, show the configured green proc glow on an addon-owned overlay attached to that frame. If the item is absent, hidden, or cannot be prepared safely, show the movable Battle Shout screen icon with the same glow instead. Never show both late reminders at once. Once the buff is confirmed missing, show the screen icon with its glow regardless of CDM visibility. A confirmed application or refresh hides the missing warning and reevaluates the new deadline. A present buff with more than the lead time remaining hides both reminders.

Leaving combat hides all reminders immediately without discarding known aura timing. Re-entering combat reevaluates the current buff and deadline. No target or mouseover state affects visibility. The proc glow flashes once on activation and then loops, following the Paladin seal glow. The screen icon follows Hunter Assist Forever's aspect icon pattern: a 64-by-64 Battle Shout texture on a movable, noninteractive frame, positioned at a saved screen offset. Its Move icon preview allows repositioning outside combat.

CDM uses pooled item frames. Resolve the Battle Shout item by its CDM cooldown/spell identity, not its screen position or icon texture, and rediscover it after CDM data or layout changes. Prepare addon overlays outside combat; a newly created CDM frame that cannot be prepared during combat uses the screen icon fallback. Clearing, disabling, hiding, or repooling a CDM item releases the old glow. The feature does not change CDM's own cooldown display or visibility setting.

## Settings and diagnostics

`/waf config` opens a native AddOns settings panel with one Battle Shout group. It contains an enable toggle (on by default), lead-time control (integer seconds from 1 through 60, default 10), a glow color picker (green `#00FF00` by default), and a Move icon preview for the fallback/missing screen icon. The old action bar and button selectors are removed from the design. Settings, including icon position, are saved account wide and apply immediately. Disabling the feature clears both visual outputs while aura observation can continue for prompt re-enabling.

`/waf` prints concise diagnostics: addon/client version, Warrior activation, enabled state, configured lead time, aura state and timing quality, CDM item found/visible state, and selected visual output. It prints safe status labels rather than restricted aura values or raw errors.

## Architecture and data flow

Use a private Lua addon namespace and a TOC that loads `Core`, focused services, the Battle Shout feature, settings panel, and bootstrap in dependency order. Adapt only the useful sibling components: Paladin's config validation, timer and LibCustomGlow renderer; Hunter's movable aspect icon and preview; and the CDM frame integration needed here. Bundle LibCustomGlow and its license files. Keep aura interpretation, CDM discovery, icon rendering, and settings in separate modules with clear interfaces.

At login, initialize settings and the icon, then start the feature only for Warriors. Refresh on player aura changes, world entry, combat transitions, settings changes, and CDM data/layout changes. A lightweight update tick checks an established deadline while in combat. Aura state drives the feature; self-cast events are not the authority. Read and validate ordinary aura values before arithmetic, comparisons, diagnostics, or table keys. Prepare and release glow overlays without changing protected frames' action attributes.

## Feasibility and limitations

The Forever source defines `BuffIconCooldownViewer` with pooled tracked-buff item frames. This supports attaching an addon-owned overlay to a discovered visible item, but the final rendering and combat behavior require in-game validation. The CDM tracked-buff aura lookup requests `HELPFUL|PLAYER` for the player, so its icon may hide for Battle Shout applied by another Warrior. That is an inference from the source, not a verified in-game result; the screen icon is the approved late fallback. The aura API marks relevant lookups as requiring a nonsecret aura, so combat readability must also be tested. Unknown results do not become false missing warnings. If this client never exposes sufficient information for an externally applied Battle Shout in combat, that part of the requirement cannot be guaranteed without a client-supported signal; `/waf` must make the limitation visible.

The estimated path assumes a 180-second duration from a safely observed application or refresh. It cannot precisely recover the remaining time for a buff already present after reload when expiration is unreadable, or for an unreadable refresh. When readable, actual expiration and removal supersede the estimate. The addon does not infer missing from a CDM item hiding, because CDM visibility can depend on its own settings and caster filter.

Primary source references:

- [WoW Forever player aura API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua)
- [WoW Forever CDM item data and aura lookup](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewerItemData.lua)
- [WoW Forever CDM frame lifecycle](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua)
- [WoW Forever CDM buff icon frames](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.xml)

## Verification and delivery

Create Lua tests around the production modules and TOC. Cover Warrior gating; default and saved settings; buffs from self and another Warrior across ranks; application, refresh, removal and expiration; exact lead-time boundaries; lead-time changes against an existing deadline; readable expiration versus a 180-second estimate; reload with readable, unreadable, missing and unknown auras; restricted or failing API calls; combat-only/no-target behavior; CDM frame discovery, hiding, repooling and overlay cleanup; late screen fallback; confirmed-missing screen icon; and immediate disable/re-enable. Include a manifest-driven package script and README with install, settings, limitations, and in-game acceptance steps.

In WoW Forever, verify `/waf` diagnostics and visuals with self-cast and externally applied Battle Shout, both outside and inside combat. Check CDM icon visibility under an external cast, whether aura expiration and removal are readable in combat, the screen fallback when CDM hides, missing-buff display, glow attachment after CDM layout changes, and safe behavior during reload and combat. Local tests cannot establish those client behaviors.

## Design choice

The selected approach is CDM first, with one independent movable screen icon for late fallback and confirmed absence. A CDM-only reminder could disappear for externally applied Battle Shout because CDM may hide that item. A screen-icon-only reminder would omit the requested CDM glow. The combined approach satisfies the desired visual placement whenever the client makes it available and keeps a visible combat reminder when CDM does not.
