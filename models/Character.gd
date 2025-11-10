extends Resource
class_name Character

@export var name: String = ""
@export var icon: Texture2D = null
@export var texture: Texture2D = null

@export var strength: int = 5
@export var constitution: int = 5
@export var agility: int = 5
@export var intelligence: int = 5
@export var position: String = "front"
@export var role: int = 0
@export var is_locked: bool = false

@export var current_hp: int = 0
@export var current_ap: int = 0

@export var melee_damage: int = 0
@export var magic_damage: int = 0
@export var ranged_damage: int = 0
@export var defense: int = 0

@export var basic_actions: Array[Action] = []
@export var combat_actions: Array[Action] = []

var buffs := {}
var is_defending: bool = false

func _init():
	calculate_stats()
	_setup_basic_actions()

func _setup_basic_actions():
	basic_actions.clear()
	var skip_turn = Action.new()
	skip_turn.name = "Pular Turno"
	skip_turn.ap_cost = 0
	skip_turn.target_type = "self"
	skip_turn.description = "Não faz nada neste turno"
	basic_actions.append(skip_turn)
	
	var defend = Action.new()
	defend.name = "Defender"
	defend.ap_cost = 1
	defend.target_type = "self"
	defend.description = "Assume postura defensiva"
	basic_actions.append(defend)
	
	var use_item = Action.new()
	use_item.name = "Usar Item"
	use_item.ap_cost = 2
	use_item.target_type = "ally"
	use_item.description = "Usa um item do inventário"
	basic_actions.append(use_item)

func calculate_stats():
	melee_damage = calculate_melee_damage()
	magic_damage = calculate_magic_damage()
	ranged_damage = calculate_ranged_damage()
	defense = calculate_defense()
	
	if current_hp == 0 or current_hp > get_max_hp():
		current_hp = get_max_hp()
	if current_ap == 0 or current_ap > get_max_ap():
		current_ap = get_max_ap()

func get_max_hp() -> int:
	return max(0, 30 + get_attribute("constitution") * 10)

func get_max_ap() -> int:
	return max(0, 6 + get_attribute("agility") + int(get_attribute("intelligence") / 2))

func calculate_defense() -> int:
	return max(0, 2 + int(get_attribute("constitution") * 0.8) + int(get_attribute("strength") * 0.3))

func full_heal():
	current_hp = get_max_hp()
	current_ap = get_max_ap()
	print("💚", name, "curado:", current_hp, "/", get_max_hp(), "HP")

func get_defense() -> int:
	var base_defense = defense
	if is_defending:
		base_defense += int(get_attribute("constitution") * 0.5)
	return base_defense

func calculate_ap_recovery() -> int:
	return max(0, 3 + int(get_attribute("agility") / 2) + int(get_attribute("intelligence") / 3))

func restore_ap():
	var recovered = calculate_ap_recovery()
	current_ap = min(get_max_ap(), current_ap + recovered)
	return recovered

func take_damage(dmg: int):
	var defense_reduction = int(get_defense() * 0.5)
	var final_damage = max(0, dmg - defense_reduction)
	current_hp = max(0, current_hp - final_damage)
	if defense_reduction > 0:
		print("   🛡️ Defesa reduziu", defense_reduction, "de dano")
		print("   💥 Dano final:", final_damage, "(original:", dmg, ")")

func spend_ap(cost: int):
	current_ap = max(0, current_ap - max(0, cost))

func is_alive() -> bool:
	return current_hp > 0

func calculate_melee_damage() -> int:
	return max(0, 3 + int(get_attribute("strength") * 1.5))

func calculate_magic_damage() -> int:
	return max(0, 2 + get_attribute("intelligence") * 2)

func calculate_ranged_damage() -> int:
	return max(0, 2 + int(get_attribute("agility") * 1.2) + int(get_attribute("strength") * 0.5))

func get_attribute(attr_name: String) -> int:
	var base_value = 0
	match attr_name:
		"strength": base_value = strength
		"constitution": base_value = constitution
		"agility": base_value = agility
		"intelligence": base_value = intelligence
		_: base_value = 0
	var buff_value = 0
	if buffs.has(attr_name):
		buff_value = buffs[attr_name][0]
	return max(0, base_value + buff_value)

func start_defending():
	is_defending = true
	print("   🛡️", name, "está defendendo")

func stop_defending():
	is_defending = false

func add_buff(attr_name: String, buff_value: int, duration_turns: int):
	if buffs.has(attr_name):
		var current_buff = buffs[attr_name]
		current_buff[0] += buff_value
		current_buff[1] = max(current_buff[1], duration_turns)
	else:
		buffs[attr_name] = [buff_value, duration_turns]
	calculate_stats()

func update_buffs():
	var keys_to_remove = []
	for attr_name in buffs.keys():
		buffs[attr_name][1] -= 1
		if buffs[attr_name][1] <= 0:
			keys_to_remove.append(attr_name)
	for attr_name in keys_to_remove:
		buffs.erase(attr_name)
	calculate_stats()
	stop_defending()

func add_combat_action(action: Action):
	if combat_actions.size() < 4:
		combat_actions.append(action)
	else:
		print("❌", name, "já tem o máximo de 4 ações de combate")

func remove_combat_action(action_index: int):
	if action_index >= 0 and action_index < combat_actions.size():
		combat_actions.remove_at(action_index)

func get_all_actions() -> Array[Action]:
	var all_actions: Array[Action] = []
	all_actions.append_array(basic_actions)
	all_actions.append_array(combat_actions)
	return all_actions

func has_ap_for_action(action: Action) -> bool:
	return current_ap >= action.ap_cost
