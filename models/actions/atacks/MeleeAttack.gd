# MeleeAttack.gd
extends AttackAction
class_name MeleeAttack

func _init():
	name = "Ataque Corpo-a-Corpo"
	ap_cost = 2
	target_type = "enemy"
	damage_multiplier = 1.0
	formula = "melee"
	animation_type = "melee"
	description = "Um ataque físico básico com a arma"

func calculate_damage(user: Character, target: Character) -> int:
	var base_damage = user.calculate_melee_damage()
	return int(base_damage * damage_multiplier)
