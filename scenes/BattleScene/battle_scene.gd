extends Control

# Áreas dos personagens
@onready var allies_area := $BattleCharactersArea/AlliesArea
@onready var enemies_area := $BattleCharactersArea/EnemiesArea

# Painel inferior
@onready var bottom_name := $BottomPanel/BottomContent/CharacterStatusBar/ActionMenu/NameLabel
@onready var bottom_hp := $BottomPanel/BottomContent/CharacterStatusBar/ActionMenu/HPBar
@onready var bottom_hp_label := $BottomPanel/BottomContent/CharacterStatusBar/ActionMenu/HPBar/Label
@onready var bottom_ap_label := $BottomPanel/BottomContent/CharacterStatusBar/ActionMenu/APBar/Label
@onready var bottom_ap := $BottomPanel/BottomContent/CharacterStatusBar/ActionMenu/APBar
@onready var bottom_action := $BottomPanel/BottomContent/CharacterStatusBar/ActionMenu/ActionLabel

# Sistema de batalha
var battle: Battle
var character_labels := {}
var current_active_character: String = ""

func _ready():
	print("🎮 BattleScene: Pronta para receber parties")

func setup_battle(allies: Party, enemies: Party):
	print("⚔️ SETUP_BATTLE: Configurando batalha")
	
	battle = Battle.new()
	battle.setup(allies, enemies)
	add_child(battle)
	
	# Conecta os sinais
	battle.turn_started.connect(_on_turn_started)
	battle.turn_completed.connect(_on_turn_completed)
	battle.battle_ended.connect(_on_battle_ended)
	
	create_character_names()
	battle.start_battle()

func create_character_names():
	print("👥 Criando nomes dos personagens...")
	
	# Limpa áreas anteriores
	for child in allies_area.get_children():
		child.queue_free()
	for child in enemies_area.get_children():
		child.queue_free()
	
	# Aliados
	for char in battle.allies_party.members:
		var label = Label.new()
		label.text = char.name + "\nAGI: " + str(char.get_attribute("agility"))
		label.add_theme_font_size_override("font_size", 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		allies_area.add_child(label)
		character_labels[char.name] = label
	
	# Inimigos
	for char in battle.enemies_party.members:
		var label = Label.new()
		label.text = char.name + "\nAGI: " + str(char.get_attribute("agility"))
		label.add_theme_font_size_override("font_size", 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		enemies_area.add_child(label)
		character_labels[char.name] = label

func _on_turn_started(character: Character, action: Action, target: Character):
	print("🎯 TURNO INICIADO: " + character.name)
	current_active_character = character.name
	highlight_character(character.name, true)
	update_bottom_panel(character, "🎯 " + character.name + " usa " + action.name + " em " + target.name)

func _on_turn_completed(character: Character):
	print("✅ TURNO COMPLETADO: " + character.name)
	highlight_character(character.name, false)
	update_bottom_panel(character, "✅ " + character.name + " completou ação")
	current_active_character = ""

func _on_battle_ended(victory: bool):
	if victory:
		print("🎉 VITÓRIA NA BATALHA!")
		bottom_action.text = "🎉 VITÓRIA!"
	else:
		print("💔 DERROTA NA BATALHA!")
		bottom_action.text = "💔 DERROTA!"

func highlight_character(character_name: String, highlight: bool):
	# Remove destaque de todos
	for name in character_labels:
		var label = character_labels[name]
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_font_size_override("font_size", 20)
	
	# Destaca apenas o ativo
	if highlight and character_name in character_labels:
		var label = character_labels[character_name]
		label.add_theme_color_override("font_color", Color.YELLOW)
		label.add_theme_font_size_override("font_size", 24)

func update_bottom_panel(character: Character, action_text: String):
	if bottom_name:
		bottom_name.text = character.name
	
	if bottom_hp and bottom_hp_label:
		bottom_hp.max_value = character.get_max_hp()
		bottom_hp.value = character.current_hp
		bottom_hp_label.text = str(character.current_hp) + "/" + str(character.get_max_hp())
	
	if bottom_ap and bottom_ap_label:
		bottom_ap.max_value = character.get_max_ap()
		bottom_ap.value = character.current_ap
		bottom_ap_label.text = str(character.current_ap) + "/" + str(character.get_max_ap())
	
	if bottom_action:
		bottom_action.text = action_text
