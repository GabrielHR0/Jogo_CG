extends Node
class_name PartyManager

@export var active_party: Party
@export var reserve: Array[Character] = [] # banco de personagens disponíveis

func _ready():
	# Se não tiver party atribuída no editor, cria uma padrão
	if active_party == null:
		active_party = load("res://data/party/default_party.tres")
		# _load_default_party()

func _load_default_party():
	var hero := load("res://data/characters/hero.tres")
	var mage := load("res://data/characters/mage.tres")
	var archer := load("res://data/characters/archer.tres")
	if hero: active_party.add_member(hero)
	if mage: active_party.add_member(mage)
	if archer: active_party.add_member(archer)

func get_party() -> Party:
	return active_party

func members() -> Array[Character]:
	return active_party.members

func add_member(c: Character) -> bool:
	return active_party.add_member(c)

func remove_member_by_name(n: String) -> bool:
	return active_party.remove_member_by_name(n)

func swap_slots(a: int, b: int) -> void:
	active_party.swap(a, b)

func set_position(index: int, pos: String) -> void:
	if index >= 0 and index < active_party.members.size():
		active_party.members[index].position = pos

func members_by_role(role_id: int) -> Array[Character]:
	return active_party.by_role(role_id)

func front_line() -> Array[Character]:
	return active_party.front_line()

func back_line() -> Array[Character]:
	return active_party.back_line()

func alive() -> Array[Character]:
	return active_party.alive()
