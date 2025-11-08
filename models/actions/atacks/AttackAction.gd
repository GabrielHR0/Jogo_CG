extends Action
class_name AttackAction

@export var damage_multiplier: float = 1.0
@export var critical_chance: float = 0.1
@export var critical_multiplier: float = 1.5

func apply_effects(user: Character, target: Character) -> void:
	var damage = calculate_damage(user, target)
	var is_critical = roll_critical()
	
	if is_critical:
		damage = int(damage * critical_multiplier)
		print("   💥 CRÍTICO! ")
	
	target.take_damage(damage)
	print("   💥 Causa " + str(damage) + " de dano em " + target.name)
	print("   ❤️  " + target.name + ": " + str(target.current_hp) + "/" + str(target.get_max_hp()) + " HP")

# SOBRESCREVA para definir como calcular dano
func calculate_damage(user: Character, target: Character) -> int:
	return 0

func roll_critical() -> bool:
	return randf() < critical_chance
