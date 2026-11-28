# shell/assets - TWAssets registry (P29 / WP9c)

The one door to a runtime asset for the v11 shell. A screen asks for an **id**, never for a path.

```gdscript
var bg: Texture2D   = TWAssets.tex("bg.bg_festival")
var clack: AudioStream = TWAssets.stream("sfx.clack0")
var ult: VideoStream   = TWAssets.video("v10.ult_video.mc_base")
var face: Texture2D    = TWAssets.tex("emotion:miel:happy")      # composite id
var info: Dictionary   = TWAssets.resolve("hero_png:rin")        # {ok, id, path, kind, status, error, message}
```

| file | role |
| --- | --- |
| `tw_assets.gd` | `TWAssets` (static class, **no autoload**: project.godot is untouched): manifest load, `resolve / tex / stream / video / font / res / has`, `ids()`, `composite_ids()`, `audit()`, the status gate, dev placeholders |
| `resolvers/tw_asset_resolver.gd` | `TWAssetResolver` base: `path_of(args)`, `enumerate(paths)` |
| `resolvers/hero_resolvers.gd` | `hero_png`, `outfit`, `emotion`, `pose` (founders + wave-1 split via `V10W1Core`) |
| `resolvers/koikoi_resolvers.gd` | `koikoi_card` (0..47, `back`), `koikoi_skin` (5 heroine light cards, `V10MjKoikoiSkins`) |
| `resolvers/dir_resolvers.gd` | one table of "folder of files addressed by name" families (`rig_layer`, `sticker`, `mj_sfx`, `hudfx_particle`, `voice_wave1`, ...) |
| `assets_selftest*.gd/.tscn` | `TWASSETS_SELFTEST ok/total` (suite `twassets`) |

## Ids

* **direct** - the id of `game/assets/manifest/assets.json` (`tools/assets/gen_manifest.py`): path under `assets/` without extension, `/` -> `.`.
* **composite** - `family:arg[:arg]`, for files a loader reaches by composing a string. A family is a resolver: it maps args to ONE manifest
  record and **enumerates** every id it can produce (`TWAssets.composite_ids()`), so "can this file still be reached?" is a list. A composite that
  expands to a path that is not in the manifest is an error (`NOT_IN_MANIFEST`), never a silent miss.
* To add a family: a `TWAssetResolver` subclass (or a row in `TWDirResolvers.TABLE`), registered in `TWAssets._register_builtin()`; the selftest
  loads every id it enumerates.

## Status gate

| request | release | dev |
| --- | --- | --- |
| approved id | the resource | the resource |
| status generated / pending / rejected | `null`, `push_error`, `problems += NOT_APPROVED` | flagged placeholder (hatch + red "!" badge; silent clip; empty video), `is_placeholder(res)` |
| unknown id / unknown family / bad args / not in manifest / wrong kind / file does not load | `null` + error code | flagged placeholder |

`TWAssets.mode`: `AUTO` (release when the export has the `release` feature or `--assets=release`), `DEV`, `RELEASE`. `TWAssets.problems` is the
QA log (`{id, code, mode, kind}`), `TWAssets.quiet = true` mutes `push_error` in tests.

## Lint

`tools/lint_asset_id_only.py` (`ASSET_ID_ONLY`): `game/shell/**` may not contain a `res://assets/` literal (0, enforcing; this folder and the selftests
are exempt because they are the manifest tooling); the legacy `game/scripts|core` literals are counted per file as a ratchet in
`tools/lint_asset_id_baseline.json` (report mode, may only shrink).

## Not done here (needs the owner / later packages)

* The release export include list generated from the manifest (`tools/assets/export_filter.py` territory) and shipping `assets/manifest/assets.json`
  itself in the .pck (needs an export_presets change; export_presets.cfg is not touched by this package).
* Migrating legacy call sites to ids (they keep working; the ratchet counts them).
