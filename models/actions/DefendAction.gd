extends Action
class_name DefendAction

func _init():
	name = "Defender"
	ap_cost = 1  # Será atualizado pelo Character
	target_type = "self"
	description = "Assume posição defensiva até seu próximo turno"

func execute(user: Character, target: Character) -> void:
	super.execute(user, target)
	
	# Atualiza o custo de AP baseado no AP máximo atual do usuário
	ap_cost = user.calculate_defend_ap_cost()
	
	# Verifica se tem AP suficiente
	if not user.has_ap_for_action(self):
		print("   ❌", user.name, "não tem AP suficiente para defender")
		return
	
	user.spend_ap(ap_cost)
	user.start_defending()
	
	print("   🛡️", user.name, "assume posição defensiva")
	print("   💰 Custo: ", ap_cost, " AP (60% do AP máximo)")
	print("   🎯 Chance de esquiva: 15%")
	print("   ⏱️ Duração: Até seu próximo turno")
