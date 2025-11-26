extends Action
class_name SupportAction

@export var heal_amount: int = 0
@export var buff_attribute: String = ""
@export var buff_value: int = 0
@export var buff_duration: int = 0

@export var heal_effect_frames: SpriteFrames  # 🆕 NOVO: Efeito de cura
@export var buff_effect_frames: SpriteFrames  # 🆕 NOVO: Efeito de buff

func apply_effects(user: Character, target: Character) -> void:
	if heal_amount > 0:
		target.current_hp = min(target.get_max_hp(), target.current_hp + heal_amount)
		healing_applied.emit(user, target, heal_amount)
		print("   💚 Cura", heal_amount, "HP em", target.name)
	
	if buff_attribute != "" and buff_value > 0:
		target.add_buff(buff_attribute, buff_value, buff_duration)
		effect_applied.emit(user, target, buff_attribute, buff_duration)
		print("   📈", target.name, "ganhou +", buff_value, buff_attribute, "por", buff_duration, "turnos")

# 🆕 NOVO: Criar efeitos específicos para suporte
func create_effect_animation(position: Vector2, parent: Node) -> Node:
	if heal_amount > 0 and heal_effect_frames:
		# Efeito de cura
		return create_custom_effect(heal_effect_frames, position, parent, Color.GREEN, Vector2(1, 1), Vector2(0, -30))
	elif buff_attribute != "" and buff_effect_frames:
		# Efeito de buff
		var buff_color = _get_buff_color(buff_attribute)
		return create_custom_effect(buff_effect_frames, position, parent, buff_color, Vector2(1.1, 1.1), Vector2(0, -10))
	else:
		return super.create_effect_animation(position, parent)

func _get_buff_color(attribute: String) -> Color:
	match attribute:
		"strength": return Color.RED
		"constitution": return Color.ORANGE
		"agility": return Color.YELLOW
		"intelligence": return Color.BLUE
		_: return Color.WHITE
