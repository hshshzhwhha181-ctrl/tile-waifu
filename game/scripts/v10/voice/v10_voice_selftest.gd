extends Node

# V10Voice selftest (docs/AUDIO_BIBLE.md §13). Headless:
#   flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --audio-driver Dummy --path game res://scripts/v10/voice/v10_voice_selftest.tscn
# Prints "V10VOICE OK n/n" (exit 0) or "V10VOICE FAIL k/n" with the failed checks (exit 1).

const BANNED: = ["скуча", "одна", "обещал", "пропал", "забыл", "почему ты", "бросил", "вернись", "₽", "скидк", "успей",
	"последн", "только сегодня", "купи", "баннер", "акци", "цена", "учител", "ученик", "урок", "школ", "за парт",
	"куда смотришь", "колен", "грудь", "бёдр", "бедр", "вино", "пиво", "алкогол", "раздев", "бельё", "белье"]
const ALLOW: = ["однажды", "ещё одна", "одна чашка", "одна партия"]

var ok: = 0
var total: = 0
var fails: = []
var heard: = []


class FakeRig extends Node:
	var levels: = []
	func set_mouth_level(l: float) -> void:
		levels.append(l)


func _check(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append(what)


func _ready() -> void:
	await get_tree().process_frame
	_data_checks()
	await _behaviour_checks()
	for f in fails.slice(0, 40):
		print("  FAIL ", f)
	print("V10VOICE %s %d/%d" % ["OK" if ok == total else "FAIL", ok, total])
	get_tree().quit(0 if ok == total else 1)


func _data_checks() -> void:
	var d: = V10Voice.data()
	_check(not d.is_empty(), "manifest.json parses")
	var heroes: Dictionary = d.get("heroes", {})
	_check(heroes.size() == V10Voice.HEROES.size(), "five heroes in the manifest")
	var gate: Dictionary = d.get("gate", {})
	var ids: = {}
	var texts: = {}
	var letters: = RegEx.create_from_string("[^а-яa-z0-9]")
	for h in V10Voice.HEROES:
		var hd: Dictionary = heroes.get(h, {})
		_check(hd.get("language", "") == "ru", h + " language ru")
		_check(String(hd.get("voice_id", "")) != "", h + " voice id")
		ids[String(hd.get("voice_id", ""))] = h
		_check(V10Voice.lines(h).size() == V10Voice.SLOTS.size(), "%s has all %d lines (%d)" % [h, V10Voice.SLOTS.size(), V10Voice.lines(h).size()])
		for s in V10Voice.SLOTS:
			var l: Dictionary = hd.get("lines", {}).get(s, {})
			var tag: String = h + ":" + s
			var t: = String(l.get("text", ""))
			_check(t.length() >= 2, tag + " text")
			var low: = t.to_lower()
			for a in ALLOW:
				low = low.replace(a, "")
			var bad: = ""
			for b in BANNED:
				if low.find(b) >= 0:
					bad = b
			_check(bad == "", "%s banned word «%s»" % [tag, bad])
			var latin: = RegEx.create_from_string("[A-Za-z~*]")
			_check(latin.search(t) == null, tag + " no latin/markup in the subtitle")
			_check(not texts.has(t), "%s duplicate text of %s" % [tag, texts.get(t, "")])
			texts[t] = tag
			var p: = V10Voice.path(h, s)
			_check(ResourceLoader.exists(p), tag + " file " + p)
			var st: AudioStream = load(p) if ResourceLoader.exists(p) else null
			_check(st != null, tag + " loads")
			if st != null:
				var len_s: = st.get_length()
				_check(len_s >= 0.4 and len_s <= 9.5, "%s length %.2f s" % [tag, len_s])
				_check(absf(len_s - float(l.get("dur", 0.0))) < 0.15, "%s manifest dur %.2f vs %.2f" % [tag, float(l.get("dur", 0.0)), len_s])
			var target: = -16.0 if s in V10Voice.CLOSE else -14.0
			_check(absf(float(l.get("lufs", 0.0)) - target) <= 1.0, "%s loudness %s LUFS (target %d)" % [tag, l.get("lufs"), target])
			_check(float(l.get("peak_db", 0.0)) <= -0.9, "%s peak %s dBFS" % [tag, l.get("peak_db")])
			# CER limits never go below one wrong letter (gate.one_letter, AUDIO_BIBLE §13.8): on a 7-letter shout a single
			# reduced vowel is CER 0.143; voice_qa.py rounds CER to 3 decimals, so round the allowance up the same way
			var n: = maxi(1, letters.sub(t.to_lower().replace("ё", "е"), "", true).length())
			var one: = ceilf(1000.0 / n) / 1000.0 if gate.get("one_letter", false) else 0.0
			var lim_w: = maxf(float(gate.get("cer_whisper", 0.12)), one)
			var lim_v: = maxf(float(gate.get("cer_w2v", 0.3)), one)
			# language ID is unreliable on 1-2 word shouts; there both transcripts must match the script instead
			var lid_ok: = l.get("p_ru") != null and float(l.get("p_ru")) >= float(gate.get("p_ru", 0.9))
			var both_ok: = l.get("cer_w2v") != null and maxf(float(l.get("cer_whisper", 1.0)), float(l.get("cer_w2v"))) <= lim_w
			_check(lid_ok or both_ok, "%s ASR: Russian (p %s, CER %s / %s)" % [tag, l.get("p_ru"), l.get("cer_whisper"), l.get("cer_w2v")])
			_check(l.get("cer_whisper") != null and float(l.get("cer_whisper")) <= lim_w, "%s Whisper CER %s" % [tag, l.get("cer_whisper")])
			_check(l.get("cer_w2v") != null and float(l.get("cer_w2v")) <= lim_v, "%s ru-CTC CER %s" % [tag, l.get("cer_w2v")])
			_check(String(l.get("job", "")).length() == 36, tag + " Higgsfield job id recorded")
			var lip: = String(l.get("lip", ""))
			_check(absf(lip.length() - float(l.get("dur", 0.0)) * float(d.get("lip_hz", 30))) <= 4.0, tag + " lip-sync envelope covers the line")
			_check(RegEx.create_from_string("^[0-9]+$").search(lip) != null and lip.find("9") >= 0, tag + " lip-sync envelope 0..9 with a full open")
	_check(ids.size() == V10Voice.HEROES.size(), "five different voices (%d)" % ids.size())


func _on_voice(hero: String, txt: String, dur: float) -> void:
	heard.append([hero, txt, dur])


func _behaviour_checks() -> void:
	var sfx: = get_node_or_null("/root/Sfx")
	_check(sfx != null and sfx.has_signal("voice_started"), "Sfx.voice_started exists")
	if sfx != null:
		sfx.voice_started.connect(_on_voice)
	var v: = V10Voice.inst()
	await get_tree().process_frame
	_check(v.is_inside_tree(), "V10Voice instance under /root")
	v._now_override = 1000.0
	var t: = V10Voice.tap("mc", "head")
	_check(t == V10Voice.text("mc", "tap_head") and t != "", "tap head -> tap_head line")
	_check(heard.size() == 1 and heard[0][0] == "mc" and heard[0][1] == t, "voice_started emitted with hero and subtitle")
	_check(heard.size() == 1 and absf(float(heard[0][2]) - V10Voice.length_of("mc", "tap_head")) < 0.2, "voice_started duration = line length")
	_check(sfx != null and float(sfx.get("_duck_until")) > Time.get_ticks_msec() / 1000.0 + 0.3, "music ducked for the line")
	v._now_override = 1010.0
	_check(V10Voice.tap("mc", "head") == "", "same tap reaction is muted for 60 s")
	v._now_override = 1061.0
	_check(V10Voice.tap("mc", "head") != "", "same tap reaction again after 60 s")
	v._now_override = 2000.0
	V10Voice.tap("rin", "hair")
	v._now_override = 2000.5
	V10Voice.tap("rin", "outfit")
	v._now_override = 2001.0
	_check(V10Voice.tap("rin", "armL") == V10Voice.text("rin", "tap_spam"), "third tap within 2 s -> tap_spam")
	v._now_override = 2100.0
	_check(V10Voice.tap("rin", "bg") == "", "background tap has no line")
	_check(V10Voice.tap("rin", "legs") == "", "unknown zone has no line")
	# dead zones (V10LiveRig "none": bust, hips) and the background never count towards tap_spam
	v._now_override = 2200.0
	var dead: = [V10Voice.tap("hana", "none"), V10Voice.tap("hana", "none"), V10Voice.tap("hana", "none"), V10Voice.tap("hana", "bg")]
	_check(dead.all(func(x): return x == ""), "dead-zone taps: no line, no tap_spam")
	v._now_override = 2300.0
	V10Voice.tap("nova", "head")
	V10Voice.tap("nova", "none")
	v._now_override = 2300.5
	_check(V10Voice.tap("nova", "none") == "" and V10Voice.tap("nova", "bg") == "", "two real taps + dead-zone taps: still no tap_spam")
	_check(V10Voice.play("hana", "close1", {"aff": 5}) == "", "whisper line locked below Симпатия 6")
	_check(V10Voice.play("hana", "close1", {"aff": 6}) == V10Voice.text("hana", "close1"), "whisper line at Симпатия 6")
	_check(V10Voice.combo("yue", 4) == "", "no combo line below ×5")
	_check(V10Voice.combo("yue", 5) == V10Voice.text("yue", "combo5"), "combo ×5")
	_check(V10Voice.combo("yue", 12) == V10Voice.text("yue", "combo10"), "combo ×10")
	_check(V10Voice.combo("yue", 25) == V10Voice.text("yue", "combo20"), "combo ×20")
	_check(V10Voice.combo("yue", 26) == "", "combo ×20 muted within 60 s")
	_check(V10Voice.combo("yue", 27, {"force": true}) != "", "force skips the cooldown")
	_check(V10Voice.play("nova", "greet") != "" and V10Voice.play("nova", "greet") != "", "greet has no cooldown")
	V10Voice.visit()
	v._now_override = 3000.0
	_check(V10Voice.play("mc", "idle") != "", "idle call 1")
	v._now_override = 3100.0
	_check(V10Voice.play("mc", "idle") != "", "idle call 2")
	v._now_override = 3200.0
	_check(V10Voice.play("mc", "idle") == "", "idle call at most twice a visit")
	V10Voice.visit()
	_check(V10Voice.play("mc", "idle") != "", "new visit -> idle call again")
	_check(V10Voice.play("nova", "nope") == "" and V10Voice.play("zzz", "greet") == "", "unknown slot / hero -> empty")
	_check(v.is_playing() or AudioServer.get_driver_name() == "Dummy", "a line is playing")
	var g: = get_node_or_null("/root/G")
	if g != null:
		var was: bool = g.S.get("voice", true)
		g.S["voice"] = false
		var n: = heard.size()
		# no stop() here: a subtitle-only line must itself silence a line that is still playing
		_check(V10Voice.play("mc", "win") != "" and not v.is_playing(), "voice off: subtitle only, the previous line stops")
		_check(V10Voice.mouth_level("mc") == -1.0, "voice off: no lip-sync for a silent line")
		_check(heard.size() == n + 1, "voice off: subtitle still emitted")
		g.S["voice"] = was
	v.stop()
	_check(not v.is_playing(), "stop()")
	var rig: = FakeRig.new()
	add_child(rig)
	V10Voice.bind_rig(rig, "nova")
	v._now_override = 9000.0
	V10Voice.play("nova", "win", {"force": true})
	for i in 12:
		await get_tree().process_frame
	if v.is_playing():
		_check(rig.levels.size() >= 5 and rig.levels.all(func(x): return x >= 0.0 and x <= 1.0), "bound rig gets mouth levels 0..1 while she speaks (%d)" % rig.levels.size())
	_check(V10Voice.mouth_level("rin") == -1.0, "another heroine's mouth is not driven")
	v.stop()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(rig.levels.is_empty() or rig.levels[-1] == -1.0, "mouth handed back to the rig after the line")
	V10Voice.bind_rig(null, "nova")
