class_name RewardFact
extends RefCounted
## A committed enemy/reward event, identified across room and save boundaries.

var fact_id: String
var base_experience: int
var chapter: int
var r021_active: bool


func _init(id: String = "", experience: int = 0, chapter_index: int = 1, active: bool = false) -> void:
	fact_id = id
	base_experience = experience
	chapter = chapter_index
	r021_active = active


func to_dict() -> Dictionary:
	return {"fact_id": fact_id, "base_experience": base_experience, "chapter": chapter, "r021_active": r021_active}


func signature() -> String:
	return JSON.stringify([fact_id, base_experience, chapter, r021_active])
