extends AttackAction
class_name RangedAttack

@export var ignore_armor: bool = false

func _init():
	name = "Ataque à Distância"
	ap_cost = 3
	target_type = "enemy"
	damage_multiplier = 0.8
	critical_chance = 0.15  # Arqueiros têm mais chance de crítico
	description = "Um ataque preciso à distância"

func calculate_damage(user: Character, target: Character) -> int:
	# Ataque à distância usa agilidade
	var base_damage = user.calculate_ranged_damage()
	return int(base_damage * damage_multiplier)
