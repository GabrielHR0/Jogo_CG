extends HBoxContainer
class_name CharacterView

var character: Character

func setup(c: Character, side: String = "ally"):
	character = c

	var sprite_rect := get_node_or_null("SpriteRect") as TextureRect
	assert(sprite_rect != null, "SpriteRect não encontrado em CharacterView.tscn")

	# Sprite corpo inteiro na área central
	if c.texture != null:
		sprite_rect.texture = c.texture
	else:
		# fallback: usa o icon se não tiver texture
		sprite_rect.texture = c.icon

	# Ajustes por lado (opcional)
	if side == "enemy":
		# exemplo: inverter horizontal via escala
		sprite_rect.scale = Vector2(-abs(sprite_rect.scale.x), sprite_rect.scale.y)
