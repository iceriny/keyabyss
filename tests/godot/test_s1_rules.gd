extends SceneTree

var failures := 0
var sessions: Array[BattleSession] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var service := AcquisitionService.new()
	for book in BuildCompiler.BOOKS:
		var selection := BuildSelection.new()
		selection.book_id = book
		_check(service.compiler.compile(selection).success(), "%s compiles without talents" % book)
		var session := _session(book)
		_word(session, "abcd")
		_check(session.manual_characters == 4 and session.completed_words == 1, "%s commits real manual input" % book)
		if book == &"spirit": _check(not session.runtime.spirit_attacks.is_empty(), "paper book sustains spirits")
		elif book == &"storm": _check(session.runtime.actual_damage_q > 0, "storm book hits without manufacture")
		else: _check(not session.projectiles.is_empty(), "%s launches main spell" % book)
		_check(session.runtime.assist_ready() == false, "active completion needs earned input")
		var pool := service.candidates(selection, {"shortest": 4, "longest": 7})
		_check("R006" in pool and "R014" in pool and "R015" in pool and "R100" not in pool, "formal pool uses restored content")
		_check(("R050" in pool) == (book == &"flame"), "flame relic respects main book")
	var plain := _session(&"frost")
	_word(plain, "abcd")
	var plain_power := plain.projectiles[0].effect.damage_q
	var strong := _session(&"frost", {&"R001": 2})
	_word(strong, "abcd")
	_check(absf(float(strong.projectiles[0].effect.damage_q) / plain_power - 1.5625) < 0.002, "direct power stacks multiply")
	var perfect := _session(&"frost", {&"R016": 1})
	_word(perfect, "abcd")
	_check(perfect.projectiles[0].effect.damage_q > plain_power * 1.3, "no-error relic adds immediate damage")
	var long_plain := _session(&"frost")
	_word(long_plain, "abcdefg")
	var long_relic := _session(&"frost", {&"R015": 1})
	_word(long_relic, "abcdefg")
	_check(absf(float(long_relic.projectiles[0].effect.damage_q) / long_plain.projectiles[0].effect.damage_q - 1.75) < 0.002, "seven-letter word receives long-word reward")
	var short := _session(&"frost", {&"R014": 1})
	short.dodge_charges = 1.0
	_word(short, "abcd")
	_check(short.projectiles[0].effect.damage_q > plain_power * 1.5 and short.dodge_charges > 1.0, "short words grant damage and dodge")
	var echo := _session(&"frost", {&"R006": 1})
	for index in 3: _word(echo, "abcd")
	var copied := 0
	for projectile in echo.projectiles:
		if projectile.effect.kind == &"echo": copied += 1
	_check(copied == 1, "third cast produces exactly one finite echo")
	var cold := _session(&"frost", {&"R003": 1})
	_word(cold, "abcd")
	var effect := cold.projectiles[0].effect
	cold.runtime.contact(effect, cold.enemies[0], cold.player_position)
	_check(cold.enemies[0].frozen_time >= 2.0, "cold relic extends freeze")
	var flame := _session(&"flame", {&"R050": 1})
	_word(flame, "abcd")
	flame.runtime.contact(flame.projectiles[0].effect, flame.enemies[0], flame.player_position)
	_check(not flame.runtime.ongoing.is_empty(), "flame baseline creates burning with no talents")
	var hourglass := _session(&"frost", {&"R041": 1})
	hourglass.runtime.on_dodge(Vector2.ZERO, Vector2.ONE)
	hourglass.step(0.5)
	_check(is_equal_approx(hourglass.runtime.clock, 0.05), "hourglass slows world to ten percent")
	_check(is_equal_approx(hourglass.precision_slow_remaining, 1.0), "hourglass expires in real time")
	var retired_selection := BuildSelection.new()
	retired_selection.assets[&"R100"] = 1
	_check(not service.compiler.compile(retired_selection).success(), "unrestored relic cannot enter formal build")
	retired_selection.assets.clear()
	retired_selection.talents = ["T01", "T57"]
	retired_selection.secondary_book = &"flame"
	_check(service.compiler.compile(retired_selection).build.mode(&"secondary") == &"", "retired configuration does not affect formal build")
	for session in sessions: session.free()
	print("S1_RULES: ", "PASS" if failures == 0 else "FAIL ", failures)
	quit(0 if failures == 0 else 1)


func _session(book: StringName, assets: Dictionary = {}) -> BattleSession:
	var selection := BuildSelection.new()
	selection.book_id = book
	for id in assets: selection.assets[id] = assets[id]
	var request := BattleStartRequest.new()
	request.build = BuildCompiler.new().compile(selection).build
	request.vocabulary = [VocabularyEntry.new("abcd", "test")]
	request.vocabulary_index = VocabularyIndex.build(request.vocabulary)
	request.seed_text = "s1-rules"
	var session := BattleSession.new()
	sessions.append(session)
	session.start(request)
	session.enemies.clear()
	session._enemies_by_id.clear()
	for index in 2:
		var enemy := BattleEnemy.new()
		enemy.id = StringName("target-%d" % index)
		enemy.word = "abcd"
		enemy.position = Vector2(0.5 + index * 0.08, 0.35)
		enemy.previous_position = enemy.position
		enemy.hp_q = 10000 * 1024
		enemy.max_hp_q = enemy.hp_q
		enemy.attack_interval = 1000.0
		enemy.attack_clock = 1000.0
		session.enemies.append(enemy)
		session._enemies_by_id[enemy.id] = enemy
		session._enemy_definitions[enemy.id] = session._enemy_definitions.values()[0]
	return session


func _word(session: BattleSession, word: String) -> void:
	session.typing.upsert_target(session.enemies[0].id, word)
	session.typing.select_target(session.enemies[0].id)
	for character in word: session.typing.feed(character)
	session.step(0.0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
