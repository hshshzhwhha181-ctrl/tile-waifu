# game/core — UI-free logic

Everything here is `RefCounted`/`Resource`/static code with no scene-tree or presentation dependency (rules, data tables, economy, gacha, meta, save helpers,
mode engines, bots, text data). The shell (`game/scripts`) may depend on core, never the reverse. Moved mechanically from `game/scripts` in WP3; see
`tools/move_map.tsv` (every move), `tools/check_move_map.py` (proof it was mechanical) and `tools/lint_core_purity.py` (report-only purity lint; the remaining
`G.` / Node-API / shell-class references are the to-do list for the state/facade work package).

Layout: `base/` (registry, money, rank, sku), `modes/<mode>/` (riichi, sanma, koikoi, triples, classic, connect, cube, garden, bridge, palm, tower, duels, adventure),
`economy/ gacha/ levels/ meta/ shop/ rituals/ salon/ phone/ chat/ auth/ online/ path/ profile/ tutorial/ look/ wave1/`, and the legacy generations
`v06/ v07/ v08/ v09/` (data tables, ladder, league, recovery, ults, letters, summon rules, riichi v08 engine).
