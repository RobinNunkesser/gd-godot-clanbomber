class_name SimTile
extends RefCounted

enum Type { GROUND, WALL, BOX, ICE, ARROW_LEFT, ARROW_RIGHT, ARROW_UP, ARROW_DOWN, TRAP, HOLE, NONE }


static func is_blocking(type: int) -> bool:
	return type == Type.WALL or type == Type.BOX or type == Type.HOLE or type == Type.NONE


static func is_destructible(type: int) -> bool:
	return type == Type.BOX


static func arrow_direction(type: int) -> Vector2i:
	match type:
		Type.ARROW_LEFT:
			return Vector2i.LEFT
		Type.ARROW_RIGHT:
			return Vector2i.RIGHT
		Type.ARROW_UP:
			return Vector2i.UP
		Type.ARROW_DOWN:
			return Vector2i.DOWN
	return Vector2i.ZERO
