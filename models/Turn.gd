class_name Turn

var character: Character
var action: Action
var target: Character

func _init(character: Character, action: Action, target: Character):
	self.character = character
	self.action = action
	self.target = target

func execute() -> void:
	if character.is_alive():
		print("🎲 Turno de " + character.name)
		action.execute(character, target)
	else:
		print("💀 " + character.name + " está morto, pulando turno")
