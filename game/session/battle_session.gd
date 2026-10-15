class_name BattleSession
extends Node
## Annotated integer divisions preserve fixed-point health, damage and finite spell budgets.
## The only owner of battle rules. Input is queued; one fixed step commits each phase.

signal state_changed
signal event_committed(event: Dictionary)
signal finished(victory: bool)
signal progression_changed

const Q := SpellResourceLedger.Q
const ULTIMATE_COST_Q := 100 * Q
const ARENA_SIZE := Vector2(1920.0, 1080.0)
const EDGE_WIDTH := 108.0
const DEFENSE_WINDOW := 0.30
const PERFECT_DEFENSE_WINDOW := 0.10
const PERFECT_REFLECT_WINDOW := 0.30
const DEFENSE_PREDICTION := 0.06
const PERFECT_DODGE_WINDOW := 0.10
const SPIRIT_MOVEMENT_SCALE := 0.75
# Counter recovery crosses precision's 0.1 scale at this real-time age:
# 0.06 + 0.94 * smoothstep(0, 1, (age - 0.06) / 0.46) == 0.1.
const COUNTER_PRECISION_CROSSOVER := 0.11720807774452963
const MAIN_SPELL_CYCLES := {&"frost": 3, &"flame": 3, &"storm": 3, &"spirit": 3}
# Midpoint of the former normal/hard pace; difficulty, chapters and loops
# change pressure and durability without changing learned motion or timing.
const ENEMY_SPEED_SCALE := 1.06
const ENEMY_ATTACK_SCALE := 1.19
const MODE_HEALTH := [0.72, 0.9, 1.24, 1.42, 5.3]
const MODE_DAMAGE := [0.55, 0.85, 1.1, 1.3, 2.4]
const MODE_SPAWN := [4.3, 3.25, 2.25, 1.8, 1.2]
const MODE_CAP := [6, 8, 11, 14, 17]
# Limit concurrent bodies, including summoned children, without reducing the
# room workload or delaying replenishment once the player clears a slot.
const MODE_ACTIVE_CAP := [6, 8, 8, 12, 14]
const MODE_DODGE_CD := [3.6, 4.2, 4.8, 5.3, 5.8]
const MODE_IFRAME := [1.0, 0.85, 0.72, 0.62, 0.54]

var typing := TypingSession.new()
var ledger := SpellResourceLedger.new()
var book_id: StringName = &"frost"
var enemies: Array[BattleEnemy] = []
var _enemies_by_id: Dictionary[StringName, BattleEnemy] = {}
var effects: Array[BattleEffect] = []
var ultimates: Array[BattleUltimate] = []
var ultimate_time := 0.0
var projectiles: Array[BattleProjectile] = []
var threats: Array[BattleThreat] = []
var _advancing_threats: bool = false
var hazards: Array[BattleHazard] = []
var pickups: Array[BattlePickup] = []
var _pickup_clock: float = 6.0
var _pickup_serial: int = 0
var _pickup_words: int = 0
var loop_index: int = 0
var difficulty: String = "normal"
var player_hp_q: int = 100 * Q
var player_max_hp_q: int = 100 * Q
var resonance_q: int = 0
var god_mode: bool = false
var manual_characters: int = 0
var completed_words: int = 0
var player_position := Vector2(0.5, 0.5)
var previous_player_position := Vector2(0.5, 0.5)
var player_impulse := Vector2.ZERO
var dodge_charges: float = 2.0
var parry_window: float = 0.0
var _perfect_reflect_remaining: float = 0.0
var parry_cooldown: float = 0.0
var counter_slow_remaining: float = 0.0
var precision_slow_remaining: float = 0.0
var perfect_dodge_remaining: float = 0.0
var _parry_succeeded: bool = false
var _settled_player_attacks: Dictionary[String, bool] = {}
var dodge_window: float = 0.0
var dodge_cooldown: float = 0.0
var hurt_window: float = 0.0
var result: int = 0 # 0 active, 1 victory, -1 defeat
var abandoned_run := false
var elapsed: float = 0.0
## Committed battlefield seconds; elapsed remains real time for input/statistics.
var world_time: float = 0.0
var world_time_scale: float:
	get:
		if result != 0: return 0.0
		var age := 0.52 - counter_slow_remaining
		var recovery := clampf((age - 0.06) / 0.46, 0.0, 1.0)
		var scale := 0.06 + 0.94 * recovery * recovery * (3.0 - 2.0 * recovery)
		return minf(scale, 0.1) if maxf(precision_slow_remaining, perfect_dodge_remaining) > 0.0 else scale
var encounter: BattleEncounter = preload("res://game/content/single_room.tres")
var wave: int = 0
var intermission: float = -1.0
var arrival_direction: String = "东"
var _pressure: float = 1.0
var _enemy_health_scale: float = 1.0
var _spawn_clock: float = 0.0
var _spawned: int = 0
var _room_quota: int = 0
var _enemy_cap: int = 8
var _dodge_recovery_seconds: float = 4.2
var _hurt_iframe: float = 0.85
var _room_world_time: float = 0.0
var _opening_grace: float = 3.0
var _enemy_serial: int = 0
var _difficulty_rank: int = 1

var _word_meanings: Dictionary[String, String] = {}
var _word_sampler: VocabularySampler
var _maximum_length := 24
var _shortest_length := 1
var _retained_word_id: StringName = &""
var _rng := RandomNumberGenerator.new()
var _progressive: bool = true
var _minimum_length: int = 1
var _completed: Array[WordCompletion] = []
var _abandoned: Array[String] = []
var _actions: Array[StringName] = []
var _pending_locks: Array[StringName] = []
const SPIRIT_CAPACITY := 4
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
var statistics: BattleStatistics
var room_result: RoomCombatResult
var _commands: Array[BattleCommand] = []
var _attack_serial: int = 0
var run_id: String
var attempt_id: String
var chapter: int = 1
var reward_facts: Array[RewardFact] = []
var has_created_redeemable_mark: bool = false
var has_input_interruption: bool = false
var has_same_root_lots: bool = false
var _enemy_definitions: Dictionary[StringName, EnemyCombatDefinition] = {}
var _progression_dirty: bool = false
static var _dodge_prepared := false
var _dodge_scorer: RefCounted = preload("res://game/algorithms/DodgeScorer.cs").new()
var _dodge_points := PackedVector2Array()
var _dodge_starts := PackedInt32Array()
var _dodge_segments := PackedInt32Array()
var _dodge_radii := PackedFloat64Array()
var _dodge_directions := PackedVector2Array()
var _dodge_candidates := PackedVector2Array()
var _dodge_travel := PackedVector2Array()
var _dodge_scores := PackedFloat64Array()
var _dodge_fixed := PackedFloat64Array()
var _dodge_tails := PackedFloat64Array()


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
	for index in 24: _dodge_directions.append(Vector2.from_angle(-PI * 0.5 + index * TAU / 24.0))
	_dodge_candidates.resize(24)
	_dodge_travel.resize(96)
	_dodge_scores.resize(24)
	_dodge_fixed.resize(24)
	if not _dodge_prepared:
		# Prepare both array marshaling and numeric JIT before the first input.
		# Synthetic data invokes the numeric methods without combat state/events.
		_dodge_tails.resize(48)
		_dodge_scorer.Choose(PackedVector2Array([Vector2.ZERO, Vector2.ONE, Vector2.RIGHT]), PackedInt32Array([0]), PackedInt32Array([2]), PackedFloat64Array([33.0]), 1, _dodge_candidates, _dodge_travel, _dodge_scores, _dodge_fixed, _dodge_tails, 2)
		_dodge_prepared = true
	typing.changed.connect(_remember_lock)
	typing.word_completed.connect(func(fact: WordCompletion) -> void: _completed.append(fact))
	typing.abandoned.connect(func(abandoned_id: String) -> void: _abandoned.append(abandoned_id))


func _remember_lock() -> void:
	if _retained_word_id != &"" and typing.target_id != _retained_word_id:
		_word_sampler.release(_retained_word_id)
		_retained_word_id = &""
	var target := enemy_by_id(typing.target_id)
	if target != null and target.alive() and not target.combat_locked and in_combat(target.position, target.radius) and target.id not in _pending_locks:
		_pending_locks.append(target.id)


func start(request: BattleStartRequest, state: RunCombatState = null) -> void:
	assert(request != null and request.build != null and request.vocabulary_index != null and not request.vocabulary.is_empty())
	compiled_build = request.build
	run_state = state if state != null else RunCombatState.new()
	run_state.room_serial = request.room_serial if request.room_serial > 0 else run_state.room_serial + 1
	run_id = request.run_id
	attempt_id = request.attempt_id
	chapter = request.chapter
	loop_index = request.loop_index
	difficulty = request.difficulty
	encounter = request.encounter
	var prepared := request.vocabulary_index
	_word_sampler = VocabularySampler.new(prepared)
	_word_meanings = prepared.meanings
	_maximum_length = request.maximum_length
	_shortest_length = request.minimum_length
	while _shortest_length < _maximum_length and prepared.count(0, request.minimum_length, _shortest_length) == 0:
		_shortest_length += 1
	_retained_word_id = &""
	_enemy_serial = 0
	_start_room(request.build.book(), request.vocabulary, request.difficulty, request.seed_text, request.progressive, request.minimum_length)
	if not request.flight_continuation.is_empty(): ledger = request.flight_continuation.ledger
	# Move live ownership to this page without changing paid roots or claim history.
	for lot in ledger.active_lots(): lot.room_id = run_state.room_serial
	ledger.room_id = run_state.room_serial
	runtime = SpellRuntime.new(self, compiled_build, run_state)
	if not request.flight_continuation.is_empty():
		for property: String in request.flight_continuation.world:
			set(property, request.flight_continuation.world[property])
		for property: String in request.flight_continuation.runtime:
			runtime.set(property, request.flight_continuation.runtime[property])
		previous_player_position = player_position
	if statistics != null: statistics.detach()
	statistics = BattleStatistics.new(self)
	typing.assisted_authorizer = runtime.consume_assist
	player_max_hp_q = compiled_build.maximum_hp_q()
	player_hp_q = mini(player_max_hp_q, run_state.hp_q)
	resonance_q = mini(ULTIMATE_COST_Q, run_state.resonance_q)
	room_result = null
	_commands.clear()
	_attack_serial = 0
	_apply_acquisition()
	if compiled_build.has(&"room-price") and run_state.claim_asset("room:%s" % ledger.room_id, &"price"):
		player_hp_q = maxi(Q, player_hp_q - roundi(Q * compiled_build.relic_number(&"R042", &"room_cost")))
	god_mode = request.god_mode
	if god_mode: _fill_god_resources()
	state_changed.emit()


func activate_god_mode() -> void:
	# Explicit local activation; the caller owns menu access and archive routing.
	god_mode = true
	_fill_god_resources()
	state_changed.emit()


func _fill_god_resources() -> void:
	resonance_q = ULTIMATE_COST_Q
	dodge_charges = 2.0 + compiled_build.value(&"dodge_capacity")
	dodge_cooldown = 0.0


func _apply_acquisition() -> void:
	for asset in compiled_build.asset_instances():
		if asset.content_id == &"R012" and run_state.claim_asset(asset.usage_key(), &"heal"):
			runtime.heal(roundi(Q * compiled_build.relic_number(&"R012", &"heal")))
		if asset.content_id == &"R009" and run_state.claim_asset(asset.usage_key(), &"dodge-charge"):
			dodge_charges = minf(2.0 + compiled_build.value(&"dodge_capacity"), dodge_charges + 1.0)


func install_prepared_build(build: CompiledBuild) -> void:
	# The expedition has already paused after a full step and committed its preview.
	_install_build(build)
	state_changed.emit()


func _install_build(build: CompiledBuild) -> void:
	compiled_build = build
	runtime.install(build)
	player_max_hp_q = compiled_build.maximum_hp_q()
	player_hp_q = mini(player_hp_q, player_max_hp_q)
	_apply_acquisition()


func start_baseline(selected_book: StringName, entries: Array[VocabularyEntry], selected_difficulty: String = "normal", seed_text: String = "", progressive: bool = true, minimum_length: int = 1) -> void:
	var selection := BuildSelection.new()
	selection.book_id = selected_book
	var compiled := BuildCompiler.new().compile(selection)
	assert(compiled.success(), str(compiled.diagnostics))
	var request := BattleStartRequest.new()
	request.build = compiled.build
	request.vocabulary = entries
	# Development-only convenience; formal requests must carry a prepared index.
	request.vocabulary_index = VocabularyIndex.build(entries)
	request.difficulty = selected_difficulty
	request.seed_text = seed_text
	request.progressive = progressive
	request.minimum_length = minimum_length
	request.encounter = encounter
	start(request)


func _start_room(selected_book: StringName, entries: Array[VocabularyEntry], selected_difficulty: String, seed_text: String, progressive: bool, minimum_length: int) -> void:
	assert(selected_book in [&"frost", &"flame", &"storm", &"spirit"] and not entries.is_empty())
	book_id = selected_book
	_progressive = progressive
	_minimum_length = minimum_length
	if seed_text.is_empty():
		_rng.randomize()
	else:
		_rng.seed = seed_text.hash()
	ledger = SpellResourceLedger.new()
	typing.drain_receipts()
	enemies.clear()
	_enemies_by_id.clear()
	_enemy_definitions.clear()
	reward_facts.clear()
	has_created_redeemable_mark = false
	has_input_interruption = false
	has_same_root_lots = false
	_progression_dirty = false
	effects.clear()
	projectiles.clear()
	threats.clear()
	hazards.clear()
	pickups.clear()
	_pickup_clock = 6.0
	_pickup_serial = 0
	_pickup_words = 0
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
	_perfect_reflect_remaining = 0.0
	parry_cooldown = 0.0
	counter_slow_remaining = 0.0
	precision_slow_remaining = 0.0
	perfect_dodge_remaining = 0.0
	_parry_succeeded = false
	_settled_player_attacks.clear()
	dodge_window = 0.0
	dodge_cooldown = 0.0
	hurt_window = 0.0
	result = 0
	abandoned_run = false
	ultimates.clear()
	ultimate_time = 0.0
	elapsed = 0.0
	world_time = 0.0
	wave = 0
	intermission = -1.0
	_difficulty_rank = ["story", "normal", "hard", "nightmare", "apocalypse"].find(selected_difficulty)
	var depth := (_physical_chapter() - 1) * 3 + encounter.room_number - 1
	# Apocalypse establishes its damage threshold in chapter one; later chapters
	# intensify enemy combinations and durability without compounding that threshold.
	var damage_depth := mini(depth, 2) if _difficulty_rank == 4 else depth
	_pressure = MODE_DAMAGE[_difficulty_rank] * (1.0 + damage_depth * 0.045) * (1.0 + 0.08 * loop_index)
	_enemy_health_scale = MODE_HEALTH[_difficulty_rank] * (1.0 + depth * (0.065 + _difficulty_rank * 0.009) + depth * depth * 0.0025) * pow(1.18, loop_index)
	_dodge_recovery_seconds = MODE_DODGE_CD[_difficulty_rank] * (1.0 - compiled_build.relic_number(&"R009", &"recovery_pct") / 100.0)
	_hurt_iframe = MODE_IFRAME[_difficulty_rank]
	_spawned = 0
	_room_world_time = 0.0
	_opening_grace = 3.0
	_room_quota = encounter.enemies.size() * encounter.wave_count if encounter.room_id == &"" else 18 + _difficulty_rank * 6 + (_physical_chapter() - 1) * 8 + encounter.room_number * 4
	_enemy_cap = mini(MODE_CAP[_difficulty_rank] - 2, MODE_ACTIVE_CAP[_difficulty_rank])
	typing.set_targets({})
	# Resetting a reused typing session may abandon the previous room's prefix.
	_abandoned.clear()
	_spawn_wave()
	state_changed.emit()


func _spawn_wave() -> void:
	wave += 1
	intermission = -1.0
	arrival_direction = BattleEncounter.DIRECTIONS[_rng.randi_range(0, BattleEncounter.DIRECTIONS.size() - 1)]
	if encounter.enemies[0].boss:
		_spawn_enemy(encounter.enemies[0], Vector2(0.5, 0.28))
		_room_quota = 0
	else:
		var opening_count := encounter.enemies.size() if encounter.room_id == &"" else (1 if _difficulty_rank < 2 else mini(3, _difficulty_rank))
		var opening_pool := encounter.enemies if encounter.opening_enemies.is_empty() else encounter.opening_enemies
		if not encounter.opening_enemies.is_empty(): opening_count = mini(opening_count, opening_pool.size())
		if wave == 1:
			for index in opening_count:
				_spawn_enemy(opening_pool[index % opening_pool.size()], _arrival_position(arrival_direction), index)
				_spawned += 1
		_spawn_clock = 3.6 if wave == 1 and _physical_chapter() == 1 and encounter.room_number == 1 else (2.4 if wave == 1 else 0.8)
	event_committed.emit({"kind": &"wave", "wave": wave, "direction": arrival_direction, "at": Vector2(0.5, 0.5)})


func _arrival_position(direction: String) -> Vector2:
	# Each arrival samples its own point in the baseline 110-degree assault area.
	# A single-enemy batch must not collapse the area to the compass centerline.
	var angle := BattleEncounter.DIRECTIONS.find(direction) * PI / 4.0 - PI / 2.0
	angle += (_rng.randf() - 0.5) * deg_to_rad(110.0) * encounter.formation_spread
	var ray := Vector2.from_angle(angle)
	var half := ARENA_SIZE * 0.5 - Vector2.ONE * 64.0
	var reach_x := INF if is_zero_approx(ray.x) else half.x / absf(ray.x)
	var reach_y := INF if is_zero_approx(ray.y) else half.y / absf(ray.y)
	return (ARENA_SIZE * 0.5 + ray * minf(reach_x, reach_y)) / ARENA_SIZE


func _spawn_enemy(definition: EnemyCombatDefinition, at: Vector2, _index: int = 0) -> BattleEnemy:
	var enemy := BattleEnemy.new()
	var local_id := "enemy_%d" % _enemy_serial
	enemy.id = StringName(local_id if run_state.room_serial == 1 else "page%d:%s" % [run_state.room_serial, local_id])
	_enemy_serial += 1
	_enemy_definitions[enemy.id] = definition
	enemy.kind = definition.kind
	enemy.behavior = definition.behavior
	enemy.speed = definition.speed * ENEMY_SPEED_SCALE
	enemy.boss = definition.boss
	enemy.long_word = definition.long_word
	enemy.stationary = definition.stationary
	enemy.weave = definition.weave
	enemy.charge_speed = definition.charge_speed * ENEMY_SPEED_SCALE
	enemy.aura = definition.aura
	enemy.aura_radius = definition.aura_radius
	enemy.mirror_ready = definition.mirror
	enemy.radius = definition.radius * BattleEnemy.SIZE_SCALE
	enemy.mass = definition.mass
	enemy.word = _take_word(enemy.id, definition.long_word)
	enemy.max_hp_q = roundi(definition.health * _enemy_health_scale * encounter.health_multiplier * Q)
	if definition.boss:
		enemy.max_hp_q = roundi(definition.boss_health[_difficulty_rank] * encounter.health_multiplier * Q)
		enemy.max_hp_q = roundi(enemy.max_hp_q * pow(1.7, _physical_chapter() - 1))
		enemy.max_hp_q = roundi(enemy.max_hp_q * pow(1.18, loop_index))
	enemy.hp_q = enemy.max_hp_q
	enemy.attack_damage_q = roundi(definition.attack_damage * _pressure * Q)
	enemy.attack_interval = definition.attack_interval * ENEMY_ATTACK_SCALE
	enemy.warning_time = definition.warning_time
	if enemy.behavior in [&"snipe", &"refrain", &"ward"]:
		enemy.attack_interval = maxf(2.0, enemy.attack_interval)
	enemy.attack_clock = (2.6 if enemy.boss else (0.72 + _rng.randf() * 0.6) * ENEMY_ATTACK_SCALE)
	if enemy.behavior in [&"snipe", &"refrain", &"ward"]:
		enemy.attack_clock = maxf(enemy.attack_clock, enemy.warning_time + 0.4)
	if enemy.behavior == &"charge":
		enemy.warning_time = 1.12 * ENEMY_ATTACK_SCALE
	for feature in encounter.element_traits:
		if feature.enemy_kind == enemy.kind: feature.apply(enemy)
	# Cold arrivals become word targets only after entering the clear battlefield.
	enemy.approach_direction = encounter.approach_direction(arrival_direction, _rng)
	enemy.ambush = enemy.approach_direction != arrival_direction
	enemy.position = Vector2(0.5, 0.28) if enemy.boss else at
	if enemy.ambush:
		enemy.position = _arrival_position(enemy.approach_direction)
	enemy.previous_position = enemy.position
	enemies.append(enemy)
	_enemies_by_id[enemy.id] = enemy
	return enemy


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
	var started := DebugLog.begin()
	step(delta)
	DebugLog.end(&"battle.step", started)


func step(delta: float) -> void:
	if result != 0:
		return
	elapsed += delta
	for command in _commands:
		if command.build != null:
			if command.build.book() != book_id:
				event_committed.emit({"kind": &"build_rejected", "reason": "主书变化需要页边界"})
				continue
			_install_build(command.build)
		elif command.action == &"assist":
			if command.attempt_id == typing.current_attempt_id() and command.target_id == typing.target_id and command.input_progress == typing.progress:
				if compiled_build.has(&"assist"):
					typing.complete_assisted()
				else:
					event_committed.emit({"kind": &"action_rejected", "action": &"assist", "at": player_position})
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
			manual_characters += 1
			add_resonance(roundi(1.2 * Q))
			if not spirits.is_empty():
				spirit_time = RelicParameters.spirit_duration(compiled_build)
			_progression_dirty = true
			event_committed.emit({"kind": &"manual_input", "at": player_position})
	for attempt in _abandoned:
		has_input_interruption = true
		_progression_dirty = true
		ledger.abandon(attempt)
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
		_publish_progression()
		return
	parry_window = maxf(0.0, parry_window - delta)
	_perfect_reflect_remaining = maxf(0.0, _perfect_reflect_remaining - delta)
	parry_cooldown = maxf(0.0, parry_cooldown - delta)
	dodge_window = maxf(0.0, dodge_window - delta)
	hurt_window = maxf(0.0, hurt_window - delta)
	_dodge_recovery_seconds = MODE_DODGE_CD[_difficulty_rank] * (1.0 - compiled_build.relic_number(&"R009", &"recovery_pct") / 100.0)
	dodge_charges = minf(2.0 + compiled_build.value(&"dodge_capacity"), dodge_charges + delta / _dodge_recovery_seconds)
	dodge_cooldown = maxf(0.0, (1.0 - dodge_charges) * _dodge_recovery_seconds)
	var world_step := world_delta(delta)
	counter_slow_remaining = maxf(0.0, counter_slow_remaining - delta)
	precision_slow_remaining = maxf(0.0, precision_slow_remaining - delta)
	perfect_dodge_remaining = maxf(0.0, perfect_dodge_remaining - delta)
	world_time += world_step
	if intermission < 0.0:
		spirit_time = 8.0 if book_id == &"spirit" and ultimate_time > 0.0 else maxf(0.0, spirit_time - delta)
	previous_player_position = player_position
	if _dodge_time < 0.17:
		_dodge_time = minf(0.17, _dodge_time + delta)
		player_position = _dodge_from.lerp(_dodge_to, 1.0 - pow(1.0 - _dodge_time / 0.17, 3))
		if _dodge_time == 0.17:
			runtime.on_dodge_landed(player_position)
			event_committed.emit({"kind": &"dodge_end", "at": player_position})
	else:
		player_position = clamp_player(player_position + player_impulse * world_step / ARENA_SIZE)
		player_impulse *= exp(-world_step * 9.0)
	var stage_started := DebugLog.begin()
	runtime.advance(world_step)
	_advance_ultimates(world_step)
	_advance_effects(world_step)
	DebugLog.end(&"battle.spells", stage_started)
	stage_started = DebugLog.begin()
	_advance_enemy_motion(world_step)
	_resolve_bodies()
	DebugLog.end(&"battle.motion_collision", stage_started)
	stage_started = DebugLog.begin()
	_advance_projectiles(world_step)
	_advance_blades(world_step)
	_advance_enemies(world_step)
	_advance_threats(world_step)
	_advance_hazards(world_step)
	_advance_pickups(world_step)
	_advance_encounter(world_step)
	DebugLog.end(&"battle.attacks_encounter", stage_started)
	if god_mode: _fill_god_resources()
	if player_hp_q <= 0 and compiled_build.has(&"revive"):
		for asset in compiled_build.asset_instances():
			if asset.content_id == &"R024" and run_state.claim_asset(asset.usage_key(), &"revive"):
				@warning_ignore("integer_division")
				player_hp_q = roundi(player_max_hp_q * compiled_build.relic_number(&"R024", &"heal_pct") / 100.0)
				hurt_window = 3.0
				threats.clear()
				hazards.clear()
				runtime.rescue_burst()
				break
	if player_hp_q <= 0:
		_end(false)
	elif not _has_living() and _spawned >= ceili(float(_room_quota * wave) / encounter.wave_count):
		if wave == encounter.wave_count:
			_end(true)
		elif intermission < 0.0:
			intermission = encounter.wave_interval if encounter.room_id == &"" else maxf(1.8, 4.0 - _difficulty_rank * 0.5)
		else:
			intermission = maxf(0.0, intermission - world_step)
			if intermission == 0.0:
				_spawn_wave()
	state_changed.emit()
	_publish_progression()


func _advance_encounter(delta: float) -> void:
	if _room_quota == 0 or intermission >= 0.0: return
	_room_world_time += delta
	_spawn_clock -= delta
	if not encounter.opening_enemies.is_empty() and _spawned == encounter.opening_enemies.size() and _opening_grace > 0.0:
		var opening_alive := 0
		for index in encounter.opening_enemies.size():
			var enemy := enemies[index]
			if not enemy.alive(): continue
			opening_alive += 1
			if not enemy_in_combat(enemy): return
		_opening_grace = maxf(0.0, _opening_grace - delta) if opening_alive > 0 else 0.0
		if _opening_grace > 0.0: return
	var depth := (_physical_chapter() - 1) * 3 + encounter.room_number - 1
	var progress := float(wave - 1) / maxf(1.0, encounter.wave_count - 1)
	_enemy_cap = mini(MODE_ACTIVE_CAP[_difficulty_rank], MODE_CAP[_difficulty_rank] - 2 + floori(depth * 0.65) + floori(progress * 2.0))
	var wave_limit := ceili(float(_room_quota * wave) / encounter.wave_count)
	var alive_count := 0
	for enemy in enemies:
		if enemy.alive(): alive_count += 1
	if alive_count == 0 and _room_world_time > 4.0: _spawn_clock = minf(_spawn_clock, 0.8)
	if _spawn_clock > 0.0 or _spawned >= wave_limit or alive_count >= _enemy_cap: return
	var kind_counts: Dictionary[StringName, int] = {}
	var role_counts: Dictionary[StringName, int] = {}
	for enemy in enemies:
		if enemy.alive():
			kind_counts[enemy.kind] = kind_counts.get(enemy.kind, 0) + 1
			var role: StringName = _enemy_definitions[enemy.id].encounter_role
			role_counts[role] = role_counts.get(role, 0) + 1
	var batch := 1 + (1 if _difficulty_rank >= 2 and wave >= 2 else 0) + (1 if _physical_chapter() >= 2 and _difficulty_rank >= 1 else 0) + (1 if _physical_chapter() >= 3 and _difficulty_rank >= 3 else 0) + (1 if wave == encounter.wave_count and _difficulty_rank >= 3 else 0)
	for index in mini(batch, wave_limit - _spawned):
		if alive_count >= _enemy_cap: break
		var allowed: Array[EnemyCombatDefinition] = []
		for definition in encounter.enemies:
			if kind_counts.get(definition.kind, 0) < definition.spawn_limit and role_counts.get(definition.encounter_role, 0) < encounter.role_limits.get(definition.encounter_role, 99):
				allowed.append(definition)
		if allowed.is_empty(): break
		var definition: EnemyCombatDefinition
		if _spawned < encounter.opening_enemies.size():
			definition = encounter.opening_enemies[_spawned]
			if definition not in allowed: break
		else:
			definition = allowed[_rng.randi_range(0, allowed.size() - 1)]
		_spawn_enemy(definition, _arrival_position(arrival_direction), index)
		alive_count += 1
		kind_counts[definition.kind] = kind_counts.get(definition.kind, 0) + 1
		role_counts[definition.encounter_role] = role_counts.get(definition.encounter_role, 0) + 1
		_spawned += 1
		if _spawned == encounter.opening_enemies.size(): break
	var opening := 1.0 + 0.3 * maxf(0.0, 1.0 - depth / 3.0) * (1.0 - progress)
	_spawn_clock = maxf(0.55, MODE_SPAWN[_difficulty_rank] * opening / (1.0 + depth * (0.025 + _difficulty_rank * 0.004) + progress * 0.12))


func _publish_progression() -> void:
	if _progression_dirty:
		_progression_dirty = false
		progression_changed.emit()


func enemy_by_id(id: StringName) -> BattleEnemy:
	return _enemies_by_id.get(id)


func spirit_blade_count() -> int:
	return spirits.size()


func word_meaning(word: String) -> String:
	return _word_meanings.get(word, "")


func _physical_chapter() -> int:
	return encounter.chapter_number


func _take_word(word_owner: StringName, long_word: bool = false) -> String:
	var upper := mini(_maximum_length, maxi(_shortest_length, _minimum_length + 3 + floori(completed_words / 5.0))) if _progressive else _maximum_length
	var entry := _word_sampler.take(word_owner, _rng, _minimum_length, upper, long_word)
	return entry.word if entry != null else ""


func _retire_word(word_owner: StringName) -> void:
	typing.retire_target(word_owner)
	if typing.target_id == word_owner and typing.progress > 0:
		_retained_word_id = word_owner
	else:
		_word_sampler.release(word_owner)


func _commit_word(completion: WordCompletion) -> void:
	var paid := ledger.claim_word(completion.attempt_id, completion.manual_positions.size())
	if paid.is_empty():
		return
	add_resonance((3 if completion.mistakes == 0 else 2) * Q)
	for pickup in pickups:
		if pickup.id == completion.target_id and pickup.alive():
			pickup.consumed = true
			_retire_word(pickup.id)
			if completion.fully_manual(): _pickup_words += 1
			var cleared := 0
			if pickup.kind == &"rune":
				cleared = reflect_projectiles_in_radius(pickup.position, 520.0)
				interrupt_enemies_in_radius(pickup.position, 520.0)
				add_resonance(5 * Q)
			else:
				for index in range(threats.size() - 1, -1, -1):
					if not threats[index].reflected and ((threats[index].position - pickup.position) * ARENA_SIZE).length() <= 255.0:
						threats.remove_at(index)
						cleared += 1
			runtime.on_pickup_completed(pickup, cleared, completion, paid)
			event_committed.emit({"kind": &"pickup_trigger", "pickup": pickup.kind, "at": pickup.position, "cleared": cleared})
			return
	var target := enemy_by_id(completion.target_id)
	if target == null or not target.alive():
		target = _nearest_living(target.position if target != null else player_position)
	if target == null:
		return
	var power_q: int = paid["power_q"]
	if completion.fully_manual():
		completed_words += 1
	var cast_origin := _player_position()
	var empowered := runtime.next_empowered()
	var word_owner := enemy_by_id(completion.target_id)
	if word_owner != null and word_owner.alive():
		word_owner.word_pending = true
	var primary := runtime.assemble(paid, completion, target, empowered)
	effects.append(primary)
	event_committed.emit({"kind": &"cast", "book": book_id, "at": cast_origin, "target": target.position, "power_q": power_q, "empowered": primary.empowered})
	# The paid primary owns renewal even when its homing target changes later.
	if word_owner != null and word_owner.alive():
		typing.retire_target(word_owner.id)


func add_resonance(amount: int) -> void:
	if ultimate_time > 0.0: return
	var before := resonance_q
	resonance_q = mini(ULTIMATE_COST_Q, resonance_q + roundi(amount * (1.0 + compiled_build.relic_number(&"R040", &"resonance_pct") / 100.0) * RelicParameters.ratio(compiled_build, &"resonance_pct")))
	if before < ULTIMATE_COST_Q and resonance_q == ULTIMATE_COST_Q:
		event_committed.emit({"kind": &"ultimate_ready", "at": player_position})


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
		_word_sampler.release(word_target.id)
		word_target.word = _take_word(word_target.id, word_target.long_word)
	if enemy_in_combat(word_target) and not word_target.word.is_empty():
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
			if effect.kind == &"storm_ultimate_word" or not effect.retargetable:
				runtime.retire(effect)
				continue
			if effect.kind == &"storm_arc" and effect.arc_index > 0:
				target = runtime.arc_target(effect, effect.origin)
			else:
				target = _nearest_living(effect.origin, effect.visited)
		if target == null:
			if effect.kind == &"storm_arc" and effect.arc_index > 0:
				# This scheduled hop never landed; finish at the last real contact.
				runtime.finish_arc(effect, effect.origin, effect.jumps + 1)
			_release_word(effect, false)
			runtime.retire(effect)
			continue
		effect.target_id = target.id
		runtime.dispatch(effect, target)
		if effect.kind in [&"frost_spear", &"frost_fragment", &"frost_ultimate", &"flame_burst", &"flame_splash", &"flame_meteor", &"echo"]:
			var projectile := BattleProjectile.new(effect)
			projectile.speed *= float(Q + effect.build.value(&"flight_speed_q")) / Q
			if effect.kind in [&"frost_spear", &"frost_fragment", &"frost_ultimate"]:
				projectile.speed *= RelicParameters.ratio(effect.build, &"frost_flight_pct")
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
					projectile.homing = false
				else:
					projectile.effect.target_id = target.id
			if projectile.homing:
				var desired := ((target.position - projectile.position) * ARENA_SIZE).angle()
				var turn := 17.0 if str(projectile.effect.kind).begins_with("frost") else 12.0
				projectile.velocity = Vector2.from_angle(lerp_angle(projectile.velocity.angle(), desired, 1.0 - exp(-delta * turn))) * projectile.speed
		projectile.velocity += projectile.attraction_impulse
		projectile.attraction_impulse = Vector2.ZERO
		projectile.position += projectile.velocity * delta / ARENA_SIZE
		projectile.trail.append(projectile.position)
		if projectile.trail.size() > 9:
			projectile.trail.remove_at(0)
		var contacts: Array[Dictionary] = []
		var single_hit := projectile.remaining_hits == 1
		var first_enemy: BattleEnemy = null
		var first_time := INF
		var sweep_from := projectile.previous_position * ARENA_SIZE
		var sweep_to := projectile.position * ARENA_SIZE
		for enemy in enemies:
			if not enemy.alive() or not enemy_in_combat(enemy) or str(enemy.id) in projectile.hit_ids:
				continue
			var time := CombatGeometry.sweep_discs(sweep_from, sweep_to, enemy.previous_position * ARENA_SIZE, enemy.position * ARENA_SIZE, projectile.radius + enemy.radius)
			if time != INF:
				if single_hit:
					if first_enemy == null or time < first_time or (time == first_time and str(enemy.id) < str(first_enemy.id)):
						first_enemy = enemy
						first_time = time
				else:
					contacts.append({"enemy": enemy, "time": time})
		if single_hit:
			if first_enemy != null: contacts.append({"enemy": first_enemy, "time": first_time})
		else:
			contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return a.time < b.time if a.time != b.time else str(a.enemy.id) < str(b.enemy.id)
			)
		for contact in contacts:
			var enemy: BattleEnemy = contact.enemy
			var primary := projectile.hit_ids.is_empty()
			var center := projectile.previous_position.lerp(projectile.position, contact.time)
			var enemy_center := enemy.previous_position.lerp(enemy.position, contact.time)
			var surface := CombatGeometry.contact_point(center * ARENA_SIZE, enemy_center * ARENA_SIZE, projectile.radius, projectile.velocity) / ARENA_SIZE
			projectile.hit_ids.append(str(enemy.id))
			runtime.contact(projectile.effect, enemy, projectile.previous_position, primary, surface)
			if primary: _release_word(projectile.effect, true)
			projectile.remaining_hits -= 1
			if primary:
				projectile.homing = false
			if projectile.remaining_hits <= 0:
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
	_release_word(effect, true)


func _advance_blades(delta: float) -> void:
	var count := spirit_blade_count()
	if spirit_time <= 0.0 and not spirits.is_empty():
		var sleeping: BattleSpirit = spirits.pop_back()
		if sleeping.effect != null: runtime.retire(sleeping.effect)
		spirit_time = 1.0 if not spirits.is_empty() else 0.0
	for index in range(spirits.size() - 1, -1, -1):
		var spirit := spirits[index]
		spirit.previous_position = spirit.position
		spirit.cooldown -= delta
		var orbit := _spirit_orbit(spirit.slot, count)
		var target := enemy_by_id(spirit.target_id)
		if spirit.mode == &"orbit" and spirit.cooldown <= 0.0:
			target = spirit_target(spirit.position)
			if target != null:
				spirit.target_id = target.id
				spirit.effect = runtime.take_spirit_attack(target, spirit.position)
				if spirit.effect != null:
					spirit.damage_q = spirit.effect.lot.amount_q
					spirit.begin(&"dive", target.position)
		if spirit.mode in [&"dive", &"cross"] and not spirit.struck and (target == null or not target.alive()):
			target = _nearest_living(spirit.position)
			if target != null:
				spirit.target_id = target.id
				spirit.begin(spirit.mode, target.position)
			else:
				if spirit.effect != null: runtime.retire(spirit.effect)
				spirit.effect = null
				spirit.damage_q = 0
				spirit.crossing = false
				spirit.begin(&"return", orbit)
		if spirit.mode == &"orbit":
			var phase := world_time * 0.5 + spirit.slot * TAU / maxf(1.0, count)
			var tangent := Vector2(-sin(phase) * 78, cos(phase) * 49.5)
			spirit.velocity = spirit.velocity.lerp((tangent + (orbit - spirit.position) * ARENA_SIZE * 3.0) * SPIRIT_MOVEMENT_SCALE, 1.0 - exp(-delta * 5.0))
			spirit.position += spirit.velocity * delta / ARENA_SIZE
		else:
			if spirit.mode in [&"dive", &"cross"] and not spirit.struck:
				spirit.endpoint = target.position
			elif spirit.mode == &"return":
				spirit.endpoint = orbit
			var flight_scale := (1.0 if spirit.crossing else SPIRIT_MOVEMENT_SCALE) * (1.8 if book_id == &"spirit" and ultimate_time > 0.0 else 1.0) * RelicParameters.ratio(compiled_build, &"spirit_speed_pct")
			spirit.flight_time = minf(spirit.duration, spirit.flight_time + delta * flight_scale)
			spirit.position = spirit.sample(spirit.flight_time / spirit.duration)
			if delta > 0.0:
				spirit.velocity = (spirit.position - spirit.previous_position) * ARENA_SIZE / delta
			if spirit.mode in [&"dive", &"cross"] and not spirit.struck and target != null and target.alive():
				var contact_time := CombatGeometry.sweep_discs(spirit.previous_position * ARENA_SIZE, spirit.position * ARENA_SIZE, target.previous_position * ARENA_SIZE, target.position * ARENA_SIZE, target.radius + 10.0)
				if contact_time != INF:
					var center := spirit.previous_position.lerp(spirit.position, contact_time)
					var target_center := target.previous_position.lerp(target.position, contact_time)
					var contact := CombatGeometry.contact_point(center * ARENA_SIZE, target_center * ARENA_SIZE, 10.0, spirit.velocity) / ARENA_SIZE
					if spirit.effect != null:
						runtime.dispatch(spirit.effect, target)
						runtime.contact(spirit.effect, target, spirit.previous_position, true, contact)
					spirit.damage_q = 0
					spirit.struck = true
					spirit.cooldown = 0.6 if ultimate_time > 0.0 and book_id == &"spirit" else 1.2
					spirit.cooldown *= 1.0 - compiled_build.modifier(&"spirit_cooldown_pct") / 100.0
					if spirit.crossing and compiled_build.asset_stacks(&"R048") > 0: spirit.cooldown = 0.0
					spirit.crossing = false
					spirit.begin(&"return", orbit)
			if spirit.flight_time >= spirit.duration:
				if spirit.mode == &"return":
					spirit.mode = &"orbit"
					spirit.struck = false
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
	var phase := world_time * 0.5 + slot * TAU / maxf(1.0, count)
	return player_position + Vector2(cos(phase) * (156.0 + sin(phase * 2.0) * 19.5), -25.5 + sin(phase) * 99.0 + sin(phase * 2.0 + slot) * 19.5) / ARENA_SIZE


func _summon_spirit() -> void:
	var count := spirit_blade_count()
	var capacity := spirit_capacity()
	if count >= capacity:
		return
	var spirit := BattleSpirit.new()
	spirit.slot = count
	spirit.position = player_position + Vector2(0, -30) / ARENA_SIZE
	spirit.previous_position = spirit.position
	spirit.cooldown = 0.35 + count * 0.15
	spirits.append(spirit)
	event_committed.emit({"kind": &"spirit_summon", "at": spirit.position})


func spirit_capacity() -> int:
	return (SPIRIT_CAPACITY if book_id == &"spirit" else 1) + compiled_build.value(&"summon_capacity") + compiled_build.modifier(&"spirit_capacity")


func spirit_target(origin: Vector2) -> BattleEnemy:
	var chosen: BattleEnemy
	var score := INF
	for enemy in enemies:
		if not enemy.alive() or not enemy_in_combat(enemy): continue
		var candidate := ((enemy.position - origin) * ARENA_SIZE).length() / (1.0 + enemy.vulnerability / 32.0)
		if candidate < score:
			score = candidate
			chosen = enemy
	return chosen


func command_spirit_cross(mark: BattleEffect, target: BattleEnemy) -> void:
	for spirit in spirits:
		if spirit.effect != null: runtime.retire(spirit.effect)
		var lot := ledger.earn(mark.lot.root_id, StringName("cross:%d" % spirit.slot), compiled_build.identity(), SpellLot.Kind.POWER, roundi(mark.base_power_q * 0.18 * (1.0 + compiled_build.relic_number(&"R048", &"cross_pct") / 100.0) * RelicParameters.ratio(compiled_build, &"cross_pct")), &"spirit-cross", DamagePacket.Element.PAPER)
		spirit.effect = runtime._effect(lot, &"spirit_cross", target.id, spirit.position, compiled_build)
		spirit.effect.depth = 1
		spirit.target_id = target.id
		spirit.crossing = true
		spirit.struck = false
		spirit.begin(&"cross", target.position)


func _advance_enemy_motion(delta: float) -> void:
	for enemy in enemies:
		if not enemy.alive():
			continue
		enemy.previous_position = enemy.position
		if enemy.frozen_time <= 0.0:
			enemy.age += delta
		enemy.phase_lock = maxf(0.0, enemy.phase_lock - delta)
		if not enemy.word_pending:
			enemy.word_age += delta
		enemy.hit_flash = maxf(0.0, enemy.hit_flash - delta)
		enemy.squash *= exp(-delta * 15.0)
		enemy.counter_push_time = maxf(0.0, enemy.counter_push_time - delta)
		enemy.stagger_time = maxf(0.0, enemy.stagger_time - delta)
		enemy.front_armor_ready = _enemy_definitions[enemy.id].front_armor and enemy.frozen_time <= 0.0 and enemy.stagger_time <= 0.0
		# Approach into the arena before keeping firing distance. The inner margin
		# prevents unselected enemies from backing across the word visibility edge.
		var entering := not enemy.combat_locked and not in_combat(enemy.position, enemy.radius + 32.0)
		var obscured := runtime.obscures(enemy)
		if not obscured:
			enemy.last_seen_position = player_position
		var approach := enemy.last_seen_position if obscured else player_position
		if entering:
			var inset := Vector2.ONE * (EDGE_WIDTH + enemy.radius + 32.0) / ARENA_SIZE
			approach = approach.clamp(inset, Vector2.ONE - inset)
		var toward := (approach - enemy.position) * ARENA_SIZE
		var distance := toward.length()
		var desired := Vector2.ZERO
		if enemy.frozen_time <= 0.0 and enemy.stagger_time <= 0.0 and not enemy.aiming and enemy.followup_time <= 0.0 and enemy.melee_strike <= 0.0 and enemy.melee_recovery <= 0.0:
			var speed := enemy.speed
			var direction := (1.0 if distance > 82.0 else 0.0) if enemy.behavior in [&"melee", &"charge"] else (1.0 if distance > 385.0 else (-0.6 if distance < 265.0 else 0.0))
			if entering or obscured:
				direction = 1.0 if distance > 4.0 else 0.0
			if distance > 480.0:
				speed = maxf(enemy.speed, 97.5 * ENEMY_SPEED_SCALE)
			desired = toward.normalized() * speed * direction
			if not obscured and (enemy.behavior == &"weave" or enemy.weave):
				desired += toward.normalized().orthogonal() * sin(enemy.age * 2.3) * speed * 0.75
			if enemy.stationary and not entering and not obscured: desired = Vector2.ZERO
			if enemy.boss and not obscured:
				var movement_radius := 270.0 if enemy.kind == &"echo-archivist" else 142.5
				var anchor := Vector2(0.5 + sin(enemy.age * 0.32) * movement_radius / ARENA_SIZE.x, 0.28 + cos(enemy.age * 0.44) * 36.0 / ARENA_SIZE.y)
				desired = (anchor - enemy.position) * ARENA_SIZE * 1.5
		var charging := enemy.charge_time > 0.0 and enemy.frozen_time <= 0.0
		if enemy.stagger_time > 0.0:
			enemy.charge_time = 0.0
			charging = false
		if charging:
			desired = enemy.charge_direction * enemy.charge_speed
		desired *= enemy.cold_move_scale()
		if enemy.local_slow_time > 0.0: desired *= 0.75
		if typing.target_id == enemy.id: desired *= 1.0 - compiled_build.relic_number(&"R018", &"slow_pct") / 100.0
		for source in enemies:
			if source.alive() and source != enemy and source.aura == &"haste" and enemy_in_combat(source) and ((source.position - enemy.position) * ARENA_SIZE).length() <= source.aura_radius:
				desired *= 1.18
				break
		if enemy.frozen_time > 0.0:
			enemy.velocity = Vector2.ZERO
		else:
			enemy.velocity = desired if charging else enemy.velocity.lerp(desired, 1.0 - exp(-delta * 5.0))
		var drag := 2.8 if enemy.counter_push_time > 0.0 else 4.4
		enemy.position += (enemy.velocity * delta + enemy.impulse * (1.0 - exp(-delta * drag)) / drag) / ARENA_SIZE
		enemy.impulse *= exp(-delta * drag)
		_bound_enemy(enemy)
		if charging:
			var hit := CombatGeometry.sweep_discs(enemy.previous_position * ARENA_SIZE, enemy.position * ARENA_SIZE, previous_player_position * ARENA_SIZE, player_position * ARENA_SIZE, enemy.radius + 21.0)
			var attack_id := "%s:%s:charge:%s" % [ledger.room_id, enemy.id, enemy.attack_serial]
			if hit != INF and not _settled_player_attacks.has(attack_id):
				if parry_window > 0.0:
					_settled_player_attacks[attack_id] = true
					_counter_contact(enemy, &"charge")
					event_committed.emit({"kind": &"enemy_attack", "at": player_position, "from": enemy.position, "outcome": &"parry", "grade": _defense_grade(), "damage_q": 0})
				elif dodge_window <= 0.0 and hurt_window <= 0.0:
					_take_player_damage(enemy.attack_damage_q, "%s:%s:charge:%s" % [ledger.room_id, enemy.id, enemy.attack_serial])
					hurt_window = _hurt_iframe
					event_committed.emit({"kind": &"enemy_attack", "at": player_position, "from": enemy.position, "outcome": &"hit", "damage_q": enemy.attack_damage_q})
				enemy.charge_time = 0.0
				enemy.stagger_time = maxf(enemy.stagger_time, 0.6)
			if enemy.charge_time > 0.0:
				# Count travelled charge time so slows affect speed, not its reach.
				enemy.charge_time = maxf(0.0, enemy.charge_time - delta * desired.length() / enemy.charge_speed)
				if enemy.charge_time == 0.0:
					enemy.stagger_time = 0.6


func _advance_enemies(delta: float) -> void:
	# Motion is already committed for this step. Paid hits resolve before attacks.
	for enemy in enemies:
		if not enemy.alive():
			continue
		if not enemy_in_combat(enemy):
			typing.retire_target(enemy.id)
			enemy.word_age = 0.0
			enemy.followup_time = 0.0
			if enemy.ward_remaining > 0.0: _end_ward(enemy)
			if enemy.frozen_time <= 0.0:
				enemy.aiming = false
				enemy.melee_strike = 0.0
				enemy.attack_clock = maxf(enemy.attack_clock, enemy.warning_time + 0.15)
			continue
		if not enemy.word_pending and not typing._targets.has(enemy.id):
			if enemy.word.is_empty(): enemy.word = _take_word(enemy.id, enemy.long_word)
			enemy.word_age = 0.0
			if not enemy.word.is_empty(): typing.upsert_target(enemy.id, enemy.word)
		var distance := ((player_position - enemy.position) * ARENA_SIZE).length()
		if enemy.behavior == &"ward":
			_advance_ward(enemy, delta)
			continue
		if enemy.followup_time > 0.0:
			if enemy.stagger_time > 0.0 or ((enemy.position - enemy.volley_origin) * ARENA_SIZE).length() > 26.0:
				enemy.followup_time = 0.0
			else:
				enemy.followup_time = maxf(0.0, enemy.followup_time - delta * enemy.cold_attack_scale())
				if enemy.followup_time == 0.0: _emit_precision_volley(enemy)
			continue
		if enemy.boss and enemy.frozen_time <= 0.0:
			var phase := 1 if enemy.hp_q > enemy.max_hp_q * 0.67 else (2 if enemy.hp_q > enemy.max_hp_q * 0.34 else 3)
			if phase != enemy.phase:
				enemy.phase = phase
				enemy.attack_clock = minf(enemy.attack_clock, 1.0)
				if phase == 2 and encounter.reinforcement != null:
					_spawn_enemy(encounter.reinforcement, enemy.position + Vector2(0.1, 0.08))
				if phase == 3 and enemy.kind == &"final-editor":
					_spawn_enemy(load("res://game/content/enemies/tower.tres"), Vector2(0.28, 0.28))
					_spawn_enemy(load("res://game/content/enemies/tower.tres"), Vector2(0.72, 0.28))
				event_committed.emit({"kind": &"boss_phase", "enemy": enemy.id, "phase": phase, "at": enemy.position})
		if enemy.boss:
			enemy.shielded = _has_combat_tower()
		if _enemy_definitions[enemy.id].mirror:
			enemy.mirror_clock -= delta
			if enemy.mirror_clock <= 0.0:
				enemy.mirror_ready = true
				enemy.mirror_clock = 6.0
		var attack_delta := delta * enemy.cold_attack_scale()
		if attack_delta > 0.0:
			for index in range(enemy.delayed_attacks.size() - 1, -1, -1):
				var delayed: Dictionary = enemy.delayed_attacks[index]
				delayed["remaining"] -= attack_delta
				if delayed["remaining"] <= 0.0:
					if delayed["pattern"] == &"blast":
						_spawn_blast(enemy, delayed.get("target", enemy.aimed_position), delayed["radius"], delayed["warning"])
					else:
						_emit_pattern(enemy, delayed["pattern"], delayed.get("curve", 0.0), delayed.get("speed", 1.0))
					enemy.delayed_attacks.remove_at(index)
		if enemy.aura == &"pull":
			runtime.pull_environment(enemy.position, enemy.aura_radius, delta * 67.5, false, enemy.id)
			if distance < enemy.aura_radius and dodge_window <= 0.0:
				player_impulse += ((enemy.position - player_position) * ARENA_SIZE).normalized() * delta * 67.5
		if enemy.kind == &"leech" and distance < enemy.radius + 32.0 and dodge_window <= 0.0:
			dodge_charges = maxf(0.0, dodge_charges - delta * 0.4)
		if enemy.behavior == &"melee":
			_advance_melee(enemy, delta, distance)
			continue
		if enemy.frozen_time > 0.0 or enemy.stagger_time > 0.0 or enemy.charge_time > 0.0 or (not enemy.boss and not enemy.aiming and distance > 480.0):
			continue
		if enemy.behavior in [&"snipe", &"refrain"] and (enemy.word.is_empty() or (not enemy.aiming and distance < 180.0)):
			continue
		var needs_aim := enemy.boss or enemy.behavior not in [&"heal", &"brood", &"ring", &"bind"]
		enemy.attack_clock -= attack_delta
		if not enemy.aiming and needs_aim and runtime.obscures(enemy):
			# Finish recovery while hidden, but wait before starting a new telegraph.
			enemy.attack_clock = maxf(enemy.warning_time, enemy.attack_clock)
			continue
		if not enemy.aiming and enemy.attack_clock <= enemy.warning_time:
			enemy.aiming = true
			if enemy.behavior in [&"snipe", &"refrain"]:
				enemy.attack_clock = enemy.warning_time
				enemy.velocity = Vector2.ZERO
			enemy.aimed_position = player_position
			event_committed.emit({"kind": &"warning", "at": enemy.position, "target": enemy.aimed_position, "enemy": enemy.id})
		if enemy.attack_clock <= 0.0:
			_resolve_attack(enemy)
			enemy.attack_clock = (2.5 if enemy.phase == 3 else 3.2) * ENEMY_ATTACK_SCALE if enemy.boss else enemy.attack_interval
			enemy.aiming = false


func _advance_melee(enemy: BattleEnemy, delta: float, distance: float) -> void:
	if enemy.stagger_time > 0.0:
		# Stagger interrupts the attack; freezing only pauses its current progress.
		enemy.aiming = false
		enemy.melee_strike = 0.0
		enemy.attack_clock = maxf(enemy.attack_clock, 0.3)
		return
	if enemy.frozen_time > 0.0:
		return
	var attack_delta := delta * enemy.cold_attack_scale()
	if enemy.melee_recovery > 0.0:
		enemy.melee_recovery = maxf(0.0, enemy.melee_recovery - attack_delta)
		return
	if enemy.melee_strike > 0.0:
		if not enemy.melee_hit:
			_resolve_melee(enemy)
		enemy.melee_strike = maxf(0.0, enemy.melee_strike - attack_delta)
		if enemy.melee_strike == 0.0:
			enemy.melee_recovery = BattleEnemy.MELEE_RECOVERY
		return
	enemy.attack_clock = maxf(0.0, enemy.attack_clock - attack_delta)
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
	elif enemy.attack_clock == 0.0 and distance <= BattleEnemy.MELEE_REACH and not runtime.obscures(enemy):
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
	if enemy.behavior in [&"snipe", &"refrain"]:
		_emit_precision_volley(enemy)
		if enemy.behavior == &"refrain":
			enemy.velocity = Vector2.ZERO
			enemy.volley_origin = enemy.position
			enemy.followup_time = BattleEnemy.REFRAIN_DELAY
		return
	if enemy.behavior == &"charge":
		var path := (enemy.aimed_position - enemy.position) * ARENA_SIZE
		enemy.charge_direction = path.normalized()
		# Cross the locked footprint instead of stopping at a fixed short range.
		enemy.charge_time = (path.length() + enemy.radius + 42.0) / enemy.charge_speed
		return
	if enemy.behavior == &"laser":
		_spawn_laser(enemy)
		return
	if enemy.behavior == &"bombard":
		_spawn_blast(enemy, enemy.aimed_position, 123.0, 1.5)
		return
	if enemy.behavior == &"heal":
		var allies := _living().filter(func(other: BattleEnemy) -> bool: return other != enemy and ((other.position - enemy.position) * ARENA_SIZE).length() <= 450.0)
		allies.sort_custom(func(a: BattleEnemy, b: BattleEnemy) -> bool: return float(a.hp_q) / a.max_hp_q < float(b.hp_q) / b.max_hp_q)
		for index in mini(3, allies.size()):
			var ally: BattleEnemy = allies[index]
			ally.hp_q = mini(ally.max_hp_q, ally.hp_q + (12 + (_physical_chapter() - 1) * 4) * Q)
			event_committed.emit({"kind": &"enemy_heal", "from": enemy.position, "at": ally.position})
		return
	if enemy.behavior == &"brood":
		if enemy.spawn_count < 5 and _living().size() < _enemy_cap:
			var kind := &"wisp" if enemy.spawn_count % 2 else &"leech"
			var child := _spawn_enemy(load("res://game/content/enemies/%s.tres" % kind), enemy.position + Vector2(0.025, 0.04))
			_make_small(child)
			enemy.spawn_count += 1
		_emit_pattern(enemy, &"fan")
		return
	if enemy.behavior == &"vortex":
		_spawn_blast(enemy, enemy.aimed_position, 138.0, 1.4)
		_emit_pattern(enemy, &"ring", 0.28)
		return
	if enemy.behavior in [&"ring", &"bind", &"curve"]:
		_emit_pattern(enemy, &"single" if enemy.behavior == &"curve" else &"ring", 0.32 if enemy.behavior == &"curve" else (-0.15 if enemy.behavior == &"bind" else 0.0))
		return
	if enemy.boss:
		_emit_pattern(enemy, &"ring", 0.23 if enemy.kind == &"echo-archivist" else (0.14 * (1 if enemy.attack_serial % 2 else -1) if enemy.kind == &"final-editor" else 0.0))
		if enemy.kind in [&"echo-archivist", &"final-editor"] or enemy.phase == 3 and enemy.attack_serial % 2 == 0:
			_spawn_laser(enemy)
		if enemy.phase >= 2:
			if enemy.kind == &"echo-archivist":
				enemy.delayed_attacks.append({"remaining": 0.3, "pattern": &"fan", "curve": 0.22})
				enemy.delayed_attacks.append({"remaining": 0.6, "pattern": &"fan", "curve": -0.22})
			elif enemy.kind == &"final-editor":
				enemy.delayed_attacks.append({"remaining": 0.5, "pattern": &"blast", "radius": 142.5, "warning": 1.15, "target": enemy.aimed_position})
				if enemy.phase == 3: enemy.delayed_attacks.append({"remaining": 0.42, "pattern": &"ring", "speed": 0.83})
			else:
				enemy.delayed_attacks.append({"remaining": 0.32, "pattern": &"fan"})
				_spawn_blast(enemy, enemy.aimed_position, 135.0, 1.25)
			var guards := _living().filter(func(other: BattleEnemy) -> bool: return not other.boss)
			if guards.size() < 2 + _difficulty_rank and encounter.reinforcement != null:
				_spawn_enemy(encounter.reinforcement, enemy.position + Vector2(0.1 if enemy.attack_serial % 2 == 0 else -0.1, 0.08))
		event_committed.emit({"kind": &"enemy_shot", "at": enemy.position, "target": enemy.aimed_position})
		return
	if enemy.kind != &"nib":
		_emit_pattern(enemy, &"fan")
		return


func _emit_precision_volley(enemy: BattleEnemy) -> void:
	var offset := (enemy.aimed_position - enemy.position) * ARENA_SIZE
	var needle := enemy.behavior == &"snipe"
	# A displaced muzzle must not create a point-blank projectile at the marked spot.
	if offset.length() < 90.0: return
	var speed := minf((440.0 if needle else 205.0) * ENEMY_SPEED_SCALE, (offset.length() - 28.0) / 0.65)
	for lane in (1 if needle else 2):
		var angle := offset.angle() + (0.0 if needle else (float(lane) - 0.5) * 0.12)
		_emit_enemy_threat(enemy, angle, lane, speed, 6.75)
		threats[-1].visual_style = &"needle" if needle else &"refrain"
		threats[-1].life = maxf(6.0, offset.length() / speed + 0.5)
	event_committed.emit({"kind": &"enemy_shot", "at": enemy.position, "target": enemy.aimed_position})


func _advance_ward(enemy: BattleEnemy, delta: float) -> void:
	if enemy.ward_remaining > 0.0:
		if ward_target(enemy) == null:
			_end_ward(enemy)
		else:
			enemy.ward_remaining = maxf(0.0, enemy.ward_remaining - delta)
			if enemy.ward_remaining == 0.0: _end_ward(enemy)
		return
	if enemy.frozen_time > 0.0 or enemy.stagger_time > 0.0 or enemy.word.is_empty():
		enemy.aiming = false
		return
	enemy.attack_clock -= delta * enemy.cold_attack_scale()
	enemy.aiming = enemy.attack_clock <= enemy.warning_time
	if enemy.attack_clock > 0.0: return
	var selected: BattleEnemy
	var closest := BattleEnemy.WARD_RANGE
	for ally in enemies:
		if not ally.alive() or not enemy_in_combat(ally) or ally.boss or ally.behavior == &"ward" or ally.kind == &"tower" or ally.word.is_empty() or is_warded(ally): continue
		var distance := ((ally.position - enemy.position) * ARENA_SIZE).length()
		if distance < closest:
			closest = distance
			selected = ally
	enemy.aiming = false
	enemy.attack_clock = enemy.attack_interval
	if selected != null:
		enemy.ward_target_id = selected.id
		enemy.ward_remaining = BattleEnemy.WARD_DURATION
		selected.ward_source_id = enemy.id
		event_committed.emit({"kind": &"enemy_ward", "enemy": enemy.id, "target": selected.id, "at": selected.position})


func ward_target(source: BattleEnemy) -> BattleEnemy:
	# Current state is read at damage time, including control applied earlier this step.
	if not source.alive() or source.ward_remaining <= 0.0 or source.frozen_time > 0.0 or source.stagger_time > 0.0 or not enemy_in_combat(source): return null
	var target := enemy_by_id(source.ward_target_id)
	if target == null or not target.alive() or not enemy_in_combat(target): return null
	if ((target.position - source.position) * ARENA_SIZE).length() > BattleEnemy.WARD_RANGE: return null
	return target


func is_warded(enemy: BattleEnemy) -> bool:
	var source := enemy_by_id(enemy.ward_source_id)
	return source != null and ward_target(source) == enemy


func _end_ward(source: BattleEnemy) -> void:
	var target := enemy_by_id(source.ward_target_id)
	if target != null and target.ward_source_id == source.id: target.ward_source_id = &""
	source.ward_target_id = &""
	source.ward_remaining = 0.0


func _emit_enemy_threat(enemy: BattleEnemy, angle: float, lane: int, speed: float, radius: float) -> void:
	var threat := BattleThreat.new()
	threat.source_id = enemy.id
	match enemy.kind:
		&"quill", &"sentinel": threat.visual_style = &"quill"
		&"wisp": threat.visual_style = &"wisp"
		&"binder", &"echo-archivist": threat.visual_style = &"rune"
		&"vortex": threat.visual_style = &"vortex"
		&"mirror", &"scribe", &"tower", &"final-editor": threat.visual_style = &"shard"
	_attack_serial += 1
	threat.attack_id = "%s:%s:%s:%s:%s" % [ledger.room_id, enemy.id, enemy.attack_serial, lane, _attack_serial]
	threat.position = enemy.position
	threat.previous_position = enemy.position
	threat.velocity = Vector2.from_angle(angle) * speed
	threat.damage_q = enemy.attack_damage_q
	threat.radius = radius
	threats.append(threat)


func _emit_pattern(enemy: BattleEnemy, pattern: StringName, curve: float = 0.0, speed_scale: float = 1.0) -> void:
	var count := 10 + (_physical_chapter() - 1) * 3 + _difficulty_rank if pattern == &"ring" else (1 if pattern == &"single" else 3 + mini(3, _physical_chapter() - 1 + floori(_difficulty_rank / 2.0)))
	var gap := _rng.randi_range(0, count - 1)
	var aim := ((enemy.aimed_position - enemy.position) * ARENA_SIZE).angle()
	for index in count:
		if pattern == &"ring" and index in [gap, (gap + 1) % count]: continue
		var angle := index * TAU / count + enemy.age * 0.14 if pattern == &"ring" else aim + (index - (count - 1) * 0.5) * 0.145
		_emit_enemy_threat(enemy, angle, enemy.attack_serial * 100 + threats.size(), 83.0 * 1.5 * ENEMY_SPEED_SCALE * speed_scale, 6.0)
		threats[-1].curvature = curve
		threats[-1].acceleration = 0.12 if pattern == &"single" and curve != 0.0 else 0.0
		if curve != 0.0 and pattern != &"ring":
			var threat := threats[-1]
			var target_offset := (enemy.aimed_position - enemy.position) * ARENA_SIZE
			var arrival := threat.aim_curve(target_offset)
			var arena := Rect2(Vector2.ZERO, ARENA_SIZE)
			var bounds := threat.flight_bounds(arrival)
			bounds.position += enemy.position * ARENA_SIZE
			if not arena.encloses(bounds):
				# Prefer the inward bend; narrow it only when both sides lack room.
				threat.curvature = -threat.curvature
				arrival = threat.aim_curve(target_offset)
				bounds = threat.flight_bounds(arrival)
				bounds.position += enemy.position * ARENA_SIZE
				while not arena.encloses(bounds):
					threat.curvature *= 0.5
					arrival = threat.aim_curve(target_offset)
					bounds = threat.flight_bounds(arrival)
					bounds.position += enemy.position * ARENA_SIZE
			threats[-1].velocity = threats[-1].velocity.rotated(angle - aim)
		threats[-1].heavy = enemy.kind == &"ink-colossus" and enemy.phase == 3 and pattern == &"ring"
		threats[-1].radius = 10.5 if threats[-1].heavy else 6.75
		threats[-1].damage_q = roundi((16 if threats[-1].heavy else 11) * _pressure * Q)
	event_committed.emit({"kind": &"enemy_shot", "at": enemy.position, "target": enemy.aimed_position})
	if pattern == &"ring": spawn_pickup(&"rune", enemy)


func _make_small(enemy: BattleEnemy) -> void:
	enemy.small = true
	enemy.radius *= 0.73
	enemy.mass *= 0.55
	enemy.max_hp_q = roundi(enemy.max_hp_q * 0.57)
	enemy.hp_q = enemy.max_hp_q
	enemy.speed *= 1.18


func _spawn_blast(enemy: BattleEnemy, center: Vector2, radius: float, warning: float) -> void:
	var hazard := BattleHazard.new()
	hazard.kind = &"blast"
	hazard.source_id = enemy.id
	_attack_serial += 1
	hazard.attack_id = "%s:%s:blast:%s:%s" % [ledger.room_id, enemy.id, enemy.attack_serial, _attack_serial]
	hazard.center = center
	hazard.origin = center
	hazard.radius = radius
	hazard.warning_remaining = warning
	hazard.warning_total = warning
	hazard.active_remaining = 0.2
	hazard.ring = enemy.kind not in [&"ink-colossus", &"vortex"]
	hazard.damage_q = roundi(23 * _pressure * Q)
	hazards.append(hazard)
	event_committed.emit({"kind": &"hazard_warning", "at": center, "source": enemy.id})


func _spawn_laser(enemy: BattleEnemy) -> void:
	var hazard := BattleHazard.new()
	hazard.kind = &"laser"
	hazard.source_id = enemy.id
	_attack_serial += 1
	hazard.attack_id = "%s:%s:laser:%s:%s" % [ledger.room_id, enemy.id, enemy.attack_serial, _attack_serial]
	var vertical := _rng.randf() < 0.5
	hazard.origin = Vector2(enemy.aimed_position.x, 0.0) if vertical else Vector2(0.0, enemy.aimed_position.y)
	hazard.end = Vector2(enemy.aimed_position.x, 1.0) if vertical else Vector2(1.0, enemy.aimed_position.y)
	hazard.center = (hazard.origin + hazard.end) * 0.5
	hazard.width = 30.0 if enemy.boss else 19.5
	hazard.warning_remaining = 1.8
	hazard.warning_total = 1.8
	hazard.damage_q = roundi(23 * _pressure * Q)
	hazards.append(hazard)
	spawn_pickup(&"rune", enemy)
	if enemy.boss and _physical_chapter() > 1:
		var cross := BattleHazard.new()
		cross.kind = &"laser"
		cross.source_id = enemy.id
		cross.attack_id = hazard.attack_id + ":cross"
		var cross_position := clamp_player(enemy.aimed_position + Vector2(232.5 / ARENA_SIZE.x, -150.0 / ARENA_SIZE.y))
		cross.origin = Vector2(0.0, cross_position.y) if vertical else Vector2(cross_position.x, 0.0)
		cross.end = Vector2(1.0, cross_position.y) if vertical else Vector2(cross_position.x, 1.0)
		cross.center = (cross.origin + cross.end) * 0.5
		cross.width = 22.5
		cross.warning_remaining = 2.2
		cross.warning_total = 2.2
		cross.active_remaining = 0.42
		cross.damage_q = hazard.damage_q
		hazards.append(cross)
	event_committed.emit({"kind": &"hazard_warning", "at": hazard.center, "source": enemy.id})


func spawn_pickup(kind: StringName, source: BattleEnemy = null) -> BattlePickup:
	if pickups.filter(func(item: BattlePickup) -> bool: return item.alive()).size() >= 3: return null
	_pickup_serial += 1
	var pickup := BattlePickup.new()
	pickup.id = StringName("pickup_%s" % _pickup_serial)
	pickup.kind = kind
	pickup.word = _take_word(pickup.id)
	if pickup.word.is_empty(): return null
	pickup.life = 15.0 if kind == &"rune" else 24.0
	pickup.position = Vector2(_rng.randf_range(0.2, 0.8), _rng.randf_range(0.25, 0.75))
	if source != null:
		pickup.source_id = source.id
		pickup.position = (source.position + player_position) * 0.5 + Vector2(_rng.randf_range(-0.025, 0.025), 0.0)
	pickup.position = clamp_player(pickup.position)
	pickups.append(pickup)
	typing.upsert_target(pickup.id, pickup.word)
	event_committed.emit({"kind": &"pickup_spawn", "pickup": kind, "at": pickup.position})
	return pickup


func _advance_pickups(delta: float) -> void:
	for index in range(pickups.size() - 1, -1, -1):
		var pickup := pickups[index]
		pickup.age += delta
		if not pickup.alive():
			_retire_word(pickup.id)
			pickups.remove_at(index)
	_pickup_clock -= delta
	if _pickup_clock <= 0.0:
		spawn_pickup(&"rune" if _rng.randf() < 0.65 else &"ink")
		_pickup_clock = _rng.randf_range(10.0, 14.0)


func _advance_hazards(delta: float) -> void:
	for index in range(hazards.size() - 1, -1, -1):
		var hazard := hazards[index]
		var source := enemy_by_id(hazard.source_id)
		if source == null or not source.alive() or not enemy_in_combat(source):
			hazards.remove_at(index)
			continue
		if hazard.warning_remaining > 0.0:
			hazard.warning_remaining = maxf(0.0, hazard.warning_remaining - delta)
			continue
		if not hazard.fired:
			hazard.fired = true
			event_committed.emit({"kind": &"hazard_active", "at": hazard.center, "hazard": hazard.kind, "radius": hazard.radius})
			if hazard.ring:
				for lane in 10:
					_emit_enemy_threat(source, lane * TAU / 10.0, 1000 + lane, 142.5 * ENEMY_SPEED_SCALE, 6.0)
					threats[-1].position = hazard.center
					threats[-1].previous_position = hazard.center
		hazard.active_remaining = maxf(0.0, hazard.active_remaining - delta)
		if hazard.contains(player_position) and not _settled_player_attacks.has(hazard.attack_id):
			if dodge_window <= 0.0 and hurt_window <= 0.0:
				_take_player_damage(hazard.damage_q, hazard.attack_id)
				hurt_window = _hurt_iframe
				event_committed.emit({"kind": &"enemy_attack", "at": player_position, "from": hazard.center, "outcome": &"hit", "damage_q": hazard.damage_q})
		if hazard.active_remaining == 0.0: hazards.remove_at(index)


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
			hurt_window = _hurt_iframe
			player_impulse = ((player_position - enemy.position) * ARENA_SIZE).normalized() * 210.0
	if outcome != &"miss":
		event_committed.emit({"kind": &"enemy_attack", "at": player_position, "from": strike_origin, "outcome": outcome, "grade": _defense_grade() if outcome == &"parry" else &"", "damage_q": enemy.attack_damage_q if outcome == &"hit" else 0})


func _advance_threats(delta: float) -> void:
	_advancing_threats = true
	for index in range(threats.size() - 1, -1, -1):
		var threat := threats[index]
		if threat.cleared: continue
		threat.previous_position = threat.position
		threat.position += BattleThreat.flight_displacement(threat.velocity, threat.curvature, threat.acceleration, delta) / ARENA_SIZE
		threat.velocity = BattleThreat.flight_velocity(threat.velocity, threat.curvature, threat.acceleration, delta)
		threat.life -= delta
		if ((threat.position - player_position) * ARENA_SIZE).length() <= 75.0 and dodge_window > 0.0: runtime.graze(threat)
		# Display history follows distance, so slow straight shots retain a full tail.
		if threat.trail.is_empty(): threat.trail.append(threat.previous_position)
		if ((threat.position - threat.trail[-1]) * ARENA_SIZE).length() >= (6.0 if threat.curvature != 0.0 else 4.0):
			threat.trail.append(threat.position)
		if threat.trail.size() > 32:
			threat.trail.remove_at(0)
		if threat.reflected:
			var hit: BattleEnemy
			var closest := INF
			for enemy in enemies:
				if not enemy.alive() or not enemy_in_combat(enemy):
					continue
				var time := CombatGeometry.sweep_discs(threat.previous_position * ARENA_SIZE, threat.position * ARENA_SIZE, enemy.previous_position * ARENA_SIZE, enemy.position * ARENA_SIZE, threat.radius + enemy.radius)
				if time < closest:
					hit = enemy
					closest = time
			if hit != null:
				threat.position = threat.previous_position.lerp(threat.position, closest)
				var target_at := hit.previous_position.lerp(hit.position, closest)
				var contact := CombatGeometry.contact_point(threat.position * ARENA_SIZE, target_at * ARENA_SIZE, threat.radius, threat.velocity) / ARENA_SIZE
				if threat.effect != null:
					runtime.contact(threat.effect, hit, threat.previous_position, true, contact)
					runtime.counter_contact(hit)
			if hit != null or threat.life <= 0.0:
				threats.remove_at(index)
			continue
		if runtime.intercept_crane(threat):
			threats.remove_at(index)
			continue
		if compiled_build.asset_stacks(&"R049") > 0:
			var intercepted := false
			for spirit in spirits:
				if spirit.mode == &"orbit": continue
				if CombatGeometry.sweep_discs(threat.previous_position * ARENA_SIZE, threat.position * ARENA_SIZE, spirit.previous_position * ARENA_SIZE, spirit.position * ARENA_SIZE, threat.radius + 18.0) != INF:
					intercepted = true
					event_committed.emit({"kind": &"spirit_intercept", "at": spirit.position})
					break
			if intercepted:
				threats.remove_at(index)
				continue
		var contact_time := CombatGeometry.sweep_discs(threat.previous_position * ARENA_SIZE, threat.position * ARENA_SIZE, previous_player_position * ARENA_SIZE, player_position * ARENA_SIZE, threat.radius + 21.0)
		var predicted_contact := parry_window > 0.0 and _threat_will_hit_player(threat, minf(DEFENSE_PREDICTION, parry_window))
		if (contact_time != INF or predicted_contact) and (parry_window > 0.0 or (dodge_window <= 0.0 and hurt_window <= 0.0)):
			if contact_time != INF:
				threat.position = threat.previous_position.lerp(threat.position, contact_time)
			var outcome: StringName = &"hit"
			var grade: StringName = &""
			if parry_window > 0.0:
				outcome = &"parry"
				grade = _defense_grade()
				if grade == &"perfect": _reflect_threat(threat)
				_parry_feedback(threat.source_id, grade)
			else:
				_take_player_damage(threat.damage_q, threat.attack_id)
				hurt_window = _hurt_iframe
				player_impulse = threat.velocity.normalized() * 165.0
			event_committed.emit({"kind": &"enemy_attack", "at": player_position, "from": threat.position, "outcome": outcome, "grade": grade, "damage_q": threat.damage_q if outcome == &"hit" else 0})
			if not threat.reflected:
				threats.remove_at(index)
		elif threat.life <= 0.0 or not Rect2(Vector2(-0.05, -0.05), Vector2(1.1, 1.1)).has_point(threat.position):
			threats.remove_at(index)
	_advancing_threats = false
	_flush_cleared_threats()


func _flush_cleared_threats() -> void:
	var write_index := 0
	for read_index in threats.size():
		var threat := threats[read_index]
		if threat.cleared: continue
		threats[write_index] = threat
		write_index += 1
	threats.resize(write_index)


func _commit_action(action: StringName) -> void:
	if action == &"abandon":
		abandoned_run = true
		_end(false)
		return
	if action == &"parry":
		if parry_cooldown <= 0.0 and _dodge_time >= 0.17:
			parry_window = DEFENSE_WINDOW
			_perfect_reflect_remaining = 0.0
			parry_cooldown = RelicParameters.parry_cooldown(compiled_build)
			_parry_succeeded = false
			event_committed.emit({"kind": &"parry_start", "at": _player_position()})
		else:
			event_committed.emit({"kind": &"action_rejected", "action": action, "at": player_position})
		return
	if action == &"ultimate":
		if (god_mode or (ultimate_time <= 0.0 and resonance_q >= ULTIMATE_COST_Q)) and _nearest_living(player_position) != null:
			resonance_q = ULTIMATE_COST_Q if god_mode else resonance_q - ULTIMATE_COST_Q
			_commit_ultimate()
		else:
			event_committed.emit({"kind": &"action_rejected", "action": action, "at": player_position})
		return
	if not str(action).begins_with("dodge"):
		return
	if (not god_mode and dodge_charges < 1.0) or _dodge_time < 0.17:
		event_committed.emit({"kind": &"action_rejected", "action": action, "at": player_position})
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
		event_committed.emit({"kind": &"action_rejected", "action": action, "at": player_position})
		return
	var perfect_source := _imminent_dodge_source() if dodge_window <= 0.0 and hurt_window <= 0.0 else &""
	_dodge_from = player_position
	_dodge_to = destination
	_dodge_time = 0.0
	player_impulse = Vector2.ZERO
	dodge_window = 1.0
	dodge_charges = 2.0 + compiled_build.value(&"dodge_capacity") if god_mode else dodge_charges - 1.0
	runtime.on_dodge(_dodge_from, destination)
	parry_window = 0.0
	_perfect_reflect_remaining = 0.0
	event_committed.emit({"kind": &"dodge", "at": player_position, "target": destination})
	if perfect_source != &"":
		perfect_dodge_remaining = dodge_window
		add_resonance(5 * Q)
		event_committed.emit({"kind": &"perfect_dodge", "at": player_position, "until": dodge_window, "source": perfect_source})


func world_delta(real_delta: float) -> float:
	## Read-only conversion for render consumers; only step consumes slow timers.
	assert(real_delta >= 0.0)
	if result != 0 or real_delta == 0.0: return 0.0
	if counter_slow_remaining <= 0.0 and precision_slow_remaining <= 0.0 and perfect_dodge_remaining <= 0.0: return real_delta
	var age := 0.52 - counter_slow_remaining
	var precision_duration := minf(real_delta, maxf(precision_slow_remaining, perfect_dodge_remaining))
	# Integrate the pointwise minimum, splitting at recovery's crossing and
	# precision expiry. Taking min of whole integrals depends on step size.
	var counter_duration := minf(precision_duration, maxf(0.0, COUNTER_PRECISION_CROSSOVER - age))
	return (_counter_time_integral(age + counter_duration) - _counter_time_integral(age)
		+ (precision_duration - counter_duration) * 0.1
		+ _counter_time_integral(age + real_delta) - _counter_time_integral(age + precision_duration))


static func _counter_time_integral(time: float) -> float:
	var recovery := clampf((time - 0.06) / 0.46, 0.0, 1.0)
	return 0.06 * minf(time, 0.52) + 0.94 * 0.46 * (pow(recovery, 3.0) - pow(recovery, 4.0) * 0.5) + maxf(0.0, time - 0.52)


func _defense_grade() -> StringName:
	return &"perfect" if _perfect_reflect_remaining > 0.0 or parry_window >= DEFENSE_WINDOW - PERFECT_DEFENSE_WINDOW else &"success"


func _threat_will_hit_player(threat: BattleThreat, horizon: float) -> bool:
	# Predict the real collision disc, never a larger interception radius.
	horizon = minf(horizon, threat.life)
	var at := threat.position * ARENA_SIZE
	var velocity := threat.velocity
	var player_at := player_position * ARENA_SIZE
	var step_time := horizon / 3.0
	for index in 3:
		var next := at + BattleThreat.flight_displacement(velocity, threat.curvature, threat.acceleration, step_time)
		velocity = BattleThreat.flight_velocity(velocity, threat.curvature, threat.acceleration, step_time)
		var player_next := clamp_player(player_position + player_impulse * step_time * (index + 1) / ARENA_SIZE) * ARENA_SIZE
		if CombatGeometry.sweep_discs(at, next, player_at, player_next, threat.radius + 21.0) != INF:
			return true
		at = next
		player_at = player_next
	return false


func _imminent_dodge_source() -> StringName:
	# The timing window is real time; trajectories advance by the current world clock.
	var horizon := world_delta(PERFECT_DODGE_WINDOW)
	for threat in threats:
		if not threat.reflected and _threat_will_hit_player(threat, horizon): return threat.source_id
	for enemy in enemies:
		if not enemy.alive() or not enemy_in_combat(enemy) or enemy.frozen_time > 0.0 or enemy.stagger_time > 0.0: continue
		if enemy.charge_time > 0.0:
			var from := enemy.position * ARENA_SIZE
			var to := from + enemy.charge_direction * enemy.charge_speed * enemy.cold_move_scale() * minf(horizon, enemy.charge_time)
			if CombatGeometry.sweep_discs(from, to, player_position * ARENA_SIZE, player_position * ARENA_SIZE, enemy.radius + 21.0) != INF: return enemy.id
		elif enemy.behavior == &"melee" and ((enemy.melee_strike > 0.0 and not enemy.melee_hit) or (enemy.aiming and enemy.attack_clock <= horizon * enemy.cold_attack_scale())):
			var offset := (player_position - enemy.melee_origin) * ARENA_SIZE
			if CombatGeometry.disc_in_sector(offset, 21.0, enemy.melee_direction, BattleEnemy.MELEE_REACH, BattleEnemy.MELEE_HALF_ANGLE): return enemy.id
	for hazard in hazards:
		var source := enemy_by_id(hazard.source_id)
		if source != null and source.alive() and enemy_in_combat(source) and not _settled_player_attacks.has(hazard.attack_id) and hazard.active_remaining > 0.0 and hazard.warning_remaining <= horizon:
			var predicted := clamp_player(player_position + player_impulse * horizon / ARENA_SIZE)
			if hazard.intersects_motion(player_position, predicted): return hazard.source_id
	return &""


func _reflect_threat(threat: BattleThreat) -> void:
	var source := enemy_by_id(threat.source_id)
	var direction := ((source.position - threat.position) * ARENA_SIZE).normalized() if source != null and source.alive() else -threat.velocity.normalized()
	threat.velocity = direction * maxf(540.0, threat.velocity.length() * 1.6)
	threat.reflected = true
	threat.curvature = 0.0
	threat.acceleration = 0.0
	threat.effect = runtime.counter(threat.attack_id, roundi(32 * Q * (1.25 if threat.heavy else 1.0)), threat.source_id, threat.position)
	threat.damage_q = threat.effect.lot.amount_q if threat.effect != null else 0
	threat.life = 3.0
	threat.trail.clear()


func reflect_projectiles_in_radius(origin: Vector2, radius: float) -> int:
	var reflected := 0
	for threat in threats:
		if not threat.reflected and ((threat.position - origin) * ARENA_SIZE).length() <= radius:
			_reflect_threat(threat)
			reflected += 1
	return reflected


func interrupt_enemies_in_radius(origin: Vector2, radius: float) -> void:
	for enemy in _living():
		if ((enemy.position - origin) * ARENA_SIZE).length() <= radius:
			_interrupt_enemy(enemy)


func _interrupt_enemy(enemy: BattleEnemy) -> void:
	# Bosses use the same cancellation contract; no saved volleys on recovery.
	enemy.aiming = false
	enemy.charge_time = 0.0
	enemy.melee_strike = 0.0
	enemy.delayed_attacks.clear()
	enemy.followup_time = 0.0
	if enemy.ward_remaining > 0.0: _end_ward(enemy)
	enemy.stagger_time = maxf(enemy.stagger_time, 0.4 if enemy.boss else 0.85)
	enemy.attack_clock = maxf(enemy.attack_clock, enemy.warning_time + 0.4)
	enemy.velocity = Vector2.ZERO
	for index in range(hazards.size() - 1, -1, -1):
		if hazards[index].source_id == enemy.id and hazards[index].warning_remaining > 0.0:
			hazards.remove_at(index)


func _parry_feedback(source_id: StringName, grade: StringName = &"perfect") -> void:
	if _parry_succeeded:
		return
	_parry_succeeded = true
	add_resonance(3 * Q)
	var perfect := grade == &"perfect"
	if perfect:
		# Start once on success; later hits cannot refresh the reflection window.
		runtime.add_shield(compiled_build.modifier(&"parry_shield") * Q)
		add_resonance(compiled_build.modifier(&"parry_resonance") * Q)
		_perfect_reflect_remaining = PERFECT_REFLECT_WINDOW
		parry_window = maxf(parry_window, PERFECT_REFLECT_WINDOW)
		counter_slow_remaining = 0.52
	# The pulse follows a defended hit; it never widens attack interception.
	for enemy in _living():
		var offset := (enemy.position - player_position) * ARENA_SIZE
		if offset.length() > 160.0:
			continue
		var direct := enemy.id == source_id
		var direction := offset.normalized() if not offset.is_zero_approx() else Vector2.UP
		var impulse := direction * (3300.0 if direct else 1575.0) * (1.0 - 0.25 * offset.length() / 278.0) / sqrt(enemy.mass)
		enemy.impulse = impulse if perfect else enemy.impulse + impulse * 0.15
		enemy.counter_push_time = maxf(enemy.counter_push_time, 1.2)
		if perfect:
			enemy.velocity = Vector2.ZERO
			enemy.aiming = false
			enemy.charge_time = 0.0
			enemy.melee_strike = 0.0
			enemy.delayed_attacks.clear()
			enemy.followup_time = 0.0
			if enemy.ward_remaining > 0.0: _end_ward(enemy)
			enemy.stagger_time = maxf(enemy.stagger_time, 1.2 if direct else 0.7)
			enemy.attack_clock = maxf(enemy.attack_clock, 1.4)
	for threat in threats:
		if threat.reflected:
			continue
		var offset := (threat.position - player_position) * ARENA_SIZE
		if offset.length() > 160.0:
			continue
		var direction := offset.normalized() if not offset.is_zero_approx() else -threat.velocity.normalized()
		# A radial velocity impulse changes flight, never allegiance or target.
		threat.velocity += direction * 1575.0 * (1.0 - 0.25 * offset.length() / 278.0) * (1.0 if perfect else 0.15)
	event_committed.emit({"kind": &"counter_pulse", "at": player_position, "source": source_id, "grade": grade})


func _separate_player(enemy: BattleEnemy) -> void:
	var offset := (enemy.position - player_position) * ARENA_SIZE
	if offset.length() >= enemy.radius + 25.0:
		return
	var direction := offset.normalized() if not offset.is_zero_approx() else Vector2.UP
	enemy.position = player_position + direction * (enemy.radius + 25.0) / ARENA_SIZE


func _counter_contact(enemy: BattleEnemy, attack_kind: StringName = &"melee") -> void:
	var grade := _defense_grade()
	_parry_feedback(enemy.id, grade)
	if grade == &"success" and attack_kind == &"charge":
		var direction := enemy.charge_direction
		player_impulse += direction * 300.0
		enemy.impulse = -direction * 900.0 / sqrt(enemy.mass)
		enemy.velocity = Vector2.ZERO
		enemy.charge_time = 0.0
	if grade == &"perfect":
		_separate_player(enemy)
		_interrupt_enemy(enemy)
		var attack_id := "%s:%s:%s:%s" % [ledger.room_id, enemy.id, attack_kind, enemy.attack_serial]
		var counter := runtime.counter(attack_id, 32 * Q, enemy.id, player_position)
		if counter != null:
			runtime.contact(counter, enemy, player_position)
			runtime.counter_contact(enemy)


func _bound_enemy(enemy: BattleEnemy) -> void:
	var bounded := enemy.position.clamp(Vector2(0.025, 0.04), Vector2(0.975, 0.94))
	if bounded != enemy.position and enemy.charge_time > 0.0:
		enemy.charge_time = 0.0
		enemy.stagger_time = 0.85
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
	# Baseline MovementSystem.findSafe: predict once, score 24 bounded candidates.
	# The 1.4s horizon includes the end of the 1s dodge protection.
	const HORIZON := 1.4
	const PREDICTION_STEP := 0.1
	var enemy_paths: Array[Dictionary] = []
	for enemy in enemies:
		if not enemy.alive(): continue
		var origin := enemy.position * ARENA_SIZE
		var velocity := enemy.velocity
		var delay := maxf(enemy.frozen_time, enemy.stagger_time)
		var duration := maxf(0.0, HORIZON - delay)
		if enemy.charge_time > 0.0:
			velocity = enemy.charge_direction * enemy.charge_speed
			duration = minf(duration, enemy.charge_time)
		elif enemy.aiming and enemy.behavior == &"charge":
			velocity = ((enemy.aimed_position - enemy.position) * ARENA_SIZE).normalized() * enemy.charge_speed
			duration = maxf(0.0, HORIZON - maxf(delay, enemy.attack_clock))
			duration = minf(duration, (((enemy.aimed_position - enemy.position) * ARENA_SIZE).length() + enemy.radius + 42.0) / enemy.charge_speed)
		var endpoint := (origin + velocity * duration + enemy.impulse * 0.12).clamp(Vector2(48.0, 43.2), ARENA_SIZE * Vector2(0.975, 0.94))
		enemy_paths.append({"enemy": enemy, "origin": origin, "endpoint": endpoint, "travel_end": origin + velocity * 0.17})
	var travel_factors: Array[Vector2] = []
	for tick in 14:
		var time := tick * PREDICTION_STEP
		if time < 0.17:
			travel_factors.append(Vector2(1.0 - pow(1.0 - time / 0.17, 3.0), 1.0 - pow(1.0 - minf(0.17, time + PREDICTION_STEP) / 0.17, 3.0)))
	_dodge_points.resize(threats.size() * 15)
	_dodge_starts.resize(threats.size())
	_dodge_segments.resize(threats.size())
	_dodge_radii.resize(threats.size())
	var point_count := 0
	var trajectory_count := 0
	for threat in threats:
		if threat.reflected: continue
		var segments := mini(14, ceili(threat.life / PREDICTION_STEP))
		_dodge_starts[trajectory_count] = point_count
		_dodge_segments[trajectory_count] = segments
		_dodge_radii[trajectory_count] = threat.radius + 21.0 + 12.0
		_dodge_points[point_count] = threat.position * ARENA_SIZE
		point_count += 1
		var velocity := threat.velocity
		for tick in segments:
			_dodge_points[point_count] = _dodge_points[point_count - 1] + BattleThreat.flight_displacement(velocity, threat.curvature, threat.acceleration, PREDICTION_STEP)
			velocity = BattleThreat.flight_velocity(velocity, threat.curvature, threat.acceleration, PREDICTION_STEP)
			point_count += 1
		trajectory_count += 1
	var from := player_position * ARENA_SIZE
	var center := ARENA_SIZE * 0.5
	var from_center_distance := from.distance_to(center)
	var relevant_hazards: Array[BattleHazard] = []
	for hazard in hazards:
		if hazard.warning_remaining <= HORIZON and hazard.warning_remaining + hazard.active_remaining > 0.17:
			relevant_hazards.append(hazard)
	var tail_stride := relevant_hazards.size() + 2
	_dodge_tails.resize(24 * tail_stride)
	_dodge_tails.fill(0.0)
	for index in 24:
		var direction := _dodge_directions[index]
		var at := clamp_player(player_position + direction * 240.0 / ARENA_SIZE)
		var point := at * ARENA_SIZE
		var edge_clearance := minf(minf(point.x, ARENA_SIZE.x - point.x), minf(point.y, ARENA_SIZE.y - point.y))
		var edge_penalty := pow(maxf(0.0, EDGE_WIDTH + 60.0 - edge_clearance), 2.0) * 0.08
		var center_distance := point.distance_to(center)
		var center_penalty := center_distance * 0.12 + maxf(0.0, center_distance - from_center_distance) * 0.7
		var tail_count := 0
		var fixed_penalty := edge_penalty + center_penalty
		for hazard in relevant_hazards:
			if hazard.clearance(at) < 20.0:
				var penalty := 1900.0 if hazard.kind == &"blast" else 1800.0
				_dodge_tails[index * tail_stride + tail_count] = penalty
				tail_count += 1
				fixed_penalty += penalty
		var score := maxf(0.0, 210.0 - from.distance_to(point)) * 5.0
		for path in enemy_paths:
			var enemy: BattleEnemy = path.enemy
			var origin: Vector2 = path.origin
			var nearest := Geometry2D.get_closest_point_to_segment(point, origin, path.endpoint)
			var clearance := point.distance_to(nearest) - enemy.radius - 21.0
			score += 5000.0 / maxf(10.0, clearance) + (1400.0 if clearance < 18.0 else 0.0)
			# Avoid a crowded travel corridor even while the dodge itself is protected.
			if CombatGeometry.sweep_discs(from, point, origin, path.travel_end, enemy.radius + 21.0) != INF:
				score += 180.0
			if enemy.behavior == &"melee" and (enemy.aiming or enemy.melee_strike > 0.0):
				if CombatGeometry.disc_in_sector((at - enemy.melee_origin) * ARENA_SIZE, 21.0, enemy.melee_direction, BattleEnemy.MELEE_REACH, BattleEnemy.MELEE_HALF_ANGLE):
					score += 500.0
		_dodge_candidates[index] = point
		_dodge_scores[index] = score
		_dodge_fixed[index] = fixed_penalty
		_dodge_tails[index * tail_stride + tail_count] = edge_penalty
		_dodge_tails[index * tail_stride + tail_count + 1] = center_penalty
		for tick in travel_factors.size():
			var factors := travel_factors[tick]
			_dodge_travel[index * 4 + tick * 2] = from.lerp(point, factors.x)
			_dodge_travel[index * 4 + tick * 2 + 1] = from.lerp(point, factors.y)
	var chosen: int = _dodge_scorer.Choose(_dodge_points, _dodge_starts, _dodge_segments, _dodge_radii, trajectory_count, _dodge_candidates, _dodge_travel, _dodge_scores, _dodge_fixed, _dodge_tails, tail_stride)
	return _dodge_directions[chosen]


func _commit_ultimate() -> void:
	var living: Array[BattleEnemy] = _living().filter(func(enemy: BattleEnemy) -> bool: return enemy_in_combat(enemy))
	var target := enemy_by_id(typing.target_id)
	if target == null or not target.alive() or not enemy_in_combat(target):
		target = _nearest_living(player_position)
	var center := player_position
	var ultimate := BattleUltimate.new(book_id, center)
	ultimate.effect = runtime.ultimate(target)
	ultimate.duration = RelicParameters.ultimate_duration(compiled_build)
	if book_id == &"frost": runtime.add_shield(20 * Q)
	if book_id == &"frost" and compiled_build.asset_stacks(&"R045") > 0:
		runtime.add_shield(roundi(Q * compiled_build.relic_number(&"R045", &"shield")))
	runtime.add_shield(compiled_build.modifier(&"ultimate_shield") * Q)
	ultimate.lifetime = maxf(ultimate.lifetime, ultimate.duration)
	ultimate.pulses_left += compiled_build.value(&"ultimate_pulses")
	ultimates.append(ultimate)
	ultimate_time = ultimate.duration
	hurt_window = maxf(hurt_window, 0.65)
	runtime.clear_ultimate_threats(ultimate.effect, player_position)
	event_committed.emit({"kind": &"ultimate", "book": book_id, "at": _player_position(), "center": center, "radius": ultimate.radius, "duration": ultimate.duration})
	for enemy in living:
		if ((enemy.position - center) * ARENA_SIZE).length() <= ultimate.radius:
			# Knockback does not cancel locked attacks; hazards already placed remain.
			var direction := ((enemy.position - center) * ARENA_SIZE).normalized()
			enemy.impulse += direction * (120.0 if enemy.boss else 500.0) / enemy.mass
		if book_id == &"flame":
			runtime._deal(enemy, roundi(60 * Q * runtime.damage_multiplier() * RelicParameters.ratio(compiled_build, &"flame_wave_pct")), &"flame_wave", center, 1, ultimate.effect.lot.root_id)
	if book_id == &"spirit":
		spirit_time = 8.0
		for blade in SPIRIT_CAPACITY: _summon_spirit()


func in_frost_field(at: Vector2) -> bool:
	for ultimate in ultimates:
		if ultimate.book == &"frost" and ultimate.contains(at):
			return true
	if runtime != null:
		for field in runtime.fields:
			if field.effect.kind == &"cold_field" and field.contains(at): return true
	return false


func _advance_ultimates(delta: float) -> void:
	ultimate_time = maxf(0.0, ultimate_time-delta)
	for index in range(ultimates.size()-1,-1,-1):
		var ultimate := ultimates[index]
		var active_delta := minf(delta, maxf(0.0, ultimate.duration-ultimate.age))
		ultimate.age += delta
		ultimate.pulse_clock -= active_delta
		while active_delta > 0.0 and ultimate.pulse_clock <= 0.0:
			ultimate.pulse_clock += 0.25 if ultimate.book == &"frost" and compiled_build.asset_stacks(&"R045") > 0 else 0.5
			var targets := runtime._nearby(ultimate.center, ultimate.radius)
			for enemy in targets:
				match ultimate.book:
					&"frost": runtime._apply_cold(enemy, (18 + compiled_build.modifier(&"ultimate_cold")) * Q, compiled_build)
					&"storm": runtime.add_shock(enemy, 18 + compiled_build.modifier(&"storm_domain_shock"))
					&"flame":
						runtime.add_burn(enemy, 15, ultimate.effect.lot.root_id, 1)
						runtime._deal(enemy, roundi(12 * Q * runtime.damage_multiplier() * RelicParameters.ratio(compiled_build, &"flame_domain_pct")), &"flame_domain", ultimate.center, 1, ultimate.effect.lot.root_id)
			if ultimate.book == &"frost" and not targets.is_empty():
				var target: BattleEnemy = targets[_rng.randi_range(0, targets.size() - 1)]
				var origin := target.position + Vector2.from_angle(_rng.randf() * TAU) * 240.0 / ARENA_SIZE
				var lot := ledger.earn(ultimate.effect.lot.root_id, StringName(runtime._tx("ice-domain")), compiled_build.identity(), SpellLot.Kind.POWER, roundi(36 * Q * runtime.damage_multiplier() * RelicParameters.ratio(compiled_build, &"frost_domain_pct")), &"ice-domain", DamagePacket.Element.ICE)
				var spear := runtime._effect(lot, &"frost_ultimate", target.id, origin, compiled_build)
				spear.manual_count = 3
				spear.depth = 1
				runtime.configure_frost_hits(spear, 2)
				effects.append(spear)
		if ultimate.age >= ultimate.lifetime:
			runtime.retire(ultimate.effect)
			ultimates.remove_at(index)


func _player_position() -> Vector2:
	return player_position


func commit_damage(enemy: BattleEnemy, damage_q: int, raw_q: int, source: StringName, origin: Vector2, empowered: bool = false, contact: Vector2 = Vector2.INF, direct: bool = false) -> void:
	if damage_q <= 0 or not enemy.alive() or not enemy_in_combat(enemy):
		return
	enemy.combat_locked = true
	damage_q = roundi(damage_q * (1.0 + 2.0 * enemy.vulnerability / 127.0))
	if enemy.boss:
		enemy.shielded = _has_combat_tower()
		if enemy.shielded: damage_q = roundi(damage_q * 0.45)
		if enemy.phase_lock > 0.0: damage_q = roundi(damage_q * 0.12)
		var floor_ratio := 0.665 if enemy.phase == 1 else (0.335 if enemy.phase == 2 else 0.0)
		var floor_q := roundi(enemy.max_hp_q * floor_ratio)
		if floor_q > 0 and enemy.hp_q - damage_q < floor_q:
			damage_q = maxi(0, enemy.hp_q - floor_q)
			enemy.phase_lock = 0.55
	if enemy.mirror_ready and enemy.frozen_time <= 0.0 and direct:
		damage_q = roundi(damage_q * 0.55)
		enemy.mirror_ready = false
		_emit_pattern(enemy, &"fan")
	enemy.front_armor_ready = _enemy_definitions[enemy.id].front_armor and enemy.frozen_time <= 0.0 and enemy.stagger_time <= 0.0
	if enemy.front_armor_ready and direct:
		var attack_side := ((origin - enemy.position) * ARENA_SIZE).normalized()
		var front := ((player_position - enemy.position) * ARENA_SIZE).normalized()
		if attack_side.dot(front) > 0.2: damage_q = roundi(damage_q * 0.7)
	if is_warded(enemy): damage_q = roundi(damage_q * BattleEnemy.WARD_DAMAGE_SCALE)
	var applied_q := mini(enemy.hp_q, damage_q)
	enemy.hp_q = maxi(0, enemy.hp_q - damage_q)
	var direction := ((enemy.position - origin) * ARENA_SIZE).normalized()
	if source not in [&"flame_burn", &"flame_domain", &"spirit_mark"]:
		enemy.hit_flash = 0.12
		enemy.squash = minf(0.36, enemy.squash + 0.19)
		enemy.impulse += direction * minf(550.0, 180.0 + sqrt(float(damage_q) / Q) * 35.0) / enemy.mass
	event_committed.emit({"kind": &"impact", "source": source, "from": origin, "at": enemy.position, "contact": enemy.position if contact == Vector2.INF else contact, "direction": direction, "enemy": enemy.id, "damage_q": damage_q, "applied_q": applied_q, "overkill_q": damage_q - applied_q, "raw_q": raw_q, "resistance": damage_q < raw_q, "weakness": damage_q > raw_q, "empowered": empowered})
	if not enemy.alive():
		enemy.aiming = false
		enemy.followup_time = 0.0
		if enemy.ward_remaining > 0.0: _end_ward(enemy)
		if enemy.marked_time > 0.0 and compiled_build.asset_stacks(&"R049") > 0:
			add_resonance(roundi(Q * compiled_build.relic_number(&"R049", &"resonance")))
		runtime.on_enemy_death(enemy, source, 0)
		var death_definition: EnemyCombatDefinition = _enemy_definitions[enemy.id]
		if death_definition.death_spawn_kind != &"" and not enemy.small:
			for side in [-1, 1]:
				if _living().size() >= _enemy_cap: break
				var child := _spawn_enemy(load("res://game/content/enemies/%s.tres" % death_definition.death_spawn_kind), enemy.position + Vector2(side * 0.025, 0.01))
				_make_small(child)
		if death_definition.death_pull:
			runtime.pull_environment(enemy.position, 367.5, 705.0, true, enemy.id)
			for other in _living():
				var offset := (enemy.position - other.position) * ARENA_SIZE
				if offset.length() < 367.5:
					other.impulse += offset.normalized() * 705.0
					if offset.length() < 232.5: commit_damage(other, 35 * Q, 35 * Q, &"vortex_death", enemy.position)
		var definition := _enemy_definitions[enemy.id]
		var fact_id := JSON.stringify([run_id, ledger.room_id, attempt_id, str(enemy.id)])
		reward_facts.append(RewardFact.new(fact_id, definition.experience, chapter, compiled_build.asset_stacks(&"R021") > 0))
		_progression_dirty = true
		_retire_word(enemy.id)
		event_committed.emit({"kind": &"death", "at": enemy.position, "enemy": enemy.id})


func _has_living() -> bool:
	for enemy in enemies:
		if enemy.alive(): return true
	return false


func _has_combat_tower() -> bool:
	for enemy in enemies:
		if enemy.kind == &"tower" and enemy.alive() and enemy_in_combat(enemy): return true
	return false


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
	if not victory:
		effects.clear()
		projectiles.clear()
		threats.clear()
		hazards.clear()
		spirits.clear()
		ultimates.clear()
	for pickup in pickups: typing.retire_target(pickup.id)
	pickups.clear()
	_word_sampler.selected.clear()
	_word_sampler.used = 0
	_retained_word_id = &""
	finished.emit(victory)


func finish_room(reason: StringName) -> RoomCombatResult:
	if room_result != null: return room_result
	if reason != &"victory":
		for effect in effects: runtime.retire(effect)
		for projectile in projectiles: runtime.retire(projectile.effect)
		for spirit in spirits:
			if spirit.effect != null: runtime.retire(spirit.effect)
	room_result = runtime.finish(reason, reason == &"victory")
	room_result.manual_characters = manual_characters
	room_result.manual_words = completed_words + _pickup_words
	room_result.elapsed = elapsed
	if statistics != null: room_result.statistics = statistics.snapshot()
	for fact in reward_facts:
		room_result.reward_facts.append(RewardFact.new(fact.fact_id, fact.base_experience, fact.chapter, fact.r021_active))
	room_result.facts = {"has_created_redeemable_mark": has_created_redeemable_mark, "has_input_interruption": has_input_interruption, "has_same_root_lots": has_same_root_lots}
	return room_result


func capture_flight() -> Dictionary:
	# Only value/ref-counted flight state crosses a page; no previous scene survives.
	var world_state: Dictionary = {}
	for property: String in ["effects", "projectiles", "threats", "hazards", "spirits", "spirit_time", "ultimates", "ultimate_time", "world_time", "player_position", "_settled_player_attacks"]:
		var value: Variant = get(property)
		world_state[property] = value.duplicate() if value is Array or value is Dictionary else value
	var runtime_state: Dictionary = {}
	for property: String in ["clock", "_serial", "ongoing", "fields", "spirit_attacks", "_spirit_letters"]:
		var value: Variant = runtime.get(property)
		runtime_state[property] = value.duplicate() if value is Array or value is Dictionary else value
	return {"ledger": ledger, "world": world_state, "runtime": runtime_state}


func _take_player_damage(amount: int, attack_id: String) -> void:
	if _settled_player_attacks.has(attack_id): return
	_settled_player_attacks[attack_id] = true
	var shield := mini(run_state.shield_q, amount)
	run_state.shield_q -= shield
	amount -= shield
	amount = roundi(amount * (1.0 + compiled_build.relic_number(&"R019", &"damage_pct") / 100.0))
	amount = roundi(amount * (1.0 - compiled_build.modifier(&"defense_pct") / 100.0))
	amount = roundi(amount * (1.0 + compiled_build.relic_number(&"R043", &"incoming_pct") / 100.0))
	@warning_ignore("integer_division")
	amount = amount * (Q + compiled_build.value(&"incoming_bonus_q")) / Q
	player_hp_q = maxi(0, player_hp_q - amount)
	if amount > 0: runtime.on_player_hurt()
	if god_mode and player_hp_q <= 0:
		player_hp_q = player_max_hp_q
		event_committed.emit({"kind": &"god_recovery", "at": player_position})
