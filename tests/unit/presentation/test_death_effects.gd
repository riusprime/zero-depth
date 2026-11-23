extends GutTest
## What one enemy's death plays, for every enemy kind, in a real floor view: its body's pop of chunks once (HitFeel),
## at most one pack explosion, and no smoke cloud over the floor (owner: enemies leave no lingering smoke and never
## explode twice). Each kind dies alone, so everything counted came from that one death.

const FAR := 6.0
## Ticks watched after the kill: a Kiln Beetle's burst blows a second later, a Splitter's halves walk out.
const WATCH_TICKS := 150

var _tables: Array[EnemyTable] = []
var _saved_density := ""


func before_all() -> void:
	_tables = CombatLab.tables()


func before_each() -> void:
	_saved_density = ViewPrefs.effects_density
	ViewPrefs.effects_density = "high"


func after_each() -> void:
	ViewPrefs.effects_density = _saved_density


func _view(w: World) -> WorldViewRoot:
	var biome: BiomeDefinition = SharedContent.repo().get_def(&"biomes", &"ruins")
	var v := WorldViewRoot.new()
	v.stage.mood = biome.mood
	add_child_autofree(v)
	v.setup(WorldReader.new(w), biome.palette, 60.0)
	return v


## Kills a lone `kind` and returns what its view played: {"chunks": the pop's pieces the tick it died,
## "explosion": pack explosions, "cloud": pack clouds, "hit"/"impact": the pack's sparks}.
func _death(kind: int) -> Dictionary:
	var w := World.new(3, PlayerTable.starting_values())
	w.set_enemy_tables(_tables)
	w.actors.invuln[0] = 1 << 24
	w.add_enemy(kind, Vector2(FAR, 0))
	var i := w.actors.ids.size() - 1
	for _t in SimTick.SPAWN_IN_TICKS + 2:
		w.step(InputFrame.new())
	var v := _view(w)
	v.sync()
	var fx := v.pack_fx
	var base := {}
	for fam: StringName in [&"explosion", &"cloud", &"hit", &"impact"]:
		base[fam] = int(fx.spawned_in.get(fam, 0)) if fx != null else 0
	var player := w.actors.ids[0]
	Damage.hit(
		w, i, w.actors.max_hp[i] * 20, player, player, player, 0, w.actors.pos(i), w.actors.pos(i)
	)
	w.step(InputFrame.new())
	v.sync()
	var out := {"chunks": v.hit_feel.spark_count()}
	for _t in WATCH_TICKS:
		w.actors.hp[0] = w.actors.max_hp[0]
		w.step(InputFrame.new())
		v.sync()
	for fam: StringName in base:
		out[fam] = (int(fx.spawned_in.get(fam, 0)) if fx != null else 0) - int(base[fam])
	return out


func test_every_enemy_dies_in_one_pop_and_at_most_one_explosion() -> void:
	var kinds: Array = ContentCompiler.ENEMY_KINDS.values()
	assert_gt(kinds.size(), 30, "every ordinary enemy kind is covered")
	for kind: int in kinds:
		var d := _death(kind)
		var name: String = ActorStore.Kind.keys()[kind]
		assert_eq(d["chunks"], ViewPrefs.sparks(HitFeel.SHARDS), "%s: its chunks fly once" % name)
		assert_lte(d["explosion"], 1, "%s: at most one explosion (%s)" % [name, d])
		assert_eq(d["cloud"], 0, "%s: no smoke cloud (%s)" % [name, d])


## An animated explosion or impact scene left its particles looping through the scene's whole length, so its sparks
## fired again and again and one blast read as two or three. Every timed one plays its particles once.
func test_every_timed_explosion_and_impact_plays_its_particles_once() -> void:
	var def := PackFx.shared_def()
	var fx: PackFx = add_child_autofree(PackFx.new())
	var checked := 0
	for k in def.ids.size():
		if def.families[k] != &"explosion" and def.families[k] != &"impact":
			continue
		var node := fx.spawn(def.ids[k], Vector3.ZERO)
		if node == null:
			continue
		for c in node.get_children():
			if c is GPUParticles3D:
				assert_true(
					(c as GPUParticles3D).one_shot, "%s / %s plays once" % [def.ids[k], c.name]
				)
		checked += 1
		fx.release(node)
	assert_gt(checked, 10, "the pack's explosions and impacts were checked")
