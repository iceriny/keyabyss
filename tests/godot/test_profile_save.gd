extends SceneTree

var checks: int = 0
var failures: int = 0
var base: String


func _init() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	base = "res://.temp/godot-m4/profile/save-%d" % Time.get_ticks_usec()
	var repository := SaveRepository.new(&"normal", base)
	var initial := repository.load_profile()
	check(initial != null and initial.revision == 0 and initial.mode == &"normal", "缺档建立新的普通档案")
	initial.allocations["frost"] = {"purchases": [{"id": "T01", "options": {"shape": "single"}}]}
	initial.run_checkpoint = {"random_state": "9223372036854775807", "reserve": [{"amount_q": 128, "claims": ["one"]}]}
	initial.records.append({"outcome": "victory", "rooms": [1, 2]})
	var first := initial.copy()
	first.revision = 1
	first.manual_characters = 100
	check(repository.save_profile(first, 0), "首次档案提交成功")
	check(initial.revision == 0 and initial.manual_characters == 0 and first.revision == 1, "保存不修改原始或候选档案")
	var loaded := SaveRepository.new(&"normal", base).load_profile()
	# JSON preserves numbers, but does not preserve GDScript int/float Variant types.
	var expected := ProfileState.from_dict(JSON.parse_string(JSON.stringify(first.to_dict())))
	check(loaded != null and loaded.to_dict() == expected.to_dict() and loaded.revision is int and loaded.manual_characters is int and loaded.run_checkpoint.random_state == "9223372036854775807", "完整纯数据档案重开一致")
	loaded.allocations.frost.purchases[0].options.shape = "changed"
	loaded.run_checkpoint.reserve[0].claims.append("changed")
	loaded.records[0].rooms.append(3)
	check(first.allocations.frost.purchases[0].options.shape == "single" and first.run_checkpoint.reserve[0].claims.size() == 1 and first.records[0].rooms.size() == 2, "嵌套配置检查点记录独立复制")
	var stale := first.copy()
	stale.revision = 1
	check(not repository.save_profile(stale, 0) and not repository.last_error.is_empty(), "磁盘修订变化拒绝旧候选")
	var second := first.copy()
	second.revision = 2
	second.manual_characters = 170
	check(repository.save_profile(second, 1), "第二次提交产生有效备份")
	var preserved_backup := FileAccess.get_file_as_string(repository.path + ".bak")
	_write(repository.path, "{ corrupt")
	var recovered := repository.load_profile()
	check(recovered != null and recovered.revision == 1 and recovered.manual_characters == 100 and not repository.last_error.is_empty(), "坏主档恢复最后有效备份并报告")
	var retry := recovered.copy()
	retry.revision = 2
	check(repository.save_profile(retry, 1), "备份恢复后的候选可重新保存")
	check(FileAccess.get_file_as_string(repository.path + ".bak") == preserved_backup, "坏主档没有污染有效备份")
	_write(repository.path, "{ broken again")
	check(repository.load_profile().revision == 1, "恢复后再次损坏仍可读原有效备份")
	_write(repository.path + ".bak", "{ also broken")
	check(repository.load_profile() == null and not repository.last_error.is_empty(), "主备均坏返回明确失败")
	check(not repository.save_profile(retry, 1) and FileAccess.get_file_as_string(repository.path) == "{ broken again", "坏档不被零进度或候选覆盖")
	_test_modes()
	_test_invalid_data()
	_test_versions()
	_test_migration_backup()
	_test_failed_write()
	print("Profile save: %d checks, %d failures; evidence %s" % [checks, failures, base])
	quit(0 if failures == 0 else 1)


func _test_modes() -> void:
	var normal := SaveRepository.new(&"normal", base.path_join("modes"))
	var god := SaveRepository.new(&"god", base.path_join("modes"))
	var ordinary := normal.load_profile()
	ordinary.revision = 1
	ordinary.manual_characters = 120
	ordinary.allocations["frost"] = {"purchases": ["T01"]}
	check(normal.save_profile(ordinary, 0), "普通模式提交")
	var unlimited := god.load_profile()
	unlimited.revision = 1
	unlimited.manual_characters = 300
	unlimited.allocations["fire"] = {"purchases": ["T02"]}
	check(god.save_profile(unlimited, 0), "God 模式独立提交")
	check(normal.load_profile().manual_characters == 120 and god.load_profile().manual_characters == 300, "模式字符与配置独立")
	unlimited.revision = 2
	check(not normal.save_profile(unlimited, 1), "跨模式保存拒绝")


func _test_invalid_data() -> void:
	var data := ProfileState.new().to_dict()
	data.manual_characters = 1.5
	check(ProfileState.from_dict(data) == null, "解析拒绝非整数字符")
	data.manual_characters = -1
	check(ProfileState.from_dict(data) == null, "解析拒绝负字符")
	data.manual_characters = 0
	data.allocations = {"frost": "invalid"}
	check(ProfileState.from_dict(data) == null, "解析拒绝非字典分配")
	data.allocations = {}
	data.run_checkpoint = {"active_node": RefCounted.new()}
	check(ProfileState.from_dict(data) == null, "解析拒绝业务对象序列化")
	data.run_checkpoint = {}
	data.settlements = {"rooms": {}, "runs": {"one": {"manual_characters": 1, "committed_characters": 2}}, "checkpoints": {}}
	check(ProfileState.from_dict(data) == null, "解析拒绝不一致的结算高水位")


func _test_versions() -> void:
	var repository := SaveRepository.new(&"normal", base.path_join("versions"))
	var profile := repository.load_profile()
	profile.revision = 1
	profile.layout_version = 2
	profile.allocations["frost"] = {"purchases": ["unknown-id"], "options": {"shape": "single"}}
	check(repository.save_profile(profile, 0), "布局版本独立保存")
	var layout := repository.load_profile()
	check(layout.allocations == profile.allocations and layout.diagnostics.is_empty(), "纯布局升级不退点或删原配置")
	layout.revision = 2
	layout.graph_version = 2
	layout.content_version = 3
	layout.manual_characters = 240
	check(repository.save_profile(layout, 1), "内容拓扑版本保留原始档案")
	var changed := repository.load_profile()
	check(changed.allocations == profile.allocations and changed.manual_characters == 240 and changed.diagnostics.size() == 2, "内容拓扑变化保留字符及未知 ID 并提供重验证诊断")
	var unknown := SaveRepository.new(&"normal", base.path_join("unknown"))
	DirAccess.make_dir_recursive_absolute(unknown.path.get_base_dir())
	_write(unknown.path, JSON.stringify({"schema_version": 999, "profile": ProfileState.new().to_dict()}))
	var original := FileAccess.get_file_as_string(unknown.path)
	check(unknown.load_profile() == null and FileAccess.get_file_as_string(unknown.path) == original, "未知结构版本明确失败且保留原档")


func _test_migration_backup() -> void:
	var repository := SaveRepository.new(&"normal", base.path_join("migration"))
	var old := repository.load_profile()
	old.content_version = 1
	old.revision = 1
	old.manual_characters = 2400
	old.allocations = {"frost": {"purchases": ["T01"]}}
	old.records.append({"reason": "victory", "characters": 2400})
	check(repository.save_profile(old, 0), "旧内容档案夹具保存")
	var original := FileAccess.get_file_as_bytes(repository.path)
	var session := RunSession.new(repository, repository.load_profile())
	check(session.begin(&"flame", AppSettings.new()), "旧档案可以开始收缩后的远征")
	check(FileAccess.get_file_as_bytes(repository.path + ".v1.json") == original, "迁移保留逐字节原档独立副本")
	check(session.profile.manual_characters == 2400 and session.profile.records.size() == 1 and session.profile.allocations == old.allocations, "迁移保留字符、记录与原配置资料")
	check(session.selection.growth_hp == 8 and session.selection.instances.is_empty() and session.selection.talents.is_empty(), "字符自动产生轻量成长，旧节点不兑换局内遗物或能力")
	check(session.begin(&"storm", AppSettings.new()) and FileAccess.get_file_as_bytes(repository.path + ".v1.json") == original, "后续保存不覆盖迁移原档")


func _test_failed_write() -> void:
	var repository := SaveRepository.new(&"normal", base.path_join("write-failure"))
	var profile := repository.load_profile()
	profile.revision = 1
	check(repository.save_profile(profile, 0), "失败情境准备有效主档")
	var original := FileAccess.get_file_as_string(repository.path)
	DirAccess.make_dir_recursive_absolute(repository.path + ".tmp")
	var candidate := profile.copy()
	candidate.revision = 2
	candidate.manual_characters = 200
	check(not repository.save_profile(candidate, 1) and not repository.last_error.is_empty(), "临时写入失败可报告并重试")
	check(FileAccess.get_file_as_string(repository.path) == original and profile.manual_characters == 0 and candidate.revision == 2, "保存失败不改变主档及内存状态")


func _write(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "测试夹具写入失败")
	file.store_string(contents)
	file.close()
