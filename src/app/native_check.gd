class_name NativeCheck
extends RefCounted
## The game's start without its native library (native/README.md): the sim's hot loops run only there
## (NativeWorld), so the game does not start without it. It reports NativeWorld.MISSING (once, as an error), shows it in a
## dialog when there is a display, and quits with exit code 1.


## True when the library is loaded. Otherwise reports it, asks `main`'s tree to quit with 1, and returns false (the
## caller stops its start).
static func passes(main: Node) -> bool:
	if NativeWorld.available():
		return true
	NativeWorld.report_missing()
	if DisplayServer.get_name() != "headless":
		OS.alert(NativeWorld.MISSING, "Zero Depth")
	main.process_mode = Node.PROCESS_MODE_DISABLED  # Nothing else of the start runs meanwhile
	main.get_tree().quit(1)
	return false
