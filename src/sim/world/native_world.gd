class_name NativeWorld
extends RefCounted
## The native side of one World (World.native): the ZdWorld class of the game's C++ library
## (native/zd_native.gdextension, built by `bash scripts/native/build.sh`). The sim's hot loops run there and only
## there: the enemies' thinking and steering (NativeAi), the collision passes (NativeMove), the enemies' strikes
## (NativeStrike), the projectile sweep (NativeShots) and the flow field's flood (NativeNav). It holds only caches
## derived from the world's walls, tables and tuning, so the snapshot never carries it: GDScript keeps every hashed
## column, and a kernel reads them by name and writes the ones it changed back as new arrays (native/README.md).
## The bridges call the sync functions here first, so the caches follow the world after a wall change, a new set of
## enemy tables, a new tuning or a restore.
##
## This file is the one place in src/sim that looks the class up (tests/arch/test_sim_purity.gd allows exactly
## `ClassDB.class_exists(CLASS)` and `ClassDB.instantiate(CLASS)` here): instantiating the sim's own kernel is not a
## node, a clock, content loading, randomness or library trigonometry (EI-02, LOCKED_DECISIONS 2026-11-11). Without
## the library a World gets no native side: make() reports MISSING once a process and World.step does nothing but
## count its tick, so a run without it is never quietly a different sim.

## The library's class.
const CLASS := &"ZdWorld"
## The one error a process prints when the library is not loaded.
const MISSING := (
	"Zero Depth's native library is not loaded (native/zd_native.gdextension and native/bin/). Build it with"
	+ " `bash scripts/native/build.sh` (see native/README.md), then import twice:"
	+ " `godot --headless --path . --editor --import --quit`. The sim does not run without it."
)

## Whether MISSING was printed in this process (a flag, not a callable: nothing static here holds a lambda).
static var _reported := false


## Whether the native library is loaded.
static func available() -> bool:
	return ClassDB.class_exists(CLASS)


## A fresh native side with its direction tables set (what every World gets in its _init), or null without the
## library (MISSING printed once).
static func make() -> Object:
	if not available():
		report_missing()
		return null
	var m: Object = ClassDB.instantiate(CLASS)
	if not m.set_trig(Kin.cos_table(), Kin.sin_table()):
		push_error("NativeWorld: the native side refused the direction tables")
	return m


## Prints MISSING, once a process.
static func report_missing() -> void:
	if _reported:
		return
	_reported = true
	push_error(MISSING)


## The walls again when they changed (World._wall_rev), and the solids standing now.
static func sync_walls(w: World) -> void:
	var m: Object = w.native
	if int(m.get_meta(&"wall_rev", -1)) != w._wall_rev:
		m.set_walls(obb_floats(w.walls))
		m.set_meta(&"wall_rev", w._wall_rev)
	if not w.solids.is_empty():
		m.set_solids(_placed_solids(w.solids))
	elif m.get_meta(&"has_solids", false):
		m.set_solids(PackedFloat32Array())
	m.set_meta(&"has_solids", not w.solids.is_empty())


## The per-kind table again unless the native side has it for this world's tables and tuning: a kernel that reads
## it calls this first. The tuning is replaced whole (never edited in place), so its identity is the stamp;
## World.set_enemy_tables clears it (tables_changed).
static func sync_kinds(w: World) -> void:
	var m: Object = w.native
	if not m.has_meta(&"kinds_for") or not is_same(m.get_meta(&"kinds_for"), w.tuning):
		send_kinds(w)


## Builds the per-kind table from the world's enemy tables and tuning and sends it.
static func send_kinds(w: World) -> void:
	var t := NativeKindTable.build(w)
	var m: Object = w.native
	var n: int = m.set_kinds(t[0], t[1], t[2], NativeKindTable.KI, NativeKindTable.KF)
	if n != NativeKindTable.kind_count():
		push_error(
			"NativeWorld: the native side took %d kinds of %d" % [n, NativeKindTable.kind_count()]
		)
	m.set_meta(&"kinds_for", w.tuning)


## The world's enemy tables changed: the table goes again before the next kernel that reads it (sync_kinds).
static func tables_changed(w: World) -> void:
	w.native.remove_meta(&"kinds_for")


## Oriented boxes as the native side reads them: 8 floats each (centre, axis u, axis v, half-extents).
static func obb_floats(list: Array[Obb]) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(list.size() * 8)
	for k in list.size():
		var o := list[k]
		var j := k * 8
		out[j] = o.center.x
		out[j + 1] = o.center.y
		out[j + 2] = o.axis_u.x
		out[j + 3] = o.axis_u.y
		out[j + 4] = o.axis_v.x
		out[j + 5] = o.axis_v.y
		out[j + 6] = o.half.x
		out[j + 7] = o.half.y
	return out


## The solids that stand as walls now (Solids.placed).
static func _placed_solids(s: Solids) -> PackedFloat32Array:
	var list: Array[Obb] = []
	for i in s.size():
		if s.placed[i] == 1:
			list.append(s.obb(i))
	return obb_floats(list)
