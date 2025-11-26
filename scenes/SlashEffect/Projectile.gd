# Projectile.gd
extends Node2D
class_name Projectile

signal arrived
signal hit

@export var speed: float = 300.0
@export var arc_height: float = 50.0

var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false
var start_position: Vector2 = Vector2.ZERO
var travel_time: float = 0.0

func launch(target: Vector2):
	target_position = target
	start_position = global_position
	is_moving = true
	
	# Calcula o tempo de viagem baseado na distância
	var distance = start_position.distance_to(target_position)
	travel_time = distance / speed

func _process(delta):
	if not is_moving:
		return
	
	# Move em direção ao alvo com um arco
	var elapsed = get_process_delta_time()
	var progress = min(elapsed / travel_time, 1.0)
	
	if progress >= 1.0:
		# Chegou no destino
		is_moving = false
		arrived.emit()
		return
	
	# Movimento com arco parabólico
	var current_x = lerp(start_position.x, target_position.x, progress)
	var current_y = lerp(start_position.y, target_position.y, progress)
	
	# Adiciona altura no arco
	var arc = sin(progress * PI) * arc_height
	current_y -= arc
	
	global_position = Vector2(current_x, current_y)

func explode():
	# Efeito de explosão quando chega no alvo
	hit.emit()
	queue_free()
