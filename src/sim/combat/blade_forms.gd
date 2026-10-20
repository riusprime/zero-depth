class_name BladeForms
extends RefCounted
## v0.6.5 WN4 (docs/design/WAND.md, the Blade pool B1–B16; owner W5: "the slash becomes a spell"): what the Blade's
## cards need from the runner beyond the shared forms, read from the compiled specs (AttackSpec's WN4 fields) and kept
## in World.blade (BladeState). Every function draws no randomness (EI-05), uses no trig and runs on the one clock.
##
## - The swing itself (step): a step whose spec changes the motion (Thrust's stab, Whirl's spin), the swing speed
##   (rate_bonus_permille: Flurry faster, Heavy slower; the whole swing's ticks scale, its hit tick too) or steps the
##   player forward (step_m: Lunge Step) swings as a copy of its SwingStep with those changes; PlayerKit and the views
##   read that copy, so what you see is what hits.
## - Hits: a landed arc hit with knockback_m pushes the enemy away over the table's knock_ticks (Heavy; not a boss).
## - Parry Edge (parry): the arc cuts every enemy shot it touches when it hits, and through the rest of the swing.
## - Fissure (line_m): a burst with a length is a line from where it fires along its angle, hitting every enemy within
##   its radius of the line (its crack waits in the launch queue first: the hook's delay).
## - Orbit Blades (an ORBITER with orbit_ticks): the blade circles the player for orbit_ticks, hitting what it touches,
##   then rests the table's orbit_gap; at most orbit_max blades (the oldest leaves).
## The runner numbers no card's ops name are World.blade_table (BladeTable, data/wand/blade_forms.tres).
## - Counter (counter_ticks): a slash within counter_ticks of a dash's end deals × counter_permille, once per dash, and
##   its WHEN_COUNTER hooks (the dash-slash wave) fire on that tick only.
## - Finisher+ (carry): after the compile, a hook child with carry takes its slash's statuses, elements and hit hooks
##   (Modifiers.inherit), so the shockwave carries every card.
## - Whirl then Wave (hook_base): a flying slash thrown by a full-circle arc flies as a ring of CRESCENT_RING crescents.
## - The view's marks (fx): the slashes nobody's blade draws (a ghost: Afterimage's copy, a Double Slash's mirrored
##   echo, a trigger's or a back copy's slash), the fissure's eruption, the sparks of a cut shot, a counter's flash.

const FX_ARC := 0
const FX_ARC_MIRROR := 1
const FX_LINE := 2
const FX_PARRY := 3
const FX_BURST := 4
const FX_COUNTER := 5
## The view's marks kept (newest last) and for how long (ticks).
const FX_MAX := 24
const FX_TICKS := 40
## A spinning slash's flying copy: this many crescents round the player (a shape rule, read at compile time).
const CRESCENT_RING := 4
## The runner numbers of a world without World.blade_table (a lab): BladeTable's defaults, which mirror
## data/wand/blade_forms.tres (Orbit Blades' count, turn and rest, Heavy's push, Lunge Step's stride, the slowest
## swing).
static var _defaults := BladeTable.new()


## The runner numbers (data/wand/blade_forms.tres; a lab world: the defaults).
static func table(w: World) -> BladeTable:
	return w.blade_table if w.blade_table != null else _defaults


# --- Compile time ---------------------------------------------------------------------------------------------
## A hook child `c` of `parent` (WandCompile._hook, after SpecForms.hook_base): a bolt off a full-circle arc flies as
## a ring of crescents (Whirl then Wave; Wave then Whirl keeps its one crescent: the order matters).
static func hook_base(c: AttackSpec, parent: AttackSpec) -> void:
	if (
		c.form == AttackSpec.Form.BOLT
		and parent.form == AttackSpec.Form.ARC
		and parent.directions == AttackSpec.DIR_CIRCLE
	):
		c.directions = AttackSpec.DIR_CIRCLE
		c.count = maxi(c.count, CRESCENT_RING)
		c.half_arc = SpecForms.HALF_ARC


## A compiled combo step: its carry children (Finisher+'s shockwave) take the slash's payload. Returns `s`.
static func settle(s: AttackSpec) -> AttackSpec:
	for k in s.hooks:
		if k.child.carry > 0:
			Modifiers.inherit(k.child, s, false)
	return s


# --- The swing ------------------------------------------------------------------------------------------------
## Combo step `k` as it swings now: the player table's, or a copy changed by its spec (class doc).
static func step(w: World, k: int) -> SwingStep:
	var base: SwingStep = w.player.combo[k]
	var s := Modifiers.step(w, k)
	var burst := 0 if s == null else FireRhythm.swing_bonus(w, s)  # v0.8.0 MR (O91): Flurry's burst
	if s == null or (s.motion < 0 and s.rate_bonus_permille + burst == 0 and s.step_m <= 0.0):
		return base
	var t := table(w)
	var rate := maxi(t.rate_min, 1000 + s.rate_bonus_permille + burst)
	var out := SwingStep.new()
	out.motion = base.motion if s.motion < 0 else (s.motion as SwingStep.Motion)
	out.active_tick = maxi(1, _scaled(base.active_tick, rate))
	out.ticks = maxi(out.active_tick + 1, _scaled(base.ticks, rate))
	out.sweep_ticks = maxi(1, _scaled(base.sweep_ticks, rate))
	out.half_arc = base.half_arc
	out.reach_m = base.reach_m
	out.damage = base.damage
	out.hitstop_ticks = base.hitstop_ticks
	out.lunge_m = base.lunge_m + s.step_m
	if s.step_m > 0.0:
		out.lunge_over = maxi(out.active_tick - 1, t.lunge_ticks)
	return out


static func _scaled(ticks: int, rate: int) -> int:
	return (ticks * 1000 + rate / 2) / rate


# --- Counter --------------------------------------------------------------------------------------------------
## The dash just ended (ModifierRuntime.on_dash_end): Counter's window opens, on a build with a counter.
static func on_dash_end(w: World) -> void:
	if w.player.combo.is_empty() or not PlayerBuild.has_blade(w):
		return
	if Modifiers.step(w, 0).counter_ticks > 0:
		w.blade.dash_end = w.tick


## The swing's damage `dmg` of step spec `spec`: × counter_permille when it counters (the window closes).
static func counter_damage(w: World, spec: AttackSpec, dmg: int) -> int:
	var b := w.blade
	if spec.counter_ticks <= 0 or b.dash_end < 0 or w.tick - b.dash_end > spec.counter_ticks:
		return dmg
	b.counter_tick = w.tick
	b.dash_end = -1
	_fx(w, FX_COUNTER, w.player_pos(), w.swing_angle, 0.0, 0.0)
	return maxi(1, dmg * spec.counter_permille / 1000)


## A slash countered this tick (Attacks.run_hook's WHEN_COUNTER).
static func countering(w: World) -> bool:
	return w.blade.counter_tick >= 0 and w.blade.counter_tick == w.tick


# --- Arcs -----------------------------------------------------------------------------------------------------
## Arc `spec` landed a hit on actor `i` (Attacks._arc): Heavy's push.
static func on_arc_hit(w: World, spec: AttackSpec, ctx: AttackContext, i: int) -> void:
	if spec.knockback_m > 0.0:
		_knock(w, i, ctx.origin, spec.knockback_m)


## Arc `spec` resolved (Attacks._arc, after its hits): Parry Edge cuts, and a slash no blade draws leaves its mark.
static func on_arc(w: World, spec: AttackSpec, ctx: AttackContext) -> void:
	if spec.parry > 0:
		parry(w, spec, ctx.origin, ctx.angle)
	if spec.has_tag(&"skill"):
		return
	var echo := ctx.effect_id == ItemEffects.EFFECT_TWIN_ARC
	var own := ctx.depth == 0 and ctx.step >= 0 and ctx.effect_id == &"" and not ctx.back
	if own and not ctx.repeat:
		return  # the swing itself: KitView's blade draws it
	if echo and spec.echo_mirror <= 0:
		return  # Twin Arc's echo keeps its own look (ItemVisuals)
	var kind := FX_ARC_MIRROR if echo else FX_ARC
	_fx(w, kind, ctx.origin, ctx.angle, float(spec.half_arc), Attacks.arc_reach_m(w, spec))


## Twin: PlayerSkill._knock / push (Scatter Blast's push, KitState.knock_*). Kept apart on purpose (audit G-13):
## merging moves Scatter Blast's push from tick phase 5 to 6 and changes the hash layout. Differences: this one
## stores metres per tick per entry (k_step), never appends a dead target, and _advance_knock rejects a gone actor
## with i > 0 (the same as PlayerSkill's i >= 0: index 0 is always the player, never a knocked enemy).
static func _knock(w: World, i: int, from: Vector2, metres: float) -> void:
	var a := w.actors
	var b := w.blade
	if a.dead[i] == 1 or BossAi.is_boss_kind(a.kinds[i]) or b.k_ids.has(a.ids[i]):
		return
	var away := a.pos(i) - from
	var len := Kin.length(away)
	b.k_ids.append(a.ids[i])
	b.k_dirs.append(away / len if len > 0.0 else Kin.dir(w.swing_angle))
	var n := table(w).knock_ticks
	b.k_step.append(metres / n)
	b.k_left.append(n)


## Every enemy shot touching arc `spec` from `center` facing `angle` is cut (removed; a spark where it was).
static func parry(w: World, spec: AttackSpec, center: Vector2, angle: int) -> void:
	var p := w.projectiles
	var cut := PackedInt32Array()
	for i in p.size():
		if p.team[i] == ActorStore.TEAM_PLAYER:
			continue
		var at := Vector2(p.pos_x[i], p.pos_y[i])
		if Attacks.arc_touches(w, spec, center, angle, at, p.radius[i]):
			cut.append(i)
	if cut.is_empty():
		return
	for i in cut:
		_fx(w, FX_PARRY, Vector2(p.pos_x[i], p.pos_y[i]), angle, p.radius[i], 0.0)
	w.blade.parried += cut.size()
	p.remove_sorted(cut)


## A burst of `spec` from `at`, radius `r` (Attacks._burst): a carrying shockwave (Finisher+) leaves the view's mark.
static func on_burst(w: World, spec: AttackSpec, at: Vector2, r: float) -> void:
	if spec.carry > 0:
		_fx(w, FX_BURST, at, 0, r, 0.0)


# --- Fissure and Orbit Blades (Attacks' BURST and ORBITER runners hand these over) ---------------------------------
## Burst `spec` with a length: a line from ctx.origin along ctx.angle, line_m long, radius_m wide. Its ON_END hooks
## fire at the line's far end. True if it landed a hit.
static func line(w: World, spec: AttackSpec, ctx: AttackContext) -> bool:
	var a := w.actors
	var from := ctx.origin
	var to := from + Kin.dir(ctx.angle) * spec.line_m
	var landed := false
	for i in range(1, a.size()):
		if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1:
			continue
		if Collide.sweep_vs_circle(from, to, spec.radius_m, a.pos(i), a.radius[i]) < 0.0:
			continue
		landed = Attacks.land(w, spec, ctx, i, from, a.pos(i)) > 0 or landed
	_fx(w, FX_LINE, from, ctx.angle, spec.line_m, spec.radius_m)
	Attacks.run_on_end(w, spec, ctx, to)
	return landed


## Orbiter `spec` with orbit_ticks: one blade starts circling the player (class doc).
static func orbit(w: World, spec: AttackSpec, ctx: AttackContext) -> bool:
	var b := w.blade
	if b.o_key.size() >= table(w).orbit_max:
		b.remove_orbit(0)
	b.o_key.append(spec.key)
	b.o_start.append(w.tick)
	b.o_end.append(w.tick + spec.orbit_ticks)
	b.o_phase.append(ctx.angle)
	b.o_damage.append(ctx.damage)
	b.o_root.append(ctx.root)
	b.o_depth.append(ctx.depth)
	b.o_proc.append(ctx.proc_pct)
	b.o_reach.append(spec.reach_m if spec.reach_m > 0.0 else 1.5)
	b.o_radius.append(spec.radius_m if spec.radius_m > 0.0 else Abilities.BLADE_R)
	b.o_ready.append(w.tick)
	return false


## Blade `j`'s position now.
static func blade_pos(w: World, j: int) -> Vector2:
	var b := w.blade
	var ang := (b.o_phase[j] + (w.tick - b.o_start[j]) * table(w).orbit_turn) & 4095
	return w.player_pos() + Kin.dir(ang) * b.o_reach[j]


# --- Each tick (ModifierRuntime.advance, phase 6) ---------------------------------------------------------------
static func advance(w: World) -> void:
	_parry_swing(w)
	var b := w.blade
	if b.k_ids.is_empty() and b.o_key.is_empty() and b.fx_kind.is_empty():
		return
	_advance_knock(w)
	_advance_orbit(w)
	while not b.fx_tick.is_empty() and w.tick - b.fx_tick[0] > FX_TICKS:
		b.remove_fx(0)


## Parry Edge keeps cutting through the rest of the swing (from its hit tick on).
static func _parry_swing(w: World) -> void:
	if w.swing_t <= 0 or w.player.combo.is_empty() or not PlayerBuild.has_blade(w):
		return
	var spec := Modifiers.step(w, w.combo_step)
	if spec.parry > 0 and w.swing_t >= PlayerKit.current_step(w).active_tick:
		parry(w, spec, w.player_pos(), w.swing_angle)


static func _advance_knock(w: World) -> void:
	var b := w.blade
	for j in range(b.k_ids.size() - 1, -1, -1):
		var i := w.actors.index_of(b.k_ids[j])
		if i > 0 and w.actors.dead[i] == 0:
			w.actors.set_pos(i, w.actors.pos(i) + b.k_dirs[j] * b.k_step[j])
			b.k_left[j] -= 1
		else:
			b.k_left[j] = 0
		if b.k_left[j] <= 0:
			b.remove_knock(j)


static func _advance_orbit(w: World) -> void:
	var b := w.blade
	var a := w.actors
	var j := 0
	while j < b.o_key.size():
		var spec := Modifiers.book(w).find(b.o_key[j])
		if spec == null or w.tick >= b.o_end[j] or w.player_dead():
			b.remove_orbit(j)
			continue
		if w.tick >= b.o_ready[j]:
			var at := blade_pos(w, j)
			var r := b.o_radius[j]
			for i in w.enemies_near(at, r + 1.0):
				if not AttackShapes.disc_touches(at, r, a.pos(i), a.radius[i]):
					continue
				var ctx := AttackContext.make(
					at,
					b.o_phase[j],
					b.o_damage[j],
					b.o_root[j],
					Attacks.lingering_tags(spec),
					spec.effect_id
				)
				ctx.depth = b.o_depth[j]
				ctx.proc_pct = b.o_proc[j]
				if Attacks.land(w, spec, ctx, i, at, a.pos(i)) > 0:
					b.o_ready[j] = w.tick + table(w).orbit_gap
					break
		j += 1


# --- The view's marks, reads, hash --------------------------------------------------------------------------------
static func _fx(w: World, kind: int, at: Vector2, angle: int, p_a: float, p_b: float) -> void:
	var b := w.blade
	if b.fx_kind.size() >= FX_MAX:
		b.remove_fx(0)
	b.fx_kind.append(kind)
	b.fx_tick.append(w.tick)
	b.fx_pos.append(at)
	b.fx_angle.append(angle)
	b.fx_a.append(p_a)
	b.fx_b.append(p_b)


## What the views draw (WorldReader.blade_forms): the marks ({kind, tick, pos, angle, a, b}), the orbiting blades'
## positions, the fissure cracks waiting to erupt ({pos, angle, length, width, left}: ticks left), the shots cut so far,
## the last counter's tick and how many enemies are being pushed.
static func read(w: World) -> Dictionary:
	var b := w.blade
	var fx := []
	for k in b.fx_kind.size():
		(
			fx
			. append(
				{
					"kind": b.fx_kind[k],
					"tick": b.fx_tick[k],
					"pos": b.fx_pos[k],
					"angle": b.fx_angle[k],
					"a": b.fx_a[k],
					"b": b.fx_b[k],
				}
			)
		)
	var blades := PackedVector2Array()
	for j in b.o_key.size():
		blades.append(blade_pos(w, j))
	var cracks := []
	var q := w.mx
	for k in q.q_key.size():
		var s := Modifiers.book(w).find(q.q_key[k])
		if s != null and s.line_m > 0.0:
			(
				cracks
				. append(
					{
						"pos": q.q_pos[k],
						"angle": q.q_angle[k],
						"length": s.line_m,
						"width": s.radius_m,
						"left": q.q_tick[k] - w.tick,
					}
				)
			)
	return {
		"fx": fx,
		"blades": blades,
		"cracks": cracks,
		"parried": b.parried,
		"counter_tick": b.counter_tick,
		"knocked": b.k_ids.size(),
	}


## The current combo step's swing as its cards change it: the damage weight (× 1), the swing speed bonus (per mille),
## and whether it lunges forward, knocks back or parries.
static func swing_read(w: World) -> Dictionary:
	if w.player.combo.is_empty() or not PlayerBuild.has_blade(w):
		return {"weight": 1.0, "rate": 0, "lunge": false, "knockback": false, "parry": false}
	var s := Modifiers.step(w, clampi(w.combo_step, 0, w.player.combo.size() - 1))
	return {
		"weight": s.damage_mul_permille / 1000.0,
		"rate": s.rate_bonus_permille,
		"lunge": s.step_m > 0.0,
		"knockback": s.knockback_m > 0.0,
		"parry": s.parry > 0,
	}


## Hashed once touched (ModifierRuntime.hash_into, inside Modifiers.hash_into: a build with a modifier).
static func hash_into(w: World, h: StateHasher) -> void:
	if w.blade.touched():
		w.blade.hash_into(h)
