extends Resource
class_name Party

@export var name: String = "Default Party"
@export var max_size: int = 4
@export var members: Array[Character] = []

func add_member(c: Character) -> bool:
	if members.size() >= max_size or c == null:
		return false
	members.append(c)
	return true

func remove_member(character: Character) -> bool:
	var index = members.find(character)
	if index != -1:
		members.remove_at(index)
		return true
	return false

func remove_member_by_name(n: String) -> bool:
	for i in members.size():
		if members[i].name == n:
			members.remove_at(i)
			return true
	return false

func swap(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a >= members.size() or b >= members.size() or a == b:
		return false
	var tmp = members[a]
	members[a] = members[b]
	members[b] = tmp
	return true

func front_line() -> Array[Character]:
	return members.filter(func(c): return c.position == "front")

func back_line() -> Array[Character]:
	return members.filter(func(c): return c.position == "back")

func by_role(role_id: int) -> Array[Character]:
	return members.filter(func(c): return c.role == role_id)

func alive() -> Array[Character]:
	return members.filter(func(c): return c.is_alive())

func is_full() -> bool:
	return members.size() >= max_size

func get_member(index: int) -> Character:
	if index >= 0 and index < members.size():
		return members[index]
	return null

func is_empty() -> bool:
	return members.is_empty()

func size() -> int:
	return members.size()

func get_member_names() -> Array[String]:
	var names: Array[String] = []
	for c in members:
		names.append(c.name)
	return names
