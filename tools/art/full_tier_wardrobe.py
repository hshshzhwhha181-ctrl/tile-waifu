"""Tier FULL wardrobe tables (P50b, rounds 2-3): body table + 10 heroines x 7 outfits, each outfit with 5 pose options (A/B/C hand-written,
D leg-focus and E bust-focus from templates) and 2 'hero' splash poses (H1/H2, used for SSR key art and showcase screens).

Spec: design/ART_TIER_FULL.md.  Used by tools/art/build_art_batches.py (H0 / H1 / H2 / H3 / H4) and quoted in the spec appendix.
Vocabulary is fashion / pin-up only (no 'sexy', 'cleavage', 'nude', 'lingerie', no '*boob' words: 'underbust cut-out' and
'side-cut' are the fashion terms); hard lines are in the spec section 2.
Outfit slots (the same 7 for everyone so the game can sell a predictable wardrobe):
  base, evening, swim, service (bunny / maid / bartender), robe (sleepwear robe-dress), battle (battle / idol), seasonal
MC is special: her two canonical Full outfits (owner mock-ups 12-15) fill the base and evening slots (night qipao, tea cheongsam).
Pose strings are "pose // expression".  Settings are used by the wardrobe batch (H2) only.
"""
from __future__ import annotations

SLOTS = ["base", "evening", "swim", "service", "robe", "battle", "seasonal"]

# ---------------------------------------------------------------------------------------------------------------------
# Body table (owner decision 2026-11-28): different heights and figures.  HARD floor: every heroine reads as a mature adult
# woman (adult face, adult figure); heads never below HEADS_MIN; petite = a shorter adult woman, never a young-looking one.
# ---------------------------------------------------------------------------------------------------------------------
HEADS_MIN, HEADS_MAX = 6.75, 8.0
HEIGHTS = {
    "yue":     dict(cm=177, heads=7.9,  tag="very tall and statuesque", legs="very long statuesque legs with full thighs"),
    "zlata":   dict(cm=176, heads=7.8,  tag="tall and statuesque", legs="long legs with full thighs"),
    "rin":     dict(cm=172, heads=7.5,  tag="tall and slender", legs="long legs with full soft thighs"),
    "mc":      dict(cm=170, heads=7.5,  tag="tall, soft and shapely", legs="long legs with full soft thighs"),
    "hana":    dict(cm=168, heads=7.25, tag="athletic average height", legs="strong athletic legs with thick thighs"),
    "tsubame": dict(cm=165, heads=7.25, tag="lithe average height", legs="slim toned shapely legs"),
    "shirin":  dict(cm=163, heads=7.25, tag="average height with fuller curves", legs="long legs with full thighs"),
    "kohaku":  dict(cm=160, heads=7.0,  tag="slightly petite but clearly a grown woman", legs="soft legs with full thighs"),
    "nova":    dict(cm=158, heads=7.0,  tag="petite but clearly a grown woman", legs="slim toned shapely legs"),
    "miel":    dict(cm=155, heads=6.75, tag="petite and curvy but clearly a mature grown woman", legs="thick shapely thighs and soft legs"),
}

# Figure descriptors (owner feedback round 3, 2026-11-28): fuller thighs on some heroines, accent on legs and bust, varied across the roster.
# Exact approved body terms (Full files only; 'thick', 'full thighs', 'wide hips', 'curvy' are NOT hard-banned, minor / school words are).
FIGURE = {
    "mc":      "soft shapely figure, full soft thighs, wide rounded hips, a defined waist, a full bust accented by the neckline",
    "miel":    "soft curvy pear-shaped figure with thick shapely thighs and wide hips, a slim waist, a full bust",
    "kohaku":  "soft athletic-soft figure with full soft thighs and rounded hips, a slim waist, a full bust",
    "zlata":   "statuesque figure, full thighs on long legs, wide regal hips, a slim waist, a full bust",
    "rin":     "slender figure with long legs and full soft thighs, rounded hips, a slim waist, a shapely bust",
    "yue":     "statuesque figure with very long legs and full thighs, rounded hips, a defined waist, a full bust",
    "shirin":  "soft shapely figure with long legs, full thighs and wide hips, a defined waist, a full bust, a bare midriff",
    "hana":    "athletic toned figure with strong thick thighs and soft definition, a flat stomach, a shapely bust",
    "tsubame": "lithe slim toned figure with shapely legs, rounded hips, a slim waist, a shapely bust",
    "nova":    "lean slim toned figure with shapely legs, gently rounded hips, a slim waist, a shapely bust",
}

# {hk: {slot: dict(name, outfit, setting, poses=[A,B,C], hero=[H1,H2])}}
W: dict[str, dict[str, dict]] = {}


FR = {
    "L": "low full-body view from knee level looking straight ahead (never below the hem, never up a skirt) that elongates the legs",
    "T": "thigh-focus three-quarter crop from the waist to the knees, the stocking bands and thighs filling the frame, camera at hip level",
    "S": "full-body seated view at eye level with the legs prominent in the foreground",
    "B": "close crop from the hip to the knees on the stocking band and garter, her smiling face partly in the frame, camera at eye level",
    "F": "waist-up to hips view leaning toward the viewer, bust-forward, camera at eye level",
}


def _p(s: str):
    """'pose // expression' or 'pose // expression // framing code' -> (pose, expression, framing text or None)."""
    parts = [x.strip() for x in s.split("//")]
    return (parts[0], parts[1], FR[parts[2]] if len(parts) > 2 else None)


def add(hk, slot, name, outfit, setting, a, b, c, h1, h2):
    W.setdefault(hk, {})[slot] = dict(name=name, outfit=outfit, setting=setting, poses=[_p(a), _p(b), _p(c)], hero=[_p(h1), _p(h2)])


# ================================================================ MC (Mahjong-chan)
add("mc", "base", "Night dragon qipao",
    "black-and-gold long qipao with gold dragon embroidery, a plunging keyhole front with a gold frog-button collar, bare shoulders, black lace detached arm sleeves, a side slit up to the hip, sheer black thigh-high stockings with wide lace tops, black stiletto heels",
    "night mahjong salon with chandeliers, black lacquer and red velvet chairs, drifting petals",
    "standing with her weight on one leg, one hand on her hip and the other raised into her hair, the stocking top visible through the slit // playful teasing smile",
    "seen from behind in three-quarter view with a hip tilted and an arched back, looking back over her shoulder, a hand on her hip // confident smile",
    "close-up of her face and shoulders, a lace-gloved fingertip at her lips, flushed cheeks // flirty half-lidded smile",
    "leaning back across the felt of the mahjong table on one elbow with one leg raised and crossed over the other, hair spilling over the edge // seductive confident smile",
    "standing in a deep S-curve against a lacquer pillar with both arms raised into her hair, the dragon embroidery catching the light // intense teasing gaze")
add("mc", "evening", "Tea floral cheongsam",
    "white-and-red floral cheongsam with gold trim, a heart-shaped chest cutout under a pink bow, bare shoulders, white detached wide sleeves with red knotted ribbons, a red sash with a flower brooch, a side slit up to the hip, white thigh-high stockings with a red ribbon-and-bell garter band, red high heels",
    "warm night tea house with paper lanterns, a round moon window and blossoming branches",
    "leaning over the mahjong table on one hand, holding up a single blank tile in the other hand, a wink // laughing open smile with a wink",
    "reclining sideways on a cushioned daybed propped on one elbow, one knee raised, holding a tea bowl // warm teasing smile",
    "kneeling on a cushion with an arched back and both hands in her long hair // dreamy flirty smile",
    "lying on her side on the daybed with her head on one arm and one long leg stretched out, the ribbon-and-bell band in view // inviting smile",
    "leaning far forward over the table toward the viewer, both hands on the felt, hair falling forward // bright teasing wink")
add("mc", "swim", "Blossom string bikini",
    "pink-and-white string bikini with jade-green ribbon ties at the hips and neck, a wet-look open white sheer shirt tied at the waist, a gold anklet, a straw sun hat with a pink ribbon",
    "sunset beach with a striped towel, soft waves and pink petals in the breeze",
    "kneeling on the towel with both fists under her chin, leaning toward the viewer, a wink // bright laughing wink",
    "standing in shallow water with both arms stretched above her head, a hip tilted, the wet shirt clinging // joyful open-mouth laugh",
    "seen from behind in three-quarter view, wringing out her wet hair over one shoulder, hips tilted, looking back // playful smile",
    "lying on her side on the towel propped on one elbow, one knee bent, hat tipped back // lazy teasing smile",
    "kneeling in the surf with an arched back and both hands pushing her wet hair back, water streaming // radiant half-lidded smile")
add("mc", "service", "Casino bunny leotard",
    "high-cut white-and-pink floral cheongsam-style bunny leotard with gold trim, a heart-shaped chest cutout and an underbust cut-out edged in gold, a pink bow collar, white bunny-ear headband with a fluffy tail, white wrist cuffs, thigh straps with gold clasps, sheer pale pantyhose, white stiletto heels",
    "grand casino-style mahjong hall with chandeliers, round felt tables and red velvet chairs",
    "standing with one hand on her hip and a fan of blank mahjong tiles held beside her face, winking // playful wink with a laugh",
    "seen from behind in three-quarter view with the fluffy tail and an arched back, glancing over her shoulder // confident teasing smile",
    "straddling a velvet chair backwards with her arms folded on the backrest, chin on her arms // sly smile, eyes on the viewer",
    "reclining across a felt table on one side, propped on an elbow, one leg raised, tiles scattered // seductive smile",
    "kneeling on the table with an arched back and both hands raised to her bunny ears // dazzling wink")
add("mc", "robe", "Moonlit wet-look robe",
    "blush-pink wet-look satin robe-dress with a plunging neckline tied by a sash over a satin mini nightgown, white lace-top thigh-high stockings, pink satin mules, the jade hairpins and cuffs kept",
    "moonlit bedroom with sheer curtains, a canopy bed and a tea tray",
    "sprawled on a silk bed on her back with one arm over her head, one leg bent, the robe slipping off a shoulder // dreamy flirty smile",
    "hugging a big pillow while lying on her side, looking at the viewer over the pillow // sleepy teasing smile",
    "standing at a moonlit window seen from behind, the robe slipping from her shoulders, looking back // soft inviting smile",
    "sitting on the bed edge with legs crossed, one hand brushing her hair, the robe open over the nightgown // intimate half-lidded smile",
    "kneeling on the bed with an arched back, both hands in her hair, moonlight on the satin // radiant seductive gaze")
add("mc", "battle", "Jade war leotard",
    "jade-green high-cut armoured leotard-dress with gold shoulder plates, a plunging keyhole front, side-cut hips, a short armoured skirt, thigh straps with gold clasps, scale-pattern thigh-high stockings, gold greaves, a large folding war fan with a tile pattern",
    "misty bamboo courtyard at dusk with floating lanterns",
    "lunging forward with the war fan opened toward the viewer, hair flying // fierce confident grin",
    "kneeling on one knee with an arched back and the fan planted like a standard, looking up // smirking challenge",
    "seen from behind in three-quarter view in a wide stance, the fan over one shoulder, looking back // bold laughing smile",
    "leaning on a bamboo pillar with her arms stretched above her head and one knee bent // confident teasing smile",
    "leaping with the fan spread and one leg extended, hair and ribbons streaming // fierce radiant grin")
add("mc", "seasonal", "Winter festival mini-qipao",
    "red velvet mini-cheongsam with white fur trim, an underbust cut-out and gold knots, bare shoulders, white fur cuffs, white thigh-high stockings with red bows and thigh straps, red heeled boots, a fur-trimmed cape",
    "snowy night festival street with lanterns and gentle snowfall",
    "twirling with the cape flaring, one hand holding a lantern // bright laughing smile",
    "leaning against a lantern post with one knee bent, blowing a kiss // playful kiss",
    "sitting on a snowy bench with legs crossed, holding a steaming cup // cozy teasing smile",
    "seen from behind in three-quarter view, the cape draped over one shoulder, glancing back with snow in her hair // flirty smile",
    "arching her back with both arms raised to catch snowflakes, the cape open // delighted laugh")

# ================================================================ Rin
add("rin", "base", "Phoenix cheongsam",
    "sleeveless black cheongsam with gold-green phoenix embroidery, a deep plunging neckline, an open back, a skirt slit up to the hip, sheer black thigh-high stockings with lace tops and garter straps clipped to the hem, black stiletto heels, a jade bangle",
    "tea library with floor-to-ceiling shelves, a rolling ladder and cherry blossom branches",
    "leaning against a bookshelf with one knee bent, sipping tea from a celadon cup, glancing at the viewer // teasing half-smile",
    "seen from behind in three-quarter view on the rolling ladder reaching for a book, the open back and hip slit in view, looking back // amused smile",
    "close-up of her face with the glasses slid down her nose, the cup at her lips, flushed cheeks // knowing smirk",
    "reclining on a chaise with her braid over one shoulder, one leg crossed over the other, a book on her stomach // sleepy flirty smile",
    "standing with one hand on her hip and the other pulling a pin from her hair, an arched back, the phoenix embroidery shining // commanding teasing gaze")
add("rin", "evening", "Knit tea dress",
    "off-shoulder cable-knit mini sweater dress in forest green with an open side, lace-top black thigh-high stockings, black stiletto heels, a jade bangle",
    "cozy library window seat with a tea set and soft rain on the glass",
    "leaning on a shelf with one leg lifted behind her, sipping tea // gentle teasing smile",
    "sitting sideways on a window seat with legs crossed, a book on her knee // warm half-smile",
    "kneeling on the window seat with an arched back, looking out at the rain and back over her shoulder // soft flirty smile",
    "lying on her side on a chaise with the sweater slipping off a shoulder, head on her hand // sleepy teasing smile",
    "stretching both arms overhead against a bookshelf, the knit riding up her thighs, the cup in one hand // lazy delighted smile")
add("rin", "swim", "Jade string swimsuit",
    "dark-green high-cut one-piece swimsuit with a deep plunging neckline, an underbust cut-out and gold side links, a sheer green wet-look wrap skirt, gold sandals, the thin gold glasses kept",
    "private hot-spring terrace with a stone pool, steam and lanterns at dusk",
    "sitting on the pool edge with her feet in the water, leaning back on one hand // calm teasing smile",
    "standing waist-deep in the pool wringing her braid, seen from behind in three-quarter view, glancing over her shoulder // soft smile",
    "lying on her side on a bamboo lounger propped on one elbow, a tea cup beside her // lazy flirty smile",
    "kneeling on the stone edge with an arched back and both hands pushing her wet hair back, steam around her // dreamy half-lidded smile",
    "close-up of her wet face and shoulders in the steam, the glasses beaded with droplets // knowing smile")
add("rin", "service", "Bunny tea-server tailcoat",
    "high-cut black bunny-style tailcoat leotard with gold-trimmed lapels, a deep plunging neckline, a side-cut waist, thigh straps with gold clasps, a green bow tie, black bunny-ear headband with a white tail, white gloves, sheer black pantyhose, black heels, a silver teapot",
    "grand tea hall with red velvet drapes, marble floor and an armillary sphere",
    "bending slightly forward presenting a silver teapot on one hand, tilting her head // gracious teasing smile",
    "standing in profile with an arched back and the fluffy tail, the teapot on a tray, glancing back // composed smirk",
    "sitting on the arm of a velvet sofa with crossed legs, pouring tea // relaxed flirty smile",
    "straddling a tea-hall chair backwards with her chin on her gloved hands // sly teasing smile",
    "seen from behind in three-quarter view leaning on a marble table with the tailcoat flaring, looking back over her shoulder // seductive smirk")
add("rin", "robe", "Jade silk robe",
    "emerald wet-look silk robe-dress with a plunging neckline and a satin sash over a green satin mini nightgown, black lace-top thigh-high stockings, jade earrings, the thin gold glasses kept",
    "night study with a lamp, scrolls and a teapot on a low table",
    "sitting on a low sofa with one leg crossed over the other, the robe slipping from one shoulder, holding a cup // soft teasing smile",
    "standing at a bookshelf seen from behind with her back arched, looking over her shoulder // amused smile",
    "reclining on a daybed with a book on her chest, one knee raised // sleepy half-smile",
    "sprawled across the daybed on her back with one arm trailing to the floor, the robe open over the nightgown // intimate teasing smile",
    "kneeling on the daybed with an arched back, taking down her braid with both hands // quiet seductive gaze")
add("rin", "battle", "Tea-master combat leotard",
    "black high-cut combat leotard-dress with green piping, a plunging neckline, side-cut waist, shoulder plates and bracers, thigh straps, scale-pattern thigh-high stockings, black boots, a kunai-shaped tea whisk at her belt",
    "rain-wet tiled rooftop at night with warm lantern light",
    "crouching on the ridge with one hand on the tiles, glancing sideways // cool smirk",
    "standing with one hand on her hip and the other holding a tea bowl, a hip tilted // calm teasing smile",
    "leaning back on a chimney with one leg bent, tying her braid // knowing half-smile",
    "seen from behind in three-quarter view on the roof ridge, the combat leotard hugging her hips, looking back // sly smile",
    "mid-leap between roofs with the braid streaming and one leg extended // fierce elegant grin")
add("rin", "seasonal", "Spring festival yukata",
    "short sage-green yukata with cherry-blossom print, an off-shoulder neckline, a wide obi with a jade charm, a slit to the hip, white thigh-high socks with green ribbon bands, wooden geta",
    "spring festival stalls with lanterns and falling cherry petals",
    "holding a paper fan against her lips, a hip tilted // elegant teasing smile",
    "sitting on a stone lantern base with legs crossed, a sweet dumpling stick in hand // playful smile",
    "looking back over her shoulder under blossom branches, seen from behind with the obi bow // soft flirty smile",
    "kneeling on a festival mat with an arched back, tying up her hair with both hands // calm teasing smile",
    "twirling under falling petals with the yukata riding up one thigh // radiant laugh")

# ================================================================ Hana
add("hana", "base", "Pin-up track set",
    "orange-striped sports crop top with a deep neckline and bare midriff, short orange-striped running shorts, an off-shoulder pink track jacket sliding down one shoulder, white over-the-knee striped socks with a small star, white-orange sneakers, sport wristband",
    "sunset running track with floodlights and a rust-red lane",
    "leaning forward with hands on her knees, pointing at the viewer, a wink // competitive grin with a wink",
    "standing on one leg with the other lifted behind her, waving, a hand on her hip // open-mouth grin",
    "kneeling with arms stretched high above her head, back arched // laughing",
    "seen from behind in three-quarter view bending slightly to tie a shoe, looking back over her shoulder // cheeky grin",
    "sprinting start crouch with the jacket flying off one shoulder and sweat glowing on her skin // fierce grin")
add("hana", "evening", "Gala backless dress",
    "orange satin mini dress with a deep plunging neckline and an open back, a high slit, sunflower-yellow ribbon straps, sheer tan thigh-high stockings, white-orange heeled sandals, a sport wristband kept",
    "gala hall with warm chandeliers and a balcony of sunflowers",
    "one hand on her hip, the other pushing back her hair, a hip tilted // bright confident smile",
    "sitting on a balustrade with legs crossed, laughing, looking at the viewer // teasing laugh",
    "seen from behind in three-quarter view showing the open back, looking back over her bare shoulder // playful smile",
    "reclining on a gala sofa with one arm over the back and one leg stretched out // relaxed flirty smile",
    "arching her back with both arms thrown up in a cheer, the satin riding up her thighs // joyful laugh")
add("hana", "swim", "Sunflower string bikini",
    "yellow string bikini with thin tie sides, an off-shoulder wet-look sheer white shirt tied at the waist, a wide straw sun hat with a yellow ribbon, a sport wristband",
    "sunset beach with a striped towel and a driftwood log",
    "kneeling on the towel with both fists under her chin, a wink // beaming wink",
    "squatting in the sand scooping a seashell, knees together, glancing up at the viewer // cheerful grin",
    "lying on her side on the towel propped on one elbow, one knee bent // relaxed laughing smile",
    "seen from behind in three-quarter view walking into the surf, looking back with a hand on her hip // teasing grin",
    "kneeling in the shallows with an arched back and her hands in her wet hair, the shirt clinging // radiant grin")
add("hana", "service", "Bartender bunny",
    "high-cut orange bunny-style leotard with white stripe trim, an underbust cut-out edged in orange, a black bow tie collar, white cuffs, thigh straps, a bunny-ear headband, sheer tan pantyhose, white platform sneakers, a shaker held as a prop",
    "neon-lit sports bar with trophies and a counter",
    "leaning over the counter on both elbows, a wink // cheeky wink",
    "shaking a cocktail shaker above her shoulder, hip tilted // bright grin",
    "sitting on a bar stool with her legs crossed, a hand under her chin // teasing smile",
    "straddling a bar stool backwards with her arms folded on the backrest // sly grin",
    "seen from behind in three-quarter view leaning on the counter with the bunny tail, looking back // playful smirk")
add("hana", "robe", "Locker-room satin robe",
    "short orange satin robe with white piping tied loosely at the waist over a satin sleep tank and shorts, sheer tan thigh-high stockings, fluffy slippers",
    "morning gym lounge with sunlight, a bench and a towel rack",
    "sitting on a bench with one leg stretched out, towel around her neck, leaning back // sleepy playful smile",
    "stretching with both arms overhead, the robe slipping off one shoulder // yawning laugh",
    "kneeling on the bench looking back over her shoulder, seen from behind // teasing smile",
    "lying on her side on the bench with her head on her arm, the robe open // lazy grin",
    "hugging a gym pillow on the bench, hair messy, one leg raised // sweet flirty smile")
add("hana", "battle", "Relay racer leotard",
    "tight orange-and-white high-cut racing bodysuit with a zip neckline pulled low, side-cut waist with mesh panels, thigh straps, thigh-high compression socks, spiked track shoes, a flowing relay baton ribbon",
    "stadium at night under floodlights with a glowing finish line",
    "sprinting start crouch with one hand on the track and a glance at the viewer // fierce grin",
    "standing with one hand on her hip holding up a baton, a hip tilted // triumphant smile",
    "leaning against a hurdle with legs crossed, wiping her forehead, sweat glowing // tired teasing smile",
    "seen from behind in three-quarter view at the start line, the bodysuit hugging her hips, looking back // fierce smirk",
    "mid-sprint with the baton ribbon streaming and sweat flying // roaring joyful grin")
add("hana", "seasonal", "Winter-rink set",
    "short orange puffer jacket worn off one shoulder over a white crop sweater, a flared white skater mini skirt, white thigh-high stockings with orange stripes and thigh straps, white ice skates, a knitted headband",
    "ice rink under string lights with falling snow",
    "spinning on one skate with one leg lifted behind her, arms out // laughing",
    "kneeling to tie a skate, looking up at the viewer // playful grin",
    "leaning back on the rink barrier with legs crossed // cheeky smile",
    "seen from behind in three-quarter view gliding backwards, looking over her shoulder // bright teasing grin",
    "arching into a layback spin with her arms overhead and snow flying // exhilarated laugh")

# ================================================================ Yue
add("yue", "base", "Moon-queen hanfu",
    "lavender silk hanfu-style gown, off-the-shoulder with a deep plunging V front, sheer layered sleeves, gold moon-and-star embroidery, sash-cinched waist, skirt slit up to the hip, white lace-top thigh-high stockings with pearl garter straps, lavender high heels",
    "moonlit palace terrace above a sea of clouds, an enormous full moon",
    "reclining on a moon-cushion divan with one leg crossed over the other, an arm extended offering a blank jade tile // serene teasing smile",
    "seated sideways on a throne armrest with legs crossed, the moon-phase fan against her lips // amused teasing smile",
    "standing in an S-curve with one hip tilted, one hand held out, the fan on her hip // slow inviting half-smile",
    "sprawled across the divan on her back with one arm trailing and the slit open to the hip, long hair spilling to the floor // languid seductive smile",
    "standing seen from behind in three-quarter view with the gown sliding off both shoulders, looking back with the fan at her lips // imperious teasing gaze")
add("yue", "evening", "Sheer window robe-gown",
    "sheer layered lavender wet-look robe-dress with a deep plunging neckline and a crescent sash over a lavender satin mini nightgown, lace-top thigh-high stockings with crystal garter charms, silver heels",
    "moonlit window of a palace bedchamber with sheer curtains",
    "reclining against the window frame with one arm along the sill, the fan held by her cheek // serene teasing smile",
    "standing at the window with one hand drawing the curtain, arched back // soft inviting smile",
    "sitting on the sill with one knee raised, looking back at the moon // dreamy half-smile",
    "lying on her side on a cushioned window bench with her head on her arm and the robe falling open // intimate smile",
    "kneeling on the bench with an arched back and both hands lifting her long hair, moonlight on the sheer fabric // luminous seductive gaze")
add("yue", "swim", "Moon-lagoon string bikini",
    "lavender string bikini with gold crescent rings and chain details, a wet-look sheer lavender sarong slit to the hip, gold anklets, a crescent forehead ornament kept",
    "moonlit lagoon with lotus flowers, a stone terrace and lanterns",
    "sitting on the terrace edge with her feet in the water, leaning back on both hands // calm teasing smile",
    "standing waist-deep in the water gathering her long hair over one shoulder, seen from behind in three-quarter view // serene smile",
    "lying on a floating cushion on her side, the fan trailing in the water // lazy flirty smile",
    "kneeling on the stone edge with an arched back and both hands in her wet hair, moon behind her // dreamy half-lidded smile",
    "rising from the water with long wet hair clinging, the fan held to her lips, close three-quarter framing // imperious flirty gaze")
add("yue", "service", "Moon bunny",
    "high-cut lavender bunny-style leotard with gold moon embroidery, a deep plunging neckline and an underbust cut-out edged in gold, long lavender bunny ears over her horns, thigh straps with crescent clasps, a crescent bow tie, sheer white pantyhose, lavender stiletto heels, white cuffs",
    "grand moon-pavilion hall with silver lamps and round tea tables",
    "standing with a tray of blank jade tiles on one hand, a hip tilted // elegant teasing smile",
    "leaning forward on a table with both forearms on it, one leg lifted behind her // sly smile",
    "sitting on a table edge with legs crossed, the fan at her lips // amused smile",
    "straddling a pavilion chair backwards with her chin on her folded arms // lazy teasing smile",
    "seen from behind in three-quarter view with the fluffy tail and an arched back, looking over her shoulder // regal seductive smile")
add("yue", "robe", "Pearl silk robe",
    "pearl-white wet-look silk robe-dress with a plunging neckline and a crescent sash, a lavender satin mini nightgown under it, lace-top thigh-high stockings, a gold crescent forehead ornament kept",
    "canopy bed in a moonlit chamber with petals on the sheets",
    "reclining on the bed propped on one elbow, one leg bent, the robe slipping from a shoulder // dreamy flirty smile",
    "kneeling on the bed with a hand in her hair, looking at the viewer // inviting smile",
    "sitting on the bed edge with legs crossed, a fan covering half her smile // teasing half-smile",
    "sprawled on her back across the silk sheets, hair fanned out, one arm above her head // languid seductive smile",
    "hugging a moon-shaped pillow lying on her side, the robe off one shoulder // sleepy intimate smile")
add("yue", "battle", "Dragon-scale armour",
    "purple dragon-scale armour leotard-dress with gold filigree plates, a plunging keyhole front with a gem pendant, side-cut hips, a short layered armoured skirt, scale thigh-high stockings with crescent gold garter bands, scale gloves, a moon glaive",
    "misty mountain temple stairs at dusk with moon banners",
    "standing in a wide stance holding the moon glaive across her body // confident smirk",
    "lunging with the glaive swept back, hair flying // fierce smile",
    "kneeling on one knee with the glaive planted, looking up // regal teasing smile",
    "seen from behind in three-quarter view on the temple stairs, the scale armour hugging her hips, looking back // imperious smirk",
    "standing on a stair with an arched back and the glaive overhead in both hands, hair streaming // majestic fierce gaze")
add("yue", "seasonal", "Moon-festival gown",
    "short white-and-lavender festival hanfu with a deep neckline, a rabbit-motif sash, off-shoulder sheer sleeves, white thigh-high stockings with lavender ribbons and thigh straps, silver heels, a lantern held in one hand",
    "mid-autumn lantern garden with a huge moon and mooncake stalls",
    "holding up a glowing lantern, looking back over her shoulder // gentle teasing smile",
    "sitting on a stone bench with legs crossed, a mooncake in her fingers // warm smile",
    "leaning against a lantern pole with one knee bent // serene flirty smile",
    "seen from behind in three-quarter view with the sash bow and a lantern raised, looking back // soft inviting smile",
    "arching her back to reach a hanging lantern with both arms overhead // delighted luminous smile")

# ================================================================ Nova
add("nova", "base", "Neon idol corset set",
    "strapless black corset bodice with neon cyan piping and a plunging sweetheart neckline, detached puffed black sleeves with neon trim, layered holographic tiered mini skirt with a big pink cat-badge bow at the hip, black fishnet thigh-highs with a neon cyan garter strap, black thigh-high lace-up platform boots with cyan laces",
    "night server room with glowing racks and a holographic panel",
    "singing into a microphone, pointing at the viewer, one leg stepped forward, a wink // wink with a bright grin",
    "perched on a server rack with her boots crossed, tapping her headphones // confident smirk",
    "leaning forward with a hip tilt, a glowing hologram card between two fingers // teasing smirk",
    "seen from behind in three-quarter view with the skirt and bow, looking back over her shoulder, a hip tilted // smug smile",
    "sprawled on a server-room couch on her back with one boot raised, a hologram floating above her // lazy smirk")
add("nova", "evening", "Latex catsuit",
    "glossy black latex-look bodysuit with a zipper neckline pulled low, an underbust cut-out edged in neon cyan piping, a holographic cropped jacket with a hood and cat ears, black thigh-high lace-up platform boots with cyan laces, a ring choker",
    "server-room corridor with fog and glowing racks",
    "squatting in a three-quarter view with knees together, one hand on her knee and a claw gesture, a wink // wink with a grin",
    "standing with her back arched and a hip tilted, the jacket slipping off one shoulder // cool smirk",
    "sitting sideways on a console with one boot raised on the edge // teasing smirk",
    "seen from behind in three-quarter view, the glossy bodysuit hugging her hips, looking back with a finger at her lips // sly smile",
    "kneeling on the console with an arched back and both hands in her hair, neon reflecting on the latex // seductive smirk")
add("nova", "swim", "Neon string bikini",
    "black-and-neon-cyan string bikini with a pink cat-badge clasp, thin tie sides, an open wet-look holographic mesh hoodie, black thigh-high sandals with cyan straps, cat-ear headphones kept",
    "rooftop pool at night with neon city lights and glowing lounge beds",
    "sitting on the pool edge with one leg bent, leaning back on both hands // playful smirk",
    "lying on her side on a glowing lounger propped on one elbow // teasing smile",
    "standing with arms stretched overhead in a stretch, a wink // bright wink",
    "seen from behind in three-quarter view at the pool edge, water beading on her skin, looking back // smug smile",
    "kneeling at the pool edge with an arched back and both hands pushing her wet hair back // half-lidded seductive smirk")
add("nova", "service", "Cyber maid",
    "short black-and-pink cyber maid dress with a deep plunging neckline and an underbust cut-out, a frilled holographic apron with a cat-badge bow, detached sleeves, black fishnet thigh-highs with a cyan garter strap and thigh straps, black platform heels, a headband over her cat ears",
    "neon cat-cafe with glowing menus left blank, small round tables and pink lights",
    "holding a tray with one hand and a finger at her lips, a hip tilted // teasing wink",
    "leaning over a table toward the viewer with a hand on her hip // smug grin",
    "sitting on a counter with legs crossed, tapping her headphones // confident smirk",
    "straddling a cafe chair backwards with her chin on her arms, the apron bow behind her // playful smirk",
    "seen from behind in three-quarter view bending slightly to set down a cup, the frilled skirt and bow in view, looking back // sly wink")
add("nova", "robe", "Hologram robe",
    "translucent iridescent wet-look robe-dress over a black satin mini nightgown with a plunging neckline, a neon cyan sash, black lace-top thigh-high stockings, fluffy cat-ear slippers",
    "dark apartment with a glowing monitor wall and a rain-streaked window",
    "reclining on a beanbag with a laptop on her knees, one leg raised // sleepy smirk",
    "kneeling on a chair back looking over her shoulder at the screens // teasing smile",
    "standing at the window with her back arched, hugging a cup // soft smirk",
    "sprawled on her back on the bed with a glowing tablet above her face, one arm trailing // lazy flirty smirk",
    "hugging a cat-shaped pillow lying on her side, the robe off one shoulder // sleepy teasing smile")
add("nova", "battle", "Street-racer leotard",
    "tight black-and-cyan high-cut racing bodysuit with a zipper neckline pulled low, side-cut hips, thigh straps, thigh-high armoured boots, a cropped racing jacket with neon piping, a visor pushed up on her forehead, race gloves",
    "neon-lit night garage with a glowing motorbike",
    "leaning back against the bike with one knee bent, holding a helmet at her hip // cool smirk",
    "squatting by the bike tightening a strap, knees together, glancing sideways // sly grin",
    "standing with a hip tilt and a thumbs-up, a wink // playful wink",
    "seen from behind in three-quarter view straddling the motorbike seat, looking back over her shoulder // smug smile",
    "leaning far forward over the bike tank toward the viewer, the zipper low, goggles pushed up // fierce teasing grin")
add("nova", "seasonal", "Rooftop sneaker set",
    "black crop top with a deep neckline, neon cyan piping and a navel stud, an iridescent holographic mini skirt, black-and-cyan striped thigh-high socks, chunky white-and-pink platform sneakers, an off-shoulder cropped jacket",
    "rooftop at dusk with a water tower, city haze and pink clouds",
    "kneeling with both arms stretched high above her head, a wink // open-mouth grin with a wink",
    "standing with legs crossed at the ankle and arms overhead, back arched // laughing",
    "sitting on the parapet with one leg swinging, looking back // teasing smile",
    "seen from behind in three-quarter view with her arms overhead in a stretch, the holo skirt and jacket flaring // playful smile",
    "lying on her side on a rooftop mat with her head on her hand and one sneaker raised // lazy smirk")

# ================================================================ Tsubame
add("tsubame", "base", "Rooftop kunoichi",
    "short indigo wrap kimono-style dress with a deep plunging neckline and open sides, a wide obi with crimson rope, fishnet thigh-high stockings with crimson ribbon thigh bands, black split-toe tabi boots, fishnet arm guards, a long crimson scarf",
    "rain-wet tiled rooftop at night above a canal town with lanterns",
    "sitting on the roof ridge with knees together, both arms raised tying her ponytail // cool unimpressed smirk",
    "crouching on the ridge with one hand on the tiles, looking back over her shoulder // sly half-smile",
    "leaning on a chimney with one leg bent, holding a sealed letter // teasing smile",
    "seen from behind in three-quarter view on the ridge with the open sides and obi bow, the scarf blowing, looking back // knowing smirk",
    "reclining on the sloped tiles on her side with her head on her arm, one leg stretched along the ridge // lazy dangerous smile")
add("tsubame", "evening", "Crimson slit dress",
    "black-and-crimson satin evening dress with a deep plunging neckline, an open back and a slit to the hip, sheer black lace-top thigh-high stockings with a crimson garter, black stiletto heels, the crimson scarf worn as a stole",
    "moonlit pagoda balcony with a lantern string",
    "standing with one hand on the railing and her back arched, glancing over her shoulder // cool teasing smile",
    "sitting on the railing with legs crossed, the scarf trailing // amused smirk",
    "leaning against a pillar with a hand on her hip, a hip tilted // confident smile",
    "seen from behind in three-quarter view showing the open back and the slit, looking back // dangerous flirty smile",
    "lying across a lacquered bench on her side with her head on her hand and the slit open to the hip // seductive half-smile")
add("tsubame", "swim", "Swallow string swimsuit",
    "indigo-and-crimson high-cut swimsuit with a deep plunging neckline, an underbust cut-out, thin side straps and an obi-style waist wrap, a wet-look sheer crimson sarong, fishnet arm guards, a swallow anklet",
    "hidden mountain hot spring at dusk with steam and lanterns",
    "sitting on a rock with her feet in the water, leaning back on one hand // calm teasing smile",
    "standing waist-deep wringing her long ponytail, glancing sideways // sly half-smile",
    "lying on her side on a flat rock propped on one elbow // lazy smirk",
    "seen from behind in three-quarter view stepping out of the water, the wet ponytail clinging, looking back // knowing smile",
    "kneeling on the rock with an arched back and both hands lifting her wet hair, steam around her // dreamy half-lidded gaze")
add("tsubame", "service", "Courier bunny",
    "high-cut black bunny-style leotard with a crimson obi sash and a messenger pouch, a deep plunging neckline, a side-cut waist, thigh straps, black bunny ears with a swallow pin, sheer black pantyhose, split-toe boots, white cuffs",
    "night market alley with lanterns and parcel stacks",
    "standing with a parcel on one hip and a hand on the other, a hip tilted // cool smirk",
    "leaning on a crate with one leg lifted behind her // teasing half-smile",
    "sitting on a parcel stack with legs crossed, tapping the sealed letter on her lips // amused smile",
    "straddling a crate backwards with her arms folded on top // sly smile",
    "seen from behind in three-quarter view bending to lift a parcel with the fluffy tail, looking back // dangerous teasing smile")
add("tsubame", "robe", "Night kimono robe",
    "loose dark-indigo wet-look silk robe-dress with a plunging neckline tied by a crimson obi over a satin mini nightgown, fishnet thigh-highs with ribbon bands, the swallow hairpin kept",
    "paper-screen bedchamber with a single lantern and rain on the roof",
    "reclining on tatami propped on one elbow, one knee raised // sleepy teasing smile",
    "kneeling at a low table pouring tea, glancing up // sly smile",
    "standing at a sliding door with her back arched, looking back // soft smirk",
    "sprawled on her back on a futon with one arm over her head, the robe open over the nightgown // lazy seductive smile",
    "hugging a bolster pillow lying on her side, the robe off one shoulder // sleepy intimate smirk")
add("tsubame", "battle", "Shadow courier leotard",
    "black fitted high-cut shinobi leotard with a deep plunging mesh neckline, side-cut hips, crimson armoured shoulder guards, a short split skirt, thigh straps, fishnet thigh-high stockings, tabi boots with crimson ties, a kunai belt",
    "tiled rooftop in a storm with lightning over the town",
    "crouching on one knee on the ridge with a kunai between her fingers // fierce smirk",
    "leaping between roofs with the scarf streaming // bold grin",
    "standing in a wide stance with arms crossed, the scarf blowing // cool half-smile",
    "seen from behind in three-quarter view crouched on the ridge, the leotard hugging her hips, looking back // deadly teasing smile",
    "mid-leap with an arched back and the scarf whipping, a kunai raised overhead // fierce radiant gaze")
add("tsubame", "seasonal", "Summer festival yukata",
    "short crimson yukata with swallow print, an off-shoulder neckline, a black obi with a bell, a slit to the hip, black thigh-high socks with red ribbon bands, wooden geta",
    "summer festival with goldfish stalls and fireworks",
    "holding a goldfish bag and a hand fan, a hip tilted // playful smile",
    "sitting on a stone step with legs crossed, a candy apple in hand // teasing smile",
    "looking back over her shoulder at fireworks, arched back // soft smirk",
    "seen from behind in three-quarter view showing the obi bow and the nape, fireworks reflected, looking back // knowing smile",
    "kneeling on a festival mat with her hair down and both hands in it, lantern glow on her face // quiet seductive smile")

# ================================================================ Miel
add("miel", "base", "Patisserie corset set",
    "cream off-shoulder puff-sleeve blouse with a plunging ruffled neckline, a fitted rose corset, a short frilled apron mini skirt with ribbons, brown thigh-high stockings with ribbon bow bands, rose high heels with bows",
    "warm bakery kitchen with a brick oven, a marble counter and macaron trays",
    "leaning over the counter on one arm, holding out a spoon of cream toward the viewer, a wink // tongue-out wink with a laugh",
    "standing with a whisk raised and a hip tilted, a dab of cream on her cheek // playful grin",
    "sitting on the counter edge with legs crossed, holding a macaron to her lips // sweet teasing smile",
    "seen from behind in three-quarter view bending slightly over the counter, the frilled skirt and bows in view, looking back // cheeky wink",
    "close-up of her flushed face with a cream-dabbed lip and a finger at her mouth // sweet flirty smile")
add("miel", "evening", "Dessert-gala dress",
    "rose-pink satin off-shoulder mini ball dress with a deep sweetheart neckline, a corset bodice with ribbons, a frilled tulle skirt, cream lace-top thigh-high stockings with bow bands, cream heels",
    "candle-lit dessert gala with tiered cake towers and flowers",
    "holding a strawberry tart toward the viewer, leaning forward, a hip tilted // sweet teasing smile",
    "sitting on a banquet table edge with legs crossed, licking cream from a finger // playful smile",
    "looking back over her bare shoulder with an arched back, seen from behind // soft flirty smile",
    "reclining on a velvet chaise with one arm over her head and a cake fork in hand // dreamy teasing smile",
    "kneeling on a banquet chair with an arched back, both hands lifting a heart-shaped cake // delighted flirty gaze")
add("miel", "swim", "Strawberry string bikini",
    "pink strawberry-print string bikini with cream ribbon ties and thin side ties, an open wet-look frilled white shirt, a straw hat with a white bow, a pearl anklet",
    "pastel seaside terrace with a picnic basket and a striped towel",
    "kneeling on the towel with a hand held up holding a strawberry, a wink // happy tongue-out wink",
    "lying on her stomach propped on both elbows, legs lifted and crossed behind her // sweet grin",
    "standing in shallow water holding her hat on, a hip tilted // bright laugh",
    "seen from behind in three-quarter view wading out with the bow ties at her hips, looking back // cheeky smile",
    "kneeling on the towel with an arched back and both hands pushing her wet curls back // dreamy sweet gaze")
add("miel", "service", "Cafe maid",
    "short caramel-and-cream high-cut maid leotard-dress with a deep plunging neckline and an underbust cut-out edged in lace, a frilled apron, puff sleeves, a lace headband with her bow kept, cream thigh-high stockings with lace tops, ribbon bands and thigh straps, rose heels",
    "pink-and-gold patisserie cafe with glass cake displays",
    "balancing a tray of macarons on one hand, a hip tilted, a wink // wink with a laugh",
    "leaning over a table toward the viewer, resting on both hands // sugary teasing smile",
    "sitting on a stool with legs crossed, hugging the tray // shy sweet smile",
    "straddling a cafe chair backwards with her chin on her arms and a macaron in her fingers // cheeky grin",
    "seen from behind in three-quarter view reaching for a high shelf on tiptoe, the frilled skirt and apron bow in view, looking back // coy smile")
add("miel", "robe", "Honey satin robe",
    "honey-gold wet-look satin robe-dress with a plunging neckline and a cream sash over a cream satin mini nightgown, lace-top thigh-high stockings with ribbons, fluffy slippers, the macaron hair clip kept",
    "morning kitchen loft with sunlight, flour dust and a quilt",
    "reclining on a cushioned window seat propped on one elbow, one knee raised, a cup in hand // sleepy sweet smile",
    "stretching with arms overhead, an arched back, the robe slipping from a shoulder // yawning laugh",
    "kneeling on the bed looking back over her shoulder // teasing smile",
    "sprawled on her back on a quilt with her curls spread out and a macaron held above her // dreamy playful smile",
    "hugging a big pillow lying on her side, the robe off one shoulder // sleepy sweet gaze")
add("miel", "battle", "Confection-knight leotard",
    "rose-and-cream high-cut armoured corset leotard with whisk-shaped pauldrons and a plunging neckline, side-cut hips, a short sugar-lace skirt, thigh straps, thigh-high armoured stockings with bows, heeled boots, a giant piping-bag lance",
    "candy-castle courtyard with sugar towers and floating macarons",
    "lunging forward with the piping-bag lance pointed at the viewer // playful fierce grin",
    "standing with the lance on her shoulder and a hand on her hip // bold wink",
    "kneeling on one knee with the lance planted // proud sweet smile",
    "seen from behind in three-quarter view in a wide stance, the lace skirt and bows flaring, looking back // cheeky fierce smile",
    "leaping with the lance overhead and macarons bursting around her, an arched back // exhilarated radiant grin")
add("miel", "seasonal", "Winter bakery",
    "red-and-cream velvet mini dress with white fur trim, a bare-shoulder neckline, an underbust cut-out, a frilled apron, a fur-trimmed cape, white thigh-high stockings with red bows and thigh straps, red heels",
    "snowy bakery window with gingerbread and string lights",
    "holding a gingerbread tray, leaning toward the viewer, a wink // festive wink",
    "sitting on a flour sack with legs crossed, a candy cane at her lips // teasing smile",
    "twirling with the cape flaring // bright laugh",
    "seen from behind in three-quarter view with the cape sliding off one shoulder, looking back at the snow // coy smile",
    "lying on a pile of cushions in the bakery window on her side with a gingerbread heart at her lips // sweet seductive smile")

# ================================================================ Kohaku
add("kohaku", "base", "Shrine-maiden festival",
    "white shrine-maiden top with a deep plunging neckline, detached wide sleeves and bare shoulders, a vermilion hakama skirt with a side slit to the hip, white thigh-high stockings with a red ribbon-and-bell thigh band, red-thonged geta",
    "lantern-lit shrine stairs with fox statues and gingko leaves",
    "leaning on a red torii pillar with one knee bent, a one-eye wink // toothy playful grin",
    "standing with a folding fan raised in one hand and the other arm out, a hip tilted // laughing open smile",
    "sitting on a stone step with legs crossed, tail curled around her // teasing smile",
    "seen from behind in three-quarter view on the stairs with the tail sweeping and the slit open, looking back // sly toothy smile",
    "lying on her side across the stone steps with her head on her arm, the tail curled over her legs, the thigh band in view // lazy seductive grin")
add("kohaku", "evening", "Fox-lantern kimono dress",
    "vermilion-and-gold short kimono dress with an off-shoulder plunging neckline, a wide obi with a bell charm, a slit to the hip, sheer white lace-top thigh-high stockings with a red ribbon band, red heeled geta",
    "night shrine garden with floating fox-fire lanterns",
    "holding a floating fire-lantern in cupped hands, looking up with a smile // sly smile",
    "looking back over her shoulder with her tail swept forward, arched back // teasing smile",
    "kneeling on a tatami platform with a hand on her thigh band // playful smile",
    "reclining on a cushioned veranda on one elbow with the kimono falling off a shoulder and the tail around her // intimate fanged smile",
    "arching her back with both arms raised to the fire-lanterns, the slit open and the tail fanned // enchanted radiant gaze")
add("kohaku", "swim", "Shrine-spring string bikini",
    "white-and-vermilion string bikini with red ribbon ties and a gold bell at the neck, a wet-look sheer white sarong with a red edge, white thigh bands with bells, the fox mask at the side of her head",
    "forest hot spring with torii gates, steam and maple leaves",
    "sitting on a rock with her feet in the water, her tail resting beside her // relaxed teasing smile",
    "standing waist-deep with her tail raised out of the water, glancing back, seen from behind in three-quarter view // playful grin",
    "lying on her side on a wooden deck propped on one elbow // lazy flirty smile",
    "kneeling on the rock with an arched back and both hands wringing her wet silver hair, steam rising // half-lidded seductive smile",
    "close-up of her wet face and bare shoulders in the steam with a fang showing // mischievous smile")
add("kohaku", "service", "Fox bunny-maid",
    "high-cut white-and-red bunny-style leotard with a deep plunging neckline, an underbust cut-out edged in gold and a gold bell collar, white fox ears kept, a red bow, white cuffs, thigh straps with bells, sheer white pantyhose, red heels, a tray with blank tea cups",
    "festival teahouse with red lanterns and paper screens",
    "carrying a tray with one hand and a hip tilted, a wink // wink with a fang",
    "leaning over a low table toward the viewer // teasing grin",
    "sitting on the table edge with legs crossed // sly smile",
    "straddling a teahouse stool backwards with her arms folded and her tail over the seat // playful fanged grin",
    "seen from behind in three-quarter view bending over the table with the tail raised, looking back // coy toothy smile")
add("kohaku", "robe", "White silk robe",
    "white wet-look silk robe-dress with red trim and a plunging neckline, tied by a red sash over a white satin mini nightgown, white lace-top thigh-high stockings with red ribbon bands, a gold bell collar",
    "moonlit shrine bedchamber with sliding doors and falling petals",
    "reclining on tatami propped on one elbow with her tail wrapped around her legs // sleepy teasing smile",
    "kneeling with the robe slipping from a shoulder, looking back // soft smile",
    "standing at an open sliding door with arched back, hugging her tail // gentle smile",
    "sprawled on a futon on her back with one arm above her head and the tail across her stomach // lazy seductive smile",
    "curled on her side hugging her fluffy tail like a pillow, the robe off one shoulder // sleepy intimate fanged smile")
add("kohaku", "battle", "Nine-tail warrior leotard",
    "white-and-red high-cut armoured miko leotard-dress with gold plates, a plunging neckline, side-cut hips, a short split hakama, white thigh-high stockings with red lacquer greaves and thigh straps, nine fox tails fanned behind her, a gohei wand",
    "burning torii avenue at night with fox-fire",
    "lunging with the gohei raised, tails fanned out // fierce toothy grin",
    "standing in a wide stance with the gohei across her shoulders // bold smile",
    "kneeling on one knee with the gohei planted, looking up // sly smirk",
    "seen from behind in three-quarter view with the nine tails fanned and the slit open, looking back // wicked toothy smile",
    "leaping over the burning gate with an arched back, tails spread like a halo // ferocious radiant grin")
add("kohaku", "seasonal", "New-year miko",
    "short white-and-gold new-year kimono with a deep neckline, an oversized red obi bow, a slit to the hip, white thigh-high stockings with gold bell bands, red heeled geta, a fox mask on her head",
    "new-year shrine with snow and lantern strings",
    "holding a lucky arrow and a fortune slip left blank, a wink // toothy wink",
    "leaning on a snowy lantern with one knee bent // playful smile",
    "looking back over her shoulder with her tail around her // teasing smile",
    "seen from behind in three-quarter view with the big obi bow and the tail raised, snow on her shoulders, looking back // coy toothy smile",
    "kneeling in the snow with an arched back, both hands in her hair, the kimono sliding off a shoulder // dreamy seductive gaze")

# ================================================================ Shirin
add("shirin", "base", "Caravan dancer",
    "teal-and-gold choli top with a deep plunging neckline and sheer chiffon sleeves, a bare midriff, a low-slung plum skirt with a slit to the hip, a coin belt, gold arm bands, layered gold anklets, barefoot",
    "desert caravan camp at dusk with lanterns and a patterned carpet",
    "belly-dance pose with a hip tilted and both arms in a serpentine wave // serene mysterious smile",
    "sitting on cushions with legs folded to one side, a lamp balanced on her palm // teasing half-smile",
    "reclining on a carpet propped on one elbow, one knee raised // lazy flirty smile",
    "seen from behind in three-quarter view mid-dance with the coin belt swinging and her hips tilted, looking back // mysterious knowing smile",
    "arching her back deeply with both arms in her long hair, the coins and chains shimmering // hypnotic half-lidded gaze")
add("shirin", "evening", "Oasis sheer gown",
    "sheer teal chiffon evening gown with gold embroidery, a deep plunging neckline, an open back, a slit to the hip, a coin belt, sheer gold thigh chains, gold sandals",
    "oasis terrace at night with lanterns, a pool and palms",
    "standing with her back arched and a hip tilted, one hand on the veil // mysterious smile",
    "sitting on a pool edge with legs crossed, the veil at her lips // teasing smile",
    "looking back over her shoulder with a hand in her long hair // inviting smile",
    "reclining on silk cushions on her side with the slit open and the thigh chains glinting // languid seductive smile",
    "seen from behind in three-quarter view with the open back and a raised arm trailing the veil // enigmatic knowing smile")
add("shirin", "swim", "Oasis string bikini",
    "gold-and-teal coin-trimmed string bikini with thin chain sides, a wet-look sheer chiffon wrap skirt, gold arm bands and anklets, the forehead jewel kept",
    "oasis pool with palms, a golden sunset and a striped cushioned lounger",
    "sitting on the pool edge leaning back on both hands, a leg raised // warm teasing smile",
    "standing waist-deep gathering her wet hair over one shoulder // mysterious smile",
    "lying on her side on a lounger propped on one elbow // lazy smile",
    "kneeling on the pool edge with an arched back and both hands in her wet hair, water running down // dreamy half-lidded smile",
    "seen from behind in three-quarter view climbing out of the pool, the coin trim glinting, looking back // sly smile")
add("shirin", "service", "Genie bunny",
    "high-cut teal-and-gold bunny-style leotard with a deep plunging neckline and an underbust cut-out edged in gold coins, a coin belt, thigh straps, sheer teal harem pantyhose, bunny ears with a gold chain, gold cuffs, gold heels, a brass lamp as a prop",
    "palace lounge with brass lamps, hanging lanterns and silk cushions",
    "holding the lamp out toward the viewer with a hip tilted // teasing wink",
    "leaning on a cushion pile on both forearms, legs lifted behind her // sly smile",
    "sitting on a low table with legs crossed, a hand under her chin // mysterious smirk",
    "straddling a low palace chair backwards with her chin on her folded arms // lazy teasing smile",
    "seen from behind in three-quarter view with the fluffy tail and the coin belt, looking back // hypnotic smile")
add("shirin", "robe", "Chiffon robe",
    "sheer teal wet-look chiffon robe-dress with gold trim and a plunging neckline over a teal satin mini nightgown, a gold sash, gold anklets, barefoot",
    "tent bedchamber with silk drapes, cushions and a lamp",
    "reclining on cushions propped on one elbow, one knee raised, the robe slipping off a shoulder // dreamy smile",
    "kneeling on the cushions looking back over her shoulder // soft teasing smile",
    "standing at the tent door with her back arched, holding the curtain // inviting smile",
    "sprawled on her back across the silk cushions with her hair spread and one arm trailing // languid seductive smile",
    "hugging a tasseled pillow lying on her side, the robe off one shoulder, lamplight on her skin // sleepy intimate smile")
add("shirin", "battle", "Sand-dancer war leotard",
    "gold-plated teal armoured dance leotard with a deep plunging neckline, side-cut hips, a low-slung split skirt with coin chains, thigh straps, armoured arm bands, gold greaves with bells, two curved dancing blades",
    "moonlit dunes with torches and drifting sand",
    "mid-dance spin with a blade in each hand, hair flying // bold smile",
    "kneeling on one knee with the blades crossed before her // fierce smirk",
    "standing with a hip tilted and a blade resting on her shoulder // teasing smile",
    "seen from behind in three-quarter view in a deep lunge with the coin skirt swinging, looking back // wicked knowing smile",
    "arching into a backbend with the blades crossed overhead, hair sweeping the sand // ecstatic fierce gaze")
add("shirin", "seasonal", "Festival lantern set",
    "short emerald silk festival dress with a deep neckline and an underbust cut-out edged in gold coin trim, bare shoulders, a slit to the hip, sheer gold thigh chains, a lantern-patterned veil, gold heeled sandals",
    "night bazaar with hanging lamps and spice stalls",
    "holding up a glowing lantern with one hand, a hip tilted // warm teasing smile",
    "sitting on a stall counter with legs crossed, a pomegranate in hand // playful smile",
    "looking back over her shoulder through hanging lamps // mysterious smile",
    "seen from behind in three-quarter view with the veil trailing from raised arms, looking back // knowing smile",
    "lying on a pile of bazaar carpets on her side with the pomegranate at her lips // sultry teasing smile")

# ================================================================ Zlata
add("zlata", "base", "Firebird sarafan",
    "scarlet corset sarafan with gold folk ornament, a plunging sweetheart neckline, bare shoulders, feather wing-sleeves, a short front-slit skirt over sheer red lace-top thigh-high stockings with gold garter straps, red embroidered heeled boots",
    "fairy-tale palace hall with gold columns and drifting embers",
    "standing with a hip tilted, the feather wing-sleeves spread, looking over her shoulder // regal teasing smile",
    "seated sideways on a gilded throne armrest with legs crossed, an ember candle in hand // warm half-smile",
    "leaning on a gold column with an arched back, one knee bent // confident smile",
    "seen from behind in three-quarter view with the floor-length braid swinging and the feather wing-sleeves open, looking back // imperious flirty smile",
    "reclining across the throne with her legs over one armrest and the garter straps in view, an ember in her palm // commanding seductive smile")
add("zlata", "evening", "Ember ball gown",
    "scarlet-and-gold satin ball gown with a deep plunging neckline and an open back, a skirt slit to the hip, sheer red lace-top thigh-high stockings with ruby garter charms, gold heels, the pearl-and-ruby choker kept",
    "grand ballroom with a golden chandelier and a marble staircase",
    "descending a stair with one hand on the rail and a hip tilted // regal teasing smile",
    "sitting on the stair with legs crossed, the gown spilling around her // warm smile",
    "looking back over her bare shoulder with an arched back // inviting smile",
    "reclining on a gilded chaise with the slit open and one arm over her head // languid regal smile",
    "seen from behind in three-quarter view at the top of the stair, the open back and the braid in view, looking back // queenly seductive smile")
add("zlata", "swim", "Firebird string swimsuit",
    "scarlet-and-gold high-cut swimsuit with a deep plunging neckline, an underbust cut-out with ruby clasps and thin gold side straps, a wet-look sheer red wrap skirt, a feather-trimmed sheer cape, gold anklets, the kokoshnik kept",
    "royal lake pavilion at sunset with gold lanterns and swans",
    "sitting on the pavilion steps with her feet in the water, leaning back on one hand // calm teasing smile",
    "standing waist-deep draping the braid over a shoulder // regal smile",
    "lying on her side on a gilded lounger propped on one elbow // lazy warm smile",
    "kneeling on the steps with an arched back and both hands wringing the wet braid, the cape open // dreamy half-lidded gaze",
    "seen from behind in three-quarter view stepping from the lake, the wet braid down her back, looking back // queenly knowing smile")
add("zlata", "service", "Tsarina bunny",
    "high-cut scarlet-and-gold bunny-style leotard with a deep plunging neckline, an underbust cut-out and gold folk embroidery, red bunny ears under the kokoshnik, feather cuffs, thigh straps with ruby clasps, sheer red pantyhose, red heeled boots, a tray with a blank tea set",
    "gilded tea salon with a samovar and tall windows",
    "carrying the tray on one hand with a hip tilted // regal teasing smile",
    "leaning on a table with both forearms and one leg lifted behind her // sly smile",
    "sitting on the table edge with legs crossed // warm smirk",
    "straddling a gilded chair backwards with her chin on her folded arms // lazy regal smile",
    "seen from behind in three-quarter view with the fluffy tail and the braid, looking back over her shoulder // commanding seductive smirk")
add("zlata", "robe", "Firebird silk robe",
    "scarlet wet-look silk robe-dress with gold folk trim and a plunging neckline over a gold satin mini nightgown, sheer red lace-top thigh-high stockings, feather-trimmed slippers, the braid over one shoulder",
    "royal bedchamber with a canopy, candles and embers",
    "reclining on the bed propped on one elbow with the braid over her arm // dreamy warm smile",
    "sitting at a gilded vanity looking back over her shoulder // teasing smile",
    "standing at a tall window with an arched back // soft inviting smile",
    "sprawled across the canopy bed on her back with the braid across her chest and one arm trailing // languid seductive smile",
    "hugging a feather pillow lying on her side, the robe off one shoulder, candlelight on her skin // sleepy intimate smile")
add("zlata", "battle", "Firebird warrior leotard",
    "red-and-gold high-cut plate-and-feather armour leotard-dress with a plunging neckline, side-cut hips, a short armoured skirt, thigh straps with ruby clasps, scale thigh-high stockings with ruby garter bands, red greaves, a feathered spear, wing-cape of fire feathers",
    "burning battlement at dusk with embers and firebird shadows",
    "lunging with the feathered spear pointed forward, the wing-cape flaring // fierce regal smile",
    "standing in a wide stance with the spear planted, a hand on her hip // bold smile",
    "kneeling on one knee with the spear planted // proud smirk",
    "seen from behind in three-quarter view with the wing-cape spread and the braid whipping, looking back // imperious fierce smile",
    "soaring with the wing-cape fully spread and an arched back, the spear overhead, embers swirling // triumphant radiant gaze")
add("zlata", "seasonal", "Winter-festival sarafan",
    "short white-and-scarlet winter sarafan with white fur trim and gold ornament, a deep sweetheart neckline, bare shoulders, an underbust cut-out, a fur-trimmed shawl, white thigh-high stockings with red ribbons and thigh straps, red heeled boots, a fur kokoshnik",
    "snowy festival square with a decorated tree and lantern strings",
    "holding a glowing ember lantern, looking back over her shoulder // warm teasing smile",
    "sitting on a sleigh seat with legs crossed, a steaming cup in hand // cozy smile",
    "twirling with the shawl flaring in snow // bright laugh",
    "seen from behind in three-quarter view with the shawl sliding off one shoulder and snow in the braid, looking back // queenly flirty smile",
    "lying back on a fur-draped sleigh with one leg raised and an ember lantern held up // sultry warm smile")


# ---------------------------------------------------------------------------------------------------------------------
# Round 3 (owner feedback): LEG-focus (pose D) and BUST-focus (pose E) shot types for every outfit, so each outfit has
# poses A..E (5 search candidates) plus the 2 hero splash poses.  Built from slot templates and per-heroine props.
# Camera stays at eye, hip or knee level: never below the hem, never up a skirt.
# ---------------------------------------------------------------------------------------------------------------------
PROPS = {  # band = the stocking / thigh detail, seat = furniture, hug = what she hugs, wpn = battle prop, neck = neckline term, mood = smile adjective
    "mc":      dict(band="lace stocking top and garter band", seat="the mahjong table", hug="a floral cushion", wpn="the war fan", neck="keyhole front", mood="playful"),
    "rin":     dict(band="lace stocking top and garter strap", seat="the library table", hug="a big book", wpn="the tea whisk", neck="plunging neckline", mood="knowing"),
    "hana":    dict(band="striped sock top", seat="the bench", hug="a gym towel", wpn="the baton", neck="deep neckline", mood="cheeky"),
    "yue":     dict(band="lace stocking top and pearl garter strap", seat="the moon-cushion divan", hug="a moon-shaped pillow", wpn="the moon glaive", neck="plunging V front", mood="serene teasing"),
    "nova":    dict(band="fishnet top and neon garter strap", seat="the console", hug="a cat-shaped pillow", wpn="the helmet", neck="sweetheart neckline", mood="smug"),
    "tsubame": dict(band="fishnet top and crimson ribbon band", seat="the crate", hug="a bolster pillow", wpn="the kunai", neck="plunging neckline", mood="cool sly"),
    "miel":    dict(band="ribbon-bow stocking band", seat="the marble counter", hug="a big cushion", wpn="the piping-bag lance", neck="plunging ruffled neckline", mood="sweet"),
    "kohaku":  dict(band="ribbon-and-bell thigh band", seat="the shrine veranda", hug="her fluffy tail", wpn="the gohei", neck="plunging neckline", mood="toothy playful"),
    "shirin":  dict(band="gold thigh chains", seat="the silk cushions", hug="a tasseled pillow", wpn="the curved blades", neck="plunging choli neckline", mood="mysterious"),
    "zlata":   dict(band="lace stocking top and gold garter strap", seat="the gilded throne", hug="a feather pillow", wpn="the feathered spear", neck="sweetheart neckline", mood="regal"),
}
LEG_BUST = {  # slot -> (leg-focus template, bust-focus template); each is "pose // expression // framing code"
    "base":     ("standing with one long leg stretched forward, a hand on her hip, the {band} in view // {mood} smirk // L",
                 "leaning forward with both hands on her knees toward the viewer, the {neck} in front // {mood} smile // F"),
    "evening":  ("perched on {seat} with one leg stretched out and the other drawn up, the {band} in view // {mood} smile // T",
                 "leaning forward on her forearms over {seat}, hugging {hug} to her chest, looking up // {mood} smile // F"),
    "swim":     ("lying on her side with one leg stretched out and the other drawn up, wet skin glowing, the thigh in view // {mood} smile // T",
                 "kneeling and leaning forward with both hands on the ground, hair falling forward, a wink // {mood} wink // F"),
    "service":  ("sitting on {seat} with her legs crossed and draped over the edge, the thigh strap in view // {mood} smile // S",
                 "leaning forward with both hands on {seat}, the {neck} toward the viewer, ears tilted // {mood} wink // F"),
    "robe":     ("sitting on the bed edge with one leg stretched out, the robe parted over the {band} // {mood} half-lidded smile // B",
                 "kneeling on the bed hugging {hug} to her chest, leaning forward with an arched back // {mood} sleepy smile // F"),
    "battle":   ("striding forward in a low knee-level view, the armoured stockings and thigh straps elongating her legs // {mood} grin // L",
                 "leaning forward on {wpn} with both hands, bust-forward toward the viewer // {mood} smile // F"),
    "seasonal": ("sitting with one leg lifted and crossed over the other, the {band} in view // {mood} smile // T",
                 "leaning forward with both hands on her knees, a playful look up, the {neck} in front // {mood} laugh // F"),
}
for _hk, _d in W.items():
    for _slot, _o in _d.items():
        _t = LEG_BUST[_slot]
        for _tpl in _t:
            _o["poses"].append(_p(_tpl.format(**PROPS[_hk])))


def outfit(hk: str, slot: str) -> dict:
    return W[hk][slot]


def check() -> None:
    assert set(W) == {"mc", "rin", "hana", "yue", "nova", "tsubame", "miel", "kohaku", "shirin", "zlata"} == set(HEIGHTS) == set(FIGURE)
    for hk, d in W.items():
        assert list(d) == SLOTS, (hk, list(d))
        for s, o in d.items():
            assert len(o["poses"]) == 5 and len(o["hero"]) == 2 and all(len(p) == 3 for p in o["poses"] + o["hero"]), (hk, s)
    for hk, b in HEIGHTS.items():
        assert HEADS_MIN <= b["heads"] <= HEADS_MAX, hk


check()
