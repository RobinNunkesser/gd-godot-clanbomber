class_name SimConstants
extends RefCounted

const GRID_WIDTH := 17
const GRID_HEIGHT := 13
const CELL_SIZE := 40.0

# Der Kern rechnet in ganzzahligen Millisekunden, damit Läufe bitgenau reproduzierbar sind.
const BOMB_COUNTDOWN_MS := 2500
const BOMB_CHAIN_DELAY_MS := 100
const EXPLOSION_DURATION_MS := 500

const BASE_PLAYER_SPEED := 90 # px/s
const SKATEBOARD_SPEED_BONUS := 40 # px/s pro Skateboard
const MAX_SKATEBOARDS := 5

const START_BOMBS := 1
const MAX_BOMBS := 9
const START_POWER := 1
const MAX_POWER := 12

const DISEASE_DURATION_MS := 10000
const OVERDRIVE_SPEED_BONUS := 600 # px/s

const BOMB_SPEED := 160 # px/s für Kick und Wurf
const THROW_FIELDS := 4

const ICE_SPEED := 80 # px/s, zusätzliches Rutschen
const ARROW_CHILL_MS := 500
const TRAP_HOLD_MS := 1000
const TRAP_FLIGHT_SPEED := 200 # px/s
const TRAP_FUSE_MS := 10

# Sudden Death: Nach Ablauf der Rundenzeit fliegt der Observer von Feld zu Feld und lässt den Boden verschwinden.
const ROUND_TIME_MS := 90000
const OBSERVER_SPEED := 500 # px/s
const VANISH_MS := 1000
const FALL_MS := 1000
