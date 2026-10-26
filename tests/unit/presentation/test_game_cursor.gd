extends GutTest
## v0.9.5 MC: the code-drawn cursors: built once, sized by the window's height class, the violet rune dot, the ring,
## the arrow's tip, and an owner image replacing the drawn one.

var _c: GameCursor


func before_each() -> void:
	_c = GameCursor.new()
	_c.reticle_path = "res://none_reticle.png"
	_c.arrow_path = "res://none_arrow.png"
	add_child_autofree(_c)


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_textures_are_built_once() -> void:
	_c.setup(1080)
	var r := _c.reticle()
	var a := _c.arrow()
	_c.set_context(true)
	_c.set_context(false)
	_c.set_context(true)
	_c.setup(1080)
	_c.setup(1000)
	assert_same(_c.reticle(), r, "the reticle is the same instance")
	assert_same(_c.arrow(), a, "the arrow is the same instance")


func test_size_follows_the_height_class() -> void:
	_c.setup(1080)
	assert_eq(_c.reticle().get_size(), Vector2(32, 32))
	assert_eq(_c.arrow().get_size(), Vector2(32, 32))
	_c.setup(1440)
	assert_eq(_c.reticle().get_size(), Vector2(48, 48))
	assert_eq(_c.arrow().get_size(), Vector2(48, 48))


func test_reticle_pixels() -> void:
	_c.setup(1080)
	var img := _c.reticle().get_image()
	var mid := img.get_pixel(16, 16)
	assert_gt(mid.a, 0.95, "the centre is opaque")
	var off := absf(mid.r - GameCursor.VIOLET.r) + absf(mid.g - GameCursor.VIOLET.g)
	assert_lt(off, 0.1, "the centre is violet")
	assert_gt(img.get_pixel(27, 16).a, 0.5, "a pixel on the ring is opaque")
	assert_lt(img.get_pixel(23, 16).a, 0.01, "between ring and dot is transparent")


func test_arrow_tip_is_opaque() -> void:
	_c.setup(1080)
	assert_gt(_c.arrow().get_image().get_pixel(1, 1).a, 0.5)
	assert_lt(_c.arrow().get_image().get_pixel(30, 2).a, 0.01, "off the shape is transparent")


func test_owner_image_overrides_the_drawn_one() -> void:
	var path := "res://assets/textures/backgrounds/bg_frozen_shore_deep.png"
	var c := GameCursor.new()
	c.reticle_path = path
	c.arrow_path = "res://none_arrow.png"
	add_child_autofree(c)
	c.setup(1080)
	assert_eq(
		c.reticle().get_size(), (load(path) as Texture2D).get_size(), "the owner image is used"
	)
	assert_eq(c.arrow().get_size(), Vector2(32, 32), "no arrow file: the drawn one")
