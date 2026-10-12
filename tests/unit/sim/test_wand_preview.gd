extends GutTest
## v0.6.5 WN2 (docs/design/WAND.md rule 4; EI-07): the Build page and the Swap panel preview a move with the same pure
## rules the sim applies. For every move of a full 8-slot wand, the preview (Wand.moved_read through WorldReader) is
## what WorldReader.wand() reads after the sim takes the move as input; the fewest-moves plan (Wand.plan_moves) turns
## any order into any other through InputFrames; a Swap's replace and insert preview (Wand.swapped_read) is what the
## sim holds after its picks (Wand.swap_picks) arrive one per tick.

const EIGHT: Array = [
	&"ember_edge",
	&"trigger_on_hit",
	&"long_edge",
	&"twin_arc",
	&"trigger_on_kill",
	&"serrated_edge",
	&"wide_arc",
	&"echo_slash",
]

var _repo: ContentRepository


func before_all() -> void:
	_repo = AttackScenario.repo()


func _world(f: int = 3) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	var w := World.new(5, t)
	w.floor_index = f
	w.dummy_speed = 0.0
	w.wand_table = WandCompiler.from_repo(_repo)
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.set_combo_tables(ContentCompiler.compile_combos(_repo))
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	for id: StringName in EIGHT:
		assert_true(BuildSlots.take(w, WandLab.code(w, id)), "takes %s" % id)
	return w


func _pick(v: int) -> InputFrame:
	var f := InputFrame.make(Vector2i.ZERO, 0, 300, 0, 0)
	f.pick = v
	return f


func _codes(read: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	for c: Dictionary in read["cards"]:
		out.append(int(c["code"]))
	return out


func test_every_move_previews_what_the_sim_reads_after_it() -> void:
	var w := _world()
	assert_eq(w.mod_slots.size(), 8, "a full 8-slot wand on floor 3")
	var checked := 0
	for from in 8:
		for to in 8:
			var before := WorldReader.new(w).wand()
			var preview := WorldReader.wand_moved(before, from, to)
			w.step(_pick(InputFrame.wand_move(from, to)))
			var after := WorldReader.new(w).wand()
			assert_eq(_codes(preview), _codes(after), "move %d → %d: the cards" % [from, to])
			assert_eq(preview["cuts"], after["cuts"], "move %d → %d: the cuts" % [from, to])
			assert_eq(
				WorldReader.wand_describe(preview),
				WorldReader.wand_describe(after),
				"move %d → %d: the read-back" % [from, to]
			)
			checked += 1
	assert_eq(checked, 64)


func test_a_refused_move_previews_no_change() -> void:
	var w := _world()
	var read := WorldReader.new(w).wand()
	for m: Vector2i in [Vector2i(0, 0), Vector2i(-1, 2), Vector2i(2, 8), Vector2i(9, 1)]:
		assert_false(WorldReader.wand_can_move(8, m.x, m.y))
		assert_eq(_codes(WorldReader.wand_moved(read, m.x, m.y)), _codes(read))


func test_the_plan_turns_any_order_into_any_other_through_input() -> void:
	var w := _world()
	var rng := RandomNumberGenerator.new()  # test-side only: the permutations to reach
	rng.seed = 6502
	for trial in 40:
		var target := w.mod_slots.duplicate()
		for k in range(target.size() - 1, 0, -1):  # Fisher-Yates
			var j := rng.randi_range(0, k)
			var t := target[k]
			target[k] = target[j]
			target[j] = t
		var plan := WorldReader.wand_plan_moves(w.mod_slots, target)
		assert_true(plan.size() <= 7, "at most one move per slot but the last")
		for v in plan:
			w.step(_pick(v))
		assert_eq(w.mod_slots, target, "trial %d reached its order" % trial)
	assert_eq(WorldReader.wand_plan_moves(w.mod_slots, w.mod_slots).size(), 0, "no change, no move")


func test_the_swap_preview_is_what_the_sim_holds_after_its_picks() -> void:
	for leave in 8:
		for at in 8:
			var w := _world()
			Offers.apply(w, AttackScenario.item_index(w.item_tables, &"overcharge"))
			assert_true(BuildSlots.swapping(w))
			var read := WorldReader.new(w).wand()
			assert_false((read["incoming"] as Dictionary).is_empty(), "the read holds the offer")
			var preview := WorldReader.wand_swapped(read, leave, at)
			for v in WorldReader.wand_swap_picks(leave, at):
				w.step(_pick(v))
			assert_false(BuildSlots.swapping(w), "answered")
			var after := WorldReader.new(w).wand()
			assert_eq(_codes(preview), _codes(after), "leave %d, at %d" % [leave, at])
			assert_eq(preview["cuts"], after["cuts"])
			assert_true((after["incoming"] as Dictionary).is_empty())
