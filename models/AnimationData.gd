extends Resource
class_name AnimationData

@export_category("Animation Resources")
@export var idle_animation: Animation
@export var walk_animation: Animation
@export var attack_melee_animation: Animation
@export var attack_magic_animation: Animation
@export var attack_ranged_animation: Animation
@export var damage_animation: Animation
@export var defense_animation: Animation
@export var victory_animation: Animation
@export var defeat_animation: Animation

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
