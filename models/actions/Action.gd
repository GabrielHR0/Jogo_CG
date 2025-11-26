# Action.gd
class_name Action
extends Resource

@export var name: String = "Ação"
@export var ap_cost: int = 1
@export var target_type: String = "enemy"  # "enemy", "ally", "self"
@export var description: String = ""
@export var animation_type: String = "basic"  # "melee", "magic", "ranged", "special", "heal", "buff", "debuff"

# 🆕 NOVO: Sistema de efeitos visuais unificado
@export_category("Visual Effects")
@export var effect_sprite_frames: SpriteFrames
@export var effect_color: Color = Color.WHITE
@export var effect_scale: Vector2 = Vector2(1, 1)
@export var effect_offset: Vector2 = Vector2(50, 0)
@export var effect_duration: float = 0.8

@export var requires_projectile: bool = false
@export var projectile_sprite_frames: SpriteFrames
@export var projectile_speed: float = 300.0
@export var projectile_color: Color = Color.WHITE
@export var projectile_scale: Vector2 = Vector2(1, 1)

@export var sound_effect: AudioStream
@export var screen_shake: bool = false
@export var screen_shake_intensity: float = 5.0

# 🆕 MODIFICADO: Sistema de Slash Effects melhorado
@export_category("Slash Effects")
@export var slash_sprite_frames: SpriteFrames  # SpriteFrames do efeito slash
@export var slash_color: Color = Color.WHITE
@export var slash_scale: Vector2 = Vector2(1, 1)
@export var slash_offset: Vector2 = Vector2(0, 0)
@export var slash_flip_h: bool = false
@export var slash_flip_v: bool = false
@export var slash_lifetime: float = 0.8
@export var slash_z_index: int = 100

# 🆕 NOVO: Classe interna para efeitos
class ActionEffect:
	var sprite_frames: SpriteFrames
	var color: Color
	var scale: Vector2
	var offset: Vector2
	var duration: float
	
	func _init(frames: SpriteFrames, effect_color: Color = Color.WHITE, effect_scale: Vector2 = Vector2(1, 1), 
			  effect_offset: Vector2 = Vector2(50, 0), effect_duration: float = 0.8):
		sprite_frames = frames
		color = effect_color
		scale = effect_scale
		offset = effect_offset
		duration = effect_duration
	
	func create_effect(position: Vector2, parent: Node) -> Node:
		if not sprite_frames:
			return null
		
		var effect = AnimatedSprite2D.new()
		effect.sprite_frames = sprite_frames
		effect.global_position = position + offset
		effect.scale = scale
		effect.modulate = color
		effect.z_index = 100
		
		parent.add_child(effect)
		
		# Tocar animação
		if sprite_frames.has_animation("default"):
			effect.play("default")
			effect.animation_finished.connect(_on_animation_finished.bind(effect))
		else:
			# Fallback: timer para remover após duração
			var timer = Timer.new()
			timer.wait_time = duration
			timer.one_shot = true
			timer.timeout.connect(_on_animation_finished.bind(effect))
			effect.add_child(timer)
			timer.start()
		
		return effect
	
	func _on_animation_finished(effect: Node):
		if effect and is_instance_valid(effect):
			effect.queue_free()

# 🆕 NOVO: Classe interna para projéteis
class ActionProjectile:
	var sprite_frames: SpriteFrames
	var color: Color
	var scale: Vector2
	var speed: float
	
	func _init(frames: SpriteFrames, projectile_color: Color = Color.WHITE, 
			  projectile_scale: Vector2 = Vector2(1, 1), projectile_speed: float = 300.0):
		sprite_frames = frames
		color = projectile_color
		scale = projectile_scale
		speed = projectile_speed
	
	func create_projectile(start_pos: Vector2, target_pos: Vector2, parent: Node, on_arrive_callback: Callable) -> Node:
		if not sprite_frames:
			return null
		
		var projectile = AnimatedSprite2D.new()
		projectile.sprite_frames = sprite_frames
		projectile.global_position = start_pos
		projectile.modulate = color
		projectile.scale = scale
		projectile.z_index = 50
		
		parent.add_child(projectile)
		
		# Tocar animação
		if sprite_frames.has_animation("default"):
			projectile.play("default")
		
		# Mover projétil
		var tween = parent.create_tween()
		var distance = start_pos.distance_to(target_pos)
		var duration = distance / speed
		
		tween.tween_property(projectile, "global_position", target_pos, duration)
		tween.tween_callback(on_arrive_callback.bind(projectile, target_pos, parent))
		
		return projectile

# 🆕 NOVO: Classe interna para Slash Effects (renomeada para evitar conflito)
class ActionSlashEffect:
	var sprite_frames: SpriteFrames
	var color: Color
	var scale: Vector2
	var offset: Vector2
	var flip_h: bool
	var flip_v: bool
	var lifetime: float
	var z_index: int
	
	func _init(frames: SpriteFrames, slash_color: Color = Color.WHITE, slash_scale: Vector2 = Vector2(1, 1),
			  slash_offset: Vector2 = Vector2(0, 0), slash_flip_h: bool = false, slash_flip_v: bool = false,
			  slash_lifetime: float = 0.8, slash_z_index: int = 100):
		sprite_frames = frames
		color = slash_color
		scale = slash_scale
		offset = slash_offset
		flip_h = slash_flip_h
		flip_v = slash_flip_v
		lifetime = slash_lifetime
		z_index = slash_z_index
	
	func create_slash(position: Vector2, parent: Node) -> Node:
		if not sprite_frames:
			return null
		
		var slash = AnimatedSprite2D.new()
		slash.sprite_frames = sprite_frames
		slash.global_position = position + offset
		slash.scale = scale
		slash.modulate = color
		slash.flip_h = flip_h
		slash.flip_v = flip_v
		slash.z_index = z_index
		
		parent.add_child(slash)
		
		# Tocar animação
		if sprite_frames.has_animation("default"):
			slash.play("default")
			slash.animation_finished.connect(_on_slash_animation_finished.bind(slash))
		else:
			# Fallback: timer para remover após duração
			var timer = Timer.new()
			timer.wait_time = lifetime
			timer.one_shot = true
			timer.timeout.connect(_on_slash_animation_finished.bind(slash))
			slash.add_child(timer)
			timer.start()
		
		print("🗡️ Slash effect criado na posição: ", slash.global_position)
		return slash
	
	func _on_slash_animation_finished(slash: Node):
		if slash and is_instance_valid(slash):
			slash.queue_free()

# Sinais
signal action_used(user: Character, action: Action, target: Character)
signal damage_dealt(user: Character, target: Character, damage: int)
signal healing_applied(user: Character, target: Character, amount: int)
signal effect_applied(user: Character, target: Character, effect_name: String, duration: int)
signal animation_requested(user: Character, action: Action, target: Character)
signal slash_effect_requested(action: Action, target_character: Character)  # 🆕 NOVO SINAL

func execute(user: Character, target: Character) -> void:
	print("🎯 Executando ", name, " em ", target.name)
	
	if not user.has_ap_for_action(self):
		push_error("AP insuficiente para executar " + name)
		return
	
	user.spend_ap(ap_cost)
	action_used.emit(user, self, target)
	
	# 🆕 NOVO: Emitir sinal de animação antes de aplicar efeitos
	animation_requested.emit(user, self, target)
	
	# 🆕 NOVO: Emitir sinal de slash effect se tiver configurado
	if has_slash_effect():
		slash_effect_requested.emit(self, target)
	
	apply_effects(user, target)

func apply_effects(user: Character, target: Character) -> void:
	pass  # Para ser sobrescrito pelas classes filhas

# 🆕 NOVO: Métodos de animação unificados usando as classes internas
func create_effect_animation(position: Vector2, parent: Node) -> Node:
	var effect = ActionEffect.new(effect_sprite_frames, effect_color, effect_scale, effect_offset, effect_duration)
	return effect.create_effect(position, parent)

func create_projectile_animation(start_pos: Vector2, target_pos: Vector2, parent: Node) -> Node:
	var projectile = ActionProjectile.new(projectile_sprite_frames, projectile_color, projectile_scale, projectile_speed)
	return projectile.create_projectile(start_pos, target_pos, parent, _on_projectile_arrived)

# 🆕 NOVO: Método para criar slash effects
func create_slash_animation(position: Vector2, parent: Node) -> Node:
	var slash = ActionSlashEffect.new(
		slash_sprite_frames, 
		slash_color, 
		slash_scale, 
		slash_offset, 
		slash_flip_h, 
		slash_flip_v, 
		slash_lifetime, 
		slash_z_index
	)
	return slash.create_slash(position, parent)

func _on_projectile_arrived(projectile: Node, target_pos: Vector2, parent: Node):
	if projectile and is_instance_valid(projectile):
		# Criar efeito de impacto
		if has_effect_animation():
			create_effect_animation(target_pos, parent)
		projectile.queue_free()

# 🆕 NOVO: Verificações de animação
func has_effect_animation() -> bool:
	return effect_sprite_frames != null

func has_projectile_animation() -> bool:
	return projectile_sprite_frames != null

# 🆕 NOVO: Verificação de slash effect
func has_slash_effect() -> bool:
	return slash_sprite_frames != null

# 🆕 NOVO: Método para obter configurações do slash
func get_slash_config() -> Dictionary:
	return {
		"sprite_frames": slash_sprite_frames,
		"color": slash_color,
		"scale": slash_scale,
		"offset": slash_offset,
		"flip_h": slash_flip_h,
		"flip_v": slash_flip_v,
		"lifetime": slash_lifetime,
		"z_index": slash_z_index
	}

# 🆕 NOVO: Método para obter posição de animação baseada no tipo
func get_animation_position(user: Character, target: Character) -> Vector2:
	if target and target.battle_position != Vector2.ZERO:
		return target.battle_position
	elif user and user.battle_position != Vector2.ZERO:
		return user.battle_position
	else:
		return Vector2.ZERO

# 🆕 NOVO: Métodos para criar efeitos customizados (para as subclasses usarem)
func create_custom_effect(frames: SpriteFrames, position: Vector2, parent: Node, 
						 custom_color: Color = Color.WHITE, custom_scale: Vector2 = Vector2(1, 1),
						 custom_offset: Vector2 = Vector2(50, 0)) -> Node:
	var custom_effect = ActionEffect.new(frames, custom_color, custom_scale, custom_offset, effect_duration)
	return custom_effect.create_effect(position, parent)

func create_custom_projectile(frames: SpriteFrames, start_pos: Vector2, target_pos: Vector2, parent: Node,
							 custom_color: Color = Color.WHITE, custom_scale: Vector2 = Vector2(1, 1),
							 custom_speed: float = 300.0) -> Node:
	var custom_projectile = ActionProjectile.new(frames, custom_color, custom_scale, custom_speed)
	return custom_projectile.create_projectile(start_pos, target_pos, parent, _on_projectile_arrived)

# 🆕 NOVO: Método para criar slash customizado
func create_custom_slash(frames: SpriteFrames, position: Vector2, parent: Node,
						custom_color: Color = Color.WHITE, custom_scale: Vector2 = Vector2(1, 1),
						custom_offset: Vector2 = Vector2(0, 0), custom_flip_h: bool = false,
						custom_flip_v: bool = false, custom_lifetime: float = 0.8) -> Node:
	var custom_slash = ActionSlashEffect.new(frames, custom_color, custom_scale, custom_offset, 
									  custom_flip_h, custom_flip_v, custom_lifetime, slash_z_index)
	return custom_slash.create_slash(position, parent)
