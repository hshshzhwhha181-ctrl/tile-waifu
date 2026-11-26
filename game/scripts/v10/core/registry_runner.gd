class_name V10RegistryRunner
extends Node

# --v10_selftest=all | fast | <id,id,…>   (main.gd _dev_args; docs/INTEGRATION_0.10.md §3.8)
# Runs EVERY module selftest of V10Registry as its own child process (the scene of the module, or main for
# responsive), reads the module's marker line and prints one line per module, then
#   V10_SELFTEST <green modules>/<modules with a selftest>   (exit code = number of red modules)
# Children run without flock (the parent already holds it), --v10_jobs=N at a time (default 3). needs_render
# modules (responsive, phone, mj_look) need a display: run the parent under
#   xvfb-run -a -s "-screen 0 1600x2700x24" godot --path game --rendering-driver opengl3 --audio-driver Dummy -- --v10_selftest=all
# without DISPLAY they are reported «skipped (no display)». tutorial runs --tut_static=1 («static only», §2.21).

var mode: = "all"
var jobs: = 3
var res_root: = ""
var tmp_dir: = ""
var _queue: Array = []
var _running: Array = []
var _results: = {}
var _t0: = 0


static func start(main: Node, a: Dictionary) -> void:
	var r: = V10RegistryRunner.new()
	r.name = "V10RegistryRunner"
	r.mode = str(a.get("v10_selftest", "all"))
	r.jobs = clampi(int(a.get("v10_jobs", "3")), 1, 8)
	main.add_child(r)


func _ready() -> void:
	res_root = ProjectSettings.globalize_path("res://").trim_suffix("/")
	tmp_dir = OS.get_cache_dir().path_join("tw_v10_selftest_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(tmp_dir)
	_t0 = Time.get_ticks_msec()
	var only: = []
	if not (mode in ["all", "fast"]):
		only = Array(mode.split(","))
	var has_display: = OS.get_environment("DISPLAY") != "" or OS.get_name() != "Linux"
	for e in V10Registry.selftests():
		var id: String = e.id
		var sp: Dictionary = e.spec
		if not only.is_empty() and not (id in only):
			continue
		if sp.is_empty():
			_results[id] = {"state": "none", "line": "no selftest (demo only)"}
			continue
		if bool(sp.get("needs_render", false)) and not has_display:
			_results[id] = {"state": "skipped", "line": "skipped (no display)"}
			continue
		_queue.append({"id": id, "spec": sp})
	print("V10_SELFTEST start: %d modules, %d jobs, mode %s" % [_queue.size(), jobs, mode])


func _cmd(id: String, sp: Dictionary) -> Array:
	var args: = []
	if not bool(sp.get("needs_render", false)):
		args.append("--headless")
	else:
		args.append_array(["--rendering-driver", "opengl3", "--resolution", str(sp.get("resolution", "720x1280"))])
	args.append_array(["--audio-driver", "Dummy", "--path", res_root])
	if sp.has("script"):
		args.append_array(["-s", str(sp.script)])
	elif str(sp.get("scene", "")) != "":
		args.append(str(sp.scene))
	args.append("--")
	var ua: Array = sp.get("fast_args", sp.get("args", [])) if mode == "fast" else sp.get("args", [])
	args.append_array(ua)
	return args


func _launch(job: Dictionary) -> void:
	var id: String = job.id
	var out: = tmp_dir.path_join(id + ".log")
	var rcf: = tmp_dir.path_join(id + ".rc")
	var exe: = OS.get_executable_path()
	if OS.get_name() == "Windows":
		var bat: = tmp_dir.path_join(id + ".cmd")
		var wparts: = [_wq(exe)]
		for a in _cmd(id, job.spec):
			wparts.append(_wq(str(a)))
		var f: = FileAccess.open(bat, FileAccess.WRITE)
		f.store_string("@echo off\r\n%s > %s 2>&1\r\necho %%ERRORLEVEL%%> %s\r\n" % [" ".join(wparts), _wq(out), _wq(rcf)])
		f.close()
		var pid_w: = OS.create_process("cmd.exe", ["/c", bat])
		_running.append({"id": id, "pid": pid_w, "out": out, "rc": rcf, "spec": job.spec, "t": Time.get_ticks_msec()})
		return
	var parts: = [_q(exe)]
	for a in _cmd(id, job.spec):
		parts.append(_q(str(a)))
	var sh: = "%s > %s 2>&1; echo $? > %s" % [" ".join(parts), _q(out), _q(rcf)]
	var pid: = OS.create_process("/bin/sh", ["-c", sh])
	_running.append({"id": id, "pid": pid, "out": out, "rc": rcf, "spec": job.spec, "t": Time.get_ticks_msec()})


static func _wq(s: String) -> String:
	return "\"" + s.replace("\"", "\"\"") + "\""


static func _q(s: String) -> String:
	return "'" + s.replace("'", "'\\''") + "'"


func _process(_dt: float) -> void:
	while _running.size() < jobs and not _queue.is_empty():
		_launch(_queue.pop_front())
	for i in range(_running.size() - 1, -1, -1):
		var r: Dictionary = _running[i]
		if FileAccess.file_exists(r.rc):
			var rc_txt: = FileAccess.get_file_as_string(r.rc).strip_edges()
			if rc_txt == "":
				continue
			_running.remove_at(i)
			_finish(r, int(rc_txt))
	if _running.is_empty() and _queue.is_empty():
		set_process(false)
		_report()


func _finish(r: Dictionary, rc: int) -> void:
	var sp: Dictionary = r.spec
	var marker: String = sp.get("marker", "")
	var txt: = FileAccess.get_file_as_string(r.out)
	var line: = ""
	for l in txt.split("\n"):
		if marker != "" and marker in l:
			line = l.strip_edges()
	var secs: = (Time.get_ticks_msec() - int(r.t)) / 1000.0
	var rc_ok: = rc == 0 or (OS.get_name() == "Windows" and rc == -1073741819 and not ("SCRIPT ERROR:" in txt) and not ("FAIL" in line))
	var ok: = line != "" and rc_ok
	# n/m on the marker line must agree (a module that prints «12/13» with rc 0 is still red)
	var re: = RegEx.create_from_string("(\\d+)/(\\d+)")
	var m: = re.search(line)
	if m and line.begins_with(marker) and "SELFTEST" in marker and int(m.get_string(1)) != int(m.get_string(2)):
		ok = false
	var state: = "ok" if ok else "FAIL"
	if bool(sp.get("static_only", false)):
		line += "  [static only]"
	_results[r.id] = {"state": state, "line": "%s (rc %d, %.0f s)" % [line if line != "" else "no marker «%s»" % marker, rc, secs], "log": r.out}
	print("V10_SELFTEST %-11s %-4s %s" % [r.id, state, _results[r.id].line])


func _report() -> void:
	var total: = 0
	var green: = 0
	var red: = 0
	print("──── V10_SELFTEST per module ────")
	for id in V10Registry.ids():
		if not _results.has(id):
			continue
		var e: Dictionary = _results[id]
		if e.state in ["ok", "FAIL"]:
			total += 1
			if e.state == "ok":
				green += 1
			else:
				red += 1
		print("  %-11s %-8s %s" % [id, e.state, e.line])
	print("V10_SELFTEST %d/%d (%.0f s)" % [green, total, (Time.get_ticks_msec() - _t0) / 1000.0])
	get_tree().quit(red)
