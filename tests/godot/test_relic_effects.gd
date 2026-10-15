extends SceneTree
## Mechanism-family regressions through formal acquisition, compilation and paid combat.

const Q := 1024
var compiler := BuildCompiler.new()
var acquisition := AcquisitionService.new(compiler)
var sessions: Array[BattleSession] = []
var failures := 0
var checks := 0

class EffectBattle:
	extends BattleSession
	var latest_primary: BattleEffect
	var impacts: Array[Dictionary] = []

	func _advance_effects(delta: float) -> void:
		for effect in effects:
			if effect.depth == 0 and effect.word_owner != &"": latest_primary = effect
		super._advance_effects(delta)


class CalibrationBattle:
	extends EffectBattle

	func _advance_encounter(_delta: float) -> void:
		pass # The finite calibration scenario owns its target schedule.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if "--gameplay-balance" in OS.get_cmdline_user_args():
		_gameplay_balance()
		quit(0 if failures == 0 else 1)
		return
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
	_manual_relic_mechanisms()
	_expanded_relic_mechanisms()
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
	plain.runtime._apply_cold(plain.enemies[0], 50 * Q, plain.compiled_build)
	tuned.runtime._apply_cold(tuned.enemies[0], 50 * Q, tuned.compiled_build)
	_check(tuned.enemies[0].cold > plain.enemies[0].cold, "cold-point efficiency increases actual status")
	plain.runtime._apply_cold(plain.enemies[0], 50 * Q, plain.compiled_build)
	tuned.runtime._apply_cold(tuned.enemies[0], 50 * Q, tuned.compiled_build)
	_check(tuned.enemies[0].frozen_time > plain.enemies[0].frozen_time, "freeze duration extension is consumed")
	_check(tuned.run_state.shield_q == Q and tuned.resonance_q == 2 * Q, "freeze consumes combined shield and resonance rewards")
	for session in [plain, tuned]:
		session.enemies[0].cold = 60
		session.enemies[0].cold_grace = 0.0
	plain.runtime.advance(1.0)
	tuned.runtime.advance(1.0)
	_check(tuned.enemies[0].cold > plain.enemies[0].cold, "cold natural decay modifier preserves more points")
	_word(plain, "abcde")
	_word(tuned, "abcde")
	_check(tuned.projectiles[-1].speed > plain.projectiles[-1].speed, "frost flight speed reaches the actual projectile")
	_check(tuned.projectiles[-1].effect.applications == plain.projectiles[-1].effect.applications, "split ice pages preserve the original main spear hit budget")
	var capped := _session(&"frost", ["F004", "F004", "F027"])
	capped.runtime._apply_cold(capped.enemies[0], 100 * Q, capped.compiled_build)
	capped.enemies[1].boss = true
	capped.runtime._apply_cold(capped.enemies[1], 100 * Q, capped.compiled_build)
	_check(is_equal_approx(capped.enemies[0].frozen_time, 2.45), "summed freeze bonuses obey the 450ms cap in actual status")
	_check(is_equal_approx(capped.enemies[1].frozen_time, 1.725), "bosses consume half the capped freeze extension")
	for session in [plain, tuned]:
		session.runtime.on_dodge(session.player_position, session.player_position)
	var mist := _session(&"frost", ["F010"])
	mist.runtime.on_dodge(mist.player_position, mist.player_position)
	_check(mist.runtime.fields[-1].radius > plain.runtime.fields[-1].radius, "frost dodge mist radius is consumed")


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
	_check(is_equal_approx(tuned.runtime.fields[-1].expires_at, plain.runtime.fields[-1].expires_at), "field conversion preserves newly generated empowered flame field duration")
	var field_plain := _session(&"flame")
	var field_tuned := _session(&"flame", ["A005"])
	for session in [field_plain, field_tuned]:
		session.runtime._region(session.enemies[0].position, 90.0, 2.0, &"fire_field")
		session.runtime.advance(0.6)
	_check(field_tuned.enemies[0].burn > field_plain.enemies[0].burn, "fire field rate is consumed over world time")
	var dodge := _session(&"flame", ["A008"])
	dodge.runtime.on_dodge(dodge.player_position, dodge.player_position)
	_check(is_equal_approx(dodge.runtime.fields[-1].radius, 72.0) and is_equal_approx(dodge.runtime.fields[-1].expires_at, 2.75), "flame dodge field consumes both parameter units")


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
	var decay_plain := _session(&"storm")
	var decay_tuned := _session(&"storm", ["T017"])
	for session in [decay_plain, decay_tuned]:
		session.runtime.add_shock(session.enemies[0], 40)
		session.runtime.advance(3.0)
	_check(decay_tuned.enemies[0].shock > decay_plain.enemies[0].shock, "shock decay reduction is consumed after grace")


func _spirit() -> void:
	var plain := _session(&"spirit")
	var tuned := _session(&"spirit", ["P001", "P003", "P005", "P002"])
	for session in [plain, tuned]: _word(session, "abcde")
	_check(tuned.enemies[0].vulnerability > plain.enemies[0].vulnerability, "mark modifier changes actual word contact status")
	_check(tuned.spirit_time > plain.spirit_time, "spirit idle duration is consumed")
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
	_check(cap.spirits.size() == BattleSession.SPIRIT_CAPACITY + 1, "paper crane creation preserves the capacity increase owned only by the awakening")
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
	_check(tuned.run_state.shield_q == 75 * Q, "shield addition consumes enlarged maximum and clamps actual shield")
	var hp := tuned.player_hp_q
	var pickup := tuned.spawn_pickup(&"ink")
	tuned.typing.upsert_target(pickup.id, "abcde")
	tuned.typing.select_target(pickup.id)
	for character in "abcde": tuned.typing.feed(character)
	tuned.step(0.0)
	_check(tuned.player_hp_q == hp + 3 * Q and pickup.consumed, "actual pickup word grants healing once")
	var parry_plain := _session(&"frost")
	var parry_tuned := _session(&"frost", ["G017", "G028", "F017"])
	for session in [parry_plain, parry_tuned]:
		session.enemies[0].position = session.player_position + Vector2(0, -60) / BattleSession.ARENA_SIZE
		session.parry_window = BattleSession.DEFENSE_WINDOW
		session._counter_contact(session.enemies[0])
	_check(parry_tuned.run_state.shield_q == 3 * Q and parry_tuned.resonance_q > parry_plain.resonance_q, "perfect parry consumes shield and resonance rewards")
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
		_check(is_equal_approx(tuned.ultimates[0].duration - plain.ultimates[0].duration, 1.0), "%s ultimate consumes duration" % book)
		_check(tuned.run_state.shield_q - plain.run_state.shield_q == 10 * Q, "%s ultimate commits extra shield" % book)
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


func _manual_relic_mechanisms() -> void:
	_length_and_switch()
	_first_and_mixed_hits()
	_frost_manual_mechanisms()
	_flame_manual_mechanisms()
	_storm_manual_mechanisms()
	_paper_manual_mechanisms()
	_derived_manual_boundaries()


func _length_and_switch() -> void:
	var ruler := _session(&"frost", ["G006", "G006", "R017"])
	_check(not _cast_word(ruler, "abcd").empowered, "length alternation does not empower its first short word")
	var shield := ruler.run_state.shield_q
	_check(_cast_word(ruler, "abcdefg").empowered and ruler.run_state.shield_q - shield == roundi(_n(ruler, &"G006", &"shield") * Q), "short-to-long manual word empowers and pays stacked shield")
	_check(_cast_word(ruler, "abcdefg").empowered, "natural third-word empowerment survives alternation")
	_check(not _cast_word(ruler, "abcdefg").empowered, "same long category cannot repeatedly empower")
	shield = ruler.run_state.shield_q
	_cast_word(ruler, "abcd", 0, true)
	_check(ruler.run_state.shield_q == shield, "assisted short word cannot earn alternation shield")
	_cast_word(ruler, "abcdefg")
	var next := _next_room(ruler, ["G006", "G006", "R017"])
	shield = next.run_state.shield_q
	_check(_cast_word(next, "abcd").empowered and next.run_state.shield_q > shield, "manual word category survives room boundary")
	var interrupted := _session(&"frost", ["G006"])
	_cast_word(interrupted, "abcd")
	var pickup := interrupted.spawn_pickup(&"rune")
	assert(pickup != null, "multiword vocabulary must leave a real pickup word available")
	interrupted.typing.select_target(pickup.id)
	for character in pickup.word: interrupted.typing.feed(character)
	interrupted.step(0.0)
	_check(pickup.consumed and interrupted.manual_characters == 4 + pickup.word.length(), "actual pickup word consumes only its real manual receipts")
	shield = interrupted.run_state.shield_q
	_check(not _cast_word(interrupted, "abcdefg").empowered and interrupted.run_state.shield_q == shield, "completed pickup interrupts short-to-long alternation without paying shield")
	_check(_cast_word(interrupted, "abcde").empowered, "pickup does not advance the natural third enemy-cast cadence")
	var switcher := _session(&"frost", ["G016"])
	_cast_word(switcher, "abcde")
	_check(_projectiles(switcher, &"echo").is_empty(), "switch echo does not trigger on first cast")
	_cast_word(switcher, "abcde")
	_check(_projectiles(switcher, &"echo").is_empty(), "switch echo does not trigger on same target")
	var manual := switcher.manual_characters
	var primary := _cast_word(switcher, "abcde", 1)
	var echoes := _projectiles(switcher, &"echo")
	_check(echoes.size() == 1, "manual target switch owns exactly one echo")
	if not echoes.is_empty():
		var echo := echoes[0]
		_check(echo.target_id == switcher.enemies[0].id and echo.depth == 1 and echo.damage_q == roundi(primary.base_power_q * _n(switcher, &"G016", &"damage_pct") / 100.0), "echo pays current base power share toward previous target")
		switcher.runtime.contact(echo, switcher.enemies[0], switcher.player_position)
		_check(switcher.manual_characters == manual + 5 and _projectiles(switcher, &"echo").size() == 1, "echo contact cannot manufacture input or recurse")
	var dead := _session(&"frost", ["G016"])
	_cast_word(dead, "abcde")
	dead.enemies[0].hp_q = 0
	_cast_word(dead, "abcde", 1)
	_check(_projectiles(dead, &"echo").size() == 1 and _projectiles(dead, &"echo")[0].target_id == dead.enemies[1].id, "dead previous target redirects switch echo to current target")
	var paper := _session(&"spirit", ["G016"])
	_cast_word(paper, "abcde")
	primary = _cast_word(paper, "abcde", 1)
	var pursuit := _projectiles(paper, &"echo")[0]
	paper.runtime.contact(pursuit, paper.enemies[0], pursuit.origin)
	_check(_raw_source(paper, &"echo") == roundi(primary.base_power_q * _n(paper, &"G016", &"damage_pct") / 100.0) and _raw_source(paper, &"echo") > _raw_source(paper, &"spirit_mark"), "paper target switch delivers substantial base-power pursuit despite low primary mark damage")


func _first_and_mixed_hits() -> void:
	var opening := _session(&"frost", ["G013", "G013", "R017"])
	opening.enemies[1].position = opening.enemies[0].position + Vector2(80, 0) / BattleSession.ARENA_SIZE
	var effect := _contact_word(opening, "abcde")
	var expected := roundi(effect.base_power_q * _n(opening, &"G013", &"damage_pct") / 100.0)
	_check(_raw_source(opening, &"G013") == expected * 2, "first actual manual contact bursts both primary and nearby enemy with stacked opening power")
	_contact_word(opening, "abcde")
	_check(_raw_source(opening, &"G013") == expected * 2, "same enemy cannot retrigger opening burst in a room")
	_contact_word(opening, "abcde", 1, true)
	_check(_raw_source(opening, &"G013") == expected * 2, "assisted contact cannot claim unused opening trigger")
	_contact_word(opening, "abcde", 1)
	_check(_raw_source(opening, &"G013") > expected * 2, "another enemy retains its own first manual contact trigger")
	var fresh := _next_room(opening, ["G013", "G013", "R017"])
	_contact_word(fresh, "abcde")
	_check(_raw_source(fresh, &"G013") > 0, "opening eligibility resets in the next room")
	var mixed := _session(&"frost", ["G025", "G027"])
	mixed.enemies[1].position = mixed.enemies[0].position + Vector2(80, 0) / BattleSession.ARENA_SIZE
	mixed.enemies[0].cold = 20
	mixed.enemies[0].burn = 30
	mixed.enemies[0].shock = 20
	mixed.enemies[0].vulnerability = 20
	effect = _contact_word(mixed, "abcde")
	_check(mixed.enemies[0].cold == 35 and mixed.enemies[0].burn == 10 and mixed.enemies[0].shock == 32 and mixed.enemies[0].vulnerability == 20, "mixed hit consumes cold then burn and retains normal on-hit statuses")
	_check(_raw_source(mixed, &"G027") == roundi(effect.base_power_q * _n(mixed, &"G027", &"damage_pct") / 100.0) * 2, "mixed status conversion commits finite area damage")
	var threshold := _session(&"frost", ["G025", "G027"])
	threshold.enemies[0].shock = 20
	_contact_word(threshold, "abcde")
	_check(_raw_source(threshold, &"G027") == 0, "new cold from current hit cannot satisfy mixed pre-hit requirement")
	threshold.enemies[0].cold = 19
	threshold.enemies[0].burn = 29
	threshold.enemies[0].shock = 19
	threshold.enemies[0].vulnerability = 19
	_contact_word(threshold, "abcde")
	_check(_raw_source(threshold, &"G027") == 0, "insufficient mixed states cannot be consumed")
	var cross := _session(&"frost", ["G025", "G025"])
	cross.enemies[1].position = cross.enemies[0].position + Vector2(80, 0) / BattleSession.ARENA_SIZE
	cross.enemies[0].shock = 31
	effect = _contact_word(cross, "abcde")
	_check(cross.enemies[0].shock == 17, "cross-book shock conversion consumes old charge before capped new shock is added")
	_check(_raw_source(cross, &"G025") == roundi(effect.base_power_q * _n(cross, &"G025", &"damage_pct") / 100.0) * 2, "non-storm manual hit cashes independent shock source into area damage")
	var new_charge := _session(&"frost", ["G025"])
	new_charge.enemies[0].shock = 30
	_contact_word(new_charge, "abcde")
	_check(_raw_source(new_charge, &"G025") == 0 and new_charge.enemies[0].shock == 42, "exact shock threshold does not trigger from newly applied charge")


func _frost_manual_mechanisms() -> void:
	var breaking := _session(&"frost", ["F006", "F006"])
	breaking.enemies[1].position = breaking.enemies[0].position + Vector2(80, 0) / BattleSession.ARENA_SIZE
	breaking.enemies[0].frozen_time = 1.5
	var effect := _contact_word(breaking, "abcde")
	_check(breaking.enemies[0].frozen_time == 0.0 and breaking.enemies[0].freeze_cooldown == 1.0, "manual ice spear breaks existing freeze and enters ordinary thaw cooldown")
	_check(_raw_source(breaking, &"F006") == roundi(effect.base_power_q * _n(breaking, &"F006", &"damage_pct") / 100.0) * 2, "nonlethal ice break bursts target and neighbor with stacked base power")
	var new_freeze := _session(&"frost", ["F006"])
	new_freeze.enemies[0].cold = 60
	_contact_word(new_freeze, "abcde")
	_check(new_freeze.enemies[0].frozen_time > 0.0 and _raw_source(new_freeze, &"F006") == 0, "freeze created by current spear cannot immediately break")
	var lethal := _session(&"frost", ["F006"])
	lethal.enemies[0].frozen_time = 1.5
	lethal.enemies[0].hp_q = 1
	_contact_word(lethal, "abcde")
	_check(_raw_source(lethal, &"F006") == 0, "lethal primary contact leaves death shatter to its existing lifecycle")
	var mist := _session(&"frost", ["F009", "F009", "R017"])
	# InputRouter's actual Alt action is dodge_auto. Actions commit before travel
	# and runtime advancement, so this step also reaches the 0.17s landing.
	mist.queue_action(&"dodge_auto")
	mist.step(0.2)
	var dodge_mist := mist.runtime.fields[-1]
	_check(mist._dodge_time == 0.17 and not dodge_mist.contains(mist.player_position) and dodge_mist.expires_at > mist.runtime.clock, "real automatic dodge lands outside its still-live ice mist")
	mist.enemies[0].position = mist.player_position + Vector2(0, -170) / BattleSession.ARENA_SIZE
	mist.enemies[0].previous_position = mist.enemies[0].position
	mist.enemies[1].position = mist.enemies[0].position + Vector2(350, 0) / BattleSession.ARENA_SIZE
	mist.enemies[1].previous_position = mist.enemies[1].position
	_cast_word(mist, "abcde")
	for tick in 60:
		mist.step(1.0 / 60.0)
		if mist.runtime.fields.size() > 1: break
	var field := mist.runtime.fields[-1]
	_check(field != dodge_mist and field.effect.kind == &"cold_field" and field.center == mist.enemies[0].position and is_equal_approx(field.radius, _n(mist, &"F009", &"radius")) and is_equal_approx(field.expires_at - mist.runtime.clock, _n(mist, &"F009", &"duration")) and _raw_source(mist, &"frost_spear") > 0, "manual spear cast outside live dodge mist leaves stacked-duration cold field at real projectile contact")
	var cold := mist.enemies[0].cold
	mist.runtime.advance(0.5)
	_check(mist.enemies[0].cold > cold, "impact cold field accumulates real cold over world time")
	mist.runtime.advance(3.0)
	_check(mist.runtime.fields.is_empty(), "dodge mist and impact field retire at their own deadlines")
	_contact_word(mist, "abcde")
	_check(mist.runtime.fields.is_empty(), "expired dodge mist cannot activate another impact field")
	var ordinary := _session(&"frost", ["F009"])
	ordinary.runtime._region(ordinary.player_position, 150.0, 3.0, &"cold_field")
	_contact_word(ordinary, "abcde")
	_check(ordinary.runtime.fields.size() == 1, "ordinary cold field cannot substitute for dodge mist or perpetuate impact fields")
	var assisted := _session(&"frost", ["F009", "R017"])
	assisted.runtime.on_dodge(assisted.player_position, assisted.player_position)
	_contact_word(assisted, "abcde", 0, true)
	_check(assisted.runtime.fields.size() == 1 and assisted.manual_characters == 1, "assisted mist cast earns no extra field or artificial manual letters")


func _flame_manual_mechanisms() -> void:
	var detonate := _session(&"flame", ["A004", "A004"])
	detonate.enemies[1].position = detonate.enemies[0].position + Vector2(80, 0) / BattleSession.ARENA_SIZE
	detonate.enemies[0].burn = 50
	_contact_word(detonate, "abcde")
	_check(detonate.enemies[0].burn == 80, "burn detonation preserves ten old points and ordinary seventy-point fire contact")
	_check(_raw_source(detonate, &"A004") == roundi(_n(detonate, &"A004", &"consume") * _n(detonate, &"A004", &"damage_per_point") * Q) * 2, "stacked burn consumption commits real explosion to target and neighbor")
	var ignition := _session(&"flame", ["A004"])
	_contact_word(ignition, "abcde")
	_check(_raw_source(ignition, &"A004") == 0 and ignition.enemies[0].burn == 70, "new ignition cannot detonate itself")
	var spread := _session(&"flame", ["A009", "A009"])
	spread.enemies[1].position = spread.enemies[0].position + Vector2(80, 0) / BattleSession.ARENA_SIZE
	for index in 3:
		_add_target(spread, Vector2(60 + index * 35, 0))
	spread.enemies[0].burn = 10
	_contact_word(spread, "abcde")
	_check(spread.enemies[2].burn == roundi(_n(spread, &"A009", &"burn")) and spread.enemies[1].burn == roundi(_n(spread, &"A009", &"burn")) and spread.enemies[3].burn == 0 and spread.enemies[4].burn == 0, "first ignition spreads stacked burn only to nearest two other targets")
	for enemy in spread.enemies.slice(1): enemy.burn = 0
	_contact_word(spread, "abcde")
	_check(spread.enemies.slice(1).all(func(enemy: BattleEnemy) -> bool: return enemy.burn == 0), "already burning target cannot spread ignition again")


func _storm_manual_mechanisms() -> void:
	var chain := _session(&"storm", ["T003", "T003"])
	chain.enemies[1].position = chain.enemies[0].position + Vector2(80, 0) / BattleSession.ARENA_SIZE
	var effect := _cast_word(chain, "abcde")
	_check(_raw_source(chain, &"T003") == 0, "chain ending burst waits for actual final arc")
	chain._advance_effects(0.1)
	var last: Array[Dictionary] = (chain as EffectBattle).impacts.filter(func(event: Dictionary) -> bool: return event.source == &"storm_arc")
	_check(last.size() == 2 and _raw_source(chain, &"T003") == roundi(effect.base_power_q * _n(chain, &"T003", &"damage_pct") / 100.0 * 2.0) * 2, "chain ends once with unused-jump area damage at last target")
	var finish := _raw_source(chain, &"T003")
	chain._advance_effects(1.0)
	_check(_raw_source(chain, &"T003") == finish, "chain ending explosion has no recursive successor")
	var solo := _session(&"storm", ["T003"])
	solo.enemies[1].hp_q = 0
	effect = _cast_word(solo, "abcde")
	_check(_raw_source(solo, &"T003") == roundi(effect.base_power_q * _n(solo, &"T003", &"damage_pct") / 100.0 * 3.0), "isolated primary arc still cashes unused jumps into ending damage")
	var script := _session(&"storm", ["T009", "T009", "R017"])
	script.runtime.on_dodge(script.player_position, script.player_position)
	script.runtime.on_dodge(script.player_position, script.player_position)
	_check(not _cast_word(script, "abcde", 0, true).empowered, "assisted thunder word does not consume prepared dodge empowerment")
	var next := _next_room(script, ["T009", "T009", "R017"])
	effect = _cast_word(next, "abcde")
	_check(effect.empowered and next.enemies[0].shock == 36 + roundi(_n(next, &"T009", &"shock")), "dodge preparation crosses rooms and pays one stacked first-hit shock bonus")
	_check(_cast_word(next, "abcde").empowered, "prepared dodge cast leaves natural third-cast cadence intact")
	_check(not _cast_word(next, "abcde").empowered, "multiple dodges cannot bank repeated prepared casts")
	_delayed_chain_end()


func _delayed_chain_end() -> void:
	var interrupted := _session(&"storm", ["T003"])
	var fields: Array[Dictionary] = []
	interrupted.event_committed.connect(func(event: Dictionary) -> void:
		if event.kind == &"field" and event.source == &"overload": fields.append(event))
	var primary := _cast_word(interrupted, "abcde")
	var queued := interrupted.effects[0]
	var last_contact := interrupted.enemies[0].position
	_check(queued.arc_index == 1 and queued.delay > 0.0 and queued.target_id == interrupted.enemies[1].id, "real manual primary schedules a delayed successor before chain ending")
	interrupted.runtime._deal(interrupted.enemies[1], interrupted.enemies[1].hp_q, &"fixture_other_attack", interrupted.enemies[1].position, 1)
	_check(_raw_source(interrupted, &"T003") == 0 and fields.is_empty(), "another attack killing scheduled target does not settle chain before its due step")
	interrupted._advance_effects(0.1)
	var expected := roundi(primary.base_power_q * _n(interrupted, &"T003", &"damage_pct") / 100.0 * (1.0 + mini(primary.jumps, roundi(_n(interrupted, &"T003", &"max_unused")))))
	_check(_raw_source(interrupted, &"T003") == expected and fields.size() == 1 and fields[0].at == last_contact, "missing successor without replacement ends at previous real contact and preserves planned unused hop")
	_check(interrupted.effects.is_empty() and queued.lot.amount_q == 0, "missing scheduled arc retires its finite paid lot")
	interrupted._advance_effects(1.0)
	_check(_raw_source(interrupted, &"T003") == expected and fields.size() == 1, "interrupted delayed chain explodes only once")
	var replaced := _session(&"storm", ["T003"])
	replaced.enemies[1].position = replaced.enemies[0].position + Vector2(80, 0) / BattleSession.ARENA_SIZE
	_add_target(replaced, Vector2(160, 0))
	var replacement_fields: Array[Dictionary] = []
	replaced.event_committed.connect(func(event: Dictionary) -> void:
		if event.kind == &"field" and event.source == &"overload": replacement_fields.append(event))
	primary = _cast_word(replaced, "abcde")
	replaced.runtime._deal(replaced.enemies[1], replaced.enemies[1].hp_q, &"fixture_other_attack", replaced.enemies[1].position, 1)
	_check(_raw_source(replaced, &"T003") == 0, "available replacement keeps ending damage pending after queued target dies")
	replaced._advance_effects(0.1)
	var arcs: Array[Dictionary] = (replaced as EffectBattle).impacts.filter(func(event: Dictionary) -> bool: return event.source == &"storm_arc")
	expected = roundi(primary.base_power_q * _n(replaced, &"T003", &"damage_pct") / 100.0 * 2.0)
	_check(arcs.size() == 2 and replacement_fields.size() == 1 and replacement_fields[0].at == replaced.enemies[2].position and _raw_source(replaced, &"T003") == expected, "queued arc retargets unvisited replacement before ending there with one unused hop")
	var empty := _session(&"storm", ["T003"])
	_cast_word(empty, "abcde")
	queued = empty.effects[0]
	for enemy in empty.enemies:
		empty.runtime._deal(enemy, enemy.hp_q, &"fixture_other_attack", enemy.position, 1)
	var manual := empty.manual_characters
	var resonance := empty.resonance_q
	empty._advance_effects(0.1)
	empty._advance_effects(1.0)
	_check(empty.effects.is_empty() and queued.lot.amount_q == 0 and _raw_source(empty, &"T003") == 0 and empty.manual_characters == manual and empty.resonance_q == resonance, "all-dead delayed chain cleans up without forged damage or manual income")


func _paper_manual_mechanisms() -> void:
	var transfer := _session(&"spirit", ["P004", "P004"])
	_add_target(transfer, Vector2(60, 0))
	_add_target(transfer, Vector2(200, 0))
	transfer.enemies[0].vulnerability = 100
	transfer.enemies[0].hp_q = 1
	_cast_word(transfer, "abcde")
	_check(not transfer.enemies[0].alive() and transfer.enemies[1].vulnerability == 80 and transfer.enemies[2].vulnerability == 80 and transfer.enemies[3].vulnerability == 0, "lethal paper word transfers capped stacked existing mark to nearest two targets")
	transfer.runtime.on_enemy_death(transfer.enemies[0], &"fixture")
	_check(transfer.enemies[1].vulnerability == 80 and transfer.enemies[2].vulnerability == 80, "repeat death notification cannot transfer mark twice")
	var crane := _session(&"spirit", ["P010", "P010", "R017"])
	crane.runtime.on_dodge(crane.player_position, crane.player_position)
	var far := crane.runtime.fields[-1]
	crane.runtime.on_dodge(crane.enemies[0].position, crane.enemies[0].position)
	var near := crane.runtime.fields[-1]
	_cast_word(crane, "abcde", 0, true)
	_check(crane.runtime.fields.has(near) and _raw_source(crane, &"paper_crane") == 0, "assisted paper word preserves available interception cranes")
	var before := crane.enemies[0].vulnerability
	_cast_word(crane, "abcde")
	_check(not crane.runtime.fields.has(near) and crane.runtime.fields.has(far) and crane.enemies[0].vulnerability == before + 40, "manual paper word consumes nearest crane into twenty mark plus normal twenty mark")
	_check(_raw_source(crane, &"paper_crane") == roundi(_n(crane, &"P010", &"damage") * Q) and crane.manual_characters == 6, "consumed crane pays stacked attack damage without forged input")
	far.expires_at = crane.runtime.clock
	_cast_word(crane, "abcde")
	_check(_raw_source(crane, &"paper_crane") == roundi(_n(crane, &"P010", &"damage") * Q), "expired crane cannot be exchanged for another attack")
	var small := _session(&"spirit", ["P004"])
	small.enemies[0].vulnerability = 5
	small.enemies[0].hp_q = 1
	_cast_word(small, "abcde")
	_check(small.enemies[1].vulnerability == 25, "mark transfer cannot invent points beyond existing death mark")


func _derived_manual_boundaries() -> void:
	var frost := _session(&"frost", ["G013", "G025", "G027", "F006", "F009", "G016", "R017"])
	frost.runtime.on_dodge(frost.player_position, frost.player_position)
	_cast_word(frost, "abcde")
	_cast_word(frost, "abcde", 1)
	frost.enemies[0].cold = 20
	frost.enemies[0].burn = 30
	frost.enemies[0].shock = 31
	frost.enemies[0].frozen_time = 1.5
	var echo := _projectiles(frost, &"echo")[0]
	frost.runtime.contact(echo, frost.enemies[0], echo.origin)
	_check(frost.enemies[0].cold == 20 and frost.enemies[0].burn == 30 and frost.enemies[0].shock == 31 and frost.enemies[0].frozen_time == 1.5, "paid derived echo cannot consume or add manual reaction states")
	_check(_raw_source(frost, &"G013") + _raw_source(frost, &"G027") + _raw_source(frost, &"G025") + _raw_source(frost, &"F006") == 0 and frost.runtime.fields.size() == 1, "derived echo cannot trigger opening, mixed, shock, thaw or mist reactions")
	for enemy in frost.enemies: enemy.hp_q = 0
	var manual := frost.manual_characters
	frost._advance_projectiles(2.2)
	_check(frost.projectiles.is_empty() and frost.effects.is_empty() and frost.manual_characters == manual, "paid original and echo retire when no living target remains without input income or loops")
	var flame := _session(&"flame", ["A004", "A009", "G016"])
	_cast_word(flame, "abcde")
	_cast_word(flame, "abcde", 1)
	flame.enemies[0].burn = 50
	echo = _projectiles(flame, &"echo")[0]
	flame.runtime.contact(echo, flame.enemies[0], echo.origin)
	_check(flame.enemies[0].burn == 50 and flame.enemies[1].burn == 0 and _raw_source(flame, &"A004") == 0, "derived fire echo cannot detonate or spread first ignition")
	var storm := _session(&"storm", ["T003", "R017"])
	storm.enemies[1].hp_q = 0
	_cast_word(storm, "abcde", 0, true)
	_check(_raw_source(storm, &"T003") == 0 and storm.manual_characters == 1, "assisted chain ending cannot mint manual ending burst")


func _expanded_relic_mechanisms() -> void:
	_split_ice_pages()
	_counter_fields_and_chain()
	_fire_field_conversion()
	_chain_return()
	_long_word_cranes()
	_intercept_cross()
	var freeze := _session(&"frost", ["F014"])
	freeze.runtime._apply_cold(freeze.enemies[0], 100 * Q, freeze.compiled_build)
	_check(freeze.run_state.shield_q == Q and freeze.resonance_q == Q, "standalone freeze reward needs no duration prerequisite")
	var charged := _session(&"storm", ["T014"])
	charged.enemies[0].shock = 31
	_cast_word(charged, "abcde")
	_check(charged.run_state.shield_q == Q, "standalone charged-hit shield needs no charge prerequisite")
	var marked := _session(&"spirit", ["P013", "P013"])
	_cast_word(marked, "abcde")
	_check(marked.run_state.shield_q == 3 * Q, "two mark-shield stacks consume the shared three-point cap")


func _split_ice_pages() -> void:
	var split := _session(&"frost", ["F003"])
	split.enemies[1].position = split.enemies[0].position + Vector2(80, 0) / BattleSession.ARENA_SIZE
	_add_target(split, Vector2(120, 0))
	_add_target(split, Vector2(170, 0))
	_cast_word(split, "abcde")
	_cast_word(split, "abcde")
	var primary := _contact_word(split, "abcde")
	_check(primary.empowered and split.effects.size() == 2, "manual empowered ice spear splits only on actual first contact")
	var fragments := split.effects.duplicate()
	_check(fragments[0].target_id == split.enemies[1].id and fragments[1].target_id == split.enemies[2].id, "ice split chooses nearest two other living enemies")
	for fragment in fragments:
		_check(fragment.kind == &"frost_fragment" and fragment.depth == 1 and fragment.manual_count == 0 and fragment.damage_q == roundi(primary.base_power_q * _n(split, &"F003", &"damage_pct") / 100.0), "split fragment pays finite base-power share without manual status input")
	split.runtime.contact(primary, split.enemies[1], primary.origin, false)
	_check(split.effects.size() == 2, "later piercing contact cannot split the same spear again")
	split._advance_effects(0.0)
	var manual := split.manual_characters
	for fragment in fragments: split.runtime.contact(fragment, split.enemy_by_id(fragment.target_id), fragment.origin)
	_check(split.effects.is_empty() and _raw_source(split, &"frost_fragment") > 0 and split.manual_characters == manual, "actual paid fragment contact has no recursive split or artificial manual income")
	var assisted := _session(&"frost", ["F003", "R017"])
	_cast_word(assisted, "abcde")
	_cast_word(assisted, "abcde")
	_contact_word(assisted, "abcde", 0, true)
	_check(assisted.effects.is_empty(), "assisted naturally empowered spear cannot split")
	var solo := _session(&"frost", ["F003"])
	solo.enemies[1].hp_q = 0
	_cast_word(solo, "abcde")
	_cast_word(solo, "abcde")
	_contact_word(solo, "abcde")
	_check(solo.effects.is_empty(), "isolated empowered ice spear creates no empty fragments")


func _counter_fields_and_chain() -> void:
	for pair in [[&"frost", &"F017", &"cold_field", &"cold"], [&"flame", &"A017", &"fire_field", &"burn"]]:
		var session := _session(pair[0], [str(pair[1]), str(pair[1])])
		_perfect_counter(session)
		var field := session.runtime.fields[-1]
		_check(field.effect.kind == pair[2] and field.center == session.enemies[0].position and is_equal_approx(field.radius, _n(session, pair[1], &"radius")) and is_equal_approx(field.expires_at - session.runtime.clock, _n(session, pair[1], &"duration")), "perfect counter creates stacked %s at real contact" % pair[2])
		var before: int = session.enemies[0].get(pair[3])
		var count := session.runtime.fields.size()
		session._counter_contact(session.enemies[0])
		_check(session.runtime.fields.size() == count and session.enemies[0].get(pair[3]) == before, "same enemy attack cannot duplicate counter field or on-hit status")
		session.runtime.advance(0.5)
		_check(session.enemies[0].get(pair[3]) > (before if pair[3] == &"cold" else before - 15), "counter field accumulates actual %s alongside its native decay" % pair[3])
		session.runtime.advance(4.0)
		_check(session.runtime.fields.is_empty(), "counter field expires without permanent status source")
	var chain := _session(&"storm", ["T016", "T016"])
	chain.enemies[0].position = chain.player_position + Vector2(0, -60) / BattleSession.ARENA_SIZE
	chain.enemies[1].position = chain.enemies[0].position + Vector2(80, 0) / BattleSession.ARENA_SIZE
	_add_target(chain, Vector2(160, 0))
	_perfect_counter(chain)
	var amount := roundi(_n(chain, &"T016", &"damage") * Q * chain.runtime.damage_multiplier())
	_check(chain.enemies[0].shock == 32 and _raw_source(chain, &"storm_chain") == amount + int(amount * 0.76), "perfect lightning counter keeps capped shock and pays two diminishing derived hops")
	var damage := _raw_source(chain, &"storm_chain")
	chain._counter_contact(chain.enemies[0])
	_check(_raw_source(chain, &"storm_chain") == damage and chain.manual_characters == 0, "same perfect counter cannot repeat chain or generate manual input")
	var solo := _session(&"storm", ["T016"])
	solo.enemies[1].hp_q = 0
	_perfect_counter(solo)
	_check(solo.enemies[0].shock == 16 and _raw_source(solo, &"storm_chain") == 0, "isolated lightning counter keeps only its original added shock")


func _fire_field_conversion() -> void:
	var conversion := _session(&"flame", ["A006", "A006"])
	conversion.enemies[1].position = conversion.enemies[0].position + Vector2(80, 0) / BattleSession.ARENA_SIZE
	conversion.runtime._region(conversion.enemies[0].position, 100.0, 3.0, &"fire_field")
	var old := conversion.runtime.fields[-1]
	var primary := _contact_word(conversion, "abcde")
	var amount := roundi(primary.base_power_q * _n(conversion, &"A006", &"damage_pct") / 100.0) * 2
	_check(not conversion.runtime.fields.has(old) and _raw_source(conversion, &"A006") == amount, "manual fire contact exchanges containing live field for stacked area damage")
	_contact_word(conversion, "abcde")
	_check(_raw_source(conversion, &"A006") == amount, "consumed field cannot convert twice")
	_contact_word(conversion, "abcde")
	_check(_raw_source(conversion, &"A006") == amount and conversion.runtime.fields.size() == 1, "new empowered contact field cannot be consumed by its own creating hit")
	var assisted := _session(&"flame", ["A006", "R017"])
	assisted.runtime._region(assisted.enemies[0].position, 100.0, 3.0, &"fire_field")
	_contact_word(assisted, "abcde", 0, true)
	_check(assisted.runtime.fields.size() == 1 and _raw_source(assisted, &"A006") == 0, "assisted fire contact preserves available field")
	var expired := _session(&"flame", ["A006"])
	expired.runtime._region(expired.enemies[0].position, 100.0, 0.0, &"fire_field")
	_contact_word(expired, "abcde")
	_check(_raw_source(expired, &"A006") == 0, "expired fire field cannot pay conversion")
	var derived := _session(&"flame", ["A006", "G016"])
	_cast_word(derived, "abcde")
	_cast_word(derived, "abcde", 1)
	derived.runtime._region(derived.enemies[0].position, 100.0, 3.0, &"fire_field")
	var echo := _projectiles(derived, &"echo")[0]
	derived.runtime.contact(echo, derived.enemies[0], echo.origin)
	_check(derived.runtime.fields.size() == 1 and _raw_source(derived, &"A006") == 0, "paid derived echo cannot consume a fire field")


func _chain_return() -> void:
	var chain := _session(&"storm", ["T004", "T004"])
	var primary := _cast_word(chain, "abcde")
	_check(_raw_source(chain, &"storm_chain") == 0, "returning chain waits for primary chain ending")
	chain._advance_effects(0.1)
	var amount := roundi(primary.base_power_q * _n(chain, &"T004", &"damage_pct") / 100.0)
	_check(_raw_source(chain, &"storm_chain") == amount, "finished manual lightning chain returns stacked base-power hit to surviving first enemy")
	chain._advance_effects(1.0)
	_check(_raw_source(chain, &"storm_chain") == amount and chain.effects.is_empty(), "derived returning chain does not recurse")
	var lost := _session(&"storm", ["T004"])
	primary = _cast_word(lost, "abcde")
	lost.runtime._deal(lost.enemies[1], lost.enemies[1].hp_q, &"fixture_other_attack", lost.enemies[1].position, 1)
	lost._advance_effects(0.1)
	_check(_raw_source(lost, &"storm_chain") == roundi(primary.base_power_q * _n(lost, &"T004", &"damage_pct") / 100.0), "missing planned successor still settles return at first surviving target")
	var dead := _session(&"storm", ["T004"])
	_cast_word(dead, "abcde")
	dead.runtime._deal(dead.enemies[0], dead.enemies[0].hp_q, &"fixture_other_attack", dead.enemies[0].position, 1)
	dead._advance_effects(0.1)
	_check(_raw_source(dead, &"storm_chain") == 0, "dead first enemy cancels returning hit without retargeting")
	var waiting := _session(&"storm", ["T004"])
	_cast_word(waiting, "abcde")
	waiting._advance_effects(0.079)
	waiting._advance_effects(0.002)
	_check(waiting.effects.size() == 1 and waiting.effects[0].kind == &"storm_chain" and waiting.effects[0].delay > 0.0, "chain ending schedules a finite delayed return")
	var return_hit := waiting.effects[0]
	waiting.runtime._deal(waiting.enemies[0], waiting.enemies[0].hp_q, &"fixture_other_attack", waiting.enemies[0].position, 1)
	var other_hp := waiting.enemies[1].hp_q
	waiting._advance_effects(0.1)
	_check(_raw_source(waiting, &"storm_chain") == 0 and waiting.enemies[1].hp_q == other_hp and return_hit.lot.amount_q == 0, "first enemy dying during return delay cancels paid return without changing target")
	var redirected := _session(&"storm", ["T004"])
	redirected.typing.upsert_target(redirected.enemies[0].id, "abcde")
	redirected.typing.select_target(redirected.enemies[0].id)
	for character in "abcde": redirected.typing.feed(character)
	redirected.runtime._deal(redirected.enemies[0], redirected.enemies[0].hp_q, &"fixture_other_attack", redirected.enemies[0].position, 1)
	redirected.step(0.0)
	redirected._advance_effects(0.1)
	_check(_raw_source(redirected, &"storm_chain") > 0, "return anchor follows first actual contact after selected target dies before paid dispatch")
	var assisted := _session(&"storm", ["T004", "R017"])
	_cast_word(assisted, "abcde", 0, true)
	assisted._advance_effects(0.1)
	_check(_raw_source(assisted, &"storm_chain") == 0, "assisted lightning chain cannot earn return hit")


func _long_word_cranes() -> void:
	var long := _session(&"spirit", ["P007", "R017"])
	_cast_word(long, "abcdefg")
	var crane := long.runtime.fields[-1]
	_check(crane.effect.kind == &"paper_crane" and crane.center == long.enemies[0].position and is_equal_approx(crane.radius, _n(long, &"P007", &"radius")) and is_equal_approx(crane.expires_at - long.runtime.clock, _n(long, &"P007", &"duration")) and long.manual_characters == 7, "manual long word creates a real finite target crane without extra input")
	_cast_word(long, "abcdefg", 0, true)
	_check(long.runtime.fields.size() == 1, "assisted long word cannot create crane")
	var wide := _session(&"spirit", ["P007", "P012"])
	_cast_word(wide, "abcdefg")
	_check(is_equal_approx(wide.runtime.fields[-1].radius, _n(wide, &"P007", &"radius") + wide.compiled_build.modifier(&"crane_radius")), "long-word crane consumes its shared radius modifier")
	var exchange := _session(&"spirit", ["P007", "P010"])
	_cast_word(exchange, "abcdefg")
	_check(exchange.runtime.fields.size() == 1 and _raw_source(exchange, &"paper_crane") == 0, "new long-word crane cannot pay same-word active exchange")
	var old := exchange.runtime.fields[-1]
	_cast_word(exchange, "abcdefg")
	_check(not exchange.runtime.fields.has(old) and exchange.runtime.fields.size() == 1 and _raw_source(exchange, &"paper_crane") == roundi(_n(exchange, &"P010", &"damage") * Q), "long word exchanges original crane before creating the next one")


func _intercept_cross() -> void:
	var intercept := _session(&"spirit", ["P011", "P011"])
	intercept.runtime.on_dodge(intercept.player_position, intercept.player_position)
	var manual := intercept.manual_characters
	_crane_threat(intercept, intercept.runtime.fields[-1].center)
	_check(intercept.runtime.fields.is_empty() and intercept.threats.is_empty() and intercept.spirits.size() == 1 and is_equal_approx(intercept.spirit_time, RelicParameters.spirit_duration(intercept.compiled_build)), "actual crane interception removes threat and crane, wakes one spirit and refreshes native lifetime")
	for tick in 60: intercept._advance_blades(1.0 / 60.0)
	_check(_raw_source(intercept, &"spirit_cross") == roundi(_n(intercept, &"P011", &"power") * Q * intercept.runtime.damage_multiplier() * 0.18) and intercept.manual_characters == manual, "interception dispatches stacked paid cross contact without fabricated manual input")
	var full := _session(&"spirit", ["P011"])
	for index in full.spirit_capacity(): full._summon_spirit()
	full.runtime.on_dodge(full.player_position, full.player_position)
	_crane_threat(full, full.runtime.fields[-1].center)
	_check(full.spirits.size() == full.spirit_capacity() and full.spirits.all(func(spirit: BattleSpirit) -> bool: return spirit.mode == &"cross"), "interception at full capacity still commands every existing spirit to cross")
	for tick in 60: full._advance_blades(1.0 / 60.0)
	_check(_raw_source(full, &"spirit_cross") > 0, "full-capacity interception produces actual cross damage")
	var exchange := _session(&"spirit", ["P011", "P010"])
	exchange.runtime.on_dodge(exchange.player_position, exchange.player_position)
	_cast_word(exchange, "a")
	_check(exchange.spirits.is_empty() and _raw_source(exchange, &"spirit_cross") == 0, "active P010 crane exchange cannot trigger interception awakening")
	var expired := _session(&"spirit", ["P011"])
	expired.runtime.on_dodge(expired.player_position, expired.player_position)
	expired.runtime.fields[-1].expires_at = expired.runtime.clock
	_crane_threat(expired, expired.runtime.fields[-1].center)
	_check(expired.spirits.is_empty() and _raw_source(expired, &"paper_crane") == 0, "expired crane cannot intercept or wake spirits")
	var empty := _session(&"spirit", ["P011"])
	empty.enemies[0].hp_q = 1
	empty.enemies[1].hp_q = 0
	empty.runtime.on_dodge(empty.player_position, empty.player_position)
	_crane_threat(empty, empty.runtime.fields[-1].center)
	_check(empty.spirits.size() == 1 and empty.spirits[0].mode != &"cross" and _raw_source(empty, &"spirit_cross") == 0, "interception with no surviving attacker wakes spirit without inventing cross target")
	var redirect := _session(&"spirit", ["P011"])
	redirect.enemies[0].hp_q = 1
	redirect.runtime.on_dodge(redirect.player_position, redirect.player_position)
	_crane_threat(redirect, redirect.runtime.fields[-1].center)
	_check(not redirect.enemies[0].alive() and redirect.spirits[0].target_id == redirect.enemies[1].id, "lethal crane reflection sends interception cross toward nearest surviving replacement")
	for tick in 60: redirect._advance_blades(1.0 / 60.0)
	_check(_raw_source(redirect, &"spirit_cross") > 0, "replacement after lethal crane reflection receives real cross damage")


func _perfect_counter(session: BattleSession) -> void:
	session.enemies[0].position = session.player_position + Vector2(0, -60) / BattleSession.ARENA_SIZE
	session.enemies[0].previous_position = session.enemies[0].position
	session.queue_action(&"parry")
	session.step(0.0)
	session._counter_contact(session.enemies[0])


func _crane_threat(session: BattleSession, center: Vector2) -> void:
	var threat := BattleThreat.new()
	threat.source_id = session.enemies[0].id
	threat.attack_id = "crane-fixture:%d" % session.threats.size()
	threat.position = center + Vector2(-50, 0) / BattleSession.ARENA_SIZE
	threat.previous_position = threat.position
	threat.velocity = Vector2(10000, 0)
	threat.damage_q = 5 * Q
	session.threats.append(threat)
	session._advance_threats(0.01)


func _gameplay_balance() -> void:
	var tailored := {
		&"frost": ["R001", "R003", "F006", "G013", "G025", "G027"],
		&"flame": ["R001", "A004", "A009", "G013", "R052", "R039"],
		&"storm": ["R001", "T003", "G013", "G025", "R002", "R039"],
		&"spirit": ["R001", "G013", "G016", "P004", "R005", "R039"],
	}
	var expanded := {
		&"frost": ["R001", "F001", "F003", "F006", "G013", "F014"],
		&"flame": ["R001", "A004", "A006", "A007", "A009", "R039"],
		&"storm": ["R001", "T003", "T004", "T007", "T008", "T014"],
		&"spirit": ["R001", "G025", "P025", "P008", "P009", "R039"],
	}
	var reports: Array[Dictionary] = []
	var summary := "# 遗物机制有限收益采样\n\n"
	summary += "锁定 Godot 4.7.2，四书 × 3/6/9 字符每秒 × 单体/密集/压力 × empty/reference6/gameplay6/expanded6，共144场。正式获取与编译；100%正确的五字词，通过 TypingSession 提交人工回执，并使用真实攻击、命中、状态、死亡和资源账本。\n\n"
	summary += "目标位置固定、移动和AI攻击关闭、自动页段关闭；保留真实击退、碰撞、状态和死亡。单体/压力使用1000000生命耐久目标以避免执行和伤害截断；密集使用六名100生命目标。每场最多30秒，压力每三秒结算8生命伤害，共九次。没有主动闪避、终式、拾取、长短交替、路线、成长或局内奖励；六次机会组合是明确合法预置，不代表随机获取路径，也不覆盖本轮全部新机制。\n\n"
	summary += "压力列记录实际生命损失、最终生命、已吸收护盾及剩余护盾；获得但未使用的护盾不能当作减伤。新增机制伤害来源只验证有限场景内效果兑现，不证明总体平衡、完整难度、连续远征或真人体验。\n\n"
	summary += "组合：empty为空；reference6为R001、R001、R016、R016、R013、R039。gameplay6如下：\n\n"
	for book in tailored: summary += "- %s：%s。\n" % [book, ", ".join(tailored[book])]
	summary += "\nexpanded6如下：\n\n"
	for book in expanded: summary += "- %s：%s。\n" % [book, ", ".join(expanded[book])]
	summary += "\n固定五字词不触发P007长词纸鹤；本采样不含御术或纸鹤拦截，相关机制由专项效果回归证明。\n\n"
	summary += "| 书 | 组合 | 单体30秒伤害 | 密集耗时/击杀 | 压力最终生命 | 压力生命损失 | 护盾吸收/剩余 |\n|---|---|---:|---:|---:|---:|---:|\n"
	for book in BuildCompiler.BOOKS:
		var profiles := {"empty": [], "reference6": ["R001", "R001", "R016", "R016", "R013", "R039"], "gameplay6": tailored[book], "expanded6": expanded[book]}
		for profile in profiles:
			for cps in [3.0, 6.0, 9.0]:
				for scenario in ["solo", "dense", "pressure"]:
					reports.append(_balance_case(book, profiles[profile], profile, cps, scenario))
		for profile in profiles:
			var solo := _sample_report(reports, book, profile, "solo")
			var dense := _sample_report(reports, book, profile, "dense")
			var pressure := _sample_report(reports, book, profile, "pressure")
			summary += "| %s | %s | %.2f | %.2fs / %d | %.2f | %.2f | %.2f / %.2f |\n" % [book, profile, solo.damage, dense.seconds, dense.kills, pressure.hp_final, pressure.hp_lost, pressure.shield_absorbed, pressure.unused_shield]
	var source_totals: Dictionary[String, float] = {}
	for report in reports:
		_check(report.opportunities == (0 if report.profile == "empty" else 6), "finite gameplay sample preserves six legal acquisition opportunities")
		if report.profile not in ["gameplay6", "expanded6"]: continue
		for source in report.sources:
			if source in [&"G013", &"G027", &"F006", &"A004", &"A006", &"T003", &"G025", &"echo", &"frost_fragment", &"storm_chain"]:
				source_totals[str(source)] = source_totals.get(str(source), 0.0) + float(report.sources[source]) / Q
	_check(not source_totals.is_empty(), "finite gameplay samples commit real new mechanism damage")
	summary += "\n六字符每秒对照是本次汇总口径。完整三档输入速度与事件来源保留在JSON。\n\n"
	for book in BuildCompiler.BOOKS:
		var reference := _sample_report(reports, book, "reference6", "solo")
		for profile in ["gameplay6", "expanded6"]:
			var gameplay := _sample_report(reports, book, profile, "solo")
			var ratio: float = gameplay.damage / reference.damage
			summary += "- %s/%s：单体伤害为参考的 %.3f 倍（%+.1f%%）。\n" % [book, profile, ratio, (ratio - 1.0) * 100.0]
	summary += "\n新增机制伤害来源合计（各场相加，仅用于验证兑现）：\n\n"
	for source in source_totals: summary += "- %s：%.2f。\n" % [source, source_totals[source]]
	summary += "\n组合用途与机会分配不同，差异供后续判断，不作为自动调参判据。伤害来源按原生effect.kind归集，例如storm_chain也包含既有链式派生；未作逐项消融归因。\n"
	var output := FileAccess.open("res://.temp/relic-expansion/balance.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"reports": reports, "failures": failures, "checks": checks, "source_totals": source_totals, "scope": "144 finite controlled native combat scenarios; 4 books, 3/6/9 correct cps, solo/dense/pressure, empty/reference6/gameplay6/expanded6. Legal six-opportunity presets. Five-letter words exclude P007 long words. No parry or crane interception; these are covered by targeted effect regressions. No active dodge, ultimate, pickups, length alternation, growth, route or rewards. Stationary targets, AI attacks and room spawning disabled; actual knockback, collision, statuses, death, input receipts, damage and shield settlement retained. Solo/pressure use one 1000000HP target, dense uses six 100HP targets. Thirty seconds maximum, pressure nine native 8HP hits. Damage-source totals use native effect.kind, so storm_chain also includes existing derived chains; not individual ablation. Sources confirm realization only, not full balancing, difficulty, random acquisition paths, continuous expedition or human-play validation."}, "\t"))
	output.close()
	output = FileAccess.open("res://.temp/relic-expansion/balance.md", FileAccess.WRITE)
	output.store_string(summary + "\n验证：%d场，%d条断言，%d失败。\n" % [reports.size(), checks, failures])
	output.close()
	print("GAMEPLAY_BALANCE: cases=", reports.size(), " checks=", checks, " failures=", failures)


func _sample_report(reports: Array[Dictionary], book: StringName, profile: String, scenario: String) -> Dictionary:
	for report in reports:
		if report.book == str(book) and report.profile == profile and report.cps == 6.0 and report.scenario == scenario: return report
	assert(false, "requested six-cps sample must exist")
	return {}


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
	var session: BattleSession = CalibrationBattle.new() if calibration else EffectBattle.new()
	sessions.append(session)
	session.event_committed.connect(func(event: Dictionary) -> void:
		if event.kind == &"impact": (session as EffectBattle).impacts.append(event))
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


func _cast_word(session: BattleSession, word: String, target_index: int = 0, assisted: bool = false) -> BattleEffect:
	var enemy := session.enemies[target_index]
	session.typing.upsert_target(enemy.id, word)
	session.typing.select_target(enemy.id)
	if assisted:
		# An acquired R017 owns the assist operation; stage one already earned token.
		session.runtime._assist_tokens = 1
		session.typing.feed(word[0])
		session.typing.complete_assisted()
	else:
		for character in word: session.typing.feed(character)
	session.step(0.0)
	var effect := (session as EffectBattle).latest_primary
	assert(effect != null, "real typed word must produce paid primary")
	return effect


func _contact_word(session: BattleSession, word: String, target_index: int = 0, assisted: bool = false) -> BattleEffect:
	var effect := _cast_word(session, word, target_index, assisted)
	if session.book_id in [&"frost", &"flame"]:
		session.runtime.contact(effect, session.enemies[target_index], effect.origin)
	return effect


func _n(session: BattleSession, id: StringName, key: StringName) -> float:
	return session.compiled_build.relic_number(id, key)


func _raw_source(session: BattleSession, source: StringName) -> int:
	var total := 0
	for event in (session as EffectBattle).impacts:
		if event.source == source: total += int(event.raw_q)
	return total


func _projectiles(session: BattleSession, kind: StringName) -> Array[BattleEffect]:
	var found: Array[BattleEffect] = []
	for projectile in session.projectiles:
		if projectile.effect.kind == kind: found.append(projectile.effect)
	return found


func _add_target(session: BattleSession, offset: Vector2) -> void:
	var enemy := BattleEnemy.new()
	enemy.id = StringName("effect-target-%d" % session.enemies.size())
	enemy.word = "abcde"
	enemy.position = session.enemies[0].position + offset / BattleSession.ARENA_SIZE
	enemy.previous_position = enemy.position
	enemy.max_hp_q = 10000 * Q
	enemy.hp_q = enemy.max_hp_q
	enemy.attack_clock = 1000.0
	enemy.attack_interval = 1000.0
	session.enemies.append(enemy)
	session._enemies_by_id[enemy.id] = enemy
	session._enemy_definitions[enemy.id] = session._enemy_definitions[session.enemies[0].id]


func _next_room(session: BattleSession, relics: Array) -> BattleSession:
	session.runtime.finish(&"fixture")
	var next := _session(session.book_id, relics)
	# This is the production runtime constructor with the carried run state and new
	# room's ledger/entities; transient fields and entity identities stay local.
	next.run_state = session.run_state
	next.run_state.room_serial += 1
	next.ledger.room_id = next.run_state.room_serial
	next.runtime = SpellRuntime.new(next, next.compiled_build, next.run_state)
	next.typing.assisted_authorizer = next.runtime.consume_assist
	return next


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
