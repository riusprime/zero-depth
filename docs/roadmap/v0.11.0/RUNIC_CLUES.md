# v0.11.0 G1 — the Runic Stone's lines become clues (approve row by row)

From the brief §7 (room messages "not connected to anything … an Easter egg … a little lore"), the owner's Q24 (it's
the hub's Runic Stone) and Q25 (a): "each line becomes a clue …; the ten together tell one short story; the last line
opens something real". PLAN row R1, step O14. Nothing is built before the rows are answered.

## How the stone works today (v0.9.5 RS1/RS2, `src/application/runic_stone.gd`, `data/hub/runic_lines.tres`)
- Ten lines, each learned once by a hidden feat. Pressing the stone shows the lines it knows in a speech bubble,
  **in runes only** (Elder Futhark, one rune per English letter). There is no translation in the game: decoding the
  cipher is the Easter egg. All ten unlock the Runic robe.
- The lines read as riddles but point nowhere, and the feats are only findable by accident.

## The idea (the lead's proposal)
- **A chain:** each line, once decoded, is a clue to **the next line's feat**. Learn one, decode it, and it tells you
  how to earn the next. Learning order stays free (any feat still teaches its line), but a player who decodes follows
  the chain.
- **A story:** read r1 → r10 in order, the lines are the city (the Depths, Codex Lore: "The Depths were a city once")
  speaking to you, from waking to trusting you.
- **The end:** with all ten, the stone speaks an eleventh line that points to the reward (below), and the robe still
  unlocks.
- Feats stay exactly as today. Lines stay English under the runes (the cipher), short, avoiding letters the cipher
  can't spell. The lead checks every line against the glyph table when building.

## The rows

| # | Learned by (today, unchanged) | Today's line | New line (decodes to) | Points to | Story beat |
|---|---|---|---|---|---|
| r1 | Activating a purple-rune room in a run | WHAT SLEEPS BELOW REMEMBERS | I WAKE. FALL TEN TIMES AND I WILL KNOW YOU | r2 (10 deaths) | the city wakes |
| r2 | 10 deaths | YOU RETURN AND RETURN | YOU RETURN. KNOCK AND KNOCK AND I ANSWER | r3 (7 presses in a row) | it learns you keep coming back |
| r3 | Pressing the woken stone 7 times in a row | PATIENCE IS A KEY | I ANSWER. NOW FACE A GUARDIAN UNTOUCHED | r4 (a floor boss with no hit) | it answers, and tests you |
| r4 | A floor boss beaten without a hit | UNTOUCHED BY THE DEEP | UNTOUCHED. STAND STILL HERE AND LISTEN | r5 (60 s still in the hub) | it trusts you enough to speak |
| r5 | 60 s standing still in the hub | THE STILL ONE SEES | I SPEAK. GATHER THE PIECES I DROPPED | r6 (8 of the 16 collectibles) | it remembers what it lost |
| r6 | 8 collectibles found | THE PIECES CALL TO ONE ANOTHER | MY PIECES. THE CROWN WENT DOWN FIRST. END IT | r7 (beat the Hollow Crown) | it names the one who sank it |
| r7 | The Hollow Crown beaten | THE CROWN WAS ALWAYS HOLLOW | IT IS ENDED. NOW TURN THE TOP TO THE BOTTOM THRICE | r8 (3 Ascension loops in one run) | it shows you how it turns over |
| r8 | 3 Ascension loops in one run | THE WHEEL TURNS FOR THE PATIENT | I TURN. MY CRACKED WALLS HIDE ROOMS, OPEN THEM RUN AFTER RUN | r9 (cracked walls on 5 runs) | it shows you where it hides |
| r9 | A cracked wall broken on 5 different runs | THE WALLS HIDE WHAT THEY FEAR | I HIDE NO MORE. SPEAK TO ME IN THE OTHER TONGUE | r10 (switch the language at the stone) | it opens up fully |
| r10 | Switching the language with the stone awake | EVERY TONGUE ONE RUNE | EVERY TONGUE. MY HEART LIES UNDER THE THRONE | the reward | it gives you its heart |
| r11 | All ten learned (new) | — | (the reward's location line, once Q-O14b is answered) | — | the end |

## Questions in this G1
- **Q-O14a. The chain:** each line hints the next feat, as above (rec); or each line hints **its own** feat (a player
  who already has it learns nothing new); or keep riddles that point nowhere.
- **Q-O14b. The reward ("opens something real"):** (a) **rec:** a hidden room on the final floor, under the Hollow
  Crown's throne (the city's heart): a short lore scene in runes and one unique card or relic found only there; (b) a
  secret final-boss variant (the Crown "remembered" by the city: a harder fight with its own end line); (c) both.
- **Each row:** approve, change the wording, or cut.

## Owner answers (2026-11-07)
- **Q-O14a:** "Chain": each line hints the next feat.
- **Q-O14b:** "Both": the hidden room under the Hollow Crown's throne leads to a secret "remembered" Hollow Crown fight.
  The owner designs the boss fights (Q13), so that variant's moves wait for the owner's boss brief; O14 builds the
  chain, the eleventh line, the room and the door into the fight.
- **Rows r1–r10:** "Approve all 10" as written.
