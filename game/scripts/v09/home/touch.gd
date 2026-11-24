class_name V9Touch
extends RefCounted

# 0.9 live heroine at home — the rules (no nodes, testable headless; V9HomeLive draws the result).
#
# Zones (classify): a tap point in the art's own pixels against a geometry Dictionary
#   {head: Vector2, head_r, hand: Vector2 (optional), hand_r, cx, band_y: Vector2(y0, y1), band_dx: Vector2(min, max),
#    body: Rect2}
#   -> chest / hip guard ("body") > "hand" (the prop she holds) > "head" (hair, face) > "outfit" (sleeves and shoulders: the band beside her
#   torso, never its middle) > "body" (anything else on her: a quiet bounce, no line, no affection) > "bg" (the room).
#   Only tasteful zones react: chest, hips and legs fall into "body".
# Taps (decide): an instance per home screen keeps the cooldowns.
#   decide(zone, now) -> {kind: "react" | "spam" | "cool" | "quiet", zone, line: bool, aff: bool, i: line index}
#   ("cool": a tap during the spam cooldown — a small acknowledge only (V9HomeLive._cool_ack: soft click, tap haptic,
#   press on her bubble / squash, tiny expression flicker), no line or affection; "quiet": «body» — no answer at all)
#   - a new bubble at most every TALK_CD s (a tap in between only bounces / changes her face)
#   - SPAM_N taps on her inside SPAM_WIN s -> one «hey, not so fast» reaction, then SPAM_CD s of quiet bounces
#   - affection +AFF on a tap on head / hand / outfit while G.pet_left() > 0 (the 0.8 daily cap of 3 touches),
#     at most one per AFF_GAP s; the background never gives affection
#   commit_aff() spends one of today's touches and adds the affection (G.S.pet, G.add_aff; the caller saves).

const AFF: = 5
const TALK_CD: = 2.6
const AFF_GAP: = 1.2
const SPAM_N: = 5
const SPAM_WIN: = 3.0
const SPAM_CD: = 3.0
const HER: = ["head", "hand", "outfit", "body"]
const AFF_ZONES: = ["head", "hand", "outfit"]

# the hand that holds her prop on the rigged base art (assets/hero/<id>.png, 848×1264 px): mc the 中 tile,
# rin the tea bowl, hana the tile on a stick, yue her free hand (the fan sits over the chest: not a zone),
# nova the hologram tile
# 0.9 fix: mc's tile sits up and right of where the old point was (535, 262 reached her bust and the qipao
# keyhole); each hand has its own radius, and a chest / hip guard (classify) runs before every zone
const RIG_HAND: = {"mc": Vector2(598, 232), "rin": Vector2(215, 392), "hana": Vector2(560, 235),
	"yue": Vector2(585, 650), "nova": Vector2(205, 330)}
const RIG_HAND_R: = {"mc": 50.0, "rin": 58.0, "hana": 50.0, "yue": 50.0, "nova": 55.0}
const CHEST_K: = 1.15
# painting «outfit» band in face-square units (s): y from the square's bottom, dx from the centre line — shoulders
# and upper arms only. Per-painting overrides for poses where the default still lands on the body.
const ART_BAND: = {"default": [Vector2(-0.1, 0.55), Vector2(0.5, 1.05)],
	"rin_after": [Vector2(-0.2, 0.08), Vector2(0.35, 0.9)],
	"nova_ssr": [Vector2(-0.1, 0.4), Vector2(0.65, 1.1)]}

var last_line_t: = -100.0
var last_aff_t: = -100.0
var spam_until: = -100.0
var taps: Array[float] = []
var last_i: = {}


static func classify(g: Dictionary, p: Vector2) -> String:
	# guard first: the chest (ellipse × CHEST_K) and the hips / legs (below the waist in the torso column) are
	# never a reacting zone, whatever hand or band circle overlaps them
	if _guarded(g, p):
		return "body"
	if g.has("hand") and g.hand is Vector2 and p.distance_to(g.hand) <= float(g.get("hand_r", 50.0)):
		return "hand"
	if p.distance_to(g.head) <= float(g.head_r):
		return "head"
	var by: Vector2 = g.band_y
	var bd: Vector2 = g.band_dx
	var dx: = absf(p.x - float(g.cx))
	if p.y >= by.x and p.y <= by.y and dx >= bd.x and dx <= bd.y:
		return "outfit"
	if (g.body as Rect2).has_point(p):
		return "body"
	return "bg"


static func _guarded(g: Dictionary, p: Vector2) -> bool:
	if not g.has("chest_c"):
		return false
	var cc: Vector2 = g.chest_c
	var cr: Vector2 = (g.chest_r as Vector2) * CHEST_K
	var q: = (p - cc) / cr
	if q.length_squared() <= 1.0:
		return true
	if g.has("waist_y") and p.y >= float(g.waist_y) and absf(p.x - float(g.cx)) <= cr.x * 1.15:
		return (g.body as Rect2).has_point(p)
	return false


# geometry of the rigged hero (Hero.RIGS, art px)
static func rig_geom(h: String) -> Dictionary:
	var rig: Dictionary = Hero.RIGS.get(h, Hero.RIGS.mc)
	var cr: Vector2 = rig.chest_r
	var cc: Vector2 = rig.chest_c
	var neck: Vector2 = rig.neck
	var g: = {"head": rig.head_c, "head_r": float(rig.head_r) * 1.05, "cx": cc.x,
		"band_y": Vector2(neck.y + 12.0, float(rig.waist_y) - 20.0), "band_dx": Vector2(cr.x * 1.0, cr.x * 2.25),
		"body": Rect2(float(rig.feet.x) - 230.0, float(rig.head_c.y) - 140.0, 460.0, float(rig.feet.y) - float(rig.head_c.y) + 140.0),
		"chest_c": cc, "chest_r": cr, "waist_y": float(rig.waist_y)}
	if RIG_HAND.has(h):
		g["hand"] = RIG_HAND[h]
		g["hand_r"] = float(RIG_HAND_R.get(h, 50.0))
	return g


# geometry of an outfit painting from its head-and-shoulders square (V9Ults face_rect, in the texture's pixels):
# no hand zone (every painting holds its props elsewhere). The «outfit» band covers shoulders and upper arms only
# (ART_BAND, per painting `key` when the pose needs it); the chest ellipse and everything below the band is «body».
static func art_geom(face_rect: Rect2, key: = "") -> Dictionary:
	var s: = face_rect.size.x
	var head: = Vector2(face_rect.position.x + s * 0.5, face_rect.position.y + face_rect.size.y * 0.42)
	var bottom: = face_rect.end.y
	var band: Array = ART_BAND.get(key, ART_BAND.default)
	var by: Vector2 = band[0]
	var bd: Vector2 = band[1]
	return {"head": head, "head_r": s * 0.34, "cx": head.x,
		"band_y": Vector2(bottom + s * by.x, bottom + s * by.y), "band_dx": Vector2(s * bd.x, s * bd.y),
		"body": Rect2(head.x - s * 1.05, face_rect.position.y, s * 2.1, s * 5.0),
		"chest_c": Vector2(head.x, bottom + s * 0.4), "chest_r": Vector2(s * 0.5, s * 0.42) / CHEST_K,
		"waist_y": bottom + s * 0.9}


# the Маджонг-тян lobby video (assets/v09/video/mc_lobby.ogv, 720×1280, drawn full screen): measured on its first
# frame (mc_lobby_still.webp)
static func video_geom() -> Dictionary:
	return {"head": Vector2(373, 316), "head_r": 70.0, "hand": Vector2(505, 398), "hand_r": 54.0, "cx": 375.0,
		"band_y": Vector2(445, 560), "band_dx": Vector2(80, 150), "body": Rect2(225, 240, 300, 920)}


func decide(zone: String, now: float) -> Dictionary:
	var out: = {"kind": "quiet", "zone": zone, "line": false, "aff": false, "i": -1}
	if zone == "bg":
		if now - last_line_t >= TALK_CD * 1.5:
			out.kind = "react"
			out.line = true
			last_line_t = now
			out.i = _pick(zone)
		return out
	# «body» (chest, hips, legs) never reacts and never counts toward the spam line: repeated pokes there get nothing
	if zone == "body":
		return out
	taps.append(now)
	while not taps.is_empty() and now - taps[0] > SPAM_WIN:
		taps.pop_front()
	if now < spam_until:
		# the spam cooldown still answers the touch (V9HomeLive._cool_ack: a press + tap haptic and a tiny expression
		# flicker), with no line and no affection; only «body» stays fully quiet
		out.kind = "cool"
		return out
	if taps.size() >= SPAM_N:
		spam_until = now + SPAM_CD
		taps.clear()
		out.kind = "spam"
		out.zone = "spam"
		out.line = true
		last_line_t = now
		out.i = _pick("spam")
		return out
	out.kind = "react"
	if now - last_line_t >= TALK_CD:
		out.line = true
		last_line_t = now
		out.i = _pick(zone)
	if zone in AFF_ZONES and G.pet_left() > 0 and now - last_aff_t >= AFF_GAP:
		out.aff = true
		last_aff_t = now
	return out


func _pick(zone: String) -> int:
	var n: = V9TouchLines.pool(str(G.S.get("partner", "mc")), zone).size()
	if n <= 0:
		return -1
	var i: = randi() % n
	if n > 1 and int(last_i.get(zone, -1)) == i:
		i = (i + 1) % n
	last_i[zone] = i
	return i


static func commit_aff(h: String) -> void:
	if G.pet_left() <= 0:
		return
	G.S.pet.n = int(G.S.pet.n) + 1
	G.add_aff(h, AFF)
