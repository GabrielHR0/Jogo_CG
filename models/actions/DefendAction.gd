extends Action
class_name DefendAction

@export var defense_effect_frames: SpriteFrames  # 🆕 NOVO: Efeito de escudo

func _init():
	name = "Defender"
	ap_cost = 1
	target_type = "self"
	description = "Assume posição defensiva até seu próximo turno"
	animation_type = "special"  # 🆕 NOVO

func execute(user: Character, target: Character) -> void:
	super.execute(user, target)
	
	ap_cost = user.calculate_defend_ap_cost()
	
	if not user.has_ap_for_action(self):
		print("   ❌", user.name, "não tem AP suficiente para defender")
		return
	
	user.spend_ap(ap_cost)
	user.start_defending()
	effect_applied.emit(user, user, "defesa", 1)
	
	print("   🛡️", user.name, "assume posição defensiva")
	print("   💰 Custo: ", ap_cost, " AP (60% do AP máximo)")
	print("   🎯 Chance de esquiva: 15%")
	print("   ⏱️ Duração: Até seu próximo turno")

# 🆕 NOVO: Sobrescrever para adicionar efeito visual específico
func create_effect_animation(position: Vector2, parent: Node) -> Node:
	if defense_effect_frames:
		# Usar efeito customizado de defesa
		return create_custom_effect(defense_effect_frames, position, parent, Color.CYAN, Vector2(1.2, 1.2), Vector2(0, -20))
	else:
		# Fallback para o efeito padrão
		return super.create_effect_animation(position, parent)
