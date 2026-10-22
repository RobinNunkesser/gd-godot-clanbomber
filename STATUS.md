# Projektstatus und nächste Schritte

Stand: 2026-10-21. Dieses Dokument ist der Wiedereinstieg: Was ist fertig, was wurde entschieden, was kommt als Nächstes.

## Ziel

Moderne Godot-4-Neuauflage des nicht mehr gepflegten C++-Spiels *ClanBomber* als Referenzprojekt für agentische Spieleentwicklung. GDScript, Tests mit GdUnit4. Architektur: reiner Simulationskern (`core/`, ohne Nodes) plus austauschbare Präsentationsschicht (`presentation/`).

## Wo liegt was

| Was | Ort |
|---|---|
| Dieses Spiel | `artifacts/consumers/production/godot/gd-godot-clanbomber` (GitHub `RobinNunkesser/gd-godot-clanbomber`, privat, MIT) |
| Originalkarten (GPL) | Schwesterrepo `gd-godot-clanbomber-original-maps` |
| Design (normativ), Verhaltensreferenz, Asset-Bewertung | `agent-workbench/projects/clanbomber-godot/`: `GDD.md`, `docs/gdd/05_parameters.md`, `docs/reference/ORIGINAL_BEHAVIOR.md`, `docs/assets/ASSET_CANDIDATES.md` |
| Original-Quellcode (nur lesen) | `artifacts/references/forks/ClanBomber2/src/` und `.../clanbomber/` |
| Rohmaterial der Asset-Pakete (nicht versioniert) | `agent-workbench/projects/clanbomber-godot/assets-candidates/` und die ZIPs im Projektordner |

## Entwicklung

Toolchain: Godot 4.7.2, GdUnit4 v6.2.2 (in `addons/`).

```sh
GODOT_BIN=$(which godot) addons/gdUnit4/runtest.sh -a test       # Tests
godot --headless --editor --quit --path .                         # nach neuen class_name-Dateien / Assets (Import)
timeout 40 godot --headless --path . --quit-after 60 2>&1 | grep -i error   # Smoke-Test
godot --path . --write-movie /tmp/s.png --quit-after 40           # Screenshot -> /tmp/s0000NNNN.png
```

Hinweise:
- Die Meldung „Remote Debugger … 127.0.0.1:0“ ist harmlos.
- Neue GLBs: Textur zuerst kopieren, dann importieren. Sonst erscheinen sie weiß (dann `*.glb.import` löschen und neu importieren).
- Workflow-Regeln des Workspace: im Hauptrepo Dateien einzeln committen, im Spielrepo ist `git add -A` erlaubt. Danach den Submodul-Pointer im Hauptrepo einzeln nachziehen.

## Fertig

Simulationskern (129 Tests grün):

| Slice | Inhalt |
|---|---|
| 1 | Karten-Parser, Raster, Bomben, Kettenreaktion, Explosion, Tod/Kills, Box-Drops |
| 2 | Kontinuierliche Pixelbewegung mit Corner-Sliding |
| 3 | Extras und Krankheiten (Overdrive, Reverse, Autobomb, Ansteckung) |
| 4 | Kick und Glove (Wurf über 4 Zellen) |
| 5 | Ice, Arrow, Trap |
| 6 | Sudden Death (Observer, Löcher, Sturz), Testsuite `sim_sudden_death_test.gd`, 98 Tests grün |
| 7 | Rundenverwaltung (`SimMatch`: Punkte, Kills, Matchsieg bei 5 Punkten), Scoreboard-Overlay, Kartenwechsel nach jeder Runde, 111 Tests grün |
| 8 | Einfache AI (`SimAI`, im Menü je Platz wählbar), 122 Tests grün |
| 9 | Startmenü (`GameMenu`, `GameConfig`): 2-4 Spieler mit Tastatur 1/2, Gamepad 1-4 oder AI, Karte oder Zufall, Punkte zum Sieg; 129 Tests grün. Gamepad-Eingabe nicht mit echter Hardware getestet |

Präsentation:
- 2D-Platzhalteransicht (`presentation/arena_view.gd`) und 3D-Ansicht (`presentation/arena_view_3d.gd`), Umschalten mit F2. Standard ist 3D.
- Ton: `presentation/sfx.gd`, 12 Effekte, in `presentation/main.gd` mit den Spielereignissen verbunden.
- Grafik (Mischung aus zwei Kenney-Kits, CC0): Mini Dungeon für Wände (`wall`), Boden (`floor`), Boxen (`barrel`), Trap (`trap`) und Figuren 5/6 (`human`, `orc`); Platformer Kit für Bomben (`bomb`) und Figuren 1–4 (`oozi/oobi/oopi/oodi`). Zuordnung als Konstanten oben in `arena_view_3d.gd`. Extras, Flammen, Eis, Trap und Pfeile sind Primitive bzw. Beschriftungen.
- 37 Karten in `maps/` (alle Eigenkarten des Autors).

## Entscheidungen

- **Lizenz (Option 3, kein Rechtsrat):** Das Original ist GPL v2+. Dieses Repo ist MIT und enthält Neuimplementierung, eigene Karten und CC0-Assets. Originalkarten liegen im separaten GPL-Datenpaket. Keine Originalsounds oder -grafiken (Herkunft ungeklärt). Siehe `THIRD_PARTY.md`.
- **Assets:** Nur CC0 (Kenney). Das glTF-Paket (Quaternius?) bleibt wegen unbelegter Lizenz zurückgestellt.
- **Kern ist reine `RefCounted`-Logik** mit ganzzahligen Millisekunden und Pixeln (40 px je Zelle, Raster 17×13), damit er deterministisch und testbar ist.
- **Kenney `template-wall.glb` ungeeignet** als Vollblock (offene Rückseite, Schadensoptik); ersetzt durch `block-grass`.

## Bekannte Abweichungen und Vereinfachungen (vom Nutzer beim Spielen zu bewerten)

- Boxen halten geworfene Bomben an (im Original nur Wände).
- Ein Wurf direkt gegen eine Wand wird ignoriert.
- „Besetzte Landezelle“ bedeutet: andere Bombe.
- Autobomb wirft nie.
- Wegfliegende Extras erscheinen sofort.
- Das Trap-Ziel kann ein besetztes Feld sein.
- Die Pfeil-Logik ist nicht Frame für Frame gegen das Original verifiziert.

- Sudden Death: Bomben auf einem Loch verschwinden sofort (im Original fallen sie 1 s). Flugbomben werden nicht berücksichtigt. Die Rundenzeit läuft ab Start (im Original erst nach Aktivierung der Controller). Die Observer-Landung auf einer Mauer macht sie zu Boden, auf einer Box zerbricht sie.
- Rundenverwaltung: Rundenende und Punkte wie im Original (+1 je Überlebendem, bei Gleichstand keiner). Das Menü erlaubt eine feste Karte (bleibt über alle Runden) oder Zufallskarte je Runde sowie 1-10 Punkte zum Sieg. Karten ohne genug Startfelder für die aktiven Plätze werden übersprungen. Ausstehend: Zufallspositionen der Startfelder.
- Observer-Grafik und Sudden-Death-Sounds sind Platzhalter (vorhandene Effekte wiederverwendet).

## Offene Punkte der Präsentation

- Figuren sind in der 3D-Ansicht klein und schwer zu unterscheiden (Skalierung in `arena_view_3d.gd`, `model.scale`; Spielerring zeigt die Farbe). Ab Spieler 5 wiederholen sich die Modelle.
- Eis, Trap und Pfeile sind noch Platzhalter-Grafik (Extras und Flammen sind Modelle).
- Blocky Characters und das Dungeon-Kit-Template wurden aus dem Repo entfernt (Rohmaterial bleibt in `agent-workbench/projects/clanbomber-godot/assets-candidates/`).
- Extras sind Mini-Dungeon-Modelle (`weapon-sword` Power, `pot` Bomb, `coin` Skateboard, `weapon-spear` Kick, `shield-round` Glove, `potion` für die drei Krankheiten, farblich getönt) plus schwebender Buchstabe; Zuordnung in `EXTRA_MODELS` in `arena_view_3d.gd`. Ungenutzt: `key`, `chest`, `column`, `rocks`.
- Das Menü kennt 4 Plätze (Aus, Tastatur 1/2, Gamepad 1-4, AI); Standard ist Mensch gegen AI auf `crossroads.map`. Der Kern kann mehr Spieler.
- Keine Musik (in keinem der Pakete enthalten).
- Feedback zu Ton, Animationen, Kamera, Wackelstärke und Flammen beim Spielen steht noch aus. Das Gamepad wurde vom Nutzer als funktionierend bestätigt.

## Nächste Schritte (Vorschlag, in dieser Reihenfolge)

1. **Spielen und Feedback** zu Slice 4-7, Ton, 3D-Ansicht (Figurengröße, Kamera), Juice-Stärke.
2. ~~Sudden Death~~ (erledigt, Slice 6).
3. ~~Rundenverwaltung~~ (erledigt, Slice 7; der Kern kann beliebig viele Spieler, das Menü bietet 4 Plätze).
4. ~~AI~~ (einfache Heuristik erledigt, Slice 8). Grenzen: ignoriert Kick, Glove, Ice, Arrow, Trap; im Selbstspiel enden viele Runden passiv erst im Sudden Death. Verbesserung: aktiver auf den Gegner zulaufen, Schwierigkeitsgrade.
5. **Karten-UI:** Karten mit zu wenigen Startfeldern im Menü ausblenden (bisher nur übersprungen), Anzeigenamen getrennt vom Dateinamen.
6. ~~Menü~~ (erledigt, Slice 9: Spielerzahl, Karte/Zufall, Punkte, Gamepad). Gamepad bestätigt. Offen: Tastenbelegung ändern, mehr als 4 Spieler.
7. **Optik:** Juice-Stufe 1 erledigt (`effects_3d.gd`: Kamerawackeln, Partikel für Explosion/Kisten/Pickup/Tod/Bombe/Sudden-Death-Löcher, Lichtblitze, Bloom, Flammen wachsen ein, Bomben-Squash). Flammen sind jetzt Kegel-Modelle mit Kern und Funken. Offen: Figuren-Squash/Hit-Stop, Musik.
8. **Kids-Mode** (Cube Pets).

Vorgehen pro Schritt: erst Test schreiben, dann Kern ändern, danach Präsentation, dann README und diese Datei aktualisieren.

## Offene Fragen

- Bestätigung der MIT-Lizenz und ob die Repos öffentlich werden.
- Ob die Git-Historie des GPL-Kartenrepos bereinigt werden soll (die Eigenkarten sind dort in älterer Historie noch einsehbar).
- Lizenz der glTF-Figuren klären, bevor sie genutzt werden.
