class_name SimTile
extends RefCounted

enum Type { GROUND, WALL, BOX, ICE, ARROW_LEFT, ARROW_RIGHT, ARROW_UP, ARROW_DOWN, TRAP, HOLE, NONE }


static func is_blocking(type: int) -> bool:
	return type == Type.WALL or type == Type.BOX or type == Type.HOLE or type == Type.NONE


static func is_destructible(type: int) -> bool:
	return type == Type.BOX
