# Interactions: engines, items and combos

The item × item table BLUEPRINT §D asks for, for the 24 items and 8 named combos of v0.3.0 step G (PLAN L8).
Every number is a **starting value** the owner tunes after playing; the data in `data/items/` and
`data/combos/` is the source of truth, and this page follows it.

## Engines

An engine is a status that stacks, scales with more stacks or partners, and comes back every fight. Each has
3–4 members by tag (checked by `tests/content/test_combo_validation.gd`).

| Engine | Members (tag) | Trigger → Condition → Payoff | Renewable / scales by |
|---|---|---|---|
| **Burn** (fire) | Ember Edge, Cinder Shot, Wildfire | Melee hit (Ember) or every 3rd landed bolt (Cinder) → once per root per enemy → +1 stack; 2 damage per stack every 0.5 s (DoT) | Each stack refreshes 3 s; cap 5; Wildfire spreads 1 + half the victim's stacks to enemies within 2.5 m on a kill |
| **Shock** (shock) | Static Chain, Overcharge, Conductor | Every 2nd landed bolt (Static Chain), each shockwave hit (Overcharge, +2), melee hit (Conductor) → once per root per enemy → +1 stack | At 5 stacks it **discharges**: 12 to the enemy and to its 2 nearest neighbours within 4 m (4 with Conductor), then resets; stacks fade after 3 s without a new one |
| **Bleed** (bleed) | Serrated Edge, Barbed Bolts, Vampiric Core (tagged for blood: it heals on every kill, bleed kills included; Kinetic Dash adds its 12 to a burst) | Melee hit (Serrated) or every 2nd landed bolt (Barbed) → once per root per enemy → +1 stack; 1 damage per stack every 0.5 s (DoT) | Cap 8, refresh 4 s. A **dash through** a bleeding enemy (any dash, no item needed) **bursts** every stack for 5 each and clears them |
| **Frost** (frost) | Frost Core, Glacial Edge, Cold Snap | Every 3rd landed bolt (Frost Core), melee hit (Glacial), dash through (Cold Snap, +2) → +1 stack, and the 30% slow runs | At 4 stacks it **freezes** for 1 s (no AI, no movement, no attacks) and resets; no stacks build while frozen. A freeze-immune actor (bosses: `ActorStore.freeze_immune`) stops at 3 stacks and is only slowed |
| **Guard charges** (guard) | Bulwark, Phase Strike, Thorn Mantle | Guard block (Bulwark) → under 3 charges → +1 charge | The next swing spends every charge for +40% each (×2.2 at 3) |

## The loop rules (SIM_CONTRACTS §7–§8, all enforced in `src/sim/items/engines.gd`)

- **DoT never procs.** Burn and bleed ticks emit `DAMAGE` with `DOT` and proc 0, never `HIT`, so they feed no engine.
- **Payoffs never feed stacks.** Discharge, bleed burst, Plasma Arc, Shatter Dash and Blood Harvest hits add no stacks.
- **Once per root chain.** `ProcLedger` records (root, effect, target): a swing adds one stack per enemy per engine
  (so Twin Arc's echo, in the same chain, adds none), a discharge or Plasma Arc fires once per root per enemy, the
  root-wide payoffs (Resonance, Shrapnel Storm, Blood Harvest, Spiked Phase) once per root.
- **Ancestry.** A payoff runs inside `Engines.begin/end`; an effect already in the running chain never re-enters it
  (`SimEvent.ancestry` and `depth` record the chain on every payoff `HIT`).
- **Watchdog.** A chain deeper than 8, or a tick past 512 events, stops with one `LIMIT` naming the effect. The soak
  test (all 24 items, guard, 5,000 ticks against real enemies) asserts 0 watchdog `LIMIT` events.
- **Caps.** Blood Harvest heals inside Vampiric Core's cap (15 per 5 s); Slipstream refunds at most once per 1.5 s.

## Items (24)

| Item | Tags | Trigger | Condition | Payoff |
|---|---|---|---|---|
| Long Edge | blade | Swing | always | reach +35% |
| Twin Arc | blade | Swing | 0.1 s later | an echo swing at 50% |
| Ember Edge | fire, blade | Melee hit | once per swing per enemy | a burn stack (2 per 0.5 s each, max 5) |
| Splinter Shot | bolt | Shot | always | 3 bolts in a fan at 60% each |
| Rapid Coil | bolt | Holding shoot | always | 40% faster fire |
| Ricochet Core | bolt | Bolt meets a wall | a bounce left | it bounces once |
| Kinetic Dash | dash | Dash through an enemy | once per dash per enemy | 12 damage |
| Overcharge | shock, blade | Every 4th swing | always | double damage + a shockwave (+2 shock) |
| Vampiric Core | bleed | Kill | heal cap left (15 per 5 s) | heal 3 |
| Static Chain | shock, bolt | Landed bolt | every 3rd; every 2nd for shock | a 5-damage jump; +1 shock |
| Momentum | dash, blade | Dash ends | a swing within 1 s | +60% swing damage |
| Frost Core | frost, bolt | Landed bolt | every bolt; every 3rd for frost | 30% slow 1.5 s; +1 frost |
| Thorn Mantle | guard | You take damage | alive | a ring of 6 bolts (4 each) |
| Executioner | blade | Your hit | target under 30% HP | +50% damage |
| Swift Feet | dash | Always | always | +15% move, dash 20% sooner |
| Phase Strike | guard | Blink lands / guard block | first block per 2 s | 12 in a 1.5 m ring |
| Cinder Shot | fire, bolt | Landed bolt | every 3rd | +1 burn stack |
| Wildfire | fire | Kill | enemies within 2.5 m | burn 1 + half the victim's stacks |
| Conductor | shock, blade | Melee hit | once per swing per enemy | +1 shock; discharges jump to 4 |
| Serrated Edge | bleed, blade | Melee hit | once per swing per enemy | +1 bleed (1 per stack per 0.5 s, max 8) |
| Barbed Bolts | bleed, bolt | Landed bolt | every 2nd | +1 bleed |
| Glacial Edge | frost, blade | Melee hit | once per swing per enemy | +1 frost and the slow |
| Cold Snap | frost, dash | Dash through / your hit | chilled or frozen target | +2 frost; +20% / +60% damage |
| Bulwark | guard | Guard block | fewer than 3 charges | +1 charge; next swing +40% each |

## Named combos (8)

Owning both items unlocks the combo at once (`SimEvent.COMBO_UNLOCKED`, the combo card, a HUD badge). Each combo
pairs two different mechanics and adds one payoff neither item has alone.

| Combo | Items | Effect | Limit |
|---|---|---|---|
| **Plasma Arc** | Ember Edge + Conductor (was Static Chain until v0.3.0 P: a Gun item can't meet a Blade item in one run, L15) | Shocking a burning enemy arcs to the nearest other within 4 m: 8 damage and 1 burn stack | once per root per enemy |
| **Shatter Dash** | Frost Core + Kinetic Dash | A dash through a frozen enemy shatters it: 30 damage, the freeze ends | once per dash per enemy |
| **Resonance** | Twin Arc + Overcharge | The echo of an Overcharge swing sends a second shockwave (100% of the first) | once per swing; its wave adds no extra shock (the swing's root already fed it) |
| **Shrapnel Storm** | Splinter Shot + Ricochet Core | A bolt that bounces bursts into 2 shards (40° fan, 60% damage each) | once per bolt; shards never bounce or burst |
| **Blood Harvest** | Vampiric Core + Executioner | An executed kill bursts in a 2.5 m blood nova (8 damage) and heals 2 inside Vampiric Core's cap | once per root; a nova kill never chains another nova (ancestry + root) |
| **Spiked Phase** | Thorn Mantle + Phase Strike | Phase Strike's ring also fires the Thorn Mantle ring | once per discharge |
| **Slipstream** | Momentum + Swift Feet | A Momentum swing that lands recharges the dash at once | at most once per 1.5 s (refund cap) |
| **Frozen Bastion** | Bulwark + Glacial Edge | A guard block chills the attacker (within 4 m) with 2 frost stacks | once per block; frost stops building while frozen |

## Ability combos (8, v0.4.0 AB)

Owner F13 ("more objects or upgrades and combos"); PLAN v0.4.0 "Ability combos". Owning **both abilities at level 3
or higher** evolves the pair (`ComboDefinition.ability_a/ability_b/min_level`, the v0.3.0 combo framework:
`COMBO_UNLOCKED`, the combo card with both ability icons, a HUD badge, its sound). Three of them use the three new
auto abilities, which feed the engines above: **Arc Field** adds shock (Static Chain's numbers when no shock item is
owned), **Frost Nova** frost (Glacial Edge's), **Flame Trail** burn (Ember Edge's). Their hits carry no melee or bolt
source, so no item feeder adds stacks through them; the stacks come from the ability itself.

| Combo | Abilities | Effect | Limit | Look |
|---|---|---|---|---|
| **Storm Bombs** | Bomb Lobber + Arc Field | A bomb's blast chains lightning to the 3 nearest enemies within 5 m: 10 damage and 1 shock stack each | once per bomb (root); runs inside the ancestry guard | violet jagged bolts from the blast |
| **Napalm Drone** | Drone Buddy + Flame Trail | A drone bolt that lands leaves a 1 m fire patch for 1.5 s (3 damage per 0.5 s, 1 burn stack) | once per bolt; fire hits an enemy at most every 0.5 s whatever patch it stands in | deep red fire discs |
| **Glacier Ring** | Orbit Blades + Frost Nova | Every blade touch adds 1 frost stack | once per blade hit per enemy (its root); no stacks while frozen | the blades turn to ice |
| **Blink Charge** | Blink + Bomb Lobber | Each blink leaves 2 of Bomb Lobber's bombs (its level's radius and damage) where you left | once per blink | a violet flash where you left; the bombs' ground circles |
| **Blade Dance** | Combo Sword + Orbit Blades | A landed swing spreads the blades 0.8 m wider and makes their hits +50 % for 1.5 s | refreshed by each landed swing, never stacks | the blades drawn larger |
| **Wingman** | Pulse Gun + Drone Buddy | Each shot makes every drone fire a bolt along your aim (60 % of a drone bolt) | at most every 0.25 s | a cyan flash at each drone |
| **Superconductor** | Arc Field + Frost Nova | An Arc Field strike on a chilled or frozen enemy deals double | a damage factor only, no extra hit | the bolt turns cyan-white and thicker |
| **Ember Ward** | Flame Trail + Aegis | A guard block bursts fire around you: 14 damage and 2 burn stacks within 2.5 m | at most once a second; inside the ancestry guard | an orange ring burst |

Pairs across builds: Blade Dance needs the Blade (Combo Sword), Wingman the Gun (Pulse Gun); Blink Charge and Ember Ward
exclude each other (Blink and Aegis share the utility button). Every other pair can meet in either build.

## Matrix

S = synergy, A = anti-synergy, · = none. Rows and columns use the codes below; every pair's reason follows.

`LE` Long Edge `TA` Twin Arc `EE` Ember Edge `SS` Splinter Shot `RC` Rapid Coil `RI` Ricochet Core `KD` Kinetic Dash `OC` Overcharge `VC` Vampiric Core `SC` Static Chain `MO` Momentum `FC` Frost Core `TM` Thorn Mantle `EX` Executioner `SF` Swift Feet `PS` Phase Strike `CS` Cinder Shot `WF` Wildfire `CO` Conductor `SE` Serrated Edge `BB` Barbed Bolts `GE` Glacial Edge `CN` Cold Snap `BW` Bulwark

| | LE | TA | EE | SS | RC | RI | KD | OC | VC | SC | MO | FC | TM | EX | SF | PS | CS | WF | CO | SE | BB | GE | CN | BW |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **LE** | — | · | S | · | · | · | · | S | · | · | · | · | · | · | · | · | · | · | S | S | · | S | · | · |
| **TA** | · | — | · | · | · | · | · | S | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · | · |
| **EE** | S | · | — | · | · | · | · | S | · | S | · | · | · | · | · | · | S | S | S | S | · | · | · | · |
| **SS** | · | · | · | — | · | S | · | · | · | S | · | S | · | · | · | · | S | · | · | · | S | · | · | · |
| **RC** | · | · | · | · | — | · | · | · | · | S | · | S | · | · | · | · | S | · | · | · | S | · | · | · |
| **RI** | · | · | · | S | · | — | · | · | · | S | · | S | · | · | · | · | S | · | · | · | S | · | · | · |
| **KD** | · | · | · | · | · | · | — | · | · | · | S | S | · | · | S | · | · | · | · | S | S | · | S | · |
| **OC** | S | S | S | · | · | · | · | — | · | S | · | · | · | · | · | · | · | · | S | S | · | S | · | · |
| **VC** | · | · | · | · | · | · | · | · | — | · | · | · | S | S | · | · | · | S | · | S | S | · | · | · |
| **SC** | · | · | S | S | S | S | · | S | · | — | · | S | · | · | · | · | S | · | S | · | S | · | · | · |
| **MO** | · | · | · | · | · | · | S | · | · | · | — | · | · | · | S | · | · | · | · | · | · | · | · | S |
| **FC** | · | · | · | S | S | S | S | · | · | S | · | — | A | · | · | · | · | · | · | · | · | S | S | A |
| **TM** | · | · | · | · | · | · | · | · | S | · | · | A | — | · | A | S | · | · | · | · | · | A | A | S |
| **EX** | · | · | · | · | · | · | · | · | S | · | · | · | · | — | · | · | · | S | · | S | S | · | S | · |
| **SF** | · | · | · | · | · | · | S | · | · | · | S | · | A | · | — | · | · | · | · | S | S | · | S | A |
| **PS** | · | · | · | · | · | · | · | · | · | · | · | · | S | · | · | — | · | · | · | · | · | · | · | S |
| **CS** | · | · | S | S | S | S | · | · | · | S | · | · | · | · | · | · | — | S | · | · | S | · | · | · |
| **WF** | · | · | S | · | · | · | · | · | S | · | · | · | · | S | · | · | S | — | · | · | · | · | · | · |
| **CO** | S | · | S | · | · | · | · | S | · | S | · | · | · | · | · | · | · | · | — | · | · | · | · | · |
| **SE** | S | · | S | · | · | · | S | S | S | · | · | · | · | S | S | · | · | · | · | — | S | · | · | · |
| **BB** | · | · | · | S | S | S | S | · | S | S | · | · | · | S | S | · | S | · | · | S | — | · | · | · |
| **GE** | S | · | · | · | · | · | · | S | · | · | · | S | A | · | · | · | · | · | · | · | · | — | S | S |
| **CN** | · | · | · | · | · | · | S | · | · | · | · | S | A | S | S | · | · | · | · | · | · | S | — | A |
| **BW** | · | · | · | · | · | · | · | · | · | · | S | A | S | · | A | S | · | · | · | · | · | S | A | — |

276 pairs: 63 synergy, 7 anti-synergy, 206 none.

## Every pair

### Long Edge

- **Twin Arc** — none: A longer swing and an echo swing share no trigger, resource or status.
- **Ember Edge** — synergy: A longer swing feeds burn to more enemies at once.
- **Splinter Shot** — none: A longer swing and more, weaker bolts share no trigger, resource or status.
- **Rapid Coil** — none: A longer swing and faster bolts share no trigger, resource or status.
- **Ricochet Core** — none: A longer swing and bouncing bolts share no trigger, resource or status.
- **Kinetic Dash** — none: A longer swing and a damaging dash share no trigger, resource or status.
- **Overcharge** — synergy: The charged swing reaches 35% farther (the wave is centred on you, unchanged).
- **Vampiric Core** — none: A longer swing and kill healing share no trigger, resource or status.
- **Static Chain** — none: A longer swing and bolt shocks and jumps share no trigger, resource or status.
- **Momentum** — none: A longer swing and dash-then-swing share no trigger, resource or status.
- **Frost Core** — none: A longer swing and bolt chill share no trigger, resource or status.
- **Thorn Mantle** — none: A longer swing and thorns when hurt share no trigger, resource or status.
- **Executioner** — none: A longer swing and execute damage share no trigger, resource or status.
- **Swift Feet** — none: A longer swing and speed share no trigger, resource or status.
- **Phase Strike** — none: A longer swing and a phase ring share no trigger, resource or status.
- **Cinder Shot** — none: A longer swing and bolt burn share no trigger, resource or status.
- **Wildfire** — none: A longer swing and kill-spread burn share no trigger, resource or status.
- **Conductor** — synergy: A longer swing feeds shock to more enemies at once.
- **Serrated Edge** — synergy: A longer swing feeds bleed to more enemies at once.
- **Barbed Bolts** — none: A longer swing and bolt bleed share no trigger, resource or status.
- **Glacial Edge** — synergy: A longer swing feeds frost to more enemies at once.
- **Cold Snap** — none: A longer swing and dash chill and cold damage share no trigger, resource or status.
- **Bulwark** — none: A longer swing and guard charges share no trigger, resource or status.

### Twin Arc

- **Ember Edge** — none: The echo hits again but adds no second burn stack (same root chain).
- **Splinter Shot** — none: An echo swing and more, weaker bolts share no trigger, resource or status.
- **Rapid Coil** — none: An echo swing and faster bolts share no trigger, resource or status.
- **Ricochet Core** — none: An echo swing and bouncing bolts share no trigger, resource or status.
- **Kinetic Dash** — none: An echo swing and a damaging dash share no trigger, resource or status.
- **Overcharge** — synergy: **Resonance** (named combo): The echo of an Overcharge swing sends a second shockwave (100% of the first).
- **Vampiric Core** — none: An echo swing and kill healing share no trigger, resource or status.
- **Static Chain** — none: An echo swing and bolt shocks and jumps share no trigger, resource or status.
- **Momentum** — none: An echo swing and dash-then-swing share no trigger, resource or status.
- **Frost Core** — none: An echo swing and bolt chill share no trigger, resource or status.
- **Thorn Mantle** — none: An echo swing and thorns when hurt share no trigger, resource or status.
- **Executioner** — none: An echo swing and execute damage share no trigger, resource or status.
- **Swift Feet** — none: An echo swing and speed share no trigger, resource or status.
- **Phase Strike** — none: An echo swing and a phase ring share no trigger, resource or status.
- **Cinder Shot** — none: An echo swing and bolt burn share no trigger, resource or status.
- **Wildfire** — none: An echo swing and kill-spread burn share no trigger, resource or status.
- **Conductor** — none: The echo adds no second shock stack (same root chain); it only deals damage.
- **Serrated Edge** — none: The echo adds no second bleed stack (same root chain); it only deals damage.
- **Barbed Bolts** — none: An echo swing and bolt bleed share no trigger, resource or status.
- **Glacial Edge** — none: The echo adds no second frost stack (same root chain); it only deals damage.
- **Cold Snap** — none: An echo swing and dash chill and cold damage share no trigger, resource or status.
- **Bulwark** — none: An echo swing and guard charges share no trigger, resource or status.

### Ember Edge

- **Splinter Shot** — none: Melee burn and more, weaker bolts share no trigger, resource or status.
- **Rapid Coil** — none: Melee burn and faster bolts share no trigger, resource or status.
- **Ricochet Core** — none: Melee burn and bouncing bolts share no trigger, resource or status.
- **Kinetic Dash** — none: Melee burn and a damaging dash share no trigger, resource or status.
- **Overcharge** — synergy: The charged swing applies burn at double damage.
- **Vampiric Core** — none: Melee burn and kill healing share no trigger, resource or status.
- **Static Chain** — none in one run since v0.3.0 L15 (Ember Edge is Blade-only, Static Chain Gun-only); Plasma Arc now pairs Ember Edge with Conductor.
- **Momentum** — none: Melee burn and dash-then-swing share no trigger, resource or status.
- **Frost Core** — none: Melee burn and bolt chill share no trigger, resource or status.
- **Thorn Mantle** — none: Melee burn and thorns when hurt share no trigger, resource or status.
- **Executioner** — none: Melee burn and execute damage share no trigger, resource or status.
- **Swift Feet** — none: Melee burn and speed share no trigger, resource or status.
- **Phase Strike** — none: Melee burn and a phase ring share no trigger, resource or status.
- **Cinder Shot** — synergy: Both feed burn (melee and bolts); one burn pool, capped at 5.
- **Wildfire** — synergy: Ember Edge lights enemies; Wildfire spreads half their stacks on a kill.
- **Conductor** — synergy: **Plasma Arc** (named combo): swings both burn and shock, and shocking a burning enemy arcs to the nearest other within 4 m: 8 damage and 1 burn stack.
- **Serrated Edge** — synergy: Swings apply burn and bleed: two DoTs, neither procs on-hit effects.
- **Barbed Bolts** — none: Melee burn and bolt bleed share no trigger, resource or status.
- **Glacial Edge** — none: Melee burn and melee chill share no trigger, resource or status.
- **Cold Snap** — none: Melee burn and dash chill and cold damage share no trigger, resource or status.
- **Bulwark** — none: Melee burn and guard charges share no trigger, resource or status.

### Splinter Shot

- **Rapid Coil** — none: More, weaker bolts and faster bolts share no trigger, resource or status.
- **Ricochet Core** — synergy: **Shrapnel Storm** (named combo): A bolt that bounces bursts into 2 shards (40° fan, 60% damage each).
- **Kinetic Dash** — none: More, weaker bolts and a damaging dash share no trigger, resource or status.
- **Overcharge** — none: More, weaker bolts and a charged swing share no trigger, resource or status.
- **Vampiric Core** — none: More, weaker bolts and kill healing share no trigger, resource or status.
- **Static Chain** — synergy: 3 bolts per shot: more landed bolts, more shock stacks.
- **Momentum** — none: More, weaker bolts and dash-then-swing share no trigger, resource or status.
- **Frost Core** — synergy: 3 bolts per shot: more landed bolts, more frost stacks.
- **Thorn Mantle** — none: More, weaker bolts and thorns when hurt share no trigger, resource or status.
- **Executioner** — none: Splinters at 60% still get +50% under 30% HP; no extra interaction.
- **Swift Feet** — none: More, weaker bolts and speed share no trigger, resource or status.
- **Phase Strike** — none: More, weaker bolts and a phase ring share no trigger, resource or status.
- **Cinder Shot** — synergy: 3 bolts per shot: more landed bolts, more burn stacks.
- **Wildfire** — none: More, weaker bolts and kill-spread burn share no trigger, resource or status.
- **Conductor** — none: More, weaker bolts and melee shock share no trigger, resource or status.
- **Serrated Edge** — none: More, weaker bolts and melee bleed share no trigger, resource or status.
- **Barbed Bolts** — synergy: 3 bolts per shot: more landed bolts, more bleed stacks.
- **Glacial Edge** — none: More, weaker bolts and melee chill share no trigger, resource or status.
- **Cold Snap** — none: More, weaker bolts and dash chill and cold damage share no trigger, resource or status.
- **Bulwark** — none: More, weaker bolts and guard charges share no trigger, resource or status.

### Rapid Coil

- **Ricochet Core** — none: Faster bolts and bouncing bolts share no trigger, resource or status.
- **Kinetic Dash** — none: Faster bolts and a damaging dash share no trigger, resource or status.
- **Overcharge** — none: Faster bolts and a charged swing share no trigger, resource or status.
- **Vampiric Core** — none: Faster bolts and kill healing share no trigger, resource or status.
- **Static Chain** — synergy: 40% more bolts: more landed bolts, more shock stacks.
- **Momentum** — none: Faster bolts and dash-then-swing share no trigger, resource or status.
- **Frost Core** — synergy: 40% more bolts: more landed bolts, more frost stacks.
- **Thorn Mantle** — none: Faster bolts and thorns when hurt share no trigger, resource or status.
- **Executioner** — none: Faster bolts and execute damage share no trigger, resource or status.
- **Swift Feet** — none: Faster bolts and speed share no trigger, resource or status.
- **Phase Strike** — none: Faster bolts and a phase ring share no trigger, resource or status.
- **Cinder Shot** — synergy: 40% more bolts: more landed bolts, more burn stacks.
- **Wildfire** — none: Faster bolts and kill-spread burn share no trigger, resource or status.
- **Conductor** — none: Faster bolts and melee shock share no trigger, resource or status.
- **Serrated Edge** — none: Faster bolts and melee bleed share no trigger, resource or status.
- **Barbed Bolts** — synergy: 40% more bolts: more landed bolts, more bleed stacks.
- **Glacial Edge** — none: Faster bolts and melee chill share no trigger, resource or status.
- **Cold Snap** — none: Faster bolts and dash chill and cold damage share no trigger, resource or status.
- **Bulwark** — none: Faster bolts and guard charges share no trigger, resource or status.

### Ricochet Core

- **Kinetic Dash** — none: Bouncing bolts and a damaging dash share no trigger, resource or status.
- **Overcharge** — none: Bouncing bolts and a charged swing share no trigger, resource or status.
- **Vampiric Core** — none: Bouncing bolts and kill healing share no trigger, resource or status.
- **Static Chain** — synergy: Bounced bolts get a second target: more landed bolts, more shock stacks.
- **Momentum** — none: Bouncing bolts and dash-then-swing share no trigger, resource or status.
- **Frost Core** — synergy: Bounced bolts get a second target: more landed bolts, more frost stacks.
- **Thorn Mantle** — none: Bouncing bolts and thorns when hurt share no trigger, resource or status.
- **Executioner** — none: Bouncing bolts and execute damage share no trigger, resource or status.
- **Swift Feet** — none: Bouncing bolts and speed share no trigger, resource or status.
- **Phase Strike** — none: Bouncing bolts and a phase ring share no trigger, resource or status.
- **Cinder Shot** — synergy: Bounced bolts get a second target: more landed bolts, more burn stacks.
- **Wildfire** — none: Bouncing bolts and kill-spread burn share no trigger, resource or status.
- **Conductor** — none: Bouncing bolts and melee shock share no trigger, resource or status.
- **Serrated Edge** — none: Bouncing bolts and melee bleed share no trigger, resource or status.
- **Barbed Bolts** — synergy: Bounced bolts get a second target: more landed bolts, more bleed stacks.
- **Glacial Edge** — none: Bouncing bolts and melee chill share no trigger, resource or status.
- **Cold Snap** — none: Bouncing bolts and dash chill and cold damage share no trigger, resource or status.
- **Bulwark** — none: Bouncing bolts and guard charges share no trigger, resource or status.

### Kinetic Dash

- **Overcharge** — none: A damaging dash and a charged swing share no trigger, resource or status.
- **Vampiric Core** — none: A damaging dash and kill healing share no trigger, resource or status.
- **Static Chain** — none: A damaging dash and bolt shocks and jumps share no trigger, resource or status.
- **Momentum** — synergy: Dash through for 12, then a +60% swing on the way out.
- **Frost Core** — synergy: **Shatter Dash** (named combo): A dash through a frozen enemy shatters it: 30 damage, the freeze ends.
- **Thorn Mantle** — none: A damaging dash and thorns when hurt share no trigger, resource or status.
- **Executioner** — none: A damaging dash and execute damage share no trigger, resource or status.
- **Swift Feet** — synergy: The dash recharges 20% sooner: more dash hits.
- **Phase Strike** — none: Blink and dash are separate moves; no shared trigger.
- **Cinder Shot** — none: A damaging dash and bolt burn share no trigger, resource or status.
- **Wildfire** — none: A damaging dash and kill-spread burn share no trigger, resource or status.
- **Conductor** — none: A damaging dash and melee shock share no trigger, resource or status.
- **Serrated Edge** — synergy: Dash through a bleeder: Kinetic Dash's 12 plus the burst (5 per stack).
- **Barbed Bolts** — synergy: Shoot to bleed, then dash through for 12 plus the burst.
- **Glacial Edge** — none: A damaging dash and melee chill share no trigger, resource or status.
- **Cold Snap** — synergy: One dash: 12 damage and 2 frost stacks, +60% if it froze.
- **Bulwark** — none: A damaging dash and guard charges share no trigger, resource or status.

### Overcharge

- **Vampiric Core** — none: A charged swing and kill healing share no trigger, resource or status.
- **Static Chain** — synergy: Bolt shocks and shockwave shocks fill the same 5-stack meter.
- **Momentum** — none: A charged swing and dash-then-swing share no trigger, resource or status.
- **Frost Core** — none: A charged swing and bolt chill share no trigger, resource or status.
- **Thorn Mantle** — none: A charged swing and thorns when hurt share no trigger, resource or status.
- **Executioner** — none: A charged swing and execute damage share no trigger, resource or status.
- **Swift Feet** — none: A charged swing and speed share no trigger, resource or status.
- **Phase Strike** — none: A charged swing and a phase ring share no trigger, resource or status.
- **Cinder Shot** — none: A charged swing and bolt burn share no trigger, resource or status.
- **Wildfire** — none: A charged swing and kill-spread burn share no trigger, resource or status.
- **Conductor** — synergy: The charged swing's wave adds 2 shock on top of Conductor's 1.
- **Serrated Edge** — synergy: The charged swing applies bleed at double damage.
- **Barbed Bolts** — none: A charged swing and bolt bleed share no trigger, resource or status.
- **Glacial Edge** — synergy: The charged swing applies frost at double damage.
- **Cold Snap** — none: A charged swing and dash chill and cold damage share no trigger, resource or status.
- **Bulwark** — none: A charged swing and guard charges share no trigger, resource or status.

### Vampiric Core

- **Static Chain** — none: Kill healing and bolt shocks and jumps share no trigger, resource or status.
- **Momentum** — none: Kill healing and dash-then-swing share no trigger, resource or status.
- **Frost Core** — none: Kill healing and bolt chill share no trigger, resource or status.
- **Thorn Mantle** — synergy: Thorn kills heal you back for the hit that fired them.
- **Executioner** — synergy: **Blood Harvest** (named combo): An executed kill bursts in a 2.5 m blood nova (8 damage) and heals 2 inside Vampiric Core's cap.
- **Swift Feet** — none: Kill healing and speed share no trigger, resource or status.
- **Phase Strike** — none: Kill healing and a phase ring share no trigger, resource or status.
- **Cinder Shot** — none: Kill healing and bolt burn share no trigger, resource or status.
- **Wildfire** — synergy: Kills both heal and spread burn; burn kills heal too.
- **Conductor** — none: Kill healing and melee shock share no trigger, resource or status.
- **Serrated Edge** — synergy: Both feed bleed.
- **Barbed Bolts** — synergy: Both feed bleed.
- **Glacial Edge** — none: Kill healing and melee chill share no trigger, resource or status.
- **Cold Snap** — none: Kill healing and dash chill and cold damage share no trigger, resource or status.
- **Bulwark** — none: Kill healing and guard charges share no trigger, resource or status.

### Static Chain

- **Momentum** — none: Bolt shocks and jumps and dash-then-swing share no trigger, resource or status.
- **Frost Core** — synergy: Both act on landed bolts: each bolt can slow, chill and shock.
- **Thorn Mantle** — none: Bolt shocks and jumps and thorns when hurt share no trigger, resource or status.
- **Executioner** — none: Bolt shocks and jumps and execute damage share no trigger, resource or status.
- **Swift Feet** — none: Bolt shocks and jumps and speed share no trigger, resource or status.
- **Phase Strike** — none: Bolt shocks and jumps and a phase ring share no trigger, resource or status.
- **Cinder Shot** — synergy: Bolts burn and shock (no named combo: Plasma Arc is the Blade's, Ember Edge + Conductor).
- **Wildfire** — none: Bolt shocks and jumps and kill-spread burn share no trigger, resource or status.
- **Conductor** — synergy: Bolts and swings both feed shock; Conductor's discharges reach 4.
- **Serrated Edge** — none: Bolt shocks and jumps and melee bleed share no trigger, resource or status.
- **Barbed Bolts** — synergy: Both act on landed bolts: bleed and shock from one stream.
- **Glacial Edge** — none: Bolt shocks and jumps and melee chill share no trigger, resource or status.
- **Cold Snap** — none: Bolt shocks and jumps and dash chill and cold damage share no trigger, resource or status.
- **Bulwark** — none: Bolt shocks and jumps and guard charges share no trigger, resource or status.

### Momentum

- **Frost Core** — none: Dash-then-swing and bolt chill share no trigger, resource or status.
- **Thorn Mantle** — none: Dash-then-swing and thorns when hurt share no trigger, resource or status.
- **Executioner** — none: Dash-then-swing and execute damage share no trigger, resource or status.
- **Swift Feet** — synergy: **Slipstream** (named combo): A Momentum swing that lands recharges the dash at once.
- **Phase Strike** — none: Dash-then-swing and a phase ring share no trigger, resource or status.
- **Cinder Shot** — none: Dash-then-swing and bolt burn share no trigger, resource or status.
- **Wildfire** — none: Dash-then-swing and kill-spread burn share no trigger, resource or status.
- **Conductor** — none: Dash-then-swing and melee shock share no trigger, resource or status.
- **Serrated Edge** — none: Dash-then-swing and melee bleed share no trigger, resource or status.
- **Barbed Bolts** — none: Dash-then-swing and bolt bleed share no trigger, resource or status.
- **Glacial Edge** — none: Dash-then-swing and melee chill share no trigger, resource or status.
- **Cold Snap** — none: Dash-then-swing and dash chill and cold damage share no trigger, resource or status.
- **Bulwark** — synergy: Both empower the next swing and multiply: block, dash, then swing.

### Frost Core

- **Thorn Mantle** — anti-synergy: Freezes stop enemies attacking you, and thorns need you to be hit.
- **Executioner** — none: Bolt chill and execute damage share no trigger, resource or status.
- **Swift Feet** — none: Bolt chill and speed share no trigger, resource or status.
- **Phase Strike** — none: Bolt chill and a phase ring share no trigger, resource or status.
- **Cinder Shot** — none: Bolt chill and bolt burn share no trigger, resource or status.
- **Wildfire** — none: Bolt chill and kill-spread burn share no trigger, resource or status.
- **Conductor** — none: Bolt chill and melee shock share no trigger, resource or status.
- **Serrated Edge** — none: Bolt chill and melee bleed share no trigger, resource or status.
- **Barbed Bolts** — none: Bolt chill and bolt bleed share no trigger, resource or status.
- **Glacial Edge** — synergy: Bolts and swings both feed frost: 4 stacks freeze.
- **Cold Snap** — synergy: Frost Core chills at range; Cold Snap adds +20% / +60% on chilled / frozen.
- **Bulwark** — anti-synergy: Frozen enemies don't attack, so there is less to block for charges.

### Thorn Mantle

- **Executioner** — none: Thorns when hurt and execute damage share no trigger, resource or status.
- **Swift Feet** — anti-synergy: Speed avoids hits, and thorns need you to be hit.
- **Phase Strike** — synergy: **Spiked Phase** (named combo): Phase Strike's ring also fires the Thorn Mantle ring.
- **Cinder Shot** — none: Thorns when hurt and bolt burn share no trigger, resource or status.
- **Wildfire** — none: Thorns when hurt and kill-spread burn share no trigger, resource or status.
- **Conductor** — none: Thorns when hurt and melee shock share no trigger, resource or status.
- **Serrated Edge** — none: Thorns when hurt and melee bleed share no trigger, resource or status.
- **Barbed Bolts** — none: Thorns when hurt and bolt bleed share no trigger, resource or status.
- **Glacial Edge** — anti-synergy: Freezes stop enemies attacking you, and thorns need you to be hit.
- **Cold Snap** — anti-synergy: Freezes stop enemies attacking you, and thorns need you to be hit.
- **Bulwark** — synergy: Guarding still lets reduced damage through: each block stores a charge and fires thorns.

### Executioner

- **Swift Feet** — none: Execute damage and speed share no trigger, resource or status.
- **Phase Strike** — none: Execute damage and a phase ring share no trigger, resource or status.
- **Cinder Shot** — none: Execute damage and bolt burn share no trigger, resource or status.
- **Wildfire** — synergy: Executioner finishes enemies sooner, so Wildfire spreads sooner.
- **Conductor** — none: Execute damage and melee shock share no trigger, resource or status.
- **Serrated Edge** — synergy: Bleed bursts are hits, so Executioner raises them on low-HP enemies.
- **Barbed Bolts** — synergy: Bleed bursts are hits, so Executioner raises them on low-HP enemies.
- **Glacial Edge** — none: Execute damage and melee chill share no trigger, resource or status.
- **Cold Snap** — synergy: Both multiply your hits: +50% low-HP and +60% frozen stack (multiplicative).
- **Bulwark** — none: Execute damage and guard charges share no trigger, resource or status.

### Swift Feet

- **Phase Strike** — none: Speed and a phase ring share no trigger, resource or status.
- **Cinder Shot** — none: Speed and bolt burn share no trigger, resource or status.
- **Wildfire** — none: Speed and kill-spread burn share no trigger, resource or status.
- **Conductor** — none: Speed and melee shock share no trigger, resource or status.
- **Serrated Edge** — synergy: Sooner dashes burst bleed more often.
- **Barbed Bolts** — synergy: Sooner dashes burst bleed more often.
- **Glacial Edge** — none: Speed and melee chill share no trigger, resource or status.
- **Cold Snap** — synergy: The dash recharges 20% sooner: more dash chills.
- **Bulwark** — anti-synergy: Guarding slows you to 40%, wasting the speed; charges need you to stand.

### Phase Strike

- **Cinder Shot** — none: A phase ring and bolt burn share no trigger, resource or status.
- **Wildfire** — none: A phase ring and kill-spread burn share no trigger, resource or status.
- **Conductor** — none: A phase ring and melee shock share no trigger, resource or status.
- **Serrated Edge** — none: A phase ring and melee bleed share no trigger, resource or status.
- **Barbed Bolts** — none: A phase ring and bolt bleed share no trigger, resource or status.
- **Glacial Edge** — none: A phase ring and melee chill share no trigger, resource or status.
- **Cold Snap** — none: A phase ring and dash chill and cold damage share no trigger, resource or status.
- **Bulwark** — synergy: Each guard block both stores a charge and (once per 2 s) fires the phase ring.

### Cinder Shot

- **Wildfire** — synergy: Cinder Shot lights enemies at range; Wildfire spreads their stacks on a kill.
- **Conductor** — none: Bolt burn and melee shock share no trigger, resource or status.
- **Serrated Edge** — none: Bolt burn and melee bleed share no trigger, resource or status.
- **Barbed Bolts** — synergy: Both act on landed bolts: burn and bleed DoTs stack on one target.
- **Glacial Edge** — none: Bolt burn and melee chill share no trigger, resource or status.
- **Cold Snap** — none: Bolt burn and dash chill and cold damage share no trigger, resource or status.
- **Bulwark** — none: Bolt burn and guard charges share no trigger, resource or status.

### Wildfire

- **Conductor** — none: Kill-spread burn and melee shock share no trigger, resource or status.
- **Serrated Edge** — none: Kill-spread burn and melee bleed share no trigger, resource or status.
- **Barbed Bolts** — none: Kill-spread burn and bolt bleed share no trigger, resource or status.
- **Glacial Edge** — none: Kill-spread burn and melee chill share no trigger, resource or status.
- **Cold Snap** — none: Kill-spread burn and dash chill and cold damage share no trigger, resource or status.
- **Bulwark** — none: Kill-spread burn and guard charges share no trigger, resource or status.

### Conductor

- **Serrated Edge** — none: Melee shock and melee bleed share no trigger, resource or status.
- **Barbed Bolts** — none: Melee shock and bolt bleed share no trigger, resource or status.
- **Glacial Edge** — none: Melee shock and melee chill share no trigger, resource or status.
- **Cold Snap** — none: Melee shock and dash chill and cold damage share no trigger, resource or status.
- **Bulwark** — none: Melee shock and guard charges share no trigger, resource or status.

### Serrated Edge

- **Barbed Bolts** — synergy: Melee and bolts both feed bleed, to its 8-stack cap.
- **Glacial Edge** — none: Melee bleed and melee chill share no trigger, resource or status.
- **Cold Snap** — none: Melee bleed and dash chill and cold damage share no trigger, resource or status.
- **Bulwark** — none: Melee bleed and guard charges share no trigger, resource or status.

### Barbed Bolts

- **Glacial Edge** — none: Bolt bleed and melee chill share no trigger, resource or status.
- **Cold Snap** — none: Bolt bleed and dash chill and cold damage share no trigger, resource or status.
- **Bulwark** — none: Bolt bleed and guard charges share no trigger, resource or status.

### Glacial Edge

- **Cold Snap** — synergy: Swings chill, dashes chill; frozen enemies take +60% from your swings.
- **Bulwark** — synergy: **Frozen Bastion** (named combo): A guard block chills the attacker (within 4 m) with 2 frost stacks.

### Cold Snap

- **Bulwark** — anti-synergy: Frozen enemies don't attack, so there is less to block for charges.

### Bulwark
