class_name RewardLedger
extends RefCounted
## Run-owned experience and opportunities. UI only submits payment intentions.

var current: int = 0
var next_threshold: int = RewardPolicy.INITIAL_THRESHOLD
var level: int = RewardPolicy.INITIAL_LEVEL
var earned: int = RewardPolicy.INITIAL_OPPORTUNITIES
var spent: int = 0
var debt: int = 0
var _chapters: Dictionary = {}
var _facts: Dictionary = {}


func start_chapter(chapter: int, base_experience: int) -> bool:
	if chapter < 1 or base_experience < 0:
		return false
	var key := str(chapter)
	if _chapters.has(key):
		return int(_chapters[key].base_experience) == base_experience
	_chapters[key] = {"base_experience": base_experience, "eligible_experience": 0, "bonus_remainder": 0, "bonus_used": 0}
	return true


func consume(fact: RewardFact) -> Dictionary:
	if fact == null or fact.fact_id.is_empty() or fact.base_experience < 0 or fact.chapter < 1:
		return _result("INVALID_REWARD_FACT")
	var record := fact.to_dict()
	if _facts.has(fact.fact_id):
		return _result("" if _facts[fact.fact_id] == record else "REWARD_FACT_CONFLICT")
	var chapter_key := str(fact.chapter)
	if not _chapters.has(chapter_key):
		return _result("CHAPTER_NOT_STARTED")
	var chapter_state: Dictionary = _chapters[chapter_key]
	var bonus := 0
	if fact.r021_active:
		chapter_state.eligible_experience += fact.base_experience
		var units: int = int(chapter_state.bonus_remainder) + fact.base_experience * RewardPolicy.R021_BONUS_PERCENT
		@warning_ignore("integer_division")
		var whole_bonus := units / 100
		chapter_state.bonus_remainder = units % 100
		bonus = whole_bonus
		chapter_state.bonus_used += bonus
	var experience_added := fact.base_experience + bonus
	var opportunities_added := 0
	current += experience_added
	while current >= next_threshold:
		current -= next_threshold
		level += 1
		earned += 1
		opportunities_added += 1
		next_threshold = RewardPolicy.next_threshold(next_threshold)
	_facts[fact.fact_id] = record
	return {"diagnostics": [], "experience_added": experience_added, "opportunities_added": opportunities_added}


func available() -> int:
	return earned - spent


func spend(amount: int) -> bool:
	if amount < 0 or amount > available():
		return false
	spent += amount
	return true


func to_dict() -> Dictionary:
	return {
		"policy_version": RewardPolicy.VERSION,
		"current": current, "next_threshold": next_threshold, "level": level,
		"earned": earned, "spent": spent, "debt": debt,
		"chapters": _chapters.duplicate(true), "facts": _facts.duplicate(true),
	}


static func from_dict(data: Dictionary) -> RewardLedger:
	if data.get("policy_version") not in [RewardPolicy.VERSION, "m4-1"]:
		return null
	for key in ["current", "next_threshold", "level", "earned", "spent", "debt"]:
		if not _is_integer(data.get(key), 0):
			return null
	if int(data.next_threshold) < 1 or int(data.level) < 1 or int(data.current) >= int(data.next_threshold) or int(data.spent) > int(data.earned):
		return null
	if not data.get("chapters") is Dictionary or not data.get("facts") is Dictionary:
		return null
	var result := RewardLedger.new()
	result.current = int(data.current)
	result.next_threshold = int(data.next_threshold)
	result.level = int(data.level)
	result.earned = int(data.earned)
	result.spent = int(data.spent)
	result.debt = int(data.debt)
	for key: Variant in data.chapters:
		if not key is String or not key.is_valid_int() or int(key) < 1 or str(int(key)) != key:
			return null
		var state: Variant = data.chapters[key]
		if not state is Dictionary:
			return null
		for field in ["base_experience", "eligible_experience", "bonus_remainder", "bonus_used"]:
			if not _is_integer(state.get(field), 0):
				return null
		if int(state.bonus_remainder) >= 100:
			return null
		result._chapters[key] = {
			"base_experience": int(state.base_experience), "eligible_experience": int(state.eligible_experience),
			"bonus_remainder": int(state.bonus_remainder), "bonus_used": int(state.bonus_used),
		}
	for key: Variant in data.facts:
		var record: Variant = data.facts[key]
		if not key is String or key.is_empty() or not record is Dictionary:
			return null
		if record.get("fact_id") != key or not _is_integer(record.get("base_experience"), 0) or not _is_integer(record.get("chapter"), 1) or not record.get("r021_active") is bool:
			return null
		if not result._chapters.has(str(int(record.chapter))):
			return null
		result._facts[key] = RewardFact.new(key, int(record.base_experience), int(record.chapter), record.r021_active).to_dict()
	return result


func copy() -> RewardLedger:
	return from_dict(to_dict())


static func _is_integer(value: Variant, minimum: int) -> bool:
	if value is int:
		return value >= minimum
	if value is float:
		return is_finite(value) and value >= minimum and value == floor(value)
	return false


func _result(diagnostic: String) -> Dictionary:
	return {"diagnostics": [] if diagnostic.is_empty() else [diagnostic], "experience_added": 0, "opportunities_added": 0}
