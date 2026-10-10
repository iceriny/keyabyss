class_name RunItinerary
extends Resource

@export var rooms_per_chapter: int = 3
@export var encounters: Array[BattleEncounter] = []


func chapter_of(room_serial: int) -> int:
	return floori(float(room_serial - 1) / rooms_per_chapter) + 1


func room_experience(room_serial: int) -> int:
	var encounter := encounters[room_serial - 1]
	var amount := 0
	for enemy in encounter.enemies:
		amount += enemy.experience * encounter.wave_count
	return amount


func chapter_experience(chapter: int) -> int:
	var amount := 0
	for index in encounters.size():
		if chapter_of(index + 1) == chapter:
			amount += room_experience(index + 1)
	return amount
