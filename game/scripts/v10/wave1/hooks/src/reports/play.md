## Lane 4, PLAY builder: final report

The data is finished and every hook is tested. `w1_play.gd` is parse-clean and its own `self_check()` passes with 0 failures inside the running project. Applied to scratch copies of the 17 consumer files, the hooks compile and all 40 smoke checks pass. For the founders the results are identical: duel data, styles, blessing offers, AI styles and a 1000-player population compared row by row. I changed no file outside `game/scripts/v10/wave1/` and ran no git command that changes state.

**File written:** `/home/user/tile-waifu/game/scripts/v10/wave1/w1_play.gd`. It is `class_name V10W1Play`, `extends RefCounted`, and holds ungated data plus small static helpers. It does not reference `V10Wave1`; every gate is in the hook code below.

**Hooks ready to apply:** `/tmp/claude-0/-home-user/a87f03f9-e6ed-50fa-86f7-4bae7fb623cc/scratchpad/play/hooks/w1_play_hooks.diff` holds 68 edits in 17 files. `git apply --check` from the repo root reports it applies cleanly. The generator is `/tmp/claude-0/-home-user/a87f03f9-e6ed-50fa-86f7-4bae7fb623cc/scratchpad/play/hooks/hooks.py`; each old string matches exactly once, and `python3 -I hooks.py test` re-runs the scratch-copy test. The test runner is `/tmp/claude-0/-home-user/a87f03f9-e6ed-50fa-86f7-4bae7fb623cc/scratchpad/play/hooks/run_hooks.gd`.

### What each table mirrors
| `V10W1Play` table | Consumer and symbol | What the five goddesses get |
|---|---|---|
| `SKILLS`, `skill(h)` | `G.SKILLS` | Ult core name and description from the ROSTER cards: Теневой шаг, Печенье-джокер, Лисий оберег, Танец монет, Огненный шлейф. `skill(h)` returns `G.SKILLS[h]` for founders. |
| `SKILL_PAIRS` | `V6Skills.use`, used only when no V9 ult is attached | 1 pair each |
| `PERKS`, `PERK_EFF`, `perk(h)`, `apply_perk(play, h)` | `G.PERKS` and `Play._apply_perk` | Цубамэ +1 перемешивание, Миэль +1 подсказка, Кохаку +1 отмена, Ширин золото ×7 (Юэ ×8), Злата окно комбо +1 с (Хана +1,5 с) |
| `RIVALS`, `DUEL_LINES` | `V6Heroines.RIVALS`, `V6Heroines.DUEL_LINES` | Pace 3.9–5.3 (founders 3.7–5.6); duel skills use the existing sprint, double and veil kinds; existing backdrops; 9 bark kinds each |
| `PASSIVES`, `passive_engine(h)` | `V7Passives.DATA`, run by `V7PassiveRun` | Each style runs on a founder's engine and is never stronger than that founder (details below) |
| `V6_BLESS`, `V6_BLESS_ORDER`, `v6_bless_pick()` | `V6ModesData.BLESS` («Лунная лестница») | One blessing per goddess, same id and name as the Pagoda's: smoke «Дымовая завеса», sugar «Сахарная пудра», foxluck «Лисья удача», mirage «Мираж», feather «Перо жар-птицы». Effects use only the climb's existing run fields (lamps, hint, undo, shuffle, slots). |
| `SHIFT_GUESTS`, `SHIFT_TASTE`, `SHIFT_ORDER_LINES`, `SHIFT_THANKS`, `SHIFT_LEAVE`, `shift()` | `V6ModesData.GUESTS`, `TASTE`, `ORDER_LINES`, `THANKS`, `LEAVE` («Смена в чайной») | Guests with patience and tips inside the founders' range |
| `AI_STYLES` | `V8AI.STYLES` | Every key inside the founders' min–max |
| `POP_AVATARS`, `POP_HERO_NICKS`, `pop_face()`, `pop_overlay()`, `is_outfit_img()`, `outfit_path()` | `V8Population` (`AVATARS`, `HERO_NICKS`, `FACES`) | League avatars, face crops and the nick filter |
| `HOST_NAMES` | `V10PathRules.HOST_NAMES` | Chapter hostess names |

The passive styles:
- **Цубамэ** «Обходной путь»: Нова's engine, every 6 pairs (Нова: 5).
- **Миэль** «Добавка»: Рин's engine, a cake every 5 pairs, at most 2 (Рин: 4 and 2).
- **Кохаку** «Лисьи огни»: Юэ's engine with the see-through glow, every 4 pairs (Юэ: 3).
- **Ширин** «Ритм каравана»: Хана's engine, needs combo ×3 (Хана: ×2).
- **Злата** «Оттепель»: Юэ's engine without the glow, every 3 pairs.

### Exact hook code
Every hook sits behind `V10Wave1.released()`, except where marked "no gate". Those edits are proven identical for the founders.

1. **`screens/levels.gd`** (no gate)
   - `G.SKILLS[h].name` becomes `V10W1Play.skill(h).name`.
   - `G.SKILLS[h].desc` becomes `V10W1Play.skill(h).desc`.
   - `% G.PERKS[h]` becomes `% V10W1Play.perk(h)`.

2. **`screens/play.gd`**
   - Perk tip: `G.PERKS[partner]` becomes `V10W1Play.perk(partner)`.
   - Ult name fallback: `String(G.SKILLS[partner].name)` becomes `String(V10W1Play.skill(partner).name)`.
   - In `_apply_perk`, after the `"nova":` case, add:
     ```
     		_:
     			if V10Wave1.released():
     				V10W1Play.apply_perk(self, partner)
     ```

3. **`v06/heroines/skills.gd`**
   - `var sk: Dictionary = G.SKILLS[h]` becomes `var sk: Dictionary = V10W1Play.skill(h)`.
   - Add a final case to the first `match h:`, after the `"yue":` block:
     ```
     		_:
     			if V10Wave1.released():
     				pairs = _pairs(board, int(V10W1Play.SKILL_PAIRS.get(h, 0)))
     ```

4. **`v06/heroines/heroines_data.gd`**
   - Add after `const RIVAL_SKILL_NEED`:
     ```
     static func has_rival(h: String) -> bool:
     	return RIVALS.has(h) or (V10Wave1.released() and V10W1Play.RIVALS.has(h))
     static func rival_def(h: String) -> Dictionary:
     	if RIVALS.has(h):
     		return RIVALS[h]
     	if V10Wave1.released() and V10W1Play.RIVALS.has(h):
     		return V10W1Play.RIVALS[h]
     	return RIVALS.rin
     ```
   - In `line()`, after `var d: Dictionary = DUEL_LINES.get(h, DUEL_LINES.mc)`, add:
     ```
     	if not DUEL_LINES.has(h) and V10Wave1.released() and V10W1Play.DUEL_LINES.has(h):
     		d = V10W1Play.DUEL_LINES[h]
     ```
   - In `duel_cfg`, `RIVALS.get(rival, RIVALS.rin)` becomes `rival_def(rival)`.
   - In `rival_pace`, `RIVALS.get(h, RIVALS.rin)` becomes `rival_def(h)`.

5. **`v06/heroines/duel.gd`**
   - Lines 46–47 become:
     ```
     	rival = rival_id if V6Heroines.has_rival(rival_id) else "rin"
     	rv = V6Heroines.rival_def(rival)
     ```
   - Shard on a win: `if not G.hero_unlocked(rival) and not rival in V10W1Play.HEROES and String(d.duel_day...`

6. **`v07/passives/passives.gd`**
   - First line of `info()`:
     ```
     	if not DATA.has(h) and V10Wave1.released() and V10W1Play.PASSIVES.has(h):
     		return V10W1Play.PASSIVES[h]
     ```
   - First line of `fit()`:
     ```
     	if not DATA.has(h) and V10Wave1.released() and V10W1Play.PASSIVES.has(h):
     		h = V10W1Play.passive_engine(h)
     ```

7. **`v07/passives/passive_run.gd`**
   - Add `var who: = "mc"`.
   - In `setup`:
     ```
     	who = h
     	d = V7Passives.info(h)
     	h = String(d.get("engine", h))
     ```
   - The chip avatar and both `passive_note` calls use `who` instead of `h`.
   - `V7Passives.RIN_EVERY`, `RIN_MAX`, `YUE_EVERY`, `NOVA_EVERY` and `HANA_COMBO` become `int(d.get("every" | "max" | "combo", <the same const>))`.
   - The float texts become `d.get("gain" | "act" | "pulse", <the founder's text>)`.
   - Overlay:
     - `var cy: Color = run.d.get("tint", Color(0.3, 0.95, 1.0))`
     - `elif run.h == "yue" and bool(run.d.get("see", true)):`
     - `var mc: Color = run.d.get("tint", Color(0.72, 0.84, 1.0))`
     - The crescent badge is drawn only when `d` has no `"tint"`; otherwise a small dot in the tint colour.
   - The founders' `DATA` has none of these keys, so their behaviour does not change.

8. **`v10/clarity/glossary.gd`**, first line of `passive_note`:
   ```
   	if not PASSIVE_SHORT.has(hero) and V10Wave1.released() and V10W1Play.PASSIVES.has(hero):
   		return "Свойство: %s" % String(V10W1Play.PASSIVES[hero].short)
   ```

9. **`v06/modes/modes_data.gd`**
   - Add `bless_ids()`: `BLESS.keys()` plus `V10W1Play.V6_BLESS_ORDER` when released.
   - Add `bless_def(id)`: `BLESS[id]`, or `V10W1Play.V6_BLESS.get(id, BLESS.lamp)`.
   - `bless_plus` uses `bless_def(id).hero`.
   - `bless_offer`:
     ```
     	for id in bless_ids():
     		...
     		if (id in BLESS_ONCE or bool(bless_def(id).get("once", false))) and n > 0:
     			continue
     		if n >= int(BLESS_CAP.get(id, bless_def(id).get("cap", 3))):
     ```
   - Add `guests()`: `GUESTS + V10W1Play.SHIFT_GUESTS` when released.
   - Add `guest(h, part)`: the founder's table, or `V10W1Play.shift(h, part)`.

10. **`v06/modes/mode_play.gd`**
    - All five `V6ModesData.BLESS[id]` become `V6ModesData.bless_def(id)`.
    - In `_pick_blessing`, after `"clear"`:
      ```
      		_:
      			if V10Wave1.released():
      				V10W1Play.v6_bless_pick(run, id, plus)
      ```
    - `var pool: Array = V6ModesData.guests().filter(...)`.
    - `TASTE[h]`, `ORDER_LINES[h]`, `THANKS[h]` become `guest(h, "taste" | "order" | "thanks")`; `LEAVE[h]` becomes `String(guest(h, "leave"))`.
    - `v8_res_avatars(ctx, V6ModesData.guests(), …)`.

11. **`v08/table/ai.gd`**
    - Add `has_style(h)`: `STYLES.has(h)`, or released and `V10W1Play.AI_STYLES.has(h)`.
    - Add `style_for(h)`: `STYLES[h]`, else `V10W1Play.AI_STYLES[h]` when released, else `STYLES.mc`.
    - `style_of` uses `style_for(String(r.players[s].get("id", "mc")))`.
    - These are shared with the mj lane:
      - `v10/mj/riichi/table_driver.gd:59`: `"id": h if V8AI.has_style(h) else "mc"`
      - `table_driver.gd:212`: `V8AI.style_for(String(hero_of[s]))`
      - `v10/mj/sanma/landlord.gd:40`: `V8AI.style_for(String(host_id))`

12. **`v08/league/population.gd`**
    - Add `const POP_HEROES: = ["mc", "rin", "hana", "yue", "nova"]` and use it instead of `G.HERO_ORDER` for the hero and fav draws in `_generate`. This keeps the 0.8 population byte-identical.
    - Build the row as `var row: = {...}`, then:
      ```
      		if V10Wave1.released():
      			V10W1Play.pop_overlay(row)
      		_pop.append(row)
      ```
    - `_clean`: `... and not core in V10W1Play.POP_HERO_NICKS` (no gate; no current nick collides, so the population is unchanged).
    - `face()`:
      ```
      	if not FACES.has(img) and V10Wave1.released() and V10W1Play.is_outfit_img(img):
      		return V10W1Play.pop_face(img)
      ```

13. **`v08/league/league_selftest.gd`**: the avatar-exists check also accepts `ResourceLoader.exists(V10W1Play.outfit_path(p.avatar))`.

14. **`v10/levels/level_gen.gd`**
    - New signature: `ready_hero(id, w, shard := false)`. It returns `id` when `id in READY_HEROES or (not shard and V10Wave1.released() and id in V10W1Play.HEROES)`.
    - The shard field passes `true`: `"shard": ready_hero(str(W.shard), w, true)`.

15. **`v10/path/path_rules.gd`**: `host_name()` returns `V10W1Play.HOST_NAMES[h]` when the name is not in `HOST_NAMES` and wave 1 is released.

### Two things the hooks protect against
- **League crash:** `V8Population._generate` does `AVATARS.filter(begins_with(hero + "_"))` and then `% outs.size()`. If the core agent adds the goddesses to `G.HERO_ORDER`, that list comes back empty and generation crashes with a modulo by zero. Hook 12 prevents this.
- **Shard unlocks:** without the shard flag, the Path and duel wins could unlock Кохаку and Злата through shards, which goes against ROSTER §1.4 and the glossary. Hooks 5 and 14 keep shards on the founders (`SHARDS_FROM_PLAY = false`).

### Self-checks for `--wave1_selftest`
Call `V10W1Play.self_check()`; an empty array means pass. It checks:
- every table has exactly the five goddesses and overrides no founder;
- each entry has the founder template's keys (`G.SKILLS.mc`, `RIVALS.mc`, `DUEL_LINES.mc`, `V7Passives.DATA.mc`, `TASTE.mc`, `V8AI.STYLES.mc`, `BLESS.lamp`);
- pace, AI style values, patience and tips sit inside the founders' min–max;
- each passive is no stronger than the founder whose engine it uses; perks give at most +1 of a help, below Юэ's gold and Хана's combo; each blessing «+» gives at most 4 helps;
- rival skill kinds, backdrop files and effect names exist;
- each goddess's Лестница blessing has the same id and name as her Pagoda blessing (`V10ModsData`);
- the upstream tables `V10Journey.BOSS`, `V10TowerBoard.STYLE` and `V10TowerUtil.ROSTER` carry all five;
- avatars are her own outfits, with no «Обет»;
- adding the goddesses' names to the nick filter changes nothing in today's population;
- the overlay gives each goddess 4–12% of the 1000 league players;
- all 176 texts pass `V10Lint` with no «бесплатн» at all and no Latin letters.

Also worth adding to the selftest: the founder-equality checks from `run_hooks.gd` (`fit`, `rival_def`, `passive_note`, population rows identical, wave-1 mains around 41%).

### Left out on purpose
- **`v07/event/event_data.gd`:** each event brings its own currency, which is not allowed here. It also needs new event art (`cg_*` and `ev_*`), and adding events would shift the cycle-based rotation for every player. Miel's «Испечь вместе» is a 1.0 event.
- **`v06/map/worlds.gd`:** keyed by world, not by heroine, and levels 1–48 stay unchanged per spec П1.
- **`v10/tower/*`:** the five Pagoda blessings, the Journey bosses and the tower's AI styles are already there and gated by `V10TowerUtil.released()`.
- **`v10/salon/*`:** only the zone heroines have lines; salon guests are planned for 1.1.
- **Path boss lines:** the founders have none in `level_gen`, so adding them only for wave 1 would be inconsistent.
- **League avatars:** limited to the A and S outfits until the SSR outfits' «bold» flags and the pending sh_sun audit are final.

### Notes for the integrator and core lanes
- If the goddesses join `G.HERO_ORDER`, the duel picker in `screens/modes.gd` (a 760 px popup with 136 px rows) needs scrolling. Its «победа = осколок» line also has to be hidden for wave-1 rivals.
- Population avatars use outfit ids such as `tb_base`. `V8Art._portrait` only looks in `assets/outfits/`, so the core lane's `V8Art` path hook must resolve `V10W1Play.outfit_path(img)`.
- `pop_face` reads `data/w1_art_cards.json` (`face_rect` and `size`, in pixels or normalized) at runtime and caches it. Until that file exists it falls back to `[0.5, 0.17, 4.7]`.
