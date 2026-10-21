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

## Lizenz

Noch nicht festgelegt. Das Original ist GPL; dieser Code ist eine Clean-Room-Neuimplementierung aus der Verhaltensbeschreibung. Assets (Kenney CC0) werden erst nach Auswahl übernommen.
