extends Control

# Áreas de batalha (topo)
@onready var enemies_front_row = $HBoxContainer/EnemiesArea/EnemyFrontRow
@onready var enemies_back_row  = $HBoxContainer/EnemiesArea/EnemyBackRow
@onready var allies_front_row  = $HBoxContainer/AlliesArea/AllyFrontRow
@onready var allies_back_row   = $HBoxContainer/AlliesArea/AllyBackRow

# Status do personagem ativo (no BottomPanel/HBoxContainer/CharacterStatus)
@onready var character_icon = $CanvasLayer/BottomPanel/HBoxContainer/CharacterStatus/CharacterIcon
@onready var character_name = $CanvasLayer/BottomPanel/HBoxContainer/CharacterStatus/VBoxContainer/CharacterName
@onready var hp_bar        = $CanvasLayer/BottomPanel/HBoxContainer/CharacterStatus/VBoxContainer/HPBar
@onready var hp_label      = $CanvasLayer/BottomPanel/HBoxContainer/CharacterStatus/VBoxContainer/HPBar/HPLabel
@onready var ap_bar        = $CanvasLayer/BottomPanel/HBoxContainer/CharacterStatus/VBoxContainer/APBar
@onready var ap_label      = $CanvasLayer/BottomPanel/HBoxContainer/CharacterStatus/VBoxContainer/APBar/APLabel

# Menu de comandos (no BottomPanel/HBoxContainer/CommandMenu)
@onready var fight_button  = $CanvasLayer/BottomPanel/HBoxContainer/CommandMenu/FightButton
@onready var defend_button = $CanvasLayer/BottomPanel/HBoxContainer/CommandMenu/DefendButton
@onready var items_button  = $CanvasLayer/BottomPanel/HBoxContainer/CommandMenu/ItemsButton
@onready var skip_button   = $CanvasLayer/BottomPanel/HBoxContainer/CommandMenu/SkipButton

# Sub-menus (dentro do mesmo HBoxContainer)
@onready var attack_menu              = $CanvasLayer/BottomPanel/HBoxContainer/AttackMenu
@onready var attack_buttons_container = $CanvasLayer/BottomPanel/HBoxContainer/AttackMenu/AttackButtons
@onready var target_menu              = $CanvasLayer/BottomPanel/HBoxContainer/TargetMenu
@onready var target_buttons_container = $CanvasLayer/BottomPanel/HBoxContainer/TargetMenu/TargetButtons

@export var character_view_scale: Vector2 = Vector2(1, 1)
@export var max_character_size: Vector2 = Vector2(180, 220)

# Sistema de batalha
var battle: Battle
var character_displays := {}
var character_views := {}
var current_player_character: Character = null
var selected_action: Action = null
var battle_ended: bool = false
var waiting_for_update: bool = false

# Configuração de delays
@export var turn_start_delay: float = 0.3
@export var action_execution_delay: float = 0.2
@export var ui_update_delay: float = 0.1

# Configuração das CharacterViews
@export var character_view_scene: PackedScene = preload("res://scenes/character_view/CharacterView.tscn")

func _ready():
	print("=== 🎮 BattleScene READY ===")
	_setup_root_layout()
	setup_ui()
	connect_buttons()

func _setup_root_layout():
	set_anchors_preset(Control.PRESET_FULL_RECT)

func setup_ui():
	attack_menu.visible = false
	attack_buttons_container.visible = false
	target_menu.visible = false
	target_buttons_container.visible = false
	
	fight_button.text = "🗡️ LUTAR"
	defend_button.text = "🛡️ DEFENDER"
	items_button.text  = "📦 ITENS"
	skip_button.text   = "⏭️ PULAR"
	
	character_icon.texture = null
	character_icon.visible = false
	
	print("UI ▶️ Botões ok; Menus ocultos")

func connect_buttons():
	fight_button.pressed.connect(_on_fight_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	items_button.pressed.connect(_on_items_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	print("UI 🔗 Sinais conectados")

func setup_battle(allies_party: Party, enemies_party: Party):
	print("⚔️ Setup battle:", allies_party.name, "vs", enemies_party.name)
	battle_ended = false
	waiting_for_update = false
	
	battle = Battle.new()
	add_child(battle)

	# Conecta sinais
	battle.battle_started.connect(_on_battle_started)
	battle.player_turn_started.connect(_on_player_turn_started)
	battle.action_executed.connect(_on_action_executed)
	battle.turn_completed.connect(_on_turn_completed)
	battle.character_died.connect(_on_character_died)
	battle.battle_ended.connect(_on_battle_ended)
	battle.player_action_selected.connect(_on_player_action_selected)

	battle.setup_battle(allies_party, enemies_party)
	
	# Cria as CharacterViews e displays
	create_character_views()
	create_character_displays()

	await get_tree().create_timer(0.5).timeout
	print("▶️ start_battle()")
	battle.start_battle()

func create_character_views():
	print("👥 Criando CharacterViews...")
	clear_character_views()
	create_enemy_views()
	create_ally_views()
	print("✅ CharacterViews criadas: ", character_views.size())

func create_enemy_views():
	for character in battle.enemies_party.members:
		_create_character_display(character, true)

func create_ally_views():
	for character in battle.allies_party.members:
		_create_character_display(character, false)

func _create_character_display(character: Character, is_enemy: bool):
	var character_container = create_character_container()
	var character_view = create_character_view(character, is_enemy)  # Passe is_enemy aqui
	var health_bar = create_health_bar(character)
	
	character_container.add_child(character_view)
	character_container.add_child(health_bar)
	
	# Posiciona nos containers corretos
	if character.position == "front":
		if is_enemy:
			enemies_front_row.add_child(character_container)
		else:
			allies_front_row.add_child(character_container)
	else:
		if is_enemy:
			enemies_back_row.add_child(character_container)
		else:
			allies_back_row.add_child(character_container)
	
	character_views[character.name] = character_view
	character_displays[character.name] = health_bar
	print("   CharacterView criada:", character.name, "| Inimigo:", is_enemy)

func create_character_container() -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(120, 160)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return container

func create_character_view(character: Character, is_enemy: bool) -> CharacterView:
	var character_view = character_view_scene.instantiate()
	character_view.character = character
	character_view.character_scale = character_view_scale
	character_view.max_character_size = max_character_size
	character_view.auto_setup = true
	
	character_view.get_node("Icon").visible = false
	
	# CALCULAR POSIÇÃO COM PERSPECTIVA
	var position_x = calculate_character_position(character, is_enemy)
	
	# Posição do personagem (com perspectiva)
	character_view.position = Vector2(position_x, 85)
	
	print("   📍 Posicionando", character.name, "em x:", position_x, "| Inimigo:", is_enemy)
	
	return character_view

func calculate_character_position(character: Character, is_enemy: bool) -> float:
	var base_x = 60  # Posição base central
	var spacing = 60  # Espaçamento entre personagens
	
	# Encontrar o índice do personagem na sua fileira
	var party_members = []
	if is_enemy:
		party_members = battle.enemies_party.members.filter(func(c): return c.position == character.position)
	else:
		party_members = battle.allies_party.members.filter(func(c): return c.position == character.position)
	
	var character_index = party_members.find(character)
	
	if character_index == -1:
		return base_x
	
	if is_enemy:
		# Inimigos: posição crescente para a DIREITA (mais à direita conforme o índice aumenta)
		return base_x - (character_index * spacing)
	else:
		# Aliados: posição crescente para a ESQUERDA (mais à esquerda conforme o índice aumenta)  
		return base_x + (character_index * spacing)

func create_health_bar(character: Character) -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(100, 15)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Barra de fundo
	var background = ColorRect.new()
	background.size = Vector2(100, 10)
	background.position = Vector2(0, 0)
	background.color = Color(0.2, 0.2, 0.2, 0.9)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Barra de vida
	var health_bar = ColorRect.new()
	health_bar.size = Vector2(100, 10)
	health_bar.position = Vector2(0, 0)
	health_bar.color = Color.GREEN
	health_bar.name = "HealthBar"
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	container.add_child(background)
	container.add_child(health_bar)
	
	update_health_bar(character, health_bar)
	
	# Posição da barra (centro superior do container)
	container.position = Vector2(10, 100)
	
	return container

func update_health_bar(character: Character, health_bar: ColorRect):
	if not character or not health_bar:
		return
	
	var health_ratio = float(character.current_hp) / float(character.get_max_hp())
	health_ratio = max(0, health_ratio)
	
	health_bar.size.x = 100 * health_ratio
	
	if health_ratio > 0.6:
		health_bar.color = Color.GREEN
	elif health_ratio > 0.3:
		health_bar.color = Color.YELLOW
	else:
		health_bar.color = Color.RED

func clear_character_views():
	for view in character_views.values():
		if is_instance_valid(view):
			view.queue_free()
	character_views.clear()
	print("🧹 CharacterViews limpas")

func create_character_displays():
	clear_character_displays()
	print("📊 Criando barras de vida...")
	# As barras já são criadas junto com as views agora

func clear_character_displays():
	for display in character_displays.values():
		if is_instance_valid(display):
			display.queue_free()
	character_displays.clear()
	print("🧹 Barras de vida limpas")

func update_character_displays():
	for character in battle.allies_party.members + battle.enemies_party.members:
		if character.name in character_displays:
			var display = character_displays[character.name]
			var health_bar = display.get_node("HealthBar") as ColorRect
			update_health_bar(character, health_bar)

# ===== Eventos/sinais =====

func _on_battle_started():
	print("🎲 Batalha iniciada")
	hide_sub_menus()

func _on_player_turn_started(character: Character):
	if battle_ended:
		return
	
	waiting_for_update = true
	
	print("⏳ Iniciando turno de:", character.name)
	
	await get_tree().create_timer(turn_start_delay).timeout
	await update_all_ui_elements()
	
	waiting_for_update = false
	
	current_player_character = character
	print("🕐 Turno:", character.name, "| AP:", character.current_ap, "/", character.get_max_ap(), "| Ações:", character.combat_actions.size())
	_print_actions(character)
	
	update_character_status(character)
	highlight_active_character(character.name)
	hide_sub_menus()
	print("🧭 CommandMenu pronto; Menus fechados")

func update_all_ui_elements():
	print("🔄 Atualizando toda a UI...")
	update_character_displays()
	
	if current_player_character:
		update_character_status(current_player_character)
	
	await get_tree().create_timer(ui_update_delay).timeout
	print("✅ UI atualizada")

func update_character_status(character: Character):
	if character == null:
		print("⚠️ update_character_status: character null")
		character_icon.visible = false
		return
	
	print("📊 Atualizando status no BottomPanel:", character.name)
	
	character_name.text = character.name
	
	if character.icon:
		character_icon.texture = character.icon
		character_icon.visible = true
		print("   🖼️ Ícone carregado:", character.icon.resource_path)
	else:
		character_icon.visible = false
		print("   ⚠️ Personagem sem ícone")
	
	hp_bar.max_value = character.get_max_hp()
	hp_bar.value = character.current_hp
	hp_label.text = "%d/%d" % [character.current_hp, character.get_max_hp()]
	
	ap_bar.max_value = character.get_max_ap()
	ap_bar.value = character.current_ap
	ap_label.text = "%d/%d" % [character.current_ap, character.get_max_ap()]
	
	print("   ❤️ HP: %d/%d | ⚡ AP: %d/%d" % [character.current_hp, character.get_max_hp(), character.current_ap, character.get_max_ap()])

func _print_actions(character: Character):
	if character == null:
		print("⚠️ _print_actions: character null")
		return
	if character.combat_actions.is_empty():
		print("⚠️", character.name, "não possui combat_actions")
	else:
		print("📜 Ações de", character.name, ":")
		for a in character.combat_actions:
			var ok_ap = character.has_ap_for_action(a)
			print("  •", a.name, "| custo:", a.ap_cost, "| tem AP?:", ok_ap)

func _on_action_executed(character: Character, action: Action, target: Character):
	if battle_ended:
		return
	
	await get_tree().create_timer(action_execution_delay).timeout
		
	var action_text = "%s usa %s em %s" % [character.name, action.name, target.name]
	print("✅ Executada:", action_text)
	
	if character.name in character_views:
		var attacker_view = character_views[character.name]
		character.request_attack_animation("melee")
	
	if target.name in character_views:
		var target_view = character_views[target.name]
		if action.target_type == "enemy":
			target.request_damage_animation()
	
	await update_all_ui_elements()

func _on_turn_completed(character: Character):
	if battle_ended:
		return
	
	await get_tree().create_timer(action_execution_delay).timeout
		
	print("⏭️ Turno concluído:", character.name)
	remove_character_highlight(character.name)
	hide_sub_menus()
	
	await update_all_ui_elements()

func _on_character_died(character: Character):
	print("💀 Morte:", character.name)
	
	await get_tree().create_timer(action_execution_delay).timeout
	
	if character.name in character_views:
		var view = character_views[character.name]
		if is_instance_valid(view):
			view.queue_free()
		character_views.erase(character.name)
		print("   👻 CharacterView removida:", character.name)
	
	if character.name in character_displays:
		var display = character_displays[character.name]
		if is_instance_valid(display):
			display.visible = false
		character_displays.erase(character.name)
		print("   👻 Display UI removido:", character.name)

func _on_battle_ended(victory: bool):
	print("🎯 BattleScene: _on_battle_ended chamado - Vitória:", victory)
	battle_ended = true
	waiting_for_update = true
	
	if victory:
		print("🎉 VITÓRIA!")
		for character in battle.allies_party.members:
			if character.name in character_views:
				character.request_victory_animation()
	else:
		print("💔 DERROTA!")
		for character in battle.allies_party.members:
			if character.name in character_views:
				character.request_defeat_animation()
	
	hide_sub_menus()
	
	await get_tree().create_timer(2.0).timeout
	return_to_main()

func _on_player_action_selected():
	print("🔄 Player action selected signal received")

func return_to_main():
	print("🏠 Voltando para a tela principal...")
	clear_character_views()
	clear_character_displays()
	
	var main_scene_path = "res://scenes/main/main.tscn"
	if FileAccess.file_exists(main_scene_path):
		get_tree().change_scene_to_file(main_scene_path)
		print("✅ Cena principal carregada: " + main_scene_path)
	else:
		print("❌ Arquivo da cena principal não encontrado: " + main_scene_path)
		try_alternative_scenes()

func try_alternative_scenes():
	var alternative_paths = [
		"res://Main.tscn",
		"res://scenes/main.tscn",
		"res://Scenes/Main.tscn",
		"res://menu_principal.tscn",
		"res://MenuPrincipal.tscn"
	]
	
	for path in alternative_paths:
		if FileAccess.file_exists(path):
			get_tree().change_scene_to_file(path)
			print("✅ Cena principal carregada (alternativa): " + path)
			return
	
	print("❌ Nenhuma cena principal encontrada. Verifique o nome do arquivo.")
	queue_free()

# ===== Menus =====

func show_command_menu():
	if waiting_for_update:
		return
	hide_sub_menus()
	print("🧭 CommandMenu visível; Sub-menus ocultos")

func hide_sub_menus():
	attack_menu.visible = false
	attack_buttons_container.visible = false
	target_menu.visible = false
	target_buttons_container.visible = false
	print("🙈 Todos os sub-menus ocultados")

func _on_fight_pressed():
	if battle_ended or waiting_for_update:
		return
	print("🗡️ LUTAR por:", current_player_character and current_player_character.name)
	show_attack_menu()

func _on_defend_pressed():
	if battle_ended or waiting_for_update:
		return
	print("🛡️ DEFENDER")
	if current_player_character == null:
		print("⚠️ DEFENDER: sem personagem ativo")
		return
	
	var defend_action = find_defend_action(current_player_character)
	if defend_action:
		print("🎯 Defender - mostrando menu de alvos")
		selected_action = defend_action
		show_target_menu(defend_action)
	else:
		print("⚠️ 'Defender' não encontrada")

func _on_items_pressed():
	if battle_ended or waiting_for_update:
		return
	print("📦 ITENS (WIP)")

func _on_skip_pressed():
	if battle_ended or waiting_for_update:
		return
	print("⏭️ PULAR")
	if current_player_character == null:
		print("⚠️ PULAR: sem personagem ativo")
		return
	var skip_action = find_skip_action(current_player_character)
	if skip_action:
		execute_player_action(skip_action, current_player_character)
	else:
		print("⚠️ 'Pular Turno' não encontrada")

func show_attack_menu():
	if battle_ended or waiting_for_update:
		return
	print("📂 AttackMenu para:", current_player_character and current_player_character.name)
	for child in attack_buttons_container.get_children():
		child.queue_free()

	if current_player_character == null:
		print("⚠️ show_attack_menu: current_player_character é null")
		attack_menu.visible = false
		attack_buttons_container.visible = false
		return

	if current_player_character.combat_actions.is_empty():
		print("⚠️", current_player_character.name, "sem ações de combate")
		var label_empty = Label.new()
		label_empty.text = "Sem ações disponíveis"
		attack_buttons_container.add_child(label_empty)
	else:
		var count := 0
		for action in current_player_character.combat_actions:
			var can_pay := current_player_character.has_ap_for_action(action)
			print("   ➕", action.name, "| custo:", action.ap_cost, "| AP:", current_player_character.current_ap, "| pode pagar?:", can_pay)
			var button = Button.new()
			var suffix := "" if can_pay else " (insuficiente)"
			button.text = "%s\n%d AP%s" % [action.name, action.ap_cost, suffix]
			button.disabled = not can_pay
			button.custom_minimum_size = Vector2(220, 56)
			button.pressed.connect(_on_attack_selected.bind(action))
			attack_buttons_container.add_child(button)
			count += 1
		print("📋 Botões criados:", count)

	attack_menu.visible = true
	attack_buttons_container.visible = true
	target_menu.visible = false
	print("👁️ AttackMenu:", attack_menu.visible, "| TargetMenu:", target_menu.visible)

func _on_attack_selected(action: Action):
	if battle_ended or waiting_for_update:
		return
	print("🎯 Selecionado:", action.name, "por", current_player_character and current_player_character.name)
	selected_action = action
	show_target_menu(action)

func show_target_menu(action: Action):
	if battle_ended or waiting_for_update:
		return
	print("🎯 Mostrando alvos para:", action.name)
	
	for child in target_buttons_container.get_children():
		child.queue_free()
	
	var valid_targets = get_valid_targets(action)
	
	if valid_targets.is_empty():
		print("⚠️ Nenhum alvo válido para:", action.name)
		var label_empty = Label.new()
		label_empty.text = "Nenhum alvo disponível"
		target_buttons_container.add_child(label_empty)
	else:
		print("🎯 Alvos válidos encontrados:", valid_targets.size())
		for target in valid_targets:
			if target == null:
				print("⚠️ Target inválido (null) encontrado, pulando...")
				continue
				
			var button = Button.new()
			var target_type_icon = get_target_type_icon(action.target_type)
			var status = "💀 MORTO" if not target.is_alive() else "❤️ HP: %d/%d" % [target.current_hp, target.get_max_hp()]
			
			button.text = "%s %s\n%s" % [target_type_icon, target.name, status]
			button.custom_minimum_size = Vector2(220, 56)
			button.disabled = not target.is_alive()
			button.pressed.connect(_on_target_selected.bind(target))
			target_buttons_container.add_child(button)
			print("   ➕ Alvo:", target.name, "| Vivo:", target.is_alive())
	
	var back_button = Button.new()
	back_button.text = "⬅️ Voltar"
	back_button.custom_minimum_size = Vector2(220, 40)
	back_button.pressed.connect(_on_target_back_pressed)
	target_buttons_container.add_child(back_button)
	
	target_menu.visible = true
	target_buttons_container.visible = true
	attack_menu.visible = false
	
	print("👁️ TargetMenu:", target_menu.visible, "| AttackMenu:", attack_menu.visible)

func get_target_type_icon(target_type: String) -> String:
	match target_type:
		"enemy": return "💀"
		"ally": return "🎯"
		"self": return "⭐"
		_: return "❓"

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
	
	print("🎯 Tipo:", action.target_type, "| Aliado?:", is_player_ally, "| Alvos:", targets.size())
	
	var valid_targets = []
	for target in targets:
		if target != null:
			valid_targets.append(target)
	
	return valid_targets

func _on_target_selected(target: Character):
	if battle_ended or waiting_for_update:
		return
	if target == null:
		print("❌ Alvo inválido (null) para ação:", selected_action.name if selected_action else "Nenhuma ação")
		return
	
	if selected_action == null:
		print("❌ Nenhuma ação selecionada!")
		return
	
	print("🎯 Alvo selecionado:", target.name, "para ação:", selected_action.name)
	execute_player_action(selected_action, target)

func _on_target_back_pressed():
	if battle_ended or waiting_for_update:
		return
	print("⬅️ Voltando do menu de alvos")
	if selected_action:
		if selected_action in current_player_character.combat_actions:
			show_attack_menu()
		else:
			hide_sub_menus()
	else:
		hide_sub_menus()

func execute_player_action(action: Action, target: Character):
	if battle_ended or waiting_for_update:
		return
	if current_player_character == null:
		print("⚠️ execute_player_action: sem personagem ativo")
		return
	
	if not current_player_character.has_ap_for_action(action):
		print("❌ AP insuficiente! AP atual:", current_player_character.current_ap, "Custo necessário:", action.ap_cost)
		return
	
	print("🚀 Executando:", action.name, "de", current_player_character.name, "em", target.name)
	print("💰 AP disponível:", current_player_character.current_ap, "/", current_player_character.get_max_ap())
	hide_sub_menus()
	battle.on_player_select_action(action, target)
	selected_action = null

# ===== Utilitários =====

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
	return null

func highlight_active_character(character_name: String):
	for name in character_displays:
		var display = character_displays[name]
		display.modulate = Color.WHITE
	if character_name in character_displays:
		var display = character_displays[character_name]
		display.modulate = Color.YELLOW

func remove_character_highlight(character_name: String):
	if character_name in character_displays:
		var display = character_displays[character_name]
		display.modulate = Color.WHITE

# Debug function para verificar as barras de vida
func _process(delta):
	if Input.is_action_just_pressed("ui_accept"):  # Tecla Enter para debug
		print("=== 🐛 DEBUG BARRAS DE VIDA ===")
		print("CharacterDisplays:", character_displays.size())
		for char_name in character_displays:
			var display = character_displays[char_name]
			print("Barra:", char_name, "| Válida:", is_instance_valid(display), "| Visível:", display.visible if is_instance_valid(display) else "INVÁLIDO")
			if is_instance_valid(display):
				print("  Posição:", display.position, "| Tamanho:", display.size)
