extends AttackAction
class_name SpecialAttack

@export var buff_attribute: String = ""
@export var buff_value: int = 0
@export var buff_duration: int = 0

func _init():
	name = "Ataque Especial"
	ap_cost = 5
	target_type = "enemy"
	damage_multiplier = 0.7
	critical_chance = 0.2
	description = "Um ataque especial que pode buffar aliados"

func apply_effects(user: Character, target: Character) -> void:
	if buff_attribute != "" and buff_value > 0:
		# Aplica buff no usuário
		user.add_buff(buff_attribute, buff_value, buff_duration)
		print("   📈 " + user.name + " ganhou +" + str(buff_value) + " " + buff_attribute + " por " + str(buff_duration) + " turnos")
