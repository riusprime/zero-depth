# O3: the Prism's last phase (L6)

Owner (2026-11-01): "The prism feels better, we still have to work on the last phase"; asked what is wrong: "Needs
something cooler while he's down and not on the dodging pattern" and "Boring pattern". Overnight mode: "Pick and
build". Every number below is a **starting value (owner, 2026-11-01)**: the lead's pick, for the owner to keep or change
([`OWNER_QUESTIONS.md`](OWNER_QUESTIONS.md)).

## Today (at `bdb2ec79`)

- **One phase.** `data/final_boss/prism.tres` has a single `BossPhaseDefinition` (threshold 1000): from her rise to
  her shatter she casts the same fixed rotation (`BossPrism.next_spell`, one spell at a time, each waiting until her
  last shot is gone): `cross_ring`, `crown_ring`, `cross_spiral`, `crown_spiral`, `cross_flower`, `crown_flower`.
  So "the last phase" is the same loop as the first: nothing new happens as she weakens except the Cross speeding up
  (a quarter turn in 2.824 s at full HP, down to 1.412 s at none).
- **The Cross** (8.5 s): 1.0 s of aim lines (shielded), 5.0 s of four beams turning (shielded; they reverse every
  3.529 s; a burn every 0.5 s, 30 damage), then a **3.5 s window**: beams out, shield down, the only "down" moment.
  In it two or three fast bolts aim at you for 0.4 s each (from 0.3 s in, every 1.1 s; 22 damage).
- **The orb spells** (`crown_ring`, `crown_spiral`, `crown_flower`): 0.8 s telegraph, shielded while the waves fly and
  until the last orb is gone, then a 2.0 s recovery (open).
- **Shield:** she can be hurt only in the Cross's window and the orb spells' recoveries: the compiled open share of a
  rotation is `window_permille` (about 0.2), and her HP is sized from the measured DPS times that share.
- **The "down" moment** today is the Cross's window: she sags, a gold ring pulses at her feet, and she still fires
  bolts at you. It is another dodge, not a payoff.

## (a) A new pattern for the last phase

1. **Facet Lances.** She flings her six shards to the arena's rim, one after another. Each shard's lance line tracks
   you, locks, then strikes as a full-width beam across the room through where it locked. They come from spots 135°
   apart round the room, so each needs a sidestep in a new direction: a staccato that reads and plays nothing like
   the turning Cross or the orb rings.
2. **Scissor Beams.** Two beams start on either side of you and sweep toward each other, closing a wedge; you run out
   of the wedge (or through the gap behind her) before they meet.
3. **Refraction.** The Cross's arms bend off the walls (one reflection each), so the beams come back across the room
   from behind.

**Pick: 1, Facet Lances.** It is the most different from what she already does (tracked lines from all round you
instead of a rotating sweep or a bullet ring), and it reuses the sim's proven "track, then lock" telegraph and lane
shapes, so it is fair by construction (every lance shows locked for at least 0.45 s before it strikes).

## (b) Something cooler while she is down, outside the dodge pattern

1. **The Shattered Kneel.** Right after the Facet Lances her shards are spent: she falls to her knees, her prism cracks
   open and her core shows. Nothing is fired at you. Hits on her core (from within 2.5 m of her edge) deal ×1.5, and
   a crack meter round her fills with the damage she takes. When the crack fills the core bursts: a big shatter
   flash, bonus damage (a share of her max HP), and she rises at once. If it doesn't fill she rises when the kneel
   ends.
2. **Counter-hit.** In the window, hitting a shard just as its bolt aims reflects the bolt back into her for bonus
   damage and a stagger flash.
3. **Breakable facets.** Her shards drop to the floor as targets with little HP; break all of them before she rises
   for a long stun and bonus damage.

**Pick: 1, the Shattered Kneel.** It is a real "she's down" moment with nothing to dodge, and it asks the opposite of the
dodge pattern: run in and commit. The crack meter and the burst make the payoff visible, and both scale with her max
HP, so the moment stays the same length for a weak or a strong build.

## What is built

- **Her last phase:** a second phase from **50 % HP** whose rotation is `cross_ring`, `crown_spiral`, `facet_lances`,
  `prism_kneel`, `cross_flower`, `crown_flower` (the Facet Lances and the kneel replace `crown_ring`, the plainest
  orb ring). A Prism phase change opens no gate (no adds; she simply changes her rotation at her next spell).
- **Facet Lances** (`facet_lances`, move `lances`): 0.8 s gather (shielded), then 6 lances 0.35 s apart: each tracks
  you for 0.45 s and holds locked for 0.45 s, then strikes for 0.15 s; lanes 0.9 m wide across the room from rim spots
  9 m out, 135° apart round her, starting from where you stand; 26 damage each; shielded throughout.
- **The Shattered Kneel** (`prism_kneel`, move `kneel`): 0.6 s fall (the telegraph), 3.0 s down (open), 0.6 s rise.
  Core hits ×1.5 within 2.5 m of her edge; the crack fills at 8 % of her max HP taken; the burst deals 5 % of her max
  HP and ends the kneel.
- **Death line:** "The Prism's facet lances pierced you." (en, es).
