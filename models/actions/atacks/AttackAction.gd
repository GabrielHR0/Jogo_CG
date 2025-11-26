# AttackAction.gd
extends Action
class_name AttackAction

@export_category("Damage Settings")
@export var damage_multiplier: float = 1.0
@export var critical_chance: float = 0.1
@export var critical_multiplier: float = 1.5
@export var formula: String = "melee"  # "melee", "magic", "ranged"

@export_category("Melee Animation Settings")
@export var melee_dash_speed: float = 300.0  # 🆕 NOVO: Velocidade do dash
@export var melee_approach_distance: float = 0.7  # 🆕 NOVO: Quão próximo chega do alvo

@export_category("Animation Settings")

func apply_effects(user: Character, target: Character) -> void:
	var damage = calculate_damage(user, target)
	var is_critical = roll_critical()
	
	if is_critical:
		damage = int(damage * critical_multiplier)
		print("   💥 CRÍTICO!")
	
	var final_damage = target.take_damage(damage)
	damage_dealt.emit(user, target, final_damage)
	
	print("   💥 Dano:", final_damage, " em ", target.name)
	print("   ❤️ ", target.name, " HP:", target.current_hp, "/", target.get_max_hp())

func calculate_damage(user: Character, target: Character) -> int:
	var base := 0
	match formula:
		"magic":
			base = user.calculate_magic_damage()
		"ranged":
			base = user.calculate_ranged_damage()
		_:
			base = user.calculate_melee_damage()
	return int(base * damage_multiplier)

func roll_critical() -> bool:
	return randf() < critical_chance

func get_damage_type() -> String:
	return formula

func create_slash_effect(position: Vector2, parent: Node) -> Node:
	if not slash_sprite_frames:
		print("❌ SpriteFrames do slash não configurado para ", name)
		return null
	
	var slash = AnimatedSprite2D.new()
	slash.sprite_frames = slash_sprite_frames
	slash.global_position = position
	slash.scale = slash_scale
	slash.modulate = slash_color
	slash.z_index = 100
	
	parent.add_child(slash)
	
	if slash_sprite_frames.has_animation("default"):
		slash.play("default")
		slash.animation_finished.connect(_on_slash_animation_finished.bind(slash))
	else:
		var timer = Timer.new()
		timer.wait_time = 0.5
		timer.one_shot = true
		timer.timeout.connect(_on_slash_animation_finished.bind(slash))
		slash.add_child(timer)
		timer.start()
	
	return slash

func create_projectile(start_pos: Vector2, target_pos: Vector2, parent: Node) -> Node:
	if not projectile_sprite_frames:
		print("❌ SpriteFrames do projétil não configurado para ", name)
		return null
	
	var projectile = AnimatedSprite2D.new()
	projectile.sprite_frames = projectile_sprite_frames
	projectile.global_position = start_pos
	projectile.z_index = 50
	
	parent.add_child(projectile)
	
	if projectile_sprite_frames.has_animation("default"):
		projectile.play("default")
	
	var tween = parent.create_tween()
	var distance = start_pos.distance_to(target_pos)
	var duration = distance / projectile_speed
	
	tween.tween_property(projectile, "global_position", target_pos, duration)
	tween.tween_callback(_on_projectile_arrived.bind(projectile, target_pos, parent))
	
	return projectile

func _on_slash_animation_finished(slash: Node):
	if slash and is_instance_valid(slash):
		slash.queue_free()

func _on_projectile_arrived(projectile: Node, target_pos: Vector2, parent: Node):
	if projectile and is_instance_valid(projectile):
		if slash_sprite_frames:
			create_slash_effect(target_pos, parent)
		projectile.queue_free()

func has_slash_animation() -> bool:
	return slash_sprite_frames != null

func has_projectile_animation() -> bool:
	return projectile_sprite_frames != null
