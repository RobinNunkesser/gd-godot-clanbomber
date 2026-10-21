class_name SimExtra
extends RefCounted

enum Type { NONE = -1, POWER, BOMB, SKATEBOARD, KICK, GLOVE, OVERDRIVE, REVERSE, AUTOBOMB }

const ALL_TYPES := 8


# Würfelt den Drop einer zerstörten Box wie im Original (ORIGINAL_BEHAVIOR 4.7):
# ein deaktivierter Typ löst einen kompletten Neuwurf aus, "nichts" beendet den Wurf.
static func roll(rng: RandomNumberGenerator, disabled: Array = []) -> int:
	if disabled.size() >= ALL_TYPES:
		return Type.NONE
	while true:
		var result := _roll_once(rng)
		if result == Type.NONE or result not in disabled:
			return result
	return Type.NONE


static func _roll_once(rng: RandomNumberGenerator) -> int:
	match rng.randi() % 8:
		0:
			return Type.POWER
		1:
			return Type.BOMB
		2:
			return Type.SKATEBOARD
		3:
			return Type.KICK if rng.randi() % 2 == 0 else Type.GLOVE
		4:
			match rng.randi() % 16:
				0:
					return Type.REVERSE
				1:
					return Type.AUTOBOMB
				2:
					return Type.OVERDRIVE
	return Type.NONE
