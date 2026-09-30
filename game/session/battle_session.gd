class_name BattleSession
extends Node
## The only owner of battle rules. Input is queued; one fixed step commits each phase.

signal state_changed
signal event_committed(event: Dictionary)
signal finished(victory: bool)

const Q := SpellResourceLedger.Q
const ULTIMATE_COST_Q := 20 * Q
const ARENA_SIZE := Vector2(1920.0, 1080.0)
const EDGE_WIDTH := 108.0
const MAIN_SPELL_CYCLES := {&"frost": 4, &"flame": 3, &"storm": 4, &"spirit": 3}

var typing := TypingSession.new()
var ledger := SpellResourceLedger.new()
var book_id: StringName = &"frost"
var enemies: Array[BattleEnemy] = []
var effects: Array[BattleEffect] = []
var ultimates: Array[BattleUltimate] = []
var ultimate_time := 0.0
var projectiles: Array[BattleProjectile] = []
var threats: Array[BattleThreat] = []
var player_hp_q: int = 100 * Q
var player_max_hp_q: int = 100 * Q
var resonance_q: int = 0
var manual_characters: int = 0
var completed_words: int = 0
var player_position := Vector2(0.5, 0.5)
var previous_player_position := Vector2(0.5, 0.5)
var player_impulse := Vector2.ZERO
var dodge_charges: float = 2.0
var parry_window: float = 0.0
var parry_cooldown: float = 0.0
var counter_slow_remaining: float = 0.0
var _parry_succeeded: bool = false
var dodge_window: float = 0.0
var dodge_cooldown: float = 0.0
var hurt_window: float = 0.0
var result: int = 0 # 0 active, 1 victory, -1 defeat
var abandoned_run := false
var elapsed: float = 0.0
var encounter: BattleEncounter = preload("res://game/content/single_room.tres")
var wave: int = 0
var intermission: float = -1.0
var arrival_direction: String = "东"
var _pressure: float = 1.0

var _words: Array[VocabularyEntry] = []
var _rng := RandomNumberGenerator.new()
var _progressive: bool = true
var _minimum_length: int = 1
var _completed: Array[WordCompletion] = []
var _abandoned: Array[String] = []
var _actions: Array[StringName] = []
var _pending_locks: Array[StringName] = []
const SPIRIT_CAPACITY := 3
var spirits: Array[BattleSpirit] = []
var spirit_time: float = 0.0
var spirit_work_q: int:
	get:
		var amount := 0
		if runtime != null:
			for attack in runtime.spirit_attacks: amount += attack.lot.amount_q
		return amount
var spirit_focus: StringName
var _dodge_from := Vector2.ZERO
var _dodge_to := Vector2.ZERO
var _dodge_time: float = 1.0
var compiled_build: CompiledBuild
var run_state: RunCombatState
var runtime: SpellRuntime
var room_result: RoomCombatResult
var _commands: Array[BattleCommand] = []
var _attack_serial: int = 0


static func arena_clarity(at: Vector2, radius: float = 0.0) -> float:
	var point := at * ARENA_SIZE
	var distance := minf(minf(point.x, ARENA_SIZE.x - point.x), minf(point.y, ARENA_SIZE.y - point.y))
	return clampf((distance - radius) / EDGE_WIDTH, 0.0, 1.0)


static func in_combat(at: Vector2, radius: float = 0.0) -> bool:
	return arena_clarity(at, radius) >= 1.0


static func enemy_in_combat(enemy: BattleEnemy) -> bool:
	return enemy.combat_locked or in_combat(enemy.position, enemy.radius)


static func clamp_player(at: Vector2) -> Vector2:
	var inset := Vector2.ONE * (EDGE_WIDTH + 32.0) / ARENA_SIZE
	return at.clamp(inset, Vector2.ONE - inset)


func _init() -> void:
	typing.changed.connect(_remember_lock)
	typing.word_completed.connect(func(fact: WordCompletion) -> void: _completed.append(fact))
	typing.abandoned.connect(func(attempt_id: String) -> void: _abandoned.append(attempt_id))


func _remember_lock() -> void:
	var target := enemy_by_id(typing.target_id)
	if target != null and target.alive() and not target.combat_locked and in_combat(target.position, target.radius) and target.id not in _pending_locks:
		_pending_locks.append(target.id)


func start(request: BattleStartRequest, state: RunCombatState = null) -> void:
	assert(request != null and request.build != null and not request.vocabulary.is_empty())
	compiled_build = request.build
	run_state = state if state != null else RunCombatState.new()
	run_state.room_serial += 1
	encounter = request.encounter
	_start_room(request.build.book(), request.vocabulary, request.difficulty, request.seed_text, request.progressive, request.minimum_length)
	ledger.room_id = run_state.room_serial
	runtime = SpellRuntime.new(self, compiled_build, run_state)
	typing.assisted_authorizer = runtime.consume_assist
	player_max_hp_q = 100 * (Q + compiled_build.value(&"max_hp_bonus_q"))
	player_hp_q = mini(player_max_hp_q, run_state.hp_q)
	resonance_q = mini(ULTIMATE_COST_Q, run_state.resonance_q)
	room_result = null
	_commands.clear()
	_attack_serial = 0
	_apply_acquisition()
	if compiled_build.has(&"room-price") and run_state.claim_asset("room:%s" % ledger.room_id, &"price"):
		player_hp_q = maxi(Q, player_hp_q - 10 * Q)
	state_changed.emit()


func _apply_acquisition() -> void:
	for asset in compiled_build.asset_instances():
		if asset.content_id == &"R012" and run_state.claim_asset(asset.usage_key(), &"heal"):
			runtime.heal(10 * Q)
		if asset.content_id == &"R009" and run_state.claim_asset(asset.usage_key(), &"dodge-charge"):
			dodge_charges = minf(2.0 + compiled_build.value(&"dodge_capacity"), dodge_charges + 1.0)


func start_baseline(selected_book: StringName, entries: Array[VocabularyEntry], difficulty: String = "normal", seed_text: String = "", progressive: bool = true, minimum_length: int = 1) -> void:
	var selection := BuildSelection.new()
	selection.book_id = selected_book
	var compiled := BuildCompiler.new().compile(selection)
	assert(compiled.success(), str(compiled.diagnostics))
	var request := BattleStartRequest.new()
	request.build = compiled.build
	request.vocabulary = entries
	request.difficulty = difficulty
	request.seed_text = seed_text
	request.progressive = progressive
	request.minimum_length = minimum_length
	request.encounter = encounter
	start(request)


func _start_room(selected_book: StringName, entries: Array[VocabularyEntry], difficulty: String, seed_text: String, progressive: bool, minimum_length: int) -> void:
	assert(selected_book in [&"frost", &"flame", &"storm", &"spirit"] and not entries.is_empty())
	book_id = selected_book
	_words = entries.duplicate()
	_progressive = progressive
	_minimum_length = minimum_length
	if seed_text.is_empty():
		_rng.randomize()
	else:
		_rng.seed = seed_text.hash()
	ledger = SpellResourceLedger.new()
	typing.drain_receipts()
	enemies.clear()
	effects.clear()
	projectiles.clear()
	threats.clear()
	_completed.clear()
	_abandoned.clear()
	_actions.clear()
	_pending_locks.clear()
	spirits.clear()
	spirit_time = 0.0
	spirit_focus = &""
	player_hp_q = player_max_hp_q
	resonance_q = 0
	manual_characters = 0
	completed_words = 0
	player_position = Vector2(0.5, 0.5)
	previous_player_position = player_position
	player_impulse = Vector2.ZERO
	dodge_charges = 2.0
	_dodge_time = 1.0
	parry_window = 0.0
	parry_cooldown = 0.0
	counter_slow_remaining = 0.0
	_parry_succeeded = false
	dodge_window = 0.0
	dodge_cooldown = 0.0
	hurt_window = 0.0
	result = 0
	abandoned_run = false
	ultimates.clear()
	ultimate_time = 0.0
	elapsed = 0.0
	wave = 0
	intermission = -1.0
	_pressure = {"story": 0.7, "normal": 1.0, "hard": 1.2, "nightmare": 1.4, "apocalypse": 1.6}.get(difficulty, 1.0)
	typing.set_targets({})
	_spawn_wave()
	state_changed.emit()


func _spawn_wave() -> void:
	wave += 1
	intermission = -1.0
	arrival_direction = BattleEncounter.DIRECTIONS[_rng.randi_range(0, BattleEncounter.DIRECTIONS.size() - 1)]
	for index in encounter.enemies.size():
		var definition := encounter.enemies[index]
		var enemy := BattleEnemy.new()
		enemy.id = StringName("enemy_%d" % enemies.size())
		enemy.kind = definition.kind
		enemy.radius = definition.radius
		enemy.mass = definition.mass
		enemy.word = _take_word()
		enemy.max_hp_q = roundi((definition.health + (wave - 1) * 3) * _pressure * encounter.health_multiplier * Q)
		enemy.hp_q = enemy.max_hp_q
		enemy.attack_damage_q = roundi(definition.attack_damage * _pressure * Q)
		enemy.attack_interval = definition.attack_interval / _pressure
		enemy.attack_clock = 2.4 + index * 1.0
		for feature in encounter.element_traits:
			if feature.enemy_kind == enemy.kind: feature.apply(enemy)
		# Cold arrivals become word targets only after entering the clear battlefield.
		enemy.approach_direction = encounter.approach_direction(arrival_direction, _rng)
		enemy.ambush = enemy.approach_direction != arrival_direction
		enemy.position = BattleEncounter.entry_position(enemy.approach_direction, index, encounter.enemies.size(), ARENA_SIZE)
		enemy.previous_position = enemy.position
		enemies.append(enemy)
	event_committed.emit({"kind": &"wave", "wave": wave, "direction": arrival_direction, "at": Vector2(0.5, 0.5)})


func queue_action(action: StringName) -> void:
	var command := BattleCommand.intent(action)
	if action == &"assist":
		command.attempt_id = typing.current_attempt_id()
		command.target_id = typing.target_id
		command.input_progress = typing.progress
	queue_command(command)


func queue_command(command: BattleCommand) -> void:
	if command != null:
		_commands.append(command)


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if result != 0:
		return
	elapsed += delta
	for command in _commands:
		if command.build != null:
			if command.build.book() != book_id:
				event_committed.emit({"kind": &"build_rejected", "reason": "主书变化需要房间边界"})
				continue
			compiled_build = command.build
			runtime.install(command.build)
			player_max_hp_q = 100 * (Q + compiled_build.value(&"max_hp_bonus_q"))
			player_hp_q = mini(player_hp_q, player_max_hp_q)
			_apply_acquisition()
		elif command.action == &"assist":
			if command.attempt_id == typing.current_attempt_id() and command.target_id == typing.target_id and command.input_progress == typing.progress:
				typing.complete_assisted()
		else:
			_actions.append(command.action)
	_commands.clear()
	# A valid input lock survives subsequent knockback, completion and cancellation.
	for id in _pending_locks:
		var locked := enemy_by_id(id)
		if locked != null:
			locked.combat_locked = true
	_pending_locks.clear()
	# Input ownership: physical receipts, abandoned attempts, then completed words.
	for receipt in typing.drain_receipts():
		if ledger.accept_manual(receipt):
			runtime.observe_input(receipt)
			manual_characters += 1
			event_committed.emit({"kind": &"manual_input", "at": player_position})
	for attempt in _abandoned:
		ledger.abandon(attempt)
		runtime.abandon_attempt(attempt)
	_abandoned.clear()
	for completion in _completed:
		_commit_word(completion)
	_completed.clear()
	for action in _actions:
		_commit_action(action)
		if result != 0:
			break
	_actions.clear()
	if result != 0:
		state_changed.emit()
		return
	parry_window = maxf(0.0, parry_window - delta)
	parry_cooldown = maxf(0.0, parry_cooldown - delta)
	dodge_window = maxf(0.0, dodge_window - delta)
	hurt_window = maxf(0.0, hurt_window - delta)
	dodge_charges = minf(2.0 + compiled_build.value(&"dodge_capacity"), dodge_charges + delta / 4.0 * (Q + compiled_build.value(&"dodge_recovery_q")) / Q)
	dodge_cooldown = maxf(0.0, (1.0 - dodge_charges) * 4.0)
	previous_player_position = player_position
	if _dodge_time < 0.17:
		_dodge_time = minf(0.17, _dodge_time + delta)
		player_position = _dodge_from.lerp(_dodge_to, 1.0 - pow(1.0 - _dodge_time / 0.17, 3))
		if _dodge_time == 0.17:
			event_committed.emit({"kind": &"dodge_end", "at": player_position})
	else:
		player_position = clamp_player(player_position + player_impulse * delta / ARENA_SIZE)
		player_impulse *= exp(-delta * 9.0)
	var world_delta := delta
	if counter_slow_remaining > 0.0:
		var start_time := 0.52 - counter_slow_remaining
		world_delta = _counter_time_integral(start_time + delta) - _counter_time_integral(start_time)
		counter_slow_remaining = maxf(0.0, counter_slow_remaining - delta)
	runtime.advance(world_delta)
	_advance_ultimates(world_delta)
	_advance_effects(world_delta)
	_advance_enemy_motion(world_delta)
	_resolve_bodies()
	_advance_projectiles(world_delta)
	_advance_blades(world_delta)
	_advance_enemies(world_delta)
	_advance_threats(world_delta)
	if player_hp_q <= 0 and compiled_build.has(&"revive"):
		for asset in compiled_build.asset_instances():
			if asset.content_id == &"R024" and run_state.claim_asset(asset.usage_key(), &"revive"):
				player_hp_q = player_max_hp_q / 3
				hurt_window = 1.0
				break
	if player_hp_q <= 0:
		_end(false)
	elif _living().is_empty() and effects.is_empty() and projectiles.is_empty():
		if wave == encounter.wave_count:
			_end(true)
		elif intermission < 0.0:
			intermission = encounter.wave_interval
			threats.clear()
		else:
			intermission = maxf(0.0, intermission - delta)
			if intermission == 0.0:
				_spawn_wave()
	state_changed.emit()


func enemy_by_id(id: StringName) -> BattleEnemy:
	for enemy in enemies:
		if enemy.id == id:
			return enemy
	return null


func spirit_blade_count() -> int:
	var count := 0
	for spirit in spirits:
		if not spirit.crossing:
			count += 1
	return count


func word_meaning(word: String) -> String:
	for entry in _words:
		if entry.word == word:
			return entry.meaning
	return ""


func _take_word() -> String:
	var candidates: Array[VocabularyEntry] = []
	var upper := _minimum_length + 3 + floori(completed_words / 5.0) if _progressive else 24
	for entry in _words:
		if entry.playable_length() <= upper:
			candidates.append(entry)
	if candidates.is_empty():
		var shortest := 24
		for entry in _words:
			shortest = mini(shortest, entry.playable_length())
		for entry in _words:
			if entry.playable_length() == shortest:
				candidates.append(entry)
	var unused: Array[VocabularyEntry] = []
	for candidate in candidates:
		var already_visible := false
		for enemy in enemies:
			if enemy.alive() and enemy.word == candidate.word:
				already_visible = true
		if not already_visible:
			unused.append(candidate)
	if not unused.is_empty():
		candidates = unused
	return candidates[_rng.randi_range(0, candidates.size() - 1)].word


func _commit_word(completion: WordCompletion) -> void:
	var paid := ledger.claim_word(completion.attempt_id, completion.manual_positions.size())
	if paid.is_empty():
		return
	var target := enemy_by_id(completion.target_id)
	if target == null or not target.alive():
		target = _nearest_living(Vector2(0.5, 0.5))
	if target == null:
		return
	var power_q: int = paid["power_q"]
	var previous_resonance := resonance_q
	if ultimate_time <= 0.0:
		resonance_q = mini(ULTIMATE_COST_Q, resonance_q + power_q * (Q + compiled_build.value(&"resonance_bonus_q")) / Q)
	if previous_resonance < ULTIMATE_COST_Q and resonance_q == ULTIMATE_COST_Q:
		event_committed.emit({"kind": &"ultimate_ready", "at": player_position})
	if completion.fully_manual():
		completed_words += 1
	var cast_origin := _player_position()
	var cycle: int = compiled_build.value(&"cadence", MAIN_SPELL_CYCLES[book_id])
	var empowered := completion.fully_manual() and completed_words % cycle == 0
	var word_owner := enemy_by_id(completion.target_id)
	if word_owner != null and word_owner.alive():
		word_owner.word_pending = true
	var primary := runtime.assemble(paid, completion, target, empowered)
	effects.append(primary)
	event_committed.emit({"kind": &"cast", "book": book_id, "at": cast_origin, "target": target.position, "power_q": power_q, "empowered": empowered})
	# The paid primary owns renewal even when its homing target changes later.
	if word_owner != null and word_owner.alive():
		typing.retire_target(word_owner.id)
	if book_id == &"storm" and ultimate_time > 0.0 and completion.fully_manual():
		for ultimate in ultimates:
			if ultimate.effect != null and ultimate.effect.lot.amount_q > 0:
				var strike := runtime.fork(ultimate.effect, mini(12 * Q, ultimate.effect.lot.amount_q), &"storm_ultimate", target.id, Vector2(target.position.x, 0.04))
				strike.delay = 0.1
				effects.append(strike)
				break


func _release_word(effect: BattleEffect, hit: bool) -> void:
	if effect.word_owner == &"":
		return
	var word_target := enemy_by_id(effect.word_owner)
	effect.word_owner = &""
	if word_target == null or not word_target.alive():
		return
	word_target.word_pending = false
	word_target.word_age = 0.0
	if hit:
		word_target.word = _take_word()
	if enemy_in_combat(word_target):
		typing.upsert_target(word_target.id, word_target.word)


func _advance_effects(delta: float) -> void:
	var index := 0
	while index < effects.size():
		var effect := effects[index]
		effect.delay -= delta
		if effect.delay > 0.0:
			index += 1
			continue
		effects.remove_at(index)
		var target := enemy_by_id(effect.target_id)
		if target == null or not target.alive():
			target = _nearest_living(effect.origin)
		if target == null:
			_release_word(effect, false)
			runtime.retire(effect)
			continue
		effect.target_id = target.id
		runtime.dispatch(effect, target)
		if effect.kind == &"storm_beam":
			var direction := ((target.position - effect.origin) * ARENA_SIZE).normalized()
			var endpoint := effect.origin * ARENA_SIZE + direction * 950.0
			var touched: Array[BattleEnemy] = []
			for enemy in _living():
				if enemy_in_combat(enemy) and CombatGeometry.sweep_discs(effect.origin * ARENA_SIZE, endpoint, enemy.position * ARENA_SIZE, enemy.position * ARENA_SIZE, enemy.radius + 14.0) != INF: touched.append(enemy)
			touched.sort_custom(func(a: BattleEnemy, b: BattleEnemy) -> bool: return a.position.distance_squared_to(effect.origin) < b.position.distance_squared_to(effect.origin))
			var total := effect.lot.amount_q
			for hit in touched.size():
				var beam_part := runtime.fork(effect, total / touched.size() + (1 if hit < total % touched.size() else 0), &"storm_arc", touched[hit].id, effect.origin)
				runtime.contact(beam_part, touched[hit], effect.origin)
			_release_word(effect, not touched.is_empty())
			runtime.retire(effect)
		elif effect.kind == &"spirit_cross":
			var spirit := BattleSpirit.new()
			spirit.crossing = true
			spirit.slot = 0 if effect.origin.x < target.position.x else 1
			var axis := Vector2.from_angle(PI * (0.24 if spirit.slot == 0 else 0.76))
			spirit.position = target.position - axis * 162.0 / ARENA_SIZE
			spirit.previous_position = spirit.position
			spirit.target_id = target.id
			spirit.damage_q = effect.damage_q
			spirit.effect = effect
			spirit.begin(&"cross", target.position + axis * 162.0 / ARENA_SIZE)
			spirits.append(spirit)
		elif effect.kind in [&"frost_spear", &"frost_fragment", &"frost_ultimate", &"flame_burst", &"flame_splash", &"flame_meteor", &"spirit_mark"]:
			var projectile := BattleProjectile.new(effect)
			projectile.speed *= float(Q + effect.build.value(&"flight_speed_q")) / Q
			projectile.velocity = ((target.position - projectile.position) * ARENA_SIZE).normalized() * projectile.speed
			projectiles.append(projectile)
		else:
			_impact_effect(effect, target, effect.origin)


func _advance_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var projectile := projectiles[index]
		projectile.life -= delta
		projectile.previous_position = projectile.position
		var target := enemy_by_id(projectile.effect.target_id)
		if projectile.homing:
			if target == null or not target.alive():
				target = runtime.retarget(projectile.effect, projectile.position, projectile.hit_ids)
				if target == null:
					_release_word(projectile.effect, false)
					runtime.retire(projectile.effect)
					projectiles.remove_at(index)
					continue
				projectile.effect.target_id = target.id
			var desired := ((target.position - projectile.position) * ARENA_SIZE).angle()
			var turn := 17.0 if str(projectile.effect.kind).begins_with("frost") else 12.0
			projectile.velocity = Vector2.from_angle(lerp_angle(projectile.velocity.angle(), desired, 1.0 - exp(-delta * turn))) * projectile.speed
		projectile.position += projectile.velocity * delta / ARENA_SIZE
		projectile.trail.append(projectile.position)
		if projectile.trail.size() > 9:
			projectile.trail.remove_at(0)
		var contacts: Array[Dictionary] = []
		for enemy in enemies:
			if not enemy.alive() or not enemy_in_combat(enemy) or str(enemy.id) in projectile.hit_ids:
				continue
			var time := CombatGeometry.sweep_discs(projectile.previous_position * ARENA_SIZE, projectile.position * ARENA_SIZE, enemy.previous_position * ARENA_SIZE, enemy.position * ARENA_SIZE, projectile.radius + enemy.radius)
			if time != INF:
				contacts.append({"enemy": enemy, "time": time})
		contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.time < b.time if a.time != b.time else str(a.enemy.id) < str(b.enemy.id)
		)
		for contact in contacts:
			var enemy: BattleEnemy = contact.enemy
			var center := projectile.previous_position.lerp(projectile.position, contact.time)
			var enemy_center := enemy.previous_position.lerp(enemy.position, contact.time)
			var surface := CombatGeometry.contact_point(center * ARENA_SIZE, enemy_center * ARENA_SIZE, projectile.radius, projectile.velocity) / ARENA_SIZE
			projectile.hit_ids.append(str(enemy.id))
			var primary := enemy.id == projectile.effect.target_id
			runtime.contact(projectile.effect, enemy, projectile.previous_position, primary, surface)
			if primary: _release_word(projectile.effect, true)
			projectile.remaining_hits -= 1
			if primary:
				projectile.homing = false
			# Ice keeps seeking its paid primary even if intervening bodies use its pierces.
			if projectile.remaining_hits <= 0 and not projectile.homing:
				projectile.position = center
				projectile.trail[projectile.trail.size() - 1] = center
				projectile.remaining_hits = 0
				break
		if (projectile.remaining_hits <= 0 and not projectile.homing) or projectile.life <= 0.0 or not Rect2(Vector2(-0.05, -0.05), Vector2(1.1, 1.1)).has_point(projectile.position):
			_release_word(projectile.effect, false)
			runtime.retire(projectile.effect)
			projectiles.remove_at(index)


func _impact_effect(effect: BattleEffect, target: BattleEnemy, origin: Vector2, contact: Vector2 = Vector2.INF) -> void:
	if not enemy_in_combat(target):
		_release_word(effect, false)
		return
	runtime.contact(effect, target, origin, true, contact)
	if target.id == effect.word_owner:
		_release_word(effect, true)


func _advance_blades(delta: float) -> void:
	spirit_time = maxf(0.0, spirit_time - delta)
	var count := spirit_blade_count()
	for index in range(spirits.size() - 1, -1, -1):
		var spirit := spirits[index]
		if not spirit.crossing and spirit_time == 0.0:
			if spirit.effect != null: runtime.retire(spirit.effect)
			if spirit.cargo != null: runtime.return_cargo(spirit.cargo, spirit.position)
			spirits.remove_at(index)
			continue
		spirit.previous_position = spirit.position
		spirit.cooldown -= delta
		var orbit := _spirit_orbit(spirit.slot, count)
		var target := enemy_by_id(spirit.target_id)
		if spirit.mode == &"hold":
			if target == null or not target.alive():
				spirit.begin(&"return", orbit)
			else:
				spirit.position = target.position + Vector2(-target.radius - 10, 0) / ARENA_SIZE
				if runtime.deliver(spirit.cargo, target, spirit.position):
					spirit.cargo = null
					spirit.begin(&"return", orbit)
			continue
		if spirit.mode == &"orbit" and spirit.cooldown <= 0.0 and not runtime.spirit_attacks.is_empty():
			target = enemy_by_id(spirit_focus)
			if target == null or not target.alive() or target.marked_time <= 0.0:
				target = _nearest_living(spirit.position)
			if target != null:
				spirit.target_id = target.id
				spirit.effect = runtime.take_spirit_attack(target, spirit.position)
				if spirit.effect != null:
					spirit.damage_q = spirit.effect.lot.amount_q
					spirit.begin(&"dive", target.position)
					spirit.cargo = runtime.pickup(spirit)
		if spirit.mode == &"dive" and (target == null or not target.alive()):
			if spirit.effect != null: runtime.retire(spirit.effect)
			spirit.effect = null
			spirit.damage_q = 0
			spirit.begin(&"return", orbit)
		if spirit.mode == &"orbit":
			var phase := elapsed * 0.5 + spirit.slot * TAU / maxf(1.0, count)
			var tangent := Vector2(-sin(phase) * 78, cos(phase) * 49.5)
			spirit.velocity = spirit.velocity.lerp(tangent + (orbit - spirit.position) * ARENA_SIZE * 3.0, 1.0 - exp(-delta * 5.0))
			spirit.position += spirit.velocity * delta / ARENA_SIZE
		else:
			if spirit.mode == &"dive":
				spirit.endpoint = target.position
			elif spirit.mode == &"return":
				spirit.endpoint = orbit
			spirit.flight_time = minf(spirit.duration, spirit.flight_time + delta)
			spirit.position = spirit.sample(spirit.flight_time / spirit.duration)
			if delta > 0.0:
				spirit.velocity = (spirit.position - spirit.previous_position) * ARENA_SIZE / delta
			if spirit.cargo != null: spirit.cargo.position = spirit.position
			if spirit.mode in [&"dive", &"cross"] and not spirit.struck and target != null and target.alive():
				var contact_time := CombatGeometry.sweep_discs(spirit.previous_position * ARENA_SIZE, spirit.position * ARENA_SIZE, target.previous_position * ARENA_SIZE, target.position * ARENA_SIZE, target.radius + 10.0)
				if contact_time != INF:
					var center := spirit.previous_position.lerp(spirit.position, contact_time)
					var target_center := target.previous_position.lerp(target.position, contact_time)
					var contact := CombatGeometry.contact_point(center * ARENA_SIZE, target_center * ARENA_SIZE, 10.0, spirit.velocity) / ARENA_SIZE
					var holding := false
					if spirit.effect != null:
						if spirit.cargo != null:
							holding = not runtime.deliver(spirit.cargo, target, contact)
							if not holding: spirit.cargo = null
						else:
							runtime.dispatch(spirit.effect, target)
							runtime.contact(spirit.effect, target, spirit.previous_position, true, contact)
					spirit.damage_q = 0
					if spirit.crossing:
						spirit.struck = true
					else:
						spirit.position = center
						spirit.cooldown = 0.24 if ultimate_time > 0.0 and book_id == &"spirit" else 0.55
						if holding:
							spirit.mode = &"hold"
							spirit.flight_time = 0.0
						else: spirit.begin(&"return", orbit)
			if spirit.flight_time >= spirit.duration:
				if spirit.crossing:
					spirits.remove_at(index)
				elif spirit.mode == &"return":
					if spirit.cargo != null:
						runtime.return_cargo(spirit.cargo, spirit.position)
						spirit.cargo = null
					spirit.mode = &"orbit"
				else:
					if spirit.effect != null: runtime.retire(spirit.effect)
					spirit.effect = null
					spirit.damage_q = 0
					spirit.begin(&"return", orbit)
		if spirit.trail.is_empty() or ((spirit.position - spirit.trail[-1]) * ARENA_SIZE).length() >= 3.0:
			spirit.trail.append(spirit.position)
			if spirit.trail.size() > 20:
				spirit.trail.remove_at(0)


func _spirit_orbit(slot: int, count: int) -> Vector2:
	var phase := elapsed * 0.5 + slot * TAU / maxf(1.0, count)
	return player_position + Vector2(cos(phase) * (156.0 + sin(phase * 2.0) * 19.5), -25.5 + sin(phase) * 99.0 + sin(phase * 2.0 + slot) * 19.5) / ARENA_SIZE


func _summon_spirit() -> void:
	var count := spirit_blade_count()
	var capacity := (SPIRIT_CAPACITY if book_id == &"spirit" else 1) + compiled_build.value(&"summon_capacity")
	if compiled_build.mode(&"shape") == &"lone_blade": capacity = 1
	if count >= capacity:
		return
	var spirit := BattleSpirit.new()
	spirit.slot = count
	spirit.position = player_position + Vector2(0, -30) / ARENA_SIZE
	spirit.previous_position = spirit.position
	spirit.cooldown = 0.35 + count * 0.15
	spirits.append(spirit)
	event_committed.emit({"kind": &"spirit_summon", "at": spirit.position})


func _advance_enemy_motion(delta: float) -> void:
	for enemy in enemies:
		if not enemy.alive():
			continue
		enemy.previous_position = enemy.position
		enemy.age += delta
		if not enemy.word_pending:
			enemy.word_age += delta
		enemy.hit_flash = maxf(0.0, enemy.hit_flash - delta)
		enemy.squash *= exp(-delta * 15.0)
		enemy.counter_push_time = maxf(0.0, enemy.counter_push_time - delta)
		enemy.marked_time = maxf(0.0, enemy.marked_time - delta)
		enemy.frozen_time = maxf(0.0, enemy.frozen_time - delta)
		enemy.stagger_time = maxf(0.0, enemy.stagger_time - delta)
		# Approach into the arena before keeping firing distance. The inner margin
		# prevents unselected enemies from backing across the word visibility edge.
		var entering := not enemy.combat_locked and not in_combat(enemy.position, enemy.radius + 32.0)
		var approach := player_position
		if entering:
			var inset := Vector2.ONE * (EDGE_WIDTH + enemy.radius + 32.0) / ARENA_SIZE
			approach = approach.clamp(inset, Vector2.ONE - inset)
		var toward := (approach - enemy.position) * ARENA_SIZE
		var distance := toward.length()
		var desired := Vector2.ZERO
		if enemy.frozen_time <= 0.0 and enemy.stagger_time <= 0.0 and not enemy.aiming and enemy.melee_strike <= 0.0 and enemy.melee_recovery <= 0.0:
			var speed: float = {&"nib": 46.0, &"quill": 35.0, &"guard": 29.0}[enemy.kind]
			var direction := (1.0 if distance > 82.0 else 0.0) if enemy.kind == &"nib" else (1.0 if distance > 385.0 else (-0.6 if distance < 265.0 else 0.0))
			if entering: direction = 1.0
			if distance > 480.0:
				speed = 90.0
			if in_frost_field(enemy.position):
				speed *= 0.55
			desired = toward.normalized() * speed * direction
		if enemy.local_slow_time > 0.0: desired *= 0.75
		enemy.velocity = enemy.velocity.lerp(desired, 1.0 - exp(-delta * 5.0))
		var drag := 2.8 if enemy.counter_push_time > 0.0 else 4.4
		enemy.position += (enemy.velocity * delta + enemy.impulse * (1.0 - exp(-delta * drag)) / drag) / ARENA_SIZE
		enemy.impulse *= exp(-delta * drag)
		_bound_enemy(enemy)


func _advance_enemies(delta: float) -> void:
	# Motion is already committed for this step. Paid hits resolve before attacks.
	for enemy in enemies:
		if not enemy.alive():
			continue
		if not enemy_in_combat(enemy):
			typing.retire_target(enemy.id)
			enemy.word_age = 0.0
			enemy.aiming = false
			enemy.melee_strike = 0.0
			enemy.attack_clock = maxf(enemy.attack_clock, enemy.warning_time + 0.15)
			continue
		if not enemy.word_pending and not typing._targets.has(enemy.id):
			enemy.word_age = 0.0
			typing.upsert_target(enemy.id, enemy.word)
		var distance := ((player_position - enemy.position) * ARENA_SIZE).length()
		if enemy.kind == &"nib":
			_advance_melee(enemy, delta, distance)
			continue
		if enemy.frozen_time > 0.0 or enemy.stagger_time > 0.0 or (not enemy.aiming and distance > 480.0):
			continue
		enemy.attack_clock -= delta
		if not enemy.aiming and enemy.attack_clock <= enemy.warning_time:
			enemy.aiming = true
			enemy.aimed_position = player_position
			event_committed.emit({"kind": &"warning", "at": enemy.position, "target": enemy.aimed_position, "enemy": enemy.id})
		if enemy.attack_clock <= 0.0:
			_resolve_attack(enemy)
			enemy.attack_clock = enemy.attack_interval
			enemy.aiming = false


func _advance_melee(enemy: BattleEnemy, delta: float, distance: float) -> void:
	if enemy.frozen_time > 0.0 or enemy.stagger_time > 0.0:
		# Interrupted attacks must telegraph again; no stored strike on thaw.
		enemy.aiming = false
		enemy.melee_strike = 0.0
		enemy.attack_clock = maxf(enemy.attack_clock, 0.3)
		return
	if enemy.melee_recovery > 0.0:
		enemy.melee_recovery = maxf(0.0, enemy.melee_recovery - delta)
		return
	if enemy.melee_strike > 0.0:
		if not enemy.melee_hit:
			_resolve_melee(enemy)
		enemy.melee_strike = maxf(0.0, enemy.melee_strike - delta)
		if enemy.melee_strike == 0.0:
			enemy.melee_recovery = BattleEnemy.MELEE_RECOVERY
		return
	enemy.attack_clock = maxf(0.0, enemy.attack_clock - delta)
	if enemy.aiming:
		# Keep the marked footprint fixed. Knockback interrupts a displaced strike.
		if ((enemy.position - enemy.melee_origin) * ARENA_SIZE).length() > 26.0:
			enemy.aiming = false
			enemy.attack_clock = 0.35
		elif enemy.attack_clock == 0.0:
			enemy.attack_serial += 1
			enemy.aiming = false
			enemy.melee_hit = false
			enemy.melee_strike = BattleEnemy.MELEE_STRIKE_TIME
			enemy.attack_clock = enemy.attack_interval
			event_committed.emit({"kind": &"melee_swing", "at": enemy.melee_origin, "enemy": enemy.id})
			_resolve_melee(enemy)
	elif enemy.attack_clock == 0.0 and distance <= BattleEnemy.MELEE_REACH:
		enemy.aiming = true
		enemy.warning_time = 0.72
		enemy.attack_clock = enemy.warning_time
		enemy.velocity = Vector2.ZERO
		enemy.melee_origin = enemy.position
		enemy.aimed_position = player_position
		enemy.melee_direction = ((player_position - enemy.position) * ARENA_SIZE).normalized()
		if enemy.melee_direction.is_zero_approx():
			enemy.melee_direction = Vector2.DOWN
		event_committed.emit({"kind": &"warning", "at": enemy.position, "target": player_position, "enemy": enemy.id})


func _resolve_attack(enemy: BattleEnemy) -> void:
	enemy.attack_serial += 1
	if enemy.kind != &"nib":
		var angle := ((enemy.aimed_position - enemy.position) * ARENA_SIZE).angle()
		for lane in [-1, 0, 1]:
			var threat := BattleThreat.new()
			threat.source_id = enemy.id
			threat.attack_id = "%s:%s:%s:%s" % [ledger.room_id, enemy.id, enemy.attack_serial, lane]
			threat.position = enemy.position
			threat.previous_position = enemy.position
			threat.velocity = Vector2.from_angle(angle + lane * 0.15) * (320.0 if enemy.kind == &"guard" else 380.0)
			threat.damage_q = enemy.attack_damage_q
			threat.radius = 7.0 if enemy.kind == &"guard" else 4.5
			threats.append(threat)
		event_committed.emit({"kind": &"enemy_shot", "at": enemy.position, "target": enemy.aimed_position})
		return


func _resolve_melee(enemy: BattleEnemy) -> void:
	var offset := (player_position - enemy.melee_origin) * ARENA_SIZE
	if not CombatGeometry.disc_in_sector(offset, 21.0, enemy.melee_direction, BattleEnemy.MELEE_REACH, BattleEnemy.MELEE_HALF_ANGLE):
		return
	var outcome: StringName = &"miss"
	var strike_origin := enemy.melee_origin
	if parry_window > 0.0 or (dodge_window <= 0.0 and hurt_window <= 0.0):
		enemy.melee_hit = true
		if parry_window > 0.0:
			outcome = &"parry"
			_counter_contact(enemy)
		else:
			outcome = &"hit"
			_take_player_damage(enemy.attack_damage_q, "%s:%s:melee:%s" % [ledger.room_id, enemy.id, enemy.attack_serial])
			hurt_window = 0.45
			player_impulse = ((player_position - enemy.position) * ARENA_SIZE).normalized() * 210.0
	if outcome != &"miss":
		event_committed.emit({"kind": &"enemy_attack", "at": player_position, "from": strike_origin, "outcome": outcome, "damage_q": enemy.attack_damage_q})


func _advance_threats(delta: float) -> void:
	for index in range(threats.size() - 1, -1, -1):
		var threat := threats[index]
		threat.previous_position = threat.position
		var pace := 0.63 if not threat.reflected and in_frost_field(threat.position) else 1.0
		threat.position += threat.velocity * delta * pace / ARENA_SIZE
		threat.life -= delta
		if ((threat.position - player_position) * ARENA_SIZE).length() <= 75.0 and dodge_window > 0.0: runtime.graze(threat)
		threat.trail.append(threat.position)
		if threat.trail.size() > 12:
			threat.trail.remove_at(0)
		if threat.reflected:
			var hit: BattleEnemy
			var closest := INF
			for enemy in _living():
				if not enemy_in_combat(enemy):
					continue
				var time := CombatGeometry.sweep_discs(threat.previous_position * ARENA_SIZE, threat.position * ARENA_SIZE, enemy.previous_position * ARENA_SIZE, enemy.position * ARENA_SIZE, enemy.radius + threat.radius)
				if time < closest:
					hit = enemy
					closest = time
			if hit != null:
				threat.position = threat.previous_position.lerp(threat.position, closest)
				var target_at := hit.previous_position.lerp(hit.position, closest)
				var contact := CombatGeometry.contact_point(threat.position * ARENA_SIZE, target_at * ARENA_SIZE, threat.radius, threat.velocity) / ARENA_SIZE
				if threat.effect != null: runtime.contact(threat.effect, hit, threat.previous_position, true, contact)
			if hit != null or threat.life <= 0.0:
				threats.remove_at(index)
			continue
		var radius := 54.0 if parry_window > 0.0 else 21.0
		var contact_time := CombatGeometry.sweep_discs(threat.previous_position * ARENA_SIZE, threat.position * ARENA_SIZE, previous_player_position * ARENA_SIZE, player_position * ARENA_SIZE, radius + threat.radius)
		if contact_time != INF and (parry_window > 0.0 or (dodge_window <= 0.0 and hurt_window <= 0.0)):
			threat.position = threat.previous_position.lerp(threat.position, contact_time)
			var outcome: StringName = &"hit"
			if parry_window > 0.0:
				outcome = &"parry"
				_parry_feedback(threat.source_id)
				var source := enemy_by_id(threat.source_id)
				var direction := ((source.position - threat.position) * ARENA_SIZE).normalized() if source != null and source.alive() else -threat.velocity.normalized()
				threat.velocity = direction * maxf(540.0, threat.velocity.length() * 1.6)
				threat.reflected = true
				threat.effect = runtime.counter(threat.attack_id, threat.damage_q, threat.source_id, threat.position)
				threat.damage_q = threat.effect.lot.amount_q if threat.effect != null else 0
				threat.life = 3.0
				threat.trail.clear()
			else:
				_take_player_damage(threat.damage_q, threat.attack_id)
				hurt_window = 0.45
				player_impulse = threat.velocity.normalized() * 165.0
			event_committed.emit({"kind": &"enemy_attack", "at": player_position, "from": threat.position, "outcome": outcome, "damage_q": threat.damage_q})
			if not threat.reflected:
				threats.remove_at(index)
		elif threat.life <= 0.0 or not Rect2(Vector2(-0.05, -0.05), Vector2(1.1, 1.1)).has_point(threat.position):
			threats.remove_at(index)


func _commit_action(action: StringName) -> void:
	if action == &"abandon":
		abandoned_run = true
		_end(false)
		return
	if action == &"parry":
		if parry_cooldown <= 0.0 and _dodge_time >= 0.17:
			parry_window = 0.24
			parry_cooldown = maxf(0.1, 0.7 + compiled_build.value(&"parry_cooldown_ms") / 1000.0)
			_parry_succeeded = false
			event_committed.emit({"kind": &"parry_start", "at": _player_position()})
		return
	if action == &"ultimate":
		if ultimate_time <= 0.0 and resonance_q >= ULTIMATE_COST_Q and _nearest_living(player_position) != null:
			resonance_q -= ULTIMATE_COST_Q
			_commit_ultimate()
		return
	if not str(action).begins_with("dodge") or dodge_charges < 1.0 or _dodge_time < 0.17:
		return
	var direction := Vector2.ZERO
	match action:
		&"dodge_left": direction = Vector2.LEFT
		&"dodge_right": direction = Vector2.RIGHT
		&"dodge_up": direction = Vector2.UP
		&"dodge_down": direction = Vector2.DOWN
		&"dodge_auto": direction = _safe_direction()
	var destination := clamp_player(player_position + direction * 240.0 / ARENA_SIZE)
	if ((destination - player_position) * ARENA_SIZE).length() < 8.0:
		return
	_dodge_from = player_position
	_dodge_to = destination
	_dodge_time = 0.0
	player_impulse = Vector2.ZERO
	dodge_window = 1.0
	dodge_charges -= 1.0
	runtime.on_dodge(_dodge_from, destination)
	parry_window = 0.0
	event_committed.emit({"kind": &"dodge", "at": player_position, "target": destination})


static func _counter_time_integral(time: float) -> float:
	var recovery := clampf((time - 0.06) / 0.46, 0.0, 1.0)
	return 0.08 * minf(time, 0.52) + 0.92 * 0.46 * (pow(recovery, 3.0) - pow(recovery, 4.0) * 0.5) + maxf(0.0, time - 0.52)


func _parry_feedback(source_id: StringName) -> void:
	if _parry_succeeded:
		return
	_parry_succeeded = true
	counter_slow_remaining = 0.52
	for enemy in _living():
		var offset := (enemy.position - player_position) * ARENA_SIZE
		if offset.length() > 160.0:
			continue
		var direct := enemy.id == source_id
		var direction := offset.normalized() if not offset.is_zero_approx() else Vector2.UP
		enemy.impulse = direction * (3300.0 if direct else 1575.0) * (1.0 - 0.25 * offset.length() / 278.0) / sqrt(enemy.mass)
		enemy.counter_push_time = 1.2
		enemy.velocity = Vector2.ZERO
		enemy.aiming = false
		enemy.melee_strike = 0.0
		enemy.stagger_time = 1.2 if direct else 0.7
		enemy.attack_clock = maxf(enemy.attack_clock, 1.4)
	event_committed.emit({"kind": &"counter_pulse", "at": player_position})


func _separate_player(enemy: BattleEnemy) -> void:
	var offset := (enemy.position - player_position) * ARENA_SIZE
	if offset.length() >= enemy.radius + 25.0:
		return
	var direction := offset.normalized() if not offset.is_zero_approx() else Vector2.UP
	enemy.position = player_position + direction * (enemy.radius + 25.0) / ARENA_SIZE


func _counter_contact(enemy: BattleEnemy) -> void:
	_separate_player(enemy)
	var effect := runtime.counter("%s:%s:melee:%s" % [ledger.room_id, enemy.id, enemy.attack_serial], enemy.attack_damage_q, enemy.id, player_position)
	if effect != null: runtime.contact(effect, enemy, player_position)
	_parry_feedback(enemy.id)
	if enemy.alive():
		enemy.impulse = ((enemy.position - player_position) * ARENA_SIZE).normalized() * 3300.0 / sqrt(enemy.mass)
		enemy.counter_push_time = 1.2
		enemy.stagger_time = 1.2
		enemy.velocity = Vector2.ZERO
		enemy.aiming = false
		enemy.melee_strike = 0.0
		enemy.attack_clock = maxf(enemy.attack_clock, 2.4)


func _bound_enemy(enemy: BattleEnemy) -> void:
	var bounded := enemy.position.clamp(Vector2(0.025, 0.04), Vector2(0.975, 0.94))
	if bounded.x != enemy.position.x:
		enemy.impulse.x *= -0.43
		enemy.velocity.x *= -0.25
	if bounded.y != enemy.position.y:
		enemy.impulse.y *= -0.43
		enemy.velocity.y *= -0.25
	enemy.position = bounded


func _resolve_bodies() -> void:
	var bodies := _living()
	# Sweep before projection: a fast counter push cannot exchange sides with a body.
	for i in bodies.size():
		var a := bodies[i]
		for j in range(i + 1, bodies.size()):
			var b := bodies[j]
			var time := CombatGeometry.sweep_discs(a.previous_position * ARENA_SIZE, a.position * ARENA_SIZE, b.previous_position * ARENA_SIZE, b.position * ARENA_SIZE, a.radius + b.radius + 4.0)
			if time == INF:
				continue
			var a_at := a.previous_position.lerp(a.position, time)
			var b_at := b.previous_position.lerp(b.position, time)
			var offset := (b_at - a_at) * ARENA_SIZE
			if offset.is_zero_approx():
				offset = (b.position - a.position) * ARENA_SIZE
			var normal := offset.normalized() if not offset.is_zero_approx() else Vector2.RIGHT
			var inverse_a := 1.0 / a.mass
			var inverse_b := 1.0 / b.mass
			var total := inverse_a + inverse_b
			var blocked := maxf(0.0, ((a.position - a_at - b.position + b_at) * ARENA_SIZE).dot(normal))
			a.position -= normal * blocked * inverse_a / total / ARENA_SIZE
			b.position += normal * blocked * inverse_b / total / ARENA_SIZE
			var relative := (a.velocity + a.impulse - b.velocity - b.impulse).dot(normal)
			if relative > 0.0:
				if relative > 80.0: runtime.body_contact(a, b)
				# Slow crowd pressure is inelastic; only a real impact gets rebound.
				var restitution := 0.12 if relative > 80.0 else 0.0
				var momentum := relative * (1.0 + restitution) / total
				a.impulse -= normal * momentum * inverse_a
				b.impulse += normal * momentum * inverse_b
				if relative > 80.0:
					a.squash = 0.18
					b.squash = 0.18
	# Revisit constraints after neighbors move; one pass leaves chain overlaps.
	for iteration in 4:
		for i in bodies.size():
			var a := bodies[i]
			for j in range(i + 1, bodies.size()):
				var b := bodies[j]
				var offset := (b.position - a.position) * ARENA_SIZE
				var distance := offset.length()
				var overlap := a.radius + b.radius + 4.0 - distance
				if overlap <= 0.15:
					continue
				var normal := offset / distance if distance > 0.001 else Vector2.RIGHT
				var inverse_a := 1.0 / a.mass
				var inverse_b := 1.0 / b.mass
				var correction := normal * (overlap - 0.15) / (inverse_a + inverse_b) / ARENA_SIZE
				a.position -= correction * inverse_a
				b.position += correction * inverse_b
		for enemy in bodies:
			if _dodge_time >= 0.17:
				_separate_player(enemy)
			_bound_enemy(enemy)
		bodies.reverse()


func _safe_direction() -> Vector2:
	var best := Vector2.LEFT
	var best_clearance := -INF
	for index in 8:
		var direction := Vector2.from_angle(index * TAU / 8.0)
		var at := clamp_player(player_position + direction * 240.0 / ARENA_SIZE)
		var clearance := 560.0
		for enemy in enemies:
			if enemy.alive():
				clearance = minf(clearance, ((at - enemy.position) * ARENA_SIZE).length())
		for threat in threats:
			var projected := threat.position * ARENA_SIZE + threat.velocity * 0.45
			clearance = minf(clearance, (at * ARENA_SIZE).distance_to(projected))
		clearance -= ((at - Vector2(0.5, 0.5)) * ARENA_SIZE).length() * 0.15
		if clearance > best_clearance:
			best_clearance = clearance
			best = direction
	return best


func _commit_ultimate() -> void:
	var living: Array[BattleEnemy] = _living().filter(func(enemy: BattleEnemy) -> bool: return enemy_in_combat(enemy))
	var target := enemy_by_id(typing.target_id)
	if target == null or not target.alive() or not enemy_in_combat(target):
		target = _nearest_living(player_position)
	var center := target.position if book_id in [&"frost", &"flame"] else player_position
	var ultimate := BattleUltimate.new(book_id, center)
	ultimate.effect = runtime.ultimate(target)
	if book_id in [&"flame", &"spirit"]:
		living = living.filter(func(enemy: BattleEnemy) -> bool: return ultimate.contains(enemy.position))
	ultimate.duration += compiled_build.value(&"ultimate_duration_ms") / 1000.0
	ultimate.lifetime = maxf(ultimate.lifetime, ultimate.duration)
	ultimate.pulses_left += compiled_build.value(&"ultimate_pulses")
	ultimates.append(ultimate)
	ultimate_time = ultimate.duration
	hurt_window = maxf(hurt_window, 0.65)
	# The release guard shares the ultimate's paid pool with its offensive portions.
	runtime.clear_ultimate_threats(ultimate.effect, player_position)
	event_committed.emit({"kind": &"ultimate", "book": book_id, "at": _player_position(), "center": center, "radius": ultimate.radius, "duration": ultimate.duration})
	var start_budget := ultimate.effect.lot.amount_q / 4
	for index in living.size():
		var enemy := living[index]
		var effect := runtime.fork(ultimate.effect, start_budget / living.size() + (1 if index < start_budget % living.size() else 0), StringName(str(book_id) + "_ultimate"), enemy.id, center)
		runtime.dispatch(effect, enemy)
		runtime.contact(effect, enemy, center)
	if book_id == &"spirit":
		spirit_time = 18.0
		while ultimate.effect.lot.amount_q > 0:
			var attack := runtime.fork(ultimate.effect, mini(6 * Q, ultimate.effect.lot.amount_q), &"spirit_blade", target.id, center)
			attack.expires_at = runtime.clock + 18.0
			runtime.spirit_attacks.append(attack)
		for blade in SPIRIT_CAPACITY: _summon_spirit()


func in_frost_field(at: Vector2) -> bool:
	for ultimate in ultimates:
		if ultimate.book == &"frost" and ultimate.contains(at):
			return true
	return false


func _advance_ultimates(delta: float) -> void:
	ultimate_time = maxf(0.0, ultimate_time-delta)
	for index in range(ultimates.size()-1,-1,-1):
		var ultimate := ultimates[index]
		var active_delta := minf(delta, maxf(0.0, ultimate.duration-ultimate.age))
		ultimate.age += delta
		ultimate.pulse_clock -= active_delta
		while ultimate.pulses_left > 0 and ultimate.pulse_clock <= 0.0:
			ultimate.pulses_left -= 1
			ultimate.pulse_clock += 0.25 if ultimate.book == &"frost" else 0.7
			var target := _nearest_living(Vector2(_rng.randf_range(0.18,0.82),_rng.randf_range(0.22,0.72)))
			if target == null:
				continue
			var amount := ultimate.effect.lot.amount_q / maxi(1, ultimate.pulses_left + 1)
			if ultimate.book == &"frost":
				var origin := target.position + Vector2.from_angle(_rng.randf()*TAU)*375.0/ARENA_SIZE
				var spear := runtime.fork(ultimate.effect, amount, &"frost_ultimate", target.id, origin)
				spear.primary_share_q = spear.lot.amount_q * 2 / 3
				spear.empowered = true
				spear.applications = 2
				effects.append(spear)
			else:
				var origin := (target.position-Vector2(145,375)/ARENA_SIZE).max(Vector2(0.035,0.035))
				var meteor := runtime.fork(ultimate.effect, amount, &"flame_meteor", target.id, origin)
				meteor.empowered = true
				effects.append(meteor)
		if ultimate.age >= ultimate.lifetime:
			runtime.retire(ultimate.effect)
			ultimates.remove_at(index)


func _player_position() -> Vector2:
	return player_position


func commit_damage(enemy: BattleEnemy, damage_q: int, raw_q: int, source: StringName, origin: Vector2, empowered: bool = false, contact: Vector2 = Vector2.INF) -> void:
	if damage_q <= 0 or not enemy.alive() or not enemy_in_combat(enemy):
		return
	var applied_q := mini(enemy.hp_q, damage_q)
	enemy.hp_q = maxi(0, enemy.hp_q - damage_q)
	var direction := ((enemy.position - origin) * ARENA_SIZE).normalized()
	if source != &"flame_burn":
		enemy.hit_flash = 0.12
		enemy.squash = minf(0.36, enemy.squash + 0.19)
		enemy.impulse += direction * minf(550.0, 180.0 + sqrt(float(damage_q) / Q) * 35.0) / enemy.mass
	event_committed.emit({"kind": &"impact", "source": source, "from": origin, "at": enemy.position, "contact": enemy.position if contact == Vector2.INF else contact, "direction": direction, "enemy": enemy.id, "damage_q": damage_q, "applied_q": applied_q, "overkill_q": damage_q - applied_q, "raw_q": raw_q, "resistance": damage_q < raw_q, "weakness": damage_q > raw_q, "empowered": empowered})
	if not enemy.alive():
		enemy.aiming = false
		typing.retire_target(enemy.id)
		event_committed.emit({"kind": &"death", "at": enemy.position, "enemy": enemy.id})


func _living() -> Array[BattleEnemy]:
	var result_enemies: Array[BattleEnemy] = []
	for enemy in enemies:
		if enemy.alive():
			result_enemies.append(enemy)
	return result_enemies


func _nearest_living(origin: Vector2, excluded: PackedStringArray = []) -> BattleEnemy:
	var chosen: BattleEnemy
	var distance := INF
	for enemy in enemies:
		if not enemy.alive() or not enemy_in_combat(enemy) or str(enemy.id) in excluded:
			continue
		var next := ((origin - enemy.position) * ARENA_SIZE).length_squared()
		if next < distance:
			distance = next
			chosen = enemy
	return chosen


func _end(victory: bool) -> void:
	finish_room(&"victory" if victory else (&"abandon" if abandoned_run else &"defeat"))
	result = 1 if victory else -1
	effects.clear()
	projectiles.clear()
	threats.clear()
	spirits.clear()
	ultimates.clear()
	ultimate_time = 0.0
	spirit_time = 0.0
	finished.emit(victory)


func finish_room(reason: StringName) -> RoomCombatResult:
	if room_result != null: return room_result
	for effect in effects: runtime.retire(effect)
	for projectile in projectiles: runtime.retire(projectile.effect)
	for spirit in spirits:
		if spirit.effect != null: runtime.retire(spirit.effect)
	room_result = runtime.finish(reason)
	room_result.manual_characters = manual_characters
	room_result.manual_words = completed_words
	room_result.elapsed = elapsed
	if compiled_build.has(&"progression-policy"):
		room_result.progression_requests.append({"content": &"R021", "room": ledger.room_id, "experience_bonus_q": compiled_build.value(&"experience_cap_q"), "requires": &"chapter_reward_budget"})
	return room_result


func _take_player_damage(amount: int, attack_id: String) -> void:
	amount = runtime.guard(attack_id, amount, player_position)
	var shield := mini(run_state.shield_q, amount)
	run_state.shield_q -= shield
	amount -= shield
	var armor := compiled_build.value(&"armor_q")
	amount = amount * Q / (Q + maxi(0, armor))
	amount = amount * (Q + compiled_build.value(&"incoming_bonus_q")) / Q
	player_hp_q = maxi(0, player_hp_q - amount)
