extends SceneTree

var failures := 0
const Fixture = preload("res://tests/godot/combat_fixture.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(CombatGeometry.disc_in_sector(Vector2(115, 0), 21.0, Vector2.RIGHT, 106.0, 0.82), "melee includes the player body's intersection with the marked front arc")
	_check(not CombatGeometry.disc_in_sector(Vector2(-60, 0), 21.0, Vector2.RIGHT, 106.0, 0.82), "melee never hits behind its committed direction")
	_check(not CombatGeometry.disc_in_sector(Vector2(150, 0), 21.0, Vector2.RIGHT, 106.0, 0.82), "melee reach is bounded by the same sector used for its warning")
	_check(is_equal_approx(CombatGeometry.sweep_discs(Vector2.ZERO, Vector2(100, 0), Vector2(50, 0), Vector2(50, 0), 10), 0.4), "circle sweep reports first surface contact, not closest center")
	_check(is_equal_approx(CombatGeometry.sweep_discs(Vector2.ZERO, Vector2(100, 0), Vector2(50, -50), Vector2(50, 50), 10), (50.0 - 10.0 / sqrt(2.0)) / 100.0), "relative sweep catches a target crossing the flight between endpoints")
	_check(CombatGeometry.sweep_discs(Vector2.ZERO, Vector2(100, 0), Vector2(50, 20), Vector2(50, 20), 10) == INF, "a near miss does not become a hit")
	_check(CombatGeometry.sweep_discs(Vector2.ZERO, Vector2.ZERO, Vector2(5, 0), Vector2(5, 0), 10) == 0.0 and CombatGeometry.sweep_discs(Vector2.ZERO, Vector2.ZERO, Vector2(20, 0), Vector2(20, 0), 10) == INF, "stationary overlapping and separated sweeps are well defined")
	var ledger := SpellResourceLedger.new()
	var receipt := ManualInputReceipt.new()
	receipt.id = "physical-1"
	receipt.attempt_id = "attempt-1"
	receipt.position = 1
	_check(ledger.accept_manual(receipt) and not ledger.accept_manual(receipt), "physical receipt can be credited once")
	_check(ledger.claim_word("attempt-1", 2).is_empty(), "incomplete word cannot claim income")
	_check(int(ledger.claim_word("attempt-1", 1)["power_q"]) == SpellResourceLedger.Q, "completed word claims exact manual income")
	_check(ledger.claim_word("attempt-1", 1).is_empty(), "claimed attempt cannot spend twice")

	var words: Array[VocabularyEntry] = [VocabularyEntry.new("abc", "测试")]
	var sessions: Array[BattleSession] = []
	_check_cold_ranged_entry(words, sessions)
	var arrival := BattleSession.new()
	sessions.append(arrival)
	arrival.start_baseline(&"frost", words, "normal", "entry-lanes")
	_check(arrival.wave == 1 and arrival.arrival_direction in BattleEncounter.DIRECTIONS, "single room begins with a seeded eight-direction approach")
	for direction in BattleEncounter.DIRECTIONS:
		var points: Array[Vector2] = []
		for index in 3:
			var point := BattleEncounter.entry_position(direction, index, 3, BattleSession.ARENA_SIZE)
			points.append(point)
			_check(not BattleSession.in_combat(point, 32.0), "%s arrival starts in the cold periphery" % direction)
		for index in 2:
			_check(((points[index + 1] - points[index]) * BattleSession.ARENA_SIZE).length() > 68.0, "%s arrival lanes leave body clearance" % direction)
	_check(arrival.typing._targets.is_empty(), "cold arrivals have no target words")
	for frame in 180:
		arrival.step(1.0 / 60.0)
	var entered := false
	for enemy in arrival.enemies:
		entered = entered or BattleSession.in_combat(enemy.position, enemy.radius)
	_check(entered, "approaching enemies enter the clear battlefield")
	var geometry := BattleSession.new()
	sessions.append(geometry)
	geometry.start_baseline(&"flame", words)
	geometry.enemies[0].position = Vector2(1020, 540) / BattleSession.ARENA_SIZE
	geometry.enemies[0].radius = 5.0
	geometry.enemies[1].position = Vector2(1060, 540) / BattleSession.ARENA_SIZE
	geometry.enemies[1].radius = 60.0
	geometry.enemies[2].position = Vector2(1100, 800) / BattleSession.ARENA_SIZE
	for enemy in geometry.enemies:
		enemy.previous_position = enemy.position
	var paid := Fixture.effect(geometry, &"flame_splash", geometry.enemies[0].id, 4 * SpellResourceLedger.Q, 0, Vector2(800, 540) / BattleSession.ARENA_SIZE)
	var shot := BattleProjectile.new(paid)
	shot.homing = false
	shot.velocity = Vector2(1080, 0)
	geometry.projectiles.append(shot)
	geometry._advance_projectiles(0.3)
	_check(geometry.enemies[1].hp_q < geometry.enemies[1].max_hp_q and geometry.enemies[0].hp_q == geometry.enemies[0].max_hp_q, "blocking projectile chooses the earliest surface even when its center is farther away")
	_check(is_equal_approx(shot.position.x * BattleSession.ARENA_SIZE.x, 994.0) and shot.trail[-1] == shot.position, "spent projectile and retiring trail stop at actual contact")
	var fast_body := geometry.enemies[0]
	var heavy_body := geometry.enemies[1]
	fast_body.radius = 28.0
	heavy_body.radius = 32.0
	fast_body.mass = 1.0
	heavy_body.mass = 3.0
	fast_body.previous_position = Vector2(900, 540) / BattleSession.ARENA_SIZE
	fast_body.position = Vector2(1140, 540) / BattleSession.ARENA_SIZE
	heavy_body.previous_position = Vector2(1040, 540) / BattleSession.ARENA_SIZE
	heavy_body.position = heavy_body.previous_position
	fast_body.velocity = Vector2.ZERO
	heavy_body.velocity = Vector2.ZERO
	fast_body.impulse = Vector2(2400, 0)
	heavy_body.impulse = Vector2.ZERO
	geometry._resolve_bodies()
	_check(fast_body.position.x < heavy_body.position.x and ((heavy_body.position - fast_body.position) * BattleSession.ARENA_SIZE).length() >= 63.8, "fast pushed bodies cannot exchange sides through tunneling")
	_check(is_equal_approx(fast_body.impulse.x * fast_body.mass + heavy_body.impulse.x * heavy_body.mass, 2400.0), "contact impulse transfers momentum without creating it")
	fast_body.previous_position = Vector2(976.1, 540) / BattleSession.ARENA_SIZE
	fast_body.position = Vector2(1140, 540) / BattleSession.ARENA_SIZE
	heavy_body.previous_position = Vector2(1040, 540) / BattleSession.ARENA_SIZE
	heavy_body.position = heavy_body.previous_position
	geometry._resolve_bodies()
	_check(fast_body.position.x < heavy_body.position.x, "bodies already inside contact slop cannot tunnel on the next push")
	var renewal := BattleSession.new()
	sessions.append(renewal)
	renewal.start_baseline(&"frost", words)
	_place_enemies_in_combat(renewal)
	var renewal_target := renewal.enemies[0]
	renewal_target.position = Vector2(0.72, 0.5)
	renewal_target.hp_q = 100 * BattleSession.Q
	for letter in "abc":
		renewal.typing.feed(letter)
	renewal.step(1.0 / 60.0)
	_check(renewal_target.word_pending and not renewal.typing._targets.has(renewal_target.id), "completed word stays unavailable while its primary is in flight")
	Fixture.hit(renewal, renewal_target, 1, &"counter", renewal.player_position)
	_check(renewal_target.word_pending, "unrelated impact cannot release a paid primary's word")
	for frame in 45:
		renewal.step(1.0 / 60.0)
	_check(not renewal_target.word_pending and renewal.typing._targets.has(renewal_target.id), "primary contact releases a surviving target's next word")
	var cold := BattleSession.new()
	sessions.append(cold)
	cold.start_baseline(&"flame", words)
	var cold_target := cold.enemies[0]
	cold_target.position = Vector2(0.98, 0.5)
	var cold_hp := cold_target.hp_q
	Fixture.hit(cold, cold_target, 10 * BattleSession.Q, &"flame_burst", cold.player_position)
	cold.step(1.0 / 60.0)
	_check(cold_target.hp_q == cold_hp and not cold.typing._targets.has(cold_target.id) and not cold_target.aiming, "cold periphery cannot take damage, expose target words or initiate attacks")
	cold_target.position = Vector2(0.7, 0.5)
	cold.step(1.0 / 60.0)
	_check(cold.typing._targets.has(cold_target.id) and cold_target.word_age == 0.0, "entering the clear battlefield enables a fresh word fade-in")
	_check(BattleSession.in_combat(BattleSession.clamp_player(Vector2.ZERO), 32), "player dodge boundary keeps the body inside the clear battlefield")
	for selection_mode in ["click", "cycle", "type"]:
		var retained := BattleSession.new()
		sessions.append(retained)
		retained.start_baseline(&"flame", words)
		var target := retained.enemies[0]
		target.position = Vector2(0.7, 0.5)
		retained.step(1.0 / 60.0)
		if selection_mode == "click":
			retained.typing.select_target(target.id)
		elif selection_mode == "cycle":
			retained.typing.cycle_target()
		else:
			retained.typing.feed(target.word[0])
		target.position = Vector2(0.98, 0.5)
		retained.step(1.0 / 60.0)
		_check(target.combat_locked and retained.typing.target_id == target.id and retained.typing._targets.has(target.id), "%s lock survives knockback into the edge including zero-prefix selection" % selection_mode)
		retained.typing.cancel()
		var hp := target.hp_q
		Fixture.hit(retained, target, BattleSession.Q, &"flame_burst", retained.player_position)
		_check(target.hp_q == hp-BattleSession.Q and BattleSession.enemy_in_combat(target), "lock history keeps edge combat active after cancellation")
	for book in [&"frost", &"flame", &"storm", &"spirit"]:
		var session := BattleSession.new()
		sessions.append(session)
		session.start_baseline(book, words, "story")
		_place_enemies_in_combat(session)
		var hp_before := session.enemies[0].hp_q
		for letter in "abc":
			session.typing.feed(letter)
		session.step(1.0 / 60.0)
		_check(session.manual_characters == 3 and session.completed_words == 1 and session.resonance_q == 3 * SpellResourceLedger.Q, "%s pays one cast from three physical characters" % book)
		if book != &"storm":
			_check(not session.projectiles.is_empty() and session.enemies[0].hp_q == hp_before, "%s must travel before dealing damage" % book)
		for frame in 90:
			session.step(1.0 / 60.0)
		_check(session.enemies[0].hp_q < hp_before, "%s cast reaches target" % book)
		if book == &"spirit":
			_check(session.spirit_blade_count() > 0 or session.enemies[0].hp_q < hp_before - 4 * SpellResourceLedger.Q, "spirit blade draws from finite paid work")

	var line := BattleSession.new()
	sessions.append(line)
	line.start_baseline(&"frost", words)
	_place_enemies_in_combat(line)
	line.enemies[0].position = Vector2(0.65, 0.5)
	line.enemies[1].position = Vector2(0.78, 0.5)
	line.enemies[2].position = Vector2(0.65, 0.75)
	for enemy in line.enemies:
		enemy.attack_clock = 100.0
	for letter in "abc":
		line.typing.feed(letter)
	for frame in 90:
		line.step(1.0 / 60.0)
	_check(line.enemies[0].hp_q < line.enemies[0].max_hp_q and line.enemies[1].hp_q < line.enemies[1].max_hp_q and line.enemies[2].hp_q == line.enemies[2].max_hp_q, "frost pierces enemies on its flight path without hitting an unrelated off-axis target")

	var flame := BattleSession.new()
	sessions.append(flame)
	flame.start_baseline(&"flame", words)
	_place_enemies_in_combat(flame)
	flame.enemies[1].position = flame.enemies[0].position + Vector2(0.035, 0.01)
	flame.enemies[0].hp_q = SpellResourceLedger.Q
	var next_hp := flame.enemies[1].hp_q
	for letter in "abc":
		flame.typing.feed(letter)
	flame.step(0.02)
	for frame in 60:
		flame.step(1.0 / 60.0)
	_check(not flame.enemies[0].alive() and flame.enemies[1].hp_q < next_hp, "paid flame splash survives first target death")
	var echo := BattleSession.new()
	var spirit := BattleSession.new()
	sessions.append(spirit)
	spirit.start_baseline(&"spirit", words)
	_place_enemies_in_combat(spirit)
	spirit.completed_words = 2
	spirit.enemies[0].hp_q = SpellResourceLedger.Q
	var cross_hits: Array[Dictionary] = []
	spirit.event_committed.connect(func(event: Dictionary) -> void:
		if event.kind == &"impact" and event.source == &"spirit_cross":
			cross_hits.append(event)
	)
	for letter in "abc":
		spirit.typing.feed(letter)
	for frame in 90:
		spirit.step(1.0 / 60.0)
	_check(cross_hits.size() == 2 and spirit.manual_characters == 3 and spirit.resonance_q == 3 * SpellResourceLedger.Q, "third spirit cast owns two finite crossing strikes even after the first target dies, without new manual income")
	var flock := BattleSession.new()
	sessions.append(flock)
	flock.start_baseline(&"spirit", words)
	_place_enemies_in_combat(flock)
	for enemy in flock.enemies:
		enemy.hp_q = 1000 * BattleSession.Q
		enemy.max_hp_q = enemy.hp_q
		enemy.attack_clock = 100.0
		enemy.frozen_time = 100.0
	for count in 4:
		for letter in "abc":
			flock.typing.feed(letter)
		flock.step(1.0 / 60.0)
		_check(flock.spirit_blade_count() == mini(count + 1, 3), "each completed word summons one persistent spirit up to capacity")
	var first := flock.spirits[0]
	var phases: Array[StringName] = []
	for frame in 600:
		flock.step(1.0 / 60.0)
		if not phases.has(first.mode):
			phases.append(first.mode)
	_check(phases.has(&"dive") and phases.has(&"return") and phases.has(&"orbit"), "the same spirit dives, contacts and returns to its orbit")
	_check(flock.spirit_blade_count() == 3 and flock.spirit_work_q == 0, "spent attack funding leaves the summons visibly orbiting until silence timeout")
	var idle_hp := flock.enemies[0].hp_q + flock.enemies[1].hp_q + flock.enemies[2].hp_q
	for frame in 120:
		flock.step(1.0 / 60.0)
	_check(flock.enemies[0].hp_q + flock.enemies[1].hp_q + flock.enemies[2].hp_q == idle_hp, "unfunded orbiting summons cannot mint damage")
	var time_before := flock.spirit_time
	for letter in "abc":
		flock.typing.feed(letter)
	flock.step(1.0 / 60.0)
	var supplied := flock.spirit_work_q
	for summon in flock.spirits:
		supplied += summon.damage_q
	_check(flock.spirit_blade_count() == 3 and flock.spirit_time > time_before + 7.9 and supplied > 0 and flock.spirits.has(first), "casting at capacity supplies work and lifetime without replacing bodies")
	for frame in 1100:
		flock.step(1.0 / 60.0)
	_check(flock.spirit_blade_count() == 0 and flock.spirit_work_q == 0, "silent summons expire, including unused work")
	for letter in "abc":
		flock.typing.feed(letter)
	flock.step(1.0 / 60.0)
	_check(flock.spirit_blade_count() == 1 and flock.spirit_time > 7.9, "after silence the next word summons a fresh flock from one")
	sessions.append(echo)
	echo.start_baseline(&"frost", words)
	_place_enemies_in_combat(echo)
	echo.typing.feed("a")
	echo.step(0.02)
	Fixture.queued(echo, &"counter", echo.enemies[0].id, echo.enemies[0].hp_q, 0.0, Vector2(0.5, 0.82))
	echo.step(0.02)
	_check(not echo.enemies[0].alive() and echo.typing.target_id == echo.enemies[0].id and echo.typing.progress == 1, "partly typed word remains as an echo after target death")
	var redirected_hp := echo.enemies[1].hp_q + echo.enemies[2].hp_q
	echo.typing.feed("b")
	echo.typing.feed("c")
	for frame in 60:
		echo.step(1.0 / 60.0)
	_check(echo.completed_words == 1 and echo.enemies[1].hp_q + echo.enemies[2].hp_q < redirected_hp, "completed echo redirects paid spell to a living enemy")

	var defense := BattleSession.new()
	sessions.append(defense)
	defense.start_baseline(&"frost", words)
	_place_enemies_in_combat(defense)
	for enemy in defense.enemies:
		enemy.attack_clock = 100.0
	defense.enemies[0].attack_clock = 0.0
	defense.enemies[0].hp_q = 100 * SpellResourceLedger.Q
	defense.enemies[0].max_hp_q = defense.enemies[0].hp_q
	defense.enemies[0].position = defense.player_position + Vector2(80.0, 0) / BattleSession.ARENA_SIZE
	defense.enemies[1].position = defense.player_position + Vector2(0.07, 0.05)
	var nearby_before := defense.enemies[1].position
	defense.step(0.01)
	_check(defense.enemies[0].aiming and defense.player_hp_q == defense.player_max_hp_q, "entering melee range starts a committed warning without contact damage")
	defense.step(0.62)
	_check(defense.player_hp_q == defense.player_max_hp_q, "melee warning remains harmless until the strike")
	defense.queue_action(&"parry")
	defense.step(0.11)
	_check(defense.player_hp_q == defense.player_max_hp_q and defense.enemies[0].hp_q == 99 * SpellResourceLedger.Q and defense.enemies[0].impulse.length() > 2000.0, "unfunded melee parry gives bounded base damage while preserving protection and strong physical push")
	_check((defense.enemies[1].position - nearby_before).dot(nearby_before - defense.player_position) > 0.0 and defense.enemies[1].hp_q == defense.enemies[1].max_hp_q, "successful parry pushes nearby enemies without minting collateral damage")
	var passing := BattleThreat.new()
	passing.position = Vector2(0.9, 0.9)
	passing.velocity = Vector2(120, 0)
	passing.damage_q = SpellResourceLedger.Q
	defense.threats.append(passing)
	var threat_start := passing.position
	defense.enemies[0].attack_clock = 0.1
	defense.enemies[0].aiming = true
	defense.enemies[0].aimed_position = defense.player_position
	defense.queue_action(&"dodge_left")
	defense.step(0.1)
	_check(defense.player_position.x < 0.4 and defense.player_hp_q == defense.player_max_hp_q and defense.dodge_window > 0.8, "directional dodge travels out of the attack and retains one second of invulnerability")
	_check(is_equal_approx(defense.parry_cooldown, 0.49) and ((passing.position - threat_start) * BattleSession.ARENA_SIZE).length() < 2.0, "counter recovery slows the world while input and defense cooldown retain real time")

	var ranged := BattleSession.new()
	sessions.append(ranged)
	ranged.start_baseline(&"frost", words)
	_place_enemies_in_combat(ranged)
	for enemy in ranged.enemies:
		enemy.attack_clock = 100.0
	ranged.enemies[1].position = Vector2(0.62, 0.5)
	ranged.enemies[1].aimed_position = ranged.player_position
	ranged.enemies[1].aiming = true
	ranged.enemies[1].attack_clock = 0.01
	ranged.step(0.02)
	_check(ranged.threats.size() == 3 and ranged.player_hp_q == ranged.player_max_hp_q, "ranged warning releases a visible fan without applying remote damage")
	for frame in 45:
		ranged.step(1.0 / 60.0)
	_check(ranged.player_hp_q < ranged.player_max_hp_q, "enemy projectile damages only when its flight reaches the player")

	var reflected := BattleSession.new()
	sessions.append(reflected)
	reflected.start_baseline(&"flame", words)
	_place_enemies_in_combat(reflected)
	for enemy in reflected.enemies:
		enemy.attack_clock = 100.0
	reflected.enemies[1].position = Vector2(0.72, 0.5)
	reflected.enemies[1].hp_q = 100 * SpellResourceLedger.Q
	var incoming := BattleThreat.new()
	incoming.source_id = reflected.enemies[1].id
	incoming.attack_id = "fixture-reflected-attack"
	incoming.position = reflected.player_position + Vector2(0.03, 0)
	incoming.velocity = Vector2(-380, 0)
	incoming.damage_q = 10 * SpellResourceLedger.Q
	reflected.threats.append(incoming)
	reflected.dodge_window = 0.7
	reflected.queue_action(&"parry")
	reflected.step(1.0 / 60.0)
	_check(incoming.reflected and incoming.velocity.x > 0 and reflected.enemies[1].hp_q == 100 * SpellResourceLedger.Q, "parry reverses the actual projectile without remote damage, including post-dodge invulnerability")
	for frame in 90:
		reflected.step(1.0 / 60.0)
	_check(reflected.enemies[1].hp_q == 99 * SpellResourceLedger.Q and reflected.player_hp_q == reflected.player_max_hp_q, "unfunded reflection spends only the bounded base response at actual enemy contact")

	var crowd := BattleSession.new()
	sessions.append(crowd)
	crowd.start_baseline(&"frost", words)
	_place_enemies_in_combat(crowd)
	for enemy in crowd.enemies:
		enemy.position = Vector2(0.7, 0.5)
		enemy.attack_clock = 100.0
	for frame in 6:
		crowd.step(1.0 / 60.0)
	_check(((crowd.enemies[0].position - crowd.enemies[1].position) * BattleSession.ARENA_SIZE).length() >= 45.0, "coincident enemy bodies separate instead of overlapping")
	for index in 3:
		crowd.enemies[index].position = Vector2(0.60 + index * 0.12, 0.5)
		crowd.enemies[index].velocity = Vector2.ZERO
		crowd.enemies[index].frozen_time = 2.0
	var rear_hp := crowd.enemies[2].hp_q
	var spear := Fixture.queued(crowd, &"frost_spear", crowd.enemies[2].id, 4 * SpellResourceLedger.Q, 0, crowd.player_position)
	spear.applications = 3
	spear.primary_share_q = 2 * SpellResourceLedger.Q
	for frame in 60:
		crowd.step(1.0 / 60.0)
	_check(crowd.enemies[2].hp_q == rear_hp - 2 * SpellResourceLedger.Q, "ice reserves the main half while foreground pierces share the other half")

	var ultimate := BattleSession.new()
	sessions.append(ultimate)
	ultimate.start_baseline(&"storm", words)
	_place_enemies_in_combat(ultimate)
	for enemy in ultimate.enemies:
		enemy.hp_q = 1000 * BattleSession.Q
		enemy.attack_clock = 100.0
	ultimate.resonance_q = BattleSession.ULTIMATE_COST_Q
	ultimate.queue_action(&"ultimate")
	ultimate.step(0.02)
	_check(ultimate.resonance_q == 0 and ultimate.ultimates.size() == 1 and ultimate.ultimate_time > 5.9, "storm spends once and owns a six-second paid timeline")
	ultimate.effects.clear()
	ultimate.typing.select_target(ultimate.enemies[0].id)
	for letter in ultimate.typing.word:
		ultimate.typing.feed(letter)
	ultimate.step(0.02)
	_check(ultimate.effects.any(func(effect: BattleEffect) -> bool: return effect.kind == &"storm_ultimate") and ultimate.manual_characters == 3 and ultimate.resonance_q == 0, "storm aftercast adds a finite strike while active without recharging resonance or forging input")
	for book: StringName in [&"frost", &"flame", &"spirit"]:
		var field := BattleSession.new()
		sessions.append(field)
		field.start_baseline(book, words)
		_place_enemies_in_combat(field)
		for enemy in field.enemies:
			enemy.hp_q = 1000 * BattleSession.Q
			enemy.attack_clock = 100.0
		field.resonance_q = BattleSession.ULTIMATE_COST_Q
		field.typing.select_target(field.enemies[0].id)
		field.queue_action(&"ultimate")
		field.step(0.02)
		var timeline := field.ultimates[0]
		_check(field.resonance_q == 0 and field.manual_characters == 0 and field.hurt_window > 0.0, "%s has paid startup protection without manual income" % book)
		if book == &"flame":
			_check(field.enemies[0].hp_q < 1000 * BattleSession.Q and field.enemies[2].hp_q == 1000 * BattleSession.Q, "flame startup allocates its paid budget inside the target-centered radius")
		if book == &"spirit":
			_check(field.spirits.size() == BattleSession.SPIRIT_CAPACITY and field.spirit_work_q > 0, "spirit fills the summon capacity with finite work")
		for tick in 240:
			field._advance_ultimates(0.025)
		if book in [&"frost", &"flame"]:
			var pulses := field.effects.filter(func(effect: BattleEffect) -> bool: return effect.kind == (&"frost_ultimate" if book == &"frost" else &"flame_meteor"))
			_check(pulses.size() == (16 if book == &"frost" else 7) and timeline.pulses_left == 0 and field.ultimates.is_empty(), "%s timeline emits only its finite pulses and expires" % book)
		field.queue_action(&"abandon")
		field.step(0.02)
		_check(field.ultimates.is_empty() and field.ultimate_time == 0.0 and field.abandoned_run, "%s abandonment clears all active ultimate state" % book)
	var cold_ultimate := BattleSession.new()
	sessions.append(cold_ultimate)
	cold_ultimate.start_baseline(&"frost", words)
	cold_ultimate.resonance_q = BattleSession.ULTIMATE_COST_Q
	cold_ultimate.queue_action(&"ultimate")
	cold_ultimate.step(0.01)
	_check(cold_ultimate.resonance_q == BattleSession.ULTIMATE_COST_Q and cold_ultimate.ultimates.is_empty(), "cold-zone entry alone cannot consume an ultimate or select an invalid center")
	var victory := BattleSession.new()
	sessions.append(victory)
	victory.encounter = BattleEncounter.new()
	victory.encounter.wave_count = 1
	victory.start_baseline(&"storm", words)
	_place_enemies_in_combat(victory)
	for enemy in victory.enemies:
		enemy.hp_q = 2 * SpellResourceLedger.Q
		enemy.attack_clock = 100.0
	for letter in "abc":
		victory.typing.feed(letter)
	for frame in 120:
		victory.step(1.0 / 60.0)
	_check(victory.result == 1 and victory.completed_words == 1, "all enemies die and paid chains finish before room victory")
	var defeat := BattleSession.new()
	sessions.append(defeat)
	defeat.start_baseline(&"frost", words)
	_place_enemies_in_combat(defeat)
	defeat.player_hp_q = SpellResourceLedger.Q
	for enemy in defeat.enemies:
		enemy.attack_clock = 100.0
	defeat.enemies[0].attack_clock = 0.02
	defeat.enemies[0].aiming = true
	defeat.enemies[0].position = defeat.player_position + Vector2(80.0, 0) / BattleSession.ARENA_SIZE
	defeat.enemies[0].aimed_position = defeat.player_position
	defeat.enemies[0].melee_origin = defeat.enemies[0].position
	defeat.enemies[0].melee_direction = Vector2.LEFT
	defeat.step(0.03)
	_check(defeat.result == -1 and defeat.player_hp_q == 0, "lethal enemy attack produces defeat")
	for session in sessions:
		session.free()

	call_deferred("_finish")


func _finish() -> void:
	print("Battle session tests: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("Battle session: " + label)


func _place_enemies_in_combat(session: BattleSession) -> void:
	# Focus existing spell/defense tests on their mechanic after the entry phase.
	var positions := [Vector2(0.69, 0.32), Vector2(0.78, 0.53), Vector2(0.65, 0.72)]
	for index in session.enemies.size():
		var enemy := session.enemies[index]
		enemy.position = positions[index]
		enemy.previous_position = enemy.position
		session.typing.upsert_target(enemy.id, enemy.word)


func _check_cold_ranged_entry(words: Array[VocabularyEntry], sessions: Array[BattleSession]) -> void:
	for kind: StringName in [&"quill", &"guard"]:
		var session := BattleSession.new()
		sessions.append(session)
		session.start_baseline(&"storm", words, "normal", "cold-ranged-entry")
		session.player_position = BattleSession.clamp_player(Vector2(0.5, 1.0))
		var target := session.enemies[1 if kind == &"quill" else 2]
		_check(target.kind == kind, "cold-entry fixture uses the normal %s enemy" % kind)
		for enemy in session.enemies:
			enemy.attack_clock = 100.0
			if enemy != target:
				enemy.position = Vector2(0.03, 0.3 + 0.2 * session.enemies.find(enemy))
				enemy.previous_position = enemy.position
				enemy.frozen_time = 100.0
		target.position = Vector2(session.player_position.x + 300.0 / BattleSession.ARENA_SIZE.x, 1.0 - (BattleSession.EDGE_WIDTH + target.radius - 12.0) / BattleSession.ARENA_SIZE.y)
		target.previous_position = target.position
		var distance := ((target.position - session.player_position) * BattleSession.ARENA_SIZE).length()
		_check(not target.combat_locked and not BattleSession.in_combat(target.position, target.radius) and distance > 265.0 and distance < 385.0, "%s starts unselected in the cold zone despite already being inside its ranged distance band" % kind)
		var appeared := false
		var disappeared := false
		for frame in 1800:
			session.step(1.0 / 60.0)
			var available := session.typing._targets.has(target.id)
			if appeared and not available: disappeared = true
			appeared = appeared or available
		_check(appeared and not disappeared and session.typing._targets.has(target.id), "%s enters and keeps its word available without repeatedly crossing the cold-zone threshold" % kind)
		_check(not target.combat_locked and session.typing.target_id == &"", "%s entry itself does not forge a player target lock" % kind)
		session.typing.feed(target.word[0])
		target.impulse = Vector2(0.0, 12000.0)
		session.step(0.05)
		_check(target.combat_locked and not BattleSession.in_combat(target.position, target.radius) and BattleSession.enemy_in_combat(target) and session.typing._targets.has(target.id) and session.typing.progress == 1, "%s first-character lock retains its word and combat eligibility after an outward physical push" % kind)
		session.typing.cancel()
		var hp_before := target.hp_q
		Fixture.hit(session, target, BattleSession.Q, &"counter", session.player_position)
		_check(target.hp_q < hp_before and BattleSession.enemy_in_combat(target), "%s remains damageable at the edge after its locked input is cancelled" % kind)
