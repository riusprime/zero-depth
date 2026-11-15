class_name BossGlass
extends RefCounted
## The Hive Lens's burnt glass (BossLensTable.strip_*; BossFightStore.hl_s_*, hl_strip_at), run by BossLens: from
## strip_phase, on the last tick a Focus Beam burns, the far strip_len_m of each of its lanes (all of a shorter lane)
## stays as a strip strip_half_m each side of the lane's line for strip_ticks. At most strip_max lie at once: a new one
## past it takes the oldest's place. The hero touching any strip loses strip_damage HP (the boss's power applies) once
## every strip_step_ticks, as a step of damage over time (the hurt invulnerability neither swallows a step nor is
## given by one: SafeArea's STEP). Pure: no stream is drawn.

## STATUS_APPLY effects (source the boss). LAID: a strip was laid (pos = its centre, amount = its ticks, target = 0).
## GONE: a strip went (pos = its centre).
const LAID := &"lens_glass_laid"
const GONE := &"lens_glass_gone"
## The damage effect id of the glass.
const EFFECT := &"lens_glass"


## BossLens.advance: boss i's Focus Beam on its last burning tick lays its strips (in `phase`, from strip_phase).
static func lay(w: World, i: int, f: BossLensTable, phase: int) -> void:
	if phase < f.strip_phase or not BossLens.burning(w, i, f):
		return
	var atk := BossAi.attack_of(w, i)
	if w.actors.state_t[i] != atk.active_ticks - 1:
		return
	var fs := w.boss_fight
	for k in atk.count:
		var o := BossAi.lane_of(w, i, k)
		var whole := o.half.x * 2.0
		var length := minf(f.strip_len_m, whole)
		var start := o.center + o.axis_u * (o.half.x - length)
		while fs.hl_s_x.size() >= f.strip_max:
			_remove(w, i, 0)
		fs.hl_s_from.append(w.tick)
		fs.hl_s_until.append(w.tick + f.strip_ticks)
		fs.hl_s_a.append(o.angle)
		fs.hl_s_x.append(start.x)
		fs.hl_s_y.append(start.y)
		fs.hl_s_len.append(length)
		BossLens.event(w, i, LAID, strip(fs, fs.hl_s_x.size() - 1, f).center).amount = f.strip_ticks


## Strip k as a box (its line strip_half_m each side).
static func strip(fs: BossFightStore, k: int, f: BossLensTable) -> Obb:
	return AttackShapes.lane(
		Vector2(fs.hl_s_x[k], fs.hl_s_y[k]),
		fs.hl_s_a[k],
		maxf(fs.hl_s_len[k], 0.01),
		f.strip_half_m
	)


## BossLens.advance: old strips go; the hero touching one pays its step.
static func advance(w: World, i: int, f: BossLensTable) -> void:
	var fs := w.boss_fight
	var k := 0
	while k < fs.hl_s_x.size():
		if w.tick >= fs.hl_s_until[k]:
			_remove(w, i, k)
		else:
			k += 1
	if fs.hl_s_x.is_empty() or w.player_dead() or w.tick < fs.hl_strip_at:
		return
	if under(w, f, w.player_pos(), w.player.radius_m) < 0:
		return
	fs.hl_strip_at = w.tick + f.strip_step_ticks
	_step(w, i, BossAi.powered(w, i, f.strip_damage), f.strip_cause)


## The first strip a body of radius r at p touches, or -1.
static func under(w: World, f: BossLensTable, p: Vector2, r: float) -> int:
	var fs := w.boss_fight
	for k in fs.hl_s_x.size():
		if Collide.circle_vs_obb(p, r, strip(fs, k, f)) != Vector2.ZERO:
			return k
	return -1


## One step of `amount` HP to the hero (a step of damage over time, as SafeArea's STEP, but a flat amount).
static func _step(w: World, i: int, amount: int, cause: int) -> void:
	var id := w.actors.ids[i]
	var shield := w.actors.invuln[0]
	w.actors.invuln[0] = 0
	Damage.tick_dot(w, 0, amount, id, id, EFFECT)
	if not w.player_dead():
		w.actors.invuln[0] = shield
	elif w.killer_attack < 0:
		w.killer_attack = cause


static func _remove(w: World, i: int, k: int) -> void:
	var fs := w.boss_fight
	var f := BossAi.table_of(w, i).lens if i >= 0 else null
	if f != null:
		BossLens.event(w, i, GONE, strip(fs, k, f).center)
	fs.remove_glass(k)


## The glass goes (the hero dead or out of the room).
static func clear(w: World, i: int) -> void:
	while not w.boss_fight.hl_s_x.is_empty():
		_remove(w, i, 0)
	w.boss_fight.hl_strip_at = 0


## The view's read (BossLens.state's "glass"): [{"from", "to" (the line's ends), "half_width", "left" (ticks until it
## goes), "progress" (0..1000 of its life)}].
static func rows(w: World, f: BossLensTable) -> Array[Dictionary]:
	var fs := w.boss_fight
	var out: Array[Dictionary] = []
	for k in fs.hl_s_x.size():
		var o := strip(fs, k, f)
		var life := maxi(1, fs.hl_s_until[k] - fs.hl_s_from[k])
		(
			out
			. append(
				{
					"from": o.center - o.axis_u * o.half.x,
					"to": o.center + o.axis_u * o.half.x,
					"half_width": f.strip_half_m,
					"left": maxi(0, fs.hl_s_until[k] - w.tick),
					"progress": clampi((w.tick - fs.hl_s_from[k]) * 1000 / life, 0, 1000),
				}
			)
		)
	return out
