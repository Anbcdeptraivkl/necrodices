extends SceneTree
## Runs test suites (tests/test_*.gd, TestSuite) in one headless process, case by case.
## Args after `--`:
##   (none)               every suite
##   battle_sim           one suite; several names run several
##   battle_sim:swipe     the cases of a suite whose name contains `swipe` (repeat for more)
##   --changed            the suites whose COVERS match a file changed against HEAD (staged,
##                        unstaged or untracked); `--since=<ref>` compares with a ref instead
##   --list               print suites and cases, run nothing
## Exit code 1 when a case fails. Entry point: tools\test.cmd.

const DIR := "res://tests"
## Changes to these run every suite.
const EVERYTHING := ["tests/_suite.gd", "tests/_run.gd", "project.godot"]


func _initialize() -> void:
	_run.call_deferred()  # cases may await frames: the tree runs only after _initialize


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var filters := {}  # suite -> case name parts (empty = every case)
	var since := ""
	for arg in args:
		if arg.begins_with("--since="):
			since = arg.trim_prefix("--since=")
		elif not arg.begins_with("--"):
			var suite := arg.get_slice(":", 0)
			if not filters.has(suite):
				filters[suite] = []
			if not arg.contains(":"):
				filters[suite].append("")  # the whole suite
			else:
				filters[suite].append(arg.get_slice(":", 1))
	var changed: PackedStringArray = []
	var by_change := args.has("--changed") or since != ""
	if by_change:
		changed = _changed_files(since)
		print("changed: %d files%s" % [changed.size(), "" if since == "" else " since " + since])
	var suites := _suite_files()
	var picked: Array[String] = []
	var covered := {}
	for file in suites:
		var name := file.trim_prefix("test_").trim_suffix(".gd")
		if by_change:
			var hits := _covered_by(name, load(DIR.path_join(file)), changed)
			for path in hits:
				covered[path] = true
			if not hits.is_empty():
				picked.append(file)
		elif filters.is_empty() or filters.has(name):
			picked.append(file)
	if by_change:
		for path in changed:
			if not covered.has(path) and not _ignored(path):
				print("note: no suite covers %s" % path)
	if args.has("--list"):
		for file in picked:
			print("%s: %s" % [file, ", ".join(_cases(load(DIR.path_join(file))))])
		quit(0)
		return
	var ran := 0
	var failed: Array[String] = []
	var started := Time.get_ticks_msec()
	for file in picked:
		var name := file.trim_prefix("test_").trim_suffix(".gd")
		var script: GDScript = load(DIR.path_join(file))
		var suite: TestSuite = script.new()
		suite.tree = self
		var only: Array = filters.get(name, [])
		for case in _cases(script):
			if not only.is_empty() and not only.any(func(part: String) -> bool: return part == "" or case.contains(part)):
				continue
			var before := suite.failures
			var t0 := Time.get_ticks_msec()
			await suite.call(case)
			ran += 1
			var ok := suite.failures == before
			if not ok:
				failed.append("%s.%s" % [name, case])
			print("%s %s.%s (%d ms)" % ["PASS" if ok else "FAIL", name, case, Time.get_ticks_msec() - t0])
	print("%d cases, %d failed, %.1f s" % [ran, failed.size(), (Time.get_ticks_msec() - started) / 1000.0])
	for case in failed:
		print("  FAILED %s" % case)
	if ran == 0 and not by_change:
		print("no case matched %s" % [args])
	quit(1 if not failed.is_empty() or (ran == 0 and not by_change) else 0)


static func _suite_files() -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at(DIR):
		if file.begins_with("test_") and file.ends_with(".gd"):
			out.append(file)
	out.sort()
	return out


static func _cases(script: GDScript) -> Array[String]:
	var out: Array[String] = []
	for method in script.get_script_method_list():
		var name: String = method["name"]
		if name.begins_with("test_") and not out.has(name):
			out.append(name)
	return out


## The changed files a suite covers: its own file, its COVERS prefixes, or a runner file.
static func _covered_by(name: String, script: GDScript, changed: PackedStringArray) -> Array[String]:
	var covers: Array = script.get_script_constant_map().get("COVERS", [])
	var out: Array[String] = []
	for path in changed:
		var hit := path == "tests/test_%s.gd" % name or EVERYTHING.has(path)
		for prefix: String in covers:
			hit = hit or path.begins_with(prefix)
		if hit:
			out.append(path)
	return out


## Changes no test should cover: docs, skills, captures, editor metadata.
static func _ignored(path: String) -> bool:
	for prefix in ["docs/", ".claude/", "captures/", "tools/", "AGENTS.md", "CLAUDE.md", ".git"]:
		if path.begins_with(prefix):
			return true
	return path.ends_with(".uid") or path.ends_with(".import") or path.ends_with(".md")


## Repo-relative paths changed against HEAD (or `since`), untracked files included.
static func _changed_files(since: String) -> PackedStringArray:
	var out := PackedStringArray()
	var lines: Array = []
	OS.execute("git", ["status", "--porcelain", "--untracked-files=all"], lines)
	for chunk: String in lines:
		for line in chunk.split("\n", false):
			var path := line.substr(3).strip_edges()
			if path.contains(" -> "):
				path = path.get_slice(" -> ", 1)
			out.append(path.trim_prefix("\"").trim_suffix("\""))
	if since != "":
		var diff: Array = []
		OS.execute("git", ["diff", "--name-only", since], diff)
		for chunk: String in diff:
			for path in chunk.split("\n", false):
				if not out.has(path):
					out.append(path)
	return out
