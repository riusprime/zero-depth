# v0.9.0 AS2: ribbon + pips, choose the Secondary or Element to replace, straight edges (evidence)

Owner row AS in [`../PLAN.md`](../PLAN.md) "Owner decisions" ("B: ribbon + pips"; "Let me choose"; "can you make the
edges of things straight and not the zigzags it has?"). Branch `v090-as2`, cut from `9c338674`. Machine: the owner's PC
(Windows 11, Git Bash, i7-10700K, RTX 3060), Godot 4.7.2; GUT jobs in parallel, each with its own `APPDATA`.

Every run: `APPDATA=<own folder> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit
-gtest=<files>`. Lint: `gdformat` + `gdlint` on every touched `.gd` (clean).

## What was built

- **Look B** (replaces A's slot line under the card). A Form, Pattern, Secondary or Element card names its slot first in
  its rarity line ("Pattern · Modifier · Rare"). When its slot is full, an ember-red ribbon goes across the card
  (`SlotRibbon`, laid out by `StoneCard.show_ribbon`) above the rarity gem and below the sentence, so it never covers
  the name or the icon. The sentence's room ends above it. The ribbon reads "REPLACES TWIN" / "REEMPLAZA A GEMELO", or
  "CHOOSE ONE TO REPLACE" / "ELIGE CUÁL REEMPLAZAR" for a full Secondary or Element slot. When the card is picked,
  the "Replaces" ribbon burns with N8's dissolve (it was A's chip that burned). The Build page and the Swap panel show
  the pips over the wand (`SlotPips`): "Form: Orbs ●", "Pattern ●", "Secondary ●●", "Element ●○", each with its
  mark. They read the wand read's `slot_counts` and `form`, so a Blade run shows only the Pattern's pip. The wand tiles
  keep A's "Lv 1 · Pattern". The Build page's note no longer repeats the counts.
- **Choose (sim + UI).** `AttackSlots.full_category / chosen / choices / choice_category`. A Form or Pattern card still
  replaces its card (`replaces`). A Secondary or Element card meeting its full category makes
  `BuildSlots.needs_swap` true, whether or not the wand is full. `BuildSlots.can_replace` limits the answer to that
  category's slots, and `swap_answer` treats any other slot as "no answer yet". The choice arrives through the existing
  Swap path (`InputFrame.pick` = `PICK_SWAP_BASE + n`; the altar, chest, shop and grant flows unchanged), so it is
  deterministic. The swap state is the existing `swap_code / swap_source / swap_ref`, which saves already carry, and
  the limit is derived from it, so a save mid-choice resumes the same choice. `Offers.info` adds `chooses`.
  `Wand.read` adds `swap_slot`. The Swap panel dims the other cards and won't focus or answer them. Its title reads
  "Your Secondary slots are full: choose one to replace" (es: "Tus huecos de Secundaria están llenos: elige cuál
  reemplazar"). Esc / Skip works as before: back to the cards, the card un-taken.
- **Straight edges.** One switch: `EmberStone.STRAIGHT_EDGES = true` zeroes `StoneBox.outline`'s chip depth. Every UI
  slab draws through `StoneBox`: cards, card backs, plaques, menu panels and tiles, the Build page, the Swap panel and
  the HUD pips. The HUD plates' `HudStyle.plate_points` were already straight-edged chamfers. Fill, grain, cracks,
  glow, inner bevel and the cut corners stay. Nothing in 3D is touched.

## Rules decided (simplest reading; listed for the owner)

| Question | Rule |
|---|---|
| "Shows the two" in the Swap panel | The whole wand stays in the row (its order and triggers matter). The cards of other slots are dimmed and can't be chosen. |
| Insert (I / pad X / drag the new card) in a limited Swap | Off: a limited Swap only replaces (the new card takes the chosen card's slot). Reordering (R / Y) still works. The hint line still lists Insert (not reworded). |
| A full Secondary slot with room in the wand | It still asks (the category's limit is the rule, not the wand's free slots). |
| The Form pip | Lit by the form fired now (the Orbs need no card), shown as "Form: Orbs ●". |
| The dev panel's grant (PlaygroundApi) of a third Secondary | It refuses, as it does for any card needing the Swap. |
| test_arrival's swap-mid-arrival test | Its Blade cards (Whirl, Thrust, Wide Arc) have been Patterns since AS, so the wand never filled and the test failed. It now fills with Free cards (Heavy, Echo Slash, Flurry, Chain Cut) before Wide Arc. |

## Tests (raw summary lines, final code)

| Run (`-gtest`) | Summary |
|---|---|
| sim: test_attack_slots, test_build_slots, test_wand, test_gun_pool_order, test_arrival, test_laser, test_bomb, test_gun_pool, test_wand_migration | `Tests 127 / Passing Tests 127 / Asserts 4328` |
| presentation: attack_slot_views, build_views, card_frames, card_level_views, ember_stone, hud_style, item_cards, plaques, reward_cards, reward_views, shop_views, wand_views | `Tests 93 / Passing Tests 92 / Failing Tests 1` (test_attack_slot_views: "data.blocked > 0" from SlotPips rebuilding inside the translation notification; fixed by deferring it), then test_attack_slot_views again: `Tests 4 / Passing Tests 4 / Asserts 52` |
| e2e: attack_slots, reward_cards | `Tests 5 / Passing Tests 5 / Asserts 87` |
| e2e: wand_build, pad_menus, shell | `Tests 10 / Passing Tests 10 / Asserts 106` |
| content (all 27 files), arch (layering, sim purity), golden replay_ground_plane, test_modifier_equivalence, test_state_hasher | `Tests 151 / Passing Tests 151 / Asserts 23688` (no golden moved) |

## Shots

`godot --path . --resolution 1920x1080 -s scripts/shots/attack_slots_2.gd` (RTX 3060) writes `build/shots/v0.9.0/as2/`,
copied by hand to [`as2_shots/`](as2_shots/), seed 5, a Gun run holding Twin, Pierce, Homing, Ember Core and On Hit:
`pick_en.png`, `pick_es.png` (Halo "Replaces Twin", Ricochet "Choose one to replace", Storm Core with room),
`build_en.png` (the pips over the wand), `swap_en.png` (choosing which Secondary Ricochet replaces), `menu_en.png` (the
pause menu's straight edges).
