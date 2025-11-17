extends Control

# Áreas de batalha (topo)
@onready var enemies_front_row = $HBoxContainer/EnemiesArea/EnemyFrontRow
@onready var enemies_back_row  = $HBoxContainer/EnemiesArea/EnemyBackRow
@onready var allies_front_row  = $HBoxContainer/AlliesArea/AllyFrontRow
@onready var allies_back_row   = $HBoxContainer/AlliesArea/AllyBackRow

# Status do personagem ativo (no BottomPanel/HBoxContainer/CharacterStatus)
@onready var character_icon = $BottomPanel/HBoxContainer/CharacterStatus/CharacterIcon
@onready var character_name = $BottomPanel/HBoxContainer/CharacterStatus/VBoxContainer/CharacterName
@onready var hp_bar        = $BottomPanel/HBoxContainer/CharacterStatus/VBoxContainer/HPBar
@onready var hp_label      = $BottomPanel/HBoxContainer/CharacterStatus/VBoxContainer/HPBar/HPLabel
@onready var ap_bar        = $BottomPanel/HBoxContainer/CharacterStatus/VBoxContainer/APBar
@onready var ap_label      = $BottomPanel/HBoxContainer/CharacterStatus/VBoxContainer/APBar/APLabel
@onready var action_label  = $BottomPanel/HBoxContainer/CharacterStatus/ActionLabel

# Menu de comandos (no BottomPanel/HBoxContainer/CommandMenu)
@onready var fight_button  = $BottomPanel/HBoxContainer/CommandMenu/FightButton
@onready var defend_button = $BottomPanel/HBoxContainer/CommandMenu/DefendButton
@onready var items_button  = $BottomPanel/HBoxContainer/CommandMenu/ItemsButton
@onready var skip_button   = $BottomPanel/HBoxContainer/CommandMenu/SkipButton

# Sub-menus (dentro do mesmo HBoxContainer)
@onready var attack_menu              = $BottomPanel/HBoxContainer/AttackMenu
@onready var attack_buttons_container = $BottomPanel/HBoxContainer/AttackMenu/AttackButtons
@onready var target_menu              = $BottomPanel/HBoxContainer/TargetMenu
@onready var target_buttons_container = $BottomPanel/HBoxContainer/TargetMenu/TargetButtons

# Sistema de batalha
var battle: Battle
var character_displays := {}
var current_player_character: Character = null
var selected_action: Action = null
var battle_ended: bool = false
var waiting_for_update: bool = false

# 🎯 NOVO: Configuração de delays
@export var turn_start_delay: float = 0.3
@export var action_execution_delay: float = 0.2
@export var ui_update_delay: float = 0.1

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
	create_character_displays()

	await get_tree().create_timer(0.5).timeout
	print("▶️ start_battle()")
	battle.start_battle()

func create_character_displays():
	clear_character_displays()
	print("👥 Criando displays...")
	create_enemy_displays()
	create_ally_displays()

func create_enemy_displays():
	for character in battle.enemies_party.members:
		var display = create_character_display(character)
		if character.position == "front":
			enemies_front_row.add_child(display)
		else:
			enemies_back_row.add_child(display)
		character_displays[character.name] = display
		print("   💀 Inimigo no grid:", character.name)

func create_ally_displays():
	for character in battle.allies_party.members:
		var display = create_character_display(character)
		if character.position == "front":
			allies_front_row.add_child(display)
		else:
			allies_back_row.add_child(display)
		character_displays[character.name] = display
		print("   🎯 Aliado no grid:", character.name)

func create_character_display(character: Character) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 150)

	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var name_label = Label.new()
	name_label.name = "Name"
	name_label.text = character.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)

	var hp_container = HBoxContainer.new()
	hp_container.name = "HPRow"
	var hp_text = Label.new(); hp_text.text = "HP:"
	var hp_value = Label.new(); hp_value.name = "HPValue"
	hp_value.text = "%d/%d" % [character.current_hp, character.get_max_hp()]
	hp_container.add_child(hp_text); hp_container.add_child(hp_value)

	var ap_container = HBoxContainer.new()
	ap_container.name = "APRow"
	var ap_text = Label.new(); ap_text.text = "AP:"
	var ap_value = Label.new(); ap_value.name = "APValue"
	ap_value.text = "%d/%d" % [character.current_ap, character.get_max_ap()]
	ap_container.add_child(ap_text); ap_container.add_child(ap_value)

	vbox.add_child(name_label)
	vbox.add_child(hp_container)
	vbox.add_child(ap_container)
	panel.add_child(vbox)
	return panel

func clear_character_displays():
	for display in character_displays.values():
		display.queue_free()
	character_displays.clear()
	print("🧹 Displays limpos")

# ===== Eventos/sinais =====

func _on_battle_started():
	print("🎲 Batalha iniciada")
	action_label.text = "Batalha Iniciada!"
	hide_sub_menus()

func _on_player_turn_started(character: Character):
	if battle_ended:
		return
	
	# 🎯 NOVO: Sistema de espera para garantir que tudo foi atualizado
	waiting_for_update = true
	action_label.text = "Atualizando..."
	
	print("⏳ Iniciando turno de:", character.name)
	
	# Delay para garantir que todos os campos foram atualizados
	await get_tree().create_timer(turn_start_delay).timeout
	
	# Atualiza a UI completamente
	await update_all_ui_elements()
	
	# Libera para interação
	waiting_for_update = false
	
	current_player_character = character
	print("🕐 Turno:", character.name, "| AP:", character.current_ap, "/", character.get_max_ap(), "| Ações:", character.combat_actions.size())
	_print_actions(character)
	update_character_status(character)
	highlight_active_character(character.name)
	action_label.text = "Sua vez! Escolha uma ação"
	hide_sub_menus() # fecha restos do turno anterior
	print("🧭 CommandMenu pronto; Menus fechados")

# 🎯 NOVO: Função para atualizar todos os elementos da UI
func update_all_ui_elements():
	print("🔄 Atualizando toda a UI...")
	
	# Atualiza displays de todos os personagens
	update_character_displays()
	
	# Atualiza status do personagem atual se existir
	if current_player_character:
		update_character_status(current_player_character)
	
	# Pequeno delay para garantir que a UI foi atualizada
	await get_tree().create_timer(ui_update_delay).timeout
	print("✅ UI atualizada")

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
	
	# 🎯 NOVO: Espera antes de atualizar a UI após ação
	await get_tree().create_timer(action_execution_delay).timeout
		
	var action_text = "%s usa %s em %s" % [character.name, action.name, target.name]
	print("✅ Executada:", action_text)
	action_label.text = action_text
	
	# Atualiza a UI após a ação
	await update_all_ui_elements()

func _on_turn_completed(character: Character):
	if battle_ended:
		return
	
	# 🎯 NOVO: Espera antes de finalizar o turno
	await get_tree().create_timer(action_execution_delay).timeout
		
	print("⏭️ Turno concluído:", character.name)
	remove_character_highlight(character.name)
	hide_sub_menus()
	
	# Atualiza a UI após o turno
	await update_all_ui_elements()

func _on_character_died(character: Character):
	print("💀 Morte:", character.name)
	
	# 🎯 NOVO: Espera antes de remover o personagem
	await get_tree().create_timer(action_execution_delay).timeout
	
	if character.name in character_displays:
		var display = character_displays[character.name]
		# 🎯 CORREÇÃO: Faz o personagem desaparecer em vez de escurecer
		display.visible = false
		# Remove do dicionário para evitar acesso futuro
		character_displays.erase(character.name)
		print("   👻 Personagem removido da tela:", character.name)

func _on_battle_ended(victory: bool):
	print("🎯 BattleScene: _on_battle_ended chamado - Vitória:", victory)
	battle_ended = true
	waiting_for_update = true
	
	if victory:
		print("🎉 VITÓRIA!")
		action_label.text = "🎉 VITÓRIA!"
	else:
		print("💔 DERROTA!")
		action_label.text = "💔 DERROTA!"
	
	hide_sub_menus()
	
	# 🎯 CORREÇÃO: Voltar para a main após um delay
	await get_tree().create_timer(2.0).timeout
	return_to_main()

func _on_player_action_selected():
	print("🔄 Player action selected signal received")
	# Este sinal é apenas para sincronização interna do Battle
	# Não precisa fazer nada aqui

func return_to_main():
	print("🏠 Voltando para a tela principal...")
	
	# 🎯 CORREÇÃO: Abordagem direta para trocar de cena
	var main_scene_path = "res://scenes/main/main.tscn"
	
	# Verifica se o arquivo existe antes de tentar carregar
	if FileAccess.file_exists(main_scene_path):
		get_tree().change_scene_to_file(main_scene_path)
		print("✅ Cena principal carregada: " + main_scene_path)
	else:
		print("❌ Arquivo da cena principal não encontrado: " + main_scene_path)
		# Fallback: tentar carregar cena com nome comum
		try_alternative_scenes()

func try_alternative_scenes():
	# Tenta carregar cenas com nomes alternativos comuns
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
	# Se não encontrar, pelo menos limpa a batalha
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
		# 🛡️ CORREÇÃO: Mostra menu de alvos para defender (apenas self)
		print("🎯 Defender - mostrando menu de alvos")
		selected_action = defend_action
		show_target_menu(defend_action)
	else:
		print("⚠️ 'Defender' não encontrada")

func _on_items_pressed():
	if battle_ended or waiting_for_update:
		return
	print("📦 ITENS (WIP)")
	action_label.text = "Sistema de itens em desenvolvimento"

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
	
	# Limpa botões anteriores
	for child in target_buttons_container.get_children():
		child.queue_free()
	
	# Obtém alvos válidos baseado no target_type da ação
	var valid_targets = get_valid_targets(action)
	
	if valid_targets.is_empty():
		print("⚠️ Nenhum alvo válido para:", action.name)
		var label_empty = Label.new()
		label_empty.text = "Nenhum alvo disponível"
		target_buttons_container.add_child(label_empty)
	else:
		print("🎯 Alvos válidos encontrados:", valid_targets.size())
		for target in valid_targets:
			# 🛡️ CORREÇÃO: Verifica se o target é válido antes de criar o botão
			if target == null:
				print("⚠️ Target inválido (null) encontrado, pulando...")
				continue
				
			var button = Button.new()
			var target_type_icon = get_target_type_icon(action.target_type)
			var status = "💀 MORTO" if not target.is_alive() else "❤️ HP: %d/%d" % [target.current_hp, target.get_max_hp()]
			
			button.text = "%s %s\n%s" % [target_type_icon, target.name, status]
			button.custom_minimum_size = Vector2(220, 56)
			button.disabled = not target.is_alive()  # Desabilita se o alvo estiver morto
			button.pressed.connect(_on_target_selected.bind(target))
			target_buttons_container.add_child(button)
			print("   ➕ Alvo:", target.name, "| Vivo:", target.is_alive())
	
	# Botão Voltar
	var back_button = Button.new()
	back_button.text = "⬅️ Voltar"
	back_button.custom_minimum_size = Vector2(220, 40)
	back_button.pressed.connect(_on_target_back_pressed)
	target_buttons_container.add_child(back_button)
	
	# Mostra o menu de alvos
	target_menu.visible = true
	target_buttons_container.visible = true
	attack_menu.visible = false
	action_label.text = "Escolha um alvo para: %s" % action.name
	
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
			# Se é aliado, ataca inimigos; se é inimigo, ataca aliados
			targets = battle.enemies_party.alive() if is_player_ally else battle.allies_party.alive()
		"ally":
			# Se é aliado, cura/ajuda aliados; se é inimigo, cura/ajuda inimigos
			targets = battle.allies_party.alive() if is_player_ally else battle.enemies_party.alive()
		"self":
			# 🛡️ CORREÇÃO: Para ações self, mostra apenas o próprio personagem
			targets = [current_player_character]
		_:
			# Fallback: assume inimigo
			targets = battle.enemies_party.alive() if is_player_ally else battle.allies_party.alive()
	
	print("🎯 Tipo:", action.target_type, "| Aliado?:", is_player_ally, "| Alvos:", targets.size())
	
	# 🛡️ CORREÇÃO: Filtra targets nulos
	var valid_targets = []
	for target in targets:
		if target != null:
			valid_targets.append(target)
	
	return valid_targets

func _on_target_selected(target: Character):
	if battle_ended or waiting_for_update:
		return
	# 🛡️ CORREÇÃO: Verifica se o target é válido
	if target == null:
		print("❌ Alvo inválido (null) para ação:", selected_action.name if selected_action else "Nenhuma ação")
		return
	
	# 🛡️ CORREÇÃO: Verifica se a ação ainda existe
	if selected_action == null:
		print("❌ Nenhuma ação selecionada!")
		return
	
	print("🎯 Alvo selecionado:", target.name, "para ação:", selected_action.name)
	execute_player_action(selected_action, target)

func _on_target_back_pressed():
	if battle_ended or waiting_for_update:
		return
	print("⬅️ Voltando do menu de alvos")
	# Volta para o menu anterior
	if selected_action:
		if selected_action in current_player_character.combat_actions:
			# Se veio do menu de ataques, volta para lá
			show_attack_menu()
		else:
			# Se veio do menu principal (defender), volta para o CommandMenu
			hide_sub_menus()
	else:
		hide_sub_menus()

func execute_player_action(action: Action, target: Character):
	if battle_ended or waiting_for_update:
		return
	if current_player_character == null:
		print("⚠️ execute_player_action: sem personagem ativo")
		return
	
	# 🎯 CORREÇÃO: Verifica AP novamente antes de executar
	if not current_player_character.has_ap_for_action(action):
		print("❌ AP insuficiente! AP atual:", current_player_character.current_ap, "Custo necessário:", action.ap_cost)
		action_label.text = "AP insuficiente! AP: " + str(current_player_character.current_ap) + "/" + str(current_player_character.get_max_ap())
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

func update_character_status(character: Character):
	if character == null:
		print("⚠️ update_character_status: character null")
		return
	character_name.text = character.name
	hp_bar.max_value = character.get_max_hp()
	hp_bar.value = character.current_hp
	hp_label.text = "%d/%d" % [character.current_hp, character.get_max_hp()]
	ap_bar.max_value = character.get_max_ap()
	ap_bar.value = character.current_ap
	ap_label.text = "%d/%d" % [character.current_ap, character.get_max_ap()]

func update_character_displays():
	for character in battle.allies_party.members + battle.enemies_party.members:
		if character.name in character_displays:
			var display = character_displays[character.name]
			var hp_value = display.get_node("VBoxContainer/HPRow/HPValue") as Label
			var ap_value = display.get_node("VBoxContainer/APRow/APValue") as Label
			hp_value.text = "%d/%d" % [character.current_hp, character.get_max_hp()]
			ap_value.text = "%d/%d" % [character.current_ap, character.get_max_ap()]

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
