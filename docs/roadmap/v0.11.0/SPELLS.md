# v0.11.0 G1 — the elemental spells (approve row by row)

From the brief §5, PLAN E1–E5 and the owner's answers Q17–Q20 (2026-11-07). Answer each row **approve**, **change: …**
or **cut**. Nothing here is built before the rows are answered (O10, O11).

## The rules every spell follows (already decided)
- **Unlock (Q17):** holding an element card (Fire, Frost, Lightning, Venom, Bleed) adds that element's 3 spells to this
  run's card pool. The element worn as the Wardrobe's rune affinity raises those spells' offer weight.
- **Slots (E2, Q19):** 4 spell slots, separate from the wand, any mix of elements. Each spell fires by itself on its own
  cooldown. 4 HUD squares above the ability bar show the cooldown sweep and flash on cast.
- **Levels (Q18):** taking a held spell again levels it, Lv 1–3, Lv 4–5 from loop 2. Every level is a visible change.
- **Statuses:** a spell applies its element's status the same way the wand's element card does (same stacks, same
  rules), so a spell and an element card add up.

## Starting values (the lead's; O12 measures them before anything else changes)
- **Cooldown:** 12 s unless the row says otherwise.
- **Damage budget:** at Lv 1, each spell deals about **15 % of the wand's expected DPS** over its cooldown (the
  `scripts/balance/forms_dps.gd` numbers). With all 4 slots at Lv 1 that is about +60 %. Lv 5 is about 2.5 × Lv 1. These
  are targets for the O12 sim, not measurements. If a build with 4 spells misses its band, the lead reports the numbers
  and stops. No enemy HP changes before that.
- **Aim:** spells never need aiming. "The densest pack" = the 3 m circle holding the most enemies within 10 m of you
  (sim-picked, the same function for the forecast and the cast, EI-07).

## The rows (your 6 in bold)

| # | Element | Spell | What it does at Lv 1 | What the levels add (Lv 2 → 5) | Why it's its own spell |
|---|---|---|---|---|---|
| F1 | Frost | **Blizzard** | A 4 m storm settles on the densest pack for 4 s. It hits every 0.5 s and chills (slows) everything inside | radius 4 → 5.5 m; 4 → 6 s; Lv 5: enemies still inside at the end freeze for 1 s | Area control far from you: holds a pack in place |
| F2 | Frost | **Frost Nova** | Everything within 3.5 m freezes for 1 s and is pushed 1 m away | radius → 5 m; freeze → 1.5 s; Lv 5: a frozen enemy hit by you shatters for bonus damage | The panic button: room to breathe when you're surrounded |
| F3 | Frost | Ice Lances | 3 shards fly at the 3 nearest enemies, each passing through up to 2 | shards 3 → 6; Lv 5: a shard that kills splits into 2 more | Single targets at range: picks off casters and snipers |
| B1 | Fire | **Fireball** | A big, slow ball flies at the densest pack and bursts 3 m, setting everything on fire | radius → 4 m; Lv 3: 2 balls; Lv 5: the burst leaves Burning Ground for 3 s | The burst: big damage on one pack |
| B2 | Fire | **Burning Ground** | A 3 m fire patch under you for 5 s (cooldown 10 s); enemies standing in it burn | radius → 4 m; 5 → 8 s; Lv 5: the patch follows you at half speed | Rewards holding a spot; good with Frost Nova and Blizzard |
| B3 | Fire | Meteor | After a 1.2 s mark on the ground (the densest pack, locked when the mark appears), a huge strike hits 5 m and knocks enemies down for 0.5 s (cooldown 16 s) | radius → 6.5 m; Lv 5: the crater burns for 4 s | Slow and huge: the biggest single hit; enemies can walk out of the mark |
| L1 | Lightning | **Sky Strike** | 3 bolts strike random enemies within 10 m, each jumping to 1 more | bolts 3 → 6; Lv 5: each bolt stuns for 0.3 s | Spread damage: hits the whole room a little |
| L2 | Lightning | Ball Lightning | A slow orb rolls out ahead of you for 4 s, zapping the nearest enemy within 2.5 m every 0.3 s | zap range → 3.5 m; Lv 3: zaps 2 enemies; Lv 5: bursts at the end | A moving area: clears a path you're about to walk |
| L3 | Lightning | Static Field | A 2.5 m ring around you for 4 s; every enemy touching it is shocked every 0.5 s | radius → 3.5 m; 4 → 6 s; Lv 5: your dash discharges it (a 4 m burst) | Close-range defence that moves with you |
| V1 | Venom | **Venom Orb** | An orb lobbed at the densest pack lands as a 3 m pool for 5 s; each enemy in it gains a venom stack every 0.5 s | radius → 4 m; 5 → 7 s; Lv 5: enemies that die in it leave a small pool | Stacks venom fast on a pack |
| V2 | Venom | Toxic Cloud | A cloud trails behind you for 6 s (a 2 m puff every 0.5 s, each lasting 2 s); enemies chasing you walk through it | puff → 2.6 m; Lv 5: the cloud also slows | Rewards kiting: punishes whatever follows you |
| V3 | Venom | Spitter Vine | A vine grows where you stand for 8 s and spits venom at enemies within 7 m, one shot every 0.6 s | 8 → 12 s; Lv 3: 2 heads; Lv 5: its shots pass through | A turret: holds a doorway or a corner for you |
| X1 | Bleed | Blood Thorns | Thorns burst out of the ground in a ring from 2 m to 4 m around you; every enemy hit bleeds | Lv 3: a second ring a beat later; Lv 5: the thorns stay 2 s as a wall | A ring that punishes enemies keeping a short distance |
| X2 | Bleed | Hemorrhage | Marks the enemy with the most HP within 10 m. After 3 s, all its bleed deals its damage at once and spreads to enemies within 3 m | spread radius → 4.5 m; Lv 5: marks 2 enemies | Cashes in bleed: strong on elites and big foes |
| X3 | Bleed | Leech | For 4 s, every bleeding enemy within 6 m is drained; you heal 1 HP for each 25 damage it deals, at most 10 HP a cast | heal cap 10 → 20; Lv 5: also drains non-bleeding enemies at half | The only healing spell; strong with any bleed build |

## Notes for your answers
- **Frost Nova, Flame Trail and Arc Field** were auto abilities until v0.10.5 removed them. F2 brings Frost Nova back as a
  spell. The old fire-patch code can carry B2. Flame Trail and Arc Field stay gone (B2 and L3 cover their place).
- **Readability:** every spell has its own colour (its element's) and a shape no enemy attack uses: player spells are
  never round red/purple ground marks, so you never mistake your Meteor for a boss telegraph.
- **Bosses:** spells hit bosses like the wand does. Freeze and knock-down on bosses follow the rules the element cards
  already have.
- Each spell needs its strings (name, description, levels) in `en` and `es`, an icon, and its own sound and effect.
