extends SceneTree
## v0.8.0 AO (owner O37: "currently the order does not matter that much"): how much the wand's card order matters.
## For each weapon it takes every wand card its runs can hold (the weapon's pool, the shared pool and the triggers),
## compiles every pair in both orders (Modifiers.compile_for on WandLab's world) and compares what each attack does:
## the book's specs hashed with the list of the cards that wrote them cleared (that list always follows the order, so
## it would make every pair differ). With --fight=a|b,c|d it also fights those pairs both ways (WandLab.run, 360 ticks
## of AttackScenario) and compares the event digests. With --chains=a+b+c,d+e it prints what each wand (cards in that
## order, on the Gun) does to the shot: its form, count, the AO ring layout and the fight's numbers.
## Prints only (no file written).
##   godot --headless --path . -s scripts/checks/order_audit.gd [-- --fight=a|b] [-- --chains=a+b+c] [-- --no-pairs]

const FIGHT_TICKS := 360


func _initialize() -> void:
	var fights: Array = []
	var chains: Array = []
	var pairs := true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fight="):
			for p in a.get_slice("=", 1).split(",", false):
				fights.append(p.split("|"))
		elif a.begins_with("--chains="):
			for c in a.get_slice("=", 1).split(",", false):
				chains.append(c.split("+"))
		elif a == "--no-pairs":
			pairs = false
	if pairs:
		for weapon: StringName in [&"gun", &"blade"]:
			_pairs(weapon)
	for p: PackedStringArray in fights:
		var ab := WandLab.run(
			WandLab.fight(&"gun", [StringName(p[0]), StringName(p[1])]), FIGHT_TICKS
		)
		var ba := WandLab.run(
			WandLab.fight(&"gun", [StringName(p[1]), StringName(p[0])]), FIGHT_TICKS
		)
		print("fight gun %s|%s events_same=%s" % [p[0], p[1], str(ab["digest"] == ba["digest"])])
	for c: PackedStringArray in chains:
		_chain(c)
	quit()


static func _cards(w: World, weapon: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for k in w.item_tables.size():
		var t := w.item_tables[k]
		if t.modifiers.is_empty():
			continue
		if not CardLevels.is_card(w, k) and not t.modifiers[0].is_trigger():
			continue
		if weapon == &"gun" and t.requires_weapon == PlayerTable.WEAPON_BLADE:
			continue
		if weapon == &"blade" and t.requires_weapon == PlayerTable.WEAPON_GUN:
			continue
		ids.append(t.id)
	ids.sort()
	return ids


static func _pairs(weapon: StringName) -> void:
	var w := WandLab.world(weapon)
	var ids := _cards(w, weapon)
	var diff: Array[String] = []
	var same := 0
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a := WandLab.card(ids[i])
			var b := WandLab.card(ids[j])
			var ab: Array[ModifierTable] = [a, b]
			var ba: Array[ModifierTable] = [b, a]
			if _sem(Modifiers.compile_for(w, ab)) != _sem(Modifiers.compile_for(w, ba)):
				diff.append("%s|%s" % [ids[i], ids[j]])
			else:
				same += 1
	print(
		(
			"%s cards=%d pairs=%d order_matters=%d order_free=%d"
			% [weapon, ids.size(), same + diff.size(), diff.size(), same]
		)
	)
	var per := {}
	for p in diff:
		for c in p.split("|"):
			per[c] = int(per.get(c, 0)) + 1
	var rows := PackedStringArray()
	for c in ids:
		rows.append("%s=%d" % [c, int(per.get(String(c), 0))])
	print("%s per-card order-sensitive pairs: %s" % [weapon, " ".join(rows)])
	var plain := PackedStringArray()  # the pairs with no trigger and no Split in them
	for p in diff:
		if not ("trigger" in p or "split_shot" in p):
			plain.append(p)
	print("%s order-sensitive pairs without a trigger or Split: %s" % [weapon, " ".join(plain)])


## The book's specs hashed with their writers' list cleared (class doc).
static func _sem(b: AttackBook) -> String:
	var h := StateHasher.new()
	for id in b.order:
		var s: AttackSpec = b.specs[StringName(id)]
		_clear(s)
		s.hash_into(h)
	return h.finish_hex()


static func _clear(s: AttackSpec) -> void:
	s.modifier_ids = PackedStringArray()
	for k in s.hooks:
		_clear(k.child)


static func _chain(ids: PackedStringArray) -> void:
	var cards: Array = []
	for id in ids:
		cards.append(StringName(id))
	var w := WandLab.fight(&"gun", cards)
	var s := Modifiers.bolt(w)
	var dmg := 0
	var hits := 0
	var shocked := 0
	var rings_max := 0
	var seen := 0
	for t in FIGHT_TICKS:
		w.step(AttackScenario.frame(t))
		rings_max = maxi(rings_max, w.ab.ring_pos.size())
		for e in w.events_since(seen):
			seen = e.seq
			if e.kind == SimEvent.Kind.HIT and e.source_id == w.actors.ids[0]:
				dmg += e.amount
				hits += 1
			if "shock" in String(e.effect_id) or "storm" in String(e.effect_id):
				shocked += 1
	print(
		(
			"chain %s: form=%d count=%d ring_layout=%d pulses=%d share=%d swirl=%d swirl_group=%d"
			% [
				" -> ".join(ids),
				s.form,
				s.count,
				s.ring_layout,
				s.ring_pulses,
				s.ring_share_permille,
				s.swirl,
				s.swirl_group,
			]
		)
	)
	print(
		(
			"  %d ticks: player hits=%d damage=%d (%.1f per s) shock/storm events=%d rings alive max=%d"
			% [FIGHT_TICKS, hits, dmg, dmg * 60.0 / FIGHT_TICKS, shocked, rings_max]
		)
	)
