extends SceneTree

var checks: int = 0
var failures: int = 0
var base: String


class GatedRepository:
	extends SaveRepository
	var permit := Semaphore.new()
	var reject := false
	var worker_was_main := true

	func _save_profile(candidate: ProfileState, revision: int) -> bool:
		worker_was_main = Thread.is_main_thread()
		permit.wait()
		if reject:
			last_error = "injected write failure"
			return false
		return super._save_profile(candidate, revision)


func _init() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	base = "res://.temp/godot-m4/profile/save-%d" % Time.get_ticks_usec()
	if "--performance" in OS.get_cmdline_user_args():
		_measure_saves()
		return
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
	_test_verified_snapshot()
	await _test_async_save()
	print("Profile save: %d checks, %d failures; evidence %s" % [checks, failures, base])
	quit(0 if failures == 0 else 1)


func _collect_async(action: Callable, result: Dictionary) -> void:
	result["ok"] = await action.call()


func _test_async_save() -> void:
	var repository := GatedRepository.new(&"normal", base.path_join("async"))
	var proposed := repository.load_profile()
	proposed.revision = 1
	proposed.records.append({"note": "submitted"})
	var result := {}
	_collect_async(repository.save_profile_async.bind(proposed, 0, self), result)
	proposed.records[0].note = "caller changed"
	for frame in 3: await process_frame
	check(result.is_empty() and repository.is_saving(), "后台等待时主循环继续推进")
	check(not await repository.save_profile_async(proposed, 0, self), "同一仓库拒绝重叠写入")
	check(repository.load_profile() == null and not repository.save_profile(proposed, 0), "后台拥有缓存期间同步访问被阻止")
	repository.permit.post()
	while result.is_empty(): await process_frame
	check(result.ok and not repository.worker_was_main and not repository.is_saving(), "后台线程提交并完整join")
	var loaded := repository.load_profile()
	check(loaded.records[0].note == "submitted", "提交快照与随后修改的候选隔离")
	var previous := FileAccess.get_file_as_bytes(repository.path)
	var session := RunSession.new(repository, loaded)
	session.save_tree = self
	repository.reject = true
	result.clear()
	_collect_async(session.begin.bind(&"frost", AppSettings.new()), result)
	await process_frame
	check(session.run_id.is_empty() and session.profile.revision == 1, "等待保存回执时远征尚未发布")
	repository.permit.post()
	while result.is_empty(): await process_frame
	check(not result.ok and session.run_id.is_empty() and FileAccess.get_file_as_bytes(repository.path) == previous, "后台写入失败保留原状态与档案")
	repository.reject = false
	repository.permit.post()
	check(await session.begin(&"frost", AppSettings.new()) and session.profile.revision == 2, "失败后异步重试成功才发布远征")
	var stale := session.profile.copy()
	stale.revision = 2
	repository.permit.post()
	check(not await repository.save_profile_async(stale, 1, self), "异步路径保留修订冲突检查")
	var final_profile := session.profile.copy()
	final_profile.revision += 1
	result.clear()
	_collect_async(repository.save_profile_async.bind(final_profile, 2, self), result)
	repository.permit.post()
	repository.finish_pending_save()
	while result.is_empty(): await process_frame
	check(result.ok and not repository.is_saving() and repository.load_profile().revision == 3, "退出join完成原子替换且回执仅消费一次")
	var reopened := await repository.load_profile_async(self)
	check(reopened != null and reopened.revision == 3 and reopened.records[0].note == "submitted", "后台读取返回独立有效档案")
	session = RunSession.new(repository, reopened)
	session.save_tree = self
	check(await session.restore(), "异步远征恢复")
	var god_repository := SaveRepository.new(&"god", base.path_join("async"))
	repository.permit.post()
	repository.permit.post()
	check(await session.isolate_to_god(god_repository), "后台完成普通档锁定、备份保护、God提交及源档清理")
	check(not repository.load_profile().has_pending_run() and god_repository.load_profile().has_pending_run(), "跨档转移独立重读后仅God档可继续")


func _measure_saves() -> void:
	var source := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--source-profile="): source = argument.trim_prefix("--source-profile=")
	assert(not source.is_empty())
	var rows: Array[Dictionary] = []
	for stress: bool in [false, true]:
		var repository := SaveRepository.new(&"normal", base.path_join("extreme" if stress else "baseline"))
		DirAccess.make_dir_recursive_absolute(repository.path.get_base_dir())
		if stress:
			check(DirAccess.copy_absolute(source, repository.path) == OK, "实际档案复制到隔离目录")
		var started := Time.get_ticks_usec()
		var profile := repository.load_profile()
		var load_ms := float(Time.get_ticks_usec() - started) / 1000.0
		check(profile != null, "性能档案读取成功")
		if profile == null: continue
		var times: Array[float] = []
		var starting_records := profile.records.size()
		for iteration in 3:
			var next := profile.copy()
			next.revision += 1
			if iteration == 2:
				next.records.append(profile.records[-1].duplicate(true) if stress else {"reason":"victory", "characters":0})
			started = Time.get_ticks_usec()
			DebugLog._spans.clear()
			check(repository.save_profile(next, profile.revision), "性能候选完整提交")
			times.append(float(Time.get_ticks_usec() - started) / 1000.0)
			profile = next
			if iteration == 2: print("SAVE_PHASES ", DebugLog._spans)
		var row := {"group": "extreme" if stress else "baseline", "records_before": starting_records, "records_after": profile.records.size(), "load_ms": load_ms, "steady_save_ms": times.slice(0,2), "append_save_ms":times[2]}
		var reopened := SaveRepository.new(&"normal", repository.path.get_base_dir().get_base_dir()).load_profile()
		check(reopened != null and reopened.to_dict() == ProfileState.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict()))).to_dict(), "独立读取完整持久化数据而非内存缓存")
		rows.append(row)
		print("SAVE_PERF ", JSON.stringify(row))
	FileAccess.open(base.path_join("performance.json"), FileAccess.WRITE).store_string(JSON.stringify(rows, "\t"))
	print("Save performance: %d checks, %d failures; %s" % [checks, failures, base])
	quit(0 if failures == 0 else 1)


func _test_verified_snapshot() -> void:
	var repository := SaveRepository.new(&"normal", base.path_join("verified"))
	var profile := repository.load_profile()
	profile.revision = 1
	profile.records.append({"note":"original", "values":[1,2,3]})
	check(repository.save_profile(profile,0), "无历史新档首次序列化合法")
	var fresh := SaveRepository.new(&"normal", base.path_join("verified")).load_profile()
	var canonical := ProfileState.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
	check(fresh != null and fresh.records == canonical.records, "新实例能读回首次提交")
	profile.records[0].note = "mutated after save"
	var exposed := repository.load_profile()
	exposed.records[0].values.append(4)
	check(repository.load_profile().records == fresh.records, "候选与读取结果的修改不污染已验证快照")
	var candidate := fresh.copy()
	candidate.revision = 2
	candidate.records[0].values.append(RefCounted.new())
	check(not repository.save_profile(candidate,1), "修改旧历史时仍拒绝非JSON对象")
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(repository.path))
	envelope.profile.records[0].note = "external same revision"
	_write(repository.path,JSON.stringify(envelope))
	check(repository.load_profile().records[0].note == "external same revision", "同修订外部修改按实际字节使缓存失效")
	var preserved := repository.load_profile()
	var next := preserved.copy()
	next.revision = 2
	next.records.append({"note":"new record"})
	check(repository.save_profile(next,1), "新历史完整验证并提交")
	next.revision = 3
	next.records.remove_at(0)
	check(repository.save_profile(next,2), "历史删除与重排不复用错误序列化片段")
	check(SaveRepository.new(&"normal", base.path_join("verified")).load_profile().records == next.records, "更新后的历史可独立重开")


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
	check(session.call("begin", &"flame", AppSettings.new()), "旧档案可以开始收缩后的远征")
	check(FileAccess.get_file_as_bytes(repository.path + ".v1.json") == original, "迁移保留逐字节原档独立副本")
	check(session.profile.manual_characters == 2400 and session.profile.records.size() == 1 and session.profile.allocations == old.allocations, "迁移保留字符、记录与原配置资料")
	check(session.selection.growth_hp == 8 and session.selection.instances.is_empty() and session.selection.talents.is_empty(), "字符自动产生轻量成长，旧节点不兑换局内遗物或能力")
	check(not session.call("begin", &"storm", AppSettings.new()), "已有远征不允许隐式覆盖")
	check(session.call("restart", &"storm", AppSettings.new()) and FileAccess.get_file_as_bytes(repository.path + ".v1.json") == original, "明确重开后的保存不覆盖迁移原档")


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
