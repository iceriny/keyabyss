extends SceneTree
## Rule regressions plus an opt-in real-renderer/input presentation pass.

const EVIDENCE := "res://.temp/enemy-expansion"
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if "--actors" in OS.get_cmdline_user_args():
		await _actor_window()
		quit(1 if failures else 0)
		return
	if "--feedback-fixes" in OS.get_cmdline_user_args():
		await _feedback_window()
		print("Enemy feedback: %s failure(s)" % failures)
		quit(1 if failures else 0)
		return
	if "--gravity" in OS.get_cmdline_user_args():
		_check_gravity_source()
		print("Enemy gravity: %s failure(s)" % failures)
		quit(1 if failures else 0)
		return
	if "--window" in OS.get_cmdline_user_args():
		await _window()
	else:
		_check_gravity_source()
		_check_precision()
		_check_refrain()
		_check_ward()
		_check_encounters()
	print("Enemy expansion: %s failure(s)" % failures)
	quit(1 if failures else 0)


func _words() -> Array[VocabularyEntry]:
	var words: Array[VocabularyEntry] = []
	for word: String in ["archive", "bloom", "crystal", "dream", "ember", "frost", "garden", "hollow", "ink", "jade", "leaf", "mist", "night", "ocean", "paper", "quill", "root", "spell", "thorn", "veil", "wind"]:
		words.append(VocabularyEntry.new(word, "试炼"))
	return words


func _session(kind: String, book: StringName = &"storm") -> BattleSession:
	var battle := BattleSession.new()
	battle.encounter = BattleEncounter.new()
	battle.encounter.enemies = [load("res://game/content/enemies/%s.tres" % kind)]
	battle.start_baseline(book, _words(), "normal", "enemy-expansion", false)
	battle._room_quota = 0
	_place(battle.enemies[0], Vector2(0.7, 0.5))
	battle._advance_enemies(0.0)
	return battle


func _place(enemy: BattleEnemy, at: Vector2) -> void:
	enemy.position = at
	enemy.previous_position = at
	enemy.velocity = Vector2.ZERO
	enemy.impulse = Vector2.ZERO
	enemy.combat_locked = true


func _check_gravity_source() -> void:
	var battle := _session("vortex")
	var source := battle.enemies[0]
	source.attack_clock = 100.0
	var shots: Array[BattleThreat] = []
	for index in 3:
		battle._emit_enemy_threat(source, 0.0, index, 130.0, 6.75)
		var shot := battle.threats[-1]
		shot.position = source.position + Vector2(100, 0) / BattleSession.ARENA_SIZE
		shots.append(shot)
	shots[1].reflected = true
	shots[2].source_id = &"another_enemy"
	var projectile := BattleProjectile.new(BattleEffect.new())
	projectile.position = shots[0].position
	battle.projectiles.append(projectile)
	battle._advance_enemies(0.1)
	_check(shots[0].velocity == Vector2(130, 0), "enemy aura does not bend its own outgoing projectile")
	_check(shots[1].velocity.x < 130 and shots[2].velocity.x < 130, "reflected and other-source shots retain gravity response")
	_check(projectile.attraction_impulse.x < 0, "enemy aura still attracts player projectiles")
	battle.runtime.pull_environment(source.position, source.aura_radius, 10.0, false)
	_check(shots[0].velocity.x < 130, "player gravity still attracts the enemy's outgoing projectile")
	shots[0].velocity = Vector2(130, 0)
	var reflected_velocity := shots[1].velocity
	battle.commit_damage(source, 9999 * battle.Q, 9999 * battle.Q, &"test", battle.player_position)
	_check(shots[0].velocity == Vector2(130, 0) and shots[1].velocity != reflected_velocity, "death pull preserves the same source and reflection distinction")
	battle.free()
	# Follow the real emitted ring through repeated aura and curved-flight steps.
	battle = _session("vortex")
	source = battle.enemies[0]
	source.attack_clock = 100.0
	source.aimed_position = battle.player_position
	battle._resolve_attack(source)
	var ring: Array[BattleThreat] = battle.threats.duplicate()
	for tick in 240:
		battle._advance_enemies(1.0 / 60.0)
		battle._advance_threats(1.0 / 60.0)
	for shot in ring:
		_check(((shot.position - source.position) * BattleSession.ARENA_SIZE).length() > source.aura_radius, "emitted ring exits its source's gravity radius")
	battle.free()


func _check_precision() -> void:
	var battle := _session("pin_archer")
	var enemy := battle.enemies[0]
	enemy.attack_clock = 0.1
	battle._advance_enemies(0.01)
	_check(enemy.aiming and is_equal_approx(enemy.attack_clock, 1.2), "a late initial clock still grants a full sniper warning")
	var locked := enemy.aimed_position
	battle.player_position += Vector2(0, 240) / BattleSession.ARENA_SIZE
	battle._advance_enemies(1.21)
	_check(battle.threats.size() == 1 and enemy.aimed_position == locked, "sniper fires exactly once at the committed position")
	var shot := battle.threats[0]
	_check(shot.velocity.normalized().is_equal_approx(((locked - enemy.position) * BattleSession.ARENA_SIZE).normalized()), "sniper does not retarget after a dodge")
	_check((((locked - shot.position) * BattleSession.ARENA_SIZE).length() - 28.0) / shot.velocity.length() >= 0.649, "projectile retains at least 0.65 seconds to the marked contact")
	battle.player_position = locked
	shot.position = locked + Vector2(35, 0) / BattleSession.ARENA_SIZE
	shot.previous_position = shot.position
	battle._commit_action(&"parry")
	battle._advance_threats(0.01)
	_check(shot.reflected and battle.player_hp_q == battle.player_max_hp_q, "new needle uses the actual perfect parry collision path")
	battle.free()
	# Without a reaction the same emitted projectile really damages the player.
	battle = _session("pin_archer")
	enemy = battle.enemies[0]
	enemy.aimed_position = battle.player_position
	battle._resolve_attack(enemy)
	var health := battle.player_hp_q
	for tick in 120: battle._advance_threats(1.0 / 60.0)
	_check(battle.player_hp_q == health - enemy.attack_damage_q, "needle damage is committed once at its real contact")
	battle.free()


func _check_refrain() -> void:
	for cancellation: String in ["none", "interrupt", "displace", "death"]:
		var battle := _session("refrain")
		var enemy := battle.enemies[0]
		enemy.aimed_position = battle.player_position
		enemy.velocity = Vector2(20, 10)
		battle._resolve_attack(enemy)
		var origin := enemy.position
		battle._advance_enemy_motion(0.1)
		_check(enemy.position == origin, "refrain holds its firing station between beats")
		var first_direction := battle.threats[0].velocity.normalized()
		_check(battle.threats.size() == 2 and enemy.followup_time > 0.0, "refrain starts with exactly two projectiles and a pending beat")
		battle.player_position += Vector2(0, 240) / BattleSession.ARENA_SIZE
		battle.previous_player_position = battle.player_position
		enemy.frozen_time = 1.0
		var before := enemy.followup_time
		battle._advance_enemies(0.5)
		battle._advance_threats(0.1)
		_check(enemy.followup_time == before and battle.threats[0].position != enemy.position, "freeze pauses only the unfired beat, leaving emitted projectiles live")
		enemy.frozen_time = 0.0
		match cancellation:
			"interrupt": battle._interrupt_enemy(enemy)
			"displace": enemy.position += Vector2(30, 0) / BattleSession.ARENA_SIZE
			"death": battle.commit_damage(enemy, 999 * battle.Q, 999 * battle.Q, &"test", battle.player_position)
		battle._advance_enemies(0.76)
		_check(battle.threats.size() == (4 if cancellation == "none" else 2), "pending beat has correct %s semantics" % cancellation)
		if cancellation == "none":
			_check(battle.threats[2].velocity.normalized().is_equal_approx(first_direction), "second beat retains the first aim after player relocation")
			var ids: Dictionary[String, bool] = {}
			for shot in battle.threats: ids[shot.attack_id] = true
			_check(ids.size() == 4, "each projectile has an independent settlement identity")
			for tick in 180: battle._advance_threats(1.0 / 60.0)
			_check(battle.player_hp_q == battle.player_max_hp_q, "one perpendicular 240px relocation clears the whole two-beat group")
		battle.free()


func _check_ward() -> void:
	var battle := _session("folio_warden")
	var source := battle.enemies[0]
	var ally := battle._spawn_enemy(load("res://game/content/enemies/quill.tres"), Vector2(0.65, 0.5))
	_place(ally, Vector2(0.65, 0.5))
	ally.attack_clock = 100.0
	for forbidden: String in ["folio_warden", "tower", "ink_colossus"]:
		var entity := battle._spawn_enemy(load("res://game/content/enemies/%s.tres" % forbidden), source.position)
		_place(entity, source.position)
	source.attack_clock = 0.0
	battle._advance_ward(source, 0.0)
	_check(battle.ward_target(source) == ally and not battle.is_warded(source), "ward chooses a normal ally over closer self, warden, tower or Boss")
	for direct in [true, false]:
		var health := ally.hp_q
		battle.commit_damage(ally, 4 * battle.Q, 4 * battle.Q, &"flame_burn", battle.player_position, false, Vector2.INF, direct)
		_check(health - ally.hp_q == 3 * battle.Q, "direct and ongoing damage share 25 percent ward mitigation")
	var second := battle.enemies[2]
	second.attack_clock = 0.0
	battle._advance_ward(second, 0.0)
	_check(battle.ward_target(second) == null, "a second warden cannot stack on the same ally")
	for cause: String in ["range", "freeze", "stagger", "target_death", "source_death", "expire"]:
		source.hp_q = source.max_hp_q
		ally.hp_q = ally.max_hp_q
		_place(ally, Vector2(0.65, 0.5))
		source.frozen_time = 0.0
		source.stagger_time = 0.0
		source.attack_clock = 0.0
		battle._advance_ward(source, 0.0)
		match cause:
			"range": ally.position = Vector2(0.2, 0.5)
			"freeze": source.frozen_time = 1.0
			"stagger": source.stagger_time = 1.0
			"target_death": battle.commit_damage(ally, 9999 * battle.Q, 9999 * battle.Q, &"test", source.position)
			"source_death": battle.commit_damage(source, 9999 * battle.Q, 9999 * battle.Q, &"test", ally.position)
			"expire": battle._advance_ward(source, 2.5)
		_check(not battle.is_warded(ally), "ward is invalid immediately on %s" % cause)
		battle._advance_ward(source, 0.0)
		_check(source.ward_remaining == 0.0 and source.ward_target_id == &"", "broken ward releases its relationship on %s" % cause)
		if cause == "expire":
			battle._advance_ward(source, 1.99)
			_check(not battle.is_warded(ally), "natural expiry retains at least a two-second recovery")
	battle.free()


func _check_encounters() -> void:
	var itinerary: RunItinerary = load("res://game/content/s2_itinerary.tres")
	var kinds: Dictionary[StringName, bool] = {&"tower": true}
	for encounter in itinerary.encounters:
		for definition in encounter.enemies: kinds[definition.kind] = true
		if encounter.reinforcement != null: kinds[encounter.reinforcement.kind] = true
	_check(kinds.size() == 23 and kinds.has(&"pin-archer") and kinds.has(&"refrain") and kinds.has(&"folio-warden"), "formal resources reference twenty ordinary kinds and three Bosses")
	for mode: String in ["story", "normal", "hard", "nightmare", "apocalypse"]:
		for room: String in ["lost_library_2", "echo_gallery_1", "echo_gallery_2", "final_court_2"]:
			var battle := BattleSession.new()
			battle.encounter = load("res://game/content/encounters/%s.tres" % room)
			battle.start_baseline(&"storm", _words(), mode, "enemy-expansion-" + mode, false)
			for tick in 30:
				battle._spawn_clock = 0.0
				battle._advance_encounter(0.0)
			for index in battle.encounter.opening_enemies.size():
				_check(battle.enemies[index].kind == battle.encounter.opening_enemies[index].kind, "%s/%s guarantees the authored first arrivals within its quota" % [mode, room])
			if not battle.encounter.opening_enemies.is_empty():
				var opening_count := battle.encounter.opening_enemies.size()
				battle._advance_encounter(30.0)
				_check(battle.enemies.size() == opening_count, "cold opening arrivals do not consume their observation time")
				for index in opening_count: _place(battle.enemies[index], Vector2(0.68 + index * 0.07, 0.5))
				battle._advance_encounter(2.9)
				_check(battle.enemies.size() == opening_count, "authored opening has a three-second clear introduction")
				battle._advance_encounter(0.11)
				_check(battle.enemies.size() > opening_count, "normal finite replenishment resumes after the opening")
				for tick in 30:
					battle._spawn_clock = 0.0
					battle._advance_encounter(0.0)
			var roles: Dictionary[StringName, int] = {}
			for enemy in battle.enemies:
				var role := battle._enemy_definitions[enemy.id].encounter_role
				roles[role] = roles.get(role, 0) + 1
			for role: StringName in battle.encounter.role_limits:
				_check(roles.get(role, 0) <= battle.encounter.role_limits[role], "%s/%s counts cold arrivals toward the %s cap" % [mode, room, role])
			_check(battle.enemies.size() == battle._spawned, "authored arrivals are part of the original finite spawn quota")
			battle.free()


func _actor_window() -> void:
	assert(DisplayServer.get_name() != "headless")
	root.size = Vector2i(1920, 1080)
	var directory := EVIDENCE.path_join("actors-%s" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var groups := [
		["nib", "quill", "guard", "wisp", "ram", "leech", "split"],
		["binder", "brood", "mirror", "mortar", "priest", "reaper", "scribe"],
		["sentinel", "tower", "vortex", "ink_colossus", "echo_archivist", "final_editor"],
	]
	for group_index in groups.size():
		var kinds: Array = groups[group_index]
		var battle := _session(kinds[0])
		for index in kinds.size():
			var enemy := battle.enemies[0] if index == 0 else battle._spawn_enemy(load("res://game/content/enemies/%s.tres" % kinds[index]), Vector2.ZERO)
			_place(enemy, Vector2(0.2 + (index % 3) * 0.28, 0.28 + floori(index / 3.0) * 0.23))
			enemy.attack_clock = 100.0
		battle.player_position = Vector2(0.48, 0.84)
		battle.previous_player_position = battle.player_position
		battle._advance_enemies(0.0)
		var settings := AppSettings.new(directory.path_join("settings.cfg"))
		settings.sound = false
		var book: BookPresentation = ArchiveHome.BOOKS[0]
		var page := BattlePage.create(battle, settings, book)
		page.theme = ArchiveTheme.create(book.color)
		root.add_child(page)
		battle.set_physics_process(false)
		await _advance(0.2)
		await _capture(directory, "group-%s" % group_index)
		if "--actor-states" in OS.get_cmdline_user_args():
			page.visuals.quality = 0
			page.visuals.reduced_motion = true
			await _advance(0.1)
			await _capture(directory, "group-%s-low" % group_index)
			for index in battle.enemies.size():
				var enemy := battle.enemies[index]
				if index % 3 == 0: enemy.frozen_time = 2.0
				elif index % 3 == 1: enemy.burn_time = 2.0
				else: enemy.hit_flash = 0.06
			await _advance(0.25)
			await _capture(directory, "group-%s-states" % group_index)
		page.queue_free()
		await process_frame
	print("Actor evidence: ", ProjectSettings.globalize_path(directory))


func _feedback_window() -> void:
	assert(DisplayServer.get_name() != "headless")
	root.size = Vector2i(1920, 1080)
	var directory := EVIDENCE.path_join("feedback-%s" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var battle := _session("pin_archer")
	var sniper := battle.enemies[0]
	var settings := AppSettings.new(directory.path_join("settings.cfg"))
	settings.sound = false
	var book: BookPresentation = ArchiveHome.BOOKS[0]
	var page := BattlePage.create(battle, settings, book)
	page.theme = ArchiveTheme.create(book.color)
	root.add_child(page)
	battle.set_physics_process(false)
	await _advance(0.1)
	var actor: BattleActorVisual = page.visuals._actors[sniper.id]
	sniper.last_seen_position = battle.player_position
	sniper.aimed_position = battle.player_position
	for reduced in [false, true]:
		actor.sync_enemy(sniper, sniper.position * BattleSession.ARENA_SIZE, 0.0, 1.0, reduced, 2)
		var moving_heading := actor.body.rotation
		sniper.aiming = true
		actor.sync_enemy(sniper, sniper.position * BattleSession.ARENA_SIZE, 0.0, 1.0 / 60.0, reduced, 2)
		_check(is_equal_approx(moving_heading, actor.body.rotation), "entering aim preserves the moving sniper's facing")
		sniper.aiming = false
		sniper.last_seen_position = sniper.position + Vector2.UP * 0.2
		actor.sync_enemy(sniper, sniper.position * BattleSession.ARENA_SIZE, 0.0, 1.0 / 60.0, reduced, 2)
		_check(absf(angle_difference(moving_heading, actor.body.rotation)) <= TAU * 1.5 / 60.0 + 0.001, "ending aim turns continuously even with reduced motion")
		sniper.frozen_time = 1.0
		var frozen_heading := actor.body.rotation
		actor.sync_enemy(sniper, sniper.position * BattleSession.ARENA_SIZE, 0.0, 0.2, reduced, 2)
		_check(actor.body.rotation == frozen_heading, "frozen sniper holds its facing")
		sniper.frozen_time = 0.0
		sniper.last_seen_position = battle.player_position
	var kinds: Array[String] = ["pin_archer", "quill", "refrain", "wisp", "binder", "vortex", "mirror", "ink_colossus", "brood"]
	var expected: Array[StringName] = [&"needle", &"quill", &"refrain", &"wisp", &"rune", &"vortex", &"shard", &"", &""]
	var representatives: Array[BattleThreat] = []
	for index in kinds.size():
		var enemy := sniper if index == 0 else battle._spawn_enemy(load("res://game/content/enemies/%s.tres" % kinds[index]), Vector2.ZERO)
		_place(enemy, Vector2(0.2 + (index % 3) * 0.27, 0.28 + floori(index / 3.0) * 0.23))
		enemy.attack_clock = 100.0
		enemy.aimed_position = enemy.position + Vector2.RIGHT * 0.2
		enemy.last_seen_position = enemy.aimed_position
		var before := battle.threats.size()
		if index in [0, 2]: battle._resolve_attack(enemy)
		else: battle._emit_pattern(enemy, &"single")
		var shot := battle.threats[before]
		_check(shot.visual_style == expected[index], "emitted projectile retains its source-specific visual identity")
		if kinds[index] == "ink_colossus":
			shot.heavy = true
			shot.radius = 10.5
		shot.position = enemy.position + Vector2(90, 0) / BattleSession.ARENA_SIZE
		shot.previous_position = shot.position
		shot.velocity = Vector2.RIGHT * 140.0
		shot.trail = PackedVector2Array([shot.position - Vector2(50, 0) / BattleSession.ARENA_SIZE, shot.position])
		representatives.append(shot)
		enemy.followup_time = 0.0
	battle.threats.assign(representatives)
	battle.player_position = Vector2(0.1, 0.85)
	battle.previous_player_position = battle.player_position
	battle._advance_enemies(0.0)
	battle.state_changed.emit()
	await _advance(0.15)
	await _capture(directory, "projectiles-high")
	if "--trail-glow" in OS.get_cmdline_user_args():
		await _check_trail_glow(battle, page, directory)
	page.visuals.reduced_motion = true
	page.visuals.quality = 0
	page.warnings.quality = 0
	page.warnings.reduced_motion = true
	page.stage.set_quality(0)
	page.visuals.fluid.set_options(0, true)
	await _advance(0.15)
	await _capture(directory, "projectiles-low-reduced")
	for shot in battle.threats: shot.reflected = true
	await _advance(0.15)
	await _capture(directory, "projectiles-reflected")
	if "--trail-glow" in OS.get_cmdline_user_args():
		page.visuals.set_options(2, false)
		page.warnings.quality = 2
		page.warnings.reduced_motion = false
		page.stage.set_quality(2)
		page.visuals.fluid.set_options(2, false)
		await _advance(0.15)
		await _capture(directory, "projectiles-reflected-hdr")
		battle.threats.clear()
		await _advance(0.1)
		await process_frame
		_check(page.visuals.fluid._motion.keys().all(func(id: StringName) -> bool: return not str(id).begins_with("threat_")), "removed threats release fluid motion and native light inputs")
		_check(page.visuals.threat_glow.ribbons.mesh == null, "removed threats release their emissive ribbon geometry")
		await _capture(directory, "projectiles-cleared")
	page.queue_free()
	await process_frame
	print("Enemy feedback evidence: ", ProjectSettings.globalize_path(directory))


func _check_trail_glow(battle: BattleSession, page: BattlePage, directory: String) -> void:
	# Exercise actual fixed-step flight and fluid tracking, not a synthetic straight line.
	for index in battle.threats.size():
		var shot := battle.threats[index]
		shot.curvature = 0.4 if index % 2 else 0.0
		shot.acceleration = 0.0
		shot.trail.clear()
		shot.life = 10.0
	for frame in 72:
		battle._advance_threats(1.0 / 60.0)
		await physics_frame
		if frame == 29: await _capture(directory, "flight-early")
	await process_frame
	await _capture(directory, "flight-hdr-fluid")
	var fluid := page.visuals.fluid
	for shot in battle.threats:
		var id := StringName("threat_%d" % shot.get_instance_id())
		_check(fluid._motion.has(id), "moving threat remains registered with shared fluid")
		var motion: Dictionary = fluid._motion[id]
		_check(motion.plumes.any(func(plume: FluidInfluence) -> bool: return plume.density > 0.0), "moving threat continues injecting an advected fluid plume")
		_check(motion.color == BattleThreatOverlay.threat_color(shot), "fluid illumination follows projectile identity")
		_check(((shot.position - shot.trail[0]) * battle.ARENA_SIZE).length() > 100.0, "slow straight and curved shots retain distance-based tail history")
	_check(fluid._lights.any(func(light: PointLight2D) -> bool: return light.enabled), "native lighting is still active alongside HDR emission")
	var world := page.stage.viewport.get_texture().get_image()
	var peak := 0.0
	for shot in battle.threats:
		var center := Vector2i(shot.position * Vector2(world.get_size()))
		for y in range(center.y - 12, center.y + 13):
			for x in range(center.x - 12, center.x + 13):
				var pixel := world.get_pixel(x, y)
				peak = maxf(peak, maxf(pixel.r, maxf(pixel.g, pixel.b)))
	print("Threat world HDR peak: ", peak)
	_check(peak > 1.0, "world render contains HDR projectile radiance above display white")
	page.visuals.threat_glow.hide()
	await _advance(0.1)
	await _capture(directory, "flight-fluid-without-emission")
	page.visuals.threat_glow.show()


func _window() -> void:
	assert(DisplayServer.get_name() != "headless", "Window evidence requires the real renderer")
	root.size = Vector2i(1920, 1080)
	var directory := EVIDENCE.path_join("window-%s" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for book: BookPresentation in ArchiveHome.BOOKS:
		var battle := _session("pin_archer", book.id)
		var refrain := battle._spawn_enemy(load("res://game/content/enemies/refrain.tres"), Vector2(0.66, 0.7))
		var warden := battle._spawn_enemy(load("res://game/content/enemies/folio_warden.tres"), Vector2(0.76, 0.7))
		_place(refrain, Vector2(0.66, 0.7))
		_place(warden, Vector2(0.76, 0.7))
		# Extra fixture health lets all three survive incidental chains from each book.
		for enemy in battle.enemies:
			enemy.max_hp_q = 600 * battle.Q
			enemy.hp_q = enemy.max_hp_q
		warden.attack_clock = 0.0
		battle._advance_ward(warden, 0.0)
		var settings := AppSettings.new(directory.path_join("settings.cfg"))
		settings.sound = false
		settings.quality = 0 if "--low" in OS.get_cmdline_user_args() else 2
		settings.reduce_motion = "--reduce-motion" in OS.get_cmdline_user_args()
		var page := BattlePage.create(battle, settings, book)
		page.theme = ArchiveTheme.create(book.color)
		root.add_child(page)
		var router := InputRouter.new()
		router.typing = battle.typing
		router.configure(InputRouter.Context.TYPING)
		router.action_requested.connect(battle.queue_action)
		page.add_child(router)
		await _advance(0.1)
		for enemy in battle.enemies:
			enemy.attack_clock = 0.4
			enemy.aimed_position = battle.player_position
			enemy.aiming = enemy.behavior != &"ward"
		await _advance(0.08)
		await _capture(directory, str(book.id) + "-warning")
		await _advance(0.5)
		await _capture(directory, str(book.id) + "-first-beat")
		await _advance(0.75)
		await _capture(directory, str(book.id) + "-second-beat")
		# Real input, each book, each new target; suspend attacks to isolate targetability.
		for target in battle.enemies:
			target.attack_clock = 100.0
			target.aiming = false
			target.followup_time = 0.0
			target.speed = 0.0
		for target in battle.enemies:
			_check(target.alive(), "every new target survives to its explicit input check")
			battle.typing.select_target(target.id)
			var completed := battle.completed_words
			var health := target.hp_q
			var word := battle.typing.word
			for character in word:
				var key := InputEventKey.new()
				key.keycode = character.to_upper().unicode_at(0) as Key
				key.unicode = character.unicode_at(0)
				key.pressed = true
				Input.parse_input_event(key)
				await _advance(0.03)
			await _advance(0.65)
			_check(battle.completed_words > completed, "%s accepts physical input for %s" % [book.id, target.kind])
			_check(target.hp_q < health, "%s settles actual damage on %s" % [book.id, target.kind])
		await _capture(directory, str(book.id) + "-typed")
		page.queue_free()
		await process_frame
	print("Enemy window evidence: ", ProjectSettings.globalize_path(directory))


func _advance(seconds: float) -> void:
	for frame in ceili(seconds * 60.0): await physics_frame
	await process_frame


func _capture(directory: String, label: String) -> void:
	paused = true
	await RenderingServer.frame_post_draw
	var source := root.get_texture().get_image()
	var image := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width(): image.set_pixel(x, y, source.get_pixel(x, y).linear_to_srgb())
	image.save_png(directory.path_join(label + ".png"))
	paused = false


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
