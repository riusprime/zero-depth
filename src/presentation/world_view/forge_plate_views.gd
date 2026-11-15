class_name ForgePlateViews
extends Node3D
## The Foundry's Forged Plate as the player sees it, drawn from WorldReader.boss_forge (EI-07: when it forges, whether
## it wears the plate and when a bomb blew it off are the sim's, BossForge). No word anywhere (the owner: the player
## discovers the answer from glows and motion).
## - The forging: through its cast the pack's hot lift (fo_forge) rises round the Foundry's feet, and hammer sparks
##   (fo_spark) strike on its body, faster as the cast fills.
## - Plated: the Foundry's model wears a steel shell (FoundryAvatar's plate overlay) and the hero's hits on it give the
##   dull grey spark of an ARMOURED hit (HitFeel). While a bomb drone's lob is in the air, its bomb carries the pack's
##   ember flare (fo_bomb), and a faint ring (fo_reach) lies round the Foundry where a landing bomb blows the plate:
##   its edge plus the blast distance (ForgeLooks.DRONE_BLAST_M). The ring turns gold (fo_reach_on) while the bomb
##   is aimed inside it. Nothing of this shows while no bomb flies.
## - Blown: the plate bursts in steel shards (fo_shards) where the bomb landed and on the Foundry; the exposed time is
##   BossVulnerableViews' gold pulse and stars, and the bar's shimmer.
## Reduced motion keeps the sparks to one at a time. Nothing here decides.

const FORGE_ID := &"fo_forge"
const SPARK_ID := &"fo_spark"
const SHARDS_ID := &"fo_shards"
const REACH_ID := &"fo_reach"
const REACH_ON_ID := &"fo_reach_on"
const BOMB_ID := &"fo_bomb"
const BLOWN_EVENT := &"plate_blown"
## The pack scenes' size per metre of radius (the rim 0.55, as the Siege Engine's; the lift and the shards).
const RIM_PER_M := 0.55
const LIFT_PER_M := 0.5
const SHARDS_PER_M := 0.7
const BOMB_SCALE := 0.45
## The hammer's beat through the cast (s between sparks at its start and at its end) and where they strike.
const BEAT_SLOW := 0.32
const BEAT_FAST := 0.12
const SPARK_SCALE := 0.55
const SPARK_UP := 1.4

var pack_fx: PackFx = null:
	set(v):
		pack_fx = v
		hold.pack = v
var hold := FormPackHold.new()
## True once a frame with nothing to show drew it all hidden: later frames return at once.
var quiet := false
var _plate := {}
var _boss_at := Vector3.ZERO
var _boss_r := 1.6
var _bombs: Array = []
var _last_seq := 0
var _primed := false
var _beat := 0.0
var _sparks := 0
## The ring's key suffix: a ring the pack had no room for (its family full that frame) tries again under a new key
## the next frame, rather than staying refused for the whole flight.
var _ring_try := 0


func _init() -> void:
	name = "ForgePlateViews"


func sync(reader: WorldReader) -> void:
	if pack_fx == null and is_inside_tree():
		pack_fx = GapPack.pack_of(self)
	var forge := reader.boss_forge()
	_plate = forge.get("plate", {})
	_bombs = []
	if not forge.is_empty():
		var b := int(forge["boss"])
		_boss_at = SimPlane.to_3d(reader.actor_pos(b))
		_boss_r = reader.actor_radius(b)
		if bool(_plate.get("on", false)):
			_bombs = bombs_in_flight(reader, reader.actor_pos(b), _boss_r)
	if not _primed:
		_primed = true
		for e in reader.events_since(0):
			_last_seq = e.seq  # joining a fight under way replays nothing that already happened
	for e in reader.events_since(_last_seq):
		_last_seq = e.seq
		if e.kind == SimEvent.Kind.STATUS_APPLY and e.effect_id == BLOWN_EVENT:
			_burst(SimPlane.to_3d(e.pos, 0.3), 1.0)
			_burst(_boss_at + Vector3(0, 1.2, 0), _boss_r)


## The bomb drones' lobs in the air: [bomb position (3D, on the arc FireballViews draws it on), whether it is aimed
## within the plate's reach of a boss at `boss` of radius `r`].
static func bombs_in_flight(reader: WorldReader, boss: Vector2, r: float) -> Array:
	var out := []
	if not reader.any_kind(WorldReader.KIND_BOMB_DRONE):
		return out
	for j in reader.actor_count():
		if reader.actor_kind(j) != WorldReader.KIND_BOMB_DRONE:
			continue
		var tg := reader.telegraph(j)
		if tg.get("shape", &"") != &"lob":
			continue
		var p := float(tg["progress"]) / 1000.0
		var to: Vector2 = tg["to"]
		var at := (tg["from"] as Vector2).lerp(to, p)
		var y := FireballViews.HEIGHT + FireballViews.LOB_RISE * 4.0 * p * (1.0 - p)
		out.append([SimPlane.to_3d(at, y), to.distance_to(boss) <= r + ForgeLooks.DRONE_BLAST_M])
	return out


func _burst(at: Vector3, size: float) -> void:
	if pack_fx != null and pack_fx.has_id(SHARDS_ID) and pack_fx.has_room(&"impact"):
		pack_fx.spawn(SHARDS_ID, at, size * SHARDS_PER_M, ForgeLooks.SHARD_COLORS)


func _process(delta: float) -> void:
	advance(delta)


## Frame-time animation (the tests and the shot scripts call it too).
func advance(delta: float) -> void:
	if _plate.is_empty() and hold.count() == 0:
		quiet = true
		return
	quiet = false
	hold.begin()
	_draw_forging(delta)
	_draw_reach()
	hold.end()


func _draw_forging(delta: float) -> void:
	var forging := int(_plate.get("forging", -1))
	if forging < 0:
		_beat = 0.0
		return
	var share := float(forging) / 1000.0
	hold.put(
		&"forge",
		FORGE_ID,
		&"status",
		SiegeLooks.at(_boss_at + Vector3(0, 0.08, 0), _boss_r * LIFT_PER_M)
	)
	_beat -= delta
	if _beat > 0.0:
		return
	_beat = lerpf(BEAT_SLOW, BEAT_FAST, share) * (2.0 if ViewPrefs.reduced_motion else 1.0)
	_sparks += 1
	if pack_fx == null or not pack_fx.has_id(SPARK_ID) or not pack_fx.has_room(&"hit"):
		return
	var a := float(_sparks) * 2.39996  # the golden angle: each strike lands round the body from the last
	var off := Vector3(cos(a), 0.0, sin(a)) * _boss_r * 0.7
	pack_fx.spawn(
		SPARK_ID,
		_boss_at + off + Vector3(0, SPARK_UP + 0.3 * sin(a * 3.0), 0),
		SPARK_SCALE,
		ForgeLooks.SPARK_COLORS
	)


func _draw_reach() -> void:
	if _bombs.is_empty():
		return
	var inside := false
	for k in _bombs.size():
		var b: Array = _bombs[k]
		inside = inside or bool(b[1])
		hold.put([&"bomb", k], BOMB_ID, &"projectile", SiegeLooks.at(b[0], BOMB_SCALE))
	var r := (_boss_r + ForgeLooks.DRONE_BLAST_M) * RIM_PER_M
	var at := _boss_at + Vector3(0, 0.06, 0)
	var key := [&"reach_on" if inside else &"reach", _ring_try]
	if hold.put(key, REACH_ON_ID if inside else REACH_ID, &"area", SiegeLooks.at(at, r)) == null:
		if hold.refused(key):
			_ring_try += 1


# --- tests and the shot scripts ----------------------------------------------------------------------------------


## The forging read is drawn now.
func forging_shown() -> bool:
	return hold.has(&"forge")


## The ring round the Foundry now: &"" none, &"reach" (faint), &"reach_on" (a bomb aimed inside it).
func reach_read() -> StringName:
	if hold.has([&"reach_on", _ring_try]):
		return &"reach_on"
	return &"reach" if hold.has([&"reach", _ring_try]) else &""


## Bombs carrying the ember flare now.
func bombs_shown() -> int:
	return _bombs.size()
