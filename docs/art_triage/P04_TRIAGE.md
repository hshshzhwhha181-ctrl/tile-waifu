# P04: triage of unused Higgsfield assets (30 key arts + 100 backgrounds)

Date 2026-11-28. Read-only: no Higgsfield generation, no credits spent, nothing written under game/. Source: hf-mining catalog (workspace scan 2026-11-27). Machine-readable results: `triage_top30.json`, `triage_bg100.json` in this folder. Candidate previews (640 px) and MANIFEST (status=generated): `assets/incoming/p04_triage/`. Full-size originals stay in the scan folder (hf-mining/files/*) and on Higgsfield by `hf_id`.

## What was audited and how

- **Key-art set (30)** = the 20 unused `heroine_key_art` images + the 10 best-looking unused `heroine_art_edit` hero pieces (Yue, Kohaku, Tsubame, Mahjong-chan, Rin, Shirin, Miel, Zlata, Nova portraits), chosen from contact sheets because the report's own top-30 mixes tile backs, icons and backgrounds.
- **Background set (100)** = all 100 unused images the scan labelled `background`. Honest note: the scan's `background` label is loose. By kind: 26 pure environments (mostly glossy 1024 px vignettes plus 3 full-size empty bgs), 24 scene CGs with heroines, 20 heroine cards (incl. 8 Nova/Tsubame/Yue 2048 pieces), 13 prop vignettes, 12 Hana expression close-ups/sheets, 3 edit variants, 2 UI assets.
- Every image was opened visually at up to 1600 px on the long edge (native for the 1360x2048 and 1024 px files; 1520x2688 and 2688x1520 files were downscaled ~0.6). For 22 of the 30 key arts, hands / feet / legs were additionally cropped at native resolution (list in the JSON `crops_checked`; some crop boxes missed a target region, for example the right hand and feet of 28139660, so those items carry a partial check). 8 key arts (12093d91, 3060bffc, 24b5ac07, 60fc5295, 16bb0b24, 476fd351, 808c5558, 686b2217) and all 100 backgrounds were checked at full-view / sheet scale (2 per screen, ~780 px wide each), NOT with per-hand crops. Anything marked pass for hands in the backgrounds set means "no defect visible at that scale"; a native crop pass is still owed for whichever you actually ship.
- Not automated, no model-based check, no OCR: text defects were judged by eye. Verdicts: `pass` no visible anatomy/text/artifact defect; `cond` usable with a fix or only for the 17+ build; `fail` reject. `rating_class=17plus_only` marks items hitting the HEROINES red-line list (bikini/leotard/wet swimwear/bunny/garter-lace as the focus).

## Result against acceptance

| criterion | required | result |
|---|---|---|
| key arts opened full-size with pass/fail + defect tags | 30 | 30 (pass 22, cond 7, fail 1) |
| backgrounds opened full-size | 100 | 100 (pass 87, cond 12, fail 1) |
| key-art candidates | >= 12 | 22 (19 sfw_ok, 3 17+ only) |
| background candidates | >= 40 | 50 (30 flagged as Tea Room / Salon fit) |
| files only in assets/incoming (status generated), none in game/ | yes | yes |

Caveat on the bar: of the 50 background candidates, 26 are no-character environments (3 at full size, 23 glossy 1024 px); the other 24 are scene CGs with heroines (usable as banners, loading screens, story CGs, or references, not as plain UI backgrounds). The glossy 1024 px vignettes (style: bright semi-real 3D render, not recipe v4) need upscale or a re-render for full-screen use; their value is as composition references.

## Key arts (30)

| id8 | heroine | size | verdict | score | rating | tags | note |
|---|---|---|---|---|---|---|---|
| d29d446f | kohaku | 752x1344 | pass | 8 | 17plus_only | lace_stockings_17plus | Kohaku lounging shrine priestess. Hands (3), both feet/geta crops clean at native 752x1344; lace thigh-high with garter ribbons = 17+ build only; low  |
| 31ee1f9e | tsubame | 752x1344 | pass | 8 | sfw_ok | - | Tsubame moonlit rooftop. Tile hand, rail hand, sleeve crops clean (fishnet sleeve consistent). Feet not visible. 752x1344 native. |
| 6a73cf62 | shirin | 752x1344 | pass | 8 | sfw_ok | - | Shirin reclining desert fortune-teller. Tile hand, both resting hands, both crossed feet w/ anklets clean (toes 5/5). 752x1344 native. Bare midriff/le |
| 5455fbf7 | - | 1520x2688 | cond | 7 | sfw_ok | text_in_image | Salon banner with baked 'Five Winds' lettering (not the game title Tile Waifu) and 5 heroine silhouettes on shoji screen. No people anatomy. Usable on |
| bd6a1c81 | - | 1360x2048 | fail | 6 | 17plus_only | hand_flat, bunny_sfw_ban | Mahjong-chan bunny-bartender: supporting hand flattened (fingers merged into one slab, nails off), bunny costume banned in SFW builds per P-report; he |
| 910c7d6f | - | 1360x2048 | pass | 8 | sfw_ok | open_mouth_laugh | Mahjong-chan Lunar New Year cheongsam, gloved reaching hand shows 5 digits, lantern-hand+cord clean, heel ok. Open-mouth laugh is cheerful not suggest |
| 6ec151d8 | yue | 1360x2048 | cond | 7 | 17plus_only | leotard_17plus_only, swimwear | Yue high-cut leotard/swim pose. Gloved hands read ok (fingers merged slightly), ankle crop ok (toe crop missed). Quality fine but swimsuit/high-cut =  |
| 27a129fc | - | 1360x2048 | pass | 8 | 17plus_only | fishnet_17plus | Nova arcade-cabinet sit, bubble gum. Raised hand 5 digits clean, resting fingerless-glove hand clean, platform boot laces clean. Cleaner SFW than most |
| 3bf37740 | nova | 1360x2048 | pass | 9 | sfw_ok | - | Nova cat-hoodie gaming chair, plush. Fingerless-glove hand holding plush clean; face/eyes clean; other hand hidden. Best SFW-leaning Nova card/banner; |
| 2b04512f | rin | 1360x2048 | pass | 9 | 17plus_only | lace_stockings_17plus | Rin back-view qipao w/ gold glasses, braid. Hand on braid 5 digits clean, hand at skirt clean, heel clean. Lace-top stockings with bows = 17+ build on |
| 27c27ba3 | hana | 1360x2048 | cond | 7 | sfw_ok | hand_chin_awkward | Hana gym knee-hug, soft figure. Gripping hand ok; chin-resting hand merges awkwardly into forearm/shoulder (thumb unclear). Knee-high socks, SFW-frien |
| 946faf74 | hana | 1360x2048 | cond | 6 | 17plus_only | bikini_17plus_only, wet_swimwear | Hana beach kneeling bikini; both hands on thighs have 5 digits, clean. Rating risk per HEROINES red-line report (bikini, wet, kneeling) = 17+ APK/RuSt |
| a4f9983f | hana | 1360x2048 | pass | 9 | sfw_ok | - | Hana sports-festival cheer jump, mahjong-tile pompoms, stadium. Both sneakers clean (laces, soles), pompoms hide hands; crowd is small/blurred. Strong |
| 39da4bd6 | hana | 1360x2048 | pass | 8 | sfw_ok | long_fingers_minor | Hana ring-girl/boxing, belt, wraps. Reaching hand has 5 digits but fingers slightly elongated; salute fist OK; high-top shoe clean. Strong tournament  |
| 89d77fc5 | hana | 1360x2048 | cond | 7 | 17plus_only | wet_swimwear_17plus_only, hand_chin_awkward | Hana lifeguard wet one-piece. Reaching hand 5 digits clean; chin hand awkward (fingers lost in cheek/hair); bare foot on tower step reads 5 toes at fu |
| ce44ea7f | rin | 1360x2048 | pass | 9 | sfw_ok | - | Rin onsen kimono kneeling, tea pour. Teapot hand, cup hand (5 digits, jade bangle), both geta feet clean; best SFW Rin SSR/VIP backdrop; glasses+sage  |
| b2de89bb | nova | 1360x2048 | cond | 7 | sfw_ok | hand_helmet_muddled, noisy_texture | Nova cyber-racer w/ bike in rain. Heels/boots clean; hand gripping helmet reads as a muddled glove bundle (fingers unclear); fairing-leaning hand not  |
| b868b3ae | yue | 1360x2048 | cond | 7 | 17plus_only | swimsuit_17plus_only, wet | Yue night-swim lunar palace (same leotard as 6ec151d8). Both gloved hands 5-finger readable, slightly elongated; legs into water plausible. Rating 17+ |
| 8e0699bc | rin | 1360x2048 | pass | 9 | sfw_ok | - | Rin tea-plantation R costume, glasses-pinch hand (5 digits, natural) and basket hand clean; excellent SFW identity-correct card/tea event banner; sunr |
| 1deb8db4 | rin | 1360x2048 | pass | 9 | sfw_ok | bg_people_blurred | Rin auctioneer SR (gavel, velvet jacket, pencil skirt, pantyhose). Gloved gavel hand and desk hand have 4+thumb readable though blocky; both stilettos |
| 4fa461de | yue | 2048x2048 | pass | 8 | sfw_ok | legs_cropped_frame, stocking_lace | Yue lilac moon-balcony standing, 2048x2048 native. Fan hand 5 digits and hanging hand clean; figure cut off at knee-shin (no feet). Pastel, low contra |
| 28139660 | kohaku | 1360x2048 | pass | 8 | sfw_ok | - | Kohaku on torii stairs, staff behind shoulders. Left hand on staff 4 fingers visible (thumb hidden) fine; feet in platform geta OK at full view; stock |
| 12093d91 | tsubame | 1360x2048 | pass | 8 | sfw_ok | - | Tsubame courier on rooftop at night, swallow on fingertip, sealed letter. Hands readable (index-raise, envelope grip), tabi boots fine at full view; d |
| 3060bffc | mahjong_chan | 1744x2336 | pass | 9 | sfw_ok | - | Mahjong-chan pink qipao in salon (1744x2336). Tile-holding hand 5 digits, table hand clean, jade bangle; legs cropped at knee. Pink-on-pink low contra |
| 24b5ac07 | rin | 1744x2336 | pass | 9 | sfw_ok | - | Rin library tea-cup bust-up (1744x2336). Both hands cradling cup 5 digits readable, glasses/earrings/braid on canon. SFW, excellent Rin salon/phone/di |
| 60fc5295 | shirin | 1360x2048 | pass | 8 | sfw_ok | - | Shirin dancing in tent, arms spread. Hands elegant and readable, anklets, bare feet ok at full view; bg carpet busy but fine. Flat/low contrast render |
| 16bb0b24 | miel | 1360x2048 | pass | 8 | sfw_ok | - | Miel baking, whisk+bowl. Hands fine, one thigh-high lace w/ bows, heels clean; soft sepia haze, lovely cafe/bakery ref. SFW. |
| 476fd351 | zlata | 880x1168 | pass | 8 | sfw_ok | low_res | Zlata phoenix-kokoshnik waist-up on grey, 880x1168 only (below key-art res), hand on hip + hanging hand readable. Usable as ref/portrait, not as banne |
| 808c5558 | nova | 2336x1744 | pass | 9 | sfw_ok | - | Nova bust-up neon room (2336x1744 landscape), chin-rest hand 5 digits clean, cat-ear headphones; excellent dialogue/phone hero. SFW. |
| 686b2217 | - | 1024x1024 | pass | 8 | sfw_ok | open_mouth_minor | Rin library fan portrait (1024x1024). White glove hand 4+thumb readable; slightly parted lips, mildly flirty, not suggestive. Good dialogue portrait. |

## Shortlist for the owner (pick best; M7)

**Tea Room / Salon, SFW, no fixes needed (best first):**

- `b0726543` (2688x1520, pass/9): Festival banner / title wide art
- `57a2bc78` (2688x1520, pass/9): Salon friendship wide CG / hub banner
- `16f5c2ae` (2688x1520, pass/9): Salon / tea shop wide bg (use with/without char)
- `f1b9cedd` (1520x2688, pass/9): Loading screen / rainy tea street (Chaina mood)
- `6c86232f` (1520x2688, pass/9): Salon study / Rin event
- `c0cbba5b` (1520x2688, pass/9): Salon lobby / Chaina victory splash
- `05fd9a16` (1520x2688, pass/9): Salon exterior / Chaina lobby
- `b7ee9bcf` (1024x1024, pass/9): Salon restoration progression bg (before/after)
- `176e0150` (1520x2688, pass/9): Home / Salon night hub bg; Yue chapter
- `7b9afb59` (1520x2688, pass/8): Salon entrance / Chaina door transition bg
- `3bf37740` (1360x2048, pass/9): Nova cat-hoodie gaming chair, plush. Fingerless-glove hand holding plush clean; 
- `1deb8db4` (1360x2048, pass/9): Rin auctioneer SR (gavel, velvet jacket, pencil skirt, pantyhose). Gloved gavel 
- `8e0699bc` (1360x2048, pass/9): Rin tea-plantation R costume, glasses-pinch hand (5 digits, natural) and basket 
- `ce44ea7f` (1360x2048, pass/9): Rin onsen kimono kneeling, tea pour. Teapot hand, cup hand (5 digits, jade bangl
- `3060bffc` (1744x2336, pass/9): Mahjong-chan pink qipao in salon (1744x2336). Tile-holding hand 5 digits, table 
- `24b5ac07` (1744x2336, pass/9): Rin library tea-cup bust-up (1744x2336). Both hands cradling cup 5 digits readab
- `910c7d6f` (1360x2048, pass/8): Mahjong-chan Lunar New Year cheongsam, gloved reaching hand shows 5 digits, lant
- `a4f9983f` (1360x2048, pass/9): Hana sports-festival cheer jump, mahjong-tile pompoms, stadium. Both sneakers cl
- `39da4bd6` (1360x2048, pass/8): Hana ring-girl/boxing, belt, wraps. Reaching hand has 5 digits but fingers sligh
- `2358f677` (1024x1024, pass/9): Home / menu hero bg
- `51c363c1` (1024x1024, pass/9): World-map / Path chapter cover
- `f37ebb22` (1024x1024, pass/9): Boudoir hub bg
- `32a3e162` (1024x1024, pass/9): Wardrobe screen hero
- `f8b752b4` (1024x1024, pass/9): Shop screen hero
- `e201c7de` (1024x1024, pass/9): Phone/messenger screen hero
- `f1972099` (1024x1024, pass/9): Daily reward / chest screen
- `cb47ebbc` (1024x1024, pass/9): Victory / tournament-win screen

Notable standouts: b7ee9bcf is a split before/after Salon entrance (ruined vs restored) that fits a Salon-restoration progression; b0726543 is a 5-heroine yukata festival wide that could be the title/festival banner; 176e0150 and c0ac52ed are clean empty-floor backgrounds with space for UI.

## Rejects and fixes needed

- `5455fbf7` cond: text_in_image: Salon banner with baked 'Five Winds' lettering (not the game title Tile Waifu) and 5 heroine silhouettes on shoji screen. No people anatomy.
- `bd6a1c81` fail: hand_flat, bunny_sfw_ban: Mahjong-chan bunny-bartender: supporting hand flattened (fingers merged into one slab, nails off), bunny costume banned in SFW builds per P-
- `6ec151d8` cond: leotard_17plus_only, swimwear: Yue high-cut leotard/swim pose. Gloved hands read ok (fingers merged slightly), ankle crop ok (toe crop missed). Quality fine but swimsuit/h
- `27c27ba3` cond: hand_chin_awkward: Hana gym knee-hug, soft figure. Gripping hand ok; chin-resting hand merges awkwardly into forearm/shoulder (thumb unclear). Knee-high socks,
- `946faf74` cond: bikini_17plus_only, wet_swimwear: Hana beach kneeling bikini; both hands on thighs have 5 digits, clean. Rating risk per HEROINES red-line report (bikini, wet, kneeling) = 17
- `89d77fc5` cond: wet_swimwear_17plus_only, hand_chin_awkward: Hana lifeguard wet one-piece. Reaching hand 5 digits clean; chin hand awkward (fingers lost in cheek/hair); bare foot on tower step reads 5 
- `b2de89bb` cond: hand_helmet_muddled, noisy_texture: Nova cyber-racer w/ bike in rain. Heels/boots clean; hand gripping helmet reads as a muddled glove bundle (fingers unclear); fairing-leaning
- `b868b3ae` cond: swimsuit_17plus_only, wet: Yue night-swim lunar palace (same leotard as 6ec151d8). Both gloved hands 5-finger readable, slightly elongated; legs into water plausible. 
- `5e4e0e63` fail: glow_halo_artifact, not_a_background: Hana stride pose on black with heavy orange glow halo (edit artifact); hands ok but unusable; test output

Other `cond` backgrounds (card art with 17+ pose, baked frames, foot pose, off-style, glow artifact): see JSON. Items 5e4e0e63 (glow halo edit artifact) fails.

## Red-line / rating notes (from this audit)
- 17+ only: bd6a1c81 (bunny bartender, also hand fails), 6ec151d8 and b868b3ae (Yue leotard / wet swim), 946faf74 (kneeling bikini), 89d77fc5 (wet lifeguard), b36c1c06 and 88c38125 (Nova wet suit / lace fishnets), c31790d7 (Yue garter satin), 96b99139 (Miel counter-lean pose), Hana close-ups 8d030e9b / 74bd0205 / 08f7b1ea (suggestive open mouth).
- Lace-top thigh-highs / garter ribbons appear in several otherwise-clean pieces (d29d446f, 2b04512f, 28139660, e190d189, c5098fb3, 503b6d97, 34fba271); acceptable for the RuStore/APK build, strip for Yandex.
- Baked text: 5455fbf7 contains the lettering 'Five Winds'; every other background item is text-free (the 84ce8bae sheet shows real mahjong glyphs 南/九萬 only).

## What this does NOT establish
- No native-resolution finger/toe count for the 100 backgrounds; only the ~14 hand-critical key arts that were cropped got that. Before shipping any shortlisted CG, run a crop pass on it.
- The glossy 1024 px vignettes were not compared against the shipped UI kit at pixel level; style fit with recipe v4 is by eye.
- Duplicate/near-duplicate sets exist (wardrobe 32a3e162/d9aab546, shop 3ca873b6/f8b752b4, lantern 49534656/60ecea27, tile skins 6483fe66/191377c6); pick one of each pair.
- Nothing was regenerated, so fixes (hands on 27c27ba3/89d77fc5/ebc9d4a4/d7cb9590, text on 5455fbf7) cost credits later and are not done.
