class_name EnemyScaler
extends RefCounted


static func generate(enemy_definition: Dictionary, stage: int) -> Dictionary:
	var safe_stage := maxi(1, stage)
	var progress := float(safe_stage - 1)
	var base_health := roundi(
		float(enemy_definition.get("base_health", 35.0))
		+ float(enemy_definition.get("health_linear", 5.0)) * progress
		+ float(enemy_definition.get("health_quadratic", 0.12)) * progress * progress
	)
	var base_attack := roundi(
		float(enemy_definition.get("base_attack", 5.0))
		+ float(enemy_definition.get("attack_linear", 0.55)) * progress
		+ float(enemy_definition.get("attack_quadratic", 0.015)) * progress * progress
	)
	var final_health := maxi(1, roundi(
		base_health * float(enemy_definition.get("health_multiplier", 1.0))
	))
	var final_attack := maxi(0, roundi(
		base_attack * float(enemy_definition.get("attack_multiplier", 1.0))
	))
	var attack_cap := int(enemy_definition.get("attack_cap", 0))
	if attack_cap > 0:
		final_attack = mini(final_attack, attack_cap)
	return {
		"id": str(enemy_definition.get("id", "enemy")),
		"stage": safe_stage,
		"base_health": maxi(1, base_health),
		"final_health": final_health,
		"base_attack": maxi(0, base_attack),
		"final_attack": final_attack,
		"enemy_type": str(enemy_definition.get("enemy_type", "normal")),
		"name_key": str(enemy_definition.get("name_key", "battle.enemy_type")),
		"intent_key": str(enemy_definition.get("intent_key", "battle.intent_caption")),
		"description_key": str(enemy_definition.get("description_key", ""))
	}


static func generate_elite(
	enemy_definition: Dictionary,
	stage: int,
	multiplier: float = 1.5
) -> Dictionary:
	var generated := generate(enemy_definition, stage)
	generated["enemy_type"] = "elite"
	generated["final_health"] = maxi(1, roundi(int(generated["final_health"]) * multiplier))
	generated["final_attack"] = maxi(0, roundi(int(generated["final_attack"]) * multiplier))
	return generated
