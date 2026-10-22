# v0.9.0 TW, XP, LG: the card changes (evidence)

Owner rows: Q8 (TW), Q11 (XP), Q12 (LG) in [`../PLAN.md`](../PLAN.md). Branch `v090-cards`, cut from
`claude/world-combat-v090` at `54b6a487`. Machine: the owner's PC (Windows, Git Bash), Godot 4.7 headless, several
GUT jobs in parallel, each with its own `APPDATA`.

Every run: `APPDATA=<own folder> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit <args>`.
Lint: `gdformat --check <files>` and `gdlint <files>` on every touched `.gd` (clean before each commit).

## TW: Twin and Spread are one card

What changed: `data/modifiers/gun_twin.tres` (2 copies at Lv 1–4, 60/70/80/90 % each; 3 at Lv 5, 70 % each);
`GunForms.lane_turns` (three copies fan 15° from one point, the middle one straight and primary);
`gun_spread` retired through `data/wand/migration.tres` (into Twin on a Gun run; Splinter Shot's row now lands on Twin).

| Run (`-gtest` / `-gdir`) | Summary |
|---|---|
| test_mr_modifiers, test_gun_pool_order, test_wand_migration, test_nemesis (after the fixes) | `Tests 68 / Passing Tests 68 / Asserts 2931` |
| test_codex, test_achievements, test_old_saves, test_codex_view, test_wand_migration_validation | `Tests 42 / Passing Tests 42 / Asserts 1343` |
| tests/content (whole folder, before the migration-count fix) | `Tests 134 / Passing 133 / Failing 1` (the row count 43 → 44; fixed) |
| tests/golden + test_modifier_equivalence, test_modifiers, test_state_hasher | `Tests 23 / Passing Tests 23 / Asserts 234` |
| test_modifier_smoke (the every-card soak) | `Tests 8 / Passing Tests 8 / Asserts 12188` |
| e2e: wand_build, builds, reward_cards | `Tests 14 / Passing Tests 14 / Asserts 153` |
| e2e: attack_order, codex | `Tests 3 / Passing Tests 3 / Asserts 80` |

## XP: no more death explosions

What changed: Fire's ON_KILL hook is a ZONE (burning patch, 1.2 m, 2 s, burns every 0.5 s, at most 12 alive, a close
one merges, one past the cap is not lit with one LIMIT event: `ElementAbilities.add_zone`); its hits feed burn whole
(tag `ground`). `shared_explosive` retired through `migration.tres` (into Fire; the rows that pointed at it too).

| Run | Summary |
|---|---|
| tests/content + tests/golden + test_modifier_equivalence, test_modifiers, test_state_hasher, test_modifier_smoke, test_wand_smoke | `Tests 167 / Passing Tests 167 / Asserts 22282` |
| test_nemesis, test_wand_migration, test_wand_shared_order, test_wand, test_mr_modifiers, test_blade_combos, test_thermal_break, test_final_pace, test_nemesis_views | `Tests 131 / Passing Tests 131 / Asserts 3776` |
| e2e: wand_shared, wand_build, builds, reward_cards, attack_order, codex + test_old_saves, test_codex | `Tests 38 / Passing Tests 38 / Asserts 568` |
| test_mx4_modifiers, test_wand_shared, test_attack_forms_live, test_wand_cast_view | `Tests 42 / Passing Tests 42 / Asserts 348` |
| test_combos, test_engines, test_items, test_modifier_abilities, test_modifier_smoke (first run) | `Tests 68 / Passing Tests 67 / Failing Tests 1`: test_items' pool counts (61 → 59: Spread and Explosive left the pool); fixed in TW (60) and XP (59), with test_items_j (60 → 59 → 58) |
| at XP, after the count fixes: test_items, test_items_j, test_heat, test_core_theft, test_mx4_engine, test_offers, test_rewards, test_shop, test_card_pool, test_combos, test_engines, test_modifier_abilities, test_loot_pacing, test_player_builds, test_gun_pool_order | `Tests 212 / Passing Tests 212 / Asserts 4680` |
| at TW, the count fixes: test_items, test_items_j, test_heat, test_items_k / test_core_theft, test_mx4_engine, test_offers, test_rewards, test_shop, test_card_pool | `Tests 55 / Passing Tests 55 / Asserts 1115` / `Tests 77 / Passing Tests 77 / Asserts 1910` |

**Goldens:** none moved. `tests/golden/test_replay_ground_plane.gd`, `test_modifier_equivalence.gd` and
`test_state_hasher.gd` pass unchanged after TW and after XP (no golden fixture holds Twin, Spread, Fire or Explosive).

## LG: the legendary nerf

What changed: `LegendaryDefinition.stat_multiplier_by_card` (validated: an id of `stat_cards`, at least 1), set to
`damage: 1.3, attack_speed: 1.3` in `data/legendary/boss.tres`; `ContentCompiler.compile_stat_cards` uses it.
Legendary Power 250 → 325 ‰ (+32.5 %), Haste 180 → 234 ‰ (+23.4 %); the others epic × 1.6.

| Run | Summary |
|---|---|
| tests/content + test_arenas, test_reward_cards, test_rarity_views, test_card_pool | `Tests 182 / Passing Tests 182 / Asserts 12629` |
| tests/golden + test_old_saves, e2e reward_cards, e2e arenas, test_rarity, test_state_hasher | `Tests 28 / Passing Tests 28 / Asserts 1199` |

Not run locally: the full suite (GitHub runs it on the PR), `scripts/ci/seams.sh` (the lead's).
