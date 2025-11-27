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

@export_category("Animations")
@export var animation_data: AnimationData
@export var animation_prefab: PackedScene

var buffs := {}
var is_defending: bool = false
var defense_bonus: int = 0
var dodge_chance: float = 0.0

# 🆕 SISTEMA DE SUPORTE
var current_shield: int = 0
var shield_duration: int = 0
var hot_amount: int = 0
var hot_duration: int = 0
var debuffs := {}

var animation_system: AnimationSystem = null
var battle_position: Vector2 = Vector2.ZERO

signal animation_requested(animation_name, attack_type)
signal damage_animation_requested()
signal defense_animation_requested()
signal effect_requested(effect_name, position_offset)
signal position_updated(new_position: Vector2)
signal animation_system_ready(system: AnimationSystem)
signal character_died()
# 🆕 NOVOS SINAIS PARA SUPORTE
signal shield_applied(amount: int, duration: int)
signal hot_applied(amount: int, duration: int)
signal debuff_applied(attribute: String, value: int, duration: int)
signal debuffs_cleansed(count: int)

func _init():
	calculate_stats()
	_setup_basic_actions()
	# 🆕 Inicializar sistemas de suporte
	current_shield = 0
	shield_duration = 0
	hot_amount = 0
	hot_duration = 0

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
	# 🆕 CORREÇÃO: Verificar escudo primeiro
	var damage_after_shield = _process_shield(dmg)
	if damage_after_shield <= 0:
		print("   🛡️ Escudo absorveu todo o dano!")
		return 0
	
	# Verifica se esquiva completamente
	if is_defending and randf() < dodge_chance:
		print("   🎯", name, "esquivou completamente do ataque!")
		effect_requested.emit("dodge", Vector2.ZERO)
		return 0
	
	var defense_reduction = int(get_defense() * 0.5)
	var final_damage = max(0, damage_after_shield - defense_reduction)
	current_hp = max(0, current_hp - final_damage)
	
	# Emite sinal de morte se HP chegou a zero
	if current_hp <= 0:
		character_died.emit()
	
	# Solicita animação de dano
	request_damage_animation()
	
	if defense_reduction > 0:
		print("   🛡️ Defesa reduziu", defense_reduction, "de dano")
		print("   💥 Dano final:", final_damage, "(original:", dmg, ")")
	
	return final_damage

# 🆕 NOVO: Processar dano no escudo
func _process_shield(damage: int) -> int:
	if current_shield <= 0:
		return damage
	
	if damage <= current_shield:
		current_shield -= damage
		print("   🛡️ Escudo absorveu ", damage, " de dano")
		print("   🛡️ Escudo restante: ", current_shield)
		return 0
	else:
		var remaining_damage = damage - current_shield
		print("   🛡️ Escudo absorveu ", current_shield, " de dano")
		current_shield = 0
		shield_duration = 0  # Escudo quebrado
		return remaining_damage

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
	
	# Aplicar buffs
	var buff_value = 0
	if buffs.has(attr_name):
		buff_value = buffs[attr_name][0]
	
	# 🆕 Aplicar debuffs
	var debuff_value = 0
	if debuffs.has(attr_name):
		debuff_value = debuffs[attr_name][0]
	
	return max(0, base_value + buff_value - debuff_value)

func start_defending():
	is_defending = true
	defense_bonus = int(get_attribute("constitution") * 1.5)
	dodge_chance = 0.15
	
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

# 🆕 NOVO: Adicionar escudo
func add_shield(amount: int, duration: int):
	current_shield = amount
	shield_duration = duration
	shield_applied.emit(amount, duration)
	print("   🛡️ ", name, " ganhou escudo de ", amount, " por ", duration, " turnos")

# 🆕 NOVO: Adicionar Heal Over Time
func add_hot(amount: int, duration: int):
	hot_amount = amount
	hot_duration = duration
	hot_applied.emit(amount, duration)
	print("   💚 ", name, " ganhou cura contínua de ", amount, " HP por ", duration, " turnos")

# 🆕 NOVO: Sistema de debuffs
func add_debuff(attr_name: String, debuff_value: int, duration_turns: int):
	if debuffs.has(attr_name):
		var current_debuff = debuffs[attr_name]
		current_debuff[0] += debuff_value
		current_debuff[1] = max(current_debuff[1], duration_turns)
	else:
		debuffs[attr_name] = [debuff_value, duration_turns]
	
	debuff_applied.emit(attr_name, debuff_value, duration_turns)
	_recalculate_combat_stats_only()

# 🆕 NOVO: Remover todos os debuffs (cleanse)
func remove_all_debuffs() -> int:
	var removed_count = debuffs.size()
	debuffs.clear()
	debuffs_cleansed.emit(removed_count)
	_recalculate_combat_stats_only()
	print("   ✨ ", name, " removeu ", removed_count, " debuffs")
	return removed_count

# 🆕 NOVO: Atualizar debuffs
func update_debuffs():
	var keys_to_remove = []
	for attr_name in debuffs.keys():
		debuffs[attr_name][1] -= 1
		if debuffs[attr_name][1] <= 0:
			keys_to_remove.append(attr_name)
	for attr_name in keys_to_remove:
		debuffs.erase(attr_name)
	
	_recalculate_combat_stats_only()

# 🆕 NOVO: Processar efeitos no início do turno
func process_start_of_turn_effects():
	# Processar HOT (Heal Over Time)
	if hot_duration > 0 and hot_amount > 0:
		var actual_heal = min(hot_amount, get_max_hp() - current_hp)
		if actual_heal > 0:
			current_hp += actual_heal
			print("   💚 Cura contínua: ", name, " recuperou ", actual_heal, " HP")
			request_heal_animation()
		hot_duration -= 1
		if hot_duration <= 0:
			hot_amount = 0
			print("   💚 Cura contínua de ", name, " terminou")

# 🆕 NOVO: Processar efeitos no final do turno
func process_end_of_turn_effects():
	# Processar duração do escudo
	if shield_duration > 0:
		shield_duration -= 1
		if shield_duration <= 0:
			current_shield = 0
			print("   🛡️ Escudo de ", name, " expirou")
	
	# Processar buffs
	update_buffs()
	
	# Processar debuffs
	update_debuffs()

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

func setup_animation_system(system: AnimationSystem):
	animation_system = system
	animation_system_ready.emit(system)

func create_animation_system(parent: Node) -> AnimationSystem:
	if animation_prefab:
		var system = animation_prefab.instantiate()
		parent.add_child(system)
		animation_system = system
		animation_system_ready.emit(system)
		return system
	return null

func set_battle_position(new_position: Vector2):
	battle_position = new_position
	position_updated.emit(new_position)

func get_battle_position() -> Vector2:
	return battle_position

func request_attack_animation(attack_type: String = "basic", target_position: Vector2 = Vector2.ZERO):
	animation_requested.emit("attack", attack_type)
	
	if animation_system and target_position != Vector2.ZERO:
		animation_system.play_attack_animation(attack_type, target_position)
	else:
		match attack_type:
			"melee":
				effect_requested.emit("slash", Vector2(50, 0))
			"magic":
				effect_requested.emit("magic", Vector2(0, -30))
			"ranged":
				effect_requested.emit("arrow", Vector2(40, -20))
			"special":
				effect_requested.emit("sparkles", Vector2(0, -50))

func request_heal_animation():
	effect_requested.emit("heal", Vector2(0, -30))
	
	if animation_system:
		animation_system.play_heal_animation()

# 🆕 NOVO: Solicitar animação de buff
func request_buff_animation(buff_type: String):
	effect_requested.emit("buff", Vector2(0, -40))
	
	if animation_system:
		animation_system.play_buff_animation(buff_type)

# 🆕 NOVO: Solicitar animação de escudo
func request_shield_animation():
	effect_requested.emit("shield", Vector2(0, 0))
	
	if animation_system:
		animation_system.play_shield_animation()

# 🆕 NOVO: Solicitar animação de cleanse
func request_cleanse_animation():
	effect_requested.emit("cleanse", Vector2(0, -60))
	
	if animation_system:
		animation_system.play_cleanse_animation()
		
func request_damage_animation():
	damage_animation_requested.emit()
	effect_requested.emit("damage", Vector2(0, -20))
	
	if animation_system:
		animation_system.play_damage_animation()

func request_defense_animation():
	animation_requested.emit("defend", "")
	effect_requested.emit("shield", Vector2(0, 0))
	
	if animation_system:
		animation_system.play_defense_animation()

func request_idle_animation():
	animation_requested.emit("idle", "")
	
	if animation_system:
		animation_system.play_idle_animation()

func request_walk_animation():
	animation_requested.emit("walk", "")
	
	if animation_system:
		animation_system.play_walk_animation()

func request_victory_animation():
	animation_requested.emit("victory", "")
	effect_requested.emit("sparkles", Vector2(0, -50))
	
	if animation_system:
		animation_system.play_victory_animation()

func request_defeat_animation():
	animation_requested.emit("defeat", "")
	
	if animation_system:
		animation_system.play_defeat_animation()

func execute_combat_action(action: Action, target: Character = null) -> String:
	spend_ap(action.ap_cost)
	
	var attack_type = "melee"
	
	if action is AttackAction:
		attack_type = action.formula
	elif action.has_method("get_damage_type"):
		var damage_type = action.get_damage_type()
		match damage_type:
			"magic":
				attack_type = "magic"
			"ranged":
				attack_type = "ranged"
			_:
				attack_type = "melee"
	
	if target and target.battle_position != Vector2.ZERO:
		request_attack_animation(attack_type, target.battle_position)
	else:
		request_attack_animation(attack_type)
	
	return attack_type

func on_selected():
	effect_requested.emit("highlight", Vector2.ZERO)
	
	if animation_system:
		animation_system.play_highlight_animation()

func on_healed(amount: int):
	effect_requested.emit("heal", Vector2(0, -30))
	
	if animation_system:
		animation_system.play_heal_animation()

func receive_healing(amount: int):
	var actual_healing = min(amount, get_max_hp() - current_hp)
	current_hp += actual_healing
	
	on_healed(actual_healing)
	
	print("   💚", name, "curado em", actual_healing, "HP")
	print("   ❤️ HP atual:", current_hp, "/", get_max_hp())
	
	return actual_healing

func can_act() -> bool:
	return is_alive() and current_ap > 0

# 🆕 ATUALIZADO: Resetar estado de batalha completo
func reset_battle_state():
	is_defending = false
	defense_bonus = 0
	dodge_chance = 0.0
	buffs.clear()
	debuffs.clear()
	current_shield = 0
	shield_duration = 0
	hot_amount = 0
	hot_duration = 0
	_recalculate_combat_stats_only()

# 🆕 ATUALIZADO: Informações de status completas
func get_status_info() -> Dictionary:
	return {
		"name": name,
		"hp": current_hp,
		"max_hp": get_max_hp(),
		"ap": current_ap,
		"max_ap": get_max_ap(),
		"is_defending": is_defending,
		"buffs": buffs.duplicate(),
		"debuffs": debuffs.duplicate(),
		"shield": current_shield,
		"shield_duration": shield_duration,
		"hot_amount": hot_amount,
		"hot_duration": hot_duration,
		"is_alive": is_alive(),
		"battle_position": battle_position
	}

# 🆕 CORREÇÃO: Método has_buff corrigido
func has_buff(attribute: String) -> bool:
	# buffs é um Dictionary onde as chaves são os nomes dos atributos
	return buffs.has(attribute)

# 🆕 ATUALIZADO: Print status completo
func print_status():
	print("=== STATUS %s ===" % name)
	print("❤️ HP: %d/%d" % [current_hp, get_max_hp()])
	print("⚡ AP: %d/%d" % [current_ap, get_max_ap()])
	print("💪 Força: %d" % get_attribute("strength"))
	print("🛡️ Constituição: %d" % get_attribute("constitution"))
	print("🎯 Agilidade: %d" % get_attribute("agility"))
	print("🧠 Inteligência: %d" % get_attribute("intelligence"))
	print("🗡️ Dano Corpo-a-Corpo: %d" % melee_damage)
	print("🔮 Dano Mágico: %d" % magic_damage)
	print("🏹 Dano à Distância: %d" % ranged_damage)
	print("🛡️ Defesa: %d" % defense)
	print("🛡️ Defendendo: %s" % ("Sim" if is_defending else "Não"))
	print("🛡️ Escudo: %d (dura %d turnos)" % [current_shield, shield_duration])
	print("💚 Cura Contínua: %d HP (dura %d turnos)" % [hot_amount, hot_duration])
	print("📍 Posição: %s" % battle_position)
	print("📈 Buffs Ativos: %d" % buffs.size())
	for buff in buffs:
		print("   - %s: +%d (%d turnos)" % [buff, buffs[buff][0], buffs[buff][1]])
	print("📉 Debuffs Ativos: %d" % debuffs.size())
	for debuff in debuffs:
		print("   - %s: -%d (%d turnos)" % [debuff, debuffs[debuff][0], debuffs[debuff][1]])
	print("================")

func cleanup():
	if animation_system:
		animation_system.queue_free()
		animation_system = null
