# DRAW_GROWTH: what piles up in what the renderer draws as a floor is played (W3-V2, 2026-11-06)

Why: [PERF_PLAYLOG_4](PERF_PLAYLOG_4.md). The owner's "objects drawn" (`Performance.RENDER_TOTAL_OBJECTS_IN_FRAME`, what
the perf recorder logs) climb within each floor and from floor to floor while the nodes stay flat.

## Finding

**The corner minimap.** Each room the hero discovers adds about 470 objects, 530 to 570 primitives and about 7 draw calls to
the 2D canvas pass. These are drawn on every frame for the rest of the floor. Read from the same spot, the 3D passes
(camera and shadows) stay flat within a floor. A new floor starts the minimap over, so the count drops back to about
1,300 on arrival. Later floors have more rooms (11, 13, 15, 17, 20 on this run's floors 1 to 5), so each one ends
higher than the last. That matches the owner's log: within each floor and from floor to floor, and loop 2's floor 1
starting low.

- At the same camera spot (the start room's centre), with all rooms visited, the minimap alone draws 4,966 / 5,401 /
  6,710 / 7,576 / 8,891 objects on floors 1 to 5. That is 85 to 88 % of the frame's 5,864 / 6,560 / 7,522 / 8,429 /
  10,154. On arrival it draws 486.
- Per room discovered, (minimap at 100 % − 486) / (rooms discovered − 1): 498, 447, 479, 473, 467 objects.
- The 2D canvas pass is 1,120 to 1,195 objects on arrival, and 5,700 to 9,653 at 100 %. Over the same checkpoints the 3D
  camera pass holds at 58 to 142 objects and the shadow passes at 59 to 441, without a climb within a floor. The shadow
  passes go up and down with the floor's walls and kit pieces near the start room.
- Ruled out, at the same spot, because they stay flat within a floor (the table below): ground tiles, walls, kit
  pieces, decor MultiMeshes, torch lights and their shadows, shard clusters, the sun's shadow, the stage's other
  children, the hero, and every other HUD part. Enemies, shards, rewards and heal orbs come and go with what is alive
  and lying near the start room, by tens of objects, not thousands.
- No direct RenderingServer instances exist in `src/` (`grep instance_create`: none). Nothing is drawn outside the nodes.
- Not measured here: frame time. The machine was shared with the lead's seams run, so how many milliseconds these
  objects cost is `NOT YET RUN (owner hardware)`. The objects follow the owner's slowdown floor by floor. That the
  minimap is the time (and not only the count) is not yet proven.

## The code

- `src/presentation/hud/minimap_view.gd` `_draw()` (line 110) draws every discovered room of the floor on every redraw:
  - `_draw_rooms()` (line 240): a wash polygon, a fill polygon and `_outline()` for each room;
  - `_outline()` (line 256): for each of the 4 walls, loops over every door of the floor (rooms × 4 × doors) and draws
    each wall run with `MinimapStyle.glow_line`;
  - `_draw_doors()` (line 296): for each known doorway, a polygon, two glow lines and, into an unknown room, an arrow
    (a glow line and a triangle).
- `src/presentation/hud/minimap_style.gd` `glow_line()` (line 92): **three** antialiased `draw_line`s per segment (shadow,
  glow and line).
- The corner view (`clip_contents = true`, 300 × 300 px at 5 px/m) clips the pixels only. All the floor's discovered
  rooms are still issued and drawn every frame, even those far outside the window.
- `refresh()` (line 69) redraws whenever the player's map pixel, aim or move changes, so nearly every frame while
  walking. Each redraw runs the GDScript loops above again. The census's "corner redraws so far" reads 1,804 on floor
  5, with a hero that mostly stood still.
- Nothing is freed or hidden as rooms are found. The picture only grows until `MinimapState` resets on the next floor.

## Proposed fix (not done; the owner sees this first)

1. **Draw the map layer once per change.** Draw rooms, doors and icons into a texture (a small `SubViewport` with
   `UPDATE_ONCE`, set again on each `MinimapState.revision` change). Each frame, draw only that texture plus the player
   arrow, in its own small CanvasItem.
   - Estimate: the minimap goes from 486 to 8,891 objects down to a few tens at any point of the floor. On this run that
     is about 4,500 to 8,400 objects off the end-of-floor frame (−77 to −83 % of the total), and about 70 to 125 canvas
     draw calls off.
   - The GDScript `_draw` would then run on a change of the map only, not on each pixel the hero moves.
2. A cheaper partial step, if 1 is too much: in the corner view, skip rooms and doors outside the window before drawing
   them, and draw one line per segment instead of three. Not measured; what it saves depends on the floor's size against
   the window.

The full map (held Tab) draws the same commands. It was not shown during the census.

## How it was measured

Tool: `scripts/checks/draw_growth.gd`, new in this step. It extends `draw_census.gd` and reuses its per-source split.
- It boots `main.tscn` and starts a run (seed 4404), with every floor red_canyon (`--biome`), so the floors differ only
  by their place in the run.
- The hero is invulnerable, as the dev panel's God. It is placed in each room in turn, nearest the start first (by the
  floor's hops), never in the boss room.
- It stays 240 sim ticks in each room:
  - every enemy within 16 m is killed through `Damage.hit`, as the dev panel's Kill boss does, so the kills, drops and
    room events are the sim's;
  - it steps onto shards and heal orbs in reach;
  - it stays on while an arena or a Lockdown holds.
- The checkpoints are arrival, then 25 / 50 / 75 / 100 % of the rooms visited. At each one:
  - the hero goes back to the start room's centre (the same camera spot each time);
  - the floor settles 90 ticks, then the sim pauses;
  - each source is read hidden, against everything shown.
- Then the next floor, through `Main._next_floor()` (what the portal calls). The boss fight and the walk into the portal
  are skipped.
- The hero picks no cards, so the build doesn't grow. That is the other half of PLAYLOG_4 (the sim per tick following
  the hero's projectiles), and it is not measured here.

Build: `57e6fe44` plus the uncommitted tool (the report's `sha=` line reads `HEAD`, which was `57e6fe44` when it ran).
Machine: the owner's PC (i7-10700K, RTX 3060), with the lead's seams run in parallel (counts only, nothing timed).

```
"$G" --headless --path . --editor --import --quit
"$G" --path . --fixed-fps 60 --position -10000,-10000 --resolution 1920x1080 --windowed \
  -s scripts/checks/draw_growth.gd -- --biome=red_canyon --floors=5 --dwell=240 > build/perf/draw_growth_red_canyon.log 2>&1
→ build/perf/draw_growth_red_canyon.txt (68 KB, untracked); exit 0
```

The run printed 6 `SCRIPT ERROR: Trying to assign invalid previously freed instance.` at
`scripts/checks/draw_census.gd:432` (`_vis_setter`'s typed loop). A node that a source listed was freed between the
listing and the toggle (a short-lived effect), and that one setter skips it. The error is in the existing census tool;
it is left as it is.

### Raw output (excerpts, verbatim; the full file is under `build/`)

Progress lines (from the log):
```
draw_growth: floor 1 (run floor_index 1, loop 1) biome=red_canyon, 10 rooms to visit
draw_growth: f1   0% objects=1352 draws=357
draw_growth: f1  25% objects=3443 draws=400
draw_growth: f1  50% objects=3827 draws=402
draw_growth: f1  75% objects=4940 draws=423
draw_growth: f1 100% objects=5864 draws=433
draw_growth: floor 2 (run floor_index 2, loop 1) biome=red_canyon, 12 rooms to visit
draw_growth: f2   0% objects=1443 draws=397
draw_growth: f2  25% objects=2746 draws=458
draw_growth: f2  50% objects=4767 draws=520
draw_growth: f2  75% objects=5384 draws=527
draw_growth: f2 100% objects=6560 draws=573
draw_growth: floor 3 (run floor_index 3, loop 1) biome=red_canyon, 14 rooms to visit
draw_growth: f3   0% objects=1252 draws=321
draw_growth: f3  25% objects=3800 draws=371
draw_growth: f3  50% objects=5277 draws=414
draw_growth: f3  75% objects=6377 draws=432
draw_growth: f3 100% objects=7522 draws=448
draw_growth: floor 4 (run floor_index 4, loop 1) biome=red_canyon, 16 rooms to visit
draw_growth: f4   0% objects=1307 draws=334
draw_growth: f4  25% objects=4160 draws=394
draw_growth: f4  50% objects=6234 draws=466
draw_growth: f4  75% objects=7118 draws=493
draw_growth: f4 100% objects=8429 draws=449
draw_growth: floor 5 (run floor_index 5, loop 1) biome=red_canyon, 19 rooms to visit
draw_growth: f5   0% objects=1572 draws=494
draw_growth: f5  25% objects=4278 draws=556
draw_growth: f5  50% objects=7358 draws=670
draw_growth: f5  75% objects=8922 draws=669
draw_growth: f5 100% objects=10154 draws=679
```

Header and everything shown (lines 1-14):
```
draw_growth  sha=57e6fe44  biome=red_canyon  floors=5  dwell=240  tag=
machine: renderer=forward_plus adapter=NVIDIA GeForce RTX 3060 window=(1920, 1080)
run seed 4404, every floor red_canyon; each checkpoint read at the start room's centre, 90 ticks settled, sim paused

== everything shown (median of the readings): objects / draws / cam_obj / shd_obj ==
checkpoint                                       f10%    f125%    f150%    f175%   f1100%     f20%    f225%    f250%    f275%   f2100%     f30%    f325%    f350%    f375%   f3100%     f40%    f425%    f450%    f475%   f4100%     f50%    f525%    f550%    f575%   f5100%
objects (total)                                  1352     3443     3827     4940     5864     1443     2746     4767     5384     6560     1252     3800     5277     6377     7522     1307     4160     6234     7118     8429     1572     4278     7358     8922    10154
draws (total)                                     357      400      402      423      433      397      458      520      527      573      321      371      414      432      448      334      394      466      493      449      494      556      670      669      679
prims (total)                                  445820   448135   448716   450169   451099   749462   768543   773873   762580   771182   500541   510061   506882   506971   513257   670328   675499   682165   678086   678356   875394   884823   905175   901381   900290
cam_obj (3D camera pass)                           83       88       88       88       88       58       76      116       97      122       65       65       86       86       86       86       97      125      142       98       62       77       84       62       69
shd_obj (3D shadow passes)                         74       76       76       76       76      265      271      285      284      291       59       66       72       71       72       89       99      104      111       93      374      390      437      441      432
cv_obj (2D canvas)                               1195     3279     3663     4776     5700     1120     2399     4366     5003     6147     1128     3669     5119     6220     7364     1132     3964     6005     6865     8238     1136     3811     6837     8419     9653
cv_dc (2D canvas)                                 212      248      250      271      281      203      241      279      275      290      207      254      266      285      300      211      252      291      292      310      215      252      309      328      350
cv_prims (2D canvas)                             5550     7731     8312     9765    10695     5414     6967     9363     9958    11174     5448     8346     9919    11232    12450     5474     8511    10901    11764    13226     5500     8387    12011    13693    15094
```

Objects each source removes when hidden (lines 16-52):
```
== objects each source removes when hidden (sources moving it by >= 3 at any checkpoint) ==
checkpoint                                       f10%    f125%    f150%    f175%   f1100%     f20%    f225%    f250%    f275%   f2100%     f30%    f325%    f350%    f375%   f3100%     f40%    f425%    f450%    f475%   f4100%     f50%    f525%    f550%    f575%   f5100%
floor: ground tiles                                 1        1        1        1        1        1        1       15        1        1        1        1        0        1        1        1        1        1        1        1        1        1        1        1       62
walls: procedural wall meshes                      24       24       24       24       24       58       58       58       58       58       22       22       22       22       22       22       22       23       22       22       85       85       85       85       85
walls: kit wall/cover pieces                       35       35       35       35       35      171      171      171      171      171       30       30       30       30       30       82       83       82       82       82      203      203      203      203      203
decor: kit decoration MultiMeshes                  15       15       15       15       15       14       14       14       14       14       17       17       17       17       17       18       18       18       18       18       16       16       16       16       16
lights: torch OmniLight3D                          34       34       34       34       34       28       28       28       12       28       29       29       33       32       32       31       31       32       31       31       47       47       47       47       50
lights: torch shadows                              21       29      252       29       29       26       26       26       26       26       26       26       30       29       29       24       24       25       24       24       44       44       43       44       47
decor: shard clusters                              37       37       24       24       24       46       46       46       46       46       35       35       35       35       35       34       25       26       34       34       74       74       59       59       59
stage: other children                              47       49       49       49       49      241      247      261      260      267       35       42       44       44       45       67       77       82       89       71      332      348      396      399      387
lights: sun shadow                                 45       47       47       47       47      239      245      259      258      265       33       40       42       42       43       65       74       79       87       69      330      346      394      397      385
hero                                               22       22       22       22       22       22       22       22       22       22       22       22       22       22       22       22       22       22       22       22       22       22       22       22       22
enemies                                             0        0        0        0        0        0       14       44        3       25        0        7        1        0        1        0        3       12        0        0        0        8       15       10       24
fx: the other views                                30       35       35       35       35       28       38       62       83       93        2        2       35       35       35        2       21       44       80       18       63       86      134      120      104
  view: KitView                                   278        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0
  view: UtilityView                                 0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        6        0        0        0        0        0
  view: RewardViews                                60        0        0        0        0      112       16       16       16       16        0        0        0        0        0        0        0        0        0        0       30       30       43       57       58
  view: ShardViews                                  0        7        7        7        7        0       10       34       55       65        0        0       33       33       33        0       18       40       75       13        0       23       58       30       13
  view: HealOrbViews                                0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0       -1        3        3        3        0        0        1        0        0
  view: BreakablesView                            100        0        0        0        0        9        9        9        9        9        0        0        0        0        0        0        0        0        0        0       17       17       16       17       17
  view: ShopStallView                               0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0       12       12       12       12       12
  view: AltarStage                                 25       25       25       25       25        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0
hud: VBoxContainer @VBoxContainer@5939            119      119      119      119      119        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0
hud: HudFrame                                      63       63       67       67       67       67       67       71       71       71       71       71       71       71       71       71       71       71       71       75       71       71       75       75       75
hud: HeatMeter                                     19       19       19       19       19       19       19       19       19       19       19       19       19       19       19       19       19       19       19       19       19       19       19       19       19
hud: Minimap                                      486     2502     2946     4042     4966      486     1577     3379     4257     5401      486     2943     4469     5566     6710      486     3322     5287     6211     7576      486     3157     6001     7749     8891
hud: KitHud                                        56       56       56       56       56       56       56       56       56       56       56       56       56       56       56       56       56       55       56       56       56       56       56       56       56
hud: AbilitySquares                               171      171      171      171      171      171      171      171      171      171      171      171      171      171      171      171      171      171      171      171      171      171      171      171      171
hud: PhaseHud                                      16       84       16       32       32       32      120      112       36       36       32      116       36       36       36       32       28      100       36       36       32       32       36       36      128
hud: BuildHud                                      16       16       16       16       16       20       20       20       20       20       24       24       24       24       24       28       28       28       28       28       32       32       32       32       32
ui: OnboardingHints                                 0      100      100      100      100        0       96       96       96       96        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0
hud: VBoxContainer @VBoxContainer@11220             0        0        0        0        0      119      119      119      119      119        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0
hud: LockdownHud                                    0        0        0        0        0        0        0      169        0        0        0        0        0        0        0        0        0        0        0        0        0        0      169        0        0
hud: VBoxContainer @VBoxContainer@20630             0        0        0        0        0        0        0        0        0        0      119      119      119      119      119        0        0        0        0        0        0        0        0        0        0
hud: VBoxContainer @VBoxContainer@29488             0        0        0        0        0        0        0        0        0        0        0        0        0        0        0      119      119      119      119      119        0        0        0        0        0
hud: VBoxContainer @VBoxContainer@41640             0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0      119      119      119      119      119
```

The minimap's row in the canvas objects and the draws tables (lines 72-73 and 81; 93-94 and 117):
```
== cv_obj each source removes when hidden (sources moving it by >= 3 at any checkpoint) ==
checkpoint                                       f10%    f125%    f150%    f175%   f1100%     f20%    f225%    f250%    f275%   f2100%     f30%    f325%    f350%    f375%   f3100%     f40%    f425%    f450%    f475%   f4100%     f50%    f525%    f550%    f575%   f5100%
hud: Minimap                                      486     2502     2946     4042     4966      486     1577     3379     4257     5401      486     2943     4469     5566     6710      486     3322     5287     6211     7576      486     3157     6002     7749     8891
== draws each source removes when hidden (sources moving it by >= 3 at any checkpoint) ==
checkpoint                                       f10%    f125%    f150%    f175%   f1100%     f20%    f225%    f250%    f275%   f2100%     f30%    f325%    f350%    f375%   f3100%     f40%    f425%    f450%    f475%   f4100%     f50%    f525%    f550%    f575%   f5100%
hud: Minimap                                       36       63       74       95      105       36       52       80       95      110       36       74       95      114      129       36       77      107      117      135       36       73      119      147      160
```

Node census, the rows that change (selected rows, verbatim):
```
checkpoint                                       f10%    f125%    f150%    f175%   f1100%     f20%    f225%    f250%    f275%   f2100%     f30%    f325%    f350%    f375%   f3100%     f40%    f425%    f450%    f475%   f4100%     f50%    f525%    f550%    f575%   f5100%
lights: shown                                      22       22       23       24       24       19       19       20       21       21       26       26       27       28       28       21       21       22       23       24       26       26       28       31       31
minimap: corner redraws so far                      2      134      234      473      513        2      102      362      734     1019        2       64      387      693      699        2       37      434      690     1073        2      161     1114     1490     1804
minimap: floor doors                               12       12       12       12       12       13       13       13       13       13       16       16       16       16       16       18       18       18       18       18       21       21       21       21       21
minimap: floor rooms                               11       11       11       11       11       13       13       13       13       13       15       15       15       15       15       17       17       17       17       17       20       20       20       20       20
minimap: rooms discovered                           1        3        5        8       10        1        3        6        9       12        1        4        8       11       14        1        5        9       12       16        1        5       11       16       19
nodes: under the view                            2693     2737     2915     3263     3356     2893     3055     3429     3851     3847     3110     4001     3820     4526     4531     3075     3638     4112     4407     4747     3191     4310     3796     5072     5640
nodes: whole tree                                3322     3366     3544     3892     3985     3522     3684     4061     4480     4478     3739     4630     4451     5155     5160     3704     4269     4741     5036     5376     3820     4939     4425     5701     6272
shown class: MeshInstance3D                       819      845      937     1123     1177      903      991     1180     1414     1410     1103     1580     1487     1859     1857     1097     1378     1610     1760     1975     1129     1743     1442     2111     2426
sim: actors (all, dead kept)                        1        3        2        7       10        1        4       10       19       23        1       22       15       27       27        1       16       24       30       33        1       26        8       42       45
sim: heal orbs                                      0        1        2        3        3        0        0        0        0        1        0        0        0        3        3        0        0        3        3        7        0        1        1        1        4
sim: kills                                          0        4       23       37       39        0       14       53      100      135        0        7       48      128      129        0        9       71       99      199        0       21      142      190      242
sim: shard drops                                    0        1       14       14       14        0        1       11       11       14        0        2       12       20       21        0        3       20       24       20        0        4       24       19       24
view geometry shown: ActorViews                    13       31       27      189      243       13       94      192      394      379       13      476      287      553      544       13      270      386      475      612       13      604      109      746     1006
view nodes: ActorViews                             37       68       66      355      448       37      186      389      738      716       37      902      533     1031     1023       37      562      806      982     1175       37     1116      224     1420     1910
view nodes: AltarStage                             25       25       25       25       25        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0
view nodes: ArenaViews                             11       11       11       11       11       13       13       13       13       13       15       15       15       15       15       17       17       17       17       17       20       20       20       20       20
view nodes: AscensionPortal                         0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0       19       19       19       19       19
view nodes: BossDoorView                           15       15       15       15       15       15       15       15       15       15       15       15       15       15       15       19       19       19       19       19       15       15       15       15       15
view nodes: BreakablesView                         23       23       23       23       23       98       98       98       98       98       28       28       28       28       28       28       28       28       28       28       78       78       78       78       78
view nodes: EventPedestalViews                     63       63       63       63       63       63       63       63       63       63       68       68       68       68       68        2        2        3        3        3       62       62       62       62       62
view nodes: HealOrbViews                            0        4        8       12       12        0        0        0        0        4        0        0        0       12       12        0        0       12       12       28        0        4        4        4       16
view nodes: HitFeel                                 0        0        0        0        0        0        0       14        0        7        0        0        7        0        0        0        7        0        0        0        0        0        0        0       21
view nodes: LockdownView                            9        9        9        9        9        9        9        9        9        9        6        6        6        6        6       12       12       12       12       12       12       12       12       12       12
view nodes: LoopDevice                              0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0        9        9        9        9        9
view nodes: PortalGate                              4        4        4        4        4        8        8        8        8        8       12       12       12       12       12        8        8        8        8        8        4        4        4        4        4
view nodes: PurpleRuneView                          0        0        0        0        0        0        0        0        0        0       18       18       18       18       18        0        0        0        0        0        0        0        0        0        0
view nodes: RewardViews                           138      138      193      248      248      193      193      248      303      303      193      193      248      303      303      166      166      221      276      331      152      152      262      391      391
view nodes: RuneMarkingsView                        0        0        0        0        0        1        1        1        1        1        0        0        0        0        0        0        0        0        0        0        0        0        0        0        0
view nodes: ShardViews                              0        9      130      130      130        0       13      115      147      154        0       26      152      300      313        0       31      200      264      340        0       36      304      255      300
view nodes: ShopStallView                         125      125      125      125      125        0        0        0        0        0      237      237      237      237      237        0        0        0        0        0       73       73       73       73       73
view nodes: ShrinesView                             0        0        0        0        0        0        0        0        0        0       12       12       12       12       12        0        0        0        0        0       24       24       24       24       24
view nodes: StageView                             740      740      740      740      740      952      952      952      952      952      962      962      962      962      962     1284     1284     1284     1284     1284     1180     1180     1180     1180     1180
```

The ActorViews and ShardViews nodes grow with the enemies still alive in rooms the hero left (the 16 m kill radius
clears only near it) and with the shards not picked up. What they draw at the start room is the "enemies" and
"view: ShardViews" rows above: tens of objects. In play they follow the fight, not how far the floor has been played.

Owner-only: whether the slowdown goes once the minimap is fixed: OWNER ONLY (needs the fix, then a playtest on their PC).
