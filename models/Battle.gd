extends Node
class_name Battle

signal battle_started()
signal player_turn_started(character: Character)
signal action_executed(character: Character, action: Action, target: Character)
signal turn_completed(character: Character)
signal character_died(character: Character)
signal battle_ended(victory: bool)
signal player_action_selected()

var allies_party: Party
var enemies_party: Party
var current_round: int = 0
var battle_active: bool = false

var turn_order: Array[Character] = []
var current_turn_index: int = 0

var waiting_for_player_input: bool = false
var current_player_character: Character = null

@export var global_agility_order: bool = true
@export var action_delay_sec: float = 0.20
@export var between_actions_delay_sec: float = 0.20

func setup_battle(allies: Party, enemies: Party):
	allies_party = allies
	enemies_party = enemies
	battle_active = true
	print("🔧 setup_battle | allies:", allies_party.get_member_names(), "| enemies:", enemies_party.get_member_names())
	_initialize_characters()

func _initialize_characters():
	for character in allies_party.members + enemies_party.members:
		character.calculate_stats()
		character.full_heal()

func start_battle():
	battle_started.emit()
	print("🎲 Batalha iniciada")
	while battle_active:
		await _execute_round()
		current_round += 1

func _execute_round():
	_calculate_turn_order()
	current_turn_index = 0
	
	while current_turn_index < turn_order.size() and battle_active:
		var character = turn_order[current_turn_index]
		if character.is_alive():
			if character in allies_party.members:
				await _execute_player_turn(character)
			else:
				await _execute_ai_turn(character)
		current_turn_index += 1
	
	_update_all_buffs()
	_check_battle_end()

func _execute_player_turn(character: Character):
	current_player_character = character
	waiting_for_player_input = true
	
	if current_round > 0:
		var rec = character.restore_ap()
		print("🔋", character.name, "recuperou", rec, "AP (", character.current_ap, "/", character.get_max_ap(), ")")
	
	player_turn_started.emit(character)
	print("⏸️ Esperando ação do jogador:", character.name)
	await self.player_action_selected
	print("▶️ Ação recebida do jogador")

func _execute_ai_turn(character: Character):
	if current_round > 0:
		var rec = character.restore_ap()
		print("🤖", character.name, "recuperou", rec, "AP (", character.current_ap, "/", character.get_max_ap(), ")")
	
	var action = _choose_action(character)
	var target = _choose_target(character, action)
	
	if action and target:
		await _execute_action(character, action, target)
	
	turn_completed.emit(character)

func on_player_select_action(action: Action, target: Character):
	print("🖱️ player_select_action:", action and action.name, "->", target and target.name)
	if waiting_for_player_input and current_player_character:
		waiting_for_player_input = false
		var actor := current_player_character
		current_player_character = null
		# Executa a ação do jogador no mesmo pipeline da IA
		await _execute_action(actor, action, target)
		turn_completed.emit(actor)
		player_action_selected.emit()

func _calculate_turn_order():
	if global_agility_order:
		turn_order = (allies_party.alive() + enemies_party.alive()).duplicate()
		turn_order.sort_custom(_sort_by_agility)
	else:
		turn_order.clear()
		var players = allies_party.alive()
		var enemies = enemies_party.alive()
		players.sort_custom(_sort_by_agility)
		enemies.sort_custom(_sort_by_agility)
		turn_order.append_array(players)
		turn_order.append_array(enemies)
	print("🧭 Ordem de turnos:", turn_order.map(func(c): return c.name))

func _sort_by_agility(a: Character, b: Character) -> bool:
	return a.get_attribute("agility") > b.get_attribute("agility")

func _choose_action(character: Character) -> Action:
	var valid_actions: Array[Action] = []
	for action in character.get_all_actions():
		if character.has_ap_for_action(action):
			valid_actions.append(action)
	if valid_actions.is_empty():
		print("⚠️", character.name, "sem AP — pulando")
		return null
	var attacks := valid_actions.filter(func(a): return a is AttackAction)
	if not attacks.is_empty():
		return attacks[randi() % attacks.size()]
	return valid_actions[randi() % valid_actions.size()]

func _choose_target(character: Character, action: Action) -> Character:
	if not action:
		return null
	match action.target_type:
		"enemy":
			var targets = enemies_party.alive() if character in allies_party.members else allies_party.alive()
			return targets[randi() % targets.size()] if not targets.is_empty() else null
		"ally":
			var targets = allies_party.alive() if character in allies_party.members else enemies_party.alive()
			return targets[randi() % targets.size()] if not targets.is_empty() else null
		"self":
			return character
		_:
			return character

func _execute_action(character: Character, action: Action, target: Character):
	print("🧮 Execute:", action.name, "| atacker:", character.name, "| target_type:", action.target_type, "| target:", target and target.name)
	await get_tree().create_timer(action_delay_sec).timeout
	
	action.execute(character, target)  # gasta AP e aplica dano/efeitos
	action_executed.emit(character, action, target)
	
	if not target.is_alive():
		print("💀", target.name, "morreu")
		character_died.emit(target)
	
	await get_tree().create_timer(between_actions_delay_sec).timeout

func _update_all_buffs():
	for character in turn_order:
		if character.is_alive():
			character.update_buffs()

func _check_battle_end():
	var allies_alive = not allies_party.alive().is_empty()
	var enemies_alive = not enemies_party.alive().is_empty()
	if not allies_alive:
		print("🏁 Fim da batalha: DERROTA")
		battle_ended.emit(false)
		battle_active = false
	elif not enemies_alive:
		print("🏁 Fim da batalha: VITÓRIA")
		battle_ended.emit(true)
		battle_active = false
