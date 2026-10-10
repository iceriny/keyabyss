class_name SaveRepository
extends RefCounted

const SCHEMA_VERSION: int = 1
const CONTENT_VERSION: int = 2
const GRAPH_VERSION: int = 1
const LAYOUT_VERSION: int = 1

var last_error: String = ""
var mode: StringName
var path: String


func _init(profile_mode: StringName = &"normal", base_path: String = "user://profiles") -> void:
	mode = profile_mode
	path = base_path.path_join(String(mode)).path_join("profile.json")


func load_profile() -> ProfileState:
	var started := DebugLog.begin()
	var loaded := _load_profile()
	DebugLog.operation(&"profile.load", started, {"ok": loaded != null, "error": last_error})
	return loaded


func _load_profile() -> ProfileState:
	last_error = ""
	if mode not in [&"normal", &"god"]:
		last_error = "未知档案模式。"
		return null
	var main := _read_file(path)
	var profile: ProfileState = main.get("profile")
	if profile == null:
		var backup := _read_file(path + ".bak")
		profile = backup.get("profile")
		if profile != null:
			last_error = "主档不可用：%s 已读取有效备份。" % main.error
		elif not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
			profile = ProfileState.new()
			profile.mode = mode
		else:
			last_error = "档案与备份均不可用，原文件已保留。主档：%s；备份：%s" % [main.error, backup.error]
			return null
	_report_versions(profile)
	return profile


func save_profile(candidate: ProfileState, expected_revision: int) -> bool:
	var started := DebugLog.begin()
	var saved := _save_profile(candidate, expected_revision)
	DebugLog.operation(&"profile.save", started, {"ok": saved, "revision": expected_revision + 1, "error": last_error}, true)
	return saved


func _save_profile(candidate: ProfileState, expected_revision: int) -> bool:
	last_error = ""
	if candidate == null or candidate.mode != mode or mode not in [&"normal", &"god"]:
		last_error = "候选档案与保存模式不同。"
		return false
	if candidate.revision != expected_revision + 1:
		last_error = "候选修订必须为预期修订加一。"
		return false
	var current := load_profile()
	if current == null:
		return false
	if current.revision != expected_revision:
		last_error = "档案已改变，请重新读取（预期 %d，实际 %d）。" % [expected_revision, current.revision]
		return false
	# Keep the original pre-contraction archive independently of rotating backups.
	if current.content_version < CONTENT_VERSION and not FileAccess.file_exists(path + ".v1.json"):
		var original := path if _read_file(path).has("profile") else path + ".bak"
		if FileAccess.file_exists(original):
			var preserved := DirAccess.copy_absolute(original, path + ".v1.json")
			if preserved != OK:
				return _save_error("保留旧规则档案", preserved)
	last_error = ""
	var data := candidate.to_dict()
	if ProfileState.from_dict(data) == null:
		last_error = "候选档案包含无效字段或无法保存的对象。"
		return false
	var envelope := {"schema_version": SCHEMA_VERSION, "content_version": candidate.content_version, "graph_version": candidate.graph_version, "layout_version": candidate.layout_version, "revision": candidate.revision, "profile": data}
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		return _save_error("创建档案目录", error)
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _save_error("写入临时档案", FileAccess.get_open_error())
	file.store_string(JSON.stringify(envelope, "\t"))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		return _save_error("写入临时档案", error)
	var verified := _read_file(temporary)
	if not verified.has("profile"):
		last_error = "临时档案验证失败：%s" % verified.error
		return false
	# Only a validated primary may replace the last valid backup.
	if _read_file(path).has("profile"):
		error = DirAccess.copy_absolute(path, path + ".bak.tmp")
		if error != OK:
			return _save_error("写入档案备份", error)
		var checked_backup := _read_file(path + ".bak.tmp")
		if not checked_backup.has("profile"):
			last_error = "档案备份验证失败：%s" % checked_backup.error
			return false
		error = DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
		if error != OK:
			return _save_error("替换档案备份", error)
	error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		return _save_error("替换档案", error)
	return true


func protect_transfer_backup(expected_revision: int) -> bool:
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
	var error := json.parse(file.get_as_text())
	file.close()
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
