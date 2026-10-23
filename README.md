# ClanBomber Godot

> **A clean-room reimplementation inspired by the classic 1998 open-source game *ClanBomber*.**

Moderne Godot-4-Neuauflage (2.5D-Präsentation, 2D-Simulationskern). Referenzprojekt für agentische Spieleentwicklung und offener Community-Remake.

Design-Quellen (im Workspace `work`): `agent-workbench/projects/clanbomber-godot/` mit `GDD.md` (normativ) und `docs/reference/ORIGINAL_BEHAVIOR.md` (Verhalten des Originals, Clean-Room-Referenz).

Aktueller Stand und nächste Schritte: [STATUS.md](STATUS.md). Details zu Lizenzen und Drittinhalten: [THIRD_PARTY.md](THIRD_PARTY.md).

## Stand: Slice 11 (8 Spieler, externe Karten, Intro & Hurry-Up)

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
| `map_catalog.gd`, `map_rotation.gd` | Kartenkatalog aus mehreren Ordnern (`load_dirs`, Quellpfade, erster Ordner gewinnt bei Namenskonflikten), Filter nach Startplätzen (`is_playable`, `playable`) und Kartenrotation (Shuffle-Bag oder der Reihe nach über die ausgewählten Karten) |
| `sim_match.gd` | Runden- und Teamverwaltung: Rundenende (höchstens eine überlebende Partei, keine laufenden Explosionen, fallenden Spieler oder fliegenden Bomben), Teampunkte, Siegesbedingung (Einzelspieler: Punkte zum Sieg; Team: `team_points >= team_size * points_to_win`), Ranking |
| `sim_observer.gd`, `sim_world.gd` (Sudden Death) | Einstellbare Rundenzeit (15–300 s, Standard 90 s): Observer fliegt zu zufälligen Feldern, Boden wird zu Löchern, Mauern zu Boden, Boxen zerbrechen |
| `sim_ai.gd` | Heuristik-AI: flieht aus Gefahrenzonen, legt Bomben nur mit Fluchtweg, sprengt Boxen, jagt Gegner (ignoriert Teamkameraden), sammelt Extras |
| `game_config.gd` | Matcheinstellungen mit Persistenz: 8 Plätze (Aus, Tastatur 1/2, Gamepad 1-8, AI), eigene Spielernamen, Teams (Blood, Gold, Water, Leaf), Kartenauswahl (Pool, Reihenfolge zufällig oder der Reihe nach), optionale Zufalls-Startpositionen, externer Kartenordner, Sudden Death Zeit, Punkte (1-10) und Audio-Lautstärken |
| `sim_extra.gd` | Extra-Drop-Verteilung wie im Original |

## Spiel starten & Steuerung

Starten: Projekt in Godot 4.7 öffnen und F5, oder `godot --path .`. Die Szene `scenes/main.tscn` startet direkt im Hauptmenü bzw. Spiel.

| Taste | Aktion |
|---|---|
| Menü: ↑↓ ←→, Enter / Leertaste / Gamepad A | Navigation, Werte anpassen, Submenüs ("Namen & Teams", "Karten wählen") öffnen |
| Menü: Esc / Gamepad B / Back | Zurück ins Hauptmenü / Spiel fortsetzen |
| Menü: Beenden | Spiel beenden (`get_tree().quit()`) |
| Esc / Gamepad Start | Spiel pausieren / Hauptmenü öffnen |
| Sieger-Bildschirm: ↑↓, Enter / A | "Neues Match" oder "Zurück zum Menü" wählen |
| Tastatur 1: WASD, Leertaste | bewegen, Bombe legen |
| Tastatur 2: Pfeiltasten, Enter | bewegen, Bombe legen |
| Gamepad: D-Pad oder linker Stick, A | bewegen, Bombe legen (Gerät 1-8 im Menü zuordnen) |
| R | Runde neu starten |
| M | Musik stummschalten / aktivieren (Mute) |
| F4 | Ton-Effekte stummschalten / aktivieren (Mute) |
| F5 | Neues Match (Punkte zurücksetzen) |
| F3 | Testhilfe: Sudden Death in 2 s starten |
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

Vor jeder Runde fliegen die Bomber zur Startposition (Steuerung gesperrt), bei 20 s Restzeit erscheint „HURRY UP!“ mit Signalton. Kranke Spieler tragen einen farbigen Rahmen mit dem Buchstaben. Musik und Effekte laufen über eigene Audio-Busse.

## Tests

GdUnit4 (v6.2.2, unter `addons/` mitgeliefert), Godot 4.7. Aktuell laufen 177 Tests (175 Kern, 2 Präsentation) grün; der GitHub-Actions-Workflow `.github/workflows/test.yml` führt sie bei Push und Pull Request aus:

```sh
GODOT_BIN=$(which godot) addons/gdUnit4/runtest.sh -a test
```

`map_parser_test.gd` lädt zusätzlich alle Originalkarten, wenn der Referenzbaum im Monorepo (`artifacts/references/forks/ClanBomber2/src/maps`) oder `CLANBOMBER_MAPS_DIR` verfügbar ist, sonst wird dieser Test übersprungen. Die Originalkarten sind bewusst nicht Teil dieses Repos (Lizenz-/Rechteklärung offen).

## Bekannte Lücken gegenüber dem GDD

- Die 177-ms-Sperre beim Bombenlegen ist nicht implementiert (durch Tasten-Events praktisch entschärft).
- Die 33 Originalkarten sind nicht gebündelt; sie werden bei Bedarf aus einem externen Ordner geladen.
- Freeze ist bewusst nicht implementiert (im Original Totcode); der Glove-Wurf stoppt an Wänden und Boxen.

## Karten

`maps/` enthält 37 eigene Karten (MIT): einheitlich auf englische Titel im Title Case benannt (z. B. `Crossroads`, `Ice Rink`, `Box Depot`, `Chokepoint`, `Dead End`, `Twin Vortex`, `Chaos Grid`, `Spiral Maze`). 

Zur Laufzeit werden zusätzlich `user://maps`, der im Menü unter **Externe Karten** eingetragene Ordner und die Umgebungsvariable `CLANBOMBER_MAPS_DIR` gelesen. Die 33 historischen Originalkarten von ClanBomber liegen im separaten GPL-Datenpaket [gd-godot-clanbomber-original-maps](https://github.com/RobinNunkesser/gd-godot-clanbomber-original-maps) und sind nicht Teil dieses Repos; bei Namenskonflikten gewinnt `res://maps`.

## Export & Testversionen

Das Projekt ist mit Export-Presets (`export_presets.cfg`) für **Windows Desktop**, **Linux**, **macOS** und **Web (HTML5)** konfiguriert:

- **Lokaler Export:**  
  Im Godot-Editor über `Projekt` $\to$ `Exportieren...` oder auf der Kommandozeile:
  ```bash
  godot --headless --export-release "Windows Desktop" builds/windows/ClanBomber.exe
  ```
- **Automatisierte Builds via GitHub Actions:**  
  Unter `.github/workflows/export.yml` ist ein Workflow eingerichtet:
  - **Manuell:** Kann im GitHub-Web-Interface unter *Actions* $\to$ *Export & Release* $\to$ *Run workflow* jederzeit per Klick ausgelöst werden. Die fertigen ZIP-Dateien (Windows, Linux, macOS, Web) stehen anschließend direkt als Run-Artifacts zum Download bereit.
  - **Automatisch bei Release:** Wird ein Git-Tag (z. B. `v0.1.0`) gepusht, erzeugt die Action automatisch ein GitHub Release mit allen Plattform-ZIPs als Download-Anhänge.
- **Tests:** `.github/workflows/test.yml` installiert Godot 4.7.2 und führt bei jedem Push und Pull Request `addons/gdUnit4/runtest.sh -a test` aus.

## Credits & Third-Party Assets

Ein großes Dankeschön an die Open-Gaming- und Open-Source-Community:

- **3D-Assets & Audio von Kenney ([kenney.nl](https://kenney.nl)):**
  - 3D-Modelle aus dem *Platformer Kit* und *Mini-Dungeon* (Figuren, Blöcke, Fässer, Bomben, Fallen).
  - Soundeffekte aus den Kenney-Audio-Paketen (*Impact*, *Digital*, *Sci-Fi*, *Interface*).
  - Alle Kenney-Assets sind unter **CC0 1.0 Universal** (Public Domain Dedication) lizenziert.
- **Retro-Hintergrundmusik (BGM):**
  - Chiptune-Tracks *"Title Screen"* und *"Level 1"* aus der Sammlung *"5 Chiptunes (Action)"* von **Juhani Junkala (SubspaceAudio)** via OpenGameArt (**CC0 1.0 Universal**).
- **Unit-Testing Framework:**
  - [GdUnit4](https://github.com/MikeSchulze/gdUnit4) von Mike Schulze (lizenziert unter der MIT-Lizenz).
- **Historische Inspiration:**
  - Inspiriert durch das klassische Open-Source-Multiplayerspiel *ClanBomber* (1998–2002 von Denis Oliver Kropp, Andreas Hundt und Mitwirkenden).

## Disclaimer & Rechtliche Hinweise

- **Eigenständigkeit:** Dieses Spiel ist eine eigenständige Clean-Room-Neuimplementierung *from scratch* in Godot Engine 4. Es verwendet keinerlei Quellcode, Binärdateien oder urheberrechtlich geschützte Assets des historischen C++-Spiels *ClanBomber* oder der *ClanLib*-Bibliothek.
- **Markenhinweis:** *Bomberman* ist eine eingetragene Marke von Konami Digital Entertainment Co., Ltd. Dieses Projekt ist ein nicht-kommerzielles Bildungs- und Community-Projekt und steht in keiner geschäftlichen oder offiziellen Verbindung zu Konami Digital Entertainment, Hudson Soft oder den ursprünglichen Autoren von *ClanBomber*.

## Lizenz

Code, eigene Karten und neu erstellte PBR-Texturen: **MIT-Lizenz** ([LICENSE](LICENSE)).  
Ausführliche Lizenz- und Drittkomponenten-Nachweise: [THIRD_PARTY.md](THIRD_PARTY.md).
