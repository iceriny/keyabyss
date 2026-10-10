class_name SpellRuntime
extends RefCounted
## Annotated integer divisions truncate paid shares; ceiling fees and split remainders stay explicit.
## Rules operate on paid lots. BattleSession supplies the world and fixed clock.

const Q := SpellResourceLedger.Q
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


func _init(session: BattleSession, combat_build: CompiledBuild, state: RunCombatState) -> void:
	world = session
	build = combat_build
	run = state
	ledger = session.ledger
	_cast_count = int(state.relic_counters.get("casts", 0))
	_book_cast_count = int(state.relic_counters.get("book", 0))
	_combo = int(state.relic_counters.get("combo", 0))
	_perfect_words = int(state.relic_counters.get("perfect", 0))
	_manual_words = int(state.relic_counters.get("manual", 0))
	_assist_tokens = int(state.relic_counters.get("assist", 0))
	_reflection_boost = int(state.relic_counters.get("boost", 0)) > 0


func install(next_build: CompiledBuild) -> void:
	build = next_build


func assemble(paid: Dictionary, fact: WordCompletion, target: BattleEnemy, empowered: bool) -> BattleEffect:
	_book_cast_count += 1
	_record_word(fact)
	var multiplier := damage_multiplier() * (1.0 + mini(10, _combo) * (0.05 if build.asset_stacks(&"R030") > 0 else 0.025))
	if fact.mistakes == 0: multiplier *= 1.08 + 0.35 * build.asset_stacks(&"R016")
	if fact.word.length() <= 4 and build.asset_stacks(&"R014") > 0:
		multiplier *= 1.0 + 0.6 * build.asset_stacks(&"R014")
		world.dodge_charges = minf(2.0 + build.value(&"dodge_capacity"), world.dodge_charges + 0.1)
	if fact.word.length() >= 7 and build.asset_stacks(&"R015") > 0:
		multiplier *= 1.0 + 0.75 * build.asset_stacks(&"R015")
		clear_radius(target.position, 105.0)
	if build.asset_stacks(&"R022") > 0 and _cast_count % 4 == 0: multiplier *= 2.0
	if _reflection_boost:
		multiplier *= 2.0
		_reflection_boost = false
	var root := fact.attempt_id
	var base_power := int(fact.manual_positions.size() * build.value(&"base_power_q", 12 * Q) * multiplier)
	if build.book() == &"storm": base_power = roundi(base_power * 0.9)
	var coefficient: float = {&"spirit": 0.1, &"flame": 0.67, &"frost": 1.35 if empowered else 0.9, &"storm": 1.0}[build.book()]
	var power := ledger.earn(root, build.book(), build.identity(), SpellLot.Kind.POWER, roundi(base_power * coefficient), &"assembly", ELEMENTS[build.book()])
	var effect := _effect(power, KINDS[build.book()], target.id, world.player_position, build)
	effect.base_power_q = base_power
	effect.manual_count = fact.manual_positions.size()
	effect.empowered = empowered or (build.book() == &"storm" and world.ultimate_time > 0.0)
	effect.word_owner = fact.target_id
	work_bank.append(ledger.earn(root, build.book(), build.identity(), SpellLot.Kind.WORK, int(paid.work_q), &"active-completion"))
	if build.book() == &"spirit" or build.asset_stacks(&"R005") > 0 or build.asset_stacks(&"R035") > 0:
		world.spirit_focus = target.id
		_spirit_letters += fact.manual_positions.size()
		while _spirit_letters >= 5:
			_spirit_letters -= 5
			world._summon_spirit()
		world.spirit_time = 8.0 + build.asset_stacks(&"R005") + 2.0 * build.asset_stacks(&"R035")
	_after_cast(fact)
	if build.asset_stacks(&"R054") > 0 and empowered and build.book() == &"flame": add_shield(5 * Q * build.asset_stacks(&"R054"))
	dispatch(effect, target)
	_configure_shape(effect)
	if build.asset_stacks(&"R006") > 0 and _cast_count % 3 == 0: _periodic_copy(effect)
	_save_counters()
	return effect


func dispatch(effect: BattleEffect, target: BattleEnemy) -> void:
	if effect.dispatched: return
	effect.dispatched = true
	if effect.empowered and effect.kind == &"spirit_mark":
		world.command_spirit_cross(effect, target)


func contact(effect: BattleEffect, target: BattleEnemy, origin: Vector2, primary: bool = true, contact_at: Vector2 = Vector2.INF) -> void:
	if effect.lot == null or effect.lot.amount_q <= 0 or not target.alive() or effect.expires_at <= clock: return
	var direct := primary and (effect.word_owner != &"" or effect.kind in [&"frost_spear", &"flame_burst", &"spirit_mark"])
	var amount := effect.lot.amount_q
	if effect.primary_share_q > 0:
		amount = effect.primary_share_q
	var base_amount := amount
	var factor := 1.0
	if effect.kind in [&"spirit_blade", &"spirit_cross"] and world.book_id == &"spirit" and world.ultimate_time > 0.0:
		factor *= 1.5
	if effect.kind == &"storm_arc" and target.shock > 30:
		target.shock -= 30
		effect.jumps += 1
		effect.arc_charge += 0.25
	if effect.kind == &"storm_arc":
		factor *= effect.arc_charge
	if target.frozen_time > 0.0:
		factor *= 1.18 + 0.4 * effect.build.asset_stacks(&"R031")
		if effect.empowered and effect.kind == &"frost_spear": factor *= 1.25
	if target.boss and effect.build.asset_stacks(&"R027") > 0: factor *= 1.15
	if factor > 1.0:
		var bonus := ledger.earn(effect.lot.root_id, StringName(_tx("hit-relic")), effect.build.identity(), SpellLot.Kind.POWER, int(amount * (factor - 1.0)), &"hit", ELEMENTS[effect.build.book()])
		ledger.aggregate(_tx("hit-join"), effect.lot, bonus)
		amount = int(amount * factor)
	if effect.kind in [&"frost_spear", &"frost_fragment", &"frost_ultimate"]:
		_apply_cold(target, (roundi((55.0 if effect.empowered else 35.0) * effect.manual_count / 5.0) + 10 * effect.build.asset_stacks(&"R003")) * Q, effect.build)
	elif effect.build.asset_stacks(&"R003") > 0:
		_apply_cold(target, 45 * Q * effect.build.asset_stacks(&"R003"), effect.build)
	if effect.kind in [&"flame_burst", &"flame_meteor", &"flame_ultimate"]:
		add_burn(target, roundi(70.0 * effect.manual_count / 5.0), effect.lot.root_id, effect.depth)
	if direct and effect.build.asset_stacks(&"R028") > 0: _status(target, &"corrosion", 1, 0)
	if effect.kind == &"spirit_mark":
		target.vulnerability = mini(127, target.vulnerability + 4 * effect.manual_count)
		target.mark_grace = 1.5
		target.marked_time = 8.0
	if effect.kind == &"storm_arc":
		add_shock(target, roundi(36.0 * effect.manual_count / 5.0))
	_pending_death_depth[target.id] = effect.depth
	var packet := ledger.spend(_tx("hit"), effect.lot, mini(amount, effect.lot.amount_q))
	_commit_damage(target, packet, effect.kind, origin, effect.empowered, contact_at, direct)
	if effect.kind == &"storm_arc" and effect.arc_index < 3 and world.ultimate_time > 0.0 and effect.build.asset_stacks(&"R047") > 0:
		add_shield(2 * Q)
	_impulse(target, origin, (530.0 if effect.empowered else 300.0) if effect.kind == &"frost_spear" else 150.0)
	if direct and effect.build.asset_stacks(&"R027") > 0 and target.alive() and not target.boss and target.hp_q < target.max_hp_q * 0.18:
		_deal(target, target.hp_q, &"R027", target.position, 0)
	if direct and effect.build.asset_stacks(&"R007") > 0:
		_burst(target.position, 90.0 + 25.0 * build.asset_stacks(&"R023"), int(base_amount * factor * 0.35 * build.asset_stacks(&"R007")), &"R007", target.id, 1)
	if direct and effect.build.asset_stacks(&"R026") > 0: _pull(target.position, 190.0, 260.0)
	if direct and build.asset_stacks(&"R032") > 0:
		_region(target.position, (114.0 if effect.empowered else 75.0) + (35.0 if build.asset_stacks(&"R032") > 0 else 0.0), 2.6 + (3.0 if build.asset_stacks(&"R032") > 0 else 0.0), &"cold_field")
	elif direct and effect.kind == &"frost_spear":
		world.event_committed.emit({"kind": &"frost_ground", "at": target.position, "radius": 114.0 if effect.empowered else 75.0, "duration": 2.6})
	if effect.empowered and effect.kind == &"frost_spear" and build.asset_stacks(&"R045") > 0:
		for enemy in _nearby(target.position, 155.0): _apply_cold(enemy, 100 * Q, build)
	if effect.kind == &"flame_burst" and effect.empowered:
		var radius := (115.0 if effect.empowered else 55.0) + 25.0 * build.asset_stacks(&"R053")
		for enemy in _nearby(target.position, radius, target.id):
			add_burn(enemy, 35, effect.lot.root_id, effect.depth + 1)
			_deal(enemy, int(base_amount * (0.5 if effect.empowered else 0.22)), &"flame_splash", target.position, effect.depth + 1)
		_deal(target, int(base_amount * 0.5), &"flame_splash", target.position, effect.depth + 1)
		_region(target.position, radius, 3.2, &"fire_field")
	if effect.kind == &"storm_arc" and effect.empowered:
		var radius := 125.0 + 25.0 * effect.build.asset_stacks(&"R023")
		for enemy in _nearby(target.position, radius, target.id):
			add_shock(enemy, 30)
			_deal(enemy, roundi(effect.base_power_q * 0.3), &"storm_burst", target.position, 1)
		world.event_committed.emit({"kind": &"field", "source": &"overload", "at": target.position, "radius": radius})
	if effect.kind == &"storm_arc" or (direct and build.asset_stacks(&"R034") > 0): _conduct(target)
	if effect.kind == &"storm_arc":
		effect.visited.append(str(target.id))
		_continue_arc(effect, target)
	elif direct and build.book() != &"storm" and build.asset_stacks(&"R002") > 0:
		_chain(target, int(base_amount * 0.45), build.asset_stacks(&"R002"))
	if not target.alive(): on_enemy_death(target, effect.kind, effect.depth)
	effect.damage_q = effect.lot.amount_q
	if effect.applications > 1: effect.applications -= 1


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
	var amount := roundi(60 * Q * 0.12 * damage_multiplier() * (1.0 + 0.25 * build.asset_stacks(&"R005") + 0.3 * build.asset_stacks(&"R035")))
	var lot := ledger.earn(_tx("spirit-strike"), &"spirit", build.identity(), SpellLot.Kind.POWER, amount, &"spirit", DamagePacket.Element.PAPER)
	var effect := _effect(lot, &"spirit_blade", target.id, position, build)
	effect.depth = 1
	return effect


func clear_ultimate_threats(_effect_value: BattleEffect, origin: Vector2) -> void:
	clear_radius(origin, 650.0)


func consume_assist() -> bool:
	if not assist_ready(): return false
	_assist_tokens -= 1
	_save_counters()
	return true


func assist_ready() -> bool:
	return build.has(&"assist") and _assist_tokens > 0


func finish(reason: StringName) -> RoomCombatResult:
	_save_counters()
	var result := RoomCombatResult.new()
	result.room_id = ledger.room_id
	result.reason = reason
	result.actual_damage_q = actual_damage_q
	result.asset_claims = run.asset_claims.duplicate()
	run.hp_q = world.player_hp_q
	run.resonance_q = world.resonance_q
	run.reserve = []
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
	result.raw_spent_q = ledger.raw_spent_q
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
		configure_frost_hits(effect, 2 + (2 if effect.empowered else 0) + (2 if effect.build.asset_stacks(&"R044") > 0 else 0))
	if effect.kind == &"storm_arc":
		effect.arc_base_hits = 3 + effect.build.asset_stacks(&"R002") + 2 * effect.build.asset_stacks(&"R046")
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
	target.cold = mini(127, target.cold + roundi(float(amount) / Q * (1.0 + float(snapshot.value(&"cold_efficiency_q")) / Q)))
	_try_freeze(target)


func _try_freeze(target: BattleEnemy) -> void:
	if target.cold <= 90 or target.frozen_time > 0.0 or target.freeze_cooldown > 0.0: return
	target.cold -= 60
	target.frozen_time = 0.45 if target.boss else 0.9 + 0.15 * build.asset_stacks(&"R003")
	freezes += 1
	world.event_committed.emit({"kind": &"freeze", "at": target.position, "enemy": target.id})


func add_burn(target: BattleEnemy, points: float, root: String, depth: int = 0) -> void:
	if not target.alive(): return
	target.burn_remainder += points * (1.0 + 0.2 * build.asset_stacks(&"R051"))
	var gained := floori(target.burn_remainder)
	target.burn_remainder -= gained
	target.burn = clampi(target.burn + gained, 0, 127)
	target.burn_root = root
	target.burn_depth = depth
	target.burn_time = maxf(0.0, (target.burn - 10) / 50.0)


func add_shock(target: BattleEnemy, points: int) -> void:
	if not target.alive(): return
	target.shock = clampi(target.shock + points, 0, 127)
	target.shock_grace = 1.5


func _advance_states(delta: float) -> void:
	for enemy in world._living():
		var frozen_before := enemy.frozen_time
		enemy.frozen_time = maxf(0.0, frozen_before - delta)
		if frozen_before > 0.0 and enemy.frozen_time == 0.0:
			enemy.freeze_cooldown = 3.0 if enemy.boss else 1.0
		elif frozen_before <= 0.0:
			enemy.freeze_cooldown = maxf(0.0, enemy.freeze_cooldown - delta)
		enemy.cold_remainder += delta * 12.0
		var cold_loss := floori(enemy.cold_remainder)
		enemy.cold_remainder -= cold_loss
		enemy.cold = maxi(0, enemy.cold - cold_loss)
		var mark_decay := maxf(0.0, delta - enemy.mark_grace)
		enemy.mark_grace = maxf(0.0, enemy.mark_grace - delta)
		enemy.vulnerability_remainder += mark_decay * 12.0
		var mark_loss := floori(enemy.vulnerability_remainder)
		enemy.vulnerability_remainder -= mark_loss
		enemy.vulnerability = maxi(0, enemy.vulnerability - mark_loss)
		enemy.marked_time = maxf(0.0, enemy.marked_time - delta)
		var shock_decay := maxf(0.0, delta - enemy.shock_grace)
		enemy.shock_grace = maxf(0.0, enemy.shock_grace - delta)
		enemy.shock_remainder += shock_decay * 8.0
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
			add_burn(enemy, 40.0 * (1.0 - pow(0.5, layers)) * delta, "fire-field", 1)
		if cold_rate > 0.0:
			enemy.cold_gain_remainder += cold_rate * delta
			var gain := floori(enemy.cold_gain_remainder)
			enemy.cold_gain_remainder -= gain
			if gain > 0: _apply_cold(enemy, gain * Q, build)
		_try_freeze(enemy)
		if enemy.burn > 10:
			enemy.burn_clock += delta
			while enemy.burn_clock >= 0.1 and enemy.burn > 10 and enemy.alive():
				enemy.burn_clock -= 0.1
				enemy.burn = maxi(0, enemy.burn - 5)
				var damage := roundi(6 * Q * damage_multiplier() * (1.0 + 0.3 * build.asset_stacks(&"R050")) * (1.35 if build.asset_stacks(&"R056") > 0 else 1.0))
				_deal(enemy, damage, &"flame_burn", enemy.position, enemy.burn_depth + 1, enemy.burn_root)
		else:
			enemy.burn_clock = 0.0
		enemy.burn_time = maxf(0.0, (enemy.burn - 10) / 50.0)


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
	var extension := 100.0 * effect.build.asset_stacks(&"R023")
	for next in world.enemies:
		if not next.alive() or next.id == &"" or not BattleSession.enemy_in_combat(next): continue
		if str(next.id) in effect.visited: continue
		var offset := (next.position - origin) * BattleSession.ARENA_SIZE
		var distance := offset.length_squared()
		if not distance <= 3000.0 * 3000.0: continue
		var reach := (530.0 if next.shock > 30 else 265.0) + extension
		if next.shock <= 60 and offset.length() > reach: continue
		if best == null or distance < best_distance or (distance == best_distance and str(next.id) < str(best.id)):
			best = next
			best_distance = distance
	return best


func _continue_arc(effect: BattleEffect, target: BattleEnemy) -> void:
	if effect.jumps <= 0: return
	var next := arc_target(effect, target.position)
	if next == null: return
	var floor_ratio := 0.35 if effect.build.asset_stacks(&"R033") > 0 else 0.2
	var ratio := maxf(floor_ratio, 1.0 - (1.0 - floor_ratio) * (effect.arc_index + 1) / maxi(1, effect.arc_base_hits - 1))
	var retained := roundi(effect.base_power_q * ratio)
	var lot := ledger.earn(effect.lot.root_id, StringName(_tx("chain")), effect.build.identity(), SpellLot.Kind.POWER, retained, &"chain", DamagePacket.Element.LIGHTNING)
	var arc := _effect(lot, &"storm_arc", next.id, target.position, effect.build)
	arc.shaped = true
	arc.jumps = effect.jumps - 1
	arc.visited = effect.visited.duplicate()
	arc.delay = 0.08
	arc.depth = 1
	arc.manual_count = effect.manual_count
	arc.base_power_q = effect.base_power_q
	arc.arc_base_hits = effect.arc_base_hits
	arc.arc_index = effect.arc_index + 1
	arc.arc_charge = effect.arc_charge
	world.effects.append(arc)












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
	# Truncate to whole fixed-point units without converting the ledger to float.
	@warning_ignore("integer_division")
	var output := ledger.earn(template.lot.root_id, &"R006", template.build.identity(), SpellLot.Kind.POWER, template.damage_q * 665 / Q, &"copy", ELEMENTS[template.build.book()])
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
	if boosted: add_shield(int(0.6 * Q))


func on_dodge(origin: Vector2, destination: Vector2) -> void:
	if build.asset_stacks(&"R041") > 0: world.precision_slow_remaining = 1.5
	if build.asset_stacks(&"R037") > 0:
		_pull(origin, 190.0, 260.0)
		_region(origin, 190.0, 1.2, &"gravity_field")
	if build.book() == &"flame":
		_region(origin, 60.0 + 20.0 * build.asset_stacks(&"R055"), 2.0 + build.asset_stacks(&"R055"), &"fire_field")
	elif build.book() == &"frost":
		_region(origin, 105.0, 3.0, &"ice_mist")
	elif build.book() == &"spirit":
		_region(origin, 26.0, 4.0, &"paper_crane")
	elif build.book() == &"storm":
		var start := origin * BattleSession.ARENA_SIZE
		var end := destination * BattleSession.ARENA_SIZE
		for enemy in world._living():
			if not BattleSession.enemy_in_combat(enemy): continue
			var point := enemy.position * BattleSession.ARENA_SIZE
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, start, end)) <= 28.0 + enemy.radius:
				add_shock(enemy, 30)
				_deal(enemy, roundi(18 * Q * damage_multiplier()), &"storm_dodge", origin, 1)
		world.event_committed.emit({"kind": &"storm_path", "from": origin, "at": destination})


func intercept_crane(threat: BattleThreat) -> bool:
	for field in fields:
		if field.effect.kind != &"paper_crane" or field.expires_at <= clock: continue
		var center := field.center * BattleSession.ARENA_SIZE
		if CombatGeometry.sweep_discs(threat.previous_position * BattleSession.ARENA_SIZE, threat.position * BattleSession.ARENA_SIZE, center, center, threat.radius + field.radius) == INF: continue
		var target := world.enemy_by_id(threat.source_id)
		if target == null or not target.alive(): target = world._nearest_living(field.center)
		if target != null: _deal(target, roundi(24 * Q * damage_multiplier()), &"paper_crane", field.center, 1)
		world.event_committed.emit({"kind": &"spirit_intercept", "at": field.center})
		fields.erase(field)
		return true
	return false










func _next() -> int:
	_serial += 1
	return _serial


func on_dodge_landed(at: Vector2) -> void:
	if build.asset_stacks(&"R010") > 0:
		clear_radius(at, 135.0)
		for enemy in _nearby(at, 180.0): _impulse(enemy, at, 210.0)
	if build.asset_stacks(&"R037") > 0:
		clear_radius(at, 75.0)
		for enemy in _nearby(at, 115.0): _impulse(enemy, at, 180.0)


func damage_multiplier() -> float:
	var factor := pow(1.25, build.asset_stacks(&"R001"))
	if build.asset_stacks(&"R036") > 0 and world.player_hp_q < world.player_max_hp_q * 0.4: factor *= 1.5
	if build.asset_stacks(&"R042") > 0: factor *= 1.4
	if build.asset_stacks(&"R043") > 0: factor *= 1.45
	return factor


func add_shield(amount: int) -> void:
	run.shield_q = mini(60 * Q, run.shield_q + amount)


func clear_radius(at: Vector2, radius: float) -> void:
	var write_index := 0
	for read_index in world.threats.size():
		var threat := world.threats[read_index]
		if not threat.reflected and ((threat.position - at) * BattleSession.ARENA_SIZE).length() <= radius: continue
		world.threats[write_index] = threat
		write_index += 1
	world.threats.resize(write_index)


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


func pull_environment(at: Vector2, radius: float, force: float, pulse: bool = true) -> void:
	# Both allegiances use the same physical attraction; rendering never decides
	# trajectories. Keep the existing swept collision and homing rules downstream.
	for projectile in world.projectiles:
		var offset := (at - projectile.position) * BattleSession.ARENA_SIZE
		if offset.length_squared() < radius * radius:
			projectile.attraction_impulse += offset.normalized() * force
	for threat in world.threats:
		var offset := (at - threat.position) * BattleSession.ARENA_SIZE
		if offset.length_squared() < radius * radius:
			threat.velocity += offset.normalized() * force
	if pulse:
		world.event_committed.emit({"kind": &"gravity_pull", "at": at, "radius": radius, "force": force})


func _impulse(target: BattleEnemy, at: Vector2, force: float) -> void:
	if target.boss or target.speed == 0.0: return
	target.impulse += (target.position - at).normalized() * force * (1.0 + 0.6 * build.asset_stacks(&"R025")) / target.mass


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
	var lifetime := 3.0 + build.asset_stacks(&"R051") if kind == &"flame_burn" else 4.0
	var pulses := int(lifetime / interval)
	var per_pulse := int(6 * Q * damage_multiplier() * (1.0 + 0.3 * build.asset_stacks(&"R050"))) if kind == &"flame_burn" else 8 * Q * build.asset_stacks(&"R028")
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


func _chain(target: BattleEnemy, amount: int, count: int) -> void:
	var seen: Dictionary[StringName, bool] = {target.id: true}
	var origin := target.position
	var radius := 265.0 + 100.0 * build.asset_stacks(&"R023")
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
		var lot := ledger.earn(_tx("extra-chain"), &"R002", build.identity(), SpellLot.Kind.POWER, amount, &"chain", DamagePacket.Element.LIGHTNING)
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
	_conduct_counts[target.id] = count % 3
	if count < 3: return
	var radius := 190.0 if build.asset_stacks(&"R046") > 0 else 125.0
	var damage := int((34 + 8 * (world.chapter - 1)) * Q * damage_multiplier() * (1.0 + 0.35 * build.asset_stacks(&"R033")))
	if build.asset_stacks(&"R046") > 0: _pull(target.position, radius + 50.0, 380.0)
	if build.asset_stacks(&"R034") > 0: clear_radius(target.position, 135.0)
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
	depth = _pending_death_depth.get(target.id, depth)
	if build.asset_stacks(&"R011") > 0 and world.typing.target_id == target.id and world.typing.progress > 0: add_shield(10 * Q)
	if target.burn > 10 and build.asset_stacks(&"R052") > 0 and target.burn_depth < 2:
		for next in _nearby(target.position, 130.0 + 25.0 * build.asset_stacks(&"R052"), target.id).slice(0, 2 + build.asset_stacks(&"R052")):
			add_burn(next, mini(70, target.burn), target.burn_root, target.burn_depth + 1)
	for status in ongoing.duplicate():
		if status.target_id != target.id: continue
		if status.effect.kind == &"flame_burn" and build.asset_stacks(&"R052") > 0 and status.spread_depth < 2:
			for next in _nearby(target.position, 130.0 + 25.0 * build.asset_stacks(&"R052"), target.id).slice(0, 2 + build.asset_stacks(&"R052")):
				_burn(next, mini(2, status.stacks), status.spread_depth + 1)
		retire(status.effect)
		ongoing.erase(status)
	if target.frozen_time > 0.0 and (build.book() == &"frost" or build.asset_stacks(&"R004") > 0) and depth < 3:
		_burst(target.position, 100.0 + 20.0 * build.asset_stacks(&"R004") + 25.0 * build.asset_stacks(&"R023"), int((28 + 18 * build.asset_stacks(&"R004")) * Q * damage_multiplier()), &"frost_shatter", target.id, depth + 1, true)
		if build.asset_stacks(&"R044") > 0 and depth == 0:
			for next in _nearby(target.position, 3000.0, target.id).slice(0, 6):
				var lot := ledger.earn(_tx("avalanche"), &"R044", build.identity(), SpellLot.Kind.POWER, int(26 * Q * damage_multiplier()), &"frost_fragment", DamagePacket.Element.ICE)
				var effect := _effect(lot, &"frost_fragment", next.id, target.position, build)
				effect.depth = 2
				world.effects.append(effect)


func counter_contact(target: BattleEnemy) -> void:
	if build.asset_stacks(&"R057") == 0: return
	match build.book():
		&"frost": _apply_cold(target, 100 * Q, build)
		&"flame": _burn(target)
		&"storm":
			add_shock(target, 36)
			_conduct(target)
		&"spirit":
			target.marked_time = 8.0
			target.vulnerability = mini(127, target.vulnerability + 20)
			target.mark_grace = 1.5
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
		if build.asset_stacks(&"R017") > 0 and _manual_words % 4 == 0: _assist_tokens += 1
	_save_counters()


func _after_cast(fact: WordCompletion) -> void:
	if build.asset_stacks(&"R013") > 0 and _cast_count % 6 == 0: heal(4 * Q * build.asset_stacks(&"R013"))
	if build.asset_stacks(&"R039") > 0 and _cast_count % 5 == 0: add_shield(12 * Q * build.asset_stacks(&"R039"))
	if build.asset_stacks(&"R020") > 0 and _cast_count % 5 == 0:
		clear_radius(world.player_position, 220.0)
		_burst(world.player_position, 220.0, 35 * Q, &"R020")
	elif build.asset_stacks(&"R029") > 0 and fact.mistakes == 0 and _perfect_words % 3 == 0:
		clear_radius(world.player_position, 150.0)
		_burst(world.player_position, 150.0, 24 * Q, &"R029")


func on_pickup_completed(pickup: BattlePickup, _reflected: int, fact: WordCompletion, paid: Dictionary) -> void:
	_record_word(fact)
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
	return 1.6


func rescue_burst() -> void:
	_burst(world.player_position, 1000.0, 80 * Q, &"rescue", &"", 1)


func _save_counters() -> void:
	run.relic_counters = {"casts": _cast_count, "book": _book_cast_count, "combo": _combo, "perfect": _perfect_words, "manual": _manual_words, "assist": _assist_tokens, "boost": int(_reflection_boost)}


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
