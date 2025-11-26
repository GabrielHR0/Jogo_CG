# SlashEffect.gd
extends BattleEffect
class_name SlashEffect

@export var sprite_frames: SpriteFrames
@export var effect_color: Color = Color.WHITE
@export var effect_scale: Vector2 = Vector2(1, 1)
@export var flip_h: bool = false
@export var flip_v: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	if animated_sprite and sprite_frames:
		animated_sprite.sprite_frames = sprite_frames
		animated_sprite.scale = effect_scale
		animated_sprite.modulate = effect_color
		animated_sprite.flip_h = flip_h
		animated_sprite.flip_v = flip_v
		
		if auto_play:
			play()

func play():
	if animated_sprite and sprite_frames:
		if sprite_frames.has_animation("default"):
			animated_sprite.play("default")
			animated_sprite.animation_finished.connect(_on_animation_finished)
		else:
			# Fallback: usar timer se não tiver animação
			var timer = Timer.new()
			add_child(timer)
			timer.wait_time = lifetime
			timer.one_shot = true
			timer.timeout.connect(_on_animation_finished)
			timer.start()
