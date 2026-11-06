# O11a: how each verb feels today (theory audit P7, Swink's game feel)

Measure-and-document only. No game code or data was changed. Every number below was read from the code or data at
branch `v0105-o11a` (cut from `claude/v0100-cleanup` at 516caed7). Nothing here was run or timed; "ticks" are sim
ticks at 60 Hz (`src/sim/core/sim_tick.gd:5`), 1 tick = 16.7 ms. Paths are relative to the repo root.

Reading the swing timeline (`src/sim/combat/player_kit.gd:74-104`): a press is buffered at `world.gd:725`, before
`_advance_actions` (`world.gd:763`), so an idle press starts the swing on the same tick (`swing_t = 1`, line 98). The
hit resolves when `swing_t == active_tick` (line 83), so "start-up" = `active_tick` ticks after the start tick. The
swing ends when `swing_t > ticks` (line 86), and a buffered press starts the next swing on that same tick (line 94).
Whether the tick-to-screen path adds a frame of latency is not measured here (`NOT YET RUN`).

## 1. Blade four-slash combo

Source rows: `data/player/runner.tres:12-58` (seconds), compiled by `compile_swing_step` in
`src/application/content_compiler.gd` (`seconds_to_ticks`, `sim_tick.gd:25`; start-up at least 1 tick). The same
numbers are in `src/sim/world/player_table.gd:91-98`.

| | Hit 1 slash R-L | Hit 2 backhand L-R | Hit 3 thrust | Hit 4 spin (finisher) |
|---|---|---|---|---|
| Start-up (press to hit) | 2 ticks (33 ms) `runner.tres:15` | 3 ticks (50 ms) `:27` | 4 ticks (67 ms) `:39` | 7 ticks (117 ms) `:51` |
| Active window | 1 tick (the hit resolves on one tick, `player_kit.gd:83-84`, `swing_step.gd:3-7`) | 1 tick | 1 tick | 1 tick |
| Recovery (after the hit) | 11 ticks (183 ms) `:16` | 11 ticks `:28` | 12 ticks (200 ms) `:40` | 24 ticks (400 ms) `:52` |
| Whole swing | 13 ticks (217 ms) | 14 ticks (233 ms) | 16 ticks (267 ms) | 31 ticks (517 ms) |
| Hit-stop (sim, only if the hit lands) | 3 ticks `runner.tres:20` | 3 ticks `:32` | 3 ticks `:44` | 5 ticks `:56` |
| Damage / arc / reach | 10, 120 deg, 1.6 m `:19,17,18` | 10, 120 deg, 1.6 m | 12, 40 deg, 2.3 m `:43,41,42` | 24, 360 deg, 1.9 m `:55,53,54` |
| Forward step (lunge) | 0 `:21` | 0 | 0.35 m over 3 ticks `:45`, `swing_step.gd:51-52` | 0.6 m over 6 ticks `:57` |

Sim hit-stop mechanics: `add_freeze` adds the step's ticks to `freeze_ticks`, capped at 8 (`world.gd:852-853`,
`sim_tick.gd:8`), only when the swing landed (`player_kit.gd:172-173`). While `freeze_ticks > 0` the whole sim is
held: nothing moves, the input buffer does not age, new presses are still buffered (`world.gd:690-694`). Taking a hit
also freezes 4 ticks (`player_definition.gd:19`, `damage.gd:238-239`). The S1 values 3,3,3,5 are stated in
`player_table.gd:90`. The view adds a separate 2-frame hold (section 8).

Other combo facts:

- **Movement during the swing:** not locked and not slowed. The ordinary move branch runs with `vel` easing and adds
  `PlayerKit.lunge_offset` on top (`world.gd:1706`); `armed()` gates starting an attack, not movement
  (`player_kit.gd:121-124`). Only hits 3 and 4 add a forward step (above). The swing angle is fixed at swing start
  along the facing (`player_kit.gd:99`).
- **Move speed:** 6 m/s base (`player_definition.gd:11`), eases in over 0.1 s (`:13`) and stops over 5 ticks (`:14`).
- **Input buffer:** 6 ticks (`sim_tick.gd:6`; `SIM_CONTRACTS.md:109`). A press only counts if it lands within 6 ticks
  before the swing can start (the last 6 ticks of recovery, or any time after). A press earlier in the swing is lost.
  The buffer does not age during hit-stop (`SIM_CONTRACTS.md:47`).
- **Combo reset window:** `combo_window_seconds` default 0.2 s = 12 ticks (`primary_definition.gd:9`;
  `player_table.gd:43`). It opens when a swing ends, only for steps 1-3 (`player_kit.gd:88`); after the finisher it is
  0 and the next press starts hit 1. It counts down only while no swing runs (lines 89-90) and not during hit-stop. A
  press inside the window gives the next step; after it runs out the combo restarts at hit 1 (`next_step`, lines
  141-144).
- **Full combo length:** 13+14+16+31 = 74 ticks (1.23 s), plus up to 14 ticks of hit-stop if all four land
  (3+3+3+5).
- **Attack speed:** `BladeForms.step` rescales all four timings by one rate (`blade_forms.gd:72-96`); at rate 1000 and
  no step bonus it returns the base table (lines 81-82). The numbers above are the unmodified base.
- **Dash cancel:** nothing cancels a swing. `PlayerKit.advance` ticks `swing_t` regardless of `armed()`
  (`player_kit.gd:81-90`), and no code resets `swing_t` except death (`world.gd:1644`; grep over `src` for
  `swing_t =`). A dash can be started at any swing phase (start-up, active, recovery); the swing keeps counting and
  the hit still resolves on its tick from the dashed-to position, but the swing's own forward step is skipped during
  the dash (`world.gd:1677-1678` replaces the move branch). While dashing, `armed()` is false (`player_kit.gd:122`),
  so no new swing starts; a buffered press waits. The dash start condition checks only the cooldown, curses and
  `PlayerSkill.busy` (`world.gd:1661`), not the swing.
- **Vent cancel:** no. Vent is not gated by swing, dash or skill (`player_skill.gd:47-51, 85-95`), and it does not
  touch `swing_t`.
- **Skill cancel:** the Skill needs `swing_t == 0` and no dash (`player_skill.gd:71-82`), so it cannot interrupt a
  swing; its press waits in a 6-tick buffer (`player_skill.gd:23-28`).

## 2. Lunge Cleave (the Blade's skill) and the Gun

| | Lunge Cleave (Blade) | Scatter Blast (Gun skill) | Gun primary (held SHOOT) |
|---|---|---|---|
| Data | `data/builds/blade.tres:6-17` | `data/builds/gun.tres:6-21` | `data/player/runner.tres:63-67` |
| Cooldown | 4.0 s = 240 ticks, counted from the press (`blade.tres:11`, `player_skill.gd:101`) | 3.5 s = 210 ticks (`gun.tres:11`) | Shot interval 0.15 s = 9 ticks (`runner.tres:63`, `player_table.gd:47`) |
| Start-up | 12 ticks of lunge (0.2 s), the fan hits as `skill_t` passes 12 (`player_skill.gd:58-64`, `blade.tres:15`) | 0: the pellets fire on the press tick (`player_skill.gd:112-113`) | 0: the first bolt fires on the tick SHOOT is held with `shot_cd == 0` (`player_kit.gd:113-115`) |
| Locked window | 12 ticks (0.2 s): moves 3.5 m along the facing (`blade.tres:14`), no swing, shot, dash or blink (`player_kit.gd:124`, `world.gd:1661`, `player_kit.gd:29`) | 6 ticks (0.1 s) of 0.8 m recoil backward (`gun.tres:20-21`), same lock | None: move and shoot freely |
| Recovery | 0 ticks after the hit | 0 after the recoil | none (the interval is the only gap) |
| Hit | 28 dmg, 180 deg, 2.2 m (`blade.tres:12,16-17`), x1.15 Blade factor (`blade.tres:25`); hit-stop 7 ticks (0.1167 s, `blade.tres:18`) if it lands (`player_skill.gd:143-144`) | 7 pellets x 6 dmg, 60 deg cone, 4.0 m (`gun.tres:12-16`); each non-boss enemy hit is pushed 1.5 m over 8 ticks (`gun.tres:18-19`, `player_skill.gd:176-185`); no hit-stop | 5 dmg, 16.2 m/s, 0.2 m radius, 40 ticks (10.8 m) life (`runner.tres:64-67`) |
| Heat | +5.0 on a landed use (`blade.tres:13`) | +2.5 (`gun.tres:13`) | Fills by firing time: 840 ticks (14 s) empty to full (`heat_table.gd:13`; `data/heat` `gun_fill_seconds = 14.0`) |
| Move speed while using | Replaced by the lunge (velocity zeroed, `world.gd:1679-1682`) | Replaced by the recoil | Unchanged; only the Laser form slows to 75 % (`world.gd:1691`) |

Notes: the Gun cannot swing and a Blade run cannot shoot (`player_kit.gd:92-93`, `:127-131`). Shots are blocked while
dashing, guarding, in a skill, stalled by overheat or stunned (`player_kit.gd:121-124`). The shot interval is re-read
from item effects each shot (`ItemEffects.shot_period_ticks`, `player_kit.gd:115`). The Cleave's lunge angle is fixed at
press time and is not steerable (`player_skill.gd:106`).

## 3. Dash

| Item | Value | Source |
|---|---|---|
| Distance | 4.0 m | `dash_definition.gd:5`, `world.gd:1678` |
| Duration | 0.15 s = 9 ticks (0.444 m/tick, about 26.7 m/s) | `dash_definition.gd:6`, `content_compiler.gd` compile_player |
| Start-up | 0: starts on the press tick when off cooldown | `world.gd:1661-1667` |
| I-frames | 0.15 s = 9 ticks, the whole dash, from its first tick | `dash_definition.gd:8`, `world.gd:1304-1310`, `damage.gd:119` |
| Cooldown | 10.0 s = 600 ticks (items such as Swift Feet can shorten it) | `runner.tres:10`, `world.gd:1667` |
| Direction | Move input, else the aim | `player_kit.gd:44-46` |
| Recovery | None; the cooldown is the only cost | `world.gd:1644-1658` |
| What it cancels | No action is cancelled: a swing in progress keeps counting (section 1). It replaces the move branch (velocity is not eased during it, `world.gd:1677-1678`). It blocks new swings, shots, Blink and guard while active | `player_kit.gd:28,122`, `world.gd:874` |
| What blocks it | Cooldown, the Rooted curse, the Brittle stun, a running Skill | `world.gd:1659-1661` |
| Buffer | 6 ticks | `sim_tick.gd:6` |
| S12 perfect-Vent refund | A Vent from 90 or more heat sets `dash_cooldown_left = 0` and emits `DASH_REFUND` | `heat.gd:283-286`, `heat_table.gd:31-32`, heat data `perfect_vent_from = 90` |
| Hurt i-frames (not the dash) | 0.5 s = 30 ticks after being hit | `player_definition.gd:18`, `damage.gd:238` |

## 4. Blink and Aegis (the utility)

There is no utility at the start of a run; it comes from an ability card (`abilities.gd:167-176`).

| | Blink (ability) | Aegis (guard) |
|---|---|---|
| Data | `data/abilities/blink.tres` | `data/abilities/aegis.tres`; guard numbers `player_table.gd:31-34` |
| Start-up | 0: teleport on the press tick (`player_kit.gd:33-37`) | 0: active while the UTILITY button is held (`world.gd:871-877`) |
| Range | up to 5 m (`blink.tres` `range_m`), through a wall only when a free spot lies beyond within range (`player_kit.gd:49-71`) | n/a |
| I-frames | 0.1 s = 6 ticks (`blink.tres` `duration_seconds`, `abilities.gd:194-196`; the forced-loadout default is also 6, `player_table.gd:38`) | none; hits from the front 120-deg arc take 20 % (`player_table.gd:31-32`) |
| Cooldown | 15 / 14 / 13 / 12 / 11 s by level, 1 / 1 / 2 / 2 / 2 charges (`blink.tres` `level_cooldown`, `level_extra`); charges recharge in turn (`abilities.gd:217-234`). Forced-loadout default 150 ticks = 2.5 s (`player_table.gd:37`) | None (held) |
| Move speed | normal | 40 % while held (`player_table.gd:34`, `world.gd:1692-1693`) |
| Extra | 15-damage landing shock, radius 2 m (1.4 at level 5) (`blink.tres`) | Stores 1-5 guard charges feeding the next swing (`aegis.tres` `level_extra`, `abilities.gd:240-246`) |
| Blocked by | dash, a running Skill, the Brittle stun (`player_kit.gd:25-32`) | dash (`world.gd:874`); `armed()` is false while guarding, so no swing or shot (`player_kit.gd:122`) |
| Cancels | Nothing; a swing in progress keeps counting | Nothing started; it only prevents new attacks |

## 5. Vent

| Item | Value | Source |
|---|---|---|
| Windup | 0: the blast fires on the press tick | `player_skill.gd:47-51`, `heat.gd:273-290` |
| Blast | Radius 2.5 m, damage = heat x 0.5, hits every enemy in the disc, resets heat to 0 | `heat_table.gd:25-27`, `heat.gd:311-345` |
| Minimum heat | 40 points (a refused press emits a silent `VENT_COLD`) | `heat_table.gd:29`, `player_skill.gd:85-95` |
| Cooldown | 6.0 s = 360 ticks, counted from a successful Vent | `heat_table.gd:30`, `heat.gd:282` |
| Perfect band | 90 or more heat: refunds the dash (S12) | `heat_table.gd:32`, `heat.gd:283-286` |
| Heat gain | 2.5 per landed swing, 5.0 per finisher, the Skill adds its own; the Gun fills over 14 s of firing | `heat_table.gd:10-13`, `heat.gd:163-171, 177-186` |
| Thresholds | Hot 40, Overclock 75, overheat at 100 = 72-tick (1.2 s) stall: no attacks, move 60 % | `heat_table.gd:19-24`, `heat.gd:59, 203-216, 225-234` |
| Overheat refuses Vent | yes (`stall > 0` fails `vent_ready`) | `heat.gd:295-299` |
| Lock on the hero | None: Vent is not gated by swing, dash or skill and locks nothing | `player_skill.gd:47-51` |
| Cooling | starts 60 ticks after the last gain, 25 points/s | `heat_table.gd:16-17` |
| Buffer | 6 ticks | `player_skill.gd:23-28` |

## 6. Enemy hit reactions today

- **Simulation: a normal enemy does not flinch, stagger, stun or get interrupted by a hit.** `enemy_ai.gd`,
  `elite_ai.gd` and `elites.gd` contain no flinch, stagger or knock handling (grep `flinch|stagger|knock|stun`); the
  only enemy halt is the frost freeze from an item engine (`enemy_ai.gd:141`). The AI has no per-kind hit-reaction
  branch.
- **Sim knockback exists only from two sources, neither in the base combo:** Scatter Blast pushes each non-boss enemy
  1.5 m over 8 ticks (`gun.tres:18-19`, `player_skill.gd:176-205`), and the Heavy modifier card adds `knockback_m`
  1.5 (+0.25 per level) to melee steps, non-boss (`data/modifiers/heavy.tres` Op_2, `blade_forms.gd:129-132, 155-170`;
  `data/wand/blade_forms.tres:10` `knock_seconds = 0.13`).
- **Bosses:** the STAGGERED state is never entered by the sim now (v0.9.5 BH1, `boss_ai.gd:103-108`); only a 30-tick
  post-stagger cooldown constant remains (`boss_ai.gd:19`). No sim reaction to hits.
- **View-only flinch (pose only; the sim body never moves):** every normal enemy avatar (`AvatarBase.flinch`,
  `avatar_base.gd:116`) leans back 0.3 rad and squashes 16 % for 0.2 s, peaking at 25 % of the way, retriggerable
  after 0.12 s (`avatar_base.gd:24-30`). A Blade hit also shifts the pose up to 0.09 m away from the swing
  (`avatar_base.gd:33`); a bolt does not (knock 0). Bosses use `BossAvatar.flinch`'s own clip (`boss_avatar.gd:418`;
  `hit_feel.gd:17-18`). A node without a `flinch` method is skipped (`hit_feel.gd` `_flinch`).
- **Hit flash:** 3 frames of white on whoever takes damage; the finisher doubles it (`actor_views.gd:41`,
  `hit_feel.gd:26, 77-83`).
- **View hit-stop on a Blade hit:** the hero's swing pose and the struck enemies are held 2 frames (2/60 s), shared by
  one swing's hits, at most one new freeze per 9 sim ticks, off with the Hit-stop option or reduced motion
  (`hit_stop.gd:21-28, 33-34`).
- **Death:** a pop of 7 shards (`hit_feel.gd:30, 94-96`).

## 7. Impact on the hero

A hit on the hero gives 30 ticks of invulnerability and a 4-tick sim freeze (`damage.gd:238-239`) and a camera shake
of 0.55 (`hit_feel.gd:86-87`). It does not interrupt a swing, dash or skill (no code resets them on damage).

## 8. Camera and feel polish

| Feel element | Trigger | Value | Source |
|---|---|---|---|
| Camera shake | The hero is hit | amount 0.55 (0 to 1; decays 2.5 per second; view offset up to 0.35 m scaled) | `hit_feel.gd:86-87`, `iso_rig.gd:80-90, 128-130` |
| Camera shake | The Blade finisher (hit 4) lands (once per tick) | 0.3 | `hit_feel.gd:27, 80-83` |
| Camera kick | Any Blade hit | 0.06 m (finisher 0.1 m) along the swing, eases out over 0.09 s | `hit_stop.gd:34-35, 84`, `iso_rig.gd:9, 100-110` |
| Thud / vibration | Boss door landings, elite slam, lockdowns, final approach, portal transit (not player verbs) | various | `world_view_root.gd:630-694` |
| Shake gating | Off with the shake option or reduced motion | | `iso_rig.gd:97, 120, 133` |
| Hit flash | Any damage | 3 frames; finisher 6 | `actor_views.gd:41`, `hit_feel.gd:26` |
| Impact FX | Each player hit on an enemy (a cut along the slash for Blade, sparks) | ImpactFx | `hit_feel.gd:88-90` |
| Spark scales | Guard 0.3, deflect 0.25, weak spot 0.4, exposed 0.5, armour 0.22, finisher 0.4 | pack scenes | `hit_feel.gd:45-51` |
| Damage numbers | Every direct player hit; DoT ticks are quiet | white size 37, crit yellow size 69; life 0.75 s (crit 0.8 s); pool 40 | `damage_numbers.gd:15-25` |
| Blade swing sound | Swing's first tick | `blade_slash_1` (R-L), `blade_slash_2` (L-R), `blade_slash_3` (any later slash), `blade_thrust`, `blade_spin` | `audio_events.gd:795-805` |
| Hit sound | A non-DoT damage event on an enemy | `enemy_hit` (melee) / `bolt_hit` (projectile), pitched up on a crit, down on a boss | `audio_events.gd:455-470` |
| Gun shot | A new player projectile (once per tick) | `bolt_fire` (form variants: bomb, void, wave, scatter, glaive, seekers) | `audio_events.gd:808-840` |
| Skill | `SKILL_USED` event | `skill_lunge_cleave` / `skill_scatter_blast` | `audio_events.gd:497-498, 786-791` |
| Dash | The dash starts | `dash` | `audio_events.gd:770-773` |
| Blink | A new blink tick | `blink_out` at the origin plus `blink_in` at the destination | `audio_events.gd:774-777` |
| Vent / heat | Vent, threshold cross, overheat | `heat_vent`, `heat_threshold`, `heat_overheat`; a refused Vent is silent; a perfect Vent plays the combo chime, lower | `audio_events.gd:499-502, 906` |
| Guard | A guarded or blocked hit | `guard_block` | `audio_events.gd:471-473` |
| Hit taken | The hero is damaged | `hit_taken` | `audio_events.gd:463-464` |

No cue was found for the Aegis raise or the dash ending. The cue files themselves live in `data/audio/cues`; this doc
did not audit them.

## 9. Observations (facts only)

1. The spin finisher is the longest locked window: 31 ticks (517 ms) of swing, 24 of them after the hit. Slashes 1 and
   2 recover in 11 ticks.
2. Nothing in the sim cancels a swing, a dash, a Skill or a Blink in progress. No verb has a recovery cancel; the only
   cross-verb interactions are gates on starting (`armed()`, `PlayerSkill.busy`, the Skill's `swing_t == 0`).
3. A dash or Blink does not cancel a swing; the swing keeps running and its hit lands mid-dash from the new position.
4. The Skill (Lunge Cleave) is committed for 12 ticks with movement taken over by the lunge, and cannot start during a
   swing, dash or guard. Scatter Blast has no start-up and locks only for its 6-tick recoil.
5. Vent has no windup and no lock; it works during a swing, dash or skill. It is refused (silently) under 40 heat and
   during the overheat stall, and a successful Vent starts a 6 s cooldown.
6. The input buffer is 6 ticks, half the combo window (12 ticks), and does not age in hit-stop; the sim hit-stop
   (3 to 5 ticks per Blade hit, cap 8) freezes the whole world including the hero's movement.
7. A normal enemy has no sim reaction to a hit (no flinch, stagger, stun or knockback); its only reaction is a
   view-only pose flinch and flash. Knockback comes only from Scatter Blast and the Heavy card (both skip bosses);
   bosses never stagger.
8. Neither the Gun primary nor the Blade combo has a movement penalty. The only slowdowns are guarding (40 %), the
   overheat stall (60 %) and the Laser form (75 %).
9. The dash i-frames equal the full dash (9 ticks); there is no recovery after it, but a 600-tick (10 s) cooldown
   unless a Vent of 90 or more refunds it.
10. Camera shake has two sources tied to player verbs: being hit (0.55) and the Blade finisher landing (0.3). The
    skills, dash, Vent and slashes 1-3 cause no shake; the 0.06 m kick is the only camera response to hits 1-3.
