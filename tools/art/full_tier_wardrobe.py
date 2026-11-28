"""Tier FULL wardrobe tables (P50b): 10 heroines x 7 outfits, each with 3 pose/expression options.

Spec: design/ART_TIER_FULL.md.  Used by tools/art/build_art_batches.py (H0 / H1 / H2) and quoted in the spec appendix.
Vocabulary is fashion / pin-up only (no 'sexy', 'cleavage', 'nude', 'lingerie'); hard lines are in the spec section 2.
Outfit slots (the same 7 for everyone so the game can sell a predictable wardrobe):
  base, evening, swim, service (bunny / maid / bartender), robe (sleepwear robe-dress), battle (battle / idol / cosplay), seasonal
MC is special: her two canonical Full outfits (owner mock-ups 12-15) fill the base and evening slots (night qipao, tea cheongsam).
Each pose entry is (pose, expression).  Settings are used by the wardrobe batch (H2) only.
"""
from __future__ import annotations

SLOTS = ["base", "evening", "swim", "service", "robe", "battle", "seasonal"]

# {hk: {slot: dict(name, outfit, setting, poses=[(pose, expr) x3])}}
W: dict[str, dict[str, dict]] = {}


def add(hk, slot, name, outfit, setting, p1, p2, p3):
    W.setdefault(hk, {})[slot] = dict(name=name, outfit=outfit, setting=setting, poses=[p1, p2, p3])


# ---------------------------------------------------------------- MC (Mahjong-chan)
add("mc", "base", "Night dragon qipao",
    "black-and-gold long qipao with gold dragon embroidery, a plunging keyhole front with a gold frog-button collar, bare shoulders, black lace detached arm sleeves, a side slit up to the hip, sheer black thigh-high stockings with wide lace tops, black stiletto heels",
    "night mahjong salon with chandeliers, black lacquer and red velvet chairs, drifting petals",
    ("standing with her weight on one leg, one hand on her hip and the other raised into her hair, the stocking top visible through the slit", "playful teasing smile"),
    ("perched on the edge of the mahjong table with her legs crossed, looking back at the viewer over her shoulder", "confident smile"),
    ("leaning back against a lacquer pillar with an arched back, one knee bent, one hand touching her collar", "half-lidded flirty smile"))
add("mc", "evening", "Tea floral cheongsam",
    "white-and-red floral cheongsam with gold trim, a heart-shaped chest cutout under a pink bow, bare shoulders, white detached wide sleeves with red knotted ribbons, a red sash with a flower brooch, a side slit up to the hip, white thigh-high stockings with a red ribbon-and-bell garter band, red high heels",
    "warm night tea house with paper lanterns, a round moon window and blossoming branches",
    ("leaning over the mahjong table on one hand, holding up a single blank tile in the other hand, a wink", "laughing open smile with a wink"),
    ("reclining sideways on a cushioned daybed propped on one elbow, one knee raised, holding a tea bowl", "warm teasing smile"),
    ("kneeling on a cushion pouring tea, glancing up at the viewer", "sly sidelong smile"))
add("mc", "swim", "Blossom bikini",
    "pink-and-white halter bikini with jade-green ribbon ties at the hips, an open white sheer shirt tied at the waist, a gold anklet, a straw sun hat with a pink ribbon",
    "sunset beach with a striped towel, soft waves and pink petals in the breeze",
    ("kneeling on the towel with both fists under her chin, leaning toward the viewer, a wink", "bright laughing wink"),
    ("standing in shallow water with both arms stretched above her head, a hip tilted", "joyful open-mouth laugh"),
    ("sitting on the towel leaning back on both hands, one knee raised, hair blowing in the breeze", "relaxed teasing smile"))
add("mc", "service", "Casino bunny leotard",
    "white-and-pink floral cheongsam-style bunny leotard with gold trim and a heart-shaped chest cutout, a pink bow collar, white bunny-ear headband with a fluffy tail, white wrist cuffs, sheer pale pantyhose, white stiletto heels",
    "grand casino-style mahjong hall with chandeliers, round felt tables and red velvet chairs",
    ("standing with one hand on her hip and a fan of blank mahjong tiles held beside her face, winking", "playful wink with a laugh"),
    ("leaning forward on a felt table with both forearms on it, one leg lifted behind her", "sly smile, eyes on the viewer"),
    ("standing in profile with an arched back and a hip tilted, glancing back over her shoulder", "confident teasing smile"))
add("mc", "robe", "Moonlit silk robe-dress",
    "blush-pink silk robe-dress with a plunging neckline tied by a satin sash over a satin mini dress, white lace-top thigh-high stockings, pink satin mules, the jade hairpins and cuffs kept",
    "moonlit bedroom with sheer curtains, a canopy bed and a tea tray",
    ("reclining on a silk bed propped on one elbow, one leg bent, the robe falling off one shoulder", "dreamy flirty smile"),
    ("sitting at a vanity mirror looking back over her shoulder, a hand brushing her hair", "soft teasing smile"),
    ("standing at a moonlit window with one hand holding the robe edge, arched back", "gentle inviting smile"))
add("mc", "battle", "Jade war-qipao",
    "jade-green lamellar-armour cheongsam with gold shoulder plates, a plunging keyhole front, a short armoured skirt, scale-pattern thigh-high stockings, gold greaves, a large folding war fan with a tile pattern",
    "misty bamboo courtyard at dusk with floating lanterns",
    ("lunging forward with the war fan opened toward the viewer, hair flying", "fierce confident grin"),
    ("kneeling on one knee with the fan planted like a standard, looking up at the viewer", "smirking challenge"),
    ("standing in a wide stance with the fan over one shoulder, a hand on her hip", "bold laughing smile"))
add("mc", "seasonal", "Winter festival mini-qipao",
    "red velvet mini-cheongsam with white fur trim and gold knots, bare shoulders, white fur cuffs, white thigh-high stockings with red bows, red heeled boots, a fur-trimmed cape",
    "snowy night festival street with lanterns and gentle snowfall",
    ("twirling with the cape flaring, one hand holding a lantern", "bright laughing smile"),
    ("leaning against a lantern post with one knee bent, blowing a kiss", "playful kiss"),
    ("sitting on a snowy bench with legs crossed, holding a steaming cup", "cozy teasing smile"))

# ---------------------------------------------------------------- Rin
add("rin", "base", "Phoenix cheongsam",
    "sleeveless black cheongsam with gold-green phoenix embroidery, a deep plunging neckline, an open back, a skirt slit up to the hip, sheer black thigh-high stockings with lace tops and garter straps clipped to the hem, black stiletto heels, a jade bangle",
    "tea library with floor-to-ceiling shelves, a rolling ladder and cherry blossom branches",
    ("leaning against a bookshelf with one knee bent, sipping tea from a celadon cup, glancing at the viewer", "teasing half-smile"),
    ("one hand adjusting her glasses, the other on her hip, hip tilted", "knowing smirk"),
    ("standing on the rolling ladder reaching for a book, looking back over her shoulder", "amused smile"))
add("rin", "evening", "Knit tea dress",
    "off-shoulder cable-knit mini sweater dress in forest green with an open side, lace-top black thigh-high stockings, black stiletto heels, a jade bangle",
    "cozy library window seat with a tea set and soft rain on the glass",
    ("leaning on a shelf with one leg lifted behind her, sipping tea", "gentle teasing smile"),
    ("sitting sideways on a window seat with legs crossed, a book on her knee", "warm half-smile"),
    ("reclining on a chaise with her braid over one shoulder, holding the cup", "sleepy flirty smile"))
add("rin", "swim", "Jade swimsuit",
    "dark-green one-piece swimsuit with a deep plunging neckline and side cut-outs bordered in gold trim, a sheer green wrap skirt, gold sandals, the thin gold glasses kept",
    "private hot-spring terrace with a stone pool, steam and lanterns at dusk",
    ("sitting on the pool edge with her feet in the water, leaning back on one hand", "calm teasing smile"),
    ("standing waist-deep in the pool wringing her braid, glancing over her shoulder", "soft smile"),
    ("lying on her side on a bamboo lounger propped on one elbow, a tea cup beside her", "lazy flirty smile"))
add("rin", "service", "Bunny tea-server tailcoat",
    "black bunny-style tailcoat leotard with gold-trimmed lapels, a deep plunging neckline, a green bow tie, black bunny-ear headband with a white tail, white gloves, sheer black pantyhose, black heels, a silver teapot",
    "grand tea hall with red velvet drapes, marble floor and an armillary sphere",
    ("bending slightly forward presenting a silver teapot on one hand, tilting her head", "gracious teasing smile"),
    ("standing with the teapot on a tray and a hand on her hip, a hip tilted", "composed smirk"),
    ("sitting on the arm of a velvet sofa with crossed legs, pouring tea", "relaxed flirty smile"))
add("rin", "robe", "Jade silk robe",
    "emerald silk robe-dress with a plunging neckline and a satin sash over a green satin mini dress, black lace-top thigh-high stockings, jade earrings, the thin gold glasses kept",
    "night study with a lamp, scrolls and a teapot on a low table",
    ("sitting on a low sofa with one leg crossed over the other, the robe slipping from one shoulder, holding a cup", "soft teasing smile"),
    ("standing at a bookshelf with her back arched, looking over her shoulder", "amused smile"),
    ("reclining on a daybed with a book on her chest, one knee raised", "sleepy half-smile"))
add("rin", "battle", "Tea-master combat dress",
    "black fitted high-slit combat cheongsam with green piping, shoulder plates and bracers, a plunging neckline, scale-pattern thigh-high stockings, black boots, a kunai-shaped tea whisk at her belt",
    "rain-wet tiled rooftop at night with warm lantern light",
    ("crouching on the ridge with one hand on the tiles, glancing sideways", "cool smirk"),
    ("standing with one hand on her hip and the other holding a tea bowl, a hip tilted", "calm teasing smile"),
    ("leaning back on a chimney with one leg bent, tying her braid", "knowing half-smile"))
add("rin", "seasonal", "Spring festival yukata",
    "short sage-green yukata with cherry-blossom print, an off-shoulder neckline, a wide obi with a jade charm, a slit to the hip, white thigh-high socks with green ribbon bands, wooden geta",
    "spring festival stalls with lanterns and falling cherry petals",
    ("holding a paper fan against her lips, a hip tilted", "elegant teasing smile"),
    ("sitting on a stone lantern base with legs crossed, a sweet dumpling stick in hand", "playful smile"),
    ("looking back over her shoulder under blossom branches", "soft flirty smile"))

# ---------------------------------------------------------------- Hana
add("hana", "base", "Pin-up track set",
    "orange-striped sports crop top with a deep neckline and bare midriff, short orange-striped running shorts, an off-shoulder pink track jacket sliding down one shoulder, white over-the-knee striped socks with a small star, white-orange sneakers, sport wristband",
    "sunset running track with floodlights and a rust-red lane",
    ("leaning forward with hands on her knees, pointing at the viewer, a wink", "competitive grin with a wink"),
    ("standing on one leg with the other lifted behind her, waving, a hand on her hip", "open-mouth grin"),
    ("kneeling with arms stretched high above her head, back arched", "laughing"))
add("hana", "evening", "Gala backless dress",
    "orange satin mini dress with a deep plunging neckline and an open back, a high slit, sunflower-yellow ribbon straps, sheer tan thigh-high stockings, white-orange heeled sandals, a sport wristband kept",
    "gala hall with warm chandeliers and a balcony of sunflowers",
    ("one hand on her hip, the other pushing back her hair, a hip tilted", "bright confident smile"),
    ("sitting on a balustrade with legs crossed, laughing, looking at the viewer", "teasing laugh"),
    ("looking back over her bare shoulder with an arched back", "playful smile"))
add("hana", "swim", "Sunflower bikini",
    "yellow tie-side bikini with an off-shoulder sheer white shirt tied at the waist, a wide straw sun hat with a yellow ribbon, a sport wristband",
    "sunset beach with a striped towel and a driftwood log",
    ("kneeling on the towel with both fists under her chin, a wink", "beaming wink"),
    ("squatting in the sand scooping a seashell, glancing up at the viewer, knees together", "cheerful grin"),
    ("lying on her side on the towel propped on one elbow, one knee bent", "relaxed laughing smile"))
add("hana", "service", "Bartender bunny",
    "orange bunny-style leotard with white stripe trim, a black bow tie collar, white cuffs, a bunny-ear headband, sheer tan pantyhose, white platform sneakers, a shaker held as a prop",
    "neon-lit sports bar with trophies and a counter",
    ("leaning over the counter on both elbows, a wink", "cheeky wink"),
    ("shaking a cocktail shaker above her shoulder, hip tilted", "bright grin"),
    ("sitting on a bar stool with her legs crossed, a hand under her chin", "teasing smile"))
add("hana", "robe", "Locker-room satin robe",
    "short orange satin robe with white piping tied loosely at the waist over a sports bodysuit, sheer tan thigh-high stockings, fluffy slippers",
    "morning gym lounge with sunlight, a bench and a towel rack",
    ("sitting on a bench with one leg stretched out, towel around her neck, leaning back", "sleepy playful smile"),
    ("stretching with both arms overhead, the robe slipping off one shoulder", "yawning laugh"),
    ("kneeling on the bench looking back over her shoulder", "teasing smile"))
add("hana", "battle", "Relay racer",
    "tight orange-and-white racing bodysuit with a zip neckline pulled low and cut-out sides covered by mesh, thigh-high compression socks, spiked track shoes, a flowing relay baton ribbon",
    "stadium at night under floodlights with a glowing finish line",
    ("sprinting start crouch with one hand on the track and a glance at the viewer", "fierce grin"),
    ("standing with one hand on her hip holding up a baton, a hip tilted", "triumphant smile"),
    ("leaning against a hurdle with legs crossed, wiping her forehead", "tired teasing smile"))
add("hana", "seasonal", "Winter-rink set",
    "short orange puffer jacket worn off one shoulder over a white crop sweater, a flared white skater mini skirt, white thigh-high stockings with orange stripes, white ice skates, a knitted headband",
    "ice rink under string lights with falling snow",
    ("spinning on one skate with one leg lifted behind her, arms out", "laughing"),
    ("kneeling to tie a skate, looking up at the viewer", "playful grin"),
    ("leaning back on the rink barrier with legs crossed", "cheeky smile"))

# ---------------------------------------------------------------- Yue
add("yue", "base", "Moon-queen hanfu",
    "lavender silk hanfu-style gown, off-the-shoulder with a deep plunging V front, sheer layered sleeves, gold moon-and-star embroidery, sash-cinched waist, skirt slit up to the hip, white lace-top thigh-high stockings with pearl garter straps, lavender high heels",
    "moonlit palace terrace above a sea of clouds, an enormous full moon",
    ("reclining on a moon-cushion divan with one leg crossed over the other, an arm extended offering a blank jade tile", "serene teasing smile"),
    ("seated sideways on a throne armrest with legs crossed, the moon-phase fan against her lips", "amused teasing smile"),
    ("standing in an S-curve with one hip tilted, one hand held out, the fan on her hip", "slow inviting half-smile"))
add("yue", "evening", "Sheer window robe-gown",
    "sheer layered lavender robe-dress with a deep plunging neckline and a crescent sash over a lavender satin mini dress, lace-top thigh-high stockings with crystal garter charms, silver heels",
    "moonlit window of a palace bedchamber with sheer curtains",
    ("reclining against the window frame with one arm along the sill, the fan held by her cheek", "serene teasing smile"),
    ("standing at the window with one hand drawing the curtain, arched back", "soft inviting smile"),
    ("sitting on the sill with one knee raised, looking back at the moon", "dreamy half-smile"))
add("yue", "swim", "Moon-lagoon swimsuit",
    "lavender halter bikini with gold crescent rings and chain details, a sheer lavender sarong slit to the hip, gold anklets, a crescent forehead ornament kept",
    "moonlit lagoon with lotus flowers, a stone terrace and lanterns",
    ("sitting on the terrace edge with her feet in the water, leaning back on both hands", "calm teasing smile"),
    ("standing waist-deep in the water gathering her long hair over one shoulder", "serene smile"),
    ("lying on a floating cushion on her side, the fan trailing in the water", "lazy flirty smile"))
add("yue", "service", "Moon bunny",
    "lavender bunny-style leotard with gold moon embroidery and a deep plunging neckline, long lavender bunny ears over her horns, a crescent bow tie, sheer white pantyhose, lavender stiletto heels, white cuffs",
    "grand moon-pavilion hall with silver lamps and round tea tables",
    ("standing with a tray of blank jade tiles on one hand, a hip tilted", "elegant teasing smile"),
    ("leaning forward on a table with both forearms on it, one leg lifted behind her", "sly smile"),
    ("sitting on a table edge with legs crossed, the fan at her lips", "amused smile"))
add("yue", "robe", "Pearl silk robe",
    "pearl-white silk robe-dress with a plunging neckline and a crescent sash, lavender satin mini dress under it, lace-top thigh-high stockings, a gold crescent forehead ornament kept",
    "canopy bed in a moonlit chamber with petals on the sheets",
    ("reclining on the bed propped on one elbow, one leg bent, the robe slipping from a shoulder", "dreamy flirty smile"),
    ("kneeling on the bed with a hand in her hair, looking at the viewer", "inviting smile"),
    ("sitting on the bed edge with legs crossed, a fan covering half her smile", "teasing half-smile"))
add("yue", "battle", "Dragon-scale armour",
    "purple dragon-scale armour dress with gold filigree plates, a plunging keyhole front with a gem pendant, a short layered armoured skirt, scale thigh-high stockings with crescent gold garter bands, scale gloves, a moon glaive",
    "misty mountain temple stairs at dusk with moon banners",
    ("standing in a wide stance holding the moon glaive across her body", "confident smirk"),
    ("lunging with the glaive swept back, hair flying", "fierce smile"),
    ("kneeling on one knee with the glaive planted, looking up", "regal teasing smile"))
add("yue", "seasonal", "Moon-festival gown",
    "short white-and-lavender festival hanfu with a deep neckline, a rabbit-motif sash, off-shoulder sheer sleeves, white thigh-high stockings with lavender ribbons, silver heels, a lantern held in one hand",
    "mid-autumn lantern garden with a huge moon and mooncake stalls",
    ("holding up a glowing lantern, looking back over her shoulder", "gentle teasing smile"),
    ("sitting on a stone bench with legs crossed, a mooncake in her fingers", "warm smile"),
    ("leaning against a lantern pole with one knee bent", "serene flirty smile"))

# ---------------------------------------------------------------- Nova
add("nova", "base", "Neon idol corset set",
    "strapless black corset bodice with neon cyan piping and a plunging sweetheart neckline, detached puffed black sleeves with neon trim, layered holographic tiered mini skirt with a big pink cat-badge bow at the hip, black fishnet thigh-highs with a neon cyan garter strap, black thigh-high lace-up platform boots with cyan laces",
    "night server room with glowing racks and a holographic panel",
    ("singing into a microphone, pointing at the viewer, one leg stepped forward, a wink", "wink with a bright grin"),
    ("perched on a server rack with her boots crossed, tapping her headphones", "confident smirk"),
    ("leaning forward with a hip tilt, a glowing hologram card between two fingers", "teasing smirk"))
add("nova", "evening", "Latex catsuit",
    "glossy black latex bodysuit with a zipper neckline pulled low and neon cyan piping, a holographic cropped jacket with a hood and cat ears, black thigh-high lace-up platform boots with cyan laces, a ring choker",
    "server-room corridor with fog and glowing racks",
    ("squatting in a three-quarter view with knees together, one hand on her knee and a claw gesture, a wink", "wink with a grin"),
    ("standing with her back arched and a hip tilted, the jacket slipping off one shoulder", "cool smirk"),
    ("sitting sideways on a console with one boot raised on the edge", "teasing smirk"))
add("nova", "swim", "Neon bikini",
    "black-and-neon-cyan strappy bikini with a pink cat-badge clasp, an open holographic mesh hoodie, black thigh-high sandals with cyan straps, cat-ear headphones kept",
    "rooftop pool at night with neon city lights and glowing lounge beds",
    ("sitting on the pool edge with one leg bent, leaning back on both hands", "playful smirk"),
    ("lying on her side on a glowing lounger propped on one elbow", "teasing smile"),
    ("standing with arms stretched overhead in a stretch, a wink", "bright wink"))
add("nova", "service", "Cyber maid",
    "short black-and-pink cyber maid dress with a deep plunging neckline, a frilled holographic apron with a cat-badge bow, detached sleeves, black fishnet thigh-highs with a cyan garter strap, black platform heels, a headband over her cat ears",
    "neon cat-cafe with glowing menus left blank, small round tables and pink lights",
    ("holding a tray with one hand and a finger at her lips, a hip tilted", "teasing wink"),
    ("leaning over a table toward the viewer with a hand on her hip", "smug grin"),
    ("sitting on a counter with legs crossed, tapping her headphones", "confident smirk"))
add("nova", "robe", "Hologram robe",
    "translucent iridescent robe-dress over a black satin mini dress with a plunging neckline, a neon cyan sash, black lace-top thigh-high stockings, fluffy cat-ear slippers",
    "dark apartment with a glowing monitor wall and a rain-streaked window",
    ("reclining on a beanbag with a laptop on her knees, one leg raised", "sleepy smirk"),
    ("kneeling on a chair back looking over her shoulder at the screens", "teasing smile"),
    ("standing at the window with her back arched, hugging a cup", "soft smirk"))
add("nova", "battle", "Street-racer suit",
    "tight black-and-cyan racing bodysuit with a zipper neckline pulled low, thigh-high armoured boots, a cropped racing jacket with neon piping, a visor pushed up on her forehead, race gloves",
    "neon-lit night garage with a glowing motorbike",
    ("leaning back against the bike with one knee bent, holding a helmet at her hip", "cool smirk"),
    ("squatting by the bike tightening a strap, knees together, glancing sideways", "sly grin"),
    ("standing with a hip tilt and a thumbs-up, a wink", "playful wink"))
add("nova", "seasonal", "Rooftop sneaker set",
    "black crop top with a deep neckline, neon cyan piping and a navel stud, an iridescent holographic mini skirt, black-and-cyan striped thigh-high socks, chunky white-and-pink platform sneakers, an off-shoulder cropped jacket",
    "rooftop at dusk with a water tower, city haze and pink clouds",
    ("kneeling with both arms stretched high above her head, a wink", "open-mouth grin with a wink"),
    ("standing with legs crossed at the ankle and arms overhead, back arched", "laughing"),
    ("sitting on the parapet with one leg swinging, looking back", "teasing smile"))

# ---------------------------------------------------------------- Tsubame
add("tsubame", "base", "Rooftop kunoichi",
    "short indigo wrap kimono-style dress with a deep plunging neckline and open sides, a wide obi with crimson rope, fishnet thigh-high stockings with crimson ribbon thigh bands, black split-toe tabi boots, fishnet arm guards, a long crimson scarf",
    "rain-wet tiled rooftop at night above a canal town with lanterns",
    ("sitting on the roof ridge with knees together, both arms raised tying her ponytail", "cool unimpressed smirk"),
    ("crouching on the ridge with one hand on the tiles, looking back over her shoulder", "sly half-smile"),
    ("leaning on a chimney with one leg bent, holding a sealed letter", "teasing smile"))
add("tsubame", "evening", "Crimson slit dress",
    "black-and-crimson satin evening dress with a deep plunging neckline, an open back and a slit to the hip, sheer black lace-top thigh-high stockings with a crimson garter, black stiletto heels, the crimson scarf worn as a stole",
    "moonlit pagoda balcony with a lantern string",
    ("standing with one hand on the railing and her back arched, glancing over her shoulder", "cool teasing smile"),
    ("sitting on the railing with legs crossed, the scarf trailing", "amused smirk"),
    ("leaning against a pillar with a hand on her hip, a hip tilted", "confident smile"))
add("tsubame", "swim", "Swallow swimsuit",
    "indigo-and-crimson high-cut one-piece swimsuit with a deep plunging neckline and obi-style waist wrap, a sheer crimson sarong, fishnet arm guards, a swallow anklet",
    "hidden mountain hot spring at dusk with steam and lanterns",
    ("sitting on a rock with her feet in the water, leaning back on one hand", "calm teasing smile"),
    ("standing waist-deep wringing her long ponytail, glancing sideways", "sly half-smile"),
    ("lying on her side on a flat rock propped on one elbow", "lazy smirk"))
add("tsubame", "service", "Courier bunny",
    "black bunny-style leotard with a crimson obi sash and a messenger pouch, a deep plunging neckline, black bunny ears with a swallow pin, sheer black pantyhose, split-toe boots, white cuffs",
    "night market alley with lanterns and parcel stacks",
    ("standing with a parcel on one hip and a hand on the other, a hip tilted", "cool smirk"),
    ("leaning on a crate with one leg lifted behind her", "teasing half-smile"),
    ("sitting on a parcel stack with legs crossed, tapping the sealed letter on her lips", "amused smile"))
add("tsubame", "robe", "Night kimono robe",
    "loose dark-indigo silk robe-dress with a plunging neckline tied by a crimson obi over a satin mini dress, fishnet thigh-highs with ribbon bands, the swallow hairpin kept",
    "paper-screen bedchamber with a single lantern and rain on the roof",
    ("reclining on tatami propped on one elbow, one knee raised", "sleepy teasing smile"),
    ("kneeling at a low table pouring sake-free tea, glancing up", "sly smile"),
    ("standing at a sliding door with her back arched, looking back", "soft smirk"))
add("tsubame", "battle", "Shadow courier armour",
    "black fitted shinobi bodysuit with a deep plunging mesh neckline, crimson armoured shoulder guards, a short split skirt, fishnet thigh-high stockings, tabi boots with crimson ties, a kunai belt",
    "tiled rooftop in a storm with lightning over the town",
    ("crouching on one knee on the ridge with a kunai between her fingers", "fierce smirk"),
    ("leaping between roofs with the scarf streaming", "bold grin"),
    ("standing in a wide stance with arms crossed, the scarf blowing", "cool half-smile"))
add("tsubame", "seasonal", "Summer festival yukata",
    "short crimson yukata with swallow print, an off-shoulder neckline, a black obi with a bell, a slit to the hip, black thigh-high socks with red ribbon bands, wooden geta",
    "summer festival with goldfish stalls and fireworks",
    ("holding a goldfish bag and a hand fan, a hip tilted", "playful smile"),
    ("sitting on a stone step with legs crossed, a candy apple in hand", "teasing smile"),
    ("looking back over her shoulder at fireworks, arched back", "soft smirk"))

# ---------------------------------------------------------------- Miel
add("miel", "base", "Patisserie corset set",
    "cream off-shoulder puff-sleeve blouse with a plunging ruffled neckline, a fitted rose corset, a short frilled apron mini skirt with ribbons, brown thigh-high stockings with ribbon bow bands, rose high heels with bows",
    "warm bakery kitchen with a brick oven, a marble counter and macaron trays",
    ("leaning over the counter on one arm, holding out a spoon of cream toward the viewer, a wink", "tongue-out wink with a laugh"),
    ("standing with a whisk raised and a hip tilted, a dab of cream on her cheek", "playful grin"),
    ("sitting on the counter edge with legs crossed, holding a macaron to her lips", "sweet teasing smile"))
add("miel", "evening", "Dessert-gala dress",
    "rose-pink satin off-shoulder mini ball dress with a deep sweetheart neckline, a corset bodice with ribbons, a frilled tulle skirt, cream lace-top thigh-high stockings with bow bands, cream heels",
    "candle-lit dessert gala with tiered cake towers and flowers",
    ("holding a strawberry tart toward the viewer, leaning forward, a hip tilted", "sweet teasing smile"),
    ("sitting on a banquet table edge with legs crossed, licking cream from a finger", "playful smile"),
    ("looking back over her shoulder with an arched back", "soft flirty smile"))
add("miel", "swim", "Strawberry bikini",
    "pink strawberry-print bikini with cream ribbon ties and a sheer white frilled shirt tied at the waist, a straw hat with a white bow, a pearl anklet",
    "pastel seaside terrace with a picnic basket and a striped towel",
    ("kneeling on the towel with a hand held up holding a strawberry, a wink", "happy tongue-out wink"),
    ("lying on her stomach propped on both elbows, legs lifted and crossed behind her", "sweet grin"),
    ("standing in shallow water holding her hat on, a hip tilted", "bright laugh"))
add("miel", "service", "Cafe maid",
    "short caramel-and-cream maid dress with a deep plunging neckline, a frilled apron, puff sleeves, a lace headband with her bow kept, cream thigh-high stockings with lace tops and ribbon bands, rose heels",
    "pink-and-gold patisserie cafe with glass cake displays",
    ("balancing a tray of macarons on one hand, a hip tilted, a wink", "wink with a laugh"),
    ("leaning over a table toward the viewer, resting on both hands", "sugary teasing smile"),
    ("sitting on a stool with legs crossed, hugging the tray", "shy sweet smile"))
add("miel", "robe", "Honey satin robe",
    "honey-gold satin robe-dress with a plunging neckline and a cream sash over a cream satin mini dress, lace-top thigh-high stockings with ribbons, fluffy slippers, the macaron hair clip kept",
    "morning kitchen loft with sunlight, flour dust and a quilt",
    ("reclining on a cushioned window seat propped on one elbow, one knee raised, a cup in hand", "sleepy sweet smile"),
    ("stretching with arms overhead, an arched back, the robe slipping from a shoulder", "yawning laugh"),
    ("kneeling on the bed looking back over her shoulder", "teasing smile"))
add("miel", "battle", "Confection-knight",
    "rose-and-cream armoured corset dress with whisk-shaped pauldrons and a plunging neckline, a short skirt with sugar-lace trim, thigh-high armoured stockings with bows, heeled boots, a giant piping-bag lance",
    "candy-castle courtyard with sugar towers and floating macarons",
    ("lunging forward with the piping-bag lance pointed at the viewer", "playful fierce grin"),
    ("standing with the lance on her shoulder and a hand on her hip", "bold wink"),
    ("kneeling on one knee with the lance planted", "proud sweet smile"))
add("miel", "seasonal", "Winter bakery",
    "red-and-cream velvet mini dress with white fur trim, a bare-shoulder neckline, a frilled apron, a Christmas-style fur-trimmed cape, white thigh-high stockings with red bows, red heels",
    "snowy bakery window with gingerbread and string lights",
    ("holding a gingerbread tray, leaning toward the viewer, a wink", "festive wink"),
    ("sitting on a flour sack with legs crossed, a candy cane at her lips", "teasing smile"),
    ("twirling with the cape flaring", "bright laugh"))

# ---------------------------------------------------------------- Kohaku
add("kohaku", "base", "Shrine-maiden festival",
    "white shrine-maiden top with a deep plunging neckline, detached wide sleeves and bare shoulders, a vermilion hakama skirt with a side slit to the hip, white thigh-high stockings with a red ribbon-and-bell thigh band, red-thonged geta",
    "lantern-lit shrine stairs with fox statues and gingko leaves",
    ("leaning on a red torii pillar with one knee bent, a one-eye wink", "toothy playful grin"),
    ("standing with a folding fan raised in one hand and the other arm out, a hip tilted", "laughing open smile"),
    ("sitting on a stone step with legs crossed, tail curled around her", "teasing smile"))
add("kohaku", "evening", "Fox-lantern kimono dress",
    "vermilion-and-gold short kimono dress with an off-shoulder plunging neckline, a wide obi with a bell charm, a slit to the hip, sheer white lace-top thigh-high stockings with a red ribbon band, red heeled geta",
    "night shrine garden with floating fox-fire lanterns",
    ("holding a floating fire-lantern in cupped hands, looking up with a smile", "sly smile"),
    ("looking back over her shoulder with her tail swept forward, arched back", "teasing smile"),
    ("kneeling on a tatami platform with a hand on her thigh band", "playful smile"))
add("kohaku", "swim", "Shrine-spring bikini",
    "white-and-vermilion halter bikini with red ribbon ties and a gold bell at the neck, a sheer white sarong with a red edge, white thigh bands with bells, the fox mask at the side of her head",
    "forest hot spring with torii gates, steam and maple leaves",
    ("sitting on a rock with her feet in the water, her tail resting beside her", "relaxed teasing smile"),
    ("standing waist-deep with her tail raised out of the water, glancing back", "playful grin"),
    ("lying on her side on a wooden deck propped on one elbow", "lazy flirty smile"))
add("kohaku", "service", "Fox bunny-maid",
    "white-and-red bunny-style leotard with a deep plunging neckline and a gold bell collar, white fox ears kept, a red bow, white cuffs, sheer white pantyhose, red heels, a tray with blank tea cups",
    "festival teahouse with red lanterns and paper screens",
    ("carrying a tray with one hand and a hip tilted, a wink", "wink with a fang"),
    ("leaning over a low table toward the viewer", "teasing grin"),
    ("sitting on the table edge with legs crossed", "sly smile"))
add("kohaku", "robe", "White silk robe",
    "white silk robe-dress with red trim and a plunging neckline, tied by a red sash over a white satin mini dress, white lace-top thigh-high stockings with red ribbon bands, a gold bell collar",
    "moonlit shrine bedchamber with sliding doors and falling petals",
    ("reclining on tatami propped on one elbow with her tail wrapped around her legs", "sleepy teasing smile"),
    ("kneeling with the robe slipping from a shoulder, looking back", "soft smile"),
    ("standing at an open sliding door with arched back, hugging her tail", "gentle smile"))
add("kohaku", "battle", "Nine-tail warrior",
    "white-and-red armoured miko dress with gold plates, a plunging neckline, a short split hakama, white thigh-high stockings with red lacquer greaves, nine fox tails fanned behind her, a gohei wand",
    "burning torii avenue at night with fox-fire",
    ("lunging with the gohei raised, tails fanned out", "fierce toothy grin"),
    ("standing in a wide stance with the gohei across her shoulders", "bold smile"),
    ("kneeling on one knee with the gohei planted, looking up", "sly smirk"))
add("kohaku", "seasonal", "New-year miko",
    "short white-and-gold new-year kimono with a deep neckline, an oversized red obi bow, a slit to the hip, white thigh-high stockings with gold bell bands, red heeled geta, a fox mask on her head",
    "new-year shrine with snow and lantern strings",
    ("holding a lucky arrow and a fortune slip left blank, a wink", "toothy wink"),
    ("leaning on a snowy lantern with one knee bent", "playful smile"),
    ("looking back over her shoulder with her tail around her", "teasing smile"))

# ---------------------------------------------------------------- Shirin
add("shirin", "base", "Caravan dancer",
    "teal-and-gold choli top with a deep plunging neckline and sheer chiffon sleeves, a bare midriff, a low-slung plum skirt with a slit to the hip, a coin belt, gold arm bands, layered gold anklets, barefoot",
    "desert caravan camp at dusk with lanterns and a patterned carpet",
    ("belly-dance pose with a hip tilted and both arms in a serpentine wave", "serene mysterious smile"),
    ("sitting on cushions with legs folded to one side, a lamp balanced on her palm", "teasing half-smile"),
    ("reclining on a carpet propped on one elbow, one knee raised", "lazy flirty smile"))
add("shirin", "evening", "Oasis sheer gown",
    "sheer teal chiffon evening gown with gold embroidery, a deep plunging neckline, an open back, a slit to the hip, a coin belt, sheer gold thigh chains, gold sandals",
    "oasis terrace at night with lanterns, a pool and palms",
    ("standing with her back arched and a hip tilted, one hand on the veil", "mysterious smile"),
    ("sitting on a pool edge with legs crossed, the veil at her lips", "teasing smile"),
    ("looking back over her shoulder with a hand in her long hair", "inviting smile"))
add("shirin", "swim", "Oasis bikini",
    "gold-and-teal coin-trimmed bikini with a sheer chiffon wrap skirt, gold arm bands and anklets, the forehead jewel kept",
    "oasis pool with palms, a golden sunset and a striped cushioned lounger",
    ("sitting on the pool edge leaning back on both hands, a leg raised", "warm teasing smile"),
    ("standing waist-deep gathering her wet hair over one shoulder", "mysterious smile"),
    ("lying on her side on a lounger propped on one elbow", "lazy smile"))
add("shirin", "service", "Genie bunny",
    "teal-and-gold bunny-style leotard with a deep plunging neckline, a coin belt, sheer teal harem pantyhose, bunny ears with a gold chain, gold cuffs, gold heels, a brass lamp as a prop",
    "palace lounge with brass lamps, hanging lanterns and silk cushions",
    ("holding the lamp out toward the viewer with a hip tilted", "teasing wink"),
    ("leaning on a cushion pile on both forearms, legs lifted behind her", "sly smile"),
    ("sitting on a low table with legs crossed, a hand under her chin", "mysterious smirk"))
add("shirin", "robe", "Chiffon robe",
    "sheer teal chiffon robe-dress with gold trim and a plunging neckline over a teal satin mini dress, a gold sash, gold anklets, barefoot",
    "tent bedchamber with silk drapes, cushions and a lamp",
    ("reclining on cushions propped on one elbow, one knee raised, the robe slipping off a shoulder", "dreamy smile"),
    ("kneeling on the cushions looking back over her shoulder", "soft teasing smile"),
    ("standing at the tent door with her back arched, holding the curtain", "inviting smile"))
add("shirin", "battle", "Sand-dancer war outfit",
    "gold-plated teal armour choli with a deep plunging neckline, a low-slung split skirt with coin chains, armoured arm bands, gold greaves with bells, two curved dancing blades",
    "moonlit dunes with torches and drifting sand",
    ("mid-dance spin with a blade in each hand, hair flying", "bold smile"),
    ("kneeling on one knee with the blades crossed before her", "fierce smirk"),
    ("standing with a hip tilted and a blade resting on her shoulder", "teasing smile"))
add("shirin", "seasonal", "Festival lantern set",
    "short emerald silk festival dress with a deep neckline and gold coin trim, bare shoulders, a slit to the hip, sheer gold thigh chains, a lantern-patterned veil, gold heeled sandals",
    "night bazaar with hanging lamps and spice stalls",
    ("holding up a glowing lantern with one hand, a hip tilted", "warm teasing smile"),
    ("sitting on a stall counter with legs crossed, a pomegranate in hand", "playful smile"),
    ("looking back over her shoulder through hanging lamps", "mysterious smile"))

# ---------------------------------------------------------------- Zlata
add("zlata", "base", "Firebird sarafan",
    "scarlet corset sarafan with gold folk ornament, a plunging sweetheart neckline, bare shoulders, feather wing-sleeves, a short front-slit skirt over sheer red lace-top thigh-high stockings with gold garter straps, red embroidered heeled boots",
    "fairy-tale palace hall with gold columns and drifting embers",
    ("standing with a hip tilted, the feather wing-sleeves spread, looking over her shoulder", "regal teasing smile"),
    ("seated sideways on a gilded throne armrest with legs crossed, an ember candle in hand", "warm half-smile"),
    ("leaning on a gold column with an arched back, one knee bent", "confident smile"))
add("zlata", "evening", "Ember ball gown",
    "scarlet-and-gold satin ball gown with a deep plunging neckline and an open back, a skirt slit to the hip, sheer red lace-top thigh-high stockings with ruby garter charms, gold heels, the pearl-and-ruby choker kept",
    "grand ballroom with a golden chandelier and a marble staircase",
    ("descending a stair with one hand on the rail and a hip tilted", "regal teasing smile"),
    ("sitting on the stair with legs crossed, the gown spilling around her", "warm smile"),
    ("looking back over her bare shoulder with an arched back", "inviting smile"))
add("zlata", "swim", "Firebird swimsuit",
    "scarlet-and-gold high-cut swimsuit with a deep plunging neckline and ruby clasps, a sheer red wrap skirt, a feather-trimmed sheer cape, gold anklets, the kokoshnik kept",
    "royal lake pavilion at sunset with gold lanterns and swans",
    ("sitting on the pavilion steps with her feet in the water, leaning back on one hand", "calm teasing smile"),
    ("standing waist-deep draping the braid over a shoulder", "regal smile"),
    ("lying on her side on a gilded lounger propped on one elbow", "lazy warm smile"))
add("zlata", "service", "Tsarina bunny",
    "scarlet-and-gold bunny-style leotard with a deep plunging neckline and gold folk embroidery, red bunny ears under the kokoshnik, feather cuffs, sheer red pantyhose, red heeled boots, a tray with a blank tea set",
    "gilded tea salon with a samovar and tall windows",
    ("carrying the tray on one hand with a hip tilted", "regal teasing smile"),
    ("leaning on a table with both forearms and one leg lifted behind her", "sly smile"),
    ("sitting on the table edge with legs crossed", "warm smirk"))
add("zlata", "robe", "Firebird silk robe",
    "scarlet silk robe-dress with gold folk trim and a plunging neckline over a gold satin mini dress, sheer red lace-top thigh-high stockings, feather-trimmed slippers, the braid over one shoulder",
    "royal bedchamber with a canopy, candles and embers",
    ("reclining on the bed propped on one elbow with the braid over her arm", "dreamy warm smile"),
    ("sitting at a gilded vanity looking back over her shoulder", "teasing smile"),
    ("standing at a tall window with an arched back", "soft inviting smile"))
add("zlata", "battle", "Firebird warrior",
    "red-and-gold plate-and-feather armour dress with a plunging neckline, a short armoured skirt, scale thigh-high stockings with ruby garter bands, red greaves, a feathered spear, wing-cape of fire feathers",
    "burning battlement at dusk with embers and firebird shadows",
    ("lunging with the feathered spear pointed forward, the wing-cape flaring", "fierce regal smile"),
    ("standing in a wide stance with the spear planted, a hand on her hip", "bold smile"),
    ("kneeling on one knee with the spear planted", "proud smirk"))
add("zlata", "seasonal", "Winter-festival sarafan",
    "short white-and-scarlet winter sarafan with white fur trim and gold ornament, a deep sweetheart neckline, bare shoulders, a fur-trimmed shawl, white thigh-high stockings with red ribbons, red heeled boots, a fur kokoshnik",
    "snowy festival square with a decorated tree and lantern strings",
    ("holding a glowing ember lantern, looking back over her shoulder", "warm teasing smile"),
    ("sitting on a sleigh seat with legs crossed, a steaming cup in hand", "cozy smile"),
    ("twirling with the shawl flaring in snow", "bright laugh"))


def outfit(hk: str, slot: str) -> dict:
    return W[hk][slot]


def check() -> None:
    assert set(W) == {"mc", "rin", "hana", "yue", "nova", "tsubame", "miel", "kohaku", "shirin", "zlata"}
    for hk, d in W.items():
        assert list(d) == SLOTS, (hk, list(d))
        for s, o in d.items():
            assert len(o["poses"]) == 3 and all(len(p) == 2 for p in o["poses"]), (hk, s)


check()
