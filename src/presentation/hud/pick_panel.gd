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

enum Layout { ROW_CENTRE, ROW_LOW, COLUMN_RIGHT }

## Key repeats (PanelInput.Echo): a held key repeats (the sent latch stops a second answer).
const ECHO := PanelInput.Echo.ACT
const SLOTS := 3
## v0.8.0 RR (owner O33): the tier words in order (Offers.info's rarity: common, rare, epic, legendary).
const RARITY_KEYS: Array[String] = [
	"RARITY_COMMON", "RARITY_RARE", "RARITY_EPIC", "RARITY_LEGENDARY"
]

var layout := Layout.ROW_CENTRE
var _dim := ColorRect.new()
var _title := Label.new()
var _price_icon := ShardIcon.new(26.0)
var _hint := Label.new()
var _slots: Array[PickSlot] = []
var _count := 0
var _reward := -1
var _boss := false  # v0.8.0 RR: the open choice is the boss's altar
var _swap_seen := false


func _init(p_layout: Layout = Layout.ROW_CENTRE) -> void:
	layout = p_layout
	name = "PickPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_dim(_dim, 0.18 if layout == Layout.ROW_LOW else 0.45)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 14)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 10)
	head.add_child(_title)
	head.add_child(_price_icon)
	_price_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(head)
	var groove := MenuPanel.TitleGroove.new(true)  # v0.8.0 MU: the Ember stone title's glowing groove
	groove.custom_minimum_size = Vector2(0, 12)
	col.add_child(groove)
	var cards: BoxContainer = (
		VBoxContainer.new() if layout == Layout.COLUMN_RIGHT else HBoxContainer.new()
	)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards.add_theme_constant_override("separation", 18)
	col.add_child(cards)
	col.add_child(_hint)
	HudStyle.style_label(_title, 28, true)  # v0.3.5 F16: the HUD's plain type
	_title.add_theme_color_override("font_shadow_color", Color(EmberStone.EMBER, 0.3))  # v0.8.0 MU
	_title.add_theme_constant_override("shadow_outline_size", 12)
	HudStyle.style_label(_hint, 15)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	style_labels([_title, _hint])
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
	if _closed(reader.choosing()):
		return
	var r := reader.choice_reward()
	var rid := reader.reward_id(r)
	if reader.swapping():  # v0.6.0 MX2: the Swap choice (SwapPanel) sits over the cards
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
	var items := reader.choice_items()
	var legendary := reader.reward_is_legendary(r)  # v0.5.5 AR (X1b)
	_boss = legendary
	_count = items.size()
	for k in SLOTS:
		var s := _slots[k]
		s.visible = k < _count
		if k >= _count:
			continue
		var face := card_face(self, reader, items[k])  # v0.4.0 BS: a mod, an ability or a stat card
		if legendary:
			face = legendary_face(self, face, reader.legendary_card_level(r))
		s.show_card(face)
		var curse := reader.choice_curse(k)  # v0.5.0 EV: a cursed chest card says so
		s.show_curse(CurseLook.down_line(self, reader, curse) if curse >= 0 else "")  # v0.6.0 CU
	var chest := reader.reward_kind(r) == WorldReader.REWARD_CHEST
	_title.text = (
		tr("PICK_TITLE_CHEST") % reader.reward_price(r) if chest else tr("PICK_TITLE_ALTAR")
	)
	if reader.reward_is_epic(r):  # v0.5.0 RT
		_title.text = tr("PICK_TITLE_EPIC_ALTAR")
	if legendary:  # v0.5.5 AR (X1b): the boss's reward; v0.8.0 RR: says when it holds a Legendary card
		_title.text = boss_title(self, _slots.slice(0, _count), reader.legendary_picks_left())
	var drop := reader.reward_drop_kind(r)  # v0.6.0 CU: a stolen core, Marked's card
	if drop == WorldReader.DROP_CORE or drop == WorldReader.DROP_BOSS_CORE:
		_title.text = tr("PICK_TITLE_CORE")
	elif drop == WorldReader.DROP_ELITE_CARD:
		_title.text = tr("PICK_TITLE_ELITE_DROP")
	_price_icon.visible = chest
	_hint.text = tr("PICK_HINT")
	_set_focus(0)


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
		"type": int(info["type"]),  # v0.5.5 A4: the colour's family falls back on the card's type
		"wand": bool(info.get("wand", false)),  # v0.6.5 WN5b: a wand card (levels 1–5)
		"level_text": "",  # v0.7.5 SM: the level badge ("Lv 1", "Lv 2 → 3"); "" for a card with no level
		"held_level": 0,  # v0.7.5 SM: the level held now (0: not held)
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
		WorldReader.CARD_STAT:
			var args := [GambleIcons.percent(int(info["amount"]))]
			if int(info.get("side", 0)) > 0:  # v0.5.0 CP: a rule card's second number
				args.append(GambleIcons.percent(int(info["side"])))
			face["sentence"] = ci.tr(info["desc_key"]) % args
			face["tier_text"] = ci.tr(RARITY_KEYS[clampi(face["tier"], 0, 3)])
			if face["tier"] == WorldReader.RARITY_LEGENDARY:  # v0.5.5 AR: tier 3 is the ability's; legendary has its own
				face["tier"] = CardFrames.LEGENDARY_TIER
		WorldReader.CARD_CURSE:  # v0.6.0 CU: a trade-off curse card: its name, its upside, rare
			face["sentence"] = CurseLook.up_sentence(ci, reader, int(info["curse"]))
			face["color"] = CurseLook.COLOR
			face["tier_text"] = "%s · %s" % [ci.tr("UI_CARD_CURSE"), ci.tr("RARITY_RARE")]
		_:
			face["color"] = ItemLooks.color_of_id(id)
			# v0.8.0 RR (owner O33): the four tiers' words; a Legendary card wears the legendary gold
			var rarity: String = ci.tr(RARITY_KEYS[clampi(face["tier"], 0, 3)])
			if face["tier"] == WorldReader.RARITY_LEGENDARY:
				face["tier"] = CardFrames.LEGENDARY_TIER
			var run := not reader.abilities().is_empty()  # a run with abilities: say it's a mod
			var kind_key := "UI_CARD_MODIFIER" if info.get("modifier", false) else "UI_CARD_MOD"  # v0.6.0 MX2
			face["tier_text"] = "%s · %s" % [ci.tr(kind_key), rarity] if run else rarity
			if face["wand"]:  # v0.7.5 SM (N8): a wand card's level, and the level taking it gives
				face["held_level"] = held_level(reader, code)
				face["level_text"] = level_text(ci, face["held_level"], face["held_level"] + 1)
	return face


## v0.7.5 SM (N8): the level of card `code` in the wand now (BuildSlots' slots), or 0 when it isn't held.
static func held_level(reader: WorldReader, code: int) -> int:
	for s: Dictionary in reader.build()["slots"]:
		if int(s["code"]) == code:
			return int(s["level"])
	return 0


## v0.7.5 SM (N8): the level badge: "Lv N" for a card not held (N is the level it arrives at), "Lv N → M" when
## taking it raises a held card from N to M.
static func level_text(ci: Object, held: int, to: int) -> String:
	if held <= 0 or held >= to:
		return ci.tr("UI_WAND_LEVEL") % maxi(held, to)
	return ci.tr("UI_CARD_LEVEL_UP") % [held, to]


## v0.5.5 AR (X1b): a card of the boss's legendary altar. v0.8.0 RR (owner O33): it keeps its own tier (a Legendary
## card the legendary gold, a legendary stat card too; any other its tier's colour and word), so a Legendary card
## stands out among the boss's level-5 versions. v0.6.5 WN5b: a wand card taken there goes to `wand_level`: the line
## says "Mod · Level 5 · <tier>" and the badge "Lv 5".
static func legendary_face(ci: Object, face: Dictionary, wand_level: int = 0) -> Dictionary:
	var out := face.duplicate()
	if wand_level > 0 and bool(face.get("wand", false)):
		var tier := int(face["tier"])
		var word: String = ci.tr(
			RARITY_KEYS[3 if tier == CardFrames.LEGENDARY_TIER else clampi(tier, 0, 2)]
		)
		word = "%s · %s" % [ci.tr("UI_CARD_ABILITY_LEVEL") % wand_level, word]
		out["level_text"] = level_text(ci, int(face.get("held_level", 0)), wand_level)  # v0.7.5 SM
		out["tier_text"] = "%s · %s" % [ci.tr("UI_CARD_MOD"), word]
	return out


## v0.8.0 RR: the boss altar's title: "The boss left a Legendary card" when one of `slots` is a Legendary mod card
## (the gold frame on a mod), else "The boss's reward"; with picks left after this one, their count after it.
static func boss_title(ci: Object, slots: Array, picks_left: int) -> String:
	var key := "PICK_TITLE_BOSS"
	for s: PickSlot in slots:
		if s.tier == CardFrames.LEGENDARY_TIER and int(s.face_type()) == WorldReader.CARD_MOD:
			key = "PICK_TITLE_BOSS_LEGENDARY"
	var title: String = ci.tr(key)
	return ci.tr("PICK_TITLE_BOSS_MORE") % [title, picks_left] if picks_left > 0 else title


## Whether the open choice is the boss's legendary pick (v0.8.0 RR: by the reward, not the first card's tier).
func is_legendary() -> bool:
	return _open and _boss


func card_count() -> int:
	return _count


func slot(k: int) -> PickSlot:
	return _slots[k]


func title_text() -> String:
	return _title.text


func _input(event: InputEvent) -> void:
	if not _open or not input_enabled or _sent:
		return
	var d := PanelInput.decode(event, 3, ECHO)
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
	_set_focus(k)
	_send(k + 1)


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
