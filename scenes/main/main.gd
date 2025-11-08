extends Node2D

@onready var start_button = $StartButton
@onready var status_label = $StatusLabel

func _ready():
	print("=== 🎮 MENU PRINCIPAL ===")
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	status_label.text = "Pressione para iniciar batalha"

func _on_start_button_pressed():
	print("🎯 Iniciando batalha...")
	status_label.text = "Carregando batalha..."
	
	# Cria as parties
	var allies_party = create_simple_allies_party()
	var enemies_party = create_simple_enemies_party()
	
	# CARREGA A CENA DE BATALHA
	load_battle_scene(allies_party, enemies_party)

func load_battle_scene(allies_party: Party, enemies_party: Party):
	# Carrega a cena de batalha
	var battle_scene = preload("res://scenes/BattleScene/BattleScene.tscn").instantiate()
	
	# TROCA A CENA ATUAL pela cena de batalha PRIMEIRO
	get_tree().root.add_child(battle_scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = battle_scene
	
	print("✅ Cena de batalha carregada!")
	
	# AGORA chama setup_battle DEPOIS que a cena já está na árvore
	battle_scene.call_deferred("setup_battle", allies_party, enemies_party)

func create_simple_allies_party() -> Party:
	var party = Party.new()
	party.name = "Heróis"
	
	var warrior = Character.new()
	warrior.name = "Guerreiro"
	warrior.strength = 8
	warrior.constitution = 7
	warrior.agility = 4
	warrior.intelligence = 3
	warrior.position = "front"
	warrior.calculate_stats()
	party.add_member(warrior)
	
	var mage = Character.new()
	mage.name = "Mago"
	mage.strength = 2
	mage.constitution = 4
	mage.agility = 5
	mage.intelligence = 9
	mage.position = "back"
	mage.calculate_stats()
	party.add_member(mage)
	
	return party

func create_simple_enemies_party() -> Party:
	var party = Party.new()
	party.name = "Inimigos"
	
	var goblin = Character.new()
	goblin.name = "Goblin"
	goblin.strength = 5
	goblin.constitution = 5
	goblin.agility = 8
	goblin.intelligence = 2
	goblin.position = "front"
	goblin.calculate_stats()
	party.add_member(goblin)
	
	var orc = Character.new()
	orc.name = "Orc"
	orc.strength = 9
	orc.constitution = 8
	orc.agility = 3
	orc.intelligence = 1
	orc.position = "front"
	orc.calculate_stats()
	party.add_member(orc)
	
	return party
