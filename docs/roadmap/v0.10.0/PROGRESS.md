# v0.10.0 progress

## Where we are
(The lead keeps this block current at every push; the SessionStart hook prints it. Updated 2026-10-31.)

- **Started 2026-10-31** on the owner's word ("you can start with v0.10.0 and v0.10.5 will be focused on feedback"),
  an exception to ROADMAP §0.3: v0.9.5 and v0.10.0 are played together, and that feedback opens v0.10.5.
- **Built and merged on `claude/v0100-vfx`:** VX0-VX8 and VX-W (the whole VFX pack plan), on top of all of v0.9.5
  (EP1-EP4, BR, EP3, the combo e2e fix). The owner's folder (`claude/v095-feedback`) was moved up to it on their word.
- **FX (the owner's cleanup brief, 2026-10-31)** on `claude/v0100-cleanup` in the owner's folder: the Laser with Homing
  is one curved beam that respects walls, no death smoke, effect particles sized right, stable keys for enemy lob and
  rain effects, status icons with `xN`, the Foundry's doubled lava flames removed, a snappy Blink, longer-reaching
  Seekers, the old Void back, the floor-mark and puddle clutter removed. See PLAN FX and evidence/FX.md.
- **Next:** the owner plays the build (v0.9.5 and v0.10.0 together); their feedback opens v0.10.5. Then the release
  step (one PR into `main`).
- **Waiting on the owner:** Q1 (the Blade's forms: now or later), the look of FX in play, the menu's four ~0.1 s
  warm-up hitches (VX-W), a 20-enemy frame time on their PC.

## Done
| Step | Commit | Notes |
|---|---|---|
| VX0 | `cb0d0402` | The pack installed, PackFx, warm-up, fire explosions; +1.3 ms a frame in a 20-enemy fire fight (single run) |
| VX1 | `b31a0e7f` | Hits, impacts, slashes, guard sparks, muzzle and cast flashes, the death puff |
| VX2 | `3e7a98ae` | The hero's shots per element, Seekers, Wisps, Laser, Lance, Void, Rune Explosion, spec forms, crit flash, sigil |
| VX3 | `28bd2879` | Zones, rings, element bursts, burn/poison/frost status, guard orbs; hero fire patches cooler (I7) |
| VX4 | `63ca49d6` | 17 of 18 enemy shot looks (nemesis_crescent in VX7) |
| VX5 | `f41f83a2` | Boss strikes, beams, pillars, fire lanes, molten floor, shell, blink, sigils, final shatter |
| VX6 | `fa9ae9b5` | Lightning built in the pack's style (ZdBolt): strikes, chains, fields, rings, bursts, shock |
| VX7 | `b65211fb` | Bleed drips, Glaive ring, Wave crest and wash, void rift, Tidecaller water, frost and splat marks |
| VX8 | `80cd73f8` | Blade swing trail, cut spark, form crescents, eruption, rings, Lunge Cleave |
| VX-W | `2a8f3193` | Warm-up once a session at the main menu (load frames back to ~0.3 s, loads 3x shorter) |
| FX | (this commit) | The owner's cleanup brief: Laser + Homing + Pierce, deaths, particle sizes, lob/rain keys, badges, Foundry, Blink, Seekers, Void, clutter |

## Goldens changed on purpose
- (none)

## Gates
- G1 VFX_PACK: answered 2026-10-31 (in v0.9.5's folder).

## Open
- Q1 the Blade's forms.

## Blockers
- (none)

## History
- 2026-10-31: FX, the owner's VFX cleanup brief, done by the lead alone (the brief: no sub-agents). Two sim changes
  (Laser Homing aims with the player and needs sight; Seekers 12 m, 1.3 s, sight).
- 2026-10-31: VX1-VX8 and VX-W built by Sonnet agents (5, then 4, at once; owner's limit) and merged; three helpers named PackHold renamed (FormPackHold, BossPackHold); PackFx fixed for per-instance materials and held effects.
- 2026-10-31: v0.10.0 started on the owner's word; PLAN written.
