class_name HitFeel
extends Node3D
## Hit feel from the event log (PRESENTATION §6): a white flash on whoever took damage, a camera shake when you're
## hit, a spark where a hit was guarded, a dull grey spark off a Warden's armoured front, a bright one on its weak
## spot behind, and a pop of shards when an enemy dies. The combo's finisher hits harder: a longer
## flash on each enemy it lands on, a bright spark and a small camera shake (none when shake is off).
## The sim's hit-stop is already in the tick (freeze_ticks); nothing here changes an outcome.
## Bosses: a dull grey-blue spark when the ranged armour deflects most of a far hit, a big gold one on
## the open weak point.
## Each of the player's hits on an enemy also throws an impact (ImpactFx: a flash and sparks
## where it hit, a spray out of the far side along the hit) and flinches the enemy's model away from the hit
## (AvatarBase.flinch for the normal kinds, BossAvatar.flinch's clip for the bosses: a pose only, the sim body never
## moves), on top of the white flash.
## A Blade hit's impact is a cut along the slash with sparks along it (ImpactFx), its flinch is
## stronger and knocks the pose away from the swing, and it starts the view's hit-stop (HitStop: the hero's swing and
## the struck enemies held about 2 frames, shared by one swing's hits, rate-limited; a tiny camera kick). In the view
## only: the sim's own hit-stop above is unchanged and the sim never reads this one.

const SHARDS := 7
const FINISHER_SHAKE := 0.3
const FINISHER_FLASH_MULT := 2
## A hit a boss's ranged armour deflected: a dull, small, grey-blue spark.
const DEFLECT_COLOR := Color(0.42, 0.46, 0.52)
## The guard, block, deflect, weak-spot, armour and finisher sparks are the pack's hit scenes
## (false: the old box bursts; a full family throws the boxes for that spark). v0.10.0 FX (owner, 2026-10-31: "enemies
## explode when killed ... smoke remains 4-5 seconds"): a dead enemy's pop is the lit chunks alone again, as before VX1.
const PACK_SPARKS := true
const SPARK_HEIGHT := 0.4
## The pack scenes' scale for each spark (a metre across at 1).
const SCALE_GUARD := 0.3
const SCALE_DEFLECT := 0.25
const SCALE_WEAK := 0.4
const SCALE_EXPOSED := 0.5
const SCALE_ARMOUR := 0.22
const SCALE_FINISHER := 0.4
## ENEMIES.md H3: the spark a dead Ember Flea leaves (no damage, just a look).
const FLEA_SPARK := Color(1.0, 0.62, 0.2)

var actors: ActorViews
var rig: IsoRig
## The impacts (drawn into the effects layer: WorldViewRoot adds impacts.draw to its drawers).
var impacts := ImpactFx.new()
## Flinches started (tests).
var flinches := 0
## The view's hit-stop (WorldViewRoot hands it the blade view, KitView, as `hit_stop.kit`).
var hit_stop := HitStop.new()
## The pack's effects (WorldViewRoot hands it over); none: the box bursts.
var pack_fx: PackFx = null
## A count of the swings seen (one swing's hits share one freeze), and the last sync's swing tick / step.
var _swing_serial := 0
var _last_swing_t := 0
var _last_step := -1
var _last_seq := 0
var _rng := RandomNumberGenerator.new()
## The Ember Fleas alive at the last sync (by actor id), so their KILL can spark after they are gone.
var _fleas := {}
## One pool of flying cubes per look, made on its first use and kept for the view's life.
var _pools := {}


func _init(p_actors: ActorViews, p_rig: IsoRig) -> void:
	actors = p_actors
	rig = p_rig
	hit_stop.actors = p_actors
	hit_stop.rig = p_rig
	_rng.seed = 1  # the cosmetic stream: presentation only, never feeds the sim (EI-05)


func sync(reader: WorldReader) -> void:
	var player_id := reader.actor_id(0)
	var shook := false
	var st := reader.swing_tick()
	if st > 0 and (_last_swing_t == 0 or st < _last_swing_t or reader.combo_step() != _last_step):
		_swing_serial += 1
	_last_swing_t = st
	_last_step = reader.combo_step()
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		match e.kind:
			SimEvent.Kind.DAMAGE:
				if finisher_hit(reader, e):
					actors.flash(e.target_id, actors.flash_frames * FINISHER_FLASH_MULT)
					_spark(HitPack.GUARD, e.pos, Color(0.85, 1.0, 1.0), SCALE_FINISHER, 6, 0.1)
					if not shook:
						rig.shake(FINISHER_SHAKE)
						shook = true
				else:
					actors.flash(e.target_id)
				if e.target_id == player_id:
					rig.shake(0.55)
				elif player_hit(e, player_id):
					var hit := impacts.on_hit(reader, e)
					_flinch(e.target_id, hit[0], hit[1], hit[2])
					if e.tags & SimEvent.TAG_MELEE:  # A Blade hit holds the views a moment
						hit_stop.on_blade_hit(
							e.target_id,
							e.tick,
							_swing_serial if st > 0 else -1,
							SimPlane.to_3d(hit[0]),
							finisher_hit(reader, e),
							player_id
						)
			SimEvent.Kind.HIT:
				if e.tags & SimEvent.TAG_EXPOSED:  # BX: a boss's open weak point, struck up close
					_spark(HitPack.WEAK, e.pos, Color(1.0, 0.84, 0.42), SCALE_EXPOSED, 9, 0.11)
				elif e.tags & SimEvent.TAG_DEFLECTED:  # BX: the ranged armour turned most of it
					_spark(HitPack.DEFLECT, e.pos, DEFLECT_COLOR, SCALE_DEFLECT, 3, 0.06)
				elif e.tags & (SimEvent.TAG_BLOCKED | SimEvent.TAG_GUARDED):
					_spark(HitPack.GUARD, e.pos, Color(0.85, 0.9, 1.0), SCALE_GUARD, 4, 0.08)
				elif e.tags & SimEvent.TAG_ARMOURED:
					_spark(HitPack.GUARD, e.pos, Color(0.45, 0.45, 0.48), SCALE_ARMOUR, 3, 0.07)
				elif e.tags & SimEvent.TAG_WEAK_SPOT:
					_spark(HitPack.WEAK, e.pos, Color(1.0, 0.92, 0.55), SCALE_WEAK, 6, 0.09)
			SimEvent.Kind.KILL:
				if e.target_id != player_id:
					_burst(e.pos, ThemePalette.color(&"enemy_body"), SHARDS, 0.16, true)
					if _fleas.has(e.target_id):  # ENEMIES.md H3: a dead flea leaves a spark (a look)
						_fleas.erase(e.target_id)
						_spark(HitPack.WEAK, e.pos, FLEA_SPARK, SCALE_WEAK, 6, 0.09)
	_track_fleas(reader)
	impacts.track(reader)


## A DAMAGE event that is the player's hit on an enemy (not a damage-over-time tick).
static func player_hit(e: SimEvent, player_id: int) -> bool:
	return (
		e.kind == SimEvent.Kind.DAMAGE
		and e.owner_id == player_id
		and e.target_id != player_id
		and (e.tags & SimEvent.TAG_DOT) == 0
		and e.amount > 0
	)


## Flinches the hit enemy's model away along `away` (a model without a flinch: nothing).
## `knock` (a Blade hit's) also knocks the pose away (AvatarBase.flinch).
func _flinch(id: int, away: Vector2, strength: float, knock: float = 0.0) -> void:
	var node := actors.actor_node(id)
	if node == null or not node.has_meta(&"enemy_avatar"):
		return
	var avatar: Object = node.get_meta(&"enemy_avatar")
	if avatar.has_method(&"flinch") and avatar.call(&"flinch", away, strength, knock):
		flinches += 1


## A DAMAGE event from the combo's finisher itself (the player's melee, not an item's echo), read while that swing
## is still running.
static func finisher_hit(reader: WorldReader, e: SimEvent) -> bool:
	return (
		e.kind == SimEvent.Kind.DAMAGE
		and (e.tags & SimEvent.TAG_MELEE) != 0
		and e.effect_id == &""
		and e.owner_id == reader.actor_id(0)
		and reader.swing_tick() > 0
		and reader.is_finisher()
	)


## How many spark pieces are flying (tests).
func spark_count() -> int:
	var n := 0
	for pool: ShardPool in _pools.values():
		n += pool.count()
	return n


## A spark of pack scene `id` tinted `c` and scaled `k`; the family full (or no pack): `n` boxes.
func _spark(id: StringName, at: Vector2, c: Color, k: float, n: int, size: float) -> void:
	if (
		PACK_SPARKS
		and ViewPrefs.sparks(n) > 0
		and HitPack.spark(pack_fx, id, SimPlane.to_3d(at, SPARK_HEIGHT), k, c)
	):
		return
	_burst(at, c, n, size)


## A dead enemy's smoke puff and flash in its body colour, added to the chunks.
## `lit`: the pieces are debris (a dead enemy's body), shaded by the scene's light like the body they came from;
## otherwise they are sparks of light, unshaded. A3 VFX audit: the death pop was unshaded, so its red
## chunks glowed at full brightness next to the lit bodies, and stood out of a darker scene as flat stickers.
func _burst(at: Vector2, c: Color, n: int, size: float, lit: bool = false) -> void:
	var key := [c, lit]
	var pool: ShardPool = _pools.get(key)
	if pool == null:
		# One material and one multimesh per look, kept for the view's life, not one per kill (DAMAGE_LAG.md):
		# nothing is allocated per kill, and a look is one draw however many cubes fly.
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		if lit:
			m.roughness = 1.0
		else:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pool = ShardPool.new(m)
		add_child(pool)
		_pools[key] = pool
	for k in ViewPrefs.sparks(n):  # reduced motion throws fewer
		var dir := Vector3(
			_rng.randf_range(-1, 1), _rng.randf_range(0.6, 1.4), _rng.randf_range(-1, 1)
		)
		pool.throw(SimPlane.to_3d(at, 0.4), dir * _rng.randf_range(2.5, 4.5), size)


func _process(delta: float) -> void:
	hit_stop.advance(delta)
	for pool: ShardPool in _pools.values():
		pool.step(delta)


## The Ember Fleas alive now (only on a floor whose critter is the flea: a scan of the actors).
func _track_fleas(reader: WorldReader) -> void:
	if reader.critter_kind() != WorldReader.KIND_EMBER_FLEA:
		if not _fleas.is_empty():
			_fleas.clear()
		return
	for i in range(1, reader.actor_count()):
		if reader.actor_kind(i) == WorldReader.KIND_EMBER_FLEA and not reader.actor_dead(i):
			_fleas[reader.actor_id(i)] = true
