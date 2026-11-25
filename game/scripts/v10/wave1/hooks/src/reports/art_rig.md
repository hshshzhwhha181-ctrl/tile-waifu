The five full-body hero cut-outs and their RIGS measurements are on disk, at the same scale and placement as the founders. Running the pipeline again gives byte-identical files (checked with md5). Godot import is done (exit 0, no errors, run under `flock` with a timeout). No git commands were used.

**Files**
- Cut-outs, 848×1264 RGBA, feet on y 1240, lowest opaque row 1244: `/home/user/tile-waifu/game/assets/v10/wave1/hero/{tsubame,miel,kohaku,shirin,zlata}.png`. I set `mipmaps/generate=true` in their `.import` files to match the founders. Those `.import` files were already there from another agent's import run.
- Rig data: `/home/user/tile-waifu/game/scripts/v10/wave1/data/w1_art_rig.json`, in the brief's format: `{hero: {file, source, source_note, fit, rig, notes}}`. Each `rig` has head_c, head_r, neck, chest_c, chest_r, waist_y, feet, hair_l, hair_r, eye_l, eye_r, mouth, lash (hex), lid_l and lid_r, lid_tilt (all except Zlata, whose eyes are level), face_w, av and zoom_k. All values are arrays or numbers.
- Script: `/home/user/tile-waifu/game/scripts/v10/wave1/tools/w1_art_rig.py`.
- Contact sheet (five next to mc and yue, on #1d1b2e and #f6efe6): `/tmp/claude-0/-home-user/a87f03f9-e6ed-50fa-86f7-4bae7fb623cc/scratchpad/rig/w1_hero_sheet.jpg`. It reads as one cast.
- Debug overlays and blink/talk previews: `/tmp/claude-0/-home-user/a87f03f9-e6ed-50fa-86f7-4bae7fb623cc/scratchpad/rig/debug/<hero>_full.jpg` and `<hero>_face.jpg`.

**Source per heroine.** BiRefNet gave the cleanest cut-outs, so it is the base for all five; isnet-anime is only used on Kohaku's tail.

| hero | source used | why not FINAL |
|---|---|---|
| tsubame | `w1src/tsubame__tb_base__shy.png` | FINAL is cropped at mid-thigh, so there are no feet. The shy slot also matches LW33 (swallow print above the knee, ankle cord). |
| miel | `w1src/miel__me_base__select.png` | FINAL has closed "^^" eyes, so blinking is impossible. Its cream stockings also contradict LW36; the select slot has the caramel thigh-highs. |
| kohaku | `w1src/kohaku__ko_base__shy.png` | In FINAL she rests her arms on a staff that leans on the torii, with one foot up a step; cut out, the arms and foot would hang on nothing. In the shy slot both feet are on one step, with the LW48 bell-bows. |
| shirin | `w1src/FINAL_shirin.png` | — |
| zlata | `w1src/FINAL_zlata.png` | — |

**Clean-up:** only the largest piece of the figure is kept (this drops the roof eave and Miel's music note), the outer 1 px of the edge is trimmed, scene colour is removed from semi-transparent edges, and edges the source frame cuts fade over 6 px.

**Measurements.** Every point was checked on 4–7× face crops, plus a Python copy of the shader's blink and talk.

| hero | face width | talk flap | hair sway |
|---|---|---|---|
| tsubame | 88.6 | off: mouth hidden by her scarf | ponytail + scarf |
| miel | 100.2 | off: open smile, like Hana | none: her skirt frill sits right under the curls |
| kohaku | 101.5 | on | tail on the left, loose strands on the right |
| shirin | 90.5 | on | veil wings below her arms |
| zlata | 84.1 | on | outer feathers of the mantle |

- **Face width** is 1.75 × the distance between the eyes; the founders are 89–96. `face_w` is in the JSON, and `V10W1Core.rig_face_w()` reads it.
- **Blink:** the eyes sample upper-lid skin instead of the blushing cheek. Miel, Kohaku, Shirin and Tsubame have their eye slant set (`lid_tilt`); Zlata's eyes are level.
- **`av`** follows the founders' formula. The round avatars frame the face like mc's and Hana's.
- **`zoom_k`** = 115 / face width. Nothing in the code reads `zoom_k` yet, so I took the reference face size from mc and Hana's own values (95 × 1.25 and 89 × 1.25 ≈ 115).
- **`head_r`** is 135 for Zlata and 118 for Shirin, above the founders' 112–125, so that the kokoshnik and the oil lamp turn with the head.

**Problems left**
- **Tsubame:** her scarf and ponytail fill the left of the canvas, so she stands right of centre (feet x 655). Any consumer that assumes a centred figure must use `feet` and `head_c` from the JSON. Her default look is the blushing shy pose, mouth behind the scarf. The scarf tip fades out because the source frame cuts it.
- **Miel:** her hero sprite now has caramel stockings and red heels, while her card art (FINAL) has cream stockings. The art audit should know.
- **Kohaku:** she is the shortest figure because she leans forward (head centre at y 268; the founders range 130–225). Scaling her up would make her face about 13% bigger than the founders', so I left it. I removed the faint motion-blur trail from her tail tip because it looked like smoke on dark backgrounds.
- **Zlata:** she is limited by canvas width (face 84, the smallest), and the kokoshnik reaches y≈16.
- **Shirin and Zlata:** a fingertip and a feather tip touch the source frame edge; both fade over 6 px and are not noticeable.
- The picked `sh_sun` card is not used here: this lane only covers the base-outfit hero sprites.

**How to re-run**
```
python3 /home/user/tile-waifu/game/scripts/v10/wave1/tools/w1_art_rig.py all [--hero <id>] [--src DIR] [--work DIR]
cd /home/user/tile-waifu/game && timeout 600 flock -w 500 /tmp/tw-godot.lock timeout 300 /opt/tw-tools/godot --headless --path . --import
```
The stages are `masks`, `cut`, `json`, `debug` and `sheet`. By default it reads the sources from the scratchpad `w1src` folder and caches the masks and fit numbers in the scratchpad `rig` folder. The masks need rembg with the birefnet-general and isnet-anime models; the models are already downloaded and the masks are cached. Run birefnet one model at a time: it needs several GB of RAM, and a parallel run was killed for lack of memory. The measured rig values are the `RIG` constant in the script; `json` writes them out with `face_w`, `av` and `zoom_k` worked out from them.