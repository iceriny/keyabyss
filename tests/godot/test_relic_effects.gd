extends SceneTree
## Mechanism-family regressions through formal acquisition, compilation and paid combat.

const Q := 1024
var compiler := BuildCompiler.new()
var acquisition := AcquisitionService.new(compiler)
var sessions: Array[BattleSession] = []
var failures := 0
var checks := 0

class CalibrationBattle:
	extends BattleSession

	func _advance_encounter(_delta: float) -> void:
		pass # The finite calibration scenario owns its target schedule.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if "--storm-ablation" in OS.get_cmdline_user_args():
		_storm_ablation()
		quit(0 if failures == 0 else 1)
		return
	if "--balance" in OS.get_cmdline_user_args():
		_balance()
		quit(0 if failures == 0 else 1)
		return
	_damage()
	_frost()
	_flame()
	_storm()
	_spirit()
	_defense_and_recovery()
	_ultimates_and_sources()
	_snapshot_install()
	for session in sessions: session.free()
	print("RELIC_EFFECTS: checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)


func _damage() -> void:
	var plain := _hit_damage(_session(&"frost"), "abcde")
	_check(_hit_damage(_session(&"frost", ["G002"]), "abcde") > plain, "generic power increases committed damage")
	_check(_hit_damage(_session(&"frost", ["G003"]), "abcde") > plain, "perfect-word bonus increases committed damage")
	_check(_hit_damage(_session(&"frost", ["G011"]), "abcde") > plain, "fully manual bonus increases committed damage")
	var short_plain := _hit_damage(_session(&"frost"), "abcd")
	_check(_hit_damage(_session(&"frost", ["G004"]), "abcd") > short_plain, "short-word bonus is consumed")
	var long_plain := _hit_damage(_session(&"frost"), "abcdefg")
	_check(_hit_damage(_session(&"frost", ["G004"]), "abcdefg") < long_plain, "short-word tradeoff reduces long-word damage")
	_check(_hit_damage(_session(&"frost", ["G005"]), "abcdefg") > long_plain, "long-word bonus is consumed")
	_check(_hit_damage(_session(&"frost", ["G013"]), "abcde") > plain, "fresh-target bonus affects contact")
	for assets in [[], ["G014"]]:
		var session := _session(&"frost", assets)
		session.enemies[0].hp_q = floori(session.enemies[0].max_hp_q / 4.0)
		var damage := _hit_damage(session, "abcde")
		if assets.is_empty(): plain = damage
		else: _check(damage > plain, "wounded-target bonus affects contact")
	for assets in [[], ["G012"]]:
		var session := _session(&"frost", assets)
		var damage := _hit_damage(session, "abcde", true)
		if assets.is_empty(): plain = damage
		else: _check(damage > plain, "imperfect bonus requires a real rejected input")
	var cap := _session(&"frost", ["G001", "G001"])
	_check(cap.player_max_hp_q == 116 * Q, "flat maximum HP enters actual session initialization")


func _frost() -> void:
	var plain := _session(&"frost")
	var tuned := _session(&"frost", ["F001", "F004", "F014", "F018", "F005", "F021", "F003"])
	plain.runtime._apply_cold(plain.enemies[0], 80 * Q, plain.compiled_build)
	tuned.runtime._apply_cold(tuned.enemies[0], 80 * Q, tuned.compiled_build)
	_check(tuned.enemies[0].cold > plain.enemies[0].cold, "cold-point efficiency increases actual status")
	plain.runtime._apply_cold(plain.enemies[0], 20 * Q, plain.compiled_build)
	tuned.runtime._apply_cold(tuned.enemies[0], 20 * Q, tuned.compiled_build)
	_check(tuned.enemies[0].frozen_time > plain.enemies[0].frozen_time, "freeze duration extension is consumed")
	_check(tuned.run_state.shield_q == Q and tuned.resonance_q == Q, "freeze grants shield and resonance")
	plain.runtime.advance(1.0)
	tuned.runtime.advance(1.0)
	_check(tuned.enemies[0].cold > plain.enemies[0].cold, "cold natural decay modifier preserves more points")
	_word(plain, "abcde")
	_word(tuned, "abcde")
	_check(tuned.projectiles[-1].speed > plain.projectiles[-1].speed, "frost flight speed reaches the actual projectile")
	_check(tuned.projectiles[-1].effect.applications > plain.projectiles[-1].effect.applications, "additional frost pierce reaches paid hit budget")
	var capped := _session(&"frost", ["F004", "F004", "F027"])
	capped.runtime._apply_cold(capped.enemies[0], 100 * Q, capped.compiled_build)
	capped.enemies[1].boss = true
	capped.runtime._apply_cold(capped.enemies[1], 100 * Q, capped.compiled_build)
	_check(is_equal_approx(capped.enemies[0].frozen_time, 2.45), "summed freeze bonuses obey the 450ms cap in actual status")
	_check(is_equal_approx(capped.enemies[1].frozen_time, 1.725), "bosses consume half the capped freeze extension")
	for session in [plain, tuned]:
		session.runtime.on_dodge(session.player_position, session.player_position)
	var mist := _session(&"frost", ["F009", "F010"])
	mist.runtime.on_dodge(mist.player_position, mist.player_position)
	_check(mist.runtime.fields[-1].radius > plain.runtime.fields[-1].radius and mist.runtime.fields[-1].expires_at - mist.runtime.clock > plain.runtime.fields[-1].expires_at - plain.runtime.clock, "frost dodge mist radius and duration are consumed")


func _flame() -> void:
	var plain := _session(&"flame")
	var tuned := _session(&"flame", ["A002", "A003", "A005", "A006", "A007"])
	for session in [plain, tuned]: session.runtime.add_burn(session.enemies[0], 40, "burn-test")
	_check(tuned.enemies[0].burn > plain.enemies[0].burn, "burn-point efficiency affects actual status")
	for session in [plain, tuned]: session.runtime.advance(0.15)
	_check(tuned.runtime.actual_damage_q > plain.runtime.actual_damage_q, "burn modifier changes actual timed damage")
	for session in [plain, tuned]:
		_word(session, "abcde")
		_word(session, "abcde")
		_word(session, "abcde")
		session.runtime.contact(session.projectiles[-1].effect, session.enemies[0], session.player_position)
	_check(tuned.runtime.fields[-1].radius > plain.runtime.fields[-1].radius, "empowered flame mist radius is consumed")
	_check(tuned.runtime.fields[-1].expires_at > plain.runtime.fields[-1].expires_at, "empowered flame mist duration is consumed")
	var field_plain := _session(&"flame")
	var field_tuned := _session(&"flame", ["A005"])
	for session in [field_plain, field_tuned]:
		session.runtime._region(session.enemies[0].position, 90.0, 2.0, &"fire_field")
		session.runtime.advance(0.6)
	_check(field_tuned.enemies[0].burn > field_plain.enemies[0].burn, "fire field rate is consumed over world time")
	var dodge := _session(&"flame", ["A008"])
	dodge.runtime.on_dodge(dodge.player_position, dodge.player_position)
	_check(is_equal_approx(dodge.runtime.fields[-1].radius, 68.0) and is_equal_approx(dodge.runtime.fields[-1].expires_at, 2.5), "flame dodge field consumes both parameter units")


func _storm() -> void:
	var plain := _session(&"storm")
	var tuned := _session(&"storm", ["T001", "T005", "T006", "T014", "T017"])
	for session in [plain, tuned]: session.runtime.add_shock(session.enemies[0], 31)
	_check(tuned.enemies[0].shock > plain.enemies[0].shock, "shock point modifier affects real status")
	_check(tuned.enemies[0].shock_grace > plain.enemies[0].shock_grace, "shock grace modifier reaches status lifetime")
	for session in [plain, tuned]: _word(session, "abcde")
	_check(tuned.runtime.actual_damage_q > plain.runtime.actual_damage_q and tuned.run_state.shield_q == Q, "preexisting shock consumes increased chain charge and grants shield")
	_check(not plain.effects.is_empty() and not tuned.effects.is_empty(), "main arc creates a finite successor")
	_check(tuned.effects[0].arc_charge > plain.effects[0].arc_charge, "chain successor carries the paid charge")
	var tail_plain := _session(&"storm")
	var tail_tuned := _session(&"storm", ["T003"])
	for session in [tail_plain, tail_tuned]:
		_word(session, "abcde")
		session._advance_effects(0.1)
	_check(tail_tuned.enemies[1].hp_q < tail_plain.enemies[1].hp_q, "chain tail parameter changes actual successor hit damage")
	var decay_plain := _session(&"storm")
	var decay_tuned := _session(&"storm", ["T017"])
	for session in [decay_plain, decay_tuned]:
		session.runtime.add_shock(session.enemies[0], 40)
		session.runtime.advance(3.0)
	_check(decay_tuned.enemies[0].shock > decay_plain.enemies[0].shock, "shock decay reduction is consumed after grace")


func _spirit() -> void:
	var plain := _session(&"spirit")
	var tuned := _session(&"spirit", ["P001", "P003", "P004", "P005", "P002"])
	for session in [plain, tuned]: _word(session, "abcde")
	_check(tuned.enemies[0].vulnerability > plain.enemies[0].vulnerability, "mark modifier changes actual word contact status")
	_check(tuned.enemies[0].mark_grace > plain.enemies[0].mark_grace and tuned.spirit_time > plain.spirit_time, "mark grace and spirit idle duration are consumed")
	for session in [plain, tuned]:
		session.typing.upsert_target(session.enemies[0].id, "abcde")
		session.typing.select_target(session.enemies[0].id)
		session.typing.feed("a")
		session.step(0.0)
	_check(tuned.spirit_time > plain.spirit_time, "correct partial input preserves the increased paper idle duration")
	var plain_attack := plain.runtime.take_spirit_attack(plain.enemies[0], plain.player_position)
	var tuned_attack := tuned.runtime.take_spirit_attack(tuned.enemies[0], tuned.player_position)
	var plain_hp := plain.enemies[0].hp_q
	var tuned_hp := tuned.enemies[0].hp_q
	plain.runtime.contact(plain_attack, plain.enemies[0], plain.player_position)
	tuned.runtime.contact(tuned_attack, tuned.enemies[0], tuned.player_position)
	_check(tuned_hp - tuned.enemies[0].hp_q > plain_hp - plain.enemies[0].hp_q, "paper attack bonus produces increased committed damage")
	for session in [plain, tuned]: session.runtime.advance(3.0)
	_check(tuned.enemies[0].vulnerability > plain.enemies[0].vulnerability, "mark decay reduction is consumed")
	var cap := _session(&"spirit", ["P007", "P026"])
	for index in 12: cap._summon_spirit()
	_check(cap.spirits.size() == BattleSession.SPIRIT_CAPACITY + 2, "summed spirit capacity respects cap in actual summon lifecycle")
	var bookmark := _session(&"storm", ["G026", "G026"])
	for index in 6: _word(bookmark, "abcde")
	_check(bookmark.enemies[0].vulnerability == 32, "repeated paid bookmark hits stop at the secondary mark ceiling")
	bookmark.enemies[0].vulnerability = 80
	bookmark.enemies[0].mark_grace = 0.25
	bookmark.enemies[0].marked_time = 0.4
	_word(bookmark, "abcde")
	_check(bookmark.enemies[0].vulnerability == 80, "bookmark cannot truncate a stronger native mark")
	_check(is_equal_approx(bookmark.enemies[0].mark_grace, 0.25) and is_equal_approx(bookmark.enemies[0].marked_time, 0.4), "bookmark cannot refresh a stronger native mark lifetime")
	var native_mark := _session(&"spirit", ["G026", "G026"])
	for index in 7: _word(native_mark, "abcde")
	_check(native_mark.enemies[0].vulnerability == 127, "native paid paper words retain the full native mark ceiling")
	var naming_pen := _session(&"spirit", ["P015"])
	_word(naming_pen, "abcde")
	_check(naming_pen.enemies[0].vulnerability == 24, "native naming pen applies its extra mark without a bookmark")
	var combined_mark := _session(&"spirit", ["G026", "G026", "P015", "P015"])
	_word(combined_mark, "abcde")
	_check(combined_mark.enemies[0].vulnerability == 38, "native naming pen and paper mark can exceed the bookmark ceiling on the same hit")
	for index in 6: _word(combined_mark, "abcde")
	_check(combined_mark.enemies[0].vulnerability == 127, "coexisting bookmark cannot restrict the native naming pen ceiling")


func _defense_and_recovery() -> void:
	var plain := _session(&"frost")
	var tuned := _session(&"frost", ["G007", "G009", "G010", "G008", "G017", "G018", "G019", "G028", "F017", "G021"])
	for session in [plain, tuned]: session._take_player_damage(20 * Q, "damage-test")
	_check(tuned.player_hp_q > plain.player_hp_q, "defense modifier reduces actual HP loss")
	var glass := _session(&"frost", ["R043"])
	var glass_hp := glass.player_hp_q
	glass._take_player_damage(20 * Q, "glass-unshielded")
	_check(glass_hp - glass.player_hp_q == 26 * Q, "glass cover consumes its thirty-percent actual life damage cost")
	glass.runtime.add_shield(10 * Q)
	glass_hp = glass.player_hp_q
	glass._take_player_damage(20 * Q, "glass-shielded")
	_check(glass_hp - glass.player_hp_q == 13 * Q and glass.run_state.shield_q == 0, "glass cover life cost applies after native shield absorption")
	for session in [plain, tuned]:
		session.player_hp_q = 50 * Q
		for index in 6: _word(session, "abcde")
	_check(tuned.player_hp_q == 51 * Q and plain.player_hp_q == 50 * Q, "six actual words consume periodic healing")
	_check(tuned.run_state.shield_q == 2 * Q and plain.run_state.shield_q == 0, "five actual words consume periodic shielding")
	tuned.runtime.add_shield(200 * Q)
	_check(tuned.run_state.shield_q == 68 * Q, "shield addition consumes enlarged maximum and clamps actual shield")
	var hp := tuned.player_hp_q
	var pickup := tuned.spawn_pickup(&"ink")
	tuned.typing.upsert_target(pickup.id, "abcde")
	tuned.typing.select_target(pickup.id)
	for character in "abcde": tuned.typing.feed(character)
	tuned.step(0.0)
	_check(tuned.player_hp_q == hp + 2 * Q and pickup.consumed, "actual pickup word grants healing once")
	var parry_plain := _session(&"frost")
	var parry_tuned := _session(&"frost", ["G017", "G028", "F017"])
	for session in [parry_plain, parry_tuned]:
		session.enemies[0].position = session.player_position + Vector2(0, -60) / BattleSession.ARENA_SIZE
		session.parry_window = BattleSession.DEFENSE_WINDOW
		session._counter_contact(session.enemies[0])
	_check(parry_tuned.run_state.shield_q == 2 * Q and parry_tuned.resonance_q > parry_plain.resonance_q, "perfect parry consumes shield and resonance rewards")
	_check(parry_tuned.enemies[0].cold == 18 and parry_plain.enemies[0].cold == 0, "perfect parry paid counter applies cold")
	var resonance := tuned.resonance_q
	tuned.runtime.on_dodge(tuned.player_position, tuned.player_position)
	_check(tuned.resonance_q > resonance, "dodge resonance reward is committed")
	var kill := _session(&"frost", ["G022", "G023"])
	kill.enemies[0].hp_q = 1
	_hit_damage(kill, "abcde")
	_check(kill.run_state.shield_q == Q and not kill.enemies[0].alive(), "actual lethal spell contact grants kill shield")
	var kill_resonance := kill.resonance_q
	kill.runtime.on_enemy_death(kill.enemies[0], &"fixture")
	_check(kill.run_state.shield_q == Q and kill.resonance_q == kill_resonance, "repeat death notification cannot duplicate kill rewards")


func _ultimates_and_sources() -> void:
	for book in BuildCompiler.BOOKS:
		var plain := _session(book)
		var tuned := _session(book, ["G020", "G031"])
		for session in [plain, tuned]: session._commit_ultimate()
		_check(is_equal_approx(tuned.ultimates[0].duration - plain.ultimates[0].duration, 0.4), "%s ultimate consumes duration" % book)
		_check(tuned.run_state.shield_q - plain.run_state.shield_q == 5 * Q, "%s ultimate commits extra shield" % book)
	var domain_plain := _session(&"frost")
	var domain_tuned := _session(&"frost", ["F019"])
	for session in [domain_plain, domain_tuned]:
		session.enemies[0].position = session.player_position
		session._commit_ultimate()
		session._advance_ultimates(0.5)
	_check(domain_tuned.enemies[0].cold > domain_plain.enemies[0].cold, "frost ultimate pulse consumes extra cold")
	var selection := BuildSelection.new()
	selection.book_id = &"spirit"
	_check(not acquisition.evaluate(selection, &"P023").eligible, "cross-book cold benefit is rejected without an actual source")
	var sourced := _session(&"spirit", ["R003", "G025", "P023", "P025"])
	var source_plain := _session(&"spirit", ["R003", "G025"])
	for session in [sourced, source_plain]:
		session.enemies[0].cold = 40
		var effect: BattleEffect = session.runtime.take_spirit_attack(session.enemies[0], session.player_position)
		session.runtime.contact(effect, session.enemies[0], session.player_position)
	_check(sourced.runtime.actual_damage_q > source_plain.runtime.actual_damage_q, "legal cross-book source enables real cold-paper synergy")
	_check(sourced.enemies[0].shock == 4 and source_plain.enemies[0].shock == 0, "legal shock source enables paper attack to apply shock")


func _snapshot_install() -> void:
	var flame := _session(&"flame")
	for index in 3: _word(flame, "abcde")
	var old_flame := flame.projectiles[-1].effect
	var next_flame := _session(&"flame", ["A003", "A006", "A007"])
	flame.install_prepared_build(next_flame.compiled_build)
	flame.runtime.contact(old_flame, flame.enemies[0], flame.player_position)
	_check(flame.enemies[0].burn == 70, "in-flight flame keeps its original burn accumulation after build installation")
	var field: SpellField = flame.runtime.fields[-1]
	_check(is_equal_approx(field.radius, 115.0) and is_equal_approx(field.expires_at - flame.runtime.clock, 3.2), "in-flight empowered flame keeps its original field radius and duration")
	var frost := _session(&"frost")
	_word(frost, "abcde")
	var old_frost := frost.projectiles[-1].effect
	var next_frost := _session(&"frost", ["F004"])
	frost.install_prepared_build(next_frost.compiled_build)
	frost.enemies[0].cold = 60
	frost.runtime.contact(old_frost, frost.enemies[0], frost.player_position)
	_check(is_equal_approx(frost.enemies[0].frozen_time, 2.0), "in-flight frost freezes with its original duration after build installation")


func _balance() -> void:
	var reports: Array[Dictionary] = []
	for book in BuildCompiler.BOOKS:
		var tailored := {&"frost": ["F001", "F002", "F004", "F015", "F020", "F021"], &"flame": ["A001", "A002", "A003", "A005", "A006", "A007"], &"storm": ["T001", "T002", "T003", "T006", "T015", "T017"], &"spirit": ["P001", "P003", "P007", "P006", "P008", "P009"]}
		var profiles := {
			"empty": [],
			"legacy6": ["R001", "R001", "R016", "R016", "R013", "R039"],
			"added6": ["G002", "G002", "G003", "G003", "G009", "G010"],
			"tailored6": tailored[book],
			"legacy_extreme": _extreme_assets(book, true),
			"extreme": _extreme_assets(book),
		}
		if "--tailored-only" in OS.get_cmdline_user_args(): profiles = {"tailored6": tailored[book]}
		if "--six-only" in OS.get_cmdline_user_args(): profiles = {"legacy6": profiles.legacy6, "added6": profiles.added6, "tailored6": tailored[book]}
		if "--storm-extreme-only" in OS.get_cmdline_user_args():
			if book != &"storm": continue
			profiles = {"extreme": profiles.extreme}
		if "--extreme-pressure-only" in OS.get_cmdline_user_args(): profiles = {"legacy_extreme": profiles.legacy_extreme, "extreme": profiles.extreme}
		for profile in profiles:
			for cps in [3.0, 6.0, 9.0]:
				for scenario in ["solo", "dense", "pressure"]:
					if "--extreme-pressure-only" in OS.get_cmdline_user_args() and scenario != "pressure": continue
					reports.append(_balance_case(book, profiles[profile], profile, cps, scenario))
	var path := "res://.temp/relic-upgrade/effects/balance-tailored.json" if "--tailored-only" in OS.get_cmdline_user_args() else "res://.temp/relic-upgrade/effects/balance.json"
	if "--six-only" in OS.get_cmdline_user_args(): path = "res://.temp/relic-upgrade/effects/balance-six-after-limit.json"
	if "--storm-extreme-only" in OS.get_cmdline_user_args(): path = "res://.temp/relic-upgrade/effects/balance-storm-after-limit.json"
	if "--extreme-pressure-only" in OS.get_cmdline_user_args(): path = "res://.temp/relic-upgrade/effects/balance-pressure-final.json"
	var output := FileAccess.open(path, FileAccess.WRITE)
	output.store_string(JSON.stringify({"reports": reports, "failures": failures, "scope": "Controlled scenarios; normal mode, seed relic-effects, 60Hz, distinct-initial five-letter vocabulary, 100% correct 3/6/9 scheduled cps through TypingSession. Solo/pressure: 1000000HP durable ordinary target to avoid execution/clipping during extreme output sampling; dense: six 100HP references. Stationary targets, AI attack and room schedule disabled, actual knockback/collision/status/death retained. Pressure additionally applies 8HP damage every three seconds via native damage settlement, nine finite probes; shield absorbed and healing during the sampled fight are recorded separately from unused shield and prior acquisition healing. No ultimate, pickup, active defense, growth, route or rewards earned in the fight. Build profiles are explicit legal prior acquisitions, not random reward-path claims. Both extreme profiles have separately recorded much larger opportunity counts and are cap stress cases, not equal-budget comparisons. Not full difficulty, highest-mode gate or human-play validation."}, "\t"))
	output.close()
	print("RELIC_BALANCE: cases=", reports.size(), " failures=", failures)


func _extreme_assets(book: StringName, only_legacy: bool = false) -> Array:
	var selection := BuildSelection.new()
	selection.book_id = book
	var relics: Array = []
	while true:
		var candidates := acquisition.candidates(selection, {"shortest": 5, "longest": 5})
		if candidates.is_empty(): break
		candidates.sort()
		var id := &""
		for candidate in candidates:
			if not only_legacy or StringName(candidate) in BuildCompiler.RESTORED_RELICS:
				id = StringName(candidate)
				break
		if id == &"": break
		_acquire(selection, id)
		relics.append(str(id))
	return relics


func _storm_ablation() -> void:
	var all_assets := _extreme_assets(&"storm")
	var assembly := [&"power_pct", &"low_health_pct", &"shielded_pct", &"perfect_pct", &"imperfect_pct", &"manual_pct", &"combo_pct", &"empowered_pct", &"short_pct", &"long_pct", &"storm_direct_pct"]
	var hit := [&"fresh_pct", &"wounded_pct", &"boss_pct", &"frozen_pct", &"shocked_pct", &"burning_pct", &"mixed_pct", &"cold_chain_pct", &"burn_chain_pct"]
	var groups := {"full": [], "mute_assembly": assembly, "mute_hit": hit, "mute_cross_mark_hit": [&"cross_mark_hit"], "mute_charge": [&"charge_pct"], "mute_chain_delivery": [&"chain_hits", &"chain_tail_pct", &"chain_range", &"storm_burst_pct", &"storm_burst_radius", &"overload_pct"], "mute_added_multipliers": assembly + hit + [&"charge_pct"], "mute_all_added": RelicParameters.CAPS.keys()}
	var reports: Array[Dictionary] = [_balance_case(&"storm", _extreme_assets(&"storm", true), "legacy_extreme", 6.0, "solo")]
	for group in groups: reports.append(_balance_case(&"storm", all_assets, group, 6.0, "solo", groups[group]))
	var output := FileAccess.open("res://.temp/relic-upgrade/effects/storm-ablation.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"reports": reports, "failures": failures, "scope": "Same legal acquisitions and native combat as balance solo at 6cps. Test-only post-compile modifier removal isolates causal contributions; muted profiles are diagnostic interventions, not achievable reward paths. Production assets, old relic parameters and other added modifiers remain intact. Source raw sums and impact counts come from native committed impact events; max mark samples native status."}, "\t"))
	output.close()
	print("STORM_ABLATION: cases=", reports.size(), " failures=", failures)


func _balance_case(book: StringName, relics: Array, profile: String, cps: float, scenario: String, muted: Array = []) -> Dictionary:
	var session := _session(book, relics, true)
	var original_modifiers := session.compiled_build._modifiers.duplicate()
	for key in muted: session.compiled_build._modifiers.erase(key)
	var source_counts: Dictionary[StringName, int] = {}
	var source_raw: Dictionary[StringName, int] = {}
	session.event_committed.connect(func(event: Dictionary) -> void:
		if event.kind == &"impact":
			var source: StringName = event.source
			source_counts[source] = source_counts.get(source, 0) + 1
			source_raw[source] = source_raw.get(source, 0) + int(event.raw_q))
	for owner in session._word_sampler.selected.keys(): session._word_sampler.release(owner)
	session.typing.set_targets({})
	session.enemies.clear()
	session._enemies_by_id.clear()
	session._pickup_clock = 9999.0
	var count := 6 if scenario == "dense" else 1
	for index in count:
		var at := Vector2(.66, .48) + Vector2.from_angle(index * 2.399) * (100.0 if count > 1 else 0.0) / BattleSession.ARENA_SIZE
		var enemy := session._spawn_enemy(load("res://game/content/enemies/nib.tres"), at)
		enemy.max_hp_q = (100 if count > 1 else 1000000) * Q
		enemy.hp_q = enemy.max_hp_q
		enemy.speed = 0.0
		enemy.stationary = true
		enemy.attack_clock = 9999.0
		enemy.combat_locked = true
		enemy.word_pending = false
		session.typing.upsert_target(enemy.id, enemy.word)
	var next_letter := 0.0
	var hp_lost := 0
	var shield_absorbed := 0
	var damage6 := 0
	var damage18 := 0
	var frozen_seconds := 0.0
	var max_mark := 0
	var hp_start := session.player_hp_q
	var prior_heal := session.runtime.healed_q
	for tick in 1800:
		if tick / 60.0 >= next_letter:
			next_letter += 1.0 / cps
			if session.typing.target_id == &"":
				var targets: Array[BattleEnemy] = session._living().filter(func(enemy: BattleEnemy) -> bool: return not enemy.word_pending)
				if book == &"flame": targets.sort_custom(func(a: BattleEnemy, b: BattleEnemy) -> bool: return a.burn < b.burn)
				if not targets.is_empty(): session.typing.select_target(targets[0].id)
			if session.typing.target_id != &"" and session.typing.progress < session.typing.word.length():
				session.typing.feed(session.typing.word[session.typing.progress])
		if scenario == "pressure" and tick > 0 and tick % 180 == 0:
			var before_hp := session.player_hp_q
			var before_shield := session.run_state.shield_q
			session._take_player_damage(8 * Q, "pressure:%d" % tick)
			hp_lost += before_hp - session.player_hp_q
			shield_absorbed += before_shield - session.run_state.shield_q
		session.step(1.0 / 60.0)
		for enemy in session._living():
			if enemy.frozen_time > 0.0: frozen_seconds += 1.0 / 60.0
			max_mark = maxi(max_mark, enemy.vulnerability)
		if tick == 359: damage6 = session.runtime.actual_damage_q
		if tick == 1079: damage18 = session.runtime.actual_damage_q
		if session._living().is_empty() or session.player_hp_q <= 0: break
	if session.elapsed < 6.0: damage6 = session.runtime.actual_damage_q
	var report := {"book": str(book), "profile": profile, "opportunities": relics.size(), "assets": session.compiled_build.assets(), "cps": cps, "scenario": scenario, "seconds": session.elapsed, "characters": session.manual_characters, "casts": session.runtime.book_cast_count(), "damage": session.runtime.actual_damage_q / float(Q), "damage6": damage6 / float(Q), "late_dps": (session.runtime.actual_damage_q - damage18) / float(12 * Q) if session.elapsed >= 29.9 else 0.0, "overkill": session.runtime.overkill_damage_q / float(Q), "kills": count - session._living().size(), "hp_lost": hp_lost / float(Q), "hp_start": hp_start / float(Q), "hp_final": session.player_hp_q / float(Q), "hp_max": session.player_max_hp_q / float(Q), "shield_absorbed": shield_absorbed / float(Q), "effective_heal": (session.runtime.healed_q - prior_heal) / float(Q), "unused_shield": session.run_state.shield_q / float(Q), "freezes": session.runtime.freezes, "frozen_target_seconds": frozen_seconds, "sources": session.runtime.damage_by_source}
	report.merge({"muted": muted, "original_modifiers": original_modifiers, "source_counts": source_counts, "source_raw": source_raw, "max_mark": max_mark})
	_check(session.manual_characters > 0 and session.runtime.actual_damage_q > 0, "%s/%s/%s/%s calibration produces actual input and damage" % [book, profile, cps, scenario])
	print("BALANCE ", book, " ", profile, " ", cps, " ", scenario, " damage=", report.damage, " seconds=", report.seconds)
	sessions.erase(session)
	session.free()
	return report


func _session(book: StringName, relics: Array = [], calibration: bool = false) -> BattleSession:
	var selection := BuildSelection.new()
	selection.book_id = book
	for id in relics: _acquire(selection, StringName(id))
	var compiled := compiler.compile(selection)
	assert(compiled.success(), "fixture must formally compile: " + str(compiled.diagnostics))
	var request := BattleStartRequest.new()
	request.build = compiled.build
	request.vocabulary = [VocabularyEntry.new("abcde", "test")]
	for index in 8: request.vocabulary.append(VocabularyEntry.new(String.chr(98 + index) + "bcde", "test"))
	request.vocabulary_index = VocabularyIndex.build(request.vocabulary)
	request.seed_text = "relic-effects"
	var session: BattleSession = CalibrationBattle.new() if calibration else BattleSession.new()
	sessions.append(session)
	session.start(request)
	var definition: EnemyCombatDefinition = session._enemy_definitions.values()[0]
	session.enemies.clear()
	session._enemies_by_id.clear()
	for index in 2:
		var enemy := BattleEnemy.new()
		enemy.id = StringName("effect-target-%d" % index)
		enemy.word = "abcde"
		enemy.position = Vector2(0.5 + index * 0.08, 0.35)
		enemy.previous_position = enemy.position
		enemy.hp_q = 10000 * Q
		enemy.max_hp_q = enemy.hp_q
		enemy.attack_clock = 1000.0
		enemy.attack_interval = 1000.0
		session.enemies.append(enemy)
		session._enemies_by_id[enemy.id] = enemy
		session._enemy_definitions[enemy.id] = definition
	return session


func _acquire(selection: BuildSelection, id: StringName) -> void:
	var definition := compiler.catalog.get_definition(id) as RelicDefinition
	for required in definition.requires_all:
		if selection.assets.get(StringName(required), 0) == 0: _acquire(selection, StringName(required))
	for required in definition.required_stacks:
		while selection.assets.get(required, 0) < definition.required_stacks[required]: _acquire(selection, required)
	if not definition.requires_any.is_empty():
		var satisfied := false
		for required in definition.requires_any: satisfied = satisfied or selection.assets.get(StringName(required), 0) > 0
		if not satisfied: _acquire(selection, StringName(definition.requires_any[0]))
	var eligibility := acquisition.evaluate(selection, id, {"shortest": 4, "longest": 7})
	assert(eligibility.eligible, "fixture acquisition must be legal: %s %s" % [id, eligibility.diagnostics])
	selection.assets[id] = selection.assets.get(id, 0) + 1


func _word(session: BattleSession, word: String, mistaken: bool = false) -> void:
	session.typing.upsert_target(session.enemies[0].id, word)
	session.typing.select_target(session.enemies[0].id)
	if mistaken: session.typing.feed("z")
	for character in word: session.typing.feed(character)
	session.step(0.0)


func _hit_damage(session: BattleSession, word: String, mistaken: bool = false) -> int:
	_word(session, word, mistaken)
	var before := session.enemies[0].hp_q
	session.runtime.contact(session.projectiles[-1].effect, session.enemies[0], session.player_position)
	return before - session.enemies[0].hp_q


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
