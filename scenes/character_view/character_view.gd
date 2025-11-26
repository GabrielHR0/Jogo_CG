extends Node2D
class_name CharacterView

@export var character: Character
@export var auto_setup: bool = true

# Tamanhos ajustados
@export var character_scale: Vector2 = Vector2(0.6, 0.6)
@export var max_character_size: Vector2 = Vector2(120, 180)

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Variável para controlar o animated sprite atual
var current_animated_sprite: AnimatedSprite2D = null
var current_damage_tween: Tween = null

# 🆕 NOVO: Variáveis para sistema de dash
var original_position: Vector2 = Vector2.ZERO
var is_dashing: bool = false
var dash_tween: Tween = null

# 🆕 NOVO: Guarda o tamanho original do sprite principal
var original_sprite_size: Vector2 = Vector2.ZERO

# 🆕 NOVO: Componentes da barra de vida
var health_bar_background: ColorRect
var health_bar_fill: ColorRect
var health_bar_container: Control

# 🆕 CORREÇÃO: Variável para rastrear HP anterior
var last_known_hp: int = 0
var last_known_max_hp: int = 0

# 🆕 CORREÇÃO: Flag para controlar se a barra já foi criada
var health_bar_created: bool = false

func _ready():
	if auto_setup and character:
		setup_character()

func setup_character():
	# Configura a sprite principal
	if character.texture:
		sprite.texture = character.texture
		adjust_sprite_size()
		center_sprite()
		# 🆕 GUARDA o tamanho original
		original_sprite_size = sprite.texture.get_size() * sprite.scale
	
	# 🆕 NOVO: Guarda a posição original
	original_position = position
	
	# Configurações do AnimationData
	if character.animation_data:
		var combined_scale = character.animation_data.animation_scale * character_scale
		scale = combined_scale
		position += character.animation_data.sprite_offset
	else:
		scale = character_scale
	
	# 🆕 NOVO: Cria a barra de vida (apenas uma vez)
	if not health_bar_created:
		create_health_bar()
		health_bar_created = true
	
	# Conecta aos sinais do personagem
	character.animation_requested.connect(_on_animation_requested)
	character.damage_animation_requested.connect(_on_damage_animation_requested)
	
	# 🆕 CORREÇÃO: Inicializa o rastreamento de HP
	last_known_hp = character.current_hp
	last_known_max_hp = character.get_max_hp()
	
	# 🆕 NOVO: Atualiza a barra de vida inicialmente
	update_health_bar()

# 🆕 CORREÇÃO: Verificação contínua de mudanças de HP
func _process(delta):
	if character and health_bar_created:
		# Verifica se o HP atual mudou
		if character.current_hp != last_known_hp or character.get_max_hp() != last_known_max_hp:
			last_known_hp = character.current_hp
			last_known_max_hp = character.get_max_hp()
			update_health_bar()

# 🆕 NOVO: Função para criar a barra de vida (APENAS UMA VES)
func create_health_bar():
	# Container principal
	health_bar_container = Control.new()
	health_bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Calcula a posição da barra baseada na posição atual da Sprite2D
	var bar_width = original_sprite_size.x * 0.8
	var bar_height = 6
	
	# 🆕 CORREÇÃO: Posiciona baseado na posição atual da Sprite2D
	# Pega a posição atual da sprite
	var sprite_position = sprite.position
	var sprite_size = original_sprite_size
	
	# Centraliza horizontalmente com a sprite
	var bar_x = sprite_position.x - bar_width / 2
	# Posiciona acima da sprite
	var bar_y = sprite_position.y - sprite_size.y / 2 - 20
	
	health_bar_container.position = Vector2(bar_x, bar_y)
	health_bar_container.size = Vector2(bar_width, bar_height)
	
	# Fundo da barra (borda)
	health_bar_background = ColorRect.new()
	health_bar_background.size = Vector2(bar_width + 2, bar_height + 2)
	health_bar_background.position = Vector2(-1, -1)
	health_bar_background.color = Color.BLACK
	health_bar_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Preenchimento da barra (vida)
	health_bar_fill = ColorRect.new()
	health_bar_fill.size = Vector2(bar_width, bar_height)
	health_bar_fill.position = Vector2(0, 0)
	health_bar_fill.color = Color.GREEN
	health_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Adiciona à cena
	health_bar_container.add_child(health_bar_background)
	health_bar_container.add_child(health_bar_fill)
	add_child(health_bar_container)
	
	print("Barra de vida criada para ", character.name, " na posição: ", health_bar_container.position, " (Sprite pos: ", sprite_position, ")")

# 🆕 NOVO: Função para atualizar a barra de vida (APENAS ATUALIZA O TAMANHO/COR)
func update_health_bar():
	if not health_bar_fill or not character or not health_bar_created:
		return
	
	var health_ratio = float(character.current_hp) / float(character.get_max_hp())
	health_ratio = max(0, health_ratio)  # Garante que não seja negativo
	
	# 🆕 CORREÇÃO: Atualiza apenas a largura do preenchimento, não o container inteiro
	var bar_width = health_bar_container.size.x
	health_bar_fill.size.x = bar_width * health_ratio
	
	# Muda a cor baseado na porcentagem de vida
	if health_ratio > 0.6:
		health_bar_fill.color = Color.GREEN
	elif health_ratio > 0.3:
		health_bar_fill.color = Color.YELLOW
	else:
		health_bar_fill.color = Color.RED
	
	# Mostra ou esconde a barra baseado na vida
	health_bar_container.visible = character.is_alive()

func center_sprite():
	if not sprite.texture:
		return
	
	var texture_size = sprite.texture.get_size() * sprite.scale
	sprite.position = Vector2(-texture_size.x / 2, -texture_size.y / 2)

func adjust_sprite_size():
	if not sprite.texture:
		return
	
	var texture_size = sprite.texture.get_size()
	var scale_ratio = min(
		max_character_size.x / texture_size.x,
		max_character_size.y / texture_size.y
	)
	sprite.scale = Vector2(scale_ratio, scale_ratio)

func _on_animation_requested(animation_name: String, attack_type: String):
	stop_current_animation()
	
	match animation_name:
		"attack":
			play_attack_animation(attack_type)
		"defend":
			play_defend_animation()
		"idle":
			play_idle_animation()
		"walk":
			play_walk_animation()
		"victory":
			play_victory_animation()
		"defeat":
			play_defeat_animation()
	
	# 🆕 CORREÇÃO: Remove a atualização duplicada da barra de vida aqui
	# A barra já é atualizada automaticamente no _process

func _on_damage_animation_requested():
	stop_current_animation()
	play_damage_animation()
	
	# 🆕 CORREÇÃO: Remove a atualização duplicada da barra de vida aqui
	# A barra já é atualizada automaticamente no _process

# 🆕 ATUALIZADO: Função de ataque com sistema de dash
func play_attack_animation(attack_type: String):
	var anim_name = "ataque"
	
	if has_custom_animation(anim_name):
		play_spriteframes_animation(anim_name, false)
		return
	
	print("🎬 CharacterView: Ataque iniciado - tipo: ", attack_type)
	
	# 🆕 NOVO: Sistema de dash apenas para melee
	if attack_type == "melee":
		perform_melee_dash_attack()
	else:
		# Para outros tipos de ataque, usa animação básica
		var tween = create_tween()
		tween.tween_property(sprite, "position", sprite.position + Vector2(10, -5), 0.1)
		tween.tween_property(sprite, "position", sprite.position, 0.1)
	
	# 🆕 CORREÇÃO: Reposiciona a barra apenas se necessário
	if health_bar_created:
		reposition_health_bar()

# 🆕 NOVA FUNÇÃO: Sistema de dash para ataques melee
func perform_melee_dash_attack():
	if is_dashing:
		return
	
	print("⚔️ Iniciando dash de ataque melee")
	is_dashing = true
	
	# 🆕 1. Pequeno movimento para trás (preparação)
	var prep_tween = create_tween()
	prep_tween.tween_property(self, "position", position + Vector2(-20, 0), 0.1)
	prep_tween.tween_callback(perform_dash_forward)

# 🆕 NOVA FUNÇÃO: Executar dash para frente
func perform_dash_forward():
	print("   💨 Dash para frente")
	
	# 🆕 2. Dash rápido para frente
	var dash_distance = 150.0  # Distância do dash
	var dash_duration = 0.2    # Duração rápida
	
	dash_tween = create_tween()
	dash_tween.tween_property(self, "position", position + Vector2(dash_distance, 0), dash_duration)
	dash_tween.tween_callback(perform_attack_animation)

# 🆕 NOVA FUNÇÃO: Executar animação de ataque durante o dash
func perform_attack_animation():
	print("   🗡️ Executando animação de ataque durante dash")
	
	# 🆕 3. Animação de ataque durante o pico do dash
	var attack_tween = create_tween()
	attack_tween.tween_property(sprite, "position", sprite.position + Vector2(15, -8), 0.1)
	attack_tween.tween_property(sprite, "position", sprite.position, 0.1)
	attack_tween.tween_callback(return_from_dash)

# 🆕 NOVA FUNÇÃO: Retornar da posição de dash
func return_from_dash():
	print("   ↩️ Retornando da posição de dash")
	
	# 🆕 4. Retornar para posição original
	var return_tween = create_tween()
	return_tween.tween_property(self, "position", original_position, 0.3)
	return_tween.tween_callback(finish_dash_attack)

# 🆕 NOVA FUNÇÃO: Finalizar sequência de dash
func finish_dash_attack():
	print("   ✅ Sequência de dash concluída")
	is_dashing = false
	
	# Garantir que está na posição exata original
	position = original_position
	
	# Voltar para animação idle
	play_idle_animation()

# 🆕 NOVA FUNÇÃO: Dash em direção a um alvo específico
func dash_towards_target(target_position: Vector2, dash_speed: float = 300.0):
	if is_dashing:
		return
	
	print("🎯 Dash em direção ao alvo: ", target_position)
	is_dashing = true
	
	# Calcular direção e distância
	var direction = (target_position - position).normalized()
	var dash_distance = min(position.distance_to(target_position) * 0.7, 200.0)  # 70% da distância, máximo 200
	
	var dash_target = position + (direction * dash_distance)
	
	# 🆕 1. Pequena preparação para trás
	var prep_tween = create_tween()
	prep_tween.tween_property(self, "position", position - (direction * 30), 0.1)
	prep_tween.tween_callback(perform_targeted_dash.bind(dash_target, direction))

# 🆕 NOVA FUNÇÃO: Dash direcionado
func perform_targeted_dash(dash_target: Vector2, direction: Vector2):
	print("   💨 Dash direcionado")
	
	# 🆕 2. Dash para o alvo
	var dash_duration = 0.25
	
	dash_tween = create_tween()
	dash_tween.tween_property(self, "position", dash_target, dash_duration)
	dash_tween.tween_callback(perform_targeted_attack.bind(direction))

# 🆕 NOVA FUNÇÃO: Ataque durante dash direcionado
func perform_targeted_attack(direction: Vector2):
	print("   🗡️ Ataque durante dash direcionado")
	
	# 🆕 3. Animação de ataque
	var attack_tween = create_tween()
	attack_tween.tween_property(sprite, "position", sprite.position + (direction * 20), 0.1)
	attack_tween.tween_property(sprite, "position", sprite.position, 0.1)
	attack_tween.tween_callback(return_from_targeted_dash)

# 🆕 NOVA FUNÇÃO: Retornar de dash direcionado
func return_from_targeted_dash():
	print("   ↩️ Retornando de dash direcionado")
	
	# 🆕 4. Retornar para posição original
	var return_tween = create_tween()
	return_tween.tween_property(self, "position", original_position, 0.4)
	return_tween.tween_callback(finish_targeted_dash)

# 🆕 NOVA FUNÇÃO: Finalizar dash direcionado
func finish_targeted_dash():
	print("   ✅ Dash direcionado concluído")
	is_dashing = false
	position = original_position
	play_idle_animation()

# 🆕 NOVA FUNÇÃO: Parar dash se necessário
func stop_dash():
	if dash_tween and dash_tween.is_valid():
		dash_tween.kill()
	
	if is_dashing:
		# Retornar imediatamente para posição original
		var return_tween = create_tween()
		return_tween.tween_property(self, "position", original_position, 0.2)
		return_tween.tween_callback(func(): is_dashing = false)

func play_damage_animation():
	stop_damage_tween()
	stop_dash()  # 🆕 Parar dash se estiver acontecendo
	
	if has_custom_animation("dano"):
		play_spriteframes_animation("dano", false)
		return
	
	current_damage_tween = create_tween()
	current_damage_tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	current_damage_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	current_damage_tween.finished.connect(_on_damage_animation_finished)

func _on_damage_animation_finished():
	stop_damage_tween()
	play_idle_animation()

func stop_damage_tween():
	if current_damage_tween and current_damage_tween.is_valid():
		current_damage_tween.kill()
		current_damage_tween = null

func play_defend_animation():
	if has_custom_animation("defesa"):
		play_spriteframes_animation("defesa", false)
		return
	
	var tween = create_tween()
	tween.tween_property(sprite, "scale", sprite.scale * Vector2(1.08, 0.95), 0.1)
	tween.tween_property(sprite, "scale", sprite.scale, 0.1)

func play_idle_animation():
	stop_dash()  # 🆕 Garantir que não está em dash
	
	if has_custom_animation("parado"):
		play_spriteframes_animation("parado", true)
		return
	
	reset_to_idle()

func play_walk_animation():
	if has_custom_animation("andar"):
		play_spriteframes_animation("andar", true)
		return
	
	var tween = create_tween()
	tween.tween_property(sprite, "position", sprite.position + Vector2(0, -4), 0.3)
	tween.tween_property(sprite, "position", sprite.position, 0.3)
	
	# 🆕 CORREÇÃO: Reposiciona a barra apenas se necessário
	if health_bar_created:
		reposition_health_bar()

func play_victory_animation():
	if has_custom_animation("vitoria"):
		play_spriteframes_animation("vitoria", false)
		return
	
	var tween = create_tween()
	tween.tween_property(sprite, "position", sprite.position + Vector2(0, -15), 0.2)
	tween.tween_property(sprite, "position", sprite.position, 0.2)
	
	# 🆕 CORREÇÃO: Reposiciona a barra apenas se necessário
	if health_bar_created:
		reposition_health_bar()

func play_defeat_animation():
	if has_custom_animation("derrota"):
		play_spriteframes_animation("derrota", false)
		return
	
	var tween = create_tween()
	tween.tween_property(sprite, "rotation_degrees", 60, 0.5)
	tween.parallel().tween_property(sprite, "position", sprite.position + Vector2(0, 12), 0.5)
	
	# 🆕 CORREÇÃO: Reposiciona a barra apenas se necessário
	if health_bar_created:
		reposition_health_bar()
	
	# 🆕 NOVO: Esconde a barra de vida quando derrotado
	if health_bar_container:
		health_bar_container.visible = false

func has_custom_animation(animation_name: String) -> bool:
	return (character.animation_data and 
			character.animation_data.sprite_frames and 
			character.animation_data.sprite_frames.has_animation(animation_name))

func play_spriteframes_animation(animation_name: String, should_loop: bool = false):
	if not has_custom_animation(animation_name):
		return
	
	stop_current_animation()
	
	current_animated_sprite = AnimatedSprite2D.new()
	current_animated_sprite.sprite_frames = character.animation_data.sprite_frames
	
	# Configura o loop
	character.animation_data.sprite_frames.set_animation_loop(animation_name, should_loop)
	
	# 🆕 CORREÇÃO: CALCULA ESCALA EXATA para ficar do MESMO TAMANHO do sprite principal
	adjust_animated_sprite_to_exact_size()
	
	current_animated_sprite.z_index = sprite.z_index + 1  # 🆕 CORREÇÃO: Fica acima do sprite principal
	
	sprite.visible = false
	add_child(current_animated_sprite)
	
	if not should_loop:
		current_animated_sprite.animation_finished.connect(_on_animation_finished_once)
	
	current_animated_sprite.play(animation_name)

# 🆕 CORREÇÃO: FUNÇÃO MELHORADA - TAMANHO EXATO
func adjust_animated_sprite_to_exact_size():
	if not current_animated_sprite or not character.animation_data:
		return
	
	# Pega o primeiro frame da animação atual
	var first_frame = character.animation_data.sprite_frames.get_frame_texture(current_animated_sprite.animation, 0)
	if not first_frame:
		return
	
	var frame_size = first_frame.get_size()
	
	# 🆕 CALCULA a escala para ter o MESMO TAMANHO do sprite principal
	var target_scale_x = original_sprite_size.x / frame_size.x
	var target_scale_y = original_sprite_size.y / frame_size.y
	
	# 🆕 USA a MESMA escala em ambos os eixos para não distorcer
	var uniform_scale = min(target_scale_x, target_scale_y)
	
	current_animated_sprite.scale = Vector2(uniform_scale, uniform_scale)
	
	# 🆕 CENTRALIZA exatamente na mesma posição do sprite principal
	var scaled_size = frame_size * uniform_scale
	current_animated_sprite.position = Vector2(-scaled_size.x / 2, -scaled_size.y / 2)

func _on_animation_finished_once():
	stop_current_animation()
	play_idle_animation()

func stop_current_animation():
	stop_damage_tween()
	stop_dash()  # 🆕 Parar dash também
	
	if current_animated_sprite and is_instance_valid(current_animated_sprite):
		if current_animated_sprite.animation_finished.is_connected(_on_animation_finished_once):
			current_animated_sprite.animation_finished.disconnect(_on_animation_finished_once)
		
		current_animated_sprite.stop()
		current_animated_sprite.queue_free()
		current_animated_sprite = null
	
	for child in get_children():
		if child is AnimatedSprite2D and child != current_animated_sprite:
			if child.animation_finished.is_connected(_on_animation_finished_once):
				child.animation_finished.disconnect(_on_animation_finished_once)
			child.queue_free()
	
	sprite.visible = true
	
	# Restaura loops para animações contínuas
	if character.animation_data and character.animation_data.sprite_frames:
		if character.animation_data.sprite_frames.has_animation("parado"):
			character.animation_data.sprite_frames.set_animation_loop("parado", true)
		if character.animation_data.sprite_frames.has_animation("andar"):
			character.animation_data.sprite_frames.set_animation_loop("andar", true)
	
	# 🆕 GARANTE que o sprite principal volte com tamanho correto
	if character.texture:
		adjust_sprite_size()
		center_sprite()
	
	# 🆕 CORREÇÃO: Reposiciona a barra apenas se necessário
	if health_bar_created:
		reposition_health_bar()

func reset_to_idle():
	stop_current_animation()
	
	if has_custom_animation("parado"):
		play_spriteframes_animation("parado", true)
		return
	
	var tween = create_tween()
	tween.tween_property(sprite, "position", Vector2(-sprite.texture.get_size().x * sprite.scale.x / 2, -sprite.texture.get_size().y * sprite.scale.y / 2), 0.2)
	tween.parallel().tween_property(sprite, "scale", sprite.scale, 0.2)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.2)
	tween.parallel().tween_property(sprite, "rotation_degrees", 0, 0.2)
	
	# 🆕 CORREÇÃO: Reposiciona a barra apenas se necessário
	if health_bar_created:
		reposition_health_bar()
	
	# 🆕 NOVO: Mostra a barra de vida ao voltar ao idle (se estiver vivo)
	if health_bar_container and character and character.is_alive():
		health_bar_container.visible = true

# 🆕 NOVO: Função para forçar atualização da barra de vida externamente
func refresh_health_display():
	update_health_bar()

# 🆕 NOVO: Função para reposicionar a barra baseada na posição atual da Sprite2D
func reposition_health_bar():
	if health_bar_container and sprite.texture and health_bar_created:
		var bar_width = original_sprite_size.x * 0.8
		var bar_height = 6
		
		# Pega a posição atual da sprite
		var sprite_position = sprite.position
		var sprite_size = original_sprite_size
		
		# Centraliza horizontalmente com a sprite
		var bar_x = sprite_position.x - bar_width / 2
		# Posiciona acima da sprite
		var bar_y = sprite_position.y - sprite_size.y / 2 - 20
		
		health_bar_container.position = Vector2(bar_x, bar_y)
		health_bar_container.size = Vector2(bar_width, bar_height)
		
		# 🆕 CORREÇÃO: NÃO atualiza o tamanho do fundo e preenchimento aqui
		# Isso fazia a barra resetar. O tamanho é mantido constante.

# 🆕 NOVO: Função chamada quando o personagem morre
func on_character_died():
	if health_bar_container:
		health_bar_container.visible = false
	update_health_bar()

# 🆕 NOVO: Função para limpar recursos
func cleanup():
	if health_bar_container and is_instance_valid(health_bar_container):
		health_bar_container.queue_free()
		health_bar_created = false
	stop_current_animation()

# 🆕 NOVO: SISTEMA DE SLASH EFFECTS - CORREÇÃO CRÍTICA
func apply_slash_effect(slash_config: Dictionary):
	if not is_instance_valid(sprite):
		return
	
	print("🗡️ Aplicando slash effect em ", character.name)
	print("   Personagem position:", position)
	print("   Sprite position:", sprite.position)
	print("   Sprite global position:", sprite.global_position)
	
	# Criar o AnimatedSprite2D para o slash
	var slash_sprite = AnimatedSprite2D.new()
	slash_sprite.sprite_frames = slash_config.get("sprite_frames")
	slash_sprite.scale = slash_config.get("scale", Vector2(1, 1))
	slash_sprite.modulate = slash_config.get("color", Color.WHITE)
	slash_sprite.flip_h = slash_config.get("flip_h", false)
	slash_sprite.flip_v = slash_config.get("flip_v", false)
	slash_sprite.z_index = slash_config.get("z_index", 1000)
	slash_sprite.centered = true
	
	# 🆕 CORREÇÃO CRÍTICA: Usar top_level para ficar acima de TUDO
	slash_sprite.top_level = true
	slash_sprite.z_as_relative = false
	
	# 🆕 CORREÇÃO: Calcular posição GLOBAL correta
	var slash_offset = slash_config.get("offset", Vector2.ZERO)
	var global_slash_position = global_position + sprite.position + slash_offset
	
	slash_sprite.global_position = global_slash_position
	
	print("   Slash global position:", slash_sprite.global_position)
	print("   Slash z-index:", slash_sprite.z_index)
	print("   Slash top_level:", slash_sprite.top_level)
	
	# Adicionar à cena raiz para garantir visibilidade
	get_tree().current_scene.add_child(slash_sprite)
	
	# Verificar animação
	if slash_sprite.sprite_frames:
		var anim_names = slash_sprite.sprite_frames.get_animation_names()
		print("   Animations available:", anim_names)
		
		if anim_names.size() > 0:
			var anim_to_play = "default" if slash_sprite.sprite_frames.has_animation("default") else anim_names[0]
			
			# 🆕 CORREÇÃO CRÍTICA: DESABILITAR LOOP da animação
			slash_sprite.sprite_frames.set_animation_loop(anim_to_play, false)
			
			slash_sprite.play(anim_to_play)
			print("   Playing animation (NO LOOP):", anim_to_play)
	else:
		print("   ❌ NO SPRITE FRAMES!")
		slash_sprite.queue_free()
		return
	
	# Conectar sinal de animação terminada
	slash_sprite.animation_finished.connect(_on_slash_animation_finished.bind(slash_sprite))
	
	print("   ✅ Slash sprite criado")

func _on_slash_animation_finished(slash_sprite: AnimatedSprite2D):
	print("   🗑️ Animação de slash terminada - removendo sprite")
	if slash_sprite and is_instance_valid(slash_sprite):
		slash_sprite.queue_free()

# 🆕 NOVO: Método para aplicar múltiplos slashes (efeitos especiais)
func apply_multiple_slash_effects(slash_config: Dictionary, count: int = 1, spread: float = 20.0):
	for i in count:
		var modified_config = slash_config.duplicate()
		
		# Pequenas variações para múltiplos slashes
		if count > 1:
			var angle = (float(i) / count) * TAU
			var offset_variation = Vector2(cos(angle), sin(angle)) * spread
			modified_config["offset"] = modified_config.get("offset", Vector2.ZERO) + offset_variation
			
			# Variação de escala
			var scale_variation = 0.8 + (i * 0.1)
			modified_config["scale"] = modified_config.get("scale", Vector2(1, 1)) * scale_variation
		
		# Aplicar com delay
		await get_tree().create_timer(i * 0.1).timeout
		apply_slash_effect(modified_config)

# 🆕 NOVO: Método para conectar sinais de ações (chamado pela BattleScene)
func connect_action_signals():
	# Conectar ações do personagem para slash effects
	for action in character.get_all_actions():
		if action and action.has_signal("slash_effect_requested"):
			if not action.slash_effect_requested.is_connected(_on_action_slash_requested):
				action.slash_effect_requested.connect(_on_action_slash_requested)

# 🆕 NOVO: Manipulador de slash effects das ações
func _on_action_slash_requested(action: Action, target_character: Character):
	# Só aplicar se este CharacterView for o alvo
	if target_character == character:
		print("🎯 Recebendo slash effect de ", action.name, " em ", character.name)
		var slash_config = action.get_slash_config()
		apply_slash_effect(slash_config)

# 🆕 FUNÇÃO DE TESTE DIRETO - Remove depois
func test_slash_directly():
	print("🔧 TESTE DIRETO DE SLASH")
	
	# Criar config manual para teste
	var test_config = {
		"sprite_frames": load("res://assets/effects/slash_effect.tres"),  # Ajuste o caminho
		"offset": Vector2(50, 0),
		"scale": Vector2(2, 2),  # 🆕 Aumentar escala
		"color": Color(1, 0, 0, 1),  # 🆕 Vermelho brilhante
		"z_index": 9999  # 🆕 Z-index extremamente alto
	}
	
	apply_slash_effect(test_config)

# Chamar no _input para teste
func _input(event):
	if event.is_action_pressed("ui_accept"):  # Pressione ENTER
		test_slash_directly()
