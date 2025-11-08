extends AttackAction
class_name MagicAttack

@export var element: String = "fire"  # "fire", "ice", "lightning"

func _init():
	name = "Ataque Mágico"
	ap_cost = 4
	target_type = "enemy"
	damage_multiplier = 1.2
	description = "Um ataque elemental poderoso"

func calculate_damage(user: Character, target: Character) -> int:
	# Ataque mágico usa inteligência
	var base_damage = user.calculate_magic_damage()
	return int(base_damage * damage_multiplier)

func execute(user: Character, target: Character) -> void:
	print("   🔮 " + get_element_emoji() + " Ataque " + element + "!")
	super.execute(user, target)

func get_element_emoji() -> String:
	match element:
		"fire": return "🔥"
		"ice": return "❄️"
		"lightning": return "⚡"
		_: return "✨"
