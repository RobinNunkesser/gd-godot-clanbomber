# ClanBomber Godot

Moderne Godot-4-Neuauflage von *ClanBomber* (2.5D-Präsentation, 2D-Simulationskern). Referenzprojekt für agentische Spieleentwicklung.

Design-Quellen (im Workspace `work`): `agent-workbench/projects/clanbomber-godot/` mit `GDD.md` (normativ) und `docs/reference/ORIGINAL_BEHAVIOR.md` (Verhalten des Originals, Clean-Room-Referenz).

## Stand: Slice 1 (Simulationskern)

Reine `RefCounted`-Logik in `core/`, ohne Node-Abhängigkeit und mit ganzzahligen Millisekunden für bitgenaue Reproduzierbarkeit:

| Datei | Inhalt |
|---|---|
| `map_parser.gd`, `map_data.gd` | Importer für das Original-Kartenformat (17×13, `R`-Zufall seedbar, `-` = `NONE`) |
| `sim_board.gd`, `sim_tile.gd` | Raster und Kacheltypen |
| `sim_world.gd` | Bomben, Kettenreaktion (0,1 s), Strahlberechnung bei Zündung, Explosion 0,5 s, Tod/Kill-Zählung, Box-Drops |
| `sim_extra.gd` | Extra-Drop-Verteilung wie im Original |

Noch nicht enthalten: kontinuierliche Bewegung mit Corner-Sliding, Kick/Glove, Ice/Arrow/Trap-Verhalten, Sudden Death, Handicaps, AI, Präsentation.

## Tests

GdUnit4 (v6.2.2, unter `addons/` mitgeliefert), Godot 4.7:

```sh
GODOT_BIN=$(which godot) addons/gdUnit4/runtest.sh -a test
```

`map_parser_test.gd` lädt zusätzlich alle Originalkarten, wenn der Referenzbaum im Monorepo (`artifacts/references/forks/ClanBomber2/src/maps`) oder `CLANBOMBER_MAPS_DIR` verfügbar ist, sonst wird dieser Test übersprungen. Die Originalkarten sind bewusst nicht Teil dieses Repos (Lizenz-/Rechteklärung offen).

## Karten

`maps/` enthält 37 eigene Karten (MIT): einheitlich auf englische Titel im Title Case benannt (z. B. `Crossroads`, `Ice Rink`, `Box Depot`, `Chokepoint`, `Dead End`, `Twin Vortex`, `Chaos Grid`, `Spiral Maze`). Die Autorenangaben im Dateikopf lauten auf *Robin Nunkesser* (23 Karten), *anonymous hendrik* (13 Karten) und *cjl* (1 Karte) – alle vom Repo-Eigentümer erstellt.  Die 33 Originalkarten liegen im separaten GPL-Datenpaket [gd-godot-clanbomber-original-maps](https://github.com/RobinNunkesser/gd-godot-clanbomber-original-maps) und sind nicht Teil dieses Repos.

## Lizenz

Code und eigene Karten: MIT (`LICENSE`). Drittkomponenten und Abgrenzung zum Original: `THIRD_PARTY.md`. Original-Sounds und -Grafiken werden nicht übernommen (Herkunft ungeklärt), Sounds kommen aus CC0-Quellen (Kenney).
