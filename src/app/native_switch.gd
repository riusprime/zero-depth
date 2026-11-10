class_name NativeSwitch
extends RefCounted
## The switch for the native kernels (NativeWorld), all off by default, each switched on by its own name when the
## game's GDExtension (native/zd_native.gdextension) has loaded its ZdWorld class:
## - the command line: `-- --native=move,ai,strike,shots,nav` (any of them, or `all`); `-- --native-move` is `move`;
## - the environment: ZD_NATIVE_MOVE=1, ZD_NATIVE_AI=1, ZD_NATIVE_STRIKE=1, ZD_NATIVE_SHOTS=1, ZD_NATIVE_NAV=1, or
##   ZD_NATIVE_ALL=1 (what the tests' pre-run hook reads).
## Without the built library the class is missing and every world runs GDScript.

const CLASS := &"ZdWorld"
const ARG := "--native="
const ARG_MOVE := "--native-move"
const ENV := "ZD_NATIVE_"


## Whether the native library is loaded.
static func available() -> bool:
	return ClassDB.class_exists(CLASS)


## The kernels a spec names: "move,ai" (NativeWorld.NAMES), "all", "1" (move: the older form) or "0" / "" (none);
## -1 when it names a kernel there isn't.
static func parse(spec: String) -> int:
	var s := spec.strip_edges().to_lower()
	if s == "" or s == "0":
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


## install(requested()): what the game's start and the tools call.
static func install_from_args() -> int:
	return install(requested())


## A fresh native side for a benchmark or a test, or null without the library.
static func make() -> Object:
	return ClassDB.instantiate(CLASS) if available() else null
