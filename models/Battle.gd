extends Node
class_name Battle

signal battle_started()
signal player_turn_started(character: Character)
signal ai_turn_started(character: Character)
signal action_executed(character: Character, action: Action, target: Character)
signal action_detailed_executed(character: Character, action: Action, target: Character, damage: int, healing: int, ap_used: int)
signal turn_completed(character: Character)
signal character_died(character: Character)
signal battle_ended(victory: bool)
signal player_action_selected()
signal ui_updated()

# 🆕 NOVO: Sinais para animações específicas
signal slash_effect_requested(action: Action, target_character: Character)
signal action_animation_requested(user: Character, action: Action, target: Character)

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
@export var ai_decision_delay: float = 1.0
@export var ui_update_wait_time: float = 0.5

# 🆕 NOVO: Referência para a BattleScene para acessar CharacterViews
var battle_scene: Node = null

func setup_battle(allies: Party, enemies: Party):
	allies_party = allies
	enemies_party = enemies
	battle_active = true
	print("🔧 setup_battle | allies:", allies_party.get_member_names(), "| enemies:", enemies_party.get_member_names())
	_initialize_characters()
	
	# 🆕 NOVO: Conectar sinais das ações de todos os personagens
	_connect_all_action_signals()

func _initialize_characters():
	for character in allies_party.members + enemies_party.members:
		character.calculate_stats()
		character.full_heal()

# 🆕 NOVO: Conectar sinais de todas as ações
func _connect_all_action_signals():
	for character in allies_party.members + enemies_party.members:
		for action in character.get_all_actions():
			if action and action.has_signal("slash_effect_requested"):
				if not action.slash_effect_requested.is_connected(_on_action_slash_requested):
					action.slash_effect_requested.connect(_on_action_slash_requested)
			
			if action and action.has_signal("animation_requested"):
				if not action.animation_requested.is_connected(_on_action_animation_requested):
					action.animation_requested.connect(_on_action_animation_requested)
	
	print("✅ Sinais das ações conectados no Battle")

# 🆕 NOVO: Manipulador de slash effects das ações
func _on_action_slash_requested(action: Action, target_character: Character):
	print("🗡️ Battle: Slash effect solicitado para ", action.name, " em ", target_character.name)
	slash_effect_requested.emit(action, target_character)

# 🆕 NOVO: Manipulador de animações gerais das ações
func _on_action_animation_requested(user: Character, action: Action, target: Character):
	print("🎬 Battle: Animação solicitada para ", action.name, " de ", user.name, " em ", target.name)
	action_animation_requested.emit(user, action, target)

func start_battle():
	battle_started.emit()
	print("🎲 Batalha iniciada")
	
	while battle_active:
		await _execute_round()
		current_round += 1
		_check_battle_end()

func _execute_round():
	_calculate_turn_order()
	current_turn_index = 0
	
	print("🔄 Rodada", current_round, "iniciada com", turn_order.size(), "personagens")
	
	while current_turn_index < turn_order.size() and battle_active:
		var character = turn_order[current_turn_index]
		
		if character.is_alive():
			print("🎯 Turno", current_turn_index, ":", character.name)
			
			if character in allies_party.members:
				await _execute_player_turn(character)
			else:
				await _execute_ai_turn(character)
		else:
			print("💀", character.name, "está morto - pulando turno")
		
		current_turn_index += 1
		print("➡️ Avançando para próximo turno. Índice:", current_turn_index)
		
		_check_battle_end()
		if not battle_active:
			print("🏁 Batalha terminou durante a rodada")
			break
	
	print("✅ Rodada", current_round, "concluída")
	_update_all_buffs()

func _execute_player_turn(character: Character):
	print("🎮 INICIANDO TURNO DO JOGADOR:", character.name)
	
	current_player_character = character
	waiting_for_player_input = true
	
	# Restaurar AP no início do turno
	if current_round > 0:
		var rec = character.restore_ap()
		print("🔋", character.name, "recuperou", rec, "AP")
	
	player_turn_started.emit(character)
	
	ui_updated.emit()
	await get_tree().create_timer(ui_update_wait_time).timeout
	
	print("⏸️ Esperando ação do jogador:", character.name)
	print("💰 AP disponível:", character.current_ap, "/", character.get_max_ap())
	
	# Se não tem AP, pular turno automaticamente
	if character.current_ap <= 0:
		print("❌", character.name, "sem AP - pulando turno automaticamente")
		waiting_for_player_input = false
		current_player_character = null
		turn_completed.emit(character)
		return
	
	# Aguardar ação do jogador
	print("⏳ Aguardando input do jogador...")
	await self.player_action_selected
	print("✅ Ação recebida do jogador")

func _execute_ai_turn(character: Character):
	print("🤖 INICIANDO TURNO DA IA:", character.name)
	
	# Restaurar AP no início do turno
	if current_round > 0:
		var rec = character.restore_ap()
		print("🤖", character.name, "recuperou", rec, "AP")
	
	ai_turn_started.emit(character)
	
	ui_updated.emit()
	await get_tree().create_timer(ui_update_wait_time).timeout
	
	# Se não tem AP, pular turno automaticamente
	if character.current_ap <= 0:
		print("❌", character.name, "sem AP - pulando turno")
		turn_completed.emit(character)
		return
	
	print("🤖 IA pensando...")
	await get_tree().create_timer(ai_decision_delay).timeout
	
	var action = _choose_action(character)
	var target = _choose_target(character, action)
	
	if action and target:
		print("🤖 IA escolheu:", action.name, "em", target.name)
		await _execute_action(character, action, target)
	else:
		print("🤖", character.name, "não encontrou ação válida")
	
	# SEMPRE finalizar turno da IA
	print("🤖 FINALIZANDO TURNO DA IA:", character.name)
	turn_completed.emit(character)

func on_player_select_action(action: Action, target: Character):
	print("🖱️ player_select_action chamado:", action and action.name, "->", target and target.name)
	
	if not waiting_for_player_input or not current_player_character:
		print("❌ player_select_action rejeitado - não está esperando input")
		return
	
	waiting_for_player_input = false
	var actor := current_player_character
	current_player_character = null
	
	# Verificar se ainda está vivo
	if not actor.is_alive():
		print("💀", actor.name, "morreu durante seleção de ação")
		turn_completed.emit(actor)
		player_action_selected.emit()
		return
	
	# Verificar AP
	if not actor.has_ap_for_action(action):
		print("❌ AP insuficiente! AP atual:", actor.current_ap, "Custo:", action.ap_cost)
		turn_completed.emit(actor)
		player_action_selected.emit()
		return
	
	# Executar ação
	print("🎮 Executando ação do jogador...")
	await _execute_action(actor, action, target)
	
	# SEMPRE finalizar turno após ação do jogador
	print("🎮 FINALIZANDO TURNO DO JOGADOR:", actor.name)
	turn_completed.emit(actor)
	
	player_action_selected.emit()

# 🆕 ATUALIZADO: Método _execute_action com sistema de dash
func _execute_action(character: Character, action: Action, target: Character):
	print("🧮 Execute:", action.name, "| atacker:", character.name, "| target:", target and target.name)
	
	await get_tree().create_timer(action_delay_sec).timeout
	
	# 🆕 NOVO: Executar animação de dash para ataques melee
	if action is AttackAction and action.animation_type == "melee" and target:
		await _execute_melee_dash_animation(character, action, target)
	else:
		# Para outros tipos de ação, apenas solicitar animação normal
		action_animation_requested.emit(character, action, target)
		await get_tree().create_timer(0.3).timeout  # Pequeno delay para animação básica
	
	# Guardar HP/AP antes da ação
	var target_hp_before = target.current_hp if target else 0
	var character_ap_before = character.current_ap
	
	# Executar ação - isso emitirá os sinais de animação automaticamente
	action.execute(character, target)
	action_executed.emit(character, action, target)
	
	# Calcular dano/efeito
	var damage_dealt = 0
	var healing_done = 0
	var ap_used = character_ap_before - character.current_ap
	
	if target:
		if action is AttackAction:
			damage_dealt = target_hp_before - target.current_hp
			if damage_dealt > 0:
				print("💥 Dano causado:", damage_dealt)
		elif action.name == "Curar" or action.name.contains("Cura"):
			healing_done = target.current_hp - target_hp_before
			if healing_done > 0:
				print("❤️ Cura realizada:", healing_done)
	
	# Emitir sinal com detalhes
	action_detailed_executed.emit(character, action, target, damage_dealt, healing_done, ap_used)
	
	# Verificar se o personagem morreu durante a ação
	if not character.is_alive():
		print("💀", character.name, "morreu durante a execução da ação!")
		character_died.emit(character)
	
	await get_tree().create_timer(between_actions_delay_sec).timeout
	
	# Log do estado final
	print("💰 AP após ação:", character.current_ap, "/", character.get_max_ap())
	if target and target.is_alive():
		print("❤️", target.name, "HP:", target.current_hp, "/", target.get_max_hp())

# 🆕 NOVA FUNÇÃO: Executar animação de dash para ataques melee
func _execute_melee_dash_animation(character: Character, action: Action, target: Character):
	print("⚔️ Executando animação de dash melee para", character.name)
	
	# 🆕 1. Solicitar animação de dash
	action_animation_requested.emit(character, action, target)
	
	# 🆕 2. Aguardar um pouco para o dash acontecer
	await get_tree().create_timer(0.5).timeout
	
	# 🆕 3. Solicitar slash effect no alvo
	if action.slash_sprite_frames:
		print("🗡️ Solicitando slash effect durante dash")
		slash_effect_requested.emit(action, target)
		
		# 🆕 4. Aguardar animação do slash
		await get_tree().create_timer(0.5).timeout
	
	print("✅ Animação de dash melee concluída")

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
	
	print("🧭 Ordem de turnos calculada com", turn_order.size(), "personagens:")
	for i in turn_order.size():
		print("   ", i, ":", turn_order[i].name, "(AGI:", turn_order[i].get_attribute("agility"), ")")

func _sort_by_agility(a: Character, b: Character) -> bool:
	return a.get_attribute("agility") > b.get_attribute("agility")

func _choose_action(character: Character) -> Action:
	var valid_actions: Array[Action] = []
	for action in character.get_all_actions():
		if character.has_ap_for_action(action):
			valid_actions.append(action)
	
	if valid_actions.is_empty():
		print("🤖", character.name, "não tem ações válidas (AP insuficiente)")
		return null
	
	var attacks := valid_actions.filter(func(a): return a is AttackAction)
	if not attacks.is_empty():
		var chosen = attacks[randi() % attacks.size()]
		print("🤖", character.name, "escolheu ataque:", chosen.name)
		return chosen
	
	var chosen = valid_actions[randi() % valid_actions.size()]
	print("🤖", character.name, "escolheu:", chosen.name)
	return chosen

func _choose_target(character: Character, action: Action) -> Character:
	if not action:
		return null
	
	var targets: Array[Character] = []
	
	match action.target_type:
		"enemy":
			targets = enemies_party.alive() if character in allies_party.members else allies_party.alive()
		"ally":
			targets = allies_party.alive() if character in allies_party.members else enemies_party.alive()
		"self":
			return character
		_:
			targets = enemies_party.alive() if character in allies_party.members else allies_party.alive()
	
	if targets.is_empty():
		print("🤖 Nenhum alvo disponível para", action.name)
		return null
	
	var target = targets[randi() % targets.size()]
	print("🤖 Alvo escolhido:", target.name)
	return target

func _update_all_buffs():
	for character in turn_order:
		if character.is_alive():
			character.update_buffs()

func _check_battle_end():
	var allies_alive = not allies_party.alive().is_empty()
	var enemies_alive = not enemies_party.alive().is_empty()
	
	if not allies_alive or not enemies_alive:
		battle_active = false
		
		if not allies_alive:
			print("🏁 Fim da batalha: DERROTA")
			battle_ended.emit(false)
		elif not enemies_alive:
			print("🏁 Fim da batalha: VITÓRIA")
			battle_ended.emit(true)

# Função para forçar fim do turno do jogador
func force_end_player_turn():
	if waiting_for_player_input and current_player_character:
		print("🔄 Forçando fim do turno do jogador:", current_player_character.name)
		waiting_for_player_input = false
		var character = current_player_character
		current_player_character = null
		turn_completed.emit(character)
		player_action_selected.emit()

# Função para forçar próximo turno
func force_next_turn():
	print("🔄 Battle: forçando próximo turno")
	if waiting_for_player_input and current_player_character:
		force_end_player_turn()

# 🆕 NOVO: Método para adicionar ações dinamicamente a personagens
func add_action_to_character(character_name: String, action: Action):
	for character in allies_party.members + enemies_party.members:
		if character.name == character_name:
			character.add_combat_action(action)
			# Reconectar sinais da nova ação
			if action.has_signal("slash_effect_requested"):
				action.slash_effect_requested.connect(_on_action_slash_requested)
			if action.has_signal("animation_requested"):
				action.animation_requested.connect(_on_action_animation_requested)
			print("✅ Ação", action.name, "adicionada a", character_name)
			return
	
	print("❌ Personagem", character_name, "não encontrado")

# 🆕 NOVO: Método para obter informações da batalha atual
func get_battle_info() -> Dictionary:
	return {
		"current_round": current_round,
		"allies_alive": allies_party.alive().size(),
		"enemies_alive": enemies_party.alive().size(),
		"current_turn": current_turn_index if current_turn_index < turn_order.size() else -1,
		"waiting_player_input": waiting_for_player_input
	}
