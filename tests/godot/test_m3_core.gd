extends SceneTree

var checks := 0
var failures := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := BuildCatalog.new()
	check(catalog.definitions.size() == 377, "Catalog contains all 206 talents / roots and 171 relics")
	var selection := BuildSelection.new()
	var compiler := BuildCompiler.new(catalog)
	var baseline := compiler.compile(selection)
	check(baseline.success(), "Neutral baseline compiles")
	selection.book_id = &"flame"
	selection.talents = ["flame", "frost", "storm", "spirit"]
	var other_roots := compiler.compile(selection)
	check(other_roots.success() and other_roots.build.book() == &"flame" and other_roots.build.value(&"cadence") == 3, "Other book roots add materials while preserving the single primary book / cadence")
	check(other_roots.build.has(&"cold") and other_roots.build.has(&"conduct") and other_roots.build.has(&"summon"), "All four native root entries can be selected without starting a second primary")
	selection.book_id = &"frost"
	var changed_primary := compiler.compile(selection)
	check(changed_primary.success() and changed_primary.build.identity() != other_roots.build.identity(), "Identical material providers with a different primary have distinct frozen snapshots")
	selection.talents = ["spirit", "storm", "frost", "flame"]
	check(compiler.compile(selection).build.identity() == changed_primary.build.identity(), "Snapshot identity is independent of content selection order")
	selection.talents = ["T23"]
	selection.assets = {&"R141": 1}
	selection.modes[&"guard-order"] = &"T23"
	var talent_policy := compiler.compile(selection)
	selection.modes[&"guard-order"] = &"R141"
	var asset_policy := compiler.compile(selection)
	check(talent_policy.success() and asset_policy.success() and talent_policy.build.identity() != asset_policy.build.identity(), "Explicit mode provenance remains part of snapshot identity")
	selection.modes.clear()
	selection.talents = ["T50"]
	selection.assets = {&"R003": 1}
	var sources := compiler.compile(selection)
	check(sources.success() and sources.build.sources(&"cold").size() == 3, "Shared cold has three providers and one rule")
	check(sources.build.value(&"cold_efficiency_q") == 256, "Distinct numeric contributions survive deduplication")
	selection.talents = ["T23", "T24"]
	check(not compiler.compile(selection).success(), "Conflicting guard ordering is diagnosed")
	selection.talents = []
	selection.assets = {&"R172": 1}
	check(not compiler.compile(selection).success(), "Permanent acquisition requires allocated permit")
	var ledger := SpellResourceLedger.new()
	ledger.room_id = 1
	var power := ledger.earn("manual", &"frost", "snapshot", SpellLot.Kind.POWER, 13, &"spell", DamagePacket.Element.ICE)
	var work := ledger.earn("manual", &"frost", "snapshot", SpellLot.Kind.WORK, 5, &"work")
	check(ledger.earn("manual", &"frost", "snapshot", SpellLot.Kind.POWER, 13, &"spell") == null, "Income cannot be replayed")
	check(ledger.pay_and_transfer("capacity", work, 3, power, 7, &"shell", &"stored", 6) == null, "Capacity failure rejects the whole operation")
	check(power.amount_q == 13 and work.amount_q == 5 and power.claims.is_empty(), "Failed payment has no side effects")
	var child := ledger.pay_and_transfer("paid", work, 3, power, 7, &"shell", &"stored", 7)
	check(child != null and power.amount_q == 6 and work.amount_q == 2, "Fee and output commit together")
	check(ledger.transfer("paid", power, 1, &"copy") == null, "Transaction replay rejected")
	check(ledger.transfer("duplicate-claim", power, 1, &"shell", &"stored") == null, "Splits preserve claims")
	var resistances: PackedInt64Array = [0, 256, -256, 0, 0]
	var mixed := DamagePacket.single(11, DamagePacket.Element.ICE)
	mixed.add(DamagePacket.single(7, DamagePacket.Element.FIRE))
	var split := mixed.take(9)
	check(split.total() + mixed.total() == 18, "Small mixed splits conserve every integer unit")
	var conversion := DamagePacket.single(16, DamagePacket.Element.ICE)
	check(conversion.refract(resistances) and conversion.total() == 16, "Refraction conserves the paid total")
	check(conversion.components()[DamagePacket.Element.FIRE] == 4, "Refraction changes only the declared quarter")
	var spend := ledger.spend("hit", child, child.amount_q)
	check(child.amount_q == 0 and spend.total() == 7, "Contact consumes raw budget before resistance")
	check(ledger.spend("second-hit", child, 1) == null, "Spent damage cannot be reused")
	ledger.room_id = 2
	check(ledger.spend("old-room", power, 1) == null, "Old room references are rejected")
	var words: Array[VocabularyEntry] = []
	var entry := VocabularyEntry.new()
	entry.word = "stone"
	words.append(entry)
	for book in BuildCompiler.BOOKS:
		var session := BattleSession.new()
		root.add_child(session)
		session.set_physics_process(false)
		session.start_baseline(book, words, "normal", "m3-core", false)
		var enemy := session.enemies[0]
		enemy.combat_locked = true
		enemy.position = Vector2(0.6, 0.5)
		enemy.previous_position = enemy.position
		enemy.hp_q = 1000 * 1024
		enemy.max_hp_q = enemy.hp_q
		session.typing.upsert_target(enemy.id, "stone")
		session.typing.select_target(enemy.id)
		for character in "stone": session.typing.feed(character)
		session.step(1.0 / 60)
		check(session.manual_characters == 5 and session.completed_words == 1, "Manual facts arrive at the native runtime: " + str(book))
		for tick in 120: session.step(1.0 / 60)
		check(enemy.hp_q < enemy.max_hp_q, "Primary reaches real native contact: " + str(book))
		var room := session.finish_room(&"abandon")
		check(room == session.finish_room(&"abandon"), "Room result is delivered once")
		session.queue_free()
	await process_frame
	print("M3 core: %s checks, %s failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
