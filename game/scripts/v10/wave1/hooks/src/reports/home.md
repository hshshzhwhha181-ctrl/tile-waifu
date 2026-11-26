## Lane 4 home builder: done

Both files parse cleanly. The self-check returns 0 issues, and my scratch runner reports ok=894, bad=0. I made no git changes.

### Files (only inside game/scripts/v10/wave1/)
- **`/home/user/tile-waifu/game/scripts/v10/wave1/w1_home_lines.gd`** (`class_name V10W1HomeLines`, about 1140 lines). Text only, never gated. Tables: TOUCH, TIME_GREET, CLOCK, DATES, TICKLE, STAR, CAMEO, CAMEO_LOCKED, PEEK_PLAY, BARKS, SIGN, PS, LETTERS, ARRIVALS, ARRIVAL_TITLES, GIFT_LINES, ROOM_LINES, OPENERS, MOMENTS, ENDINGS, ROOM_SCENES.
- **`/home/user/tile-waifu/game/scripts/v10/wave1/w1_home.gd`** (`class_name V10W1Home`). Contents:
  - **Data:** ROOMS, PREFS, FAV, HAND, HAND_R, COURIER, OUTFITS, plus the schema and limit consts.
  - **Helpers:** `touch_pool`, `greet`, `clock_line`, `date_line`, `egg`, `barks`, `letters`, `courier_line(name, i)`, `arrival_id(h)`, `pending_arrival(seen, unlocked: Callable)`, `arrival_play(h)`, `scene_ids`.
  - **Merge and checks:** `merges()`, `merge_into(dst, src, nested)` (never overwrites a founder's key), `strings()`, `lint()`, `self_check() -> Array`.
- `.uid` files were created by `--import`. The class cache has both classes.
- **Parse-clean under `--check-only`:** w1_home.gd has no compile-time reference to G, Sfx, V7RoomData or V8Art, which `--check-only` cannot resolve. Those consts are read with `load(path).get_script_constant_map()`, and G.hero_unlocked is passed in as a Callable.

### Consumers mirrored (same schema, same counts as the founders)
- `V9TouchLines.LINES` and `V9Touch.RIG_HAND` / `RIG_HAND_R`.
  - Hand zones were measured on the cut-outs.
  - Kohaku has no hand zone: her hands are in her sleeves inside the waist guard.
- `V7Lines` (eggs): TIME_GREET, CLOCK, DATES, TICKLE, STAR, CAMEO, CAMEO_LOCKED, PEEK_PLAY.
- `V6Txt.LINES` (the Sfx.say barks): all 27 kinds at Маджонг-тян's counts. Greets mix «return» lines (matching Sfx.RETURN_MARKS) with fresh ones.
- `V9LetterText` SIGN, PS and LETTERS: 4 events × 2 variants, with the 0.9 placeholders. The comeback letters carry no guilt.
- `V6Scenes.SCENES` / `TITLES`: one arrival per heroine, `arrive_<h>`.
  - Salon setting, cast [mc, h], one ask worth 5 or 6 affection.
  - Titles are the catchphrases: «Доставлено.», «Попробуй!», «Удача любит меня», «Звёзды не лгут», «Весна пришла!».
- `V7RoomData`: ROOMS, PREFS, FAV, GIFT_LINES, ROOM_LINES, OPENERS (all 7 places), MOMENTS, ENDINGS.
- `V7RoomScenes.SCENES`: `<h>_2/4/7/10`.
  - Photos use the heroine's own outfit ids, since G.ITEM ids equal V10W1Core.ITEMS ids.
  - Affection is 8/5, 8/6, 10/6 and 15/10, and every level-10 scene has a black beat.
- Tsubame as courier: `COURIER` holds 4 toast lines with `%s` for the sender's name.

### Counts per goddess (the same for all five)
| Table | Count |
|---|---|
| Touch | 18 (head 4, hand 3, outfit 3, bg 3, spam 2, idle 3) |
| Time greetings | 8 (4 phases × 2) |
| Special minute | 1 |
| Dates | 2 for tsubame and kohaku, 1 for the others |
| Eggs | tickle, star, cameo, cameo_locked, peek: 1 each |
| Barks | 52 across 27 kinds |
| Letters | 8, plus sign and P.S. |
| Arrival scene | 1 |
| Gift lines | 6 (love / like / plain × 2) |
| Room lines | 6 (3 tiers × 2) |
| Openers | 7 |
| Moments | 5 × 3 choices graded 2/1/0 |
| Endings | 3 |
| Room scenes | 4 |

The project has 1227 visible strings in total.

### Hooks for the integrator (exact code)
**H-home-1.** Change `const` to `static var` on these tables. I tested that a static var dict built from a literal is mutable, nested dicts included. No other const depends on these tables (checked by grep).
- `scripts/v09/home/touch_lines.gd:11` LINES
- `scripts/v09/home/touch.gd:36,38` RIG_HAND, RIG_HAND_R
- `scripts/v07/eggs/lines.gd` TIME_GREET:14, CLOCK:48, DATES:58, TICKLE:69, STAR:78, CAMEO:87, CAMEO_LOCKED:95, PEEK_PLAY:103
- `scripts/v06/story/txt.gd:342` LINES
- `scripts/v09/letters/letter_text.gd` SIGN:13, PS:14, LETTERS:18
- `scripts/v06/story/story_scenes.gd` SCENES:15, TITLES:192
- `scripts/v07/room/room_data.gd` ROOMS:26, PREFS:50, GIFT_LINES:71, ROOM_LINES:90, FAV:132, OPENERS:134, MOMENTS:173, ENDINGS:287
- `scripts/v07/room/room_scenes.gd:14` SCENES

Each change has this form: `const LINES: = {` becomes `static var LINES: = {`.

**H-home-2.** In V10Wave1, call this once at boot when released. Run it after core's merge_g / merge_art.
```gdscript
static func merge_home() -> void:
	if not released():
		return
	V10W1Home.merge_into(V9TouchLines.LINES, V10W1HomeLines.TOUCH)
	V10W1Home.merge_into(V9Touch.RIG_HAND, V10W1Home.HAND)
	V10W1Home.merge_into(V9Touch.RIG_HAND_R, V10W1Home.HAND_R)
	V10W1Home.merge_into(V7Lines.TIME_GREET, V10W1HomeLines.TIME_GREET)
	V10W1Home.merge_into(V7Lines.CLOCK, V10W1HomeLines.CLOCK, true)
	V10W1Home.merge_into(V7Lines.DATES, V10W1HomeLines.DATES, true)
	V10W1Home.merge_into(V7Lines.TICKLE, V10W1HomeLines.TICKLE)
	V10W1Home.merge_into(V7Lines.STAR, V10W1HomeLines.STAR)
	V10W1Home.merge_into(V7Lines.CAMEO, V10W1HomeLines.CAMEO)
	V10W1Home.merge_into(V7Lines.CAMEO_LOCKED, V10W1HomeLines.CAMEO_LOCKED)
	V10W1Home.merge_into(V7Lines.PEEK_PLAY, V10W1HomeLines.PEEK_PLAY)
	V10W1Home.merge_into(V6Txt.LINES, V10W1HomeLines.BARKS)
	V10W1Home.merge_into(V9LetterText.SIGN, V10W1HomeLines.SIGN)
	V10W1Home.merge_into(V9LetterText.PS, V10W1HomeLines.PS)
	V10W1Home.merge_into(V9LetterText.LETTERS, V10W1HomeLines.LETTERS)
	V10W1Home.merge_into(V6Scenes.SCENES, V10W1HomeLines.ARRIVALS)
	V10W1Home.merge_into(V6Scenes.TITLES, V10W1HomeLines.ARRIVAL_TITLES)
	V10W1Home.merge_into(V7RoomData.ROOMS, V10W1Home.ROOMS)
	V10W1Home.merge_into(V7RoomData.PREFS, V10W1Home.PREFS)
	V10W1Home.merge_into(V7RoomData.FAV, V10W1Home.FAV)
	V10W1Home.merge_into(V7RoomData.GIFT_LINES, V10W1HomeLines.GIFT_LINES)
	V10W1Home.merge_into(V7RoomData.ROOM_LINES, V10W1HomeLines.ROOM_LINES)
	V10W1Home.merge_into(V7RoomData.OPENERS, V10W1HomeLines.OPENERS)
	V10W1Home.merge_into(V7RoomData.MOMENTS, V10W1HomeLines.MOMENTS)
	V10W1Home.merge_into(V7RoomData.ENDINGS, V10W1HomeLines.ENDINGS)
	V10W1Home.merge_into(V7RoomScenes.SCENES, V10W1HomeLines.ROOM_SCENES)
```
CLOCK and DATES are nested merges (`[time or date][hero]`). All 5 of my times already exist as founder keys, so wave-1 heroes are added inside those keys.

**H-home-3.** Arrival trigger in home.gd (a hot file), wherever the screen already plays pending story:
```gdscript
var w1h: = V10W1Home.pending_arrival(V6Story.st().seen, G.hero_unlocked) if V10Wave1.released() else ""
if w1h != "":
	await V6Story.play(V10W1Home.arrival_id(w1h))   # V6Story.play marks the scene seen
```
Without the SCENES merge, use the room runner instead: `await V7RoomScene.run(V10W1Home.arrival_play(w1h))`, then `V6Story.mark(V10W1Home.arrival_id(w1h))`.

**H-home-4 (optional).** Courier toast when a letter from another heroine arrives: `V10W1Home.courier_line(V9LetterText.SIGN.get(sender, sender))`.

### Notes
- **Room backgrounds:**
  - tsubame: bg_rooftop
  - kohaku: bg_shrine
  - shirin: bg_festival
  - miel: menu.webp, which differs from core STAGE_BG bg_street
  - zlata: `res://assets/v10/look/zlata/menu_bg.webp`, which differs from core STAGE_BG menu

  self_check confirms every path exists.
- All wave-1 lines are text only (no `v` voice keys).
- BIO in txt.gd is unused, so I skipped it; core owns the profile facts.
- **Dependency on the look lane:** after the merge, the founders' letters and touch selftests check `V8Art.has_emotion(h, emo)` for every heroine in G.HERO_ORDER. Wave-1 emotion art is missing until the look lane's merge_art runs.

### Self-checks for the integrator's selftest
- `V10W1Home.self_check().is_empty()`. It covers:
  - completeness, no founder keys, counts and emotions
  - return/fresh greets, letter schema and placeholders
  - scene rules: cast, a single ask, affection values, photo in OUTFITS, level-10 black beat
  - room backgrounds exist, gift ids are in V7RoomData.GIFTS, places are in PLACES
  - hand inside the art bounds
  - every string within the founders' max length per field (story narr 128, room-scene narr 117, and so on)
  - V10Lint plus the red-line and jargon list, balanced «», no straight quotes, no Latin except SSR and P.S.
- After H-home-2, each `merges()` target contains all five ids, and founder entries are unchanged. I simulated this on deep copies: +5 keys per table, +20 room scenes.
- Hand zone: `V9Touch.classify(V9Touch.rig_geom(h), V10W1Home.hand(h)) == "hand"` for tsubame, miel, shirin and zlata. Verified with the wave-1 rigs from `V10W1Core.rig(h)`.
- Letters pixel checks, the same as v09 letters_selftest:
  - widest reply 335 px of 560
  - tallest answer 58 px of 88
  - widest subject 311 px of 500
- Case-insensitive grep of the BANNED stems over both files is clean. The only hit is w1_home.gd's own EXTRA_BANNED list.

My scratch runners are `/tmp/claude-0/-home-user/a87f03f9-e6ed-50fa-86f7-4bae7fb623cc/scratchpad/home_tools/run_home_check.gd` and `/tmp/claude-0/-home-user/a87f03f9-e6ed-50fa-86f7-4bae7fb623cc/scratchpad/home_tools/counts.gd`. Run each with `-s`.

### Environment (for the lead)
The session's setup script failed with exit 127. Line 4 is `permissions:`, which looks like a settings line pasted into the shell script. It needs fixing in the environment settings; I did not touch it. Godot at /opt/tw-tools/godot works.