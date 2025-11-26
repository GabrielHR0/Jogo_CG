# AnimationData.gd
extends Resource
class_name AnimationData

@export_category("SpriteFrames")
@export var sprite_frames: SpriteFrames

@export_category("Animation Clips")
@export var attack_melee_animation: StringName = "attack_melee"
@export var attack_magic_animation: StringName = "attack_magic" 
@export var attack_ranged_animation: StringName = "attack_ranged"
@export var attack_special_animation: StringName = "attack_special"
@export var defend_animation: StringName = "defend"
@export var idle_animation: StringName = "idle"
@export var walk_animation: StringName = "walk"
@export var victory_animation: StringName = "victory"
@export var defeat_animation: StringName = "defeat"
@export var damage_animation: StringName = "damage"
@export var heal_animation: StringName = "heal"

@export_category("Animation Settings")
@export var attack_animation_speed: float = 1.0
@export var cast_animation_speed: float = 0.8
@export var movement_animation_speed: float = 1.2
@export var animation_scale: float = 1.0

@export_category("Effect Positions")
@export var slash_offset: Vector2 = Vector2(50, 0)
@export var magic_offset: Vector2 = Vector2(0, -30)
@export var arrow_offset: Vector2 = Vector2(40, -20)
@export var damage_offset: Vector2 = Vector2(0, -20)
@export var heal_offset: Vector2 = Vector2(0, -30)
@export var shield_offset: Vector2 = Vector2(0, 0)
@export var sparkles_offset: Vector2 = Vector2(0, -50)
@export var highlight_offset: Vector2 = Vector2.ZERO
@export var dodge_offset: Vector2 = Vector2.ZERO

@export_category("Visual Settings")
@export var character_scale: Vector2 = Vector2(1, 1)
@export var flip_h: bool = false
@export var sprite_offset: Vector2 = Vector2.ZERO

func get_animation_name(animation_type: String, attack_type: String = "") -> StringName:
	match animation_type:
		"attack":
			match attack_type:
				"melee": return attack_melee_animation
				"magic": return attack_magic_animation
				"ranged": return attack_ranged_animation
				"special": return attack_special_animation
				_: return attack_melee_animation
		"defend": return defend_animation
		"idle": return idle_animation
		"walk": return walk_animation
		"victory": return victory_animation
		"defeat": return defeat_animation
		"damage": return damage_animation
		"heal": return heal_animation
		_: return idle_animation

func get_effect_offset(effect_type: String) -> Vector2:
	match effect_type:
		"slash": return slash_offset
		"magic": return magic_offset
		"arrow": return arrow_offset
		"damage": return damage_offset
		"heal": return heal_offset
		"shield": return shield_offset
		"sparkles": return sparkles_offset
		"highlight": return highlight_offset
		"dodge": return dodge_offset
		_: return Vector2.ZERO

func get_animation_speed(animation_type: String) -> float:
	match animation_type:
		"attack": return attack_animation_speed
		"cast": return cast_animation_speed
		"movement": return movement_animation_speed
		_: return 1.0

func has_animation(animation_name: String) -> bool:
	return sprite_frames != null and sprite_frames.has_animation(animation_name)

func set_animation_loop(animation_name: String, should_loop: bool):
	if sprite_frames and sprite_frames.has_animation(animation_name):
		sprite_frames.set_animation_loop(animation_name, should_loop)
