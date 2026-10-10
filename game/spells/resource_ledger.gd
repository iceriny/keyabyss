class_name SpellResourceLedger
extends RefCounted
## Annotated integer divisions retain exact int64 resource amounts and occupancy limits.
## A word attempt owns its manual income until a completed cast commits it.

const Q := 1024

var _seen_receipts: Dictionary[String, bool] = {}
var _attempts: Dictionary[String, Dictionary] = {}
var _lots: Dictionary[int, SpellLot] = {}
var _transactions: Dictionary[String, bool] = {}
var _income: Dictionary[String, bool] = {}
var _next_lot: int = 0
var room_id: int = 0
var raw_spent_q: int = 0
var lost_q: int = 0


func accept_manual(receipt: ManualInputReceipt) -> bool:
	if receipt == null or receipt.id.is_empty() or receipt.attempt_id.is_empty() or receipt.position < 1:
		return false
	if _seen_receipts.has(receipt.id):
		return false
	var account: Dictionary = _attempts.get(receipt.attempt_id, {"characters": 0, "power_q": 0, "work_q": 0, "receipts": PackedStringArray(), "positions": PackedInt32Array(), "word": receipt.word})
	if receipt.position != int(account["characters"]) + 1:
		return false
	_seen_receipts[receipt.id] = true
	account["characters"] = int(account["characters"]) + 1
	account["power_q"] = int(account["power_q"]) + Q
	account["work_q"] = int(account["work_q"]) + Q
	var ids: PackedStringArray = account["receipts"]
	ids.append(receipt.id)
	account["receipts"] = ids
	var positions: PackedInt32Array = account["positions"]
	positions.append(receipt.position)
	account["positions"] = positions
	_attempts[receipt.attempt_id] = account
	return true


func claim_word(attempt_id: String, manual_count: int) -> Dictionary:
	var account: Dictionary = _attempts.get(attempt_id, {})
	if manual_count < 1 or account.is_empty() or int(account["characters"]) != manual_count:
		return {}
	_attempts.erase(attempt_id)
	return account.duplicate(true)


func abandon(attempt_id: String) -> void:
	_attempts.erase(attempt_id)


func earn(root: String, source: StringName, snapshot: String, material: SpellLot.Kind, amount: int, owner: StringName, element: DamagePacket.Element = DamagePacket.Element.NEUTRAL) -> SpellLot:
	var key := "%s:%s:%s" % [root, source, material]
	if root.is_empty() or amount < 0 or amount > 1 << 30 or _income.has(key):
		return null
	_income[key] = true
	var lot := SpellLot.new()
	lot.root_id = root
	lot.source_id = source
	lot.snapshot_id = snapshot
	lot.room_id = room_id
	lot.material = material
	lot.amount_q = amount
	lot.owner = owner
	lot.lineage.append({"root": root, "source": source, "snapshot": snapshot, "material": material, "earned_q": amount})
	if material == SpellLot.Kind.POWER:
		lot.packet = DamagePacket.single(amount, element)
	_register(lot)
	return lot


func get_lot(id: int) -> SpellLot:
	return _lots.get(id)


func aggregate(transaction: String, receiver: SpellLot, contributor: SpellLot) -> bool:
	if receiver == null or contributor == null or receiver == contributor or receiver.material != contributor.material or receiver.amount_q + contributor.amount_q > 1 << 30 or not _prepare(transaction, receiver, 0, &"") or not _prepare(transaction, contributor, contributor.amount_q, &""):
		return false
	_transactions[transaction] = true
	receiver.amount_q += contributor.amount_q
	contributor.amount_q = 0
	if receiver.packet != null:
		receiver.packet.add(contributor.packet)
		contributor.packet.take(contributor.packet.total())
	for claim in contributor.claims: receiver.claims[claim] = true
	for entry in contributor.lineage:
		if entry not in receiver.lineage: receiver.lineage.append(entry.duplicate())
	return true


func divert_work(receipt: ManualInputReceipt, amount: int, snapshot: String, channel: StringName = &"letters") -> SpellLot:
	if not _seen_receipts.has(receipt.id) or amount < 0:
		return null
	var account: Dictionary = _attempts.get(receipt.attempt_id, {})
	if account.is_empty() or int(account.work_q) < amount:
		return null
	var lot := earn(receipt.id, channel, snapshot, SpellLot.Kind.OPPORTUNITY, amount, &"input-allocation")
	if lot != null:
		account.work_q -= amount
	return lot


func transfer(transaction: String, lot: SpellLot, amount: int, next_owner: StringName, claim: StringName = &"") -> SpellLot:
	if not _prepare(transaction, lot, amount, claim):
		return null
	_transactions[transaction] = true
	if claim != &"":
		lot.claims[claim] = true
	var child := lot.portion(amount, next_owner)
	_register(child)
	return child


func spend(transaction: String, lot: SpellLot, amount: int, claim: StringName = &"") -> DamagePacket:
	if not _prepare(transaction, lot, amount, claim):
		return null
	_transactions[transaction] = true
	if claim != &"":
		lot.claims[claim] = true
	lot.amount_q -= amount
	if lot.packet != null:
		raw_spent_q += amount
		return lot.packet.take(amount)
	return DamagePacket.single(0)


func convert(transaction: String, lot: SpellLot, amount: int, material: SpellLot.Kind, ratio_q: int, next_owner: StringName) -> SpellLot:
	if not _prepare(transaction, lot, amount, &"") or ratio_q < 0 or ratio_q > 64 * Q:
		return null
	@warning_ignore("integer_division")
	if amount * ratio_q / Q > 1 << 30:
		return null
	_transactions[transaction] = true
	var child := lot.portion(amount, next_owner)
	child.material = material
	@warning_ignore("integer_division")
	child.amount_q = amount * ratio_q / Q
	child.packet = null
	_register(child)
	return child


func pay_and_transfer(transaction: String, fee: SpellLot, cost: int, lot: SpellLot, amount: int, owner: StringName, claim: StringName, capacity: int = -1, occupancy: int = 0) -> SpellLot:
	# Both inputs are prepared before either changes. Failed attempts leave no claims.
	if fee == lot or not _prepare(transaction, fee, cost, &"") or not _prepare(transaction, lot, amount, claim):
		return null
	if capacity >= 0 and occupancy + amount > capacity:
		return null
	_transactions[transaction] = true
	fee.amount_q -= cost
	if fee.packet != null:
		fee.packet.take(cost)
	lot.claims[claim] = true
	var child := lot.portion(amount, owner)
	_register(child)
	return child


func reclaim(transaction: String, lot: SpellLot, ratio_q: int, available_space: int) -> SpellLot:
	@warning_ignore("integer_division")
	if lot == null or lot.material in [SpellLot.Kind.WORK, SpellLot.Kind.OPPORTUNITY] or ratio_q < 0 or ratio_q > Q * 7 / 10:
		return null
	@warning_ignore("integer_division")
	var retained := lot.amount_q * ratio_q / Q
	@warning_ignore("integer_division")
	retained = mini(retained, available_space / maxi(1, SpellLot.SPACE_WEIGHTS[lot.material]))
	if not _prepare(transaction, lot, lot.amount_q, &"recovered"):
		return null
	_transactions[transaction] = true
	lot.claims[&"recovered"] = true
	var child := lot.portion(retained, &"reserve")
	lost_q += lot.amount_q
	if lot.packet != null:
		lot.packet.take(lot.amount_q)
	lot.amount_q = 0
	_register(child)
	return child


func import_reserve(lot: SpellLot) -> SpellLot:
	# Room handoff retains provenance and claims, but never a room entity reference.
	var imported := lot.portion(lot.amount_q, &"reserve")
	imported.room_id = room_id
	_register(imported)
	return imported


func active_lots() -> Array[SpellLot]:
	var active: Array[SpellLot] = []
	for lot in _lots.values():
		if lot.amount_q > 0:
			active.append(lot)
	return active


func _prepare(transaction: String, lot: SpellLot, amount: int, claim: StringName) -> bool:
	return not transaction.is_empty() and not _transactions.has(transaction) and lot != null and _lots.get(lot.id) == lot and lot.room_id == room_id and amount >= 0 and amount <= lot.amount_q and (claim == &"" or not lot.claims.has(claim))


func _register(lot: SpellLot) -> void:
	_next_lot += 1
	lot.id = _next_lot
	_lots[lot.id] = lot
