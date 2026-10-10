class_name SpellLot
extends RefCounted
## A single owned remainder. Splitting inherits its full claim history.

enum Kind { POWER, WORK, COLD, HEAT, CHARGE, OPPORTUNITY }
const SPACE_WEIGHTS := [16, 0, 1, 64, 16, 0]
var id: int
var root_id: String
var source_id: StringName
var room_id: int
var snapshot_id: String
var owner: StringName
var material: Kind
var amount_q: int
var packet: DamagePacket
var claims: Dictionary[StringName, bool] = {}
var lineage: Array[Dictionary] = []


func portion(amount: int, next_owner: StringName) -> SpellLot:
	var child := SpellLot.new()
	child.root_id = root_id
	child.source_id = source_id
	child.room_id = room_id
	child.snapshot_id = snapshot_id
	child.owner = next_owner
	child.material = material
	child.amount_q = amount
	child.claims = claims.duplicate()
	child.lineage = lineage.duplicate(true)
	if packet != null:
		child.packet = packet.take(amount)
	amount_q -= amount
	return child
