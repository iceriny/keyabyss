class_name RelicParameters
extends RefCounted
## Integer percentages, milliseconds, arena pixels and point/count values.
## All added relic bonuses share these limits; absent parameters are neutral.
const CAPS := {
	&"power_pct": 60,
	&"perfect_pct": 50,
	&"short_pct": 45,
	&"long_pct": 45,
	&"empowered_pct": 50,
	&"manual_pct": 35,
	&"imperfect_pct": 35,
	&"fresh_pct": 40,
	&"wounded_pct": 40,
	&"boss_pct": 30,
	&"copy_pct": 40,
	&"combo_pct": 2,
	&"low_health_pct": 35,
	&"shielded_pct": 30,
	&"mixed_pct": 30,
	&"max_hp_flat": 40,
	&"defense_pct": 25,
	&"shield_cap": 30,
	&"word_heal": 4,
	&"word_shield": 8,
	&"parry_shield": 6,
	&"dodge_resonance": 3,
	&"resonance_pct": 30,
	&"pickup_heal": 6,
	&"kill_shield": 3,
	&"kill_resonance": 2,
	&"parry_resonance": 3,
	&"ultimate_shield": 20,
	&"ultimate_ms": 2000,
	&"burn_hit": 20,
	&"shock_hit": 16,
	&"mark_hit": 16,
	&"cross_mark_hit": 16,
	&"cold_hit": 16,
	&"cold_pct": 40,
	&"ice_direct_pct": 40,
	&"frost_pierce": 2,
	&"freeze_ms": 450,
	&"cold_decay_pct": 30,
	&"frozen_pct": 45,
	&"shatter_pct": 45,
	&"shatter_radius": 40,
	&"mist_ms": 1500,
	&"mist_radius": 35,
	&"frost_domain_pct": 40,
	&"freeze_shield": 3,
	&"dodge_cold": 30,
	&"parry_cold": 40,
	&"freeze_resonance": 2,
	&"ultimate_cold": 10,
	&"empowered_cold": 15,
	&"frost_flight_pct": 25,
	&"cold_chain_pct": 30,
	&"cold_burn_pct": 30,
	&"cold_spirit_pct": 30,
	&"shock_pct": 40,
	&"storm_direct_pct": 35,
	&"chain_tail_pct": 35,
	&"chain_range": 80,
	&"charge_pct": 40,
	&"storm_burst_pct": 40,
	&"storm_burst_radius": 35,
	&"dodge_storm_pct": 35,
	&"dodge_shock": 18,
	&"storm_domain_shock": 12,
	&"charged_shield": 2,
	&"parry_shock": 32,
	&"shock_decay_pct": 30,
	&"shock_grace_ms": 1000,
	&"shocked_pct": 30,
	&"overload_pct": 40,
	&"overload_radius": 35,
	&"burn_chain_pct": 30,
	&"spirit_shock_hit": 8,
	&"chain_hits": 1,
	&"spirit_pct": 40,
	&"spirit_ms": 1600,
	&"mark_pct": 40,
	&"mark_grace_ms": 1000,
	&"mark_decay_pct": 30,
	&"cross_pct": 40,
	&"spirit_capacity": 2,
	&"spirit_speed_pct": 25,
	&"spirit_cooldown_pct": 25,
	&"crane_pct": 40,
	&"crane_ms": 2000,
	&"crane_radius": 12,
	&"mark_shield": 3,
	&"mark_kill_resonance": 3,
	&"parry_mark": 30,
	&"ultimate_spirit_pct": 35,
	&"full_spirit_pct": 30,
	&"mark_fresh_points": 16,
	&"shielded_spirit_pct": 30,
	&"burn_spirit_pct": 30,
	&"flame_direct_pct": 35,
	&"burn_pct": 40,
	&"burn_points_pct": 35,
	&"burn_weak_pct": 30,
	&"fire_field_rate_pct": 35,
	&"fire_field_ms": 1200,
	&"fire_field_radius": 30,
	&"dodge_flame_ms": 1500,
	&"dodge_flame_radius": 25,
	&"burn_spread_radius": 40,
	&"burn_spread_targets": 1,
	&"flame_wave_pct": 40,
	&"flame_domain_pct": 40,
	&"burn_kill_resonance": 3,
	&"burn_kill_shield": 3,
	&"parry_burn": 30,
	&"burning_pct": 30,
}


static func ratio(build: CompiledBuild, key: StringName) -> float:
	return 1.0 + build.modifier(key) / 100.0


static func seconds(build: CompiledBuild, key: StringName) -> float:
	return build.modifier(key) / 1000.0


static func spirit_duration(build: CompiledBuild) -> float:
	return 8.0 + build.relic_number(&"R005", &"duration") + build.relic_number(&"R035", &"duration") + seconds(build, &"spirit_ms")


static func parry_cooldown(build: CompiledBuild) -> float:
	return 0.7 * (1.0 - build.relic_number(&"R058", &"cooldown_pct") / 100.0)


static func freeze_duration(build: CompiledBuild, boss: bool = false) -> float:
	var duration := 1.5 if boss else 2.0 + build.relic_number(&"R003", &"freeze_ms") / 1000.0
	return duration + seconds(build, &"freeze_ms") * (0.5 if boss else 1.0)


static func shield_capacity(build: CompiledBuild) -> int:
	return 60 + build.modifier(&"shield_cap")


static func ultimate_duration(build: CompiledBuild) -> float:
	var duration: float = BattleUltimate.DURATIONS[build.book()] + build.value(&"ultimate_duration_ms") / 1000.0
	if build.book() == &"storm" and build.asset_stacks(&"R047") > 0: duration = build.relic_number(&"R047", &"duration")
	if build.book() == &"flame" and build.asset_stacks(&"R056") > 0: duration = build.relic_number(&"R056", &"duration")
	return duration + seconds(build, &"ultimate_ms")
