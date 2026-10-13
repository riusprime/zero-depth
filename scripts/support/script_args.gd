class_name ScriptArgs
extends RefCounted
## The tool scripts' command line (`godot ... -s <script> -- key=value ...`) as a dictionary: every user argument
## that holds "=" becomes key -> value (split at the first "="; a later repeat wins). Keys are kept exactly as typed,
## so a script reading "--only" and one reading "mode" each keep the spelling their documented commands use.


static func parse(args: PackedStringArray = OS.get_cmdline_user_args()) -> Dictionary:
	var out := {}
	for arg in args:
		var kv := arg.split("=", true, 1)
		if kv.size() == 2:
			out[kv[0]] = kv[1]
	return out
