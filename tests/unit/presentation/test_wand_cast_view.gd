extends GutTest
## v0.6.5 WN5a (docs/design/WAND.md, the shared pool's "You see" column and rule 3's child spell): each shared card
## shows on the spell (its element's core and particles; Explosive's blast cue), and a trigger's cast reads as a small
## spell of its own where it fires: AttackFormView reads WorldReader.wand_casts and draws the sigil and the child
## slash or blast once, a cast bolt flies with the &"cast" cue. Presentation only (EI-07): the view reads, the sim
## decides.

const W := preload("res://tests/support/mx4_world.gd")
## S1–S6 and the element each puts in the spell's core.
const ELEMENTS: Array = [
	[&"ember_core", &"ember"],
	[&"storm_core", &"storm"],
	[&"frost_core", &"frost"],
	[&"venom_core", &"venom"],
	[&"shared_bleed", &"bleed"],
	[&"gravity_well", &"void"],
]

var _view: AttackFormView


func before_each() -> void:
	ViewPrefs.effects_density = "high"
	_view = add_child_autofree(AttackFormView.new())


func _spell(w: World, weapon: StringName) -> Dictionary:
	var r := WorldReader.new(w)
	return r.attack_spec(Modifiers.step_id(0) if weapon == &"blade" else WorldReader.ATTACK_BOLT)


## Steps `w` `ticks` ticks after one attack, syncing the view each tick.
func _play(w: World, weapon: StringName, ticks: int) -> void:
	var r := WorldReader.new(w)
	var first := (
		InputFrame.make(Vector2i.ZERO, 0, 300, 0, W.P)
		if weapon == &"blade"
		else InputFrame.make(Vector2i.ZERO, 0, 300, W.S, 0)
	)
	w.step(first)
	_view.sync(r)
	for t in ticks:
		w.step(W.frame())
		_view.sync(r)


func test_the_wand_cues_and_the_sigil() -> void:
	assert_eq(AttackFormLooks.TRIGGER_ON_END, AttackSpec.Trigger.ON_END, "pinned to the sim's")
	var cast := {"form": AttackFormLooks.BOLT, "tags": PackedStringArray(["hook", "cast"])}
	assert_has(AttackFormLooks.cues_of(cast), &"cast")
	var blast := {
		"form": AttackFormLooks.BOLT,
		"hooks": [{"trigger": AttackSpec.Trigger.ON_END, "child": {"form": AttackFormLooks.BURST}}],
	}
	assert_has(AttackFormLooks.cues_of(blast), &"blast")
	assert_eq(AttackFormLooks.cues_of({}), [] as Array[StringName], "a plain spell has none")
	assert_false(
		AttackFormLooks.is_hostile_hue(AttackFormLooks.CAST_SIGIL), "never a telegraph hue"
	)


func test_each_shared_card_colours_the_spell_on_both_weapons() -> void:
	for weapon: StringName in [&"blade", &"gun"]:
		for c: Array in ELEMENTS:
			var look := AttackFormLooks.compose(_spell(W.world(weapon, [c[0]]), weapon))
			assert_eq(look["core"], AttackFormLooks.element_color(c[1]), "%s: its core" % c[0])
			assert_false((look["particles"] as Array).is_empty(), "%s: its particles" % c[0])
			assert_true(
				AttackFormView.adds_layer(look), "%s: drawn over the plain %s" % [c[0], weapon]
			)
		var x := AttackFormLooks.compose(_spell(W.world(weapon, [&"shared_explosive"]), weapon))
		assert_has(x["cues"], &"blast", "Explosive: the %s carries its blast" % weapon)


func test_a_blade_on_hit_cast_draws_its_sigil_its_slash_and_its_blast() -> void:
	var w := W.world(
		&"blade", [&"trigger_on_hit", &"shared_explosive"], [[Vector2(1.6, 0.0), 5000]]
	)
	_play(w, &"blade", 30)
	assert_gt(WandCasts.read(w).size(), 0, "the sim cast it")
	assert_gt(_view.casts_drawn, 0, "the sigil where it fired")
	assert_gt(int(_view.cast_forms.get(&"arc", 0)), 0, "the small slash")
	assert_gt(int(_view.cast_forms.get(&"burst", 0)), 0, "its blast where it ends")
	var drawn := _view.casts_drawn
	_view.sync(WorldReader.new(w))
	assert_eq(_view.casts_drawn, drawn, "each cast is drawn once")


func test_a_gun_on_hit_cast_flies_with_its_cue() -> void:
	var w := W.world(&"gun", [&"trigger_on_hit"], [[Vector2(2.5, 0.0), 5000]])
	var r := WorldReader.new(w)
	var bolt := r.attack_spec(WorldReader.ATTACK_BOLT)
	var child: Dictionary = AttackFormView.hook_child(
		bolt, AttackSpec.Trigger.ON_HIT, WorldReader.FORM_BOLT
	)
	assert_false(child.is_empty(), "the cast is a small bolt")
	var look := AttackFormLooks.compose(child)
	assert_has(look["cues"], &"cast")
	assert_true(AttackFormView.adds_layer(look), "a cast bolt is drawn as one")
	_play(w, &"gun", 20)
	assert_gt(_view.casts_drawn, 0, "the sigil where it fired")


## v0.9.0 XP (owner Q11): Fire's kill leaves a burning patch, no burst.
func test_a_fire_kill_leaves_a_patch_not_a_burst() -> void:
	var w := W.world(&"gun", [&"ember_core"], [[Vector2(2.5, 0.0), 1]])
	_play(w, &"gun", 20)
	assert_eq(int(_view.cast_forms.get(&"burst", 0)), 0, "no burst where it died")
	assert_eq(w.ab.fire_pos.size(), 1, "a burning patch instead")
	assert_eq(_view.casts_drawn, 0, "a card's patch, no trigger sigil")
