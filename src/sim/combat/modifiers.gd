class_name Modifiers
extends RefCounted
## v0.6.0 MX1 (docs/design/MODIFIER_ENGINE.md §2, §7; SIM_CONTRACTS §5b): compiles the build into attack specs.
## compile(w) runs when the build changes (an item picked, an ability's level, a save restored: World invalidates
## the cache) and the first time a spec is read after that, never every tick; the result is cached on
## World.attack_book and its digest is hashed.
##
## The build's modifiers are the modifier slots' (World.mod_slots, v0.6.0 MX2: an item's ItemTable.modifiers, an
## ability's AbilityTable.modifiers), in slot order (the pick order). Each base spec (the Blade's combo steps, the
## Gun's bolt, the Skill, MX2 each held ability modifier's attack) goes through every modifier stage by stage (FORM,
## PATTERN, BEHAVIOUR, PAYLOAD, HOOK, SCALE); inside a stage, modifiers in pick order and each one's ops in order.
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
const TAG_ABILITY := "ability"
## v0.6.0 MX2: Frost Nova's ring grows to its radius over this many ticks (a starting value).
const RING_TICKS := 18
## v0.6.0 MX2: a hook's lingering child when its op names no time: a lob's flight, a zone's life and its hit gap.
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


## The build's modifiers in slot order (v0.6.0 MX2: World.mod_slots; each slot's card's modifiers in its order).
static func build_modifiers(w: World) -> Array[ModifierTable]:
	var out: Array[ModifierTable] = []
	for code in w.mod_slots:
		if Offers.type_of(code) == Offers.ABILITY:
			var idx := Offers.ability_of(code)
			if idx < w.ability_tables.size():
				out.append_array(w.ability_tables[idx].modifiers)
		elif code < w.item_tables.size():
			out.append_array(w.item_tables[code].modifiers)
	return out


## v0.6.0 MX2: an owned ability modifier's compiled spec (by its ability id), or null.
static func ability(w: World, t: AbilityTable) -> AttackSpec:
	return book(w).spec(t.id) if t != null else null


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
	var root := _weapon_root(w, b)
	for idx in w.ability_owned:  # v0.6.0 MX2: the ability modifiers' attacks, carrying the weapon's
		var t := w.ability_tables[idx]
		var base := _base_ability(w, t, Abilities.level_of(w, idx))
		if base == null:
			continue
		var s := compile_spec(base, mods)
		inherit(s, root, t.kind == AbilityTable.Kind.DRONE_BUDDY)
		b.add(s)
	b.register()
	b.seal()
	return b


## The weapon's own attack the abilities copy: the Gun's bolt on a Gun build, else the Blade's first step.
static func _weapon_root(w: World, b: AttackBook) -> AttackSpec:
	if PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w):
		return b.spec(GUN_BOLT)
	return b.spec(step_id(0)) if w.player.combo.size() > 0 else b.spec(GUN_BOLT)


## v0.6.0 MX2: `s` takes `root`'s statuses (not its riders; a status `s` already has stays), elements and ON_HIT /
## ON_KILL hooks (shared, as compiled for the weapon); with `copy`, a bolt root's pattern and behaviour too.
static func inherit(s: AttackSpec, root: AttackSpec, copy: bool) -> void:
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
	if s.depth < MAX_DEPTH:
		for h in root.hooks:
			if h.trigger == AttackSpec.Trigger.ON_HIT or h.trigger == AttackSpec.Trigger.ON_KILL:
				s.hooks.append(h)
	if copy and root.form == AttackSpec.Form.BOLT:
		s.count = maxi(s.count, root.count)
		s.spread = root.spread
		s.damage_permille = root.damage_permille
		s.bounces = maxi(s.bounces, root.bounces)
		s.pierce = maxi(s.pierce, root.pierce)


## v0.6.0 MX2: ability `t` at `level` as an attack spec (null for the weapon and the utility). Its numbers are the
## ability's v0.5 numbers at that level; the runtime factors (the area stat, Blade Dance, the cooldowns) stay with
## the ability's driver (Abilities, ModifierAbilities).
static func _base_ability(_w: World, t: AbilityTable, level: int) -> AttackSpec:
	if not t.is_modifier():
		return null
	var s := AttackSpec.new()
	s.id = t.id
	s.effect_id = t.id
	s.damage = Abilities.damage_at(t, level)
	s.tags = PackedStringArray([TAG_ABILITY, "auto"])
	var lvl_r := t.radius_m * t.radius_permille(level) / 1000.0
	match t.kind:
		AbilityTable.Kind.BOMB_LOBBER:
			s.form = AttackSpec.Form.LOB
			s.tags.append_array(["bomb", "area"])
			s.radius_m = lvl_r
			s.reach_m = t.range_m
			s.life_ticks = t.duration_ticks
			s.count = t.count(level)
			s.period_ticks = t.cooldown_ticks
		AbilityTable.Kind.DRONE_BUDDY:
			s.form = AttackSpec.Form.BOLT
			s.tags.append_array(["drone", "projectile"])
			s.radius_m = Abilities.BOLT_RADIUS_M
			s.speed = t.speed
			s.reach_m = t.range_m
			s.life_ticks = int(ceil(t.range_m / t.speed)) + 2
			s.period_ticks = maxi(1, t.period_ticks * 1000 / t.rate_permille(level))
		AbilityTable.Kind.ORBIT_BLADES:
			s.form = AttackSpec.Form.ORBITER
			s.tags.append_array(["orbit", "melee"])
			s.count = t.count(level)
			s.reach_m = lvl_r
			s.radius_m = Abilities.BLADE_R
			s.period_ticks = t.period_ticks
		AbilityTable.Kind.ARC_FIELD:
			s.form = AttackSpec.Form.ZONE
			s.tags.append_array(["field", "area"])
			s.radius_m = t.radius_m
			s.reach_m = t.range_m
			s.life_ticks = t.duration_ticks
			s.period_ticks = t.hit_ticks
			s.count = t.count(level)
			s.set_status(&"shock", t.extra(level), 0)
			s.elements.append("storm")
		AbilityTable.Kind.FROST_NOVA:
			s.form = AttackSpec.Form.RING
			s.tags.append_array(["nova", "area"])
			s.radius_m = lvl_r
			s.life_ticks = RING_TICKS
			s.set_status(&"frost", t.extra(level), 0)
			s.elements.append("frost")
		AbilityTable.Kind.FLAME_TRAIL:
			s.form = AttackSpec.Form.ZONE
			s.tags.append_array(["trail", "area"])
			s.radius_m = lvl_r
			s.life_ticks = maxi(1, t.duration_ticks * t.rate_permille(level) / 1000)
			s.period_ticks = t.hit_ticks
			s.set_status(&"burn", t.extra(level), 0)
			s.elements.append("ember")
	return s


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
	match op.form:  # v0.6.0 MX2: the lingering forms' times (an op names only a radius and a reach)
		AttackSpec.Form.LOB:
			c.life_ticks = HOOK_LOB_TICKS
		AttackSpec.Form.ZONE:
			c.life_ticks = HOOK_ZONE_TICKS
			c.period_ticks = HOOK_ZONE_GAP
		AttackSpec.Form.RING:
			c.life_ticks = RING_TICKS
		AttackSpec.Form.ORBITER:
			c.count = maxi(1, c.count)
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
