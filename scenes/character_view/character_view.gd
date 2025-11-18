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

# 🆕 NOVO: Guarda o tamanho original do sprite principal
var original_sprite_size: Vector2 = Vector2.ZERO

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
	
	# Configurações do AnimationData
	if character.animation_data:
		var combined_scale = character.animation_data.animation_scale * character_scale
		scale = combined_scale
		position += character.animation_data.sprite_offset
	else:
		scale = character_scale
	
	# Conecta aos sinais do personagem
	character.animation_requested.connect(_on_animation_requested)
	character.damage_animation_requested.connect(_on_damage_animation_requested)

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

func _on_damage_animation_requested():
	stop_current_animation()
	play_damage_animation()

func play_attack_animation(attack_type: String):
	var anim_name = "ataque_" + attack_type
	
	if has_custom_animation(anim_name):
		play_spriteframes_animation(anim_name, false)
		return
	
	var tween = create_tween()
	tween.tween_property(sprite, "position", sprite.position + Vector2(15, -8), 0.1)
	tween.tween_property(sprite, "position", sprite.position, 0.1)

func play_damage_animation():
	stop_damage_tween()
	
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

func play_victory_animation():
	if has_custom_animation("vitoria"):
		play_spriteframes_animation("vitoria", false)
		return
	
	var tween = create_tween()
	tween.tween_property(sprite, "position", sprite.position + Vector2(0, -15), 0.2)
	tween.tween_property(sprite, "position", sprite.position, 0.2)

func play_defeat_animation():
	if has_custom_animation("derrota"):
		play_spriteframes_animation("derrota", false)
		return
	
	var tween = create_tween()
	tween.tween_property(sprite, "rotation_degrees", 60, 0.5)
	tween.parallel().tween_property(sprite, "position", sprite.position + Vector2(0, 12), 0.5)

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
	
	current_animated_sprite.z_index = sprite.z_index
	
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
