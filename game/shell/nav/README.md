# shell/nav - screen skeleton (P23 / WP8a)

New files only; **nothing routes the live game through them yet** (main.gd / the v10 `main.go` are untouched, project.godot is untouched).

| file | class | role |
| --- | --- | --- |
| `screen_spec.gd` | `ScreenSpec` (Resource) | the one declaration of a screen: id, scene/script, tab, chrome flags, unlock rule ref, back target, tut ids, analytics name, keep_history |
| `tw_screen.gd` | `TWScreen` (Control) | base class: `enter(params)`, `intro() -> Signal`, `intro_forced()`, `on_back()`, `can_back()`, `exit()`; gets a typed `ctx` + its `spec` instead of `main` |
| `tw_screens.gd` | `TWScreens` (Node) | manager: IDLE/TRANSITIONING state machine, **3 s watchdog**, history, tabs, registry by `scan()`, single back handler |
| `../tw_context.gd` | `TWContext` | typed `state / clock / bus / screens` + a closed service table (`wallet audio assets modals ...`) |
| `../tw_bus.gd` | `TWBus` | shell side of the event contract: subscribe by event kind, ordered synchronous `publish_all(core_events)`, no re-entrancy |
| `nav_fake_screen.gd` | `TWNavFakeScreen` | test double (hang / late intro, block / consume back); the only TWScreen allowed outside `shell/screens/` |
| `nav_selftest*.gd/.tscn` | `TWNavSelftest` | `TWNAV_SELFTEST ok/total` (suite `twnav`) |

## A screen = a folder

```
game/shell/screens/<name>/spec.tres     ScreenSpec (id, script_path | scene, tab, ...)
game/shell/screens/<name>/screen.gd     extends TWScreen
```

`TWScreens.scan("res://shell/screens")` registers every folder that has a valid `spec.tres`. A folder with `screen.gd` and no
`spec.tres` is refused (`SCREEN_HAS_SPEC`); `tools/lint_screen_has_spec.py` (suite `screen_has_spec`) makes the same cases red in CI,
plus bad/duplicate specs and any `extends TWScreen` outside `shell/screens/` (fixtures in `game/tests/fixtures/screens/` are the
negative samples of the runtime scan test).

## Contract highlights

* `go(id, params, opts) -> Signal` (`done(ok, reason)`), emitted on a *later* idle frame even for an instant move, so `await screens.go(..)` never hangs. Refusals: `unknown | locked | busy | instantiate`.
* TRANSITIONING lasts until the new screen's `intro()` Signal fires; `WATCHDOG_MS = 3000` force-finishes (`intro_forced()`, `watchdog_fired`, IDLE). Measured on the fake clock (exact 3.000 s) and in real time (3.001 s, limit 3.0 +- 0.2).
* `back()` order: top modal (`modals.handle_back()`), `screen.on_back()`, `screen.can_back()`, history, `spec.back_target`, `exit_requested`.
* History: transient screens (`keep_history = false`) and same-id refreshes are not pushed; tab roots clear it; cap 32. `go_tab(tab)` returns to the remembered screen of the tab.
* `modals` is duck-typed (`clear_all(reason)` before each mount, `handle_back() -> bool`): the ModalStack lane plugs in without a change here.

## Integrator notes (project.godot is not touched here)

* Autoloads are still 11 (limit at this stage: 11 + 1). `TWScreens` is a `class_name`, so it cannot also be an autoload *named* `TWScreens` (Godot: "hides an autoload singleton"). Wire it as one instance owned by the v11 root (`TWContext.screens`), or autoload it as `Screens`.
* `TWBus` and `TWContext` are plain RefCounted objects held by the root; nothing needs an autoload.
* Core never imports any of this (CORE_PURITY); the shell hands `ctx.bus.publish_all(events)` the lists core commands return.
