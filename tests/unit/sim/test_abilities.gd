extends GutTest
## The four ability slots (v0.4.0 BS, owner F8, F11) with the shipped data: slot 1 is the build's weapon, cards
## fill slots 2-4 and then only level up; Bomb Lobber, Drone Buddy and Orbit Blades (damage, targeting, cooldowns,
## levels, determinism); Blink and Aegis on the utility button (exclusive); the run carry and the state hash.
## Crit is switched off here (crit_chance_permille = 0) so damage numbers are exact; test_stats covers crit.

const U := InputFrame.UTILITY

var _repo: ContentRepository
var _abilities: Array[AbilityTable] = []


func before_all() -> void:
	_repo = ContentRepository.load_all()
	_abilities = ContentCompiler.compile_abilities(_repo)


## The runner with `build` (or none), the shipped abilities and stat cards, still dummies at `enemies`.
func _world(build: StringName = &"blade", enemies: Array = [], hp: int = 5000) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	if build != &"":
		ContentCompiler.apply_build(t, _repo.get_def(&"build", build))
	t.crit_chance_permille = 0
	var w := World.new(11, t)
	w.dummy_speed = 0.0
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	for at: Vector2 in enemies:
		w.add_dummy(at, 0.35, hp)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	return w


func _by(id: StringName) -> AbilityTable:
	for t in _abilities:
		if t.id == id:
			return t
	return null


func _idx(w: World, kind: int) -> int:
	return Abilities.index_of_kind(w, kind)


func _f(pressed: int = 0, move := Vector2i.ZERO, held: int = 0) -> InputFrame:
	return InputFrame.make(move, 0, 300, held, pressed)


func _run(w: World, n: int) -> void:
	for i in n:
		w.step(_f())


func _damage(w: World, effect: StringName, after: int = 0) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(after):
		if e.kind == SimEvent.Kind.DAMAGE and e.effect_id == effect:
			out.append(e)
	return out


# --- Data and slots -----------------------------------------------------------------------------------------
func test_the_shipped_abilities_compile() -> void:
	var ids := []
	for t in _abilities:
		ids.append(String(t.id))
	for id in ["aegis", "blink", "combo_sword", "pulse_gun"]:
		assert_true(ids.has(id), "%s ships" % id)
	var blink := _by(&"blink")
	assert_eq(
		blink.level_cooldown,
		PackedInt32Array([900, 840, 780, 720, 660]),
		"-1 s per level (15 s to 11 s)"
	)
	assert_eq(blink.level_extra, PackedInt32Array([1, 1, 2, 2, 2]), "a second charge at L3")
	assert_eq(_by(&"combo_sword").start_weapon, PlayerTable.WEAPON_BLADE)
	assert_eq(_by(&"pulse_gun").start_weapon, PlayerTable.WEAPON_GUN)


func test_slot_one_is_the_builds_weapon() -> void:
	var blade := _world(&"blade")
	assert_eq(blade.ability_owned, PackedInt32Array([_idx(blade, AbilityTable.Kind.COMBO_SWORD)]))
	assert_eq(blade.ability_levels, PackedInt32Array([1]))
	var gun := _world(&"gun")
	assert_eq(gun.ability_owned, PackedInt32Array([_idx(gun, AbilityTable.Kind.PULSE_GUN)]))
	var none := _world(&"")
	assert_true(none.ability_owned.is_empty(), "no build, no weapon ability (the lab worlds)")


func test_blink_and_aegis_are_exclusive_and_drive_the_utility_button() -> void:
	var w := _world()
	assert_eq(Abilities.utility(w), PlayerTable.Utility.NONE, "no utility at the start (F11)")
	assert_true(Abilities.grant(w, _idx(w, AbilityTable.Kind.AEGIS)))
	assert_eq(Abilities.utility(w), PlayerTable.Utility.GUARD)
	assert_false(Abilities.can_take(w, _idx(w, AbilityTable.Kind.BLINK)), "one utility only")
	w.step(_f(U, Vector2i.ZERO, U))
	w.step(_f(0, Vector2i.ZERO, U))
	assert_true(w.guarding(), "Aegis: holding the utility button guards")
	assert_eq(Abilities.charge_max(w), 1, "Aegis L1 stores one guard charge")
	Abilities.grant(w, _idx(w, AbilityTable.Kind.AEGIS))
	assert_eq(Abilities.charge_max(w), 2, "+1 charge cap per level")


# --- Blink --------------------------------------------------------------------------------------------------
func test_blink_teleports_and_lands_with_a_shock() -> void:
	var w := _world(&"blade", [Vector2(5.0, 0.0), Vector2(5.0, 3.5)])
	Abilities.grant(w, _idx(w, AbilityTable.Kind.BLINK))
	var right := Vector2i(SimTick.MOVE_MAX, 0)
	w.step(_f(U, right))
	_run(w, 2)
	assert_gt(w.player_pos().x, 3.0, "blinked along the move")
	assert_eq(w.ab.blink_charges, 0, "the charge is spent")
	var shocks := _damage(w, Abilities.EFFECT_BLINK)
	assert_eq(
		shocks.size(), 1, "the 2 m landing shock hit the dummy beside the landing, not the far one"
	)
	assert_eq(shocks[0].amount, 15)
	assert_true(shocks[0].tags & SimEvent.TAG_ABILITY != 0)
	assert_eq(w.blink_cd, 900 - 2, "the 15 s cooldown runs")


func test_blink_level_three_holds_two_charges() -> void:
	var w := _world()
	var b := _idx(w, AbilityTable.Kind.BLINK)
	for k in 3:
		Abilities.grant(w, b)
	assert_eq(Abilities.level_of(w, b), 3)
	assert_eq(w.ab.blink_charges, 2, "two charges ready")
	var up := Vector2i(0, SimTick.MOVE_MAX)
	w.step(_f(U, up))
	_run(w, 2)
	w.step(_f(U, up))
	_run(w, 2)
	assert_eq(w.ab.blink_charges, 0, "both spent back to back")
	assert_eq(Abilities.blink_cooldown(w), 780, "L3: 13 s per charge")
	_run(w, 790)
	assert_eq(w.ab.blink_charges, 1, "one charge back after one cooldown")
	_run(w, 790)
	assert_eq(w.ab.blink_charges, 2, "and the next")


# --- Weapons ------------------------------------------------------------------------------------------------
func test_weapon_levels_raise_the_builds_damage_and_reach() -> void:
	var w := _world(&"blade")
	var s := _idx(w, AbilityTable.Kind.COMBO_SWORD)
	var base := PlayerBuild.melee_damage(w, 100)
	Abilities.grant(w, s)
	assert_eq(PlayerBuild.melee_damage(w, 100), base * 1120 / 1000, "L2: +12 %")
	var reach := ItemEffects.swing_reach_m(w, 0)
	Abilities.grant(w, s)
	assert_almost_eq(ItemEffects.swing_reach_m(w, 0), reach * 1.15, 1e-4, "L3: +15 % reach")
	var g := _world(&"gun")
	var p := _idx(g, AbilityTable.Kind.PULSE_GUN)
	assert_eq(Abilities.bolt_tags(g), 0)
	Abilities.grant(g, p)
	Abilities.grant(g, p)
	assert_eq(Abilities.bolt_tags(g), SimEvent.TAG_PIERCE, "L3: bolts pierce")
	Abilities.grant(g, p)
	Abilities.grant(g, p)
	assert_eq(Abilities.shot_offsets(g, PackedInt32Array([0])).size(), 2, "L5: twin bolts")


func test_combo_sword_level_five_finisher_sends_a_shockwave() -> void:
	var w := _world(&"blade", [Vector2(1.2, 0), Vector2(-2.6, 0)])
	var s := _idx(w, AbilityTable.Kind.COMBO_SWORD)
	for k in 4:
		Abilities.grant(w, s)
	for k in 150:  # the four-slash combo along the aim (+x): a press every 6 ticks keeps it going
		w.step(_f(InputFrame.PRIMARY if k % 6 == 0 else 0))
	var waves := _damage(w, Abilities.EFFECT_SWORD_WAVE)
	assert_gt(waves.size(), 0, "the finisher's wave hit")
	assert_eq(waves[0].amount, (14 * 1480 + 500) / 1000, "14 x the L5 factor")


# --- Determinism, carry and hash ----------------------------------------------------------------------------
func _scripted(seed_shift: int) -> String:
	var w := _world(&"blade", [Vector2(3, 1), Vector2(-4, 2), Vector2(2, -5), Vector2(-3, -3)], 60)
	w.player.crit_chance_permille = 50
	for kind in [AbilityTable.Kind.COMBO_SWORD, AbilityTable.Kind.BLINK]:
		Abilities.grant(w, _idx(w, kind))
		Abilities.grant(w, _idx(w, kind))
	for k in 600:
		w.step(_f(0, Vector2i((k / 60 % 3 - 1) * 60, seed_shift)))
	return w.state_hash()


func test_same_inputs_same_hash() -> void:
	assert_eq(_scripted(0), _scripted(0), "deterministic")
	assert_ne(_scripted(0), _scripted(40), "different inputs differ")


func test_ability_state_is_in_the_hash_and_carried() -> void:
	var a := _world()
	var b := _world()
	assert_eq(a.state_hash(), b.state_hash())
	Abilities.grant(b, _idx(b, AbilityTable.Kind.BLINK))
	assert_ne(a.state_hash(), b.state_hash(), "a slot changes the hash")
	var carry := RunCarry.take(b, 0)
	var c := _world()
	RunCarry.apply(c, carry)
	Abilities.start_floor(c)
	assert_eq(c.ability_owned, b.ability_owned, "the slots go to the next floor")
	assert_eq(c.ability_levels, b.ability_levels)


func test_kernel_worlds_keep_their_hash() -> void:
	var w := World.new(1, PlayerTable.starting_values())
	assert_false(Abilities.touched(w), "no slots, stats or crit: nothing new in the hash")
