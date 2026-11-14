class_name Modifiers
extends RefCounted
## docs/design/MODIFIER_ENGINE.md §2, §7; SIM_CONTRACTS §5b: compiles the build into attack specs.
## compile(w) runs when the build changes (an item picked, an ability's level, a save restored: World invalidates
## the cache) and the first time a spec is read after that, never every tick; the result is cached on
## World.attack_book and its digest is hashed.
##
## The build's modifiers are the modifier slots' (World.mod_slots, v0.6.0 MX2: an item's ItemTable.modifiers, an
## ability's AbilityTable.modifiers), in slot order (the wand's order, which the player rearranges). Each
## base spec (the Blade's combo steps, the Gun's bolt, the Skill, MX2 each held ability modifier's attack) is
## rewritten by the cards left to right (WandCompile: each card changes the spell built so far, a trigger card ends it
## and the cards to its right build the child spell it casts); v0.6.0's fixed stage sort across cards is gone (inside
## one card its ops still run in stage order).
##
## v0.6.0 MX2, the ability modifiers carry the build (owner B7: "each carries your other modifiers"): after its own
## compile, an ability's spec takes the weapon's statuses (not the riders), elements and ON_HIT / ON_KILL hooks
## (inherit: the Blade's first step, or the Gun's bolt), and the drone's copy of a Gun also takes the bolt's pattern
## and behaviour (count, spread, split share, bounces, pierce). So a burning sword makes burning bombs, and a
## ricochet gun gives its drone ricochet shots. A modifier rewrites a spec only
## when the spec carries every tag of its target. So the result never depends on luck, and a seed replays exactly
## (no randomness here: EI-05).
##
## Rules (design §2): numeric ops change one field (SET, ADD, MAX, MIN, MUL_PERMILLE); SET_FORM changes the form (a
## later form op layers); STATUS sets a status the spec's hits feed; ELEMENT adds an element the view draws
## (stacking, no repeats); HOOK adds a child attack at depth + 1, compiled by its own card and the cards to its right
## (v0.6.5 WN1; none below MAX_DEPTH, so compiling always ends; the loop's WandCompile.max_depth).
##
## Riders (the v0.5 rules kept exact): a Blade step's hits burn whenever the burn engine runs (Wildfire or Flame
## Trail with no Ember Edge did that before MX1), and the bolt's hits slow whenever the slow runs (Glacial Edge or
## Cold Snap without Frost Core). A rider is a status, never an element.

const MAX_DEPTH := 2
const GUN_BOLT := &"gun_bolt"
const SKILL := &"skill"
const TAG_WEAPON := "weapon"
const TAG_MELEE := "melee"
const TAG_PROJECTILE := "projectile"
const TAG_SKILL := "skill"
const TAG_HOOK := "hook"
const TAG_ABILITY := "ability"
## The moments that launch from specs (the dash, walking, a blink, the body's rules; Vent's blast is an
## attack). A moment's spec is rewritten only by a modifier whose target names its tag (an empty target means every
## attack, not every moment).
const TAG_MOMENT := "moment"
const DASH := &"dash"
const VENT := &"vent"
const MOVE := &"move"
const BLINK := &"blink"
const BODY := &"body"
## Walking this far (not dashing) launches the move spec's ON_LAUNCH hooks (Ember Trail; a starting
## value).
const MOVE_STEP_M := 1.4
## Frost Nova's ring grows to its radius over this many ticks (a starting value).
const RING_TICKS := 18
## A hook's lingering child when its op names no time: a lob's flight, a zone's life and its hit gap.
const HOOK_LOB_TICKS := 30
const HOOK_ZONE_TICKS := 90
const HOOK_ZONE_GAP := 30


## The cached book, compiled now if the build changed since the last read.
static func book(w: World) -> AttackBook:
	if w.attack_book == null:
		w.attack_book = compile(w)
	return w.attack_book


## The build changed: the next read compiles again.
static func invalidate(w: World) -> void:
	w.attack_book = null


static func step_id(k: int) -> StringName:
	return StringName("blade_step_%d" % k)


## Combo step `k`'s compiled spec.
static func step(w: World, k: int) -> AttackSpec:
	return book(w).spec(step_id(k))


static func bolt(w: World) -> AttackSpec:
	return book(w).spec(GUN_BOLT)


## The Skill's spec (null without one).
static func skill(w: World) -> AttackSpec:
	return book(w).spec(SKILL)


## The build's modifiers in slot order (World.mod_slots; each slot's card's modifiers in its order).
## A Form card's (the Laser) come first, wherever it sits, so it makes the Gun's shot itself, never a
## trigger's cast, and every Pattern, Secondary and Element card shapes the form.
static func build_modifiers(w: World) -> Array[ModifierTable]:
	return build_modifiers_of(w, w.mod_slots)


## build_modifiers for the card codes `codes` in this order (a wand the player hasn't made yet: the Build
## page's reorder, the Swap's answer; WandForecast). build_modifiers is this on the held wand, so the two can't differ.
static func build_modifiers_of(w: World, codes: PackedInt32Array) -> Array[ModifierTable]:
	var out: Array[ModifierTable] = []
	var form: Array[ModifierTable] = []  # The Form card shapes the root shot wherever it sits
	for code in codes:
		if Offers.type_of(code) == Offers.ABILITY:
			var idx := Offers.ability_of(code)
			if idx < w.ability_tables.size():
				out.append_array(w.ability_tables[idx].modifiers)
		elif code < w.item_tables.size() and AttackSlots.compiles(w, code):  # The form's table
			var lvl := CardLevels.base_level(w, code)  # A wand card at its level (W3-P3: at most its max)
			# Its overlevels grow its main number; an element's grows in ElementStack.level_permille
			var over := 1000
			if LootPacing.category(w, code) != LootPacing.Category.ELEMENT:
				over = CardLevels.overlevel_now(w, code)
			var to := form if AttackSlots.category(w, code) == AttackSlots.FORM else out
			for m in w.item_tables[code].modifiers:
				to.append(m.at(lvl).overlevelled(over))
	form.append_array(out)
	return form


## The moments' specs (never null once compiled: every book has them) and Vent's (null without heat).
static func dash(w: World) -> AttackSpec:
	return book(w).spec(DASH)


static func move(w: World) -> AttackSpec:
	return book(w).spec(MOVE)


static func blink(w: World) -> AttackSpec:
	return book(w).spec(BLINK)


static func body(w: World) -> AttackSpec:
	return book(w).spec(BODY)


static func vent(w: World) -> AttackSpec:
	return book(w).spec(VENT)


## The weapon's last attack, which a WEAPON hook child copies (Long Shadow, Meltdown Edge): the Blade's
## current combo step on a run with the Blade, else the Gun's shot.
static func weapon_attack(w: World) -> AttackSpec:
	var n := w.player.combo.size()
	if PlayerBuild.has_blade(w) and n > 0:
		return step(w, clampi(w.combo_step, 0, n - 1))
	return bolt(w)


## That attack's damage under the build's weapon factor (rounded down, no remainder carried: a copy
## never shifts the weapon's own numbers).
static func weapon_damage(w: World) -> int:
	var s := weapon_attack(w)
	if s == null:
		return 1
	var pm := Abilities.weapon_permille(w) * CardLevels.weapon_overlevel_permille(w) / 1000  # W3-P3: overlevels
	if s.form == AttackSpec.Form.ARC and s.has_tag(&"melee"):
		pm = w.player.melee_damage_permille * pm / 1000
		return maxi(1, s.damage * pm / 1000)
	pm = w.player.bolt_damage_permille * pm / 1000
	return maxi(1, Attacks.bolt_base_damage(s) * pm / 1000)


## An owned ability modifier's compiled spec (by its ability id), or null.
static func ability(w: World, t: AbilityTable) -> AttackSpec:
	return book(w).spec(t.id) if t != null else null


static func compile(w: World) -> AttackBook:
	var b := compile_for(w, build_modifiers(w))
	ElementPairs.refresh(w)  # The element pairs follow the cards' levels
	return b


## The book of `w`'s player table with `mods` (in this order) and w's riders. Tests compile any list with it.
static func compile_for(w: World, mods: Array[ModifierTable]) -> AttackBook:
	var b := AttackBook.new()
	for m in mods:
		b.modifier_ids.append(String(m.id))
	var wand := WandCompile.for_world(w, mods)  # Slot order, triggers cut the wand
	for k in w.player.combo.size():
		b.add(BladeForms.settle(wand.spec(base_step(w, k)), wand.max_depth))  # Finisher+'s carry
	b.add(wand.spec(base_bolt(w)))
	var sk := _base_skill(w)
	if sk != null:
		b.add(wand.spec(sk))
	for id: StringName in [DASH, MOVE, BLINK, BODY]:  # The moments
		b.add(wand.spec(_base_moment(id)))
	if w.heat != null:  # Vent's blast
		b.add(wand.spec(_base_vent(w)))
	_riders(w, b)
	b.register()
	b.seal()
	return b


## `s` takes `root`'s statuses (not its riders; a status `s` already has stays), elements and ON_HIT /
## ON_KILL hooks (shared, as compiled for the weapon); with `copy`, a bolt root's pattern and behaviour too.
## The hooks only while `s` is shallower than `max_depth` (the compile's: WandCompile.max_depth).
static func inherit(s: AttackSpec, root: AttackSpec, copy: bool, max_depth := MAX_DEPTH) -> void:
	if root == null:
		return
	for k in root.status_ids.size():
		if root.status_rider[k] == 0 and not s.has_status(StringName(root.status_ids[k])):
			s.set_status(
				StringName(root.status_ids[k]), root.status_stacks[k], root.status_every[k]
			)
	for e in root.elements:
		if not s.elements.has(e):
			s.elements.append(e)
	for m in root.modifier_ids:
		if not s.modifier_ids.has(m):
			s.modifier_ids.append(m)
	if s.depth < max_depth:
		for h in root.hooks:
			if h.trigger == AttackSpec.Trigger.ON_HIT or h.trigger == AttackSpec.Trigger.ON_KILL:
				s.hooks.append(h)
	if copy and root.form == AttackSpec.Form.BOLT:
		s.count = maxi(s.count, root.count)
		s.spread = root.spread
		s.damage_permille = root.damage_permille
		s.bounces = maxi(s.bounces, root.bounces)
		s.pierce = maxi(s.pierce, root.pierce)


## Hashes the build's specs once it has a modifier (worlds without one, the kernel goldens among them, keep their
## hash; the specs are then the player table's, already hashed by what they derive from).
static func hash_into(w: World, h: StateHasher) -> void:
	var b := book(w)
	if b.modifier_ids.is_empty():
		return
	h.add_string(b.digest)
	ModifierRuntime.hash_into(w, h)  # The queue, the counters, poison, projectile behaviours


## A moment's spec (the dash, walking, a blink, the body): no damage of its own, only hooks and rules.
static func _base_moment(id: StringName) -> AttackSpec:
	var s := AttackSpec.new()
	s.id = id
	s.form = AttackSpec.Form.BURST
	s.tags = PackedStringArray([String(id), TAG_MOMENT])
	return s


## Vent's blast (Heat.vent): a burst of the heat table's radius; its damage is the heat vented.
static func _base_vent(w: World) -> AttackSpec:
	var s := AttackSpec.new()
	s.id = VENT
	s.form = AttackSpec.Form.BURST
	s.tags = PackedStringArray([String(VENT), "area"])
	s.radius_m = w.heat.table.vent_radius_m
	return s


## One numeric op on `s` (SET, ADD, MAX, MIN, MUL_PERMILLE on an AttackSpec field, or the virtual `range`).
static func numeric(s: AttackSpec, op: ModifierOp) -> void:
	if op.field == &"halo_homing_permille":  # Spent at the end of the compile (SpecForms)
		s.halo_homing_permille = int(op.value)
		return
	if op.field == &"range":  # The form's own range field (SpecForms.range_of)
		if op.op == ModifierOp.Op.MUL_PERMILLE:
			SpecForms.scale_range(s, op.value)
		return
	if op.field in AttackSpec.FLOAT_FIELDS:
		var cur: float = s.get(op.field)
		var v := op.value
		match op.op:
			ModifierOp.Op.SET:
				cur = v
			ModifierOp.Op.ADD:
				cur += v
			ModifierOp.Op.MAX:
				cur = maxf(cur, v)
			ModifierOp.Op.MIN:
				cur = minf(cur, v)
			ModifierOp.Op.MUL_PERMILLE:
				cur = cur * v / 1000.0
		s.set(op.field, cur)
		return
	var c: int = s.get(op.field)
	var iv := int(op.value)
	if op.field == &"share_permille":  # Shares multiply down the wand (0 = whole)
		c = c if c > 0 else 1000
		if op.op == ModifierOp.Op.MUL_PERMILLE:
			s.damage_mul_permille = s.damage_mul_permille * iv / 1000  # the view's weight is each bolt's
	match op.op:
		ModifierOp.Op.SET:
			c = iv
		ModifierOp.Op.ADD:
			c += iv
		ModifierOp.Op.MAX:
			c = maxi(c, iv)
		ModifierOp.Op.MIN:
			c = mini(c, iv)
		ModifierOp.Op.MUL_PERMILLE:
			c = c * iv / 1000
			if op.field == &"damage":  # The weight the view draws
				s.damage_mul_permille = s.damage_mul_permille * iv / 1000
	s.set(op.field, c)


## The v0.5 riders (see the class doc), after every modifier: statuses the engines already running bring.
## A rider rides only on an engine something outside the wand runs (a v0.5 item, an ability's borrow):
## a wand card's own status (Fire's burn, Frost's slow) goes where the card sits, so Fire right of a trigger burns
## the child and not the slash.
static func _riders(w: World, b: AttackBook) -> void:
	var m := w.item_mods
	var burn := m.burn_max_stacks > 0 and _engine_outside_wand(w, true)
	var slow := m.slow_ticks > 0 and _engine_outside_wand(w, false)
	for id in b.order:
		var s: AttackSpec = b.specs[StringName(id)]
		if s.depth != 0 or not s.has_tag(TAG_WEAPON):
			continue
		if s.has_tag(TAG_MELEE) and burn and not s.has_status(&"burn"):
			s.set_status(&"burn", 1, 0, true)
		if s.has_tag(TAG_PROJECTILE) and slow and not s.has_status(&"slow"):
			s.set_status(&"slow", 1, 0, true)


## The burn (`burn`) or the slow engine runs from something other than a wand card (CardLevels.is_card):
## an owned item that isn't one brings its numbers, or no owned item does (an ability borrows it).
static func _engine_outside_wand(w: World, burn: bool) -> bool:
	var from_item := false
	for idx in w.items_owned:
		var t := w.item_tables[idx]
		if (t.burn_max_stacks if burn else t.slow_ticks) <= 0:
			continue
		if not CardLevels.is_card(w, idx):
			return true
		from_item = true
	return not from_item


## Combo step `k` as the player table has it (public, the wand's child spell copies it).
static func base_step(w: World, k: int) -> AttackSpec:
	var st: SwingStep = w.player.combo[k]
	var s := AttackSpec.new()
	s.id = step_id(k)
	s.form = AttackSpec.Form.ARC
	s.tags = PackedStringArray([TAG_WEAPON, TAG_MELEE])
	if k == w.player.combo.size() - 1:
		s.tags.append("finisher")  # The combo's last step (Finisher+ targets it)
	s.half_arc = st.half_arc
	s.reach_m = st.reach_m
	s.damage = st.damage
	s.hitstop_ticks = st.hitstop_ticks
	return s


## The Gun's bolt as the player table has it.
static func base_bolt(w: World) -> AttackSpec:
	var t := w.player
	var s := AttackSpec.new()
	s.id = GUN_BOLT
	s.form = AttackSpec.Form.BOLT
	s.tags = PackedStringArray([TAG_WEAPON, TAG_PROJECTILE])
	s.radius_m = t.bolt_radius_m
	s.speed = t.bolt_speed
	s.life_ticks = t.bolt_life_ticks
	s.period_ticks = t.shot_period_ticks
	s.damage = t.bolt_damage
	return s


## Lunge Cleave: an arc tagged skill + melee; Scatter Blast: a fan of beams (pellets) tagged skill + projectile.
## Weapon-targeted modifiers (every v0.5 item's) leave both alone, as before MX1.
static func _base_skill(w: World) -> AttackSpec:
	var t := w.player.skill
	if t == null:
		return null
	var s := AttackSpec.new()
	s.id = SKILL
	s.damage = t.damage
	s.hitstop_ticks = t.hitstop_ticks
	if t.kind == SkillTable.Kind.LUNGE_CLEAVE:
		s.form = AttackSpec.Form.ARC
		s.tags = PackedStringArray([TAG_SKILL, TAG_MELEE])
		s.half_arc = t.half_arc
		s.reach_m = t.reach_m
	else:
		s.form = AttackSpec.Form.BEAM
		s.tags = PackedStringArray([TAG_SKILL, TAG_PROJECTILE])
		s.count = t.pellets
		s.spread = 2 * t.half_cone
		s.reach_m = t.range_m
		s.radius_m = t.pellet_radius_m
	return s


## Overcharge's shockwave radius as the view and Resonance read it: the first ON_NTH burst of the combo's steps
## (0 without one).
static func nth_burst_radius_m(w: World) -> float:
	for k in w.player.combo.size():
		for h in step(w, k).hooks_on(AttackSpec.Trigger.ON_NTH):
			if h.child.form == AttackSpec.Form.BURST:
				return h.child.radius_m
	return 0.0
