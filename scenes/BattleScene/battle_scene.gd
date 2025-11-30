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
enum UIState { IDLE, PLAYER_TURN, AI_TURN, ACTION_EXECUTING }
var current_ui_state: UIState = UIState.IDLE

# 🆕 NOVO: Sinal de sincronização
signal action_animations_completed(character: Character)

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
	
	_update_button_states()

func connect_buttons():
	fight_button.pressed.connect(_on_fight_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	items_button.pressed.connect(_on_items_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	print("UI Sinais conectados")

# 🆕 REFATORADO: Botões habilitados APENAS durante o turno do jogador
func _update_button_states():
	"""Atualiza o estado dos botões baseado no UIState"""
	var should_enable = (current_ui_state == UIState.PLAYER_TURN and 
						current_player_character != null and 
						current_player_character.is_alive() and 
						not battle_ended)
	
	fight_button.disabled = not should_enable
	defend_button.disabled = not should_enable
	items_button.disabled = not should_enable
	skip_button.disabled = not should_enable
	
	var status = "✅ habilitados" if should_enable else "❌ desabilitados"
	print("🎮 Botões ", status, " | UIState: ", UIState.keys()[current_ui_state])

func can_process_player_input() -> bool:
	var can_process = (not battle_ended and 
			current_player_character != null and
			current_player_character.is_alive() and
			current_ui_state == UIState.PLAYER_TURN)
	
	return can_process

func setup_battle(allies_party: Party, enemies_party: Party):
	print("Setup battle:", allies_party.name, "vs", enemies_party.name)
	battle_ended = false
	current_ui_state = UIState.IDLE
	
	battle = Battle.new()
	_connect_battle_signals()
	add_child(battle)

	# 🆕 NOVO: Passar referência do BattleScene para o Battle
	battle.set_battle_scene(self)

	battle.setup_battle(allies_party, enemies_party)
	
	await get_tree().process_frame
	
	create_character_views()
	_setup_actions_battle_scene_reference()
	
	_connect_character_support_signals()

	await get_tree().create_timer(0.5).timeout
	print("start_battle()")
	battle.start_battle()

func _setup_actions_battle_scene_reference():
	"""Configura a referência do BattleScene em todas as SupportActions E DefendActions"""
	print("🔗 Configurando referências do BattleScene nas ações...")
	
	var action_count = 0
	for character in battle.allies_party.members + battle.enemies_party.members:
		for action in character.combat_actions + character.basic_actions:
			if action is SupportAction or action is DefendAction:
				if action.has_method("set_battle_scene"):
					action.set_battle_scene(self)
					action_count += 1
					print("   ✅ ", action.name, " configurada para ", character.name)
	
	print("🎯 Total de ações configuradas: ", action_count)
	
	# 🆕 Esperar mensagem com tempo mínimo e skip por input
func _wait_for_message(min_time: float = 1.2, max_time: float = 3.5) -> void:
	var elapsed := 0.0
	
	# 1) Tempo mínimo obrigatório (não pode pular ainda)
	while elapsed < min_time:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	
	# 2) Janela em que o jogador pode pular com clique/tecla
	while elapsed < max_time:
		# Tecla de confirmar (ui_accept) ou clique do mouse
		if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			break
		
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		
func _connect_battle_signals():
	if not battle:
		print("❌ Battle não existe para conectar sinais")
		return
	
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
	
	battle.slash_effect_requested.connect(_on_battle_slash_requested)
	battle.action_animation_requested.connect(_on_battle_action_animation_requested)
	battle.attack_action_details.connect(_on_attack_action_details)
	
	# 🆕 NOVOS: Conectar eventos de defesa
	battle.dodge_event.connect(_on_dodge_event)
	battle.shield_break_event.connect(_on_shield_break_event)
	battle.reflection_event.connect(_on_reflection_event)
	battle.counter_attack_event.connect(_on_counter_attack_event)
	
	if battle.has_signal("turn_ended"):
		battle.turn_ended.connect(_on_turn_ended)
	
	print("✅ Todos os sinais do Battle conectados")

# 🆕 NOVOS HANDLERS de eventos
func _on_dodge_event(character: Character, attacker: Character):
	print("🎯 Dodge detectado!")
	actions_label.text = "🎯 %s esquivou completamente do ataque de %s!" % [character.name, attacker.name]
	
	if character.name in character_views:
		character_views[character.name].play_dodge_animation()

func _on_shield_break_event(character: Character, damage_remaining: int):
	print("💔 Escudo quebrado!")
	actions_label.text = "💔 Escudo de %s foi quebrado! (%d de dano restante)" % [character.name, damage_remaining]

func _on_reflection_event(defender: Character, attacker: Character, reflected_damage: int):
	print("🔄 Reflexão!")
	actions_label.text = "🔄 %s reflete %d de dano para %s!" % [defender.name, reflected_damage, attacker.name]

func _on_counter_attack_event(defender: Character, attacker: Character, counter_damage: int):
	print("⚔️ Contra-ataque!")
	actions_label.text = "⚔️ %s realiza um CONTRA-ATAQUE em %s, causando %d de dano!" % [defender.name, attacker.name, counter_damage]


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

func _connect_character_support_signals():
	print("🔗 Conectando sinais de suporte...")
	
	if not battle:
		print("❌ Battle não existe para conectar sinais de suporte")
		return
	
	if not "allies_party" in battle or not battle.allies_party:
		print("❌ Allies Party não disponível")
		return
	
	if not "enemies_party" in battle or not battle.enemies_party:
		print("❌ Enemies Party não disponível")
		return
	
	var connected_count = 0
	
	for character in battle.allies_party.members:
		if character and _connect_character_signals(character):
			connected_count += 1
	
	for character in battle.enemies_party.members:
		if character and _connect_character_signals(character):
			connected_count += 1
	
	print("✅ Sinais de suporte conectados para", connected_count, "personagens")

func _connect_character_signals(character: Character) -> bool:
	if not character:
		return false
	
	var connected = false
	
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

func _on_shield_applied(amount: int, duration: int, character: Character):
	print("🛡️ BattleScene: Escudo aplicado em", character.name, "amount:", amount, "duration:", duration)
	
	if character.name in character_views:
		var character_view = character_views[character.name]
		var shield_action = null
		for action in character.combat_actions + character.basic_actions:
			if action is SupportAction and action.shield_amount > 0:
				shield_action = action
				break
		
		character_view.play_shield_effect(amount, shield_action)
	
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
		character_view.play_debuff_effect(attribute, value)

func _on_debuffs_cleansed(count: int, character: Character):
	print("✨ BattleScene: Debuffs removidos de", character.name, "count:", count)
	
	if character.name in character_views:
		var character_view = character_views[character.name]
		character_view.play_cleanse_effect(count)

# 🆕 NOVO: Receber detalhes de ataques
func _on_attack_action_details(user: Character, action: Action, target: Character, action_name: String):
	print("⚔️ Ataque detectado:", action_name)

func _process_support_action(action: Action, user: Character, target: Character):
	print("🌟 BattleScene: Processando ação de suporte:", action.name)
	
	if not (action is SupportAction and target.name in character_views):
		return
	
	var support_action = action as SupportAction
	
	if support_action.buff_attribute == "defense" and support_action.buff_value > 0:
		_process_defense_action(support_action, user, target)
		return
	
	if support_action.name == "Barreira Arcana":
		_process_barreira_arcana(support_action, user, target)
		return
	
	if action.has_effect_animation():
		print("   🎬 1. Criando efeito visual principal")
		var target_wrapper = character_views[target.name].get_parent()
		if target_wrapper:
			var effect_position = target_wrapper.global_position + target_wrapper.size / 2
			var effect = action.create_effect_animation(effect_position, self)
			
			if effect:
				print("   ⏳ Aguardando efeito principal terminar...")
				await get_tree().create_timer(0.5).timeout
	
	if support_action.heal_amount > 0:
		print("   💚 2. Executando efeito de cura")
		character_views[target.name].play_heal_effect(support_action.heal_amount, support_action)
	
	if support_action.buff_attribute != "" and support_action.buff_value > 0 and support_action.buff_attribute != "defense":
		print("   📈 2. Executando efeito de buff")
		character_views[target.name].play_buff_effect(support_action.buff_attribute, support_action.buff_value, support_action)
	
	if support_action.shield_amount > 0:
		print("   🛡️ 3. Executando efeito de escudo PERSISTENTE")
		await get_tree().create_timer(0.2).timeout
		character_views[target.name].play_shield_effect(support_action.shield_amount, support_action)
	
	if support_action.cleanse_debuffs:
		print("   ✨ 2. Executando efeito de cleanse")
		character_views[target.name].play_cleanse_effect(0, support_action)
	
	if support_action.hot_amount > 0 and support_action.hot_duration > 0:
		print("   💚 2. Executando efeito de HOT")
		character_views[target.name].play_hot_effect(support_action.hot_amount, support_action.hot_duration)

func _process_barreira_arcana(action: SupportAction, user: Character, target: Character):
	print("🌟 BattleScene: Processando BARREIRA ARCANA")
	
	if target.name not in character_views:
		return
	
	if action.has_effect_animation():
		print("   🎬 1. Efeito principal da barreira")
		var target_wrapper = character_views[target.name].get_parent()
		if target_wrapper:
			var effect_position = target_wrapper.global_position + target_wrapper.size / 2
			var effect = action.create_effect_animation(effect_position, self)
			if effect:
				await get_tree().create_timer(0.6).timeout
	
	if action.buff_attribute == "defense" and action.buff_value > 0:
		print("   📈 2. Efeito de buff de defesa")
		character_views[target.name].play_buff_effect(action.buff_attribute, action.buff_value, action)
		await get_tree().create_timer(0.3).timeout
	
	if action.shield_amount > 0:
		print("   🛡️ 3. Efeito de escudo persistente")
		character_views[target.name].play_shield_effect(action.shield_amount, action)

func _process_defense_action(action: SupportAction, user: Character, target: Character):
	print("🛡️ BattleScene: Processando DEFESA com efeito persistente")
	
	if target.name not in character_views:
		return
	
	if action.has_effect_animation():
		print("   🎬 1. Efeito principal da defesa")
		var target_wrapper = character_views[target.name].get_parent()
		if target_wrapper:
			var effect_position = target_wrapper.global_position + target_wrapper.size / 2
			var effect = action.create_effect_animation(effect_position, self)
			if effect:
				await get_tree().create_timer(0.4).timeout
	
	print("   🛡️ 2. Efeito de defesa no personagem")
	character_views[target.name].play_defense_effect(action)
	
	print("   🎆 DefendAction está controlando os efeitos persistentes")

# 🆕 REFATORADO: Suporte a melee, magic e ranged com projéteis
# 🆕 REFATORADO: Suporte a melee, magic e ranged COM SLASH EFFECT
# 🆕 REFATORADO: Suporte a melee, magic e ranged COM SINCRONIZAÇÃO CORRETA
func _on_battle_action_animation_requested(user: Character, action: Action, target: Character):
	print("🎬 BattleScene: EXECUTANDO ANIMAÇÃO para ", action.name)
	print("   User:", user.name, " | Target:", target.name)
	
	if action is SupportAction:
		_process_support_action(action, user, target)
		return
	
	if user.name not in character_views or target.name not in character_views:
		print("❌ CharacterView não encontrada")
		return
	
	var user_view = character_views[user.name]
	var target_view = character_views[target.name]
	var target_wrapper = target_view.get_parent()
	var target_global_pos = target_wrapper.global_position + target_wrapper.size / 2
	
	# 🆕 Switch case completo para todos os tipos de animação
	if action is AttackAction:
		match action.animation_type:
			"melee":
				print("   ⚔️ Executando ATAQUE MEELE COM DASH + SLASH")
				user_view.execute_melee_attack(target_global_pos)
				
				# 🆕 Aguardar o dash terminar antes de aplicar slash
				await get_tree().create_timer(0.7).timeout
				
				if action.has_slash_effect():
					print("   🗡️ Aplicando slash effect no alvo")
					var slash_config = action.get_slash_config()
					slash_config["z_index"] = 1000
					target_view.apply_slash_effect(slash_config)
			
			"magic":
				print("   🔮 Executando ATAQUE MÁGICO com projétil")
				var projectile_config = {
					"sprite_frames": action.projectile_sprite_frames,
					"color": action.projectile_color,
					"scale": action.projectile_scale,
					"speed": action.projectile_speed
				}
				
				# 🆕 Executar animação e AGUARDAR
				user_view.execute_magic_attack(target_global_pos, projectile_config)
				await user_view.magic_attack_finished
				
				# 🆕 DEPOIS que projétil chegar, aplicar slash
				if action.has_slash_effect():
					print("   🗡️ Aplicando slash effect no alvo após impacto")
					var slash_config = action.get_slash_config()
					slash_config["z_index"] = 1000
					target_view.apply_slash_effect(slash_config)
				
			"ranged":
				print("   🏹 Executando ATAQUE RANGED com projétil")
				var projectile_config = {
					"sprite_frames": action.projectile_sprite_frames,
					"color": action.projectile_color,
					"scale": action.projectile_scale,
					"speed": action.projectile_speed
				}
				
				# 🆕 Executar animação e AGUARDAR
				user_view.execute_ranged_attack(target_global_pos, projectile_config)
				await user_view.ranged_attack_finished
				
				# 🆕 DEPOIS que projétil chegar, aplicar slash
				if action.has_slash_effect():
					print("   🗡️ Aplicando slash effect no alvo após impacto")
					var slash_config = action.get_slash_config()
					slash_config["z_index"] = 1000
					target_view.apply_slash_effect(slash_config)
			
			_:
				print("   ✨ Executando ATAQUE NORMAL")
				user_view.execute_normal_attack()
	else:
		print("   ✨ Executando AÇÃO NORMAL")
		user_view.execute_normal_attack()


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
	setup_areas_layout()
	setup_container_layout()
	create_enemy_views()
	create_ally_views()
	print("CharacterViews criadas: ", character_views.size())

func setup_container_layout():
	"""Configura o layout dos containers para posicionamento vertical"""
	enemies_front_row.alignment = BoxContainer.ALIGNMENT_CENTER
	enemies_back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	allies_front_row.alignment = BoxContainer.ALIGNMENT_CENTER
	allies_back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	
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
			return allies_front_row

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
	
	var character_container = get_character_container(is_enemy, character.position)
	
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
	
	if character_view.has_method("get_sprite_size"):
		var sprite_size = character_view.get_sprite_size()
		character_view.position = Vector2(wrapper.custom_minimum_size.x / 2, wrapper.custom_minimum_size.y / 2)
	else:
		character_view.position = Vector2(70, 80)
	
	wrapper.add_child(character_view)
	character_container.add_child(wrapper)
	
	character_views[character.name] = character_view
	
	_connect_character_signals(character)
	
	print("   CharacterView criada:", character.name, "| Inimigo:", is_enemy, "| Posição:", character.position, "| Container:", character_container.name)

func setup_areas_layout():
	"""Configura o layout das áreas principais (HBoxContainer)"""
	$HBoxContainer/EnemiesArea.alignment = BoxContainer.ALIGNMENT_CENTER
	$HBoxContainer/AlliesArea.alignment = BoxContainer.ALIGNMENT_CENTER
	$HBoxContainer.add_theme_constant_override("separation", 100)

func clear_character_views():
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
		print("❌ _on_player_turn_started rejeitado - batalha já acabou")
		return
	
	print("🎮 Iniciando turno do JOGADOR:", character.name)
	
	current_player_character = character
	current_ui_state = UIState.PLAYER_TURN
	
	actions_label.text = "🎮 Turno de " + character.name + " [AP: %d/%d]" % [character.current_ap, character.get_max_ap()]
	
	await get_tree().create_timer(0.3).timeout
	
	update_character_status(character)
	hide_sub_menus()
	_update_button_states()
	
	print("🎮 Turno do jogador pronto - Botões habilitados")

func _on_ai_turn_started(character: Character):
	if battle_ended:
		return
	
	print("🤖 Iniciando turno da IA:", character.name)
	actions_label.text = "🤖 Turno de " + character.name
	current_ui_state = UIState.AI_TURN
	current_player_character = character
	
	_update_button_states()
	
	await get_tree().create_timer(0.3).timeout
	
	update_character_status(character)
	
	print("🤖 Turno da IA")

func _on_action_executed(character: Character, action: Action, target: Character):
	if battle_ended:
		return
	
	await get_tree().create_timer(0.2).timeout
	
	var action_text = "%s usa %s em %s" % [character.name, action.name, target.name]
	print("Executada:", action_text)
	actions_label.text = action_text
	
	await get_tree().create_timer(0.5).timeout

# 🆕 REFATORADO: Mostra detalhes completos com sinais de ação
# 🆕 REFATORADO: Mostrar detalhes de ações de suporte E defesa
func _on_action_detailed_executed(character: Character, action: Action, target: Character, damage: int, healing: int, ap_used: int):
	if battle_ended:
		return
	
	var action_text = ""
	
	# ⚔️ ATAQUE: Mostrar dano
	if damage > 0:
		action_text = "💥 %s usa %s em %s e causa %d de dano!" % [character.name, action.name, target.name, damage]
	
	# 🛡️ DEFESA: Mostrar detalhes de defesa
	elif action is DefendAction:
		var defense_bonus = int(character.get_attribute("constitution") * action.defense_multiplier)
		var dodge_percent = int(action.dodge_chance_bonus * 100)
		var reflection_percent = int(action.damage_reflection * 100)
		var counter_percent = int(action.counter_attack_chance * 100)
		
		action_text = "🛡️ %s ativa POSTURA DEFENSIVA MÁXIMA! [+%d DEF, +%d%% ESQ, +%d%% REF, %d%% CONTRA]" % [
			character.name, 
			defense_bonus, 
			dodge_percent,
			reflection_percent,
			counter_percent
		]
	
	# ✨ SUPORTE: Mostrar múltiplos efeitos
	elif action is SupportAction:
		var support_action = action as SupportAction
		var effects = []
		
		# Cura
		if support_action.heal_amount > 0 and healing > 0:
			effects.append("Cura: +%d HP" % healing)
		
		# Buff de atributo
		if support_action.buff_attribute != "" and support_action.buff_value > 0:
			var attr_name = _get_attribute_display_name(support_action.buff_attribute)
			effects.append("Buff: +%d %s (%d turnos)" % [support_action.buff_value, attr_name, support_action.buff_duration])
		
		# Escudo
		if support_action.shield_amount > 0:
			effects.append("Escudo: +%d (%d turnos)" % [support_action.shield_amount, support_action.shield_duration])
		
		# Cleanse
		if support_action.cleanse_debuffs:
			effects.append("Purificação: Remove debuffs")
		
		# HOT
		if support_action.hot_amount > 0:
			effects.append("Cura Contínua: +%d HP (%d turnos)" % [support_action.hot_amount, support_action.hot_duration])
		
		if effects.size() > 0:
			action_text = "✨ %s usa %s em %s: [%s]" % [character.name, action.name, target.name, ", ".join(effects)]
		else:
			action_text = "✨ %s usa %s em %s" % [character.name, action.name, target.name]
	
	# Pular turno
	elif action.name == "Pular Turno":
		action_text = "⏭️ %s pulou o turno" % character.name
	
	# Fallback
	elif healing > 0:
		action_text = "❤️ %s usa %s em %s e cura %d de HP!" % [character.name, action.name, target.name, healing]
	elif damage == 0 and action is AttackAction:
		action_text = "⚔️ %s usa %s em %s, mas não causa dano" % [character.name, action.name, target.name]
	else:
		action_text = "✨ %s usa %s em %s" % [character.name, action.name, target.name]
	
	# Adicionar custo de AP
	if ap_used > 0:
		action_text += " [%d AP]" % ap_used
	
	print("📝 " + action_text)
	actions_label.text = action_text
	
	await get_tree().create_timer(0.8).timeout
	
	# Animações visuais
	print("📝 " + action_text)
	actions_label.text = action_text
	
	await get_tree().create_timer(0.8).timeout
	
	await _wait_for_message(1.2, 3.5)
	
	if damage > 0 and target.name in character_views:
		character_views[target.name].take_damage()
	
	if healing > 0 and target.name in character_views:
		character_views[target.name].play_heal_effect(healing)
	
	# Aqui já não precisa mais de outro delay fixo;
	# o texto ficou tempo suficiente na tela
	
	if ap_used > 0:
		await _animate_ap_reduction(character, ap_used)
	
	print("🎬 FINALIZANDO ANIMAÇÕES para:", character.name)
	action_animations_completed.emit(character)

# 🆕 NOVO: Traduzir nome dos atributos
func _get_attribute_display_name(attribute: String) -> String:
	match attribute:
		"strength": return "Força"
		"constitution": return "Constituição"
		"agility": return "Agilidade"
		"intelligence": return "Inteligência"
		"defense": return "Defesa"
		"attack": return "Ataque"
		"speed": return "Velocidade"
		"magic": return "Magia"
		"max_hp": return "Vida Máxima"
		"critical_chance": return "Crítico"
		_: return attribute


func _animate_ap_reduction(character: Character, ap_used: int):
	print("💰 Animando redução de AP: ", ap_used, " AP")
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	var start_ap = character.current_ap + ap_used
	var end_ap = character.current_ap
	
	tween.tween_method(func(value):
		ap_bar.value = value
		ap_label.text = "%d/%d" % [int(value), character.get_max_ap()]
	, float(start_ap), float(end_ap), 0.6)
	
	await tween.finished
	
	print("   ✅ Redução de AP concluída")

func _on_turn_completed(character: Character):
	if battle_ended:
		return
	
	print("✅ Turno concluído:", character.name)
	
	_update_all_persistent_effects()
	
	if battle.current_round > 0 and character.current_ap > 0:
		actions_label.text = "✅ %s concluiu o turno [AP: %d/%d]" % [character.name, character.current_ap, character.get_max_ap()]
	else:
		actions_label.text = "✅ %s concluiu o turno" % character.name
	
	await get_tree().create_timer(0.8).timeout
	
	# 🆕 CORREÇÃO: NÃO chamar _update_button_states() aqui
	# Os botões serão atualizados quando o próximo turno começar
	
	# Apenas limpar submenus se foi IA
	if character not in battle.allies_party.members:
		hide_sub_menus()

func _on_character_died(character: Character):
	print("💀 Morte:", character.name)
	actions_label.text = "💀 %s foi derrotado!" % character.name
	
	for action in character.combat_actions + character.basic_actions:
		if action is DefendAction:
			action.update_defense_effects(character)
	
	await get_tree().create_timer(0.8).timeout
	
	if character.name in character_views:
		var view = character_views[character.name]
		if is_instance_valid(view):
			view.queue_free()
		character_views.erase(character.name)
		print("   CharacterView removida:", character.name)
func _on_battle_ended(victory: bool):
	print("BattleScene _on_battle_ended - Vitória:", victory)
	
	# Limpar efeitos persistentes de defesa
	print("Limpando todos os efeitos persistentes...")
	for character in battle.allies_party.members + battle.enemies_party.members:
		for action in character.combat_actions + character.basic_actions:
			if action is DefendAction:
				action.clear_all_defense_effects()
	
	if victory:
		actions_label.text = "Vitória! Todos os inimigos foram derrotados!"
		print("VITÓRIA!")
		
		# Aqui você pode depois chamar uma tela de vitória se quiser
	else:
		actions_label.text = "Derrota! Todos os aliados foram derrotados!"
		print("DERROTA! Carregando tela de derrota...")
		
		# 🆕 CARREGAR CENA DE DERROTA
		var lose_scene_path := "res://scenes/Lose/lose.tscn"
		if FileAccess.file_exists(lose_scene_path):
			await get_tree().create_timer(1.5).timeout  # pequeno delay opcional
			get_tree().change_scene_to_file(lose_scene_path)
		else:
			print("❌ Arquivo da cena de derrota não encontrado:", lose_scene_path)
	
	battle_ended = true
	current_ui_state = UIState.IDLE
	current_player_character = null
	_update_button_states()
	
	await get_tree().create_timer(1.0).timeout
	hide_sub_menus()


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
			
			# 🆕 NOVO: Conectar hover signals
			button.mouse_entered.connect(_on_target_button_hover.bind(target))
			button.mouse_exited.connect(_on_target_button_unhover)
			
			target_buttons_container.add_child(button)
	
	var back_button = create_textured_button("Voltar", Vector2(180, 35))
	back_button.pressed.connect(_on_target_back_pressed)
	target_buttons_container.add_child(back_button)
	
	target_menu.visible = true
	attack_menu.visible = false
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
	if current_ui_state != UIState.PLAYER_TURN:
		return
	
	print("↩️ Voltando do menu de alvos")
	if selected_action:
		if selected_action in current_player_character.combat_actions:
			show_attack_menu()
		else:
			hide_sub_menus()
	else:
		hide_sub_menus()

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
	
	current_ui_state = UIState.ACTION_EXECUTING
	_update_button_states()
	hide_sub_menus()
	
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

# 🆕 NOVO: Funções de highlight de alvo
func _on_target_button_hover(target: Character):
	"""Destacar alvo quando mouse entra no botão"""
	print("🔆 Destacando alvo:", target.name)
	
	if target.name in character_views:
		highlighted_target = target
		var character_view = character_views[target.name]
		_apply_target_highlight(character_view)
		target_highlighted.emit(target)

func _on_target_button_unhover():
	"""Remover destaque quando mouse sai do botão"""
	if highlighted_target:
		print("🔆 Removendo destaque de:", highlighted_target.name)
		
		if highlighted_target.name in character_views:
			var character_view = character_views[highlighted_target.name]
			_remove_target_highlight(character_view)
			target_unhighlighted.emit(highlighted_target)
		
		highlighted_target = null

func _apply_target_highlight(character_view: Node):
	"""Aplicar linha branca ao redor do personagem"""
	if character_view.has_meta("highlight_node"):
		return  # Já tem highlight
	
	var highlight = ColorRect.new()
	highlight.name = "TargetHighlight"
	highlight.color = Color.WHITE
	highlight.color.a = 0.3
	
	var sprite_size = Vector2(140, 160)
	highlight.size = sprite_size
	highlight.position = Vector2(-sprite_size.x / 2, -sprite_size.y / 2)
	highlight.z_index = 1000
	
	character_view.add_child(highlight)
	character_view.set_meta("highlight_node", highlight)
	
	# Animar piscando
	var tween = character_view.create_tween()
	tween.set_loops()
	tween.tween_property(highlight, "color:a", 0.0, 0.5)
	tween.tween_property(highlight, "color:a", 0.3, 0.5)

func _remove_target_highlight(character_view: Node):
	if character_view.has_meta("highlight_node"):
		var highlight = character_view.get_meta("highlight_node")
		
		if character_view.has_meta("highlight_tween"):
			var tween = character_view.get_meta("highlight_tween")
			tween.kill()
			character_view.remove_meta("highlight_tween")
		
		if is_instance_valid(highlight):
			highlight.queue_free()
		
		character_view.remove_meta("highlight_node")
		print("🔆 Destaque removido")

# 🆕 NOVO: Referência do alvo destacado
var highlighted_target: Character = null

# 🆕 NOVO: Sinais de highlight
signal target_highlighted(character: Character)
signal target_unhighlighted(character: Character)
