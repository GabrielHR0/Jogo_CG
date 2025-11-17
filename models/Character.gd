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

# NOVO: Sistema de animações
@export_category("Animations")
@export var animation_data: AnimationData

var buffs := {}
var is_defending: bool = false
var defense_bonus: int = 0
var dodge_chance: float = 0.0

# NOVO: Sinais para controle de animações
signal animation_requested(animation_name, attack_type)
signal damage_animation_requested()
signal defense_animation_requested()
signal effect_requested(effect_name, position_offset)

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
	
	var defend = DefendAction.new()
	defend.name = "Defender"
	defend.ap_cost = calculate_defend_ap_cost()
	defend.target_type = "self"
	defend.description = "Assume postura defensiva até seu próximo turno"
	basic_actions.append(defend)
	
	var use_item = Action.new()
	use_item.name = "Usar Item"
	use_item.ap_cost = 2
	use_item.target_type = "ally"
	use_item.description = "Usa um item do inventário"
	basic_actions.append(use_item)

func calculate_defend_ap_cost() -> int:
	return int(get_max_ap() * 0.6)

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
	var base_defense = defense + defense_bonus
	return base_defense

func calculate_ap_recovery() -> int:
	return max(0, 3 + int(get_attribute("agility") / 2) + int(get_attribute("intelligence") / 3))

func restore_ap():
	var recovered = calculate_ap_recovery()
	current_ap = min(get_max_ap(), current_ap + recovered)
	
	if is_defending:
		stop_defending()
	
	return recovered

func take_damage(dmg: int) -> int:
	# Verifica se esquiva completamente
	if is_defending and randf() < dodge_chance:
		print("   🎯", name, "esquivou completamente do ataque!")
		# NOVO: Efeito de esquiva
		effect_requested.emit("dodge", Vector2.ZERO)
		return 0
	
	var defense_reduction = int(get_defense() * 0.5)
	var final_damage = max(0, dmg - defense_reduction)
	current_hp = max(0, current_hp - final_damage)
	
	# NOVO: Solicita animação de dano
	request_damage_animation()
	
	if defense_reduction > 0:
		print("   🛡️ Defesa reduziu", defense_reduction, "de dano")
		print("   💥 Dano final:", final_damage, "(original:", dmg, ")")
	
	return final_damage

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
	defense_bonus = int(get_attribute("constitution") * 1.5)
	dodge_chance = 0.15
	
	# NOVO: Solicita animação de defesa
	request_defense_animation()
	
	print("   🛡️", name, "está defendendo")
	print("   📈 +", defense_bonus, "defesa")
	print("   🎯 Chance de esquiva: 15%")
	print("   ⏱️ Duração: Até seu próximo turno")

func stop_defending():
	if is_defending:
		is_defending = false
		defense_bonus = 0
		dodge_chance = 0.0
		print("   🛡️", name, "saiu da posição defensiva")

func add_buff(attr_name: String, buff_value: int, duration_turns: int):
	if buffs.has(attr_name):
		var current_buff = buffs[attr_name]
		current_buff[0] += buff_value
		current_buff[1] = max(current_buff[1], duration_turns)
	else:
		buffs[attr_name] = [buff_value, duration_turns]
	
	_recalculate_combat_stats_only()

func _recalculate_combat_stats_only():
	melee_damage = calculate_melee_damage()
	magic_damage = calculate_magic_damage()
	ranged_damage = calculate_ranged_damage()
	defense = calculate_defense()

func update_buffs():
	var keys_to_remove = []
	for attr_name in buffs.keys():
		buffs[attr_name][1] -= 1
		if buffs[attr_name][1] <= 0:
			keys_to_remove.append(attr_name)
	for attr_name in keys_to_remove:
		buffs.erase(attr_name)
	
	_recalculate_combat_stats_only()

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

# ========== NOVOS MÉTODOS DE ANIMAÇÃO ==========

func request_attack_animation(attack_type: String = "basic"):
	animation_requested.emit("attack", attack_type)
	
	# Efeitos específicos por tipo de ataque
	match attack_type:
		"melee":
			effect_requested.emit("slash", Vector2(50, 0))
		"magic":
			effect_requested.emit("magic", Vector2(0, -30))
		"ranged":
			effect_requested.emit("arrow", Vector2(40, -20))

func request_damage_animation():
	damage_animation_requested.emit()

func request_defense_animation():
	animation_requested.emit("defend", "")
	effect_requested.emit("shield", Vector2(0, 0))

func request_idle_animation():
	animation_requested.emit("idle", "")

func request_walk_animation():
	animation_requested.emit("walk", "")

func request_victory_animation():
	animation_requested.emit("victory", "")
	effect_requested.emit("sparkles", Vector2(0, -50))

func request_defeat_animation():
	animation_requested.emit("defeat", "")

# Método para ações de combate
func execute_combat_action(action: Action) -> String:
	# Gasta AP
	spend_ap(action.ap_cost)
	
	# Determina tipo de animação baseado na ação
	var attack_type = "melee"  # padrão
	
	if action.has_method("get_damage_type"):
		var damage_type = action.get_damage_type()
		match damage_type:
			"magic":
				attack_type = "magic"
			"ranged":
				attack_type = "ranged"
			_:
				attack_type = "melee"
	
	# Solicita animação de ataque
	request_attack_animation(attack_type)
	
	return attack_type

# Método para quando o personagem é selecionado
func on_selected():
	effect_requested.emit("highlight", Vector2.ZERO)

# Método para quando o personagem é curado
func on_healed(amount: int):
	effect_requested.emit("heal", Vector2(0, -30))
