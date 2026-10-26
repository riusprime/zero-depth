# Evidence: v0.9.5 Step EE1 (Venom and Bleed levels)

Base build SHA: `8fa8862e` (branch `v095-ee1`, cut from `v095-feedback` HEAD, before the EE1 commit). Machine: owner's PC,
Windows 11, Godot 4.7.2 headless, `--fixed-fps 60 --language en`. Each run used its own `APPDATA`.

## What was built
- `src/sim/items/element_levels.gd` (new): Venom Lv 2 Contagion, Lv 3 Virulence; Bleed Lv 2 Open wounds, Lv 3
  Exsanguinate. Numbers are the card's (`data/items/venom_core.tres`, `shared_bleed.tres`, `el_*` fields, validated in
  `ItemDefinition._check_element_levels`). Both cards' modifier `per_level` is now 0.
- Contagion budget: a jump happens only on a tick that is a multiple of 15, one jump per such tick (4 a second room-wide,
  no counter to save). Each poisoned enemy has `poison_jump_cd` (90 ticks).
- New actor columns `poison_jump_cd`, `bleed_x`, `bleed_y` (`ActorStore.ELEMENT_FIELDS`): hashed only while a card runs
  at Lv 2 or more, saved in the snapshot, padded with 0 for older saves.
- Adaptation (today's engines already stack, to 8): Lv 1 and Lv 2 keep today's cap of 8 and linear damage (the Lv 1 test
  pins it). Lv 3 caps at 5 and, for poison, multiplies a tick by `1 + 0.25 x (stacks - 1)`; Contagion passes the
  giver's stacks at Lv 2 and 1 stack at Lv 3. Bleed at Lv 3 caps at 5 and bursts when the 5th stack lands.
- Rounding: the +25 % and +50 % use `(base * (1000 + permille) + 500) / 1000`.

## Text lengths (content test caps a description at 60)
| Key | en | es |
|---|---|---|
| `ITEM_VENOM_CORE_DESC` | 40 | 42 |
| `ITEM_SHARED_BLEED_DESC` | 48 | 52 |

No per-level text mechanism exists (the pick panel shows only "Lv a -> b"), so the level behaviours are in the description.

## Commands and raw totals
```
APPDATA=<own> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://<file> -gexit --language en
```
| Run | Result |
|---|---|
| `tests/unit/sim/test_element_levels_venom_bleed.gd` | 11/11 passed (one test fixed after the first run: an out-of-range enemy placed at 2.7 m of a 2.85 m reach) |
| `tests/unit/presentation/test_status_visuals.gd` | 6/6 |
| `tests/e2e/test_e2e_element_levels.gd` (new, main.tscn, real input) | 1/1: "2 poisoned dummies never hit by a bolt; 3 jumps" |
| `tests/content/` | 157/157 (30 scripts) |
| `tests/golden/` | 2/2 |
| `tests/arch/` | 4/4 (first run failed: presentation named `ElementLevels`; the two effect ids moved to `SimEvent`) |
| batch: `test_modifier_equivalence`, `test_card_levels_clv`, `test_affinities`, `test_wand_shared_order`, `test_attack_slots`, `test_wand_migration`, `test_wand_shared`, `test_mx4_modifiers(_2)` | 109 tests, 3 failing before the fix below |
| batch: element, wand_shared, status_visuals, vx_looks, modifier_overlays, codex, e2e wand_build, e2e card_levels, e2e element_levels | 67/67 |

## Existing tests changed
- `tests/unit/sim/test_wand_shared.gd::test_each_shared_card_levels_up_without_a_slot_and_grows`: for `venom_core` and
  `shared_bleed` it expected the spell digest and bolt damage to change per level (+5 %). Their levels are now
  behaviours, so it now expects both unchanged. Nothing else was edited.

## Changed digests and goldens
None. `test_modifier_equivalence` passes unchanged (the Lv 1 digests of both cards did not move). No golden changed.

## Failures not caused by EE1 (pasted, not fixed)
- `tests/unit/sim/test_mx4_modifiers.gd`: Halo and Split Shot tests ("three bolts round the player" `[4]` vs `[3]`, "three
  splits leave the hit" `[2]` vs `[3]`). They concern halo_shot and split_shot (CLV level changes); not run on a clean base.
- `tests/unit/application/test_old_saves.gd`, `tests/unit/sim/test_world_snapshot.gd` (via the v0.6.1 snapshot),
  `tests/e2e/test_e2e_old_save.gd`: `World.heat.fill_rem: not in the snapshot`, a field added by step HT (commit
  `98ea1ed0`); a failure list of 3 in that batch (94/97 passing). Not run on a clean base.

## Not run
`test_five_floors.gd`, `test_curse_room.gd`, `test_modifier_smoke.gd` (excluded by the brief); the full suite (GitHub).
No frame-time probe was run. Look and feel of the dots, the green arc and the red splash: OWNER ONLY (no screenshot taken).
