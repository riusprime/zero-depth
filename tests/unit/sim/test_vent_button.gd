extends GutTest
## The Vent button (v0.3.5 K, owner F1) with the shipped heat data: dash and blink no longer vent, a press during
## hit-stop waits for it, and overheated the button only clicks. (Venting while Hot and its blast: test_heat.gd.)

const P := InputFrame.PRIMARY
const S := InputFrame.SHOOT
const U := InputFrame.UTILITY
const D := InputFrame.DASH
const V := InputFrame.VENT
const M := HeatTable.MILLI

var _repo: ContentRepository
var _items: Array[ItemTable] = []
var _heat: HeatTable


func before_all() -> void:
	_repo = ContentRepository.load_all()
	_items = ContentCompiler.compile_items(_repo)
	_heat = ContentCompiler.compile_heat(_repo.get_def(&"heat", &"overclock"))


func _index(id: StringName) -> int:
	for i in _items.size():
		if _items[i].id == id:
			return i
	return -1


## The runner (four-slash combo) with heat, the item tables, the given items owned, still dummies at `enemies`.
func _world(
	items: Array = [], enemies: Array = [Vector2(1.2, 0)], utility: int = PlayerTable.Utility.NONE
) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	t.utility = utility
	var w := World.new(5, t)
	w.dummy_speed = 0.0
	w.set_item_tables(_items)
	Heat.enable(w, _heat)
	for id: StringName in items:
		assert_true(w.add_item(_index(id)), "added %s" % id)
	for at: Vector2 in enemies:
		w.add_dummy(at, 0.35, 5000)
	return w


func _f(held: int = 0, pressed: int = 0, aim: int = 0, move := Vector2i.ZERO) -> InputFrame:
	return InputFrame.make(move, aim, 300, held, pressed)


func _idle(w: World, n: int, held: int = 0) -> void:
	for i in n:
		w.step(_f(held))


## Presses attack and steps until the swing and its hit-stop are over.
func _swing(w: World) -> void:
	w.step(_f(0, P))
	for k in 120:
		if w.swing_t == 0 and w.freeze_ticks == 0 and w.input_buffer[0] == 0:
			break
		w.step(_f())


func _events(w: World, kind: SimEvent.Kind, effect := &"", after: int = 0) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(after):
		if e.kind == kind and (effect == &"" or e.effect_id == effect):
			out.append(e)
	return out


func test_dash_and_blink_no_longer_vent() -> void:
	# v0.3.5 K (owner F1): venting moved to its own button.
	var w := _world([], [Vector2(1.5, 0)])
	w.heat.milli = 60 * M
	w.step(_f(0, D, 0, Vector2i(0, 127)))
	assert_true(w.is_dashing(), "the dash went")
	assert_eq(_events(w, SimEvent.Kind.HIT, Heat.EFFECT_VENT).size(), 0, "a Hot dash vents nothing")
	assert_eq(w.heat.vent_tick, -1)
	assert_true(Heat.hot(w), "still Hot")
	var b := _world([], [Vector2(5, 1.0)], PlayerTable.Utility.BLINK)
	b.heat.milli = 60 * M
	b.step(_f(0, U, 0, Vector2i(127, 0)))
	assert_eq(b.blink_tick, 0, "the blink went")
	assert_eq(
		_events(b, SimEvent.Kind.HIT, Heat.EFFECT_VENT).size(), 0, "a Hot blink vents nothing"
	)
	b.step(_f(0, V))
	var blast := _events(b, SimEvent.Kind.HIT, Heat.EFFECT_VENT)
	assert_eq(blast.size(), 1, "blinked 5 m next to the enemy, then the Vent button vented there")
	assert_eq(blast[0].amount, 30)
	assert_eq(b.heat.milli, 0)


func test_a_vent_press_during_hit_stop_waits_for_it() -> void:
	var w := _world([], [Vector2(1.5, 0)])
	w.heat.milli = 60 * M
	w.add_freeze(3)
	w.step(_f(0, V))
	assert_eq(w.heat.vent_tick, -1, "frozen: buffered")
	_idle(w, 3)
	assert_gt(w.heat.vent_tick, -1, "vented once the hit-stop ended")
	assert_eq(_events(w, SimEvent.Kind.VENT).size(), 1, "once")


func test_overheated_the_vent_button_does_nothing() -> void:
	var w := _world()
	Heat.add(w, 100 * M)
	assert_true(Heat.stalled(w))
	var seq := w.last_event_seq()
	w.step(_f(0, V))
	assert_eq(_events(w, SimEvent.Kind.HIT, Heat.EFFECT_VENT, seq).size(), 0)
	assert_eq(_events(w, SimEvent.Kind.VENT_COLD, &"", seq).size(), 1, "a cold click")
	assert_true(Heat.stalled(w), "the stall runs on")
