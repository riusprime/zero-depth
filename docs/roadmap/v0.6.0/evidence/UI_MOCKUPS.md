# UI_MOCKUPS: which HUD and menu style should match the crystal cards? (G2, PLAN v0.5.5 A5)

- **Status:** RUN (mockups made); the pick is **OWNER ONLY**
- **Build:** worktree branch `worktree-agent-a7c40463ca6fd0251` off `8e248ab`; Godot `4.7.2.stable.official.ed1daf0bf`; Linux (lavapipe Vulkan under Xvfb)
- **Date:** 2026-10-08
- **Who ran it:** agent

These are **mockups, not the game**: the in-game HUD is unchanged until the owner picks (PLAN "Open items": the A5
pick blocks the UI restyle beyond the cards). Each is drawn with Pillow over a real game frame captured with the
HUD hidden (floor 1, Ruins), using the owner's card frames from `assets/ui/cards/` and the game's Atkinson font.
The minimap is cropped from a real frame with the shipped HUD. **Every number on them (HP 72/100, 03:42, 87 kills,
146 shards, the 2.1 s cooldown, "3 of 9 cards") is illustrative, not from a run.** The ability symbols in the slots
are stand-ins drawn by the script, not the game's icons. English only.

## Command
```
# 1. the background frames (needs a renderer)
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/crystal_cards.gd
# 2. the mockups
python3 scripts/art/ui_mockups.py build/shots/v0.5.5/cards/00_game_no_hud_1920x1080.png \
  build/shots/v0.5.5/cards/01_altar_en_1920x1080.png build/mockups/v0.5.5
# 3. copied by hand: build/mockups/v0.5.5/*.png -> docs/roadmap/v0.6.0/evidence/ui_mockups/
```

## Raw output
```
wrote build/mockups/v0.5.5/hud_a.png
wrote build/mockups/v0.5.5/pause_a.png
wrote build/mockups/v0.5.5/hud_b.png
wrote build/mockups/v0.5.5/pause_b.png
wrote build/mockups/v0.5.5/hud_c.png
wrote build/mockups/v0.5.5/pause_c.png
wrote build/mockups/v0.5.5/ui_mockups_sheet.png
```

## The options
All three keep the shipped layout (timer and danger top centre, shards and minimap top right, ability slots, HP,
skill and dash bottom left, heat bottom centre), so only the look changes. Overview:
[`ui_mockups/ui_mockups_sheet.png`](ui_mockups/ui_mockups_sheet.png).

**A. Crystal crown** — [`hud_a.png`](ui_mockups/hud_a.png), [`pause_a.png`](ui_mockups/pause_a.png).
Dark chamfered plates with a faint cold rim; crystals carry state: the danger tier is five gems that light cold to
hot, the hero's HP plate holds a glowing cyan core gem, ability slots are hex sockets rimmed in the card family's
colour, the minimap has crystal corners, heat is a row of shard teeth with a warm glow. The pause menu sits inside
the owner's silver card frame, scaled up: the closest match to the cards. Most ornate; the most screen it covers.

**B. Ember stone** — [`hud_b.png`](ui_mockups/hud_b.png), [`pause_b.png`](ui_mockups/pause_b.png).
Chipped dark stone slabs (the ruined city) with a warm ember line under the important plates; crystals only as
small accents (the shard gem, the danger teeth). HP is a red bar, heat an ember bar with glow. Pause is one stone
tablet with an ember-lit selection and a proposed "Your build" strip of tiny crystal frames. Warm-heavy; reads as
the world rather than as the cards.

**C. Cold glass** — [`hud_c.png`](ui_mockups/hud_c.png), [`pause_c.png`](ui_mockups/pause_c.png).
The current calm BARE HUD kept almost as is, with thin translucent glass plates whose top edge glows (cold cyan for
the hero, warm orange for heat and danger) and small faceted gems as markers. Least screen covered. Pause blurs the
game, lists the options on the left over a dark gradient and shows the build as full crystal cards on the right
(proposal). The lightest change from today.

## Interpretation
The owner picks one (or mixes parts: for example A's pause with C's HUD). The "Your build" panels in B and C's
pause menus are a proposal (the build is not shown in the pause menu today); D4's catch-up multiplier is planned to
show there too (PLAN D4). The pick goes into PROGRESS "Gates"; the restyle is a later step.

| Gate | Answer |
|---|---|
| A5 mockup pick (A / B / C / mix) | OWNER ONLY |
