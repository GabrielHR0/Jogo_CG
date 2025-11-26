# RangedAttack.gd
extends AttackAction
class_name RangedAttack

@export var ignore_armor: bool = false
@export var accuracy: float = 0.9

func _init():
	name = "Ataque à Distância"
	ap_cost = 3
	target_type = "enemy"
	damage_multiplier = 0.8
	critical_chance = 0.15
	formula = "ranged"
	animation_type = "ranged"
	requires_projectile = true
	description = "Um ataque preciso à distância"

func calculate_damage(user: Character, target: Character) -> int:
	# Verifica se acerta o alvo
	var hit_chance = calculate_hit_chance(user, target)
	if randf() > hit_chance:
		print("   🎯 " + user.name + " errou o alvo!")
		return 0
	
	var base_damage = user.calculate_ranged_damage()
	return int(base_damage * damage_multiplier)

func calculate_hit_chance(user: Character, target: Character) -> float:
	var user_agility = user.get_attribute("agility")
	var target_agility = target.get_attribute("agility")
	var calculated_accuracy = accuracy + (user_agility - target_agility) * 0.02
	return clamp(calculated_accuracy, 0.1, 0.95)
