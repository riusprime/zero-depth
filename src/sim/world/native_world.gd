class_name NativeWorld
extends RefCounted
## The native side of one World (World.native: the ZdWorld class of the game's GDExtension, made by the app layer's
## World.native_factory). It holds only caches derived from the world's walls, tables and tuning, so the snapshot
## never carries it: GDScript keeps every hashed column, and a kernel reads them by name and writes the ones it
## changed back as new arrays (NATIVE_CORE.md §2). Each kernel is switched on by its own bit (World.native_on); the
## bridges (NativeMove and the others in src/sim/world/native_*.gd) call the sync functions here first, so the caches
## follow the world after a wall change, a new set of enemy tables, a new tuning or a restore.

## The kernels, one bit each (World.native_kernels, World.native_on).
const MOVE := 1
const AI := 2
const STRIKE := 4
const SHOTS := 8
const NAV := 16
const ALL := MOVE | AI | STRIKE | SHOTS | NAV
## The kernels by the names the switch takes (NativeSwitch), in bit order.
const NAMES := {&"move": MOVE, &"ai": AI, &"strike": STRIKE, &"shots": SHOTS, &"nav": NAV}
## The kernels that read the per-kind table (NativeKindTable).
const READ_KINDS := AI | STRIKE


## A new world's one-time setup: the direction tables, the same 513 floats Kin reads.
static func setup(w: World) -> void:
	if not w.native.set_trig(Kin.cos_table(), Kin.sin_table()):
		push_error("NativeWorld: the native side refused the direction tables")


## The names of the kernels in `bits`, joined by commas ("" for none).
static func names_of(bits: int) -> String:
	var out := PackedStringArray()
	for k: StringName in NAMES:
		if (bits & int(NAMES[k])) != 0:
			out.append(String(k))
	return ",".join(out)


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


## The world's enemy tables changed: the table goes again, now when a kernel that reads it is on.
static func tables_changed(w: World) -> void:
	w.native.remove_meta(&"kinds_for")
	if (w.native_on & READ_KINDS) != 0:
		send_kinds(w)


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
