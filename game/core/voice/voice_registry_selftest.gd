extends SceneTree

# Voice registry selftest (P44, GDD 8.4). Pure data: no scenes, no autoloads, no audio.
#   godot --headless --path game -s res://core/voice/voice_registry_selftest.gd
#   godot --headless --path game -s res://core/voice/voice_registry_selftest.gd -- --strict_files=1
# Prints:  VOICE_FILES have/total pct%      (map coverage: how many ids already have an audio file; 0/240 is expected now)
#          VOICE_REGISTRY ok/total          (schema + text + red-line + duration checks; exit code 0 when all pass)
# --strict_files=1 adds the check "every id has its file" (release gate "карта реплик 100%").
# The mora counter and the duration model mirror tools/audio/voice_registry.py; the registry stores `mora` and
# `dur_est`, so the two implementations cross-check each other.

const REG := "res://core/voice/voice_registry.json"
const SMALL := "ゃゅょぁぃぅぇぉゎャュョァィゥェォヮ"
const PUNCT := "、。！？…〜"
const TRAIL := "、。！？…〜 "

var ok := 0
var total := 0
var fails: Array = []


func t(name: String, cond: bool, detail: String = "") -> void:
	total += 1
	if cond:
		ok += 1
	else:
		fails.append("FAIL %s %s" % [name, detail])


func mora(s: String) -> int:
	var n := 0
	for i in s.length():
		var ch := s[i]
		var o := s.unicode_at(i)
		if (o >= 0x3041 and o <= 0x3096) or (o >= 0x30A1 and o <= 0x30FA) or ch == "ー":
			if SMALL.find(ch) < 0:
				n += 1
	return n


func pause_of(ch: String, pause: Dictionary) -> float:
	return float(pause.get(ch, 0.0))


func pauses(s: String, pause: Dictionary) -> float:
	var end := s.length()
	while end > 0 and TRAIL.find(s[end - 1]) >= 0:
		end -= 1
	var total_p := 0.0
	var run := 0.0
	for i in end:
		var ch := s[i]
		if PUNCT.find(ch) >= 0:
			run = maxf(run, pause_of(ch, pause))
		else:
			total_p += run
			run = 0.0
	return total_p + run


func to_hira(s: String) -> String:
	var out := ""
	for i in s.length():
		var o := s.unicode_at(i)
		if o >= 0x30A1 and o <= 0x30F6:
			out += String.chr(o - 0x60)
		else:
			out += s[i]
	return out


func kana_charset_ok(s: String) -> bool:
	if s.length() == 0:
		return false
	for i in s.length():
		var o := s.unicode_at(i)
		var ch := s[i]
		var good := (o >= 0x3041 and o <= 0x3096) or (o >= 0x30A1 and o <= 0x30FA) or ch == "ー" or PUNCT.find(ch) >= 0
		if not good:
			return false
	return true


func kana_subsequence_ok(jp: String, kana: String) -> bool:
	var k := to_hira(kana)
	var pos := 0
	var j := to_hira(jp)
	for i in j.length():
		var o := j.unicode_at(i)
		if o >= 0x3041 and o <= 0x3096:
			var idx := k.find(j[i], pos)
			if idx < 0:
				return false
			pos = idx + 1
	return true


func contains_any(text: String, words: Array) -> Array:
	var hit: Array = []
	for w in words:
		if text.find(String(w)) >= 0:
			hit.append(w)
	return hit


func ru_words(s: String) -> Array:
	var out: Array = []
	var cur := ""
	for i in s.length():
		var ch := s[i].to_lower()
		var o := ch.unicode_at(0)
		if (o >= 0x0430 and o <= 0x044F) or o == 0x0451:
			cur += ch
		else:
			if cur != "":
				out.append(cur)
			cur = ""
	if cur != "":
		out.append(cur)
	return out


func file_exists_for(path: String) -> bool:
	return FileAccess.file_exists(path)


func run() -> void:
	var strict_files := false
	for a in OS.get_cmdline_user_args():
		if a == "--strict_files=1" or a == "--strict_files":
			strict_files = true

	t("registry.exists", FileAccess.file_exists(REG), REG)
	if not FileAccess.file_exists(REG):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(REG))
	t("registry.parses", parsed is Dictionary)
	if not (parsed is Dictionary):
		return
	var doc: Dictionary = parsed
	var lines: Array = doc.get("lines", [])
	var pol: Dictionary = doc.get("policy", {})
	var classes: Dictionary = doc.get("classes", {})
	var cats: Array = doc.get("categories", [])
	var heroines: Array = doc.get("heroines", [])
	var names: Dictionary = doc.get("names", {})
	var rate := float(doc.get("rate_mora_per_s", 0.0))
	var pause: Dictionary = doc.get("pause_s", {})
	var jp_stop: Array = pol.get("jp_stop", [])
	var ru_stop: Array = pol.get("ru_stop", [])
	var player_ru: Array = pol.get("player_ru", [])
	var player_jp: Array = pol.get("player_jp", [])
	var tmpl := String(doc.get("file_template", ""))

	t("heroines.count_10", heroines.size() == 10, str(heroines.size()))
	t("categories.count_24", cats.size() == 24, str(cats.size()))
	t("lines.count_240", lines.size() == 240, str(lines.size()))
	t("rate.positive", rate > 1.0)
	t("policy.jp_stop_core", jp_stop.has("胸") and jp_stop.has("お尻") and jp_stop.has("太もも") and jp_stop.has("下着") and jp_stop.has("どこ見"))
	t("policy.ru_stop_core", ru_stop.has("грудь") and ru_stop.has("коленк") and ru_stop.has("куда смотришь") and ru_stop.has("интим"))
	t("policy.player_words", player_ru.size() > 3 and player_jp.size() > 1)

	var id_re := RegEx.new()
	id_re.compile("^([a-z]+)_([a-z0-9_]+)_([0-9]+)$")

	var seen_ids := {}
	var seen_files := {}
	var per_h := {}
	var per_h_cats := {}
	var prio := {}
	var have := 0
	for r in lines:
		var rid := String(r.get("id", ""))
		var h := String(r.get("heroine", ""))
		seen_ids[rid] = true
		seen_files[String(r.get("file", ""))] = true
		per_h[h] = int(per_h.get(h, 0)) + 1
		if not per_h_cats.has(h):
			per_h_cats[h] = []
		var cn := String(r.get("category", "")) + "_" + str(int(r.get("n", 0)))
		per_h_cats[h].append(cn if cats.has(cn) else String(r.get("category", "")))
		prio[String(r.get("category", ""))] = int(r.get("priority", 9))

		var m := id_re.search(rid)
		t(rid + ".id_format", m != null and m.get_string(1) == h and m.get_string(2) == String(r.get("category", "")) and int(m.get_string(3)) == int(r.get("n", -1)), rid)
		var jp := String(r.get("jp", ""))
		var kana := String(r.get("kana", ""))
		var ru := String(r.get("ru", ""))
		t(rid + ".ru_nonempty", ru.strip_edges() != "")
		t(rid + ".jp_nonempty", jp.strip_edges() != "")
		t(rid + ".kana_charset", kana_charset_ok(kana), kana)
		t(rid + ".kana_matches_jp", kana_subsequence_ok(jp, kana), jp)
		var mo := mora(kana)
		t(rid + ".mora_matches", mo == int(r.get("mora", -1)), "%d vs %s" % [mo, str(r.get("mora"))])
		var est := snappedf(float(mo) / rate + pauses(kana, pause), 0.01)
		t(rid + ".dur_est_matches", absf(est - float(r.get("dur_est", -1.0))) < 0.011, "%s vs %s" % [str(est), str(r.get("dur_est"))])
		var cl: Dictionary = classes.get(String(r.get("class", "")), {})
		var lo := float(cl.get("min_s", 0.0))
		var hi := float(cl.get("max_s", 0.0))
		var de := float(r.get("dur_est", -1.0))
		t(rid + ".dur_in_range", de >= lo - 0.0001 and de <= hi + 0.0001, "%s not in [%s,%s] %s" % [str(de), str(lo), str(hi), kana])
		t(rid + ".dur_bounds_match_class", absf(float(r.get("dur_min", -1.0)) - lo) < 0.0001 and absf(float(r.get("dur_max", -1.0)) - hi) < 0.0001)
		# red lines
		var bad_jp := contains_any(jp, jp_stop) + contains_any(kana, jp_stop)
		var bad_ru := contains_any(ru.to_lower(), ru_stop)
		t(rid + ".stoplist", bad_jp.is_empty() and bad_ru.is_empty(), str(bad_jp) + str(bad_ru))
		# no other heroine's name (own name is removed first: シリン contains リン)
		var own: Dictionary = names.get(h, {})
		var t_ru := ru.replace(String(own.get("ru", "?")), "")
		var t_jp := jp.replace(String(own.get("jp", "?")), "")
		var t_kana := kana.replace(String(own.get("jp", "?")), "")
		var names_bad: Array = []
		for h2 in names:
			if h2 == h:
				continue
			var n2: Dictionary = names[h2]
			if t_ru.find(String(n2["ru"])) >= 0 or t_jp.find(String(n2["jp"])) >= 0 or t_kana.find(String(n2["jp"])) >= 0:
				names_bad.append(h2)
		t(rid + ".no_other_heroine", names_bad.is_empty(), str(names_bad))
		if String(r.get("category", "")) == "touch_bold":
			var ok_ru := false
			for w in ru_words(ru):
				if player_ru.has(w):
					ok_ru = true
			t(rid + ".flirt_targets_player", ok_ru and not contains_any(jp, player_jp).is_empty(), jp)
		t(rid + ".np_flag", r.get("np", false) == true or String(r.get("status", "")) != "text_draft")
		t(rid + ".file_path", String(r.get("file", "")) == tmpl.format({"heroine": h, "id": rid}), String(r.get("file", "")))
		if file_exists_for(String(r.get("file", ""))):
			have += 1

	t("ids.unique", seen_ids.size() == lines.size(), "%d unique of %d" % [seen_ids.size(), lines.size()])
	t("files.unique", seen_files.size() == lines.size())
	for h in heroines:
		t(String(h) + ".lines_24", int(per_h.get(h, 0)) == 24, str(per_h.get(h, 0)))
		var got: Array = per_h_cats.get(h, [])
		got.sort()
		var want: Array = cats.duplicate()
		want.sort()
		t(String(h) + ".categories_match", got == want)
	t("priority.ladder", int(prio.get("ron", 99)) < int(prio.get("tsumo", 99)) and int(prio.get("tsumo", 99)) < int(prio.get("riichi", 99)) and int(prio.get("riichi", 99)) < int(prio.get("combo_t2", 99)) and int(prio.get("combo_t2", 99)) <= 9)

	var pct := 100.0 * float(have) / maxf(float(lines.size()), 1.0)
	print("VOICE_FILES %d/%d %.1f%%" % [have, lines.size(), pct])
	if strict_files:
		t("files.all_exist", have == lines.size(), "%d/%d" % [have, lines.size()])


func _initialize() -> void:
	run()
	for f in fails.slice(0, 60):
		print(f)
	if fails.size() > 60:
		print("... %d more" % (fails.size() - 60))
	print("VOICE_REGISTRY %d/%d" % [ok, total])
	quit(0 if ok == total else 1)
