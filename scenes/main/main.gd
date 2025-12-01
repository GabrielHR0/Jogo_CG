extends Node2D

@onready var start_button = $StartButton
@onready var status_label = $StatusLabel
@onready var test_button = $TestButton

var battle_ended: bool = false
signal battle_finished(victory: bool)
var test_character_view: CharacterView = null
var character_buttons: Array[Button] = []
var animation_buttons: Array[Button] = []
var current_character: Character = null

# Array para armazenar os personagens encontrados
var found_characters: Array[Dictionary] = []

# 🆕 NOVO: Array para armazenar ataques carregados
var loaded_attacks: Array[Dictionary] = []

# Controle de fases para fluxo automático
var current_phase: int = 0
var max_phases: int = 2  # Agora temos 2 fases
var game_started: bool = false

func _ready():
	print("=== 🎮 MENU PRINCIPAL ===")
	
	status_label.text = "Procurando personagens e ataques..."
	
	load_all_attacks()
	find_and_load_characters()
	
	# Configurar botão de início
	if start_button:
		start_button.pressed.connect(_on_start_game_pressed)
	
	# Configurar botão de teste (se existir)
	if test_button:
		test_button.pressed.connect(_on_test_button_pressed)
	
	status_label.text = "Pronto! Clique em 'Jogar' para começar."

# 🆕 NOVO: Iniciar jogo quando clicar no botão
func _on_start_game_pressed():
	print("🎮 Iniciando jogo...")
	game_started = true
	start_button.visible = false
	if test_button:
		test_button.visible = false
	
	# Limpar UI existente
	cleanup_test_character()
	for button in character_buttons + animation_buttons:
		if is_instance_valid(button):
			button.queue_free()
	character_buttons.clear()
	animation_buttons.clear()
	
	start_game_flow()

# 🆕 NOVO: Botão de teste
func _on_test_button_pressed():
	print("🔧 Modo teste ativado")
	status_label.text = "Modo teste - Selecione um personagem"
	create_character_buttons()

func start_game_flow() -> void:
	print("🎬 INICIANDO FLUXO DO JOGO")
	current_phase = 0
	
	while current_phase < max_phases:
		print("📖 === INICIANDO FASE ", current_phase + 1, " ===")
		
		# 1. Mostrar cutscene da fase
		print("DEBUG: Mostrando cutscene...")
		await _play_cutscene(current_phase)
		
		# 2. Criar party aliada
		print("DEBUG: Criando party aliada...")
		var allies_party = create_allies_party_from_found()
		
		# 3. Criar party inimiga baseada na fase
		print("DEBUG: Criando party inimiga...")
		var enemies_party = _create_enemies_party_for_phase(current_phase)
		
		# 4. Executar batalha
		print("⚔️ Iniciando batalha da fase ", current_phase + 1)
		var victory = await _run_battle(allies_party, enemies_party)
		
		print("DEBUG: Resultado da batalha: ", victory)
		
		if victory:
			print("✅ Vitória na fase ", current_phase + 1)
			
			# Se não for a última fase, mostrar cutscene de transição
			if current_phase < max_phases - 1:
				print("DEBUG: Mostrando cutscene de transição...")
				await _play_transition_cutscene(current_phase)
				current_phase += 1  # 🆕 IMPORTANTE: Avançar para próxima fase
			else:
				print("DEBUG: Última fase concluída!")
				break
		else:
			print("❌ Derrota na fase ", current_phase + 1)
			await _play_defeat_cutscene()
			break
	
	# Se completou todas as fases
	if current_phase >= max_phases - 1:
		print("DEBUG: Todas as fases completadas!")
		await _play_victory_cutscene()
	else:
		print("DEBUG: Jogo interrompido na fase ", current_phase + 1)
	
	# Fim do jogo
	status_label.text = "Fim do jogo! Obrigado por jogar!"
	print("🎮 FIM DO JOGO")
	
	# Resetar para o menu
	current_phase = 0
	start_button.visible = true
	if test_button:
		test_button.visible = true
	game_started = false

# 🆕 NOVO: Cutscenes para cada fase
func _play_cutscene(phase_index: int) -> void:
	print("🎬 CUTSCENE Fase ", phase_index + 1)
	
	var cutscenes = [
		"""🌅 FLORESTA DOS ESPÍRITOS

Você acorda em uma floresta densa e misteriosa.
O ar está frio e uma névoa esbranquiçada cobre o solo.
Estranhos sussurros ecoam entre as árvores...

De repente, figuras sombrias emergem da neblina!
Goblins famintos avistam você e avançam com intenções hostis.

Prepare-se para a batalha!""",

		"""🔥 RUÍNAS DO TEMPLO PROIBIDO

Após derrotar os goblins, você adentra um antigo templo élfico.
O ar aqui está pesado com energia arcana corrompida.
Estatuas de guerreiros élficos observam seu avanço...

No salão principal, os GUARDIÕES ÉLFICOS CORROMPIDOS aguardam!
O Xamã Orc Arcano canaliza energias proibidas, 
enquanto seu Campeão bate seu machado no chão, 
causando rachaduras na pedra milenar.

Esta será sua batalha MAIS DIFÍCIL até agora!
Os Guardiões possuem habilidades antigas e sinergias mortais.
ESTRATÉGIA será crucial para sobreviver!"""
	]
	
	var cutscene_text = cutscenes[phase_index] if phase_index < cutscenes.size() else "Próxima fase..."
	
	# Mostrar texto da cutscene
	status_label.text = cutscene_text
	
	# Aguardar input do jogador
	await get_tree().create_timer(0.5).timeout
	status_label.text = cutscene_text + "\n\n[Pressione ESPAÇO ou clique para continuar]"
	
	# Esperar input
	await _wait_for_any_input()
	
	print("✅ Cutscene da fase ", phase_index + 1, " concluída")

# 🆕 NOVO: Cutscene de transição entre fases
func _play_transition_cutscene(phase_index: int) -> void:
	print("🎬 CUTSCENE de Transição")
	
	var transitions = [
		"""✨ VOCÊ VENCEU... POR ENQUANTO

Os goblins recuam para as sombras da floresta.
Sua coragem foi provada, mas o verdadeiro desafio apenas começa.

À frente, as RUÍNAS DO TEMPLO PROIBIDO emanam uma energia
perturbadora e antiga. Você sente uma presença poderosa
e maligna guardando algo dentro...

Os Guardiões Corrompidos que habitam essas ruínas
não são como os goblins - eles são guerreiros treinados,
com táticas e magias antigas.

PREPARE-SE PARA SUA BATALHA MAIS DESAFIADORA!"""
	]
	
	if phase_index < transitions.size():
		status_label.text = transitions[phase_index]
		await get_tree().create_timer(0.5).timeout
		status_label.text = transitions[phase_index] + "\n\n[Pressione ESPAÇO ou clique para continuar]"
		await _wait_for_any_input()
	
	print("✅ Transição concluída")

# 🆕 NOVO: Cutscene de derrota
func _play_defeat_cutscene() -> void:
	print("🎬 CUTSCENE de Derrota")
	
	status_label.text = """💀 DERROTA

Você foi derrotado em batalha...
Sua jornada termina aqui, mas sua coragem não será esquecida.

Os espíritos da floresta acolhem você,
enquanto seus inimigos celebram sua vitória.

Tente novamente quando estiver mais forte!"""
	
	await get_tree().create_timer(0.5).timeout
	status_label.text += "\n\n[Pressione ESPAÇO ou clique para voltar ao menu]"
	await _wait_for_any_input()
	
	# Reiniciar jogo
	current_phase = 0
	start_button.visible = true
	if test_button:
		test_button.visible = true
	game_started = false
	status_label.text = "Pronto! Clique em 'Jogar' para tentar novamente."

# 🆕 NOVO: Cutscene de vitória final
func _play_victory_cutscene() -> void:
	print("🎬 CUTSCENE de Vitória Final")
	
	status_label.text = """🎉 VITÓRIA COMPLETA!

Você derrotou todos os inimigos!
O xamã orc cai ao chão, e as energias malignas
que permeavam o templo começam a se dissipar.

No centro da câmara principal, você encontra
um artefato brilhante - a fonte do poder do templo.

Sua missão está completa!
Você emerge das ruínas como um verdadeiro herói,
pronto para novas aventuras..."""
	
	await get_tree().create_timer(0.5).timeout
	status_label.text += "\n\n[Pressione ESPAÇO ou clique para voltar ao menu]"
	await _wait_for_any_input()
	
	# Voltar ao menu
	current_phase = 0
	start_button.visible = true
	if test_button:
		test_button.visible = true
	game_started = false
	status_label.text = "Vitória! Clique em 'Jogar' para uma nova aventura."

# 🆕 NOVO: Esperar qualquer input
func _wait_for_any_input() -> void:
	print("⏳ Aguardando input do jogador...")
	
	var input_received = false
	
	while not input_received:
		if Input.is_action_just_pressed("ui_accept") or \
		   Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or \
		   Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			input_received = true
		await get_tree().process_frame
	
	print("✅ Input recebido")

# 🆕 ATUALIZADO: Criar party inimiga baseada na fase
func _create_enemies_party_for_phase(phase_index: int) -> Party:
	match phase_index:
		0:
			return _create_goblin_party()
		1:
			return _create_guardian_party()
		_:
			return _create_default_party()

func _create_goblin_party() -> Party:
	var party = Party.new()
	party.name = "Goblins Novatos"
	
	# Goblin 1 - Mais fraco
	var goblin1 = create_enemy_character("Goblin Espião", "Archer", 3, 2, 6, 1)
	goblin1.position = "back"
	party.add_member(goblin1)
	
	# Goblin 2 - Mais fraco
	var goblin2 = create_enemy_character("Goblin Aprendiz", "Warrior", 5, 4, 3, 1)
	goblin2.position = "front"
	party.add_member(goblin2)
	
	# Goblin 3 - Mais fraco
	var goblin3 = create_enemy_character("Goblin Arremessador", "Archer", 2, 1, 5, 1)
	goblin3.position = "back"
	party.add_member(goblin3)
	
	print("✅ Party fase 1 (FÁCIL) criada")
	return party

func _create_guardian_party() -> Party:
	var party = Party.new()
	party.name = "Guardiões do Templo"
	
	# Chefe: Xamã Orc (MAIS FORTE)
	var orc_shaman = create_enemy_character("Xamã Orc Arcano", "Mage", 8, 8, 5, 10)
	orc_shaman.position = "back"
	
	# Bola de fogo mais forte
	var powerful_fireball = create_fireball()
	powerful_fireball.name = "Inferno Arcano"
	powerful_fireball.ap_cost = 6
	powerful_fireball.damage_multiplier = 2.0
	orc_shaman.add_combat_action(powerful_fireball)
	
	# Curse mais forte
	var strong_curse = SupportAction.new()
	strong_curse.name = "Maldição Poderosa"
	strong_curse.ap_cost = 4
	strong_curse.target_type = "enemy"
	strong_curse.buff_attribute = "strength"
	strong_curse.buff_value = -3
	strong_curse.buff_duration = 4
	orc_shaman.add_combat_action(strong_curse)
	
	# Nova habilidade: Proteção Arcana
	var arcane_protection = SupportAction.new()
	arcane_protection.name = "Proteção Arcana"
	arcane_protection.ap_cost = 3
	arcane_protection.target_type = "self"
	arcane_protection.buff_attribute = "defense"
	arcane_protection.buff_value = 5
	arcane_protection.buff_duration = 3
	orc_shaman.add_combat_action(arcane_protection)
	
	party.add_member(orc_shaman)
	
	# Guarda: Orc Campeão (TANK MUITO RESISTENTE)
	var orc_champion = create_enemy_character("Orc Campeão", "Tank", 12, 15, 3, 2)
	orc_champion.position = "front"
	
	# Ataque devastador
	var devastating_attack = AttackAction.new()
	devastating_attack.name = "Golpe Devastador"
	devastating_attack.ap_cost = 5
	devastating_attack.target_type = "enemy"
	devastating_attack.damage_multiplier = 2.0
	devastating_attack.formula = "melee"
	orc_champion.add_combat_action(devastating_attack)
	
	# Provocação forte
	var strong_taunt = SupportAction.new()
	strong_taunt.name = "Provocação Intimidante"
	strong_taunt.ap_cost = 3
	strong_taunt.target_type = "enemy"
	strong_taunt.buff_attribute = "attack"
	strong_taunt.buff_value = -2
	strong_taunt.buff_duration = 3
	orc_champion.add_combat_action(strong_taunt)
	
	# Nova habilidade: Revitalizar
	var revitalize = SupportAction.new()
	revitalize.name = "Revitalizar"
	revitalize.ap_cost = 4
	revitalize.target_type = "self"
	revitalize.buff_attribute = "constitution"
	revitalize.buff_value = 4
	revitalize.buff_duration = 3
	orc_champion.add_combat_action(revitalize)
	
	party.add_member(orc_champion)
	
	# Apoio: Atirador Elite
	var orc_elite = create_enemy_character("Atirador de Elite Orc", "Archer", 8, 7, 10, 4)
	orc_elite.position = "back"
	
	# Flecha rápida e forte
	var rapid_shot = AttackAction.new()
	rapid_shot.name = "Rajada de Flechas"
	rapid_shot.ap_cost = 3
	rapid_shot.target_type = "enemy"
	rapid_shot.damage_multiplier = 1.5
	rapid_shot.formula = "ranged"
	orc_elite.add_combat_action(rapid_shot)
	
	# Disparo preciso
	var precise_shot = AttackAction.new()
	precise_shot.name = "Disparo Preciso"
	precise_shot.ap_cost = 4
	precise_shot.target_type = "enemy"
	precise_shot.damage_multiplier = 1.8
	precise_shot.formula = "ranged"
	orc_elite.add_combat_action(precise_shot)
	
	# Habilidade especial: Postura de Mira
	var aim_stance = SupportAction.new()
	aim_stance.name = "Postura de Mira"
	aim_stance.ap_cost = 2
	aim_stance.target_type = "self"
	aim_stance.buff_attribute = "agility"
	aim_stance.buff_value = 3
	aim_stance.buff_duration = 2
	orc_elite.add_combat_action(aim_stance)
	
	party.add_member(orc_elite)
	
	# 🆕 QUARTO INIMIGO: Assassino
	var orc_assassin = create_enemy_character("Assassino Orc", "Warrior", 9, 6, 9, 3)
	orc_assassin.position = "mid"
	
	# Ataque furtivo
	var sneak_attack = AttackAction.new()
	sneak_attack.name = "Ataque Furtivo"
	sneak_attack.ap_cost = 4
	sneak_attack.target_type = "enemy"
	sneak_attack.damage_multiplier = 1.7
	sneak_attack.formula = "melee"
	orc_assassin.add_combat_action(sneak_attack)
	
	# Golpe rápido
	var quick_strike = AttackAction.new()
	quick_strike.name = "Golpe Rápido"
	quick_strike.ap_cost = 2
	quick_strike.target_type = "enemy"
	quick_strike.damage_multiplier = 1.0
	quick_strike.formula = "melee"
	orc_assassin.add_combat_action(quick_strike)
	
	party.add_member(orc_assassin)
	
	print("⚠️ PARTE 2 - INIMIGOS FORTIFICADOS!")
	print("   Xamã: INT 10 | Campeão: STR 12 CON 15")
	print("   Elite: AGI 10 | Assassino: STR 9 AGI 9")
	print("   TOTAL: 4 INIMIGOS PODEROSOS")
	
	return party
	
func _create_default_party() -> Party:
	var party = Party.new()
	party.name = "Inimigos Básicos"
	
	# Criar um inimigo básico genérico
	var enemy = create_enemy_character("Inimigo Genérico", "Warrior", 5, 5, 5, 5)
	enemy.position = "front"
	party.add_member(enemy)
	
	# Adicionar um segundo inimigo para balancear
	var enemy2 = create_enemy_character("Inimigo Suporte", "Archer", 3, 3, 6, 3)
	enemy2.position = "back"
	party.add_member(enemy2)
	
	print("✅ Party padrão criada: ", party.name)
	return party

# 🆕 ATUALIZADO: Criar personagem inimigo com bônus para fase 2
# 🆕 ATUALIZADO: Criar personagem inimigo SEM tentar acessar max_hp/current_hp
func create_enemy_character(name: String, enemy_class: String, strength: int, constitution: int, agility: int, intelligence: int) -> Character:
	var character = Character.new()
	character.name = name
	
	# 🆕 BÔNUS PARA FASE 2 (fase mais difícil)
	var phase_bonus = 0
	if current_phase == 1:  # Fase 2
		phase_bonus = 1  # +1 em todos os stats para fase 2 (já incluído nos valores acima)
	
	character.strength = strength
	character.constitution = constitution
	character.agility = agility
	character.intelligence = intelligence
	
	# Versão SUPER simplificada para evitar erros
	# Primeiro tenta texturas específicas
	var goblin_path = "res://assets/characters/goblin.png"
	var orc_path = "res://assets/characters/orc.png"
	
	if name.to_lower().contains("goblin") and ResourceLoader.exists(goblin_path):
		character.texture = load(goblin_path)
	elif name.to_lower().contains("orc") and ResourceLoader.exists(orc_path):
		character.texture = load(orc_path)
	else:
		# Fallback
		var warrior_path = "res://assets/characters/warrior.png"
		var hero_path = "res://assets/characters/hero.png"
		var char_path = "res://assets/characters/character.png"
		
		if ResourceLoader.exists(warrior_path):
			character.texture = load(warrior_path)
		elif ResourceLoader.exists(hero_path):
			character.texture = load(hero_path)
		elif ResourceLoader.exists(char_path):
			character.texture = load(char_path)
	
	# Adicionar ações básicas
	character.add_combat_action(create_basic_attack())
	
	# Ações específicas por classe
	match enemy_class:
		"Warrior":
			character.add_combat_action(create_heavy_attack())
		"Mage":
			character.add_combat_action(create_fireball())
		"Archer":
			var quick_shot = AttackAction.new()
			quick_shot.name = "Disparo Rápido"
			quick_shot.ap_cost = 2
			quick_shot.target_type = "enemy"
			quick_shot.damage_multiplier = 0.8
			quick_shot.formula = "ranged"
			character.add_combat_action(quick_shot)
		"Tank":
			var defend_action = create_defend_action()
			defend_action.name = "Postura Defensiva"
			character.add_combat_action(defend_action)
	
	character.calculate_stats()
	
	# 🆕 REMOVIDO: HP extra para fase 2 (causava erro porque Character não tem essas propriedades)
	# if current_phase == 1:
	#     character.max_hp += 20
	#     character.current_hp = character.max_hp
	
	return character

# 🆕 NOVO: Criar ação de defesa para inimigos
func create_defend_action() -> SupportAction:
	var action = SupportAction.new()
	action.name = "Defender"
	action.ap_cost = 2
	action.target_type = "self"
	action.buff_attribute = "defense"
	action.buff_value = 3
	action.buff_duration = 2
	return action

# 🆕 CORRIGIDO: Função _run_battle para manter Main.gd ativo
# 🆕 ATUALIZADO: Adicionado tratamento de erro para evitar o problema "null instance"
func _run_battle(allies_party: Party, enemies_party: Party) -> bool:
	print("⚔️ PREPARANDO BATALHA - Fase ", current_phase + 1)
	
	cleanup_test_character()
	
	var battle_scene_res = preload("res://scenes/BattleScene/BattleScene.tscn")
	var battle_scene = battle_scene_res.instantiate()
	
	# Conectar o sinal ANTES de adicionar à cena
	var battle_finished_promise = battle_scene.battle_finished
	
	# IMPORTANTE: Desconectar sinais anteriores
	if battle_scene.is_connected("battle_finished", Callable(self, "_on_battle_finished")):
		battle_scene.disconnect("battle_finished", Callable(self, "_on_battle_finished"))
	
	# 🆕 NOVO: Verificar se a cena anterior foi limpa corretamente
	await get_tree().process_frame
	
	# Adicionar à cena
	get_tree().root.add_child(battle_scene)
	
	# Esconder o Main temporariamente
	self.visible = false
	
	print("DEBUG: Configurando batalha...")
	battle_scene.call_deferred("setup_battle", allies_party, enemies_party)
	battle_scene.call_deferred("start_battle")
	
	print("⏳ Aguardando término da batalha...")
	
	# Aguardar o sinal
	var battle_result = await battle_finished_promise
	
	print("✅ Batalha finalizada. Vitória: ", battle_result)
	
	# IMPORTANTE: Aguardar um frame para garantir que tudo foi limpo
	await get_tree().process_frame
	
	# 🆕 ATUALIZADO: Limpeza mais segura
	if is_instance_valid(battle_scene):
		print("🧹 Limpando cena de batalha...")
		
		# 🆕 IMPORTANTE: Limpar todos os efeitos persistentes ANTES de remover a cena
		_cleanup_battle_scene_effects(battle_scene)
		
		# Remover do parent
		if battle_scene.get_parent():
			battle_scene.get_parent().remove_child(battle_scene)
		
		# Liberar memória
		battle_scene.queue_free()
		
		# 🆕 Forçar coleta de lixo
		await get_tree().process_frame
	
	# Mostrar o Main novamente
	self.visible = true
	
	print("DEBUG: Retornando ao fluxo do jogo. Fase: ", current_phase)
	
	return battle_result

# 🆕 NOVA FUNÇÃO: Limpar efeitos da cena de batalha antes de destruí-la
func _cleanup_battle_scene_effects(battle_scene: Node):
	"""Limpa todos os efeitos persistentes antes de destruir a cena - VERSÃO SEGURA"""
	print("🧹 Limpando efeitos da BattleScene...")
	
	# 🆕 Usar uma abordagem segura baseada em nomes e métodos
	# 1. Procurar por nós que sabemos que podem ter efeitos persistentes
	var nodes_to_cleanup = []
	
	# Procurar recursivamente
	_find_nodes_with_persistent_effects(battle_scene, nodes_to_cleanup)
	
	# Limpar todos os nós encontrados
	for node in nodes_to_cleanup:
		if is_instance_valid(node):
			print("   🧹 Limpando: ", node.name)
			if node.has_method("clear_all_persistent_effects"):
				node.clear_all_persistent_effects()
			elif node.has_method("cleanup"):
				node.cleanup()
	
	print("✅ Efeitos da BattleScene limpos")

func _find_nodes_with_persistent_effects(node: Node, result: Array):
	"""Encontra recursivamente todos os nós com efeitos persistentes"""
	if not node:
		return
	
	# Verificar este nó
	if (node.has_method("clear_all_persistent_effects") or 
		node.has_method("cleanup") or
		"Support" in node.name or
		"Action" in node.name):
		result.append(node)
	
	# Verificar filhos recursivamente
	for child in node.get_children():
		_find_nodes_with_persistent_effects(child, result)

# 🆕 NOVA FUNÇÃO: Limpar referências de forma segura
func _disconnect_all_signals():
	"""Desconecta todos os sinais para evitar referências pendentes"""
	print("🔌 Desconectando todos os sinais...")
	# Esta função pode ser expandida conforme necessário
	pass

func cleanup_test_character():
	if test_character_view:
		test_character_view.queue_free()
		test_character_view = null
	
	for button in animation_buttons:
		if is_instance_valid(button):
			button.queue_free()
	animation_buttons.clear()
	
	current_character = null

# --- FUNÇÕES ORIGINAIS DO SEU MAIN.GD ---

func load_all_attacks():
	print("🔍 Procurando ataques em res://data/characters/ataques/")
	
	var attacks_base_path = "res://data/characters/ataques/"
	
	var attack_directories = [
		"actions/meele/",
		"actions/magic/", 
		"actions/ranged/",
		"actions/special/"
	]
	
	loaded_attacks.clear()
	
	for dir_path in attack_directories:
		var full_path = attacks_base_path + dir_path
		var dir = DirAccess.open(full_path)
		
		if dir:
			print("📁 Procurando em: ", full_path)
			
			dir.list_dir_begin()
			var file_name = dir.get_next()
			
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".tres"):
					var attack_full_path = full_path + file_name
					var attack = load_attack(attack_full_path)
					
					if attack:
						var attack_data = {
							"name": attack.name,
							"path": attack_full_path,
							"resource": attack,
							"type": dir_path.replace("actions/", "").replace("/", "")
						}
						loaded_attacks.append(attack_data)
						print("✅ Ataque carregado: ", file_name, " -> ", attack.name, " (", attack_data["type"], ")")
					else:
						print("❌ Falha ao carregar ataque: ", file_name)
				
				file_name = dir.get_next()
			
			dir.list_dir_end()
		else:
			print("⚠️ Diretório não encontrado: ", full_path)
	
	print("🎯 Total de ataques carregados: ", loaded_attacks.size())

func setup_battle(allies_party: Party, enemies_party: Party) -> void:
	print("Configurando batalha: Aliados %d, Inimigos %d" % [allies_party.size(), enemies_party.size()])
	# Faça sua configuração normal aqui (carregar personagens, UI, etc.)

func start_battle() -> void:
	print("Batalha iniciada")
	# Insira sua lógica real de batalha aqui
	# Exemplo simples de delay para simular batalha
	await get_tree().create_timer(3).timeout
	_on_battle_ended(true)  # Simula vitória para teste

func _on_battle_ended(victory: bool):
	print("Batalha finalizada. Vitória: ", victory)
	battle_ended = true
	battle_finished.emit(victory)

func load_attack(path: String) -> AttackAction:
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is AttackAction:
			print("   ✅ Ataque carregado: ", path)
			print("      Nome: ", resource.name)
			print("      AP Cost: ", resource.ap_cost)
			print("      Sprite Frames: ", resource.slash_sprite_frames != null)
			print("      Target Type: ", resource.target_type)
			return resource
		else:
			print("   ❌ Arquivo não é um AttackAction: ", path)
			return null
	else:
		print("   ❌ Arquivo não encontrado: ", path)
		return null

func find_and_load_characters():
	print("🔍 Procurando personagens em res://data/characters/aliados/")
	
	var aliados_path = "res://data/characters/aliados/"
	var dir = DirAccess.open(aliados_path)
	
	if dir:
		found_characters.clear()
		
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var full_path = aliados_path + file_name
				var character = load_character(full_path)
				
				if character:
					check_character_attacks(character)
					
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

func check_character_attacks(character: Character):
	print("   🔍 Verificando ataques de: ", character.name)
	
	if character.combat_actions and character.combat_actions.size() > 0:
		print("   🎯 Combat Actions encontradas: ", character.combat_actions.size())
		for i in range(character.combat_actions.size()):
			var action = character.combat_actions[i]
			if action:
				print("     ", i, ": ", action.name)
				print("       AP Cost: ", action.ap_cost)
				print("       Sprite Frames: ", action.slash_sprite_frames != null)
				print("       Target Type: ", action.target_type)
			else:
				print("     ", i, ": ❌ Ação nula")
	else:
		print("   ⚠️ Nenhuma combat_action encontrada")
	
	if character.basic_actions and character.basic_actions.size() > 0:
		print("   🎯 Basic Actions encontradas: ", character.basic_actions.size())
		for i in range(character.basic_actions.size()):
			var action = character.basic_actions[i]
			if action:
				print("     ", i, ": ", action.name)
			else:
				print("     ", i, ": ❌ Ação nula")
	else:
		print("   ⚠️ Nenhuma basic_action encontrada")

func create_fallback_characters():
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
		
		var display_name = char_data.name
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
		
		if not char_data.path.begins_with("fallback://"):
			button.tooltip_text = char_data.path
		
		# Correção: usar função lambda para capturar valores
		button.pressed.connect(func(): _on_character_button_pressed(char_data.resource, char_data.name))
		
		add_child(button)
		character_buttons.append(button)
	
	print("✅ Botões de personagens criados: ", character_buttons.size())

func _on_character_button_pressed(character: Character, character_name: String):
	print("👤 Selecionando personagem: ", character_name)
	status_label.text = "Carregando: " + character_name
	
	cleanup_test_character()
	
	current_character = character
	load_character_view(character)
	create_animation_buttons()
	status_label.text = "Pronto: " + character_name + " - Selecione uma animação"

func create_allies_party_from_found() -> Party:
	var party = Party.new()
	party.name = "Heróis"
	
	var max_members = min(4, found_characters.size())
	
	for i in range(max_members):
		var char_data = found_characters[i]
		party.add_member(char_data.resource)
		print("✅ Adicionado à party: " + char_data.name)
	
	if party.members.is_empty():
		print("⚠️ Nenhum personagem encontrado, criando party fallback...")
		party.add_member(create_fallback_character("Guerreiro", "Warrior"))
		party.add_member(create_fallback_character("Mago", "Mage"))
		party.add_member(create_fallback_character("Arqueiro", "Archer"))
	
	print("✅ Party aliada criada: " + party.name + " com " + str(party.members.size()) + " membros")
	return party
	
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
	
	# 🆕 ATUALIZADO: Adiciona ataques carregados se disponíveis
	add_loaded_attacks_to_character(character, character_class)
	
	character.calculate_stats()
	return character

# 🆕 NOVA FUNÇÃO: Adicionar ataques carregados ao personagem
func add_loaded_attacks_to_character(character: Character, character_class: String):
	# Adiciona ações básicas padrão primeiro
	character.add_combat_action(create_basic_attack())
	
	# 🆕 Tenta adicionar ataques carregados baseado na classe
	var class_attacks_added = 0
	
	for attack_data in loaded_attacks:
		var attack = attack_data["resource"]
		var attack_type = attack_data["type"]
		
		# Adiciona baseado no tipo de personagem e tipo de ataque
		if character_class == "Warrior" and attack_type == "meele":
			character.add_combat_action(attack)
			class_attacks_added += 1
			print("   ✅ Ataque adicionado (Guerreiro): ", attack.name)
		elif character_class == "Mage" and attack_type == "magic":
			character.add_combat_action(attack)
			class_attacks_added += 1
			print("   ✅ Ataque adicionado (Mago): ", attack.name)
		elif character_class == "Archer" and attack_type == "ranged":
			character.add_combat_action(attack)
			class_attacks_added += 1
			print("   ✅ Ataque adicionado (Arqueiro): ", attack.name)
	
	# Fallback se não encontrou ataques específicos
	if class_attacks_added == 0:
		print("   ⚠️ Nenhum ataque específico encontrado, usando fallbacks")
		if character_class == "Mage" or character_class == "Mago":
			character.add_combat_action(create_fireball())
		elif character_class == "Warrior" or character_class == "Guerreiro":
			character.add_combat_action(create_heavy_attack())
		elif character_class == "Archer" or character_class == "Arqueiro":
			var arrow_shot = AttackAction.new()
			arrow_shot.name = "Flecha Precisa"
			arrow_shot.ap_cost = 3
			arrow_shot.target_type = "enemy"
			arrow_shot.damage_multiplier = 1.2
			arrow_shot.formula = "ranged"
			character.add_combat_action(arrow_shot)

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
		# Correção: usar função lambda para capturar valores
		button.pressed.connect(func(): _on_animation_button_pressed(anim_type, attack_type))
		
		add_child(button)
		animation_buttons.append(button)
	
	# 🆕 ATUALIZADO: Botões para ataques específicos do personagem
	create_attack_buttons()
	
	# Botão para limpar/resetar
	var clear_button = Button.new()
	clear_button.text = "❌ Limpar Animações"
	clear_button.position = Vector2(650, 500)
	clear_button.size = Vector2(180, 40)
	clear_button.pressed.connect(_on_clear_button_pressed)
	add_child(clear_button)
	animation_buttons.append(clear_button)
	
	print("✅ Botões de animação criados: ", animation_buttons.size())

# 🆕 NOVA FUNÇÃO: Criar botões para ataques específicos
func create_attack_buttons():
	if not current_character:
		return
	
	var attack_button_margin = 10
	var attack_button_width = 200
	var attack_button_height = 45
	var start_x = 650
	var start_y = 100
	
	var attack_count = 0
	
	# 🆕 Botões para combat_actions
	if current_character.combat_actions and current_character.combat_actions.size() > 0:
		print("🎯 Criando botões para combat_actions: ", current_character.combat_actions.size())
		
		for i in range(current_character.combat_actions.size()):
			var action = current_character.combat_actions[i]
			if action and action is AttackAction:
				var button = Button.new()
				button.text = "🎯 " + action.name + "\n" + str(action.ap_cost) + " AP"
				button.position = Vector2(start_x, start_y + attack_count * (attack_button_height + attack_button_margin))
				button.size = Vector2(attack_button_width, attack_button_height)
				
				# Cor diferente baseado no tipo de ataque
				if action.slash_sprite_frames:
					button.add_theme_color_override("font_color", Color.GREEN)
					button.tooltip_text = "Tem animação de slash!"
				else:
					button.add_theme_color_override("font_color", Color.YELLOW)
					button.tooltip_text = "Sem animação de slash"
				
				# Correção: usar função lambda para capturar a ação
				var captured_action = action  # Capturar em variável local
				button.pressed.connect(func(): _on_specific_attack_pressed(captured_action))
				
				add_child(button)
				animation_buttons.append(button)
				attack_count += 1
				
				print("   ✅ Botão criado para: ", action.name)

# 🆕 NOVA FUNÇÃO: Manipulador para ataques específicos
func _on_specific_attack_pressed(action: AttackAction):
	if not test_character_view or not current_character:
		status_label.text = "Nenhum personagem selecionado!"
		return
	
	print("🎯 Testando ataque específico: ", action.name)
	status_label.text = "Testando: " + action.name + " - " + current_character.name
	
	# 🆕 Aplicar o slash effect diretamente
	if action.slash_sprite_frames:
		var slash_config = action.get_slash_config()
		print("   Slash Config: ", slash_config)
		
		if slash_config.get("sprite_frames"):
			print("   ✅ Sprite Frames encontrado - aplicando slash")
			test_character_view.apply_slash_effect(slash_config)
			status_label.text = "✨ " + action.name + " - Slash aplicado!"
		else:
			print("   ❌ Sprite Frames não encontrado no slash config")
			status_label.text = "❌ " + action.name + " - Sem sprite frames"
	else:
		print("   ⚠️ Este ataque não tem slash_sprite_frames")
		status_label.text = "⚠️ " + action.name + " - Sem animação de slash"

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
