# AnimationSystem.gd
extends Node2D
class_name AnimationSystem

signal animation_started(animation_name)
signal animation_finished(animation_name)

@export var character: Character
@export var animation_player: AnimationPlayer
@export var slash_scene: PackedScene
@export var projectile_scene: PackedScene
@export var effect_container: Node

var scene_position: Vector2 = Vector2.ZERO

func _ready():
	if character:
		character.animation_requested.connect(_on_animation_requested)
		character.damage_animation_requested.connect(_on_damage_requested)
		character.position_updated.connect(_on_position_updated)

func _on_position_updated(new_position: Vector2):
	scene_position = new_position
	global_position = new_position

func _on_animation_requested(animation_name: String, attack_type: String):
	match animation_name:
		"attack":
			pass
		"defend":
			play_defense_animation()
		"idle":
			play_idle_animation()
		"walk":
			play_walk_animation()
		"victory":
			play_victory_animation()
		"defeat":
			play_defeat_animation()

func _on_damage_requested():
	play_damage_animation()

func play_attack_animation(attack_type: String, target_position: Vector2):
	animation_started.emit("attack_" + attack_type)
	
	match attack_type:
		"melee":
			await play_melee_animation(target_position)
		"magic":
			await play_magic_animation(target_position)
		"ranged":
			await play_ranged_animation(target_position)
		"special":
			await play_special_animation(target_position)
		_:
			await play_basic_animation(target_position)

func play_melee_animation(target_position: Vector2):
	# 🆕 CORREÇÃO: Verificar se a animação existe
	if animation_player and animation_player.has_animation("attack_melee"):
		animation_player.play("attack_melee")
		await animation_player.animation_finished
	else:
		# Fallback: animação simulada
		print("🎬 Animação 'attack_melee' não encontrada - usando fallback")
		await _simulate_attack_animation()
	
	if slash_scene and target_position != Vector2.ZERO:
		var slash = slash_scene.instantiate()
		_get_effect_container().add_child(slash)
		slash.global_position = target_position
		slash.play_animation()
		await slash.effect_finished
		slash.queue_free()
	
	animation_finished.emit("attack_melee")

func play_magic_animation(target_position: Vector2):
	# 🆕 CORREÇÃO: Verificar se a animação existe
	if animation_player and animation_player.has_animation("attack_magic"):
		animation_player.play("attack_magic")
	else:
		print("🎬 Animação 'attack_magic' não encontrada - usando fallback")
	
	if projectile_scene and target_position != Vector2.ZERO:
		var projectile = projectile_scene.instantiate()
		_get_effect_container().add_child(projectile)
		
		projectile.global_position = _get_character_position()
		projectile.launch(target_position)
		
		await projectile.arrived
		projectile.explode()
		
		if slash_scene:
			var slash = slash_scene.instantiate()
			_get_effect_container().add_child(slash)
			slash.global_position = target_position
			slash.modulate = Color.CYAN
			slash.play_animation()
			await slash.effect_finished
			slash.queue_free()
	
	animation_finished.emit("attack_magic")

func play_ranged_animation(target_position: Vector2):
	# 🆕 CORREÇÃO: Verificar se a animação existe
	if animation_player and animation_player.has_animation("attack_ranged"):
		animation_player.play("attack_ranged")
	else:
		print("🎬 Animação 'attack_ranged' não encontrada - usando fallback")
	
	if projectile_scene and target_position != Vector2.ZERO:
		var projectile = projectile_scene.instantiate()
		_get_effect_container().add_child(projectile)
		
		projectile.global_position = _get_character_position()
		projectile.launch(target_position)
		
		await projectile.arrived
		
		if slash_scene:
			var slash = slash_scene.instantiate()
			_get_effect_container().add_child(slash)
			slash.global_position = target_position
			slash.modulate = Color.YELLOW
			slash.play_animation()
			await slash.effect_finished
			slash.queue_free()
	
	animation_finished.emit("attack_ranged")

func play_special_animation(target_position: Vector2):
	# 🆕 CORREÇÃO: Verificar se a animação existe
	if animation_player and animation_player.has_animation("attack_special"):
		animation_player.play("attack_special")
		await animation_player.animation_finished
	else:
		print("🎬 Animação 'attack_special' não encontrada - usando fallback")
		await _simulate_special_animation()
	
	if slash_scene and target_position != Vector2.ZERO:
		for i in 3:
			var slash = slash_scene.instantiate()
			_get_effect_container().add_child(slash)
			slash.global_position = target_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
			slash.modulate = Color.PURPLE
			slash.scale *= 1.5
			slash.play_animation()
	
	animation_finished.emit("attack_special")

func play_basic_animation(target_position: Vector2):
	# 🆕 CORREÇÃO: Verificar se a animação existe
	if animation_player and animation_player.has_animation("attack_basic"):
		animation_player.play("attack_basic")
		await animation_player.animation_finished
	else:
		print("🎬 Animação 'attack_basic' não encontrada - usando fallback")
		await _simulate_attack_animation()
	
	animation_finished.emit("attack_basic")

func play_damage_animation():
	# 🆕 CORREÇÃO: Verificar se a animação existe
	if animation_player and animation_player.has_animation("damage"):
		animation_player.play("damage")
		await animation_player.animation_finished
	else:
		print("🎬 Animação 'damage' não encontrada - usando fallback")
		await _simulate_damage_animation()

func play_defense_animation():
	# 🆕 CORREÇÃO: Verificar se a animação existe
	if animation_player and animation_player.has_animation("defend"):
		animation_player.play("defend")
		await animation_player.animation_finished
	else:
		print("🎬 Animação 'defend' não encontrada - usando fallback")
		await _simulate_defense_animation()

func play_idle_animation():
	# 🆕 CORREÇÃO: Verificar se a animação existe
	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")
	else:
		print("🎬 Animação 'idle' não encontrada - usando fallback")
		# Para idle, não fazemos nada já que é o estado padrão

func play_walk_animation():
	# 🆕 CORREÇÃO: Verificar se a animação existe
	if animation_player and animation_player.has_animation("walk"):
		animation_player.play("walk")
	else:
		print("🎬 Animação 'walk' não encontrada - usando fallback")

func play_victory_animation():
	# 🆕 CORREÇÃO: Verificar se a animação existe
	if animation_player and animation_player.has_animation("victory"):
		animation_player.play("victory")
		await animation_player.animation_finished
	else:
		print("🎬 Animação 'victory' não encontrada - usando fallback")
		await _simulate_victory_animation()

func play_defeat_animation():
	# 🆕 CORREÇÃO: Verificar se a animação existe
	if animation_player and animation_player.has_animation("defeat"):
		animation_player.play("defeat")
		await animation_player.animation_finished
	else:
		print("🎬 Animação 'defeat' não encontrada - usando fallback")
		await _simulate_defeat_animation()

func play_heal_animation():
	# 🆕 CORREÇÃO: Verificar se a animação existe
	if animation_player and animation_player.has_animation("heal"):
		animation_player.play("heal")
		await animation_player.animation_finished
	else:
		print("🎬 Animação 'heal' não encontrada - usando fallback")
		await _simulate_heal_animation()

func play_highlight_animation():
	var original_scale = scale
	var tween = create_tween()
	tween.tween_property(self, "scale", original_scale * 1.2, 0.1)
	tween.tween_property(self, "scale", original_scale, 0.1)

func _get_character_position() -> Vector2:
	if global_position != Vector2.ZERO:
		return global_position
	elif character and character.battle_position != Vector2.ZERO:
		return character.battle_position
	return Vector2.ZERO

func _get_effect_container() -> Node:
	if effect_container:
		return effect_container
	return get_tree().current_scene

# 🆕 CORREÇÃO: Métodos de animação simulada (sem acessar sprite do Character)
func _simulate_attack_animation():
	var tween = create_tween()
	
	# Simula um movimento de ataque
	tween.tween_property(self, "position", position + Vector2(20, 0), 0.1)
	tween.tween_property(self, "position", position, 0.1)
	
	await tween.finished
	await get_tree().create_timer(0.3).timeout

func _simulate_damage_animation():
	var tween = create_tween()
	
	# 🆕 CORREÇÃO: Não tenta acessar sprite do Character
	# Efeito de dano - piscar usando o próprio AnimationSystem
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	# Pequeno recuo
	tween.parallel().tween_property(self, "position", position + Vector2(-10, 0), 0.1)
	tween.parallel().tween_property(self, "position", position, 0.1)
	
	await tween.finished

func _simulate_defense_animation():
	var tween = create_tween()
	
	# 🆕 CORREÇÃO: Efeito de defesa - brilho azul no próprio AnimationSystem
	tween.tween_property(self, "modulate", Color.CYAN, 0.2)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	
	await tween.finished

func _simulate_victory_animation():
	var tween = create_tween()
	
	# Efeito de vitória - pular
	tween.tween_property(self, "position", position + Vector2(0, -20), 0.2)
	tween.tween_property(self, "position", position, 0.2)
	tween.tween_property(self, "position", position + Vector2(0, -20), 0.2)
	tween.tween_property(self, "position", position, 0.2)
	
	await tween.finished

func _simulate_defeat_animation():
	var tween = create_tween()
	
	# Efeito de derrota - cair e desaparecer
	tween.tween_property(self, "rotation", PI / 4, 0.5)
	tween.parallel().tween_property(self, "position", position + Vector2(0, 30), 0.5)
	tween.parallel().tween_property(self, "modulate:a", 0.3, 0.5)
	
	await tween.finished

func _simulate_heal_animation():
	var tween = create_tween()
	
	# 🆕 CORREÇÃO: Efeito de cura - brilho verde no próprio AnimationSystem
	tween.tween_property(self, "modulate", Color.GREEN, 0.3)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	
	await tween.finished

func _simulate_special_animation():
	var tween = create_tween()
	
	# Efeito especial - múltiplos movimentos
	tween.tween_property(self, "scale", scale * 1.3, 0.1)
	tween.tween_property(self, "scale", scale, 0.1)
	tween.tween_property(self, "rotation", PI / 8, 0.1)
	tween.tween_property(self, "rotation", -PI / 8, 0.1)
	tween.tween_property(self, "rotation", 0, 0.1)
	
	await tween.finished

# 🆕 CORREÇÃO: Método para verificar animações disponíveis
func list_available_animations():
	if animation_player:
		print("📋 Animações disponíveis:")
		for anim in animation_player.get_animation_list():
			print("   ✅ " + anim)
	else:
		print("❌ AnimationPlayer não encontrado")

# 🆕 CORREÇÃO: Método para aplicar efeitos visuais no próprio AnimationSystem
func apply_visual_effect(effect_type: String):
	var tween = create_tween()
	
	match effect_type:
		"damage":
			tween.tween_property(self, "modulate", Color.RED, 0.1)
			tween.tween_property(self, "modulate", Color.WHITE, 0.1)
		"heal":
			tween.tween_property(self, "modulate", Color.GREEN, 0.2)
			tween.tween_property(self, "modulate", Color.WHITE, 0.2)
		"defend":
			tween.tween_property(self, "modulate", Color.CYAN, 0.2)
			tween.tween_property(self, "modulate", Color.WHITE, 0.2)
		"highlight":
			tween.tween_property(self, "scale", scale * 1.1, 0.1)
			tween.tween_property(self, "scale", scale, 0.1)
	
	await tween.finished
