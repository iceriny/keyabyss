extends SceneTree

var failures := 0
var sessions: Array[BattleSession] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_curved_trajectory()
	for grade: StringName in [&"success", &"perfect"]:
		var session := _session()
		var events: Array[Dictionary] = []
		session.event_committed.connect(func(event: Dictionary) -> void: events.append(event))
		session._commit_action(&"parry")
		_check(is_equal_approx(session.parry_window, 0.30) and is_equal_approx(session.parry_cooldown, 0.7), "defense opens 0.30 seconds and retains cooldown")
		session.parry_window = 0.15 if grade == &"success" else 0.25
		var bystander_shot := _threat(session, Vector2(0, 100), Vector2(100, 0), "bystander-" + str(grade))
		var bystander_start := bystander_shot.position
		var shot := _threat(session, Vector2(35, 0), Vector2(-200, 0), "defense-" + str(grade))
		var hp := session.player_hp_q
		session._advance_threats(0.05)
		_check(session.player_hp_q == hp, "%s protects the real player collision" % grade)
		_check(shot.reflected == (grade == &"perfect"), "only perfect defense reflects")
		_check(session.threats.has(shot) == (grade == &"perfect"), "success consumes the attack instead of leaving it hostile")
		_check(not bystander_shot.reflected and session.threats.has(bystander_shot) and bystander_shot.position.y > bystander_start.y, "a nearby unblocked shot is physically deflected outward while staying hostile")
		if grade == &"perfect":
			var return_direction := ((session.enemies[0].position - shot.position) * BattleSession.ARENA_SIZE).normalized()
			_check(shot.velocity.normalized().is_equal_approx(return_direction) and is_equal_approx(shot.velocity.length(), 540.0), "the defended projectile returns to its source without receiving the radial impulse")
		_check(events.any(func(event: Dictionary) -> bool: return event.kind == &"counter_pulse" and event.grade == grade), "feedback exposes defense grade")
		_check(session.hurt_window == 0.0, "defense does not grant a global hurt invulnerability window")
		_check(session.enemies[1].hp_q == session.enemies[1].max_hp_q and session.enemies[1].stagger_time == 0.0, "defense does not damage or interrupt nearby bystanders")
	for grade: StringName in [&"success", &"perfect"]:
		var pulse := _session()
		var attacker := pulse.enemies[0]
		var neighbor := pulse.enemies[1]
		attacker.position = pulse.player_position + Vector2(80, 0) / BattleSession.ARENA_SIZE
		neighbor.position = pulse.player_position + Vector2(0, 159) / BattleSession.ARENA_SIZE
		neighbor.charge_time = 1.0
		neighbor.aiming = true
		neighbor.melee_strike = 0.16
		neighbor.velocity = Vector2(30, 40)
		neighbor.delayed_attacks.append({"remaining": 0.3, "pattern": &"fan"})
		var outside_enemy := BattleEnemy.new()
		outside_enemy.id = &"outside_pulse"
		outside_enemy.hp_q = 100 * BattleSession.Q
		outside_enemy.position = pulse.player_position + Vector2(161, 0) / BattleSession.ARENA_SIZE
		pulse.enemies.append(outside_enemy)
		pulse._enemies_by_id[outside_enemy.id] = outside_enemy
		pulse._commit_action(&"parry")
		_check(attacker.impulse.is_zero_approx() and neighbor.impulse.is_zero_approx(), "activation alone never pushes enemies")
		pulse.parry_window = 0.15 if grade == &"success" else 0.25
		_threat(pulse, Vector2(35, 0), Vector2(-200, 0), "pulse-" + str(grade))
		pulse._advance_threats(0.05)
		if grade == &"perfect":
			_check(attacker.impulse.x > 0.0 and neighbor.impulse.y > 0.0 and neighbor.charge_time == 0.0, "perfect defense pushes surrounding enemies outward and stops their charge")
			_check(attacker.impulse.length() * sqrt(attacker.mass) > neighbor.impulse.length() * sqrt(neighbor.mass), "direct attacker receives the stronger counter push")
			neighbor.impulse *= 0.5
			var remaining_impulse := neighbor.impulse
			pulse._parry_feedback(attacker.id, grade)
			_check(neighbor.impulse == remaining_impulse, "one defense window emits only one crowd pulse")
		else:
			_check(attacker.impulse.x > 0.0 and neighbor.impulse.y > 0.0 and is_equal_approx(neighbor.impulse.length() * sqrt(neighbor.mass), 1575.0 * (1.0 - 0.25 * 159.0 / 278.0) * 0.15), "ordinary defense pushes at fifteen percent of perfect strength")
			_check(neighbor.charge_time == 1.0 and neighbor.aiming and neighbor.melee_strike == 0.16 and neighbor.velocity == Vector2(30, 40) and neighbor.delayed_attacks.size() == 1 and neighbor.stagger_time == 0.0 and neighbor.attack_clock == 100.0, "ordinary push preserves motion, windup, strikes and queued attacks")
		_check(outside_enemy.impulse.is_zero_approx() and outside_enemy.stagger_time == 0.0, "counter pulse excludes enemies beyond 160px")
		_check(neighbor.hp_q == neighbor.max_hp_q, "crowd push adds no area damage")
	_check_projectile_push()
	_check_reflect_window()
	var charging := _session()
	var charger := charging.enemies[0]
	charger.position = charging.player_position + Vector2(40, 0) / BattleSession.ARENA_SIZE
	charger.charge_direction = Vector2.LEFT
	charger.charge_time = 1.0
	charging._commit_action(&"parry")
	charging.parry_window = 0.15
	charging._advance_enemy_motion(0.01)
	_check(charger.charge_time == 0.0 and charger.stagger_time > 0.0 and charger.velocity.is_zero_approx(), "ordinary defense ends the colliding charge")
	_check(charging.player_impulse.x < 0.0 and charger.impulse.x > 0.0, "ordinary charge defense sends the player and attacker in opposite directions")
	charging.parry_window = 0.0
	charging._advance_enemy_motion(0.01)
	_check(charging.player_hp_q == charging.player_max_hp_q and charger.charge_time == 0.0, "the defended charge cannot settle damage again during its recoil")
	var graze := _session()
	graze._commit_action(&"parry")
	var passing := _threat(graze, Vector2(40, 40), Vector2(-400, 0), "graze")
	graze._advance_threats(0.05)
	_check(not passing.reflected and graze.threats.has(passing) and not graze._parry_succeeded, "a 40px near miss is never defended by the old 54px range")
	var prediction := _session()
	prediction._commit_action(&"parry")
	var approaching := _threat(prediction, Vector2(40, 0), Vector2(-200, 0), "prediction")
	prediction._advance_threats(0.01)
	_check(approaching.reflected, "short prediction catches an actual imminent player hit")
	var distant := _session()
	distant._commit_action(&"parry")
	var later := _threat(distant, Vector2(54, 0), Vector2(-200, 0), "beyond-prediction")
	distant._advance_threats(0.01)
	_check(not later.reflected and not distant._parry_succeeded, "prediction remains bounded to 0.06 seconds")
	for grade: StringName in [&"success", &"perfect"]:
		var melee := _session()
		var source := melee.enemies[0]
		source.boss = true
		source.position = melee.player_position + Vector2(80, 0) / BattleSession.ARENA_SIZE
		source.melee_origin = source.position
		source.melee_direction = Vector2.LEFT
		source.melee_strike = 0.16
		source.aiming = true
		source.charge_time = 1.0
		source.delayed_attacks.append({"remaining": 0.3, "pattern": &"fan"})
		var hp := source.hp_q
		melee.parry_window = 0.15 if grade == &"success" else 0.25
		melee._resolve_melee(source)
		_check(source.melee_hit and melee.player_hp_q == melee.player_max_hp_q, "melee defense consumes the strike and protects the player")
		if grade == &"perfect":
			_check(source.hp_q < hp and melee.runtime.damage_by_source.get(&"counter", 0) > 0, "perfect melee defense settles actual counter damage against its attacker")
			_check(not source.aiming and source.charge_time == 0.0 and source.delayed_attacks.is_empty() and source.stagger_time > 0.0, "perfect melee defense interrupts a Boss and cancels saved volleys")
			var after_counter := source.hp_q
			melee._counter_contact(source)
			_check(source.hp_q == after_counter, "the same melee strike cannot settle counter damage twice")
		else:
			_check(source.hp_q == hp and source.stagger_time == 0.0 and not source.delayed_attacks.is_empty(), "ordinary melee defense does not grant counter damage or perfect interruption")
	for kind: StringName in [&"blast", &"laser"]:
		for grade: StringName in [&"success", &"perfect"]:
			var area_hit := _session()
			var active := _hazard(area_hit, kind, 0.0)
			var feedback: Array[Dictionary] = []
			area_hit.event_committed.connect(func(event: Dictionary) -> void: feedback.append(event))
			area_hit.parry_window = 0.15 if grade == &"success" else 0.25
			area_hit._advance_hazards(0.01)
			_check(area_hit.player_hp_q == area_hit.player_max_hp_q - active.damage_q and not area_hit._parry_succeeded and area_hit.resonance_q == 0, "%s AOE passes through %s defense without a reward" % [kind, grade])
			_check(not feedback.any(func(event: Dictionary) -> bool: return event.kind == &"counter_pulse"), "AOE never produces a counter pulse")
			area_hit.hurt_window = 0.0
			area_hit._advance_hazards(0.1)
			_check(area_hit.player_hp_q == area_hit.player_max_hp_q - active.damage_q, "one AOE settles damage once")
	var area := _session()
	area._take_player_damage(5 * BattleSession.Q, "one-hit")
	area.hurt_window = 0.0
	area._take_player_damage(5 * BattleSession.Q, "one-hit")
	_check(area.player_hp_q == area.player_max_hp_q - 5 * BattleSession.Q, "one attack cannot settle damage twice")
	var counter := _session()
	var boss := counter.enemies[0]
	boss.boss = true
	boss.aiming = true
	boss.charge_time = 1.0
	boss.delayed_attacks.append({"remaining": 0.3, "pattern": &"fan"})
	var nearby := _threat(counter, Vector2(519, 0), Vector2.LEFT * 100, "rune-inside")
	var outside := _threat(counter, Vector2(521, 0), Vector2.LEFT * 100, "rune-outside")
	_check(counter.reflect_projectiles_in_radius(counter.player_position, 520.0) == 1, "counter radius includes 519px and excludes 521px")
	counter.interrupt_enemies_in_radius(counter.player_position, 520.0)
	_check(nearby.reflected and not outside.reflected and not boss.aiming and boss.delayed_attacks.is_empty() and boss.charge_time == 0.0, "counter reflects range attacks and interrupts Bosses")
	_check(counter.reflect_projectiles_in_radius(counter.player_position, 520.0) == 0, "already reflected projectiles cannot create a second counter")
	counter.threats.clear()
	counter._emit_enemy_threat(boss, 0.0, 7, 100.0, 6.0)
	var first_attack_id := counter.threats[0].attack_id
	counter.threats.clear()
	counter._emit_enemy_threat(boss, 0.0, 7, 100.0, 6.0)
	_check(counter.threats[0].attack_id != first_attack_id, "later volleys cannot reuse a retired projectile identity")
	var safe := _session()
	for enemy in safe.enemies: enemy.hp_q = 0
	var danger := BattleHazard.new()
	danger.kind = &"blast"
	danger.center = safe.player_position + Vector2(0, -240) / BattleSession.ARENA_SIZE
	danger.radius = 170.0
	danger.warning_remaining = 1.1
	danger.active_remaining = 0.3
	safe.hazards.append(danger)
	var landing := BattleSession.clamp_player(safe.player_position + safe._safe_direction() * 240.0 / BattleSession.ARENA_SIZE)
	_check(danger.clearance(landing) >= 20.0, "auto dodge avoids a hazard firing after protection ends")
	safe.hazards.clear()
	var trajectory := _threat(safe, Vector2(240, -400), Vector2(0, 360), "late-trajectory")
	var selected := BattleSession.clamp_player(safe.player_position + safe._safe_direction() * 240.0 / BattleSession.ARENA_SIZE) * BattleSession.ARENA_SIZE
	var crossing := trajectory.position * BattleSession.ARENA_SIZE + trajectory.velocity * 1.2
	_check(selected.distance_to(crossing) > 50.0, "auto dodge considers late projectile passage instead of one projected point")
	var spirit := _session()
	spirit.spirit_time = 10.0
	var blade := BattleSpirit.new()
	blade.position = spirit.player_position
	blade.begin(&"return", spirit.player_position + Vector2(300, 0) / BattleSession.ARENA_SIZE)
	spirit.spirits.append(blade)
	spirit._advance_blades(0.1)
	_check(is_equal_approx(blade.flight_time, 0.075) and is_equal_approx(spirit.spirit_time, 10.0), "paper spirit travel slows by 25 percent without consuming the separate input-maintenance clock")
	var statistics := prediction.finish_room(&"fixture").statistics
	_check(statistics.defense_successes == 1 and statistics.perfect_defenses == 1, "room result snapshots actual committed defense outcomes")
	_check_world_clocks()
	_check_perfect_dodge()
	for session in sessions: session.free()
	print("Defense and movement: %s failure(s)" % failures)
	quit(1 if failures else 0)


func _check_curved_trajectory() -> void:
	for turn in [-0.32, 0.32]:
		for offset in [Vector2(280, 0), Vector2(-380, 140), Vector2(900, 0)]:
			var aimed := _session()
			var enemy := aimed.enemies[0]
			enemy.position = aimed.player_position + offset / BattleSession.ARENA_SIZE
			enemy.previous_position = enemy.position
			enemy.aimed_position = aimed.player_position
			aimed._emit_pattern(enemy, &"single", turn)
			var shot := aimed.threats[-1]
			_check(shot.position == enemy.position and shot.curvature != 0.0, "curved shot launches from its enemy with nonzero turning")
			_check(absf(shot.velocity.normalized().cross(-offset.normalized())) > 0.05, "launch tangent compensates for the bend instead of pointing straight at PC")
			var aimed_hp := aimed.player_hp_q
			for tick in 600:
				aimed._advance_threats(1.0 / 60.0)
				if aimed.player_hp_q < aimed_hp or aimed.threats.is_empty(): break
			_check(aimed.player_hp_q < aimed_hp, "the actual curved flight crosses and damages stationary PC: %s/%s" % [turn, offset])
	for growth in [0.0, 0.12]:
		var shot := BattleThreat.new()
		shot.velocity = Vector2.RIGHT * 125.0
		shot.curvature = -0.32
		shot.acceleration = growth
		var target := Vector2(-1500, 300)
		var arrival := shot.aim_curve(target)
		var end := BattleThreat.flight_displacement(shot.velocity, shot.curvature, growth, arrival)
		_check(end.distance_to(target) < 0.002 and shot.life > arrival, "far target remains reachable before expiry, with or without acceleration")
		var half := BattleThreat.flight_displacement(shot.velocity, shot.curvature, growth, arrival * 0.5)
		_check(absf(half.cross(target.normalized())) > 50.0, "the trajectory has a visible bend rather than a straight projectile")
		var first := BattleThreat.flight_displacement(shot.velocity, shot.curvature, growth, arrival * 0.37)
		var velocity := BattleThreat.flight_velocity(shot.velocity, shot.curvature, growth, arrival * 0.37)
		var rest := BattleThreat.flight_displacement(velocity, shot.curvature, growth, arrival * 0.63)
		_check((first + rest).distance_to(end) < 0.002, "fixed-step flight and longer prediction partitions share the same path")
	var moved := _session()
	var boundary := _session()
	boundary.player_position = Vector2(0.85, 0.065)
	boundary.previous_player_position = boundary.player_position
	boundary.enemies[0].position = Vector2(0.12, 0.065)
	boundary.enemies[0].aimed_position = boundary.player_position
	boundary._emit_pattern(boundary.enemies[0], &"single", 0.32)
	var boundary_hp := boundary.player_hp_q
	for tick in 900:
		boundary._advance_threats(1.0 / 60.0)
		if boundary.player_hp_q < boundary_hp or boundary.threats.is_empty(): break
	_check(boundary.player_hp_q < boundary_hp, "aimed curve near the arena boundary does not vanish before reaching PC")
	var source := moved.enemies[0]
	source.position = moved.player_position + Vector2(500, 0) / BattleSession.ARENA_SIZE
	source.aimed_position = moved.player_position
	moved._emit_pattern(source, &"single", 0.32)
	moved.player_position += Vector2(0, -160) / BattleSession.ARENA_SIZE
	moved.previous_player_position = moved.player_position
	var hp := moved.player_hp_q
	for tick in 360: moved._advance_threats(1.0 / 60.0)
	_check(moved.player_hp_q == hp, "PC can leave the launch-time aim; curved flight does not home")
	var fan := _session()
	source = fan.enemies[0]
	source.position = fan.player_position + Vector2(450, -120) / BattleSession.ARENA_SIZE
	source.aimed_position = fan.player_position
	fan._emit_pattern(source, &"fan", -0.22)
	hp = fan.player_hp_q
	for tick in 360: fan._advance_threats(1.0 / 60.0)
	_check(fan.player_hp_q < hp, "the central curved fan lane crosses its aimed PC")
	for action: StringName in [&"parry", &"dodge_down"]:
		var defense := _session()
		var shot := _threat(defense, Vector2(40, 0), Vector2.LEFT * 200.0, "curved-" + str(action))
		shot.curvature = 0.32
		shot.acceleration = 0.12
		shot.aim_curve(Vector2(-40, 0))
		if action == &"parry":
			defense._advance_threats(0.01)
			defense._commit_action(action)
			defense._advance_threats(0.01)
			_check(shot.reflected and shot.curvature == 0.0, "perfect defense predicts the curved head and sends it back to the source")
		else:
			defense._commit_action(action)
			_check(defense.perfect_dodge_remaining == 1.0, "perfect dodge predicts the curved head using the same flight integral")
	var tail := _session()
	var distant := _threat(tail, Vector2(300, 0), Vector2.RIGHT * 125.0, "curved-tail")
	distant.curvature = 0.32
	distant.trail.append(tail.player_position)
	tail._advance_threats(1.0 / 60.0)
	_check(tail.player_hp_q == tail.player_max_hp_q, "decorative history crossing PC never deals damage")
	print("Curved trajectory: origin, both turns, distant aim, partitions, fan, evasion, defense and harmless trail checked")


func _check_perfect_dodge() -> void:
	var precise := _session()
	var events: Array[Dictionary] = []
	precise.event_committed.connect(func(event: Dictionary) -> void: events.append(event))
	_threat(precise, Vector2(36, 0), Vector2(-200, 0), "precise-dodge")
	precise._commit_action(&"dodge_down")
	_check(precise.resonance_q == 5 * BattleSession.Q and precise.dodge_window == 1.0 and precise.perfect_dodge_remaining == 1.0, "an imminent real collision grants five resonance and slow time without extending dodge protection")
	_check(is_equal_approx(precise.world_delta(1.25), 0.35), "perfect dodge slow time expires at its one-second protection boundary within a long step")
	precise.step(0.4)
	_check(is_equal_approx(precise.dodge_window, 0.6) and is_equal_approx(precise.perfect_dodge_remaining, 0.6) and precise.player_hp_q == precise.player_max_hp_q, "protection and perfect dodge feedback both advance in real seconds")
	precise.step(0.61)
	_check(precise.dodge_window == 0.0 and precise.perfect_dodge_remaining == 0.0 and precise.world_time_scale == 1.0, "perfect dodge slow time ends with the original invulnerability")
	var successes := 0
	for event in events:
		if event.kind == &"perfect_dodge": successes += 1
	_check(successes == 1, "one dodge emits its perfect reward only once")
	for offset in [Vector2(60, 0), Vector2(36, 40)]:
		var early := _session()
		_threat(early, offset, Vector2(-200, 0), "early-or-miss")
		early._commit_action(&"dodge_down")
		_check(early.perfect_dodge_remaining == 0.0 and early.resonance_q == 0, "an early dodge or a near miss never receives the precise reward: %s" % offset)
	var protected := _session()
	protected.dodge_window = 0.5
	_threat(protected, Vector2(36, 0), Vector2(-200, 0), "already-protected")
	protected._commit_action(&"dodge_down")
	_check(protected.perfect_dodge_remaining == 0.0 and protected.resonance_q == 0, "dodging again while already protected cannot farm the reward")
	var melee := _session()
	var attacker := melee.enemies[0]
	attacker.behavior = &"melee"
	attacker.aiming = true
	attacker.melee_hit = true # The previous strike settled; the current windup is a new attack.
	attacker.attack_clock = 0.08
	attacker.melee_origin = melee.player_position + Vector2(80, 0) / BattleSession.ARENA_SIZE
	attacker.melee_direction = Vector2.LEFT
	melee._commit_action(&"dodge_down")
	_check(melee.perfect_dodge_remaining == 1.0, "a new imminent melee windup participates even after the previous strike settled")
	var charge := _session()
	var ram := charge.enemies[0]
	ram.position = charge.player_position + Vector2(90, 0) / BattleSession.ARENA_SIZE
	ram.charge_direction = Vector2.LEFT
	ram.charge_time = 0.5
	charge._commit_action(&"dodge_down")
	_check(charge.perfect_dodge_remaining == 1.0, "an approaching charge participates in precise dodge timing")
	for kind: StringName in [&"blast", &"laser", &"horizontal"]:
		var area := _session()
		_hazard(area, kind, 0.08)
		area._commit_action(&"dodge_right")
		_check(area.perfect_dodge_remaining == 1.0 and area.resonance_q == 5 * BattleSession.Q, "%s AOE grants one precise dodge reward" % kind)
		area._advance_hazards(0.08)
		area._advance_hazards(0.01)
		_check(area.player_hp_q == area.player_max_hp_q, "AOE remains dodgeable during invulnerability")
		var early := _session()
		_hazard(early, kind, 0.2)
		early._commit_action(&"dodge_right")
		_check(early.perfect_dodge_remaining == 0.0, "early AOE dodge receives no precise reward")
		var missed := _session()
		var distant := _hazard(missed, kind, 0.08)
		distant.center.x += 0.3
		distant.origin += Vector2(.3, .3)
		distant.end += Vector2(.3, .3)
		missed._commit_action(&"dodge_right")
		_check(missed.perfect_dodge_remaining == 0.0, "an imminent AOE outside the collision footprint receives no reward")
	var recoil := _session()
	var crossing := _hazard(recoil, &"laser", 0.08)
	crossing.origin.x += 0.03
	crossing.end.x += 0.03
	recoil.player_impulse = Vector2(900, 0)
	recoil._commit_action(&"dodge_down")
	_check(recoil.perfect_dodge_remaining == 1.0, "imminent recoil into an AOE participates in precise dodge timing")


func _hazard(session: BattleSession, kind: StringName, warning: float) -> BattleHazard:
	var hazard := BattleHazard.new()
	hazard.kind = &"laser" if kind == &"horizontal" else kind
	hazard.source_id = session.enemies[0].id
	hazard.attack_id = "area-%s" % sessions.size()
	hazard.center = session.player_position
	hazard.origin = Vector2(0, hazard.center.y) if kind == &"horizontal" else Vector2(hazard.center.x, 0)
	hazard.end = Vector2(1, hazard.center.y) if kind == &"horizontal" else Vector2(hazard.center.x, 1)
	hazard.radius = 60.0
	hazard.width = 19.5
	hazard.warning_remaining = warning
	hazard.active_remaining = 0.5
	hazard.damage_q = 10 * BattleSession.Q
	session.hazards.append(hazard)
	return hazard


func _check_projectile_push() -> void:
	for grade: StringName in [&"success", &"perfect"]:
		var pulse := _session()
		pulse._commit_action(&"parry")
		var nearby := _threat(pulse, Vector2(0, 100), Vector2(80, 0), "pushed-" + str(grade))
		nearby.curvature = 0.4
		nearby.acceleration = 0.1
		var outside := _threat(pulse, Vector2(0, 161), Vector2(80, 0), "unpushed-" + str(grade))
		var friendly := _threat(pulse, Vector2(0, -100), Vector2(80, 0), "reflected-" + str(grade))
		friendly.reflected = true
		pulse._parry_feedback(pulse.enemies[0].id, grade)
		var expected_push := 1575.0 * (1.0 - 0.25 * 100.0 / 278.0) * (1.0 if grade == &"perfect" else 0.15)
		_check(nearby.velocity.is_equal_approx(Vector2(80, expected_push)), "successful defense adds a radial projectile impulse with the matching strength")
		_check(not nearby.reflected and nearby.source_id == pulse.enemies[0].id and nearby.effect == null and nearby.damage_q == 10 * BattleSession.Q, "nearby hostile shots keep their source, allegiance and damage")
		_check(nearby.curvature == 0.4 and nearby.acceleration == 0.1 and nearby.life == 6.0, "a radial projectile push preserves its remaining flight behavior")
		_check(outside.velocity == Vector2(80, 0) and friendly.velocity == Vector2(80, 0), "the pulse excludes distant and already reflected projectiles")
		var after_push := nearby.velocity
		pulse._parry_feedback(pulse.enemies[0].id, grade)
		_check(nearby.velocity == after_push, "one defense window applies only one surrounding projectile impulse")


func _check_reflect_window() -> void:
	var chain := _session()
	var pulses: Array[Dictionary] = []
	chain.event_committed.connect(func(event: Dictionary) -> void:
		if event.kind == &"counter_pulse": pulses.append(event))
	chain._commit_action(&"parry")
	chain.parry_window = 0.205
	var first := _threat(chain, Vector2(28, 0), Vector2(-200, 0), "chain-first")
	chain._advance_threats(0.01)
	_check(first.reflected and is_equal_approx(chain._perfect_reflect_remaining, 0.30), "first perfect hit opens a fresh 0.30 second reflection window")
	var resonance := chain.resonance_q
	for index in 2:
		chain.step(0.11)
		var followup := _threat(chain, Vector2(0, 28), Vector2(0, -200), "chain-followup-%s" % index)
		chain._advance_threats(0.01)
		_check(followup.reflected, "later hits reflect beyond the initial perfect timing and original defense expiry")
	_check(is_equal_approx(chain._perfect_reflect_remaining, 0.08) and is_equal_approx(chain.counter_slow_remaining, 0.30), "followup hits never refresh reflection or slow time")
	_check(pulses.size() == 1 and chain.resonance_q == resonance, "the reflection window emits one crowd pulse and one resonance reward")
	chain.step(0.09)
	var hp := chain.player_hp_q
	var expired := _threat(chain, Vector2(0, -28), Vector2(0, 200), "chain-expired")
	chain._advance_threats(0.01)
	_check(not expired.reflected and chain.player_hp_q < hp, "reflection ends after 0.30 real seconds despite slow motion")
	var cancelled := _session()
	cancelled._commit_action(&"parry")
	cancelled._parry_feedback(cancelled.enemies[0].id, &"perfect")
	cancelled._commit_action(&"dodge_left")
	_check(cancelled.parry_window == 0.0 and cancelled._perfect_reflect_remaining == 0.0, "dodge cancels the active reflection window")


func _session() -> BattleSession:
	var session := BattleSession.new()
	sessions.append(session)
	var words: Array[VocabularyEntry] = [VocabularyEntry.new("abcdef", "测试")]
	session.start_baseline(&"frost", words)
	for index in session.enemies.size():
		var enemy := session.enemies[index]
		enemy.position = session.player_position + Vector2(180 + index * 150, 120) / BattleSession.ARENA_SIZE
		enemy.previous_position = enemy.position
		enemy.attack_clock = 100.0
	return session


func _check_world_clocks() -> void:
	var clock := _session()
	_check(clock.world_delta(0.25) == 0.25 and clock.world_time_scale == 1.0, "ordinary world time matches real time")
	clock.counter_slow_remaining = 0.52
	_check(is_equal_approx(clock.world_delta(0.06), 0.0036) and is_equal_approx(clock.world_delta(0.52), 0.2474), "counter retains its hold and smooth recovery integral")
	for sample: Vector3 in [Vector3(.52,.2,.4), Vector3(.45,.01,.2), Vector3(.12,.02,.1), Vector3(0,.03,.07), Vector3(.52,0,.52), Vector3(.03,.2,.4)]:
		clock.counter_slow_remaining = sample.x
		clock.precision_slow_remaining = sample.y
		var whole := clock.world_delta(sample.z)
		_check(clock.counter_slow_remaining == sample.x and clock.precision_slow_remaining == sample.y, "render conversion never consumes slow timers")
		var split := 0.0
		for index in 100:
			var real_step := sample.z / 100.0
			split += clock.world_delta(real_step)
			clock.counter_slow_remaining = maxf(0.0, clock.counter_slow_remaining - real_step)
			clock.precision_slow_remaining = maxf(0.0, clock.precision_slow_remaining - real_step)
		_check(absf(whole - split) < 0.00000001, "overlapping slow time integrates equally across 100 partitions: %s" % sample)
	clock.counter_slow_remaining = 0.52
	clock.precision_slow_remaining = 0.0
	clock.parry_cooldown = 0.5
	clock.hurt_window = 0.5
	clock.player_impulse = Vector2(100,0)
	var player_start := clock.player_position
	var enemy_age := clock.enemies[0].age
	var shot := _threat(clock, Vector2(-500,0), Vector2(100,0), "slow-clock")
	var shot_start := shot.position
	var hazard := BattleHazard.new()
	hazard.kind = &"blast"
	hazard.center = Vector2(.1,.1)
	hazard.source_id = clock.enemies[0].id
	hazard.warning_remaining = 1.0
	hazard.active_remaining = 1.0
	clock.hazards.append(hazard)
	var ultimate := BattleUltimate.new(&"spirit", Vector2(.1,.1))
	clock.ultimates.append(ultimate)
	clock.spirit_time = 10.0
	clock.step(0.05)
	print("World clock consumers: enemy=%s shot_life=%s warning=%s ultimate=%s spirit=%s shot_travel=%s player_travel=%s" % [clock.enemies[0].age-enemy_age,shot.life,hazard.warning_remaining,ultimate.age,clock.spirit_time,(shot.position-shot_start)*BattleSession.ARENA_SIZE,(clock.player_position-player_start)*BattleSession.ARENA_SIZE])
	_check(is_equal_approx(clock.elapsed, .05) and is_equal_approx(clock.world_time, .003) and is_equal_approx(clock.runtime.clock, .003), "committed world and runtime clocks share slow time while elapsed stays real")
	_check(is_equal_approx(clock.enemies[0].age - enemy_age, .003) and is_equal_approx(shot.life, 5.997) and is_equal_approx(hazard.warning_remaining, .997) and is_equal_approx(ultimate.age, .003), "enemies, hostile shots, warning areas and ultimate ages use one world step")
	_check(is_equal_approx(clock.spirit_time, 9.95), "paper input maintenance consumes active real seconds even during world slow time")
	# Normalized Vector2 positions use float32: allow less than 0.0001 design px.
	_check(((shot.position-shot_start)*BattleSession.ARENA_SIZE-Vector2(.3,0)).length() < .0001 and ((clock.player_position-player_start)*BattleSession.ARENA_SIZE-Vector2(.3,0)).length() < .0001, "projectile and ordinary player knockback travel at world speed")
	_check(is_equal_approx(clock.parry_cooldown,.45) and is_equal_approx(clock.hurt_window,.45), "input cooldown and protection windows retain real seconds")
	var orbit := clock._spirit_orbit(0,1)
	clock.elapsed += 10.0
	_check(clock._spirit_orbit(0,1) == orbit, "paper orbit phase never advances from elapsed real time")
	clock.world_time += 1.0
	_check(clock._spirit_orbit(0,1) != orbit, "paper orbit phase follows committed world time")
	clock.result = 1
	_check(clock.world_delta(.05) == 0.0 and clock.world_time_scale == 0.0, "completed battlefield freezes its presentation clock")
	print("World clock: overlap partition checks and shared consumers completed")


func _threat(session: BattleSession, offset: Vector2, velocity: Vector2, attack_id: String) -> BattleThreat:
	var threat := BattleThreat.new()
	threat.position = session.player_position + offset / BattleSession.ARENA_SIZE
	threat.previous_position = threat.position
	threat.velocity = velocity
	threat.source_id = session.enemies[0].id
	threat.attack_id = attack_id
	threat.damage_q = 10 * BattleSession.Q
	threat.radius = 6.0
	session.threats.append(threat)
	return threat


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
