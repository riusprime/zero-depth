class_name GdSource
extends RefCounted
## Helpers for the architecture lint: list .gd files and strip comments and string literals.


static func files_under(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var path := dir.path_join(name)
		if d.current_is_dir():
			out.append_array(files_under(path))
		elif name.ends_with(".gd"):
			out.append(path)
		name = d.get_next()
	out.sort()
	return out


## Source with comments and string contents blanked, so tokens only match real code.
static func code_only(text: String) -> String:
	var out := PackedStringArray()
	for line in text.split("\n"):
		var buf := ""
		var quote := ""
		var i := 0
		while i < line.length():
			var ch := line[i]
			if quote != "":
				if ch == "\\":
					i += 2
					continue
				if ch == quote:
					quote = ""
					buf += ch
				i += 1
				continue
			if ch == "#":
				break
			if ch == '"' or ch == "'":
				quote = ch
			buf += ch
			i += 1
		out.append(buf)
	return "\n".join(out)


static func read(path: String) -> String:
	return FileAccess.get_file_as_string(path)
