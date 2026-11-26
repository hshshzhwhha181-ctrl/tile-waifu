## Lane 4 SOCIAL: final report

The social data for all five goddesses is written and checks clean in Godot 4.5.1. The headless `-s` SceneTree check reports `V10W1Social.problems(true)`: 0 problems, and that run includes the strict art check, since all 50 outfit/pose photo paths now exist. There are no SCRIPT ERRORs, and the lint sanity check catches «скидк / только сегодня / за парт / вино». I edited no consumer files and ran no git commands.

One thing the integrator must know: plain `--check-only` on `w1_social.gd` used to fail only because `rit_bridge.gd` needs the `G` autoload. I removed that dependency, so the module now compiles without `G`.

### Files (all mine, nothing else touched)
- `/home/user/tile-waifu/game/scripts/v10/wave1/w1_social.gd` (`V10W1Social`):
  - Constants: `HEROES`, `BDAY`, `SIG`, `SIG_NAME`, `SIG_TILE`, `CAKE`, `OUTFITS`, `CHAT_OUTFITS`.
  - Loaders: `chat_file`, `threads`, `stickers`, `reactions`, `feed`, `meta`, `birthday`.
  - Merge helpers: `with_stickers`, `with_reactions`, `with_feed` (each returns a cached copy; the base data is never changed).
  - Other helpers: `rit_lines`, `rit_all`, `away_body`, `sig_icon`, `cake`, `portrait`, `sticker_path`, `auth_nicks`, `auth_greet`.
  - Checks: `problems(strict_art=true)` and `volumes()`.
- `/home/user/tile-waifu/game/scripts/v10/wave1/w1_social_lines.gd` (`V10W1SocialLines`):
  - `RIT`: same shape as `V10RitLines.L`.
  - `AWAY_BODY`, `AUTH_NICKS`, `AUTH_GREET`.
- Chat data in `/home/user/tile-waifu/game/scripts/v10/wave1/data/w1_chat/`:
  - `src/<hero>.chat` ×5: the chat lane's DSL.
  - `threads_<hero>.json` ×5: compiled output.
  - `stickers.json`, `reactions.json`, `feed.json`, `meta.json`.
- Build: the one-liner is in the header of `w1_social.gd`. It imports `build_chat.parse` unchanged. The script I used is `/tmp/claude-0/-home-user/a87f03f9-e6ed-50fa-86f7-4bae7fb623cc/scratchpad/social/build_w1_chat.py` (run `python3 <it> /home/user/tile-waifu`).

### Consumers mirrored
- `V10RitLines.L`: all 18 groups, with the same line count per group as a founder; 36 lines per goddess.
- Other rituals: `V10Comeback.AWAY_BODY`, plus `V10BdayData` `SIG`/`SIG_NAME`/`CAKE`.
- Chat: thread JSON, `stickers.json`, `reactions.json`, `feed.json`, `meta.json`, all checked against every `V10ChatValidate` rule.
- Sign-in: `V10AuthNicks.IDEAS` and `V10AuthText.GREET`.
- Data already present needs no change: `V10BdayData.DATES` has all five birthdays, and `V10RitBridge.GEN` has all five genitives.

### Volume per goddess (founders: about 91–106 messages, 28–30 pills, 5–7 photos)

| | Threads | Messages | Pills | Photos | Stickers in threads | Voice | Feed posts |
|---|---|---|---|---|---|---|---|
| Цубамэ | 14 | 108 | 29 | 6 | 8 | 1 | 4 |
| Миэль | 14 | 98 | 29 | 6 | 10 | 1 | 4 |
| Кохаку | 14 | 106 | 28 | 6 | 10 | 1 | 4 |
| Ширин | 14 | 99 | 28 | 5 | 8 | 1 | 4 |
| Злата | 14 | 96 | 28 | 7 | 8 | 1 | 4 |

- Every goddess also has an 8-sticker set (2 open at Симпатия 5), 22 reaction lines, 36 ritual lines, 8 nick ideas and 3 greetings.
- Each has 14 threads: 7 daily (levels 1–7), plus `first_win`, `combo_record`, `rank_up`, `comeback` (repeat 30), `birthday` (repeat 300), and two outfit threads.
- Outfit threads: `tb_post`/`tb_crimson`, `me_parlor`/`me_gala`, `ko_matsuri`/`ko_kyubi`, `sh_oasis`/`sh_night`, `zl_fair`/`zl_ember`.
- Photos point to `v10/wave1/outfits/*` and `v10/wave1/poses/*`. Vow outfits are never used as photos.

### HOOKS (exact code, each behind `V10Wave1.released()`)

**`chat/chat_data.gd`**
```gdscript
static func heroes() -> Array:
	return HEROES + V10W1Social.HEROES if V10Wave1.released() else HEROES
# hero_file(hero), first lines:
	if hero in V10W1Social.HEROES:
		return V10W1Social.chat_file(hero) if V10Wave1.released() else {}
# all_threads() and sticker(id): `for h in HEROES:` → `for h in heroes():`
# stickers():  var base: Dictionary = d if d is Dictionary else {}
#              return V10W1Social.with_stickers(base) if V10Wave1.released() else base
# reactions(): same pattern with V10W1Social.with_reactions(base)
# feed():      var posts: Array = d.get("posts", []) if d is Dictionary else []
#              return V10W1Social.with_feed(posts) if V10Wave1.released() else posts
# birthday(hero), first line:
	if hero in V10W1Social.HEROES:
		return V10W1Social.birthday(hero) if V10Wave1.released() else ""
```

**`chat/chat.gd`:** replace `D.HEROES` with `D.heroes()` in `tick` (line 280), `_pick_daily` (331) and `stickers_for` (518).

**`chat/chat_validate.gd` `_feed()`:** in the membership checks `if not h in D.HEROES` and `if not str(c.get("hero","")) in D.HEROES`, use `D.heroes()`. Keep the per-hero ≥3 loop on `D.HEROES`. Without this, `V10ChatValidate` reports wave-1 posts as "unknown hero" once released.

**`phone/phone.gd`**
- In `owned()` (line 128) and `ctx()` (line 137), replace `D.HEROES` with `D.heroes()`.
- `sticker_path(id)`: `var p := STICKER_DIR + id + ".webp"` then `if not ResourceLoader.exists(p) and V10Wave1.released(): return V10W1Social.sticker_path(id)`.

**`phone/sticker_tray.gd`:** in `_packs()` (line 55), replace `D.HEROES` with `D.heroes()`.

**`rituals/rit_lines.gd` `pick()`:** after `var arr: Array = g.get(h, g.get("mc", [""]))`:
```gdscript
	if not g.has(h) and V10Wave1.released() and not V10W1Social.rit_lines(group, h).is_empty():
		arr = V10W1Social.rit_lines(group, h)
```
- Optional, in `all()`: `if V10Wave1.released(): out.append_array(V10W1Social.rit_all())`.

**`rituals/comeback.gd`, line 195:**
`"body": AWAY_BODY.get(h, V10W1Social.away_body(h, AWAY_BODY.mc) if V10Wave1.released() else AWAY_BODY.mc)`

**`rituals/bday.gd`**
```gdscript
static func sig_icon(h: String) -> String:
	if not V10BdayData.SIG.has(h) and V10Wave1.released():
		return V10W1Social.sig_icon(h)
	return str(V10BdayData.SIG.get(h, ""))
# cake_icon(h):
	var c: String = V10BdayData.CAKE.get(h, V10W1Social.cake(h) if V10Wave1.released() else "cake_tier")
	return "res://assets/v10/rituals/%s.webp" % c
```

**`rituals/ui/bday_cake.gd`, line 178:** the same `CAKE.get(h, V10W1Social.cake(h) if V10Wave1.released() else "cake_tier")`.

**`rituals/rit_bridge.gd` `portrait(h)`**
```gdscript
	var p := "res://assets/hero/%s.png" % h
	if not ResourceLoader.exists(p) and V10Wave1.released():
		p = V10W1Social.portrait(h)
	return load(p) if p != "" and ResourceLoader.exists(p) else null
```
`hero_name`, `color` and genitive already resolve through `G.HEROES` and `GEN`. Birthdays stay off until release because `V10Bday` only uses `G.HEROES`.

**`auth/auth_nicks.gd`, line 38**
```gdscript
		var arr: Array = IDEAS.get(h, V10W1Social.auth_nicks(h) if V10Wave1.released() else [])
		if arr.is_empty(): arr = IDEAS.mc
```
This is a real crash fix: `arr[randi_range(0,-1)]` fails as soon as any heroine without ideas enters `G.HERO_ORDER`.

**`auth/auth_text.gd` `greet()`:** `var arr: Array = GREET.get(hero, V10W1Social.auth_greet(hero) if V10Wave1.released() and not V10W1Social.auth_greet(hero).is_empty() else GREET.mc)`

**Selftest:** `--wave1_selftest` should `check(V10W1Social.problems().is_empty())` and print `V10W1Social.volumes()`.

### Self-checks inside `problems()`
- **Lint:** `V10Lint.BANNED` plus the stricter `V10ChatData.BANNED` red-line stems over all 1,197 texts.
- **Ritual groups:** the same groups and counts as a founder.
- **Gendered past tense:** no gendered past tense about the player (the rituals selftest list).
- **Weekly letter:** week lines avoid the `V10WeekLetter` black list («ноч», «проигр»…).
- **Tokens:** milestone lines have `{n}`; player birthday lines have `{voc}`.
- **Birthdays:** they equal `V10BdayData.DATES` (Р6) and `meta.json`, and `V10BdayData.problems()` is empty.
- **Genitive / letters / cakes:** each goddess has a `GEN` entry (checked when `G` is present), an `AWAY_BODY` letter and existing cake art.
- **Sign-in:** 8 nicks of 3–16 characters each, and 3 greetings with exactly one `%s`.
- **Chat rules:** the full `V10ChatValidate` rule set (worst-case token lengths in both genders, graph, 4–16 messages, ≤5 affection, triggers, repeat ≥28, sticker ownership and levels, outfit ownership, photo exists and is sfw), plus founder volume floors.
- **Feed:** captions and pills carry no tokens, because `feed_view` shows them raw.

### Gaps for the art lane (not generated, out of my lane)
- **Birthday emblems:** `res://assets/v10/wave1/rituals/sig_<hero>.webp` (192 px, gold medallion like `sig_mc`). Until they exist, `sig_icon()` returns "" and the 24-pair birthday goal does not run for wave 1. Birthday letters, the cake scene and chats still work. The plain tile face can't stand in for the emblem: when that tile is in the deal, two kinds would look identical.
- **Sticker art:** `res://assets/v10/wave1/stickers/<id>.webp` (40 ids in `stickers.json`). Until then the phone draws glyph + label.

### Note outside my files
`V10NotifyText` «У {name} сегодня праздник» gives «У Злата». Hana and Nova already have the same problem. The fix is to use `V10RitBridge.gen_name(h)` for that line.
