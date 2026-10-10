extends RefCounted
## Explicit paid fixtures for geometry / lifecycle tests, never a game fallback.

static var serial := 0


static func effect(session: BattleSession, kind: StringName, target: StringName, amount: int, delay: float, origin: Vector2) -> BattleEffect:
	serial += 1
	var lot := session.ledger.earn("fixture:%s" % serial, &"fixture", session.compiled_build.identity(), SpellLot.Kind.POWER, amount, &"fixture")
	var paid := session.runtime._effect(lot, kind, target, origin, session.compiled_build)
	paid.delay = delay
	# Keep the fixture's two-thirds share in whole fixed-point units.
	@warning_ignore("integer_division")
	paid.primary_share_q = amount * 2 / 3
	return paid


static func queued(session: BattleSession, kind: StringName, target: StringName, amount: int, delay: float, origin: Vector2) -> BattleEffect:
	var paid := effect(session, kind, target, amount, delay, origin)
	session.effects.append(paid)
	return paid


static func hit(session: BattleSession, enemy: BattleEnemy, amount: int, _kind: StringName, origin: Vector2) -> void:
	var paid := effect(session, &"counter", enemy.id, amount, 0.0, origin)
	if BattleSession.enemy_in_combat(enemy): session.runtime.contact(paid, enemy, origin)
