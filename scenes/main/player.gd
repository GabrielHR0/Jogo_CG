# Este script deve ser anexado a um nó CharacterBody2D.
extends CharacterBody2D

# Exporta as variáveis para que você possa editá-las no Inspetor do Godot.
# Isso é ótimo para ajustar a sensação do jogo sem mexer no código.
@export var normal_speed: float = 150.0
@export var sprint_speed: float = 300.0

# Esta função é chamada a cada quadro de física (60 vezedss por segundo por padrão).
# É o local ideal para código de movimento e física.
func _physics_process(delta):
	
	# 1. Obter a direção da entrada (input)
	# Input.get_vector() usa as ações que configuramos no Input Map.
	# Ele combina "move_left", "move_right", "move_up", "move_down"
	# em um vetor de direção normalizado (comprimento máximo de 1).
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# 2. Verificar se a tecla "sprint" está pressionada
	var current_speed = normal_speed
	if Input.is_action_pressed("sprint"):
		current_speed = sprint_speed

	# 3. Calcular a velocidade final
	# Multiplicamos a direção (um vetor como (0, 1) ou (1, 0))
	# pela velocidade atual (um número como 150 ou 300).
	velocity = input_direction * current_speed

	# 4. Mover o personagem
	# move_and_slide() é a função mágica do CharacterBody2D.
	# Ela move o personagem com base na 'velocity' e para
	# automaticamente se colidir com paredes ou outros corpos.
	move_and_slide()
