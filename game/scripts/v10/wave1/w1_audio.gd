class_name V10W1Audio
extends RefCounted

# V10W1Audio — the sound of wave 1 (Цубамэ, Миэль, Кохаку, Ширин, Злата): leitmotifs, Злата's stings, heroine SFX and
# the voice-line script. TEXT AND PROMPTS ONLY: nothing here is generated yet; every asset is listed by pending() with
# its exact target path, model and parameters (docs/AUDIO_BIBLE.md §5, §6, §7.2, §9.3; UX_RULES §7.2, §8.3).
# Pure data + static helpers, NOT gated itself: consumers call it only behind V10Wave1.released() (hooks in the report).
# Every consumer falls back silently while a file is missing (motif_ready / voice_ready / ResourceLoader.exists).
#
# Leitmotifs (MOTIFS): core pluck + a timbre signature no other heroine has (§5.1), own tempo/key (no two heroines on the
# same key closer than 6 BPM, checked against the founders' and the wave 2–3 slots, REGISTRY), the «Пять ветров» hook
# (major sol-la-do-re-do / minor la-do-re-mi-re), the bible's 30-s motif template verbatim → loop of 12–24 s.
# Note: Рин's approved signature is koto + shakuhachi-like flute. Цубамэ's flute is the breathy, percussive night-courier
# flute over taiko rim clicks at 112 BPM in B minor (Рин: lyrical, 72 BPM, A minor) — keep the critic's ear on it (§11).
# Stings (STINGS): Злата's SSR kit stings at the paths V10KitData.STINGS already reads (short 1,5 s at «Сделать
# партнёром», full 5 s once per session on entering Чайная, ≤ 1 per 600 s — V10HudSkin.sting).
# SFX (SFX): V10SfxBank.BANK schema (+ prompt/use), `mirelo_text_to_audio` template §7.2, ids «w1_*».
# Voice (VOICED): 24 Russian lines per goddess = the first lines of each kind of the home lane's barks
# (V10W1HomeLines.BARKS → V6Txt.LINES), so subtitle and recording match exactly as Sfx.say requires
# (VOICED[h][k][i] == LINES[h][k][i]); selfcheck re-verifies it. VOICE_CAST: the voice to design once per goddess.
#
#   V10W1Audio.motif_ready(h) -> bool ; track_id(h) ; has_track(id) ; track_path(id) ; track_loops(id)   (V10Music)
#   V10W1Audio.has_voice(h, kind) ; lines(h, kind) ; voice_path(h, kind, i) ; voice_ready(h, kind, i)    (Sfx / V10SfxBank)
#   V10W1Audio.sfx_entry(id) ; sfx_path(variant)                                                         (V10SfxBank)
#   V10W1Audio.sting_path(h, full) -> String                                                             (V10KitData)
#   V10W1Audio.speak(line) -> String      TTS text («SSR» → «Эс-эс-эр», no «~»)
#   V10W1Audio.pending() -> Array         [{kind, path, model, params, prompt | text}] — what generation must produce
#   V10W1Audio.voice_json() -> String     {name: {hero, kind, ru, speak}} for pipeline/voice_check.py
#   V10W1Audio.selfcheck() -> Array       [{ok, name}] for --wave1_selftest

const HEROES: = ["tsubame", "miel", "kohaku", "shirin", "zlata"]
const DIR: = "res://assets/v10/wave1/audio/"
const MUSIC_DIR: = DIR + "music/"
const SFX_DIR: = DIR + "sfx/"
const VOICE_DIR: = DIR + "voice/"
const SFX_PREFIX: = "w1_"
const MUSIC_MODEL: = "elevenlabs_music_v2_5"
const SFX_MODEL: = "mirelo_text_to_audio"
const HOME_LINES: = "res://scripts/v10/wave1/w1_home_lines.gd"
const MOTIF_ANCHOR: = "Same teahouse anime-pop sonic identity."
const MOTIF_TAIL: = "Loopable, no intro, no fade-out. Instrumental."
const HOOK_MAJOR: = "sol-la-do-re-do"
const HOOK_MINOR: = "la-do-re-mi-re"

# tempo/key of every heroine theme that exists or has a slot (AUDIO_BIBLE §5.2 approved, §5.3 slots)
const REGISTRY: = {
	"mc": [122, "G major"], "rin": [72, "A minor"], "hana": [140, "E major"], "yue": [80, "D minor"], "nova": [118, "F# minor"],
	"minamo": [76, "Eb major"], "kira": [132, "B minor"], "vesper": [92, "G minor"], "sigrid": [100, "F# major"],
}

# ------------------------------------------------------------------------------------------------ leitmotifs
# desc: what the motif is (RU, for the critic); prompt: AUDIO_BIBLE §9.3 «Мотив героини», 30 s, batch 4
const MOTIFS: = {
	"tsubame": {"bpm": 112, "key": "B minor", "hook": HOOK_MINOR, "core": "guzheng",
		"signature": ["shakuhachi", "taiko rim"], "ru_signature": "сякухати (дыхание, порывы ветра) + римшоты тайко",
		"desc": "Ночная крыша и письмо за пазухой: хрипловатая сякухати с порывами ветра отвечает приглушённому стаккато гучжэна, щелчки по ободу тайко держат шаг курьера. Минорный хук «ля-до-ре-ми-ре» с тёплым мажорным разрешением — сдержанная профи, которая прячет улыбку в шарф. 112 BPM, си минор (пентатоника).",
		"prompt": "Character theme for Tsubame, a cool night courier who carries sealed letters between worlds across misty moonless rooftops, an elegant adult heroine of the Five Winds teahouse: cool, swift, mysterious, with a hidden warmth. Breathy shakuhachi-like bamboo flute with sharp wind-gust accents and crisp taiko rim clicks with muted staccato guzheng, soft analog synth pads and a pulsing round bass, tight lo-fi drums with brushed snare, built on a short five-note pentatonic hook (three quick rising notes and a long held note, la-do-re-mi-re), very catchy short hook, 112 BPM, B minor pentatonic leaning major. Same teahouse anime-pop sonic identity. Loopable, no intro, no fade-out. Instrumental."},
	"miel": {"bpm": 102, "key": "F major", "hook": HOOK_MAJOR, "core": "guzheng",
		"signature": ["music box", "pizzicato"], "ru_signature": "музыкальная шкатулка + пиццикато струнных",
		"desc": "Утренняя кондитерская: музыкальная шкатулка и прыгучее пиццикато струнных над ярким гучжэном, тёплое Rhodes и шейкер-«венчик». Мажорный хук «соль-ля-до-ре-до», как напевает над миской крема, — солнечно, сладко и по-взрослому. 102 BPM, фа мажор (пентатоника).",
		"prompt": "Character theme for Miel, a sunny pastry chef who runs a honey-and-steam patisserie, an elegant adult heroine of the Five Winds teahouse: warm, sunny, sweet and playful, grown-up. Twinkling music box and bouncy pizzicato strings with bright guzheng, warm Rhodes chords and a soft whisk-like shaker, light lo-fi hip-hop drums with brushed snare, built on a short five-note pentatonic hook (three quick rising notes and a long held note, sol-la-do-re-do), very catchy short hook, 102 BPM, F major pentatonic. Same teahouse anime-pop sonic identity. Loopable, no intro, no fade-out. Instrumental."},
	"kohaku": {"bpm": 98, "key": "E minor", "hook": HOOK_MINOR, "core": "koto",
		"signature": ["suzu", "clapper"], "ru_signature": "кото + встряхивания кагура-судзу, деревянные хёсиги",
		"desc": "Тысяча врат ночью: щипковое кото дразнит, связка колокольчиков кагура-судзу звенит на сильных долях, деревянные хёсиги щёлкают, как лисья усмешка. Минорный хук с хитрым мажорным уклоном — надменная проказница, которая тает от ласки. 98 BPM, ми минор (пентатоника).",
		"prompt": "Character theme for Kohaku, a mischievous white-fox shrine maiden who has guarded the luck of a hill of a thousand vermilion gates for nine centuries, an elegant adult heroine of the Five Winds teahouse: sly, playful, haughty, secretly tender. Shimmering kagura suzu bell-tree shakes and soft wooden clapper accents with plucky koto, temple-bell glints and soft analog synth pads, light lo-fi drums with a swung hi-hat, built on a short five-note pentatonic hook (three quick rising notes and a long held note, la-do-re-mi-re), very catchy short hook, 98 BPM, E minor pentatonic leaning major. Same teahouse anime-pop sonic identity. Loopable, no intro, no fade-out. Instrumental."},
	"shirin": {"bpm": 94, "key": "D minor", "hook": HOOK_MINOR, "core": "pipa",
		"signature": ["oud", "ney", "darbuka"], "ru_signature": "уд + най + дарбука (с пипой ядра)",
		"desc": "Шатёр каравана под первыми звёздами: тёплый уд и дыхание ная, дарбука в мягком танцевальном ритме, пипа отвечает уду, звенят тарелочки и пояс-монисто. Минорный хук, светлеющий к концу фразы, — загадочная гадалка, мудрая и игривая. 94 BPM, ре минор (пентатоника).",
		"prompt": "Character theme for Shirin, a dancer and fortune teller of a desert caravan who reads destinies in the stars, an elegant adult heroine of the Five Winds teahouse: mysterious, warm, wise, playfully alluring. Warm oud and breathy ney flute over darbuka in a gentle dance groove with pipa, finger cymbals and coin-belt jingles, round upright-style bass, built on a short five-note pentatonic hook (three quick rising notes and a long held note, la-do-re-mi-re), very catchy short hook, 94 BPM, D minor pentatonic leaning major. Same teahouse anime-pop sonic identity. Loopable, no intro, no fade-out. Instrumental."},
	"zlata": {"bpm": 108, "key": "A minor", "hook": HOOK_MINOR, "core": "guzheng",
		"signature": ["gusli", "balalaika", "choir"], "ru_signature": "гусли + балалайка + хор «ой» (без слов)",
		"desc": "Терем на рассвете весны: звонкие гусли и тремоло балалайки над ярким гучжэном, хор-пэд на открытом «ой» без слов, бубенцы и хлопки ярмарки. Минорная фольклорная пентатоника с праздничным мажорным подъёмом — царственная, тёплая, щедрая. 108 BPM, ля минор (слот AUDIO_BIBLE §5.3).",
		"prompt": "Character theme for Zlata, the Firebird tsarevna of a fairy-tale kingdom and spirit of the spring sun, an elegant adult heroine of the Five Winds teahouse: regal, warm, proud, generous and festive. Ringing gusli, tremolo balalaika and wordless folk choir-like synth pads on an open oy vowel (no words) with bright guzheng, sleigh-bell sparkle and warm piano, bouncy folk-pop drums with handclaps, built on a short five-note pentatonic hook (three quick rising notes and a long held note, la-do-re-mi-re), very catchy short hook, 108 BPM, A minor pentatonic leaning major. Same teahouse anime-pop sonic identity. Loopable, no intro, no fade-out. Instrumental."},
}
const MOTIF_PARAMS: = {"model": MUSIC_MODEL, "duration": 30, "force_instrumental": true, "batch_size": 4}
const MOTIF_LOOP: = "python3 game/scripts/v10/audio/pipeline/v10_loop.py music <in.mp3> <out.ogg>  → loop 12–24 s, −16 LUFS, loop=true"

# ------------------------------------------------------------------------------------------------ stings (Злата, SSR kit)
# paths = V10KitData.STINGS.zlata (the consumer contract); generation 4 s / 8 s, the file keeps 1,5 s / 5 s
const STINGS: = {
	"zlata": {
		"short": {"file": "res://assets/v10/audio/sting/zlata_short.ogg", "len": 1.5, "gen": 4,
			"use": "«Сделать партнёром»: взять 1,5 с от атаки, затухание 120 мс",
			"prompt": "Short heroine signature jingle for an anime mahjong game set in the Five Winds teahouse, 4 seconds: a bright rising gusli glissando into one ringing tremolo balalaika chord, bright guzheng and gusli with a single wordless folk choir-like swell on an open oy vowel (no words), sleigh-bell sparkle, joyful anime-pop, five-note pentatonic hook rising, A minor pentatonic leaning major, ends on a big satisfying resolved chord with natural ring-out. Instrumental."},
		"full": {"file": "res://assets/v10/audio/sting/zlata_full.ogg", "len": 5.0, "gen": 8,
			"use": "вход в Чайную раз за сессию (не чаще раза в 600 с): 5 с, естественное затухание",
			"prompt": "Short radiant SSR reveal jingle for an anime mahjong game set in the Five Winds teahouse, 8 seconds: ringing gusli and tremolo balalaika state the five-note hook rising, answered by a soaring erhu, bright guzheng, wordless folk choir-like pads swelling on an open oy vowel (no words), taiko hits and sleigh bells, warm piano, regal and festive anime-pop, radiant, awe, five-note pentatonic hook rising, A minor pentatonic leaning major, ends on a big satisfying resolved chord with natural ring-out. Instrumental."},
	},
}
const STING_LOOP: = "python3 game/scripts/v10/audio/pipeline/v10_loop.py music <in.mp3> <out.ogg> --sting  → −16 LUFS, no loop"

# ------------------------------------------------------------------------------------------------ SFX (V10SfxBank.BANK schema)
const SFX: = {
	"w1_tb_smoke": {"v": ["w1_tb_smoke"], "db": -6.0, "spread": 0.4, "max": 1, "gap": 0.4, "hero": "tsubame", "duration": 1,
		"use": "касание головы: исчезает в облачке дыма и появляется рядом",
		"prompt": "courier vanishes in a puff of smoke: soft silk cloth swish with an airy smoke whoosh and a tiny wind chime, quick, gentle, clean, short tail, mobile game UI sound"},
	"w1_tb_kunai": {"v": ["w1_tb_kunai"], "db": -7.0, "spread": 0.3, "max": 1, "gap": 0.3, "hero": "tsubame", "duration": 1,
		"use": "касание фона: кунай-ласточка прикалывает падающий лист",
		"prompt": "small swallow-shaped throwing pin lands in a wooden post: crisp wooden thunk with a light metal ting, quick, satisfying, clean, no reverb tail, mobile game UI sound"},
	"w1_me_sugar": {"v": ["w1_me_sugar"], "db": -6.0, "spread": 0.6, "max": 2, "gap": 0.2, "hero": "miel", "duration": 1,
		"use": "касание головы: облачко сахарной пудры; комбо: взрыв посыпки",
		"prompt": "puff of powdered sugar: soft airy powder poof with tiny crystal sparkle, quick, gentle, clean, short shimmering tail, mobile game UI sound"},
	"w1_me_oven": {"v": ["w1_me_oven"], "db": -6.0, "spread": 0.2, "max": 1, "gap": 0.6, "hero": "miel", "duration": 2,
		"use": "касание фона: звенит духовка, она заглядывает внутрь",
		"prompt": "small bakery oven timer: warm brass bell ding with a soft porcelain clink, short, friendly not harsh, clean, short shimmering tail, mobile game UI sound"},
	"w1_ko_suzu": {"v": ["w1_ko_suzu"], "db": -6.0, "spread": 0.5, "max": 2, "gap": 0.25, "hero": "kohaku", "duration": 1,
		"use": "колокольчик-судзу: idle, наряд (маска), бубенцы мико LW48",
		"prompt": "shrine maiden's small suzu bell shaken once: bright brass bell jingle with a tiny bell overtone, short, premium, clean, short shimmering tail, mobile game UI sound"},
	"w1_ko_foxfire": {"v": ["w1_ko_foxfire"], "db": -5.0, "spread": 0.6, "max": 2, "gap": 0.2, "hero": "kohaku", "duration": 1,
		"use": "касание руки: лисий огонёк прыгает на палец; комбо: огоньков всё больше",
		"prompt": "small foxfire flame lights up: soft warm whoosh of a tiny flame with crystal shimmer, quick, gentle, clean, short tail, mobile game UI sound"},
	"w1_sh_coins": {"v": ["w1_sh_coins"], "db": -6.0, "spread": 0.7, "max": 2, "gap": 0.2, "hero": "shirin", "duration": 1,
		"use": "касание головы: звенят монеты; комбо: лестница звона; пайал LW52",
		"prompt": "dancer's coin belt shimmy: light gold coin jingle with tiny bells, quick, friendly not harsh, clean, short shimmering tail, mobile game UI sound"},
	"w1_sh_sand": {"v": ["w1_sh_sand"], "db": -7.0, "spread": 0.3, "max": 1, "gap": 0.6, "hero": "shirin", "duration": 2,
		"use": "касание фона: песчаный вихрь, мигает лампа",
		"prompt": "small desert sand swirl: airy silk breath and soft sand hiss with a wind chime, short, gentle, clean, short tail, mobile game UI sound"},
	"w1_zl_feather": {"v": ["w1_zl_feather"], "db": -5.0, "spread": 0.5, "max": 2, "gap": 0.2, "hero": "zlata", "duration": 1,
		"use": "касание руки: дарит светящееся перо; комбо: огненные перья множатся",
		"prompt": "glowing firebird feather appears: soft warm ember crackle with crystal shimmer and a tiny bell, short, premium, clean, short shimmering tail, mobile game UI sound"},
	"w1_zl_wings": {"v": ["w1_zl_wings"], "db": -4.0, "spread": 0.2, "max": 1, "gap": 0.8, "hero": "zlata", "duration": 2,
		"use": "касание наряда: плащ-крылья раскрываются; победа: крылья света",
		"prompt": "feather wing-cape opens wide: big silky feather swish with a warm ember glow and soft harp shimmer, big, premium, clean, short shimmering tail, mobile game UI sound"},
}
const SFX_LOOP: = "python3 game/scripts/v10/audio/pipeline/v10_loop.py sfx <in.mp3> <out.ogg> --maxlen 1.2  → −14 LUFS, peak ≤ −1 dBFS"

# ------------------------------------------------------------------------------------------------ voice
# kinds of Sfx.say and how many lines of each are voiced (24): the first N barks of the kind, as the founders
const VOICE_PLAN: = {"greet": 3, "match": 3, "combo": 2, "fever": 1, "win": 2, "lose": 1, "gacha": 1, "ssr": 1, "outfit": 1,
	"aff": 1, "hint": 1, "yaku": 2, "riichi": 1, "rankup": 1, "skill": 1, "idle": 1, "start": 1}
const VOICE_LOOP: = "python3 game/scripts/v10/audio/pipeline/v10_loop.py voice <in.mp3> <out.ogg> --lufs -14  → −14 LUFS, silence trimmed"
const VOICE_QA: = "pipeline/voice_check.py with the text of voice_json(): ru transcript similarity ≥ 0,8, one f0 per heroine"

# the voice to design once per goddess (create_voice from the description, then text-to-speech line by line, Russian)
const VOICE_CAST: = {
	"tsubame": {"ru": "24 года. Прохладное низкое альто, коротко и тихо, чёткая дикция; тепло прорывается в паузах. Ближний микрофон, без придыханий.",
		"prompt": "Adult Russian woman, 24, cool low alto, quiet and clipped, precise diction, a hint of warmth under restraint, close intimate microphone, calm breathing between phrases, no sighs or moans, native Russian pronunciation with no accent."},
	"miel": {"ru": "25 лет. Тёплое светлое меццо, солнечно и с улыбкой в голосе, лёгкий смешок; уютно, по-взрослому.",
		"prompt": "Adult Russian woman, 25, warm bright mezzo-soprano, sunny and bubbly, a smile in the voice and a light giggle, cosy and grown-up, close microphone, no sighs or moans, native Russian pronunciation with no accent."},
	"kohaku": {"ru": "На вид 25, лисе 900 лет. Игривое лукавое меццо с ленцой и превосходством, которое срывается в смущённую высокую ноту.",
		"prompt": "Adult Russian woman, ageless and elegant, sly playful mezzo with a teasing lazy drawl and a haughty tone that slips into a flustered higher note, close microphone, no sighs or moans, native Russian pronunciation with no accent."},
	"shirin": {"ru": "26 лет. Бархатное низкое меццо, неторопливая речь сказительницы, загадочно и тепло; по утрам чуть сонно.",
		"prompt": "Adult Russian woman, 26, velvety low mezzo, unhurried storyteller cadence, mysterious and warm, slightly sleepy and wise, close microphone, no sighs or moans, native Russian pronunciation with no accent."},
	"zlata": {"ru": "25 лет. Насыщенное царственное меццо-сопрано, напевная сказочная интонация, гордо и щедро, звонкий смех.",
		"prompt": "Adult Russian woman, 25, rich regal mezzo-soprano, warm folk-tale cadence, proud yet generous, bright ringing laugh, close microphone, no sighs or moans, native Russian pronunciation with no accent."},
}

# TTS (HANDOFF §15: elevenlabs_v4 or qwen_audio_tts, language ru; check by speech recognition that it is Russian)
const VOICE_MODEL: = "elevenlabs_v4"
const VOICE_PARAMS: = {"model": VOICE_MODEL, "alt": "qwen_audio_tts", "language": "ru", "lufs": -14}
# Sfx.RETURN_MARKS (sfx.gd): a greet with one of these plays only to a returning player
const RETURN_MARKS: = ["возвращ", "Опять", "снова", "Я тебя ждала", "каждый день", "и этой ночью"]
# on top of V10Lint.BANNED: the brief's «бесплатн», red lines and the UX §4.3 jargon (heroine lines only)
const EXTRA_BANNED: = ["бесплатн", "рубл", "донат", "гача", "крутк", "фивер", "ивент", "риичи", "пити", "гарант",
	"школ", "учител", "ученик", "раздев", "грудь", "бёдр"]
const HOME: = "res://scripts/v10/wave1/w1_home.gd"
const SSR_SPOKEN: = "Эс-эс-эр"

# the 24 voiced lines per goddess, kind → [line 1..n] = V10W1HomeLines.BARKS[h][kind].slice(0, VOICE_PLAN[kind])
# file: VOICE_DIR + "<hero>_<kind><n>.ogg" (n from 1), e.g. res://assets/v10/wave1/audio/voice/zlata_ssr1.ogg
const VOICED: = {
	"tsubame": {
		"greet": ["Цубамэ на месте. Маршрут свободен.", "С возвращением. Адрес тот же, получатель тоже.", "Пришла с крыши. Чай остался?"],
		"match": ["Чисто.", "Принято.", "Есть."],
		"combo": ["Серия. Ласточки взлетают.", "Темп держишь. Как на крышах."],
		"fever": ["Полнолуние. Двигайся быстро и тихо."],
		"win": ["Стол чист. Доставлено.", "Задание выполнено. Салют двумя пальцами."],
		"lose": ["Ещё заход."],
		"gacha": ["Посылка без обратного адреса…"],
		"ssr": ["SSR. Срочная доставка. Тебе."],
		"outfit": ["Сменила форму. Для дела. …Ладно, для тебя."],
		"aff": ["Обычно я ношу чужие письма. С тобой хочется писать свои."],
		"hint": ["Эти. Зажаты с боков, но открыты."],
		"yaku": ["Комбинация собрана. Печать поставлена.", "Чистая комбинация. Как по инструкции."],
		"riichi": ["Ва-банк. Без подсказок, как в ночной доставке."],
		"rankup": ["Новый ранг. Внесу в реестр гильдии."],
		"skill": ["Теневой шаг. Пара уходит в дым."],
		"idle": ["Жду команды."],
		"start": ["Маршрут построен. Начинаем."],
	},
	"miel": {
		"greet": ["Попробуй! Свежие эклеры, только что из печи~", "С возвращением! Я берегла тебе самый ровный макарон.", "Сегодня вкус партии — малина и мёд. Садись!"],
		"match": ["Вкусно!", "Есть пара!", "Сладко легли!"],
		"combo": ["Ещё-ещё! Как слои в торте!", "Взрыв посыпки! Не останавливайся!"],
		"fever": ["Полнолуние! Глазурь блестит, хватай пары!"],
		"win": ["Стол чист! Несу поднос пирожных!", "Попробуй победу на вкус — она с малиной~"],
		"lose": ["Перестаралась с сахаром… Ещё раз?"],
		"gacha": ["Что там? Как духовку открывать!"],
		"ssr": ["SSR?! Это же торт со свечками!"],
		"outfit": ["Новый наряд! Ленту завязала идеально, проверь~"],
		"aff": ["Я назову новый десерт в твою честь. Пока секрет~"],
		"hint": ["Вот эти две! Как пара эклеров."],
		"yaku": ["Комбинация! Многоярусная красота!", "Как по бабушкиному рецепту. Красиво!"],
		"riichi": ["Ва-банк! Без подсказок, как торт без рецепта!"],
		"rankup": ["Новый ранг! Испеку тебе торт с цифрой!"],
		"skill": ["Печенье-джокер — к любой фишке!"],
		"idle": ["Задумался? Я пока украшу кексы~"],
		"start": ["Фартук надет, фишки разложены. Начинаем!"],
	},
	"kohaku": {
		"greet": ["Удача любит меня. Значит, и тебя сегодня тоже.", "С возвращением, человек. Холм тебя помнит.", "Пришёл к лисе на поклон? Правильно."],
		"match": ["Ловко.", "Как задумано.", "Лисья хватка!"],
		"combo": ["Огоньков всё больше! Не останавливайся!", "Хвост ходит ходуном. Ещё!"],
		"fever": ["Полнолуние! Лисьи огни пляшут — хватай пары!"],
		"win": ["Удача любит меня, а значит, и тебя.", "Стол чист. Лиса довольна. Очень."],
		"lose": ["Уши прижаты… Ничего. Удача вернётся."],
		"gacha": ["Посмотрим, кого привела удача~"],
		"ssr": ["SSR! Девять хвостов одобряют!"],
		"outfit": ["Нравится? Разрешаю любоваться. Недолго."],
		"aff": ["Девятьсот лет я ждала такого игрока. Не зазнавайся."],
		"hint": ["Вот эти, человек. Лиса видит."],
		"yaku": ["Комбинация! Удача складывается в узор.", "Красиво. Почти как мой хвост."],
		"riichi": ["Ва-банк! Удача, не подведи меня. И его."],
		"rankup": ["Новый ранг. Холм шепчет твоё имя."],
		"skill": ["Лисий оберег! Лоток под защитой."],
		"idle": ["Задумался? Лиса не ждёт вечно."],
		"start": ["Огни зажжены. Начинай, человек."],
	},
	"shirin": {
		"greet": ["Звёзды сказали, что ты придёшь. Звёзды не лгут.", "С возвращением, путник. Песок помнит твои шаги.", "Садись. Я уже разложила фишки и судьбу."],
		"match": ["Как предсказано.", "Звенит!", "Красиво."],
		"combo": ["Звон монет всё выше! Ещё!", "Танцуешь по столу, как я в шатре!"],
		"fever": ["Полнолуние! Танцуем, пока звенят монеты!"],
		"win": ["Звёзды сказали правду.", "Стол чист! Вуаль летит в небо!"],
		"lose": ["Пески переменчивы."],
		"gacha": ["Песок пересыпается… Что там?"],
		"ssr": ["SSR! Это было в звёздах!"],
		"outfit": ["Новый наряд. Монеты звенят по-новому."],
		"aff": ["В караване говорят: нашёл свой колодец — ты дома."],
		"hint": ["Вижу пару… вот здесь."],
		"yaku": ["Комбинация! Как созвездие над дюнами.", "Узор сложился. Звёзды не лгут."],
		"riichi": ["Ва-банк! Пусть звёзды смотрят на нас."],
		"rankup": ["Новый ранг. Я видела его в твоей ладони."],
		"skill": ["Танец монет! Пара — и Полнолуние!"],
		"idle": ["Задумался? Мудро. Но не засыпай."],
		"start": ["Звёзды на местах. Начинай."],
	},
	"zlata": {
		"greet": ["Весна пришла! И ты тоже. Добро пожаловать!", "С возвращением, сокол! Блины ещё тёплые.", "Царевна рада гостю. Садись к огню."],
		"match": ["Славно!", "Жарко!", "Ладно легли!"],
		"combo": ["Перья множатся! Ещё!", "Жар-птица расправляет крылья!"],
		"fever": ["Полнолуние! Гори, как костёр на Купалу!"],
		"win": ["Весна пришла!", "Стол чист! Крылья света — тебе!"],
		"lose": ["Пепел — только начало."],
		"gacha": ["Ну-ка, что принесёт ветер?"],
		"ssr": ["SSR! Жар-птица в руках!"],
		"outfit": ["Новый наряд! Ну как, хороша царевна?"],
		"aff": ["Жар-птица раз в сто лет выбирает человека. Тсс."],
		"hint": ["Вот эти, сокол."],
		"yaku": ["Комбинация! Узор как на моём сарафане.", "Ладно сложилось! Как в сказке."],
		"riichi": ["Ва-банк! Смелым — весна!"],
		"rankup": ["Новый ранг! Царство гордится тобой."],
		"skill": ["Огненный шлейф! Лёд тает!"],
		"idle": ["Задумался? Весна ждать не любит."],
		"start": ["Огонь разожжён. Начинаем!"],
	},
}


# ------------------------------------------------------------------------------------------------ lookups
static func is_hero(h: String) -> bool:
	return h in HEROES


static func track_id(h: String) -> String:
	return "motif_" + h


static func motif_path(h: String) -> String:
	return MUSIC_DIR + "motif_%s.ogg" % h


static func motif_ready(h: String) -> bool:
	return is_hero(h) and ResourceLoader.exists(motif_path(h))


# V10Music track ids served here: motif_<wave-1 hero>
static func has_track(id: String) -> bool:
	return id.begins_with("motif_") and is_hero(id.substr(6))


static func track_path(id: String) -> String:
	return motif_path(id.substr(6)) if has_track(id) else ""


static func track_loops(id: String) -> bool:
	return has_track(id)


static func lines(h: String, kind: String) -> Array:
	var d: Dictionary = VOICED.get(h, {})
	return d.get(kind, [])


static func has_voice(h: String, kind: String) -> bool:
	return not lines(h, kind).is_empty()


static func voice_path(h: String, kind: String, i: int) -> String:
	return VOICE_DIR + "%s_%s%d.ogg" % [h, kind, i + 1]


static func voice_ready(h: String, kind: String, i: int) -> bool:
	return i >= 0 and i < lines(h, kind).size() and ResourceLoader.exists(voice_path(h, kind, i))


# the text the TTS reads: «SSR» spelled out, no «~»
static func speak(line: String) -> String:
	return line.replace("SSR", SSR_SPOKEN).replace("~", "").strip_edges()


static func is_sfx(id: String) -> bool:
	return SFX.has(id)


static func sfx_entry(id: String) -> Dictionary:
	return SFX.get(id, {})


static func sfx_path(variant: String) -> String:
	return SFX_DIR + variant + ".ogg"


static func sfx_ids() -> Array:
	return SFX.keys()


static func sting_path(h: String, full: bool) -> String:
	var s: Dictionary = STINGS.get(h, {})
	var e: Dictionary = s.get("full" if full else "short", {})
	return String(e.get("file", ""))


# ------------------------------------------------------------------------------------------------ generation list
# every asset still to make (all = true: also the ones already on disk), with its exact path, model and prompt/text
static func pending(all: bool = false) -> Array:
	var out: = []
	for h in HEROES:
		var m: Dictionary = MOTIFS[h]
		out.append({"kind": "motif", "hero": h, "path": motif_path(h), "model": MUSIC_MODEL, "params": MOTIF_PARAMS,
			"prompt": String(m.prompt), "post": MOTIF_LOOP})
	for h in STINGS:
		for k in ["short", "full"]:
			var s: Dictionary = STINGS[h][k]
			out.append({"kind": "sting", "hero": h, "path": String(s.file), "model": MUSIC_MODEL,
				"params": {"model": MUSIC_MODEL, "duration": int(s.gen), "force_instrumental": true, "batch_size": 4, "keep_s": float(s.len)},
				"prompt": String(s.prompt), "post": STING_LOOP})
	for id in SFX:
		var e: Dictionary = SFX[id]
		out.append({"kind": "sfx", "hero": String(e.hero), "path": sfx_path(String(e.v[0])), "model": SFX_MODEL,
			"params": {"model": SFX_MODEL, "duration": int(e.duration)}, "prompt": String(e.prompt), "post": SFX_LOOP})
	for h in HEROES:
		for kind in VOICE_PLAN:
			var arr: = lines(h, kind)
			for i in arr.size():
				out.append({"kind": "voice", "hero": h, "path": voice_path(h, kind, i), "model": VOICE_MODEL,
					"params": VOICE_PARAMS, "voice": String(VOICE_CAST[h].prompt), "text": String(arr[i]),
					"speak": speak(String(arr[i])), "post": VOICE_LOOP})
	if all:
		return out
	return out.filter(func(x): return not ResourceLoader.exists(String(x.path)))


# {"<hero>_<kind><n>": {hero, kind, ru, speak, path}} — the script text for pipeline/voice_check.py
static func voice_json() -> String:
	var d: = {}
	for h in HEROES:
		for kind in VOICE_PLAN:
			var arr: = lines(h, kind)
			for i in arr.size():
				d["%s_%s%d" % [h, kind, i + 1]] = {"hero": h, "kind": kind, "ru": String(arr[i]),
					"speak": speak(String(arr[i])), "path": voice_path(h, kind, i)}
	return JSON.stringify(d, "\t")


# every player-visible string of this file (subtitles of the voiced lines)
static func texts() -> Array:
	var out: = []
	for h in HEROES:
		for kind in VOICE_PLAN:
			out.append_array(lines(h, kind))
	return out


static func lint(s: String) -> Array:
	var bad: = V10Lint.check(s)
	var low: = s.to_lower()
	for w in EXTRA_BANNED:
		if low.contains(String(w)) and not (w in bad):
			bad.append(String(w))
	return bad


static func _latin(s: String) -> bool:
	var t: = s.replace("SSR", "")
	for i in t.length():
		var c: = t.unicode_at(i)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122):
			return true
	return false


static func _consts(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		return {}
	var sc: = load(path) as Script
	return sc.get_script_constant_map() if sc != null else {}


# ------------------------------------------------------------------------------------------------ selfcheck (→ --wave1_selftest)
static func selfcheck() -> Array:
	var out: = []
	var ck: = func(ok: bool, name: String): out.append({"ok": ok, "name": name})
	var total: = 0
	for k in VOICE_PLAN:
		total += int(VOICE_PLAN[k])
	ck.call(total == 24, "voice plan: 24 lines per goddess")
	# voice script
	var plan_ok: = true
	for h in HEROES:
		var d: Dictionary = VOICED.get(h, {})
		if d.size() != VOICE_PLAN.size():
			plan_ok = false
		for k in VOICE_PLAN:
			if lines(h, k).size() != int(VOICE_PLAN[k]):
				plan_ok = false
	ck.call(plan_ok and VOICED.size() == HEROES.size(), "VOICED: 5 goddesses × the 17 kinds of VOICE_PLAN, 24 lines each")
	var barks: Dictionary = _consts(HOME_LINES).get("BARKS", {})
	var pre_ok: = not barks.is_empty()
	for h in HEROES:
		for k in VOICE_PLAN:
			var src: Array = (barks.get(h, {}) as Dictionary).get(k, [])
			var mine: = lines(h, k)
			if src.size() < mine.size() or src.slice(0, mine.size()) != mine:
				pre_ok = false
	ck.call(pre_ok, "VOICED[h][k] = first lines of V10W1HomeLines.BARKS[h][k] (subtitle = recording, Sfx.say rule)")
	var greet_ok: = true
	for h in HEROES:
		var g0: = String(lines(h, "greet")[0])
		for m in RETURN_MARKS:
			if g0.contains(String(m)):
				greet_ok = false
	ck.call(greet_ok, "first greet of each goddess is not a «с возвращением» line (first visit can be voiced)")
	var lint_ok: = true
	var latin_ok: = true
	var speak_ok: = true
	for s in texts():
		if not lint(String(s)).is_empty():
			lint_ok = false
		if _latin(String(s)):
			latin_ok = false
		var sp: = speak(String(s))
		if _latin(sp.replace(SSR_SPOKEN, "")) or sp.contains("SSR") or sp.contains("~") or sp.is_empty():
			speak_ok = false
	ck.call(lint_ok and texts().size() == 120, "no V10Lint.BANNED / red-line / UX jargon stem in the 120 voiced lines")
	ck.call(latin_ok, "voiced lines: no Latin except «SSR»")
	ck.call(speak_ok, "TTS text: «SSR» spelled out, no «~», no Latin")
	var lim: Dictionary = _consts(HOME).get("BARK_LIMITS", {})
	var len_ok: = true
	for h in HEROES:
		for k in VOICE_PLAN:
			for s in lines(h, k):
				if lim.has(k) and String(s).length() > int(lim[k]):
					len_ok = false
	ck.call(len_ok, "voiced lines within the founders' BARK_LIMITS (w1_home.gd)")
	var cast_ok: = VOICE_CAST.size() == HEROES.size()
	for h in HEROES:
		var c: Dictionary = VOICE_CAST.get(h, {})
		var p: = String(c.get("prompt", ""))
		if String(c.get("ru", "")).is_empty() or not p.begins_with("Adult Russian woman") or not p.contains("no accent") \
				or p.to_lower().contains("girl") or not p.contains("no sighs or moans"):
			cast_ok = false
	ck.call(cast_ok, "VOICE_CAST: one adult Russian voice per goddess, no accent")
	# leitmotifs
	var m_ok: = MOTIFS.size() == HEROES.size()
	var hook_ok: = true
	for h in HEROES:
		var m: Dictionary = MOTIFS.get(h, {})
		var p: = String(m.get("prompt", ""))
		var low: = p.to_lower()
		if not p.contains(MOTIF_ANCHOR) or not p.ends_with(MOTIF_TAIL) or not low.contains("adult") or p.length() > 1100 \
				or not p.contains("%d BPM" % int(m.bpm)) or not p.contains(String(m.key)) or not low.contains(String(m.core)) \
				or not p.begins_with("Character theme for ") or String(m.get("desc", "")).is_empty():
			m_ok = false
		for w in ["kawaii", "school", "girl", "teen", "sexy", "sensual"]:
			if low.contains(w):
				m_ok = false
		for sig in m.signature:
			if not low.contains(String(sig)):
				m_ok = false
		var minor: = String(m.key).ends_with("minor")
		if String(m.hook) != (HOOK_MINOR if minor else HOOK_MAJOR) or not p.contains(String(m.hook)):
			hook_ok = false
	ck.call(m_ok, "motif prompts: §9.3 template (anchor, tail, adult, BPM, key, core + signature), ≤ 1100 chars, no red words")
	ck.call(hook_ok, "motif hook syllables match the mode (major sol-la-do-re-do / minor la-do-re-mi-re)")
	var reg_ok: = true
	var all_reg: = REGISTRY.duplicate()
	for h in HEROES:
		all_reg[h] = [int(MOTIFS[h].bpm), String(MOTIFS[h].key)]
	for h in HEROES:
		for o in all_reg:
			if o != h and String(all_reg[o][1]) == String(MOTIFS[h].key) and absi(int(all_reg[o][0]) - int(MOTIFS[h].bpm)) < 6:
				reg_ok = false
	ck.call(reg_ok, "no two themes on the same key closer than 6 BPM (founders, slots, wave 1)")
	var sig_ok: = true
	var seen: = {}
	for h in HEROES:
		for sig in MOTIFS[h].signature:
			if seen.has(sig):
				sig_ok = false
			seen[sig] = h
	ck.call(sig_ok, "each goddess has her own timbre signature")
	var z: Dictionary = MOTIFS.get("zlata", {})
	ck.call(int(z.get("bpm", 0)) == 108 and String(z.get("key", "")) == "A minor" and String(z.get("core", "")) == "guzheng"
		and Array(z.get("signature", [])) == ["gusli", "balalaika", "choir"], "Злата = AUDIO_BIBLE §5.3 slot: 108 BPM, A minor, gusli + balalaika + choir «ой»")
	var ins_ok: = Array(MOTIFS.tsubame.signature).has("shakuhachi") and Array(MOTIFS.tsubame.signature).has("taiko rim") \
		and Array(MOTIFS.miel.signature).has("music box") and Array(MOTIFS.miel.signature).has("pizzicato") \
		and String(MOTIFS.kohaku.core) == "koto" and Array(MOTIFS.kohaku.signature).has("suzu") \
		and Array(MOTIFS.shirin.signature) == ["oud", "ney", "darbuka"]
	ck.call(ins_ok, "instruments as briefed: Цубамэ shakuhachi + taiko rim, Миэль music box + pizzicato, Кохаку koto + suzu, Ширин oud + darbuka + ney")
	var tr_ok: = has_track("motif_zlata") and not has_track("motif_mc") and track_path("motif_kohaku") == MUSIC_DIR + "motif_kohaku.ogg"
	for h in HEROES:
		if V10Music.TRACKS.has(track_id(h)) or h in V10Music.HEROES:
			tr_ok = false
	ck.call(tr_ok, "track ids motif_<hero> do not collide with V10Music.TRACKS")
	# stings
	var ks: Dictionary = V10KitData.STINGS.get("zlata", {})
	var st: Dictionary = STINGS.get("zlata", {})
	ck.call(sting_path("zlata", false) == String(ks.get("short", "-")) and sting_path("zlata", true) == String(ks.get("full", "-"))
		and is_equal_approx(float(st.full.len), float(ks.get("len", 0.0))) and float(st.short.len) <= 1.5
		and int(st.short.gen) > float(st.short.len) and int(st.full.gen) > float(st.full.len),
		"Злата stings at the V10KitData.STINGS paths, full 5 s, short ≤ 1,5 s")
	var sp_ok: = true
	for k in ["short", "full"]:
		var p: = String(st[k].prompt)
		if not p.ends_with("Instrumental.") or not p.to_lower().contains("gusli") or not p.contains("oy vowel (no words)"):
			sp_ok = false
	ck.call(sp_ok, "sting prompts: gusli + wordless «ой», instrumental")
	# SFX
	var sfx_ok: = SFX.size() == 10
	var per: = {}
	var bank_keys: Array = (V10SfxBank.BANK.values()[0] as Dictionary).keys()
	for id in SFX:
		var e: Dictionary = SFX[id]
		per[e.get("hero", "")] = int(per.get(e.get("hero", ""), 0)) + 1
		if not String(id).begins_with(SFX_PREFIX) or V10SfxBank.BANK.has(id) or Array(e.get("v", [])).is_empty() \
				or float(e.get("db", 1.0)) > 0.0 or int(e.get("max", 0)) < 1 or float(e.get("gap", 0.0)) <= 0.0 \
				or not is_hero(String(e.get("hero", ""))) or int(e.get("duration", 0)) < 1 or int(e.get("duration", 0)) > 2 \
				or not String(e.get("prompt", "")).ends_with("mobile game UI sound") or String(e.get("use", "")).is_empty():
			sfx_ok = false
		for bk in bank_keys:
			if bk != "vdb" and not e.has(bk):
				sfx_ok = false
	for h in HEROES:
		if int(per.get(h, 0)) != 2:
			sfx_ok = false
	ck.call(sfx_ok, "SFX: 10 «w1_*» ids in V10SfxBank.BANK schema, 2 per goddess, mirelo template")
	# paths and lists
	ck.call(voice_path("zlata", "ssr", 0) == "res://assets/v10/wave1/audio/voice/zlata_ssr1.ogg"
		and sfx_path("w1_zl_wings") == "res://assets/v10/wave1/audio/sfx/w1_zl_wings.ogg"
		and motif_path("miel") == "res://assets/v10/wave1/audio/music/motif_miel.ogg", "asset paths under assets/v10/wave1/audio/")
	var pend: = pending(true)
	var p_ok: = pend.size() == 5 + 2 + 10 + 120
	var paths: = {}
	for x in pend:
		if String(x.path).is_empty() or String(x.model).is_empty() or paths.has(x.path):
			p_ok = false
		paths[x.path] = true
	ck.call(p_ok, "pending(): 137 unique assets (5 motifs, 2 stings, 10 SFX, 120 lines) with path + model")
	var vj: Variant = JSON.parse_string(voice_json())
	ck.call(vj is Dictionary and (vj as Dictionary).size() == 120, "voice_json(): 120 named lines for voice_check.py")
	return out
