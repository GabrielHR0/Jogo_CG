# BattleEffect.gd
extends Node2D
class_name BattleEffect

signal effect_finished

@export var lifetime: float = 1.0
@export var auto_play: bool = true

func _ready():
	if auto_play:
		play()

func play():
	# Para ser sobrescrito pelas classes filhas
	pass

func _on_animation_finished():
	effect_finished.emit()
	queue_free()
