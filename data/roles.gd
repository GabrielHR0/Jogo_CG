extends Resource
class_name Roles

enum Role { TANK, DPS, HEALER, SUPPORT }

static func role_name(r: int) -> String:
	match r:
		Role.TANK: return "Tank"
		Role.DPS: return "DPS"
		Role.HEALER: return "Healer"
		Role.SUPPORT: return "Support"
		_: return "Unknown"
