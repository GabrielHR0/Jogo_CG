extends Resource
class_name AnimationData

@export_category("Animation Data")
@export var sprite_frames: SpriteFrames  # ← 1 SpriteFrames com TODAS as animações

@export_category("Animation Settings")
@export var attack_effect_offset: Vector2 = Vector2(50, 0)
@export var magic_effect_offset: Vector2 = Vector2(0, -50)
@export var animation_scale: Vector2 = Vector2(1, 1)
@export var sprite_offset: Vector2 = Vector2(0, 0)

@export_category("Effect Prefabs")
@export var slash_effect: PackedScene
@export var magic_effect: PackedScene
@export var heal_effect: PackedScene
@export var shield_effect: PackedScene
