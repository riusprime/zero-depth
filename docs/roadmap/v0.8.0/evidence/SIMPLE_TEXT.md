# v0.8.0 N16: simple text (O74)

Agent, branch `v080-n16` cut from `b21c313`. The runs below were made on that base with this step's changes in the
working tree (before the commit). Machine: cloud container, headless Godot 4.7.2 (shots: Xvfb + llvmpipe, software
GL, not the owner's hardware).

**What changed:** values only in `locale/strings.csv` (no key added, removed or renamed; row order kept), the two
regenerated `locale/strings.*.translation` files, two tests, the regenerated review workbook, the PLAN row, and
[`docs/text/REMOVALS_PROPOSAL.md`](../../../text/REMOVALS_PROPOSAL.md). **No text was removed** (step 3: the
removals wait on the owner). **No call site changed.**

## Counts

216 rows changed (each row is one key with its English and Spanish).

| Group | Rows |
|---|---|
| The owner's edits (from `docs/text/TEXT_REVIEW_owner_2026-10-18.xlsx`: 28 rows touched, 25 with new text; the 3 others were marked OK with no new text) | 25 |
| Cards: items, wand, gun, blade, legendary (`ITEM_*_DESC`) | 101 |
| Combo cards (`ITEM_COMBO_*_DESC`, `ABILITY_COMBO_*`; one combo renamed, see below) | 17 |
| Curses (`CURSE_*_DESC` / `_UP`) | 20 |
| End screen, what killed you (`CAUSE_*`, the longest ones only) | 17 |
| Achievements (`ACH_*_DESC`, besides the owner's) | 13 |
| Stat cards (`STAT_*_DESC`, the long ones; numbers kept, see below) | 6 |
| Weapon pick and skills (`BUILD_*_DESC`, `SKILL_*_DESC`) | 4 |
| Utility cards (`UTIL_*_DESC`) | 2 |
| Shop and reward lines (`SHOP_BUYS_*`, `PICK_TITLE_BOSS_MORE`) | 3 |
| "Hollow Crown" kept as a name in Spanish (wherever the Spanish named "la Corona Hueca") | 8 |

All 10 ability descriptions are the owner's. The weapon-pick and skill lines, utility cards, every item and combo card,
every curse and every achievement description with a mechanic in it are now one short sentence. The texts left
as they were are already short (names, prompts, labels, event flavour, the short `CAUSE_*` lines and the short stat
lines such as "+%s%% damage").

## How the style was applied

- One short sentence that gives the feel, no ranges, levels, seconds or internal words (stacks, ticks, permille), no
  "Modifier:" / "Utility button:" / "Gun:" / "Trinket:" / "Legendary:" prefixes (the card's tier line already says
  what kind of card it is). A count that *is* the card stays, as the owner kept "every 4th attack": Bomb Rounds
  "Every 5th shot is a bomb." / "Cada 5 disparos, lanzas una bomba."; Heavy Hands "Every 4th hit hits harder".
- Spanish written on its own in the owner's words: "esquivar" for the dash (as in the owner's Flame Trail line),
  "Teletranspórtate", "pega más fuerte", "desangra"; the Blade is "espada" in new lines (owner: "cartas de espada").
- **Stat cards keep their numbers.** The pick panel and the Codex fill a stat card's sentence with `tr(key) % args`
  (`pick_panel.gd` `card_face`, `codex_view.gd` `desc_of`), so each `%s` must stay or the format errors. Only the long
  ones were shortened, with the same placeholders (checked by the apply script: same `%s`/`%d`/`{0}` count per row,
  every group but curses).
- **Curses lost their numbers.** `CurseLook.fill` fills `%s` only when the text has one
  (`return text % value if text.contains("%s") else text`), so dropping it is safe with no code change. Curse lines
  keep no final period: `CurseLook` joins them as "Name: drawback · upside".
- Card faces: N8's gain line (what gets better, old → new, from the sim's forecast) is untouched, so a card still
  shows its numbers there; the sentence no longer repeats them (see the shots: "Perforación" with "Nivel 1 → 2" and
  "Tus disparos atraviesan a los enemigos.").
- Length rules: `test_item_descriptions_are_short` (≤ 60 per language) and the combo rule (1–60) pass.

## The owner's edits: typo fixes (for the owner to veto)

| Key | Owner wrote | Applied |
|---|---|---|
| `ABILITY_BLINK_DESC` (es) | Teletrasportáte hacia delante. | Teletranspórtate hacia delante. |
| `ABILITY_DRONE_BUDDY_DESC` (en) | A dron follows you and copies your attack. | A drone follows you and copies your attack. |
| `ABILITY_ARC_FIELD_DESC` (es) | … Conmociona enemigos | … Conmociona enemigos. (final period) |
| `ACH_BIOMES_ALL_DESC` (es) | Descubre todos los biomas | Descubre todos los biomas. (final period) |
| `ACH_CODEX_BLADE_NAME` (es) | Libro del herrero. | Libro del herrero (names have no period) |
| `ABILITY_AEGIS_DESC` (es) | … ataques enemigos.␠ | … ataques enemigos. (trailing space removed) |

Kept exactly as the owner wrote, though they may want another look: `ABILITY_FROST_NOVA_DESC` en "Every 4 deaths
throw a frost ring." (perhaps "Every 4 kills, throw a frost ring."), `ABILITY_COMBO_SWORD_DESC` en "Increase damage of
your combo and Lunge Cleave.", and "códice" in lower case in `ACH_CODEX_BLADE_DESC` (the menu says "Códice"; the new
Gun and Trigger lines follow the owner's lower case).

## The other language brought in line (the owner changed the meaning in one)

| Key | Owner (es) | English before → after |
|---|---|---|
| `ACH_CODEX_BLADE_DESC` | Descubre todas las cartas de espada en el códice. | See every card of the Blade pool in the Codex. → Discover every Blade card in the Codex. |
| `ACH_CURSED_CARD_DESC` | Elige una maldición. | Take a cursed chest's card. → Pick a curse. |
| `ACH_FINAL_NO_HIT_DESC` | Completa una fase de Hollow Crown sin ser golpeado. | Beat one of the Hollow Crown's bodies without being hit. → Clear a Hollow Crown phase without being hit. |

The Spanish-only renames (Electromagnetismo, Combo de espada, Compidron, Senda Ígnea, Lanzapulsos) keep their
English names (same meaning). `ACH_FINAL_LOOPED_DESC`'s English keeps its meaning and stays.

## Follow-on changes the owner's edits caused (for the owner to veto)

- **"Blade Dance" twice.** The owner renamed Orbiting Copies to Blade Dance / Danza de espadas; the combo
  `ABILITY_COMBO_BLADE_DANCE` was already "Blade Dance" / "Danza de Cuchillas". The combo is now **"Whirling Steel" /
  "Torbellino de acero"**. `ITEM_RAZOR_ORBIT_DESC` named "Orbiting Copies": now "Blade Dance makes enemies bleed." /
  "La Danza de espadas desangra a los enemigos."
- **Hollow Crown in Spanish.** Following "Derrota a Hollow Crown.", the Spanish names it "Hollow Crown" everywhere:
  `BOSS_HOLLOW_CROWN` (the boss bar), `UI_CODEX_SECTION_FINAL`, `UI_RECAP_TRUE_ENDING`, the three body Codex lines,
  `FINAL_ARENA_DESC` and the dev playground hint. The other bosses keep their Spanish names: a question in the
  removals proposal.

## Ten examples, before → after

| Key | English | Spanish |
|---|---|---|
| `ABILITY_AEGIS_DESC` (owner) | Utility button: hold to guard toward your aim (front hits deal a fifth). Each blocked hit stores a charge that adds 25% to your next swing; +1 charge cap per level. → **Hold to guard against enemies. Next attack deals more damage based on your blocks.** | Botón de utilidad: mantén para cubrirte hacia donde apuntas (los golpes de frente hacen una quinta parte). Cada golpe bloqueado guarda una carga que añade un 25 % a tu siguiente tajo; +1 carga máxima por nivel. → **Mantén para cubrirte de los enemigos. Potencia tu siguiente ataque al bloquear ataques enemigos.** |
| `ITEM_GRAVITY_WELL_DESC` | 8 % a shot (+3 %/lv): a 2 s black hole pulls and hurts. → **Your shots may open a black hole.** | 8 % por disparo (+3 %/nv): agujero negro que atrae y daña. → **Tus disparos pueden abrir un agujero negro.** |
| `ITEM_STATIC_CHAIN_DESC` | Bolts shock; every 3rd bolt hit arcs to another for 5. → **Your shots shock and jump to other enemies.** | Tus proyectiles electrizan; cada 3.º salta a otro: 5. → **Tus disparos electrocutan y saltan a otros.** |
| `ITEM_THRUST_DESC` | Stab: reach ×2, +30% damage; arc ×0.4, wider from Lv 3. → **Stab farther and harder, but narrower.** | Estocada: alcance ×2, +30% daño; arco ×0,4, más desde Nv 3. → **Estocadas más largas y fuertes, pero más estrechas.** |
| `ITEM_TRIGGER_ON_HIT_TWICE_DESC` | Legendary: cards to its right cast 2× a hit (4× a slash). → **Cards to its right cast twice on hit.** | Legendario: lo de su derecha, 2× por impacto (4× con tajo). → **Las cartas a su derecha se lanzan 2 veces al impactar.** |
| `ITEM_FROST_CORE_DESC` | Hits slow; the 3rd hit on a slowed enemy freezes it 1 s. → **Your hits slow and freeze enemies.** | Ralentizas; el 3.er golpe a un ralentizado lo congela 1 s. → **Tus golpes ralentizan y congelan.** |
| `ABILITY_COMBO_SUPERCONDUCTOR_DESC` | Lightning deals double damage to chilled foes. → **Lightning hits chilled enemies harder.** | Los rayos hacen doble daño a enemigos helados. → **Los rayos pegan más fuerte a los enemigos helados.** |
| `CURSE_MARKED_DESC` | Elites hunt you: +%s %% speed toward you, and more enemies are elites → **Elites hunt you, and there are more of them** | Las élites te cazan: +%s %% de velocidad hacia ti, y más enemigos son élite → **Las élites te cazan, y hay más** |
| `ACH_TRIGGER_KILL_DESC` | Kill an enemy with a child spell: one a trigger card or a split casts. → **Kill an enemy with a trigger card.** | Mata a un enemigo con un hechizo hijo: el que lanza una carta disparadora o una división. → **Mata a un enemigo con una carta disparadora.** |
| `CAUSE_SIEGE_RICOCHET` | A Siege Engine shell bounced off the wall and hit you from behind. → **A Siege Engine shell bounced into you.** | Un proyectil de la Máquina de Asedio rebotó en la pared y te dio por la espalda. → **Un proyectil rebotado de la Máquina de Asedio te alcanzó.** |

Every change is listed at the end of this file.

## Removals proposal

[`docs/text/REMOVALS_PROPOSAL.md`](../../../text/REMOVALS_PROPOSAL.md): 73 rows in 8 groups (tutorial hints 14,
bosses 15, enemies 14, biomes 5, Loop device and Ascension 5, shrine 5, floor/portal/room messages 9, menus that
explain 6; the wand read-out's 12 `WAND_READ_*` rows are one "ask" row). Recommendations: remove 10, shorten 48,
keep or ask 15. Nothing applied.

## Review workbook

`python3 scripts/content/text_review.py` → `build/TEXT_REVIEW.xlsx`, copied by hand to `docs/TEXT_REVIEW.xlsx` (the
current text for the owner's next pass). The owner's file `docs/text/TEXT_REVIEW_owner_2026-10-18.xlsx` is kept as
they sent it.

## Tests changed

- `tests/e2e/test_e2e_void.gd`: asserted the Void card's text names its chance ("8 %"); now asserts it has no
  number (N16).
- `tests/unit/presentation/test_card_frames.gd` `test_frost_nova_in_spanish_reflows_clear_of_the_gem`: used Frost
  Nova's Spanish sentence as the long sentence (> 150 chars) that must reflow clear of the gem; that sentence is now
  short, so the test keeps the old sentence as a constant (`LONG_ES`) and still proves the reflow.

Other tests that name a changed key compare against `tr(key)` (e.g. `test_e2e_shop` `SHOP_BUYS_*`,
`test_status_visuals`, `test_e2e_achievements`, `test_rarity_views`) and needed no change.

## Shots

`docs/roadmap/v0.8.0/evidence/n16_shots/`: the N8 reward-card script over the real HUD and pick panel, in English and
Spanish (Pierce, Power, Twin at an altar; Chain Blast and Spread at a legendary altar; a chest's card):
`hover_tilt_{en,es}.png`, `legendary_{en,es}.png`, `chest_{en,es}.png`.

```
xvfb-run -a -s "-screen 0 1600x1000x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
  --resolution 1600x1000 --fixed-fps 60 -s scripts/shots/reward_cards.gd -- --lang=en   (then --lang=es)
n8: renderer=gl_compatibility lang=en
n8: wrote …/build/shots/v0.8.0/n8/fan_facedown_en.png
…
```

The Codex shot script (`scripts/shots/codex.gd`, v0.7.5) was tried and is stale: its key presses now end on the
Credits page, not the Codex, so no Codex shot is included (not fixed here).

## Test results (raw, on `b21c313` + this step's working tree)

Lint:

```
$ gdformat --check src scripts tests
1024 files would be left unchanged
$ gdlint src scripts tests
Success: no problems found
```

`tests/content` (strings, locale coverage, item / combo length caps, Codex, achievements):

```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content -ginclude_subdirs -gexit
Scripts              26
Tests               133
Passing Tests       133
Asserts            9497
---- All tests passed! ----
```

`tests/unit/presentation` (**2 failures**):

```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gexit
Scripts             111
Tests               777
Passing Tests       775
Failing Tests         2
Asserts           1977309/1977311

res://tests/unit/presentation/test_ui_polish.gd
- test_the_swap_panel_wears_ember_stone_and_its_names_fit_the_tiles
    [Failed]:  [138.0] expected to be <= than [124.0]:  es: 'Electromagnetismo' (ABILITY_ARC_FIELD) fits a swap tile
          at line 298

res://tests/unit/presentation/test_wand_views.gd
- test_every_wand_card_name_fits_its_tile_in_both_languages
    [Failed]:  es: 'Electromagnetismo' of 'Electromagnetismo' is 138 px (124)
          at line 161
```

**Finding for the owner (not resolved quietly):** the owner's new Spanish name for Arc Field, "Electromagnetismo",
is one word 138 px wide at the tile's font size; the swap panel's and the wand row's tiles have 124 px for a word, so
it would be cut on those tiles. The owner's text is applied as written; the two tests are left failing. Options for
the owner: a shorter name (e.g. "Campo eléctrico", two words that wrap; widths not measured), or the tiles shrink a long word to
fit (a code change in `swap_panel.gd` / `wand_row.gd`, not made here).

e2e (through `main.tscn`):

```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_spanish.gd,res://tests/e2e/test_e2e_codex.gd,res://tests/e2e/test_e2e_rewards.gd,res://tests/e2e/test_e2e_reward_cards.gd,res://tests/e2e/test_e2e_pad_menus.gd,res://tests/e2e/test_e2e_shell.gd,res://tests/e2e/test_e2e_achievements.gd,res://tests/e2e/test_e2e_void.gd,res://tests/e2e/test_e2e_shop.gd,res://tests/e2e/test_e2e_curses.gd,res://tests/e2e/test_e2e_final_boss.gd -gexit
test_e2e_spanish 2/2 · test_e2e_codex 2/2 · test_e2e_rewards 3/3 · test_e2e_reward_cards 2/2 · test_e2e_pad_menus 5/5
test_e2e_shell 2/2 · test_e2e_achievements 0/1 · test_e2e_void 1/1 · test_e2e_shop 3/3 · test_e2e_curses 2/2
test_e2e_final_boss 1/1
Tests                24
Passing Tests        23
Failing Tests         1
Asserts           468/470

res://tests/e2e/test_e2e_achievements.gd
- test_an_achievement_unlocks_by_play_toasts_and_is_on_the_codex_page
    [Failed]:  its toast shows
          at line 79
    [Failed]:
          at line 80
```

`test_e2e_achievements` also fails **without N16**: with `locale/strings.csv` and both `.translation` files put back
to `b21c313` (the rest of the tree as above), the same test gives the same two failures (`Tests 1`, `Failing Tests 1`,
`Asserts 37/39`). So it is not caused by the text change; for the lead (the biome achievement's toast is not shown
within 900 frames of the run's start, perhaps since N11's arrival).

Not run (owner rule: no full suite, no bot tests): the rest of `tests/unit`, the sim and bot folders, the seams.

## Every change

Generated from the apply script's list (base `b21c313` → this step), grouped as in the counts.

### Utility cards (2)

| Key | English before → after | Spanish before → after |
|---|---|---|
| `UTIL_GUARD_DESC` | Hold to raise a shield toward your aim: hits from the front deal a fifth. You move slowly and can't attack. → **Hold to block hits from the front.** | Mantén para alzar un escudo hacia donde apuntas: los golpes de frente hacen una quinta parte. Te mueves despacio y no puedes atacar. → **Mantén para bloquear los golpes de frente.** |
| `UTIL_BLINK_DESC` | Press to teleport toward your aim, up to 5 m. Recharges in 2.5 s. → **Teleport where you aim.** | Pulsa para teletransportarte hacia donde apuntas, hasta 5 m. Se recarga en 2,5 s. → **Teletranspórtate hacia donde apuntas.** |

### Cards (items, wand, gun, blade, legendary) (101)

| Key | English before → after | Spanish before → after |
|---|---|---|
| `ITEM_LONG_EDGE_DESC` | Your blade reaches 35% farther. → **Your blade reaches farther.** | Tu hoja llega un 35% más lejos. → **Tu espada llega más lejos.** |
| `ITEM_TWIN_ARC_DESC` | Swings echo 0.1 s later at half damage. → **Your swings strike twice.** | Tus tajos se repiten 0,1 s después, a mitad de daño. → **Tus tajos golpean dos veces.** |
| `ITEM_EMBER_EDGE_DESC` | Melee hits burn: 2 every 0.5 s, up to 5 stacks. → **Your hits set enemies on fire.** | Tus golpes queman: 2 cada 0,5 s, hasta 5 veces. → **Tus golpes queman a los enemigos.** |
| `ITEM_SPLINTER_SHOT_DESC` | Shots fire 3 bolts in a fan, each at 60% damage. → **Shoot a fan of bolts.** | Disparas 3 proyectiles en abanico, al 60% de daño. → **Disparas en abanico.** |
| `ITEM_RAPID_COIL_DESC` | You shoot 40% faster. → **Shoot faster.** | Disparas un 40% más rápido. → **Disparas más rápido.** |
| `ITEM_RICOCHET_CORE_DESC` | Your bolts bounce off a wall once. → **Your shots bounce off walls.** | Tus proyectiles rebotan una vez en una pared. → **Tus disparos rebotan en las paredes.** |
| `ITEM_KINETIC_DASH_DESC` | Dashing through an enemy deals 12. → **Dash through enemies to hurt them.** | Atravesar a un enemigo con el esprint hace 12. → **Esquiva a través de los enemigos para dañarlos.** |
| `ITEM_OVERCHARGE_DESC` | Your finisher hits double with a shocking wave. → **Your finisher hits harder and shocks.** | Tu remate hace el doble y lanza una onda eléctrica. → **Tu remate golpea más fuerte y electrocuta.** |
| `ITEM_VAMPIRIC_CORE_DESC` | Kills heal 3 HP, up to 15 every 5 s. → **Kills heal you.** | Cada baja cura 3 PV, hasta 15 cada 5 s. → **Cada baja te cura.** |
| `ITEM_STATIC_CHAIN_DESC` | Bolts shock; every 3rd bolt hit arcs to another for 5. → **Your shots shock and jump to other enemies.** | Tus proyectiles electrizan; cada 3.º salta a otro: 5. → **Tus disparos electrocutan y saltan a otros.** |
| `ITEM_MOMENTUM_DESC` | A swing within 1 s of a dash deals +60% damage. → **Attack right after a dash to hit harder.** | Un tajo hasta 1 s tras el esprint hace +60% de daño. → **Ataca justo después de esquivar y pega más fuerte.** |
| `ITEM_FROST_CORE_DESC` | Hits slow; the 3rd hit on a slowed enemy freezes it 1 s. → **Your hits slow and freeze enemies.** | Ralentizas; el 3.er golpe a un ralentizado lo congela 1 s. → **Tus golpes ralentizan y congelan.** |
| `ITEM_THORN_MANTLE_DESC` | Taking damage fires a ring of 6 bolts. → **Getting hit fires bolts all around you.** | Al recibir daño lanzas un anillo de 6 proyectiles. → **Al recibir un golpe disparas a tu alrededor.** |
| `ITEM_EXECUTIONER_DESC` | +50% damage to enemies below 30% HP. → **Deal more damage to weak enemies.** | +50% de daño a enemigos con menos del 30% de PV. → **Haz más daño a los enemigos débiles.** |
| `ITEM_SWIFT_FEET_DESC` | Move 15% faster; dash recharges 20% sooner. → **Run faster and dash more often.** | Corres un 15% más; el esprint recarga un 20% antes. → **Corres más y esquivas más a menudo.** |
| `ITEM_PHASE_STRIKE_DESC` | Blinks and guard blocks deal 12 around you. → **Blinking or blocking hurts enemies around you.** | Destellar o bloquear hace 12 de daño a tu alrededor. → **Teletransportarte o bloquear daña a tu alrededor.** |
| `ITEM_CINDER_SHOT_DESC` | Every 3rd bolt hit adds a burn stack. → **Your shots set enemies on fire.** | Cada 3.er impacto de proyectil añade una quemadura. → **Tus disparos queman a los enemigos.** |
| `ITEM_WILDFIRE_DESC` | Kills spread burn to enemies within 2.5 m. → **Kills spread the fire.** | Cada baja propaga quemaduras a 2,5 m. → **Las bajas propagan el fuego.** |
| `ITEM_CONDUCTOR_DESC` | Swings shock; discharges jump to 2 more enemies. → **Your swings shock and jump to other enemies.** | Tus tajos electrizan; las descargas saltan a 2 más. → **Tus tajos electrocutan y saltan a otros.** |
| `ITEM_SERRATED_EDGE_DESC` | Swings bleed; dash through a bleeder to burst it. → **Your swings bleed. Dash through to burst them.** | Tus tajos sangran; esprinta a través para reventarlo. → **Tus tajos desangran. Esquiva a través para reventarlos.** |
| `ITEM_BARBED_BOLTS_DESC` | Every 2nd bolt hit adds a bleed stack. → **Your shots make enemies bleed.** | Cada 2.º impacto de proyectil añade un sangrado. → **Tus disparos desangran a los enemigos.** |
| `ITEM_GLACIAL_EDGE_DESC` | Swings chill; 4 frost stacks freeze for 1 s. → **Your swings chill and freeze.** | Tus tajos enfrían; 4 cargas de escarcha congelan 1 s. → **Tus tajos enfrían y congelan.** |
| `ITEM_COLD_SNAP_DESC` | Dashing through chills; frozen enemies take +60%. → **Dashing chills enemies. Frozen ones take more.** | Esprintar a través enfría; los congelados sufren +60%. → **Al esquivar enfrías. Los congelados sufren más.** |
| `ITEM_BULWARK_DESC` | Guard blocks store charges: next swing +40% each. → **Blocking powers up your next swing.** | Cada bloqueo guarda una carga: +40% al siguiente tajo. → **Bloquear potencia tu siguiente tajo.** |
| `ITEM_HEAT_SINK_DESC` | Vent blasts deal +50% and reach 30% farther. → **Your vents hit harder and farther.** | Las purgas hacen +50% y llegan un 30% más lejos. → **Tus purgas golpean más fuerte y más lejos.** |
| `ITEM_THERMAL_EDGE_DESC` | You run Hot from 30 heat instead of 40. → **You run Hot sooner.** | Entras en Caliente con 30 de calor en vez de 40. → **Entras en Caliente antes.** |
| `ITEM_CLUSTER_PAYLOAD_DESC` | Bomb Lobber's bombs split into 3 bomblets (40% damage each). → **Your bombs split into smaller bombs.** | Las bombas se dividen en 3 bombetas (40% de daño cada una). → **Tus bombas se dividen en bombas más pequeñas.** |
| `ITEM_OVERCLOCKED_DRONE_DESC` | Your drones fire 0.8% faster per point of heat. → **Your drones fire faster the hotter you are.** | Tus drones disparan un 0,8% más rápido por punto de calor. → **Tus drones disparan más rápido con más calor.** |
| `ITEM_RAZOR_ORBIT_DESC` | Orbiting Copies make enemies bleed (+1 per touch). → **Blade Dance makes enemies bleed.** | Las Copias orbitales hacen sangrar (+1 por toque). → **La Danza de espadas desangra a los enemigos.** |
| `ITEM_AFTERIMAGE_DESC` | Blinking leaves an echo that bursts for 18 soon after. → **Blinking leaves an echo that explodes.** | Al teletransportarte dejas un eco que estalla por 18. → **Al teletransportarte dejas un eco que estalla.** |
| `ITEM_STORM_CORE_DESC` | Hits chain lightning to 2 more enemies (50% damage). → **Your hits chain lightning.** | Tus golpes encadenan un rayo a 2 enemigos más (50%). → **Tus golpes lanzan rayos en cadena.** |
| `ITEM_EMBER_CORE_DESC` | Hits burn; kills explode in a small fire burst. → **Your hits burn. Kills explode in flames.** | Tus golpes queman; las bajas estallan en llamas. → **Tus golpes queman. Las bajas estallan en llamas.** |
| `ITEM_VENOM_CORE_DESC` | Hits stack poison that spreads when the enemy dies. → **Your hits poison. Poison spreads on death.** | Tus golpes envenenan; el veneno salta al morir. → **Tus golpes envenenan. El veneno salta al morir.** |
| `ITEM_ECHO_SLASH_DESC` | Slashes fly on as crescents (60%); +1 crescent a level. → **Your slashes fly as crescents.** | Tus tajos vuelan como medias lunas (60%); +1 por nivel. → **Tus tajos vuelan como medias lunas.** |
| `ITEM_EDGE_ROUNDS_DESC` | Projectiles pierce once and slash where they hit. → **Your shots pierce and slash where they hit.** | Los proyectiles atraviesan una vez y cortan al impactar. → **Tus disparos atraviesan y cortan al impactar.** |
| `ITEM_SHOCK_CIRCLES_DESC` | Trinket: projectiles become shock rings at half range. → **Your shots become shock rings.** | Baratija: los proyectiles son anillos de choque cortos. → **Tus disparos se vuelven anillos eléctricos.** |
| `ITEM_HALO_SHOT_DESC` | Gun: fires in a full ring, ×3 count, half range. → **Fire in a full ring.** | Pistola: dispara en anillo, ×3 balas, media distancia. → **Disparas en anillo.** |
| `ITEM_BOOMERANG_DESC` | Gun: flies out, then comes back through you. → **Your shots fly out and come back.** | Pistola: sale y vuelve pasando por ti. → **Tus disparos van y vuelven.** |
| `ITEM_ORBIT_ROUNDS_DESC` | Gun: circles you once before it flies out. → **Your shots circle you before flying out.** | Pistola: te rodea una vez antes de salir. → **Tus disparos te rodean antes de salir.** |
| `ITEM_SPLIT_SHOT_DESC` | Gun: splits in 3 on hit (+1 a level); splits don't explode. → **Your shots split on hit.** | Pistola: se parte en 3 al impactar (+1/nivel); no estallan. → **Tus disparos se dividen al impactar.** |
| `ITEM_TWIN_CAST_DESC` | Every attack repeats once 0.2 s later at 50%. → **Every attack repeats.** | Cada ataque se repite 0,2 s después al 50%. → **Cada ataque se repite.** |
| `ITEM_REARGUARD_DESC` | Every attack also fires backwards at 60%. → **Your attacks also fire backwards.** | Cada ataque también sale hacia atrás al 60%. → **Tus ataques también salen hacia atrás.** |
| `ITEM_WIDE_ARC_DESC` | Slashes sweep 60° wider and reach 30% farther. → **Your slashes sweep wider and farther.** | Tus tajos barren 60° más y llegan un 30% más lejos. → **Tus tajos barren más amplio y más lejos.** |
| `ITEM_GRAVITY_WELL_DESC` | 8 % a shot (+3 %/lv): a 2 s black hole pulls and hurts. → **Your shots may open a black hole.** | 8 % por disparo (+3 %/nv): agujero negro que atrae y daña. → **Tus disparos pueden abrir un agujero negro.** |
| `ITEM_SHATTER_DESC` | Kills burst into 4 shards that hit nearby enemies. → **Kills burst into shards.** | Las bajas estallan en 4 esquirlas que golpean cerca. → **Las bajas estallan en esquirlas.** |
| `ITEM_AFTERSHOCK_DESC` | Where an attack ends, a small blast. → **Your attacks end in a small blast.** | Donde termina un ataque, una pequeña explosión. → **Tus ataques acaban en una pequeña explosión.** |
| `ITEM_SEEKER_DESC` | Projectiles home in; arcs snap to the nearest enemy. → **Your attacks seek the nearest enemy.** | Los proyectiles persiguen; los arcos giran al más cercano. → **Tus ataques buscan al enemigo más cercano.** |
| `ITEM_LONG_SHADOW_DESC` | Dashing leaves a ghost that repeats your last slash. → **Dashing leaves a ghost that slashes.** | Al esquivar dejas un fantasma que repite tu último tajo. → **Al esquivar dejas un fantasma que ataca.** |
| `ITEM_PHASE_DASH_DESC` | Your dash is intangible and ends in 6 shards. → **Dash untouchable and burst into shards.** | Tu esquiva es intangible y acaba en 6 esquirlas. → **Esquiva intocable y estalla en esquirlas.** |
| `ITEM_EMBER_TRAIL_DESC` | Walking leaves burning crystals on the ground. → **Walking leaves burning crystals.** | Al caminar dejas cristales ardientes en el suelo. → **Al caminar dejas cristales ardientes.** |
| `ITEM_AETHER_SHELL_DESC` | 3 s out of combat: a barrier absorbs the next hit. → **Out of combat, a shield stops the next hit.** | 3 s sin combatir: una barrera absorbe el siguiente golpe. → **Fuera de combate, un escudo para el siguiente golpe.** |
| `ITEM_ASCENSION_DESC` | After 3 s without attacking, your next attack deals ×3. → **Wait before attacking to hit much harder.** | Tras 3 s sin atacar, tu siguiente ataque hace ×3. → **Espera antes de atacar y pega mucho más fuerte.** |
| `ITEM_RESONANCE_CORE_DESC` | Each status on an enemy: +15% damage taken. → **Enemies with more effects take more damage.** | Cada estado en un enemigo: +15% de daño recibido. → **Los enemigos con más efectos sufren más daño.** |
| `ITEM_HEAT_SINK_ROUNDS_DESC` | At Overclock, every attack fires one extra projectile. → **At Overclock, fire an extra shot.** | En Sobrecarga, cada ataque dispara un proyectil extra. → **En Sobrecarga, disparas un proyectil extra.** |
| `ITEM_MELTDOWN_EDGE_DESC` | Venting fires your weapon's attack in a full circle. → **Venting fires your attack all around you.** | Ventilar lanza el ataque de tu arma en círculo. → **Purgar lanza tu ataque a tu alrededor.** |
| `ITEM_MIRROR_DRONE_DESC` | Your drone copies your weapon's attack, modifiers too. → **Your drone copies your weapon and its cards.** | Tu dron copia el ataque de tu arma y sus modificadores. → **Tu dron copia tu arma y sus cartas.** |
| `ITEM_BOMB_ROUNDS_DESC` | Every 5th shot is a bomb (150% damage). → **Every 5th shot is a bomb.** | Cada 5.º disparo es una bomba (150% de daño). → **Cada 5 disparos, lanzas una bomba.** |
| `ITEM_BLADE_ORBIT_DESC` | Each slash throws off a blade that circles you for 3 s. → **Your slashes throw blades that circle you.** | Cada tajo suelta una hoja que gira a tu alrededor 3 s. → **Tus tajos sueltan espadas que te rodean.** |
| `ITEM_SHORT_FUSE_DESC` | Trinket: all ranges ×0.6, all damage ×1.4. → **Shorter reach, much more damage.** | Baratija: todo alcance ×0,6, todo daño ×1,4. → **Menos alcance, mucho más daño.** |
| `ITEM_TEMPEST_CORE_DESC` | Legendary: lightning chains to 4 more enemies (75%). → **Lightning jumps to many more enemies.** | Legendario: el rayo salta a 4 enemigos más (75%). → **El rayo salta a muchos más enemigos.** |
| `ITEM_INFERNO_CORE_DESC` | Legendary: hits burn twice; kills burst in big flames. → **Burn twice as hard. Kills erupt in flames.** | Legendario: quemas el doble; las bajas arden en grande. → **Quemas el doble. Las bajas arden en grande.** |
| `ITEM_ECHO_STORM_DESC` | Legendary: every slash flies on as 3 crescents (80%). → **Every slash flies as three crescents.** | Legendario: cada tajo vuela como 3 medias lunas (80%). → **Cada tajo vuela como tres medias lunas.** |
| `ITEM_TRIGGER_ON_HIT_DESC` | Cards to its right cast on each hit (twice on a slash). → **Cards to its right cast on hit.** | Lo de su derecha se lanza al impactar (2 veces con tajo). → **Las cartas a su derecha se lanzan al impactar.** |
| `ITEM_TRIGGER_ON_KILL_DESC` | Cards to its right cast on each kill (twice on a slash). → **Cards to its right cast on kill.** | Lo de su derecha se lanza al matar (2 veces con tajo). → **Las cartas a su derecha se lanzan al matar.** |
| `ITEM_TRIGGER_ON_END_DESC` | Cards to its right cast a small spell where it ends. → **Cards to its right cast where it ends.** | Las cartas a su derecha lanzan un hechizo al terminar. → **Las cartas a su derecha se lanzan al terminar.** |
| `ITEM_TRIGGER_ON_FINISHER_DESC` | Cards to its right cast twice on the finisher's hits. → **Cards to its right cast on your finisher.** | Lo de su derecha se lanza 2 veces al rematar. → **Las cartas a su derecha se lanzan al rematar.** |
| `ITEM_GUN_BIG_SHOT_DESC` | Gun: ×2 size, ×1.6 damage, −25% speed. → **Bigger, stronger, slower shots.** | Pistola: ×2 tamaño, ×1,6 daño, −25% velocidad. → **Disparos más grandes, fuertes y lentos.** |
| `ITEM_GUN_RAPID_FIRE_DESC` | Gun: ×0.6 size, +60% fire rate, −30% damage. → **Smaller, faster, weaker shots.** | Pistola: ×0,6 tamaño, +60% cadencia, −30% daño. → **Disparos más pequeños, rápidos y débiles.** |
| `ITEM_GUN_TWIN_DESC` | Gun: fires the spell twice, side by side. → **Fire twice, side by side.** | Pistola: dispara dos veces, lado a lado. → **Disparas dos veces, lado a lado.** |
| `ITEM_GUN_SPREAD_DESC` | Gun, count: a 3-shot fan (+2 a level); after Ring: 3 rings → **Fire in a fan.** | Pistola: abanico de 3 (+2 por nivel); tras Anillo: 3 anillos → **Disparas en abanico.** |
| `ITEM_GUN_RING_DESC` | Gun, shape: your shot is a flying, shocking lightning ring → **Your shot becomes a lightning ring.** | Pistola, forma: disparas un anillo de rayos que electrocuta → **Tu disparo se vuelve un anillo de rayos.** |
| `ITEM_GUN_SWIRL_DESC` | Gun, motion: throws what is left of it at random → **Your shots swirl at random.** | Pistola, movimiento: lanza al azar lo de su izquierda → **Tus disparos giran al azar.** |
| `ITEM_GUN_PIERCE_DESC` | Gun: passes through 2 enemies (+1 per level). → **Your shots pass through enemies.** | Pistola: atraviesa 2 enemigos (+1 por nivel). → **Tus disparos atraviesan a los enemigos.** |
| `ITEM_GUN_RICOCHET_DESC` | Gun: bounces off walls twice (+1 per level). → **Your shots bounce off walls.** | Pistola: rebota dos veces en paredes (+1 por nivel). → **Tus disparos rebotan en las paredes.** |
| `ITEM_GUN_HOMING_DESC` | Gun: curves toward the nearest enemy. → **Your shots curve toward enemies.** | Pistola: se curva hacia el enemigo más cercano. → **Tus disparos persiguen a los enemigos.** |
| `ITEM_GUN_SPIRAL_DESC` | Gun: travels in a corkscrew. → **Your shots corkscrew.** | Pistola: avanza en espiral. → **Tus disparos avanzan en espiral.** |
| `ITEM_GUN_MINE_DESC` | Gun: stops at its range, waits 3 s, blows on contact. → **Your shots stop and wait as mines.** | Pistola: se para, espera 3 s y estalla al contacto. → **Tus disparos se quedan como minas.** |
| `ITEM_GUN_CHARGE_DESC` | Gun: hold to grow it, up to ×3 size and damage. → **Hold to charge a bigger shot.** | Pistola: mantén para crecer, hasta ×3 tamaño y daño. → **Mantén para cargar un disparo mayor.** |
| `ITEM_GUN_ECHO_DESC` | Gun: fires again 0.3 s later at 60%. → **Fire again a moment later.** | Pistola: dispara otra vez 0,3 s después al 60%. → **Disparas otra vez un instante después.** |
| `ITEM_GUN_BACKFIRE_DESC` | Gun: also fires behind you. → **Also fire behind you.** | Pistola: también dispara hacia atrás. → **También disparas hacia atrás.** |
| `ITEM_SPLIT_WAVE_DESC` | A flying slash splits into 3 crescents on hit; +1 a level. → **Flying slashes split on hit.** | Un tajo volador se parte en 3 medias lunas; +1 por nivel. → **Tus tajos voladores se dividen al impactar.** |
| `ITEM_WHIRL_DESC` | Every slash becomes a full 360° spin. → **Every slash becomes a full spin.** | Cada tajo se vuelve un giro completo de 360°. → **Cada tajo se vuelve un giro completo.** |
| `ITEM_DOUBLE_SLASH_DESC` | Every slash repeats, mirrored, at 70%; +1 repeat a level. → **Every slash repeats, mirrored.** | Cada tajo se repite, en espejo, al 70%; +1 por nivel. → **Cada tajo se repite en espejo.** |
| `ITEM_THRUST_DESC` | Stab: reach ×2, +30% damage; arc ×0.4, wider from Lv 3. → **Stab farther and harder, but narrower.** | Estocada: alcance ×2, +30% daño; arco ×0,4, más desde Nv 3. → **Estocadas más largas y fuertes, pero más estrechas.** |
| `ITEM_HEAVY_DESC` | ×1.7 damage, big knockback; 30% slower (less from Lv 3). → **Slower swings that hit much harder.** | ×1,7 daño, gran empuje; 30% más lento (menos desde Nv 3). → **Tajos más lentos que golpean mucho más fuerte.** |
| `ITEM_FLURRY_DESC` | +50% swing speed; −25% damage, shrinking to 0 by Lv 5. → **Faster, lighter swings.** | +50% velocidad de tajo; −25% daño, hasta 0 en el Nv 5. → **Tajos más rápidos y ligeros.** |
| `ITEM_FISSURE_DESC` | Each slash cracks the ground ahead; the crack erupts. → **Your slashes crack the ground and it erupts.** | Cada tajo agrieta el suelo delante; la grieta estalla. → **Tus tajos agrietan el suelo y la grieta estalla.** |
| `ITEM_CHAIN_CUT_DESC` | A slash hit leaps to the next enemy within 4 m. → **Your slash hits jump to the next enemy.** | Un golpe de tajo salta al siguiente enemigo a 4 m. → **Tus tajos saltan al siguiente enemigo.** |
| `ITEM_BLADE_STORM_DESC` | Each slash throws 2 blades that fly out and back (+1/level). → **Your slashes throw blades that come back.** | Cada tajo lanza 2 hojas que van y vuelven; +1 por nivel. → **Tus tajos lanzan espadas que van y vuelven.** |
| `ITEM_RIPOSTE_CHAIN_DESC` | A slash kill slashes the next enemy in 4 m: 2, +1 a level. → **A slash kill strikes the next enemy.** | Un tajo que mata tajea al siguiente a 4 m: 2, +1 por nivel. → **Cada baja con tajo golpea al siguiente enemigo.** |
| `ITEM_PARRY_EDGE_DESC` | Your slashes destroy the enemy shots they touch. → **Your slashes destroy enemy shots.** | Tus tajos destruyen los disparos enemigos que tocan. → **Tus tajos destruyen los disparos enemigos.** |
| `ITEM_LUNGE_STEP_DESC` | Each slash steps you 1 m forward. → **Each slash steps you forward.** | Cada tajo te adelanta 1 m. → **Cada tajo te hace avanzar.** |
| `ITEM_FINISHER_PLUS_DESC` | The 4th slash bursts in a big shockwave with every card. → **Your finisher bursts in a big shockwave.** | El 4.º tajo estalla en una gran onda con todas tus cartas. → **Tu remate estalla en una gran onda.** |
| `ITEM_COUNTER_DESC` | A slash within 0.5 s of a dash deals ×2 and flies as a wave. → **Slash right after a dash to hit hard.** | Un tajo 0,5 s tras esquivar hace ×2 y vuela como onda. → **Ataca justo tras esquivar y pega fuerte.** |
| `ITEM_TRIGGER_ON_CRIT_DESC` | Cards to its right cast a small spell on each critical hit. → **Cards to its right cast on a critical hit.** | Las cartas a su derecha lanzan un hechizo en cada crítico. → **Las cartas a su derecha se lanzan con un crítico.** |
| `ITEM_SHARED_BLEED_DESC` | Hits bleed; the bleed ticks twice as fast while you move. → **Your hits bleed, faster while you move.** | Desangras; sangra el doble de rápido si te mueves. → **Desangras, y más rápido si te mueves.** |
| `ITEM_SHARED_EXPLOSIVE_DESC` | The spell explodes where it ends (its splits don't). → **Your attack explodes where it ends.** | El hechizo estalla donde termina (sus divisiones no). → **Tu ataque estalla donde termina.** |
| `ITEM_TRIGGER_ON_HIT_TWICE_DESC` | Legendary: cards to its right cast 2× a hit (4× a slash). → **Cards to its right cast twice on hit.** | Legendario: lo de su derecha, 2× por impacto (4× con tajo). → **Las cartas a su derecha se lanzan 2 veces al impactar.** |
| `ITEM_TRIGGER_ON_KILL_TWICE_DESC` | Legendary: cards to its right cast 2× a kill (4× a slash). → **Cards to its right cast twice on kill.** | Legendario: lo de su derecha, 2× por baja (4× con tajo). → **Las cartas a su derecha se lanzan 2 veces al matar.** |
| `ITEM_TRIGGER_ON_END_TWICE_DESC` | Legendary: cards to its right cast twice where it ends. → **Cards to its right cast twice where it ends.** | Legendario: lo de su derecha se lanza 2 veces al terminar. → **Las cartas a su derecha se lanzan 2 veces al terminar.** |
| `ITEM_CHAIN_BLAST_DESC` | The spell and all its splits explode; blasts never merge. → **Your attack and its splits all explode.** | El hechizo y sus divisiones estallan; nunca se funden. → **Tu ataque y sus divisiones estallan.** |

### End screen: what killed you (17)

| Key | English before → after | Spanish before → after |
|---|---|---|
| `CAUSE_BROOD_WEB` | The Brood Mother's web spiral of acid caught you. → **The Brood Mother's acid web caught you.** | La espiral de telaraña ácida de la Madre de la Prole te atrapó. → **La telaraña ácida de la Madre de la Prole te atrapó.** |
| `CAUSE_BROOD_EGG_BURST` | An egg the Brood Mother left burst into acid over you. → **A Brood Mother egg burst over you.** | Un huevo de la Madre de la Prole estalló en ácido sobre ti. → **Un huevo de la Madre de la Prole te estalló encima.** |
| `CAUSE_SIEGE_GRID` | The Siege Engine's mortar grid caught you on the wrong square. → **The Siege Engine's mortars caught you.** | La cuadrícula de morteros de la Máquina de Asedio te pilló en la casilla equivocada. → **Los morteros de la Máquina de Asedio te pillaron.** |
| `CAUSE_GATEKEEPER_PULL` | The Gatekeeper's vortex dragged you into its slam. → **The Gatekeeper's vortex pulled you in.** | El vórtice del Guardián de la Puerta te arrastró hasta su golpe. → **El vórtice del Guardián de la Puerta te atrapó.** |
| `CAUSE_BROOD_POUNCE` | The Brood Mother hunted you down in a run of leaps. → **The Brood Mother hunted you down.** | La Madre de la Prole te dio caza con una serie de saltos. → **La Madre de la Prole te dio caza.** |
| `CAUSE_SIEGE_SHOCKWAVE` | The Siege Engine's shockwave swept the room and you with it. → **The Siege Engine's shockwave swept you away.** | La onda de choque de la Máquina de Asedio barrió la sala y a ti con ella. → **La onda de choque de la Máquina de Asedio te barrió.** |
| `CAUSE_BOSS_ARENA` | The closing arena caught you against the wall. → **The closing arena crushed you.** | La arena que se cierra te atrapó contra el muro. → **La arena te aplastó contra el muro.** |
| `CAUSE_FOUNDRY_LAUNCH` | A Bomb Drone launched by the Foundry crushed you. → **A Foundry Bomb Drone crushed you.** | Un Dron Bombardero lanzado por la Fundición te aplastó. → **Un Dron Bombardero de la Fundición te aplastó.** |
| `CAUSE_HIVE_GAZE_ORBS` | The Hive Lens's orbs caught you while you ran from its gaze. → **The Hive Lens's orbs caught you.** | Los orbes de la Lente Enjambre te alcanzaron mientras huías de su mirada. → **Los orbes de la Lente Enjambre te alcanzaron.** |
| `CAUSE_SIEGE_RICOCHET` | A Siege Engine shell bounced off the wall and hit you from behind. → **A Siege Engine shell bounced into you.** | Un proyectil de la Máquina de Asedio rebotó en la pared y te dio por la espalda. → **Un proyectil rebotado de la Máquina de Asedio te alcanzó.** |
| `CAUSE_SIEGE_TURRET_RICOCHET` | A turret's shot bounced off the wall into you. → **A turret's bouncing shot hit you.** | El disparo de una torreta rebotó en la pared y te alcanzó. → **El disparo rebotado de una torreta te alcanzó.** |
| `CAUSE_FOUNDRY_LAVA` | You stood in the lava the Foundry left behind. → **You stood in the Foundry's lava.** | Te quedaste en la lava que dejó la Fundición. → **Pisaste la lava de la Fundición.** |
| `CAUSE_COLOSSUS_LEAP` | The Colossus's leap and its shockwave struck you. → **The Colossus's leap struck you.** | El salto del Coloso y su onda expansiva te golpearon. → **El salto del Coloso te golpeó.** |
| `CAUSE_COLOSSUS_BURST` | The Colossus's spikes burst out of the floor around it. → **The Colossus's spikes burst under you.** | Los pinchos del Coloso brotaron del suelo a su alrededor. → **Los pinchos del Coloso brotaron bajo tus pies.** |
| `CAUSE_PRISM_ORBS` | The Prism's orbs caught you between the beams. → **The Prism's orbs caught you.** | Los orbes del Prisma te alcanzaron entre los rayos. → **Los orbes del Prisma te alcanzaron.** |
| `CAUSE_PRISM_BOLT` | A fast bolt from the Prism's shards struck you. → **The Prism's bolt struck you.** | Un proyectil rápido de las esquirlas del Prisma te alcanzó. → **Un proyectil del Prisma te alcanzó.** |
| `CAUSE_NEMESIS_CARD` | The Fallen turned one of your own cards against you. → **The Fallen used your own card.** | El Caído usó una de tus propias cartas contra ti. → **El Caído usó tu propia carta.** |

### Combo cards (17)

| Key | English before → after | Spanish before → after |
|---|---|---|
| `ITEM_COMBO_PLASMA_ARC_DESC` | Shocking a burning enemy arcs fire to another. → **Shocking a burning enemy spreads the fire.** | Electrizar a un enemigo en llamas salta fuego a otro. → **Electrocutar a un enemigo en llamas propaga el fuego.** |
| `ITEM_COMBO_SHATTER_DASH_DESC` | Dashing through a frozen enemy shatters it for 30. → **Dash through frozen enemies to shatter them.** | Esprintar a través de un congelado lo rompe: 30. → **Esquiva a través de un congelado y rómpelo.** |
| `ITEM_COMBO_RESONANCE_DESC` | The echo of a charged swing sends a second wave. → **Charged swings send a second wave.** | El eco de un tajo cargado lanza otra onda. → **Tus tajos cargados lanzan otra onda.** |
| `ITEM_COMBO_SHRAPNEL_STORM_DESC` | Bolts that bounce burst into 2 shards. → **Bouncing shots burst into shards.** | Los proyectiles que rebotan estallan en 2 esquirlas. → **Los disparos que rebotan estallan en esquirlas.** |
| `ITEM_COMBO_BLOOD_HARVEST_DESC` | Executions burst in a blood nova that heals you. → **Executions burst in blood and heal you.** | Las ejecuciones estallan en sangre y te curan. |
| `ITEM_COMBO_SPIKED_PHASE_DESC` | Phase Strike also fires your ring of thorns. → **Phase Strike also fires your thorns.** | Golpe de Fase también lanza tu anillo de espinas. → **Golpe de Fase también lanza tus espinas.** |
| `ITEM_COMBO_SLIPSTREAM_DESC` | A Momentum swing that hits recharges your dash. → **Momentum hits recharge your dash.** | Un tajo de Inercia que acierta recarga el esprint. → **Los golpes de Inercia recargan tu esquiva.** |
| `ITEM_COMBO_FROZEN_BASTION_DESC` | Guard blocks chill the attacker: 2 frost stacks. → **Blocking chills the attacker.** | Bloquear enfría al atacante: 2 cargas de escarcha. → **Bloquear enfría al atacante.** |
| `ABILITY_COMBO_STORM_BOMBS_DESC` | Each bomb blast chains lightning to 3 enemies. → **Your bombs chain lightning.** | Cada explosión encadena rayos a 3 enemigos. → **Tus bombas lanzan rayos en cadena.** |
| `ABILITY_COMBO_NAPALM_DRONE_DESC` | Drone bolts set the ground on fire. → **Drone shots set the ground on fire.** | Los disparos del dron incendian el suelo. |
| `ABILITY_COMBO_GLACIER_RING_DESC` | Every blade touch adds frost. → **Your orbiting blades chill enemies.** | Cada toque de cuchilla añade escarcha. → **Tus espadas en órbita enfrían a los enemigos.** |
| `ABILITY_COMBO_BLINK_CHARGE_DESC` | Each blink leaves two bombs behind. → **Blinking leaves bombs behind.** | Cada destello deja dos bombas atrás. → **Al teletransportarte dejas bombas atrás.** |
| `ABILITY_COMBO_BLADE_DANCE` | Blade Dance → **Whirling Steel** | Danza de Cuchillas → **Torbellino de acero** |
| `ABILITY_COMBO_BLADE_DANCE_DESC` | Landed swings spread the blades: +50 % damage. → **Landing swings spreads your orbiting blades.** | Tus tajos abren las cuchillas: +50 % de daño. → **Tus tajos abren las espadas que te rodean.** |
| `ABILITY_COMBO_WINGMAN_DESC` | Your drones fire with every shot. | Tus drones disparan con cada disparo. → **Tus drones disparan contigo.** |
| `ABILITY_COMBO_SUPERCONDUCTOR_DESC` | Lightning deals double damage to chilled foes. → **Lightning hits chilled enemies harder.** | Los rayos hacen doble daño a enemigos helados. → **Los rayos pegan más fuerte a los enemigos helados.** |
| `ABILITY_COMBO_EMBER_WARD_DESC` | Blocking a hit bursts fire around you. → **Blocking bursts fire around you.** | Bloquear un golpe estalla en fuego a tu alrededor. → **Bloquear hace estallar fuego a tu alrededor.** |

### Weapon pick and skills (4)

| Key | English before → after | Spanish before → after |
|---|---|---|
| `BUILD_BLADE_DESC` | A four-slash combo toward where you face. No gun. → **Slash enemies up close.** | Un combo de cuatro tajos hacia donde miras. Sin pistola. → **Corta a los enemigos de cerca.** |
| `BUILD_GUN_DESC` | Hold to shoot where you aim. No blade. → **Shoot enemies from afar.** | Mantén para disparar hacia donde apuntas. Sin hoja. → **Dispara a los enemigos desde lejos.** |
| `SKILL_LUNGE_CLEAVE_DESC` | Skill: lunge 3.5 m where you face, then cleave everything in front of you. → **Lunge forward and cleave what's in front.** | Técnica: arremete 3,5 m hacia donde miras y luego tajea todo lo que tengas delante. → **Arremete hacia delante y corta todo a tu paso.** |
| `SKILL_SCATTER_BLAST_DESC` | Skill: a close-range spray of 7 pellets toward your aim that knocks enemies back. → **A close blast that knocks enemies back.** | Técnica: una ráfaga corta de 7 perdigones hacia donde apuntas que empuja a los enemigos. → **Una ráfaga corta que empuja a los enemigos.** |

### Owner's edits (25)

| Key | English before → after | Spanish before → after |
|---|---|---|
| `ABILITY_COMBO_SWORD` | Combo Sword | Espada de combo → **Combo de espada** |
| `ABILITY_COMBO_SWORD_DESC` | Your four-slash combo and Lunge Cleave. +12% damage per level; level 3 reaches 15% farther; level 5 finishers send a shockwave. → **Increase damage of your combo and Lunge Cleave.** | Tu combo de cuatro tajos y el Tajo en estocada. +12 % de daño por nivel; el nivel 3 alcanza un 15 % más; en el nivel 5 el remate lanza una onda. → **Aumenta el daño de tu combo y estocada.** |
| `ABILITY_PULSE_GUN` | Pulse Gun | Pistola de pulsos → **Lanzapulsos** |
| `ABILITY_PULSE_GUN_DESC` | Your held bolts and Scatter Blast. +12% damage per level; level 3 bolts pierce one enemy; level 5 fires twin bolts. → **Increase the damage of your weapon and Scatter Blast.** | Tus disparos sostenidos y la Ráfaga dispersa. +12 % de daño por nivel; en el nivel 3 los disparos atraviesan a un enemigo; en el nivel 5 disparas dobles. → **Aumenta el daño de tus disparos y ráfaga.** |
| `ABILITY_BOMB_LOBBER_DESC` | Modifier: every 4th weapon attack also lobs a bomb at the thickest crowd within 8 m (at most every 2.5 s): 22 damage in 2 m, carrying your weapon's elements and effects. More bombs at levels 2 and 4, bigger at 3 and 5. → **Throw bombs every 4th attack.** | Modificador: cada 4.º ataque del arma también lanza una bomba a la multitud más densa a 8 m (como mucho cada 2,5 s): 22 de daño en 2 m, con los elementos y efectos de tu arma. Más bombas en los niveles 2 y 4, más grandes en el 3 y el 5. → **Lanza una bomba cada 4 ataques.** |
| `ABILITY_DRONE_BUDDY` | Drone Buddy | Dron compañero → **Compidron** |
| `ABILITY_DRONE_BUDDY_DESC` | Modifier: a little drone follows you and fires a copy of your weapon's attack at the nearest enemy within 9 m three times a second for 5, with your elements and effects. +20% fire rate per level; a second drone at level 3; chaining bolts at level 5. → **A drone follows you and copies your attack.** | Modificador: un pequeño dron te sigue y dispara una copia del ataque de tu arma al enemigo más cercano a 9 m tres veces por segundo por 5, con tus elementos y efectos. +20 % de cadencia por nivel; un segundo dron en el nivel 3; disparos encadenados en el nivel 5. → **Un pequeño dron te sigue y copia tu ataque.** |
| `ABILITY_ORBIT_BLADES` | Orbiting Copies → **Blade Dance** | Copias orbitales → **Danza de espadas** |
| `ABILITY_ORBIT_BLADES_DESC` | Modifier: three copies of your attack orbit you at 1.6 m, 8 damage per touch with your elements and effects (each enemy at most every 0.5 s). +1 blade per level; a wider ring at level 5. → **Three copies of your attack orbit you.** | Modificador: tres copias de tu ataque orbitan a tu alrededor a 1,6 m, 8 de daño por toque con tus elementos y efectos (cada enemigo como mucho cada 0,5 s). +1 cuchilla por nivel; un anillo más ancho en el nivel 5. → **Tres copias de tu ataque orbitan a tu alrededor.** |
| `ABILITY_BLINK_DESC` | Utility button: teleport up to 5 m the way you move, through thin walls, and land with a 2 m shock for 15. Faster recharge per level; 2 charges at level 3; a wider shock at level 5. → **Teleport forward.** | Botón de utilidad: teletranspórtate hasta 5 m hacia donde te mueves, a través de muros finos, y aterriza con una onda de 2 m de 15. Recarga más rápida por nivel; 2 cargas en el nivel 3; una onda más ancha en el nivel 5. → **Teletranspórtate hacia delante.** |
| `ABILITY_AEGIS_DESC` | Utility button: hold to guard toward your aim (front hits deal a fifth). Each blocked hit stores a charge that adds 25% to your next swing; +1 charge cap per level. → **Hold to guard against enemies. Next attack deals more damage based on your blocks.** | Botón de utilidad: mantén para cubrirte hacia donde apuntas (los golpes de frente hacen una quinta parte). Cada golpe bloqueado guarda una carga que añade un 25 % a tu siguiente tajo; +1 carga máxima por nivel. → **Mantén para cubrirte de los enemigos. Potencia tu siguiente ataque al bloquear ataques enemigos.** |
| `ABILITY_ARC_FIELD` | Arc Field | Campo de arco → **Electromagnetismo** |
| `ABILITY_ARC_FIELD_DESC` | Modifier: your attacks leave a 1.6 m shock field where they end (at most every 1.5 s) for 2 s: 12 damage and a shock stack to enemies in it every 0.5 s. One more target a tick and a faster field every level. → **Your attacks leave a field where they land. Shock enemies.** | Modificador: tus ataques dejan un campo de choque de 1,6 m donde terminan (como mucho cada 1,5 s) durante 2 s: 12 de daño y una carga de choque a los enemigos dentro cada 0,5 s. Un objetivo más por tic y un campo más rápido por nivel. → **Tus ataques crean un campo de choque al impactar. Conmociona enemigos.** |
| `ABILITY_FROST_NOVA_DESC` | Modifier: your weapon gains the frost element (frost stacks on hit), and 4 kills in a row send a 3 m frost ring: 10 damage and 2 frost stacks (at most every 4 s). Wider every level; 4 frost stacks from level 3; every 3 s at level 5. → **Every 4 deaths throw a frost ring.** | Modificador: tu arma gana el elemento escarcha (cargas de escarcha al golpear) y 4 muertes seguidas lanzan un anillo de escarcha de 3 m: 10 de daño y 2 cargas de escarcha (como mucho cada 4 s). Más amplio por nivel; 4 cargas desde el nivel 3; cada 3 s en el nivel 5. → **Cada 4 muertes lanza un anillo de escarcha.** |
| `ABILITY_FLAME_TRAIL` | Flame Trail | Rastro de llamas → **Senda Ígnea** |
| `ABILITY_FLAME_TRAIL_DESC` | Modifier: your dash and your projectiles leave fire for 2 s: 6 damage a second and burn to enemies in it. +25 % duration and damage every level. → **Leave a flame trail after dashing or attacking.** | Modificador: tu esquiva y tus proyectiles dejan fuego 2 s: 6 de daño por segundo y quemadura a los enemigos en él. +25 % de duración y daño por nivel. → **Deja un rastro de llamas al esquivar o atacar.** |
| `ACH_BIOMES_ALL_DESC` | Enter a floor of every biome. → **Discover every biome.** | Entra en un piso de cada bioma. → **Descubre todos los biomas.** |
| `ACH_CURSED_CARD_DESC` | Take a cursed chest's card. → **Pick a curse.** | Toma la carta de un cofre maldito. → **Elige una maldición.** |
| `ACH_CODEX_BLADE_NAME` | Bladesmith's Ledger | Libro del espadero → **Libro del herrero** |
| `ACH_CODEX_BLADE_DESC` | See every card of the Blade pool in the Codex. → **Discover every Blade card in the Codex.** | Descubre en el Códice todas las cartas del mazo de la Espada. → **Descubre todas las cartas de espada en el códice.** |
| `ACH_ASCEND_1_DESC` | Take the Loop device and start a new loop. → **Start a new loop.** | Toma el dispositivo del Ciclo y empieza un nuevo ciclo. → **Empieza un nuevo ciclo.** |
| `ACH_ASCEND_5_DESC` | Take the Loop device 5 times. → **Start a new loop 5 times.** | Toma el dispositivo del Ciclo 5 veces. → **Empieza un nuevo ciclo 5 veces.** |
| `ACH_FINAL_BOSS_DESC` | Beat the Hollow Crown, the final boss. → **Beat the Hollow Crown.** | Derrota a la Corona Hueca, el jefe final. → **Derrota a Hollow Crown.** |
| `ACH_FINAL_NO_HIT_DESC` | Beat one of the Hollow Crown's bodies without being hit. → **Clear a Hollow Crown phase without being hit.** | Derrota a uno de los cuerpos de la Corona Hueca sin recibir un golpe. → **Completa una fase de Hollow Crown sin ser golpeado.** |
| `ACH_FINAL_LOOPED_DESC` | Beat the Hollow Crown after an Ascension loop. | Derrota a la Corona Hueca después de un ciclo de Ascensión. → **Derrota a Hollow Crown después de un ciclo de Ascensión.** |

### Stat cards (numbers kept: the card's number is passed in) (6)

| Key | English before → after | Spanish before → after |
|---|---|---|
| `STAT_REGEN_DESC` | Heal %s%% of max HP per second → **Heal %s%% HP a second** | Cura un %s %% de la vida máxima por segundo → **Te curas un %s %% de vida por segundo** |
| `STAT_PICKUP_RANGE_DESC` | +%s%% pickup and interact range → **+%s%% pickup range** | +%s %% de alcance para recoger e interactuar → **+%s %% de alcance para recoger** |
| `STAT_OVERKILL_DESC` | A kill splashes %s%% of its excess damage onto the nearest enemy → **Kills splash %s%% of extra damage nearby** | Una baja salpica el %s %% de su daño sobrante al enemigo más cercano → **Las bajas salpican un %s %% del daño sobrante** |
| `STAT_HOARDER_DESC` | +%s%% damage per 100 shards held, +%s%% shards → **+%s%% damage per 100 shards, +%s%% shards** | +%s %% de daño por cada 100 fragmentos guardados, +%s %% de fragmentos → **+%s %% de daño por cada 100 fragmentos, +%s %% de fragmentos** |
| `STAT_FAST_HANDS_DESC` | -%s%% auto ability cooldowns → **-%s%% ability cooldowns** | -%s %% de enfriamiento de las habilidades automáticas → **-%s %% de recarga de habilidades** |
| `STAT_LIFESPROUT_DESC` | Kills have a %s%% chance to drop a heal orb (+25%% HP); each extra card +%s%% → **Kills may drop a heal orb: %s%% (+%s%% per extra card)** | Las bajas tienen un %s %% de probabilidad de soltar un orbe de curación (+25 %% de vida); cada carta extra, +%s %% → **Las bajas pueden soltar un orbe de curación: %s %% (+%s %% por carta extra)** |

### Curses (no numbers; the code fills %s only when the text has one) (20)

| Key | English before → after | Spanish before → after |
|---|---|---|
| `CURSE_SWIFT_FOES_DESC` | Enemies move %s %% faster → **Enemies move faster** | Los enemigos se mueven un %s %% más rápido → **Los enemigos son más rápidos** |
| `CURSE_WITHERING_DESC` | −%s %% regeneration → **You heal less** | −%s %% de regeneración → **Te curas menos** |
| `CURSE_LEAKY_CORE_DESC` | Overclock heat fades %s %% faster → **Your heat fades faster** | El calor de sobrecarga se disipa un %s %% más rápido → **Tu calor se disipa antes** |
| `CURSE_SWARM_CALL_DESC` | +%s enemy in every pack → **More enemies in every pack** | +%s enemigo en cada grupo → **Más enemigos en cada grupo** |
| `CURSE_PRICE_GOUGE_DESC` | Shard prices +%s %% → **Everything costs more** | Precios en fragmentos +%s %% → **Todo cuesta más** |
| `CURSE_MARKED_DESC` | Elites hunt you: +%s %% speed toward you, and more enemies are elites → **Elites hunt you, and there are more of them** | Las élites te cazan: +%s %% de velocidad hacia ti, y más enemigos son élite → **Las élites te cazan, y hay más** |
| `CURSE_MARKED_UP` | A slain elite drops a free rare card → **Slain elites drop a free rare card** | Una élite abatida suelta una carta rara gratis → **Las élites abatidas sueltan una carta rara** |
| `CURSE_ROOTED_UP` | %s %% chance to dodge a hit → **Sometimes dodge a hit** | Un %s %% de probabilidad de esquivar un golpe → **A veces esquivas un golpe** |
| `CURSE_HEAVY_HANDS_DESC` | Attack speed −%s %% → **You attack slower** | Velocidad de ataque −%s %% → **Atacas más lento** |
| `CURSE_HEAVY_HANDS_UP` | Every 4th hit (combo or shot) deals +%s %% → **Every 4th hit hits harder** | Cada 4.º golpe (combo o disparo) hace +%s %% → **Cada 4 golpes, uno pega más fuerte** |
| `CURSE_GLASS_HEART_DESC` | Max HP −%s %% → **Less max HP** | Vida máxima −%s %% → **Menos vida máxima** |
| `CURSE_GLASS_HEART_UP` | +%s %% crit chance → **More crit chance** | +%s %% de probabilidad de crítico → **Más probabilidad de crítico** |
| `CURSE_BLOOD_PRICE_DESC` | Each Skill or Blink costs %s %% of max HP (never lethal) → **Skills and Blink cost HP** | Cada Técnica o Destello cuesta un %s %% de la vida máxima (nunca letal) → **Las técnicas y el Destello cuestan vida** |
| `CURSE_BLOOD_PRICE_UP` | Skills and abilities deal +%s %% → **Skills and abilities hit harder** | Técnicas y habilidades hacen +%s %% → **Técnicas y habilidades pegan más fuerte** |
| `CURSE_FEVERED_DESC` | Heat fades %s %% slower → **Heat fades slower** | El calor se disipa un %s %% más lento → **El calor tarda más en irse** |
| `CURSE_FEVERED_UP` | Overclock deals +%s %% → **Overclock hits harder** | La sobrecarga hace +%s %% → **La sobrecarga pega más fuerte** |
| `CURSE_TUNNEL_VISION_DESC` | The minimap is off → **No minimap** | El minimapa está apagado → **Sin minimapa** |
| `CURSE_TUNNEL_VISION_UP` | +%s %% shards → **More shards** | +%s %% de fragmentos → **Más fragmentos** |
| `CURSE_BRITTLE_DESC` | A hit taken stuns you for %s s → **Getting hit stuns you** | Un golpe recibido te aturde %s s → **Los golpes te aturden** |
| `CURSE_BRITTLE_UP` | Move %s %% faster → **Move faster** | Te mueves un %s %% más rápido → **Te mueves más rápido** |

### Shop and reward lines (3)

| Key | English before → after | Spanish before → after |
|---|---|---|
| `SHOP_BUYS_LEFT` | Cards you can still buy on this floor: %d → **Buys left: %d** | Cartas que aún puedes comprar en esta planta: %d → **Compras restantes: %d** |
| `SHOP_BUYS_DONE` | No buys left on this floor (%d of %d bought) → **No buys left (%d/%d)** | No te quedan compras en esta planta (%d de %d compradas) → **Sin compras (%d/%d)** |
| `PICK_TITLE_BOSS_MORE` | %s · %d more picks here → **%s · %d more** | %s · %d elecciones más aquí → **%s · %d más** |

### Achievements (13)

| Key | English before → after | Spanish before → after |
|---|---|---|
| `ACH_CLEAR_FLOOR_1_DESC` | Clear floor 1: take its portal. → **Clear the first floor.** | Supera el piso 1: cruza su portal. → **Supera el primer piso.** |
| `ACH_CLEAR_FLOOR_2_DESC` | Clear floor 2. → **Clear the second floor.** | Supera el piso 2. → **Supera el segundo piso.** |
| `ACH_WIN_RUN_DESC` | Win a run: beat the last floor's boss. → **Win a run.** | Gana una partida: derrota al jefe del último piso. → **Gana una partida.** |
| `ACH_BOSSES_ALL_DESC` | Defeat every boss at least once. → **Defeat every boss.** | Derrota a cada jefe al menos una vez. → **Derrota a todos los jefes.** |
| `ACH_BIOME_DESC` | Enter a floor of this biome: %s. → **Discover a biome: %s.** | Entra en un piso de este bioma: %s. → **Descubre un bioma: %s.** |
| `ACH_WAND_FULL_DESC` | Hold 8 cards in your wand. → **Fill your wand.** | Lleva 8 cartas en tu varita. → **Llena tu varita.** |
| `ACH_CARD_LEVEL_5_DESC` | Raise a card to level 5. → **Max out a card.** | Sube una carta al nivel 5. → **Mejora una carta al máximo.** |
| `ACH_TRIGGER_KILL_DESC` | Kill an enemy with a child spell: one a trigger card or a split casts. → **Kill an enemy with a trigger card.** | Mata a un enemigo con un hechizo hijo: el que lanza una carta disparadora o una división. → **Mata a un enemigo con una carta disparadora.** |
| `ACH_TRIGGER_KILLS_100_DESC` | Kill 100 enemies with child spells. → **Kill 100 enemies with trigger cards.** | Mata a 100 enemigos con hechizos hijos. → **Mata a 100 enemigos con cartas disparadoras.** |
| `ACH_NO_HIT_ROOM_DESC` | Clear a sealed room without losing any HP. → **Clear a sealed room without getting hit.** | Supera una sala sellada sin perder vida. → **Supera una sala sellada sin recibir daño.** |
| `ACH_CORE_STOLEN_DESC` | Steal a core from an elite or a boss. → **Steal a core.** | Roba el núcleo de un élite o de un jefe. → **Roba un núcleo.** |
| `ACH_CODEX_GUN_DESC` | See every card of the Gun pool in the Codex. → **Discover every Gun card in the Codex.** | Descubre en el Códice todas las cartas del mazo de la Pistola. → **Descubre todas las cartas de pistola en el códice.** |
| `ACH_CODEX_TRIGGERS_DESC` | See every trigger card in the Codex. → **Discover every trigger card in the Codex.** | Descubre en el Códice todas las cartas disparadoras. → **Descubre todas las cartas disparadoras en el códice.** |

### Hollow Crown kept as a name in Spanish (8)

| Key | English before → after | Spanish before → after |
|---|---|---|
| `BOSS_COLOSSUS_DESC` | The Hollow Crown's first body: stone fists as big as a man. It never stops: fist combos that follow you and end in a ground slam, leaps that crack the floor in a shockwave ring, lines of stone spikes that chase you across the arena and bursts of them all around it, and boulders that shatter into shards where they land. Every blow locks half a second before it lands. | El primer cuerpo de la Corona Hueca: puños de piedra tan grandes como un hombre. Nunca se detiene: combos de puños que te siguen y acaban en un golpe al suelo, saltos que agrietan el suelo en un anillo de onda expansiva, líneas de pinchos de piedra que te persiguen por la arena y estallidos de pinchos a su alrededor, y rocas que se rompen en esquirlas al caer. Cada golpe se fija medio segundo antes de caer. → **El primer cuerpo de Hollow Crown: puños de piedra tan grandes como un hombre. Nunca se detiene: combos de puños que te siguen y acaban en un golpe al suelo, saltos que agrietan el suelo en un anillo de onda expansiva, líneas de pinchos de piedra que te persiguen por la arena y estallidos de pinchos a su alrededor, y rocas que se rompen en esquirlas al caer. Cada golpe se fija medio segundo antes de caer.** |
| `BOSS_PRISM_DESC` | The Hollow Crown's second body: a torn figure ringed by floating red crystal shards. She floats at the arena's heart inside the Cross, four beams that turn round the room, reversing, faster as she weakens. Her shards weave rings, spirals and flowers of orbs between the beams and fire quick bolts down a short aim line. She is shielded while the Cross turns: strike in the short windows between its spins. Her strength is measured from your own damage, so she lasts about a minute however strong you are. | El segundo cuerpo de la Corona Hueca: una figura rasgada rodeada de esquirlas de cristal rojo que flotan. Flota en el corazón de la arena dentro de la Cruz, cuatro rayos que giran por la sala, cambian de sentido y aceleran a medida que se debilita. Sus esquirlas tejen anillos, espirales y flores de orbes entre los rayos y disparan proyectiles rápidos por una breve línea de mira. Está protegida mientras la Cruz gira: golpea en las breves ventanas entre giros. Su fuerza se mide a partir de tu propio daño, así que dura un minuto más o menos por fuerte que seas. → **El segundo cuerpo de Hollow Crown: una figura rasgada rodeada de esquirlas de cristal rojo que flotan. Flota en el corazón de la arena dentro de la Cruz, cuatro rayos que giran por la sala, cambian de sentido y aceleran a medida que se debilita. Sus esquirlas tejen anillos, espirales y flores de orbes entre los rayos y disparan proyectiles rápidos por una breve línea de mira. Está protegida mientras la Cruz gira: golpea en las breves ventanas entre giros. Su fuerza se mide a partir de tu propio daño, así que dura un minuto más o menos por fuerte que seas.** |
| `BOSS_NEMESIS_DESC` | The Hollow Crown's last body: a small dark hooded figure, your own shadow, fallen. It fights with a kit of its own, and at times it reaches for yours: for a few seconds it takes your weapon, your dash, your steps and the strongest cards of your wand, and pulls your power down to its level, an even duel. Its strength follows yours. | El último cuerpo de la Corona Hueca: una pequeña figura encapuchada y oscura, tu propia sombra, caída. Lucha con sus propias armas y, a ratos, alcanza las tuyas: durante unos segundos toma tu arma, tu impulso, tus pasos y las cartas más fuertes de tu varita, y rebaja tu poder hasta el suyo, un duelo igualado. Su fuerza sigue a la tuya. → **El último cuerpo de Hollow Crown: una pequeña figura encapuchada y oscura, tu propia sombra, caída. Lucha con sus propias armas y, a ratos, alcanza las tuyas: durante unos segundos toma tu arma, tu impulso, tus pasos y las cartas más fuertes de tu varita, y rebaja tu poder hasta el suyo, un duelo igualado. Su fuerza sigue a la tuya.** |
| `BOSS_HOLLOW_CROWN` | The Hollow Crown | La Corona Hueca → **Hollow Crown** |
| `FINAL_ARENA_DESC` | A round arena of dark violet stone hung in the star-lit void, red crystal in its veins and its tiers empty. Its great gate is sealed: the only way out is through the Hollow Crown. | Una arena redonda de piedra violeta oscura suspendida en el vacío estrellado, con cristal rojo en sus vetas y sus gradas vacías. Su gran puerta está sellada: la única salida es a través de la Corona Hueca. → **Una arena redonda de piedra violeta oscura suspendida en el vacío estrellado, con cristal rojo en sus vetas y sus gradas vacías. Su gran puerta está sellada: la única salida es a través de Hollow Crown.** |
| `UI_CODEX_SECTION_FINAL` | The Hollow Crown | La Corona Hueca → **Hollow Crown** |
| `UI_RECAP_TRUE_ENDING` | The Hollow Crown is broken: the true ending. | La Corona Hueca está rota: el verdadero final. → **Hollow Crown está rota: el verdadero final.** |
| `UI_PG_FINAL_HINT` | Summons the Hollow Crown at the room's centre; a phase button jumps to that body. | Invoca a la Corona Hueca en el centro de la sala; un botón de fase salta a ese cuerpo. → **Invoca a Hollow Crown en el centro de la sala; un botón de fase salta a ese cuerpo.** |
