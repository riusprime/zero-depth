extends SceneTree
## v0.10.5 PC (owner PERF_PLAYLOG_2: ~2,300 more nodes after the effect pools were filled at load): how many nodes sit
## in the scene tree on a built floor, and how many of them are the effect pools'. Starts a run in the real main.tscn,
## waits for the floor and its cover to open, then walks the tree and prints the totals and each pool owner's count
## (in the tree, and idle entries held outside it). A tool, not a test; writes nothing into the tree.
##   godot --headless --fixed-fps 60 --path . -s scripts/checks/pool_node_count.gd
## OBJECT_NODE_COUNT (the perf log's `nodes` column) counts the nodes in the tree; OBJECT_ORPHAN_NODE_COUNT the
## ones out of it.
const LIMIT_MS := 180000

var main: Main


func _initialize() -> void:
	ProfileStore.use_shared(ProfileStore.new(""))
	RunSaveStore.use_shared(RunSaveStore.new(""))
	Main.fixed_seed = Main.STAGE_SEED
	main = (load("res://src/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


static func _count(n: Node) -> int:
	var total := 1
	for c in n.get_children(true):
		total += _count(c)
	return total


func _run() -> void:
	await _frames(5)
	main.loads.behind(self, main.ui, main._covered_start, Main.FADE_SECONDS)
	var from := Time.get_ticks_msec()
	await _frames(3)
	while Time.get_ticks_msec() - from < LIMIT_MS:
		if main.driver != null and not main.loads.cover.showing() and not main.loads.call("busy"):
			break
		await process_frame
	await _frames(90)
	var v: Node = main.view
	print("pool_nodes: tree=%d" % _count(root))
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("pool_nodes: object_node_count=%d" % nodes)
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	print("pool_nodes: orphan_node_count=%d" % orphans)
	print("pool_nodes: view=%d" % _count(v))
	for key in [&"pack_fx", &"telegraphs", &"status_fx", &"elite_fx", &"fireballs"]:
		var n: Variant = v.get(key)
		if n is Node:
			var held := 0
			if (n as Node).has_method(&"idle_outside"):
				held = int((n as Node).call(&"idle_outside"))
			print("pool_nodes: %-10s in_tree=%d idle_outside=%d" % [key, _count(n), held])
		else:
			print("pool_nodes: %-10s (not found)" % key)
	quit(0)
