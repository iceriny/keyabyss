class_name SpellRuntime
extends RefCounted
## Rules operate on paid lots. BattleSession supplies the world and fixed clock.

const Q := SpellResourceLedger.Q
const ELEMENTS := {&"frost": DamagePacket.Element.ICE, &"flame": DamagePacket.Element.FIRE, &"storm": DamagePacket.Element.LIGHTNING, &"spirit": DamagePacket.Element.PAPER}
const KINDS := {&"frost": &"frost_spear", &"flame": &"flame_burst", &"storm": &"storm_arc", &"spirit": &"spirit_mark"}
var ledger: SpellResourceLedger
var build: CompiledBuild
var run: RunCombatState
var world: BattleSession
var stored: Array[StoredSpell] = []
var ongoing: Array[OngoingSpell] = []
var fields: Array[SpellField] = []
var reserve: Array[SpellLot] = []
var spirit_attacks: Array[BattleEffect] = []
var work_bank: Array[SpellLot] = []
var copy_work_bank: Array[SpellLot] = []
var letter_marks: Array[Dictionary] = []
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
var _previous_manual: StringName
var _reserve_targets: Dictionary[StringName, bool] = {}
var _enemy_attacks: Dictionary[String, bool] = {}
var _last_shape: StringName
var _mastery: int = 0
var _input_opportunities: Array[Dictionary] = []
var _letter_rewards: Dictionary[String, Array] = {}
var _dead_inputs: Dictionary[String, bool] = {}
var _rhythm: int = 0
var _last_manual_at: float = -INF
var _counter_reserve: Array[BattleEffect] = []
var _snapshots: Dictionary[String, CompiledBuild] = {}
var _charge_marks: Dictionary[StringName, Array] = {}
var _perfect_saved: Array[SpellLot] = []
var _collision_strikes: Dictionary[StringName, BattleEffect] = {}
var _death_fractures: Dictionary[StringName, Array] = {}


func _init(session: BattleSession, combat_build: CompiledBuild, state: RunCombatState) -> void:
	world = session
	build = combat_build
	_snapshots[build.identity()] = build
	run = state
	ledger = session.ledger
	for lot in state.reserve:
		reserve.append(ledger.import_reserve(lot))
	state.reserve = []


func install(next_build: CompiledBuild) -> void:
	build = next_build
	_snapshots[build.identity()] = build


func assemble(paid: Dictionary, fact: WordCompletion, target: BattleEnemy, empowered: bool) -> BattleEffect:
	var count := fact.manual_positions.size()
	var bonus := build.value(&"power_bonus_q")
	if build.has(&"rhythm") and fact.fully_manual():
		_rhythm = ((_rhythm + 1) % 5 if build.assets().has(&"R022") else mini(4, _rhythm + 1)) if clock - _last_manual_at < 4.0 else 0
		_last_manual_at = clock
		bonus += (104 if _rhythm == 4 else 0) if build.assets().has(&"R022") else _rhythm * 26
	if fact.fully_manual() and fact.mistakes == 0:
		bonus += build.value(&"perfect_bonus_q", 102 if build.has(&"perfect") else 0)
	if build.has(&"low-health") and world.player_hp_q * 3 <= world.player_max_hp_q:
		bonus += 205
	if build.has(&"mastery") and fact.fully_manual():
		var shape := build.mode(&"shape")
		_mastery = mini(5, _mastery + 1) if shape == _last_shape else 0
		_last_shape = shape
		bonus += _mastery * 20
	var root := fact.attempt_id
	var power := ledger.earn(root, build.book(), build.identity(), SpellLot.Kind.POWER, count * build.value(&"base_power_q", 12 * Q) * (Q + bonus) / Q, &"assembly", ELEMENTS[build.book()])
	var work := ledger.earn(root, build.book(), build.identity(), SpellLot.Kind.WORK, int(paid.work_q), &"assembly")
	var effect := _effect(power, KINDS[build.book()], target.id, world.player_position, build)
	effect.empowered = empowered
	effect.word_owner = fact.target_id
	for saved in _perfect_saved: ledger.aggregate(_tx("perfect-use"), power, saved)
	_perfect_saved.clear()
	if build.has(&"perfect") and fact.fully_manual() and fact.mistakes == 0:
		_perfect_saved.append(ledger.transfer(_tx("perfect-save"), power, count * maxi(0, bonus) / 4, &"next-manual"))
	if _letter_rewards.has(fact.attempt_id):
		for reward: SpellLot in _letter_rewards[fact.attempt_id]:
			if build.mode(&"mark-reward-use") == &"K14":
				var copy_work := ledger.convert(_tx("letter-copy-work"), reward, reward.amount_q / 4, SpellLot.Kind.WORK, Q / 12, &"copy-work")
				copy_work_bank.append(copy_work)
			if build.has(&"mark-store") and _storage_occupancy() + _shell_units(build) <= _storage_capacity():
				var fraction := 512 if build.has(&"letter-fixed") else mini(Q, 512 + build.value(&"letter_store_q"))
				var portion := ledger.transfer(_tx("letter-store"), reward, reward.amount_q * fraction / Q, &"letter-page")
				var snapshot: CompiledBuild = _snapshots.get(reward.snapshot_id, build)
				var page := _effect(portion, KINDS[snapshot.book()], effect.target_id, effect.origin, snapshot)
				page.optional_shape = snapshot.has(&"letter-inherit")
				_store(page)
			ledger.aggregate(_tx("letter-join"), power, reward)
		_letter_rewards.erase(fact.attempt_id)
	if fact.fully_manual() and not _counter_reserve.is_empty():
		var returned: BattleEffect = _counter_reserve.pop_front()
		ledger.aggregate(_tx("counter-join"), power, returned.lot)
	# Prepare the shell fee before auxiliary directions compete for the remainder.
	var shell_fee: SpellLot
	if build.has(&"vault") and work.amount_q >= Q:
		shell_fee = ledger.transfer(_tx("shell-fee"), work, Q, &"manufacture")
	if build.has(&"work-convert"):
		var diverted := ledger.convert(_tx("work-convert"), power, power.amount_q / 10, SpellLot.Kind.WORK, Q / 12, &"assembly")
		ledger.aggregate(_tx("work-convert-join"), work, diverted)
	_apply_reserve(effect, target, fact.fully_manual(), count)
	if build.has(&"extract"):
		_extract_previous(effect)
	# Supplies share one work pool. Duplicate rule providers do not add directions.
	var directions: Array[StringName] = []
	if build.has(&"conduct"): directions.append(&"charge")
	if build.has(&"heat") or build.book() == &"flame": directions.append(&"heat")
	if build.has(&"copy"): directions.append(&"copy")
	if build.has(&"summon"): directions.append(&"summon")
	if build.has(&"heal") and world.player_hp_q < world.player_max_hp_q: directions.append(&"heal")
	if build.has(&"trail") or build.has(&"assist") or build.has(&"input-clear") or build.has(&"perfect-clear") or build.has(&"execute") or build.has(&"input-shield") or build.has(&"dodge-clear") or build.has(&"dodge-pull") or build.has(&"dodge-window") or _funds_counter(): directions.append(&"bank")
	var secondary := build.mode(&"secondary")
	if secondary != &"":
		var direction: StringName = {&"frost": &"cold", &"flame": &"heat", &"storm": &"charge", &"spirit": &"summon"}[secondary]
		if direction not in directions: directions.append(direction)
	# Explicit fixed priorities define who receives indivisible Q remainders.
	directions.sort()
	if build.mode(&"study-mode") == &"K19":
		if build.mode(&"material-1") == &"cold" or build.mode(&"material-2") == &"cold":
			if &"cold" not in directions: directions.append(&"cold")
		directions = directions.filter(func(direction: StringName) -> bool:
			return direction not in [&"cold", &"heat", &"charge", &"summon"] or direction in [build.mode(&"material-1"), build.mode(&"material-2")])
		directions.sort()
	if build.has(&"long-word") and count >= 8:
		work_bank.append(ledger.transfer(_tx("long-word"), work, work.amount_q / 4, &"long-word"))
	var original_work := work.amount_q
	var weights: Array[int] = []
	var total_weight := 0
	var secondary_direction: StringName = {&"frost": &"cold", &"flame": &"heat", &"storm": &"charge", &"spirit": &"summon"}.get(secondary, &"")
	for direction in directions:
		var weight := Q + (build.value(&"secondary_weight_q") if direction == secondary_direction else 0)
		if build.has(&"two-materials") and build.mode(&"study-mode") == &"K19": weight = Q
		weights.append(weight)
		total_weight += weight
	var allocated := 0
	var copies: Array[SpellLot] = []
	for index in directions.size():
		var direction := directions[index]
		var share := original_work * weights[index] / total_weight
		if index == directions.size() - 1: share = original_work - allocated
		allocated += share
		var allocation := ledger.transfer(_tx("work-share"), work, share, direction)
		var secondary_retention := build.value(&"secondary_retention_q") if direction == secondary_direction else 0
		match direction:
			&"charge":
				var charge := ledger.convert(_tx("charge"), allocation, allocation.amount_q, SpellLot.Kind.CHARGE, mini(Q, 900 + build.value(&"charge_efficiency_q") + secondary_retention), &"spell")
				if effect.charge == null: effect.charge = charge
				else: ledger.aggregate(_tx("charge-join"), effect.charge, charge)
			&"cold":
				var cold := ledger.convert(_tx("cold-supply"), allocation, allocation.amount_q, SpellLot.Kind.COLD, 16 * mini(Q, 900 + secondary_retention), &"spell")
				if effect.cold == null: effect.cold = cold
				else: ledger.aggregate(_tx("cold-join"), effect.cold, cold)
			&"heat":
				var heat := ledger.convert(_tx("heat"), allocation, allocation.amount_q, SpellLot.Kind.HEAT, mini(Q, 900 + build.value(&"heat_efficiency_q") + secondary_retention) / 8, &"spell")
				if effect.heat == null: effect.heat = heat
				else: ledger.aggregate(_tx("heat-join"), effect.heat, heat)
			&"copy": copies.append(allocation)
			&"summon": _fund_spirit(allocation, effect, secondary_retention)
			&"heal":
				var amount := allocation.amount_q * (Q + build.value(&"heal_efficiency_q")) / Q
				ledger.spend(_tx("heal"), allocation, allocation.amount_q)
				heal(amount)
			&"bank": work_bank.append(allocation)
	if build.has(&"cold"):
		var cold := ledger.convert(_tx("cold-conversion"), power, power.amount_q * 12 / 100, SpellLot.Kind.COLD, 16 * Q, &"spell")
		if effect.cold == null:
			effect.cold = cold
		else:
			# Keep independently sourced material lots; secondary cold is not reissued.
			ledger.aggregate(_tx("cold-join"), effect.cold, cold)
	if fact.fully_manual() and fact.mistakes == 0 and build.has(&"perfect-shield"):
		var cost := power.amount_q / 20
		ledger.spend(_tx("perfect-shield"), power, cost)
		run.shield_q = mini(20 * Q, run.shield_q + cost)
	if empowered and build.has(&"empowered-shield"):
		var cost := power.amount_q / 10
		ledger.spend(_tx("empowered-shield"), power, cost)
		run.shield_q = mini(20 * Q, run.shield_q + cost)
	if (build.has(&"input-clear") or (build.has(&"long-word") and count >= 8 and build.value(&"long_clear_q") > 0) or (build.has(&"perfect-clear") and fact.fully_manual() and fact.mistakes == 0)) and _spend_work(4 * Q, &"input-clear"):
		var clear := ledger.transfer(_tx("input-clear-budget"), power, power.amount_q / 10, &"clear")
		_clear_threats(clear, world.player_position, 220.0)
	effect.damage_q = power.amount_q
	dispatch(effect, target)
	for allocation in copies: _make_copy(allocation, effect)
	if build.mode(&"mark-reward-use") == &"K14" and copies.is_empty(): _make_copy(null, effect)
	if shell_fee != null:
		var amount := power.amount_q * (3 if (build.has(&"low-health-guard") and world.player_hp_q * 3 < world.player_max_hp_q) or build.mode(&"low-life-allocation") == &"K17" else (2 if build.mode(&"guard-mode") == &"K10" else 1)) / 5
		_store_portion(effect, amount, shell_fee)
		if shell_fee.amount_q > 0: work_bank.append(shell_fee)
	_configure_shape(effect)
	if fact.fully_manual():
		_previous_manual = fact.target_id
	return effect


func dispatch(effect: BattleEffect, target: BattleEnemy) -> void:
	if effect.dispatched:
		return
	effect.dispatched = true
	if effect.build.has(&"refract") and not effect.lot.claims.has(&"refracted"):
		effect.lot.packet.refract(target.resistances)
		effect.lot.claims[&"refracted"] = true
	_heat_contact(effect, effect.origin)
	if effect.empowered and effect.kind == &"spirit_mark":
		var portion := effect.lot.amount_q / 5
		for side in [-1, 1]:
			var cross := fork(effect, portion, &"spirit_cross", target.id, target.position + Vector2(side * 0.04, -0.05))
			cross.delay = 0.09 if side < 0 else 0.18
			world.effects.append(cross)


func contact(effect: BattleEffect, target: BattleEnemy, origin: Vector2, primary: bool = true, contact_at: Vector2 = Vector2.INF) -> void:
	if effect.lot == null or effect.lot.room_id != ledger.room_id or effect.expires_at <= clock or effect.lot.amount_q <= 0 or not target.alive():
		return
	# Due actions settle before the new hit can advance/delay older schedules.
	_settle_due(target.id)
	if not target.alive():
		return
	if effect.build.has(&"advance-dot"):
		for status in ongoing.duplicate():
			if status.target_id == target.id and not status.advanced:
				status.advanced = true
				for pulse in mini(2, status.remaining_pulses): _pulse_status(status)
	if effect.build.has(&"delay-dot") and effect.cold != null and effect.cold.amount_q >= 12 * Q:
		for status in ongoing:
			if status.target_id == target.id and not status.delayed:
				ledger.spend(_tx("delay-dot"), effect.cold, 12 * Q)
				status.delayed = true
				status.next_at += 2.0
				break
	_heat_contact(effect, target.position)
	var amount := effect.lot.amount_q
	if effect.applications > 1 and effect.kind != &"storm_arc":
		amount = mini(amount, effect.primary_share_q if primary else (amount - effect.primary_share_q) / maxi(1, effect.applications - 1))
		if not primary:
			var loss := amount * (Q - mini(Q, 900 + effect.build.value(&"pierce_retention_q"))) / Q
			ledger.spend(_tx("pierce-loss"), effect.lot, loss)
			amount -= loss
	elif effect.kind == &"storm_arc" and effect.jumps > 0:
		amount = maxi(1, amount / (effect.jumps + 1))
	if effect.kind in [&"flame_burst", &"spirit_mark", &"frost_spear", &"storm_arc"] and primary:
		amount = _apply_paid_modifiers(effect, target, amount)
		amount = mini(amount, effect.lot.amount_q)
		if effect.kind != &"storm_arc" and effect.build.has(&"conduct") and effect.charge != null and effect.charge.amount_q >= Q and not effect.lot.claims.has(&"conducted"):
			effect.lot.claims[&"conducted"] = true
			var arc := fork(effect, amount / 4, &"storm_arc", target.id, target.position)
			amount -= arc.lot.amount_q
			arc.jumps = maxi(1, 2 + effect.build.value(&"chain_targets"))
			arc.visited.append(str(target.id))
			_continue_arc(arc, target)
		if effect.build.has(&"heat-field") and effect.heat != null and effect.heat.amount_q > 0 and not effect.heat.claims.has(&"heat-burn"):
			effect.heat.claims[&"heat-burn"] = true
			var thermal := ledger.convert(_tx("heat-burn"), effect.heat, effect.heat.amount_q / 2, SpellLot.Kind.POWER, 8 * Q, &"ongoing")
			thermal.packet = DamagePacket.single(thermal.amount_q, DamagePacket.Element.FIRE)
			_start_ongoing(_effect(thermal, &"flame_burn", target.id, target.position, effect.build))
		if effect.shape == &"crystal_ring" and (effect.build.mode(&"study-mode") != &"K20" or effect.shape_spread) and not effect.lot.claims.has(&"ring"):
			effect.lot.claims[&"ring"] = true
			var crystal := fork(effect, amount / 3, &"frost_fragment", target.id, target.position)
			amount -= crystal.lot.amount_q
			var ring_targets := _nearby(target.position, 300.0, target.id)
			if ring_targets.is_empty(): retire(crystal)
			else: _distribute(crystal.lot, ring_targets.slice(0, 3), &"frost_fragment", target.position, effect.build)
		if effect.shape == &"flame_column" and not effect.lot.claims.has(&"column"):
			effect.lot.claims[&"column"] = true
			var column := fork(effect, amount / 8, &"flame_burn", target.id, target.position)
			amount -= column.lot.amount_q
			_field(column, target.position, 70.0, 6, 0.4, effect.origin)
		if effect.shape == &"embers" and (effect.build.mode(&"study-mode") != &"K20" or effect.shape_spread) and not effect.lot.claims.has(&"embers"):
			effect.lot.claims[&"embers"] = true
			var ember := fork(effect, amount * 2 / 5, &"flame_burn", target.id, target.position)
			amount -= ember.lot.amount_q
			_field(ember, target.position, 150.0, 8, 0.5)
		if effect.build.has(&"dot") and not effect.lot.claims.has(&"dot"):
			var dot_amount := amount * (20 if effect.shape == &"flame_column" else 35) / 100
			var dot := ledger.transfer(_tx("dot"), effect.lot, dot_amount, &"ongoing", &"dot")
			if dot != null:
				var loss := dot.amount_q * (Q - mini(Q, 900 + effect.build.value(&"dot_retention_q"))) / Q
				ledger.spend(_tx("dot-loss"), dot, loss)
				_start_ongoing(_effect(dot, &"flame_burn", target.id, target.position, effect.build))
			amount -= dot_amount
		if effect.build.has(&"splash") or effect.kind == &"flame_burst":
			var nearby := _nearby(target.position, 150.0, target.id)
			if not nearby.is_empty():
				var splash := ledger.transfer(_tx("splash"), effect.lot, amount / (10 if effect.shape == &"flame_column" else 5), &"splash", &"splash")
				if splash != null:
					amount -= splash.amount_q
					_distribute(splash, nearby, &"flame_splash", target.position, effect.build)
	var packet := ledger.spend(_tx("hit"), effect.lot, maxi(0, amount))
	if packet != null:
		_commit_damage(target, packet, effect.kind, origin, effect.empowered, contact_at)
	if primary and effect.kind in [&"frost_spear", &"frost_ultimate"]: effect.primary_share_q = 0
	if effect.cold != null and effect.cold.amount_q > 0:
		if effect.build.has(&"secondary-target") and effect.build.mode(&"secondary") == &"frost":
			var candidates := _nearby(target.position, 480.0, target.id)
			if not candidates.is_empty():
				var secondary_amount := effect.cold.amount_q * 4 / 5
				ledger.spend(_tx("secondary-cold"), effect.cold, secondary_amount)
				_apply_cold(candidates[0], secondary_amount, effect.build)
		var cold := effect.cold.amount_q if primary else effect.cold.amount_q / maxi(1, effect.applications)
		ledger.spend(_tx("cold-hit"), effect.cold, cold)
		_apply_cold(target, cold, effect.build)
	if effect.charge != null and effect.build.has(&"charge-mark") and effect.charge.amount_q >= Q:
		var marks: Array = _charge_marks.get(target.id, [])
		if marks.size() < 3:
			marks.append({"lot": ledger.transfer(_tx("charge-mark"), effect.charge, Q, &"charge-mark"), "expires": clock + 3.0})
			_charge_marks[target.id] = marks
	if effect.kind == &"spirit_mark":
		target.marked_time = 8.0
	if effect.kind == &"storm_arc":
		if effect.build.has(&"charge-clear") and effect.charge != null and effect.charge.amount_q >= Q:
			ledger.spend(_tx("charge-clear-fee"), effect.charge, Q)
			var clear := ledger.transfer(_tx("charge-clear-budget"), effect.lot, effect.lot.amount_q / 10, &"clear")
			_clear_threats(clear, target.position, 140.0)
		effect.visited.append(str(target.id))
		_continue_arc(effect, target)
	if not target.alive():
		_death(target)
	effect.damage_q = effect.lot.amount_q
	if effect.applications > 1: effect.applications -= 1


func advance(delta: float) -> void:
	clock += delta
	for attack in spirit_attacks.duplicate():
		if attack.expires_at <= clock:
			retire(attack)
			spirit_attacks.erase(attack)
	for id in _collision_strikes.keys():
		if _collision_strikes[id].expires_at <= clock:
			retire(_collision_strikes[id])
			_collision_strikes.erase(id)
	for id in _death_fractures.keys():
		var pending: Array = _death_fractures[id]
		for effect: BattleEffect in pending.duplicate():
			if effect.expires_at <= clock:
				retire(effect)
				pending.erase(effect)
		if pending.is_empty(): _death_fractures.erase(id)
	for item in _input_opportunities.duplicate():
		if item.expires <= clock:
			ledger.spend(_tx("input-opportunity-expire"), item.lot, item.lot.amount_q)
			_input_opportunities.erase(item)
	for enemy in world.enemies:
		enemy.burn_time = 0.0
		enemy.local_slow_time = maxf(0.0, enemy.local_slow_time - delta)
	for status in ongoing:
		var enemy := world.enemy_by_id(status.target_id)
		if enemy != null: enemy.burn_time = maxf(enemy.burn_time, status.remaining_pulses * status.interval)
	for mark in letter_marks.duplicate():
		if mark.expires <= clock or world.typing.target_version(mark.target) != mark.version:
			ledger.spend(_tx("letter-expire"), mark.lot, mark.lot.amount_q)
			letter_marks.erase(mark)
	for enemy in world.enemies:
		enemy.control_protection = maxf(0.0, enemy.control_protection - delta)
	for status in ongoing.duplicate():
		while status.remaining_pulses > 0 and status.next_at <= clock:
			_pulse_status(status)
		if status.remaining_pulses <= 0 or status.effect.lot.amount_q == 0:
			ongoing.erase(status)
	for field in fields.duplicate():
		if field.expires_at <= clock or field.remaining_pulses <= 0:
			_recover(field.effect.lot, field.effect.build.has(&"field-recover"))
			fields.erase(field)
			continue
		while field.next_at <= clock and field.remaining_pulses > 0:
			field.next_at += field.interval
			var targets: Array[BattleEnemy] = []
			for enemy in world._living():
				if field.contains(enemy.position) and BattleSession.enemy_in_combat(enemy): targets.append(enemy)
			if targets.is_empty(): break # Contact fields retain their finite opportunities.
			field.remaining_pulses -= 1
			var share: int = field.effect.lot.amount_q if field.remaining_pulses == 0 else mini(field.pulse_q, field.effect.lot.amount_q)
			var lot := ledger.transfer(_tx("field-pulse"), field.effect.lot, share, &"field-contact")
			if lot.material == SpellLot.Kind.POWER:
				_distribute(lot, targets, &"flame_burn", field.center, field.effect.build, true)
			else:
				var amount := lot.amount_q
				ledger.spend(_tx("field-cold"), lot, amount)
				for index in targets.size():
					_apply_cold(targets[index], amount / targets.size() + (1 if index < amount % targets.size() else 0), field.effect.build)
	for shell in stored.duplicate():
		if shell.closed or shell.transporting: continue
		if shell.expires_at <= clock:
			_close_shell(shell, &"expiry")
		elif shell.ready_at <= clock:
			_close_shell(shell, &"release")
	stored = stored.filter(func(shell: StoredSpell) -> bool: return not shell.closed)


func retire(effect: BattleEffect) -> void:
	if effect.lot == null: return
	_recover(effect.lot, effect.build.has(&"miss-recover"))
	if effect.charge != null: _recover(effect.charge, effect.build.has(&"charge-recover"))
	if effect.cold != null: _recover(effect.cold, effect.build.has(&"miss-recover") and effect.build.has(&"reserve"))
	if effect.heat != null: _recover(effect.heat, effect.build.has(&"miss-recover") and effect.build.has(&"reserve"))


func guard(attack_id: String, damage: int, at: Vector2) -> int:
	if _enemy_attacks.has("guard:" + attack_id): return damage
	var incoming := damage
	if build.has(&"spirit-guard") and not spirit_attacks.is_empty():
		var defense := spirit_attacks[0]
		var cost := mini(damage, defense.lot.amount_q)
		ledger.spend(_tx("spirit-guard"), defense.lot, cost)
		damage -= cost
		_enemy_attacks["guard:" + attack_id] = true
		if defense.lot.amount_q == 0: spirit_attacks.pop_front()
	var candidates: Array[StoredSpell] = stored.filter(func(shell: StoredSpell) -> bool:
		return not shell.closed and not shell.transporting and shell.expires_at > clock and shell.guard_after <= clock and shell.effect.build.has(&"guard") and (shell.position - at).length() * 1080 < 220.0)
	if candidates.is_empty():
		_record_guard(incoming - damage)
		return damage
	candidates.sort_custom(func(a: StoredSpell, b: StoredSpell) -> bool:
		if build.mode_operation(&"guard-order") == &"closest-guard": return absi(a.effect.lot.amount_q - damage) < absi(b.effect.lot.amount_q - damage)
		return a.born_at > b.born_at if build.mode_operation(&"guard-order") == &"newest" else a.born_at < b.born_at)
	_enemy_attacks["guard:" + attack_id] = true
	var remainder := damage
	var first := candidates[0]
	for shell: StoredSpell in candidates.slice(0, 2):
		if shell != first and (not build.has(&"joint-guard") or not _compatible(first, shell)): break
		var efficiency := Q + shell.effect.build.value(&"guard_efficiency_q") + shell.effect.build.value(&"shell_durability_q")
		var blocked := mini(remainder, shell.effect.lot.amount_q * efficiency / Q)
		var cost := (blocked * Q + efficiency - 1) / efficiency
		ledger.spend(_tx("guard"), shell.effect.lot, cost)
		remainder -= blocked
		_close_shell(shell, &"guard")
		world.event_committed.emit({"kind": &"guard", "at": at, "from": shell.position, "damage_q": blocked})
		if build.has(&"guard-spacing"):
			for neighbor in stored:
				if neighbor != shell and neighbor.effect.lot.root_id == shell.effect.lot.root_id: neighbor.guard_after = clock + 0.3
		if remainder == 0: break
	_record_guard(incoming - remainder)
	return remainder


func _record_guard(amount: int) -> void:
	if amount > 0:
		guarded_damage_q += amount
		guarded_hits += 1


func heal(amount: int) -> void:
	var restored := mini(maxi(0, amount), world.player_max_hp_q - world.player_hp_q)
	world.player_hp_q += restored
	healed_q += restored


func counter(attack_id: String, damage: int, target: StringName, origin: Vector2) -> BattleEffect:
	if _enemy_attacks.has("counter:" + attack_id): return null
	_enemy_attacks["counter:" + attack_id] = true
	# The attack receipt permits one small base response; typing funds amplification.
	var lot := ledger.earn(attack_id, &"counter", build.identity(), SpellLot.Kind.POWER, mini(Q, damage), &"counter")
	var paid_work := mini(6 * Q, _available_work()) if _funds_counter() else 0
	if paid_work > 0:
		var strength := _convert_work(paid_work, 4 * (Q + build.value(&"parry_efficiency_q")), &"counter")
		ledger.aggregate(_tx("counter-funded"), lot, strength)
	var effect := _effect(lot, &"counter", target, origin, build)
	if build.has(&"parry"): _apply_reserve(effect, world.enemy_by_id(target), false)
	if build.value(&"parry_followup_q") > 0 and _counter_reserve.size() < 2 + build.value(&"counter_capacity"):
		_counter_reserve.append(fork(effect, effect.lot.amount_q * mini(256, build.value(&"parry_followup_q")) / Q, &"counter-followup", target, origin))
	if build.mode(&"parry-mode") == &"K16" and _counter_reserve.size() < 2 + build.value(&"counter_capacity"):
		var stored_counter := fork(effect, effect.lot.amount_q / 2, &"counter", target, origin)
		_counter_reserve.append(stored_counter)
	return effect


func _funds_counter() -> bool:
	return build.has(&"parry") or build.has(&"counter-store") or build.value(&"parry_efficiency_q") > 0 or build.value(&"parry_followup_q") > 0


func _available_work() -> int:
	var amount := 0
	for lot in work_bank: amount += lot.amount_q
	return amount


func ultimate(target: BattleEnemy) -> BattleEffect:
	var lot := ledger.earn(_tx("ultimate-root"), build.book(), build.identity(), SpellLot.Kind.POWER, 20 * 12 * (Q + build.value(&"ultimate_power_q")), &"ultimate", ELEMENTS[build.book()])
	var effect := _effect(lot, StringName(str(build.book()) + "_ultimate"), target.id, target.position, build)
	if build.book() == &"frost":
		effect.cold = ledger.convert(_tx("ultimate-cold"), lot, lot.amount_q * 12 / 100, SpellLot.Kind.COLD, 16 * Q, &"ultimate")
	if build.has(&"ultimate-shield"):
		var cost := lot.amount_q / 10
		ledger.spend(_tx("ultimate-shield"), lot, cost)
		run.shield_q = mini(20 * Q, run.shield_q + cost)
	effect.empowered = true
	return effect


func take_spirit_attack(target: BattleEnemy, position: Vector2) -> BattleEffect:
	while not spirit_attacks.is_empty():
		var effect: BattleEffect = spirit_attacks.pop_front()
		if effect.expires_at <= clock:
			retire(effect)
			continue
		effect.target_id = target.id
		effect.origin = position
		return effect
	return null


func clear_ultimate_threats(effect: BattleEffect, origin: Vector2) -> void:
	var budget := ledger.transfer(_tx("ultimate-guard"), effect.lot, effect.lot.amount_q / 10, &"ultimate-guard")
	_clear_threats(budget, origin, 390.0)


func consume_assist() -> bool:
	if not build.has(&"assist"): return false
	return _spend_work(maxi(2 * Q, 12 * Q + build.value(&"assist_cost_q")), &"assist")


func assist_ready() -> bool:
	return build.has(&"assist") and _available_work() >= maxi(2 * Q, 12 * Q + build.value(&"assist_cost_q"))


func finish(reason: StringName) -> RoomCombatResult:
	for status in ongoing: _recover(status.effect.lot, status.effect.build.has(&"dot-recover"))
	for field in fields: _recover(field.effect.lot, field.effect.build.has(&"field-recover"))
	for shell in stored:
		if not shell.closed: _recover(shell.effect.lot, shell.effect.build.has(&"shell-recover"))
	for effect in spirit_attacks: retire(effect)
	ongoing.clear()
	fields.clear()
	stored.clear()
	spirit_attacks.clear()
	var result := RoomCombatResult.new()
	result.room_id = ledger.room_id
	result.reason = reason
	result.actual_damage_q = actual_damage_q
	if reason == &"victory" and build.has(&"clear-heal"):
		for lot in reserve:
			if lot.material == SpellLot.Kind.POWER and world.player_hp_q < world.player_max_hp_q:
				var amount := mini(lot.amount_q, world.player_max_hp_q - world.player_hp_q)
				ledger.spend(_tx("clear-heal"), lot, amount)
				heal(amount)
	if reason == &"victory" and build.has(&"archive") and build.mode(&"clear-surplus-use") != &"K18":
		var ratio := mini(700, (600 if build.mode(&"reserve-mode") == &"K06" else 350) + build.value(&"archive_retention_q"))
		for lot in reserve:
			if lot.amount_q > 0:
				var retained := ledger.transfer(_tx("handoff"), lot, lot.amount_q * ratio / Q, &"handoff")
				result.reserve.append(retained)
	result.asset_claims = run.asset_claims.duplicate()
	run.hp_q = world.player_hp_q
	run.resonance_q = world.resonance_q
	run.reserve = result.reserve.duplicate()
	for lot in ledger.active_lots():
		if lot.owner != &"handoff":
			if lot.material == SpellLot.Kind.POWER: unused_power_q += lot.amount_q
			ledger.spend(_tx("room-loss"), lot, lot.amount_q)
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


func fork(effect: BattleEffect, amount: int, kind: StringName, target: StringName, origin: Vector2) -> BattleEffect:
	var total := effect.lot.amount_q
	var lot := ledger.transfer(_tx("fork"), effect.lot, amount, kind)
	var child := _effect(lot, kind, target, origin, effect.build)
	child.empowered = effect.empowered
	child.dispatched = effect.dispatched
	child.expires_at = effect.expires_at
	child.shape = effect.shape
	if total > 0:
		if effect.cold != null: child.cold = ledger.transfer(_tx("fork-cold"), effect.cold, effect.cold.amount_q * amount / total, kind)
		if effect.charge != null: child.charge = ledger.transfer(_tx("fork-charge"), effect.charge, effect.charge.amount_q * amount / total, kind)
		if effect.heat != null: child.heat = ledger.transfer(_tx("fork-heat"), effect.heat, effect.heat.amount_q * amount / total, kind)
	return child


func _plan_shape(effect: BattleEffect) -> void:
	effect.shape_plan_ready = true
	var primary_target := world.enemy_by_id(effect.target_id)
	var targets := _nearby(primary_target.position if primary_target != null and effect.build.mode(&"study-mode") == &"K20" else effect.origin, 600.0)
	for target in targets: effect.shape_targets.append(str(target.id))
	effect.shape_spread = effect.build.mode(&"study-mode") == &"K20" and targets.size() >= 3


func _configure_shape(effect: BattleEffect) -> void:
	if effect.shaped: return
	effect.shaped = true
	var shape := effect.build.mode(&"shape") if effect.optional_shape else &""
	effect.shape = shape
	if effect.kind == &"frost_spear" or effect.kind == &"frost_ultimate":
		effect.applications = 3 if shape != &"ice_lance" else 2
		effect.primary_share_q = effect.lot.amount_q * (3 if effect.build.has(&"last-segment") else 2) / (4 if effect.build.has(&"last-segment") else 3)
	if effect.kind == &"storm_arc":
		effect.jumps = maxi(1, 2 + effect.build.value(&"chain_targets"))
		if shape == &"lightning_beam":
			effect.kind = &"storm_beam"
			effect.jumps = 0
	var targets: Array[BattleEnemy] = []
	if effect.shape_plan_ready:
		for id in effect.shape_targets:
			var planned := world.enemy_by_id(StringName(id))
			if planned != null and planned.alive() and BattleSession.enemy_in_combat(planned): targets.append(planned)
	else:
		var primary := world.enemy_by_id(effect.target_id)
		targets = _nearby(primary.position if primary != null and effect.build.mode(&"study-mode") == &"K20" else effect.origin, 600.0)
	var adaptive_spread := effect.shape_spread if effect.shape_plan_ready else effect.build.mode(&"study-mode") == &"K20" and targets.size() >= 3
	effect.shape_spread = adaptive_spread
	if adaptive_spread or shape in [&"radial_lightning", &"patrol_blade"] or (effect.optional_shape and effect.build.has(&"split")):
		if effect.build.mode(&"study-mode") == &"K20" and targets.size() < 3: return
		var branches := 2 + effect.build.value(&"split_targets")
		var share := effect.lot.amount_q / (branches + 1)
		for target in targets.slice(0, mini(branches + 1, targets.size())):
			if target.id != effect.target_id:
				var child := fork(effect, mini(share, effect.lot.amount_q), effect.kind, target.id, effect.origin)
				var loss := child.lot.amount_q * (Q - mini(Q, 900 + effect.build.value(&"split_retention_q") + effect.build.value(&"shape_retention_q"))) / Q
				ledger.spend(_tx("shape-loss"), child.lot, loss)
				child.primary_share_q = child.lot.amount_q
				child.applications = 1
				world.effects.append(child)
		effect.primary_share_q = effect.lot.amount_q
	if not adaptive_spread and (shape in [&"ice_lance", &"flame_column", &"lightning_beam", &"lone_blade"] or (effect.optional_shape and (effect.build.has(&"concentrate") or effect.build.mode(&"shape-mode") == &"K03"))):
		effect.primary_share_q = effect.lot.amount_q * 4 / 5
		effect.applications = 2 if effect.kind != &"storm_arc" else 1
	if shape in [&"flame_column", &"embers", &"crystal_ring"]: effect.applications = 1
	if effect.optional_shape and effect.build.has(&"pierce") and effect.kind not in [&"storm_arc", &"storm_beam"]:
		if effect.applications == 1: effect.primary_share_q = effect.lot.amount_q
		effect.applications += 1
		effect.primary_share_q = effect.primary_share_q * 3 / 4


func _start_ongoing(effect: BattleEffect) -> void:
	if effect.build.has(&"heat-field"):
		var field_lot := ledger.transfer(_tx("dot-field"), effect.lot, effect.lot.amount_q / 2, &"field")
		_field(_effect(field_lot, &"flame_burn", effect.target_id, effect.origin, effect.build), effect.origin, 130.0, 8, 0.5)
	var status := OngoingSpell.new()
	status.id = _next()
	status.effect = effect
	status.target_id = effect.target_id
	status.remaining_pulses = 8 + effect.build.value(&"dot_pulses")
	status.interval = (4.0 + effect.build.value(&"dot_duration_ms") / 1000.0) / status.remaining_pulses
	status.next_at = clock + status.interval
	ongoing.append(status)


func _pulse_status(status: OngoingSpell) -> void:
	if status.remaining_pulses <= 0: return
	var target := world.enemy_by_id(status.target_id)
	if target == null or not target.alive():
		status.remaining_pulses = 0
		_recover(status.effect.lot, status.effect.build.has(&"dot-recover"))
		return
	var amount := status.effect.lot.amount_q / status.remaining_pulses
	var packet := ledger.spend(_tx("status-pulse"), status.effect.lot, amount)
	status.remaining_pulses -= 1
	status.next_at += status.interval
	_commit_damage(target, packet, &"flame_burn", status.effect.origin)
	if not target.alive(): _death(target)


func _settle_due(target_id: StringName) -> void:
	for status in ongoing.duplicate():
		while status.target_id == target_id and status.remaining_pulses > 0 and status.next_at <= clock: _pulse_status(status)


func _apply_cold(target: BattleEnemy, amount: int, snapshot: CompiledBuild) -> void:
	if not target.alive() or target.control_protection > 0.0: return
	target.cold_q += amount * (Q + snapshot.value(&"cold_efficiency_q")) / Q
	if target.cold_q >= 100 * Q:
		target.cold_q -= 100 * Q
		var duration := 1.55
		if target.boss:
			duration = 0.8 / (1.0 + 0.5 * target.control_resistance)
			target.control_resistance = mini(3, target.control_resistance + 1)
			target.control_protection = duration + 2.0
		target.frozen_time = maxf(target.frozen_time, duration)
		freezes += 1
		world.event_committed.emit({"kind": &"freeze", "at": target.position, "enemy": target.id})


func _continue_arc(effect: BattleEffect, target: BattleEnemy) -> void:
	if effect.charge != null and effect.charge.amount_q < Q:
		for mark in _charge_marks.get(target.id, []):
			if mark.expires > clock and mark.lot.root_id != effect.lot.root_id and mark.lot.amount_q > 0:
				ledger.aggregate(_tx("charge-mark-use"), effect.charge, mark.lot)
	if effect.jumps <= 0 or effect.lot.amount_q <= 0 or effect.charge == null or effect.charge.amount_q < Q:
		retire(effect)
		return
	var distance := 480.0 * (Q + effect.build.value(&"hop_range_q")) / Q
	if effect.shape == &"radial_lightning": distance *= 0.75
	var route := _arc_route(effect, target.position, distance)
	if route.is_empty():
		retire(effect)
		return
	var cost := Q * (Q - mini(205, effect.build.value(&"shared_discount_q"))) / Q if effect.build.has(&"shared-work") and effect.cold != null else Q
	if effect.charge.amount_q < cost * route.size() or effect.jumps < route.size():
		retire(effect)
		return
	for node: Dictionary in route:
		ledger.spend(_tx("hop-fee"), effect.charge, cost)
		world.event_committed.emit({"kind": &"relay", "from": target.position, "at": node.position})
		if node.has("shell"):
			var relay: StoredSpell = node.shell
			relay.effect.lot.claims[&"relay"] = true
			if relay.transporting and relay.effect.charge != null:
				ledger.spend(_tx("cargo-relay"), relay.effect.charge, Q)
			else: ledger.spend(_tx("shell-relay"), relay.effect.lot, relay.effect.lot.amount_q / 10)
		elif node.has("field"):
			var field: SpellField = node.field
			field.relayed = true
			field.remaining_pulses -= 1
			ledger.spend(_tx("field-relay"), field.effect.lot, mini(field.pulse_q, field.effect.lot.amount_q))
	var next: BattleEnemy = route.back().enemy
	var loss := effect.lot.amount_q * (Q - mini(Q, 900 + effect.build.value(&"chain_retention_q"))) / Q
	ledger.spend(_tx("chain-loss"), effect.lot, loss)
	effect.jumps -= route.size()
	effect.target_id = next.id
	effect.origin = target.position
	effect.delay = 0.16 if effect.build.has(&"delayed-chain") else 0.08
	world.effects.append(effect)


func _distribute(lot: SpellLot, targets: Array[BattleEnemy], kind: StringName, origin: Vector2, snapshot: CompiledBuild, immediate: bool = false) -> void:
	var total := lot.amount_q
	for index in targets.size():
		var child := ledger.transfer(_tx("distribute"), lot, total / targets.size() + (1 if index < total % targets.size() else 0), kind)
		if immediate:
			var packet := ledger.spend(_tx("distributed-hit"), child, child.amount_q)
			_commit_damage(targets[index], packet, kind, origin)
			if not targets[index].alive(): _death(targets[index])
		else:
			world.effects.append(_effect(child, kind, targets[index].id, origin, snapshot))


func _field(effect: BattleEffect, center: Vector2, radius: float, pulses: int, interval: float, endpoint: Vector2 = Vector2.INF) -> void:
	if effect.build.has(&"field-split") and not effect.lot.claims.has(&"field-split"):
		effect.lot.claims[&"field-split"] = true
		var original := effect.lot.amount_q
		for index in 3:
			var count := pulses / 3 + (1 if index < pulses % 3 else 0)
			var portion := fork(effect, effect.lot.amount_q if index == 2 else mini(effect.lot.amount_q, original * count / pulses), effect.kind, effect.target_id, center)
			_field(portion, center + Vector2.from_angle(index * TAU / 3) * radius * 0.5 / BattleSession.ARENA_SIZE, radius * 0.65, count, interval, endpoint)
		return
	var field := SpellField.new()
	field.id = _next()
	field.effect = effect
	field.center = center
	field.endpoint = center if endpoint == Vector2.INF else endpoint
	field.radius = radius * (Q + effect.build.value(&"field_radius_q")) / Q
	field.remaining_pulses = pulses
	field.pulse_q = effect.lot.amount_q / maxi(1, pulses)
	field.interval = interval
	field.next_at = clock + interval
	field.expires_at = clock + pulses * interval + effect.build.value(&"field_lifetime_ms") / 1000.0
	fields.append(field)
	world.event_committed.emit({"kind": &"field", "at": center, "radius": field.radius})


func _store_portion(effect: BattleEffect, amount: int, work: SpellLot) -> void:
	var capacity := _storage_capacity()
	if effect.build.has(&"reserved-slot") and world.completed_words <= 1: capacity -= 1
	if effect.build.has(&"continuation-slot"):
		var owner := world.enemy_by_id(effect.word_owner)
		if owner == null or owner.alive(): capacity -= 1
	if _storage_occupancy() + _shell_units(effect.build, effect.lot.claims.has(&"copied")) > capacity or amount <= 0: return
	var cost := maxi(1, Q * (Q - mini(512, effect.build.value(&"manufacture_discount_q") + _shared_discount(effect.build))) / Q)
	var total := effect.lot.amount_q
	var lot := ledger.pay_and_transfer(_tx("store"), work, cost, effect.lot, amount, &"shell", &"stored")
	if lot != null:
		var loss := lot.amount_q * (Q - mini(Q, 900 + effect.build.value(&"storage_retention_q"))) / Q
		ledger.spend(_tx("storage-loss"), lot, loss)
		var child := _effect(lot, effect.kind, effect.target_id, effect.origin, effect.build)
		child.dispatched = effect.dispatched
		if effect.cold != null: child.cold = ledger.transfer(_tx("store-cold"), effect.cold, effect.cold.amount_q * amount / total, &"shell")
		if effect.charge != null: child.charge = ledger.transfer(_tx("store-charge"), effect.charge, effect.charge.amount_q * amount / total, &"shell")
		if effect.heat != null: child.heat = ledger.transfer(_tx("store-heat"), effect.heat, effect.heat.amount_q * amount / total, &"shell")
		_store(child)


func _store(effect: BattleEffect) -> void:
	var shell := StoredSpell.new()
	shell.space_units = _shell_units(effect.build, effect.lot.claims.has(&"copied"))
	shell.id = _next()
	shell.effect = effect
	shell.position = effect.origin
	shell.born_at = clock
	shell.ready_at = clock + maxf(0.1, 1.8 + effect.build.value(&"storage_wait_ms") / 1000.0)
	if effect.build.has(&"stagger-release"): shell.ready_at += 0.1 + stored.size() * 0.12
	shell.expires_at = clock + maxf(0.1, (1.0 if effect.build.mode(&"storage-mode") == &"K11" or effect.build.has(&"short-storage") else 5.0) + effect.build.value(&"storage_lifetime_ms") / 1000.0)
	# Keep the entire paid portion in its shell. Ordinary pages freeze dispatch
	# choices now; R168 chooses them on release. Neither launches early branches.
	if not effect.build.has(&"late-shape"): _plan_shape(effect)
	stored.append(shell)
	world.event_committed.emit({"kind": &"store", "at": shell.position, "power_q": effect.lot.amount_q})
	if effect.build.has(&"merge") and effect.build.mode(&"transport-mode") != &"K12": _merge(shell)


func _close_shell(shell: StoredSpell, reason: StringName) -> void:
	if shell.closed: return
	var target := _choose_target(shell.effect, shell.position)
	if reason == &"release" and target == null and shell.effect.build.has(&"reseal") and not shell.resealed:
		shell.resealed = true
		shell.ready_at = clock + 0.5
		return
	shell.closed = true
	shell.transporting = false
	# Closing transfers the remainder out of the shell before any derived request.
	var lot := ledger.transfer(_tx("shell-close"), shell.effect.lot, shell.effect.lot.amount_q, &"ending")
	var effect := _effect(lot, shell.effect.kind, shell.effect.target_id, shell.position, shell.effect.build)
	effect.cold = shell.effect.cold
	effect.charge = shell.effect.charge
	effect.heat = shell.effect.heat
	effect.optional_shape = shell.effect.optional_shape
	effect.dispatched = shell.effect.dispatched
	effect.shape_plan_ready = shell.effect.shape_plan_ready
	effect.shape_targets = shell.effect.shape_targets.duplicate()
	effect.shape_spread = shell.effect.shape_spread
	if target != null and lot.amount_q > 0 and reason == &"fracture" and shell.effect.build.has(&"fracture"):
		var targets := _nearby(shell.position, 480.0)
		_distribute(lot, targets.slice(0, mini(3 + effect.build.value(&"split_targets"), targets.size())), effect.kind, shell.position, effect.build)
	elif target != null and lot.amount_q > 0 and (reason == &"release" or shell.effect.build.has(&"echo")):
		effect.target_id = target.id
		_configure_shape(effect)
		world.effects.append(effect)
	else:
		_recover(lot, shell.effect.build.has(&"shell-recover") or shell.effect.build.has(&"miss-recover"))
		retire(effect)
	world.event_committed.emit({"kind": &"release", "at": shell.position, "reason": reason})


func _make_copy(work: SpellLot, template: BattleEffect) -> void:
	if work != null: copy_work_bank.append(work)
	var cost := maxi(Q, 12 * (Q - mini(512, template.build.value(&"manufacture_discount_q") + _shared_discount(template.build))))
	if template.build.has(&"inherit") and not template.build.has(&"base-copy"): cost += Q
	var total := 0
	for lot in copy_work_bank: total += lot.amount_q
	var count := 2 if template.build.has(&"copy-split") else 1
	if total < cost or _storage_occupancy() + count * _shell_units(template.build, true) > _storage_capacity(): return
	var remaining := cost
	var output: SpellLot = null
	for fee in copy_work_bank:
		if remaining == 0: break
		var paid := mini(fee.amount_q, remaining)
		if paid == 0: continue
		remaining -= paid
		var lot := ledger.convert(_tx("copy-make"), fee, paid, SpellLot.Kind.POWER, 4 * Q, &"copy")
		lot.packet = DamagePacket.single(lot.amount_q, ELEMENTS[template.build.book()])
		if output == null: output = lot
		else: ledger.aggregate(_tx("copy-funding"), output, lot)
	var retention := 358 + template.build.value(&"copy_retention_q")
	if template.build.has(&"copy-concentrate"): retention *= 2
	var cap := mini(output.amount_q, template.lot.amount_q * mini(Q, retention) / Q)
	ledger.spend(_tx("copy-loss"), output, output.amount_q - cap)
	output.root_id = template.lot.root_id
	output.claims[&"copied"] = true
	if template.lot.claims.has(&"refracted"):
		output.claims[&"refracted"] = true
		output.packet = template.lot.packet.copy().take(output.amount_q)
	var effect := _effect(output, template.kind if template.build.has(&"inherit") and not template.build.has(&"base-copy") else KINDS[template.build.book()], template.target_id, template.origin, template.build)
	effect.optional_shape = template.build.has(&"inherit") and not template.build.has(&"base-copy")
	if template.build.has(&"copy-split"):
		var second := fork(effect, output.amount_q / 2, effect.kind, effect.target_id, effect.origin)
		second.optional_shape = effect.optional_shape
		_store(second)
	_store(effect)


func _fund_spirit(work: SpellLot, template: BattleEffect, secondary_retention: int = 0) -> void:
	var lot := ledger.convert(_tx("spirit-fund"), work, work.amount_q, SpellLot.Kind.POWER, 3 * mini(Q, 900 + template.build.value(&"summon_efficiency_q") + secondary_retention), &"spirit-queue")
	lot.packet = DamagePacket.single(lot.amount_q, DamagePacket.Element.PAPER)
	var strike_size := 12 * Q if template.build.mode(&"shape") == &"lone_blade" else (3 * Q if template.build.mode(&"shape") == &"patrol_blade" else 6 * Q)
	while lot.amount_q > 0:
		var child := ledger.transfer(_tx("spirit-portion"), lot, mini(strike_size, lot.amount_q), &"spirit-attack")
		var effect := _effect(child, &"spirit_blade", template.target_id, template.origin, template.build)
		effect.expires_at = clock + 8.0
		spirit_attacks.append(effect)
	world.spirit_time = minf(18.0, world.spirit_time + 8.0)
	world.spirit_focus = template.target_id
	world._summon_spirit()


func _apply_reserve(effect: BattleEffect, target: BattleEnemy, manual: bool, manual_length: int = 0) -> void:
	if run.reserve_cooldown_words > 0:
		if manual: run.reserve_cooldown_words -= 1
		return
	var burst := target != null and build.mode(&"reserve-mode") == &"K07" and not _reserve_targets.has(target.id) and target.hp_q >= effect.lot.amount_q * 3
	var ratio := (768 + build.value(&"burst_ratio_q")) if burst else (128 if build.has(&"meter") or build.mode(&"reserve-mode") == &"K06" else 256)
	if build.has(&"short-word") and manual_length > 0 and manual_length <= 4: ratio = mini(Q, ratio + 128)
	var short_word := build.has(&"short-word") and manual_length > 0 and manual_length <= 4
	var capacity := (48 * Q + build.value(&"burst_cap_q")) * 16 if burst else ((8 if short_word else 12) * Q + build.value(&"reserve_cast_cap_q")) * 16
	var used := 0
	var ordered := reserve.duplicate()
	ordered.sort_custom(func(a: SpellLot, b: SpellLot) -> bool:
		return _reserve_order(a.material) < _reserve_order(b.material))
	for lot in ordered:
		var amount := mini(lot.amount_q * ratio / Q, (capacity - used) / maxi(1, SpellLot.SPACE_WEIGHTS[lot.material]))
		if amount <= 0: continue
		var portion := ledger.transfer(_tx("reserve-use"), lot, amount, &"spell")
		used += amount * SpellLot.SPACE_WEIGHTS[lot.material]
		if portion.material == SpellLot.Kind.POWER:
			ledger.aggregate(_tx("reserve-join"), effect.lot, portion)
		else:
			match portion.material:
				SpellLot.Kind.COLD:
					if effect.cold == null: effect.cold = portion
					else: ledger.aggregate(_tx("reserve-cold"), effect.cold, portion)
				SpellLot.Kind.HEAT:
					if effect.heat == null: effect.heat = portion
					else: ledger.aggregate(_tx("reserve-heat"), effect.heat, portion)
				SpellLot.Kind.CHARGE:
					if effect.charge == null: effect.charge = portion
					else: ledger.aggregate(_tx("reserve-charge"), effect.charge, portion)
	if burst and used > 0:
		_reserve_targets[target.id] = true
		run.reserve_cooldown_words = 2 + build.value(&"reserve_cooldown_words")


func _extract_previous(effect: BattleEffect) -> void:
	for status in ongoing:
		if status.target_id != _previous_manual: continue
		var target := world.enemy_by_id(status.target_id)
		if target == null or not target.alive(): continue
		var lot := ledger.transfer(_tx("extract"), status.effect.lot, status.effect.lot.amount_q * (256 + build.value(&"extract_ratio_q")) / Q, &"extracted")
		ledger.aggregate(_tx("extract-join"), effect.lot, lot)


func _recover(lot: SpellLot, allowed: bool) -> void:
	if lot == null or lot.amount_q <= 0: return
	var snapshot: CompiledBuild = _snapshots.get(lot.snapshot_id, build)
	if lot.material in [SpellLot.Kind.COLD, SpellLot.Kind.HEAT] and not snapshot.has(&"reserve"): allowed = false
	if allowed:
		var used := 0
		for item in reserve: used += item.amount_q * SpellLot.SPACE_WEIGHTS[item.material]
		var capacity := 96 * Q * 16 * (Q + build.value(&"reserve_capacity_q")) / Q
		var child := ledger.reclaim(_tx("recover"), lot, clampi(358 + snapshot.value(&"recovery_q"), 0, 716), maxi(0, capacity - used))
		if child != null: reserve.append(child)
	if lot.amount_q > 0:
		if lot.material == SpellLot.Kind.POWER: unused_power_q += lot.amount_q
		ledger.spend(_tx("loss"), lot, lot.amount_q)


func _death(target: BattleEnemy) -> void:
	_distribute_letters(target)
	if _death_fractures.has(target.id):
		for effect: BattleEffect in _death_fractures[target.id]:
			var candidates := _nearby(target.position, 420.0, target.id)
			if candidates.is_empty(): retire(effect)
			else:
				var fragment_targets := candidates.slice(0, mini(3 + effect.build.value(&"split_targets"), candidates.size()))
				_distribute(effect.lot, fragment_targets, &"frost_fragment" if effect.build.has(&"avalanche") else &"flame_splash", target.position, effect.build)
		_death_fractures.erase(target.id)
	for status in ongoing.duplicate():
		if status.target_id != target.id or status.effect.lot.amount_q <= 0: continue
		if status.effect.build.has(&"dot-transfer"):
			var next := world._nearest_living(target.position)
			if next != null:
				status.target_id = next.id
				status.effect.target_id = next.id
				continue
		if status.effect.build.has(&"dot-shell") and _storage_occupancy() + _shell_units(status.effect.build, status.effect.lot.claims.has(&"copied")) <= _storage_capacity():
			var lot := ledger.transfer(_tx("dot-shell"), status.effect.lot, status.effect.lot.amount_q * 358 / Q, &"shell")
			_store(_effect(lot, &"flame_splash", target.id, target.position, status.effect.build))
		if status.effect.build.has(&"dot-selective-recover"):
			var ratio := 410 if status.remaining_pulses >= 4 else 307
			var child := ledger.reclaim(_tx("selective-dot-recover"), status.effect.lot, ratio, maxi(0, 96 * Q * 16 - _reserve_space()))
			if child != null: reserve.append(child)
		_recover(status.effect.lot, status.effect.build.has(&"dot-recover"))
		status.remaining_pulses = 0


func _apply_paid_modifiers(effect: BattleEffect, target: BattleEnemy, amount: int) -> int:
	if (effect.build.has(&"death-fracture") or (effect.build.has(&"avalanche") and target.frozen_time > 0.0)) and not effect.lot.claims.has(&"death-fracture"):
		var fracture := ledger.transfer(_tx("death-fracture"), effect.lot, amount / 10, &"death-fracture", &"death-fracture")
		var pending: Array = _death_fractures.get(target.id, [])
		var fragment := _effect(fracture, &"flame_splash", target.id, target.position, effect.build)
		fragment.expires_at = clock + 5.0
		pending.append(fragment)
		_death_fractures[target.id] = pending
	if effect.build.has(&"brittle") and target.frozen_time > 0.0:
		# Concentrate existing future/along-path power; control does not mint power.
		amount = mini(effect.lot.amount_q, amount + effect.lot.amount_q / 10)
	if effect.build.has(&"execute") and target.hp_q < 12 * Q:
		var lot := _convert_work(Q, 6 * Q, &"execute")
		if lot != null:
			if target.boss and lot.amount_q > 2 * Q: ledger.spend(_tx("boss-execute-cap"), lot, lot.amount_q - 2 * Q)
			amount += lot.amount_q
			ledger.aggregate(_tx("execute-join"), effect.lot, lot)
	if effect.build.has(&"pull") or effect.build.has(&"push"):
		var cost := amount / 10
		if effect.build.has(&"push"):
			var collision := fork(effect, cost / 2, &"collision", target.id, target.position)
			collision.expires_at = clock + 2.0
			if _collision_strikes.has(target.id): retire(_collision_strikes[target.id])
			_collision_strikes[target.id] = collision
		ledger.spend(_tx("displacement"), effect.lot, cost / 2 if effect.build.has(&"push") else cost)
		for neighbor in _nearby(target.position, 180.0):
			var direction := (target.position - neighbor.position).normalized() if effect.build.has(&"pull") else (neighbor.position - effect.origin).normalized()
			neighbor.impulse += direction * minf(500.0, cost / float(Q) * 60.0) / neighbor.mass * (0.2 if neighbor.boss else 1.0)
	if effect.build.has(&"cold-field") and effect.cold != null and effect.cold.amount_q > 0:
		var lot := ledger.transfer(_tx("cold-field"), effect.cold, effect.cold.amount_q / 2, &"field")
		_field(_effect(lot, &"cold_field", target.id, target.position, effect.build), target.position, 120.0, 4, 0.5)
	return mini(amount, effect.lot.amount_q)


func _heat_contact(effect: BattleEffect, at: Vector2) -> void:
	if effect.heat == null or effect.heat.amount_q <= 0: return
	for shell in stored.duplicate():
		var claim := StringName("heat-pair:%s:%s" % [effect.lot.root_id, shell.id])
		if shell.closed or shell.transporting or (shell.position - at).length() * 1080 > 180.0 or effect.heat.claims.has(claim): continue
		var heat := mini(effect.heat.amount_q, Q / 4)
		if ledger.spend(_tx("heat-contact"), effect.heat, heat, claim) == null: continue
		shell.heat_q = mini(2 * Q + shell.effect.build.value(&"heat_capacity_q"), shell.heat_q + heat * (Q + shell.effect.build.value(&"heat_absorption_q")) / Q)
		if shell.effect.build.has(&"anneal") and shell.heat_q > 0: shell.heat_q = shell.heat_q * 3 / 4
		if shell.effect.build.has(&"heat-transfer") and shell.heat_q > 0 and not shell.effect.lot.claims.has(&"heat-transfer"):
			for neighbor in stored:
				if neighbor != shell and not neighbor.closed and ((neighbor.position - shell.position) * BattleSession.ARENA_SIZE).length() < 180.0:
					neighbor.heat_q += shell.heat_q * 3 / 4
					shell.heat_q = 0
					shell.effect.lot.claims[&"heat-transfer"] = true
					break
		var heat_mode: StringName = shell.effect.build.mode(&"shell-heat-mode")
		if heat_mode == &"K04" or (heat_mode != &"K05" and shell.effect.build.has(&"heat-hold")): continue
		var threshold := maxi(Q / 16, (Q / 4 + shell.effect.build.value(&"heat_threshold_q") / 4) * (Q + shell.effect.build.value(&"shell_durability_q")) / Q)
		if shell.heat_q >= threshold:
			shell.heat_q -= threshold
			if heat_mode == &"K05" or shell.effect.build.has(&"heat-open") or shell.effect.build.has(&"heat-fracture") or shell.effect.build.has(&"thin-shell") or shell.effect.build.has(&"fracture"):
				_close_shell(shell, &"fracture" if shell.effect.build.has(&"heat-fracture") or shell.effect.build.has(&"thin-shell") or shell.effect.build.has(&"fracture") else &"release")


func _merge(shell: StoredSpell) -> StoredSpell:
	for other in stored:
		if other == shell or other.closed or not _compatible(shell, other): continue
		if other.merged_sources + shell.merged_sources > 2 + build.value(&"merge_count"): continue
		ledger.aggregate(_tx("merge"), other.effect.lot, shell.effect.lot)
		other.merged_sources += shell.merged_sources
		for material in [&"cold", &"heat", &"charge"]:
			var incoming: SpellLot = shell.effect.get(material)
			var existing: SpellLot = other.effect.get(material)
			if incoming == null: continue
			if existing == null: other.effect.set(material, incoming)
			else: ledger.aggregate(_tx("merge-material"), existing, incoming)
		other.ready_at = maxf(other.ready_at, shell.ready_at) + maxf(0.1, 0.5 + shell.effect.build.value(&"merge_wait_ms") / 1000.0)
		other.expires_at = minf(other.expires_at, shell.expires_at)
		other.born_at = minf(other.born_at, shell.born_at)
		other.effect.applications = mini(other.effect.applications, shell.effect.applications)
		shell.closed = true
		return other
	return shell


func _compatible(a: StoredSpell, b: StoredSpell) -> bool:
	return a.effect.lot.root_id == b.effect.lot.root_id and a.effect.build.identity() == b.effect.build.identity() and a.position == b.position and a.effect.kind == b.effect.kind and a.effect.optional_shape == b.effect.optional_shape and a.effect.target_id == b.effect.target_id and a.effect.dispatched == b.effect.dispatched and a.returned == b.returned and a.resealed == b.resealed and a.effect.lot.claims == b.effect.lot.claims


func _choose_target(effect: BattleEffect, origin: Vector2) -> BattleEnemy:
	var target := world.enemy_by_id(effect.target_id)
	if target != null and target.alive() and BattleSession.enemy_in_combat(target) and not effect.build.has(&"blind") and not effect.build.has(&"new-target"): return target
	var candidates := _nearby(origin, 1200.0)
	if candidates.is_empty(): return null
	if effect.build.has(&"durable"):
		candidates.sort_custom(func(a: BattleEnemy, b: BattleEnemy) -> bool: return a.hp_q > b.hp_q)
	elif effect.build.has(&"near"):
		candidates.sort_custom(func(a: BattleEnemy, b: BattleEnemy) -> bool: return a.position.distance_squared_to(world.player_position) < b.position.distance_squared_to(world.player_position))
	return candidates[0]


func _commit_damage(target: BattleEnemy, packet: DamagePacket, kind: StringName, origin: Vector2, empowered: bool = false, contact_point: Vector2 = Vector2.INF) -> void:
	if not BattleSession.enemy_in_combat(target): return
	var amount := packet.actual(target.resistances)
	var applied := mini(target.hp_q, amount)
	actual_damage_q += applied
	overkill_damage_q += amount - applied
	damage_by_source[kind] = damage_by_source.get(kind, 0) + applied
	world.commit_damage(target, amount, packet.total(), kind, origin, empowered, contact_point)
	if not target.alive(): kills_by_source[kind] = kills_by_source.get(kind, 0) + 1


func _nearby(origin: Vector2, radius: float, excluded: StringName = &"") -> Array[BattleEnemy]:
	var targets: Array[BattleEnemy] = []
	for target in world._living():
		if target.id != excluded and BattleSession.enemy_in_combat(target) and ((target.position - origin) * BattleSession.ARENA_SIZE).length_squared() <= radius * radius: targets.append(target)
	targets.sort_custom(func(a: BattleEnemy, b: BattleEnemy) -> bool:
		var ad := a.position.distance_squared_to(origin)
		var bd := b.position.distance_squared_to(origin)
		return ad < bd if ad != bd else str(a.id) < str(b.id))
	return targets


func _spend_work(amount: int, claim: StringName) -> bool:
	var total := 0
	for lot in work_bank: total += lot.amount_q
	if total < amount: return false
	var remaining := amount
	for lot in work_bank:
		var cost := mini(remaining, lot.amount_q)
		ledger.spend(_tx(str(claim)), lot, cost)
		remaining -= cost
		if remaining == 0: break
	return true


func _storage_capacity() -> int:
	return maxi(1, 4 + build.value(&"storage_slots"))


func _storage_occupancy() -> int:
	var units := 0
	for shell in stored:
		if not shell.closed and not shell.transporting: units += shell.space_units
	return units


func _shell_units(snapshot: CompiledBuild, copied: bool = false) -> int:
	return 1 + snapshot.value(&"shell_space") + (1 if copied and snapshot.has(&"copy-concentrate") else 0)


func _shared_discount(snapshot: CompiledBuild) -> int:
	return mini(205, 102 + snapshot.value(&"shared_discount_q")) if snapshot.has(&"shared-work") and snapshot.value(&"material_count") >= 2 else 0


func observe_input(receipt: ManualInputReceipt) -> void:
	if build.has(&"letters") or build.has(&"continuation"):
		var opportunity := ledger.divert_work(receipt, Q / 4, build.identity())
		if opportunity != null:
			_input_opportunities.append({"receipt": receipt, "lot": opportunity, "build": build, "expires": clock + 5.0})
	for mark in letter_marks.duplicate():
		if mark.target != receipt.target_id or mark.position != receipt.position or mark.character != receipt.character or mark.version != receipt.word_version: continue
		var reward := ledger.convert(_tx("letter-redeem"), mark.lot, mark.lot.amount_q, SpellLot.Kind.POWER, 4 * Q, &"letter-reward")
		var snapshot: CompiledBuild = mark.build
		reward.packet = DamagePacket.single(reward.amount_q, ELEMENTS[snapshot.book()])
		ledger.spend(_tx("letter-loss"), reward, reward.amount_q * (Q - mini(Q, 900 + snapshot.value(&"letter_retention_q"))) / Q)
		var rewards: Array = _letter_rewards.get(receipt.attempt_id, [])
		rewards.append(reward)
		_letter_rewards[receipt.attempt_id] = rewards
		letter_marks.erase(mark)
		world.event_committed.emit({"kind": &"letter_redeem", "at": world.enemy_by_id(receipt.target_id).position, "position": receipt.position})
	if build.has(&"input-shield"):
		var opportunity := ledger.divert_work(receipt, Q / 8, build.identity(), &"input-shield")
		if opportunity != null:
			ledger.spend(_tx("input-shield"), opportunity, opportunity.amount_q)
			run.shield_q = mini(20 * Q, run.shield_q + Q / 2)
	if build.has(&"input-slow") or (build.has(&"local-slow") and build.has(&"cold")):
		var opportunity := ledger.divert_work(receipt, Q / 4, build.identity(), &"input-slow")
		if opportunity != null:
			if build.has(&"local-slow") and build.has(&"cold"):
				opportunity = ledger.convert(_tx("input-slow-cold"), opportunity, opportunity.amount_q, SpellLot.Kind.COLD, 16 * Q, &"input-slow")
			ledger.spend(_tx("input-slow"), opportunity, opportunity.amount_q)
			var target := world.enemy_by_id(receipt.target_id)
			if target != null:
				for neighbor in _nearby(target.position, 120.0): neighbor.local_slow_time = maxf(neighbor.local_slow_time, 0.35)


func _distribute_letters(target: BattleEnemy) -> void:
	if world.typing.target_id != target.id or world.typing.progress <= 0: return
	var attempt := world.typing.current_attempt_id()
	if _dead_inputs.has(attempt): return
	_dead_inputs[attempt] = true
	var available: Array[Dictionary] = _input_opportunities.filter(func(item: Dictionary) -> bool:
		return item.receipt.attempt_id == attempt and item.lot.amount_q > 0)
	if build.has(&"continuation") and not available.is_empty():
		var protection: SpellLot = available[0].lot
		var amount := protection.amount_q
		ledger.spend(_tx("continuation"), protection, amount)
		run.shield_q = mini(20 * Q, run.shield_q + amount * 4)
	if not build.has(&"letters"): return
	var positions := 4 + build.value(&"letter_positions") + (6 if build.mode(&"mark-target-spread") == &"K15" else 0)
	var used_targets: Dictionary[StringName, bool] = {}
	for item in available:
		if positions <= 0: break
		var receipt: ManualInputReceipt = item.receipt
		for candidate in _nearby(target.position, 1400.0, target.id):
			if used_targets.has(candidate.id) and (build.has(&"mark-spread") or build.mode(&"mark-target-spread") == &"K15"): continue
			var word := candidate.word.replace(" ", "")
			var position := word.find(receipt.character) + 1
			if position < 1: continue
			var lot: SpellLot = item.lot
			if lot.amount_q == 0: break
			var portion := ledger.transfer(_tx("letter-mark"), lot, lot.amount_q, &"letter-mark")
			if build.has(&"letter-heavy"):
				for extra in available:
					if extra.lot != lot and extra.lot.amount_q > 0:
						ledger.aggregate(_tx("letter-heavy"), portion, extra.lot)
						break
			letter_marks.append({"lot": portion, "target": candidate.id, "position": position, "character": receipt.character, "version": world.typing.target_version(candidate.id), "build": item.build, "expires": clock + 5.0})
			used_targets[candidate.id] = true
			positions -= 1
			world.event_committed.emit({"kind": &"letter_mark", "at": candidate.position, "position": position})
			break


func graze(threat: BattleThreat) -> void:
	if threat.grazed or threat.reflected or not build.has(&"graze"): return
	threat.grazed = true
	var lot := ledger.earn(threat.attack_id, &"graze", build.identity(), SpellLot.Kind.OPPORTUNITY, Q, &"graze")
	if lot == null: return
	ledger.spend(_tx("graze"), lot, Q)
	var shield := 768 if build.has(&"graze-shield") else 512
	run.shield_q = mini(20 * Q, run.shield_q + shield)
	world.resonance_q = mini(BattleSession.ULTIMATE_COST_Q, world.resonance_q + Q - shield)


func on_dodge(origin: Vector2, destination: Vector2) -> void:
	if build.has(&"dodge-window") and _spend_work(Q, &"dodge-window"):
		world.dodge_window += 0.35
	if build.has(&"trail") or build.has(&"dodge-pull"):
		var lot := _convert_work(2 * Q, 3 * Q, &"trail")
		if lot != null:
			var effect := _effect(lot, &"flame_burn", &"", origin, build)
			_field(effect, origin, 130.0, 4, 0.5)
			fields.back().endpoint = destination if build.has(&"trail") else origin
			if build.has(&"dodge-pull"):
				for target in _nearby(origin, 200.0): target.impulse += (origin - target.position).normalized() * 100.0 / target.mass
	if build.has(&"dodge-clear") or build.has(&"input-clear"):
		var lot := _convert_work(2 * Q, 6 * Q, &"clear")
		if lot != null: _clear_threats(lot, destination, 180.0)


func _convert_work(amount: int, ratio: int, owner: StringName) -> SpellLot:
	var total := 0
	for lot in work_bank: total += lot.amount_q
	if total < amount: return null
	var remaining := amount
	var output: SpellLot = null
	for fee in work_bank:
		if remaining == 0: break
		var cost := mini(remaining, fee.amount_q)
		if cost == 0: continue
		remaining -= cost
		var lot := ledger.convert(_tx("work-conversion"), fee, cost, SpellLot.Kind.POWER, ratio, owner)
		lot.packet = DamagePacket.single(lot.amount_q, ELEMENTS[build.book()])
		if output == null: output = lot
		else: ledger.aggregate(_tx("work-join"), output, lot)
	return output


func _clear_threats(lot: SpellLot, origin: Vector2, radius: float) -> void:
	for threat in world.threats.duplicate():
		if threat.reflected or ((threat.position - origin) * BattleSession.ARENA_SIZE).length() > radius: continue
		var blocked := mini(lot.amount_q, threat.damage_q)
		ledger.spend(_tx("clear-threat"), lot, blocked)
		threat.damage_q -= blocked
		if threat.damage_q == 0: world.threats.erase(threat)
		if lot.amount_q == 0: break
	_recover(lot, false)


func pickup(spirit: BattleSpirit) -> StoredSpell:
	if spirit.effect == null or not spirit.effect.build.has(&"transport"): return null
	if spirit.effect.build.mode(&"transport-mode") == &"K13" and spirit.slot != 0: return null
	var candidates: Array[StoredSpell] = stored.filter(func(shell: StoredSpell) -> bool:
		return not shell.closed and not shell.transporting and shell.expires_at > clock)
	if candidates.is_empty(): return null
	candidates.sort_custom(func(a: StoredSpell, b: StoredSpell) -> bool:
		return a.effect.lot.amount_q > b.effect.lot.amount_q if build.mode(&"transport-mode") == &"K13" else a.born_at < b.born_at)
	var shell := candidates[0]
	if spirit.effect.build.mode(&"transport-mode") == &"K12":
		for iteration in 3:
			var merged := _merge(shell)
			if merged == shell: break
			shell = merged
	var loss := shell.effect.lot.amount_q * (Q - mini(Q, 900 + shell.effect.build.value(&"transport_retention_q"))) / Q
	ledger.spend(_tx("transport-loss"), shell.effect.lot, loss)
	ledger.spend(_tx("transport-opportunity"), spirit.effect.lot, spirit.effect.lot.amount_q)
	shell.transporting = true
	shell.effect.target_id = spirit.target_id
	world.event_committed.emit({"kind": &"transport", "at": shell.position, "target": spirit.endpoint})
	return shell


func deliver(shell: StoredSpell, target: BattleEnemy, at: Vector2) -> bool:
	if shell.closed: return true
	shell.position = at
	if shell.expires_at <= clock:
		_close_shell(shell, &"expiry")
		return true
	if shell.ready_at > clock: return false
	shell.effect.target_id = target.id
	_close_shell(shell, &"release")
	return true


func return_cargo(shell: StoredSpell, at: Vector2) -> void:
	if shell.closed: return
	shell.position = at
	shell.transporting = false
	if shell.expires_at > clock and shell.effect.build.has(&"return") and not shell.returned and _storage_occupancy() <= _storage_capacity():
		shell.returned = true
		shell.ready_at = clock + 0.5 + shell.effect.build.value(&"return_wait_ms") / 1000.0
	else:
		_close_shell(shell, &"lost")


func _reserve_order(material: int) -> int:
	if build.has(&"charge-priority") and material == SpellLot.Kind.CHARGE: return -1
	return [0, 4, 3, 1, 2, 5][material]


func _next() -> int:
	_serial += 1
	return _serial


func _tx(kind: String) -> String:
	return "%s:%s:%s" % [ledger.room_id, kind, _next()]


func body_contact(a: BattleEnemy, b: BattleEnemy) -> void:
	for pair in [[a, b], [b, a]]:
		var source: BattleEnemy = pair[0]
		var victim: BattleEnemy = pair[1]
		if not _collision_strikes.has(source.id): continue
		var effect := _collision_strikes[source.id]
		_collision_strikes.erase(source.id)
		if effect.expires_at > clock: contact(effect, victim, source.position)
		else: retire(effect)


func _reserve_space() -> int:
	var space := 0
	for lot in reserve: space += lot.amount_q * SpellLot.SPACE_WEIGHTS[lot.material]
	return space


func retarget(effect: BattleEffect, origin: Vector2, excluded: PackedStringArray) -> BattleEnemy:
	var target := world._nearest_living(origin, excluded)
	if effect.build.has(&"return-target"):
		if effect.lot.claims.has(&"return-target") or target == null or ((target.position - origin) * BattleSession.ARENA_SIZE).length() > 600.0: return null
		effect.lot.claims[&"return-target"] = true
	return target


func abandon_attempt(attempt: String) -> void:
	for item in _input_opportunities.duplicate():
		if item.receipt.attempt_id == attempt:
			ledger.spend(_tx("abandon-opportunity"), item.lot, item.lot.amount_q)
			_input_opportunities.erase(item)
	# Death has already transferred marked opportunities to other word versions.
	# Abandoning the old attempt only forfeits value it still owns.
	for lot: SpellLot in _letter_rewards.get(attempt, []):
		ledger.spend(_tx("abandon-reward"), lot, lot.amount_q)
	_letter_rewards.erase(attempt)


func _arc_route(effect: BattleEffect, origin: Vector2, distance: float) -> Array[Dictionary]:
	var enemies := _nearby(origin, 1500.0)
	for enemy in enemies:
		if str(enemy.id) not in effect.visited and ((enemy.position - origin) * BattleSession.ARENA_SIZE).length() <= distance:
			return [{"enemy": enemy, "position": enemy.position}]
	var nodes: Array[Dictionary] = [{"position": origin}]
	if effect.build.has(&"relay"):
		for shell in stored:
			if shell.closed or shell.expires_at <= clock or shell.effect.lot.claims.has(&"relay") or (shell.transporting and not effect.build.has(&"cargo-relay")): continue
			if shell.transporting and (shell.effect.charge == null or shell.effect.charge.amount_q < Q): continue
			nodes.append({"shell": shell, "position": shell.position})
	if effect.build.has(&"field-relay"):
		for field in fields:
			if field.expires_at > clock and not field.relayed and field.remaining_pulses > 0: nodes.append({"field": field, "position": field.center})
	for enemy in enemies:
		if str(enemy.id) not in effect.visited: nodes.append({"enemy": enemy, "position": enemy.position})
	var distances: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	for node in nodes:
		distances.append(INF)
		previous.append(-1)
		visited.append(false)
	distances[0] = 0.0
	for iteration in nodes.size():
		var current := -1
		for index in nodes.size():
			if not visited[index] and (current < 0 or distances[index] < distances[current]): current = index
		if current < 0 or distances[current] == INF: break
		visited[current] = true
		if nodes[current].has("enemy"):
			var route: Array[Dictionary] = []
			while current > 0:
				route.push_front(nodes[current])
				current = previous[current]
			return route
		for index in range(1, nodes.size()):
			if visited[index]: continue
			if effect.build.mode(&"chain-mode") != &"K08" and current != 0 and not nodes[index].has("enemy"): continue
			var edge := (Vector2(nodes[index].position) - Vector2(nodes[current].position)) * BattleSession.ARENA_SIZE
			var range_limit := distance * (Q + effect.build.value(&"relay_range_q")) / Q if nodes[current].has("field") else distance
			if edge.length() <= range_limit and distances[current] + edge.length() + 1.0 < distances[index]:
				distances[index] = distances[current] + edge.length() + 1.0
				previous[index] = current
	return []
