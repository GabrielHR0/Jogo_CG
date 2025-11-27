extends Control

# Áreas de batalha (topo)
@onready var enemies_front_row = $HBoxContainer/EnemiesArea/EnemyFrontRow
@onready var enemies_back_row  = $HBoxContainer/EnemiesArea/EnemyBackRow
@onready var allies_front_row  = $HBoxContainer/AlliesArea/AllyFrontRow
@onready var allies_back_row   = $HBoxContainer/AlliesArea/AllyBackRow

# Status do personagem ativo
@onready var character_icon = $CanvasLayer/BottomPanel/HBoxContainer/CharacterStatus/CharacterIcon/CharacterIcon
@onready var character_name = $CanvasLayer/BottomPanel/HBoxContainer/CharacterStatus/VBoxContainer/VBoxContainer/CharacterName
@onready var hp_bar        = $CanvasLayer/BottomPanel/HBoxContainer/CharacterStatus/VBoxContainer/VBoxContainer/HPBar
@onready var hp_label      = $CanvasLayer/BottomPanel/HBoxContainer/CharacterStatus/VBoxContainer/VBoxContainer/HPBar/HPLabel
@onready var ap_bar        = $CanvasLayer/BottomPanel/HBoxContainer/CharacterStatus/VBoxContainer/VBoxContainer/APBar
@onready var ap_label      = $CanvasLayer/BottomPanel/HBoxContainer/CharacterStatus/VBoxContainer/VBoxContainer/APBar/APLabel

# Menu de comandos
@onready var fight_button  = $CanvasLayer/BottomPanel/HBoxContainer/CommandMenu/CommandMenu/FightButton
@onready var defend_button = $CanvasLayer/BottomPanel/HBoxContainer/CommandMenu/CommandMenu/DefendButton
@onready var items_button  = $CanvasLayer/BottomPanel/HBoxContainer/CommandMenu/CommandMenu/ItemsButton
@onready var skip_button   = $CanvasLayer/BottomPanel/HBoxContainer/CommandMenu/CommandMenu/SkipButton

# Sub-menus
@onready var attack_menu              = $CanvasLayer/BottomPanel/HBoxContainer/AttackMenu/AttackMenu
@onready var attack_buttons_container = $CanvasLayer/BottomPanel/HBoxContainer/AttackMenu/AttackMenu/AttackButtons
@onready var target_menu              = $CanvasLayer/BottomPanel/HBoxContainer/TargetMenu/TargetMenu
@onready var target_buttons_container = $CanvasLayer/BottomPanel/HBoxContainer/TargetMenu/TargetMenu/TargetButtons

# Actions Label
@onready var actions_label = $CanvasLayer/BottomPanel/ActionsLabel

# Sistema de batalha
var battle: Battle
var character_views := {}
var current_player_character: Character = null
var selected_action: Action = null
var battle_ended: bool = false

# Estados
enum UIState { IDLE, PLAYER_TURN, AI_TURN, ACTION_EXECUTING, MENU_OPEN }
var current_ui_state: UIState = UIState.IDLE

# 🆕 NOVO: Sistema de efeitos persistentes
var persistent_effects: Dictionary = {}

func get_character_views() -> Dictionary:
	"""Fornece acesso às character_views para as SupportActions"""
	return character_views

# Configuração das CharacterViews
var character_view_scene: PackedScene

func _ready():
	print("=== BattleScene READY ===")
	_load_character_view_scene()
	setup_ui()
	connect_buttons()

func _load_character_view_scene():
	var possible_paths = [
		"res://scenes/character_view/CharacterView.tscn",
		"res://CharacterView.tscn", 
	]
	
	for path in possible_paths:
		if ResourceLoader.exists(path):
			character_view_scene = load(path)
			if character_view_scene:
				print("✅ CharacterView carregada de: ", path)
				return
	
	print("❌ CharacterView.tscn não encontrada")
	character_view_scene = null

func setup_ui():
	attack_menu.visible = false
	target_menu.visible = false
	character_icon.visible = false
	
	if actions_label:
		actions_label.text = "Preparando batalha..."
	
	set_buttons_enabled(false)

func connect_buttons():
	fight_button.pressed.connect(_on_fight_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	items_button.pressed.connect(_on_items_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	print("UI Sinais conectados")

func set_buttons_enabled(enabled: bool):
	fight_button.disabled = not enabled
	defend_button.disabled = not enabled
	items_button.disabled = not enabled
	skip_button.disabled = not enabled
	print("Botões " + ("✅ habilitados" if enabled else "❌ desabilitados"))

func can_process_player_input() -> bool:
	return (not battle_ended and 
			current_player_character != null and
			current_player_character in battle.allies_party.members and
			current_player_character.is_alive() and
			(current_ui_state == UIState.PLAYER_TURN or current_ui_state == UIState.MENU_OPEN))

func setup_battle(allies_party: Party, enemies_party: Party):
	print("Setup battle:", allies_party.name, "vs", enemies_party.name)
	battle_ended = false
	current_ui_state = UIState.IDLE
	
	battle = Battle.new()
	_connect_battle_signals()
	add_child(battle)

	battle.setup_battle(allies_party, enemies_party)
	
	# 🆕 CORREÇÃO: Aguardar um frame para garantir que o battle esteja completamente inicializado
	await get_tree().process_frame
	
	# 🆕 CORREÇÃO: Conectar sinais de suporte APÓS criar as character views
	create_character_views()
	_setup_actions_battle_scene_reference()
	
	# 🆕 CORREÇÃO: Conectar sinais de suporte APÓS as character views estarem criadas
	_connect_character_support_signals()

	await get_tree().create_timer(0.5).timeout
	print("start_battle()")
	battle.start_battle()
	
func _setup_actions_battle_scene_reference():
	"""Configura a referência do BattleScene em todas as SupportActions"""
	print("🔗 Configurando referências do BattleScene nas SupportActions...")
	
	var action_count = 0
	for character in battle.allies_party.members + battle.enemies_party.members:
		for action in character.combat_actions + character.basic_actions:
			if action is SupportAction:
				action.set_battle_scene(self)
				action_count += 1
				print("   ✅ ", action.name, " configurada para ", character.name)
	
	print("🎯 Total de SupportActions configuradas: ", action_count)

# 🆕 CORREÇÃO: Sistema de conexão de sinais melhorado
func _connect_battle_signals():
	if not battle:
		print("❌ Battle não existe para conectar sinais")
		return
	
	# Sinais básicos do battle
	battle.battle_started.connect(_on_battle_started)
	battle.player_turn_started.connect(_on_player_turn_started)
	battle.ai_turn_started.connect(_on_ai_turn_started)
	battle.action_executed.connect(_on_action_executed)
	battle.action_detailed_executed.connect(_on_action_detailed_executed)
	battle.turn_completed.connect(_on_turn_completed)
	battle.character_died.connect(_on_character_died)
	battle.battle_ended.connect(_on_battle_ended)
	battle.player_action_selected.connect(_on_player_action_selected)
	battle.ui_updated.connect(_on_ui_updated)
	
	# 🆕 SINAIS DE ANIMAÇÃO - BattleScene executa diretamente
	battle.slash_effect_requested.connect(_on_battle_slash_requested)
	battle.action_animation_requested.connect(_on_battle_action_animation_requested)
	
	# 🆕 NOVO: Conectar sinal para atualizar efeitos persistentes
	if battle.has_signal("turn_ended"):
		battle.turn_ended.connect(_on_turn_ended)
	
	print("✅ Todos os sinais do Battle conectados")

# BattleScene.gd - Adicione este método se não existir

func _on_turn_ended(character: Character):
	print("🔄 BattleScene: Atualizando efeitos persistentes no final do turno de ", character.name)
	_update_all_persistent_effects()

func _update_all_persistent_effects():
	"""Atualiza todos os efeitos persistentes de todas as SupportActions"""
	print("🎆 Atualizando todos os efeitos persistentes...")
	
	var updated_count = 0
	for character in battle.allies_party.members + battle.enemies_party.members:
		for action in character.combat_actions + character.basic_actions:
			if action is SupportAction:
				action.update_persistent_effects()
				updated_count += 1
	
	print("🎆 Efeitos persistentes atualizados para ", updated_count, " ações")

# 🆕 CORREÇÃO: Função simplificada e mais segura
func _connect_character_support_signals():
	print("🔗 Conectando sinais de suporte...")
	
	# Verificar se o battle e as parties existem
	if not battle:
		print("❌ Battle não existe para conectar sinais de suporte")
		return
	
	# 🆕 CORREÇÃO: Verificar diretamente as properties
	if not "allies_party" in battle or not battle.allies_party:
		print("❌ Allies Party não disponível")
		return
	
	if not "enemies_party" in battle or not battle.enemies_party:
		print("❌ Enemies Party não disponível")
		return
	
	# Conectar sinais de todos os personagens existentes
	var connected_count = 0
	
	# 🆕 CORREÇÃO: Acessar diretamente os arrays de members
	# Aliados
	for character in battle.allies_party.members:
		if character and _connect_character_signals(character):
			connected_count += 1
	
	# Inimigos
	for character in battle.enemies_party.members:
		if character and _connect_character_signals(character):
			connected_count += 1
	
	print("✅ Sinais de suporte conectados para", connected_count, "personagens")

func _connect_character_signals(character: Character) -> bool:
	if not character:
		return false
	
	var connected = false
	
	# 🆕 Conectar sinais de suporte com verificações de segurança
	if character.has_signal("shield_applied"):
		if not character.shield_applied.is_connected(_on_shield_applied):
			character.shield_applied.connect(_on_shield_applied.bind(character))
			connected = true
			print("   🔗 Conectado shield_applied para", character.name)
	
	if character.has_signal("hot_applied"):
		if not character.hot_applied.is_connected(_on_hot_applied):
			character.hot_applied.connect(_on_hot_applied.bind(character))
			connected = true
			print("   🔗 Conectado hot_applied para", character.name)
	
	if character.has_signal("debuff_applied"):
		if not character.debuff_applied.is_connected(_on_debuff_applied):
			character.debuff_applied.connect(_on_debuff_applied.bind(character))
			connected = true
			print("   🔗 Conectado debuff_applied para", character.name)
	
	if character.has_signal("debuffs_cleansed"):
		if not character.debuffs_cleansed.is_connected(_on_debuffs_cleansed):
			character.debuffs_cleansed.connect(_on_debuffs_cleansed.bind(character))
			connected = true
			print("   🔗 Conectado debuffs_cleansed para", character.name)
	
	return connected
	
#🆕 SISTEMA DE ANIMAÇÕES DE SUPORTE
func _on_shield_applied(amount: int, duration: int, character: Character):
	print("🛡️ BattleScene: Escudo aplicado em", character.name, "amount:", amount, "duration:", duration)
	
	if character.name in character_views:
		var character_view = character_views[character.name]
		character_view.play_shield_effect(amount)
	
	# Atualizar UI se for o personagem atual
	if current_player_character == character:
		update_character_status(character)

func _on_hot_applied(amount: int, duration: int, character: Character):
	print("💚 BattleScene: HOT aplicado em", character.name, "amount:", amount, "duration:", duration)
	
	if character.name in character_views:
		var character_view = character_views[character.name]
		character_view.play_hot_effect(amount, duration)

func _on_debuff_applied(attribute: String, value: int, duration: int, character: Character):
	print("📉 BattleScene: Debuff aplicado em", character.name, "attribute:", attribute, "value:", value)
	
	if character.name in character_views:
		var character_view = character_views[character.name]
		# Mostrar efeito visual de debuff (vermelho/escuro)
		character_view.play_debuff_effect(attribute, value)

func _on_debuffs_cleansed(count: int, character: Character):
	print("✨ BattleScene: Debuffs removidos de", character.name, "count:", count)
	
	if character.name in character_views:
		var character_view = character_views[character.name]
		character_view.play_cleanse_effect(count)

# 🆕 NOVO: Processar ações de suporte especificamente
# 🆕 CORREÇÃO: Processar ações de suporte COM ORDEM CORRETA
func _process_support_action(action: Action, user: Character, target: Character):
	print("🌟 BattleScene: Processando ação de suporte:", action.name)
	
	if not (action is SupportAction and target.name in character_views):
		return
	
	var support_action = action as SupportAction
	
	# 🆕 CASO ESPECIAL: DEFESA COM EFEITO PERSISTENTE
	if support_action.buff_attribute == "defense" and support_action.buff_value > 0:
		_process_defense_action(support_action, user, target)
		return
	
	if support_action.name == "Barreira Arcana":
		_process_barreira_arcana(support_action, user, target)
		return
	
	# 🆕 ORDEM CORRETA DAS ANIMAÇÕES:
	
	# 1. PRIMEIRO: Efeito especial principal (se tiver)
	if action.has_effect_animation():
		print("   🎬 1. Criando efeito visual principal")
		var target_wrapper = character_views[target.name].get_parent()
		if target_wrapper:
			var effect_position = target_wrapper.global_position + target_wrapper.size / 2
			var effect = action.create_effect_animation(effect_position, self)
			
			# 🆕 AGUARDAR EFEITO PRINCIPAL TERMINAR ANTES DE CONTINUAR
			if effect:
				print("   ⏳ Aguardando efeito principal terminar...")
				await get_tree().create_timer(0.5).timeout  # Ajuste o tempo conforme sua animação
	
	# 2. SEGUNDO: Efeitos específicos (cura, buff, escudo, cleanse)
	
	# 🆕 CURA (pode acontecer junto com outros efeitos)
	if support_action.heal_amount > 0:
		print("   💚 2. Executando efeito de cura")
		character_views[target.name].play_heal_effect(support_action.heal_amount, support_action)
	
	# 🆕 BUFF (exceto escudo - esse é tratado separadamente)
	if support_action.buff_attribute != "" and support_action.buff_value > 0 and support_action.buff_attribute != "defense":
		print("   📈 2. Executando efeito de buff")
		character_views[target.name].play_buff_effect(support_action.buff_attribute, support_action.buff_value, support_action)
	
	# 🆕 ESCUDO (TRATAMENTO ESPECIAL - deve vir DEPOIS dos outros efeitos)
	if support_action.shield_amount > 0:
		print("   🛡️ 3. Executando efeito de escudo PERSISTENTE")
		# 🆕 PEQUENA PAUSA ANTES DO ESCUDO
		await get_tree().create_timer(0.2).timeout
		character_views[target.name].play_shield_effect(support_action.shield_amount, support_action)
	
	# 🆕 CLEANSE (pode acontecer junto)
	if support_action.cleanse_debuffs:
		print("   ✨ 2. Executando efeito de cleanse")
		character_views[target.name].play_cleanse_effect(0, support_action)
	
	# 🆕 HOT (pode acontecer junto)
	if support_action.hot_amount > 0 and support_action.hot_duration > 0:
		print("   💚 2. Executando efeito de HOT")
		character_views[target.name].play_hot_effect(support_action.hot_amount, support_action.hot_duration)

# 🆕 FUNÇÃO ESPECIAL PARA BARREIRA ARCANA
func _process_barreira_arcana(action: SupportAction, user: Character, target: Character):
	print("🌟 BattleScene: Processando BARREIRA ARCANA")
	
	if target.name not in character_views:
		return
	
	# 1. EFEITO PRINCIPAL DA AÇÃO
	if action.has_effect_animation():
		print("   🎬 1. Efeito principal da barreira")
		var target_wrapper = character_views[target.name].get_parent()
		if target_wrapper:
			var effect_position = target_wrapper.global_position + target_wrapper.size / 2
			var effect = action.create_effect_animation(effect_position, self)
			if effect:
				await get_tree().create_timer(0.6).timeout  # Aguardar animação principal
	
	# 2. EFEITO DE BUFF DE DEFESA
	if action.buff_attribute == "defense" and action.buff_value > 0:
		print("   📈 2. Efeito de buff de defesa")
		character_views[target.name].play_buff_effect(action.buff_attribute, action.buff_value, action)
		await get_tree().create_timer(0.3).timeout  # Pequena pausa
	
	# 3. EFEITO DE ESCUDO PERSISTENTE (POR ÚLTIMO)
	if action.shield_amount > 0:
		print("   🛡️ 3. Efeito de escudo persistente")
		character_views[target.name].play_shield_effect(action.shield_amount, action)

# 🆕 NOVO: Processar ação de defesa com efeito persistente
func _process_defense_action(action: SupportAction, user: Character, target: Character):
	print("🛡️ BattleScene: Processando DEFESA com efeito persistente")
	
	if target.name not in character_views:
		return
	
	# 1. Efeito principal da ação
	if action.has_effect_animation():
		print("   🎬 1. Efeito principal da defesa")
		var target_wrapper = character_views[target.name].get_parent()
		if target_wrapper:
			var effect_position = target_wrapper.global_position + target_wrapper.size / 2
			var effect = action.create_effect_animation(effect_position, self)
			if effect:
				await get_tree().create_timer(0.4).timeout
	
	# 2. Efeito visual no CharacterView
	print("   🛡️ 2. Efeito de defesa no personagem")
	character_views[target.name].play_defense_effect(action)
	
	# 3. Efeito persistente (se configurado)
	if action.has_persistent_effect:
		print("   🎆 3. Criando efeito persistente de defesa")
		# O efeito persistente é criado automaticamente pelo SupportAction.apply_effects()
		# Mas podemos forçar a criação aqui também para garantir
		action.create_persistent_effect(target, action.buff_duration)
		
func _on_battle_action_animation_requested(user: Character, action: Action, target: Character):
	print("🎬 BattleScene: EXECUTANDO ANIMAÇÃO para ", action.name)
	print("   User:", user.name, " | Target:", target.name)
	
	# 🆕 PRIMEIRO: Verificar se é ação de suporte
	if action is SupportAction:
		_process_support_action(action, user, target)
		return
	
	# Verificar se temos as views para ações normais
	if user.name not in character_views:
		print("❌ CharacterView do usuário não encontrada:", user.name)
		return
	
	if target.name not in character_views:
		print("❌ CharacterView do alvo não encontrada:", target.name)
		return
	
	var user_view = character_views[user.name]
	var target_view = character_views[target.name]
	
	# 🆕 CORREÇÃO: Obter a posição global do wrapper (pai do CharacterView)
	var user_wrapper = user_view.get_parent()
	var target_wrapper = target_view.get_parent()
	
	if user_wrapper and target_wrapper:
		var target_global_pos = target_wrapper.global_position + target_wrapper.size / 2
		
		# 🆕 BATTLE SCENE CONTROLA TUDO
		if action is AttackAction and action.formula == "melee":
			print("   ⚔️ Executando ATAQUE MEELE com dash")
			# BattleScene calcula e executa diretamente
			user_view.execute_melee_attack(target_global_pos)
			
			# Aplicar slash effect se tiver
			if action.has_slash_effect():
				print("   🗡️ Aplicando slash effect")
				await get_tree().create_timer(0.5).timeout  # Esperar dash chegar
				var slash_config = action.get_slash_config()
				slash_config["z_index"] = 1000
				target_view.apply_slash_effect(slash_config)
		else:
			print("   ✨ Executando ATAQUE NORMAL")
			user_view.execute_normal_attack()
	else:
		print("❌ Wrappers não encontrados para as CharacterViews")

func _on_battle_slash_requested(action: Action, target_character: Character):
	print("🗡️ BattleScene: Slash effect recebido")
	if target_character.name in character_views:
		var target_view = character_views[target_character.name]
		var slash_config = action.get_slash_config()
		slash_config["z_index"] = 1000
		target_view.apply_slash_effect(slash_config)

func create_character_views():
	print("Criando CharacterViews...")
	clear_character_views()
	setup_areas_layout()    # 🆕 Configurar áreas primeiro
	setup_container_layout() # 🆕 Configurar rows depois
	create_enemy_views()
	create_ally_views()
	print("CharacterViews criadas: ", character_views.size())

func setup_container_layout():
	"""Configura o layout dos containers para posicionamento vertical"""
	# Configurar as rows (VBoxContainer) para distribuir os filhos verticalmente
	enemies_front_row.alignment = BoxContainer.ALIGNMENT_CENTER
	enemies_back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	allies_front_row.alignment = BoxContainer.ALIGNMENT_CENTER
	allies_back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Espaçamento vertical entre os personagens
	enemies_front_row.add_theme_constant_override("separation", 15)
	enemies_back_row.add_theme_constant_override("separation", 15)
	allies_front_row.add_theme_constant_override("separation", 15)
	allies_back_row.add_theme_constant_override("separation", 15)

func get_character_container(is_enemy: bool, position: String) -> VBoxContainer:
	"""Retorna o container correto baseado na posição e time"""
	match [is_enemy, position]:
		[true, "front"]:
			return enemies_front_row
		[true, "back"]:
			return enemies_back_row
		[false, "front"]:
			return allies_front_row
		[false, "back"]:
			return allies_back_row
		_:
			return allies_front_row  # fallback
			
func create_enemy_views():
	for character in battle.enemies_party.members:
		_create_character_display(character, true)

func create_ally_views():
	for character in battle.allies_party.members:
		_create_character_display(character, false)

func _create_character_display(character: Character, is_enemy: bool):
	if character_view_scene == null:
		print("❌ character_view_scene é null - não é possível criar CharacterView")
		return
	
	# Obter o container correto baseado na posição do personagem
	var character_container = get_character_container(is_enemy, character.position)
	
	# 🆕 CORREÇÃO: Criar um Control wrapper para o Node2D
	var wrapper = Control.new()
	wrapper.custom_minimum_size = Vector2(140, 160)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var character_view = character_view_scene.instantiate()
	
	if not character_view is CharacterView:
		print("❌ Nó instanciado não é CharacterView: ", character_view.get_class())
		return
	
	character_view.character = character
	character_view.auto_setup = true
	
	# 🆕 CORREÇÃO: Centralizar o CharacterView (Node2D) dentro do wrapper (Control)
	if character_view.has_method("get_sprite_size"):
		var sprite_size = character_view.get_sprite_size()
		character_view.position = Vector2(wrapper.custom_minimum_size.x / 2, wrapper.custom_minimum_size.y / 2)
	else:
		# Posição padrão caso não tenha o método
		character_view.position = Vector2(70, 80)  # Metade do custom_minimum_size
	
	wrapper.add_child(character_view)
	character_container.add_child(wrapper)
	
	character_views[character.name] = character_view
	
	# 🆕 CONECTAR SINAIS DO CHARACTER individualmente
	_connect_character_signals(character)
	
	print("   CharacterView criada:", character.name, "| Inimigo:", is_enemy, "| Posição:", character.position, "| Container:", character_container.name)
	
func setup_areas_layout():
	"""Configura o layout das áreas principais (HBoxContainer)"""
	# As áreas principais distribuem as rows horizontalmente
	$HBoxContainer/EnemiesArea.alignment = BoxContainer.ALIGNMENT_CENTER
	$HBoxContainer/AlliesArea.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Espaçamento entre as áreas de inimigos e aliados
	$HBoxContainer.add_theme_constant_override("separation", 100)

func clear_character_views():
	# 🆕 CORREÇÃO: Limpar todos os containers (agora temos wrappers)
	for container in [enemies_front_row, enemies_back_row, allies_front_row, allies_back_row]:
		for child in container.get_children():
			if is_instance_valid(child):
				child.queue_free()
	
	character_views.clear()
	print("CharacterViews limpas")

func _on_battle_started():
	print("Batalha iniciada")
	actions_label.text = "🎲 Batalha iniciada!"
	hide_sub_menus()

func _on_player_turn_started(character: Character):
	if battle_ended:
		return
	
	print("🎮 Iniciando turno do JOGADOR:", character.name)
	actions_label.text = "🎮 Turno de " + character.name + " [AP: %d/%d]" % [character.current_ap, character.get_max_ap()]
	current_ui_state = UIState.PLAYER_TURN
	current_player_character = character
	
	await get_tree().create_timer(0.3).timeout
	
	set_buttons_enabled(true)
	update_character_status(character)
	hide_sub_menus()
	
	print("🎮 Turno do jogador pronto - Botões habilitados")

func _on_ai_turn_started(character: Character):
	if battle_ended:
		return
	
	print("🤖 Iniciando turno da IA:", character.name)
	actions_label.text = "🤖 Turno de " + character.name
	current_ui_state = UIState.AI_TURN
	current_player_character = character
	
	set_buttons_enabled(false)
	
	await get_tree().create_timer(0.3).timeout
	
	update_character_status(character)
	
	print("🤖 Turno da IA - Botões desabilitados")

func _on_action_executed(character: Character, action: Action, target: Character):
	if battle_ended:
		return
	
	current_ui_state = UIState.ACTION_EXECUTING
	set_buttons_enabled(false)
	
	await get_tree().create_timer(0.2).timeout
	
	var action_text = "%s usa %s em %s" % [character.name, action.name, target.name]
	print("Executada:", action_text)
	actions_label.text = action_text

func _on_action_detailed_executed(character: Character, action: Action, target: Character, damage: int, healing: int, ap_used: int):
	if battle_ended:
		return
	
	var action_text = ""
	
	if action.name == "Pular Turno":
		action_text = "⏭️ %s pulou o turno" % character.name
	elif action.name == "Defender":
		action_text = "🛡️ %s está se defendendo" % character.name
	elif damage > 0:
		action_text = "💥 %s usou %s em %s e causou %d de dano!" % [character.name, action.name, target.name, damage]
	elif healing > 0:
		action_text = "❤️ %s usou %s em %s e curou %d de HP!" % [character.name, action.name, target.name, healing]
	elif damage == 0 and action is AttackAction:
		action_text = "⚔️ %s usou %s em %s, mas não causou dano" % [character.name, action.name, target.name]
	else:
		action_text = "✨ %s usou %s em %s" % [character.name, action.name, target.name]
	
	if ap_used > 0:
		action_text += " [%d AP]" % ap_used
	
	print("📝 " + action_text)
	actions_label.text = action_text
	
	# Aplicar animação de dano se necessário
	if damage > 0 and target.name in character_views:
		character_views[target.name].take_damage()
	
	# 🆕 ATUALIZAR: Se foi cura, mostrar efeito visual
	if healing > 0 and target.name in character_views:
		character_views[target.name].play_heal_effect(healing)

func _on_turn_completed(character: Character):
	if battle_ended:
		return
	
	print("✅ Turno concluído:", character.name)
	
	# 🆕 ATUALIZAÇÃO: Atualizar efeitos persistentes quando um turno é completado
	_update_all_persistent_effects()
	
	if battle.current_round > 0 and character.current_ap > 0:
		actions_label.text = "✅ %s concluiu o turno [AP: %d/%d]" % [character.name, character.current_ap, character.get_max_ap()]
	else:
		actions_label.text = "✅ %s concluiu o turno" % character.name
	
	current_ui_state = UIState.IDLE
	set_buttons_enabled(false)
	hide_sub_menus()
	
	if current_player_character == character:
		current_player_character = null

func _on_character_died(character: Character):
	print("💀 Morte:", character.name)
	actions_label.text = "💀 %s foi derrotado!" % character.name
	
	await get_tree().create_timer(0.2).timeout
	
	if character.name in character_views:
		var view = character_views[character.name]
		if is_instance_valid(view):
			view.queue_free()
		character_views.erase(character.name)
		print("   CharacterView removida:", character.name)

func _on_battle_ended(victory: bool):
	print("🏁 BattleScene: _on_battle_ended - Vitória:", victory)
	
	if victory:
		actions_label.text = "🎉 Vitória! Todos os inimigos foram derrotados!"
		print("🎉 VITORIA!")
	else:
		actions_label.text = "💔 Derrota! Todos os aliados foram derrotados!"
		print("💔 DERROTA!")
	
	battle_ended = true
	current_ui_state = UIState.IDLE
	set_buttons_enabled(false)
	
	hide_sub_menus()
	await get_tree().create_timer(2.0).timeout
	return_to_main()
	
func _on_player_action_selected():
	print("Player action selected signal received")

func _on_ui_updated():
	print("✅ UI atualizada")

func update_character_status(character: Character):
	if character == null:
		print("update_character_status: character null")
		character_icon.visible = false
		return
	
	print("Atualizando status no BottomPanel:", character.name)
	
	character_name.text = character.name
	
	if character.icon:
		character_icon.texture = character.icon
		character_icon.visible = true
	else:
		character_icon.visible = false
	
	hp_bar.max_value = character.get_max_hp()
	hp_bar.value = character.current_hp
	hp_label.text = "%d/%d" % [character.current_hp, character.get_max_hp()]
	
	ap_bar.max_value = character.get_max_ap()
	ap_bar.value = character.current_ap
	ap_label.text = "%d/%d" % [character.current_ap, character.get_max_ap()]
	
	print("   HP: %d/%d | AP: %d/%d" % [character.current_hp, character.get_max_hp(), character.current_ap, character.get_max_ap()])

func return_to_main():
	print("Voltando para a tela principal...")
	clear_character_views()
	
	var main_scene_path = "res://scenes/main/main.tscn"
	if FileAccess.file_exists(main_scene_path):
		get_tree().change_scene_to_file(main_scene_path)
		print("Cena principal carregada: " + main_scene_path)
	else:
		print("Arquivo da cena principal não encontrado: " + main_scene_path)
		# Tentar alternativas
		var alternative_paths = [
			"res://Main.tscn",
			"res://scenes/main.tscn",
		]
		
		for path in alternative_paths:
			if FileAccess.file_exists(path):
				get_tree().change_scene_to_file(path)
				print("Cena principal carregada (alternativa): " + path)
				return
		
		print("Nenhuma cena principal encontrada.")
		queue_free()

func hide_sub_menus():
	attack_menu.visible = false
	target_menu.visible = false
	print("Todos os sub-menus ocultados")

func _on_fight_pressed():
	if not can_process_player_input():
		print("❌ Botão Lutar bloqueado")
		actions_label.text = "❌ Não é possível agir agora"
		return
	print("🥊 LUTAR por:", current_player_character.name)
	actions_label.text = "🥊 " + current_player_character.name + " prepara um ataque..."
	show_attack_menu()

func _on_defend_pressed():
	if not can_process_player_input():
		print("❌ Botão Defender bloqueado")
		actions_label.text = "❌ Não é possível agir agora"
		return
	print("🛡️ DEFENDER")
	actions_label.text = "🛡️ " + current_player_character.name + " se prepara para defender"
	var defend_action = find_defend_action(current_player_character)
	if defend_action:
		print("Defender - mostrando menu de alvos")
		selected_action = defend_action
		show_target_menu(defend_action)
	else:
		print("'Defender' não encontrada")
		actions_label.text = "❌ Ação Defender não disponível"

func _on_items_pressed():
	if not can_process_player_input():
		print("❌ Botão Itens bloqueado")
		actions_label.text = "❌ Não é possível agir agora"
		return
	print("🎒 ITENS (WIP)")
	actions_label.text = "🎒 " + current_player_character.name + " abre o inventário..."

func _on_skip_pressed():
	if not can_process_player_input():
		print("❌ Botão Pular bloqueado")
		actions_label.text = "❌ Não é possível agir agora"
		return
	print("⏭️ PULAR")
	actions_label.text = "⏭️ " + current_player_character.name + " pula o turno"
	var skip_action = find_skip_action(current_player_character)
	if skip_action:
		print("Ação Pular encontrada - executando")
		execute_player_action(skip_action, current_player_character)
	else:
		print("'Pular Turno' não encontrada")
		actions_label.text = "❌ Ação Pular não disponível"

func show_attack_menu():
	if not can_process_player_input():
		return
	
	print("AttackMenu para:", current_player_character.name)
	for child in attack_buttons_container.get_children():
		child.queue_free()

	if current_player_character.combat_actions.is_empty():
		print(current_player_character.name, " sem ações de combate")
		var label_empty = Label.new()
		label_empty.text = "Sem ações disponíveis"
		attack_buttons_container.add_child(label_empty)
	else:
		var count := 0
		for action in current_player_character.combat_actions:
			var can_pay := current_player_character.has_ap_for_action(action)
			print("   ", action.name, "| custo:", action.ap_cost, "| pode pagar?:", can_pay)
			var button = create_textured_button("%s\n%d AP%s" % [action.name, action.ap_cost, "" if can_pay else " (insuficiente)"], Vector2(180, 45))
			button.disabled = not can_pay
			button.pressed.connect(_on_attack_selected.bind(action))
			attack_buttons_container.add_child(button)
			count += 1
		print("Botões criados:", count)

	attack_menu.visible = true
	target_menu.visible = false
	current_ui_state = UIState.MENU_OPEN
	print("AttackMenu aberto")

func _on_attack_selected(action: Action):
	if not can_process_player_input():
		print("❌ Seleção de ataque bloqueada")
		actions_label.text = "❌ Não é possível agir agora"
		return
	print("🎯 Selecionado:", action.name, "por", current_player_character.name)
	actions_label.text = "🎯 " + current_player_character.name + " selecionou: " + action.name
	selected_action = action
	show_target_menu(action)

func show_target_menu(action: Action):
	if not can_process_player_input():
		return
	
	print("🎯 Mostrando alvos para:", action.name)
	
	for child in target_buttons_container.get_children():
		child.queue_free()
	
	var valid_targets = get_valid_targets(action)
	
	if valid_targets.is_empty():
		print("Nenhum alvo válido para:", action.name)
		var label_empty = Label.new()
		label_empty.text = "Nenhum alvo disponível"
		target_buttons_container.add_child(label_empty)
	else:
		print("Alvos válidos encontrados:", valid_targets.size())
		for target in valid_targets:
			if target == null:
				continue
				
			var target_type_text = get_target_type_text(action.target_type)
			var status = "MORTO" if not target.is_alive() else "HP: %d/%d" % [target.current_hp, target.get_max_hp()]
			var button_text = "%s %s\n%s" % [target_type_text, target.name, status]
			
			var button = create_textured_button(button_text, Vector2(180, 35))
			button.disabled = not target.is_alive()
			button.pressed.connect(_on_target_selected.bind(target))
			target_buttons_container.add_child(button)
	
	var back_button = create_textured_button("Voltar", Vector2(180, 35))
	back_button.pressed.connect(_on_target_back_pressed)
	target_buttons_container.add_child(back_button)
	
	target_menu.visible = true
	attack_menu.visible = false
	current_ui_state = UIState.MENU_OPEN
	print("TargetMenu aberto")

func create_textured_button(text: String, size: Vector2) -> TextureButton:
	var button = TextureButton.new()
	
	var button_texture_normal = preload("res://assets/fundo-botão.png")
	var button_texture_hover = preload("res://assets/fundo-botão-hover.png")
	
	button.texture_normal = button_texture_normal
	button.texture_hover = button_texture_hover
	button.texture_pressed = button_texture_hover
	button.texture_disabled = button_texture_normal
	
	button.custom_minimum_size = size
	button.size = size
	button.stretch_mode = TextureButton.STRETCH_SCALE
	
	var label = Label.new()
	label.text = text
	
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	
	label.offset_left = 0
	label.offset_top = 0
	label.offset_right = 0
	label.offset_bottom = 0
	
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	label.add_theme_color_override("font_color", Color.BLACK)
	label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	
	button.add_child(label)
	
	return button

func get_target_type_text(target_type: String) -> String:
	match target_type:
		"enemy": return "INIMIGO"
		"ally": return "ALIADO"
		"self": return ""
		_: return "ALVO"

func get_valid_targets(action: Action) -> Array:
	if current_player_character == null:
		return []
	
	var is_player_ally = current_player_character in battle.allies_party.members
	var targets = []
	
	match action.target_type:
		"enemy":
			targets = battle.enemies_party.alive() if is_player_ally else battle.allies_party.alive()
		"ally":
			targets = battle.allies_party.alive() if is_player_ally else battle.enemies_party.alive()
		"self":
			targets = [current_player_character]
		_:
			targets = battle.enemies_party.alive() if is_player_ally else battle.allies_party.alive()
	
	print("Tipo:", action.target_type, "| Aliado?:", is_player_ally, "| Alvos:", targets.size())
	
	var valid_targets = []
	for target in targets:
		if target != null:
			valid_targets.append(target)
	
	return valid_targets

func _on_target_selected(target: Character):
	print("🎯 Tentando selecionar alvo:", target and target.name)
	
	if not can_process_player_input():
		print("❌ Seleção de alvo bloqueada")
		actions_label.text = "❌ Não é possível agir agora"
		return
	
	if target == null:
		print("❌ Alvo inválido")
		actions_label.text = "❌ Alvo inválido"
		return
	
	if selected_action == null:
		print("❌ Nenhuma ação selecionada!")
		actions_label.text = "❌ Nenhuma ação selecionada"
		return
	
	print("✅ Alvo selecionado:", target.name, "para ação:", selected_action.name)
	actions_label.text = "🎯 " + current_player_character.name + " mira em " + target.name + " com " + selected_action.name
	execute_player_action(selected_action, target)

func _on_target_back_pressed():
	if current_ui_state != UIState.MENU_OPEN:
		return
	
	print("↩️ Voltando do menu de alvos")
	if selected_action:
		if selected_action in current_player_character.combat_actions:
			show_attack_menu()
		else:
			hide_sub_menus()
			current_ui_state = UIState.PLAYER_TURN
	else:
		hide_sub_menus()
		current_ui_state = UIState.PLAYER_TURN

func execute_player_action(action: Action, target: Character):
	print("🚀 Iniciando execução de ação...")
	
	if not can_process_player_input():
		print("❌ Execução de ação bloqueada")
		actions_label.text = "❌ Não é possível agir agora"
		return
	
	if current_player_character == null:
		print("❌ Sem personagem ativo")
		actions_label.text = "❌ Sem personagem ativo"
		return
	
	if action.name != "Pular Turno" and not current_player_character.has_ap_for_action(action):
		print("❌ AP insuficiente! AP atual:", current_player_character.current_ap, "Custo necessário:", action.ap_cost)
		actions_label.text = "❌ AP insuficiente para " + action.name
		return
	
	print("✅ Executando:", action.name, "de", current_player_character.name, "em", target.name)
	print("💰 AP disponível:", current_player_character.current_ap, "/", current_player_character.get_max_ap())
	
	set_buttons_enabled(false)
	hide_sub_menus()
	current_ui_state = UIState.ACTION_EXECUTING
	
	battle.on_player_select_action(action, target)
	selected_action = null

func find_defend_action(character: Character) -> Action:
	if character == null: return null
	for action in character.basic_actions:
		if action.name == "Defender":
			return action
	return null

func find_skip_action(character: Character) -> Action:
	if character == null: return null
	
	for action in character.basic_actions:
		if action.name == "Pular Turno":
			return action
	
	for action in character.combat_actions:
		if action.name == "Pular Turno":
			return action
	
	print("❌ Ação 'Pular Turno' não encontrada")
	return null
