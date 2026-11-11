class_name NativeSwitch
extends RefCounted
## The switch for the native kernels (NativeWorld), each switched on by its own name when the game's GDExtension
## (native/zd_native.gdextension) has loaded its ZdWorld class:
## - the command line: `-- --native=move,ai,strike,shots,nav` (any of them, or `all`; `0` or `none`: none);
##   `-- --native-move` is `move`;
## - the environment: ZD_NATIVE_MOVE=1, ZD_NATIVE_AI=1, ZD_NATIVE_STRIKE=1, ZD_NATIVE_SHOTS=1, ZD_NATIVE_NAV=1, or
##   ZD_NATIVE_ALL=1 (what the tests' pre-run hook reads).
## The game's start (install_for_game) turns every kernel on when neither asks, so the owner plays the native core;
## a World built without Main (a unit test, a tool) stays on the script sim unless something installs kernels.
## Without the built library the class is missing and every world runs GDScript, silently.

const CLASS := &"ZdWorld"
const ARG := "--native="
const ARG_MOVE := "--native-move"
const ENV := "ZD_NATIVE_"
## The dev panel's switch id (DebugApi.view_switches) and its button's text.
const SWITCH := &"native"
const SWITCH_KEY := "UI_DEV_NATIVE"

## The kernels the dev panel's "Native core" switch turns back on: the set the game started with, or every kernel
## when it started with none.
static var core_kernels := NativeWorld.ALL


## Whether the native library is loaded.
static func available() -> bool:
	return ClassDB.class_exists(CLASS)


## The kernels a spec names: "move,ai" (NativeWorld.NAMES), "all", "1" (move: the older form) or "0" / "none" / ""
## (none); -1 when it names a kernel there isn't.
static func parse(spec: String) -> int:
	var s := spec.strip_edges().to_lower()
	if s == "" or s == "0" or s == "none":
		return 0
	if s == "1":
		return NativeWorld.MOVE
	var bits := 0
	for part in s.split(",", false):
		var p := part.strip_edges()
		if p == "all":
			bits |= NativeWorld.ALL
		elif NativeWorld.NAMES.has(StringName(p)):
			bits |= int(NativeWorld.NAMES[StringName(p)])
		else:
			return -1
	return bits


## The kernels the command line and the environment ask for (0: none). A spec that names an unknown kernel is
## reported and asks for none.
static func requested() -> int:
	var bits := 0
	for arg in OS.get_cmdline_user_args():
		if arg == ARG_MOVE:
			bits |= NativeWorld.MOVE
		elif arg.begins_with(ARG):
			var got := parse(arg.substr(ARG.length()))
			if got < 0:
				push_error(
					"NativeSwitch: unknown kernel in %s (move, ai, strike, shots, nav, all)" % arg
				)
				return 0
			bits |= got
	if OS.get_environment(ENV + "ALL") == "1":
		bits |= NativeWorld.ALL
	for k: StringName in NativeWorld.NAMES:
		if OS.get_environment(ENV + String(k).to_upper()) == "1":
			bits |= int(NativeWorld.NAMES[k])
	return bits


## Whether the command line or the environment says anything about the kernels (even "none").
static func asked() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == ARG_MOVE or arg.begins_with(ARG):
			return true
	if OS.get_environment(ENV + "ALL") != "":
		return true
	for k: StringName in NativeWorld.NAMES:
		if OS.get_environment(ENV + String(k).to_upper()) != "":
			return true
	return false


## The kernels the game starts with: what the command line or the environment asks for, else every one.
static func for_game() -> int:
	return requested() if asked() else NativeWorld.ALL


## Turns the kernels in `kernels` on for every world made from now on, and every other one off. Returns the kernels
## now on: 0 when none are asked for or the library is missing.
static func install(kernels: int) -> int:
	if kernels != 0 and available():
		# A static function, not a lambda: a lambda left in the static var at exit crashed the engine on quit
		World.native_factory = NativeSwitch.make
		World.native_kernels = kernels & NativeWorld.ALL
		return World.native_kernels
	World.native_factory = Callable()
	World.native_kernels = 0
	return 0


## install(requested()): what the tools call (no argument: the script sim).
static func install_from_args() -> int:
	return install(requested())


## The game's start: installs for_game() (nothing without the library), registers the dev panel's switch when the
## library is loaded, and puts back what was installed before when `main` leaves the tree, so a test that builds a
## World after an e2e's Main is gone runs the sim it ran before. Returns the kernels now on.
static func install_for_game(main: Node) -> int:
	main.tree_exiting.connect(
		NativeSwitch._restore.bind(World.native_factory, World.native_kernels, EnemyBatch.native),
		CONNECT_ONE_SHOT
	)
	var on := install(for_game())
	EnemyBatch.native = on != 0  # The batched enemies' native writer goes with the core
	if on != 0:
		core_kernels = on
	if available():
		DebugApi.register_view_switch(
			SWITCH, SWITCH_KEY, NativeSwitch.flip_core, NativeSwitch.core_on
		)
	print("NativeSwitch: native kernels on: %s" % (NativeWorld.names_of(on) if on != 0 else "none"))
	return on


## Whether worlds made from now on get native kernels.
static func core_on() -> bool:
	return World.native_kernels != 0


## The dev panel's switch: off goes to the script sim, on gives core_kernels again. A live World keeps the kernels
## it was made with (its native caches are set up at its start), so the change applies from the next floor or run;
## the batched enemies' native writer (EnemyBatch.native) follows it from the next frame.
static func flip_core() -> void:
	install(0 if core_on() else core_kernels)
	EnemyBatch.native = core_on()


static func _restore(factory: Callable, kernels: int, crowd: bool) -> void:
	World.native_factory = factory
	World.native_kernels = kernels
	EnemyBatch.native = crowd
	DebugApi.view_switches.erase(SWITCH)


## A fresh native side for a benchmark or a test, or null without the library.
static func make() -> Object:
	return ClassDB.instantiate(CLASS) if available() else null
