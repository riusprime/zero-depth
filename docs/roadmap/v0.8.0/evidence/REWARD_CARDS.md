# REWARD_CARDS: cards that deal, flip and react (v0.8.0 N8, owner O62, D48; with N7, O61)

- **Status:** RUN (unit, e2e, content, arch, golden, application, lint, the timing runs and the renders); how it
  feels and reads in play is **OWNER ONLY**
- **Build:** the working tree of the commit `v0.8.0 Step N8` on `v080-n78` (parent: the N7 commit); the runs were made
  on that tree before it was committed. Godot `4.7.2.stable.official.ed1daf0bf`; a shared Linux cloud container
  (headless; renders on software GL, llvmpipe, under xvfb), not the owner's hardware
- **Date:** 2026-10-17
- **Who ran it:** agent

Owner (PLAN O62, verbatim there): give the card order (name on top, the icon big in the middle, below what gets better
with the old value and the new one); give each rarity its own colour, paint the whole card and write the rarity out;
deal them face down from the bottom in a fan and flip them one by one (width to zero, the face swapped halfway); make
a rare one wait (last, its back glowing, the background dark, then a punch, a flash and rays behind it; a Legendary
keeps a holographic shine); on hover tilt toward the cursor and sink a little, the numbers counting up from the old
value; on a pick the icon flies to its HUD slot, and a discarded card burns. D48: the wait is for Epic and Legendary;
a chest deals one card that flips (with the wait if it rolled high); at an altar the two cards not picked burn.

## The change
**Sim (read only by the view; EI-07):** `CardForecast.of` (`src/sim/abilities/card_forecast.gd`) works out what
taking a card changes with the take's own steps, now shared: `Stats.stepped` (the stat step `Stats.add_amount` runs,
within the cap), `Stats.max_hp_at` / `total_at` (what `max_hp` / `total` read), `Abilities.level_after` (`grant`'s
step, and `Offers.info`'s level), `CardLevels.level_after` (`level_up`'s), `BossReward.level_after` (the boss altar's
level-5 rule, `on_pick`'s). `WorldReader.card_forecast(code)` (on the open choice's reward) and `GAIN_*` kinds. No
state, no hash, no stream is touched; `tests/golden` unchanged.

**The card** (`StoneCard`, every pick card: altars, the boss's altar, the epic altar, a chest's card, the shop's
stock, the Swap's card, the Codex): from the top, the name; the groove; the big icon (112 px at scale 1, was 78;
its element or star glyph badge kept); the **gain line** (`CardGain`: "100% → 115%", "100 → 108 HP", "Level 1 → 2",
"New · Level 1"; none for a card with no number); the sentence; the gem; the rarity's word. A long sentence still
reflows (a 44 px icon, the title higher), checked in en and es at every scale. Painted in its rarity (`CardPaint`):
the stone face and the back tinted toward the tier colour (Common grey, Rare blue, Epic purple, Legendary gold; an
ability card the hero's cyan) at a dark value, a frame line and the glow in it; the text keeps at least 4.5:1 against
the brightest the face gets behind it (unit test). The word stays: "Rare", "Modifier · Epic", "New ability · Common".

**The deal** (`CardDeal`, a timeline the panel reads each frame; it decides nothing): each card arrives face down
from below the screen into a fan (0.34 s each, 0.09 s apart; ±0.07 rad and 14 px a step from the middle), then they
flip one by one (0.22 s: `scale.x` 1 → 0, the face swapped at half, 0 → 1). An **Epic or Legendary** card flips last:
before it the background darkens (dim 0.45 → 0.77) and its back glows for 0.75 s, then it flips with a punch (+16 %
scale), a white flash (0.4 s) and light rays rising behind it (they stay softer while it shows); several high cards
(the boss's altar) share the one wait and flip in turn. A **Legendary** card keeps a looping holographic sheen
(`CardFx`'s canvas shader). The rays are drawn on one layer under every card (they never cross a neighbour).

**React:** the focused card tilts toward the cursor (skew and a small turn, by where the pointer is on it; a fixed tilt
when focused by key or pad) and sinks a little (×0.965, 5 px down; it no longer lifts), and its gain counts up from
the old value (0.45 s).

**Where it went:** after a pick the picked card's icon flies on an arc to the HUD slot it landed in (`CardFlights`,
`CardFly`, 0.55 s and a ring flash; deferred a frame so the HUD's slots have synced): an ability's slot, its wand pip,
its icon in the carried row, else the HP plate. The cards not picked burn (a dissolve from the foot up with an ember
edge in their colour, 0.75 s, one front over every part of the face via `use_parent_material`). A cancel just
closes. At a chest the one card flies; nothing burns.

**Input:** a press during the deal (a digit, an arrow, Enter / A, Esc / B, a click) ends the deal at once and still
counts, the same frame (`PickPanel.skip_deal`): no input is lost or held back by the animation; the sim waits on the
pick exactly as before. **Reduced motion:** no deal, flip, tilt or flight; the cards fade in face up (StoneCard's
0.15 s fade), the tier colour and word kept, the Legendary sheen held still, the panel fades out in 0.15 s.

**N7 alongside:** a chest's panel says "Chest · it gave you this" / "Cofre · te ha dado esto" and "Enter, A or a click
to take it"; its numbers are the state before the take (the take happens on that answer).

New strings (en + es): `UI_GAIN_LEVEL`, `UI_GAIN_LEVEL_NEW`, `UI_GAIN_HP`, `UI_GAIN_ARROW`, `UI_GAIN_PERCENT` (N7:
`PICK_TITLE_CHEST_DEALT`, `PICK_HINT_DEALT`). An ability card's rarity line now names its rarity too.

## Tests
New: `tests/unit/presentation/test_reward_cards.gd` (14: the deal order with Epic and Legendary last and the wait,
the flip's halfway swap, the punch / flash / rays, a press skipping and still counting, the Epic waiting in the
panel, the gain line = the forecast = the outcome, the count-up, every tier's paint, word and contrast, the shine,
the tilt and sink, reduced motion, the burn and the flight to the wand pip, a cancel neither burns nor flies, a
chest's one card), `tests/e2e/test_e2e_reward_cards.gd` (2, through `main.tscn` with `Input.parse_input_event` only:
an altar's three cards dealt face down from below, flipped in `CardDeal.order`, Enter takes one, applied, its icon
flies to `slot_rect_for`, the others burn; a chest's one card, a press during its deal takes it, it flies).
Changed on purpose: `test_hud_style.gd` (the card title's parent chain: the face hangs from the pivot).

Results: see the PROGRESS History line of 2026-10-17 (N8), pasted from the runs.

## Frame cost
`scripts/shots/reward_cards.gd` drives the real `Hud` and pick panel over a Gun run's world (an altar with Pierce,
Power (Rare), Twin (Epic); a pick; an altar with Vitality, Chain Blast (Legendary), Spread; a pick; a chest), and
times the panel's own `_process` per frame (`Time.get_ticks_usec`, the panel driven by the script) and the draw
calls.

```
godot --headless --path . --fixed-fps 60 -s scripts/shots/reward_cards.gd -- --lang=es    (3 runs)
n8: frame cost idle: 235 frames, process avg 0.174 ms, max 0.174 ms, draw calls avg 0; the panel's own _process avg 0.019 ms, max 0.090 ms
n8: frame cost deal: 328 frames, process avg 0.174 ms, max 0.174 ms, draw calls avg 0; the panel's own _process avg 0.040 ms, max 1.051 ms
n8: frame cost outro: 135 frames, process avg 0.174 ms, max 0.174 ms, draw calls avg 0; the panel's own _process avg 0.020 ms, max 0.873 ms
n8: frame cost idle: 235 frames, process avg 0.170 ms, max 0.170 ms, draw calls avg 0; the panel's own _process avg 0.019 ms, max 0.112 ms
n8: frame cost deal: 328 frames, process avg 0.170 ms, max 0.170 ms, draw calls avg 0; the panel's own _process avg 0.045 ms, max 1.162 ms
n8: frame cost outro: 135 frames, process avg 0.170 ms, max 0.170 ms, draw calls avg 0; the panel's own _process avg 0.022 ms, max 1.092 ms
n8: frame cost idle: 235 frames, process avg 33.458 ms, max 47.011 ms, draw calls avg 0; the panel's own _process avg 0.019 ms, max 0.137 ms
n8: frame cost deal: 328 frames, process avg 27.020 ms, max 47.011 ms, draw calls avg 0; the panel's own _process avg 0.048 ms, max 1.317 ms
n8: frame cost outro: 135 frames, process avg 46.317 ms, max 47.011 ms, draw calls avg 0; the panel's own _process avg 0.020 ms, max 1.037 ms
```
```
xvfb-run -a -s "-screen 0 1600x1000x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
  --resolution 1600x1000 --fixed-fps 60 -s scripts/shots/reward_cards.gd -- --lang=en   (then --lang=es)
n8: frame cost idle: 235 frames, process avg 107.103 ms, max 316.625 ms, draw calls avg 288; the panel's own _process avg 0.248 ms, max 3.850 ms
n8: frame cost deal: 328 frames, process avg 118.070 ms, max 356.491 ms, draw calls avg 378; the panel's own _process avg 0.629 ms, max 10.286 ms
n8: frame cost outro: 135 frames, process avg 142.281 ms, max 316.625 ms, draw calls avg 368; the panel's own _process avg 0.102 ms, max 1.488 ms
n8: frame cost idle: 235 frames, process avg 114.318 ms, max 337.981 ms, draw calls avg 288; the panel's own _process avg 0.514 ms, max 43.631 ms
n8: frame cost deal: 328 frames, process avg 130.762 ms, max 285.168 ms, draw calls avg 378; the panel's own _process avg 0.882 ms, max 79.258 ms
n8: frame cost outro: 135 frames, process avg 148.851 ms, max 337.981 ms, draw calls avg 368; the panel's own _process avg 0.101 ms, max 0.985 ms
```
- **The panel's script cost is small:** headless (no rendering), 0.040–0.048 ms a frame on average while dealing,
  at most 1.3 ms (the first frames: the burn material, the layout); idle (the panel open, settled) about 0.02 ms.
- Under llvmpipe the same work averages 0.6–0.9 ms with spikes to 10 and 79 ms in single frames: the software
  renderer shares the CPU (the frame's process time there is 100+ ms whatever the panel does, and
  `Performance.TIME_PROCESS` is sampled once a second, so its "max = avg" headless rows are not per-frame). Not the
  owner's GPU; on real hardware: **OWNER ONLY**.
- **Draw calls** (llvmpipe, the whole HUD): 288 with the cards settled (idle rows include the panel open), 378 while
  dealing, 368 in the outro: about +90 for the deal's backs, rays, flash and glows.

## Shots
Rendered by the commands above (llvmpipe), cropped to the panel and the HUD's lower left by hand
(`PIL`, 1440 × 720, JPEG 80) into [`n8_shots/`](n8_shots/):

| Moment | en | es |
|---|---|---|
| The fan face down, painted by tier (Common, Rare, Epic) | [fan_facedown_en](n8_shots/fan_facedown_en.jpg) | — |
| A flip midway (the first card edge on) | [midflip_en](n8_shots/midflip_en.jpg) | — |
| The Epic wait: the darkened background, its back glowing | [epic_wait_en](n8_shots/epic_wait_en.jpg) | — |
| The Epic's flip: the punch, the flash, the rays | [epic_flip_en](n8_shots/epic_flip_en.jpg) | [epic_flip_es](n8_shots/epic_flip_es.jpg) |
| A Legendary with its sheen (Chain Blast) and the gain lines | [legendary_en](n8_shots/legendary_en.jpg) | [legendary_es](n8_shots/legendary_es.jpg) |
| Hover: the tilt toward the pointer, the sink, the count-up midway | [hover_tilt_en](n8_shots/hover_tilt_en.jpg) | [hover_tilt_es](n8_shots/hover_tilt_es.jpg) |
| The burn of the two not picked | [burn_en](n8_shots/burn_en.jpg) | [burn_es](n8_shots/burn_es.jpg) |
| The picked icon flying to the HUD (the HP plate, a stat card) | [fly_en](n8_shots/fly_en.jpg) | — |
| A chest's one card | [chest_en](n8_shots/chest_en.jpg) | [chest_es](n8_shots/chest_es.jpg) |

## Not done / not measured
- **The shop's stock** wears the new face, paint and gain line (the same `PickSlot`), but is not dealt, tilted or
  burned: a purchase isn't a discard, and the shop's panel has its own flow (for the owner to ask if wanted).
- The gun mods' icons are the generic gem (`ItemIconView`'s fallback), as before N8.
- Sound for the deal, flip, burn and flight: none added (no audio asked; OWNER ONLY if wanted).
- Frame time on the owner's hardware: NOT YET RUN (OWNER ONLY).
