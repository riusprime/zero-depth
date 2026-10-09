extends GutTest
## v0.5.9 art (owner, 2026-10-09: "fire should be fire … not a circle with bad made particles on top"): with a
## VfxLayer, fire zones are flames, electric is lightning, bombs land as explosions, and none of them lays a ground
## circle. Without one the canvas draws as before (test_attack_forms.gd).

const AT := Vector2(2, 3)

var _view: AttackFormView
var _vfx: VfxLayer


func before_each() -> void:
	ViewPrefs.effects_density = "high"
	_view = add_child_autofree(AttackFormView.new())
	_vfx = add_child_autofree(VfxLayer.new())
	_view.vfx = _vfx


func _spec(form: int, els: Array, extra: Dictionary = {}) -> Dictionary:
	var s := {"form": form, "elements": PackedStringArray(els)}
	s.merge(extra, true)
	return s


func _used(id: StringName) -> int:
	return _view.pool(id).used


func test_the_owners_textures_are_installed() -> void:
	assert_true(VfxLayer.available())


func test_a_fire_zone_is_flames_not_a_circle() -> void:
	_view.spawn(
		_spec(WorldReader.FORM_ZONE, ["ember"], {"radius_m": 2.0, "life_ticks": 120}),
		AT,
		0.0,
		{"start": 0}
	)
	_view.draw_at(60.0)
	assert_eq(_used(&"zone_fill"), 0, "no ground disc")
	assert_eq(_used(&"zone_rim"), 0, "no ground ring")
	assert_gt(_vfx.used(&"flame"), 3, "flames")
	assert_gt(_vfx.lights_on(), 0, "the fire lights the floor")
	_view.draw_at(130.0)
	assert_eq(_vfx.used(&"flame"), 0, "gone after its life")


func test_an_electric_zone_and_ring_are_lightning() -> void:
	_view.spawn(
		_spec(WorldReader.FORM_ZONE, ["storm"], {"radius_m": 2.0, "life_ticks": 120}),
		AT,
		0.0,
		{"start": 0}
	)
	_view.spawn(_spec(WorldReader.FORM_RING, ["storm"], {"radius_m": 3.0}), AT, 0.0, {"start": 0})
	_view.draw_at(6.0)
	assert_eq(_used(&"zone_fill") + _used(&"ring_fill") + _used(&"ring_front"), 0, "no circles")
	assert_gt(_vfx.used(&"bolt"), 0, "lightning")


func test_an_electric_beam_is_a_lightning_bolt() -> void:
	_view.spawn(
		_spec(WorldReader.FORM_BEAM, ["storm"]), AT, 0.0, {"start": 0, "to": AT + Vector2(0, 5)}
	)
	_view.draw_at(1.0)
	assert_eq(_used(&"beam_core"), 0)
	assert_gt(_vfx.used(&"bolt"), 0)


func test_a_bomb_has_no_ground_circle_and_lands_as_an_explosion() -> void:
	var e := _view.spawn(
		_spec(WorldReader.FORM_LOB, ["ember"], {"reach_m": 5.0, "radius_m": 1.8}),
		AT,
		0.0,
		{"start": 0}
	)
	var flight: float = e["flight"]
	_view.draw_at(flight * 0.5)
	assert_eq(_used(&"lob_body"), 1, "the bomb itself")
	assert_eq(_used(&"lob_ground"), 0, "no ground circle")
	_view.draw_at(flight + 2.0)
	assert_eq(_used(&"burst_fill"), 0, "no flat flash")
	assert_gt(_vfx.used(&"blast"), 0, "a fireball")
	assert_gt(_vfx.scorches(), 0, "a scorch mark")
	_view.draw_at(flight + 40.0)
	assert_gt(_vfx.used(&"smoke"), 0, "smoke still rising")


func test_a_plain_element_keeps_the_flat_look() -> void:
	_view.spawn(
		_spec(WorldReader.FORM_ZONE, ["frost"], {"radius_m": 2.0, "life_ticks": 120}),
		AT,
		0.0,
		{"start": 0}
	)
	_view.draw_at(60.0)
	assert_eq(_used(&"zone_fill"), 1, "frost is not in this pass")
