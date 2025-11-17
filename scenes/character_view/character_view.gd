extends Node2D
class_name CharacterView

@export var character: Character
@export var auto_setup: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var effects_node: Node2D = $Effects

var current_animation: String = ""
var is_busy: bool = false

func _ready():
	if auto_setup and character:
		setup_character()

func setup_character():
	# Configura aparência básica
	if character.texture:
		sprite.texture = character.texture
	
	# Configura escala se definida nos dados de animação
	if character.animation_data:
		scale = character.animation_data.animation_scale
		position += character.animation_data.sprite_offset
	
	# Conecta sinais do personagem
	character.animation_requested.connect(_on_animation_requested)
	character.damage_animation_requested.connect(_on_damage_animation_requested)
	character.effect_requested.connect(_on_effect_requested)
	
	# Configura animações se disponíveis
	if character.animation_data:
		setup_animations_from_data()
	
	# Inicia com animação idle
	play_idle()

func setup_animations_from_data():
	var anim_data = character.animation_data
	
	# Limpa animações existentes
	for anim_name in animation_player.get_animation_list():
		animation_player.remove_animation(anim_name)
	
	# Adiciona animações do resource
	if anim_data.idle_animation:
		animation_player.add_animation("idle", anim_data.idle_animation)
	if anim_data.walk_animation:
		animation_player.add_animation("walk", anim_data.walk_animation)
	if anim_data.attack_melee_animation:
		animation_player.add_animation("attack_melee", anim_data.attack_melee_animation)
	if anim_data.attack_magic_animation:
		animation_player.add_animation("attack_magic", anim_data.attack_magic_animation)
	if anim_data.attack_ranged_animation:
		animation_player.add_animation("attack_ranged", anim_data.attack_ranged_animation)
	if anim_data.damage_animation:
		animation_player.add_animation("damage", anim_data.damage_animation)
	if anim_data.defense_animation:
		animation_player.add_animation("defend", anim_data.defense_animation)
	if anim_data.victory_animation:
		animation_player.add_animation("victory", anim_data.victory_animation)
	if anim_data.defeat_animation:
		animation_player.add_animation("defeat", anim_data.defeat_animation)
	
	# Conecta o sinal de animação finalizada
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)

# Métodos de animação
func play_idle():
	if not is_busy:
		if animation_player.has_animation("idle"):
			animation_player.play("idle")
			current_animation = "idle"
		else:
			# Fallback: para qualquer animação
			animation_player.stop()

func play_attack(attack_type: String = "melee"):
	is_busy = true
	var anim_name = "attack_" + attack_type
	
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
		current_animation = anim_name
	else:
		# Fallback para ataque melee
		if animation_player.has_animation("attack_melee"):
			animation_player.play("attack_melee")
			current_animation = "attack_melee"
		else:
			create_default_attack_animation()

func play_damage():
	is_busy = true
	if animation_player.has_animation("damage"):
		animation_player.play("damage")
		current_animation = "damage"
	else:
		create_default_damage_animation()

func play_defend():
	is_busy = true
	if animation_player.has_animation("defend"):
		animation_player.play("defend")
		current_animation = "defend"
	else:
		create_default_defend_animation()

func play_walk():
	if not is_busy and animation_player.has_animation("walk"):
		animation_player.play("walk")
		current_animation = "walk"

func play_victory():
	is_busy = true
	if animation_player.has_animation("victory"):
		animation_player.play("victory")
		current_animation = "victory"

func play_defeat():
	is_busy = true
	if animation_player.has_animation("defeat"):
		animation_player.play("defeat")
		current_animation = "defeat"

# Sinais do personagem
func _on_animation_requested(animation_name: String, attack_type: String):
	match animation_name:
		"attack":
			play_attack(attack_type)
		"defend":
			play_defend()
		"idle":
			play_idle()
		"walk":
			play_walk()
		"victory":
			play_victory()
		"defeat":
			play_defeat()

func _on_damage_animation_requested():
	play_damage()

func _on_effect_requested(effect_name: String, position_offset: Vector2):
	spawn_effect(effect_name, position_offset)

func _on_animation_finished(anim_name: String):
	is_busy = false
	
	# Volta para idle após certas animações
	match anim_name:
		"attack_melee", "attack_magic", "attack_ranged", "damage", "defend":
			play_idle()

# Sistema de efeitos
func spawn_effect(effect_name: String, position_offset: Vector2):
	var effect_scene = get_effect_scene(effect_name)
	if effect_scene:
		var effect_instance = effect_scene.instantiate()
		effects_node.add_child(effect_instance)
		effect_instance.position = position_offset
		
		# Configura efeito baseado no tipo
		match effect_name:
			"slash", "magic", "arrow":
				effect_instance.play()
			"heal", "shield", "sparkles":
				effect_instance.emitting = true
			"highlight":
				create_highlight_effect()

func get_effect_scene(effect_name: String) -> PackedScene:
	if character and character.animation_data:
		match effect_name:
			"slash":
				return character.animation_data.slash_effect
			"magic":
				return character.animation_data.magic_effect
			"heal":
				return character.animation_data.heal_effect
			"shield":
				return character.animation_data.shield_effect
	return null

# Animações padrão (fallback)
func create_default_attack_animation():
	var animation = Animation.new()
	var track_idx = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_idx, "Sprite2D:position")
	animation.length = 0.4
	
	animation.track_insert_key(track_idx, 0.0, Vector2(0, 0))
	animation.track_insert_key(track_idx, 0.1, Vector2(15, -5))
	animation.track_insert_key(track_idx, 0.3, Vector2(0, 0))
	
	animation_player.add_animation("attack_default", animation)
	animation_player.play("attack_default")
	current_animation = "attack_default"

func create_default_damage_animation():
	var animation = Animation.new()
	var track_idx = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_idx, "Sprite2D:modulate")
	animation.length = 0.4
	
	animation.track_insert_key(track_idx, 0.0, Color.WHITE)
	animation.track_insert_key(track_idx, 0.1, Color.RED)
	animation.track_insert_key(track_idx, 0.2, Color.WHITE)
	animation.track_insert_key(track_idx, 0.3, Color.RED)
	animation.track_insert_key(track_idx, 0.4, Color.WHITE)
	
	animation_player.add_animation("damage_default", animation)
	animation_player.play("damage_default")
	current_animation = "damage_default"

func create_default_defend_animation():
	var animation = Animation.new()
	var track_idx = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_idx, "Sprite2D:scale")
	animation.length = 0.3
	
	animation.track_insert_key(track_idx, 0.0, Vector2(1, 1))
	animation.track_insert_key(track_idx, 0.1, Vector2(0.95, 1.05))
	animation.track_insert_key(track_idx, 0.2, Vector2(1, 1))
	
	animation_player.add_animation("defend_default", animation)
	animation_player.play("defend_default")
	current_animation = "defend_default"

func create_highlight_effect():
	# Efeito simples de highlight
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.YELLOW, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

# Utilitários
func get_animation_length(animation_name: String) -> float:
	if animation_player.has_animation(animation_name):
		return animation_player.get_animation(animation_name).length
	return 0.0

func is_playing_animation() -> bool:
	return animation_player.is_playing()

func get_current_animation() -> String:
	return current_animation
