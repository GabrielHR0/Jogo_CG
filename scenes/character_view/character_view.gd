extends Node2D
class_name CharacterView

@export var character: Character
@export var auto_setup: bool = true

@onready var sprite: Sprite2D = $Sprite2D

# Sistema de animação
var original_position: Vector2 = Vector2.ZERO
var is_dashing: bool = false
var dash_tween: Tween = null

# Barra de vida
var health_bar_container: Control
var health_bar_fill: ColorRect
var health_bar_created: bool = false

func _ready():
	if auto_setup and character:
		setup_character()

func setup_character():
	if character.texture:
		sprite.texture = character.texture
		adjust_sprite_size()
		center_sprite()
	
	original_position = position
	
	if character.animation_data:
		var combined_scale = character.animation_data.animation_scale * Vector2(1, 1)
		scale = combined_scale
		position += character.animation_data.sprite_offset
	else:
		scale = Vector2(1, 1)
	
	# Criar barra de vida
	create_health_bar()

func center_sprite():
	if not sprite.texture:
		return
	var texture_size = sprite.texture.get_size() * sprite.scale
	sprite.position = Vector2(-texture_size.x / 2, -texture_size.y / 2)

func adjust_sprite_size():
	if not sprite.texture:
		return
	var texture_size = sprite.texture.get_size()
	var scale_ratio = min(170.0 / texture_size.x, 200.0 / texture_size.y)
	sprite.scale = Vector2(scale_ratio, scale_ratio)

func create_health_bar():
	if health_bar_created:
		return
	
	health_bar_container = Control.new()
	health_bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var bar_width = 80
	var bar_height = 6
	
	# Posicionar acima do personagem
	health_bar_container.position = Vector2(-bar_width / 2, -60)
	health_bar_container.size = Vector2(bar_width, bar_height)
	
	# Fundo da barra
	var health_bar_background = ColorRect.new()
	health_bar_background.size = Vector2(bar_width + 2, bar_height + 2)
	health_bar_background.position = Vector2(-1, -1)
	health_bar_background.color = Color.BLACK
	
	# Preenchimento da barra
	health_bar_fill = ColorRect.new()
	health_bar_fill.size = Vector2(bar_width, bar_height)
	health_bar_fill.position = Vector2(0, 0)
	health_bar_fill.color = Color.GREEN
	
	health_bar_container.add_child(health_bar_background)
	health_bar_container.add_child(health_bar_fill)
	add_child(health_bar_container)
	
	health_bar_created = true
	update_health_bar()

func update_health_bar():
	if not health_bar_fill or not character:
		return
	
	var health_ratio = float(character.current_hp) / float(character.get_max_hp())
	health_ratio = max(0, health_ratio)
	
	health_bar_fill.size.x = 80 * health_ratio
	
	if health_ratio > 0.6:
		health_bar_fill.color = Color.GREEN
	elif health_ratio > 0.3:
		health_bar_fill.color = Color.YELLOW
	else:
		health_bar_fill.color = Color.RED
	
	health_bar_container.visible = character.is_alive()

# 🆕 SISTEMA SIMPLIFICADO: BattleScene chama esta função diretamente
func execute_melee_attack(target_global_position: Vector2):
	print("🎬 CharacterView EXECUTANDO ATAQUE MEELE: ", character.name)
	
	if is_dashing:
		print("   ❌ Já está em dash - ignorando")
		return
	
	is_dashing = true
	
	# 1. Calcular posição próxima do alvo
	var direction = (target_global_position - global_position).normalized()
	var distance = global_position.distance_to(target_global_position)
	var dash_distance = distance * 0.7  # 70% da distância
	var min_distance = 50.0
	dash_distance = max(dash_distance, min_distance)
	var dash_target = position + (direction * dash_distance)
	
	print("   📏 Dash para: ", dash_target, " (distância: ", dash_distance, ")")
	
	# 2. Sequência de dash
	var sequence_tween = create_tween()
	
	# Dash para frente
	sequence_tween.tween_property(self, "position", dash_target, 0.3)
	sequence_tween.tween_callback(perform_attack_animation)
	
	# Pequena pausa para ataque
	sequence_tween.tween_interval(0.3)
	
	# Voltar
	sequence_tween.tween_property(self, "position", original_position, 0.4)
	sequence_tween.tween_callback(finish_attack)

func perform_attack_animation():
	print("   🗡️ Executando animação de ataque")
	# Animação simples de ataque
	var attack_tween = create_tween()
	attack_tween.tween_property(sprite, "position", sprite.position + Vector2(15, -8), 0.1)
	attack_tween.tween_property(sprite, "position", sprite.position, 0.1)

func finish_attack():
	print("   ✅ Ataque concluído")
	is_dashing = false
	position = original_position  # Garantir posição exata

# Para outros tipos de ataque
func execute_normal_attack():
	print("🎬 CharacterView ATAQUE NORMAL: ", character.name)
	var attack_tween = create_tween()
	attack_tween.tween_property(sprite, "position", sprite.position + Vector2(10, -5), 0.1)
	attack_tween.tween_property(sprite, "position", sprite.position, 0.1)

# Sistema de dano
func take_damage():
	print("💥 CharacterView DANO: ", character.name)
	var damage_tween = create_tween()
	damage_tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	damage_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

# Sistema de slash effects
func apply_slash_effect(slash_config: Dictionary):
	print("🗡️ CharacterView SLASH EFFECT: ", character.name)
	
	var slash_sprite = AnimatedSprite2D.new()
	slash_sprite.sprite_frames = slash_config.get("sprite_frames")
	slash_sprite.scale = slash_config.get("scale", Vector2(1, 1))
	slash_sprite.modulate = slash_config.get("color", Color.WHITE)
	slash_sprite.z_index = slash_config.get("z_index", 1000)
	slash_sprite.centered = true
	
	# Usar top_level para ficar acima de tudo
	slash_sprite.top_level = true
	slash_sprite.z_as_relative = false
	
	# Posicionar no personagem
	slash_sprite.global_position = global_position
	
	get_tree().current_scene.add_child(slash_sprite)
	
	if slash_sprite.sprite_frames:
		var anim_names = slash_sprite.sprite_frames.get_animation_names()
		if anim_names.size() > 0:
			var anim_to_play = "default" if slash_sprite.sprite_frames.has_animation("default") else anim_names[0]
			slash_sprite.sprite_frames.set_animation_loop(anim_to_play, false)
			slash_sprite.play(anim_to_play)
	
	# Conectar sinal para remover após animação
	slash_sprite.animation_finished.connect(_on_slash_animation_finished.bind(slash_sprite))

func _on_slash_animation_finished(slash_sprite: AnimatedSprite2D):
	if slash_sprite and is_instance_valid(slash_sprite):
		slash_sprite.queue_free()

# Atualizar barra de vida continuamente
func _process(_delta):
	if character and health_bar_created:
		update_health_bar()
