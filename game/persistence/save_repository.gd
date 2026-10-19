class_name SaveRepository
extends RefCounted

const SCHEMA_VERSION: int = 1
const CONTENT_VERSION: int = 2
const GRAPH_VERSION: int = 1
const LAYOUT_VERSION: int = 1

var last_error: String = ""
var mode: StringName
var path: String
var _verified_text := ""
var _verified_profile: ProfileState
var _primary_valid := false
var _records_json := "[]"
var _writer: Thread
var _background_result: Variant


func _init(profile_mode: StringName = &"normal", base_path: String = "user://profiles") -> void:
	mode = profile_mode
	path = base_path.path_join(String(mode)).path_join("profile.json")


func load_profile() -> ProfileState:
	if is_saving():
		return null
	var started := DebugLog.begin()
	var loaded := _load_profile()
	DebugLog.operation(&"profile.load", started, {"ok": loaded != null, "error": last_error})
	return loaded.copy() if loaded != null else null


func _load_profile() -> ProfileState:
	last_error = ""
	if mode not in [&"normal", &"god"]:
		last_error = "未知档案模式。"
		return null
	var main := _read_file(path)
	_primary_valid = main.has("profile")
	var profile: ProfileState = main.get("profile")
	if profile == null:
		var backup := _read_file(path + ".bak")
		profile = backup.get("profile")
		if profile != null:
			last_error = "主档不可用：%s 已读取有效备份。" % main.error
		elif not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
			profile = ProfileState.new()
			profile.mode = mode
			_verified_text = ""
			_verified_profile = null
			_records_json = "[]"
		else:
			last_error = "档案与备份均不可用，原文件已保留。主档：%s；备份：%s" % [main.error, backup.error]
			return null
	_report_versions(profile)
	return profile


func save_profile(candidate: ProfileState, expected_revision: int) -> bool:
	if is_saving():
		return false
	var started := DebugLog.begin()
	var saved := _save_profile(candidate, expected_revision)
	DebugLog.operation(&"profile.save", started, {"ok": saved, "revision": expected_revision + 1, "error": last_error}, true)
	return saved


func is_saving() -> bool:
	return _writer != null


func save_profile_async(candidate: ProfileState, expected_revision: int, tree: SceneTree) -> bool:
	if is_saving():
		return false
	# The caller can keep using its profile. Only this private snapshot and this
	# repository's cache belong to the worker until it has been joined.
	var snapshot := candidate.copy() if candidate != null else null
	return await _save_owned_profile_async(snapshot, expected_revision, tree)


func _save_owned_profile_async(snapshot: ProfileState, expected_revision: int, tree: SceneTree) -> bool:
	# RunSession transfers its private proposed profile until the awaited commit.
	# No live state/caller-held collections may be mutated during that handoff.
	if is_saving(): return false
	var started := Time.get_ticks_usec()
	var result: Variant = await _run_background(_save_profile.bind(snapshot, expected_revision), tree)
	var saved: bool = result == true
	DebugLog.background_operation(&"profile.save_async", (Time.get_ticks_usec() - started) / 1000.0, {"ok": saved, "revision": expected_revision + 1, "error": last_error})
	return saved


func load_profile_async(tree: SceneTree) -> ProfileState:
	if is_saving(): return null
	var started := Time.get_ticks_usec()
	var loaded: ProfileState = (await _run_background(_load_snapshot, tree)) as ProfileState
	DebugLog.background_operation(&"profile.load_async", (Time.get_ticks_usec() - started) / 1000.0, {"ok": loaded != null, "error": last_error})
	return loaded


func _load_snapshot() -> ProfileState:
	var loaded := _load_profile()
	return loaded.copy() if loaded != null else null


func protect_transfer_backup_async(expected_revision: int, tree: SceneTree) -> bool:
	if is_saving(): return false
	var result: Variant = await _run_background(_protect_transfer_backup.bind(expected_revision), tree)
	return result == true


func _run_background(action: Callable, tree: SceneTree) -> Variant:
	_writer = Thread.new()
	var error := _writer.start(action)
	if error != OK:
		_writer = null
		_save_error("启动档案线程", error)
		return null
	while _writer != null and _writer.is_alive():
		await tree.process_frame
	finish_pending_save()
	return _background_result


func finish_pending_save() -> void:
	# Normal completion joins an already finished worker. Shutdown also joins so
	# the engine cannot tear down the writer during its atomic replacement.
	if _writer == null: return
	_background_result = _writer.wait_to_finish()
	_writer = null


func _save_profile(candidate: ProfileState, expected_revision: int) -> bool:
	last_error = ""
	if candidate == null or candidate.mode != mode or mode not in [&"normal", &"god"]:
		last_error = "候选档案与保存模式不同。"
		return false
	if candidate.revision != expected_revision + 1:
		last_error = "候选修订必须为预期修订加一。"
		return false
	var current := _load_profile()
	if current == null:
		return false
	if current.revision != expected_revision:
		last_error = "档案已改变，请重新读取（预期 %d，实际 %d）。" % [expected_revision, current.revision]
		return false
	# Keep the original pre-contraction archive independently of rotating backups.
	if current.content_version < CONTENT_VERSION and not FileAccess.file_exists(path + ".v1.json"):
		var original := path if _primary_valid else path + ".bak"
		if FileAccess.file_exists(original):
			var preserved := DirAccess.copy_absolute(original, path + ".v1.json")
			if preserved != OK:
				return _save_error("保留旧规则档案", preserved)
	last_error = ""
	var phase_started := DebugLog.begin()
	# This synchronous transaction only reads the candidate; it does not need a
	# second deep copy of the whole immutable history before encoding it.
	var data := candidate.to_dict(false)
	# Historical records already validated from the current disk bytes need no
	# second recursive validation. Changed/new records still cross the boundary.
	var validation := data.duplicate()
	var changed_records: Array = []
	var history_prefix_unchanged: bool = data.records.size() >= current.records.size()
	for index in data.records.size():
		if index >= current.records.size() or data.records[index] != current.records[index]:
			changed_records.append(data.records[index])
			if index < current.records.size(): history_prefix_unchanged = false
	validation.records = changed_records
	if ProfileState.from_dict(validation) == null:
		last_error = "候选档案包含无效字段或无法保存的对象。"
		return false
	DebugLog.end(&"profile.validate_candidate", phase_started)
	var envelope := {"schema_version": SCHEMA_VERSION, "content_version": candidate.content_version, "graph_version": candidate.graph_version, "layout_version": candidate.layout_version, "revision": candidate.revision}
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		return _save_error("创建档案目录", error)
	var temporary := path + ".tmp"
	phase_started = DebugLog.begin()
	var records_unchanged := history_prefix_unchanged and changed_records.is_empty()
	var added_json := JSON.stringify(changed_records, "", false) if history_prefix_unchanged and not records_unchanged else "[]"
	var records_json := _records_json
	if not records_unchanged:
		records_json = _records_json.trim_suffix("]") + ("," if not current.records.is_empty() else "") + added_json.substr(1) if history_prefix_unchanged else JSON.stringify(data.records, "", false)
	var fields := PackedStringArray()
	var live_fields := PackedStringArray()
	for key: String in data:
		var field := JSON.stringify(key) + ":" + (records_json if key == "records" else JSON.stringify(data[key], "", false))
		fields.append(field)
		if key != "records": live_fields.append(field)
	var encoded := JSON.stringify(envelope, "", false).trim_suffix("}") + ',"profile":{' + ",".join(fields) + "}}"
	DebugLog.end(&"profile.encode", phase_started)
	phase_started = DebugLog.begin()
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _save_error("写入临时档案", FileAccess.get_open_error())
	file.store_string(encoded)
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		return _save_error("写入临时档案", error)
	if FileAccess.get_file_as_string(temporary) != encoded:
		last_error = "临时档案验证失败：写入内容不一致。"
		return false
	DebugLog.end(&"profile.write_verify", phase_started)
	phase_started = DebugLog.begin()
	# Only a validated primary may replace the last valid backup.
	if _primary_valid:
		error = DirAccess.copy_absolute(path, path + ".bak.tmp")
		if error != OK:
			return _save_error("写入档案备份", error)
		if FileAccess.get_file_as_string(path + ".bak.tmp") != _verified_text:
			last_error = "档案备份验证失败：内容已改变。"
			return false
		error = DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
		if error != OK:
			return _save_error("替换档案备份", error)
	error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		return _save_error("替换档案", error)
	_verified_text = encoded
	# Keep the same canonical String/number representation as a fresh disk read.
	var canonical: Dictionary
	if history_prefix_unchanged:
		canonical = JSON.parse_string("{" + ",".join(live_fields) + "}")
		# The previous parsed records are private and already canonical. Public
		# loads copy them; caller-owned records are never adopted into this cache.
		canonical.records = current.records.duplicate()
		if not records_unchanged: canonical.records.append_array(JSON.parse_string(added_json))
	else:
		canonical = JSON.parse_string(encoded).profile
	_verified_profile = ProfileState._from_validated_dict(canonical, false)
	_records_json = records_json
	DebugLog.end(&"profile.backup_commit", phase_started)
	return true


func protect_transfer_backup(expected_revision: int) -> bool:
	if is_saving(): return false
	return _protect_transfer_backup(expected_revision)


func _protect_transfer_backup(expected_revision: int) -> bool:
	var main := _read_file(path)
	var current: ProfileState = main.get("profile")
	if current == null or current.revision != expected_revision or not current.run_checkpoint.get("facts", {}).has("god_transfer"):
		last_error = "接管锁定检查点不可用，未发布God档。"
		return false
	var error := DirAccess.copy_absolute(path, path + ".bak.tmp")
	if error != OK: return _save_error("保护接管备份", error)
	var checked := _read_file(path + ".bak.tmp")
	if not checked.has("profile"):
		last_error = "接管备份验证失败，未发布God档。"
		return false
	error = DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
	return true if error == OK else _save_error("替换接管备份", error)


func _read_file(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"error": error_string(FileAccess.get_open_error())}
	var json := JSON.new()
	var text := file.get_as_text()
	file.close()
	# Compare actual file contents, not timestamps/revision alone: external edits
	# and same-revision corruption must still invalidate the parsed snapshot.
	if _verified_profile != null and text == _verified_text:
		return {"profile": _verified_profile}
	var error := json.parse(text)
	if error != OK:
		return {"error": "JSON 第 %d 行：%s" % [json.get_error_line(), json.get_error_message()]}
	var data: Variant = json.data
	if not data is Dictionary or not ProfileState.is_count(data.get("schema_version")) or int(data.schema_version) != SCHEMA_VERSION:
		return {"error": "不支持的存档结构版本。"}
	if not data.get("profile") is Dictionary:
		return {"error": "缺少档案快照。"}
	var profile := ProfileState.from_dict(data.profile)
	if profile == null or profile.mode != mode:
		return {"error": "档案字段无效或模式不匹配。"}
	for field: String in ["revision", "content_version", "graph_version", "layout_version"]:
		if not ProfileState.is_count(data.get(field)) or int(data[field]) != int(data.profile[field]):
			return {"error": "封套与档案的 %s 不一致。" % field}
	_verified_text = text
	_verified_profile = profile
	_records_json = JSON.stringify(profile.records, "", false)
	return {"profile": profile}


func _report_versions(profile: ProfileState) -> void:
	if profile.content_version != CONTENT_VERSION:
		var message := "内容版本发生变化，请重新验证配置与本局检查点。"
		if not profile.diagnostics.has(message):
			profile.diagnostics.append(message)
	if profile.graph_version != GRAPH_VERSION:
		var message := "天赋拓扑版本发生变化，请重新验证原始分配。"
		if not profile.diagnostics.has(message):
			profile.diagnostics.append(message)
	# Layout changes do not alter earned characters or allocations.


func _save_error(action: String, error: Error) -> bool:
	last_error = "%s失败（%s）。" % [action, error_string(error)]
	return false
