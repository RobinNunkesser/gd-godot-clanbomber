class_name SimBomb
extends RefCounted

var id := 0
var owner_id := 0
var cell := Vector2i.ZERO
var power := 1
var timer_ms := SimConstants.BOMB_COUNTDOWN_MS
