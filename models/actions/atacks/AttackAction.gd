extends Action
class_name AttackAction

@export var damage_multiplier: float = 1.0
@export var critical_chance: float = 0.1
@export var critical_multiplier: float = 1.5
@export var formula: String = "melee" # "melee", "magic", "ranged"

func apply_effects(user: Character, target: Character) -> void:
	var damage = calculate_damage(user, target)
	var is_critical = roll_critical()
	if is_critical:
		damage = int(damage * critical_multiplier)
		print("   💥 CRÍTICO!")
	target.take_damage(damage)
	print("   💥 Dano:", damage, "em", target.name)
	print("   ❤️", target.name, "HP:", target.current_hp, "/", target.get_max_hp())

func calculate_damage(user: Character, target: Character) -> int:
	var base := 0
	match formula:
		"magic":
			base = user.calculate_magic_damage()
		"ranged":
			base = user.calculate_ranged_damage()
		_:
			base = user.calculate_melee_damage()
	return int(base * damage_multiplier)

func roll_critical() -> bool:
	return randf() < critical_chance
