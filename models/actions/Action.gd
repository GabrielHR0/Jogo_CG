extends Resource
class_name Action

@export var name: String = ""
@export var icon: Texture2D = null
@export var ap_cost: int = 0
@export var target_type: String = "enemy"  # "enemy", "ally", "self"
@export var description: String = ""

func execute(user: Character, target: Character) -> void:
	print("🎯 " + user.name + " usa '" + name + "'")
	user.spend_ap(ap_cost)
	apply_effects(user, target)

func apply_effects(user: Character, target: Character) -> void:
	match name:
		"Pular Turno":
			print("   ⏭️ " + user.name + " pula o turno")
		"Defender":
			user.start_defending()
			print("   🛡️ " + user.name + " assume postura defensiva")
		"Usar Item":
			print("   📦 " + user.name + " tenta usar um item")
			# Aqui você implementaria a lógica de itens depois
		_:
			print("   💫 Efeito padrão da ação")
