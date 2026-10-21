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

Simulationskern (87 Tests, Stand letzter Lauf mit Slice 5; seither nur Präsentation geändert):

| Slice | Inhalt |
|---|---|
| 1 | Karten-Parser, Raster, Bomben, Kettenreaktion, Explosion, Tod/Kills, Box-Drops |
| 2 | Kontinuierliche Pixelbewegung mit Corner-Sliding |
| 3 | Extras und Krankheiten (Overdrive, Reverse, Autobomb, Ansteckung) |
| 4 | Kick und Glove (Wurf über 4 Zellen) |
| 5 | Ice, Arrow, Trap |

Präsentation:
- 2D-Platzhalteransicht (`presentation/arena_view.gd`) und 3D-Ansicht (`presentation/arena_view_3d.gd`), Umschalten mit F2. Standard ist 3D.
- Ton: `presentation/sfx.gd`, 12 Effekte, in `presentation/main.gd` mit den Spielereignissen verbunden.
- Grafik: Kenney Platformer Kit (Wände `block-grass`, Boxen `crate`, Bomben `bomb`, Figuren `oozi/oobi/oopi/oodi`), Boden aus dem Modular Dungeon Kit. Extras, Flammen, Eis, Trap und Pfeile sind Primitive bzw. Beschriftungen.
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

## Offene Punkte der Präsentation

- Figuren sind in der 3D-Ansicht klein und schwer zu unterscheiden (Skalierung in `arena_view_3d.gd`, `model.scale`; Spielerring zeigt die Farbe). Ab Spieler 5 wiederholen sich die Modelle.
- Extras, Flammen, Eis, Trap, Pfeile sind noch Platzhalter-Primitive.
- Die Blocky Characters unter `assets/models/characters/` sind ungenutzt (entfernen oder für den Kids-Mode behalten).
- Es gibt nur 2 Spieler und `crossroads.map` als Startkarte (N/P wechselt).
- Keine Musik (in keinem der Pakete enthalten).
- Ton und Animationen sind noch nicht im Spiel beurteilt worden.

## Nächste Schritte (Vorschlag, in dieser Reihenfolge)

1. **Spielen und Feedback** zu Slice 4 und 5, Ton, 3D-Ansicht (Figurengröße, Kamera).
2. **Sudden Death** (Wert-Referenzen in `docs/reference/ORIGINAL_BEHAVIOR.md` prüfen), mit Tests im Kern.
3. **Rundenverwaltung:** Punkte, Scoreboard, mehrere Runden, Spielerzahl bis 8.
4. **AI** (Controller_AI des Originals als Referenz), zuerst einfache Heuristik: Gefahrenfelder meiden, Boxen sprengen, Extras holen.
5. **Karten-UI:** Karten mit zu wenigen Startfeldern ausblenden, Anzeigenamen getrennt vom Dateinamen.
6. **Menü und Eingabe:** Gamepad, Tastenbelegung, Spielerzahl.
7. **Optik:** eigene Modelle oder Kenney-Varianten für Extras und Flammen, Partikel, Musik.
8. **Kids-Mode** (Cube Pets).

Vorgehen pro Schritt: erst Test schreiben, dann Kern ändern, danach Präsentation, dann README und diese Datei aktualisieren.

## Offene Fragen

- Bestätigung der MIT-Lizenz und ob die Repos öffentlich werden.
- Ob die Git-Historie des GPL-Kartenrepos bereinigt werden soll (die Eigenkarten sind dort in älterer Historie noch einsehbar).
- Lizenz der glTF-Figuren klären, bevor sie genutzt werden.
