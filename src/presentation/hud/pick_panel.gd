class_name PickPanel
extends ModalPanel
## The 3-card pick (v0.3.0 E, owner line L9): while the sim waits on an open altar or chest, three cards
## (PickSlot: carved stone tablets since v0.8.0 MU, coloured by the card's family), a title (the chest's
## price) and a hint. It shows what the sim offers and sends the player's choice as input (the `picked` signal →
## InputLatch.note_pick → InputFrame.pick); it decides nothing itself.
## - Mouse: hover focuses a card, a click takes it.
## - Keyboard: ←/→ (or 1/2/3) moves the focus, Enter takes it, Esc leaves the choice for later.
## - Pad: d-pad or left stick moves the focus, A (Cross) takes it, B (Circle) leaves.
## Space (dash) never confirms: the panel doesn't use ui_accept.
## Layouts (G2 mockups for the owner): ROW_CENTRE ships as the default.
## The cards are dealt (CardDeal): face down from the bottom of the screen into a fan,
## flipped one by one (the width to 0, the face swapped halfway); an Epic or Legendary card waits for last with a
## glowing back while the background darkens, and flips with a punch, a flash and rays behind it; a Legendary card
## keeps a holographic shine. The hovered card tilts toward the cursor (a focused one by key or pad: a fixed tilt)
## and sinks a little, its numbers counting up from the old value. On a pick its icon flies to its HUD slot
## (card_taken → Hud's CardFly) and the cards not picked burn (no discard button: D48; and the card a
## picked Form, Pattern, Secondary or Element card replaces burns on its slot line, PickSlot); a chest deals its one
## card, already taken, and any answer closes it. A press during the deal ends the deal at once and still counts
## (no input is lost or held back). Reduced motion: no deal, flip or tilt; the cards fade in face up, tier colour and
## words kept; on a pick the panel fades. All of it only draws: the sim decides (EI-07).

## The picked card (its code) leaves its socket at `from` (global px): the HUD flies its icon to its slot.
signal card_taken(code: int, from: Rect2)

enum Layout { ROW_CENTRE, ROW_LOW, COLUMN_RIGHT }

## Key repeats (PanelInput.Echo): a held key repeats (the sent latch stops a second answer).
const ECHO := PanelInput.Echo.ACT
const SLOTS := 3
## The background's dim at rest and how much darker the rare wait takes it; the outro (burn, fly) length.
const DIM := 0.45
const DIM_WAIT := 0.32
const OUTRO_S := 0.75
const OUTRO_REDUCED_S := 0.15
## The fixed tilt of a card focused by key or pad (CardFx.set_hover).
const FOCUS_TILT := Vector2(0.35, -0.2)
## The tier words in order (Offers.info's rarity: common, rare, epic, legendary).
const RARITY_KEYS: Array[String] = [
	"RARITY_COMMON", "RARITY_RARE", "RARITY_EPIC", "RARITY_LEGENDARY"
]

var layout := Layout.ROW_CENTRE
## The deal's timeline (CardDeal).
var deal := CardDeal.new()
var _dim := ColorRect.new()
## The Astral heading (AstralChrome.Heading), a chest price's shard and the hint line.
var _title := AstralChrome.Heading.new(32)
var _price_icon := ShardIcon.new(28.0, true)
var _hint := AstralChrome.Hint.new(200.0, 16)
## The high cards' light rays, on one layer under every card.
var _rays := Control.new()
var _slots: Array[PickSlot] = []
var _count := 0
var _reward := -1
var _boss := false  # The open choice is the boss's altar
var _swap_seen := false
## The cards' codes, the answer sent, the dealt chest, the outro's clock (< 0: none).
var _codes := PackedInt32Array()
var _answer := InputFrame.PICK_NONE
var _dealt := false
var _outro := -1.0
var _picked := -1
var _reader: WorldReader
var _dim_base := DIM
var _mouse_tilt := false


func _init(p_layout: Layout = Layout.ROW_CENTRE) -> void:
	layout = p_layout
	name = "PickPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_base = 0.18 if layout == Layout.ROW_LOW else DIM
	_add_dim(_dim, _dim_base)
	_dim.color = Color(AstralChrome.INK, _dim_base)  # Astral's ink, not black
	_rays.name = "Rays"
	_rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.draw.connect(_draw_rays)
	add_child(_rays)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 16)
	# Astral: the sigil and the letter-spaced title (a chest's price with Astral's shard after it),
	# a rule under it, the cards, and the hint between fading hairlines.
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 12)
	head.add_child(_title)
	head.add_child(_price_icon)
	_price_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(head)
	col.add_child(AstralChrome.Rule.new(400.0))
	var cards: BoxContainer = (
		VBoxContainer.new() if layout == Layout.COLUMN_RIGHT else HBoxContainer.new()
	)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards.add_theme_constant_override("separation", 32)
	col.add_child(cards)
	var gap := Control.new()  # room for the dealt fan's drop over the hint
	gap.custom_minimum_size = Vector2(0, 16)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	col.add_child(_hint)
	for k in SLOTS:
		var s := PickSlot.new(k)
		s.clicked.connect(_on_clicked)
		s.hovered.connect(_set_focus)
		cards.add_child(s)
		_slots.append(s)
	_place(col)
	visible = false


## Opens, refreshes or closes from the sim's state.
func sync(reader: WorldReader) -> void:
	_reader = reader
	if _closed(reader.choosing()):
		return
	var r := reader.choice_reward()
	var rid := reader.reward_id(r)
	if reader.swapping():  # The Swap choice (SwapPanel) sits over the cards
		_swap_seen = true
		return
	if _swap_seen and _open and rid == _reward:  # a skipped swap: back to the cards
		_swap_seen = false
		_sent = false
		return
	_swap_seen = false
	if _open and rid == _reward:
		return
	_open = true
	_sent = false
	_reward = rid
	visible = true
	_end_outro()
	var items := reader.choice_items()
	_codes = items
	var legendary := reader.reward_is_legendary(r)  # v0.5.5 AR
	_boss = legendary
	_count = items.size()
	for k in SLOTS:
		var s := _slots[k]
		s.visible = k < _count
		if k >= _count:
			continue
		var face := card_face(self, reader, items[k])  # A mod, an ability or a stat card
		if legendary:
			face = legendary_face(self, face)
		if reader.choice_jackpot(k):  # A jackpot card says so
			face = jackpot_face(self, face)
		s.show_card(face)
		var curse := reader.choice_curse(k)  # A cursed chest card says so
		s.show_curse(CurseLook.down_line(self, reader, curse) if curse >= 0 else "")  # v0.6.0 CU
	var chest := reader.reward_kind(r) == WorldReader.REWARD_CHEST
	var title := (
		tr("PICK_TITLE_CHEST") % reader.reward_price(r) if chest else tr("PICK_TITLE_ALTAR")
	)
	if reader.reward_is_epic(r):  # v0.5.0 RT
		title = tr("PICK_TITLE_EPIC_ALTAR")
	if legendary:  # The boss's reward; says when it holds a Legendary card
		title = boss_title(self, _slots.slice(0, _count), reader.legendary_picks_left())
	var drop := reader.reward_drop_kind(r)  # A stolen core, Marked's card
	if drop == WorldReader.DROP_CORE or drop == WorldReader.DROP_BOSS_CORE:
		title = tr("PICK_TITLE_CORE")
	elif drop == WorldReader.DROP_ELITE_CARD:
		title = tr("PICK_TITLE_ELITE_DROP")
	var dealt := reader.choice_dealt()  # A chest deals its one card, no choice
	if dealt:
		title = tr("PICK_TITLE_CHEST_DEALT")
	_price_icon.visible = chest and not dealt
	_title.set_text(title)
	_hint.label.text = tr("PICK_HINT_DEALT" if dealt else "PICK_HINT")
	_dealt = dealt
	_answer = InputFrame.PICK_NONE
	_set_focus(0)
	_start_deal()


## A card code's face (v0.4.0 BS; WorldReader.card_info), translated through `ci`: id, title, sentence, color,
## tier (PickSlot.TIERS: 0 common, 1 rare, 2 epic, 3 ability) and tier_text (the rarity, or "New ability" /
## "Level N", with "Mod" before a mod's rarity once the run has other card types).
static func card_face(ci: Object, reader: WorldReader, code: int) -> Dictionary:
	var info := reader.card_info(code)
	var id: StringName = info["id"]
	var face := {
		"id": id,
		"title": ci.tr(info["name_key"]),
		"sentence": ci.tr(info["desc_key"]),
		"color": AbilityIcons.color(id),
		"tier": int(info["rarity"]),
		"tier_text": "",
		"type": int(info["type"]),  # The colour's family falls back on the card's type
		"wand": bool(info.get("wand", false)),  # A wand card (levels 1–5)
		"level_text": "",  # The level badge ("Lv 1", "Lv 2 → 3"); "" for a card with no level
		"held_level": 0,  # The level held now (0: not held)
		"gain": reader.card_forecast(code),  # What gets better, old → new (the sim's forecast)
	}
	match int(info["type"]):
		WorldReader.CARD_ABILITY:
			face["tier"] = 3
			var lvl := int(info["level"])
			face["held_level"] = lvl - 1 if lvl > 1 else 0
			face["level_text"] = level_text(ci, face["held_level"], lvl)
			var new_key := (
				"UI_CARD_MODIFIER_NEW" if info.get("modifier", false) else "UI_CARD_ABILITY_NEW"
			)
			face["tier_text"] = (
				ci.tr(new_key) if lvl <= 1 else ci.tr("UI_CARD_ABILITY_LEVEL") % lvl
			)
			# O62, "write the rarity out": an ability card names its rarity too
			face["tier_text"] += " · " + ci.tr(RARITY_KEYS[clampi(int(info["rarity"]), 0, 3)])
		WorldReader.CARD_STAT:
			var args := [GambleIcons.percent(int(info["amount"]))]
			if int(info.get("side", 0)) > 0:  # A rule card's second number
				args.append(GambleIcons.percent(int(info["side"])))
			face["sentence"] = ci.tr(info["desc_key"]) % args
			face["tier_text"] = ci.tr(RARITY_KEYS[clampi(face["tier"], 0, 3)])
			if face["tier"] == WorldReader.RARITY_LEGENDARY:  # Tier 3 is the ability's; legendary has its own
				face["tier"] = CardFrames.LEGENDARY_TIER
		WorldReader.CARD_STARBOUND:  # The gold Starbound card (AstralCardArt), its stacks as Lv
			face["tier"] = 1  # its rarity line in the moon-blue (AstralCardArt.RARITY), no high-card wait
			face["color"] = AstralCardArt.STARBOUND_BLUE
			face["tier_text"] = ci.tr("STARBOUND_KIND")
			face["held_level"] = int(info.get("stacks", 0))
			# W3-P10j: the gold frame's inner edge is narrower than the stone card's, so an "Lv N" badge sat over the
			# title and the corner ornaments: no badge; stacks already held read "Starbound ×N" on the rarity line.
			face["level_text"] = ""
			if face["held_level"] > 0:
				face["tier_text"] = "%s ×%d" % [face["tier_text"], face["held_level"]]
		WorldReader.CARD_SPELL:  # A spell card, its element's colour, "Spell · Lv N", the Replace line
			spell_face(ci, info, face)
		WorldReader.CARD_CURSE:  # A trade-off curse card: its name, its upside, rare
			face["sentence"] = CurseLook.up_sentence(ci, reader, int(info["curse"]))
			face["color"] = CurseLook.COLOR
			face["tier_text"] = "%s · %s" % [ci.tr("UI_CARD_CURSE"), ci.tr("RARITY_RARE")]
		_:
			face["color"] = ItemLooks.color_of_id(id)
			# The four tiers' words; a Legendary card wears the legendary gold
			var rarity: String = ci.tr(RARITY_KEYS[clampi(face["tier"], 0, 3)])
			if face["tier"] == WorldReader.RARITY_LEGENDARY:
				face["tier"] = CardFrames.LEGENDARY_TIER
			var run := not reader.abilities().is_empty()  # a run with abilities: say it's a mod
			var kind_key := "UI_CARD_MODIFIER" if info.get("modifier", false) else "UI_CARD_MOD"  # v0.6.0 MX2
			face["tier_text"] = "%s · %s" % [ci.tr(kind_key), rarity] if run else rarity
			if face["wand"]:  # A wand card's level, and the level taking it gives
				face["held_level"] = held_level(reader, code)
				face["level_text"] = level_text(
					ci,
					face["held_level"],
					face["held_level"] + 1,
					int(info.get("max_level", 5)),
					int(info.get("base_max", 0)),  # An overlevel says so
				)
			slot_face(ci, reader, info, face)  # v0.9.0 AS
			form_face(reader, info, face)  # v0.9.5 TX
			pair_face(ci, reader, code, face)  # v0.9.5 EP4
	return face


## A spell card's face: its element's colour (SpellLooks), the kind line "Spell · Lv N" (the
## level taking it gives), the level badge (Lv N, or Lv N → M when held), the level's line under the sentence when it
## levels a held spell, and "Replaces <spell>" when every spell slot is full (Offers.info "replaces", Spells.replaces).
static func spell_face(ci: Object, info: Dictionary, face: Dictionary) -> void:
	var lv := int(info["level"])
	var held := int(info.get("held_level", 0))
	face["color"] = SpellLooks.color(int(info.get("element", 0)))
	face["tier"] = 1
	face["tier_text"] = ci.tr("UI_CARD_SPELL_LEVEL") % lv
	face["held_level"] = held
	face["level_text"] = level_text(ci, held, lv, int(info.get("max_level", 5)))
	var key: StringName = info.get("level_key", &"")
	if held > 0 and key != &"":
		face["form_line"] = ci.tr(key)
		face["form_color"] = face["color"]
	var old := int(info.get("replaces", -1))
	if old >= 0:
		face["replaces_text"] = ci.tr("UI_SLOT_REPLACES") % ci.tr(info.get("replaces_name", &""))


## A Pattern or Secondary Gun card says what it does on the form held now (FormCardText): face["form_line"]
## under the generic sentence, in the form's colour (face["form_color"]). Orbs, the Blade and every other card: none.
static func form_face(reader: WorldReader, info: Dictionary, face: Dictionary) -> void:
	var slot := int(info.get("slot", WorldReader.SLOT_NONE))
	if slot != WorldReader.SLOT_PATTERN and slot != WorldReader.SLOT_SECONDARY:
		return
	var form := reader.attack_form_id()
	var line := FormCardText.line_for(form, face["id"])
	if line.is_empty():
		return
	face["form_line"] = line
	face["form_color"] = FormCardText.accent_for(form)


## An
## element card that would turn on or raise a pair says so under the sentence ("Pair: Thermal Shock", "Thermal Shock
## -> Lv 2") in the pair's colour, unless the card already has a form line. `code` is the item's index.
static func pair_face(ci: Object, reader: WorldReader, code: int, face: Dictionary) -> void:
	if face.has("form_line"):
		return
	var pv := reader.pair_preview(code)
	if pv.size() < 2:
		return
	var x := pv[0]
	var lv := pv[1]
	var pname: String = ci.tr(reader.pair_name_key(x))
	if lv <= 1:
		face["form_line"] = ci.tr("UI_PAIR_PREVIEW_ON") % pname
	else:
		face["form_line"] = ci.tr("UI_PAIR_PREVIEW_UP") % [pname, lv]
	face["form_color"] = ItemLooks.combo_color(reader.pair_id(x))


## A Form, Pattern, Secondary or Element card's slot tag
## ("Pattern"), and when its slot is full the card taking it replaces ("Replaces Twin", that card's id and colour).
## AS2 (G2 AS = B): the tag leads the rarity line ("Pattern · Modifier · Rare") and the pick card's ribbon (PickSlot)
## says "Replaces Twin", or "Choose one to replace" for a full Secondary or Element slot (the Swap panel asks).
static func slot_face(ci: Object, reader: WorldReader, info: Dictionary, face: Dictionary) -> void:
	var slot := int(info.get("slot", WorldReader.SLOT_NONE))
	if slot == WorldReader.SLOT_NONE:
		return
	face["slot"] = slot
	face["slot_text"] = ci.tr(WorldReader.SLOT_TAG_KEYS[slot])
	face["tier_text"] = "%s · %s" % [face["slot_text"], face.get("tier_text", "")]
	if info.get("chooses", false):
		face["replaces_text"] = ci.tr("UI_SLOT_CHOOSE")
		return
	var old := int(info.get("replaces", -1))
	if old < 0:
		return
	var o := reader.card_info(old)
	face["replaces_id"] = o["id"]
	face["replaces_text"] = ci.tr("UI_SLOT_REPLACES") % ci.tr(o["name_key"])


## The level of card `code` in the wand now (BuildSlots' slots), or 0 when it isn't held.
static func held_level(reader: WorldReader, code: int) -> int:
	for s: Dictionary in reader.build()["slots"]:
		if int(s["code"]) == code:
			return int(s["level"])
	return 0


## The level badge: "Lv N" for a card not held (N is the level it arrives at), "Lv N → M" when
## taking it raises a held card from N to M. a level past the card's own max (`base`, 0: none) is an
## overlevel: the badge adds "✦ overlevel" (UI_CARD_OVERLEVEL).
static func level_text(ci: Object, held: int, to: int, cap: int = 5, base: int = 0) -> String:
	var s := ""
	if held <= 0 or held >= to:
		if cap < 5:  # A card of 3 levels reads "Lv 1/3"
			s = ci.tr("UI_WAND_LEVEL_OF") % [maxi(held, to), cap]
		else:
			s = ci.tr("UI_WAND_LEVEL") % maxi(held, to)
	else:
		s = ci.tr("UI_CARD_LEVEL_UP") % [held, to]
	if base > 0 and maxi(held, to) > base:
		s += " " + ci.tr("UI_CARD_OVERLEVEL")
	return s


## A card of the boss's legendary altar. it keeps its own tier (a Legendary
## card the legendary gold, a legendary stat card too; any other its tier's colour and word), so a Legendary card
## stands out. no level-5 version any more: a wand card there reads as anywhere else (an
## upgrade's badge "Lv N → N+1", card_face).
static func legendary_face(_ci: Object, face: Dictionary) -> Dictionary:
	return face.duplicate()


## A jackpot
## card's line starts with "Jackpot", and the face says so (`jackpot`).
static func jackpot_face(ci: Object, face: Dictionary) -> Dictionary:
	var out := face.duplicate()
	out["jackpot"] = true
	var line: String = face.get("tier_text", "")
	out["tier_text"] = (
		ci.tr("PICK_JACKPOT") if line == "" else "%s · %s" % [ci.tr("PICK_JACKPOT"), line]
	)
	return out


## The boss altar's title: "The boss left a Legendary card" when one of `slots` is a Legendary mod card
## (the gold frame on a mod), else "The boss's reward"; with picks left after this one, their count after it.
static func boss_title(ci: Object, slots: Array, picks_left: int) -> String:
	var key := "PICK_TITLE_BOSS"
	for s: PickSlot in slots:
		if s.tier == CardFrames.LEGENDARY_TIER and int(s.face_type()) == WorldReader.CARD_MOD:
			key = "PICK_TITLE_BOSS_LEGENDARY"
	var title: String = ci.tr(key)
	return ci.tr("PICK_TITLE_BOSS_MORE") % [title, picks_left] if picks_left > 0 else title


## Whether the open choice is the boss's legendary pick (by the reward, not the first card's tier).
func is_legendary() -> bool:
	return _open and _boss


func card_count() -> int:
	return _count


func slot(k: int) -> PickSlot:
	return _slots[k]


func title_text() -> String:
	return _title.full_text()


func _input(event: InputEvent) -> void:
	if not _open or not input_enabled or _sent:
		return
	if event is InputEventMouseMotion:
		_mouse_tilt = true
	var d := PanelInput.decode(event, 3, ECHO)
	if (
		d.kind
		in [
			PanelInput.Kind.DIGIT,
			PanelInput.Kind.CONFIRM,
			PanelInput.Kind.CANCEL,
			PanelInput.Kind.STEP
		]
	):
		_mouse_tilt = false
		skip_deal()  # A press during the deal ends it at once, and still counts
	match d.kind:
		PanelInput.Kind.DIGIT:
			_set_focus(d.digit)
		PanelInput.Kind.CONFIRM:
			_send(_focus + 1)
		PanelInput.Kind.CANCEL:
			_send(InputFrame.PICK_CANCEL)
		PanelInput.Kind.STEP:
			_set_focus(clampi(_focus + d.line(), 0, maxi(0, _count - 1)))
		_:
			return
	get_viewport().set_input_as_handled()


func _set_focus(k: int) -> void:
	if k < 0 or k >= _count:
		return
	_focus = k
	for s in _slots:
		s.set_focused(s.index == k)


func _on_clicked(k: int) -> void:
	if not _open or not input_enabled or _sent or k >= _count:
		return
	skip_deal()
	_set_focus(k)
	_send(k + 1)


## Ends the deal now (every card in place, face up); a pick press calls it before it counts.
func skip_deal() -> void:
	if not deal.done():
		deal.skip()
		_apply_deal()


func _send(value: int) -> void:
	_answer = value
	super(value)


func _start_deal() -> void:
	var tiers := []
	for k in _count:
		tiers.append(_slots[k].tier)
	deal.start(tiers, HudStyle.reduced_motion)
	for k in _count:
		var fx := _slots[k].card.fx
		fx.set_burn(0.0)
		fx.modulate = Color.WHITE
	_apply_deal()


## Puts every card where the deal has it now, and the background's dim.
func _apply_deal() -> void:
	var view_h := get_viewport_rect().size.y if is_inside_tree() else 1080.0
	for k in _count:
		var s := _slots[k]
		var fx := s.card.fx
		var arrive := deal.arrive(k)
		var fan := deal.fan(k)
		var below := (
			view_h - s.global_position.y + 60.0 if s.is_inside_tree() else CardDeal.FROM_BELOW
		)
		var drop := fan.y * s.card.scale_factor
		var off := Vector2(0, drop + below * (1.0 - arrive))
		fx.set_pose(
			off,
			fan.x * arrive + 0.3 * (1.0 - arrive) * signf(fan.x + 0.01),
			deal.width(k),
			deal.punch(k)
		)
		fx.set_side(deal.face_up(k), deal.back_glow(k))
		fx.set_light(deal.flash(k), deal.rays(k))
	_dim.color.a = _dim_base + DIM_WAIT * deal.dark()
	_rays.queue_redraw()


func _draw_rays() -> void:
	var inv := _rays.get_global_transform().affine_inverse()
	for k in _count:
		var fx := _slots[k].card.fx
		if fx.rays > 0.001 and _slots[k].visible:
			fx.draw_rays(_rays, inv * fx.global_position, fx.get_global_transform().get_scale().y)


func _process(delta: float) -> void:
	if _outro >= 0.0:
		_advance_outro(delta)
		return
	if not _open:
		return
	if deal.time < deal.length() + 2.0:  # the deal, then the rays and the dim settling after the last flip
		deal.advance(minf(delta, 0.1))
		_apply_deal()
	else:
		_rays.queue_redraw()  # the rays keep turning
	_hover()


## The focused card tilts toward the cursor (or a fixed tilt when focused by key or pad) and sinks; the others rest.
func _hover() -> void:
	var mouse := get_global_mouse_position()
	for k in _count:
		var s := _slots[k]
		var tilt := Vector2.ZERO
		if s.focused and not HudStyle.reduced_motion and deal.done():
			tilt = FOCUS_TILT
			var r := s.card.get_global_rect()
			if _mouse_tilt and r.has_point(mouse) and r.size.x > 0.0:
				tilt = (mouse - r.get_center()) / (r.size * 0.5)
		s.card.fx.set_hover(tilt, 1.0 if s.focused else 0.0)


## The choice closed. After a pick (or a dealt chest's answer) the picked card's icon flies to the HUD and
## the others burn; after a cancel the panel just goes.
func _on_closed() -> void:
	var k := _answer - 1 if _answer > 0 else (0 if _dealt else -1)
	if k < 0 or k >= _count or (_answer <= 0 and _still_there()):
		return  # a cancel; or a chest's card that needs the swap, left for later
	card_taken.emit(_codes[k], _slots[k].card.socket.get_global_rect())
	visible = true
	_outro = 0.0
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in _slots:
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picked = k


## The choice's reward still stands (its card was not taken).
func _still_there() -> bool:
	if _reader == null:
		return false
	for i in _reader.reward_count():
		if _reader.reward_id(i) == _reward:
			return true
	return false


func _advance_outro(delta: float) -> void:
	_outro += delta
	var reduced := HudStyle.reduced_motion
	var length := OUTRO_REDUCED_S if reduced else OUTRO_S
	var t := clampf(_outro / length, 0.0, 1.0)
	for k in _count:
		var fx := _slots[k].card.fx
		fx.set_light(0.0, deal.rays(k) * (1.0 - t))  # the rays sink with the cards
		_rays.queue_redraw()
		if k == _picked:
			fx.modulate.a = 1.0 - clampf(t * 3.0, 0.0, 1.0)  # its icon is flying; the card fades fast
			_slots[k].burn_replaced(t)  # The card it replaces burns
		elif reduced:
			fx.modulate.a = 1.0 - t
		else:
			fx.set_burn(t)
	_dim.color.a = _dim_base * (1.0 - t)
	modulate.a = 1.0 if t < 0.8 else (1.0 - t) * 5.0
	if t >= 1.0:
		_end_outro()
		visible = _open


## The outro is over (or a new choice opened): the cards whole again, the panel's clicks back.
func _end_outro() -> void:
	if _outro < 0.0:
		return
	_outro = -1.0
	_picked = -1
	modulate.a = 1.0
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	for s in _slots:
		s.mouse_filter = Control.MOUSE_FILTER_STOP
		s.card.fx.set_burn(0.0)
		s.card.fx.modulate = Color.WHITE
		s.burn_replaced(0.0)


## The outro is playing (the picked card's icon flying, the others burning), and which card was picked.
func outro_playing() -> bool:
	return _outro >= 0.0


func picked_slot() -> int:
	return _picked


func _place(col: VBoxContainer) -> void:
	match layout:
		Layout.ROW_CENTRE:
			var centre := CenterContainer.new()
			centre.set_anchors_preset(Control.PRESET_FULL_RECT)
			centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(centre)
			centre.add_child(col)
		Layout.ROW_LOW:
			add_child(col)
			col.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
			col.grow_horizontal = Control.GROW_DIRECTION_BOTH
			col.grow_vertical = Control.GROW_DIRECTION_BEGIN
			col.offset_bottom = -190
		Layout.COLUMN_RIGHT:
			add_child(col)
			col.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
			col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			col.grow_vertical = Control.GROW_DIRECTION_BOTH
			col.offset_right = -40
