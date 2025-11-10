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
	
	# Cria as parties de teste
	var allies_party = create_test_allies()
	var enemies_party = create_test_enemies()
	
	# Carrega a cena de batalha
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
	# Usando call_deferred para garantir que _ready() já executou
	battle_scene.call_deferred("setup_battle", allies_party, enemies_party)

# ... (o resto do código permanece igual)

func create_test_allies() -> Party:
	var party = Party.new()
	party.name = "Heróis"
	
	var warrior = Character.new()
	warrior.name = "Guerreiro"
	warrior.strength = 8
	warrior.constitution = 7
	warrior.agility = 4
	warrior.intelligence = 3
	warrior.calculate_stats()
	
	# Adiciona ações ao guerreiro
	warrior.add_combat_action(create_basic_attack())
	warrior.add_combat_action(create_heavy_attack())
	party.add_member(warrior)
	
	var mage = Character.new()
	mage.name = "Mago"
	mage.strength = 2
	mage.constitution = 4
	mage.agility = 5
	mage.intelligence = 9
	mage.calculate_stats()
	
	# Adiciona ações ao mago
	mage.add_combat_action(create_basic_attack())
	mage.add_combat_action(create_fireball())
	party.add_member(mage)
	
	print("✅ Party aliada criada: " + party.name)
	return party

func create_test_enemies() -> Party:
	var party = Party.new()
	party.name = "Inimigos"
	
	var goblin = Character.new()
	goblin.name = "Goblin"
	goblin.strength = 5
	goblin.constitution = 5
	goblin.agility = 8
	goblin.intelligence = 2
	goblin.calculate_stats()
	
	goblin.add_combat_action(create_basic_attack())
	party.add_member(goblin)
	
	var orc = Character.new()
	orc.name = "Orc"
	orc.strength = 9
	orc.constitution = 8
	orc.agility = 3
	orc.intelligence = 1
	orc.calculate_stats()
	
	orc.add_combat_action(create_basic_attack())
	orc.add_combat_action(create_heavy_attack())
	party.add_member(orc)
	
	print("✅ Party inimiga criada: " + party.name)
	return party
	
func create_basic_attack() -> AttackAction:
	var a := AttackAction.new()
	a.name = "Ataque Básico"
	a.ap_cost = 2
	a.target_type = "enemy"
	a.damage_multiplier = 1.0
	a.formula = "melee"
	return a

func create_heavy_attack() -> AttackAction:
	var a := AttackAction.new()
	a.name = "Ataque Pesado"
	a.ap_cost = 4
	a.target_type = "enemy"
	a.damage_multiplier = 1.6
	a.formula = "melee"
	return a

func create_fireball() -> AttackAction:
	var a := AttackAction.new()
	a.name = "Bola de Fogo"
	a.ap_cost = 5
	a.target_type = "enemy"
	a.damage_multiplier = 1.8
	a.formula = "magic"
	return a
