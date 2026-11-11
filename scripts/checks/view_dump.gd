extends SceneTree
## A frame-by-frame dump of the views that read the sim in bulk and rest while nothing of their kind happens (the
## telegraphs, the statuses on the actors, the shard gems and drops, the burn tints, the ruins, variant and canyon
## kinds' views), over one seeded fight, so the dump of one tree can be compared with another's line by line. Every
## frame: one tick, the views' sync on a LatchedReader (noted each tick and settled, as the game does), then the
## views' own _process at 1/60 s. Statuses, shard payouts and drops are written into the fight on fixed ticks.
## Each line: the frame, the view, and per node in tree order (child index path) whether it shows in the tree, its
## global transform, a mesh's surface sizes and a multimesh's drawn instances. The flying shard gems are dumped as
## the gems themselves (place and turn, sorted), from their nodes or their instances, whichever the tree draws them
## with.
## Needs a renderer (the instances are read back from it), off screen, at a fixed 60 fps:
##   godot --path . --fixed-fps 60 --resolution 640x360 --windowed --position -10000,-10000 \
##     -s scripts/checks/view_dump.gd -- --out=build/view_dump.txt [--frames=900]
## Writes only the given file (under build/).

const MIX := [
	ActorStore.Kind.SWARMER,
	ActorStore.Kind.WARDEN,
	ActorStore.Kind.MINE_LAYER,
	ActorStore.Kind.ARC_CASTER,
	ActorStore.Kind.CHARGER,
	ActorStore.Kind.SPLIT_SNIPER,
	ActorStore.Kind.STONE_THROWER,
	ActorStore.Kind.WIRE_WEAVER,
	ActorStore.Kind.SCRAP_HOUND,
	ActorStore.Kind.FROST_SPITTER,
	ActorStore.Kind.GLACIER_TURTLE,
	ActorStore.Kind.SWARMER,
]

## The state a view keeps per actor, dumped beside its nodes (where what it changes is not its own node).
const STATE := {
	"item_fx": ["_burning"],
	"canyon_shore_fx": ["_arcs", "_shells"],
	"variant_fx": ["_states"],
	"ruins_rocks_fx": ["_yelped"],
}

var _out := "build/view_dump.txt"
var _frames := 900
var _frame := 0
var _w: World
var _r: LatchedReader
var _views: Array = []  # [name, node]
var _lines: PackedStringArray = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("out="):
			_out = s.trim_prefix("out=")
		elif s.begins_with("frames="):
			_frames = int(s.trim_prefix("frames="))
	_w = CombatLab.world()
	_w.actors.hp[0] = 1 << 24
	_w.actors.max_hp[0] = 1 << 24
	for k in 24:
		var ang := TAU * k / 24.0
		_w.add_enemy(MIX[k % MIX.size()], Vector2(cos(ang), sin(ang)) * (3.0 + (k % 6)))
	_r = LatchedReader.new(WorldReader.new(_w))
	var stage := Node3D.new()
	root.add_child(stage)
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.look_at_from_position(Vector3(10, 14, 10), Vector3.ZERO)
	var actors := ActorViews.new()
	stage.add_child(actors)
	var tg := TelegraphViews.new()
	stage.add_child(tg)
	tg.prepare()
	var status := StatusVisuals.new(actors)
	stage.add_child(status)
	status.prepare()
	var kit := KitView.new()
	stage.add_child(kit)
	var items := ItemVisuals.new(kit, actors)
	stage.add_child(items)
	var shards := ShardViews.new()
	stage.add_child(shards)
	var ruins := RuinsRocksViews.new()
	stage.add_child(ruins)
	var variants := VariantViews.new()
	stage.add_child(variants)
	var canyon := CanyonShoreViews.new()
	stage.add_child(canyon)
	_views = [
		["actors", actors],
		["telegraphs", tg],
		["status_fx", status],
		["item_fx", items],
		["shards", shards],
		["ruins_rocks_fx", ruins],
		["variant_fx", variants],
		["canyon_shore_fx", canyon],
	]


func _process(_delta: float) -> bool:
	if _frame > 0:
		_dump()
	if _frame >= _frames:
		var f := FileAccess.open(_out, FileAccess.WRITE)
		f.store_string("\n".join(_lines) + "\n")
		f.close()
		print("view_dump: %d frames, %d lines, %s" % [_frame, _lines.size(), _out])
		quit(0)
		return true
	_frame += 1
	_feed(_frame)
	_w.step(InputFrame.new())
	_r.note()
	_r.settle()
	for v: Array in _views:
		(v[1] as Object).call(&"sync", _r)
	return false


## The fight's fixed writes: statuses on some enemies, an instant shard payout, a drop on the floor, one in reach.
func _feed(t: int) -> void:
	var a := _w.actors
	if t % 37 == 0:
		for i in range(1, a.size()):
			a.burn_stacks[i] = (i * 7 + t) % 5 if i % 3 == 0 else 0
			a.frozen_t[i] = 20 if (i + t) % 11 == 0 else 0
			a.bleed_stacks[i] = 2 if (i + t) % 7 == 0 else 0
			a.shock_stacks[i] = 1 if (i + t) % 13 == 0 else 0
	if t % 120 == 40:
		_w.guard_charges = (t / 120) % 3
	if t % 90 == 10:
		var me := a.ids[0]
		var e := _w.emit_event(SimEvent.Kind.SHARDS, me, me, me, Vector2(4, (t % 7) - 3.0))
		e.amount = 3 + t % 6
	if t % 50 == 5:
		ShardDrops.drop(_w, Vector2(5, (t % 11) - 5.0), 2 + t % 9)
	if t % 200 == 100:
		ShardDrops.drop(_w, Vector2(0.4, 0), 4)


func _dump() -> void:
	for v: Array in _views:
		var out: PackedStringArray = []
		if v[1] is ShardViews:
			_gems(v[1], out)
		if v[1] is ActorViews:  # Only the status pieces on the actors (the bodies are not these views')
			var k := 0
			for st: Node in (v[1] as Node).find_children("Statuses", "Node3D", true, false):
				out.append("st%d:%s" % [k, _xf((st as Node3D).global_transform)])
				_walk(st, "st%d" % k, out, false)
				k += 1
			_lines.append("%d %s %s" % [_frame, v[0], " ".join(out)])
			continue
		_walk(v[1], "", out, v[1] is ShardViews)
		for key: String in STATE.get(v[0], []):  # What a view keeps per actor (tints, shells, arcs, states)
			out.append("%s=%s" % [key, _plain((v[1] as Object).get(key))])
		_lines.append("%d %s %s" % [_frame, v[0], " ".join(out)])


func _walk(n: Node, path: String, out: PackedStringArray, shards: bool) -> void:
	var k := 0  # The child's place among the ones dumped (the gems, whichever way they are drawn, left out)
	for c in n.get_children():
		if (
			shards
			and n is ShardViews
			and (c.has_meta(&"crystal") or String(c.name).begins_with("Gem"))
		):
			continue  # A flying gem (a node or the batches): dumped by _gems
		var p := "%s/%d" % [path, k]
		k += 1
		if c is Node3D:
			var n3 := c as Node3D
			if n3.is_visible_in_tree():
				out.append("%s:%s" % [p, _xf(n3.global_transform)])
				if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
					out.append("%s:mesh%s" % [p, _surfaces((c as MeshInstance3D).mesh)])
				if c is MultiMeshInstance3D and (c as MultiMeshInstance3D).multimesh != null:
					out.append("%s:mm%s" % [p, _instances((c as MultiMeshInstance3D).multimesh)])
			else:
				out.append("%s:hidden" % p)
		_walk(c, p, out, shards)


## The flying gems in flight order: their place and turn, read from the nodes or from the crystal batch's instances,
## and the outline shell's scale against the crystal.
func _gems(s: ShardViews, out: PackedStringArray) -> void:
	var gems: PackedStringArray = []
	if s.has_method(&"gem_batches"):
		var b: Array = s.call(&"gem_batches")
		# The batches move in the physics interpolation, so reading an instance back gives the last tick's
		# transform; the gems are read from the view's slots instead (the shots prove what the batches draw),
		# with the transform each slot's crystal and shell are given.
		if b[0] != null and (b[0] as MultiMeshInstance3D).visible:
			var live: PackedByteArray = s.get(&"_g_live")
			var pos: PackedVector3Array = s.get(&"_g_pos")
			var turn: PackedFloat32Array = s.get(&"_g_turn")
			var shown := (b[0] as MultiMeshInstance3D).multimesh.visible_instance_count
			for k in live.size():
				if live[k] == 1:
					var c := Transform3D(Basis(Vector3.UP, turn[k]), pos[k])
					var grow := (
						1.0 + float(s.get_script().get_script_constant_map()[&"GEM_OUTLINE"])
					)
					gems.append("%s~%.4f%s" % [_xf(c), grow, "" if k < shown else "!undrawn"])
	else:
		for c in s.get_children():
			if c.has_meta(&"crystal") and (c as Node3D).visible:
				var body: Node3D = c.get_meta(&"crystal")
				var shell: Node3D = c.get_meta(&"outline")
				var cx := body.global_transform
				gems.append(
					(
						"%s~%.4f"
						% [
							_xf(cx),
							shell.global_transform.basis.get_scale().x / cx.basis.get_scale().x
						]
					)
				)
	gems.sort()  # In place order: the nodes keep flight order, the batches keep slots
	out.append("gems[%d]{%s}" % [gems.size(), ",".join(gems)])


static func _xf(t: Transform3D) -> String:
	var b := t.basis
	return (
		"%.3f,%.3f,%.3f|%.3f,%.3f,%.3f,%.3f,%.3f,%.3f"
		% [t.origin.x, t.origin.y, t.origin.z, b.x.x, b.x.z, b.y.y, b.z.x, b.z.z, b.x.y]
	)


static func _surfaces(m: Mesh) -> String:
	if not (m is ArrayMesh or m is ImmediateMesh):
		return "[%s]" % m.get_class()  # A primitive: its shape is its class and its node's transform
	var s := "["
	for k in m.get_surface_count():
		s += "%d;" % m.surface_get_array_len(k)
	return s + "]"


static func _instances(mm: MultiMesh) -> String:
	var n := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
	var s := "[%d:" % n
	for k in n:
		s += _xf(mm.get_instance_transform(k)) + ";"
	return s + "]"


## A view's kept value as text: a Dictionary by sorted key, nodes as their places, numbers rounded.
static func _plain(v: Variant) -> String:
	if v is Dictionary:
		var keys: Array = (v as Dictionary).keys()
		keys.sort()
		var parts: PackedStringArray = []
		for k: Variant in keys:
			parts.append("%s:%s" % [k, _plain(v[k])])
		return "{%s}" % ",".join(parts)
	if v is Array:
		var parts: PackedStringArray = []
		for x: Variant in v:
			parts.append(_plain(x))
		return "[%s]" % ",".join(parts)
	if v is Node3D:
		return _xf((v as Node3D).global_transform)
	if v is float:
		return "%.4f" % v
	if v is Vector2:
		return "%.4f,%.4f" % [v.x, v.y]
	return str(v)
