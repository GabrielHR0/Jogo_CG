extends Action
class_name SupportAction

@export_category("Support Effects")
@export var heal_amount: int = 0
@export var buff_attribute: String = ""
@export var buff_value: int = 0
@export var buff_duration: int = 0
@export var shield_amount: int = 0
@export var shield_duration: int = 0
@export var cleanse_debuffs: bool = false
@export var hot_amount: int = 5
@export var hot_duration: int = 2

@export_category("Support Visuals")
@export var heal_effect_frames: SpriteFrames
@export var buff_effect_frames: SpriteFrames
@export var shield_effect_frames: SpriteFrames
@export var cleanse_effect_frames: SpriteFrames

@export_category("Persistent Effects")
@export var has_persistent_effect: bool = false
@export var persistent_effect_frames: SpriteFrames
@export var persistent_effect_color: Color = Color.WHITE
@export var persistent_effect_scale: Vector2 = Vector2(1, 1)
@export var persistent_effect_offset: Vector2 = Vector2(0, -20)

# 🆕 CONTROLE DE LOOP
var is_playing_animation: bool = false

# 🆕 NOVO: Dicionário para rastrear efeitos persistentes ativos
var active_persistent_effects: Dictionary = {}

# Referência para acessar character_views do BattleScene
var battle_scene: Node = null

func _init():
	animation_type = "heal"

func set_battle_scene(scene: Node):
	"""Define a referência do BattleScene para acessar character_views"""
	battle_scene = scene

func apply_effects(user: Character, target: Character) -> void:
	print("🎯 Aplicando efeitos de suporte: ", name)
	print("   User: ", user.name, " | Target: ", target.name)
	
	# 🆕 EVITAR LOOP: Marcar que estamos executando
	is_playing_animation = true
	
	# 🆕 SISTEMA DE CURA
	if heal_amount > 0:
		var previous_hp = target.current_hp
		target.current_hp = min(target.get_max_hp(), target.current_hp + heal_amount)
		var actual_heal = target.current_hp - previous_hp
		healing_applied.emit(user, target, actual_heal)
		print("   💚 Curou ", actual_heal, " HP em ", target.name)
	
	# 🆕 SISTEMA DE BUFF
	if buff_attribute != "" and buff_value > 0:
		target.add_buff(buff_attribute, buff_value, buff_duration)
		effect_applied.emit(user, target, buff_attribute, buff_duration)
		print("   📈 ", target.name, " ganhou +", buff_value, " ", buff_attribute, " por ", buff_duration, " turnos")
		
		# 🆕 NOVO: Criar efeito persistente se configurado
		if has_persistent_effect and persistent_effect_frames:
			create_persistent_effect(target, buff_duration)
		else:
			# 🆕 CORREÇÃO: Se não tem efeito persistente, usar o efeito normal de buff
			_create_buff_effect_animation(target)
	
	# 🆕 SISTEMA DE ESCUDO
	if shield_amount > 0:
		target.add_shield(shield_amount, shield_duration)
		effect_applied.emit(user, target, "shield", shield_duration)
		print("   🛡️ ", target.name, " ganhou escudo de ", shield_amount, " por ", shield_duration, " turnos")
		
		# 🆕 NOVO: Criar efeito persistente para escudo se configurado
		if has_persistent_effect and persistent_effect_frames:
			create_persistent_effect(target, shield_duration)
		else:
			# 🆕 CORREÇÃO: Se não tem efeito persistente, usar o efeito normal de escudo
			_create_shield_effect_animation(target)
	
	# 🆕 SISTEMA DE CLEANSE
	if cleanse_debuffs:
		var removed_count = target.remove_all_debuffs()
		if removed_count > 0:
			effect_applied.emit(user, target, "cleanse", 0)
			print("   ✨ ", target.name, " removeu ", removed_count, " debuffs")
			_create_cleanse_effect_animation(target)
	
	# 🆕 SISTEMA DE HOT (Heal Over Time)
	if hot_amount > 0 and hot_duration > 0:
		target.add_hot(hot_amount, hot_duration)
		effect_applied.emit(user, target, "hot", hot_duration)
		print("   🔥 ", target.name, " ganhou HOT de ", hot_amount, " HP por ", hot_duration, " turnos")
	
	# 🆕 RESETAR CONTROLE DE LOOP
	is_playing_animation = false

# 🆕 NOVO: Criar efeito de buff usando as animações existentes
func _create_buff_effect_animation(target: Character):
	if not buff_effect_frames:
		print("   ❌ Nenhum SpriteFrames de buff configurado")
		return
	
	if not battle_scene or not battle_scene.has_method("get_character_views"):
		print("   ❌ BattleScene não disponível")
		return
	
	var character_views = battle_scene.get_character_views()
	if not character_views or not target.name in character_views:
		print("   ❌ CharacterView não encontrada para: ", target.name)
		return
	
	var character_view = character_views[target.name]
	
	# Usar o sistema existente do CharacterView
	var buff_color = _get_buff_color(buff_attribute)
	character_view.play_buff_effect(buff_attribute, buff_value, self)
	
	print("   🎬 Efeito de buff animado para ", target.name)

# 🆕 NOVO: Criar efeito de escudo usando as animações existentes
func _create_shield_effect_animation(target: Character):
	if not shield_effect_frames:
		print("   ❌ Nenhum SpriteFrames de escudo configurado")
		return
	
	if not battle_scene or not battle_scene.has_method("get_character_views"):
		print("   ❌ BattleScene não disponível")
		return
	
	var character_views = battle_scene.get_character_views()
	if not character_views or not target.name in character_views:
		print("   ❌ CharacterView não encontrada para: ", target.name)
		return
	
	var character_view = character_views[target.name]
	
	# Usar o sistema existente do CharacterView
	character_view.play_shield_effect(shield_amount, self)
	
	print("   🎬 Efeito de escudo animado para ", target.name)

# 🆕 NOVO: Criar efeito de cleanse usando as animações existentes
func _create_cleanse_effect_animation(target: Character):
	if not cleanse_effect_frames:
		print("   ❌ Nenhum SpriteFrames de cleanse configurado")
		return
	
	if not battle_scene or not battle_scene.has_method("get_character_views"):
		print("   ❌ BattleScene não disponível")
		return
	
	var character_views = battle_scene.get_character_views()
	if not character_views or not target.name in character_views:
		print("   ❌ CharacterView não encontrada para: ", target.name)
		return
	
	var character_view = character_views[target.name]
	
	# Usar o sistema existente do CharacterView
	character_view.play_cleanse_effect(0, self)  # 0 porque não sabemos quantos debuffs foram removidos
	
	print("   🎬 Efeito de cleanse animado para ", target.name)

# 🆕 NOVO: Criar efeito de cura usando as animações existentes
func _create_heal_effect_animation(target: Character, heal_amount: int):
	if not heal_effect_frames:
		print("   ❌ Nenhum SpriteFrames de cura configurado")
		return
	
	if not battle_scene or not battle_scene.has_method("get_character_views"):
		print("   ❌ BattleScene não disponível")
		return
	
	var character_views = battle_scene.get_character_views()
	if not character_views or not target.name in character_views:
		print("   ❌ CharacterView não encontrada para: ", target.name)
		return
	
	var character_view = character_views[target.name]
	
	# Usar o sistema existente do CharacterView
	character_view.play_heal_effect(heal_amount, self)
	
	print("   🎬 Efeito de cura animado para ", target.name)

# 🆕 CORREÇÃO: Sobrescrever create_effect_animation para evitar loop
func create_effect_animation(position: Vector2, parent: Node) -> Node:
	# 🆕 EVITAR LOOP: Se já está executando animação, não criar outra
	if is_playing_animation:
		print("   ⚠️ Evitando loop de animação para: ", name)
		return null
	
	# 🆕 CHAMAR A IMPLEMENTAÇÃO ORIGINAL
	return super.create_effect_animation(position, parent)

# 🆕 SOBRESCREVER: Criar efeitos visuais específicos para suporte
func create_support_effect(position: Vector2, parent: Node) -> Node:
	if heal_amount > 0 and heal_effect_frames:
		return create_custom_effect(heal_effect_frames, position, parent, Color.GREEN, Vector2(1.2, 1.2), Vector2(0, -50))
	elif buff_attribute != "" and buff_effect_frames:
		var buff_color = _get_buff_color(buff_attribute)
		return create_custom_effect(buff_effect_frames, position, parent, buff_color, Vector2(1.1, 1.1), Vector2(0, -30))
	elif shield_amount > 0 and shield_effect_frames:
		return create_custom_effect(shield_effect_frames, position, parent, Color.CYAN, Vector2(1.3, 1.3), Vector2(0, -20))
	elif cleanse_debuffs and cleanse_effect_frames:
		return create_custom_effect(cleanse_effect_frames, position, parent, Color.WHITE, Vector2(1.0, 1.0), Vector2(0, -40))
	else:
		return null

# 🆕 NOVO: Criar efeito persistente
func create_persistent_effect(target: Character, duration: int):
	if not persistent_effect_frames:
		print("❌ Não há SpriteFrames configurado para efeito persistente")
		return
	
	# 🆕 Tentar acessar character_views através do BattleScene
	if not battle_scene or not battle_scene.has_method("get_character_views"):
		print("❌ BattleScene não disponível para criar efeito persistente")
		return
	
	var character_views = battle_scene.get_character_views()
	if not character_views or not target.name in character_views:
		print("❌ CharacterView não encontrada para: ", target.name)
		return
	
	var character_view = character_views[target.name]
	
	# Verificar se já existe um efeito persistente para esta ação
	var effect_id = target.name + "_" + name
	if effect_id in active_persistent_effects:
		print("⚠️ Efeito persistente já existe para ", target.name, " - removendo anterior")
		remove_persistent_effect(effect_id)
	
	# Criar o efeito visual
	var effect = AnimatedSprite2D.new()
	effect.sprite_frames = persistent_effect_frames
	effect.scale = persistent_effect_scale
	effect.modulate = persistent_effect_color
	effect.z_index = 500  # Abaixo da barra de vida, acima do sprite
	effect.centered = true
	
	# Posicionar no personagem
	effect.position = persistent_effect_offset
	
	# Adicionar ao CharacterView
	character_view.add_child(effect)
	
	# Tocar animação em loop
	if persistent_effect_frames.has_animation("default"):
		effect.play("default")
		persistent_effect_frames.set_animation_loop("default", true)
	else:
		# Fallback: usar primeira animação disponível
		var anim_names = persistent_effect_frames.get_animation_names()
		if anim_names.size() > 0:
			effect.play(anim_names[0])
			persistent_effect_frames.set_animation_loop(anim_names[0], true)
	
	# 🆕 CORREÇÃO: Armazenar a duração correta baseada no tipo de efeito
	var actual_duration = duration
	if buff_attribute != "":
		actual_duration = buff_duration
	elif shield_amount > 0:
		actual_duration = shield_duration
	
	# Armazenar referência do efeito
	active_persistent_effects[effect_id] = {
		"effect": effect,
		"target": target,
		"duration": actual_duration,
		"turns_remaining": actual_duration,
		"character_view": character_view,
		"effect_type": "buff" if buff_attribute != "" else "shield"
	}
	
	print("🎆 Efeito persistente criado para ", target.name, " por ", actual_duration, " turnos (ID: ", effect_id, ")")
	
	# 🆕 CORREÇÃO: Também mostrar o efeito normal de buff/escudo
	if buff_attribute != "":
		_create_buff_effect_animation(target)
	elif shield_amount > 0:
		_create_shield_effect_animation(target)

# 🆕 CORREÇÃO: Atualizar efeitos persistentes a cada turno (método principal)
func update_persistent_effects():
	var effects_to_remove = []
	
	for effect_id in active_persistent_effects:
		var effect_data = active_persistent_effects[effect_id]
		
		# Verificar se o alvo ainda está vivo e válido
		if not effect_data.target or not is_instance_valid(effect_data.target) or not effect_data.target.is_alive():
			print("🎯 Alvo inválido ou morto - removendo efeito: ", effect_id)
			effects_to_remove.append(effect_id)
			continue
		
		# 🆕 CORREÇÃO: Verificar se o buff ainda está ativo no character
		if effect_data.effect_type == "buff" and buff_attribute != "":
			if effect_data.target.has_buff(buff_attribute):
				effect_data.turns_remaining -= 1
				print("✅ Buff ainda ativo para ", effect_data.target.name, " - Turnos restantes: ", effect_data.turns_remaining)
				
				if effect_data.turns_remaining <= 0:
					print("⏰ Duração do buff acabou: ", effect_id)
					effects_to_remove.append(effect_id)
			else:
				print("❌ Buff expirou para ", effect_data.target.name, " - removendo efeito persistente")
				effects_to_remove.append(effect_id)
				continue
		
		# 🆕 CORREÇÃO: Verificar se o escudo ainda está ativo
		elif effect_data.effect_type == "shield" and shield_amount > 0:
			if effect_data.target.current_shield > 0:
				effect_data.turns_remaining -= 1
				print("✅ Escudo ainda ativo para ", effect_data.target.name, " - Turnos restantes: ", effect_data.turns_remaining)
				
				if effect_data.turns_remaining <= 0:
					print("⏰ Duração do escudo acabou: ", effect_id)
					effects_to_remove.append(effect_id)
			else:
				print("❌ Escudo expirou para ", effect_data.target.name, " - removendo efeito persistente")
				effects_to_remove.append(effect_id)
				continue
	
	# Remover efeitos expirados
	for effect_id in effects_to_remove:
		remove_persistent_effect(effect_id)

# 🆕 NOVO: Remover efeito persistente
func remove_persistent_effect(effect_id: String):
	if effect_id in active_persistent_effects:
		var effect_data = active_persistent_effects[effect_id]
		
		print("🗑️ Removendo efeito persistente: ", effect_id)
		
		# Remover o nó do efeito visual
		if effect_data.effect and is_instance_valid(effect_data.effect):
			effect_data.effect.queue_free()
		
		# Limpar referências
		active_persistent_effects.erase(effect_id)
		
		print("🎆 Efeito persistente removido: ", effect_id)
	else:
		print("⚠️ Tentativa de remover efeito não existente: ", effect_id)

# 🆕 NOVO: Remover todos os efeitos persistentes
func clear_all_persistent_effects():
	print("🧹 Limpando TODOS os efeitos persistentes (", active_persistent_effects.size(), " efeitos)")
	
	var effect_ids = active_persistent_effects.keys()
	for effect_id in effect_ids:
		remove_persistent_effect(effect_id)

# 🆕 NOVO: Verificar se um personagem tem efeito persistente ativo
func has_persistent_effect_on_character(character_name: String) -> bool:
	for effect_id in active_persistent_effects:
		if effect_id.begins_with(character_name + "_"):
			return true
	return false

# 🆕 NOVO: Obter informações sobre efeitos persistentes ativos
func get_active_persistent_effects_info() -> Dictionary:
	var info = {}
	for effect_id in active_persistent_effects:
		var effect_data = active_persistent_effects[effect_id]
		info[effect_id] = {
			"target": effect_data.target.name if effect_data.target else "Unknown",
			"turns_remaining": effect_data.turns_remaining,
			"duration": effect_data.duration,
			"effect_type": effect_data.effect_type
		}
	return info

# 🆕 NOVO: Forçar remoção de efeitos de um personagem específico
func remove_persistent_effects_from_character(character_name: String):
	var effects_to_remove = []
	
	for effect_id in active_persistent_effects:
		if effect_id.begins_with(character_name + "_"):
			effects_to_remove.append(effect_id)
	
	for effect_id in effects_to_remove:
		remove_persistent_effect(effect_id)

func _get_buff_color(attribute: String) -> Color:
	match attribute:
		"strength", "attack": return Color.RED
		"constitution", "defense": return Color.ORANGE
		"agility", "speed": return Color.YELLOW
		"intelligence", "magic": return Color.CYAN
		"max_hp": return Color.GREEN
		"critical_chance": return Color.PURPLE
		_: return Color.WHITE

# 🆕 NOVO: Sobrescrever para limpar efeitos quando a ação for destruída
func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		clear_all_persistent_effects()
