# art-ui (UI kit U1) picks

Style: owner UI mock-ups (design/refs/owner_ui): thin gold monoline icons on dark plum lacquer, rose-pink accent; currencies as gold-rimmed jewel icons; ornaments in plum lacquer + gold hairline.
Generated with gpt_image_2_6, `background: transparent` (native alpha, no remove_background needed); prompts in `tools/art/ui_kit_prompts.py` / the sandbox builder (see commit), NOT the batch JSON wording.

- `icons_*/`: 512 px PNG with alpha (1024 originals stay in scratch). `ornaments/`: bbox-trimmed PNG with alpha, max 768 px. `covers/`: 2336x1744 JPG q92 (no characters, empty lower third for the title; `*_hero` = same mode with Mahjong-chan / Yue / Nova).
- `candidates/`: every generated candidate as small JPG (icons on plum, 384 px; covers 1168 px).
- `picks.json`: pick -> source candidate; contact sheets: `contact_sheet*.jpg`.
- No text, letters or numerals in any frame (visual check on every pick). Icons carry a baked soft glow in their alpha edge.
