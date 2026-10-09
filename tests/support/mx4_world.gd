class_name Mx4World
extends RefCounted
## v0.6.0 MX4: small fixed worlds for the M-list's unit tests (tests/unit/sim/test_mx4_*.gd): the runner with the
## Blade or the Gun (crit off, so numbers are exact), the shipped items, combos, abilities and stat cards, standing
## dummies where a test puts them, and the inputs a test scripts. No randomness beyond the world's own streams.

const P := InputFrame.PRIMARY
const S := InputFrame.SHOOT
const D := InputFrame.DASH
const V := InputFrame.VENT

static var _repo: ContentRepository


static func repo() -> ContentRepository:
	if _repo == null:
		_repo = ContentRepository.load_all()
	return _repo


## A `build` (&"blade", &"gun") world holding `items` (ids) and `abilities` (ids), heat on with `heat`, and a
## standing dummy at each [position, hp] of `enemies`.
static func world(
	build: StringName,
	items: Array = [],
	enemies: Array = [],
	abilities: Array = [],
	heat: bool = false,
	seed_value: int = 9
) -> World:
	var r := repo()
	var t := ContentCompiler.compile_player(r.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, r.get_def(&"build", build))
	t.crit_chance_permille = 0
	var w := World.new(seed_value, t)
	w.dummy_speed = 0.0
	w.set_item_tables(ContentCompiler.compile_items(r))
	w.set_combo_tables(ContentCompiler.compile_combos(r))
	w.ability_tables = ContentCompiler.compile_abilities(r)
	w.stat_tables = ContentCompiler.compile_stat_cards(r)
	if heat:
		Heat.enable(w, ContentCompiler.compile_heat(r.get_def(&"heat", &"overclock")))
	Abilities.grant_start(w)
	for id: StringName in abilities:
		for k in w.ability_tables.size():
			if w.ability_tables[k].id == id:
				Abilities.grant(w, k)
	for id: StringName in items:
		w.add_item(item(w, id))
	Abilities.start_floor(w)
	for e: Array in enemies:
		w.add_dummy(e[0], 0.35, e[1])
	return w


static func item(w: World, id: StringName) -> int:
	return AttackScenario.item_index(w.item_tables, id)


static func frame(
	pressed: int = 0, held: int = 0, aim: int = 0, move := Vector2i.ZERO
) -> InputFrame:
	return InputFrame.make(move, aim, 300, held, pressed)


## Steps `n` ticks of the same input.
static func run(
	w: World, n: int, pressed: int = 0, held: int = 0, aim: int = 0, move := Vector2i.ZERO
) -> void:
	for k in n:
		w.step(frame(pressed if k == 0 else 0, held, aim, move))


## Every event of `kind` (and `effect`, unless &"*") since the log began.
static func events(w: World, kind: int, effect: StringName = &"*") -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(0):
		if e.kind == kind and (effect == &"*" or e.effect_id == effect):
			out.append(e)
	return out


## The DAMAGE events the player dealt with `effect`.
static func damage(w: World, effect: StringName) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	var pid := w.actors.ids[0]
	for e in events(w, SimEvent.Kind.DAMAGE, effect):
		if e.owner_id == pid and e.target_id != pid:
			out.append(e)
	return out


## The distinct targets of `evs`.
static func targets(evs: Array[SimEvent]) -> Array:
	var out := []
	for e in evs:
		if not out.has(e.target_id):
			out.append(e.target_id)
	return out


## The player's projectiles now that run the spec filed under a key starting with `prefix` (a hook child's key is
## "<parent key>/<n>").
static func projectiles_of(w: World, spec_id: StringName) -> int:
	var n := 0
	var p := w.projectiles
	for i in p.size():
		if p.team[i] != ActorStore.TEAM_PLAYER:
			continue
		var s := Modifiers.book(w).find(p.spec_key[i])
		if s != null and s.id == spec_id:
			n += 1
	return n


## The first hook of `spec` added by modifier `id`, or null.
static func hook_of(spec: AttackSpec, id: StringName) -> AttackHook:
	for k in spec.hooks:
		if k.id == id:
			return k
	return null
