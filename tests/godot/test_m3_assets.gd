extends SceneTree

var checks := 0
var failures := 0
var compiler := BuildCompiler.new()
var service := CombatAssetService.new(compiler)


func _init() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func asset(id: String, content: StringName, scope: StringName = &"run", deadline: int = -1) -> CombatAssetInstance:
	var instance := CombatAssetInstance.new()
	instance.instance_id = id
	instance.content_id = content
	instance.source_id = &"reward" if deadline < 0 else &"loan"
	instance.expiry_scope = scope
	instance.expiry_index = deadline
	return instance


func _run() -> void:
	var selection := BuildSelection.new()
	selection.instances = [asset("owned", &"R001"), asset("borrowed", &"R001", &"chapter", 2)]
	var compiled := compiler.compile(selection)
	check(compiled.success(), "同种永久与借阅实例可编译")
	if not compiled.success():
		quit(1)
		return
	check(compiled.build.asset_stacks(&"R001") == 2, "按实例汇总层数")
	var reversed := BuildSelection.new()
	reversed.instances = [selection.instances[1], selection.instances[0]]
	check(compiler.compile(reversed).build.identity() == compiled.build.identity(), "实例选择顺序不影响快照")
	var exposed := compiled.build.asset_instances()
	exposed[0].instance_id = "changed"
	check(compiled.build.asset_instances()[0].instance_id == "borrowed", "快照实例通过副本读取")
	var remove := CombatAssetRequest.new()
	remove.action = CombatAssetRequest.Action.REMOVE
	remove.content_id = &"R001"
	remove.instance_id = "borrowed"
	var removed := service.prepare(selection, remove)
	check(removed.has("selection") and removed.selection.instances.size() == 1 and removed.selection.instances[0].instance_id == "owned", "删除仅针对指定份")
	check(selection.instances.size() == 2, "prepare不修改原选择")
	var run := RunCombatState.new()
	check(run.claim_asset(selection.instances[1].usage_key(), &"once"), "首次使用可领取")
	var returned := CombatAssetRequest.new()
	returned.action = CombatAssetRequest.Action.ADD
	returned.instance_id = "borrowed"
	returned.content_id = &"R001"
	returned.source_id = &"loan"
	returned.expiry_scope = &"chapter"
	returned.expiry_index = 2
	var restored := service.prepare(removed.selection, returned)
	check(restored.has("selection"), "同实例可返还")
	check(not run.claim_asset(restored.selection.instances[1].usage_key(), &"once"), "返还同实例不刷新已用机会")
	var duplicate := service.prepare(selection, returned)
	check(not duplicate.has("selection") and selection.instances.size() == 2, "重复ID失败无副作用")
	var too_many := BuildSelection.new()
	too_many.instances = [asset("a", &"R001"), asset("b", &"R001"), asset("c", &"R001"), asset("d", &"R001")]
	check(not compiler.compile(too_many).success() and too_many.instances.size() == 4, "超最大层数失败且不修改选择")
	selection.assets[&"R001"] = 1
	check(not compiler.compile(selection).success(), "正式与开发选择混用有诊断")
	selection.assets.clear()
	var parent := compiler.catalog.get_definition(&"R074").duplicate(true) as RelicDefinition
	parent.max_stacks = 2
	compiler.catalog.definitions[&"R074"] = parent
	var evolution := BuildSelection.new()
	evolution.talents = ["T20"]
	evolution.instances = [asset("parent-a", &"R074"), asset("parent-b", &"R074", &"room", 3)]
	var evolve := CombatAssetRequest.new()
	evolve.action = CombatAssetRequest.Action.EVOLVE
	evolve.instance_id = "parent-b"
	evolve.parent_id = &"R074"
	evolve.content_id = &"R084"
	var evolved := service.prepare(evolution, evolve)
	check(evolved.has("selection"), "演化单份允许其他同种父资产共存")
	if evolved.has("selection"):
		check(evolved.selection.instances[0].content_id == &"R074" and evolved.selection.instances[1].content_id == &"R084", "演化不替换另一份")
		check(evolved.selection.instances[1].usage_key() == "parent-b" and evolved.selection.instances[1].expiry_index == 3, "演化保持回执键与期限")
	check(evolution.instances[1].content_id == &"R074", "演化不修改原实例")
	var lab := BuildSelection.new()
	lab.assets[&"R001"] = 2
	var lab_build := compiler.compile(lab)
	check(lab_build.success() and lab_build.build.asset_instances()[1].usage_key() == "lab:R001:layer:1", "开发多层有确定且独立的回执键")
	lab.asset_instances[&"R001"] = "explicit-development-id"
	var explicit_first := compiler.compile(lab).build.asset_instances()[0].usage_key()
	var explicit_again := compiler.compile(lab).build.asset_instances()[0].usage_key()
	check(explicit_first == explicit_again, "显式开发ID重复编译不变")
	check(run.claim_asset(explicit_first, &"once") and not run.claim_asset(explicit_again, &"once"), "重复安装开发实例不刷新回执")
	print("M3 assets: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
