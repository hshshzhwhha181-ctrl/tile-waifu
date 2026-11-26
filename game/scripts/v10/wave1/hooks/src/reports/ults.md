ULTS lane 4: done. I wrote one repo file, `/home/user/tile-waifu/game/scripts/v10/wave1/w1_ults.gd` (class_name V10W1Ults, extends RefCounted, about 60 KB). Godot also made `w1_ults.gd.uid` next to it on import. I changed no other repo file and ran no git command that changes state. `docs/STYLE_SYSTEM.md` shows as modified in git, but that was not me.

## What the file holds
- **Five cores, each worth 1 pair-equivalent.** Ranked cores are also exactly 1.0, plus at most one small extra:
  - Цубамэ «Теневой шаг»: removes a pair, preferring a pair pinned by tiles on both sides.
  - Миэль «Печенье-джокер»: puts a cookie in the tray. The next tile you play leaves together with its twin on the table. With an empty tray she removes 1 pair instead.
  - Кохаку «Лисий оберег»: hangs a charm on the tray. When the tray overflows, the oldest tray tile leaves with its twin and the player does not lose. Unranked it also highlights a pair; ranked it does not.
  - Ширин «Танец монет»: removes 1 pair and lights the fever. Ranked, she instead adds 0.06 to the fever charge.
  - Злата «Огненный шлейф»: removes a pair and melts the ice on its line. Ranked, she melts 1 ice.
  - Every removal is a `from_ult` pair, so it does not charge the ult or combo. The cookie and charm work through `tray_changed` (emitted before the overflow check) and always take a tile together with its twin, so the board stays solvable.
- **18 outfit entries in V9Ults' exact schema:** name, 2–3 lines, palette (main colour = the heroine's colour, an accent, a dark ink), ref_img (`res://assets/v10/wave1/outfits/<id>.webp`), mod, sfx, fx, desc, particles, motif. The bases have no modifier; no goddess repeats a modifier; every sfx file exists; every fx is unique. Rarities are in `RAR` and the vows (ko_vow, zl_vow) are in `VOWS`.
- **face_rect / alt_rect** are loaded once, at runtime, from `game/scripts/v10/wave1/data/w1_art_cards.json` and scaled from 850×1280 to the game's 859×1280 art size. The face stays square, clamped to 180–480 px. If a file or entry is missing, the loader returns a centred default rect and marks it as not measured. sh_sun's art and rects are now present.
- **Triples version, per heroine** (`TRIPLES_EFFECT` / `TRIPLES_DESC` / `triples_core`): one triple each, preferring the tray. Кохаку instead returns 2 tray tiles to the table, or takes a triple when the tray is empty.
- **Mirrored API:**
  - from V9Ults: `has`, `get_ult`, `core(hero, ranked)`, `mod`, `shown(id, modest)`, `base`, `is_base`, `is_hero`, `ids`, `outfits_of`, `rar`
  - from V9UltCast: `cast_pairs`, `cast_blocked`, `cast_auto_pick`, `cast_apply`, plus `cast_expect`, `joker_on` and `charm_on` for the selftest
  - from V10MjTriplesUlts: `triples_core`
  - V9Cutin palette and flash rules, `V10KitData.PARTICLES` and `V10Lint.BANNED` are reused as they are
- **No bare autoload names.** G and Sfx are reached through the scene tree, so the file compiles without autoloads.

## Hooks for the integrator (exact code)
The full diff is in `/tmp/claude-0/-home-user/a87f03f9-e6ed-50fa-86f7-4bae7fb623cc/scratchpad/ults/difftree/w1_ults_hooks.diff`. The ult_cast hooks need no release gate: `is_hero` is false for the founders, and a wave-1 heroine can only be the partner once she is released.

**`game/scripts/v09/core/ults.gd`**
```
static func has(id: String) -> bool:
	return ULTS.has(id) or (V10Wave1.released() and V10W1Ults.has(id))  # wave-1 hook

static func get_ult(id: String) -> Dictionary:
	if not ULTS.has(id) and V10Wave1.released() and V10W1Ults.has(id):  # wave-1 hook
		return V10W1Ults.get_ult(id)
	return ULTS.get(id, {})

# for_hero:
	if id != "" and has(id):  # wave-1 hook (was ULTS.has)
		return id
	if V10Wave1.released() and V10W1Ults.is_hero(hero):  # wave-1 hook
		return V10W1Ults.base(hero)
	return String(BASE.get(hero, "o_base"))

# shown(), first lines:
	if not ULTS.has(id) and V10Wave1.released() and V10W1Ults.has(id):  # wave-1 hook: wave-1 art dir + JSON rects
		return V10W1Ults.shown(id, modest)

# clip_art, redraw branch:
		var uh: = String(u.get("hero", "mc"))
		var sh: = shown(V10W1Ults.base(uh) if V10W1Ults.is_hero(uh) else String(BASE.get(uh, "o_base")), modest)  # wave-1 hook

# core(), first lines:
	if not CORES.has(hero) and V10Wave1.released() and V10W1Ults.is_hero(hero):  # wave-1 hook
		return V10W1Ults.core(hero, ranked)

# start_charge_for:
	return start_charge(String(it.get("rar", V10W1Ults.RAR.get(id, "R"))), ranked, id in G.BASE_OUTFITS or V10W1Ults.is_base(id))  # wave-1 hook
```

**`game/scripts/v09/ult/ult_cast.gd`**
```
# pairs(): bind the existing filter result to `var ps: Array = bd._pairs_on_board().filter(...unchanged...)`, then
	return V10W1Ults.cast_pairs(self, ps) if V10W1Ults.is_hero(hero) else ps  # wave-1 hook: Цубамэ's targets

# blocked(), after `if bd == null: return "…"`:
	if V10W1Ults.is_hero(hero):  # wave-1 hook
		return V10W1Ults.cast_blocked(self)

# auto_pick(), first lines:
	if V10W1Ults.is_hero(hero):  # wave-1 hook
		return V10W1Ults.cast_auto_pick(self)

# _apply(), new match arm before `_:`:
		"tsubame", "miel", "kohaku", "shirin", "zlata":  # wave-1 hook: her core on the strong beat
			V10W1Ults.cast_apply(self, pick, col)
```

**`game/scripts/v10/mj/triples/ults_triples.gd`**, `core()` first lines:
```
	if not EFFECT.has(hero) and V10Wave1.released() and V10W1Ults.is_hero(hero):  # wave-1 hook
		return V10W1Ults.triples_core(hero)
```

**Optional, `game/scripts/v09/ult/ult_selftest.gd`**
```
		"tsubame", "miel", "kohaku", "shirin", "zlata":  # wave-1 hook: a cookie / a charm removes nothing at once
			want_pairs = V10W1Ults.cast_expect(hero, ranked, tray0 == 0)
# skip check:
		_check("skip: effect still applied", hero in ["rin", "yue"] or box[0] > 0 or V10W1Ults.joker_on(bd) or V10W1Ults.charm_on(bd), "%d" % box[0])  # wave-1 hook
```

## Checks
- **Parse in Godot:** `--check-only` cannot compile w1_ults on its own, because its dependencies (ults.gd, ult_cast.gd, tile.gd, cutin.gd, feel.gd, fx.gd) use the G autoload, which check-only mode does not register. Founder `ults.gd` fails the same way. Loaded in the real game it compiles with no errors.
- **Live probe:** 75 ok, 0 fails, against the newest art cards. It boots `main.tscn`, works on copies of the files with the hooks applied, and checks:
  - founders are unchanged through the hooks
  - every wave-1 query
  - ranked PE = 1.0
  - triples plans keep tile counts in threes
  - a live cast on the play screen for all five heroines
  - no loss during the whole probe

  One earlier run failed 2–3 Кохаку checks only because the probe ran out of free tiles on the random board. I fixed the probe's tile picker and the next run was clean.
- **Data satisfies these ults_selftest rules:**
  - ids unique; one base per heroine; base rarity = heroine rarity
  - mods from `V9Ults.MODS`, bases have none, none repeated per heroine
  - names and lines in Cyrillic and within length limits; palette main = heroine colour
  - flash colour never white (s≥0.45, v≤0.7); ink luminance below 0.3
  - sfx exists; core desc ≤45 characters with a valid target; pairs = 1
- **BANNED grep:** the only hit is a code comment (line 1111) naming «бесплатн». No heroine text hits, and `problems()` also enforces the red lines.

**New checks for the wave-1 selftest:**
- Call `V10W1Ults.problems(true)` and require it to be empty.
- Run the live ult selftest with the hooks, using `cast_expect`.

`problems(true)` currently reports 23 items, all waiting on integration: 18 outfits missing from G.ITEM and 5 heroines missing from G.HEROES.

## Integration notes
- **Core agent** must add G.ITEM entries for all 18 outfits (img = outfit id, rar from `V10W1Ults.RAR`, vows nogacha) and G.HEROES colours equal to `V10W1Ults.HERO_COLOR`.
- **V9UltsSelftest** loops over all of `G.HERO_ORDER` and expects founder data only (BASE, CORES, ref_img under `res://assets/outfits`). Run it with wave-1 off, or limit it to the keys of `V9Ults.BASE`.
- **Play agent:** levels.gd:925/927 and play.gd:1402 read `G.SKILLS[h]` directly, so the five heroines need G.SKILLS entries.
- `ko_kyubi.webp` was briefly 0 bytes while the art agent rewrote it; it is 201 KB now.
- **Environment:** this session's setup script failed when the container was built (exit 127, "line 4: permissions:: command not found"). Line 4 of the script looks like settings text pasted into it by mistake and needs fixing in the environment settings. I did not change the environment from this sub-agent; Godot works here.

My probe tooling is in `/tmp/claude-0/-home-user/a87f03f9-e6ed-50fa-86f7-4bae7fb623cc/scratchpad/ults/` (`probe.gd`, `boot.gd`, `hooks.py`, `run2.sh`, latest log `run5.log`).