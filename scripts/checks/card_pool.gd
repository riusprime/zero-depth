extends SceneTree
## The card pool report (v0.5.0 CP): each build's distinct candidate cards (CardPoolSurvey.pool) and how often an
## altar and a chest offer each one over many seeds and reachable states (CardPoolSurvey.survey). Prints the table
## and writes build/card_pool.txt; paste it into evidence by hand. Exits 1 if a card in a pool is never offered or a
## pool is outside 40–50 cards.
##   godot --headless --path . -s scripts/checks/card_pool.gd -- seeds=300

var seeds := 300


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() == 2 and kv[0] == "seeds":
			seeds = int(kv[1])
	var repo := ContentRepository.load_all()
	var lines := PackedStringArray()
	var bad := 0
	for build in CardPoolSurvey.BUILDS:
		var p := CardPoolSurvey.pool(repo, build)
		var n := p[0].size() + p[1].size()
		lines.append(
			(
				"%s pool: %d in the data + %d planned %s = %d"
				% [build, p[0].size(), p[1].size(), p[1], n]
			)
		)
		if n < CardPoolSurvey.POOL_MIN or n > CardPoolSurvey.POOL_MAX:
			bad += 1
		var counts := CardPoolSurvey.survey(repo, build, seeds)
		lines.append_array(CardPoolSurvey.table(build, counts, p[0]))
		for k in p[0]:
			var c: Array = counts.get(k, [0, 0])
			if c[0] + c[1] == 0:
				lines.append("DEAD %s: %s" % [build, k])
				bad += 1
	DirAccess.make_dir_recursive_absolute("res://build")
	var f := FileAccess.open("res://build/card_pool.txt", FileAccess.WRITE)
	for l in lines:
		print(l)
		if f != null:
			f.store_line(l)
	print("card_pool: %s" % ("ok" if bad == 0 else "%d problems" % bad))
	quit(0 if bad == 0 else 1)
