class_name SimExplosion
extends RefCounted

var owner_id := 0
var origin := Vector2i.ZERO
# Alle betroffenen Zellen inklusive Ursprung; wird bei Erzeugung fest berechnet.
var cells: Array[Vector2i] = []
var remaining_ms := SimConstants.EXPLOSION_DURATION_MS
