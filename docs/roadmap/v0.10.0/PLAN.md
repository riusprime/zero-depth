# v0.10.0 — The new look of attacks (plan, owner-directed 2026-10-31)

## Context
- **Owner (2026-10-31):** "you can start with v0.10.0 and v0.10.5 will be focused on feedback from the gameplay, I
  already gave you some feedback I am holding it to test it with the changes I gave you on effects and elements".
  - **An exception to ROADMAP §0.3** (no minor version before the owner plays the previous one), granted by the
    owner. v0.9.5 gets no playtest of its own. The owner plays v0.9.5 and v0.10.0 together (effects, elements, the
    early build, the Bomb gone), and that feedback opens **v0.10.5**.
  - **Lead's call:** v0.9.5 has no separate release PR. Its last steps (EP3, the combo e2e fix, seams) close on
    `claude/v095-feedback`, v0.10.0 builds on top, and **one PR into `main`** at v0.10.0's release carries both, with
    patch notes for each version. The owner can ask for a v0.9.5 PR first.
- **Scope:** the owner's purchased VFX pack (`newVFX/`) replaces the attack effects, as G1
  [`../v0.9.5/VFX_PACK.md`](../v0.9.5/VFX_PACK.md) was answered on 2026-10-31:
  - R1–R43 and I1–I9 as proposed;
  - I7: the hero's fire patches shift cooler;
  - I10: the licence is held;
  - N1–N10: the gaps are built in the pack's style where it works.
  - R6 is moot (the Bomb was removed, v0.9.5 BR).
- **The cost test and gallery:** [`../v0.9.5/evidence/VFX_PACK.md`](../v0.9.5/evidence/VFX_PACK.md),
  `build/vfx_lab/index.html` (owner's PC).
- **Not in v0.10.0 unless the owner asks:**
  - the Blade's own forms (v0.9.5 G11: "its forms wait for v0.10.0"). They need a G1 of their own (no design
    exists yet). Asked as Q1 below. Until then VX8 gives the Blade's *existing* swings the pack's look;
  - the non-attack packs (Portal, Loot and the others).

## Every owner line → where it lands
| # | Owner line | Kind | Step |
|---|---|---|---|
| V1 | The VFX pack replaces the attack effects; recolour to elements | **Decided:** G1 VFX_PACK | VX0–VX5 |
| V2 | Gaps built in the pack's style ("take that style and how they are built and build something new") | **Decided:** VFX_PACK N rows | VX6–VX8 |
| V3 | I7: the hero's fire patches shift cooler | **Direct** | VX3 |
| V4 | v0.10.5 is the feedback pass | Process | — |
| V5–V13 | The VFX cleanup brief (2026-10-31, nine points: Laser + Homing + Pierce, deaths, stray sprites and lights, stack indicators, the Foundry, Blink, Seekers, Void, general clutter) | **Direct** (owner's brief) | FX |

## Design questions
**Q1. The Blade's forms.** v0.9.5 left them "for v0.10.0".
- (a) Write a G1 for them now and build them in v0.10.0 after the VFX steps.
- (b) Leave them for v0.10.5 or later; v0.10.0 is the look only. ← recommended: the owner holds feedback for this build, so a small, focused v0.10.0 gets to the playtest sooner.

## Steps
Each step is *presentation only* unless it says otherwise. Each adds:
- one shot per thing the owner will look at;
- the hitch probe once the warm-up exists;
- the e2e that reaches the effect.

### VX0. The pack in the game, and one family to judge (foundation)
- **Install (I1):** copy the attack packs from `newVFX/*.zip` into `assets/BinbunVFX/` (`fire_effects`, `beam_vfx`,
  `ice_effects`, `magic_orbs`, `magic_projectiles`, `impact_explosions`, `magic_areas`, `muzzle_flash`,
  `poison_effects`, `smoke_effects`, `shared`) and `addons/magic_circles/` (without its demo).
  - **The `shared` folder:** where the packs ship different copies, keep the newest copy that every scene still loads
    with, and prove it by loading every effect scene in a test.
  - **What isn't installed:** the non-attack packs; the zips stay out of git.
  - **Credits:** the Magic Circles credits line goes into `data/credits/licences.tres` (I10); the Binbun packs are
    named there as licensed.
- **`PackFx` (new, `src/presentation/world_view/vfx/pack_fx.gd`):** the one way the game spawns a pack effect.
  - **Pools:** instances per effect scene are kept and reused (`spawn(id, pos, colors, scale, life_ticks)`). Each
    family has a cap (I5, starting values: hit 24, impact 12, explosion 12, area 16, beam 8, cloud 4,
    projectile 96, status 32). Past the cap, the oldest instance is reused.
  - **Lights (I3):** each instance's own light is switched off (`light_enable = false` on its VFXController and any
    Light3D). A family that should glow asks VfxCore for one through `light_merged`.
  - **Colours (I6):** `primary`, `secondary` and `tertiary` come from `ElementLooks` (the first element's core, the
    second element's rim).
  - **Timing (I8):** `speed_scale` follows the view's time (0 in pause and hit-stop).
  - **Density (I9):** low, medium and high scale the caps ×0.25 / ×0.55 / ×1.
  - **Ids:** effects are named by a short id in a data table (`data/vfx/pack_fx.tres`: id → scene path, family,
    scale, base colours), so later steps only add rows.
- **Warm-up (I2):** while the LoadingCover is up (`CoverLoads`, a ViewBuildQueue job), every effect in the table is
  spawned once in front of the camera for 2 frames, then returned to its pool.
  - **Check:** the hitch probe (`scripts/checks/hitch_probe.gd`) on the owner's PC shows no first-use stall in the
    first fight.
- **The family to judge:** VfxLayer's fire explosion (R18: `vfx_explosion_01/03/04` + `smoke_vfx` after) replaces
  `vfx_layer.gd`'s `_explosion`. Burst budgets, merging and pressure thinning stay as they are.
- **Evidence:**
  - shots of the old and the new explosion in two biomes;
  - a 20-enemy fight's frame time on the owner's PC, before and after;
  - the warm-up's time behind the cover.
- **The owner looks at the explosion before VX1 starts.**

### Lead's calls after VX0 (2026-10-31; the owner approved continuing: "we can continue with the VX tasks", up to 5
agents at once)
- **I4 changes (lead, to confirm with the owner):** every effect goes through PackFx scenes, including every-shot ones
  (hits, muzzle flashes, bolts). Lifting the pack's shaders into our MultiMesh pools would mean rewriting each pack
  shader for per-instance animation; VX0's lab measured 24 hits or projectiles at +0.2–0.6 ms (lights off). Each
  family has a cap, and past it the instance draws the OLD look (no live effect is taken over). If the final 20-enemy
  measurement misses, the heaviest family moves into a pool then.
- **PackFx API (lead):** `life` 0 holds an effect until `release()` (bolts, zones, statuses that follow something),
  `has_room()`, and an `enemy_shot` family (cap 128) so the hero's bolts never starve hostile shots. Each step ships
  its own table file, `data/vfx/pack_fx_vx<N>.tres`.
- **VX-W, warm-up spread (lead, after the merges):** with ~100 ids the per-effect warm-up jobs would lengthen loads.
  Warm one id a frame, and only the ids a floor can use (its biome's bosses, the hero's build); keep the cover moving
  (owner O70).
- **VX1–VX5 run at once,** each on its own files.

### VX1. Hits and flashes (R10–R17)
- **Bolt impacts per element (R14) and every-shot muzzle flashes (R10):** I4 says these move the pack's shaders and
  textures into our MultiMesh pools (`VfxCore`, `HeroFx`), not a scene per shot.
- **Through PackFx:** heavy impacts (R15), slash impacts (R16), guard sparks (R17), crit and bounce flashes (R12),
  cast flashes (R11) and sigils (R13, Magic Circles).

### VX2. The hero's projectiles and forms (R1–R5, R7–R9)
- **Orbs per element (R1), Seekers (R2) and Wisps (R3):** the pack's shaders in the HeroPulse and form pools (I4).
- **Through PackFx:** Laser (R4), Lance (R5), Void's body (R7), Rune Explosion (R8) and the spec forms (R9).

### VX3. Zones, rings and status (R20–R30), and the cooler fire patches (I7)
- **Ground effects:** fire patches, frost and venom fields, the Toxic Fumes cloud (cap 4), bleed pools, rings.
- **Status on enemies:** burn, poison and frost, capped by STATUS budgets.
- **I7:** the hero's fire patches go through `AttackFormLooks.ground_safe`.

### VX4. Enemy shots (R31–R35)
The 18 fireball looks map to the pack's balls, javelins and orbs (warm hues kept for hostiles).

### VX5. Bosses, shields, deaths (R19, R27, R36–R43)

### VX6. Lightning in the pack's style (N1)
- **Strikes:** bolts, chains and forks use the laser shader on a jagged strip, plus the hit spark.
- **Shock status:** small forks round the body.

### VX7. The other gaps (N2, N4, N5, N8, N9)
Bleed drips and splatter, the Glaive, Wave and crescent looks, the void rim, Tidecaller water, and lasting floor
marks.

### VX8. Blade swings in the pack's style (N3)
The pack's look on the Blade's existing swings: a ribbon trail along the swing with the beam's scrolling noise, and
slash flashes. The Blade's forms are Q1.

### FX. The VFX cleanup (owner's brief, 2026-10-31)
The owner, after a look at the build: "the latest VFX overhaul has introduced visual clutter, performance problems, and
regressions ... make combat visually cleaner, more readable, smoother, and better optimized", "restore older effects
when they were objectively better", "do not revert the entire overhaul blindly". Evidence:
[`evidence/FX.md`](evidence/FX.md). The lead's calls, per point:
- **1. Laser + Homing + Pierce.** Each Homing leg was its own pack beam scene with its own start flare, which gave the 7–8
  overlapping beams. Now:
  - the Laser draws its own ribbons again (`LaserView.PACK_LASER` off), and a lane's chain of legs is one strip along
    the sim's points, corners rounded (`_join`, `_round`, `_lay_path`), so the beam and the hits stay in step;
  - **sim:** Homing no longer swings the aim (it turned at 120 °/s toward the nearest enemy; `home_dps` is gone), so the
    beam leaves along the player's aim at once and bends toward its targets;
  - a target must be in sight of the hero (`World.sees`) and no more than 90° off the aim;
  - legs are 0.75 m and turn at most 12° each (were 1.5 m and 25°: the same curve, smoother), up to 24 legs.
- **2. Deaths.** VX1's smoke and flash on every kill are gone, and so is the smoke after every pack fire explosion
  (`smoke_after`: 4.1 s). A kill is the old lit chunks.
- **3. Stray sprites and lights.**
  - Godot does not size a world-space particle by its node's scale, so every scaled-down pack effect drew its particles
    full size (the white starbursts, oversized flashes). An effect that stands where it spawned now has local particles
    (`PackFx.WORLD_SPACE`: only projectiles, enemy shots and trails keep world space).
  - Enemy lob and rain shots were keyed by their place in the frame's list, so a landed shot's effect jumped to the next
    shot and its trail streaked across the screen. They are keyed by the drone and the drop now.
  - Any held effect that jumps more than 1.5 m in a frame restarts its particles (`PackFx.settle`).
- **4. Stack indicators.** `StatusBadges`: an icon (drawn in code) and an `xN` count (`STATUS_STACK_COUNT`) for burn,
  bleed, poison, shock and frost, in a row over the bar. They replace the shock pips and the poison and bleed dots.
- **5. Foundry.** VX5's pack fire areas stood on the molten floor's own shader (up to 4 a piece, 10 round the meltdown),
  so both looks drew at once. The pack flames are removed; the floor shader stays. The rain and lob keys (point 3) were
  the Foundry's other duplicate.
- **6. Blink.** The flash plays its whole animation in 0.28 s (`PackFx.spawn` gains `speed`); it was 1.1 s at each end.
  The old flash fallback is 0.22 s (was 0.36 s).
- **7. Seekers (sim).**
  - The search reaches 12 m (was 10.8 m) and a dart lives 1.3 s (was 1 s: 10 m of flight for a 10.8 m search).
  - A target must be in sight of the hero.
- **8. Void.** Its v0.9.5 look is back (`VoidView.PACK_VOID`, `PACK_SPARKS`, `GapPack.PACK_RIFT` off; their rows
  removed).
- **9. Clutter, judged one by one.**
  - **Removed:**
    - the frozen pack effects on every frost and splat floor mark (7 s each, on the decals);
    - the pack splatter laid on the bleed splat decal every 2 s;
    - the puddle after venom and bleed bursts.
  - **Kept:** the hits, impacts, zones, enemy shots, lightning and blade looks (improvements once their particles are
    the right size).
- **Goldens:** the laser and the Seekers changes are sim changes; they move no golden unless a golden run uses Homing
  or the Seekers (the seams run says).

### R. Release
- The release checklist (ROADMAP §0.4) for v0.10.0, covering v0.9.5 too.
- One PR into `main`.
- PLAYTEST.md asks the owner about effects, elements and the early build together.

## Open items (what they block)
- **Q1** (the Blade's forms) blocks nothing in VX0–VX8.
- **The owner's look at VX0's explosion** gates VX1–VX8.

## Verification
- **Per step:**
  - shots for the owner;
  - every pack scene the table names loads (content test);
  - PackFx caps, lights off, colours and density (unit tests);
  - the e2e that reaches each replaced effect.
- **Performance (PLAN PF's target carries over):** a 20-enemy fight with a two-element build stays under the v0.9.5
  frame time on the owner's PC. The hitch probe shows no first-use stall.
- **At release:** the full suite on the PR, goldens unchanged (presentation only), the export smoke.
