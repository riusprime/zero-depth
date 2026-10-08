class_name Modifiers
extends RefCounted
## v0.6.0 MX1 (docs/design/MODIFIER_ENGINE.md §2, §7; SIM_CONTRACTS §5b): compiles the build into attack specs.
## compile(w) runs when the build changes (an item picked, an ability's level, a save restored: World invalidates
## the cache) and the first time a spec is read after that, never every tick; the result is cached on
## World.attack_book and its digest is hashed.
##
## The build's modifiers are the owned items' (ItemTable.modifiers), in pick order. Each base spec (the Blade's combo
## steps, the Gun's bolt, the Skill) goes through every modifier stage by stage (FORM, PATTERN, BEHAVIOUR, PAYLOAD,
## HOOK, SCALE); inside a stage, modifiers in pick order and each one's ops in order. A modifier rewrites a spec only
## when the spec carries every tag of its target. So the result never depends on luck, and a seed replays exactly
## (no randomness here: EI-05).
##
## Rules (design §2): numeric ops change one field (SET, ADD, MAX, MIN, MUL_PERMILLE); SET_FORM changes the form (a
## later form op layers: MX1 has none, the rule lands with the first form cards); STATUS sets a status the spec's hits
## feed; ELEMENT adds an element the view draws (stacking, no repeats); HOOK adds a child attack, itself compiled
## through every modifier at depth + 1 (none below MAX_DEPTH, so compiling always ends).
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


## The build's modifiers in pick order: each owned item's, in the item's order.
static func build_modifiers(w: World) -> Array[ModifierTable]:
	var out: Array[ModifierTable] = []
	for idx in w.items_owned:
		out.append_array(w.item_tables[idx].modifiers)
	return out


static func compile(w: World) -> AttackBook:
	return compile_for(w, build_modifiers(w))


## The book of `w`'s player table with `mods` (in this order) and w's riders. Tests compile any list with it.
static func compile_for(w: World, mods: Array[ModifierTable]) -> AttackBook:
	var b := AttackBook.new()
	for m in mods:
		b.modifier_ids.append(String(m.id))
	for k in w.player.combo.size():
		b.add(compile_spec(_base_step(w, k), mods))
	b.add(compile_spec(_base_bolt(w), mods))
	var sk := _base_skill(w)
	if sk != null:
		b.add(compile_spec(sk, mods))
	_riders(w, b)
	b.seal()
	return b


## Hashes the build's specs once it has a modifier (worlds without one, the kernel goldens among them, keep their
## hash; the specs are then the player table's, already hashed by what they derive from).
static func hash_into(w: World, h: StateHasher) -> void:
	var b := book(w)
	if b.modifier_ids.is_empty():
		return
	h.add_string(b.digest)


## `base` rewritten by `mods` in the stage order from `first_stage` on (a fresh spec; `base` is not written).
static func compile_spec(
	base: AttackSpec, mods: Array[ModifierTable], first_stage: int = 0
) -> AttackSpec:
	var s := base.copy()
	for stage in range(first_stage, ModifierTable.STAGE_COUNT):
		for m in mods:
			if not s.matches(m.target):
				continue
			var applied := false
			for op in m.ops:
				if op.stage == stage:
					_apply(s, m, op, mods)
					applied = true
			if applied and not s.modifier_ids.has(String(m.id)):
				s.modifier_ids.append(String(m.id))
	return s


static func _apply(
	s: AttackSpec, m: ModifierTable, op: ModifierOp, mods: Array[ModifierTable]
) -> void:
	match op.op:
		ModifierOp.Op.SET_FORM:
			if s.form_layers == 0:
				s.form = op.form
				s.form_layers = 1
			elif s.depth < MAX_DEPTH:
				s.hooks.append(_layer(s, m, op, mods))
				s.form_layers += 1
		ModifierOp.Op.STATUS:
			s.set_status(op.status, op.stacks, op.every)
		ModifierOp.Op.ELEMENT:
			if not s.elements.has(String(op.element)):
				s.elements.append(String(op.element))
		ModifierOp.Op.HOOK:
			if s.depth < MAX_DEPTH:
				s.hooks.append(_hook(s, m, op, mods))
		_:
			_numeric(s, op)


static func _numeric(s: AttackSpec, op: ModifierOp) -> void:
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
	s.set(op.field, c)


## The hook `op` of modifier `m` adds to `s`: its child spec, compiled through every modifier one level deeper.
static func _hook(
	s: AttackSpec, m: ModifierTable, op: ModifierOp, mods: Array[ModifierTable]
) -> AttackHook:
	var c := AttackSpec.new()
	c.id = m.id
	c.form = op.form
	c.tags = op.hook_tags.duplicate()
	if not c.tags.has(TAG_HOOK):
		c.tags.append(TAG_HOOK)
	c.depth = s.depth + 1
	c.radius_m = op.radius_m
	c.reach_m = op.reach_m
	c.seek = op.form == AttackSpec.Form.BEAM
	c.effect_id = op.effect_id
	var k := AttackHook.new()
	k.id = m.id
	k.trigger = op.trigger
	k.every = op.hook_every
	k.damage = op.damage
	k.damage_permille = op.damage_permille
	k.child = compile_spec(c, mods)
	return k


## The form-layering rule (design §2, owner B8): a second form op never replaces the first; it adds an attack in its
## own form that fires where the spec ends (ON_END), carrying everything the spec carries so far, then compiled
## through the stages after FORM (so it layers once and every later pattern, payload and hook op reaches it too).
static func _layer(
	s: AttackSpec, m: ModifierTable, op: ModifierOp, mods: Array[ModifierTable]
) -> AttackHook:
	var c := s.copy()
	c.id = m.id
	c.form = op.form
	c.form_layers = 1
	c.depth = s.depth + 1
	c.hooks = []
	c.seek = false
	if not c.tags.has(TAG_HOOK):
		c.tags.append(TAG_HOOK)
	var k := AttackHook.new()
	k.id = m.id
	k.trigger = AttackSpec.Trigger.ON_END
	k.damage_permille = 1000
	k.child = compile_spec(c, mods, ModifierTable.Stage.PATTERN)
	return k


## The v0.5 riders (see the class doc), after every modifier: statuses the engines already running bring.
static func _riders(w: World, b: AttackBook) -> void:
	var m := w.item_mods
	for id in b.order:
		var s: AttackSpec = b.specs[StringName(id)]
		if s.depth != 0 or not s.has_tag(TAG_WEAPON):
			continue
		if s.has_tag(TAG_MELEE) and m.burn_max_stacks > 0 and not s.has_status(&"burn"):
			s.set_status(&"burn", 1, 0, true)
		if s.has_tag(TAG_PROJECTILE) and m.slow_ticks > 0 and not s.has_status(&"slow"):
			s.set_status(&"slow", 1, 0, true)


static func _base_step(w: World, k: int) -> AttackSpec:
	var st: SwingStep = w.player.combo[k]
	var s := AttackSpec.new()
	s.id = step_id(k)
	s.form = AttackSpec.Form.ARC
	s.tags = PackedStringArray([TAG_WEAPON, TAG_MELEE])
	s.half_arc = st.half_arc
	s.reach_m = st.reach_m
	s.damage = st.damage
	s.hitstop_ticks = st.hitstop_ticks
	return s


static func _base_bolt(w: World) -> AttackSpec:
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
