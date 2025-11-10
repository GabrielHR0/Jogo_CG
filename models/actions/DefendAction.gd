extends Action
class_name DefendAction

@export var defense_buff: int = 5
@export var duration: int = 1

func _init():
	name = "Defender"
	ap_cost = 1
	target_type = "self"
	description = "Assume posição defensiva"

func execute(user: Character, target: Character) -> void:
	super.execute(user, target)
	user.add_buff("constitution", defense_buff, duration)
	print("   🛡️", user.name, "assume posição defensiva")
	print("   📈 +", defense_buff, "constituição por", duration, "turnos")
