extends SceneTree

var checks: int = 0
var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_policy_and_thresholds()
	_test_facts_and_chapters()
	_test_r021()
	_test_payment()
	_test_serialization()
	print("Reward ledger: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)


func _test_policy_and_thresholds() -> void:
	var ledger := RewardLedger.new()
	_check(ledger.current == 0 and ledger.next_threshold == 27 and ledger.earned == 0 and ledger.available() == 0, "No initially earned opportunity")
	ledger.start_chapter(1, 200)
	var below := ledger.consume(RewardFact.new("below", 26))
	_check(below.opportunities_added == 0 and ledger.current == 26, "Experience below first threshold")
	var first := ledger.consume(RewardFact.new("first", 1))
	_check(first.opportunities_added == 1 and ledger.current == 0 and ledger.next_threshold == 35 and ledger.level == 2, "Exact first threshold")
	var several := ledger.consume(RewardFact.new("several", 35 + 44 + 9))
	_check(several.opportunities_added == 2 and ledger.current == 9 and ledger.next_threshold == 54 and ledger.earned == 3, "Several thresholds preserve remainder")


func _test_facts_and_chapters() -> void:
	var ledger := RewardLedger.new()
	var fact := RewardFact.new("run/1/attempt/enemy", 8, 1, true)
	_check(ledger.consume(fact).diagnostics == ["CHAPTER_NOT_STARTED"], "Missing chapter budget is rejected")
	_check(not ledger.start_chapter(0, 100) and not ledger.start_chapter(1, -1), "Invalid chapter budget is rejected")
	_check(ledger.start_chapter(1, 100), "Chapter budget starts once")
	_check(ledger.consume(fact).experience_added == 10, "Fact carries its policy context")
	var frozen := ledger.to_dict()
	_check(ledger.start_chapter(1, 100) and ledger.to_dict() == frozen, "Restarting the same chapter preserves usage")
	_check(not ledger.start_chapter(1, 200) and ledger.to_dict() == frozen, "A different chapter baseline is refused")
	var duplicate := ledger.consume(fact)
	_check(duplicate.diagnostics.is_empty() and duplicate.experience_added == 0 and duplicate.opportunities_added == 0 and ledger.to_dict() == frozen, "Duplicate fact has no mutation")
	_check(not ledger.consume(RewardFact.new(fact.fact_id, 9, 1, true)).diagnostics.is_empty() and ledger.to_dict() == frozen, "Changed experience on the same ID is refused")
	_check(not ledger.consume(RewardFact.new(fact.fact_id, 8, 1, false)).diagnostics.is_empty() and ledger.to_dict() == frozen, "Changed eligibility on the same ID is refused")
	_check(not ledger.consume(RewardFact.new(fact.fact_id, 8, 2, true)).diagnostics.is_empty() and ledger.to_dict() == frozen, "Changed chapter on the same ID is refused")
	_check(not ledger.consume(RewardFact.new("", 8)).diagnostics.is_empty() and not ledger.consume(RewardFact.new("negative", -1)).diagnostics.is_empty() and ledger.to_dict() == frozen, "Malformed facts never change the ledger")
	fact.base_experience = 1000
	_check(ledger.to_dict() == frozen, "Committed facts are detached from the caller")


func _test_r021() -> void:
	var whole := RewardLedger.new()
	var split := RewardLedger.new()
	whole.start_chapter(1, 100)
	split.start_chapter(1, 100)
	var whole_result := whole.consume(RewardFact.new("whole", 20, 1, true))
	var split_added := 0
	for index in range(20):
		split_added += int(split.consume(RewardFact.new("split-" + str(index), 1, 1, true)).experience_added)
	_check(whole_result.experience_added == 27 and split_added == 27, "Split facts retain hundredth units instead of rounding each kill")
	_check(whole.current == split.current and whole.earned == split.earned and whole.to_dict().chapters == split.to_dict().chapters, "Splitting preserves experience, opportunities and policy state")
	_check(whole.earned == 1, "Extra experience does not recursively receive another bonus")
	var toggled := RewardLedger.new()
	toggled.start_chapter(1, 100)
	_check(toggled.consume(RewardFact.new("before-acquire", 10)).experience_added == 10, "Past base experience is not retroactively eligible")
	_check(toggled.consume(RewardFact.new("active-first", 2, 1, true)).experience_added == 2, "First active fact retains its fractional bonus")
	_check(toggled.consume(RewardFact.new("pledged", 10, 1, false)).experience_added == 10, "Inactive experience receives no bonus")
	var paused: Dictionary = toggled.to_dict().chapters["1"]
	_check(paused.eligible_experience == 2 and paused.bonus_remainder == 70, "Inactive facts do not accumulate eligible experience or change remainder")
	_check(toggled.consume(RewardFact.new("returned", 1, 1, true)).experience_added == 2, "Returned/replaced R021 resumes the same chapter remainder")
	var capped := RewardLedger.new()
	capped.start_chapter(1, 12)
	_check(capped.consume(RewardFact.new("cap", 100, 1, true)).experience_added == 135, "R021 has no chapter cap")
	capped.start_chapter(1, 12)
	_check(capped.consume(RewardFact.new("cap-again", 100, 1, true)).experience_added == 135, "R021 continues throughout the chapter")
	capped.start_chapter(2, 19)
	_check(capped.consume(RewardFact.new("next-chapter", 100, 2, true)).experience_added == 135, "R021 is independent of chapter base")
	_check(capped.to_dict().chapters["1"].bonus_used == 70, "Starting another chapter preserves the previous usage")
	var zero := RewardLedger.new()
	zero.start_chapter(1, 3)
	_check(zero.consume(RewardFact.new("zero-cap", 4, 1, true)).experience_added == 5, "A small chapter baseline does not cap R021")


func _test_payment() -> void:
	var ledger := RewardLedger.new()
	ledger.start_chapter(1, 200)
	_check(not ledger.spend(1), "Unearned opportunities cannot be paid")
	ledger.consume(RewardFact.new("earn", 27 + 35 + 44))
	_check(ledger.available() == 3, "All earned opportunities remain spendable")
	var before := ledger.to_dict()
	_check(not ledger.spend(-1) and not ledger.spend(4) and ledger.to_dict() == before, "Invalid spending is atomic")
	_check(ledger.spend(3) and ledger.available() == 0 and not ledger.spend(1), "Earned opportunities are spent once")
	_check(ledger.spend(0), "Zero payment is harmless")


func _test_serialization() -> void:
	var ledger := RewardLedger.new()
	ledger.start_chapter(1, 100)
	ledger.consume(RewardFact.new("persisted", 2, 1, true))
	var snapshot := ledger.to_dict()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
	var restored := RewardLedger.from_dict(parsed)
	_check(restored != null, "Pure JSON snapshot can be restored")
	if restored != null:
		_check(restored.to_dict() == snapshot, "Restoration preserves balances, fractional bonus and facts")
		_check(restored.consume(RewardFact.new("persisted", 2, 1, true)).experience_added == 0, "Save restoration preserves fact deduplication")
		_check(restored.consume(RewardFact.new("after-restore", 1, 1, true)).experience_added == 2, "Save restoration preserves the bonus remainder")
	var legacy := snapshot.duplicate(true)
	legacy.policy_version = "m4-1"
	legacy.debt = 1
	var migrated := RewardLedger.from_dict(legacy)
	_check(migrated != null and migrated.to_dict().policy_version == "s2-1" and migrated.debt == 1, "Legacy debt is preserved only for migration")
	migrated.consume(RewardFact.new("legacy-no-deduction", 27))
	_check(migrated.spent == 0 and migrated.debt == 1, "Legacy debt has no execution branch")
	var copied := ledger.copy()
	copied.consume(RewardFact.new("copy-only", 25, 1, true))
	_check(ledger.to_dict() == snapshot and copied.earned > ledger.earned, "Copy is independent, including chapter policy and debt")
	var output := ledger.to_dict()
	output.chapters["1"].bonus_used = 25
	output.facts["persisted"].base_experience = 100
	_check(ledger.to_dict() == snapshot, "Serialized nested dictionaries are detached")
	var malformed := snapshot.duplicate(true)
	malformed.current = 0.5
	_check(RewardLedger.from_dict(malformed) == null, "Fractional experience in JSON is refused")
	malformed = snapshot.duplicate(true)
	malformed.spent = 1
	_check(RewardLedger.from_dict(malformed) == null, "Spending beyond earned opportunities is refused")
	malformed = snapshot.duplicate(true)
	malformed.chapters["1"].bonus_used = 26
	_check(RewardLedger.from_dict(malformed) != null, "Restoration accepts uncapped bonus usage")
	malformed = snapshot.duplicate(true)
	malformed.facts["persisted"].fact_id = "different"
	_check(RewardLedger.from_dict(malformed) == null, "Mismatched persisted fact identity is refused")
	malformed = snapshot.duplicate(true)
	malformed.policy_version = "other"
	_check(RewardLedger.from_dict(malformed) == null, "Unrecognized policy versions are refused")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
