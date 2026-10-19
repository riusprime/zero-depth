# Zero Depth — performance review + wand-modifier math

Checked 2026-10-19 against `riusprime/zero-depth` @ main (v0.7.0-dev, commit of 2026-10-13).
Read-only review: nothing in the original repo was modified.

---

## Part 1 — How the wand modifiers combine (the repo's actual math)

> Heads-up: this **differs** from the earlier `wand-modifier-system-reference.md`
> sketch (additive-summed-first, then multiplicative product, mana pools, caps).
> The shipped system (v0.6.5+, `src/sim/combat/wand_compile.gd`) is Noita-style:
> **slot order, sequential rewrites, no mana**. The sketch is obsolete — don't
> balance against it.

### The pipeline

1. **Compile-time only.** The wand compiles when the build changes (card picked,
   leveled, reordered, save loaded) and caches on `World.attack_book`
   (`Modifiers.book`). Never per tick, never per frame. This is already optimal —
   the modifier math costs zero at runtime.
2. **Left to right.** Each card rewrites the spell built so far, in slot order.
   Inside one card, its ops run in the card's own stage order.
3. **A numeric op changes the field as the spell has it now.** Big then Split =
   one big shot whose splits are normal size. Split then Big = the splits are big
   too. Order is the whole game, and the repo's tests pin it
   (`test_shipped_cards_are_order_sensitive_too`).
4. **A card only touches specs carrying all of its target tags.**
   Big Shot targets `projectile` — it never touches a Blade slash.
5. **Triggers cut the wand.** Cards right of a trigger don't rewrite the shot;
   they build a child spell: a small copy of the basic attack
   (60% size, 60% range — `child_size/range_permille = 600`), dealing **50%** of
   the hit that set it off (`child_damage_permille = 500`). Depth ≤ 2, proc
   coefficient halves per level (100 → 50 → 25), max **256 launches/tick**
   (rest dropped + one LIMIT event). A legendary "On Hit ×2" casts twice,
   0.15 s apart.

### The five numeric ops (`Modifiers._numeric`)

| Op | Float field | Int field |
|---|---|---|
| SET | `cur = v` | `c = iv` |
| ADD | `cur += v` | `c += iv` |
| MAX | `cur = maxf(cur, v)` | `c = maxi(c, iv)` |
| MIN | `cur = minf(cur, v)` | `c = mini(c, iv)` |
| MUL_PERMILLE | `cur = cur * v / 1000.0` | `c = c * iv / 1000` (**integer division — truncates**) |

Permille scale: 1000 = ×1.0, 1600 = ×1.6, 700 = ×0.7. Card levels:
`value + per_level × (level − 1)`, rounded for int fields. Duplicates level up
(1–5) instead of taking a slot. Fire rate: `period × 1000 / (1000 + bonus)`,
rounded, floored at 2 ticks — Rapid Fire's +600 → period × 0.625 (60% faster).

### Worked example — Gun, base bolt damage 4, two cards

Cards: **Big Shot** (damage ×1.6 = 1600‰, radius ×2.0, speed ×0.75, life ×1.333
so range is preserved: 0.75 × 1.333 ≈ 1.0) and **Rapid Fire** (damage ×0.7,
radius ×0.6, +600‰ fire rate).

**Order A — [Big Shot, Rapid Fire]:**
- Big: damage 4 × 1600/1000 = **6** (exact)
- Rapid: damage 6 × 700/1000 = 4200/1000 = **4** (4.2 truncated)
- Result: **4 dmg**, 1.2× size, 0.75× speed, +60% fire rate

**Order B — [Rapid Fire, Big Shot]:**
- Rapid: damage 4 × 700/1000 = 2800/1000 = **2** (2.8 truncated)
- Big: damage 2 × 1600/1000 = 3200/1000 = **3** (3.2 truncated)
- Result: **3 dmg** — same two cards, **25% less damage**, purely from order
  and truncation compounding.

### Two numerical quirks worth knowing

1. **Truncation compounds.** Every MUL_PERMILLE on an int field floors. Chained
   multipliers on small base numbers (bolt starts at 4) lose more than the raw
   product suggests: 4 × 1.6 × 0.7 = 4.48 in real math, 4 then 3 in-game
   depending on order. This is *by design* (deterministic, seed-stable), but it
   means the "×1.6, ×0.7" card text overstates what small numbers actually get.
2. **The look and the number can diverge.** `damage_mul_permille` accumulates
   the raw multiplier product *without* truncation and drives the attack's
   visual weight (`attack_form_looks.gd`). In Order B above the bolt *looks*
   1.12× heavier while *hitting* for 3 vs base 4. Small, but real: heavy
   truncation makes the visual weight lie upward.

---

## Part 2 — Performance: maximize FPS without losing the look

Ranked by expected FPS impact. Every recommendation preserves the current
visuals (moody low-poly iso, warm torchlight vs cool shadows, blooming flames).
"Estimate" marks anything not measured in-repo; the repo's own measured data
point is `docs/roadmap/v0.4.0/evidence/HORDES.md` (~6,920 draw calls/frame at
120 enemies + 200 projectiles).

### 1. Enemy crowds: ~7,000 draw calls/frame (the repo's own measurement)
- `src/presentation/world_view/actor_views.gd`, `docs/roadmap/v0.4.0/evidence/HORDES.md:376-382`
- Each enemy is a full node tree (~60 meshes with X-ray twins). The repo flags
  this as the open risk for 60 fps at 120 enemies; the owner-PC check is still
  pending (OWNER ONLY in HORDES.md).
- **Do:** run that owner-PC check *first*, before any rework. If draw-call
  bound, cheap wins that keep the look: skip X-ray twins when not occluded,
  shrink `ANIMATE_RADIUS_M` (already 24 m), cull sub-parts fully behind fog.
  Full MultiMesh crowds would change silhouette animation — nuclear option only.

### 2. Four shadow-casting omni lights, re-picked every 15 frames
- `src/presentation/world_view/stage_kit.gd:10` (`SHADOW_LIGHTS := 4`),
  `:184-215` (`_process` → `_pick_shadow_lights()` on `_frame % 15 == 1`)
- Omni shadows render per-light depth faces in Forward+ — among the most
  expensive things in the frame. Worse, *toggling* `shadow_enabled` forces the
  shadow atlas to rebuild those faces each time the set changes, ~4×/sec.
- **Do:** keep the 4-light budget, stabilize the set — re-pick every 60 frames
  instead of 15, and only swap a light when a challenger is meaningfully
  closer (hysteresis). The flame flicker (`light_energy`, same `_process`)
  doesn't touch shadows, so the warm look stays pixel-identical.

### 3. Directional shadow atlas at 8192 + PCF soft filter quality 4
- `project.godot` (`lights_and_shadows/directional_shadow/size=8192`,
  `directional_shadow/soft_shadow_filter_quality=4`);
  `src/presentation/world_view/stage_view.gd:228-250` (orthogonal sun, 80 m)
- An 8k depth atlas is ~256 MB VRAM and heavy shadow-pass bandwidth — mostly
  wasted texel density for a top-down iso camera. It was a deliberate choice
  for crisp edges (`evidence/SHADOWS.md`), so don't just change it.
- **Do:** A/B 4096 against the existing SHADOWS.md test renders with
  `SHADOW_BLUR := 0.5` unchanged. Iso cameras are forgiving; if edges stay
  straight, 4096 is a large, free win. If not, 8192 stays.

### 4. Ground tiles: hundreds of unique PlaneMeshes + nodes (new finding)
- `src/presentation/world_view/stage_view.gd:279-301` (`_build_room_ground`),
  `:253-266` (`_build_ground`)
- Every ground tile gets its **own `PlaneMesh.new()`** (allocated inside the
  loop) plus its own `MeshInstance3D` — a generated floor is hundreds of unique
  meshes and hundreds of draw calls for a flat checkerboard. (Arena mode
  reuses one shared plane but still one node per tile: ~100 nodes at
  `ARENA_HALF = 15`.)
- **Do:** share 2 PlaneMeshes (4×4 m) and scale nodes for clipped edge cells,
  or better: one MultiMeshInstance3D per checker color, or a single plane per
  room with the checker in a shader. Identical pixels, far fewer draw calls.

### 5. SSAO + SSIL always on at "high"
- `src/presentation/world_view/stage_view.gd:190-204` (`set_lighting`),
  `src/content/defs/biome_mood.gd` (ssao_radius 1.2, ssao_intensity 2.5,
  ssil on)
- Full-screen screen-space passes — the second-biggest GPU cost after shadows
  (estimate). But they *are* the "cool shadows vs warm light" look.
- **Do:** keep. The "low" lighting tier already drops both for slow GPUs.
  Only touch intensity if the owner-PC check still fails after 1–4.

### 6. MSAA 3D = 2×
- `project.godot` (`anti_aliasing/quality/msaa_3d=2`); window caps at 1600×900
  (`window_width_override`)
- Moderate constant cost on every 3D pass including glow downsamples.
- **Do:** A/B stills with MSAA 0 — the ink-outline pass
  (`src/presentation/world_view/ink_pass.gd`) already defines edges, so MSAA
  may be visually redundant. One reversible setting.

### 7. Glow: keep as-is
- `src/presentation/world_view/stage_view.gd:103-160`
- Already the minimal effective config for the signature look: threshold 1.0
  (only HDR emissives bloom — flames at energy 3), bloom 0.0, levels 2+4
  (+3,5 with spread). The pass cost is roughly fixed once enabled. Don't touch.

### 8. Two CPU micro-fixes (visual-neutral, nearly free)
- `src/presentation/world_view/horde_visuals.gd:65-67`: `Color("#FF2A22")`
  hex-parses **every frame** in `_process` — hoist to consts.
- `src/presentation/world_view/attack_forms/attack_form_view.gd:99`:
  `"%s|%s|%d" % [...]` formats a String per live projectile per tick
  (60 Hz; ~12–18k formats/sec at 200–300 bolts) just to key a ≤64-entry
  cache — hoist the `digest|tier` prefix once per `sync()`.

### Already well-optimized — do not "fix"
VFX/attack forms are MultiMesh-pooled with fixed caps (`vfx_core.gd`,
`attack_form_pool.gd`); 10 pooled VFX omni lights, none shadowed, merged
within 2.5 m; projectiles pooled per look (400 max); off-screen enemies skip
animation (24 m radius); no Godot physics bodies anywhere (fully data-driven
sim — zero physics-server cost); wand compiles at build time only, never per
tick; sync-on-tick / draw-on-frame split; textures VRAM-compressed with
mipmaps; hit-flash materials pre-built (no runtime shader recompiles).

### Suggested order of attack
1. Stabilize the 4 shadow omnis (hysteresis / 60-frame re-pick) — `stage_kit.gd`
2. A/B shadow atlas 8192 → 4096 — `project.godot` + SHADOWS.md renders
3. Ground tiles → shared meshes / MultiMesh — `stage_view.gd`
4. Run the pending owner-PC 60 fps check before touching anything else
5. The two micro-fixes (anytime — trivial, zero risk)
6. Only if still bound: MSAA 2× → 0 A/B, then SSAO/SSIL tuning, then —
   last resort — instanced enemy crowds

---

## Part 3 — Effect-by-effect lag audit (added 2026-10-19)

**The systemic finding:** the fire-patch fix (LIGHTING_PASS.md) gave `_fire`
merged lights (`_light_merged`, 2.5 m) — but the pattern was never applied to
the other five elements or the status visuals. **Every other effect requests
unmerged `_light`s.** Near-simultaneous effects (Twin pairs, chains, burning
hordes) each grab their own light instead of sharing one.

### Per-effect cost (density 1.0, per call — `vfx_layer.gd`)

| Effect | Instances | Light | Notes |
|---|---|---|---|
| Fire field | ≤16 flames (HDR) + embers + 1 smoke | merged ✓ | the fixed one |
| Fire ring / line | ≤24 flames | **unmerged** | rings/lines missed the fix |
| **Explosion** (fire burst) | 3 blast (HDR) + 4 debris + 5 smoke + 10 spark (HDR) = **22** | **unmerged, energy 7.0** | worst single-shot cost |
| Storm bolt | ≤6 ribbons (HDR) + 3 sparks (HDR) | **unmerged** per bolt | chains multiply it |
| Storm field | ≤10 bolts ≈ ≤60 ribbons + 30 sparks | **unmerged** | ribbon king |
| Storm ring / burst | ≤18 ribbons / 6 bolts | **unmerged** | |
| Frost field | ≤16 **crystals (3D geometry)** + 2 smoke + glints | **unmerged** | geometry, not sprites |
| Frost burst | ≤20 crystals + 10 sparks (HDR) | **unmerged, energy 4.0** | |
| Frost ring / line | ≤24 / ≤28 crystals | **unmerged** | ice pool cap 256 |
| Venom / bleed | ≤12 bubbles/splashes + smoke | **unmerged, energy ≤2.0** | cheapest; low energy, no HDR |
| Void field / ring / burst / line | ≤12–18 tendrils + rift (HDR 1.6–2.0) | **unmerged, energy ≤5.0** | moderate |
| **Burning enemy** (status, per frame) | ≤4 flames (HDR) + embers | **unmerged** | × every burning enemy |
| **Shocked enemy** (status, per frame) | 1 lightning ≈ 6 ribbons + 3 sparks | **unmerged** | × every shocked enemy |
| Frosted enemy (status, per frame) | ≤6 crystals | — | geometry × enemy count |

Decals are fine everywhere (overlapping marks dedupe, `vfx_core.gd:359`).

### The laggy combos, ranked
1. **Burn/shock statuses over a horde** — the worst *sustained* case, worse
   than the user's burst case: `status_visuals.gd:290` draws statuses for every
   affected enemy every frame. 40 burning enemies = 40 unmerged light wants +
   ~200 HDR sprites/frame against a 10-light pool. A Wildfire/Flame Trail
   build in a horde is the most likely real-world trigger of the reported lag.
2. **Twin + Explosive + fast fire** (reported) — 22 instances + 1 unmerged
   7-energy light per detonation, ×2–3 projectiles × fire rate ≈ 8–12
   detonations/sec into ~200 instances/sec and a saturated light pool.
3. **Lightning + chains + Twin** — each chained hit is a full `_lightning`
   with its own unmerged light; chains × projectiles × fire rate.
4. **Frost fields/rings over hordes** — 16–28 real crystal meshes per cast;
   the only effect that spends geometry instead of sprites.

### Fixes (visual-preserving)
1. **Extend `_light_merged` to every effect** — explosion, storm bursts/rings/
   fields, frost bursts, void bursts, fire rings/lines, and status lights
   (merge radius 2–3 m). This is the fire-patch pattern, just finished. One
   brighter light vs several dim ones is visually near-identical where they
   overlap — which is exactly when it triggers.
2. **Budget status lights** — burning/shocked enemies are the unbounded term
   (scales with horde size). Merge within 2–3 m and/or let only the N
   brightest status lights request pool slots. A burning horde already reads
   as one glow; merged is arguably more correct.
3. **Pressure-based particle thinning** — pools past ~70%: halve debris/smoke/
   spark/crystal counts per effect, keep blast + flash. The `density` pref is
   the manual version; this makes the caps graceful instead of cliff-edged.
4. Leave decals, glow, and all damage numbers alone — none of them are the
   bottleneck, and the combo feel stays intact.
