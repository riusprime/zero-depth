# FC0: Rune Explosion replaces Scatter (v0.9.5 Step FC0, FORM_COMBOS.md R0 and R1)

- **Status:** RUN (agent). Owner playtest of the look and feel: OWNER ONLY (empty).
- **Build:** the commit that holds this file, on branch `v095-fc0` (cut from `claude/v095-feedback` at `fa7a05c4`;
  a file cannot name its own commit, the SHA is in the step report); Godot 4.7.2 stable; OS Windows 11 Pro, owner PC
  (RTX 3060), several Godot processes at once (no timings here are evidence).
- **Date:** 2026-10-26
- **Who ran it:** agent

Owner line: "The shotgun form, the scatter has to go, we are gonna be replacing it with rune explosion, a violet
explosion that comes out of the player as an energy kind like shield that grown, just like a mage from world of
warcraft."

## What was built

- Card `gun_rune_explosion` (item + modifier, Form slot, level_max 1, Rare like Scatter, family `area`, stage 3 like
  the Bomb). Data: radius 3500 mm, growth 0.35 s (21 ticks), period 1.1 s (66 ticks, `rate_scale_permille` 500 like
  the other forms), damage multiplier x3.75 (see the DPS section: x3.0 was the spec, tuned up by the allowed +25 %).
- `src/sim/combat/rune_explosion.gd` (pure): `Attacks._shared_form` hands the whole shot to `RuneExplosion.fire`
  (no bolt leaves). Bursts live in `ModifierState.rune_*` (uid, spec key, born tick, radius, damage, root, the enemies
  each burst hit, the shoves), hashed and saved only while one lives (older digests unchanged), copied by
  `WorldSnapshot`. The ring is centred on the hero every tick, edge = radius x age / 21 in whole mm, each enemy hit
  once per burst the tick `enemies_near(centre, edge)` first holds it (edge >= distance - enemy radius), as
  `Attacks.land` under the spec (elements, On Hit/On Kill hooks), tags `TAG_AREA | TAG_PROJECTILE` (so
  `Heat.NOT_ATTACK` makes it add no heat). Hit = shove 0.4 m outward over 6 ticks (bosses ignore it, as the Blade's
  shove). The burst stays 9 ticks (0.15 s) after the growth for the view's fade, hitting nothing.
- Twin (R1): `twin` extra bursts (Lv 1-2: one, Lv 3: two) every 12 ticks, 70 % radius and `share_permille` (Twin's
  70 %) damage. At most 3 live bursts; a burst is no projectile, so it is not counted in ShotCap's 40 a second (the
  Laser's rule; Bomb's bomb is a projectile, a burst is not).
- `AttackSpec.rune_mm` / `rune_ticks` (LATE_INT_FIELDS: hashed only when set), ops `rune_radius_mm`, `rune_seconds`.
- Retirement: `gun_scatter` appended to `data/wand/migration.tres` (`old_ids`, `blade_into` "", `gun_into`
  `gun_rune_explosion`), so it is retired, never offered, and a save holding it loads holding Rune Explosion. The
  Scatter's `attack_slots` row was removed (content validation rejects a row for a retired card); its item, modifier,
  `scatter.gd`, `ScatterView` and tests stay for a retired card the dev panel can still grant. The Gun skill "Scatter
  Blast" is untouched.
- Row `rune_explosion`: Twin and the five elements.
- View `rune_explosion_view.gd`: translucent violet dome (hemisphere, 0.45 x radius tall, alpha <= 0.35, blend_mix),
  floor ring quad with a cached 12-glyph rune strip texture and inner glow (blend_add, masked to the disc), all
  `fog_disabled`; core #9B5CFF, rim #D9C2FF; fades over the last 30 % of the growth plus 0.15 s; HeroFx flash on each
  hit; Low density: no inner glow, fewer sparks; Reduced motion: no dome, no shimmer.
- Sound `rune_burst` (generate_sfx.py, 0.53 s, peak -1 dBFS; only the new wav and its manifest row kept, the six old
  wavs a re-render rewrites were restored with `git checkout`), cue `data/audio/cues/rune_burst.tres` (pitch_jitter
  0.12, caption `CAPTION_RUNE_BURST`), played once per new burst (`AudioEvents`, by burst uid). Credits list rebuilt
  with `scripts/content/build_credits.gd` (131 files).
- Text (en/es): `ITEM_GUN_RUNE_EXPLOSION`, `ITEM_GUN_RUNE_EXPLOSION_DESC`, `CAPTION_RUNE_BURST`. Card frame: family
  `trinket` (no new art).
- `scripts/balance/forms_dps.gd` and `affinity_bot.gd`: the Scatter row became Rune Explosion; the DPS script also
  measures short-reach forms in NEAR scenes and holds its dummies in place (see below).

## DPS check

Command (headless, owner PC):
```
godot --headless --path . -s scripts/balance/forms_dps.gd      # writes build/balance/forms_dps.txt
```
The far scenes (single at 4 m, line 2 to 8 m, pack on a 4 m arc) are mostly beyond the ring (3.5 m + 0.35 m): a
Rune Explosion reads 0.000 single and pack there. So the script now also runs NEAR scenes for it, against the orbs
in the same near scenes (single at 2.5 m; line five at 1 to 3 m; pack five on a 2.5 m arc of 1.2 rad), and puts the
dummies back each tick (the 0.4 m shove would otherwise carry a static dummy out of reach for good; a real enemy
walks back in).

| Version | Hit | single x | line x | pack x | single dmg | line dmg | pack dmg |
|---|---|---|---|---|---|---|---|
| orbs baseline, NEAR scenes | 5 | 1.000 | 1.000 | 1.000 | 935 | 330 | 335 |
| x3.0 (the spec) | 15 | 0.417 | 2.045 | 2.015 | 390 | 675 | 675 |
| x3.75 (+25 %, the cap) | 18 | 0.501 | 2.455 | 2.418 | 468 | 810 | 810 |

Raw lines (`build/balance/forms_dps.txt`, the x3.75 run):
```
orbs baseline, NEAR scenes (for [&"rune_explosion"]): single 935, line 330, pack 335
rune_explosion (near) | 1 | no | 0.501 | 2.455 | 2.418 | 468 | 810 | 810
rune_explosion (near) | 1 | yes | 1.249 | 5.509 | 6.179 | 1168 | 1818 | 2070
```
(the x3.0 run: `rune_explosion (near) | 1 | no | 0.417 | 2.045 | 2.015 | 390 | 675 | 675`).

Result against the target (single about 0.5-0.6x, pack about 2.5-3.5x): single 0.501 is at the low edge, **pack
2.418 is just under 2.5**. The multiplier was moved by the allowed +25 % (3.0 to 3.75, which the integer damage
makes 18 per hit, not 18.75); further tuning is beyond the step's limit, so it stops here. The owner decides whether
to go further.

## Tests (all with `--language en`, own APPDATA per run)

Totals as GUT printed them (final runs after the last edit unless noted): sim batch (rune_explosion, scatter,
wand_migration, attack_slots, shot_rate_all_forms, card_levels_clv, rewards, player_builds) 8 scripts, 111 tests, 111
passing; content + presentation batch (item/modifier/wand_migration validation, credits licences, rune_explosion_view,
audio_director) 6 scripts, 44 of 44; e2e `test_e2e_lance_scatter.gd` 2 of 2; `tests/golden` 2 of 2; `tests/arch` 4 of
4 (all on the pre-tuning x3.0 build, no later change touches them); earlier run (before the x3.75 retune and the
count fixes) of gun_pool 19/19, gun_pool_order 12/12, offers, heat, scatter_view, vx_looks with no failure; the
`tests/content` folder run before the count fixes: 157 tests, 5 failures (four were this step's counts and the credits
list, fixed and re-run above; the fifth is `test_player_compiles_to_ticks` below). The files and folders: `tests/unit/sim/test_rune_explosion.gd` (new, 15),
`test_scatter.gd` (9; the row tests became "no row, never offered"), `test_wand_migration.gd`,
`test_attack_slots.gd`, `test_shot_rate_all_forms.gd`, `test_card_levels_clv.gd`, `test_rewards.gd`,
`test_player_builds.gd`, `test_gun_pool.gd`, `test_gun_pool_order.gd`, `test_offers.gd`, `test_heat.gd`,
`tests/content` (folder), `tests/golden` (folder: 2 of 2 pass, no digest moved, so no golden changed on purpose),
`tests/arch` (folder: 4 of 4), `tests/unit/presentation/test_rune_explosion_view.gd` (new),
`test_audio_director.gd`, `test_scatter_view.gd`, `test_vx_looks.gd`, and the e2e
`tests/e2e/test_e2e_lance_scatter.gd` (its Scatter test became the Rune Explosion test: the card is taken at an
altar, SHOOT held, the 2 m dummy was hurt (54) and shoved, the 6 m one untouched, the ring drawn at 3.50 m, the
boom heard).

Failing here and not touched by this step (NOT run on the base tree to confirm; I did not check out a baseline):
`tests/content/test_content_valid.gd::test_player_compiles_to_ticks` ([600] expected [84], player data, not Gun
forms), and `tests/unit/sim/test_items.gd::test_the_pool_never_repeats_and_skips_owned_and_placed` ([60] expected [65]
on a Blade-start lab pool; this step's net change to that pool is zero: Scatter retired, Rune Explosion added, and a
probe listing the pool shows `gun_rune_explosion` in and no `gun_scatter`).

## Shot

`build/shots/v0.9.5/fc0/1_rune_burst.jpg` (not tracked): 14 ticks after a burst among five standing dummies in the
Ruins stage; it shows the violet dome and the rune ring at about 2.3 m, with the ring's glow and the rim, and the
nearest dummy flashing white as it is hit (18 damage).

## Not done / owner

- The look (colours, glyph strip, dome height), the feel and the sound are OWNER ONLY.
- R2-R9 (Ring, Ricochet, Homing, Echo, Big Shot, Rapid Fire, Split, Mine on this form) are not in this step.
