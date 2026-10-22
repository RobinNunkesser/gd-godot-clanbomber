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

Simulationskern & Spielsysteme (165 Tests grün):

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
| 9 | Startmenü (`GameMenu`, `GameConfig`): 2-4 Spieler mit Tastatur 1/2, Gamepad 1-4 oder AI, Karte oder Zufall, Punkte zum Sieg; 129 Tests grün |
| 10 | Match-System & Menü-Erweiterungen (165 Tests grün):<br>- **Kartenfilter:** Nur Karten im Menü anbieten/durchschalten, die genügend Startplätze für aktive Spieler haben (`MapCatalog`).<br>- **Turnier / Kartenauswahl:** Submenü mit Checkboxen für Karten-Pool, Shuffle-Bag-Rotation ohne direkte Wiederholungen (`MapRotation`).<br>- **Team-Modus:** 4 Teams (Blood, Gold, Water, Leaf), Team-Farbringe, Teampunkte-Durchschnitt und Siegesbedingung `team_points >= team_size * points_to_win` wie im Original.<br>- **Spielernamen:** Submenü zur Vergabe eigener Spielernamen (max. 12 Zeichen), Anzeige in HUD, Bannern und Siegerbildschirm.<br>- **Konfigurierbare Sudden Death Zeit:** Im Menü einstellbar von 15 s bis 300 s (Standard 90 s).<br>- **Match-Sieger-Bildschirm:** Feierlicher Sieger-Banner bei Match-Ende mit Auswahl "Neues Match" oder "Zurück zum Menü".<br>- **Spiel beenden:** Menüpunkt "Beenden" (`get_tree().quit()`). |

Präsentation:
- 3D-Ansicht (`presentation/arena_view_3d.gd`) mit Kenney-Modellen, 3D-Partikeln und Skybox. (Der frühere 2D-Platzhaltermodus wurde entfernt.)
- Grafik (Mischung aus zwei Kenney-Kits, CC0 und PBR-Texturen): Mini Dungeon für Wände (`wall`), Boxen (`barrel`) und Figuren 5/6 (`human`, `orc`); Platformer Kit für Bomben (`bomb`) und Figuren 1–4 (`oozi/oobi/oopi/oodi`). PBR-Texturen für Boden (`tile_floor`), Eis (`tile_ice`), animierte Förderband-Pfeile (`tile_arrow`) und pulsierende Fallenfelder (`tile_trap`).
- 37 Karten in `maps/` (alle Eigenkarten des Autors).

## Entscheidungen

- **Lizenz (final: MIT):** Vollständige Clean-Room-Neuimplementierung (from scratch), eigene Karten, neu erstellte PBR-Texturen und CC0-Assets (Kenney). Kein übernommener C++-Code, daher keine GPL-Bindung. Historische Originalkarten liegen im separaten GPL-Datenpaket. Siehe `THIRD_PARTY.md`.
- **Assets:** Nur CC0 (Kenney) und eigene/generierte PBR-Texturen. Keine Übernahme ungeklärter historischer ClanBomber-Originalgrafiken.
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
- Das Menü kennt 4 Plätze (Aus, Tastatur 1/2, Gamepad 1-4, AI); Standard ist Mensch gegen AI auf `Crossroads.map`. Der Kern kann mehr Spieler.
- Steuerung & Hilfe sowie "Spiel beenden" sind direkt ins Startmenü integriert.
- Retro-Chiptune-Hintergrundmusik (`assets/audio/music/`, CC0) für Menü und Gameplay integriert, Mute-Taste `M`.
- Feedback zu Ton, Animationen, Kamera, Wackelstärke und Flammen beim Spielen steht noch aus. Das Gamepad wurde vom Nutzer als funktionierend bestätigt.

## Nächste Schritte (Vorschlag, in dieser Reihenfolge)

1. **Spielen und Feedback** zu Slice 4-10, Ton, 3D-Ansicht (Figurengröße, Kamera), Juice-Stärke.
2. ~~Sudden Death~~ (erledigt, Slice 6; konfigurierbare Zeit in Slice 10).
3. ~~Rundenverwaltung~~ (erledigt, Slice 7 & 10: Punkte, Teams, Sieger-Bildschirm).
4. ~~AI~~ (einfache Heuristik erledigt, Slice 8; beachtet Teambildung). Grenzen: ignoriert Kick, Glove, Ice, Arrow, Trap; im Selbstspiel enden manche Runden passiv erst im Sudden Death.
5. ~~Karten-UI & Turnier~~ (erledigt, Slice 10: Filter nach Spielerzahl, Kartenauswahl-Pool mit Rotation).
6. ~~Menü & Match-System~~ (erledigt, Slice 9 & 10: Spielerzahl, Spielernamen, Teams, Sudden Death Zeit, Beenden, Sieger-Screen).
7. **Optik & Audio:** Juice-Stufe 1 erledigt (`effects_3d.gd`), CC0-BGM integriert, PBR-Boden/Eis/Pfeil/Fallen-Texturen aktiv.
8. **Kids-Mode** (Cube Pets).

Vorgehen pro Schritt: erst Test schreiben, dann Kern ändern, danach Präsentation, dann README und diese Datei aktualisieren.

## Offene Fragen

- Bestätigung der MIT-Lizenz und ob die Repos öffentlich werden.
- Ob die Git-Historie des GPL-Kartenrepos bereinigt werden soll (die Eigenkarten sind dort in älterer Historie noch einsehbar).
- Lizenz der glTF-Figuren klären, bevor sie genutzt werden.
