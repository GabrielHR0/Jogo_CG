extends Node2D

@onready var start_button = $StartButton
@onready var status_label = $StatusLabel
@onready var test_button = $TestButton

var test_character_view: CharacterView = null
var character_buttons: Array[Button] = []
var animation_buttons: Array[Button] = []
var current_character: Character = null

# Array para armazenar os personagens encontrados
var found_characters: Array[Dictionary] = []

func _ready():
	print("=== 🎮 MENU PRINCIPAL ===")
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	
	if test_button:
		test_button.pressed.connect(_on_test_button_pressed)
	
	status_label.text = "Procurando personagens..."
	
	# Procura e carrega personagens automaticamente
	find_and_load_characters()

func find_and_load_characters():
	print("🔍 Procurando personagens em res://data/characters/aliados/")
	
	var aliados_path = "res://data/characters/aliados/"
	var dir = DirAccess.open(aliados_path)
	
	if dir:
		found_characters.clear()
		
		# Lista todos os arquivos .tres do diretório
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var full_path = aliados_path + file_name
				var character = load_character(full_path)
				
				if character:
					# Adiciona à lista de personagens encontrados
					var char_data = {
						"name": character.name,
						"path": full_path,
						"resource": character
					}
					found_characters.append(char_data)
					print("✅ Personagem encontrado: " + file_name + " -> " + character.name)
				else:
					print("❌ Falha ao carregar: " + file_name)
			
			file_name = dir.get_next()
		
		dir.list_dir_end()
		
		if found_characters.is_empty():
			print("⚠️ Nenhum personagem encontrado, criando fallbacks...")
			create_fallback_characters()
		else:
			print("🎯 Total de personagens encontrados: " + str(found_characters.size()))
			create_character_buttons()
			status_label.text = "Selecione um personagem para testar animações"
	else:
		print("❌ Diretório não encontrado: " + aliados_path)
		create_fallback_characters()

func create_fallback_characters():
	# Cria alguns personagens fallback se não encontrar nenhum
	var fallback_chars = [
		{"name": "🧙‍♂️ Mago", "class": "Mage"},
		{"name": "⚔️ Guerreiro", "class": "Warrior"},
		{"name": "🏹 Arqueiro", "class": "Archer"},
		{"name": "🛡️ Tank", "class": "Tank"}
	]
	
	for fallback in fallback_chars:
		var character = create_fallback_character(fallback.name, fallback.class)
		var char_data = {
			"name": character.name,
			"path": "fallback://" + fallback.class,
			"resource": character
		}
		found_characters.append(char_data)
	
	print("✅ Personagens fallback criados: " + str(found_characters.size()))
	create_character_buttons()
	status_label.text = "Personagens fallback - Selecione para testar animações"

func create_character_buttons():
	# Remove botões antigos se existirem
	for button in character_buttons:
		if is_instance_valid(button):
			button.queue_free()
	character_buttons.clear()
	
	var button_margin = 10
	var button_width = 180
	var button_height = 40
	var start_x = 50
	var start_y = 100
	
	for i in found_characters.size():
		var button = Button.new()
		var char_data = found_characters[i]
		
		# Usa emoji + nome do personagem
		var display_name = char_data.name
		# Adiciona emoji baseado no nome se não tiver
		if not display_name.contains("🧙") and not display_name.contains("⚔️") and not display_name.contains("🏹") and not display_name.contains("🛡️"):
			if display_name.to_lower().contains("mago") or display_name.to_lower().contains("mage") or display_name.to_lower().contains("wizard"):
				display_name = "🧙‍♂️ " + display_name
			elif display_name.to_lower().contains("guerreiro") or display_name.to_lower().contains("warrior") or display_name.to_lower().contains("fighter"):
				display_name = "⚔️ " + display_name
			elif display_name.to_lower().contains("arqueiro") or display_name.to_lower().contains("archer") or display_name.to_lower().contains("ranger"):
				display_name = "🏹 " + display_name
			elif display_name.to_lower().contains("tank") or display_name.to_lower().contains("defensor") or display_name.to_lower().contains("protector"):
				display_name = "🛡️ " + display_name
			else:
				display_name = "👤 " + display_name
		
		button.text = display_name
		button.position = Vector2(start_x, start_y + i * (button_height + button_margin))
		button.size = Vector2(button_width, button_height)
		
		# Tooltip com o caminho do arquivo
		if not char_data.path.begins_with("fallback://"):
			button.tooltip_text = char_data.path
		
		button.pressed.connect(_on_character_button_pressed.bind(char_data.resource, char_data.name))
		
		add_child(button)
		character_buttons.append(button)
	
	print("✅ Botões de personagens criados: ", character_buttons.size())

func _on_character_button_pressed(character: Character, character_name: String):
	print("👤 Selecionando personagem: ", character_name)
	status_label.text = "Carregando: " + character_name
	
	# Remove personagem anterior se existir
	cleanup_test_character()
	
	current_character = character
	load_character_view(character)
	create_animation_buttons()
	status_label.text = "Pronto: " + character_name + " - Selecione uma animação"

func _on_start_button_pressed():
	print("🎯 Iniciando batalha...")
	status_label.text = "Carregando batalha..."
	
	cleanup_test_character()
	
	#var allies_party = create_allies_party_from_found()
	#var enemies_party = create_test_enemies()
	var allies_party = preload("res://data/party/default_party.tres")
	var enemies_party = preload("res://data/party/enemy_default_party.tres")

	load_battle_scene(allies_party, enemies_party)

func create_allies_party_from_found() -> Party:
	var party = Party.new()
	party.name = "Heróis"
	
	# Usa os primeiros 4 personagens encontrados para a party
	var max_members = min(4, found_characters.size())
	
	for i in range(max_members):
		var char_data = found_characters[i]
		party.add_member(char_data.resource)
		print("✅ Adicionado à party: " + char_data.name)
	
	# Se não encontrou personagens suficientes, cria alguns extras
	if party.members.is_empty():
		print("⚠️ Nenhum personagem encontrado, criando party fallback...")
		party.add_member(create_fallback_character("Guerreiro", "Warrior"))
		party.add_member(create_fallback_character("Mago", "Mage"))
	
	print("✅ Party aliada criada: " + party.name + " com " + str(party.members.size()) + " membros")
	return party

func _on_test_button_pressed():
	print("🧪 Modo teste de animações")
	status_label.text = "Selecione um personagem para testar animações"

func cleanup_test_character():
	if test_character_view:
		test_character_view.queue_free()
		test_character_view = null
	
	# Remove botões de animação
	for button in animation_buttons:
		if is_instance_valid(button):
			button.queue_free()
	animation_buttons.clear()
	
	current_character = null

func load_character(path: String) -> Character:
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Character:
			print("✅ Personagem carregado: " + path)
			print("   Nome: " + resource.name)
			print("   Texture: " + (str(resource.texture) if resource.texture else "Nenhuma"))
			print("   Icon: " + (str(resource.icon) if resource.icon else "Nenhum"))
			return resource
		else:
			print("❌ Arquivo não é um Character: " + path)
			return null
	else:
		print("❌ Arquivo não encontrado: " + path)
		return null

func create_fallback_character(character_name: String, character_class: String) -> Character:
	var character = Character.new()
	character.name = character_name
	character.strength = 5
	character.constitution = 5
	character.agility = 5
	character.intelligence = 5
	
	# Ajusta stats baseado na classe
	match character_class:
		"Warrior", "Guerreiro":
			character.strength = 8
			character.constitution = 7
			character.agility = 4
			character.intelligence = 3
		"Mage", "Mago":
			character.strength = 2
			character.constitution = 4
			character.agility = 5
			character.intelligence = 9
		"Archer", "Arqueiro":
			character.strength = 4
			character.constitution = 4
			character.agility = 8
			character.intelligence = 4
		"Tank":
			character.strength = 6
			character.constitution = 9
			character.agility = 2
			character.intelligence = 3
	
	# Tenta carregar texturas comuns
	var possible_textures = [
		"res://assets/characters/warrior.png",
		"res://assets/characters/hero.png",
		"res://assets/characters/character.png",
		"res://assets/characters/mage.png",
		"res://assets/characters/archer.png",
        "res://assets/characters/tank.png"
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
	
	# Adiciona ações básicas
	character.add_combat_action(create_basic_attack())
	if character_class == "Mage" or character_class == "Mago":
		character.add_combat_action(create_fireball())
	elif character_class == "Warrior" or character_class == "Guerreiro":
		character.add_combat_action(create_heavy_attack())
	
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
	var button_width = 180
	var button_height = 40
	var start_x = 250  # Coluna ao lado dos botões de personagens
	var start_y = 100
	
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
	clear_button.text = "❌ Limpar Animações"
	clear_button.position = Vector2(650, 500)
	clear_button.size = Vector2(180, 40)
	clear_button.pressed.connect(_on_clear_button_pressed)
	add_child(clear_button)
	animation_buttons.append(clear_button)
	
	print("✅ Botões de animação criados: ", animation_buttons.size())

func _on_animation_button_pressed(animation_type: String, attack_type: String):
	if not test_character_view or not current_character:
		status_label.text = "Nenhum personagem selecionado!"
		return
	
	print("🎬 Testando animação: ", animation_type, " - ", attack_type)
	status_label.text = "Animação: " + animation_type + " - " + current_character.name
	
	match animation_type:
		"idle":
			current_character.request_idle_animation()
		"attack":
			current_character.request_attack_animation(attack_type)
		"damage":
			current_character.request_damage_animation()
		"defend":
			current_character.request_defense_animation()
		"walk":
			current_character.request_walk_animation()
		"victory":
			current_character.request_victory_animation()
		"defeat":
			current_character.request_defeat_animation()

func _on_clear_button_pressed():
	if test_character_view and current_character:
		# Para qualquer animação e volta para idle
		current_character.request_idle_animation()
		status_label.text = "Animações limpas - " + current_character.name
		print("🧹 Limpando animações - Voltando para idle")

func load_battle_scene(allies_party: Party, enemies_party: Party):
	cleanup_test_character()
	
	var battle_scene = preload("res://scenes/BattleScene/BattleScene.tscn").instantiate()
	
	get_tree().root.add_child(battle_scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = battle_scene
	
	print("✅ Cena de batalha carregada!")
	
	battle_scene.call_deferred("setup_battle", allies_party, enemies_party)

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
