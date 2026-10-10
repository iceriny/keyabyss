extends SceneTree

var checks: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func receipt(room: int, count: int, reason: StringName = &"victory", mode: StringName = &"normal") -> RoomSettlementReceipt:
	return RoomSettlementReceipt.new("one-run", room, "attempt-%d" % room, reason, count, mode)


func _run() -> void:
	for sample: Array in [[0, 0], [999, 0], [1000, 1], [1999, 1], [2000, 2], [4999, 4], [5000, 5], [30000, 5]]:
		check(TalentProgress.level_for(sample[0]) == sample[1] and TalentProgress.health_for(sample[0]) == sample[1] * 4, "成长公式边界 %d" % sample[0])
	var profile := ProfileState.new()
	var first := TalentProgress.prepare(profile, receipt(1, 100))
	check(first.has("profile") and first.added_characters == 100 and profile.manual_characters == 0, "纯候选首次房结果只增加人工事实")
	var second := TalentProgress.prepare(first.profile, receipt(2, 70))
	check(second.profile.manual_characters == 170 and second.added_characters == 70, "两房 100 加 70 等于 170")
	var duplicate := TalentProgress.prepare(second.profile, receipt(2, 70))
	check(duplicate.profile.manual_characters == 170 and duplicate.added_characters == 0, "同回执重复结算零增量")
	var conflict := TalentProgress.prepare(second.profile, receipt(2, 71))
	check(not conflict.has("profile") and not conflict.diagnostics.is_empty(), "同身份不同字符拒绝")
	check(not TalentProgress.prepare(second.profile, receipt(2, 70, &"defeat")).has("profile"), "同身份不同终止原因拒绝")
	var late_first := TalentProgress.prepare(profile, receipt(2, 70))
	var early_second := TalentProgress.prepare(late_first.profile, receipt(1, 100))
	check(early_second.profile.manual_characters == 170 and early_second.added_characters == 100, "乱序房结果没有漏计或倒扣")
	check(TalentProgress.prepare(early_second.profile, receipt(2, 70)).added_characters == 0, "乱序旧结果不重复累计")
	check(first.profile.settlements.rooms.size() == 1 and profile.settlements.rooms.is_empty(), "候选嵌套回执不修改原档")
	check(ProfileState.from_dict(second.profile.to_dict()) != null, "结算候选可被严格解析往返")
	var retry := TalentProgress.prepare(profile, receipt(1, 100))
	check(retry.profile.to_dict() == first.profile.to_dict(), "保存未发布时原意图重试得到同候选")
	for reason: StringName in [&"victory", &"defeat", &"abandon", &"interrupted"]:
		check(TalentProgress.prepare(profile, receipt(1, 20, reason)).added_characters == 20, "正常终止原因都保留已赚字符 %s" % reason)
	check(not TalentProgress.prepare(profile, receipt(1, 20, &"practice")).has("profile"), "习字和非正式原因不增加成长")
	check(not TalentProgress.prepare(profile, receipt(1, 20, &"victory", &"god")).has("profile"), "普通档拒绝 God 回执")
	var god := ProfileState.new()
	god.mode = &"god"
	check(TalentProgress.prepare(god, receipt(1, 20, &"victory", &"god")).profile.manual_characters == 20 and profile.manual_characters == 0, "God 独立成长不污染普通档")
	var capped := profile.copy()
	capped.manual_characters = 15120
	var after_cap := TalentProgress.prepare(capped, receipt(1, 700))
	check(after_cap.profile.manual_characters == 15820 and TalentProgress.health_for(after_cap.profile.manual_characters) == 20, "封顶后仍累计人工字符")
	_test_checkpoints(profile)
	var frozen := receipt(1, 100)
	check(frozen.signature() == RoomSettlementReceipt.from_dict(frozen.to_dict()).signature(), "回执签名在序列化往返后稳定")
	check(RoomSettlementReceipt.new("a:b", 1, "c", &"victory", 1).identity() != RoomSettlementReceipt.new("a", 1, "b:c", &"victory", 1).identity(), "房身份不受分隔符碰撞影响")
	print("Talent progress: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_checkpoints(profile: ProfileState) -> void:
	var saved := TalentProgress.prepare_checkpoint(profile, receipt(1, 40, &"checkpoint"))
	check(saved.profile.manual_characters == 40 and saved.profile.settlements.rooms.is_empty(), "房内保存字符不消费终止结算身份")
	var repeated := TalentProgress.prepare_checkpoint(saved.profile, receipt(1, 40, &"checkpoint"))
	check(repeated.added_characters == 0, "相同房内高水位不重复计字符")
	var continued := TalentProgress.prepare_checkpoint(saved.profile, receipt(1, 60, &"checkpoint"))
	check(continued.profile.manual_characters == 60 and continued.added_characters == 20, "房内字符只补新高水位")
	var finished := TalentProgress.prepare(continued.profile, receipt(1, 100))
	check(finished.profile.manual_characters == 100 and finished.added_characters == 40 and finished.profile.settlements.checkpoints.is_empty(), "房末完整结果只补检查点差额")
	check(TalentProgress.prepare(finished.profile, receipt(1, 100)).added_characters == 0, "房末回执重复零增量")
	var interrupted := TalentProgress.prepare(continued.profile, receipt(1, 60, &"interrupted"))
	check(interrupted.added_characters == 0 and interrupted.profile.settlements.rooms.size() == 1, "异常中断消费已持久化量且不重发成长")
	check(not TalentProgress.prepare(continued.profile, receipt(1, 59)).has("profile"), "末结算不能少于房内已提交事实")
	check(not TalentProgress.prepare_checkpoint(finished.profile, receipt(1, 100, &"checkpoint")).has("profile"), "已终止房不能重新开放检查点")
	var other_room := TalentProgress.prepare(saved.profile, receipt(2, 70))
	var first_room := TalentProgress.prepare(other_room.profile, receipt(1, 100))
	check(first_room.profile.manual_characters == 170 and first_room.added_characters == 60, "房内高水位与乱序其他房独立累计")
