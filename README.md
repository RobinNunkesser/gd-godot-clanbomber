# ClanBomber Godot

Moderne Godot-4-Neuauflage von *ClanBomber* (2.5D-Präsentation, 2D-Simulationskern). Referenzprojekt für agentische Spieleentwicklung.

Design-Quellen (im Workspace `work`): `agent-workbench/projects/clanbomber-godot/` mit `GDD.md` (normativ) und `docs/reference/ORIGINAL_BEHAVIOR.md` (Verhalten des Originals, Clean-Room-Referenz).

Aktueller Stand und nächste Schritte: [STATUS.md](STATUS.md).

## Stand: Slice 5 (Ice, Arrow, Trap)

Reine `RefCounted`-Logik in `core/`, ohne Node-Abhängigkeit und mit ganzzahligen Millisekunden für bitgenaue Reproduzierbarkeit:

| Datei | Inhalt |
|---|---|
| `map_parser.gd`, `map_data.gd` | Importer für das Original-Kartenformat (17×13, `R`-Zufall seedbar, `-` = `NONE`) |
| `sim_board.gd`, `sim_tile.gd` | Raster und Kacheltypen |
| `sim_world.gd` | Bomben, Kettenreaktion (0,1 s), Strahlberechnung bei Zündung, Explosion 0,5 s, Tod/Kill-Zählung, Box-Drops |
| `sim_movement.gd`, `sim_player.gd` | Pixelbewegung (90 px/s + 40 je Skateboard), Blockaderegeln für Bomben und Spieler, Corner-Sliding |
| `sim_world.gd` (Extras) | Aufnahme per Betreten, Obergrenzen, Heilen durch jede Aufnahme (Krankheits-Extra taucht neu auf), Overdrive/Reverse/Autobomb (10 s), Ansteckung, Extras fallen beim Tod |
| `sim_bomb.gd`, `sim_movement.gd` | Kick (Bombe rollt mit 160 px/s bis zum Hindernis und schnappt ein), Wurf mit Glove (4 Zellen, Zünder steht während des Flugs, Wände und Boxen halten an, auf besetzter Landezelle eine Zelle weiter) |
| `sim_world.gd` (Kacheln) | Ice: Figuren rutschen mit 80 px/s in Blickrichtung weiter, gerollte Bomben werden schneller. Arrow: schiebt Bomben in Pfeilrichtung, entgegenkommende Bomben werden 0,5 s gehalten und umgelenkt. Trap: hält Bomben 1 s, dann Flug (200 px/s, über Wände) auf ein zufälliges freies Feld, dort Zünder 10 ms |
| `sim_extra.gd` | Extra-Drop-Verteilung wie im Original |

Noch nicht enthalten: Sudden Death, AI, Rundenverwaltung, Musik.

## Spielbarer Prototyp (2D-Platzhalter)

Starten: Projekt in Godot 4.7 öffnen und F5, oder `godot --path .`. Die Szene `scenes/main.tscn` lädt eine Karte aus `maps/` und zeichnet den Zustand des Simulationskerns (`presentation/`).

| Taste | Aktion |
|---|---|
| WASD, Leertaste | Spieler 1 bewegen, Bombe legen |
| Pfeiltasten, Enter | Spieler 2 bewegen, Bombe legen |
| N / P / R | nächste / vorherige Karte / Neustart |
| F2 | Ansicht umschalten: 3D (Kenney-Modelle, Standard) / 2D (Platzhalter) |
| F1 | Testhilfe: alle 8 Extras neben Spieler 1 ablegen |

Kick: gegen eine Bombe laufen. Glove: stillstehend auf der eigenen Bombe die Bomben-Taste drücken, geworfen wird in Blickrichtung.

Extras werden durch Betreten aufgenommen. Kennbuchstaben: Kreis = Extra, Quadrat = Krankheit.

| Buchstabe | Extra | | Buchstabe | Krankheit |
|---|---|---|---|---|
| P | Power | | O | Overdrive |
| B | Bomb | | R | Reverse |
| S | Skateboard | | A | Autobomb |
| K | Kick | | | |
| G | Glove | | | |

Unter der Arena steht je Spieler `B` Bomben, `P` Power, `S` Skateboards, `K`/`G` falls vorhanden und die aktive Krankheit mit Restsekunden. Kranke Spieler tragen einen farbigen Rahmen mit dem Buchstaben. Kein Ton.

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
