extends SceneTree
## The cost of the columns crossing by name (NATIVE_CORE.md §2.2): an ActorStore of N rows, and the native side
## reading C of its columns with Object::get (each comes back sharing the store's buffer), then sending each back as
## a new array of the same values with Object::set. Prints, per column and call, the native clock's ns reading and
## writing (ZdWorld.bench_columns), and the whole call timed from GDScript. Needs the native library. Writes nothing.
##   godot --headless --path . -s scripts/bench/native_columns_bench.gd [-- --rows=121,500] [-- --reps=2000]

const NAMES: Array[String] = [
	"pos_x",
	"pos_y",
	"radius",
	"kinds",
	"dead",
	"state",
	"state_t",
	"cd",
	"fire_cd",
	"facing",
	"lock_x",
	"lock_y",
	"lock_a",
	"lock_len",
	"windup",
	"pick",
	"plan_x",
	"plan_y",
	"plan_block",
	"frozen_t",
	"hp",
	"max_hp",
	"ids",
	"slow_t",
	"power"
]


func _initialize() -> void:
	var args := ScriptArgs.parse()
	var m: Object = NativeWorld.make()
	if m == null:
		push_error("native_columns_bench: the native library is not loaded")
		quit(1)
		return
	var rows := PackedInt32Array([121, 500])
	if args.has("--rows"):
		rows = PackedInt32Array()
		for s in String(args["--rows"]).split(","):
			rows.append(int(s))
	var reps := int(args.get("--reps", 2000))
	for n in rows:
		var w := World.new(5, PlayerTable.starting_values())
		for i in n - 1:
			w.add_dummy(Vector2(i % 20, i / 20), 0.4, 10)
		for c in [1, 3, 10, 25]:
			_measure(m, w.actors, n, c, reps)
	quit(0)


func _measure(m: Object, store: ActorStore, n: int, c: int, reps: int) -> void:
	var names := PackedStringArray(NAMES.slice(0, c))
	var reads: PackedInt64Array = m.bench_columns(store, names, reps, false)
	var both: PackedInt64Array = m.bench_columns(store, names, reps, true)
	var t0 := Time.get_ticks_usec()
	for r in reps:
		m.bench_columns(store, names, 1, false)
	var call_us := float(Time.get_ticks_usec() - t0) / reps
	print(
		(
			"rows=%d columns=%d  get %.0f ns/column  set %.0f ns/column  read call from GDScript %.2f us"
			% [n, c, float(reads[0]) / (reps * c), float(both[1]) / (reps * c), call_us]
		)
	)
