extends RefCounted
## The frame probe's --proc-census (scripts/checks/frame_probe.gd): what the engine processes each frame that the
## script timers cannot see. Walks the live tree once (mid-fight) and counts, by class, the nodes in the tree with
## their process, internal process, physics or internal physics process on; the animation mixers that are active and
## playing; the skeletons; the particle nodes that emit and are visible; and the scripts whose nodes process.
## Probe-only, never loaded by the game. Counts, not timings: the timings come from --spans runs with an --ab switch.
##   ... -s scripts/checks/frame_probe.gd -- --biome=red_canyon --enemies=30 --secs=20 --proc-census


## The census lines of the tree under `root`.
static func lines(root: Node) -> PackedStringArray:
	var by_class := {}  # class -> [nodes, process, internal, physics, internal physics]
	var scripts := {}  # script file -> [nodes processing, nodes in all]
	var mixers := [0, 0, 0]  # in the tree, active, playing (an AnimationPlayer playing)
	var mixer_owners := {}  # nearest script of an active mixer -> count
	var skeletons := [0, 0]  # in the tree, visible in the tree
	var parts := {}  # particle class -> [nodes, emitting, emitting and visible]
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var c := n.get_class()
		var row: Array = by_class.get(c, [0, 0, 0, 0, 0])
		row[0] += 1
		row[1] += 1 if n.is_processing() else 0
		row[2] += 1 if n.is_processing_internal() else 0
		row[3] += 1 if n.is_physics_processing() else 0
		row[4] += 1 if n.is_physics_processing_internal() else 0
		by_class[c] = row
		var sc: Script = n.get_script()
		if sc != null:
			var key := String(sc.resource_path.get_file())
			var s: Array = scripts.get(key, [0, 0])
			s[0] += 1 if n.is_processing() else 0
			s[1] += 1
			scripts[key] = s
		if n is AnimationMixer:
			var m := n as AnimationMixer
			mixers[0] += 1
			if m.active:
				mixers[1] += 1
				var o := _owner_script(n)
				mixer_owners[o] = int(mixer_owners.get(o, 0)) + 1
			if m is AnimationPlayer and (m as AnimationPlayer).is_playing():
				mixers[2] += 1
		elif n is Skeleton3D:
			skeletons[0] += 1
			skeletons[1] += 1 if (n as Skeleton3D).is_visible_in_tree() else 0
		elif (
			n is GPUParticles3D or n is CPUParticles3D or n is GPUParticles2D or n is CPUParticles2D
		):
			var e: bool = n.get(&"emitting")
			var p: Array = parts.get(c, [0, 0, 0])
			p[0] += 1
			p[1] += 1 if e else 0
			p[2] += (
				1
				if e and (n as CanvasItem if n is CanvasItem else n as Node3D).is_visible_in_tree()
				else 0
			)
			parts[c] = p
	var out: PackedStringArray = []
	(
		out
		. append(
			"proc_census (the live tree, mid-fight; nodes / process / internal / physics / internal physics):"
		)
	)
	var keys: Array = by_class.keys()
	keys.sort_custom(
		func(a: String, b: String) -> bool: return _busy(by_class[a]) > _busy(by_class[b])
	)
	for k: String in keys:
		var r: Array = by_class[k]
		if _busy(r) == 0:
			continue
		out.append("  %-26s %6d %6d %6d %6d %6d" % [k, r[0], r[1], r[2], r[3], r[4]])
	out.append(
		(
			"  mixers: %d in the tree, %d active, %d AnimationPlayers playing"
			% [mixers[0], mixers[1], mixers[2]]
		)
	)
	for o: String in mixer_owners:
		out.append("    active mixers under %s: %d" % [o, mixer_owners[o]])
	out.append("  skeletons: %d in the tree, %d visible" % [skeletons[0], skeletons[1]])
	for p: String in parts:
		var r: Array = parts[p]
		out.append(
			"  %s: %d in the tree, %d emitting, %d emitting and visible" % [p, r[0], r[1], r[2]]
		)
	var sk: Array = scripts.keys()
	sk.sort_custom(func(a: String, b: String) -> bool: return scripts[a][0] > scripts[b][0])
	var parts_line: PackedStringArray = []
	for k: String in sk:
		if scripts[k][0] > 0:
			parts_line.append("%s %d/%d" % [k, scripts[k][0], scripts[k][1]])
	out.append("  script nodes processing (processing/in the tree): " + ", ".join(parts_line))
	return out


static func _busy(r: Array) -> int:
	return int(r[1]) + int(r[2]) + int(r[3]) + int(r[4])


static func _owner_script(n: Node) -> String:
	var o: Node = n
	while o != null and o.get_script() == null:
		o = o.get_parent()
	return "(no script)" if o == null else String(o.get_script().resource_path.get_file())
