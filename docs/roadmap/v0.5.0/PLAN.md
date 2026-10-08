# v0.5.0 — Roads Between: shops, events, curses, salvage, routes and a 30–60 minute measured run (plan, owner-directed 2026-10-07)

Recorded so these decisions never depend on chat context. Progress: [`PROGRESS.md`](PROGRESS.md).

## Context
- **Before this:** v0.4.0 "Run Depth" ([`../v0.4.0/PLAN.md`](../v0.4.0/PLAN.md)) on `claude/lucid-fermat-9wv2tf`; `main`
  doesn't exist yet (O3).
- **Owner (2026-10-07):** "skip the rule, keep going to v0.5.0" — ROADMAP §0.3 waived once: v0.5.0 is built without a
  v0.4.0 playtest; the owner plays both together.
- **Owner (2026-10-07):** "okay let's bove the bigger card pool to v0.5 and make it in this current development
  sprint" — the 40–50 card pool is v0.5.0 scope, built as step CP (done). Owner on how to count it: **per build**
  (what one Blade or Gun run can be offered): Blade 50, Gun 48; all content together is 58.
- **ROADMAP v0.5.0 scope:** shops and events, cursed rewards, salvage, optional routes; a full run of 30–60 minutes;
  every scorecard cell fillable from reproducible commands (exit gate, **sims** + **test**).
- Every number below is a **starting value** the owner tunes after playing. Anything not directed here is a lead
  proposal the owner may change.

## Every owner line → where it lands
| # | Source | Decision | Step |
|---|---|---|---|
| C1 | Owner: the card pool moves to v0.5.0, built now; count per build | 40–50 cards per build, every card reachable (no dead cards) | CP |
| R1 | ROADMAP: "Shops" | One **shop** per floor in a side room (a terminal): 4 cards for shards (price by rarity × floor), a heal (30 % max HP), a reroll (price rises per use) | SH |
| R2 | ROADMAP: "salvage" | At a shop: **salvage** a mod or stat card for shards (40 % of its price); **free a slot** by salvaging an ability (refunds by level) so a later ability card can take it | SH |
| R3 | ROADMAP: "events" | 1–2 **event rooms** per floor (a lit pedestal; interact): a choice between two or three outcomes with a cost (HP, shards, a curse, a fight) and a reward; 8 events to start | EV |
| R4 | ROADMAP: "cursed rewards" | Some chest offers and events carry a **curse**: a strong card plus a lasting drawback (e.g. enemies +15 % speed, −20 % regen, Overclock decays faster); curses raise threat T (PD-05) and are listed on the stats panel | EV |
| R5 | ROADMAP: "optional routes" | After floors 1 and 2 the portal room offers **two portals**: the normal next floor or a **Deep** variant (×1.25 scaling, one extra chest, a curse-free epic altar); the choice shows on the floor card and the minimap | RT |
| R6 | ROADMAP: "A full run of 30–60 minutes" | Floors last 10–15 min (M-FLOOR) by measured pacing (boss door opens after the floor's last required room or a minimum time); a bot run is 30–60 min | TU5 |
| R7 | ROADMAP exit gate: "All scorecard data collected … every cell can be filled from reproducible commands" | `scripts/sims/scorecard.gd` writes every SCORECARD §2 cell to `build/`; the evidence file is filled by hand from its output | SCD |

## Steps
| Wave | Step | Scope |
|---|---|---|
| (done) | CP | The 40–50 card pool per build ([`evidence/CARD_POOL.md`](evidence/CARD_POOL.md)) |
| 4 | SH | Shops and salvage |
| 4 | EV | Events and cursed rewards (threat T) |
| 5 | RT | Optional routes (Deep portals) |
| 5 | TU5 | Pacing to a 30–60 minute run (with v0.4.0 TU's scaling tuning) |
| 5 | SCD | Scorecard collection: every cell from a reproducible command |
| — | R | Build for the owner (v0.4.0 + v0.5.0 together) + playtest sheet |

## Step EV: events and cursed rewards (lead proposals, built; the owner may change any of them)
Every number is a starting value (data in `data/events/`, `data/curses/`, `data/event_rules/floor.tres`).
- **Rooms:** 1–2 event rooms per floor (`Events.pick_rooms`, its own generator function: never the start hall, the
  boss room or the room before the boss door; a `taken` list keeps other side-room kinds out). A lit pedestal stands
  at a spot clear of walls and ≥ 3 m from every altar or chest spot; interact (E / pad X) opens its panel and the
  world waits, like a pick. Each choice shows its cost, its reward (the rolled card itself) and its curse before you
  take it; "Leave it" is always the last card and keeps the event for later.
- **The eight events** (the brief's list, with two changes, below):

| Event | Choice → cost → reward | Needs |
|---|---|---|
| Unstable Core | Draw: −25 % max HP now → an epic stat card · Embrace: a curse → an epic stat card | stat cards |
| Echo Mirror | Gaze: a curse → a rare card of the stat you raised most · Shatter: −10 % HP → 30 shards × floor | stat cards |
| Scrap Heap | Pay 35 shards × floor → a random mod · Dig: −15 % HP → a random mod | — |
| Ambush Cache | Break the seal: 3 elites (×2 HP) arrive in the room → a free chest when they fall | — |
| Overclock Vent | Overheat now (the stall) → +30 % Overclock damage for the floor | heat |
| Blood Price | −12 % max HP for the run → one owned ability levels up | abilities |
| Wandering Drone | Stay within 4.5 m for 20 s, spawns twice as fast → 45 shards × floor | — |
| Cleansing Font | Pay 30 shards × floor, or −20 % HP → your latest curse is lifted | a curse held |

  Changes from the brief: **Echo Mirror** repeats the stat you raised most (the sim keeps no per-card stacks, only
  stat values); **Wandering Drone** is a defence (stay by it), not an escort (no friendly-AI actor exists).
  "Leave it" is the panel's last card on every event, not an event of its own.
- **Curses** (each +1 threat T, held for the run, never twice): Swift Foes (normal enemies +15 % move speed),
  Withering (−20 % regen), Leaky Core (Overclock heat decays 2× faster), Swarm Call (+1 enemy in every spawn
  arrival, under the alive cap), Price Gouge (+25 % shard prices: chests, the gamble shrine, event costs, and shops
  through `Curses.price`), Marked Hunt (12 % of spawns are elites: ×2 HP, a gold crown ring).
- **Cursed chests:** 25 % of chest offers (rolled on first open) turn their first card into a guaranteed epic stat
  card carrying a curse you don't hold, marked on the card; the other cards are clean. Altars are never cursed.
- **Cleanse:** the Cleansing Font, and `Curses.cleanse(w)` for shops (SH) to call.
- **Threat T** = the held curses' threat; shown on the HUD (top left, while T > 0), in the pause menu and in the run
  recap ("Threat: T (peak P)"); `World.threat_peak` and `RunState.threat_by_floor` record it for M-THREAT.
- **Elites** did not exist before EV: an elite here is a normal enemy kind with +100 % HP and a crown ring; its
  attacks are its kind's own (readable). SC may fold this into a shared elite rule.
- **Streams:** room picks on `map:event`, event and cursed-chest rolls on `loot:event`, the elite curse's roll on
  `ai:elite`, sub-streams of `map`, `loot` and `ai` like `ai:enemy`, so no older draw moved (SIM_CONTRACTS §5).

## Open items
- Q1 (from v0.4.0): Echoes, Core theft, Depth descent — still unanswered; not built.
- O3 `main`; O4 credit line.

## Verification
- Unit + e2e per step; generation property tests for new rooms (1,000 seeds); readable cause 0 violations; sims as
  evidence; goldens only on purpose; full suite, lint, export smoke before every merge push; CI green.
