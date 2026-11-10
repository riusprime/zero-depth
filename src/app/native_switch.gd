class_name NativeSwitch
extends RefCounted
## The switch for the native collision passes (NativeMove), off by default: `-- --native-move` on the command line or
## ZD_NATIVE_MOVE=1 in the environment turns it on, when the game's GDExtension (native/zd_native.gdextension) has
## loaded its ZdMover class. Without the built library the class is missing and every world runs the GDScript passes.

const CLASS := &"ZdMover"
const ARG := "--native-move"
const ENV := "ZD_NATIVE_MOVE"


## Whether the native library is loaded.
static func available() -> bool:
	return ClassDB.class_exists(CLASS)


## Whether the command line or the environment asks for the native passes.
static func requested() -> bool:
	return ARG in OS.get_cmdline_user_args() or OS.get_environment(ENV) == "1"


## Turns the native passes on for every world made from now on (false: off, or the library is missing).
static func install(on: bool) -> bool:
	if on and available():
		World.mover_factory = func() -> Object: return ClassDB.instantiate(CLASS)
		return true
	World.mover_factory = Callable()
	return false


## install(requested()): what the game's start and the tools call.
static func install_from_args() -> bool:
	return install(requested())


## A fresh native mover for a benchmark, or null without the library.
static func make() -> Object:
	return ClassDB.instantiate(CLASS) if available() else null
