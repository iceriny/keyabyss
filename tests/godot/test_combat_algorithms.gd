extends SceneTree
## Optional --reference=res://... subclass compares the saved pre-change rules.
## --benchmark measures alternating calls; no scene or presentation is involved.

const SIZE := BattleSession.ARENA_SIZE
var failures := 0
var checks := 0
var reference: Script
var timings: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DebugLog.enabled = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--reference="): reference = load(argument.trim_prefix("--reference="))
	if "--cold" in OS.get_cmdline_user_args():
		_cold_batch()
		quit()
		return
	_query_contract()
	print("Query contracts: %d checks" % checks)
	if reference != null:
		if "--benchmark-only" not in OS.get_cmdline_user_args():
			_dodge_parity()
			print("Dodge parity: %d checks" % checks)
			if "--dodge-only" not in OS.get_cmdline_user_args(): _replay_parity()
		if "--benchmark" in OS.get_cmdline_user_args(): _benchmark()
	print(JSON.stringify({"checks": checks, "failures": failures, "timings": timings}))
	quit(1 if failures else 0)


func _session(old: bool = false, book: StringName = &"frost", assets: Dictionary = {}) -> BattleSession:
	var session: BattleSession = reference.new() if old else BattleSession.new()
	var selection := BuildSelection.new()
	selection.book_id = book
	selection.assets.assign(assets)
	var request := BattleStartRequest.new()
	var compiled := BuildCompiler.new().compile(selection)
	assert(compiled.success(), str(compiled.diagnostics))
	request.build = compiled.build
	request.vocabulary = [VocabularyEntry.new("alpha", "a"), VocabularyEntry.new("bravo", "b"), VocabularyEntry.new("cider", "c"), VocabularyEntry.new("delta", "d")]
	request.vocabulary_index = VocabularyIndex.build(request.vocabulary)
	request.seed_text = "algorithm-parity"
	request.run_id = "algorithm"
	request.attempt_id = "replay"
	session.start(request)
	session.typing._session_id = "algorithm-input"
	for enemy in session.enemies:
		enemy.combat_locked = true
	return session


func _populate(session: BattleSession, living: int, history: int, crowded: bool = false) -> void:
	var definition: EnemyCombatDefinition = load("res://game/content/enemies/nib.tres")
	while session.enemies.size() < history: session._spawn_enemy(definition, Vector2(.5, .4))
	for index in session.enemies.size():
		var enemy := session.enemies[index]
		enemy.hp_q = 400 * BattleSession.Q if index < living else 0
		enemy.max_hp_q = 400 * BattleSession.Q
		enemy.position = Vector2(.5, .5) + Vector2.from_angle(index * 2.3999632297) * (35.0 if crowded else 290.0) / SIZE
		enemy.previous_position = enemy.position
		enemy.combat_locked = true
		enemy.attack_clock = 1000.0


func _query_contract() -> void:
	var session := _session()
	_populate(session, 12, 100)
	_check(session.enemy_by_id(&"enemy_99") == session.enemies[99], "ID lookup retains dead entities")
	session.enemies[2].position = Vector2(.5, .4)
	session.enemies[10].position = session.enemies[2].position
	for enemy in session.enemies:
		if enemy.id not in [&"enemy_2", &"enemy_10"]: enemy.hp_q = 0
	_check(session.runtime.retarget(null, Vector2(.5, .5), []) == session.enemies[10], "retarget ties retain lexical ID order")
	_check(session._nearest_living(Vector2(.5, .5)) == session.enemies[2], "ordinary nearest ties retain spawn order")
	_check(session.spirit_target(Vector2(.5, .5)) == session.enemies[2], "paper ties retain spawn order")
	var arc := BattleEffect.new()
	arc.build = session.compiled_build
	arc.visited.append("enemy_10")
	_check(session.runtime.arc_target(arc, Vector2(.5, .5)) == session.enemies[2], "arc excludes already visited targets")
	var random := RandomNumberGenerator.new()
	random.seed = 20261010
	for sample in 120:
		for enemy in session.enemies:
			enemy.hp_q = BattleSession.Q if random.randf() > .3 else 0
			enemy.position = Vector2(random.randf(), random.randf())
			enemy.shock = [0, 30, 31, 60, 61][random.randi_range(0, 4)]
		var origin := Vector2(random.randf(), random.randf())
		var ordered := session.runtime._nearby(origin, 1200.0)
		_check(session.runtime.retarget(null, origin, []) == (ordered[0] if not ordered.is_empty() else null), "nearest matches ordered radius query %d" % sample)
		var expected: BattleEnemy = null
		for enemy in session.runtime._nearby(origin, 3000.0):
			if str(enemy.id) in arc.visited: continue
			var reach := 530.0 if enemy.shock > 30 else 265.0
			if enemy.shock <= 60 and ((enemy.position - origin) * SIZE).length() > reach: continue
			expected = enemy
			break
		_check(session.runtime.arc_target(arc, origin) == expected, "arc reach and ordering %d" % sample)
	var survivors: Array[BattleThreat] = []
	for index in 256:
		var threat := BattleThreat.new()
		threat.position = session.player_position + Vector2(index * 2.0, 0) / SIZE
		threat.reflected = index % 7 == 0
		session.threats.append(threat)
		if threat.reflected or ((threat.position - session.player_position) * SIZE).length() > 250.0: survivors.append(threat)
	session.runtime.clear_radius(session.player_position, 250.0)
	_check(session.threats == survivors, "clear preserves surviving identities and order")
	session.start_baseline(&"frost", [VocabularyEntry.new("alpha", "a")], "normal", "restart")
	_check(session.enemy_by_id(&"enemy_99") == null and session.enemy_by_id(&"enemy_0") == session.enemies[0], "room restart replaces ID index")
	session.free()


func _dodge_scene(session: BattleSession, scenario: int, count: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 20261010 + scenario
	session.threats.clear()
	session.hazards.clear()
	session.player_position = BattleSession.clamp_player(Vector2(random.randf(), random.randf()))
	if scenario % 8 == 0: session.player_position = Vector2(.5, .5)
	for index in session.enemies.size():
		var enemy := session.enemies[index]
		enemy.hp_q = 100 * BattleSession.Q if scenario % 5 else 0
		enemy.position = Vector2(random.randf(), random.randf())
		enemy.velocity = Vector2.from_angle(random.randf() * TAU) * random.randf_range(0, 300)
		enemy.impulse = Vector2.from_angle(random.randf() * TAU) * random.randf_range(0, 1000)
		enemy.frozen_time = random.randf_range(0, 2) if scenario % 4 == 0 else 0.0
		enemy.stagger_time = random.randf_range(0, 1) if scenario % 6 == 0 else 0.0
		enemy.behavior = &"charge" if index == 0 else &"melee"
		enemy.aiming = scenario % 3 == 0
		enemy.aimed_position = session.player_position
		enemy.attack_clock = random.randf_range(0, 1.6)
		enemy.charge_time = random.randf_range(0, 1) if scenario % 8 == 0 else 0.0
		enemy.charge_direction = ((enemy.aimed_position - enemy.position) * SIZE).normalized()
		enemy.melee_origin = enemy.position
		enemy.melee_direction = enemy.charge_direction
		enemy.melee_strike = .16 if scenario % 9 == 0 else 0.0
	for index in count:
		var threat := BattleThreat.new()
		threat.position = Vector2(random.randf(), random.randf())
		threat.velocity = Vector2.from_angle(random.randf() * TAU) * random.randf_range(50, 600)
		threat.curvature = random.randf_range(-.5, .5)
		threat.acceleration = random.randf_range(-.1, .3)
		threat.life = random.randf_range(0, 3)
		threat.radius = random.randf_range(5, 12)
		threat.reflected = index % 17 == 0
		session.threats.append(threat)
	for index in scenario % 5:
		var hazard := BattleHazard.new()
		hazard.kind = &"blast" if index % 2 == 0 else &"laser"
		hazard.center = Vector2(random.randf(), random.randf())
		hazard.origin = Vector2(random.randf(), 0)
		hazard.end = Vector2(hazard.origin.x, 1)
		hazard.radius = random.randf_range(80, 220)
		hazard.width = random.randf_range(15, 40)
		hazard.warning_remaining = random.randf_range(0, 2)
		hazard.active_remaining = random.randf_range(.05, .5)
		session.hazards.append(hazard)


func _dodge_parity() -> void:
	var old := _session(true)
	var current := _session()
	for scenario in 1152:
		var count: int = [0, 1, 8, 32, 128, 256][scenario % 6]
		_dodge_scene(old, scenario, count)
		_dodge_scene(current, scenario, count)
		_check(old._safe_direction() == current._safe_direction(), "dodge exact direction %d" % scenario)
	old.free()
	current.free()


func _dodge_stress(session: BattleSession, count: int) -> void:
	session.threats.clear()
	session.hazards.clear()
	session.player_position = Vector2(.5, .5)
	for index in session.enemies.size():
		var enemy := session.enemies[index]
		enemy.hp_q = 100 * BattleSession.Q
		enemy.position = session.player_position + Vector2.from_angle(index * TAU / 3.0) * 200.0 / SIZE
		enemy.previous_position = enemy.position
		enemy.velocity = Vector2.from_angle(index * TAU / 3.0 + PI) * 80.0
		enemy.attack_clock = .8
	session._spawn_blast(session.enemies[0], Vector2(.4, .4), 123.0, .9)
	session._spawn_blast(session.enemies[0], Vector2(.62, .65), 142.5, 1.1)
	session._spawn_laser(session.enemies[1])
	session.hazards[-1].warning_remaining = 1.2
	for index in count:
		var angle := index * 2.3999632297
		session._emit_enemy_threat(session.enemies[index % session.enemies.size()], angle + PI, index, 180.0 + index % 5 * 35.0, 6.75)
		var threat := session.threats[-1]
		threat.position = session.player_position + Vector2.from_angle(angle) * (280.0 + index % 9 * 35.0) / SIZE
		threat.curvature = [-.32, 0.0, .23][index % 3]
		threat.acceleration = .12 if index % 4 == 0 else 0.0


func _state(session: BattleSession) -> Array:
	var enemies: Array = []
	for enemy in session.enemies:
		var values: Array = []
		for property in enemy.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: values.append(enemy.get(property.name))
		enemies.append(values.duplicate(true))
	var projectiles: Array = []
	for shot in session.projectiles: projectiles.append([shot.position, shot.previous_position, shot.velocity, shot.remaining_hits, shot.hit_ids.duplicate(), shot.trail.duplicate(), _effect_state(shot.effect)])
	var threats: Array = []
	for threat in session.threats: threats.append([threat.attack_id, threat.position, threat.velocity, threat.life, threat.reflected, threat.trail.duplicate()])
	var effects: Array = []
	for effect in session.effects: effects.append(_effect_state(effect))
	var fields: Array = []
	for field in session.runtime.fields: fields.append([field.id, field.center, field.endpoint, field.radius, field.remaining_pulses, field.pulse_q, field.interval, field.next_at, field.expires_at, field.relayed, _effect_state(field.effect)])
	var hazards: Array = []
	for hazard in session.hazards: hazards.append([hazard.kind, hazard.source_id, hazard.attack_id, hazard.origin, hazard.end, hazard.center, hazard.radius, hazard.width, hazard.warning_remaining, hazard.active_remaining, hazard.fired])
	var spirits: Array = []
	for spirit in session.spirits: spirits.append([spirit.position, spirit.previous_position, spirit.velocity, spirit.mode, spirit.target_id, spirit.cooldown, spirit.crossing, spirit.struck, spirit.trail.duplicate(), spirit.start, spirit.control, spirit.bend, spirit.endpoint, spirit.flight_time, spirit.duration, _effect_state(spirit.effect)])
	return [enemies, projectiles, threats, session.player_hp_q, session.player_position, session.resonance_q, session.typing._targets.duplicate(), session.runtime.actual_damage_q, session._rng.state, effects, fields, hazards, spirits, session.ledger.raw_spent_q]


func _effect_state(effect: BattleEffect) -> Array:
	if effect == null: return []
	return [effect.source, effect.kind, effect.target_id, effect.word_owner, effect.damage_q, effect.delay, effect.empowered, effect.applications, effect.jumps, effect.origin, effect.visited.duplicate(), effect.lot.amount_q if effect.lot != null else -1, effect.dispatched, effect.expires_at, effect.depth, effect.arc_index, effect.arc_charge]


func _replay_parity() -> void:
	for book: StringName in [&"frost", &"flame", &"storm", &"spirit"]:
		for crowded in [false, true]:
			var assets := {&"R002": 1, &"R004": 1, &"R007": 1, &"R023": 1, &"R032": 1}
			var old := _session(true, book, assets)
			var current := _session(false, book, assets)
			_populate(old, 24, 100, crowded)
			_populate(current, 24, 100, crowded)
			var expected: Array[Dictionary] = []
			var actual: Array[Dictionary] = []
			old.event_committed.connect(func(event: Dictionary) -> void: expected.append(event.duplicate(true)))
			current.event_committed.connect(func(event: Dictionary) -> void: actual.append(event.duplicate(true)))
			var step_times: Array = [[], []]
			for tick in 360:
				for session in [old, current]:
					if tick % 20 == 0:
						var target: BattleEnemy = session._nearest_living(session.player_position)
						if target != null:
							session.typing.upsert_target(target.id, "alpha")
							session.typing.select_target(target.id)
							for character in "alpha": session.typing.feed(character)
					if tick % 90 == 0: session.queue_action(&"parry")
					if tick % 120 == 60: session.queue_action(&"dodge_auto")
					var started := Time.get_ticks_usec()
					session.step(1.0 / 60.0)
					step_times[0 if session == old else 1].append((Time.get_ticks_usec() - started) / 1000.0)
				_check(expected == actual and _state(old) == _state(current), "%s crowded=%s replay tick=%d" % [book, crowded, tick])
				if failures > 0: break
				expected.clear()
				actual.clear()
			for variant in 2:
				step_times[variant].sort()
				var samples: Array = step_times[variant]
				print(JSON.stringify({"case": "step-%s-crowded-%s" % [book, crowded], "variant": variant, "samples": samples.size(), "median_ms": samples[floori(samples.size() * .5)], "p95_ms": samples[floori(samples.size() * .95) - 1], "max_ms": samples[-1]}))
			old.free()
			current.free()
			print("Replay %s crowded=%s: %d checks, %d failures" % [book, crowded, checks, failures])


func _measure(label: String, old: Callable, current: Callable, repeats: int = 1) -> void:
	for warmup in 10:
		old.call()
		current.call()
	var samples: Array = [[], []]
	for group in 3:
		for iteration in 200:
			for offset in 2:
				var variant := (iteration + offset) % 2
				var operation: Callable = old if variant == 0 else current
				var started := Time.get_ticks_usec()
				for repeat in repeats: operation.call()
				samples[variant].append((Time.get_ticks_usec() - started) / (1000.0 * repeats))
	for variant in 2:
		var ordered: Array = samples[variant].duplicate()
		ordered.sort()
		var row := {"case": label, "variant": "reference" if variant == 0 else "current", "median_ms": ordered[300], "p95_ms": ordered[569], "p99_ms": ordered[593], "max_ms": ordered[-1]}
		timings.append(row)
		print(JSON.stringify(row))


func _benchmark() -> void:
	var old := _session(true)
	var current := _session()
	for count: int in [0, 32, 128, 256]:
		_dodge_scene(old, 13, count)
		_dodge_scene(current, 13, count)
		_measure("dodge-%d" % count, old._safe_direction, current._safe_direction)
	for count: int in [32, 128, 256]:
		_dodge_stress(old, count)
		_dodge_stress(current, count)
		_check(old._safe_direction() == current._safe_direction(), "stress direction %d" % count)
		_measure("dodge-ring-%d" % count, old._safe_direction, current._safe_direction)
	for history: int in [24, 100]:
		_populate(old, 24, history)
		_populate(current, 24, history)
		_measure("lookup-%d" % history, func(): return old.enemy_by_id(StringName("enemy_%d" % (history - 1))), func(): return current.enemy_by_id(StringName("enemy_%d" % (history - 1))), 100)
		_measure("retarget-%d" % history, func(): return old.runtime.retarget(null, Vector2(.5, .5), []), func(): return current.runtime.retarget(null, Vector2(.5, .5), []), 20)
	for count: int in [8, 24, 40]:
		for crowded in [false, true]:
			_populate(old, count, maxi(100, count), crowded)
			_populate(current, count, maxi(100, count), crowded)
			# Reset outside each measured call; contacts themselves remain real.
			var positions: Array[Vector2] = []
			for enemy in old.enemies: positions.append(enemy.position)
			var pair: Array[BattleSession] = [old, current]
			for variant in 2:
				var samples: Array[float] = []
				for iteration in 610:
					var session := pair[variant]
					for index in session.enemies.size():
						session.enemies[index].position = positions[index]
						session.enemies[index].previous_position = positions[index]
						session.enemies[index].impulse = Vector2.ZERO
						session.enemies[index].velocity = Vector2.ZERO
					var started := Time.get_ticks_usec()
					session._resolve_bodies()
					if iteration >= 10: samples.append((Time.get_ticks_usec() - started) / 1000.0)
				samples.sort()
				var row := {"case": "bodies-%d-crowded-%s" % [count, crowded], "variant": "reference" if variant == 0 else "current", "median_ms": samples[300], "p95_ms": samples[569], "p99_ms": samples[593], "max_ms": samples[-1]}
				timings.append(row)
				print(JSON.stringify(row))
			_check(_state(old) == _state(current), "body projection exact %d crowded=%s" % [count, crowded])
	old.free()
	current.free()


func _cold_batch() -> void:
	var started := Time.get_ticks_usec()
	var session := _session()
	var setup_ms := (Time.get_ticks_usec() - started) / 1000.0
	_dodge_stress(session, 256)
	started = Time.get_ticks_usec()
	session._safe_direction()
	var cold_ms := (Time.get_ticks_usec() - started) / 1000.0
	var scorer: RefCounted = session._dodge_scorer
	var allocated_before: int = scorer.AllocatedBytes()
	var collections_before: int = scorer.CollectionCount()
	var samples: Array[int] = []
	for iteration in 600:
		started = Time.get_ticks_usec()
		session._safe_direction()
		samples.append(Time.get_ticks_usec() - started)
	var allocated: int = scorer.AllocatedBytes() - allocated_before
	var collections: int = scorer.CollectionCount() - collections_before
	samples.sort()
	print(JSON.stringify({"setup_ms": setup_ms, "cold_256_ms": cold_ms, "allocated_bytes_per_call": allocated / 600.0, "gen0_collections": collections, "p95_ms": samples[569] / 1000.0, "p99_ms": samples[593] / 1000.0, "max_ms": samples[-1] / 1000.0}))
	session.free()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
