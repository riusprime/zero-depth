class_name NativeAi
extends RefCounted
## The enemies' thinking (tick phase 3) and steering (phase 5) run by the native side (World.native, NativeWorld.AI):
## ZdWorld.think and ZdWorld.move, for every row whose kind the per-kind table runs (NativeKindTable: NATIVE and
## HOOKED kinds). The rules are EnemyAi's and CritterAi's: the walk plan on its staggered ticks, the state machine,
## the aim and turning, the walk and the charge. Each call hands back intents, ascending by row and then by code, for
## what needs a random draw (every draw stays on the sim's named streams, here) or a GDScript rule; they are applied
## below in that order. The rows the table leaves to GDScript (bosses, elites, the signatures that run their own, eggs,
## dummies: ZdWorld.rows_for_script) think and move as before, after the native call in phase 3 and before it in
## phase 5. So the order changes against the GDScript path (the table rows think first, then the others), and the
## arithmetic is single precision: a world hashes differently with it on, and the same on every run (NATIVE_CORE.md
## §2, L16). The native side keeps nothing between calls, so a snapshot restores exactly.
## No local here holds a store column across a native call: each read goes through the store again.

## The intents (zd_ai.h Intent), in the order a row's intents come.
enum Intent {
	FLOW = 1,  # a plan the walls block: the flow field's way, at the plan's length (f0)
	THINK_TICK = 2,  # Variants.on_think (the Rubble Warden's crust)
	MOVE_TICK = 3,  # the Mender heals instead of attacking
	WINDUP_START = 4,  # an attack began: its length drawn, and the kind's extras (the spell, the star)
	WINDUP_END = 5,  # the Star Warper's windup ran out: the hero on the star cancels the blink
	RELOCATE = 6,  # a Sniper's recovery ended: its next spot is drawn
	CHARGE_STEP = 7,  # a charge with a trail stepped (Variants.on_charge_step)
	RELOCATE_STEP = 8,  # a relocating Sniper's walk (EnemyAi.move), while the flow field is GDScript's
}
const STRIDE := 4
## The hero as the kernels read it (zd_ai.h Hero): x, y, velocity x, y, radius, dead, dashing, the dash's landing x, y.
const HERO_SIZE := 9


## Whether the native side can run the enemy kernels for world w now (its caches sent first). False leaves the
## phase to GDScript.
static func ready(w: World) -> bool:
	var m: Object = w.native
	if m == null or not m.has_trig():
		return false
	NativeWorld.sync_walls(w)
	NativeWorld.sync_kinds(w)
	return m.kind_count() == NativeKindTable.kind_count()


static func hero_of(w: World) -> PackedFloat32Array:
	var p := w.player_pos()
	var land := BossChallenge.dash_landing(w) if w.is_dashing() else p
	return PackedFloat32Array(
		[
			p.x,
			p.y,
			w.vel.x,
			w.vel.y,
			w.player.radius_m,
			1.0 if w.player_dead() else 0.0,
			1.0 if w.is_dashing() else 0.0,
			land.x,
			land.y
		]
	)


## The flow field is the native nav grid's only once the nav kernel keeps it (NativeWorld.NAV); else GDScript's.
static func flow_native(w: World) -> bool:
	return (w.native_on & NativeWorld.NAV) != 0 and w.native.has_nav()


# --- Phase 3 ---------------------------------------------------------------------------------------------------
## The enemies' thinking: the native rows, their intents, then the script rows. False when the native side refused
## (nothing changed: the caller runs the GDScript phase).
static func think(w: World) -> bool:
	if not ready(w):
		return false
	var a := w.actors
	var held := PackedByteArray()  # A spell's stun, a byte a row (none while no spell holds anyone)
	if not w.spell_hold_id.is_empty():
		held.resize(a.size())
		for id in w.spell_hold_id:
			var i := a.index_of(id)
			if i >= 0 and Spells.held_still(w, i):
				held[i] = 1
	var m: Object = w.native
	var pp := w.phase_probe
	if pp != null:
		pp.begin(&"ai.native")
	var n: int = m.think(a, hero_of(w), w.tick, held, w.mines.owner, flow_native(w))
	if pp != null:
		pp.end(&"ai.native")
	if n < 0:
		push_error("NativeAi: the native side refused think")
		return false
	if n > 0:
		_apply_think(w, m.ai_intents_i(), m.ai_intents_f())
	_script_think(w, m.rows_for_script(a))
	return true


static func _apply_think(w: World, ii: PackedInt32Array, ff: PackedFloat32Array) -> void:
	var a := w.actors
	for k in range(0, ii.size(), STRIDE):
		var i := ii[k + 1]
		match ii[k]:
			Intent.FLOW:
				var flow := w.nav.direction(a.pos(i))
				if flow != Vector2.ZERO:
					var dir := flow * ff[k]
					a.plan_x[i] = dir.x
					a.plan_y[i] = dir.y
			Intent.THINK_TICK:
				Variants.on_think(w, i)
			Intent.MOVE_TICK:
				EnemyAi._mend(w, i)
			Intent.WINDUP_START:
				_windup_start(w, i)
			Intent.WINDUP_END:
				if not StarfallKinds.cancel(w, i):
					EnemyAi.enter_state(a, i, EnemyAi.State.ACTIVE)
					a.fire_cd[i] = 0
			Intent.RELOCATE:
				EnemyAi._plan_relocation(w, i)


## EnemyAi._start_windup's draws and extras (the native side set the rest): the windup's length, the Arc Caster's
## spell (its rune's windup and lock on the hero, or its aim), the Star Warper's star.
static func _windup_start(w: World, i: int) -> void:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	if t.windup_max_ticks > t.windup_ticks:
		a.windup[i] = w.rng_enemy.range_int(t.windup_ticks, t.windup_max_ticks)
	match EnemyAi.behaviour_of(a.kinds[i]):
		ActorStore.Kind.STAR_WARPER:
			var star := StarfallKinds.mark_spot(w, i)
			a.lock_x[i] = star.x
			a.lock_y[i] = star.y
		ActorStore.Kind.ARC_CASTER:
			a.pick[i] = maxi(0, w.rng_enemy.pick_weighted(t.spell_weights))
			if a.pick[i] == EnemyAi.Spell.RUNE:
				a.windup[i] = t.rune_windup_ticks
				a.lock_x[i] = w.player_pos().x
				a.lock_y[i] = w.player_pos().y
			else:
				EnemyAi._aim(w, i)


## The rows GDScript runs, as World._run_ai does (the critters in one loop after them).
static func _script_think(w: World, rows: PackedInt32Array) -> void:
	var a := w.actors
	var critters := PackedInt32Array()
	var target := w.player_pos()
	for i in rows:
		match EnemyAi.role_of(a.kinds[i]):
			EnemyAi.Role.CRITTER:
				critters.append(i)
			EnemyAi.Role.BOSS:
				BossAi.think(w, i)
			EnemyAi.Role.ENEMY:
				EnemyAi.think(w, i)
			_:
				if a.kinds[i] == ActorStore.Kind.DUMMY:
					w.dummy_think(i, target)
	if not critters.is_empty():
		CritterAi.think_all(w, critters)


# --- Phase 5 ---------------------------------------------------------------------------------------------------
## The enemies' steering, after the hero's step and before the collision passes: the script rows as World does,
## then the native rows and their intents. False when the native side refused (the caller runs the GDScript steer).
static func move(w: World) -> bool:
	if not ready(w):
		return false
	var a := w.actors
	var m: Object = w.native
	var target := w.player_pos()
	var critters := PackedInt32Array()
	for i in m.rows_for_script(a):
		match EnemyAi.role_of(a.kinds[i]):
			EnemyAi.Role.CRITTER:
				critters.append(i)
			EnemyAi.Role.BOSS:
				BossAi.move(w, i)
			EnemyAi.Role.ENEMY:
				EnemyAi.move(w, i)
			_:
				w.dummy_steer(i, target)
	if not critters.is_empty():
		CritterAi.move_all(w, critters)
	# ItemProcs.slow_factor as a column, only while a pair or a spell could change it (else the native side reads
	# the freeze and the slow itself)
	var slow := PackedFloat32Array()
	if w.pair_mask != 0 or not w.spell_hold_id.is_empty():
		slow.resize(a.size())
		for i in a.size():
			slow[i] = ItemProcs.slow_factor(w, i)
	var n: int = m.move(a, hero_of(w), slow, float(w.item_mods.slow_permille), flow_native(w))
	if n < 0:
		push_error("NativeAi: the native side refused move")
		return true  # The script rows have moved: the table rows stand this tick
	if n == 0:
		return true
	var ii: PackedInt32Array = m.ai_intents_i()
	for k in range(0, ii.size(), STRIDE):
		var i := ii[k + 1]
		match ii[k]:
			Intent.CHARGE_STEP:
				Variants.on_charge_step(w, i, w.enemy_table(a.kinds[i]))
			Intent.RELOCATE_STEP:
				EnemyAi.move(w, i)
	return true
