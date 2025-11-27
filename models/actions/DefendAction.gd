extends Action
class_name DefendAction

@export_category("Defense Configuration")
@export var ap_cost_percentage: float = 0.8
@export var defense_multiplier: float = 2.0
@export var dodge_chance_bonus: float = 0.25
@export var damage_reflection: float = 0.1
@export var counter_attack_chance: float = 0.3

@export_category("Visual Effects")
@export var shield_color: Color = Color.CYAN
@export var shield_secondary_color: Color = Color.DARK_CYAN
@export var shield_size: float = 1.5
@export var shield_pulse_speed: float = 3.0
@export var particles_enabled: bool = true

# 🆕 NOVO: Sinal com detalhes da defesa
signal defense_details_updated(user: Character, defense_bonus: int, dodge_bonus: float, reflection: float, counter_chance: float)

var active_shields: Dictionary = {}
var battle_scene: Node = null

func _init():
	name = "Postura Defensiva Máxima"
	target_type = "self"
	description = "Assume uma postura defensiva perfeita, gastando grande parte da energia para criar uma barreira quase impenetrável"
	animation_type = "special"

func set_battle_scene(scene: Node):
	"""Define a referência do BattleScene para acessar character_views"""
	battle_scene = scene

func execute(user: Character, target: Character) -> void:
	super.execute(user, target)
	
	# 🆕 CUSTO ALTO: Percentual do AP máximo
	ap_cost = int(user.get_max_ap() * ap_cost_percentage)
	
	if not user.has_ap_for_action(self):
		print("   ❌", user.name, "não tem AP suficiente para a defesa máxima")
		print("   💰 AP necessário: ", ap_cost, " | AP disponível: ", user.current_ap)
		return
	
	user.spend_ap(ap_cost)
	
	# 🆕 DEFESA COMPLEXA COM MÚLTIPLOS EFEITOS
	user.start_advanced_defense(defense_multiplier, dodge_chance_bonus, damage_reflection, counter_attack_chance)
	effect_applied.emit(user, user, "defesa_avancada", 1)
	
	# 🆕 ANIMAÇÃO PROCEDURAL COMPLEXA
	create_advanced_defense_animation(user)
	
	# 🆕 NOVO: Calcular bônus de defesa para exibir
	var defense_bonus = int(user.get_attribute("constitution") * defense_multiplier)
	
	print("   🛡️", user.name, "ativa POSTURA DEFENSIVA MÁXIMA")
	print("   💰 Custo: ", ap_cost, " AP (\", ap_cost_percentage * 100, \"% do máximo)")
	print("   🎯 Esquiva: +", dodge_chance_bonus * 100, "%")
	print("   🔄 Reflexão: +", damage_reflection * 100, "% do dano")
	print("   ⚔️ Contra-ataque: ", counter_attack_chance * 100, "% de chance")
	print("   ⏱️ Duração: Até seu próximo turno")
	
	# 🆕 NOVO: Emitir sinal com detalhes
	defense_details_updated.emit(user, defense_bonus, dodge_chance_bonus, damage_reflection, counter_attack_chance)

func create_advanced_defense_animation(user: Character):
	if not battle_scene or not battle_scene.has_method("get_character_views"):
		print("   ❌ BattleScene não disponível")
		return
	
	var character_views = battle_scene.get_character_views()
	if not character_views or not user.name in character_views:
		print("   ❌ CharacterView não encontrada para: ", user.name)
		return
	
	var character_view = character_views[user.name]
	
	# Verificar se já existe um escudo ativo
	var shield_id = user.name + "_advanced_defense"
	if shield_id in active_shields:
		remove_defense_shield(shield_id)
	
	# 🆕 1. ESCUDO PRINCIPAL (Sprite2D)
	var main_shield = Sprite2D.new()
	main_shield.texture = create_shield_texture()
	main_shield.scale = Vector2(shield_size, shield_size)
	main_shield.modulate = shield_color
	main_shield.z_index = 450
	main_shield.centered = true
	
	# 🆕 2. ESCUDO SECUNDÁRIO (para efeito de profundidade)
	var secondary_shield = Sprite2D.new()
	secondary_shield.texture = create_shield_texture()
	secondary_shield.scale = Vector2(shield_size * 0.7, shield_size * 0.7)
	secondary_shield.modulate = shield_secondary_color
	secondary_shield.z_index = 449
	secondary_shield.centered = true
	
	# 🆕 3. PARTÍCULAS (se habilitado)
	var particles = null
	if particles_enabled:
		particles = CPUParticles2D.new()
		configure_particles(particles)
	
	# Adicionar ao CharacterView
	character_view.add_child(main_shield)
	character_view.add_child(secondary_shield)
	if particles:
		character_view.add_child(particles)
	
	# 🆕 4. ANIMAÇÕES PROCEDURAIS
	create_shield_animations(main_shield, secondary_shield, particles, character_view, user)
	
	# Armazenar referências
	active_shields[shield_id] = {
		"main_shield": main_shield,
		"secondary_shield": secondary_shield,
		"particles": particles,
		"character": user,
		"character_view": character_view,
		"animation_tween": null
	}
	
	print("   🎆 Escudo defensivo complexo criado para ", user.name)

func create_shield_texture() -> Texture2D:
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Desenhar um escudo circular com gradiente
	for x in range(64):
		for y in range(64):
			var distance = Vector2(x - 32, y - 32).length()
			if distance <= 30 and distance >= 20:  # Anel externo
				var alpha = 1.0 - (distance - 20) / 10.0
				image.set_pixel(x, y, Color(shield_color.r, shield_color.g, shield_color.b, alpha * 0.8))
			elif distance <= 20:  # Centro
				var alpha = 1.0 - distance / 20.0
				image.set_pixel(x, y, Color(shield_color.r, shield_color.g, shield_color.b, alpha * 0.4))
	
	var texture = ImageTexture.create_from_image(image)
	return texture

func configure_particles(particles: CPUParticles2D):
	particles.emitting = true
	particles.amount = 16
	particles.lifetime = 1.5
	particles.explosiveness = 0.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 25
	particles.spread = 360
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity = 5
	particles.initial_velocity_random = 0.5
	particles.angular_velocity = 45
	particles.angular_velocity_random = 0.5
	particles.scale_amount = 1.0
	particles.scale_amount_random = 0.3
	
	# Gradiente de cor para partículas
	var color_ramp = Gradient.new()
	color_ramp.set_color(0, shield_color)
	color_ramp.set_color(1, shield_secondary_color)
	particles.color_ramp = color_ramp
	
	particles.color = shield_color

func create_shield_animations(main_shield: Sprite2D, secondary_shield: Sprite2D, particles: CPUParticles2D, character_view: Node, user: Character):
	var animation_tween = character_view.create_tween()
	animation_tween.set_parallel(true)
	
	# 1. PULSAÇÃO DO ESCUDO PRINCIPAL
	animation_tween.tween_method(_pulse_main_shield.bind(main_shield), 0.0, TAU, shield_pulse_speed)
	animation_tween.set_loops()
	
	# 2. ROTAÇÃO DO ESCUDO SECUNDÁRIO
	animation_tween.tween_method(_rotate_secondary_shield.bind(secondary_shield), 0.0, -TAU, shield_pulse_speed * 1.5)
	animation_tween.set_loops()
	
	# 3. EFEITO DE "ENERGIZAÇÃO" INICIAL
	var energize_tween = character_view.create_tween()
	energize_tween.tween_property(main_shield, "scale", Vector2(shield_size * 1.3, shield_size * 1.3), 0.3)
	energize_tween.tween_property(main_shield, "scale", Vector2(shield_size, shield_size), 0.2)
	energize_tween.parallel().tween_property(main_shield, "modulate:a", 1.0, 0.5)
	
	# Armazenar o tween para controle
	if active_shields.has(user.name + "_advanced_defense"):
		active_shields[user.name + "_advanced_defense"]["animation_tween"] = animation_tween

func _pulse_main_shield(angle: float, shield: Sprite2D):
	var pulse = sin(angle) * 0.1 + 1.0
	shield.scale = Vector2(shield_size * pulse, shield_size * pulse)
	
	# Modulação de cor baseada na pulsação
	var brightness = 0.8 + pulse * 0.2
	shield.modulate = Color(shield_color.r * brightness, shield_color.g * brightness, shield_color.b * brightness, shield.modulate.a)

func _rotate_secondary_shield(angle: float, shield: Sprite2D):
	shield.rotation = angle
	
	# Efeito de transparência na rotação
	var alpha = 0.5 + sin(angle * 2) * 0.2
	shield.modulate.a = alpha

func remove_defense_shield(shield_id: String):
	if shield_id in active_shields:
		var shield_data = active_shields[shield_id]
		
		print("   🗑️ Removendo escudo defensivo: ", shield_id)
		
		# Efeito de dissipação
		if shield_data.animation_tween:
			shield_data.animation_tween.kill()
		
		var dissipate_tween = shield_data.character_view.create_tween()
		dissipate_tween.set_parallel(true)
		dissipate_tween.tween_property(shield_data.main_shield, "scale", Vector2.ZERO, 0.3)
		dissipate_tween.tween_property(shield_data.main_shield, "modulate:a", 0.0, 0.3)
		dissipate_tween.tween_property(shield_data.secondary_shield, "scale", Vector2.ZERO, 0.3)
		dissipate_tween.tween_property(shield_data.secondary_shield, "modulate:a", 0.0, 0.3)
		
		if shield_data.particles:
			dissipate_tween.tween_property(shield_data.particles, "emitting", false, 0.1)
		
		dissipate_tween.tween_callback(_cleanup_shield.bind(shield_id))
		dissipate_tween.set_delay(0.3)
	else:
		print("   ⚠️ Tentativa de remover escudo não existente: ", shield_id)

func _cleanup_shield(shield_id: String):
	if shield_id in active_shields:
		var shield_data = active_shields[shield_id]
		
		if shield_data.main_shield and is_instance_valid(shield_data.main_shield):
			shield_data.main_shield.queue_free()
		if shield_data.secondary_shield and is_instance_valid(shield_data.secondary_shield):
			shield_data.secondary_shield.queue_free()
		if shield_data.particles and is_instance_valid(shield_data.particles):
			shield_data.particles.queue_free()
		if shield_data.animation_tween:
			shield_data.animation_tween.kill()
		
		active_shields.erase(shield_id)
		print("   🎆 Escudo defensivo removido: ", shield_id)

func update_defense_effects(character: Character = null):
	if character:
		var shield_id = character.name + "_advanced_defense"
		if shield_id in active_shields and not character.is_defending:
			remove_defense_shield(shield_id)
	else:
		var shields_to_remove = []
		for shield_id in active_shields:
			var shield_data = active_shields[shield_id]
			if not shield_data.character or not is_instance_valid(shield_data.character) or not shield_data.character.is_defending:
				shields_to_remove.append(shield_id)
		
		for shield_id in shields_to_remove:
			remove_defense_shield(shield_id)

func clear_all_defense_effects():
	if active_shields.size() == 0:
		return
	
	print("🧹 Limpando TODOS os escudos defensivos (", active_shields.size(), " escudos)")
	
	var shield_ids = active_shields.keys().duplicate()
	for shield_id in shield_ids:
		if shield_id in active_shields:
			_cleanup_shield(shield_id)

func create_effect_animation(position: Vector2, parent: Node) -> Node:
	print("   🎬 Sistema de defesa avançada ativado - animação procedural em andamento")
	return null

func get_active_defense_info() -> Dictionary:
	var info = {}
	for shield_id in active_shields:
		var shield_data = active_shields[shield_id]
		info[shield_id] = {
			"character": shield_data.character.name if shield_data.character else "Unknown",
			"is_defending": shield_data.character.is_defending if shield_data.character else false,
			"defense_bonus": shield_data.character.defense_bonus if shield_data.character else 0
		}
	return info

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if active_shields.size() > 0:
			var shield_ids = active_shields.keys().duplicate()
			for shield_id in shield_ids:
				if shield_id in active_shields:
					_cleanup_shield(shield_id)
