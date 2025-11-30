extends AttackAction
class_name MagicAttack

@export var element: String = "fire"

func _init():
	name = "Ataque Mágico"
	ap_cost = 4
	target_type = "enemy"
	damage_multiplier = 1.2
	formula = "magic"
	animation_type = "magic"
	requires_projectile = true
	description = "Um ataque elemental poderoso"

func calculate_damage(user: Character, target: Character) -> int:
	var base_damage = user.calculate_magic_damage()
	return int(base_damage * damage_multiplier)

func get_element_emoji() -> String:
	match element:
		"fire": return "🔥"
		"ice": return "❄️"
		"lightning": return "⚡"
		_: return "✨"

func create_effect_animation(position: Vector2, parent: Node) -> Node:
	var element_color = _get_element_color()
	var element_scale = _get_element_scale()
	return super.create_effect_animation(position, parent)

func _get_element_color() -> Color:
	match element:
		"fire": return Color.ORANGE_RED
		"ice": return Color.CYAN
		"lightning": return Color.YELLOW
		_: return Color.PURPLE

func _get_element_scale() -> Vector2:
	match element:
		"fire": return Vector2(1.3, 1.3)
		"ice": return Vector2(1.1, 1.1)
		"lightning": return Vector2(1.2, 0.8)
		_: return Vector2(1, 1)
