class_name SpellRuntime
extends RefCounted
## Annotated integer divisions truncate paid shares; ceiling fees and split remainders stay explicit.
## Rules operate on paid lots. BattleSession supplies the world and fixed clock.

const Q := SpellResourceLedger.Q
const STORM_HEAD_SCALE := 0.6
const BURN_INTERVAL := 0.15
const COLD_GRACE := 1.0
const COLD_DECAY := 6.0
const ELEMENTS := {&"frost": DamagePacket.Element.ICE, &"flame": DamagePacket.Element.FIRE, &"storm": DamagePacket.Element.LIGHTNING, &"spirit": DamagePacket.Element.PAPER}
const KINDS := {&"frost": &"frost_spear", &"flame": &"flame_burst", &"storm": &"storm_arc", &"spirit": &"spirit_mark"}
var ledger: SpellResourceLedger
var build: CompiledBuild
var run: RunCombatState
var world: BattleSession
var ongoing: Array[OngoingSpell] = []
var fields: Array[SpellField] = []
var spirit_attacks: Array[BattleEffect] = []
var work_bank: Array[SpellLot] = []
var actual_damage_q: int = 0
var overkill_damage_q: int = 0
var unused_power_q: int = 0
var healed_q: int = 0
var guarded_damage_q: int = 0
var guarded_hits: int = 0
var freezes: int = 0
var damage_by_source: Dictionary[StringName, int] = {}
var kills_by_source: Dictionary[StringName, int] = {}
var clock: float = 0.0
var _serial: int = 0
var _enemy_attacks: Dictionary[String, bool] = {}
var _cast_count: int = 0
var _book_cast_count: int = 0
var _combo: int = 0
var _perfect_words: int = 0
var _manual_words: int = 0
var _assist_tokens: int = 0
var _reflection_boost: bool = false
var _settled_deaths: Dictionary[StringName, bool] = {}
var _pending_death_depth: Dictionary[StringName, int] = {}
var _conduct_counts: Dictionary[StringName, int] = {}
var _collision_times: Dictionary[String, float] = {}
var _spirit_letters: int = 0
var _length_class: int = 0
var _dodge_script_ready: bool = false
var _last_manual_target: StringName
var _introduced_targets: Dictionary[StringName, bool] = {}
var _raw_spent_start: int = 0


func _init(session: BattleSession, combat_build: CompiledBuild, state: RunCombatState) -> void:
	world = session
	build = combat_build
	run = state
	ledger = session.ledger
	_raw_spent_start = ledger.raw_spent_q
	_cast_count = int(state.relic_counters.get("casts", 0))
	_book_cast_count = int(state.relic_counters.get("book", 0))
	_combo = int(state.relic_counters.get("combo", 0))
	_perfect_words = int(state.relic_counters.get("perfect", 0))
	_manual_words = int(state.relic_counters.get("manual", 0))
	_assist_tokens = int(state.relic_counters.get("assist", 0))
	_reflection_boost = int(state.relic_counters.get("boost", 0)) > 0
	_length_class = int(state.relic_counters.get("length_class", 0))
	_dodge_script_ready = int(state.relic_counters.get("dodge_script", 0)) > 0


func install(next_build: CompiledBuild) -> void:
	build = next_build


func assemble(paid: Dictionary, fact: WordCompletion, target: BattleEnemy, empowered: bool) -> BattleEffect:
	_book_cast_count += 1
	_record_word(fact)
	var dodge_script := fact.fully_manual() and _dodge_script_ready and build.asset_stacks(&"T009") > 0
	if fact.fully_manual():
		var length_class := 1 if fact.word.length() <= 4 else (2 if fact.word.length() >= 7 else 0)
		if build.asset_stacks(&"G006") > 0 and length_class > 0 and _length_class > 0 and length_class != _length_class:
			empowered = true
			add_shield(roundi(Q * build.relic_number(&"G006", &"shield")))
		_length_class = length_class
	else:
		_length_class = 0
	if dodge_script:
		empowered = true
		_dodge_script_ready = false
	var multiplier := damage_multiplier() * (1.0 + mini(10, _combo) * (build.relic_number(&"R030", &"step_pct") / 100.0 if build.asset_stacks(&"R030") > 0 else 0.025))
	var word_bonus := build.modifier(&"empowered_pct") if empowered else 0
	word_bonus += build.modifier(&"perfect_pct") if fact.mistakes == 0 else build.modifier(&"imperfect_pct")
	if fact.fully_manual(): word_bonus += build.modifier(&"manual_pct")
	if fact.word.length() <= 4: word_bonus += build.modifier(&"short_pct")
	if fact.word.length() >= 7: word_bonus += build.modifier(&"long_pct")
	word_bonus += mini(10, _combo) * build.modifier(&"combo_pct")
	multiplier *= 1.0 + clampi(word_bonus, -50, 70) / 100.0
	var book_bonus: StringName = {&"frost": &"ice_direct_pct", &"flame": &"flame_direct_pct", &"storm": &"storm_direct_pct", &"spirit": &"power_pct"}[build.book()]
	if build.book() != &"spirit": multiplier *= RelicParameters.ratio(build, book_bonus)
	if fact.mistakes == 0: multiplier *= 1.08 + build.relic_number(&"R016", &"damage_pct") / 100.0
	if fact.word.length() <= 4 and build.asset_stacks(&"R014") > 0:
		multiplier *= 1.0 + build.relic_number(&"R014", &"damage_pct") / 100.0
		world.dodge_charges = minf(2.0 + build.value(&"dodge_capacity"), world.dodge_charges + 0.1)
	if fact.word.length() >= 7 and build.asset_stacks(&"R015") > 0:
		multiplier *= 1.0 + build.relic_number(&"R015", &"damage_pct") / 100.0
		clear_radius(target.position, 105.0, &"R015")
	if build.asset_stacks(&"R022") > 0 and _cast_count % roundi(build.relic_number(&"R022", &"interval")) == 0: multiplier *= 2.0
	if _reflection_boost:
		multiplier *= 2.0
		_reflection_boost = false
	var root := fact.attempt_id
	var base_power := int(fact.manual_positions.size() * build.value(&"base_power_q", 12 * Q) * multiplier)
	var coefficient: float = {&"spirit": 0.1, &"flame": 0.5, &"frost": 1.05 if empowered else 0.7, &"storm": STORM_HEAD_SCALE}[build.book()]
	var power := ledger.earn(root, build.book(), build.identity(), SpellLot.Kind.POWER, roundi(base_power * coefficient), &"assembly", ELEMENTS[build.book()])
	var effect := _effect(power, KINDS[build.book()], target.id, world.player_position, build)
	effect.base_power_q = base_power
	effect.manual_count = fact.manual_positions.size()
	effect.manual_cast = fact.fully_manual()
	effect.bonus_shock = roundi(build.relic_number(&"T009", &"shock")) if dodge_script else 0
	if effect.manual_cast and build.asset_stacks(&"F009") > 0:
		for field in fields:
			if field.effect.kind == &"ice_mist" and field.expires_at > clock:
				effect.mist_cast = true
				break
	effect.empowered = empowered or (build.book() == &"storm" and world.ultimate_time > 0.0)
	effect.word_owner = fact.target_id
	work_bank.append(ledger.earn(root, build.book(), build.identity(), SpellLot.Kind.WORK, int(paid.work_q), &"active-completion"))
	if build.book() == &"spirit" or build.asset_stacks(&"R005") > 0 or build.asset_stacks(&"R035") > 0:
		world.spirit_focus = target.id
		_spirit_letters += fact.manual_positions.size()
		while _spirit_letters >= 5:
			_spirit_letters -= 5
			world._summon_spirit()
		world.spirit_time = RelicParameters.spirit_duration(build)
	_after_cast(fact)
	if build.asset_stacks(&"R054") > 0 and empowered and build.book() == &"flame": add_shield(roundi(Q * build.relic_number(&"R054", &"shield")))
	dispatch(effect, target)
	_configure_shape(effect)
	if build.asset_stacks(&"R006") > 0 and _cast_count % roundi(build.relic_number(&"R006", &"interval")) == 0: _periodic_copy(effect)
	if fact.fully_manual():
		if build.asset_stacks(&"G016") > 0 and _last_manual_target != &"" and _last_manual_target != target.id:
			var previous := world.enemy_by_id(_last_manual_target)
			_copy_to(effect, previous if previous != null and previous.alive() and BattleSession.enemy_in_combat(previous) else target)
		_last_manual_target = target.id
		if build.asset_stacks(&"P010") > 0: _crane_followup(target)
		if build.asset_stacks(&"P007") > 0 and fact.word.length() >= 7:
			_region(target.position, build.relic_number(&"P007", &"radius") + build.modifier(&"crane_radius"), build.relic_number(&"P007", &"duration") + RelicParameters.seconds(build, &"crane_ms"), &"paper_crane")
	_save_counters()
	return effect


func dispatch(effect: BattleEffect, target: BattleEnemy) -> void:
	if effect.dispatched: return
	effect.dispatched = true
	if effect.empowered and effect.kind == &"spirit_mark":
		world.command_spirit_cross(effect, target)


func contact(effect: BattleEffect, target: BattleEnemy, origin: Vector2, primary: bool = true, contact_at: Vector2 = Vector2.INF) -> void:
	if effect.lot == null or effect.lot.amount_q <= 0 or not target.alive() or effect.expires_at <= clock: return
	if effect.kind == &"storm_arc" and effect.arc_index == 0: effect.arc_anchor = target.id
	var direct := primary and (effect.word_owner != &"" or effect.kind in [&"frost_spear", &"flame_burst", &"spirit_mark"])
	var relic_hit := _prepare_relic_hit(effect, target) if direct and effect.manual_cast and effect.depth == 0 else {}
	var amount := effect.lot.amount_q
	if effect.primary_share_q > 0:
		amount = effect.primary_share_q
	var base_amount := amount
	var factor := 1.0
	var hit_bonus := 0
	if target.hp_q == target.max_hp_q: hit_bonus += effect.build.modifier(&"fresh_pct")
	if target.hp_q < target.max_hp_q * 0.5: hit_bonus += effect.build.modifier(&"wounded_pct")
	if target.boss: hit_bonus += effect.build.modifier(&"boss_pct")
	if target.frozen_time > 0.0: hit_bonus += effect.build.modifier(&"frozen_pct")
	if target.shock > 30: hit_bonus += effect.build.modifier(&"shocked_pct")
	if target.burn > 10: hit_bonus += effect.build.modifier(&"burning_pct")
	var status_count := int(target.cold > 0) + int(target.burn > 10) + int(target.shock > 0) + int(target.vulnerability > 0)
	if status_count >= 2: hit_bonus += effect.build.modifier(&"mixed_pct")
	if effect.kind in [&"storm_arc", &"storm_chain"]:
		if target.cold > 30: hit_bonus += effect.build.modifier(&"cold_chain_pct")
		if target.burn > 10: hit_bonus += effect.build.modifier(&"burn_chain_pct")
	if effect.kind in [&"spirit_blade", &"spirit_cross"]:
		if target.cold > 30: hit_bonus += effect.build.modifier(&"cold_spirit_pct")
		if target.burn > 10: hit_bonus += effect.build.modifier(&"burn_spirit_pct")
		if world.ultimate_time > 0.0: hit_bonus += effect.build.modifier(&"ultimate_spirit_pct")
	factor *= 1.0 + mini(70, hit_bonus) / 100.0
	if effect.kind in [&"spirit_blade", &"spirit_cross"] and world.book_id == &"spirit" and world.ultimate_time > 0.0:
		factor *= 1.5
	if effect.kind == &"storm_arc" and target.shock > 30:
		target.shock -= 10
		effect.jumps += 1
		effect.arc_charge += 0.25 * RelicParameters.ratio(effect.build, &"charge_pct")
		add_shield(effect.build.modifier(&"charged_shield") * Q)
	if effect.kind == &"storm_arc":
		factor *= effect.arc_charge
	if target.frozen_time > 0.0:
		factor *= 1.18 + effect.build.relic_number(&"R031", &"damage_pct") / 100.0
		if effect.empowered and effect.kind == &"frost_spear": factor *= 1.25
	if target.boss: factor *= 1.0 + effect.build.relic_number(&"R027", &"boss_pct") / 100.0
	if factor > 1.0:
		var bonus := ledger.earn(effect.lot.root_id, StringName(_tx("hit-relic")), effect.build.identity(), SpellLot.Kind.POWER, int(amount * (factor - 1.0)), &"hit", ELEMENTS[effect.build.book()])
		ledger.aggregate(_tx("hit-join"), effect.lot, bonus)
		amount = int(amount * factor)
	if effect.kind in [&"frost_spear", &"frost_fragment", &"frost_ultimate"]:
		_apply_cold(target, (roundi((55.0 if effect.empowered else 35.0) * effect.manual_count / 5.0) + roundi(effect.build.relic_number(&"R003", &"ice_cold"))) * Q, effect.build)
	elif effect.build.asset_stacks(&"R003") > 0:
		_apply_cold(target, roundi(Q * effect.build.relic_number(&"R003", &"cold")), effect.build)
	if direct:
		if effect.bonus_shock > 0:
			add_shock(target, effect.bonus_shock, effect.build)
			effect.bonus_shock = 0
		_apply_cold(target, (effect.build.modifier(&"cold_hit") + (effect.build.modifier(&"empowered_cold") if effect.empowered else 0)) * Q, effect.build)
		if effect.build.modifier(&"burn_hit") > 0: add_burn(target, effect.build.modifier(&"burn_hit"), effect.lot.root_id, effect.depth, effect.build)
		if effect.build.modifier(&"shock_hit") > 0: add_shock(target, effect.build.modifier(&"shock_hit"), effect.build)
		if effect.build.modifier(&"cross_mark_hit") > 0:
			add_mark(target, effect.build.modifier(&"cross_mark_hit"), roundi(effect.build.relic_number(&"G026", &"mark_limit")), effect.build)
		if effect.build.modifier(&"mark_hit") > 0: add_mark(target, effect.build.modifier(&"mark_hit"), 127, effect.build)
	if effect.kind in [&"spirit_blade", &"spirit_cross"] and effect.build.modifier(&"spirit_shock_hit") > 0:
		add_shock(target, effect.build.modifier(&"spirit_shock_hit"), effect.build)
	if effect.kind in [&"flame_burst", &"flame_meteor", &"flame_ultimate"]:
		add_burn(target, roundi(70.0 * effect.manual_count / 5.0), effect.lot.root_id, effect.depth, effect.build)
	if direct and effect.build.asset_stacks(&"R028") > 0: _status(target, &"corrosion", 1, 0)
	if effect.kind == &"spirit_mark":
		add_mark(target, 4 * effect.manual_count + (effect.build.modifier(&"mark_fresh_points") if target.hp_q == target.max_hp_q else 0), 127, effect.build)
		add_shield(effect.build.modifier(&"mark_shield") * Q)
	if effect.kind == &"storm_arc":
		add_shock(target, roundi(36.0 * effect.manual_count / 5.0), effect.build)
	_pending_death_depth[target.id] = effect.depth
	var packet := ledger.spend(_tx("hit"), effect.lot, mini(amount, effect.lot.amount_q))
	_commit_damage(target, packet, effect.kind, origin, effect.empowered, contact_at, direct)
	if not relic_hit.is_empty(): _resolve_relic_hit(effect, target, relic_hit)
	if effect.kind == &"storm_arc" and effect.arc_index < 3 and world.ultimate_time > 0.0 and effect.build.asset_stacks(&"R047") > 0:
		add_shield(roundi(Q * effect.build.relic_number(&"R047", &"shield")))
	_impulse(target, origin, (530.0 if effect.empowered else 300.0) if effect.kind == &"frost_spear" else 150.0)
	if direct and effect.build.asset_stacks(&"R027") > 0 and target.alive() and not target.boss and target.hp_q < target.max_hp_q * effect.build.relic_number(&"R027", &"threshold_pct") / 100.0:
		_deal(target, target.hp_q, &"R027", target.position, 0)
	if direct and effect.build.asset_stacks(&"R007") > 0:
		_burst(target.position, effect.build.relic_number(&"R007", &"radius") + effect.build.relic_number(&"R023", &"radius"), int(base_amount * factor * effect.build.relic_number(&"R007", &"damage_pct") / 100.0), &"R007", target.id, 1)
	if direct and effect.build.asset_stacks(&"R026") > 0: _pull(target.position, 190.0, 260.0)
	if direct and effect.build.asset_stacks(&"R032") > 0:
		_region(target.position, effect.build.relic_number(&"R032", &"empowered_radius" if effect.empowered else &"radius"), effect.build.relic_number(&"R032", &"duration"), &"cold_field")
	elif direct and effect.kind == &"frost_spear":
		world.event_committed.emit({"kind": &"frost_ground", "at": target.position, "radius": 114.0 if effect.empowered else 75.0, "duration": 2.6})
	if effect.empowered and effect.kind == &"frost_spear" and effect.build.asset_stacks(&"R045") > 0:
		for enemy in _nearby(target.position, 155.0): _apply_cold(enemy, roundi(Q * effect.build.relic_number(&"R045", &"cold")), effect.build)
	if effect.kind == &"flame_burst" and effect.empowered:
		var radius := (115.0 if effect.empowered else 55.0) + effect.build.relic_number(&"R053", &"radius") + effect.build.modifier(&"fire_field_radius")
		for enemy in _nearby(target.position, radius, target.id):
			add_burn(enemy, 35, effect.lot.root_id, effect.depth + 1, effect.build)
			_deal(enemy, int(base_amount * (0.5 if effect.empowered else 0.22)), &"flame_splash", target.position, effect.depth + 1)
		_deal(target, int(base_amount * 0.5), &"flame_splash", target.position, effect.depth + 1)
		_region(target.position, radius, 3.2 + RelicParameters.seconds(effect.build, &"fire_field_ms"), &"fire_field")
	if effect.kind == &"storm_arc" and effect.empowered:
		var radius := 125.0 + effect.build.relic_number(&"R023", &"radius") + effect.build.modifier(&"storm_burst_radius")
		for enemy in _nearby(target.position, radius, target.id):
			add_shock(enemy, 30, effect.build)
			_deal(enemy, roundi(effect.base_power_q * STORM_HEAD_SCALE * 0.3 * RelicParameters.ratio(effect.build, &"storm_burst_pct")), &"storm_burst", target.position, 1)
		world.event_committed.emit({"kind": &"field", "source": &"overload", "at": target.position, "radius": radius})
	if effect.kind == &"storm_arc" or (direct and build.asset_stacks(&"R034") > 0): _conduct(target)
	if effect.kind == &"storm_arc":
		effect.visited.append(str(target.id))
		_continue_arc(effect, target)
	elif direct and build.book() != &"storm" and build.asset_stacks(&"R002") > 0:
		_chain(target, int(base_amount * build.relic_number(&"R002", &"chain_pct") / 100.0), roundi(build.relic_number(&"R002", &"jumps")))
	if not target.alive(): on_enemy_death(target, effect.kind, effect.depth)
	effect.damage_q = effect.lot.amount_q
	if effect.applications > 1: effect.applications -= 1


## Only a paid, fully manual primary can spend status or start these reactions.
## Capture conditions before this hit supplies its own element points.
func _prepare_relic_hit(effect: BattleEffect, target: BattleEnemy) -> Dictionary:
	var snapshot := effect.build
	var facts := {"frozen": target.frozen_time > 0.0, "ignite": target.burn <= 10, "opening": false, "reaction": false, "burn": 0, "discharge": false, "fire_field": false}
	if effect.kind == &"flame_burst" and snapshot.asset_stacks(&"A006") > 0:
		for field in fields:
			if field.effect.kind == &"fire_field" and field.expires_at > clock and field.contains(target.position):
				fields.erase(field)
				facts.fire_field = true
				break
	if snapshot.asset_stacks(&"G013") > 0 and not _introduced_targets.has(target.id):
		_introduced_targets[target.id] = true
		facts.opening = true
	if snapshot.asset_stacks(&"G027") > 0:
		var cost := roundi(snapshot.relic_number(&"G027", &"consume"))
		var states: Array[StringName] = []
		for key in [&"cold", &"burn", &"shock", &"vulnerability"]:
			if int(target.get(key)) >= cost + (10 if key == &"burn" else 0): states.append(key)
		if states.size() >= 2:
			for key in states.slice(0, 2): target.set(key, int(target.get(key)) - cost)
			facts.reaction = true
	if effect.kind == &"flame_burst" and snapshot.asset_stacks(&"A004") > 0 and target.burn >= snapshot.relic_number(&"A004", &"threshold"):
		facts.burn = mini(target.burn - 10, roundi(snapshot.relic_number(&"A004", &"consume")))
		target.burn -= int(facts.burn)
	if snapshot.book() != &"storm" and snapshot.asset_stacks(&"G025") > 0 and target.shock > snapshot.relic_number(&"G025", &"threshold"):
		target.shock -= roundi(snapshot.relic_number(&"G025", &"consume"))
		facts.discharge = true
	return facts


func _resolve_relic_hit(effect: BattleEffect, target: BattleEnemy, facts: Dictionary) -> void:
	var snapshot := effect.build
	if facts.frozen and target.alive() and effect.kind == &"frost_spear" and snapshot.asset_stacks(&"F006") > 0:
		target.frozen_time = 0.0
		target.freeze_cooldown = 3.0 if target.boss else 1.0
		_relic_burst(effect, target, &"F006")
	if facts.opening: _relic_burst(effect, target, &"G013")
	if facts.reaction: _relic_burst(effect, target, &"G027")
	if facts.discharge: _relic_burst(effect, target, &"G025")
	if facts.fire_field: _relic_burst(effect, target, &"A006")
	if int(facts.burn) > 0:
		_burst(target.position, snapshot.relic_number(&"A004", &"radius"), roundi(int(facts.burn) * Q * snapshot.relic_number(&"A004", &"damage_per_point")), &"A004", &"", 1)
	if facts.ignite and effect.kind == &"flame_burst" and snapshot.asset_stacks(&"A009") > 0:
		for next in _nearby(target.position, snapshot.relic_number(&"A009", &"radius"), target.id).slice(0, roundi(snapshot.relic_number(&"A009", &"targets"))):
			add_burn(next, snapshot.relic_number(&"A009", &"burn"), effect.lot.root_id, 1, snapshot)
	if effect.mist_cast and effect.kind == &"frost_spear":
		_region(target.position, snapshot.relic_number(&"F009", &"radius"), snapshot.relic_number(&"F009", &"duration"), &"cold_field")
	if effect.kind == &"frost_spear" and effect.empowered and not effect.split_released and snapshot.asset_stacks(&"F003") > 0:
		effect.split_released = true
		for next in _nearby(target.position, snapshot.relic_number(&"F003", &"radius"), target.id).slice(0, roundi(snapshot.relic_number(&"F003", &"targets"))):
			var lot := ledger.earn(effect.lot.root_id, StringName("F003:" + str(next.id)), snapshot.identity(), SpellLot.Kind.POWER, roundi(effect.base_power_q * snapshot.relic_number(&"F003", &"damage_pct") / 100.0), &"split", DamagePacket.Element.ICE)
			var shard := _effect(lot, &"frost_fragment", next.id, target.position, snapshot)
			shard.depth = 1
			shard.manual_count = 0
			world.effects.append(shard)


func _relic_burst(effect: BattleEffect, target: BattleEnemy, id: StringName) -> void:
	_burst(target.position, effect.build.relic_number(id, &"radius"), roundi(effect.base_power_q * effect.build.relic_number(id, &"damage_pct") / 100.0), id, &"", 1)


func _copy_to(template: BattleEffect, target: BattleEnemy) -> void:
	var lot := ledger.earn(template.lot.root_id, &"G016", template.build.identity(), SpellLot.Kind.POWER, roundi(template.base_power_q * template.build.relic_number(&"G016", &"damage_pct") / 100.0), &"copy", ELEMENTS[template.build.book()])
	lot.claims[&"copied"] = true
	var copy := _effect(lot, &"echo", target.id, template.origin, template.build)
	copy.depth = 1
	copy.manual_count = 0
	world.effects.append(copy)


func _crane_followup(target: BattleEnemy) -> void:
	var crane: SpellField = null
	var distance := INF
	for field in fields:
		if field.effect.kind != &"paper_crane" or field.expires_at <= clock: continue
		var next_distance := ((field.center - target.position) * BattleSession.ARENA_SIZE).length_squared()
		if next_distance < distance:
			crane = field
			distance = next_distance
	if crane == null: return
	fields.erase(crane)
	add_mark(target, roundi(build.relic_number(&"P010", &"mark")))
	_deal(target, roundi(Q * build.relic_number(&"P010", &"damage")), &"paper_crane", crane.center, 1)
	world.event_committed.emit({"kind": &"spirit_intercept", "at": crane.center})


func advance(delta: float) -> void:
	clock += delta
	_advance_states(delta)
	for attack in spirit_attacks.duplicate():
		if attack.expires_at <= clock:
			retire(attack)
			spirit_attacks.erase(attack)
	for status in ongoing.duplicate():
		var enemy := world.enemy_by_id(status.target_id)
		if enemy == null or not enemy.alive():
			ongoing.erase(status)
			continue
		while status.remaining_pulses > 0 and status.next_at <= clock:
			_pulse_status(status)
		if status.remaining_pulses <= 0: ongoing.erase(status)
	for field in fields.duplicate():
		if field.expires_at <= clock:
			fields.erase(field)
			continue
		if field.effect.kind == &"gravity_field": _pull(field.center, field.radius, delta * 180.0, false)


func retire(effect: BattleEffect) -> void:
	if effect.lot == null: return
	_recover(effect.lot)
	if effect.charge != null: _recover(effect.charge)
	if effect.cold != null: _recover(effect.cold)
	if effect.heat != null: _recover(effect.heat)






func heal(amount: int) -> void:
	var restored := mini(maxi(0, amount), world.player_max_hp_q - world.player_hp_q)
	world.player_hp_q += restored
	healed_q += restored


func counter(attack_id: String, damage: int, target: StringName, origin: Vector2) -> BattleEffect:
	if _enemy_attacks.has("counter:" + attack_id): return null
	_enemy_attacks["counter:" + attack_id] = true
	var lot := ledger.earn(attack_id, &"counter", build.identity(), SpellLot.Kind.POWER, maxi(Q, damage), &"counter")
	var effect := _effect(lot, &"counter", target, origin, build)
	effect.depth = 1
	return effect




func ultimate(target: BattleEnemy) -> BattleEffect:
	var lot := ledger.earn(_tx("ultimate-root"), build.book(), build.identity(), SpellLot.Kind.POWER, 0, &"ultimate", ELEMENTS[build.book()])
	var effect := _effect(lot, StringName(str(build.book()) + "_ultimate"), target.id, target.position, build)
	effect.empowered = true
	effect.depth = 1
	return effect


func take_spirit_attack(target: BattleEnemy, position: Vector2) -> BattleEffect:
	var amount := roundi(60 * Q * 0.12 * damage_multiplier() * (1.0 + (build.relic_number(&"R005", &"damage_pct") + build.relic_number(&"R035", &"damage_pct")) / 100.0))
	var bonus := build.modifier(&"spirit_pct")
	if run.shield_q > 0: bonus += build.modifier(&"shielded_spirit_pct")
	if world.spirit_blade_count() >= world.spirit_capacity(): bonus += build.modifier(&"full_spirit_pct")
	amount = roundi(amount * (1.0 + mini(60, bonus) / 100.0))
	var lot := ledger.earn(_tx("spirit-strike"), &"spirit", build.identity(), SpellLot.Kind.POWER, amount, &"spirit", DamagePacket.Element.PAPER)
	var effect := _effect(lot, &"spirit_blade", target.id, position, build)
	effect.depth = 1
	return effect


func clear_ultimate_threats(_effect_value: BattleEffect, origin: Vector2) -> void:
	clear_radius(origin, 650.0, &"ultimate")


func consume_assist() -> bool:
	if not assist_ready(): return false
	_assist_tokens -= 1
	_save_counters()
	return true


func assist_ready() -> bool:
	return build.has(&"assist") and _assist_tokens > 0


func finish(reason: StringName, preserve_flight: bool = false) -> RoomCombatResult:
	_save_counters()
	var result := RoomCombatResult.new()
	result.room_id = ledger.room_id
	result.reason = reason
	result.actual_damage_q = actual_damage_q
	result.asset_claims = run.asset_claims.duplicate()
	run.hp_q = world.player_hp_q
	run.resonance_q = world.resonance_q
	run.reserve = []
	if preserve_flight:
		# Unspent work is not a launched attack; active paid flight keeps its ledger.
		for lot in work_bank: ledger.spend(_tx("page-work-loss"), lot, lot.amount_q)
		work_bank.clear()
	else:
		for lot in ledger.active_lots():
			if lot.material == SpellLot.Kind.POWER: unused_power_q += lot.amount_q
			ledger.spend(_tx("room-loss"), lot, lot.amount_q)
		ongoing.clear()
		fields.clear()
		spirit_attacks.clear()
	result.overkill_damage_q = overkill_damage_q
	result.unused_power_q = unused_power_q
	result.healed_q = healed_q
	result.guarded_damage_q = guarded_damage_q
	result.guarded_hits = guarded_hits
	result.freezes = freezes
	result.damage_by_source = damage_by_source.duplicate()
	result.kills_by_source = kills_by_source.duplicate()
	result.raw_spent_q = ledger.raw_spent_q - _raw_spent_start
	return result


func _effect(lot: SpellLot, kind: StringName, target: StringName, origin: Vector2, snapshot: CompiledBuild) -> BattleEffect:
	var effect := BattleEffect.new()
	effect.lot = lot
	effect.build = snapshot
	effect.source = snapshot.book()
	effect.kind = kind
	effect.target_id = target
	effect.origin = origin
	effect.damage_q = lot.amount_q
	return effect


func storm_word_strike(primary: BattleEffect, target: BattleEnemy, delay: float) -> BattleEffect:
	var lot := ledger.earn(_tx("storm-word"), &"storm-ultimate", build.identity(), SpellLot.Kind.POWER, roundi(primary.damage_q * 0.7), &"ultimate-word", DamagePacket.Element.LIGHTNING)
	var strike := _effect(lot, &"storm_ultimate_word", target.id, Vector2(target.position.x, 0.04), build)
	strike.delay = delay
	strike.depth = 1
	strike.expires_at = clock + 0.5
	return strike


func fork(effect: BattleEffect, amount: int, kind: StringName, target: StringName, origin: Vector2) -> BattleEffect:
	var total := effect.lot.amount_q
	var lot := ledger.transfer(_tx("fork"), effect.lot, amount, kind)
	if lot.amount_q > 0 and effect.lot.amount_q > 0:
		world.has_same_root_lots = true
	var child := _effect(lot, kind, target, origin, effect.build)
	child.empowered = effect.empowered
	child.dispatched = effect.dispatched
	child.expires_at = effect.expires_at
	child.depth = effect.depth + 1
	child.manual_count = effect.manual_count
	child.base_power_q = effect.base_power_q
	if total > 0:
		@warning_ignore("integer_division")
		if effect.cold != null: child.cold = ledger.transfer(_tx("fork-cold"), effect.cold, effect.cold.amount_q * amount / total, kind)
		@warning_ignore("integer_division")
		if effect.charge != null: child.charge = ledger.transfer(_tx("fork-charge"), effect.charge, effect.charge.amount_q * amount / total, kind)
		@warning_ignore("integer_division")
		if effect.heat != null: child.heat = ledger.transfer(_tx("fork-heat"), effect.heat, effect.heat.amount_q * amount / total, kind)
	return child




func _configure_shape(effect: BattleEffect) -> void:
	if effect.shaped: return
	effect.shaped = true
	if effect.kind in [&"frost_spear", &"frost_ultimate"]:
		configure_frost_hits(effect, 2 + (2 if effect.empowered else 0) + roundi(effect.build.relic_number(&"R044", &"pierces")) + effect.build.modifier(&"frost_pierce"))
	if effect.kind == &"storm_arc":
		effect.arc_base_hits = 3 + roundi(effect.build.relic_number(&"R002", &"jumps") + effect.build.relic_number(&"R046", &"jumps")) + effect.build.modifier(&"chain_hits")
		effect.jumps = effect.arc_base_hits - 1


func configure_frost_hits(effect: BattleEffect, hits: int) -> void:
	effect.applications = hits
	effect.primary_share_q = effect.damage_q
	var pierces := ledger.earn(effect.lot.root_id, StringName(_tx("ice-pierces")), effect.build.identity(), SpellLot.Kind.POWER, effect.primary_share_q * (hits - 1), &"ice-pierces", DamagePacket.Element.ICE)
	ledger.aggregate(_tx("ice-join"), effect.lot, pierces)




func _pulse_status(status: OngoingSpell) -> void:
	var target := world.enemy_by_id(status.target_id)
	if target == null or not target.alive():
		status.remaining_pulses = 0
		return
	# Keep the fixed-point remainder in the lot for subsequent pulses.
	@warning_ignore("integer_division")
	var amount := status.effect.lot.amount_q / maxi(1, status.remaining_pulses)
	var packet := ledger.spend(_tx("status-pulse"), status.effect.lot, amount)
	status.remaining_pulses -= 1
	status.next_at += status.interval
	_pending_death_depth[target.id] = status.spread_depth + 1
	_commit_damage(target, packet, status.effect.kind, status.effect.origin)
	if not target.alive(): on_enemy_death(target, status.effect.kind, status.spread_depth + 1)




func _apply_cold(target: BattleEnemy, amount: int, snapshot: CompiledBuild) -> void:
	if not target.alive() or amount <= 0: return
	target.cold = mini(127, target.cold + roundi(float(amount) / Q * (1.0 + float(snapshot.value(&"cold_efficiency_q")) / Q) * RelicParameters.ratio(snapshot, &"cold_pct")))
	target.cold_grace = COLD_GRACE
	_try_freeze(target, snapshot)


func _try_freeze(target: BattleEnemy, snapshot: CompiledBuild = null) -> void:
	if target.cold <= 90 or target.frozen_time > 0.0 or target.freeze_cooldown > 0.0: return
	if snapshot == null: snapshot = build
	target.cold -= 60
	target.frozen_time = RelicParameters.freeze_duration(snapshot, target.boss)
	freezes += 1
	add_shield(snapshot.modifier(&"freeze_shield") * Q)
	world.add_resonance(snapshot.modifier(&"freeze_resonance") * Q)
	world.event_committed.emit({"kind": &"freeze", "at": target.position, "enemy": target.id, "duration": target.frozen_time})


func add_burn(target: BattleEnemy, points: float, root: String, depth: int = 0, snapshot: CompiledBuild = null) -> void:
	if not target.alive(): return
	if snapshot == null: snapshot = build
	target.burn_remainder += points * (1.0 + snapshot.relic_number(&"R051", &"points_pct") / 100.0) * RelicParameters.ratio(snapshot, &"burn_points_pct")
	var gained := floori(target.burn_remainder)
	target.burn_remainder -= gained
	target.burn = clampi(target.burn + gained, 0, 127)
	target.burn_root = root
	target.burn_depth = depth
	target.burn_time = maxf(0.0, (target.burn - 10) / 5.0 * BURN_INTERVAL)


func add_shock(target: BattleEnemy, points: int, snapshot: CompiledBuild = null) -> void:
	if not target.alive(): return
	if snapshot == null: snapshot = build
	target.shock = clampi(target.shock + roundi(points * RelicParameters.ratio(snapshot, &"shock_pct")), 0, 127)
	target.shock_grace = 2.0 + RelicParameters.seconds(snapshot, &"shock_grace_ms")


func add_mark(target: BattleEnemy, points: int, ceiling: int = 127, snapshot: CompiledBuild = null) -> void:
	# A secondary source cannot lower or maintain a stronger native mark.
	if target.vulnerability > ceiling: return
	if snapshot == null: snapshot = build
	target.vulnerability = mini(ceiling, target.vulnerability + roundi(points * RelicParameters.ratio(snapshot, &"mark_pct")))
	target.mark_grace = 1.5 + RelicParameters.seconds(snapshot, &"mark_grace_ms")
	target.marked_time = 8.0


func _advance_states(delta: float) -> void:
	for enemy in world._living():
		var frozen_before := enemy.frozen_time
		enemy.frozen_time = maxf(0.0, frozen_before - delta)
		if frozen_before > 0.0 and enemy.frozen_time == 0.0:
			enemy.freeze_cooldown = 3.0 if enemy.boss else 1.0
		elif frozen_before <= 0.0:
			enemy.freeze_cooldown = maxf(0.0, enemy.freeze_cooldown - delta)
		var cold_decay := maxf(0.0, delta - enemy.cold_grace)
		enemy.cold_grace = maxf(0.0, enemy.cold_grace - delta)
		enemy.cold_remainder += cold_decay * COLD_DECAY * (1.0 - build.modifier(&"cold_decay_pct") / 100.0)
		var cold_loss := floori(enemy.cold_remainder)
		enemy.cold_remainder -= cold_loss
		enemy.cold = maxi(0, enemy.cold - cold_loss)
		var mark_decay := maxf(0.0, delta - enemy.mark_grace)
		enemy.mark_grace = maxf(0.0, enemy.mark_grace - delta)
		enemy.vulnerability_remainder += mark_decay * 12.0 * (1.0 - build.modifier(&"mark_decay_pct") / 100.0)
		var mark_loss := floori(enemy.vulnerability_remainder)
		enemy.vulnerability_remainder -= mark_loss
		enemy.vulnerability = maxi(0, enemy.vulnerability - mark_loss)
		enemy.marked_time = maxf(0.0, enemy.marked_time - delta)
		var shock_decay := maxf(0.0, delta - enemy.shock_grace)
		enemy.shock_grace = maxf(0.0, enemy.shock_grace - delta)
		enemy.shock_remainder += shock_decay * 8.0 * (1.0 - build.modifier(&"shock_decay_pct") / 100.0)
		var shock_loss := floori(enemy.shock_remainder)
		enemy.shock_remainder -= shock_loss
		enemy.shock = maxi(0, enemy.shock - shock_loss)
		var layers := 0
		var cold_rate := 0.0
		for field in fields:
			if field.expires_at <= clock or not field.contains(enemy.position): continue
			if field.effect.kind == &"fire_field": layers += 1
			elif field.effect.kind in [&"cold_field", &"ice_mist"]: cold_rate += 30.0
		if layers > 0:
			add_burn(enemy, 40.0 * (1.0 - pow(0.5, layers)) * delta * RelicParameters.ratio(build, &"fire_field_rate_pct"), "fire-field", 1)
		if cold_rate > 0.0:
			enemy.cold_gain_remainder += cold_rate * delta
			var gain := floori(enemy.cold_gain_remainder)
			enemy.cold_gain_remainder -= gain
			if gain > 0: _apply_cold(enemy, gain * Q, build)
		_try_freeze(enemy)
		if enemy.burn > 10:
			enemy.burn_clock += delta
			while enemy.burn_clock >= BURN_INTERVAL and enemy.burn > 10 and enemy.alive():
				enemy.burn_clock -= BURN_INTERVAL
				enemy.burn = maxi(0, enemy.burn - 5)
				var damage := roundi(6 * Q * damage_multiplier() * (1.0 + build.relic_number(&"R050", &"damage_pct") / 100.0) * (1.0 + build.relic_number(&"R056", &"burn_pct") / 100.0))
				var bonus := build.modifier(&"burn_pct")
				if enemy.burn < 50: bonus += build.modifier(&"burn_weak_pct")
				if enemy.cold > 30: bonus += build.modifier(&"cold_burn_pct")
				damage = roundi(damage * (1.0 + mini(70, bonus) / 100.0))
				_deal(enemy, damage, &"flame_burn", enemy.position, enemy.burn_depth + 1, enemy.burn_root)
		else:
			enemy.burn_clock = 0.0
		enemy.burn_time = maxf(0.0, (enemy.burn - 10) / 5.0 * BURN_INTERVAL)


func obscures(enemy: BattleEnemy) -> bool:
	var start := enemy.position * BattleSession.ARENA_SIZE
	var end := world.player_position * BattleSession.ARENA_SIZE
	if start.distance_to(end) <= 90.0: return false
	for field in fields:
		if field.effect.kind != &"ice_mist" or field.expires_at <= clock: continue
		var center := field.center * BattleSession.ARENA_SIZE
		if center.distance_to(Geometry2D.get_closest_point_to_segment(center, start, end)) <= field.radius: return true
	return false


func arc_target(effect: BattleEffect, origin: Vector2) -> BattleEnemy:
	var best: BattleEnemy = null
	var best_distance := INF
	var extension := effect.build.relic_number(&"R023", &"chain_range") + effect.build.modifier(&"chain_range")
	for next in world.enemies:
		if not next.alive() or next.id == &"" or not BattleSession.enemy_in_combat(next): continue
		if str(next.id) in effect.visited: continue
		var offset := (next.position - origin) * BattleSession.ARENA_SIZE
		var distance := offset.length_squared()
		if not distance <= 3000.0 * 3000.0: continue
		var reach := (992.0 if next.shock > 30 else 512.0) + extension
		if next.shock <= 60 and offset.length() > reach: continue
		if best == null or distance < best_distance or (distance == best_distance and str(next.id) < str(best.id)):
			best = next
			best_distance = distance
	return best


func _continue_arc(effect: BattleEffect, target: BattleEnemy) -> void:
	var next := arc_target(effect, target.position) if effect.jumps > 0 else null
	if next == null:
		finish_arc(effect, target.position, effect.jumps)
		return
	# Retain the former absolute tail while lowering the head of the chain.
	var floor_ratio := 0.18 * (1.0 + effect.build.relic_number(&"R033", &"tail_pct") / 100.0)
	floor_ratio *= RelicParameters.ratio(effect.build, &"chain_tail_pct")
	var ratio := maxf(floor_ratio, STORM_HEAD_SCALE - (STORM_HEAD_SCALE - floor_ratio) * (effect.arc_index + 1) / maxi(1, effect.arc_base_hits - 1))
	var retained := roundi(effect.base_power_q * ratio)
	var lot := ledger.earn(effect.lot.root_id, StringName(_tx("chain")), effect.build.identity(), SpellLot.Kind.POWER, retained, &"chain", DamagePacket.Element.LIGHTNING)
	var arc := _effect(lot, &"storm_arc", next.id, target.position, effect.build)
	arc.shaped = true
	arc.jumps = effect.jumps - 1
	arc.visited = effect.visited.duplicate()
	arc.delay = 0.08
	arc.depth = 1
	arc.manual_count = effect.manual_count
	arc.manual_cast = effect.manual_cast
	arc.base_power_q = effect.base_power_q
	arc.arc_base_hits = effect.arc_base_hits
	arc.arc_index = effect.arc_index + 1
	arc.arc_charge = effect.arc_charge
	arc.arc_anchor = effect.arc_anchor
	world.effects.append(arc)


func finish_arc(effect: BattleEffect, at: Vector2, unused_jumps: int) -> void:
	if not effect.manual_cast: return
	if effect.build.asset_stacks(&"T003") > 0:
		var scale := 1.0 + mini(unused_jumps, roundi(effect.build.relic_number(&"T003", &"max_unused")))
		var radius := effect.build.relic_number(&"T003", &"radius")
		_burst(at, radius, roundi(effect.base_power_q * effect.build.relic_number(&"T003", &"damage_pct") / 100.0 * scale), &"T003", &"", 1)
		world.event_committed.emit({"kind": &"field", "source": &"overload", "at": at, "radius": radius})
	var anchor := world.enemy_by_id(effect.arc_anchor)
	if effect.build.asset_stacks(&"T004") > 0 and anchor != null and anchor.alive() and BattleSession.enemy_in_combat(anchor):
		var lot := ledger.earn(effect.lot.root_id, &"T004", effect.build.identity(), SpellLot.Kind.POWER, roundi(effect.base_power_q * effect.build.relic_number(&"T004", &"damage_pct") / 100.0), &"return", DamagePacket.Element.LIGHTNING)
		var returning := _effect(lot, &"storm_chain", anchor.id, at, effect.build)
		returning.depth = 1
		returning.manual_count = 0
		returning.retargetable = false
		returning.delay = 0.08
		world.effects.append(returning)












func _periodic_copy(template: BattleEffect) -> void:
	var target: BattleEnemy = null
	var best_distance := INF
	for candidate in world.enemies:
		if not candidate.alive() or candidate.id == template.target_id or not BattleSession.enemy_in_combat(candidate): continue
		var distance := ((candidate.position - template.origin) * BattleSession.ARENA_SIZE).length_squared()
		if not distance <= 3000.0 * 3000.0: continue
		if target == null or distance < best_distance or (distance == best_distance and str(candidate.id) < str(target.id)):
			target = candidate
			best_distance = distance
	if target == null: return
	var copy_ratio_q := int(Q * template.build.relic_number(&"R006", &"damage_pct") / 100.0)
	# Truncate to whole fixed-point units without converting the ledger to float.
	@warning_ignore("integer_division")
	var output := ledger.earn(template.lot.root_id, &"R006", template.build.identity(), SpellLot.Kind.POWER, roundi((template.damage_q * copy_ratio_q / Q) * RelicParameters.ratio(template.build, &"copy_pct")), &"copy", ELEMENTS[template.build.book()])
	output.claims[&"copied"] = true
	var effect := _effect(output, &"echo", target.id, template.origin, template.build)
	_configure_shape(effect)
	world.effects.append(effect)










func _recover(lot: SpellLot) -> void:
	if lot == null or lot.amount_q <= 0: return
	if lot.material == SpellLot.Kind.POWER: unused_power_q += lot.amount_q
	ledger.spend(_tx("retire"), lot, lot.amount_q)


















func _commit_damage(target: BattleEnemy, packet: DamagePacket, kind: StringName, origin: Vector2, empowered: bool = false, contact_point: Vector2 = Vector2.INF, direct: bool = false) -> void:
	if not target.alive() or not BattleSession.enemy_in_combat(target): return
	var amount := packet.actual(target.resistances)
	var before := target.hp_q
	world.commit_damage(target, amount, packet.total(), kind, origin, empowered, contact_point, direct)
	var applied := maxi(0, before - target.hp_q)
	actual_damage_q += applied
	overkill_damage_q += maxi(0, amount - applied)
	damage_by_source[kind] = damage_by_source.get(kind, 0) + applied
	if not target.alive(): kills_by_source[kind] = kills_by_source.get(kind, 0) + 1


func _nearby(origin: Vector2, radius: float, excluded: StringName = &"") -> Array[BattleEnemy]:
	var targets: Array[BattleEnemy] = []
	var radius_squared := radius * radius
	for target in world.enemies:
		if target.alive() and target.id != excluded and BattleSession.enemy_in_combat(target) and ((target.position - origin) * BattleSession.ARENA_SIZE).length_squared() <= radius_squared: targets.append(target)
	targets.sort_custom(func(a: BattleEnemy, b: BattleEnemy) -> bool:
		var ad := ((a.position - origin) * BattleSession.ARENA_SIZE).length_squared()
		var bd := ((b.position - origin) * BattleSession.ARENA_SIZE).length_squared()
		return ad < bd if ad != bd else str(a.id) < str(b.id))
	return targets
















func graze(threat: BattleThreat) -> void:
	if threat.grazed or threat.reflected: return
	threat.grazed = true
	var boosted := build.asset_stacks(&"R038") > 0
	world.add_resonance(int((1.4 if boosted else 0.7) * Q))
	if boosted: add_shield(int(Q * build.relic_number(&"R038", &"shield")))


func on_dodge(origin: Vector2, destination: Vector2) -> void:
	if build.asset_stacks(&"T009") > 0:
		_dodge_script_ready = true
		_save_counters()
	world.add_resonance(build.modifier(&"dodge_resonance") * Q)
	if build.modifier(&"dodge_cold") > 0:
		for enemy in _nearby(origin, 105.0): _apply_cold(enemy, build.modifier(&"dodge_cold") * Q, build)
	if build.asset_stacks(&"R041") > 0: world.precision_slow_remaining = build.relic_number(&"R041", &"duration")
	if build.asset_stacks(&"R037") > 0:
		_pull(origin, 190.0, 260.0)
		_region(origin, 190.0, 1.2, &"gravity_field")
	if build.book() == &"flame":
		_region(origin, 60.0 + build.relic_number(&"R055", &"radius") + build.modifier(&"dodge_flame_radius"), 2.0 + build.relic_number(&"R055", &"duration") + RelicParameters.seconds(build, &"dodge_flame_ms"), &"fire_field")
	elif build.book() == &"frost":
		_region(origin, 105.0 + build.modifier(&"mist_radius"), 3.0 + RelicParameters.seconds(build, &"mist_ms"), &"ice_mist")
	elif build.book() == &"spirit":
		_region(origin, 26.0 + build.modifier(&"crane_radius"), 4.0 + RelicParameters.seconds(build, &"crane_ms"), &"paper_crane")
	elif build.book() == &"storm":
		var start := origin * BattleSession.ARENA_SIZE
		var end := destination * BattleSession.ARENA_SIZE
		for enemy in world._living():
			if not BattleSession.enemy_in_combat(enemy): continue
			var point := enemy.position * BattleSession.ARENA_SIZE
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, start, end)) <= 28.0 + enemy.radius:
				add_shock(enemy, 30 + build.modifier(&"dodge_shock"))
				_deal(enemy, roundi(18 * Q * damage_multiplier() * RelicParameters.ratio(build, &"dodge_storm_pct")), &"storm_dodge", origin, 1)
		world.event_committed.emit({"kind": &"storm_path", "from": origin, "at": destination})


func intercept_crane(threat: BattleThreat) -> bool:
	for field in fields:
		if field.effect.kind != &"paper_crane" or field.expires_at <= clock: continue
		var center := field.center * BattleSession.ARENA_SIZE
		if CombatGeometry.sweep_discs(threat.previous_position * BattleSession.ARENA_SIZE, threat.position * BattleSession.ARENA_SIZE, center, center, threat.radius + field.radius) == INF: continue
		var target := world.enemy_by_id(threat.source_id)
		if target == null or not target.alive(): target = world._nearest_living(field.center)
		if target != null: _deal(target, roundi(24 * Q * damage_multiplier() * RelicParameters.ratio(build, &"crane_pct")), &"paper_crane", field.center, 1)
		world.event_committed.emit({"kind": &"spirit_intercept", "at": field.center})
		fields.erase(field)
		if build.asset_stacks(&"P011") > 0:
			world._summon_spirit()
			world.spirit_time = RelicParameters.spirit_duration(build)
			if target == null or not target.alive(): target = world._nearest_living(field.center)
			if target != null:
				var lot := ledger.earn(_tx("crane-cross"), &"P011", build.identity(), SpellLot.Kind.POWER, 0, &"crane-cross")
				var command := _effect(lot, &"spirit_mark", target.id, field.center, build)
				command.base_power_q = roundi(Q * build.relic_number(&"P011", &"power") * damage_multiplier())
				world.command_spirit_cross(command, target)
		return true
	return false










func _next() -> int:
	_serial += 1
	return _serial


func on_dodge_landed(at: Vector2) -> void:
	if build.asset_stacks(&"R010") > 0:
		clear_radius(at, build.relic_number(&"R010", &"radius"), &"dodge_clear")
		for enemy in _nearby(at, 180.0): _impulse(enemy, at, 210.0)
	if build.asset_stacks(&"R037") > 0:
		if build.asset_stacks(&"R010") == 0: clear_radius(at, 75.0, &"dodge_clear")
		for enemy in _nearby(at, 115.0): _impulse(enemy, at, 180.0)


func damage_multiplier() -> float:
	var factor := 1.0 + build.relic_number(&"R001", &"damage_pct") / 100.0
	var bonus := build.modifier(&"power_pct")
	if world.player_hp_q < world.player_max_hp_q * 0.4: bonus += build.modifier(&"low_health_pct")
	if run.shield_q > 0: bonus += build.modifier(&"shielded_pct")
	factor *= 1.0 + clampi(bonus, -50, 75) / 100.0
	if build.asset_stacks(&"R036") > 0 and world.player_hp_q < world.player_max_hp_q * build.relic_number(&"R036", &"threshold_pct") / 100.0: factor *= 1.0 + build.relic_number(&"R036", &"damage_pct") / 100.0
	if build.asset_stacks(&"R042") > 0: factor *= 1.0 + build.relic_number(&"R042", &"damage_pct") / 100.0
	if build.asset_stacks(&"R043") > 0: factor *= 1.0 + build.relic_number(&"R043", &"damage_pct") / 100.0
	return factor


func add_shield(amount: int) -> void:
	run.shield_q = mini(RelicParameters.shield_capacity(build) * Q, run.shield_q + amount)


func clear_radius(at: Vector2, radius: float, source: StringName = &"clear") -> void:
	for threat in world.threats:
		if not threat.reflected and ((threat.position - at) * BattleSession.ARENA_SIZE).length() <= radius:
			threat.cleared = true
	# A reflected hit can trigger overload while the world iterates this array.
	# Commit removal after that pass, rather than invalidating its live indices.
	if not world._advancing_threats: world._flush_cleared_threats()
	world.event_committed.emit({"kind": &"clear_pulse", "at": at, "radius": radius, "source": source})


func _deal(target: BattleEnemy, amount: int, source: StringName, at: Vector2, depth: int = 0, root: String = "") -> void:
	if not target.alive() or amount <= 0: return
	var lot := ledger.earn(_tx("derived") if root.is_empty() else root, StringName(_tx(str(source))), build.identity(), SpellLot.Kind.POWER, amount, source, ELEMENTS[build.book()])
	var packet := ledger.spend(_tx("derived-hit"), lot, amount)
	_pending_death_depth[target.id] = depth
	_commit_damage(target, packet, source, at)
	if not target.alive(): on_enemy_death(target, source, depth)


func _burst(at: Vector2, radius: float, amount: int, source: StringName, excluded: StringName = &"", depth: int = 0, cold: bool = false) -> void:
	for enemy in _nearby(at, radius, excluded):
		if cold: _apply_cold(enemy, 100 * Q, build)
		_deal(enemy, amount, source, at, depth)
	world.event_committed.emit({"kind": &"field", "at": at, "source": source, "radius": radius})


func _pull(at: Vector2, radius: float, force: float, pulse: bool = true) -> void:
	for enemy in _nearby(at, radius):
		if enemy.boss or enemy.speed == 0.0: continue
		enemy.impulse += (at - enemy.position).normalized() * force / enemy.mass
	pull_environment(at, radius, force, pulse)


func pull_environment(at: Vector2, radius: float, force: float, pulse: bool = true, source_id: StringName = &"") -> void:
	# Enemy gravity releases its own outgoing shots; reflected shots are hostile
	# to their former source and remain affected. Player gravity has no exemption.
	for projectile in world.projectiles:
		var offset := (at - projectile.position) * BattleSession.ARENA_SIZE
		if offset.length_squared() < radius * radius:
			projectile.attraction_impulse += offset.normalized() * force
	for threat in world.threats:
		if source_id != &"" and threat.source_id == source_id and not threat.reflected: continue
		var offset := (at - threat.position) * BattleSession.ARENA_SIZE
		if offset.length_squared() < radius * radius:
			threat.velocity += offset.normalized() * force
	if pulse:
		world.event_committed.emit({"kind": &"gravity_pull", "at": at, "radius": radius, "force": force})


func _impulse(target: BattleEnemy, at: Vector2, force: float) -> void:
	if target.boss or target.speed == 0.0: return
	target.impulse += (target.position - at).normalized() * force * (1.0 + build.relic_number(&"R025", &"push_pct") / 100.0) / target.mass


func _region(at: Vector2, radius: float, lifetime: float, kind: StringName) -> void:
	for field in fields:
		if kind not in [&"fire_field", &"paper_crane"] and field.effect.kind == kind and ((field.center - at) * BattleSession.ARENA_SIZE).length() < 45.0:
			field.expires_at = maxf(field.expires_at, clock + lifetime)
			field.radius = maxf(field.radius, radius)
			return
	var field := SpellField.new()
	field.id = _next()
	field.center = at
	field.endpoint = at
	field.radius = radius
	field.expires_at = clock + lifetime
	field.next_at = clock + 0.5
	field.remaining_pulses = int(ceil(lifetime * 2.0))
	field.interval = 0.5
	var lot := ledger.earn(_tx("field"), kind, build.identity(), SpellLot.Kind.POWER, 0, &"field")
	field.effect = _effect(lot, kind, &"", at, build)
	fields.append(field)


func _burn(target: BattleEnemy, stacks: int = 1, spread_depth: int = 0) -> void:
	add_burn(target, 35 * stacks, _tx("burn"), spread_depth)


func _status(target: BattleEnemy, kind: StringName, added_stacks: int, spread_depth: int) -> void:
	if not target.alive(): return
	var existing: OngoingSpell
	for status in ongoing:
		if status.target_id == target.id and status.effect.kind == kind:
			existing = status
			break
	var maximum := 5 if kind == &"flame_burn" and build.asset_stacks(&"R056") > 0 else 3
	var stacks := mini(maximum, added_stacks + (existing.stacks if existing != null else 0))
	var interval := 0.5 if kind == &"flame_burn" else 1.0
	var lifetime := 3.0 + build.asset_stacks(&"R051") if kind == &"flame_burn" else build.relic_number(&"R028", &"duration")
	var pulses := int(lifetime / interval)
	var per_pulse := int(6 * Q * damage_multiplier() * (1.0 + build.relic_number(&"R050", &"damage_pct") / 100.0)) if kind == &"flame_burn" else roundi(Q * build.relic_number(&"R028", &"damage"))
	var next_tick := existing.next_at if existing != null else clock + interval
	if existing != null:
		spread_depth = mini(spread_depth, existing.spread_depth)
		retire(existing.effect)
		ongoing.erase(existing)
	var lot := ledger.earn(_tx("status"), kind, build.identity(), SpellLot.Kind.POWER, per_pulse * stacks * pulses, &"ongoing", DamagePacket.Element.FIRE if kind == &"flame_burn" else DamagePacket.Element.NEUTRAL)
	var status := OngoingSpell.new()
	status.id = _next()
	status.target_id = target.id
	status.effect = _effect(lot, kind, target.id, target.position, build)
	status.stacks = stacks
	status.spread_depth = spread_depth
	status.interval = interval
	status.next_at = next_tick
	status.remaining_pulses = pulses
	ongoing.append(status)


func _chain(target: BattleEnemy, amount: int, count: int, source: StringName = &"R002") -> void:
	var seen: Dictionary[StringName, bool] = {target.id: true}
	var origin := target.position
	var radius := 265.0 + build.relic_number(&"R023", &"chain_range") + build.modifier(&"chain_range")
	var radius_squared := radius * radius
	for index in count:
		var next: BattleEnemy = null
		var best_distance := INF
		for candidate in world.enemies:
			if not candidate.alive() or candidate.id == &"" or seen.has(candidate.id) or not BattleSession.enemy_in_combat(candidate): continue
			var distance := ((candidate.position - origin) * BattleSession.ARENA_SIZE).length_squared()
			if not distance <= radius_squared: continue
			if next == null or distance < best_distance or (distance == best_distance and str(candidate.id) < str(next.id)):
				next = candidate
				best_distance = distance
		if next == null: break
		seen[next.id] = true
		var lot := ledger.earn(_tx("extra-chain"), source, build.identity(), SpellLot.Kind.POWER, amount, &"chain", DamagePacket.Element.LIGHTNING)
		var effect := _effect(lot, &"storm_chain", next.id, origin, build)
		effect.depth = 1
		contact(effect, next, origin)
		_conduct(next)
		origin = next.position
		amount = int(amount * (0.91 if build.asset_stacks(&"R033") > 0 else 0.76))


func _conduct(target: BattleEnemy) -> void:
	if not target.alive(): return
	if build.asset_stacks(&"R034") <= 0 and build.asset_stacks(&"R046") <= 0: return
	var count: int = _conduct_counts.get(target.id, 0) + 1
	var interval := roundi(build.relic_number(&"R034" if build.asset_stacks(&"R034") > 0 else &"R046", &"interval"))
	_conduct_counts[target.id] = count % interval
	if count < interval: return
	var radius := 190.0 if build.asset_stacks(&"R046") > 0 else 125.0
	radius += build.modifier(&"overload_radius")
	var damage := int((34 + 8 * (world.chapter - 1)) * Q * damage_multiplier() * (1.0 + build.relic_number(&"R033", &"overload_pct") / 100.0))
	damage = roundi(damage * RelicParameters.ratio(build, &"overload_pct"))
	if build.asset_stacks(&"R046") > 0: _pull(target.position, radius + 50.0, 380.0)
	if build.asset_stacks(&"R034") > 0: clear_radius(target.position, 135.0, &"overload")
	_deal(target, damage, &"overload", target.position, 1)
	_burst(target.position, radius, int(damage * 0.7), &"overload", target.id, 1)


func _fill_spirit_queue() -> void:
	var capacity := (BattleSession.SPIRIT_CAPACITY if build.book() == &"spirit" else 1) + build.value(&"summon_capacity")
	while spirit_attacks.size() < capacity * 2:
		var amount := int((12 + 3 * build.asset_stacks(&"R005")) * Q * (1.0 + 0.3 * build.asset_stacks(&"R035")))
		var lot := ledger.earn(_tx("spirit-strike"), &"spirit", build.identity(), SpellLot.Kind.POWER, amount, &"spirit", DamagePacket.Element.PAPER)
		var effect := _effect(lot, &"spirit_blade", world.spirit_focus, world.player_position, build)
		effect.expires_at = clock + world.spirit_time
		effect.depth = 1
		spirit_attacks.append(effect)


func on_player_hurt() -> void:
	_combo = int(_combo * 0.62)
	_perfect_words = 0
	_save_counters()


func on_enemy_death(target: BattleEnemy, _kind: StringName, depth: int = 0) -> void:
	if _settled_deaths.has(target.id): return
	_settled_deaths[target.id] = true
	if target.vulnerability > 0 and build.asset_stacks(&"P004") > 0:
		for next in _nearby(target.position, build.relic_number(&"P004", &"radius"), target.id).slice(0, roundi(build.relic_number(&"P004", &"targets"))):
			add_mark(next, mini(target.vulnerability, roundi(build.relic_number(&"P004", &"mark"))))
	add_shield(build.modifier(&"kill_shield") * Q)
	world.add_resonance(build.modifier(&"kill_resonance") * Q)
	if target.burn > 10:
		add_shield(build.modifier(&"burn_kill_shield") * Q)
		world.add_resonance(build.modifier(&"burn_kill_resonance") * Q)
	if target.vulnerability > 0: world.add_resonance(build.modifier(&"mark_kill_resonance") * Q)
	depth = _pending_death_depth.get(target.id, depth)
	if build.asset_stacks(&"R011") > 0 and world.typing.target_id == target.id and world.typing.progress > 0: add_shield(roundi(Q * build.relic_number(&"R011", &"shield")))
	if target.burn > 10 and build.asset_stacks(&"R052") > 0 and target.burn_depth < 2:
		for next in _nearby(target.position, 130.0 + build.relic_number(&"R052", &"radius") + build.modifier(&"burn_spread_radius"), target.id).slice(0, 2 + roundi(build.relic_number(&"R052", &"targets")) + build.modifier(&"burn_spread_targets")):
			add_burn(next, mini(70, target.burn), target.burn_root, target.burn_depth + 1)
	for status in ongoing.duplicate():
		if status.target_id != target.id: continue
		if status.effect.kind == &"flame_burn" and build.asset_stacks(&"R052") > 0 and status.spread_depth < 2:
			for next in _nearby(target.position, 130.0 + build.relic_number(&"R052", &"radius"), target.id).slice(0, 2 + roundi(build.relic_number(&"R052", &"targets"))):
				_burn(next, mini(2, status.stacks), status.spread_depth + 1)
		retire(status.effect)
		ongoing.erase(status)
	if target.frozen_time > 0.0 and (build.book() == &"frost" or build.asset_stacks(&"R004") > 0) and depth < 3:
		_burst(target.position, 100.0 + build.relic_number(&"R004", &"radius") + build.relic_number(&"R023", &"radius") + build.modifier(&"shatter_radius"), int((28 + build.relic_number(&"R004", &"damage")) * Q * damage_multiplier() * RelicParameters.ratio(build, &"shatter_pct")), &"frost_shatter", target.id, depth + 1, true)
		if build.asset_stacks(&"R044") > 0 and depth == 0:
			for next in _nearby(target.position, 3000.0, target.id).slice(0, roundi(build.relic_number(&"R044", &"fragments"))):
				var lot := ledger.earn(_tx("avalanche"), &"R044", build.identity(), SpellLot.Kind.POWER, int(26 * Q * damage_multiplier()), &"frost_fragment", DamagePacket.Element.ICE)
				var effect := _effect(lot, &"frost_fragment", next.id, target.position, build)
				effect.depth = 2
				world.effects.append(effect)


func counter_contact(target: BattleEnemy) -> void:
	_apply_cold(target, build.modifier(&"parry_cold") * Q, build)
	if build.modifier(&"parry_burn") > 0: add_burn(target, build.modifier(&"parry_burn"), _tx("parry-burn"), 1)
	if build.modifier(&"parry_shock") > 0: add_shock(target, build.modifier(&"parry_shock"))
	if build.modifier(&"parry_mark") > 0: add_mark(target, build.modifier(&"parry_mark"))
	if build.asset_stacks(&"F017") > 0: _region(target.position, build.relic_number(&"F017", &"radius"), build.relic_number(&"F017", &"duration"), &"cold_field")
	if build.asset_stacks(&"A017") > 0: _region(target.position, build.relic_number(&"A017", &"radius"), build.relic_number(&"A017", &"duration"), &"fire_field")
	if build.asset_stacks(&"T016") > 0: _chain(target, roundi(Q * build.relic_number(&"T016", &"damage") * damage_multiplier()), roundi(build.relic_number(&"T016", &"targets")), &"T016")
	if build.asset_stacks(&"R057") == 0: return
	match build.book():
		&"frost": _apply_cold(target, 100 * Q, build)
		&"flame": _burn(target)
		&"storm":
			add_shock(target, 36)
			_conduct(target)
		&"spirit":
			add_mark(target, 20)
			world.spirit_focus = target.id
			world.spirit_time = minf(18.0, world.spirit_time + 2.0)
			world._summon_spirit()


func book_cast_count() -> int:
	return _book_cast_count


func next_empowered() -> bool:
	return (_book_cast_count + 1) % 3 == 0


func _record_word(fact: WordCompletion) -> void:
	_cast_count += 1
	_combo += 1
	_perfect_words = _perfect_words + 1 if fact.mistakes == 0 else 0
	if fact.fully_manual():
		_manual_words += 1
		if build.asset_stacks(&"R017") > 0 and _manual_words % roundi(build.relic_number(&"R017", &"interval")) == 0: _assist_tokens += 1
	_save_counters()


func _after_cast(fact: WordCompletion) -> void:
	if _cast_count % 6 == 0: heal(build.modifier(&"word_heal") * Q)
	if _cast_count % 5 == 0: add_shield(build.modifier(&"word_shield") * Q)
	if build.asset_stacks(&"R013") > 0 and _cast_count % roundi(build.relic_number(&"R013", &"interval")) == 0: heal(roundi(Q * build.relic_number(&"R013", &"heal")))
	if build.asset_stacks(&"R039") > 0 and _cast_count % roundi(build.relic_number(&"R039", &"interval")) == 0: add_shield(roundi(Q * build.relic_number(&"R039", &"shield")))
	if build.asset_stacks(&"R020") > 0 and _cast_count % roundi(build.relic_number(&"R020", &"interval")) == 0:
		clear_radius(world.player_position, build.relic_number(&"R020", &"radius"), &"R020")
		_burst(world.player_position, build.relic_number(&"R020", &"radius"), roundi(Q * build.relic_number(&"R020", &"damage")), &"R020")
	if build.asset_stacks(&"R029") > 0 and fact.mistakes == 0 and _perfect_words % roundi(build.relic_number(&"R029", &"interval")) == 0:
		clear_radius(world.player_position, build.relic_number(&"R029", &"radius"), &"R029")
		_burst(world.player_position, build.relic_number(&"R029", &"radius"), roundi(Q * build.relic_number(&"R029", &"damage")), &"R029")


func on_pickup_completed(pickup: BattlePickup, _reflected: int, fact: WordCompletion, paid: Dictionary) -> void:
	_length_class = 0
	_record_word(fact)
	heal(build.modifier(&"pickup_heal") * Q)
	work_bank.append(ledger.earn(fact.attempt_id, build.book(), build.identity(), SpellLot.Kind.WORK, int(paid.work_q), &"active-completion"))
	if pickup.kind == &"rune":
		disarm_burst(pickup.position, 12 * Q, 520.0)
	else:
		_burst(pickup.position, 270.0, 95 * Q, &"ink_bottle")
	_after_cast(fact)


func disarm_burst(at: Vector2, base_damage_q: int, radius: float = 520.0) -> int:
	var multiplier := on_disarm()
	var targets := _nearby(at, radius)
	for target in targets:
		_apply_cold(target, (100 if build.book() == &"frost" else 45 * build.asset_stacks(&"R003")) * Q, build)
		_impulse(target, at, 240.0)
		_deal(target, int(base_damage_q * multiplier), &"disarm", at, 0)
	return targets.size()


func on_disarm() -> float:
	if build.asset_stacks(&"R008") == 0: return 1.0
	_reflection_boost = true
	_save_counters()
	return 1.0 + build.relic_number(&"R008", &"damage_pct") / 100.0


func rescue_burst() -> void:
	_burst(world.player_position, 1000.0, 80 * Q, &"rescue", &"", 1)


func _save_counters() -> void:
	run.relic_counters = {"casts": _cast_count, "book": _book_cast_count, "combo": _combo, "perfect": _perfect_words, "manual": _manual_words, "assist": _assist_tokens, "boost": int(_reflection_boost), "length_class": _length_class, "dodge_script": int(_dodge_script_ready)}


func _tx(kind: String) -> String:
	return "%s:%s:%s" % [ledger.room_id, kind, _next()]


func body_contact(a: BattleEnemy, b: BattleEnemy) -> void:
	var relative := (a.velocity - b.velocity + a.impulse - b.impulse).length()
	if relative <= 185.0 or a.counter_push_time > 0.0 or b.counter_push_time > 0.0: return
	var key := str(a.id) + ":" + str(b.id) if str(a.id) < str(b.id) else str(b.id) + ":" + str(a.id)
	if clock < _collision_times.get(key, -INF): return
	_collision_times[key] = clock + 0.4
	_deal(b, int((7.0 + relative * 0.018) * Q * (2.0 if build.asset_stacks(&"R025") > 0 else 1.0)), &"collision", a.position, 1)




func retarget(_effect_value: BattleEffect, origin: Vector2, excluded: PackedStringArray) -> BattleEnemy:
	var best: BattleEnemy = null
	var best_distance := INF
	for candidate in world.enemies:
		if not candidate.alive() or candidate.id == &"" or str(candidate.id) in excluded or not BattleSession.enemy_in_combat(candidate): continue
		var distance := ((candidate.position - origin) * BattleSession.ARENA_SIZE).length_squared()
		if not distance <= 1200.0 * 1200.0: continue
		if best == null or distance < best_distance or (distance == best_distance and str(candidate.id) < str(best.id)):
			best = candidate
			best_distance = distance
	return best
