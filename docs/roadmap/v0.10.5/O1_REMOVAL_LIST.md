# v0.10.5 O1: the removal list (DRAFT, read-only)

Built from the checkout at `77a99c7b` (branch `worktree-agent-a0723e9d8eac8b8fc`), 2026-11-01, by reading data and code.
**Nothing was run in Godot.** Pool sizes below are counted from the data with the survey's rules, not measured:
`test_card_pool_reach.gd` is `NOT YET RUN` for this list.

Scope as the lead asked: the owner's D69 (unused cards), plus two owner decisions from 2026-11-01:
- "The combos can go away yeah, that's old": every combo in `data/combos/`. `element_pairs.tres` is not a combo and stays (§6).
- "Yes, cut the 5": the 5 flat curses (§7).

## 1. How "reachable" was decided

There is one switch, and every offer path reads it. It is **`data/wand/migration.tres` `old_ids`** (60 ids):
- `WandCompiler.retire_items` (src/application/wand_compiler.gd:68-73) sets `ItemTable.retired` for every compiled
  item in `old_ids`. `ContentCompiler.compile_items` calls it (src/application/content_compiler.gd:522-526).
- `WandCompiler.retire_abilities` (wand_compiler.gd:77-84) does the same for abilities. `Abilities.can_take` refuses
  retired ones (src/sim/abilities/abilities.gd:84-85).
- `ItemPool.usable` returns false for a retired item (src/sim/items/item_pool.gd:93-94). `ItemPool.available`
  (item_pool.gd:67-80) is the one draw source for:
  - altars and chests (`Offers.draw`);
  - the boss altar's card slot and mods (src/sim/abilities/offers.gd:197-235);
  - legendary cards (offers.gd:250-256) and boss upgrades (offers.gd:241-246);
  - the shop, events (`ev.roll_card`) and cores (stolen cores, `core_theft.gd`).

  So `retired` closes every run path. The class doc says so: src/content/defs/wand_migration_definition.gd:5-7.
- `data/legendary/boss.tres` names stat cards only (`mods = []`), plus card categories `advanced` and `trigger`
  drawn through `ItemPool.available`. So it adds no extra reach.
- `data/rewards/pacing.tres` holds weights by category only. It names no ids.
- Other gates in `ItemPool.usable` (item_pool.gd:90-106): requires_heat (runs enable Heat), requires_utility (aegis
  gives guard, which covers Bulwark), requires_ability (only blink and aegis are live, and every requires_ability
  item is retired anyway), requires_weapon, and `AttackSlots.usable` (src/sim/*/attack_slots.gd:138-152).
  - I checked every live Gun card against `data/wand/attack_slots.tres`. Each form card has a row: laser, void,
    lance, rune_explosion, glaive, seekers, wave, wisps.
  - Every live Gun secondary, pattern and element card is in the `orbs` row's allowed list.
  - Blade has no form row, so it is always compatible. No live card is shut out.
- Meta: `locked_items` (the Void before a Purple Portal) locks only a live card. Hub unlocks name no other card.
- The Codex hides retired ids (src/application/codex_catalog.gd:152-158).
- Combos (`data/combos`) are reachable only if both halves can be held (§6).
- The reference tool is `tests/support/card_pool_survey.gd:76-110` (the pool rule: no retired, no LEGENDARY, the
  weapon matches).

**Result.** A card resource is unreachable exactly when it is in `old_ids`, or it is a modifier or combo that only
such cards reference.

**Count by the survey rule (computed, not run):**
- Blade = 3 abilities + 18 stat cards + 20 Blade cards + 18 shared cards = **59**.
- Gun = 3 + 18 + 24 + 18 = **63**.
- Chain Blast is the one live LEGENDARY. It is reachable through the boss chance, and the survey doesn't count it.
- `POOL_MAX` is 69 today. The removal changes none of these counts, because retired cards are already out of the pool.

## 2. Removable: the 60 retired card ids (54 item+modifier pairs, 6 abilities, plus 1 extra modifier)

The extra modifier is `data/modifiers/frost_nova.tres`. Only the retired Frost Nova ability references it.

The "becomes" column is the migration row. Today an old save turns a held card into that card, or refunds it as
shards when the target is empty. The build half must keep this mapping (§5).

Other data that names these ids, to clean up:
- `data/wardrobe/affinity_{ember,venom,storm,astral}.tres`: favoured_cards / disfavoured_cards. They name
  cinder_shot, ember_edge, ember_trail, inferno_core, shared_explosive, glacial_edge, shatter, overcharge,
  static_chain, conductor, shock_circles, aftershock, tempest_core and gravity_well.
- `data/wand/wand.tres`: lines 13 and 16 name shared_explosive, line 18 names gun_charge.
- `data/abilities/{arc_field,flame_trail,frost_nova}.tres`: `engine_item` names retired items. These files go too.
- `data/audio/cues/{arc_field,flame_trail,frost_nova}.tres` and their entries in `assets/audio/manifest.json`.
- `data/combos/*`: all combos go (§6).

| # | id | files | kind | why unreachable | old save becomes (Blade / Gun) | src refs (file:line; scripts/ excluded) | risk |
|---|---|---|---|---|---|---|---|
| 0 | long_edge | data/items/long_edge.tres + data/modifiers/long_edge.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | wide_arc / refund | src/presentation/hud/card_frames.gd:62 src/presentation/hud/item_icons.gd:13 src/presentation/hud/item_icons.gd:58 src/presentation/theme/element_glyphs.gd:85 src/presentation/world_view/item_looks.gd:28 | low |
| 1 | twin_arc | data/items/twin_arc.tres + data/modifiers/twin_arc.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | double_slash / refund | src/presentation/hud/card_frames.gd:77 src/presentation/hud/item_icons.gd:14 src/presentation/hud/item_icons.gd:64 src/presentation/theme/element_glyphs.gd:96 src/presentation/world_view/item_looks.gd:29 src/sim/items/item_effects.gd:15 | low |
| 2 | ember_edge | data/items/ember_edge.tres + data/modifiers/ember_edge.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | ember_core / ember_core | src/presentation/hud/card_frames.gd:56 src/presentation/hud/item_icons.gd:15 src/presentation/hud/item_icons.gd:69 src/presentation/theme/element_glyphs.gd:39 src/presentation/world_view/item_looks.gd:30 src/sim/items/item_effects.gd:16 | low |
| 3 | splinter_shot | data/items/splinter_shot.tres + data/modifiers/splinter_shot.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | refund / gun_twin | src/presentation/hud/card_frames.gd:72 src/presentation/hud/item_icons.gd:16 src/presentation/hud/item_icons.gd:91 src/presentation/world_view/item_looks.gd:31 | low |
| 4 | rapid_coil | data/items/rapid_coil.tres + data/modifiers/rapid_coil.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | refund / gun_rapid_fire | src/presentation/hud/card_frames.gd:68 src/presentation/hud/item_icons.gd:17 src/presentation/hud/item_icons.gd:98 src/presentation/world_view/item_looks.gd:32 | low |
| 5 | ricochet_core | data/items/ricochet_core.tres + data/modifiers/ricochet_core.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | refund / gun_ricochet | src/presentation/hud/card_frames.gd:70 src/presentation/hud/item_icons.gd:18 src/presentation/hud/item_icons.gd:103 src/presentation/world_view/item_looks.gd:33 | low |
| 6 | overcharge | data/items/overcharge.tres + data/modifiers/overcharge.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | finisher_plus / refund | src/presentation/hud/card_frames.gd:65 src/presentation/hud/item_icons.gd:20 src/presentation/hud/item_icons.gd:116 src/presentation/theme/element_glyphs.gd:89 src/presentation/world_view/item_looks.gd:35 src/sim/items/item_effects.gd:18 | low |
| 7 | static_chain | data/items/static_chain.tres + data/modifiers/static_chain.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | storm_core / storm_core | src/presentation/hud/card_frames.gd:73 src/presentation/hud/item_icons.gd:22 src/presentation/hud/item_icons.gd:136 src/presentation/theme/element_glyphs.gd:53 src/presentation/world_view/item_looks.gd:37 src/sim/items/item_procs.gd:9 | low |
| 8 | cinder_shot | data/items/cinder_shot.tres + data/modifiers/cinder_shot.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | ember_core / ember_core | src/presentation/hud/card_frames.gd:52 src/presentation/hud/item_icons.gd:29 src/presentation/hud/item_icons.gd:214 src/presentation/theme/element_glyphs.gd:36 src/presentation/world_view/item_looks.gd:44 src/sim/items/engines.gd:21 | low |
| 9 | conductor | data/items/conductor.tres + data/modifiers/conductor.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | storm_core / storm_core | src/presentation/hud/card_frames.gd:55 src/presentation/hud/item_icons.gd:31 src/presentation/hud/item_icons.gd:224 src/presentation/theme/element_glyphs.gd:37 src/presentation/world_view/item_looks.gd:46 | low |
| 10 | serrated_edge | data/items/serrated_edge.tres + data/modifiers/serrated_edge.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | shared_bleed / shared_bleed | src/presentation/hud/card_frames.gd:71 src/presentation/hud/item_icons.gd:32 src/presentation/hud/item_icons.gd:240 src/presentation/theme/element_glyphs.gd:49 src/presentation/world_view/item_looks.gd:47 | low |
| 11 | barbed_bolts | data/items/barbed_bolts.tres + data/modifiers/barbed_bolts.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | shared_bleed / shared_bleed | src/presentation/hud/card_frames.gd:50 src/presentation/hud/item_icons.gd:33 src/presentation/hud/item_icons.gd:248 src/presentation/theme/element_glyphs.gd:34 src/presentation/world_view/item_looks.gd:48 | low |
| 12 | glacial_edge | data/items/glacial_edge.tres + data/modifiers/glacial_edge.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | frost_core / frost_core | src/presentation/hud/card_frames.gd:59 src/presentation/hud/item_icons.gd:34 src/presentation/hud/item_icons.gd:257 src/presentation/theme/element_glyphs.gd:43 src/presentation/world_view/item_looks.gd:49 | low |
| 13 | cluster_payload | data/items/cluster_payload.tres + data/modifiers/cluster_payload.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | ember_core / gun_mine | src/presentation/hud/card_frames.gd:53 src/presentation/hud/card_pool_icons.gd:18 src/presentation/hud/card_pool_icons.gd:117 src/presentation/hud/item_icons.gd:40 src/presentation/world_view/item_looks.gd:55 src/sim/abilities/ability_mods.gd:16 | low |
| 14 | overclocked_drone | data/items/overclocked_drone.tres + data/modifiers/overclocked_drone.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | refund / refund | src/presentation/hud/card_frames.gd:66 src/presentation/hud/card_pool_icons.gd:19 src/presentation/hud/card_pool_icons.gd:128 src/presentation/hud/item_icons.gd:41 src/presentation/world_view/item_looks.gd:56 | low |
| 15 | razor_orbit | data/items/razor_orbit.tres + data/modifiers/razor_orbit.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | shared_bleed / shared_bleed | src/presentation/hud/card_frames.gd:69 src/presentation/hud/card_pool_icons.gd:20 src/presentation/hud/card_pool_icons.gd:160 src/presentation/hud/item_icons.gd:42 src/presentation/theme/element_glyphs.gd:48 src/presentation/world_view/item_looks.gd:57 | low |
| 16 | afterimage | data/items/afterimage.tres + data/modifiers/afterimage.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | refund / refund | src/presentation/hud/card_frames.gd:49 src/presentation/hud/card_pool_icons.gd:21 src/presentation/hud/card_pool_icons.gd:175 src/presentation/hud/item_icons.gd:43 src/presentation/world_view/ability_visuals.gd:106 src/presentation/world_view/item_looks.gd:58 src/sim/abilities/ability_mods.gd:17 | medium: icons/looks/kind-specific sim code |
| 17 | edge_rounds | data/items/edge_rounds.tres + data/modifiers/edge_rounds.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | refund / refund | src/presentation/hud/card_frames.gd:89 | low |
| 18 | shock_circles | data/items/shock_circles.tres + data/modifiers/shock_circles.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | refund / refund | src/presentation/hud/card_frames.gd:105 src/presentation/theme/element_glyphs.gd:52 | low |
| 19 | twin_cast | data/items/twin_cast.tres + data/modifiers/twin_cast.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | double_slash / gun_echo | src/presentation/hud/card_frames.gd:110 src/presentation/theme/element_glyphs.gd:97 | low |
| 20 | rearguard | data/items/rearguard.tres + data/modifiers/rearguard.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | refund / gun_backfire | src/presentation/hud/card_frames.gd:101 src/presentation/theme/element_glyphs.gd:91 | low |
| 21 | shatter | data/items/shatter.tres + data/modifiers/shatter.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | refund / refund | src/presentation/hud/card_frames.gd:104 (other hits are the status/loop word) | low |
| 22 | aftershock | data/items/aftershock.tres + data/modifiers/aftershock.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | ember_core / ember_core | src/presentation/hud/card_frames.gd:82 | low |
| 23 | seeker | data/items/seeker.tres + data/modifiers/seeker.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | refund / gun_homing | src/presentation/hud/card_frames.gd:103 src/presentation/theme/element_glyphs.gd:93 | low |
| 24 | phase_dash | data/items/phase_dash.tres + data/modifiers/phase_dash.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | refund / refund | src/presentation/hud/card_frames.gd:100 src/presentation/theme/element_glyphs.gd:47 | low |
| 25 | ember_trail | data/items/ember_trail.tres + data/modifiers/ember_trail.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | refund / refund | src/presentation/hud/card_frames.gd:91 src/presentation/theme/element_glyphs.gd:40 | low |
| 26 | aether_shell | data/items/aether_shell.tres + data/modifiers/aether_shell.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | refund / refund | src/presentation/hud/card_frames.gd:81 src/sim/combat/modifier_runtime.gd:257 | low |
| 27 | ascension | data/items/ascension.tres + data/modifiers/ascension.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | refund / gun_lance | src/presentation/hud/card_frames.gd:83 (other hits are the status/loop word) | low |
| 28 | resonance_core | data/items/resonance_core.tres + data/modifiers/resonance_core.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | refund / refund | src/presentation/hud/card_frames.gd:102 | low |
| 29 | heat_sink_rounds | data/items/heat_sink_rounds.tres + data/modifiers/heat_sink_rounds.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | refund / refund | src/presentation/hud/card_frames.gd:94 | low |
| 30 | meltdown_edge | data/items/meltdown_edge.tres + data/modifiers/meltdown_edge.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | refund / refund | src/presentation/hud/card_frames.gd:97 | low |
| 31 | mirror_drone | data/items/mirror_drone.tres + data/modifiers/mirror_drone.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | refund / refund | src/presentation/hud/card_frames.gd:98 | low |
| 32 | bomb_rounds | data/items/bomb_rounds.tres + data/modifiers/bomb_rounds.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | ember_core / gun_mine | src/presentation/hud/card_frames.gd:85 | low |
| 33 | short_fuse | data/items/short_fuse.tres + data/modifiers/short_fuse.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | refund / refund | src/presentation/hud/card_frames.gd:106 | low |
| 34 | tempest_core | data/items/tempest_core.tres + data/modifiers/tempest_core.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | storm_core / storm_core | src/presentation/hud/card_frames.gd:109 src/presentation/theme/element_glyphs.gd:55 src/presentation/theme/element_glyphs.gd:66 | low |
| 35 | inferno_core | data/items/inferno_core.tres + data/modifiers/inferno_core.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | ember_core / ember_core | src/presentation/hud/card_frames.gd:95 src/presentation/theme/element_glyphs.gd:46 src/presentation/theme/element_glyphs.gd:63 | low |
| 36 | echo_storm | data/items/echo_storm.tres + data/modifiers/echo_storm.tres | item + modifier | v0.6.5 WN5b: v0.6 card, migrated into the wand | echo_slash / refund | src/presentation/hud/card_frames.gd:88 src/presentation/theme/element_glyphs.gd:62 | low |
| 37 | bomb_lobber | data/abilities/bomb_lobber.tres | ability | v0.6.5 WN5b: old ability retired | ember_core / gun_mine | src/presentation/hud/ability_icons.gd:11 src/presentation/hud/ability_icons.gd:97 src/presentation/hud/card_frames.gd:192 src/sim/abilities/abilities.gd:33 | high: AbilityTable.Kind, combos, audio, icons, many tests |
| 38 | drone_buddy | data/abilities/drone_buddy.tres | ability | v0.6.5 WN5b: old ability retired | refund / refund | src/presentation/hud/ability_icons.gd:12 src/presentation/hud/ability_icons.gd:104 src/presentation/hud/card_frames.gd:194 src/sim/abilities/abilities.gd:34 | high: AbilityTable.Kind, combos, audio, icons, many tests |
| 39 | orbit_blades | data/abilities/orbit_blades.tres | ability | v0.6.5 WN5b: old ability retired | blade_orbit / orbit_rounds | src/presentation/hud/ability_icons.gd:13 src/presentation/hud/ability_icons.gd:115 src/presentation/hud/card_frames.gd:197 src/sim/abilities/abilities.gd:36 | high: AbilityTable.Kind, combos, audio, icons, many tests |
| 40 | arc_field | data/abilities/arc_field.tres | ability | v0.6.5 WN5b: old ability retired | storm_core / storm_core | src/presentation/audio/audio_events.gd:61 src/presentation/audio/audio_events.gd:62 src/presentation/audio/audio_events.gd:67 src/presentation/audio/audio_events.gd:518 src/presentation/hud/ability_icons.gd:16 src/presentation/hud/ability_icons.gd:204 src/presentation/hud/card_frames.gd:190 src/sim/abilities/element_abilities.gd:19 | high: AbilityTable.Kind, combos, audio, icons, many tests |
| 41 | frost_nova | data/abilities/frost_nova.tres + data/modifiers/frost_nova.tres | ability | v0.6.5 WN5b: old ability retired | frost_core / frost_core | src/presentation/audio/audio_events.gd:63 src/presentation/audio/audio_events.gd:520 src/presentation/hud/ability_icons.gd:17 src/presentation/hud/ability_icons.gd:222 src/presentation/hud/card_frames.gd:196 src/presentation/theme/element_glyphs.gd:42 src/sim/abilities/element_abilities.gd:20 | high: AbilityTable.Kind, combos, audio, icons, many tests |
| 42 | flame_trail | data/abilities/flame_trail.tres | ability | v0.6.5 WN5b: old ability retired | ember_core / ember_core | src/presentation/audio/audio_events.gd:64 src/presentation/audio/audio_events.gd:65 src/presentation/audio/audio_events.gd:66 src/presentation/hud/ability_icons.gd:18 src/presentation/hud/ability_icons.gd:229 src/presentation/hud/card_frames.gd:195 src/sim/abilities/element_abilities.gd:21 | high: AbilityTable.Kind, combos, audio, icons, many tests |
| 43 | gun_spread | data/items/gun_spread.tres + data/modifiers/gun_spread.tres | item + modifier | v0.9.0 XP era (explosions removed) | refund / gun_twin | src/presentation/hud/card_frames.gd:132 | low |
| 44 | shared_explosive | data/items/shared_explosive.tres + data/modifiers/shared_explosive.tres | item + modifier | v0.9.0 XP era (explosions removed) | ember_core / ember_core | src/content/defs/wand_definition.gd:25 src/content/defs/wand_definition.gd:32 src/presentation/hud/card_frames.gd:201 src/presentation/theme/element_glyphs.gd:51 src/sim/combat/wand_compile.gd:77 src/sim/combat/wand_table.gd:17 src/sim/combat/wand_table.gd:26 | medium: icons/looks/kind-specific sim code |
| 45 | gravity_well | data/items/gravity_well.tres + data/modifiers/gravity_well.tres | item + modifier | v0.9.0 XP era (explosions removed) | refund / gun_void | src/presentation/hud/card_frames.gd:92 src/presentation/theme/element_glyphs.gd:44 | low |
| 46 | gun_charge | data/items/gun_charge.tres + data/modifiers/gun_charge.tres | item + modifier | v0.9.0 AF1/AF2: became a Gun form | refund / gun_lance | src/content/defs/wand_definition.gd:39 src/presentation/hud/card_frames.gd:124 src/sim/combat/wand_table.gd:30 | low |
| 47 | boomerang | data/items/boomerang.tres + data/modifiers/boomerang.tres | item + modifier | v0.9.0 AF1/AF2: became a Gun form | refund / gun_glaive | src/presentation/hud/card_frames.gd:86 | low |
| 48 | shared_gravity_stitch | data/items/shared_gravity_stitch.tres + data/modifiers/shared_gravity_stitch.tres | item + modifier | v0.9.5 RC: Gravity Stitch, mutations, trigger cards | refund / refund | src/presentation/hud/card_frames.gd:165 | low |
| 49 | mut_double_exposure | data/items/mut_double_exposure.tres + data/modifiers/mut_double_exposure.tres | item + modifier | v0.9.5 RC: Gravity Stitch, mutations, trigger cards | refund / refund | src/presentation/hud/card_frames.gd:167 src/presentation/theme/element_glyphs.gd:64 | low |
| 50 | mut_grand_finale | data/items/mut_grand_finale.tres + data/modifiers/mut_grand_finale.tres | item + modifier | v0.9.5 RC: Gravity Stitch, mutations, trigger cards | refund / refund | src/presentation/hud/card_frames.gd:168 src/presentation/theme/element_glyphs.gd:65 | low |
| 51 | trigger_on_hit | data/items/trigger_on_hit.tres + data/modifiers/trigger_on_hit.tres | item + modifier | v0.9.5 RC: Gravity Stitch, mutations, trigger cards | refund / refund | src/presentation/hud/card_frames.gd:116 | low |
| 52 | trigger_on_kill | data/items/trigger_on_kill.tres + data/modifiers/trigger_on_kill.tres | item + modifier | v0.9.5 RC: Gravity Stitch, mutations, trigger cards | refund / refund | src/presentation/hud/card_frames.gd:117 | low |
| 53 | trigger_on_end | data/items/trigger_on_end.tres + data/modifiers/trigger_on_end.tres | item + modifier | v0.9.5 RC: Gravity Stitch, mutations, trigger cards | refund / refund | src/presentation/hud/card_frames.gd:114 | low |
| 54 | trigger_on_finisher | data/items/trigger_on_finisher.tres + data/modifiers/trigger_on_finisher.tres | item + modifier | v0.9.5 RC: Gravity Stitch, mutations, trigger cards | refund / refund | src/presentation/hud/card_frames.gd:115 | low |
| 55 | trigger_on_hit_twice | data/items/trigger_on_hit_twice.tres + data/modifiers/trigger_on_hit_twice.tres | item + modifier | v0.9.5 RC: Gravity Stitch, mutations, trigger cards | refund / refund | src/presentation/hud/card_frames.gd:118 src/presentation/theme/element_glyphs.gd:68 | low |
| 56 | trigger_on_kill_twice | data/items/trigger_on_kill_twice.tres + data/modifiers/trigger_on_kill_twice.tres | item + modifier | v0.9.5 RC: Gravity Stitch, mutations, trigger cards | refund / refund | src/presentation/hud/card_frames.gd:119 src/presentation/theme/element_glyphs.gd:69 | low |
| 57 | trigger_on_end_twice | data/items/trigger_on_end_twice.tres + data/modifiers/trigger_on_end_twice.tres | item + modifier | v0.9.5 RC: Gravity Stitch, mutations, trigger cards | refund / refund | src/presentation/hud/card_frames.gd:120 src/presentation/theme/element_glyphs.gd:67 | low |
| 58 | gun_scatter | data/items/gun_scatter.tres + data/modifiers/gun_scatter.tres | item + modifier | v0.9.5 BR: Scatter/Bomb forms removed | refund / gun_rune_explosion | src/presentation/hud/card_frames.gd:141 | low |
| 59 | gun_bomb | data/items/gun_bomb.tres + data/modifiers/gun_bomb.tres | item + modifier | v0.9.5 BR: Scatter/Bomb forms removed | refund / gun_void | src/presentation/hud/card_frames.gd:136 | low |
| — | frost_nova (modifier) | data/modifiers/frost_nova.tres | modifier | only data/abilities/frost_nova.tres (retired) uses it | — | — | low |

**How many test files name each id** (out of 110 test files that touch anything in this list): ember_edge 24,
bomb_lobber 23, trigger_on_hit 20, orbit_blades 19, drone_buddy 18, arc_field 17, gun_spread 16, gun_bomb 16,
static_chain 14, long_edge 14, frost_nova 14, gun_scatter 13, flame_trail 13, twin_arc 12, trigger_on_kill 11.
Each of the others is named in 10 or fewer. The full list is in the scratchpad's `tests_hit.txt`.

## 3. Borderline cases

| Case | What reaches it | Recommendation |
|---|---|---|
| All 60 retired ids | **Dev panel only.** `DebugApi.next_mod` / `next_ability` cycle every `item_tables` / `ability_tables` entry, retired ones too (src/application/debug_api.gd:167-190). The migration doc says so on purpose. | Remove them. The dev panel should then skip tombstones (§5). The owner never offers these in a run. |
| ~110 test files | Many tests use retired cards as fixtures: ember_edge, long_edge and twin_arc as a "plain card", the old abilities to fill slots. `tests/support/card_pool_survey.gd` STATES (lines 47-52) grants BOMB_LOBBER, DRONE_BUDDY and ORBIT_BLADES. | Remove or retarget them, in this order. (a) Delete the tests whose subject is a removed card or combo, for example test_combos, test_engines (combo parts), test_abilities_ab and the parts of test_e2e_abilities_ab about old abilities. (b) Retarget the fixture-only uses onto live cards: ember_edge to ember_core, long_edge to wide_arc, twin_arc to double_slash, and the old abilities to blink, aegis and the start weapons. **This is most of the step's cost.** |
| Old saves | `tests/fixtures/saves/v061_blade_floor1.save` and `v061_gun_floor2.save` hold retired cards **by item index**. They are covered by tests/unit/application/test_old_saves.gd and tests/e2e/test_e2e_old_save.gd, both in seams.sh. | Keep them loading (§5). This is the gate for "old saves still load". |
| Shot / probe scripts | scripts/shots/* (mu_shots, mu2_shots, wand_build, combos, card_pool, attack_order, laser_bomb, lance_scatter, vx_shots, codex, rarity_cards, abilities_2, ui_polish, text_n18, vfx_audit, plaques, card_mockups, hu_hud, …) and scripts/checks/{perf_probe,rarity_odds,catch_up_probe}.gd, scripts/bench/sim_bench.gd | Retarget them onto live cards, or delete shot scripts of past versions. They aren't in CI, but leaving them with dead ids breaks them silently. |
| `shatter`, `ascension` ids | The words are also a status effect (Shatter) and the loop (Ascension) in prism_clips, status_visuals, world_snapshot.gd:238 and achievements. | Remove only the card files and their card-frame and glyph entries. **Don't** grep-replace the words. |
| AbilityTable.Kind / ItemDefinition.Kind / ComboDefinition.Effect / Curses.Effect enums | Saved data and data files store these as ints ("appended, never renumbered"). | Keep the enum values, marked retired, the way the curse effects of Marked were kept (src/content/defs/curse_definition.gd:46). Remove only the code that acts on them. |
| Codex profile (`codex.cards` keyed by id) | A profile may hold a removed id's counters. | It is keyed by id and outside saves. Make sure the Codex page skips ids with no def (CodexStore/CodexCatalog). Add a one-line test. |

## 4. Counts

| Folder | Files | Reachable | Removable |
|---|---|---|---|
| data/items | 117 | 63 (20 Blade, 24 Gun, 19 shared: 13 passives, of which 2 are Blade-only, and 8 shared wand cards) | **54** |
| data/modifiers | 105 | 50 | **55** (54 + frost_nova) |
| data/stat_cards | 18 | 18 | 0 |
| data/abilities | 10 | 4 (combo_sword, pulse_gun, blink, aegis) | **6** |
| data/combos | 17 | 1 (element_pairs, not a combo) | **16** (owner: combos go; 4 could still form, §6) |
| data/legendary | 1 | 1 | 0 |
| data/utilities | 2 | 2 | 0 |
| **Card files total** | **270** | **139** | **131** |
| data/curses (owner addition) | 12 | 7 | **5** |
| Locale rows (`locale/strings.csv`) | — | — | **162** keys/rows: removed items, abilities, combos and curses. The list is in the scratchpad's `allkeys.txt`. 16 of them are also named in code (§5.3). |

## 5. The removal plan (build half)

### 5.1 Old saves: keep every saved index meaning the same card (the key risk)

Saves hold **indices, not ids**:
- `RunCarry.FIELDS` (src/sim/run/run_carry.gd:8-24): items_owned, ability_owned, mod_slots (Offers codes),
  card_levels, combos_owned, curses_owned.
- `World.to_snapshot`, written in `payload_of` (src/application/run_saver.gd:245-272): the same fields, plus the
  offers in rewards, shop, cores, pickups and ev.roll_card.

The item index order is `ModifierCompiler.item_defs`, by kind, pool and index_wave
(src/application/modifier_compiler.gd:128-191). Deleting 54 item defs would shift almost every live card's index:
old saves would load the wrong cards and the goldens would change.

**Recommended: tombstones, as the curses already do.** EventCompiler.RETIRED_CURSES (src/application/event_compiler.gd:11-30)
keeps a deleted curse's place in the id order, as a `retired` table with no effect. `Curses.drop_retired`
(src/sim/events/curses.gd:230-238) then drops a held one on load. Do the same for the others:
- **Items.** Freeze today's 117-entry index order as a const: a list of ids, including the 54 removed ones. That's
  simpler and safer than re-deriving it from kind and wave.
  - `item_defs` / `compile_items` emit a stub `ItemTable` at each removed id's slot. The stub has the id,
    `retired = true`, the rarity it had (`WandMigration.refund_of` prices refunds by rarity,
    src/sim/abilities/wand_migration.gd:~110-120), its kind and requires_weapon, and no modifiers.
  - Live cards keep their indices, so goldens and saves are unchanged.
  - New cards append after the frozen list.
- **Abilities.** The same pattern: a RETIRED_ABILITIES list of 6 ids keeps the by-id order of `compile_abilities`.
  The AbilityTable stubs keep `kind` and `retired`.
- **Combos.** If the whole combo system goes, drop `combos_owned` on load: ignore the snapshot and carry key, and keep
  the field out of the payload. world_snapshot.gd:32 and :81 and run_carry.gd:10 list it. Add a migration line for a
  payload that has it.
- **Curses.** Add the 5 ids to RETIRED_CURSES. The existing `drop_retired` removes a held one on load
  (events.gd:81, 643, 650; curse_table.gd:21).

**WandMigration stays.** It maps by id through the stubs: `_row` reads `w.item_tables[code].id`
(wand_migration.gd:70-80). So the v0.6.1 fixtures still turn into today's cards. `migration.tres` keeps its 60 rows.
They are the record of what each old id becomes. Change its validator `cross_check` (wand_migration_definition.gd:~52-70)
so an old id may name a tombstone instead of a def.

**Fallback, if the lead prefers ids in saves:** bump `PAYLOAD_VERSION` to 5 (run_saver.gd:36-37) and write ids. A
v2-v4 payload is read through the frozen index list above. Either way the frozen list is needed. Tombstones are the
smaller change and don't touch goldens.

**Tests:** test_old_saves.gd, test_e2e_old_save.gd, test_run_saves.gd, test_world_snapshot.gd and
test_ascension_saves.gd. Add one test: a payload holding a removed combo index and a removed curse loads without them.

### 5.2 Content

Delete the files:
- the 54 data/items/*.tres and their 55 data/modifiers/*.tres;
- the 6 data/abilities/*.tres;
- the 16 data/combos/*.tres (keep element_pairs);
- the 5 data/curses/*.tres;
- data/audio/cues/{arc_field,flame_trail,frost_nova}.tres and their manifest.json entries.

Edit:
- the wardrobe affinities (4 files) and data/wand/wand.tres (§2);
- `src/content/defs/wand_definition.gd:25,32,39` and `src/sim/combat/wand_table.gd:17,26,30` (once_per_line /
  blast_merge shared_explosive, after_trigger_dead gun_charge), and `src/sim/combat/wand_compile.gd:77`.

Keep ContentScanner discovery as it is. The validators that cross-check ids (combo, wand migration, attack slots)
must accept tombstone ids.

### 5.3 Code paths that only removed cards reach

- **Sim, item kind code.**
  - src/sim/items/item_effects.gd:15-18: Twin Arc, Ember Edge, Overcharge, plus their kind branches.
  - src/sim/items/item_procs.gd:9: Static Chain.
  - src/sim/items/engines.gd:21: Cinder Shot.
  - src/sim/combat/modifier_runtime.gd:257: Aether Shell.
  - src/sim/abilities/ability_mods.gd:16-17: Cluster Payload, Afterimage.
  - Check each for other kinds before deleting.
- **Sim, abilities.**
  - src/sim/abilities/abilities.gd:33-36: the Kind consts.
  - src/sim/abilities/element_abilities.gd:19-21: the Arc Field, Frost Nova and Flame Trail engines, plus the
    behaviour code of the 6 abilities: bombs, drone, orbit blades, arc field, nova, trail.
  - Find them through `AbilityTable.Kind.BOMB_LOBBER`, DRONE_BUDDY, ORBIT_BLADES, ARC_FIELD, FROST_NOVA and
    FLAME_TRAIL in src/sim/abilities/. 17 test files name these Kind values.
- **Presentation.**
  - src/presentation/hud/card_frames.gd: FAMILY_OF entries, about lines 49-201, one per removed id.
  - src/presentation/hud/item_icons.gd:13-43 and the draw functions at 58-257.
  - src/presentation/hud/card_pool_icons.gd:18-21 and 117-175.
  - src/presentation/hud/ability_icons.gd:11-18 and the draw functions at 97-229.
  - src/presentation/theme/element_glyphs.gd: the entries for removed ids.
  - src/presentation/world_view/item_looks.gd:28-58, plus the combos at 73-89.
  - src/presentation/world_view/ability_visuals.gd:106 (afterimage), plus the views of the 6 abilities.
  - src/presentation/audio/audio_events.gd:61-67 and 518-520.
  - src/presentation/world_view/attack_view.gd: the ITEM_* keys of removed cards.
  - src/sim/world/world_reader.gd: the ABILITY_BOMB_LOBBER, DRONE_BUDDY, ORBIT_BLADES and ITEM_STATIC_CHAIN keys.
  - test_card_frames.gd fails on a FAMILY_OF entry with no card. That is the guard for this cleanup.
- **Strings.** Remove the 162 keys (`allkeys.txt`) from `locale/strings.csv`, en and es together. Grep for the 16
  keys that code also names (listed above) before removing them.
- **Card pool.**
  - tests/support/card_pool_survey.gd: STATES grants removed abilities, so retarget it onto blink and aegis.
  - PLANNED_ABILITIES (line 14) names the 3 removed abilities. Clear it.
  - Leave the pool count the same. If the D69 test ceiling is meant to track the real pool, re-measure
    `test_card_pool_reach.gd` and set POOL_MAX from it. Don't guess.

### 5.4 Tests to rerun (agent scope)

- The content and arch tests, golden, unit/application (saves), unit/debug (dev panel lists).
- test_e2e_damage_soak (every card), test_e2e_card_pool, test_e2e_gun_pool, test_e2e_reward_cards, test_items, test_wand.
- The curse tests (§7).
- The e2e tests for the dev panel, saves and old saves.

## 6. Combos (owner: "The combos can go away yeah, that's old")

**`data/combos/element_pairs.tres` stays.** It is an `ElementPairsDefinition` (level_permille 400/700/1000), not a
combo. It drives the v0.9.5 element pairs through:
- src/sim/items/element_pairs.gd and element_pair_table.gd;
- src/application/wand_compiler.gd, and src/sim/combat/{attacks,damage,modifiers,modifier_runtime}.gd.

The HUD shows a newly lit pair on the **same ComboCard** (src/presentation/hud/hud.gd:106, "EE3: an element pair …
shows on the combo card"). So `combo_card.gd` stays, and only its combo-specific use goes. The pairs file could move
to `data/wand/` later, but it doesn't have to.

**Can each combo still form today?**

| Combo | Halves | Can form today? | Code that only it uses |
|---|---|---|---|
| blood_harvest | vampiric_core + executioner (items) | **Yes** (both live) | engines.gd (BLOOD_HARVEST branch) |
| shatter_dash | frost_core + kinetic_dash | **Yes** | engines.gd |
| slipstream | momentum + swift_feet | **Yes**, Blade only (Momentum is Blade-only) | engines.gd |
| spiked_phase | thorn_mantle + phase_strike | **Yes** | engines.gd |
| frozen_bastion | bulwark + glacial_edge (retired) | No | engines.gd:38, status_visuals.gd:347/448, item_looks.gd:80 |
| plasma_arc | ember_edge (retired) + conductor (retired) | No | engines.gd:31, status_visuals.gd:339, item_looks.gd:73 |
| resonance | twin_arc (retired) + overcharge (retired) | No | engines.gd:33, status_visuals.gd:344-345/445-446, item_looks.gd:75 |
| shrapnel_storm | splinter_shot (retired) + ricochet_core (retired) | No | engines.gd:34, item_looks.gd:76 |
| storm_bombs | bomb_lobber (retired) + arc_field (retired) | No | ability_combos.gd:24, audio_events.gd:67, item_looks.gd:82 |
| napalm_drone | drone_buddy (retired) + flame_trail (retired) | No | ability_combos.gd:25, audio_events.gd:65, item_looks.gd:83 |
| glacier_ring | orbit_blades (retired) + frost_nova (retired) | No | ability_combos.gd:26, item_looks.gd:84 |
| blink_charge | blink + bomb_lobber (retired) | No | ability_combos.gd:27, item_looks.gd:85 |
| blade_dance | combo_sword + orbit_blades (retired) | No | ability_combos.gd:28, item_looks.gd:86 |
| wingman | pulse_gun + drone_buddy (retired) | No | ability_combos.gd:29, player_kit.gd:205 (on_shot), item_looks.gd:87 |
| superconductor | arc_field + frost_nova (both retired) | No | ability_combos.gd:30, audio_events.gd:62, item_looks.gd:88 |
| ember_ward | flame_trail (retired) + aegis | No | ability_combos.gd:31, audio_events.gd:66, item_looks.gd:89 |

So **4 combos still form in real runs.** Cutting them changes live play: Blood Harvest, Shatter Dash, Slipstream and
Spiked Phase stop granting their bonus. The owner approved it, but say it in the patch notes.

**The combo system, file by file (it all goes when all 16 go):**
- **Content.**
  - src/content/defs/combo_definition.gd. Keep the Effect enum ints only if any save stores them. Saves store
    combo indices, so it can go.
  - The combo validator: src/content/content_validator.gd:21 and tests/content/test_combo_validation.gd.
- **Compiler.** `ContentCompiler.compile_combos` (src/application/content_compiler.gd:788-~830) and its callers:
  - src/app/floor_plan.gd:164 and 330;
  - floor_scenario.gd:43 and 95;
  - final_arena_scenario.gd:25 and 41;
  - playground_scenario.gd:26;
  - live_tuning.gd:28.
- **Sim.**
  - src/sim/items/combo_table.gd.
  - src/sim/abilities/ability_combos.gd: the whole file, and its call in player_kit.gd:205.
  - src/sim/items/engines.gd:91-104 (combo / combos_for), plus the combo effect branches at 244, 465-466, 505, 563,
    616, 638, 654, 685 and 696.
  - src/sim/world/world.gd:278-279 (combo_tables, combos_owned), 899-949 (`_refresh_combos`, unlock events) and 1457.
  - src/sim/abilities/abilities.gd: lines 155-160, 267, 334, 549, 631, 658, 683-684, 699 and 724.
  - src/sim/abilities/element_abilities.gd: lines 162-171 and 217-225.
  - src/sim/items/shop.gd:333-339 (remove_item recomputes combos).
  - src/sim/world/catch_up.gd:59 (`combo_permille × combos_owned.size()`; drop the term and `combo_permille` in
    catch_up_definition.gd and catch_up_table.gd).
  - src/sim/effects/sim_event.gd:43 (the COMBO_UNLOCKED event; keep the enum slot if events are hashed or saved
    by int).
  - src/sim/core/world_snapshot.gd:32 and 81, and src/sim/run/run_carry.gd:10 (§5.1).
- **Reader / presentation.**
  - src/sim/world/world_reader.gd:2470-2493.
  - The HUD combo badges, src/presentation/hud/hud.gd:30, 38, 102-105, 114, 162-165, 616, 662, 687, 713, 731 and
    804. That's the "ComboBadges" row and its plaques.
  - src/presentation/hud/combo_icon_view.gd: the badge icon, which goes.
  - combo_card.gd stays for element pairs.
  - src/presentation/world_view/item_looks.gd:73-89 and status_visuals.gd:339-347 and 445-448 (combo auras).
  - src/presentation/audio/audio_events.gd:62-67 and 485-486 and 530 (combo cues).
  - src/presentation/hud/pick_panel.gd and src/debug/dev_fields.gd: one reference each. Check them.
- **Strings.** 32 keys/rows, ITEM_COMBO_* and ABILITY_COMBO_* (each with _DESC). They are included in the 162.
- **Tests.**
  - Delete tests/unit/sim/test_combos.gd. **It is listed in scripts/ci/seams.sh:27, so remove it there too.**
  - Delete tests/e2e/test_e2e_combo.gd.
  - Edit test_engines.gd, test_abilities.gd, test_abilities_ab.gd, test_e2e_abilities.gd, test_e2e_abilities_ab.gd,
    test_catch_up.gd, test_shop.gd, test_run_flow.gd, test_player_builds.gd, test_status_visuals.gd,
    test_vx3_zones.gd, test_plaques.gd, test_ability_squares.gd and test_four_slash_combo.gd. Check the last one: it
    may be about the Blade's 4-hit combo, not item combos.
- **Scripts.** scripts/shots/{combos,card_mockups,hu_hud,plaques}.gd, scripts/checks/catch_up_probe.gd and
  scripts/bench/sim_bench.gd.
- **Docs to update.** CONTENT_SCHEMA (combos), SIM_CONTRACTS (combo unlock event), PRESENTATION_CONTRACTS
  (combo badges), GAME_BLUEPRINT if it names combos.

## 7. The 5 flat curses (owner: "Yes, cut the 5")

Each of the 5 has its own effect. No other curse uses those effects, so each effect's code goes with it.

| Curse | Effect | Hook that goes (file:line) | Tests that name it |
|---|---|---|---|
| leaky_core | heat_decay (+10 % heat decay) | Curses.heat_decay, called from src/sim/heat/heat.gd:95 | test_curses |
| price_gouge | prices (+25 %) | Curses.price, called from src/sim/events/events.gd:509, src/sim/items/gamble.gd:220, src/sim/items/rewards.gd:171, src/sim/items/shop.gd:160/162/166/170/175 | test_curses, test_curse_totals, test_event_views |
| swarm_call | extra_enemy (+1 per arrival) | Curses.extra_enemies, called from src/sim/world/spawn_director.gd:168 | test_curses, test_event_validation |
| swift_foes | enemy_speed (+15 %) | Curses.enemy_speed_factor, called from src/sim/ai/enemy_ai.gd:312 | test_curses, test_curse_totals, test_event_views, test_ui_polish, test_events, test_event_validation |
| withering | regen (−20 %) | Curses.regen, called from src/sim/abilities/stats.gd:385 and src/sim/combat/player_regen.gd:24 | test_curses, test_events, test_event_views, test_plaques; scripts/shots/plaques.gd |

What the removal touches:
- **Data and enums.**
  - Delete data/curses/{leaky_core,price_gouge,swarm_call,swift_foes,withering}.tres.
  - Remove the 5 effect names from CurseDefinition's effect list (src/content/defs/curse_definition.gd:23-27),
    `COUNTS` (line 49, extra_enemy) and `CUTS` (line 53, regen), and the regen check (lines 109-111).
  - Make them refuse as retired, the way Marked's effects do (curse_definition.gd:46 and 107).
  - Keep `Curses.Effect` ENEMY_SPEED..PRICES (src/sim/events/curses.gd:44-48) as retired enum slots. The
    `curse_totals` cache indexes by effect.
  - Remove the 5 hook functions (curses.gd:~200-226) and the doc lines 12-16, and unhook each caller above. Shop,
    gamble, events and rewards prices become plain base prices.
- **Saves.** Add the 5 ids to `EventCompiler.RETIRED_CURSES` (src/application/event_compiler.gd:11). The order of
  `World.ev.curses` then stays the same, and `Curses.drop_retired` drops a held one from an old save.
  - Add an old-save test: a payload with `curses_owned` holding swift_foes loads with it gone.
- **Draws change.** The cursed-chest and curse-room draws are weighted over the live curses, 12 today, each weight 10
  for these 5. Dropping 5 changes those RNG picks. Expect the curse goldens or recorded seeds to move:
  - test_curse_room.gd (about 14 min; run it, since this step changes that system);
  - test_events and test_event_rarity;
  - any golden whose replay meets a cursed chest.

  Name each golden that changes in PROGRESS "Goldens changed on purpose".
- **Strings.** 10 rows, CURSE_{LEAKY_CORE,PRICE_GOUGE,SWARM_CALL,SWIFT_FOES,WITHERING}[_DESC]. They are included in
  the 162.
- **Balance.** 7 curses stay (blood_price, brittle, fevered, glass_heart, heavy_hands, rooted, tunnel_vision). Check
  that the curse room and cursed chests still have enough choices, and whether `data/event_rules` sets a curse count
  that needs 3+ distinct curses.

## Owner decision (2026-11-01)

"Keep those 4": Blood Harvest, Shatter Dash, Slipstream and Spiked Phase stay, with their badge row and `combo_icon_view.gd`. The other 12 combos, the 60 retired card ids and the 5 flat curses are removed, with tombstones for saved indices (section 5.1).
