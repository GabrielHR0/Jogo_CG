extends Action
class_name SupportAction

@export var heal_amount: int = 0
@export var buff_attribute: String = ""
@export var buff_value: int = 0
@export var buff_duration: int = 0

func apply_effects(user: Character, target: Character) -> void:
	if heal_amount > 0:
		target.current_hp = min(target.get_max_hp(), target.current_hp + heal_amount)
		print("   💚 Cura", heal_amount, "HP em", target.name)
	
	if buff_attribute != "" and buff_value > 0:
		target.add_buff(buff_attribute, buff_value, buff_duration)
		print("   📈", target.name, "ganhou +", buff_value, buff_attribute, "por", buff_duration, "turnos")
