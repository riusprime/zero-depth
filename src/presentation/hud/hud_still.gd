class_name HudStill
extends Node
## Draws the HUD parts that are not changing from a texture, so a part that stays still costs the frame one draw
## instead of the dozens its polygons, arcs and text take: the engine issues every 2D draw again each frame, and
## code-drawn shapes do not batch.
##
## Each registered part (a CanvasItem under the HUD, with its whole subtree) gets its own visibility layer bit and its
## own SubViewport, which renders the HUD's canvas through that bit only, at the screen's own transform shifted by a
## whole number of pixels, so the part's shapes land on the same sub-pixel positions as on the screen. While the part
## changes (one of its items redraws, moves, resizes, shows, hides, gains or loses a child, or the screen transform
## changes) the screen draws it directly. Once it has been still for a frame (longer for a part whose renders keep
## being wasted, MIN_WAIT .. MAX_WAIT) its SubViewport renders it once (UPDATE_ONCE); from the next frame the screen
## leaves the bit out (Viewport.canvas_cull_mask) and a proxy right after the part in the draw order draws the
## texture instead, on whole screen pixels, one texel per pixel. The texture holds
## premultiplied colour (the SubViewport's transparent clear) and is drawn with a premultiplied-alpha blend, which
## composites as drawing the shapes straight onto the screen does, up to the 8-bit rounding of the stored colour. The
## nodes stay where they are: layout, input, hover and every read of them are unchanged. It only draws (EI-07).

## The visibility layer bits the parts use (bit 0 is every item's default, the one the screen always draws).
const FIRST_BIT := 12
const MAX_PARTS := 16
## Still frames before a part's texture is rendered: at first one; doubled (up to MAX_WAIT) each time a part changes
## again within PAYBACK frames of a render (a render that did not pay for itself: the heat bar while firing, the
## corner map while walking), back to one after a still spell of PAYBACK frames.
const MIN_WAIT := 1
const MAX_WAIT := 64
const PAYBACK := 30
## Canvas px added round a part's bounds for what its items draw past their rects (outlines, rings, ticks).
const MARGIN := 24.0


## One registered part.
class Part:
	extends RefCounted
	var root: CanvasItem
	var bit := 0
	## Callable() -> Rect2 in the HUD canvas's coordinates; an empty Callable: the union of its items' rects.
	var bounds: Callable
	var vp: SubViewport
	var proxy: Proxy
	var attached := false
	var changed := true
	var quiet := 0
	var wait := MIN_WAIT
	var frozen := false
	var sig := []
	## The texture's top-left on the screen (whole px) and its size, as last rendered.
	var at := Vector2i.ZERO
	var px := Vector2i.ZERO
	var renders := 0
	## Frames stepped, and of them the frames drawn from the texture (probes).
	var steps := 0
	var frozen_steps := 0
	## CanvasItem -> [the callables connected to it]
	var hooked := {}


## Draws a part's texture where the part was, in the HUD's draw order.
class Proxy:
	extends Control
	var part: Part

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # one texel per screen pixel
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		material = mat

	func _draw() -> void:
		if part != null and part.frozen:
			draw_texture_rect(part.vp.get_texture(), texture_rect(), false)

	## Where the texture goes in this item's own coordinates: its texels on the screen's pixels.
	func texture_rect() -> Rect2:
		var xf := get_viewport().get_final_transform() * get_global_transform_with_canvas()
		var inv := xf.affine_inverse()
		var p0 := inv * Vector2(part.at)
		var p1 := inv * Vector2(part.at + part.px)
		return Rect2(p0, p1 - p0)

	## Puts the texture in this item's commands at once (the switch happens after the frame's redraws).
	func paint_now() -> void:
		var ci := get_canvas_item()
		RenderingServer.canvas_item_clear(ci)
		RenderingServer.canvas_item_add_texture_rect(
			ci, texture_rect(), part.vp.get_texture().get_rid()
		)


var _parts: Array[Part] = []
var _on := true
## The time step() took, summed, and its calls (probes).
var _step_us := 0
var _step_n := 0


func _init() -> void:
	name = "HudStill"


func _enter_tree() -> void:
	if not RenderingServer.frame_pre_draw.is_connected(step):
		RenderingServer.frame_pre_draw.connect(step)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(step):
		RenderingServer.frame_pre_draw.disconnect(step)
	for p in _parts:
		if p.frozen:
			_thaw(p)


## Registers `root` (in the tree) as a part. Its parent must be a plain Control or Node2D, not a Container: the proxy
## goes right after it. `bounds` gives the part's drawn extent in its canvas's coordinates (an empty Callable: the
## union of its items' rects, without the root's own when it fills the screen).
func add_part(root: CanvasItem, bounds := Callable()) -> void:
	if _parts.size() >= MAX_PARTS or root.get_parent() is Container:
		return
	var p := Part.new()
	p.root = root
	p.bit = FIRST_BIT + _parts.size()
	p.bounds = bounds
	p.vp = SubViewport.new()
	p.vp.name = "Still%s" % root.name
	p.vp.transparent_bg = true
	p.vp.disable_3d = true
	p.vp.size = Vector2i.ONE
	p.vp.canvas_cull_mask = 1 << p.bit
	p.vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	p.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	p.vp.gui_disable_input = true
	add_child(p.vp)
	p.proxy = Proxy.new()
	p.proxy.name = "%sStill" % root.name
	p.proxy.part = p
	var parent := root.get_parent()
	parent.add_child(p.proxy)
	parent.move_child(p.proxy, root.get_index() + 1)
	_parts.append(p)
	_adopt(p, root)
	var item := parent as CanvasItem
	while item != null:  # every ancestor shares the bit, or the SubViewport would cull the part with it
		item.visibility_layer |= 1 << p.bit
		item = item.get_parent() as CanvasItem


## Turns the textures off (every part drawn directly, as without this node) or back on.
func set_enabled(on: bool) -> void:
	_on = on
	for p in _parts:
		p.changed = true
		if not on and p.frozen:
			_thaw(p)


# --- Reads (tests and probes) -------------------------------------------------------------------------------
## Whether `root`'s part is drawn from its texture this frame.
func frozen(root: CanvasItem) -> bool:
	var p := _part(root)
	return p != null and p.frozen


## How many times `root`'s texture was rendered.
func renders(root: CanvasItem) -> int:
	var p := _part(root)
	return 0 if p == null else p.renders


## One line per part: its frames, the share drawn from its texture, its renders (probes).
func stats_lines() -> PackedStringArray:
	var out: PackedStringArray = ["step: %.1f us a frame" % (float(_step_us) / maxi(1, _step_n))]
	for p in _parts:
		out.append(
			"%s steps=%d frozen=%d renders=%d" % [p.root.name, p.steps, p.frozen_steps, p.renders]
		)
	return out


## The registered parts' roots.
func roots() -> Array[CanvasItem]:
	var out: Array[CanvasItem] = []
	for p in _parts:
		out.append(p.root)
	return out


func _part(root: CanvasItem) -> Part:
	for p in _parts:
		if p.root == root:
			return p
	return null


# --- Tracking -----------------------------------------------------------------------------------------------
func _adopt(p: Part, n: Node) -> void:
	if n is Viewport:  # its items draw into its own canvas
		return
	if n is CanvasItem and not p.hooked.has(n):
		var ci := n as CanvasItem
		ci.visibility_layer = 1 << p.bit
		var mark := func() -> void: p.changed = true
		var entered := func(c: Node) -> void: _entered(p, c)
		var exiting := func(c: Node) -> void: _exiting(p, c)
		p.hooked[ci] = [mark, entered, exiting]
		ci.draw.connect(mark)
		ci.visibility_changed.connect(mark)
		ci.item_rect_changed.connect(mark)
		ci.child_order_changed.connect(mark)
		ci.child_entered_tree.connect(entered)
		ci.child_exiting_tree.connect(exiting)
	for c in n.get_children():
		_adopt(p, c)


func _entered(p: Part, c: Node) -> void:
	p.changed = true
	_adopt(p, c)


func _exiting(p: Part, c: Node) -> void:
	p.changed = true
	var stack: Array[Node] = [c]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not p.hooked.has(n):
			continue
		var cbs: Array = p.hooked[n]
		p.hooked.erase(n)
		var ci := n as CanvasItem
		ci.draw.disconnect(cbs[0])
		ci.visibility_changed.disconnect(cbs[0])
		ci.item_rect_changed.disconnect(cbs[0])
		ci.child_order_changed.disconnect(cbs[0])
		ci.child_entered_tree.disconnect(cbs[1])
		ci.child_exiting_tree.disconnect(cbs[2])
		ci.visibility_layer = 1


# --- The switch, once a frame after every redraw -------------------------------------------------------------
## Once a frame, after every redraw and before the draw (RenderingServer.frame_pre_draw; a headless test calls it):
## each part drawn directly while it changes, rendered once it has been still for its wait, drawn from its texture
## from the next frame.
func step() -> void:
	if not is_inside_tree():
		return
	var t0 := Time.get_ticks_usec()
	_step(get_viewport().get_final_transform())
	_step_us += Time.get_ticks_usec() - t0
	_step_n += 1


func _step(final: Transform2D) -> void:
	for p in _parts:
		if not is_instance_valid(p.root):
			continue
		p.steps += 1
		var showing := _on and p.root.is_visible_in_tree()
		var sig := [final, p.root.get_global_transform_with_canvas(), showing]
		if showing:
			sig.append(_tints(p))
		if p.changed or not showing or sig != p.sig:
			if p.quiet >= p.wait:  # it was rendered: did the render pay for itself?
				var still_for := p.quiet - p.wait
				p.wait = MIN_WAIT if still_for >= PAYBACK else mini(p.wait * 2, MAX_WAIT)
			p.changed = false
			p.sig = sig
			p.quiet = 0
			if p.frozen:
				_thaw(p)
			continue
		p.quiet += 1
		if p.frozen:
			p.frozen_steps += 1
		if p.quiet == p.wait:
			_render(p, final)
		elif p.quiet == p.wait + 1:
			_freeze(p)


## A sum over the part's items of what changes their look without a redraw or a signal: their tints (a fade, a
## pulse) and a Node2D's transform. Cheap enough for every frame; any real change moves it.
static func _tints(p: Part) -> float:
	var acc := 0.0
	var k := 1.0
	for ci: CanvasItem in p.hooked:
		var m := ci.modulate
		var s := ci.self_modulate
		acc += (
			(
				m.r
				+ 2.0 * m.g
				+ 3.0 * m.b
				+ 5.0 * m.a
				+ 7.0 * s.r
				+ 11.0 * s.g
				+ 13.0 * s.b
				+ 17.0 * s.a
			)
			* k
		)
		if ci is Node2D:
			var t := (ci as Node2D).transform
			acc += (t.origin.x + 3.0 * t.origin.y + 5.0 * t.x.x + 7.0 * t.x.y) * k
		k += 1.0
	return acc


## Renders the part into its SubViewport during this frame's draw (the screen still draws it directly).
func _render(p: Part, final: Transform2D) -> void:
	var to_screen := final * p.root.get_canvas_transform()
	var r := _canvas_bounds(p).grow(MARGIN)
	var lo := (to_screen * r.position).floor().max(Vector2.ZERO)
	var hi := (to_screen * r.end).ceil().min((final * get_viewport().get_visible_rect().end).ceil())
	p.at = Vector2i(lo)
	p.px = Vector2i(hi - lo).max(Vector2i.ONE)
	p.vp.size = p.px
	if "oversampling_override" in p.vp:  # text rasterised at the screen's density
		p.vp.set(&"oversampling_override", absf(final.get_scale().x))
	var vp_rid := p.vp.get_viewport_rid()
	var canvas := p.root.get_canvas()
	if not p.attached:
		p.attached = true
		RenderingServer.viewport_attach_canvas(vp_rid, canvas)
	RenderingServer.viewport_set_canvas_transform(vp_rid, canvas, Transform2D(0.0, -lo) * to_screen)
	p.vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	p.renders += 1


func _freeze(p: Part) -> void:
	p.frozen = true
	var vp := get_viewport()
	vp.canvas_cull_mask = vp.canvas_cull_mask & ~(1 << p.bit)
	p.proxy.paint_now()


func _thaw(p: Part) -> void:
	p.frozen = false
	var vp := get_viewport()
	if vp != null:
		vp.canvas_cull_mask = vp.canvas_cull_mask | (1 << p.bit)
	RenderingServer.canvas_item_clear(p.proxy.get_canvas_item())


## The part's extent in the canvas's coordinates.
func _canvas_bounds(p: Part) -> Rect2:
	if p.bounds.is_valid():
		return p.bounds.call()
	var full := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var r := Rect2()
	var first := true
	for ci: CanvasItem in p.hooked:
		if not ci is Control or not ci.is_visible_in_tree():
			continue
		var g := (ci as Control).get_global_rect()
		if ci == p.root and g.encloses(full) and p.hooked.size() > 1:
			continue  # a full-screen wrapper: its children say where it draws
		r = g if first else r.merge(g)
		first = false
	return r if not first else full
