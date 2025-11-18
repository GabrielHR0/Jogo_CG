extends Node2D

@onready var start_button = $StartButton
@onready var status_label = $StatusLabel
@onready var test_button = $TestButton

var test_character_view: CharacterView = null
var animation_buttons: Array[Button] = []

func _ready():
	print("=== 🎮 MENU PRINCIPAL ===")
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	
	if test_button:
		test_button.pressed.connect(_on_test_button_pressed)
	
	status_label.text = "Pressione para iniciar batalha"

func _on_start_button_pressed():
	print("🎯 Iniciando batalha...")
	status_label.text = "Carregando batalha..."
	
	# Remove personagem de teste e botões de animação
	cleanup_test_character()
	
	var allies_party = preload("res://data/party/default_party.tres")
	var enemies_party = create_test_enemies()
	load_battle_scene(allies_party, enemies_party)

func _on_test_button_pressed():
	print("🧪 Carregando personagem existente...")
	status_label.text = "Carregando personagem..."
	
	# Remove personagem anterior se existir
	cleanup_test_character()
	
	var character = load_existing_character()
	if character:
		load_character_view(character)
	else:
		status_label.text = "Erro: Personagem não encontrado!"

func cleanup_test_character():
	if test_character_view:
		test_character_view.queue_free()
		test_character_view = null
	
	# Remove botões de animação
	for button in animation_buttons:
		if is_instance_valid(button):
			button.queue_free()
	animation_buttons.clear()

func load_existing_character() -> Character:
	var possible_paths = [
		"res://data/characters/protagonista/character.tres",
		"res://data/characters/hero.tres", 
		"res://data/characters/character.tres",
		"res://data/characters/test_character.tres"
	]
	
	for path in possible_paths:
		if ResourceLoader.exists(path):
			var character = load(path)
			if character is Character:
				print("✅ Personagem carregado: " + path)
				print("   Nome: " + character.name)
				print("   Texture: " + (str(character.texture) if character.texture else "Nenhuma"))
				print("   Icon: " + (str(character.icon) if character.icon else "Nenhum"))
				
				if character.icon:
					print("   Icon Path: " + character.icon.resource_path)
					print("   Icon Valid: " + str(character.icon is Texture2D))
				
				return character
	
	print("⚠️ Nenhum personagem encontrado, criando fallback...")
	return create_fallback_character()

func create_fallback_character() -> Character:
	var character = Character.new()
	character.name = "Herói Fallback"
	character.strength = 5
	character.constitution = 5
	character.agility = 5
	character.intelligence = 5
	
	var possible_textures = [
		"res://assets/characters/warrior.png",
		"res://assets/characters/hero.png",
		"res://assets/characters/character.png"
	]
	
	for texture_path in possible_textures:
		if ResourceLoader.exists(texture_path):
			character.texture = load(texture_path)
			print("✅ Texture fallback carregada: " + texture_path)
			break
	
	var icon_path = "res://assets/icons/hero_icon.png"
	if ResourceLoader.exists(icon_path):
		character.icon = load(icon_path)
		print("✅ Icon fallback carregado: " + icon_path)
	
	character.calculate_stats()
	return character

func load_character_view(character: Character):
	var character_view_scene = preload("res://scenes/character_view/CharacterView.tscn")
	test_character_view = character_view_scene.instantiate()
	
	test_character_view.character = character
	test_character_view.position = Vector2(400, 300)
	test_character_view.scale = Vector2(0.4, 0.4)
	
	add_child(test_character_view)
	
	print("✅ CharacterView configurada para: " + character.name)
	
	if test_character_view.icon:
		print("   Icon node encontrado: " + str(test_character_view.icon))
		print("   Icon texture: " + str(test_character_view.icon.texture))
		print("   Icon visible: " + str(test_character_view.icon.visible))
	
	status_label.text = "Personagem carregado: " + character.name
	
	# CRIA OS BOTÕES DE ANIMAÇÃO
	create_animation_buttons()

func create_animation_buttons():
	# Lista de animações para testar
	var animations = [
		{"name": "🔄 Idle", "type": "idle", "attack_type": ""},
		{"name": "⚔️ Ataque Melee", "type": "attack", "attack_type": "melee"},
		{"name": "🔮 Ataque Magic", "type": "attack", "attack_type": "magic"},
		{"name": "🏹 Ataque Ranged", "type": "attack", "attack_type": "ranged"},
		{"name": "💥 Dano", "type": "damage", "attack_type": ""},
		{"name": "🛡️ Defender", "type": "defend", "attack_type": ""},
		{"name": "🚶 Andar", "type": "walk", "attack_type": ""},
		{"name": "🎉 Vitória", "type": "victory", "attack_type": ""},
		{"name": "💀 Derrota", "type": "defeat", "attack_type": ""}
	]
	
	var button_margin = 10
	var button_width = 150
	var button_height = 40
	var start_x = 50
	var start_y = 500
	
	for i in animations.size():
		var button = Button.new()
		button.text = animations[i].name
		button.position = Vector2(start_x + (i % 3) * (button_width + button_margin), 
								start_y + (i / 3) * (button_height + button_margin))
		button.size = Vector2(button_width, button_height)
		
		# Conecta o sinal com os parâmetros da animação
		var anim_type = animations[i].type
		var attack_type = animations[i].attack_type
		button.pressed.connect(_on_animation_button_pressed.bind(anim_type, attack_type))
		
		add_child(button)
		animation_buttons.append(button)
	
	# Botão para limpar/resetar
	var clear_button = Button.new()
	clear_button.text = "❌ Limpar"
	clear_button.position = Vector2(650, 500)
	clear_button.size = Vector2(100, 40)
	clear_button.pressed.connect(_on_clear_button_pressed)
	add_child(clear_button)
	animation_buttons.append(clear_button)

func _on_animation_button_pressed(animation_type: String, attack_type: String):
	if not test_character_view or not test_character_view.character:
		return
	
	print("🎬 Testando animação: ", animation_type, " - ", attack_type)
	
	match animation_type:
		"idle":
			test_character_view.character.request_idle_animation()
		"attack":
			test_character_view.character.request_attack_animation(attack_type)
		"damage":
			test_character_view.character.request_damage_animation()
		"defend":
			test_character_view.character.request_defense_animation()
		"walk":
			test_character_view.character.request_walk_animation()
		"victory":
			test_character_view.character.request_victory_animation()
		"defeat":
			test_character_view.character.request_defeat_animation()

func _on_clear_button_pressed():
	if test_character_view:
		# Para qualquer animação e volta para idle
		test_character_view.character.request_idle_animation()
		print("🧹 Limpando animações - Voltando para idle")

func load_battle_scene(allies_party: Party, enemies_party: Party):
	cleanup_test_character()
	
	var battle_scene = preload("res://scenes/BattleScene/BattleScene.tscn").instantiate()
	
	get_tree().root.add_child(battle_scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = battle_scene
	
	print("✅ Cena de batalha carregada!")
	
	battle_scene.call_deferred("setup_battle", allies_party, enemies_party)

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
