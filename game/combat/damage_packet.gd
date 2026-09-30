class_name DamagePacket
extends RefCounted
## Damage is a composition, never a source of cold, heat or charge.

enum Element { NEUTRAL, ICE, FIRE, LIGHTNING, PAPER }
const Q := 1024
const ELEMENT_NAMES := ["中性", "冰", "火", "雷", "纸"]
var _parts: PackedInt64Array = [0, 0, 0, 0, 0]


static func single(amount: int, element: Element = Element.NEUTRAL) -> DamagePacket:
	assert(amount >= 0 and amount <= 1 << 30)
	var packet := DamagePacket.new()
	packet._parts[element] = amount
	return packet


func total() -> int:
	var amount := 0
	for part in _parts:
		amount += part
	return amount


func components() -> PackedInt64Array:
	return _parts.duplicate()


func copy() -> DamagePacket:
	var packet := DamagePacket.new()
	packet._parts = _parts.duplicate()
	return packet


func take(amount: int) -> DamagePacket:
	assert(amount >= 0 and amount <= total())
	var packet := DamagePacket.new()
	var size := total()
	if size == 0:
		return packet
	var remainder := amount
	var fractions: Array[Dictionary] = []
	for element in _parts.size():
		# Both factors are bounded to 2^30; the product fits in int64.
		var product := _parts[element] * amount
		packet._parts[element] = product / size
		remainder -= packet._parts[element]
		fractions.append({"element": element, "remainder": product % size})
	fractions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.remainder > b.remainder if a.remainder != b.remainder else a.element < b.element)
	for index in remainder:
		packet._parts[fractions[index].element] += 1
	for element in _parts.size():
		_parts[element] -= packet._parts[element]
	return packet


func add(packet: DamagePacket) -> void:
	for element in _parts.size():
		_parts[element] += packet._parts[element]
	assert(total() <= 1 << 30)


func actual(resistances: PackedInt64Array) -> int:
	var amount := 0
	for element in _parts.size():
		amount += _parts[element] * (Q - resistances[element]) / Q
	return amount


func refract(resistances: PackedInt64Array, ratio_q: int = Q / 4) -> bool:
	var best := Element.ICE
	for element in range(Element.FIRE, Element.PAPER + 1):
		if resistances[element] < resistances[best]:
			best = element
	var converted := 0
	for element in range(Element.ICE, Element.PAPER + 1):
		if resistances[element] > resistances[best]:
			var share: int = _parts[element] * ratio_q / Q
			_parts[element] -= share
			converted += share
	_parts[best] += converted
	return converted > 0
