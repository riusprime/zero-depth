# v0.9.5 Step TX: a Gun card's text says what it does on the form you hold

Base: `d6c4f421` (`claude/v095-feedback`, includes `28218c03`). Machine: the owner's PC, Godot 4.7.2, `--language en`,
each process with its own `APPDATA`.

## What was built

- `src/presentation/menus/form_card_text.gd` (`FormCardText`, static, presentation): `line_for(form_id, card_id)` returns
  the translated line `FORMCARD_<FORM>_<CARD>`; `FORMCARD_OFF` for a card the form does not allow (read from
  `data/wand/attack_slots.tres` `forms[].allowed`, the table the sim reads); `""` for the Orbs (all cells), the form
  cards, the element cores and the Blade (`form_id` is `&""` there). `accent_for(form_id)` is the Form card's colour
  (`ItemLooks`), else a fallback orange.
- `WorldReader.attack_form_id()`: the held Form card's row id (`AttackSlots.form_id`), `&""` on a Blade run.
- `PickPanel.card_face` adds `form_line` and `form_color` to a Pattern or Secondary card's face. Every place that
  shows a card through it gets the line: the altar/chest/boss reward cards, the shop, the Swap panel and the HUD's
  held-card card. `StoneCard.show_form_line` draws it under the generic sentence in the form's colour (the sentence
  gives up the room, and shrinks first); the HUD's small card appends it to the sentence in the same text colour.
- 102 rows in `locale/strings.csv` (101 cells + `FORMCARD_OFF`), en and es, one contiguous block at the end.
- Tests: `tests/unit/presentation/test_form_card_text.gd` (8), `test_form_card_lines_exist` in
  `tests/content/test_locale_coverage.gd`, and `test_an_altar_card_shows_what_it_does_on_the_held_form` in
  `tests/e2e/test_e2e_attack_slots.gd` (a real altar with the Laser held: Ring's and Homing's Laser lines on their
  cards, none on an element core).
- Shot script `scripts/shots/form_card_text.gd` (a tool, not a test).

## The lines (en; es is in `locale/strings.csv`)

Every allowed Pattern or Secondary cell of the nine forms (101), then the Off line. The Orbs have none.

`FORMCARD_OFF`: "Does nothing on this form" / "No hace nada con esta forma".

### Laser

| Card | Line (en) |
|---|---|
| Twin | Two beams burn side by side |
| Pierce | The beam burns through every enemy |
| Halo | The beam's end fans 3 short beams (3 m, 40 %) |
| Ring | A 1.4 m lightning ring rides the beam's tip (50 %) |
| Backfire | A 4.5 m beam also burns behind you |
| Ricochet | The beam reflects off the first wall and keeps its reach |
| Homing | The beam bends to the nearest enemy; with Pierce, up to 5 |
| Echo | Where the beam swept strikes again 0.4 s later (50 %) |
| Big Shot | A beam twice as wide, +60 % damage, slower to turn |
| Rapid Fire | Ticks faster over 2 s held; thinner beam, -35 % damage |
| Split | The first enemy hit forks the beam in 2 (4 m, 50 %) |
| Mine | The tip drops a mine every 1.0 s (1.5 m burst, up to 4) |
| Spiral | The beam wiggles side to side (12 degrees, twice a second) |

### Bomb

| Card | Line (en) |
|---|---|
| Twin | Two bombs per throw |
| Halo | 4 bombs land in a cross 3 m around you |
| Ring | The blast leaves a lightning ring up to 3.5 m (50 %) |
| Backfire | A second bomb drops at your feet (0.5 s fuse) |
| Ricochet | The bomb skips once and bursts 2 m further on |
| Homing | The bomb lands on the nearest enemy within 3 m |
| Echo | The blast goes off again 0.5 s later (50 %) |
| Big Shot | 3.3 m blast, +60 % damage, slower throw |
| Rapid Fire | 1.6 m blasts every 0.6 s, -35 % damage |
| Split | The blast throws 2 to 4 bomblets 2 m out (40 % each) |
| Mine | The bomb waits as a mine until an enemy is within 1.5 m |

### Void

| Card | Line (en) |
|---|---|
| Twin | Two voids per cast |
| Ring | When it ends, it collapses in a 3 m lightning ring (60 %) |
| Backfire | A second void opens straight behind you |
| Ricochet | The void bounces off walls and keeps drifting |
| Homing | The void drifts toward the densest group within 6 m |
| Echo | A smaller void opens where it ended (60 %, half the life) |
| Big Shot | 1.3 m aura, pulls from 4 m, +20 % damage, slower |
| Rapid Fire | Smaller voids every 0.4 s, half the life, -30 % damage |
| Split | When it ends, it splits into 2 to 4 mini voids (40 %) |
| Mine | The void stops at the aim point and holds for 3 s |
| Orbit | The void circles you once (2.5 m) before flying out |

### Lance

| Card | Line (en) |
|---|---|
| Twin | Two lances per charge |
| Halo | A full charge fires 6 lances around you (50 % each) |
| Ring | A 2 m lightning ring bursts where the lance ends (50 %) |
| Backfire | Also fires a lance behind you (50 %) |
| Ricochet | A full charge bounces off one wall and keeps going |
| Homing | The lance bends gently toward the nearest enemy ahead |
| Echo | A ghost lance repeats the line 0.4 s later (50 %) |
| Big Shot | Twice as wide, +60 % damage, +0.3 s to charge |
| Rapid Fire | Charges 40 % faster, -30 % damage |
| Split | Each enemy pierced spits 2 shards sideways (25 %, 3 m) |

### Rune Explosion

| Card | Line (en) |
|---|---|
| Twin | A second, smaller shield (70 %) follows 0.2 s later |
| Ring | The edge holds as a lightning ring for 0.8 s, hitting again |
| Ricochet | At full size the shield shrinks back, hitting again (50 %) |
| Homing | The burst is cast on the nearest enemy within 6 m |
| Echo | A rune glyph bursts again 0.6 s later (60 %) |
| Big Shot | 5 m radius, +60 % damage, every 1.5 s |
| Rapid Fire | 2.5 m radius, -30 % damage, every 0.7 s |
| Split | Each enemy hit throws 2 rune shards outward (25 %, 4 m) |
| Mine | Leaves a rune trap (4 s); an enemy sets off a 2 m burst |

### Glaive

| Card | Line (en) |
|---|---|
| Twin | Two discs per throw |
| Swirl | The disc swirls at random on its way |
| Halo | 4 discs fly out in a cross and come back (50 % each) |
| Ring | The disc carries a 1 m lightning ring around itself (40 %) |
| Backfire | A second disc is thrown behind you |
| Ricochet | The disc bounces off walls twice before it turns home |
| Homing | The disc curves to an enemy out, and another coming back |
| Echo | A second disc follows the same path 0.3 s later (50 %) |
| Big Shot | A bigger, slower disc, +60 % damage |
| Rapid Fire | A smaller, faster disc every 0.45 s, -30 % damage |
| Split | On its first hit it sheds 2 small discs (30 %) |
| Mine | At its far point it spins in place for 1.2 s |
| Orbit | The disc circles you once (2.5 m) before flying out |

### Seekers

| Card | Line (en) |
|---|---|
| Twin | 6 darts per volley, 60 % each |
| Halo | The darts leave in all directions, then turn to targets |
| Ring | Each dart's hit makes a 1 m lightning ring (30 %) |
| Pierce | A dart goes through its target and seeks 2 more |
| Ricochet | Darts bounce off walls (up to 3) and keep seeking |
| Echo | A second volley follows 0.3 s later (50 %) |
| Big Shot | 2 big darts, +100 % damage each |
| Rapid Fire | 5 small darts, -35 % damage each |
| Split | On a hit, a dart splits in 2 that seek others (35 %) |
| Mine | Darts hang in the air for 0.6 s, then dive together |
| Orbit | Darts circle you once (2.5 m) before launching |

### Wave

| Card | Line (en) |
|---|---|
| Twin | Two waves per cast |
| Backfire | A second wave rolls out behind you |
| Ricochet | The wave reflects off one wall and rolls on |
| Homing | The wave bends toward the biggest group in front |
| Echo | A second wave follows 0.4 s later (50 %) |
| Big Shot | 5 m wide, +60 % damage, slower |
| Rapid Fire | 2 m wide, every 0.55 s, -30 % damage |
| Split | At the end of its run it splits into 2 waves at 45 degrees |
| Mine | The wave stops 4 m out and churns in place for 1.5 s |
| Spiral | The wave snakes left and right as it rolls |

### Wisps

| Card | Line (en) |
|---|---|
| Twin | A fourth wisp joins the circle |
| Halo | 6 wisps circle you, 60 % damage each |
| Ring | A wisp's hit makes a 1 m lightning ring |
| Pierce | The wisps' shots pass through enemies |
| Ricochet | The wisps' shots bounce off walls |
| Homing | The wisps' shots curve toward enemies |
| Echo | Each wisp shot fires again a moment later |
| Big Shot | The wisps' shots are bigger, stronger, slower |
| Rapid Fire | The wisps' shots are smaller and weaker |
| Split | The wisps' shots split on hit |
| Spiral | The wisps' shots corkscrew |
| Mine | Each wisp drops a mine every 2 s |
| Orbit | The wisps circle wider (3.5 m) and hurt what they touch |

## Commands and raw results

All with `--language en`, each with its own `APPDATA` per process, from the worktree at base `d6c4f421` plus this step.

- `godot --headless --path . --editor --import --quit`: no ERROR lines (the `GutErrorTracker` lines are class names);
  it regenerated `locale/strings.en.translation` and `locale/strings.es.translation` (committed); `project.godot`
  untouched.
- `gdformat` then `gdlint` on every touched `.gd`: "Success: no problems found". `stone_card.gd` has the file's
  `# gdlint: disable=max-public-methods` line (the repo's usual way; it passed 20 public methods).
- Unit, content and arch (`-gtest=` with the eleven files `test_form_card_text`, `test_locale_coverage`,
  `tests/arch/test_layering`, `test_sim_purity`, `test_attack_slot_views`, `test_card_frames`, `test_card_level_views`,
  `test_ember_stone`, `test_rarity_views`, `test_reward_cards`, `test_reward_views`): Scripts 11, Tests 69, Passing 69,
  Asserts 33269, 21.8 s.
- e2e (`test_e2e_attack_slots`, `test_e2e_wand_build`): Scripts 2, Tests 6, Passing 6, Asserts 123, 60.2 s.
- No seed-loop tests, no `seams.sh`, no full suite (owner rule); GitHub runs the full suite once.
- Shot: `godot --language en --path . --resolution 1920x1080 -s scripts/shots/form_card_text.gd` ->
  `build/shots/v0.9.5/tx/en.png` (1920 x 1080; looked at: Ring, Homing and Big Shot with the Laser held, each with
  its Laser line under its sentence, the lines in the fallback orange).

## Deviations

- **The Void's Big Shot line follows the data, not FORM_COMBOS / FC3.** The table and FC3.md say 1.6 m aura, pull from
  4.5 m, +60 %; the data row (`big_aura_mm` 1300, `big_pull_mm` 4000, `big_damage` 1200, `big_speed` 700) says 1.3 m,
  4 m and +20 %. The line reads "1.3 m aura, pulls from 4 m, +20 % damage, slower". Someone should check which one the
  owner wants; the line follows whatever the row says.
- Shares and numbers taken from the rows where the table gave none or a different one: Laser Halo 40 %, Ring 50 %
  (the example's 60 % was a draft), Split 50 %; Bomb Rapid Fire -35 % damage, Ring 50 %; Void Ring 60 %, Rapid Fire
  -30 %, Split 2 to 4 minis (by level) at 40 %; Lance Ring 50 %, Backfire 50 %; Rune Ring "holds 0.8 s, hitting
  again" (the table's wording), Mine 4 s; Glaive Halo 50 %, Ring 40 %, Rapid Fire -30 %; Seekers Halo and Pierce as
  built; Wave Rapid Fire -30 %.
- The cells that were already on before FC1-FC9 (Twin on every form, Pierce on the Laser, Backfire on the Wave,
  Swirl on the Glaive) had no approved wording in FORM_COMBOS; their lines are mine ("Two bombs per throw", "A second
  wave rolls out behind you", "The disc swirls at random on its way").
- Wisps: the eight cards that act on the wisps' shots read as "The wisps' shots ..."; Rapid Fire reads "smaller and
  weaker" (not faster), because FC9 found the card's rate bonus does nothing for the wisps.
- No card-name prefix on a line ("Ring: ..."): the line sits right under the card's own title and sentence, so the
  name only cost length.
- The Build page's wand row tiles show a name and a level only (no description), so there is nothing to put a line
  under there; a card that cannot act on the held form already shows its reason on its tile (v0.8.0 MR). The HUD's
  held-card card gets the line as a second paragraph of its sentence, in the sentence's colour (no separate colour).
- No form has its own colour in `ItemLooks` yet, so every line uses the fallback orange (`FormCardText.FALLBACK`); the
  code takes the Form card's colour as soon as `ItemLooks.ID_COLORS` has one.
- `FORMCARD_OFF` is built and tested, but the game never offers a card the form does not allow, so the line shows only
  where a held, now incompatible card is shown through `card_face`.

## OWNER ONLY

- Wording of the 101 lines (both languages), and whether one short line under the sentence reads well on the card.
- Whether the lines should wear a colour per form.
