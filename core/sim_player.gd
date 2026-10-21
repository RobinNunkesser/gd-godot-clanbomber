class_name SimPlayer
extends RefCounted

var id := 0
var cell := Vector2i.ZERO
var alive := true
var max_bombs := SimConstants.START_BOMBS
var active_bombs := 0
var power := SimConstants.START_POWER
var kills := 0


func can_place_bomb() -> bool:
	return alive and active_bombs < max_bombs
