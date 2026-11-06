# EP4 evidence: offer cards, a big banner and HUD badges show element pairs

Base SHA (EP1): 1dcc2031 (branch `v095-ep4`; the EP4 commit follows it). Machine: the owner's PC (Windows, Godot 4.7.2).

Commands (each `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://<file> -gexit`, or `-gdir=res://<dir> -ginclude_subdirs`):

| Target | Result (GUT totals) |
|---|---|
| tests/unit/sim/test_element_pair_preview.gd (new) | Tests 5, Passing 5, Asserts 7 |
| tests/unit/sim/test_element_pairs.gd | Tests 30, Passing 30, Asserts 260 |
| tests/unit/presentation/test_pair_banner.gd | Tests 5, Passing 5, Asserts 63 |
| tests/e2e/test_e2e_element_pairs.gd | Tests 1, Passing 1, Asserts 11 |
| tests/e2e/test_e2e_shop.gd | Tests 3, Passing 3, Asserts 71 |
| tests/unit/presentation/ test_attack_slot_views, test_card_level_views, test_form_card_text, test_shop_views, test_event_views, test_reward_cards, test_rarity_views | 4/4, 6/6, 8/8, 6/6, 6/6, 15/15, 3/3 passing |
| tests/content (dir) | Tests 158, Passing 158, Asserts 13229 |
| tests/arch (dir) | Tests 4, Passing 4, Asserts 18381 |
| tests/e2e/test_e2e_combo.gd | FAILING: `opened reward 2`, `opened reward 3`, `the floor's cards hold a combo pair` (Passing: none, Asserts 6/9). Same failure with the offer-card line disabled; not compared against EP1 without EP4 (NOT YET RUN). |

Lint: `gdformat` (0 reformatted, 7 unchanged) and `gdlint` (Success: no problems found) on all touched .gd files.

Shot: no shot. Rendering a pick panel or the pair banner needs a new shot script and a renderer; not cheap here.
