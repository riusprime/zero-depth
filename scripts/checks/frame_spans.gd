extends RefCounted
## The frame probe's whole-frame attribution (scripts/checks/frame_probe.gd): its options, its extra A/B switches and
## its report lines. Probe-only, never loaded by the game.
## --spans cuts every frame, from one probe _process to the next, into consecutive spans that add up to the frame
## (stamps from the engine's own signals and from nodes that process first and last):
##   span.probe_script     the probe's _process (and, with --process, every stolen script node's _process), then the
##                         tree's process_frame signal
##   span.nodes_process    the scene tree's process pass: the nodes' _process and internal process (AnimationMixer,
##                         particles, ...), and SimDriver's frame_ticked view sync
##   span.after_process    the tree's flushes after it: queued calls (CanvasItem redraws, Control layout), transform
##                         notifications, timers, tweens, the delete queue, then the engine's rendering sync
##   span.draw             RenderingServer.draw: culling, the render lists, the GPU submit and the present
##   span.after_draw       the end of the engine's iteration (audio, any frame delay) to the first physics step
##   span.physics_pre      per physics step: the physics servers' sync up to the first physics node
##   span.nodes_physics    per physics step: the nodes' _physics_process (SimDriver's tick is in it)
##   span.physics_post     per physics step: after the last physics node (the physics and navigation servers' step,
##                         the queued calls, the physics interpolation) to the next step or the next frame
## The stamps cost a few microseconds a frame; --redraws counts the CanvasItem `draw` signals (one per redraw, which
## rebuilds the item's draw commands on the CPU); --orphans lists the nodes outside the tree by class and script.
## --hud-hide=<part[,part]> hides the HUD's and the UI layer's children whose class name, script class or node name
## contains a part (for example ItemIcons,BuildHud,DpsMeter): what those parts cost the frame, against a run without
## it. With --spans or --redraws a run also counts the root viewport's 2D draw calls a frame (count.canvas_dc).
## --size=WxH sets the window and the root viewport (default 1920x1080); --vsync=off|on|mailbox|adaptive overrides the
## probe's vsync off.
## --ab=detach_furniture takes every enemy's contact disc, team ring, dazed ring and health bar nodes out of the tree
## (re-applied every frame, so new enemies too) while its root, body and avatar stay: what the furniture's nodes cost.
## --ab=no_batch draws the batched enemy kinds with a node each again (ActorViews.batch_enemies off): the old path, in
## the same build, for a before/after run.
## --ab=no_native_crowd writes the batched enemies' furniture in GDScript (EnemyBatch.native off) with the native
## library loaded: the native writer's before/after.
## Every report says how many nodes are in the tree under the actors' view, by class (the last frame).
## --shot-at=N:<png> saves the viewport at the scenario's Nth frame, the probe's scripted strafe and aim on frames
## (run it with --fixed-fps 60 for the same frame twice: a before/after pair).
## --twin draws the scene a second time the old way and compares every batched enemy with its node (batch_twin.gd).

## The extra --ab switches handled here.
const AB := [
	"no_fti",
	"hide_actors",
	"detach_actors",
	"detach_furniture",
	"no_batch",
	"no_native_crowd",
	"no_particles",
	"no_hud",
	"no_still",
	"no_sun_shadow",
	"no_omni",
	"no_3d",
	"no_viewport",
]
const VSYNC := {
	"off": DisplayServer.VSYNC_DISABLED,
	"on": DisplayServer.VSYNC_ENABLED,
	"adaptive": DisplayServer.VSYNC_ADAPTIVE,
	"mailbox": DisplayServer.VSYNC_MAILBOX,
}
const SPAN_KEYS := [
	"span.probe_script",
	"span.nodes_process",
	"span.after_process",
	"span.draw",
	"span.after_draw",
	"span.physics_pre",
	"span.nodes_physics",
	"span.physics_post",
]

var on := false  # --spans
var redraws := false  # --redraws
var orphans := false  # --orphans
var twin := false  # --twin
var frame_clock := false  # --shot-at: the probe's scripted time runs on frames (1/60 s each), not the clock
var frames := 0  # per_frame calls since the scenario began
var size := Vector2i(1920, 1080)
var vsync := ""
var hud_hide: PackedStringArray = []  # --hud-hide
var _ab: PackedStringArray = []
var _twin: RefCounted
var _shot_at := -1
var _shot_path := ""
var _main: Node
var _tree: SceneTree
var _events: Array = []  # [key, usec] since the last gather
var _hooked: Array[Node] = []  # particles / lights the switches keep off
var _draws := {}  # owner key -> draws since the last gather
var _draw_frames := {}  # owner key -> total draws over the measured frames
var _draw_n := 0
var _objects0 := []  # [objects, nodes, resources, orphans] at the measure's start
var _detached: Node
var _detached_parent: Node
var _actors_view: Node
var _stripped := {}  # enemy roots whose furniture --ab=detach_furniture took out
var _cut: Array[Node] = []  # the furniture taken out (freed by restore)
var _hooks: Array = []  # [Signal, Callable]: every connection, cut again by restore


## One stamp: a node that only marks when the tree reaches it (it has no _process, so --process never steals it).
class Stamp:
	extends Node
	var spans: RefCounted
	var key: StringName

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PROCESS or what == NOTIFICATION_PHYSICS_PROCESS:
			spans.call(&"mark", key)


## True when `s` (an argument without its "--") is one of this file's options.
func parse(s: String) -> bool:
	if s.begins_with("shot-at="):  # --shot-at=N:path: the viewport at the Nth frame of the scenario
		var p := s.trim_prefix("shot-at=").split(":", true, 1)
		_shot_at = int(p[0])
		_shot_path = p[1]
		frame_clock = true
	elif s == "twin":
		twin = true
	elif s == "spans":
		on = true
	elif s == "redraws":
		redraws = true
	elif s == "orphans":
		orphans = true
	elif s.begins_with("size="):
		var p := s.trim_prefix("size=").split("x")
		size = Vector2i(int(p[0]), int(p[1]))
	elif s.begins_with("hud-hide="):
		hud_hide = s.trim_prefix("hud-hide=").split(",", false)
	elif s.begins_with("vsync="):
		vsync = s.trim_prefix("vsync=")
	else:
		return false
	return true


func mark(key: StringName) -> void:
	_events.append([key, Time.get_ticks_usec()])


## Called once the scenario is set up (after the probe's own vsync-off and A/B switches).
func setup(tree: SceneTree, main: Node, ab: PackedStringArray) -> void:
	_tree = tree
	_main = main
	_ab = ab
	if VSYNC.has(vsync):
		DisplayServer.window_set_vsync_mode(VSYNC[vsync])
	if on:
		_add_stamp(&"proc_first", -2000000000, false)
		_add_stamp(&"proc_last", 2000000000, false)
		_add_stamp(&"phys_first", -2000000000, true)
		_add_stamp(&"phys_last", 2000000000, true)
		_hook(tree.physics_frame, func() -> void: mark(&"phys_sig"))
		_hook(RenderingServer.frame_pre_draw, func() -> void: mark(&"pre_draw"))
		_hook(RenderingServer.frame_post_draw, func() -> void: mark(&"post_draw"))
	if twin:  # --twin: the batched enemies against a twin view of nodes (batch_twin.gd)
		_twin = (load("res://scripts/checks/batch_twin.gd") as GDScript).new()
		_twin.call(&"setup", main)
	_hook(tree.node_added, _on_node_added)
	var stack: Array[Node] = [tree.root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		_on_node_added(n)
	var v: Node = main.get(&"view")
	_hide_hud_parts(main)
	_actors_view = v.get(&"actors")
	for f in ab:
		match f:
			"no_fti":
				tree.physics_interpolation = false
			"hide_actors":
				(v.get(&"actors") as Node3D).visible = false
			"detach_actors":
				_detached = v.get(&"actors")
				_detached_parent = _detached.get_parent()
				_detached_parent.remove_child(_detached)
			"no_batch":
				ActorViews.batch_enemies = false
			"no_native_crowd":
				EnemyBatch.native = false
			"no_hud":
				(main.get(&"ui") as CanvasLayer).visible = false
			"no_still":  # every HUD part drawn directly each frame (HudStill's textures off)
				(main.get(&"_hud").get(&"still") as HudStill).set_enabled(false)
			"no_3d":  # the root viewport draws its 2D (the HUD) only
				tree.root.disable_3d = true
			"no_viewport":  # the root viewport is not drawn at all (the engine still syncs and presents)
				RenderingServer.viewport_set_active(tree.root.get_viewport_rid(), false)


func _hide_hud_parts(main: Node) -> void:
	if hud_hide.is_empty():
		return
	var hud: Node = main.get(&"_hud")
	var parts: Array[Node] = hud.get_children()
	parts.append_array((main.get(&"ui") as Node).get_children())  # the DPS meter is on the UI layer
	for h in parts:
		if h == hud or not h is CanvasItem:
			continue
		var script: Script = h.get_script()
		var label := (
			"%s %s %s"
			% [h.get_class(), h.name, script.get_global_name() if script != null else &""]
		)
		for part in hud_hide:
			if label.contains(part) and (h as CanvasItem).visible:
				(h as CanvasItem).visible = false
				print("frame_spans: hid the HUD part ", label)


func _hook(sig: Signal, cb: Callable) -> void:
	sig.connect(cb)
	_hooks.append([sig, cb])


func _add_stamp(key: StringName, prio: int, physics: bool) -> void:
	var s := Stamp.new()
	s.spans = self
	s.key = key
	s.name = "ProbeStamp_" + String(key)
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	if physics:
		s.process_physics_priority = prio
		s.set_physics_process(true)
	else:
		s.process_priority = prio
		s.set_process(true)
	_tree.root.add_child.call_deferred(s)


func _on_node_added(n: Node) -> void:
	if redraws and n is CanvasItem:
		var key := _owner_key(n)
		_hook((n as CanvasItem).draw, func() -> void: _draws[key] = int(_draws.get(key, 0)) + 1)
	if (
		(_ab.has("no_particles") and (n is GPUParticles3D or n is CPUParticles3D))
		or (_ab.has("no_sun_shadow") and n is DirectionalLight3D)
		or (_ab.has("no_omni") and (n is OmniLight3D or n is SpotLight3D))
	):
		_hooked.append(n)


## The class and the nearest script of `n`, as a report key.
static func _owner_key(n: Node) -> String:
	var o: Node = n
	while o != null and o.get_script() == null:
		o = o.get_parent()
	var sc := "(no script)" if o == null else String(o.get_script().resource_path.get_file())
	return "%s<%s" % [n.get_class(), sc]


## Re-applied every frame: pooled effects and lights turn themselves back on.
func per_frame() -> void:
	frames += 1
	if frames == _shot_at:
		var img := _tree.root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(_shot_path.get_base_dir())
		img.save_png(_shot_path)
		print("shot-at: frame %d -> %s" % [frames, _shot_path])
	var keep: Array[Node] = []
	for n in _hooked:
		if not is_instance_valid(n):
			continue
		keep.append(n)
		if n is GPUParticles3D:
			(n as GPUParticles3D).emitting = false
		elif n is CPUParticles3D:
			(n as CPUParticles3D).emitting = false
		elif n is DirectionalLight3D:
			(n as DirectionalLight3D).shadow_enabled = false
		elif n is Light3D:
			(n as Light3D).visible = false
	_hooked = keep
	if _ab.has("detach_furniture") and is_instance_valid(_actors_view):
		_detach_furniture()


## --ab=detach_furniture: each new enemy root's disc, ring, dazed ring and bar leave the tree (kept as orphans).
func _detach_furniture() -> void:
	for root in _actors_view.get_children():
		if not root.has_meta(&"enemy_avatar") or _stripped.has(root):
			continue
		_stripped[root] = true
		var cut: Array[Node] = []
		for c in root.get_children():
			if c is MeshInstance3D:  # the contact disc and the team ring (the dazed ring too)
				cut.append(c)
		if root.has_meta(&"bar"):
			cut.append((root.get_meta(&"bar") as Node).get_parent())
		for c in cut:
			root.remove_child(c)
			_cut.append(c)
	for root: Node in _stripped.keys():
		if not is_instance_valid(root):
			_stripped.erase(root)


## The nodes in the tree under the actors' view, by class, and its direct children (one root per node enemy).
func actor_nodes_line() -> String:
	if not is_instance_valid(_actors_view) or not _actors_view.is_inside_tree():
		return "actor view nodes: (not in the tree)"
	var counts := {}
	var total := 0
	var stack: Array[Node] = [_actors_view]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		counts[n.get_class()] = int(counts.get(n.get_class(), 0)) + 1
		total += 1
	var keys: Array = counts.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return counts[a] > counts[b])
	var parts: PackedStringArray = []
	for k: String in keys:
		parts.append("%s=%d" % [k, counts[k]])
	var batched := 0
	if _actors_view.has_method(&"batched_count"):
		batched = int(_actors_view.call(&"batched_count"))
	return (
		"actor view nodes (last frame): total=%d direct_children=%d batched_enemies=%d  %s"
		% [total, _actors_view.get_child_count(), batched, ", ".join(parts)]
	)


func begin_measure() -> void:
	_events.clear()
	_draws.clear()
	_draw_frames.clear()
	_draw_n = 0
	_objects0 = _objects()


static func _objects() -> Array:
	return [
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
	]


## This frame's spans into `into` (microseconds), from `start` (the last probe _process) to `now` (this one).
func gather(start: int, now: int, into: Dictionary) -> void:
	into["count.canvas_dc"] = float(
		RenderingServer.viewport_get_render_info(
			_tree.root.get_viewport_rid(),
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
		)
	)
	if redraws:
		var n := 0
		for k: String in _draws:
			n += int(_draws[k])
			_draw_frames[k] = int(_draw_frames.get(k, 0)) + int(_draws[k])
		into["count.redraws"] = float(n)
		_draws.clear()
		_draw_n += 1
	if not on:
		return
	var last := start
	var at := "span.probe_script"
	var phys_steps := 0
	for e: Array in _events:
		var key: StringName = e[0]
		var t: int = e[1]
		if t < start:
			continue
		var next := ""
		match key:
			&"proc_first":
				next = "span.nodes_process"
			&"proc_last":
				next = "span.after_process"
			&"pre_draw":
				next = "span.draw"
			&"post_draw":
				next = "span.after_draw"
			&"phys_sig":
				next = "span.physics_pre"
				phys_steps += 1
			&"phys_first":
				next = "span.nodes_physics"
			&"phys_last":
				next = "span.physics_post"
		if next.is_empty():
			continue
		into[at] = float(into.get(at, 0.0)) + float(t - last)
		last = t
		at = next
	into[at] = float(into.get(at, 0.0)) + float(now - last)
	into["count.physics_steps"] = float(phys_steps)
	_events.clear()


## The report's lines: the settings that pace a frame, the span and script sums, the timers' own cost, the redraws
## and the orphans. `bk` is the probe's per-frame series (bucket -> PackedFloat64Array).
func report_lines(bk: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	(
		out
		. append(
			(
				(
					"pacing: vsync_mode=%d (0 off, 1 on, 2 adaptive, 3 mailbox) max_fps=%d low_processor=%s "
					+ "frame_queue_size=%s swapchain_images=%s thread_model=%s physics_tps=%d max_steps=%d "
					+ "physics_interpolation=%s disable_3d=%s window=%s root=%s"
				)
				% [
					DisplayServer.window_get_vsync_mode(),
					Engine.max_fps,
					OS.low_processor_usage_mode,
					ProjectSettings.get_setting(
						"rendering/rendering_device/vsync/frame_queue_size"
					),
					ProjectSettings.get_setting(
						"rendering/rendering_device/vsync/swapchain_image_count"
					),
					ProjectSettings.get_setting("rendering/driver/threads/thread_model"),
					Engine.physics_ticks_per_second,
					Engine.max_physics_steps_per_frame,
					_tree.physics_interpolation,
					_tree.root.disable_3d,
					DisplayServer.window_get_size(),
					_tree.root.size,
				]
			)
		)
	)
	out.append("ab_extra: " + ", ".join(_ab_extra()))
	out.append("hud_hide: " + (", ".join(hud_hide) if not hud_hide.is_empty() else "none"))
	var hud: Node = _main.get(&"_hud") if _main != null else null
	var still: HudStill = hud.get(&"still") if hud != null else null
	if still != null:
		for l in still.stats_lines():
			out.append("hud_still: " + l)
	out.append(actor_nodes_line())
	if _twin != null:
		out.append_array(_twin.call(&"report_lines"))
	if on:
		var total := 0.0
		var parts: PackedStringArray = []
		for k: String in SPAN_KEYS:
			var m := _mean(bk.get(k, PackedFloat64Array()))
			total += m
			parts.append("%s=%.0f" % [k.trim_prefix("span."), m])
		out.append("spans (us a frame, mean): %s  sum=%.0f" % ["  ".join(parts), total])
	var scripts := 0.0
	var nscripts := 0
	for k: String in bk:
		if k.begins_with("script."):
			scripts += _mean(bk[k])
			nscripts += 1
	(
		out
		. append(
			(
				"script.* buckets: %d, sum of their means %.0f us; probe.steal_total %.0f us (the walk + the calls)"
				% [nscripts, scripts, _mean(bk.get("probe.steal_total", PackedFloat64Array()))]
			)
		)
	)
	for k: String in ["engine.process", "engine.physics_process"]:
		if bk.has(k):
			var seen := {}
			for v in bk[k]:
				seen[v] = true
			out.append(
				"%s: %d distinct values over %d frames" % [k, seen.size(), (bk[k] as Array).size()]
			)
	out.append(timer_cost_line())
	if redraws:
		out.append_array(_redraw_lines())
	if orphans:
		out.append_array(_orphan_lines())
	return out


func _ab_extra() -> PackedStringArray:
	var out: PackedStringArray = []
	for f in _ab:
		if AB.has(f):
			out.append(f)
	if out.is_empty():
		out.append("none")
	return out


static func _mean(s: Variant) -> float:
	var t := 0.0
	var n := 0
	for v: float in s:
		t += v
		n += 1
	return t / maxf(n, 1)


## The cost of one empty timed span (two clock reads and a dictionary add, as PerfMarks does) and of one clock read.
static func timer_cost_line() -> String:
	var n := 100000
	var d := {}
	var t0 := Time.get_ticks_usec()
	for i in n:
		var s := Time.get_ticks_usec()
		d[&"k"] = int(d.get(&"k", 0)) + Time.get_ticks_usec() - s
	var span_ns := (Time.get_ticks_usec() - t0) * 1000.0 / n
	t0 = Time.get_ticks_usec()
	for i in n:
		Time.get_ticks_usec()
	var read_ns := (Time.get_ticks_usec() - t0) * 1000.0 / n
	return (
		"timer cost: one empty timed span %.0f ns, one clock read %.0f ns (%d each, this machine, now)"
		% [span_ns, read_ns, n]
	)


func _redraw_lines() -> PackedStringArray:
	var keys: Array = _draw_frames.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return _draw_frames[a] > _draw_frames[b])
	var out: PackedStringArray = [
		"redraws per measured frame by class<owner script> (%d frames):" % _draw_n
	]
	for k: String in keys.slice(0, 30):
		out.append("  %s %.2f" % [k, float(_draw_frames[k]) / maxf(_draw_n, 1)])
	return out


func _orphan_lines() -> PackedStringArray:
	var now := _objects()
	var out: PackedStringArray = [
		(
			"objects over the measure: objects %d -> %d, nodes %d -> %d, resources %d -> %d, orphans %d -> %d"
			% [
				_objects0[0],
				now[0],
				_objects0[1],
				now[1],
				_objects0[2],
				now[2],
				_objects0[3],
				now[3]
			]
		)
	]
	var drv: Node = _main.get(&"driver")
	var log: Array = drv.get(&"world").get(&"_events") if drv != null else []
	(
		out
		. append(
			(
				"the sim's event log holds %d SimEvent objects (RefCounted, not nodes; World.EVENT_LOG_CAP %d)"
				% [log.size(), World.EVENT_LOG_CAP]
			)
		)
	)
	var by := {}
	var roots := {}
	for id: int in Node.get_orphan_node_ids():
		var n := instance_from_id(id) as Node
		if n == null:
			continue
		var k := _owner_key(n)
		by[k] = int(by.get(k, 0)) + 1
		if n.get_parent() == null:  # the top of a detached branch
			roots[k] = int(roots.get(k, 0)) + 1
	for title: String in ["orphan nodes", "orphan branch tops"]:
		var d: Dictionary = by if title == "orphan nodes" else roots
		var keys: Array = d.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return d[a] > d[b])
		var parts: PackedStringArray = []
		for k: String in keys.slice(0, 25):
			parts.append("%s=%d" % [k, d[k]])
		out.append("%s by class<owner script>: %s" % [title, ", ".join(parts)])
	return out


## Puts a detached branch back (the probe quits next, or starts the next biome).
func restore() -> void:
	if _detached != null and _detached.get_parent() == null:
		_detached_parent.add_child(_detached)
	_detached = null
	ActorViews.batch_enemies = true
	for c in _cut:
		if is_instance_valid(c):
			c.free()
	_cut.clear()
	for h: Array in _hooks:
		var sig: Signal = h[0]
		if is_instance_valid(sig.get_object()) and sig.is_connected(h[1]):
			sig.disconnect(h[1])
	_hooks.clear()
	if _tree == null:
		return
	_tree.root.disable_3d = false
	if _ab.has("no_viewport"):
		RenderingServer.viewport_set_active(_tree.root.get_viewport_rid(), true)
