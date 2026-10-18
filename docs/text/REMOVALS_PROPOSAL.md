# Removals proposal: the explaining texts (v0.8.0 N16, O74)

**Status: Applied 2026-10-18** (v0.8.0 N18, owner O76: "Apply them all"). Every row below was applied exactly as
recommended: the 10 "Remove" rows with the code that showed them (and their keys gone from `locale/strings.csv`),
the 48 "Shorten" rows in the proposed wording, the 15 "Keep" rows unchanged (`HUD_FALLEN_WARN` kept; `WAND_READ_FIRE`
and its read-out kept). The two questions: the bosses keep their English names in Spanish ("Keep English names");
"Whirling Steel" / "Torbellino de acero" is "OK". What was removed, with its code:
[`docs/roadmap/v0.8.0/evidence/TEXT_REMOVALS.md`](../roadmap/v0.8.0/evidence/TEXT_REMOVALS.md).

The owner (O74): "we need to remove all the 'explaining texts' we need the players to discover most of the thing and
not explain anything … we do not need to explain bosses or loop device or ascension or shrine, keep the basic things,
before removing any text on screen that you doubt ask me". Process chosen: "Rewrite now, ask before removing".

(As proposed in N16, before the owner's answer:) each row is a text that teaches a rule or explains a thing,
with where it shows and a recommendation. The lead asks the owner row by row (or group by group); only a "yes" is
applied, in a later step, with its code (a removed floating label or hint needs its node or trigger gone too, and the
tests that check it changed).

- **Remove**: the text goes (and, for a floating label or a hint, the node or the trigger that shows it).
- **Shorten**: the text stays as a basic word or one look line; the proposed wording is given in both languages.
- **Keep**: basic (controls, numbers players need, feedback); listed so the owner sees it was considered.

The English and Spanish columns are the texts as they are today (after N16's rewrite, which did not touch these).

Kept out of this list on purpose (the basic things): menus and their labels, options, button prompts and the key
hints on panels (`PICK_HINT`, `SHOP_HINT`, `UI_BUILD_HINT`, `UI_EVENT_HINT` …), prices and costs (`UI_GAMBLE_USE`,
`REWARD_OPEN_CHEST`, `UI_EVENT_COST_*`), HP, the timer, floor and loop numbers, card tiers, the floor events' one-line
flavour (`EVENT_*_DESC`), the end screen's "what killed you" lines (`CAUSE_*`, rewritten shorter in N16), the
sound captions other than the one below, and the dev tools.

## Two questions that came up while rewriting

1. **Boss names in Spanish.** The owner kept "Hollow Crown" untranslated ("Derrota a Hollow Crown."); N16 applied
   that wherever the Hollow Crown is named in Spanish (`BOSS_HOLLOW_CROWN`, the Codex section, the true ending, the
   final-boss Codex lines, the achievements). Should the other bosses keep their English names in Spanish too
   (The Gatekeeper, The Brood Mother, The Siege Engine, The Warlord, The Hive Lens, The Foundry, and the Hollow
   Crown's bodies: The Colossus, The Prism, The Fallen)? Today they are "El Guardián de la Puerta", "La Madre de la
   Prole", "La Máquina de Asedio", "El Señor de la Guerra", "La Lente Enjambre", "La Fundición", "El Coloso",
   "El Prisma", "El Caído". Not changed until the owner says.
2. **Two cards called Blade Dance.** The owner renamed Orbiting Copies to "Blade Dance" / "Danza de espadas"; a combo
   card was already called "Blade Dance" / "Danza de Cuchillas" (`ABILITY_COMBO_BLADE_DANCE`). N16 renamed the
   combo to **"Whirling Steel" / "Torbellino de acero"** so the two don't share a name. The owner may pick another.

## The list

| Key | English | Spanish | Where it shows | Recommendation |
|---|---|---|---|---|
| **A. Tutorial hints (first floor, the TIP box)** | | | | |
| `HINT_HEADER` | TIP | CONSEJO | TIP box header | Keep while any hint stays |
| `HINT_MOVE` | Move with %s · aim with %s | Muévete con %s · apunta con %s | TIP box, first seconds | Keep (basic: the controls) |
| `HINT_MOUSE` | the mouse | el ratón | inside HINT_MOVE | Keep (part of HINT_MOVE) |
| `HINT_PAD_LEFT_STICK` | Left stick | Stick izquierdo | inside HINT_MOVE | Keep (part of HINT_MOVE) |
| `HINT_PAD_RIGHT_STICK` | the right stick | el stick derecho | inside HINT_MOVE | Keep (part of HINT_MOVE) |
| `HINT_ATTACK` | Attack with %s | Ataca con %s | TIP box | Keep (basic: the controls) |
| `HINT_DASH` | Dash with %s to get out of danger | Usa el impulso con %s para salir del peligro | TIP box | Shorten to the control: "Dash with %s" / "Esquiva con %s" |
| `HINT_VENT` | Your heat is high: %s vents it in a blast around you | Tu calor está alto: %s lo purga en una explosión a tu alrededor | TIP box, first time heat is high | Shorten to the control: "Vent with %s" / "Purga con %s" |
| `HINT_PICK` | Each card joins your wand, which reads left to right | Cada carta va a tu varita, que se lee de izquierda a derecha | TIP box, first card | Remove (explains the wand) |
| `HINT_BUILD` | Reorder your wand any time: %s, then Build | Reordena tu varita cuando quieras: %s y luego Construcción | TIP box | Shorten to the button: "Build: %s" / "Construcción: %s" |
| `HINT_TRIGGER` | A trigger card casts the cards to its right as a small spell (On Hit, On Kill …) | Una carta disparadora lanza las cartas a su derecha como un pequeño hechizo (Al Impactar, Al Matar …) | TIP box, first trigger card | Remove (explains trigger cards) |
| `HINT_SHOP` | The shop: buy cards with shards, or sell the ones you don't need | La tienda: compra cartas con fragmentos o vende las que sobren | TIP box, first shop | Remove (explains the shop) |
| `HINT_PORTAL` | The portal is open: step in to leave the floor | El portal está abierto: entra para salir del piso | TIP box, portal opens | Remove (explains the portal) |
| `HINT_CODEX` | Everything you meet goes into the Codex: %s, then Codex | Todo lo que encuentras va al Códice: %s y luego Códice | TIP box | Shorten to the button: "Codex: %s" / "Códice: %s" |
| **B. Bosses: Codex lines and boss-fight messages** | | | | |
| `BOSS_GATEKEEPER_DESC` | A giant stone sentinel, the Warden's big brother. Its shock lanes take your row and column, then erupt as stone spikes that stay as pillars for a few seconds: walls for you, its rock rings and everything else. Take cover behind them, but don't get boxed in. Fist slams and sweeps too. | Un centinela de piedra gigante, el hermano mayor del Guardián. Sus carriles de choque toman tu fila y tu columna y estallan en púas de piedra que quedan en pie unos segundos como pilares: muros para ti, para sus anillos de roca y para todo lo demás. Cúbrete tras ellos, pero que no te encierren. También da puñetazos al suelo y barridos. | Codex → Bosses | Shorten to one look line: "A giant stone sentinel." / "Un centinela de piedra gigante." (the Codex test needs a line; or remove the line and that check) |
| `BOSS_BROOD_MOTHER_DESC` | Lobs eggs onto circles that follow you. The eggs sit for a few seconds: break them, or they hatch into Hatchlings (and late in the fight burst into a star of acid). Spins webs of acid globs; her leaps and burrows lock where you stood. Shielded while her eggs fly. | Lanza huevos sobre círculos que te siguen. Los huevos quedan unos segundos en el suelo: rómpelos, o nacerán Crías (y al final del combate estallarán en una estrella de ácido). Teje espirales de gotas ácidas; sus saltos y sus excavaciones se fijan donde estabas. Se protege mientras vuelan sus huevos. | Codex → Bosses | Shorten: "Mother of the swarm." / "La madre del enjambre." |
| `BOSS_SIEGE_ENGINE_DESC` | A war machine that braces behind its shield and turns a cross of cannon embers that bounce off the walls and come back from behind, shells a checkerboard of circles, drops shells that follow you, fires a rail down your lane and deploys its turrets, whose shots bounce too once it is badly hurt. | Una máquina de guerra que se atrinchera tras su escudo y gira una cruz de brasas de cañón que rebotan en las paredes y vuelven por la espalda, bombardea un tablero de círculos, lanza proyectiles que te siguen, dispara un raíl por tu carril y despliega sus torretas, cuyos disparos también rebotan cuando está malherida. | Codex → Bosses | Shorten: "A war machine behind its shield." / "Una máquina de guerra tras su escudo." |
| `BOSS_WARLORD_DESC` | A knight behind a tower shield that blocks every hit from the front: circle it and strike its sides and back. Its javelins stick in the floor, then all fly back to it along the same lines: dodge them twice. Planting spears and dashing lower its shield. | Un caballero tras un escudo torre que bloquea todo golpe de frente: rodéalo y golpea sus flancos y su espalda. Sus jabalinas se clavan en el suelo y luego vuelven todas a él por las mismas líneas: esquívalas dos veces. Al plantar lanzas y embestir baja el escudo. | Codex → Bosses | Shorten: "A knight behind a tower shield." / "Un caballero tras un escudo torre." |
| `BOSS_HIVE_LENS_DESC` | A floating eye that fires prism spirals that turn back halfway and blooming petals, and turns its gaze round the room: a beam you must stay ahead of while its orbs fly. Its focus beam follows you, then locks. Its eye closes, shielded, while the spiral turns. Once hurt, Lens Drones break off its rim. | Un ojo flotante que dispara espirales de prismas que giran al revés a mitad y flores de pétalos, y pasea su mirada por la sala: un rayo al que debes adelantarte mientras vuelan sus orbes. Su rayo concentrado te sigue y luego se fija. Cierra el ojo, protegido, mientras gira la espiral. Al quedar herido, se desprenden Drones Lente de su borde. | Codex → Bosses | Shorten: "A floating eye." / "Un ojo flotante." |
| `BOSS_FOUNDRY_DESC` | A walking furnace that shuts its door and rains slag in a flower around it, sends out rings of molten drops with shifting gaps, floods your row with molten floor that stays as lava for a while and launches Bomb Drones. Near the end it melts the edge of the room for good, so you fight close to it. | Un horno andante que cierra su puerta y hace llover escoria en forma de flor a su alrededor, lanza anillos de gotas fundidas con huecos que se desplazan, inunda tu fila de suelo fundido que se queda como lava un rato y suelta Drones Bombarderos. Al final funde para siempre el borde de la sala, y luchas pegado a él. | Codex → Bosses | Shorten: "A walking furnace." / "Un horno andante." |
| `BOSS_COLOSSUS_DESC` | The Hollow Crown's first body: stone fists as big as a man. It never stops: fist combos that follow you and end in a ground slam, leaps that crack the floor in a shockwave ring, lines of stone spikes that chase you across the arena and bursts of them all around it, and boulders that shatter into shards where they land. Every blow locks half a second before it lands. | El primer cuerpo de Hollow Crown: puños de piedra tan grandes como un hombre. Nunca se detiene: combos de puños que te siguen y acaban en un golpe al suelo, saltos que agrietan el suelo en un anillo de onda expansiva, líneas de pinchos de piedra que te persiguen por la arena y estallidos de pinchos a su alrededor, y rocas que se rompen en esquirlas al caer. Cada golpe se fija medio segundo antes de caer. | Codex → The Hollow Crown | Shorten: "Hollow Crown's first body." / "El primer cuerpo de Hollow Crown." |
| `BOSS_PRISM_DESC` | The Hollow Crown's second body: a torn figure ringed by floating red crystal shards. She floats at the arena's heart inside the Cross, four beams that turn round the room, reversing, faster as she weakens. Her shards weave rings, spirals and flowers of orbs between the beams and fire quick bolts down a short aim line. She is shielded while the Cross turns: strike in the short windows between its spins. Her strength is measured from your own damage, so she lasts about a minute however strong you are. | El segundo cuerpo de Hollow Crown: una figura rasgada rodeada de esquirlas de cristal rojo que flotan. Flota en el corazón de la arena dentro de la Cruz, cuatro rayos que giran por la sala, cambian de sentido y aceleran a medida que se debilita. Sus esquirlas tejen anillos, espirales y flores de orbes entre los rayos y disparan proyectiles rápidos por una breve línea de mira. Está protegida mientras la Cruz gira: golpea en las breves ventanas entre giros. Su fuerza se mide a partir de tu propio daño, así que dura un minuto más o menos por fuerte que seas. | Codex → The Hollow Crown | Shorten: "Hollow Crown's second body." / "El segundo cuerpo de Hollow Crown." |
| `BOSS_NEMESIS_DESC` | The Hollow Crown's last body: a small dark hooded figure, your own shadow, fallen. It fights with a kit of its own, and at times it reaches for yours: for a few seconds it takes your weapon, your dash, your steps and the strongest cards of your wand, and pulls your power down to its level, an even duel. Its strength follows yours. | El último cuerpo de Hollow Crown: una pequeña figura encapuchada y oscura, tu propia sombra, caída. Lucha con sus propias armas y, a ratos, alcanza las tuyas: durante unos segundos toma tu arma, tu impulso, tus pasos y las cartas más fuertes de tu varita, y rebaja tu poder hasta el suyo, un duelo igualado. Su fuerza sigue a la tuya. | Codex → The Hollow Crown | Shorten: "Hollow Crown's last body: your own shadow." / "El último cuerpo de Hollow Crown: tu propia sombra." |
| `FINAL_ARENA_DESC` | A round arena of dark violet stone hung in the star-lit void, red crystal in its veins and its tiers empty. Its great gate is sealed: the only way out is through the Hollow Crown. | Una arena redonda de piedra violeta oscura suspendida en el vacío estrellado, con cristal rojo en sus vetas y sus gradas vacías. Su gran puerta está sellada: la única salida es a través de Hollow Crown. | Codex → The Hollow Crown | Shorten: "A dark arena in the void." / "Una arena oscura en el vacío." |
| `HUD_BOSS_AHEAD` | Boss ahead. The door shuts behind you. | Jefe adelante. La puerta se cierra tras de ti. | HUD message at the boss door | Shorten: "Boss ahead." / "Jefe adelante." |
| `HUD_FALLEN_WARN` | The Fallen reaches for your power… | El Caído alcanza tu poder… | Boss bar, The Fallen | Keep (a warning, not a rule) or remove |
| `HUD_FALLEN_WINDOW` | The Fallen mirrors you: your build is its own, your power pulled to its level (%d s) | El Caído te imita: tu equipo es el suyo y tu poder baja hasta el suyo (%d s) | Boss bar, The Fallen's mirror | Shorten: "Mirrored · %d s" / "Imitado · %d s" (the timer stays) |
| `CAPTION_BOSS_STAGGER` | [Boss staggered: power drops] | [Jefe aturdido: pierde potencia] | Captions (subtitles option) | Shorten: "[Boss staggered]" / "[Jefe aturdido]" |
| `CAPTION_BOSS_PHASE` | [Boss roars: a new phase] | [El jefe ruge: nueva fase] | Captions (subtitles option) | Keep (a caption for a sound) |
| **C. Enemies: Codex lines (tactics)** | | | | |
| `ENEMY_CHARGER_DESC` | Runs at you, locks a straight lane and charges along it, then stands dazed: the moment to punish it. | Corre hacia ti, fija un carril recto y embiste por él; después queda aturdido: el momento de castigarlo. | Codex → Enemies | Shorten to a look line, no tactics: "Runs at you and charges." / "Corre hacia ti y embiste." |
| `ENEMY_WARDEN_DESC` | A slow rock golem that slams the ground around itself. Its front is armoured; hit it from behind. | Un gólem de roca lento que golpea el suelo a su alrededor. Su frente está blindado: atácalo por la espalda. | Codex → Enemies | Shorten: "A slow rock golem." / "Un gólem de roca lento." |
| `ENEMY_NEEDLE_DESC` | A walking turret that keeps its distance and fires a burst down a locked line, backing off when you close in. | Una torreta andante que mantiene la distancia y dispara una ráfaga por una línea fija; retrocede si te acercas. | Codex → Enemies | Shorten: "A walking turret." / "Una torreta andante." |
| `ENEMY_HATCHLING_DESC` | The Brood Mother's young: small, quick, and they lunge in straight lines. | Las crías de la Madre de la Prole: pequeñas, rápidas, embisten en línea recta. | Codex → Enemies | Shorten: "The Brood Mother's young." / "Las crías de la Madre de la Prole." |
| `ENEMY_ARC_CASTER_DESC` | Keeps its range and casts: a fan of three slow plasma balls, a wider fan, or a rune that erupts under you. | Mantiene la distancia y lanza: un abanico de tres bolas de plasma lentas, un abanico más abierto o una runa que estalla bajo tus pies. | Codex → Enemies | Shorten: "Keeps its distance and casts." / "Mantiene la distancia y lanza hechizos." |
| `ENEMY_BOMB_DRONE_DESC` | Hovers out of reach and lobs a fireball that lands where you stand and bursts into an X of four small ones. | Flota fuera de tu alcance y lanza una bola de fuego que cae donde estás y estalla en una X de cuatro más pequeñas. | Codex → Enemies | Shorten: "Hovers and lobs fireballs." / "Flota y lanza bolas de fuego." |
| `ENEMY_SWARMER_DESC` | Weak alone, dangerous in packs: it bites with a short lunge. | Débil a solas, peligroso en manada: muerde con una embestida corta. | Codex → Enemies | Shorten: "Weak alone, dangerous in packs." / "Débil a solas, peligroso en manada." |
| `ENEMY_SPLITTER_DESC` | Swipes the ground ahead of it and splits into two Splitlings when it dies. | Barre el suelo frente a sí y se divide en dos Fragmentos al morir. | Codex → Enemies | Shorten: "It splits when it dies." / "Se divide al morir." |
| `ENEMY_SPLITLING_DESC` | What is left of a Splitter: smaller, weaker, and it never splits again. | Lo que queda de un Divisor: más pequeño, más débil, y ya no se divide. | Codex → Enemies | Shorten: "What is left of a Splitter." / "Lo que queda de un Divisor." |
| `ENEMY_SHIELD_BEARER_DESC` | Turns its big shield toward you and bashes whoever stands in front. Get around it. | Gira su gran escudo hacia ti y embiste a quien tenga delante. Rodéalo. | Codex → Enemies | Shorten: "Hides behind a big shield." / "Se esconde tras un gran escudo." |
| `ENEMY_MENDER_DESC` | Never attacks: it keeps away and heals its most hurt ally. Take it down first. | Nunca ataca: se mantiene lejos y cura al aliado más herido. Acaba con él primero. | Codex → Enemies | Shorten: "Heals its allies." / "Cura a sus aliados." |
| `ENEMY_MINE_LAYER_DESC` | Drops mines as it moves; a mine arms when you touch it and blows a moment later. | Suelta minas al moverse; una mina se arma al tocarla y estalla un instante después. | Codex → Enemies | Shorten: "Drops mines as it moves." / "Suelta minas al moverse." |
| `ENEMY_SNIPER_DESC` | Shows a long line, then fires down it for heavy damage, and walks to a new spot. | Muestra una línea larga, dispara por ella con mucho daño y cambia de posición. | Codex → Enemies | Shorten: "Shoots from far away." / "Dispara desde lejos." |
| `ENEMY_LENS_DRONE_DESC` | Breaks off the Hive Lens's rim and fires slow rings of six red orbs from a distance. | Se desprende del borde de la Lente Enjambre y dispara, a distancia, anillos lentos de seis orbes rojos. | Codex → Enemies | Shorten: "Breaks off the Hive Lens." / "Se desprende de la Lente Enjambre." |
| **D. Biomes: Codex lines** | | | | |
| `BIOME_FROZEN_SHORE_DESC` | A moonlit shore locked in ice: snow, slate and frozen sea. The ice patches make you slide. | Una costa helada bajo la luna: nieve, pizarra y mar congelado. Las placas de hielo te hacen resbalar. | Codex → Biomes | Cut the rule: "A moonlit shore locked in ice." / "Una costa helada bajo la luna." |
| `BIOME_STARFALL_DESC` | Floating rock and crystal islands over a field of stars. The starglow pools speed your step. | Islas flotantes de roca y cristal sobre un campo de estrellas. Los charcos de luz estelar aceleran tu paso. | Codex → Biomes | Cut the rule: "Floating islands over a field of stars." / "Islas flotantes sobre un campo de estrellas." |
| `BIOME_RUINS_DESC` | Broken halls of old stone under a cold light. | Salones rotos de piedra antigua bajo una luz fría. | Codex → Biomes | Keep (a look line) |
| `BIOME_NIGHT_ROCKS_DESC` | Dark stone fields under a night sky. | Campos de piedra oscura bajo un cielo nocturno. | Codex → Biomes | Keep (a look line) |
| `BIOME_RED_CANYON_DESC` | Sun-baked red rock and narrow passes. | Roca roja tostada por el sol y pasos estrechos. | Codex → Biomes | Keep (a look line) |
| **E. The Loop device and Ascension** | | | | |
| `WORLD_LOOP_NAME` | Loop | Ciclo | Floating 3D label over the Loop device (loop_device.gd) | Remove the floating label (like the curse pedestal, O75) |
| `WORLD_ASCENSION_NAME` | Ascension | Ascensión | Floating 3D label over the Ascension portal (ascension_portal.gd) | Remove the floating label |
| `HUD_ASCENSION_OPEN` | The Ascension portal is open: walk into its light to face the final boss. | El portal de la Ascensión está abierto: entra en su luz para enfrentarte al jefe final. | HUD message after the last boss | Remove (explains where it goes) |
| `HUD_LOOP_DEVICE_OPEN` | Or step onto the Loop device to start loop %d with everything you carry. | O pisa el dispositivo del Ciclo para empezar el ciclo %d con todo lo que llevas. | HUD message after the last boss | Remove (explains the loop) |
| `HUD_LOOP` | Loop %d | Ciclo %d | HUD: the loop number | Keep (basic: a number players need) |
| **F. The gamble shrine** | | | | |
| `UI_GAMBLE_ODDS` | Wins %d/%d · %s %% to fail | Victorias %d/%d · %s %% de fallar | Shrine prompt line under the price (N14) | Remove (odds and wins count) |
| `UI_GAMBLE_BLOCKED` | Spent · the shrine gave its %d wins | Agotado · el santuario dio sus %d victorias | Shrine prompt once spent (N14) | Shorten: "Spent" / "Agotado" (same as UI_GAMBLE_SPENT_TAG) |
| `UI_GAMBLE_SPENT` | The shrine has nothing left to give | El santuario ya no tiene nada que dar | Shrine prompt when it has nothing left | Shorten: "Spent" / "Agotado" |
| `UI_GAMBLE_FAILED` | It failed | Falló | Shrine: a miss | Keep (feedback, not a rule) |
| `UI_GAMBLE_USE` | [E / X] Gamble · %d shards | [E / X] Apostar · %d fragmentos | Shrine prompt with the price | Keep (button + price) |
| **G. Floor, portal and room messages** | | | | |
| `HUD_PORTAL_OPEN` | The portal is open. Walk in to go down. | El portal está abierto. Entra para bajar. | HUD message | Shorten: "The portal is open." / "El portal está abierto." |
| `HUD_PORTALS_OPEN` | Two portals are open: blue goes on, violet goes Deep (harder, richer). | Hay dos portales abiertos: el azul sigue, el violeta baja a lo Profundo (más duro, más botín). | HUD message (two portals) | Shorten: "Two portals are open." / "Hay dos portales abiertos." (the colours explain nothing more) |
| `HUD_EXPLORE_AFTER_BOSS` | The boss door is open: explore the rest of the floor, the portal waits for you. | La puerta del jefe está abierta: explora el resto del piso, el portal te espera. | HUD message after a boss | Remove |
| `HUD_SHARDS_HALVED` | The portal kept half your shards: -%d | El portal se quedó con la mitad de tus fragmentos: -%d | HUD message on a Deep portal | Shorten to the number: "-%d shards" / "-%d fragmentos" |
| `HUD_OVERRUN_CLEARED` | Overrun cleared, the doors open: an ability card and double shards | Asedio superado, las puertas se abren: una carta de habilidad y fragmentos dobles | Overrun banner | Shorten: "Overrun cleared" / "Asedio superado" |
| `HUD_ARENA_CLEARED` | Arena cleared: the doors are open, its reward is unlocked | Arena superada: las puertas se abren, su recompensa está desbloqueada | Arena banner | Shorten: "Arena cleared" / "Arena superada" |
| `GATE_SEALED` | The gate is sealed. The way on isn't open yet. | La puerta está sellada. El camino aún no está abierto. | HUD message at a sealed gate | Shorten: "Sealed." / "Sellada." |
| `UI_EVENT_LEAVE_DESC` | Walk away. You can come back later. | Márchate. Puedes volver más tarde. | Floor event panel, the Leave option | Shorten: "Walk away." / "Márchate." |
| `UI_EVENT_COST_DEFEND` | Stay by it for %d s; enemies come faster | Quédate a su lado %d s; los enemigos llegan antes | Floor event panel, a cost | Shorten: "Stay by it for %d s" / "Quédate a su lado %d s" |
| **H. Menus that explain** | | | | |
| `UI_CODEX_LOCKED` | Not met yet. Meet it in a run to fill this page. | Aún no lo has encontrado. Encuéntralo en una partida para llenar esta página. | Codex, a locked page | Shorten: "Not found yet." / "Aún sin descubrir." |
| `UI_ACH_HIDDEN` | A hidden achievement. Keep playing to find it. | Un logro oculto. Sigue jugando para descubrirlo. | Achievements page, a hidden one | Shorten: "Hidden." / "Oculto." |
| `UI_BUILD_SLOTS` | %d of %d slots · the wand reads left to right | %d de %d huecos · la varita se lee de izquierda a derecha | Build page header | Shorten: "%d of %d slots" / "%d de %d huecos" |
| `MAP_LEGEND_BOSS` | Boss door (dim: open after the boss) | Puerta del jefe (tenue: abierta tras el jefe) | Minimap legend | Shorten: "Boss door" / "Puerta del jefe" |
| `MAP_LEGEND_ARENA` | Arena (seals until cleared, holds rewards) | Arena (se sella hasta superarla, guarda recompensas) | Minimap legend | Shorten: "Arena" / "Arena" |
| `WAND_READ_FIRE` | You fire %s. | Disparas %s. | Build page: the wand read out (WAND_READ_*, 12 rows) | Ask: keep (it reads your own build, not a rule) or remove the read-out |


## Size by group

| Group | Rows | Remove | Shorten | Keep / ask |
|---|---|---|---|---|
| A. Tutorial hints (first floor, the TIP box) | 14 | 4 | 4 | 6 |
| B. Bosses: Codex lines and boss-fight messages | 15 | 0 | 13 | 2 |
| C. Enemies: Codex lines (tactics) | 14 | 0 | 14 | 0 |
| D. Biomes: Codex lines | 5 | 0 | 2 | 3 |
| E. The Loop device and Ascension | 5 | 4 | 0 | 1 |
| F. The gamble shrine | 5 | 1 | 2 | 2 |
| G. Floor, portal and room messages | 9 | 1 | 8 | 0 |
| H. Menus that explain | 6 | 0 | 5 | 1 |
| **Total** | 73 | 10 | 48 | 15 |
