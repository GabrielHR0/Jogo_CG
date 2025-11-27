extends Node2D
class_name CharacterView

@export var character: Character
@export var auto_setup: bool = true

@onready var sprite: Sprite2D = $Sprite2D

# Sistema de animação
var original_position: Vector2 = Vector2.ZERO
var is_dashing: bool = false
var dash_tween: Tween = null

# Barra de vida
var health_bar_container: Control
var health_bar_fill: ColorRect
var health_bar_created: bool = false

func _ready():
	if auto_setup and character:
		setup_character()

func setup_character():
	if character.texture:
		sprite.texture = character.texture
		adjust_sprite_size()
		center_sprite()
	
	original_position = position
	
	if character.animation_data:
		var combined_scale = character.animation_data.animation_scale * Vector2(0.6, 0.6)
		scale = combined_scale
		position += character.animation_data.sprite_offset
	else:
		scale = Vector2(0.6, 0.6)
	
	# Criar barra de vida
	create_health_bar()

func center_sprite():
	if not sprite.texture:
		return
	
	# 🆕 CORREÇÃO: Centralizar o sprite no pivô do CharacterView
	# Resetar a posição primeiro
	sprite.position = Vector2.ZERO
	
	# O pivô do CharacterView já é (0,0), então o sprite fica centralizado naturalmente
	# Se precisar de ajuste adicional, usar offset
	if character and character.animation_data:
		sprite.position += character.animation_data.sprite_offset

func adjust_sprite_size():
	if not sprite.texture:
		return
	
	var texture_size = sprite.texture.get_size()
	var max_width = 240 # 🆕 Aumentado de 120 para 180
	var max_height = 290 # 🆕 Aumentado de 150 para 220
	
	# 🆕 CORREÇÃO: Calcular escala mantendo proporção
	var scale_x = max_width / texture_size.x
	var scale_y = max_height / texture_size.y
	var final_scale = min(scale_x, scale_y)
	
	sprite.scale = Vector2(final_scale, final_scale)
	
	print("🎯 CharacterView ajustado: ", character.name if character else "Unknown")
	print("   Textura: ", texture_size)
	print("   Escala: ", final_scale)
	print("   Tamanho final: ", texture_size * final_scale)

func create_health_bar():
	if health_bar_created:
		return
	
	health_bar_container = Control.new()
	health_bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var bar_width = 80
	var bar_height = 7
	
	# 🆕 CALCULAR POSIÇÃO BASEADA NO TAMANHO DO SPRITE
	var sprite_height = get_sprite_size().y
	var bar_offset = sprite_height * 0.5  # 60% da altura do sprite acima
	
	health_bar_container.position = Vector2(-bar_width / 2, -bar_offset)
	health_bar_container.size = Vector2(bar_width, bar_height)
	
	# Fundo da barra
	var health_bar_background = ColorRect.new()
	health_bar_background.size = Vector2(bar_width + 2, bar_height + 2)
	health_bar_background.position = Vector2(-1, -1)
	health_bar_background.color = Color.BLACK
	
	# Preenchimento da barra
	health_bar_fill = ColorRect.new()
	health_bar_fill.size = Vector2(bar_width, bar_height)
	health_bar_fill.position = Vector2(0, 0)
	health_bar_fill.color = Color.GREEN
	
	health_bar_container.add_child(health_bar_background)
	health_bar_container.add_child(health_bar_fill)
	add_child(health_bar_container)
	
	health_bar_created = true
	update_health_bar()

func update_health_bar():
	if not health_bar_fill or not character:
		return
	
	var health_ratio = float(character.current_hp) / float(character.get_max_hp())
	health_ratio = max(0, health_ratio)
	
	health_bar_fill.size.x = 80 * health_ratio
	
	if health_ratio > 0.6:
		health_bar_fill.color = Color.GREEN
	elif health_ratio > 0.3:
		health_bar_fill.color = Color.YELLOW
	else:
		health_bar_fill.color = Color.RED
	
	health_bar_container.visible = character.is_alive()

# 🆕 SISTEMA DE ANIMAÇÕES DE SUPORTE COM SPRITEFRAMES DAS AÇÕES

# Efeito de cura com SpriteFrames da ação
func play_heal_effect(heal_amount: int, action: SupportAction = null):
	print("💚 CharacterView EFEITO DE CURA: ", character.name, " +", heal_amount, "HP")
	
	# 🆕 PRIMEIRO: Tentar usar o SpriteFrames da ação se disponível
	if action and action.heal_effect_frames:
		print("   🎬 Usando SpriteFrames da ação para cura")
		_create_action_effect(action.heal_effect_frames, Color.GREEN, Vector2(1.2, 1.2), Vector2(0, -50))
	else:
		# Fallback: Efeito visual básico de cura no sprite
		var heal_tween = create_tween()
		heal_tween.parallel().tween_property(sprite, "modulate", Color.GREEN, 0.2)
		heal_tween.parallel().tween_property(sprite, "scale", sprite.scale * 1.1, 0.2)
		heal_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
		heal_tween.parallel().tween_property(sprite, "scale", sprite.scale, 0.2)
	
	# Texto flutuante de cura
	show_floating_text("+" + str(heal_amount) + " HP", Color.GREEN)

# Efeito de buff com SpriteFrames da ação
func play_buff_effect(buff_attribute: String, buff_value: int, action: SupportAction = null):
	print("📈 CharacterView EFEITO DE BUFF: ", character.name, " +", buff_value, " ", buff_attribute)
	
	var buff_color = _get_buff_color(buff_attribute)
	
	# 🆕 PRIMEIRO: Tentar usar o SpriteFrames da ação se disponível
	if action and action.buff_effect_frames:
		print("   🎬 Usando SpriteFrames da ação para buff")
		_create_action_effect(action.buff_effect_frames, buff_color, Vector2(1.1, 1.1), Vector2(0, -30))
	else:
		# Fallback: Efeito visual básico de buff
		var buff_tween = create_tween()
		buff_tween.parallel().tween_property(sprite, "modulate", buff_color, 0.3)
		buff_tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	
	# Texto flutuante do buff
	var attribute_text = _get_buff_display_name(buff_attribute)
	show_floating_text(attribute_text + " +" + str(buff_value), buff_color)

# Efeito de escudo com SpriteFrames da ação
func play_shield_effect(shield_amount: int, action: SupportAction = null):
	print("🛡️ CharacterView EFEITO DE ESCUDO: ", character.name, " +", shield_amount, " escudo")
	
	# 🆕 PRIMEIRO: Tentar usar o SpriteFrames da ação se disponível
	if action and action.shield_effect_frames:
		print("   🎬 Usando SpriteFrames da ação para escudo")
		_create_action_effect(action.shield_effect_frames, Color.CYAN, Vector2(1.3, 1.3), Vector2(0, -20))
	else:
		# Fallback: Efeito visual básico de escudo
		var shield_tween = create_tween()
		shield_tween.parallel().tween_property(sprite, "modulate", Color.CYAN, 0.4)
		shield_tween.parallel().tween_property(sprite, "scale", sprite.scale * 1.05, 0.4)
		shield_tween.tween_property(sprite, "modulate", Color.WHITE, 0.4)
		shield_tween.parallel().tween_property(sprite, "scale", sprite.scale, 0.4)
	
	# Texto flutuante
	show_floating_text("Escudo +" + str(shield_amount), Color.CYAN)

# Efeito de cleanse com SpriteFrames da ação
func play_cleanse_effect(debuff_count: int, action: SupportAction = null):
	print("✨ CharacterView EFEITO DE CLEANSE: ", character.name, " removeu ", debuff_count, " debuffs")
	
	# 🆕 PRIMEIRO: Tentar usar o SpriteFrames da ação se disponível
	if action and action.cleanse_effect_frames:
		print("   🎬 Usando SpriteFrames da ação para cleanse")
		_create_action_effect(action.cleanse_effect_frames, Color.WHITE, Vector2(1.0, 1.0), Vector2(0, -40))
	else:
		# Fallback: Efeito visual básico de purificação
		var cleanse_tween = create_tween()
		cleanse_tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.3)
		cleanse_tween.parallel().tween_property(sprite, "scale", sprite.scale * 1.15, 0.3)
		cleanse_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
		cleanse_tween.parallel().tween_property(sprite, "scale", sprite.scale, 0.2)
	
	# Texto flutuante
	show_floating_text("Purificado!", Color.WHITE)

# Efeito de HOT (Heal Over Time)
func play_hot_effect(hot_amount: int, duration: int):
	print("💚 CharacterView EFEITO DE HOT: ", character.name, " +", hot_amount, "HP/turno por ", duration, " turnos")
	
	# Efeito visual mais suave para HOT
	var hot_tween = create_tween()
	hot_tween.parallel().tween_property(sprite, "modulate", Color(0, 1, 0, 0.7), 0.2)
	hot_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	
	# Texto flutuante específico para HOT
	show_floating_text("Cura Contínua +" + str(hot_amount), Color(0, 1, 0, 0.8))

# 🆕 FUNÇÃO PRINCIPAL: Criar efeito visual com SpriteFrames
func _create_action_effect(sprite_frames: SpriteFrames, color: Color, effect_scale: Vector2, offset: Vector2):
	if not sprite_frames:
		print("   ❌ SpriteFrames não disponível")
		return
	
	var effect_sprite = AnimatedSprite2D.new()
	effect_sprite.sprite_frames = sprite_frames
	effect_sprite.scale = effect_scale
	effect_sprite.modulate = color
	effect_sprite.z_index = 1000
	effect_sprite.centered = true
	
	# Posicionar acima do personagem
	effect_sprite.global_position = global_position + offset
	
	# Usar top_level para ficar acima de tudo
	effect_sprite.top_level = true
	effect_sprite.z_as_relative = false
	
	get_tree().current_scene.add_child(effect_sprite)
	
	# Tocar animação
	if sprite_frames.has_animation("default"):
		effect_sprite.play("default")
		effect_sprite.animation_finished.connect(_on_effect_animation_finished.bind(effect_sprite))
	else:
		# Fallback: usar primeira animação disponível
		var anim_names = sprite_frames.get_animation_names()
		if anim_names.size() > 0:
			effect_sprite.play(anim_names[0])
			effect_sprite.animation_finished.connect(_on_effect_animation_finished.bind(effect_sprite))
		else:
			print("   ❌ Nenhuma animação encontrada no SpriteFrames")
			effect_sprite.queue_free()

func _on_effect_animation_finished(effect_sprite: AnimatedSprite2D):
	if effect_sprite and is_instance_valid(effect_sprite):
		effect_sprite.queue_free()

# 🆕 FUNÇÃO PARA EFEITOS DE ATAQUE COM SPRITEFRAMES
func play_attack_effect(action: Action):
	print("🎬 CharacterView EFEITO DE ATAQUE: ", character.name, " - ", action.name)
	
	# 🆕 Usar o sistema de efeitos da Action se disponível
	if action.has_effect_animation():
		print("   🎬 Usando SpriteFrames da ação de ataque")
		var effect_position = global_position
		var effect = action.create_effect_animation(effect_position, get_tree().current_scene)
		if effect:
			print("   ✅ Efeito de ataque criado")
		else:
			print("   ❌ Não foi possível criar efeito de ataque")

# 🆕 FUNÇÕES AUXILIARES PARA ANIMAÇÕES

# Texto flutuante para efeitos
func show_floating_text(text: String, color: Color):
	var floating_text = Label.new()
	floating_text.text = text
	floating_text.add_theme_color_override("font_color", color)
	floating_text.add_theme_font_size_override("font_size", 16)
	floating_text.position = Vector2(-40, -80)
	
	# Configurar como top_level para ficar acima de tudo
	floating_text.top_level = true
	floating_text.z_index = 2000
	
	add_child(floating_text)
	
	# Animação do texto flutuante
	var text_tween = create_tween()
	text_tween.parallel().tween_property(floating_text, "position", floating_text.position + Vector2(0, -50), 1.0)
	text_tween.parallel().tween_property(floating_text, "modulate:a", 0.0, 1.0)
	text_tween.tween_callback(floating_text.queue_free)

func _get_buff_color(attribute: String) -> Color:
	match attribute:
		"strength", "attack": return Color.RED
		"constitution", "defense": return Color.ORANGE
		"agility", "speed": return Color.YELLOW
		"intelligence", "magic": return Color.CYAN
		"max_hp": return Color.GREEN
		"critical_chance": return Color.PURPLE
		_: return Color.WHITE

func _get_buff_display_name(attribute: String) -> String:
	match attribute:
		"strength": return "Força"
		"constitution": return "Constituição"
		"agility": return "Agilidade"
		"intelligence": return "Inteligência"
		"defense": return "Defesa"
		"attack": return "Ataque"
		"speed": return "Velocidade"
		"magic": return "Magia"
		"max_hp": return "Vida Máxima"
		"critical_chance": return "Crítico"
		_: return attribute

# 🆕 FUNÇÃO PARA DEBUG VISUAL
func enable_debug_visuals():
	# Adicionar um ponto vermelho no pivô (0,0)
	var debug_point = Sprite2D.new()
	debug_point.texture = preload("res://icon.svg")  # Usar qualquer textura pequena
	debug_point.scale = Vector2(0.1, 0.1)
	debug_point.modulate = Color.RED
	debug_point.z_index = 1000
	add_child(debug_point)
	
	# Adicionar retângulo verde ao redor do sprite
	var debug_rect = ColorRect.new()
	debug_rect.size = sprite.get_rect().size
	debug_rect.position = sprite.position
	debug_rect.color = Color(0, 1, 0, 0.3)  # Verde semi-transparente
	debug_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(debug_rect)

# 🆕 SISTEMA SIMPLIFICADO: BattleScene chama esta função diretamente
func execute_melee_attack(target_global_position: Vector2):
	print("🎬 CharacterView EXECUTANDO ATAQUE MEELE: ", character.name)
	
	if is_dashing:
		print("   ❌ Já está em dash - ignorando")
		return
	
	is_dashing = true
	
	# 1. Calcular posição próxima do alvo
	var direction = (target_global_position - global_position).normalized()
	var distance = global_position.distance_to(target_global_position)
	var dash_distance = distance * 0.7  # 70% da distância
	var min_distance = 50.0
	dash_distance = max(dash_distance, min_distance)
	var dash_target = position + (direction * dash_distance)
	
	print("   📏 Dash para: ", dash_target, " (distância: ", dash_distance, ")")
	
	# 2. Sequência de dash
	var sequence_tween = create_tween()
	
	# Dash para frente
	sequence_tween.tween_property(self, "position", dash_target, 0.3)
	sequence_tween.tween_callback(perform_attack_animation)
	
	# Pequena pausa para ataque
	sequence_tween.tween_interval(0.3)
	
	# Voltar
	sequence_tween.tween_property(self, "position", original_position, 0.4)
	sequence_tween.tween_callback(finish_attack)

func perform_attack_animation():
	print("   🗡️ Executando animação de ataque")
	# Animação simples de ataque
	var attack_tween = create_tween()
	attack_tween.tween_property(sprite, "position", sprite.position + Vector2(15, -8), 0.1)
	attack_tween.tween_property(sprite, "position", sprite.position, 0.1)

func finish_attack():
	print("   ✅ Ataque concluído")
	is_dashing = false
	position = original_position  # Garantir posição exata

# Para outros tipos de ataque
func execute_normal_attack():
	print("🎬 CharacterView ATAQUE NORMAL: ", character.name)
	var attack_tween = create_tween()
	attack_tween.tween_property(sprite, "position", sprite.position + Vector2(10, -5), 0.1)
	attack_tween.tween_property(sprite, "position", sprite.position, 0.1)

# Sistema de dano
func take_damage():
	print("💥 CharacterView DANO: ", character.name)
	var damage_tween = create_tween()
	damage_tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	damage_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

# Sistema de slash effects
func apply_slash_effect(slash_config: Dictionary):
	print("🗡️ CharacterView SLASH EFFECT: ", character.name)
	
	var slash_sprite = AnimatedSprite2D.new()
	slash_sprite.sprite_frames = slash_config.get("sprite_frames")
	slash_sprite.scale = slash_config.get("scale", Vector2(1, 1))
	slash_sprite.modulate = slash_config.get("color", Color.WHITE)
	slash_sprite.z_index = slash_config.get("z_index", 1000)
	slash_sprite.centered = true
	
	# Usar top_level para ficar acima de tudo
	slash_sprite.top_level = true
	slash_sprite.z_as_relative = false
	
	# Posicionar no personagem
	slash_sprite.global_position = global_position
	
	get_tree().current_scene.add_child(slash_sprite)
	
	if slash_sprite.sprite_frames:
		var anim_names = slash_sprite.sprite_frames.get_animation_names()
		if anim_names.size() > 0:
			var anim_to_play = "default" if slash_sprite.sprite_frames.has_animation("default") else anim_names[0]
			slash_sprite.sprite_frames.set_animation_loop(anim_to_play, false)
			slash_sprite.play(anim_to_play)
	
	# Conectar sinal para remover após animação
	slash_sprite.animation_finished.connect(_on_slash_animation_finished.bind(slash_sprite))
	
func play_defense_effect(action: SupportAction = null):
	print("🛡️ CharacterView EFEITO DE DEFESA: ", character.name)
	
	# Efeito visual inicial
	var defense_tween = create_tween()
	defense_tween.parallel().tween_property(sprite, "modulate", Color.CYAN, 0.2)
	defense_tween.parallel().tween_property(sprite, "scale", sprite.scale * 1.05, 0.2)
	defense_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	defense_tween.parallel().tween_property(sprite, "scale", sprite.scale, 0.2)
	
	# Texto flutuante
	show_floating_text("Defesa ↑", Color.CYAN)
	
	# 🆕 Se a ação tiver efeito persistente, ele será criado automaticamente pela SupportAction

# 🆕 NOVO: Efeito de debuff (adicione este método também se não existir)
func play_debuff_effect(attribute: String, value: int):
	print("📉 CharacterView EFEITO DE DEBUFF: ", character.name, " -", value, " ", attribute)
	
	var debuff_color = Color(1, 0, 0, 0.7)  # Vermelho escuro
	var debuff_tween = create_tween()
	debuff_tween.parallel().tween_property(sprite, "modulate", debuff_color, 0.3)
	debuff_tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	
	var attribute_text = _get_buff_display_name(attribute)
	show_floating_text(attribute_text + " -" + str(value), debuff_color)
	
func _on_slash_animation_finished(slash_sprite: AnimatedSprite2D):
	if slash_sprite and is_instance_valid(slash_sprite):
		slash_sprite.queue_free()

# Atualizar barra de vida continuamente
func _process(_delta):
	if character and health_bar_created:
		update_health_bar()

# 🆕 FUNÇÃO PARA OBTER TAMANHO DO SPRITE (útil para o BattleScene)
func get_sprite_size() -> Vector2:
	if sprite and sprite.texture:
		return sprite.texture.get_size() * sprite.scale
	return Vector2.ZERO

# 🆕 FUNÇÃO PARA OBTER RETÂNGULO DO SPRITE
func get_sprite_rect() -> Rect2:
	if sprite and sprite.texture:
		var texture_size = sprite.texture.get_size() * sprite.scale
		return Rect2(sprite.position, texture_size)
	return Rect2()
	
