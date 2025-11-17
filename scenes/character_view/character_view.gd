extends Node2D
class_name CharacterView

@export var character: Character
@export var auto_setup: bool = true

@onready var sprite: Sprite2D = $Sprite2D  # ← VOLTA para Sprite2D simples
@onready var icon: Sprite2D = $Icon
@onready var animation_player: AnimationPlayer = $AnimationPlayer  # Para efeitos especiais

func _ready():
	if auto_setup and character:
		setup_character()

func setup_character():
	# Configura a sprite principal (IDLE ESTÁTICO)
	if character.texture:
		sprite.texture = character.texture
	
	# Configura o ícone
	if character.icon:
		icon.texture = character.icon
		icon.position = Vector2(0, -80)
		icon.scale = Vector2(0.5, 0.5)
		icon.visible = true
	else:
		icon.visible = false
	
	# Configurações do AnimationData (escala, offset)
	if character.animation_data:
		scale = character.animation_data.animation_scale
		position += character.animation_data.sprite_offset
	
	# Conecta aos sinais do personagem
	character.animation_requested.connect(_on_animation_requested)
	character.damage_animation_requested.connect(_on_damage_animation_requested)
	
	# Já está em idle (texture estática)

func _on_animation_requested(animation_name: String, attack_type: String):
	print("🎬 CharacterView: Animação solicitada - ", animation_name)
	
	match animation_name:
		"attack":
			play_attack_animation(attack_type)
		"defend":
			play_defend_animation()
		"idle":
			play_idle_animation()  # Volta para texture estática
		"walk":
			play_walk_animation()
		"victory":
			play_victory_animation()
		"defeat":
			play_defeat_animation()

func _on_damage_animation_requested():
	print("💥 CharacterView: Personagem sofreu dano")
	play_damage_animation()

# ANIMAÇÕES PARA AÇÕES ESPECÍFICAS (usam SpriteFrames quando disponível)
func play_attack_animation(attack_type: String):
	var anim_name = "attack_" + attack_type
	print("⚔️ Executando ataque: ", anim_name)
	
	# Se tem AnimationData com SpriteFrames para ataque
	if character.animation_data and character.animation_data.sprite_frames:
		if character.animation_data.sprite_frames.has_animation(anim_name):
			# Troca temporariamente para AnimatedSprite2D se necessário
			play_spriteframes_animation(anim_name)
			return
	
	# Fallback: efeito simples de ataque
	var tween = create_tween()
	tween.tween_property(sprite, "position", Vector2(20, -10), 0.1)
	tween.tween_property(sprite, "position", Vector2(0, 0), 0.1)

func play_damage_animation():
	print("💢 Executando animação de dano")
	
	# Se tem AnimationData com SpriteFrames para dano
	if character.animation_data and character.animation_data.sprite_frames:
		if character.animation_data.sprite_frames.has_animation("damage"):
			play_spriteframes_animation("damage")
			return
	
	# Fallback: pisca em vermelho
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func play_defend_animation():
	print("🛡️ Executando defesa")
	
	if character.animation_data and character.animation_data.sprite_frames:
		if character.animation_data.sprite_frames.has_animation("defend"):
			play_spriteframes_animation("defend")
			return
	
	# Fallback: efeito de escala
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.1)
	tween.tween_property(sprite, "scale", Vector2(1, 1), 0.1)

func play_idle_animation():
	print("🔄 Voltando para idle")
	# Para idle, sempre volta para a texture estática
	reset_to_idle()

func play_walk_animation():
	print("🚶 Executando caminhada")
	
	if character.animation_data and character.animation_data.sprite_frames:
		if character.animation_data.sprite_frames.has_animation("walk"):
			play_spriteframes_animation("walk")
			return
	
	# Fallback: efeito simples de caminhada
	var tween = create_tween()
	tween.tween_property(sprite, "position", Vector2(0, -5), 0.3)
	tween.tween_property(sprite, "position", Vector2(0, 0), 0.3)

func play_victory_animation():
	print("🎉 Vitória!")
	
	if character.animation_data and character.animation_data.sprite_frames:
		if character.animation_data.sprite_frames.has_animation("victory"):
			play_spriteframes_animation("victory")
			return
	
	# Fallback: pula de alegria
	var tween = create_tween()
	tween.tween_property(sprite, "position", Vector2(0, -20), 0.2)
	tween.tween_property(sprite, "position", Vector2(0, 0), 0.2)

func play_defeat_animation():
	print("💀 Derrota...")
	
	if character.animation_data and character.animation_data.sprite_frames:
		if character.animation_data.sprite_frames.has_animation("defeat"):
			play_spriteframes_animation("defeat")
			return
	
	# Fallback: cai no chão
	var tween = create_tween()
	tween.tween_property(sprite, "rotation_degrees", 90, 0.5)
	tween.parallel().tween_property(sprite, "position", Vector2(0, 20), 0.5)

# MÉTODO PARA ANIMAÇÕES COM SPRITEFRAMES
func play_spriteframes_animation(animation_name: String):
	if not character.animation_data or not character.animation_data.sprite_frames:
		return
	
	# Cria um AnimatedSprite2D temporário se necessário
	var temp_animated_sprite = AnimatedSprite2D.new()
	temp_animated_sprite.sprite_frames = character.animation_data.sprite_frames
	temp_animated_sprite.position = sprite.position
	temp_animated_sprite.scale = sprite.scale
	temp_animated_sprite.z_index = sprite.z_index
	
	# Substitui o sprite estático pelo animado
	sprite.visible = false
	add_child(temp_animated_sprite)
	
	# Executa a animação
	temp_animated_sprite.play(animation_name)
	
	# Quando terminar, volta para o sprite estático
	await temp_animated_sprite.animation_finished
	temp_animated_sprite.queue_free()
	sprite.visible = true

# Volta para o estado idle (texture estática)
func reset_to_idle():
	var tween = create_tween()
	tween.tween_property(sprite, "position", Vector2(0, 0), 0.2)
	tween.parallel().tween_property(sprite, "scale", Vector2(1, 1), 0.2)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.2)
	tween.parallel().tween_property(sprite, "rotation_degrees", 0, 0.2)
