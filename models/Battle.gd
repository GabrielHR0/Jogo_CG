extends Node
class_name Battle

var allies_party: Party
var enemies_party: Party
var current_round: int = 0
var battle_active: bool = true
var turn_order: Array[Character] = []

signal battle_started()
signal turn_started(character: Character, action: Action, target: Character)
signal turn_completed(character: Character)
signal battle_ended(victory: bool)

func setup(allies: Party, enemies: Party):
	allies_party = allies
	enemies_party = enemies

func start_battle():
	print("⚔️ INICIANDO BATALHA")
	battle_started.emit()
	
	# Loop principal da batalha
	while battle_active and is_inside_tree():
		await execute_round()
		current_round += 1
		check_battle_end()
	
	print("🏁 BATALHA FINALIZADA")

func execute_round():
	print("\n--- 🎲 RODADA " + str(current_round) + " ---")
	
	# Calcula ordem de iniciativa para esta rodada
	calculate_turn_order()
	
	# Executa os turnos na ordem calculada
	for character in turn_order:
		if not battle_active or not is_inside_tree():
			break
		if character.is_alive():
			await execute_turn(character)

func calculate_turn_order():
	turn_order.clear()
	
	# Coleta todos os personagens vivos
	var all_characters: Array[Character] = []
	all_characters.append_array(allies_party.alive())
	all_characters.append_array(enemies_party.alive())
	
	# Ordena por agilidade (maior agilidade age primeiro)
	all_characters.sort_custom(sort_by_agility)
	
	turn_order = all_characters
	print("🔄 Ordem de turnos:")
	for i in range(turn_order.size()):
		var char = turn_order[i]
		print("   " + str(i+1) + ". " + char.name + " (AGI: " + str(char.get_attribute("agility")) + ")")

func sort_by_agility(a: Character, b: Character) -> bool:
	return a.get_attribute("agility") > b.get_attribute("agility")

func execute_turn(character: Character) -> void:
	print("🎯 INICIANDO TURNO: " + character.name)
	
	# Cria ação e alvo
	var action = create_ai_action(character)
	var target = get_ai_target(character, action)
	
	if target == null:
		print("   ⚠️  Nenhum alvo disponível, pulando turno")
		return
	
	# Emite sinal de turno iniciado
	turn_started.emit(character, action, target)
	
	# Delay antes da ação
	if is_inside_tree():
		await get_tree().create_timer(1.5).timeout
	
	# Executa a ação
	action.execute(character, target)
	
	# Delay depois da ação
	if is_inside_tree():
		await get_tree().create_timer(1.0).timeout
	
	# Emite sinal de turno completado
	turn_completed.emit(character)

func create_ai_action(character: Character) -> Action:
	# IA simples - sempre ataque básico por enquanto
	return create_basic_attack()

func get_ai_target(character: Character, action: Action) -> Character:
	# Define alvo baseado no tipo de ação
	if action.target_type == "enemy":
		var targets = enemies_party.alive() if character in allies_party.members else allies_party.alive()
		if targets.is_empty():
			return null
		return targets[randi() % targets.size()]
	
	elif action.target_type == "ally":
		var targets = allies_party.alive() if character in allies_party.members else enemies_party.alive()
		if targets.is_empty():
			return null
		return targets[randi() % targets.size()]
	
	else: # "self"
		return character
	
	return null

func create_basic_attack() -> Action:
	var attack = Action.new()
	attack.name = "Ataque Básico"
	attack.ap_cost = 2
	attack.target_type = "enemy"
	return attack

func update_all_buffs():
	for ally in allies_party.members:
		if ally.is_alive():
			ally.update_buffs()
	for enemy in enemies_party.members:
		if enemy.is_alive():
			enemy.update_buffs()

func check_battle_end():
	var allies_alive = not allies_party.alive().is_empty()
	var enemies_alive = not enemies_party.alive().is_empty()
	
	if not allies_alive:
		print("💔 DERROTA! Todos os aliados morreram")
		battle_ended.emit(false)
		battle_active = false
	elif not enemies_alive:
		print("🎉 VITÓRIA! Todos os inimigos morreram")
		battle_ended.emit(true)
		battle_active = false
