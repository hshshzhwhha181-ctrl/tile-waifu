class_name V10ChallengeCode
extends RefCounted

# «Вызов по коду» (spec 0.10 R5): the 64-bit challenge code, offline.
#
# LAYOUT (MSB → LSB, 64 bits)
#   mode 3 · gen_ver 3 · key 32 · time in tenths of a second 17 · stars 2 · CRC-7 over the 57 bits above
#   → 13 symbols of Crockford base32 (65 bits: the top bit is always 0, so the first symbol is 0–F), shown as
#   TW-XXXX-XXXX-XXXXX. Optional suffix «:ник» (spaces written as «_»), checked by G.nick_error + the V8 filter.
#
#   mode   1 Путь (key = uid of the level) · 2 Партия дня (key = day index) · 3 Странствие (key = week × 8 + board)
#          4 Пик (key = uid of the level). 0 is never issued (an all-zero code is invalid), 5 and 6 are reserved for
#          1.0 tables, 7 is reserved as the escape to a longer format.
#   gen    version of the deal generator of that mode (V10ChallengeDeal.cur_gen); a code from another generation
#          is refused with a clear message instead of starting a different table.
#   time   tenths of a second, 1 … 131 071 (3:38:27,1). Plausible only if ≥ 0,35 s × pairs of the table.
#   stars  1 … 3 (a code is only made after a win).
#   CRC-7  polynomial x^7 + x^3 + 1 (primitive): every single symbol typo and every transposition of two symbols
#          changes the remainder (a substitution is a ≤ 5-bit burst, a swap is d(x)·(x^5j + 1)·x^k and the
#          polynomial divides neither factor), two typos slip through 1 time in 128 before the field checks.
#   mask   the 64 bits under the top one are XORed with a fixed whitening mask (MASK_HI/MASK_LO) after the CRC, so
#          neighbouring tables do not give look-alike codes full of zeros. A constant XOR moves no error pattern:
#          the detection above is unchanged, and the all-zero code is not a valid one.
#
# API
#   encode(p) -> "TW-XXXX-XXXX-XXXXX"        p = {mode, gen, key, tenths, stars}; "" when a field is out of range
#   core(p) -> 13 symbols                    pack(p) / unpack(bits) -> bit arrays (selftest)
#   decode(text) -> {ok, err, err_text, mode, gen, key, tenths, stars, core, code, nick}   one typed / pasted code
#   normalize(text) -> {ok, err, core}       Crockford: case-insensitive, I/L → 1, O → 0, no U, dashes and spaces
#                                            optional, Cyrillic look-alikes (А В Е К М Н О Р С Т Х З …) → Latin
#   extract(text) -> same as decode           the first code found in ANY pasted text (regex), with its «:ник»
#   extract_all(text) -> Array
#   share_text(p, info) -> String             «Мой стол — 1:42. Сможешь?» + table + code with nick + where to paste
#   nick_suffix(nick) -> ":Ник" | ""          clean_nick(raw) -> "" when it fails G.nick_error or the filter
#   plausible(tenths, pairs) -> bool          min_tenths(pairs)

const U: = preload("res://scripts/v10/duels/challenge/challenge_util.gd")

const ALPHABET: = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
const PREFIX: = "TW"
const SYMBOLS: = 13
const W_MODE: = 3
const W_GEN: = 3
const W_KEY: = 32
const W_TIME: = 17
const W_STARS: = 2
const W_CRC: = 7
const CRC_POLY: = 0x09  # x^7 + x^3 + 1 (the top term implicit)
const MASK_HI: = 0x5A3C96E1  # whitening of bits 1–32
const MASK_LO: = 0xB74D2F18  # whitening of bits 33–64
const TIME_MAX: = 131071  # 2^17 − 1 tenths
const KEY_MAX: = 4294967295  # 2^32 − 1
const TENTHS_PER_PAIR: = 3.5  # spec: a time is plausible only if ≥ 0,35 s × pairs

const MODE_PATH: = 1
const MODE_DAILY: = 2
const MODE_JOURNEY: = 3
const MODE_PEAK: = 4
const MODES: = {1: "path", 2: "daily", 3: "journey", 4: "peak"}
const MODE_IDS: = {"path": 1, "daily": 2, "journey": 3, "peak": 4}
const RESERVED: = [0, 5, 6, 7]

# characters a pasted or typed code may contain between its symbols
const SEPARATORS: = " \t\n\r -‐‑‒–—―−_.·"
# Cyrillic look-alikes typed on a Russian keyboard → Latin (1:1, so regex offsets stay valid for the nick)
const HOMO: = {"А": "A", "В": "B", "Е": "E", "К": "K", "М": "M", "Н": "H", "О": "O", "Р": "P", "С": "C", "Т": "T",
	"Х": "X", "У": "Y", "З": "3", "а": "a", "в": "b", "е": "e", "к": "k", "м": "m", "н": "h", "о": "o", "р": "p",
	"с": "c", "т": "t", "х": "x", "у": "y", "з": "3"}

const ERR: = {
	"empty": "Вставь код вызова",
	"none": "В тексте нет кода вызова. Скопируй сообщение друга целиком",
	"length": "В коде 13 знаков после TW. Проверь, что он скопирован целиком",
	"u": "Буквы U в кодах нет. Проверь этот знак",
	"chars": "В коде только цифры и латинские буквы. Проверь лишний знак",
	"crc": "Код не сходится. Проверь буквы и цифры",
	"mode": "Такого стола в этой версии нет. Обнови игру",
	"time": "Время в коде невозможное: так быстро этот стол не пройти",
	"gen": "Вызов сделан в другой версии стола. Обновите игру оба, и стол совпадёт",
	"key": "Такого стола нет. Проверь код",
	"future": "Этот день ещё не наступил. Проверь код",
	"closed": "Этот стол в твоей версии игры ещё не открыт",
}

static var _re_tw: RegEx
static var _re_bare: RegEx
static var _re_flat: RegEx

# ---------------------------------------------------------------- bits

static func _push(bits: Array, v: int, n: int) -> void:
	for i in range(n - 1, -1, -1):
		bits.append((v >> i) & 1)


static func _read(bits: Array, at: int, n: int) -> int:
	var v: = 0
	for i in n:
		v = (v << 1) | int(bits[at + i])
	return v


static var _mask: Array = []


static func mask_bits() -> Array:
	if _mask.is_empty():
		_mask = [0]
		_push(_mask, MASK_HI, 32)
		_push(_mask, MASK_LO, 32)
	return _mask


static func _whiten(bits: Array) -> Array:
	var m: = mask_bits()
	var out: = bits.duplicate()
	for i in range(1, mini(out.size(), m.size())):
		out[i] = int(out[i]) ^ int(m[i])
	return out


static func crc7(bits: Array) -> int:
	var reg: = 0
	for b in bits:
		var top: = ((reg >> 6) & 1) ^ int(b)
		reg = (reg << 1) & 0x7F
		if top == 1:
			reg ^= CRC_POLY
	return reg


static func fields_ok(p: Dictionary) -> bool:
	var m: = int(p.get("mode", -1))
	var gv: = int(p.get("gen", -1))
	var k: = int(p.get("key", -1))
	var t: = int(p.get("tenths", -1))
	var s: = int(p.get("stars", -1))
	return m >= 1 and m < 8 and not m in RESERVED and gv >= 0 and gv < 8 and k >= 0 and k <= KEY_MAX \
		and t >= 1 and t <= TIME_MAX and s >= 1 and s <= 3


# 65 bits, index 0 = the always-zero top bit
static func pack(p: Dictionary) -> Array:
	var bits: = [0]
	_push(bits, int(p.mode), W_MODE)
	_push(bits, int(p.gen), W_GEN)
	_push(bits, int(p.key), W_KEY)
	_push(bits, int(p.tenths), W_TIME)
	_push(bits, int(p.stars), W_STARS)
	_push(bits, crc7(bits.slice(1)), W_CRC)
	return _whiten(bits)


static func unpack(coded: Array) -> Dictionary:
	if coded.size() != SYMBOLS * 5 or int(coded[0]) != 0:
		return {"ok": false, "err": "crc"}
	var bits: = _whiten(coded)
	var body: = bits.slice(1, 1 + 57)
	var crc: = _read(bits, 58, W_CRC)
	if crc7(body) != crc:
		return {"ok": false, "err": "crc"}
	var p: = {"ok": true, "err": ""}
	p.mode = _read(bits, 1, W_MODE)
	p.gen = _read(bits, 4, W_GEN)
	p.key = _read(bits, 7, W_KEY)
	p.tenths = _read(bits, 39, W_TIME)
	p.stars = _read(bits, 56, W_STARS)
	if int(p.mode) in RESERVED:
		p.ok = false
		p.err = "mode"
	elif int(p.stars) < 1:
		p.ok = false
		p.err = "crc"
	elif int(p.tenths) < 1:
		p.ok = false
		p.err = "time"
	return p


static func core(p: Dictionary) -> String:
	if not fields_ok(p):
		return ""
	var bits: = pack(p)
	var s: = ""
	for i in SYMBOLS:
		s += ALPHABET[_read(bits, i * 5, 5)]
	return s


static func pretty(c: String) -> String:
	if c.length() != SYMBOLS:
		return ""
	return "%s-%s-%s-%s" % [PREFIX, c.substr(0, 4), c.substr(4, 4), c.substr(8, 5)]


static func encode(p: Dictionary) -> String:
	return pretty(core(p))


static func bits_of_core(c: String) -> Array:
	var bits: = []
	for ch in c:
		_push(bits, ALPHABET.find(ch), 5)
	return bits

# ---------------------------------------------------------------- normalisation

static func map_chars(text: String) -> String:
	var out: = ""
	for ch in text:
		out += String(HOMO.get(ch, ch))
	return out


static func normalize(text: String) -> Dictionary:
	var t: = map_chars(text.strip_edges()).to_upper()
	var s: = ""
	for ch in t:
		if SEPARATORS.find(ch) >= 0:
			continue
		s += ch
	if s == "":
		return {"ok": false, "err": "empty", "core": ""}
	if s.begins_with(PREFIX) and s.length() == SYMBOLS + PREFIX.length():
		s = s.substr(PREFIX.length())
	s = s.replace("I", "1").replace("L", "1").replace("O", "0")
	if s.length() != SYMBOLS:
		return {"ok": false, "err": "length", "core": s}
	for ch in s:
		if ch == "U":
			return {"ok": false, "err": "u", "core": s}
		if ALPHABET.find(ch) < 0:
			return {"ok": false, "err": "chars", "core": s}
	return {"ok": true, "err": "", "core": s}


static func err_text(e: String) -> String:
	return String(ERR.get(e, ERR.crc))


static func _fail(e: String, extra: = {}) -> Dictionary:
	var d: = {"ok": false, "err": e, "err_text": err_text(e)}
	d.merge(extra)
	return d


# one code typed by hand or pasted alone (with or without «TW», dashes, spaces and a «:ник» tail)
static func decode(text: String) -> Dictionary:
	var raw: = text.strip_edges()
	var nick: = ""
	var colon: = raw.find(":")
	if colon >= 0:
		nick = clean_nick(raw.substr(colon + 1))
		raw = raw.substr(0, colon)
	var n: = normalize(raw)
	if not n.ok:
		return _fail(n.err)
	return _decode_core(String(n.core), nick)


static func _decode_core(c: String, nick: String) -> Dictionary:
	var p: = unpack(bits_of_core(c))
	if not p.ok:
		return _fail(String(p.err), {"core": c})
	p.erase("ok")
	p.ok = true
	p.err_text = ""
	p.core = c
	p.code = pretty(c)
	p.nick = nick
	p.mode_id = String(MODES.get(int(p.mode), ""))
	return p

# ---------------------------------------------------------------- extraction from any text

static func _regexes() -> void:
	if _re_tw != null:
		return
	var sep: = "[\\s\\-\\x{2010}-\\x{2015}\\x{2212}]{0,2}"
	var tail: = "(?::[ ]?([^\\s:,;!?«»\"'()\\[\\]<>]{1,24}))?"
	_re_tw = RegEx.new()
	_re_tw.compile("(?i)(?<![0-9A-Z])T\\s?W" + sep + "([0-9A-Z]{4})" + sep + "([0-9A-Z]{4})" + sep + "([0-9A-Z]{5})(?![0-9A-Z])" + tail)
	_re_bare = RegEx.new()
	_re_bare.compile("(?i)(?<![0-9A-Z])([0-9A-Z]{4})[\\-\\x{2010}-\\x{2015}\\x{2212}]([0-9A-Z]{4})[\\-\\x{2010}-\\x{2015}\\x{2212}]([0-9A-Z]{5})(?![0-9A-Z])" + tail)
	_re_flat = RegEx.new()
	_re_flat.compile("(?i)(?<![0-9A-Z])([0-9A-Z]{13})(?![0-9A-Z])" + tail)


static func _nick_at(src: String, m: RegExMatch, grp: int) -> String:
	if m.get_start(grp) < 0:
		return ""
	return clean_nick(src.substr(m.get_start(grp), m.get_end(grp) - m.get_start(grp)))


# All codes in the text, in order. «TW…» candidates that fail their check are kept as errors (a typo the player
# should hear about); bare candidates without «TW» are kept only when they decode (a random word is not a code).
static func extract_all(text: String) -> Array:
	_regexes()
	var mapped: = map_chars(text)
	var out: = []
	var seen: = {}
	for m in _re_tw.search_all(mapped):
		var joined: = m.get_string(1) + m.get_string(2) + m.get_string(3)
		var n: = normalize(joined)
		var d: Dictionary
		if not n.ok:
			d = _fail(n.err)
		else:
			d = _decode_core(String(n.core), _nick_at(text, m, 4))
		d.at = m.get_start()
		seen[m.get_start(1)] = true
		out.append(d)
	for re in [_re_bare, _re_flat]:
		for m in (re as RegEx).search_all(mapped):
			if seen.has(m.get_start(1)) or _inside_tw(out, m.get_start()):
				continue
			var joined2: = m.get_string(1) + (m.get_string(2) + m.get_string(3) if re == _re_bare else "")
			var n2: = normalize(joined2)
			if not n2.ok:
				continue
			var d2: = _decode_core(String(n2.core), _nick_at(text, m, 4 if re == _re_bare else 2))
			if d2.ok:
				d2.at = m.get_start()
				seen[m.get_start(1)] = true
				out.append(d2)
	out.sort_custom(func(a, b): return int(a.at) < int(b.at))
	return out


static func _inside_tw(found: Array, at: int) -> bool:
	for d in found:
		if absi(int(d.get("at", -100)) - at) <= 4:
			return true
	return false


# the first valid code of the text; if none is valid but a «TW…» code was there, its error (a typo)
static func extract(text: String) -> Dictionary:
	if text.strip_edges() == "":
		return _fail("empty")
	var all: = extract_all(text)
	for d in all:
		if d.ok:
			return d
	if not all.is_empty():
		return all[0]
	# a lone code typed loosely («tw 7k2p m9qx 4h8rt») is still a code
	var lone: = decode(text)
	if lone.ok:
		return lone
	return _fail("none")

# ---------------------------------------------------------------- nick, plausibility, share text

static func nick_suffix(nick: String) -> String:
	var n: = " ".join(nick.strip_edges().split(" ", false))
	if n == "" or not U.nick_ok(n):
		return ""
	return ":" + n.replace(" ", "_")


static func clean_nick(raw: String) -> String:
	var n: = raw.strip_edges().rstrip(".…").replace("_", " ")
	n = " ".join(n.split(" ", false))
	if n == "" or not U.nick_ok(n):
		return ""
	return n


static func min_tenths(pairs: int) -> int:
	return int(ceil(pairs * TENTHS_PER_PAIR))


static func plausible(tenths: int, pairs: int) -> bool:
	return tenths >= maxi(1, min_tenths(pairs)) and tenths <= TIME_MAX


# info = {line?, mode_name, table, stars, nick}
static func share_text(p: Dictionary, info: Dictionary) -> String:
	var t: = U.fmt_time(int(p.tenths))
	var code: = encode(p) + nick_suffix(String(info.get("nick", "")))
	var lines: = PackedStringArray()
	lines.append(String(info.get("line", "Мой стол — %s. Сможешь?" % t)))
	lines.append("%s · %s · %s" % [String(info.get("mode_name", "Путь")), String(info.get("table", "")), U.stars_text(int(p.stars))])
	lines.append("Код вызова: %s" % code)
	lines.append("Tile Waifu → Столы → Соперницы → Вызов по коду → Вставить")
	return "\n".join(lines)
