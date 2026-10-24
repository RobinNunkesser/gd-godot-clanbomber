# ClanBomber: Original-Verhalten (extrahierte Spezifikation, v0.3)

> **Eingefroren (Stand 2026-10-21, v0.3).** Dieses Dokument beschreibt das *Ist-Verhalten des Originals* (Reverse-Engineering-Protokoll mit Evidenz-Tags und Quellbaum-Vergleich) und wird nicht mehr weiterentwickelt. Das **Soll** für die Godot-Edition steht ausschließlich im **[GDD](../../GDD.md)**. Änderungen am Spielverhalten gehören dorthin; hier werden nur noch Korrekturen am Original-Befund nachgetragen.

Quelle: Historischer C++-Quellcode von *ClanBomber* (SDL2-Port, GPL). Stand: Bomb, Explosion, Extra, Disease, MapTile*, Map-Parser, GameConfig, Observer (Runde), Controller_AI (Kern), GameObject-Bewegung, Bomber-Auszüge. Nicht gelesen: `Controller_AI_mass`, Menü/Netzwerk. Vergleich beider Quellbäume: siehe Abschnitt 10.
Status der Aussagen: **[V]** = im Code gelesen, **[?]** = vermutet / noch zu verifizieren.
Diese Spec beschreibt *Regeln*, nicht Code (Lizenzfrage siehe Abschnitt 8).

## 1. Raster und Einheiten
- Spielfeld 17 × 13 Zellen [V: `MapEntry.h`], Zellgröße im Original 40 px [V].
- Positionen im Original in Pixeln, Zellzuordnung per `(x+20)/40` (nächste Zelle) [V]. Bewegung ist **pixelweise frei**, nicht zellweise; Treffer werden auf der nächstgelegenen Zelle bestimmt.
- Zeit in Sekunden, Original frame-time-basiert (`Timer::time_elapsed`) [V].

## 2. Kartenformat (`*.map`)
Textdatei [V]: Zeile 1 Autor, Zeile 2 max. Spielerzahl, danach 13 Zeilen à 17 Zeichen.

| Zeichen | Bedeutung |
|---|---|
| `*` | Wall (unzerstörbar) |
| `+` | Box (zerstörbar, kann Extra freigeben) |
| ` ` | Ground (begehbar) |
| `R` | Zufall: 2/3 Box, 1/3 Ground [V] |
| `S` | Ice (siehe 4.3) |
| `< > ^ v` | Arrow-Feld: schiebt Bomben in Richtung |
| `o` | Trap (siehe 4.3) |
| `-` | in Karten vorhanden, im Parser nicht behandelt → `default` = Tile `NONE` [V]; Semantik prüfen |
| `0`–`7` | Startposition Spieler 0–7 (Ground) [V] |
| sonst | NONE |

33 Karten, 4–8 Spieler (je Quellbaum; die frühere Angabe 66 war die Summe beider Bäume). Außerhalb des Rasters liefert `get_maptile` ein blockierendes Dummy-Tile [V].

## 3. Spielobjekte
Bomber, Bomb, Explosion, Extra, Disease, MapTile (Ground, Box, Wall, Ice, Arrow, Trap, None), Bomber_Corpse, Corpse_Part (kosmetisch).
Z-Ordnung: Flying 9000 > CorpsePart 7000 > Observer 5000 > Bomber 4000 > Bomb 3000 > Explosion 2000 > Extra 1000 > Corpse 100 > Ground 0 [V].

## 4. Regeln

### 4.1 Bombe [V]
- Zünder: `bomb_countdown` (Default 25 → **2,5 s**; Wert/10).
- Bombe belegt Kapazität des Legers (`cur_bombs--`), nach Explosion `+1`.
- Explosion bei Countdown ≤ 0; Bombe snappt auf Zellmitte.
- Kettenreaktion: Von Explosion erfasste Bombe bekommt Countdown höchstens `bomb_delay` (Default 10 → **0,1 s**), zündet nicht sofort.
- Kick: Bombe rollt mit `bomb_speed` (Default 160 px/s = 4 Zellen/s) bis zum Hindernis (stop+snap).
- Throw (Glove): Bombe fliegt N Zellen; liegt dort schon eine Bombe, fliegt sie 1 Zelle weiter.
- Fällt eine Bombe in ein Loch, explodiert sie nicht.

### 4.2 Explosion [V]
- Kreuzform, Reichweite = `power` Zellen je Richtung.
- Ausbreitung stoppt **vor** blockierenden Tiles (Wall, Box) **und vor Zellen mit Extra**. Nur ein blockierendes Tile am Strahlende (Zelle `l+1`, falls `l < power`) wird zerstört (`destroy`); ein Extra dort ebenfalls.
- Dauer 0,5 s. Jeder Bomber in einer Strahlzelle stirbt (jedes Frame geprüft).
- Kill-Zähler nur bei Opfer ≠ Verursacher.
- Zerstört nicht fliegende Extras im Strahl, lässt Leichen zerplatzen.
- Strahllängen werden **bei Erzeugung** berechnet, nicht dynamisch.

### 4.3 Tiles
- **Box:** blockierend; `destroy` startet 0,5 s Zerstörungsanimation, dann entfernt; Extra-Drop (4.7).
- **Wall:** blockierend, unzerstörbar. **Ground:** frei.
- **Ice:** begehbar; schiebt jedes Objekt auf dem Feld mit Speed 80 weiter in seiner aktuellen Richtung (Rutschen) [V]. Ice verschwindet *nicht* von selbst.
- **Vanish (Sudden Death, siehe 4.8):** Tile wird nicht passierbar (`passable=false`), 1,0 s Fade-out, danach Loch: Objekte fallen, Bomber stirbt (`fallen_down`). Extras auf dem Tile fliegen auf ein anderes freies Feld [V]. Wall/Box/None haben eigene `vanish`-Varianten [V: vorhanden, Details **[?]**].
- **Arrow:** kickt Bombe in Pfeilrichtung; bei entgegengesetzt rollender Bombe 0,5 s Stopp („chill“), dann Umlenkung [V grob].
- **Trap:** Bombe wird aus dem Spiel genommen und 1,0 s gehalten, dann an ein zufälliges passierbares, nicht verschwindendes Feld geflogen (über Wände, Speed 200); Zünder wird dabei auf 0,01 s gesetzt → explodiert praktisch bei Landung [V]. Gibt es kein freies Feld, wird die Bombe gelöscht.
- **None:** Standard für unbekannte Zeichen; wird von der Sudden-Death-Zufallsauswahl ausgeschlossen [V]. Begehbarkeit **[?]**.

### 4.4 Bomber
Startwerte (Config): Bomben 1, Power 1, Skateboards 0, Kick aus, Glove aus. Maxima: Bomben 9, Power 12, Skateboards 5 [V].
- Speed 90 + 40 pro Skateboard [V].
- Bombe legen nur bei `cur_bombs > 0`, nicht fallend; Entprellung 177 ms [V].
- Tod: `die()` idempotent; `deaths++`; Extras (Bomb/Power/Skateboard/Kick/Glove) fliegen als Extras auf freie Felder; Leiche außer `kids_mode` [V].
- Teams, Farbe/Skin, max. 8 Spieler.

### 4.5 Extras [V]
Aufnahme durch Betreten; **jede Aufnahme entfernt zuvor aktive Disease** (`loose_disease`).
| Extra | Wirkung |
|---|---|
| Bomb | +1 Kapazität (max 9) |
| Power | +1 Reichweite (max 12) |
| Skateboard | +40 Speed (max 5) |
| Kick | Bomben kicken |
| Glove | Bomben werfen |
| Joint / Koks / Viagra | Disease Stoned / Fast / PutBomb |
Von Explosion getroffen: 0,5 s Verlöschen; nicht zerstörbare Extras fliegen weg.

### 4.6 Diseases [V]
| Disease | Dauer | Wirkung |
|---|---|---|
| Fast | 10 s | Speed +600 |
| Frozen | 3 s | Eingabe deaktiviert |
| PutBomb | 10 s | legt dauernd automatisch Bomben |
| Stoned | 10 s | Steuerung invertiert |
- Ansteckung bei Kontakt (`infect_others`); Ziel-Disease wird ersetzt.
- Bei Ende wird Zustand wiederhergestellt; beim Heilen durch Extra-Aufnahme spawnt das Disease-Extra wieder aus.
- **Frozen wird im Code nirgends erzeugt** (nur in der Factory `Disease::create`); es gibt kein Extra dafür [V]. Totcode im Original → in Godot optional (z. B. als Eis-Extra) oder streichen.

### 4.7 Extra-Drop aus Boxen [V]
`r = rand%8`: 0 Power, 1 Bomb, 2 Skateboard (je 1/8, falls aktiviert); 3: 50 % Kick / 50 % Glove (je 1/16, nur falls nicht Startausrüstung); 4: `rand%16` → 0 Joint, 1 Viagra, 2 Koks (je 1/128); 5–7 nichts. Gesamt ≈ 52 % Extra pro Box.

### 4.8 Runde / Match
- Rundenzeit Default 90 s (5–300), Siegpunkte 5, Kartenreihenfolge fest/zufällig, Startpositionen zufällig [V Config].
- **Rundenstart:** Bomber fliegen (Speed 200) von Bildschirmmitte auf ihre Startfelder; Controller werden erst aktiviert, wenn alle gelandet sind; der Timer startet erst dann [V].
- **Hurry-Up:** Warnung bei Restzeit 21–18 s (blinkender Text + Sound) [V].
- **Sudden Death (Observer):** Bei Restzeit < 0 fliegt der „Observer“ (Spielobjekt, Speed 500) wiederholt auf zufällige Felder (nicht NONE, nicht schon verschwindend) und lässt jeweils das Tile unter sich verschwinden (`vanish`, 4.3) – das Spielfeld löst sich fortlaufend auf. Erster Flug nur Ansage („time over“) [V].
- **Rundenende:** Sobald < 2 aktive Spieler übrig sind, wartet die Runde, bis keine Explosion mehr läuft, keine Extras fliegen und kein lebender Bomber fällt. Dann bekommen alle Überlebenden **+1 Punkt** (bei Gleichzeitigkeit mehrere), nächste Karte laden, Scoreboard zeigen, Spielende per `get_end_of_game` [V]. Kills und Deaths werden separat gezählt.

## 4.9 Bewegung und Kollision [V]
- Bewegung pixelweise: pro Frame `span = dt*speed` Einzelschritte (mit Restübertrag), je Schritt `move_left/right/up/down`.
- Blockiert, wenn das Zieltile `blocking` ist. Bomben auf dem Ziel blockieren, außer Bomber steht schon zu >50 % (`x%40 > 19`) auf dem Feld (kann die eigene gerade gelegte Bombe verlassen).
- **Corner-Sliding:** Wird seitlich versetzt gegen eine Kante gelaufen, schiebt der Schritt automatisch ±1 px in die Gasse (Korrektur an Wandecken). Entscheidend für das Spielgefühl.
- Bomber können sich gegenseitig blockieren (`can_pass_bomber` = false) außer beim Verlassen des eigenen Feldes.
- Kick: Läuft ein Bomber mit `can_kick` gegen eine ruhende Bombe, erhält diese Richtung (Kick) [V].
- Flug (`fly_to`): lineare Interpolation mit Wand-Kollision, außer `can_fly_over_walls` (Trap-Bomben, Extras) [V]. Fallen (`falling`) nach Vanish.

## 5. Controller
`Controller` mit `update`, `activate/deactivate`, `revert`, `bomb_always/bomb_normal` [V]. Implementierungen: Keyboard (3 Keymaps), Joystick, AI, AI_mass, RCMouse.
Godot: `InputMap`-Aktionen pro Spieler, Gamepad-Bindung; AI als eigener Controller.

### 5.1 AI (`Controller_AI`) [V, Kern]
- Architektur: **Rating-Map** (17×13 `int`) wird jeden Frame neu erzeugt; **Job-Queue** (`Job_Go`, Bomb-Jobs, …) setzt Richtung/Bombe um.
- Ratings: Extra `+30` (× Extra-Typ), Bombe „heiß“ `-100` (Feld wird getroffen), absolute Gefahr `-666` (Explosion, Loch, Bombe gleich vor Zündung), Blockierend `-1000`.
- Bombenrating: frisch gelegt (Countdown nahe Maximum) nur `-1`; kurz vor Zündung (Restzeit < 40/speed) `-666`. Ohne Kick gelten Bomben als blockierend.
- Rollende Bomben werden entlang ihrer Bahn bewertet (Stopp an Wand/gegenläufigem Pfeil).
- Priorität pro neuem Job: (1) Bomben ausweichen (`find_way` aus Hotspot), (2) Weg zu Extras innerhalb 10 Felder, (3) freie Extras per Bombe freisprengen (≤ 5), danach weitere Heuristiken (Gegner jagen, Boxen sprengen; Details **[?]**).
- `Controller_AI_mass` (Variante) ungelesen; laut TODO defekt.
Gut als Vorlage: Gefahrenkarte + Pfadsuche ist sauber und ist die Grundidee für die Godot-AI. Neu schreiben mit echter Explosionsvorhersage (Kettenreaktion, Power) und testbaren reinen Funktionen.

## 6. Config-Defaults [V]
`round_time 90 · max_bombs 9 · max_power 12 · max_skateboards 5 · start_bombs 1 · start_power 1 · bomb_countdown 25 · bomb_delay 10 · bomb_speed 160 · points_to_win 5 · random_positions true`

## 7. Design-Entscheidungen für Godot (Vorschlag)
| Thema | Empfehlung |
|---|---|
| Bewegung | **Entschieden (2026-10-21):** kontinuierliche Bewegung (Float) in Zellkoordinaten mit Corner-Sliding (4.9), Zellzuordnung per Rundung. Zellbasierte Bewegung ist verworfen, da sie Spielgefühl (Kicken, Ausweichen) verändert. |
| Simulation | Deterministischer Kern ohne Nodes + dünne Node-Schicht → testbar (GUT/GdUnit), AI-fähig |
| Daten | Extras/Diseases/Config als `Resource`s, Karten per Importer |
| Themes | Extras neutral benennen (z. B. Overdrive, Reverse, Autobomb); Drogen-/Sexual-Thematik nicht übernehmen |
| AI | Neu: Gefahrenkarte, BFS-Fluchtpfad |
| Netzwerk | Nicht im MVP |

## 8. Offene Fragen
1. (erledigt: kontinuierliche Bewegung mit Corner-Sliding, siehe 7). 2. Semantik `-` in Karten / Begehbarkeit von `NONE`. 3. Glove-Wurf: Auslöser, Weite (`fields`), Zielbehandlung. 4. AI: Rest der Heuristiken, `Controller_AI_mass`. 5. (erledigt, siehe Abschnitt 10). 6. Frozen: streichen oder neu einführen? 7. Netzwerkpfad (nicht analysiert). 8. Lizenz: Code GPL ⇒ Clean-Room aus dieser Spec; Asset-Rechte (Sprites/Sounds/Maps) prüfen.

## 9. Test-Szenarien
1. Power 2 in offener Zeile → Länge 2 je Richtung.
2. Strahl stoppt an Wand; Box am Strahlende zerstört, Box dahinter nicht.
3. Kettenreaktion ≈ 0,1 s Verzögerung.
4. Extra blockiert Strahl; Extra am Strahlende zerstört.
5. Bomber im Strahl stirbt; Selbstmord zählt nicht als Kill.
6. Bomben-Kapazität 1: zweite nicht legbar, nach Explosion wieder.
7. Disease-Ansteckung/Ablauf (Fast 10 s, Frozen 3 s).
8. Extra-Aufnahme heilt Disease und spawnt Disease-Extra.
9. Extra-Drop-Verteilung (seedbar).
10. Map-Importer lädt alle 33 Karten (17×13, Starts ≤ Spielerzahl).
11. Trap: Bombe verschwindet 1 s, landet auf freiem Feld, zündet sofort.
12. Sudden Death: Tile verschwindet, Bomber darauf fällt und stirbt, Extra weicht aus.
13. Rundenende: letzter Überlebender bekommt +1 Punkt, erst nachdem Explosionen/Flüge beendet sind.
14. Corner-Sliding: Bomber gleitet an Wandecke in die Gasse.
15. AI: flieht aus Gefahrenfeld; läuft nicht in Explosionsstrahl; holt Extra.

## 10. Vergleich `clanbomber` ↔ `ClanBomber2`
Methode: Dateilisten, `diff -w -B`, Config-Defaults, Regeldateien ohne Netzwerk-/Stilzeilen.

**Ergebnis: Spielregeln und Konstanten sind identisch.** `ClanBomber2` ist ein Port derselben Spielbasis, kein Regel-Fork.

| Aspekt | `clanbomber` (Original) | `ClanBomber2` (SDL2-Fork) |
|---|---|---|
| Umfang | 133 Dateien in `src/`, ca. 28,8k LOC | 123 Dateien, ca. 19,7k LOC |
| Netzwerk | Client/Server (`Server`, `Client`, `Chat`, `Event`, `Mutex`, `Thread` usw.) mit `is_server()/is_client()`-Weichen in Bomb, Explosion, Extra, Trap | komplett entfernt |
| Backend | ClanLib-/DirectFB-Ära (`cbe/`), Boost (`filesystem`) | SDL2 (`*SDL.cpp`), C++17 `std::filesystem`, ohne Boost |
| Neu im Fork | – | Musik (`bud.mod`), Fenster skalierbar, Software-Rendering/Render-Driver-Option, `fast_random()` statt `rand()` |
| Entfernt im Fork | Option `highlight_maptiles`, `last_server` | – |
| Maps | 33 `.map` | identische 33 `.map` (nur `Makefile.in` fehlt) – **Hinweis:** Zählung 66 oben enthielt beide Bäume, **unique sind 33 Karten** |
| Grafik/Sound | `pics/`, `wavs/` | identisch bis auf `cup2.png`, `observer.png` (geändert) und zusätzlich `bud.mod` |
| Config-Defaults | – | identisch (keine Differenz bei `Config::*`-Defaults) |
| Bewegung/Kollision | – | identisch (Kantengleiten, 20-px-Grenze, Kick) |
| Rundenende/Observer | enthält `repaint_hack` (Rendering-Workaround), Team-Logik | gleiche Logik ohne Repaint-Hack |

Konsequenzen:
1. **Referenz für die Spec = `ClanBomber2`** (kleiner, Netzwerk-frei, lauffähig). `clanbomber` nur noch für Netzwerkprotokoll-Fragen (nicht im MVP).
2. Korrektur zu früher: Es gibt **33 einzigartige Karten**, nicht 66 (die erste Zählung addierte beide Bäume).
3. Bei der Asset-Rechteprüfung genügt ein Satz: Assets sind in beiden Bäumen gleich; die Herkunft ist über `AUTHORS` (Original: Andreas Hundt, Denis Oliver Kropp, mass; SDL2-Port: Rene Lopez) zu klären, die Musikdatei `bud.mod` ist gesondert zu prüfen.
4. Die AI-Dateien (`Controller_AI*.cpp`) unterscheiden sich in ca. 700 Zeilen; in den Stichproben (Ratings, Job-Architektur) nur Stil/Portierung. Eine vollständige semantische Prüfung steht aus **[?]**.
