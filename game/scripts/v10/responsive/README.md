# 0.10 M0 «responsive» — every screen on every phone and tablet

Owner's note: «нет оптимизации на все экраны, где-то начало игры сжато выглядит». The squashed start was the
Маджонг-тян lobby video at home (the first screen after the intro): a 720×1280 clip drawn with `expand` into the
whole screen, i.e. pulled 25 % taller on 9:20 phones (she looked thin and squashed) and 33 % wider on tablets.

## How the game fits a screen now

* `project.godot`: stretch `canvas_items` + aspect `expand` on a 720×1280 base (unchanged — it was already right):
  phones taller than 9:16 keep width 720 and get a taller viewport (1080×2400 → 720×1600), tablets keep height
  1280 and get a wider one (1536×2048 → 960×1280, 1600×2560 → 800×1280).
* **Content column** (`V10Layout.content_rect`, `main.CR`): every screen is built in a column ≤ 720 px wide,
  centred, between the safe insets. All screens were designed for 720 wide, so on tablets they look exactly as
  designed, centred, with nothing stretched.
* **Bleed**: backgrounds, vignettes, dims and full-width bands reach the real viewport edges past the column
  (`Common.backdrop`, `Common.vignette`, `Common.floor_fade`, `Common.edge_shade`, `V8ProfileUI.backdrop`,
  `V7RoomScene.backdrop` do it by themselves; `V10Layout.bleed_rect(ctrl)` / `V10Layout.bleed_x(node)` for
  anything else). Art is always drawn «cover» with its aspect kept (`blurbg.gdshader`, `V10Layout.cover_rect`).
* **Chrome on the edges**: the top bar sits below the camera cut-out (`main.safe_top`), the nav bar above the
  gesture inset (`main.safe_bottom`); their plates span the viewport, the five tabs keep phone spacing (≤ 820)
  in the middle on tablets. `V8Header` spans the viewport too (back / help at the real edges).
* **Safe areas**: `V10Layout.safe_insets()` reads `DisplayServer.get_display_safe_area()` on mobile (the APK draws
  edge to edge in immersive mode: `EdgeToEdge.enable` + `LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES`, so the
  camera hole is inside our viewport). Desktop / xvfb: none, unless `--safe=T,B[,L,R]` (window px) simulates one.
* **Viewport points vs screen points.** A screen's origin is the column's corner, not the viewport's (tablets: x 120
  / 40; phones with a cut-out: y = the inset). Tile canvas positions, `TrayBoard.matched` / `special` points, input
  events and `get_global_rect()` are viewport points: anything drawn in a screen (or its fx layer) at such a point
  goes through `V10Layout.local_of(node, p)`, and a screen point handed to main (`fly_gems`) or to the board
  (`slot_pos`) through `V10Layout.to_canvas(node, p)`. `play.gd` converts the `matched` point once before
  `_on_match` (so overrides and `V7Combo`, `V6HeroStage.absorb`, `_shift_serve` get screen points); `V9UltCast` keeps
  its aim / fx layers in viewport coordinates (`_canvas_space`) and takes the board rect there (`_br()`).
* **Tall phones** use the extra height instead of leaving dead bands: the title logo block moves down, the summon
  lantern stage moves into the middle (`summon.gd stage_dy`), the victory bust grows (`play.gd`), lists simply
  show more rows; the lobby video is cropped («cover», focus on her face/chest) instead of stretched.

## Files

| file | what |
|---|---|
| `scripts/v10/responsive/layout.gd` | `class_name V10Layout`: `content_rect`, `safe_insets`, `bleed_rect`, `bleed_margins`, `bleed_x`, `cover_rect`, `contain_rect`, `is_wide`, `is_tall`, `px_scale`, `dump` |
| `scripts/v10/responsive/layout_shots.gd` | `class_name V10LayoutShots`: the screenshot runner + layout lint + `--layout_selftest=1` |
| `scripts/v10/responsive/layout_shots.sh` | all target resolutions in a row (one Godot run each, under `flock /tmp/tw-godot.lock`), then contact sheets |
| `scripts/v10/responsive/sheet.py` | one JPEG per view with every resolution side by side (`<out>/sheets/<view>.jpg`) |

Edited outside this dir (allowed for this lane): `main.gd` (column, insets, title, nav, toasts, runner flag),
`screens/common.gd` (bleeding backdrop / vignette / floor fade / edge shade), `screens/home.gd` (outfit painting bleeds on tablets), `screens/summon.gd` (stage on tall
phones, bleeding night dim + flash), `screens/levels.gd` (map plate + mirrored side panels on tablets),
`screens/play.gd` (result dim bleeds, bust grows on tall phones), `v06/story/story_scene.gd` (insets, ≤ 820 box),
`v07/room/room.gd` + `room_scene.gd` (bleed), `v07/album/album_view.gd` (column + insets, modal sides),
`v08/hud/header.gd` (spans the viewport), `v08/profile/profile_ui.gd` (bleed), `v09/home/live.gd` (lobby video
«cover» + tap mapping through the video rect; hearts, «+5 ♥» and her bubble in home coordinates), `v09/ult/cutin.gd`
(strip and dim reach the edges), `v07/room/room_scene.gd` (date scene: insets, ≤ 820 box, like the story).
Viewport point → screen point fixes (review): `screens/play.gd` (tray `slot_pos`, `matched`, 1-1 finger),
`v09/ult/ult_cast.gd` (aim / beam / marks, strip), `v06/special/specials.gd`, `v07/integrator/combo.gd`,
`v07/passives/passive_run.gd`, `v06/heroines/hero_stage.gd` + `duel.gd`, `v06/modes/mode_play.gd`,
`v07/room/room.gd`, `screens/collection.gd`, `screens/home.gd`, `screens/shop.gd`, `screens/levels.gd` (drag band),
`v07/album/album_view.gd`, `v07/event/event_screen.gd`.

## Runner

```
# one resolution (any WxH), all views, lint; exits 0 on «LAYOUT OK»
xvfb-run -a godot --path game --rendering-driver opengl3 --audio-driver Dummy --resolution 1080x2400 -- \
  --layout_shots=/abs/out --save=user://layout_shots_save.json --save_wipe=1 --story_off=1 \
  [--safe=110,0 --notch=1] [--layout_only=home,shop,victory] [--layout_dump=1] [--layout_fx=min]
# every target resolution + sheets (720x1280 1080x1920 1080x2340@110,0 1080x2400 1216x2688 1440x3200@150,60 1536x2048 1600x2560)
bash game/scripts/v10/responsive/layout_shots.sh /abs/out [WxH[@T,B] ...]
# math + live placement check
xvfb-run -a godot --path game ... --resolution 1536x2048 -- --layout_selftest=1 --save=user://layout_shots_save.json --save_wipe=1
```

Views: `title_fresh`, `card` (player card), `title`, `intro` (story), `room_scene` (date scene), `home` (lobby video),
`home_outfit` (SSR painting), `settings`, `tasks`, `visits`, `calendar`, `album`, `home_say` (her line on the lobby
video), `home_outfit_say`, `profile`, `levels`, `tutorial` (1-1), `play`, `cutin` (SSR ult), `play_match` (a tile
into the tray, then its pair), `victory`, `summon`, `pull_lantern`, `pull_reveal`, `collection`, `shop`, `shop_gems`,
`modes`, `climb`, `etude`, `blitz`, `duel`, `room`, `event`, `tourney`, `tourney_week`, `tourney_play`, `letters` (38).
Lint: `LAYOUT WARN <view>: <node> leaves the viewport | centre under the cut-out | centre in the bottom inset`
for every visible tap target (JButton / tap-stop Control) outside scroll lists and hand-scrolled maps.
Probes (`LAYOUT PROBE … ok` or `LAYOUT WARN`): the tray tile lands on its slot and the match ring sits on the pair
(`play_match`), the 1-1 finger points at its tile (`tutorial`), her speech bubble keeps off her eyes (`home_say`,
`home_outfit_say`). They catch a viewport point drawn as a screen point (off by the column's offset); run them on a
tablet and with `--safe=` to see it.
`--layout_selftest=1`: V10Layout math at every listed resolution + the live column, chrome and
`local_of` / `to_canvas` round trip (`LAYOUT_SELFTEST 174/174` with this list).

## Rules for new screens (hooks for the other 0.10 lanes)

1. Build in `size` (the column), never `main.W/H` or `get_viewport_rect()` for content. `main.CR` is the column
   in viewport coordinates, `main.safe_top/safe_bottom` the insets.
2. Full-screen art: `Common.backdrop(self, bg, size, …)` / `Common.vignette(self, size, …)` — they bleed.
   A full-width band / dim of your own: `V10Layout.bleed_x(node)` (horizontal) or position it at
   `V10Layout.bleed_rect(self)`.
3. Anything added straight to `main` or `main.overlay` (full-viewport layers: story, cut-ins, modal views) must
   keep its top UI below `V10Layout.safe_insets(vs).top` and bottom UI above `.bottom`; a modal that should look
   like a screen can take `main.CR` as its rect (see `V7AlbumView.open`).
4. Heroine art / video: never `STRETCH_SCALE` or `expand` into a rect of another aspect — `V10Layout.cover_rect`
   or `contain_rect` (keep aspect), or `Common.card_art` / `blurbg.gdshader` (cover in the shader).
5. A viewport point (tile canvas position, board signal, input event, `get_global_rect()`) drawn in a screen goes
   through `V10Layout.local_of(layer, p)`; a screen point handed to main or the board through `V10Layout.to_canvas`.
   Never assume the screen sits at (0, 0).
6. Add a new screen to `V10LayoutShots._screens()` (one line: view name, screen id, args) so the runner shoots it
   at every resolution. V10Registry (spec §2.8) can call `V10LayoutShots` with its list later.

## Known limits

* Tablets: the column is 720 wide by design; the side bands show the bled background (on the Path map: dimmed
  mirror copies of the panel). A real tablet layout (two columns, bigger heroine) would be a later pass.
* `--safe=` simulates insets in window px; the real Android values come from `get_display_safe_area()` and were
  not measured on a device in this lane (no device here) — check on the RedMagic / a punch-hole phone.
