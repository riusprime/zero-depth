# v0.10.0 progress

## Where we are
(The lead keeps this block current at every push; the SessionStart hook prints it. Updated 2026-10-31.)

- **Started 2026-10-31** on the owner's word ("you can start with v0.10.0 and v0.10.5 will be focused on feedback"),
  an exception to ROADMAP §0.3: v0.9.5 and v0.10.0 are played together, and that feedback opens v0.10.5.
- **Built and merged on `claude/v0100-vfx`:** VX0-VX8 and VX-W (the whole VFX pack plan), on top of all of v0.9.5
  (EP1-EP4, BR, EP3, the combo e2e fix). Seams 590/592 before the lead's fixes (`c03c1fef`: the dev panel's
  data/vfx, the soak's pool count, two PackFx tests); those four files pass since. Each VX unit file passes.
- **Not on the owner's folder yet** (owner, 2026-10-31: "nah i'll wait"). `claude/v095-feedback` stays at
  `15769f6a` until the owner asks for the update.
- **Next:** one batch of shots for the owner (running), a clean 20-enemy frame-time run, then the update of the
  owner's folder when they ask; the release step.
- **Waiting on the owner:** Q1 (the Blade's forms: now or later), the look of the shots, the menu's four ~0.1 s
  warm-up hitches (VX-W).

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

## Goldens changed on purpose
- (none)

## Gates
- G1 VFX_PACK: answered 2026-10-31 (in v0.9.5's folder).

## Open
- Q1 the Blade's forms.

## Blockers
- (none)

## History
- 2026-10-31: VX1-VX8 and VX-W built by Sonnet agents (5, then 4, at once; owner's limit) and merged; three helpers named PackHold renamed (FormPackHold, BossPackHold); PackFx fixed for per-instance materials and held effects.
- 2026-10-31: v0.10.0 started on the owner's word; PLAN written.
