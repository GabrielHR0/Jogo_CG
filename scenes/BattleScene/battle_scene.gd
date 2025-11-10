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

# Sub-menus (dentro do mesmo HBoxContainer, conforme seu print)
@onready var attack_menu              = $BottomPanel/HBoxContainer/AttackMenu
@onready var attack_buttons_container = $BottomPanel/HBoxContainer/AttackMenu/AttackButtons

# Sistema de batalha
var battle: Battle
var character_displays := {}
var current_player_character: Character = null
var selected_action: Action = null

func _ready():
	print("=== 🎮 BattleScene READY ===")
	_setup_root_layout()
	setup_ui()
	connect_buttons()


func _setup_root_layout():
	set_anchors_preset(Control.PRESET_FULL_RECT)  # Layout via Containers [web:9]

func setup_ui():
	attack_menu.visible = false
	attack_buttons_container.visible = false
	fight_button.text = "🗡️ LUTAR"
	defend_button.text = "🛡️ DEFENDER"
	items_button.text  = "📦 ITENS"
	skip_button.text   = "⏭️ PULAR"
	print("UI ▶️ Botões ok; AttackMenu oculto")  # [web:9]

func connect_buttons():
	fight_button.pressed.connect(_on_fight_pressed)
	defend_button.pressed.connect(_on_defend_pressed)
	items_button.pressed.connect(_on_items_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	print("UI 🔗 Sinais conectados")  # [web:9]

func setup_battle(allies_party: Party, enemies_party: Party):
	print("⚔️ Setup battle:", allies_party.name, "vs", enemies_party.name)
	battle = Battle.new()
	add_child(battle)

	# Conecta sinais
	battle.battle_started.connect(_on_battle_started)
	battle.player_turn_started.connect(_on_player_turn_started)
	battle.action_executed.connect(_on_action_executed)
	battle.turn_completed.connect(_on_turn_completed)
	battle.character_died.connect(_on_character_died)
	battle.battle_ended.connect(_on_battle_ended)

	battle.setup_battle(allies_party, enemies_party)
	create_character_displays()

	await get_tree().create_timer(0.25).timeout
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
	current_player_character = character
	print("🕐 Turno:", character.name, "| AP:", character.current_ap, "/", character.get_max_ap(), "| Ações:", character.combat_actions.size())
	_print_actions(character)
	update_character_status(character)
	highlight_active_character(character.name)
	action_label.text = "Sua vez! Escolha uma ação"
	hide_sub_menus() # fecha restos do turno anterior
	print("🧭 CommandMenu pronto; AttackMenu fechado")

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
	var action_text = "%s usa %s em %s" % [character.name, action.name, target.name]
	print("✅ Executada:", action_text)
	action_label.text = action_text
	update_character_displays()

func _on_turn_completed(character: Character):
	print("⏭️ Turno concluído:", character.name)
	remove_character_highlight(character.name)
	hide_sub_menus()

func _on_character_died(character: Character):
	print("💀 Morte:", character.name)
	if character.name in character_displays:
		var display = character_displays[character.name]
		display.modulate = Color(0.5, 0.5, 0.5, 0.7)

func _on_battle_ended(victory: bool):
	print("🎉 VITÓRIA" if victory else "💔 DERROTA")
	action_label.text = "🎉 VITÓRIA!" if victory else "💔 DERROTA!"
	hide_sub_menus()

# ===== Menus =====

func show_command_menu():
	hide_sub_menus()
	print("🧭 CommandMenu visível; AttackMenu oculto")

func hide_sub_menus():
	attack_menu.visible = false
	attack_buttons_container.visible = false
	print("🙈 AttackMenu ocultado")

func _on_fight_pressed():
	print("🗡️ LUTAR por:", current_player_character and current_player_character.name)
	show_attack_menu()

func _on_defend_pressed():
	print("🛡️ DEFENDER")
	if current_player_character == null:
		print("⚠️ DEFENDER: sem personagem ativo")
		return
	var defend_action = find_defend_action(current_player_character)
	if defend_action:
		execute_player_action(defend_action, current_player_character)
	else:
		print("⚠️ 'Defender' não encontrada")

func _on_items_pressed():
	print("📦 ITENS (WIP)")
	action_label.text = "Sistema de itens em desenvolvimento"

func _on_skip_pressed():
	print("⏭️ PULAR")
	if current_player_character == null:
		print("⚠️ PULAR: sem personagem ativo")
		return
	var skip_action = find_skip_action(current_player_character)
	if skip_action:
		execute_player_action(skip_action, current_player_character)
	else:
		print("⚠️ 'Pular Turno' não encontrada")

func has_any_available_attack(character: Character) -> bool:
	if character == null or character.combat_actions.is_empty():
		return false
	for a in character.combat_actions:
		if character.has_ap_for_action(a):
			return true
	return false

func show_attack_menu():
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
	print("👁️ AttackMenu:", attack_menu.visible, "| Buttons:", attack_buttons_container.visible)

func estimate_damage(action: Action) -> int:
	if action is AttackAction:
		var attack_action = action as AttackAction
		var base_damage = current_player_character.calculate_melee_damage()
		return int(base_damage * attack_action.damage_multiplier)
	return current_player_character.calculate_melee_damage()

func _on_attack_selected(action: Action):
	print("🎯 Selecionado:", action.name, "por", current_player_character and current_player_character.name)
	selected_action = action
	show_attack_targets(action)


func show_attack_targets(action: Action):
	var is_player_ally := current_player_character in battle.allies_party.members
	var targets: Array[Character] = []
	match action.target_type:
		"enemy":
			targets = battle.enemies_party.alive() if is_player_ally else battle.allies_party.alive()
		"ally":
			targets = battle.allies_party.alive() if is_player_ally else battle.enemies_party.alive()
		"self":
			targets = [current_player_character]
		_:
			targets = battle.enemies_party.alive() if is_player_ally else battle.allies_party.alive()

	print("🎯 Seleção:", action.name, "| atacante aliado?:", is_player_ally, "| target_type:", action.target_type, "| qtd targets:", targets.size())
	if targets.is_empty():
		action_label.text = "Sem alvos válidos!"
		return
	var target = targets[0]
	execute_player_action(action, target)


func execute_player_action(action: Action, target: Character):
	if current_player_character == null:
		print("⚠️ execute_player_action: sem personagem ativo")
		return
	print("🚀 Executando:", action.name, "de", current_player_character.name, "em", target.name)
	hide_sub_menus()
	battle.on_player_select_action(action, target)
	selected_action = null
	# Battle cuidará de executar e encerrar o turno


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
