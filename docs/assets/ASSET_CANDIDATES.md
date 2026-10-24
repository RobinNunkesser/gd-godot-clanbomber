# Asset-Kandidaten: Eignungsbewertung (v0.1)

Stand: 2026-10-21 (inkl. Audio). Bezug: [GDD](../../GDD.md) (2.5D, 17×13-Raster, 8 Spieler, Kamera ca. 70°, Godot 4 Forward+).
Rohmaterial liegt lokal unter `assets-candidates/` (per `.gitignore` nicht versioniert; Zips in `assets-candidates/_zips/`). Ins Repo kommen später nur ausgewählte, geprüfte Dateien (mit Lizenzvermerk) unter einem eigenen Asset-Verzeichnis des Godot-Projekts.

Status der Aussagen: **[V]** = lokal geprüft (Dateien, Metadaten, Preview-Bilder), **[?]** = noch zu verifizieren (insbesondere im Godot-Import und Spielkontext).
Bewertungsskala: ++ sehr gut, + gut, o neutral, − schwach.

## 1. Überblick

| Paket | Inhalt | Lizenz | Formate | Rolle im Spiel |
|---|---|---|---|---|
| `kenney_blocky-characters_20` | 18 Blockfiguren (a–r) | CC0 [V: `License.txt`] | GLB, FBX, OBJ | **Spielerfiguren (Primär)** |
| `kenney_cube-pets_1.0` | 24 Würfeltiere | CC0 [V] | GLB, FBX, OBJ | Alternativ-Skin / Kids-Theme / Maskottchen |
| `kenney_modular-dungeon-kit_1.0` | 39 modulare Bauteile (Stein, Orange-Violett) | CC0 [V] | GLB, FBX, OBJ | Arena-Theme „Dungeon“ |
| `kenney_modular-cave-kit_1.0` | 40 Teile (Höhle) | CC0 [V] | GLB, FBX, OBJ | Arena-Theme „Cave“ |
| `kenney_modular-space-kit_1.0` | 40 Teile (Sci-Fi, inkl. Gate-Laser, Kabel) | CC0 [V] | GLB, FBX, OBJ | Arena-Theme „Space“ |
| `glTF-20261021T144943Z-1-001` | 52 animierte Figuren (Worker, Pirate, Ninja, Zombie, Viking, …) | **nicht belegt** (keine Lizenzdatei) | glTF (Buffer eingebettet), ca. 99 MB | Alternative Figurenfamilie |

Die drei Kits entsprechen dem Original-Konzept „Theme“ (`Config::theme`): ein Theme je Kit ist ein natürlicher Zuschnitt.

## 2. Spielerfiguren

### 2.1 Vergleich

| Kriterium | Kenney Blocky Characters | Kenney Cube Pets | glTF-Paket (Figuren) |
|---|---|---|---|
| Anzahl | 18 | 24 | 52 (inkl. Varianten/Hüte) |
| Skelett-/Animationsart | Node-Animation, 27 Clips [V] | Node-Animation, 8 Clips [V] | Skinning (1 Skin), 16–17 Clips [V] |
| Relevante Clips | `idle`, `walk`, `sprint`, `die`, `pick-up`, `holding-both` (Bombe tragen), `attack-kick-right/left` (Kick), `emote-yes` (Sieg), `emote-no` (Niederlage), `interact-*` | `idle`, `walk`, `run`, `gesture-positive/negative`, `dance`, `eat` | `Idle`, `Walk`, `Run`, `Run_Carry`/`Walk_Carry`, `Death`, `Victory`, `Defeat`, `PickUp`, `Punch`, `Roll`, `RecieveHit` |
| Fehlende Clips | – (alles abgedeckt) | **`die`**, Kick, Tragen | Kick |
| Polygone/Figur | sehr niedrig [V: ca. 70–600 Dreiecke] | niedrig (ca. 700) | mittel bis hoch (ca. 2.100–9.500) |
| Stil | Blockig, einheitlich, Kenney-Look | Würfel-Chibi, sehr niedlich | Low-Poly-Realistisch, mehr Detail |
| Stilpassung zu Kenney-Kits | ++ | + | − (anderer Stil, Mix-Risiko) |
| Unterscheidbarkeit bei 8 Spielern | + (18 Figuren, aber Hautton/Outfit-Farben teils ähnlich) [?] | ++ (viele Farben/Silhouetten) | + (viele Silhouetten) |
| Lizenzsicherheit | ++ (CC0 belegt) | ++ | − (offen) |

### 2.2 Bewertung
- **Primär: Kenney Blocky Characters.** Deckt alle spielrelevanten Aktionen ab: Laufen, Sterben, Kick, Bombe tragen (Glove), Sieg/Niederlage. Sehr niedrige Polygonzahl, passt zum Stil der Kits, CC0 belegt. Offen **[?]**: Zuordnung eindeutiger Spielerfarben (per Material-Tint/Outline oder Spielernummer-Markierung unter den Füßen).
- **Sekundär: Cube Pets.** Passt zu „Kids-Mode“/Party-Look und zum 8-Spieler-Betrieb (klare Silhouetten). Es fehlt `die`: Tod per Code-Animation (Scale/Tween/Partikel). Als alternatives Skin-Set vorgesehen.
- **Zurückgestellt: glTF-Paket.** Animationssatz (Death, Victory, Defeat, Run_Carry) passt inhaltlich sehr gut, aber: (a) **Lizenz nicht belegt**. Die Clip- und Dateinamen sprechen für ein Quaternius-Paket (dort üblicherweise CC0). Eine Websuche bestätigte nur allgemein, dass Quaternius-Pakete CC0 sind, nicht für diese konkrete Datei; (b) Stilbruch zu den Kenney-Kits; (c) ca. 99 MB wegen eingebetteter Buffer (Texturen/Meshes je Datei ca. 2 MB). Vor jeder Nutzung: Quelle und Lizenzseite des Original-Downloads dokumentieren.

## 3. Arena (Level-Kits)

### 3.1 Maßstab und Raster [V]
- Kenney-Kit-Einheit: `template-floor` = 4 × 4 Einheiten (flach), `template-wall` = 4 × 4,15 × 2 (dünne Wand), `template-wall-half` = 2 breit.
- Passung zum Raster: 1 Spielzelle = 1 Kit-Floor-Kachel (4 Einheiten) → Arena 68 × 52 Einheiten. Im Godot-Import per Skalierung (z. B. 0,25) auf 1 Zelle = 1 Einheit normieren, damit die Simulation (Zellkoordinaten) und die Präsentation sauber getrennt bleiben.
- Figuren: Blocky ca. 8 × 9 × 8 Einheiten → entspricht ca. 2 Zellen und muss auf ca. 0,8 Zelle skaliert werden (≈ Faktor 0,1). Cube Pets: ca. 1,25 × 1,7 → Faktor ca. 0,6–0,8 bei 1 Zelle = 1 Einheit. Trefferfläche (Hitbox) unabhängig von Modellgröße im Simulationskern definieren (Corner-Sliding).

### 3.2 Abdeckung der Tile-Typen aus dem GDD

| GDD-Element | Dungeon | Cave | Space | Bewertung |
|---|---|---|---|---|
| Ground | `template-floor`, `template-floor-detail` | analog | analog | ++ |
| Wall (unzerstörbar) | `template-wall` ist dünn (2 tief); als Vollblock nur durch Kombination/Stapeln von `template-wall`, `template-wall-top`, `template-detail` | analog | analog | o: Blockform fehlt, Zusammenbau oder Eigenbau nötig |
| Box (zerstörbar) | – | – | – | **Lücke**: keine Kiste/Fass in den Kits |
| Ice | – (nur Textur-/Materialvariante) | – | – | Lücke: Eigenbau (Material auf Floor) |
| Arrow | – | – | – | Lücke: Decal/Textur auf Floor |
| Trap | `gate`-/Metallgitter-Teile als Anmutung [?] | `gate-metal-bars` | `gate-lasers` (passt thematisch) | o |
| Vanish/Loch (Sudden Death) | `template-floor-layer-hole` [V: vorhanden] | analog | analog | + (Loch-Variante vorhanden, Abbruch-Animation per Code) |
| Rand/Staging (außerhalb Arena) | Wände, Räume, Gänge, Treppen | analog | analog | ++ (Kulisse) |

Fazit: Die Kits liefern **Boden, Kulisse und Randbebauung**, aber **nicht die spielentscheidenden Blöcke** (Box, Wall-Block, Pfeil, Eis). Diese müssen aus Godot-Primitiven (`CSGBox3D`/`MeshInstance3D` mit Kenney-Materialfarben) oder aus weiteren Paketen kommen.

### 3.3 Technische Hinweise
- Alle Teile nutzen eine gemeinsame Textur-Palette (1 Bild je Paket) → wenige Draw-Calls, gut für 2.5D und 8 Spieler.
- Raumteile (`room-*`, `corridor-*`) sind für Kulissen gedacht, nicht für das 17×13-Raster. Für die Arena nur Floor/Wall/Detail-Kacheln verwenden.

## 3a. Audio-Kandidaten (Kenney, alle CC0 [V: `License.txt`], Format OGG)

| Paket | Dateien | Inhalt | Eignung |
|---|---|---|---|
| `kenney_impact-sounds` | 130 | Footsteps (5 Böden), Impact Wood/Metal/Plate/Glass/Soft/Punch/Plank/Mining/Tin/Bell, je 5 Varianten | ++ Kick, Box-Zerstörung (`impactWood`, `impactPlank`), Block-Treffer, Schritte (`footstep_*` je nach Theme) |
| `kenney_sci-fi-sounds` | 73 | `explosionCrunch`, `lowFrequency_explosion`, Laser, `forceField`, Türen, Engines, `slime` | ++ **Explosion** (`explosionCrunch`, `lowFrequency_explosion`), Space-Theme, Trap (`forceField`/`laser*`) |
| `kenney_digital-audio` | 63 | `powerUp1–12`, `phaserUp/Down`, `zap*`, `laser*`, `pepSound*`, `lowDown`, `threeTone*` | ++ Extra-Pickup (`powerUp*`), Handicap/Disease (`lowDown`, `zap*`), Retro-Charakter |
| `kenney_interface-sounds` | 100 | `click`, `confirmation`, `error`, `back`, `open/close`, `select`, `maximize/minimize` | ++ Menü, Lobby, Bereit-Bestätigung |
| `kenney_voiceover-pack` | 95 (Male/Female, je 46+) | Zahlen 1–10, `ready`, `set`, `go`, `hurry_up`, `time_over`, `round`, `final_round`, `its_a_tie`, `you_win`, `you_lose`, `game_over`, `congratulations`, `power_up` u. a. | + Rundenansage, Countdown, Sudden-Death-Warnung (`hurry_up`), Rundenende. Die `war_*`-Dateien nicht verwenden (Tonfall passt nicht). Nur Englisch [V], Lokalisierung für Deutsch offen |
| `kenney_casino-audio` | 55 | Karten, Chips, Würfel | − nicht passend; höchstens Siegpunkt-/Wertungsbildschirm (`chip-*`). Nicht übernehmen |

Abdeckung der Spielereignisse (Vorschlag, Zuordnung **[?]** bis zum Hörtest):

| Ereignis | Kandidat |
|---|---|
| Bombe legen | `impactSoft_medium`, `impactWood_light` |
| Zündschnur (loop) | `computerNoise` (Paket Sci-Fi), Prüfung nötig; sonst Eigenbau |
| Explosion | `explosionCrunch_*`, `lowFrequency_explosion_*` |
| Kick | `impactPunch_medium`, `impactWood_heavy` |
| Box zerstört | `impactWood_*`, `impactPlank_medium` |
| Extra aufgenommen | `powerUp*` |
| Handicap erhalten | `lowDown`, `zapThreeToneDown` |
| Tod | `impactPunch_heavy` + `lowDown` (kein dediziertes Todes-Sample) |
| Sudden Death | `hurry_up` (Voice), `forceField_*` |
| Rundenstart/-ende | `ready`, `set`, `go`, `you_win`, `its_a_tie` |
| Menü | `click`, `confirmation`, `back`, `error` |

Lücken: Musik (keines der Pakete), Schrittsounds müssen zu den Theme-Böden passen, dedizierte Tod-/Lunten-Samples fehlen. Die Original-Sounds von ClanBomber werden nicht übernommen (Rechte ungeklärt, GPL deckt Assets nicht automatisch ab **[?]**).

## 4. Lücken und Vorschläge

Nicht durch die Kandidaten abgedeckt:
1. **Box/Kiste, Wall-Block, Eis, Pfeil** → Eigenbau mit Primitiven oder ergänzende CC0-Pakete (z. B. weitere Kenney-Kits wie Platformer/Prototype/Furniture, Verfügbarkeit und Passung **[?]**, noch nicht geprüft).
2. **Bombe** inkl. Lunte → Eigenbau oder externes Paket.
3. **Explosion/Feuer/Funken, Rauch** → Godot-Partikel (GPUParticles3D), kein Asset nötig.
4. **Extras/Handicaps (Icons)** → 2D-Icons oder einfache 3D-Pickups.
5. **Audio:** SFX sind über Abschnitt 3a weitgehend abgedeckt; **Musik fehlt**.
6. **UI/Fonts:** nicht abgedeckt.

## 5. Empfehlung

| Bereich | Wahl | Begründung |
|---|---|---|
| Spielerfiguren | **Kenney Blocky Characters** | Vollständiger Clip-Satz, CC0, Stil passt, sehr leicht |
| Alternativ-Skin | **Cube Pets** (Kids-Theme) | Hohe Unterscheidbarkeit, passt zum Original-Kids-Mode |
| Arena-Theme 1 | **Dungeon Kit** | Warme Bodenfarbe (orange) hebt Figuren gut ab; thematisch neutral |
| Arena-Themes 2/3 | **Cave**, **Space** | Als wählbare Themes (Original hatte Theme-Option); Space mit Gate-Lasern als Trap |
| glTF-Figuren | **Nicht verwenden**, bis Lizenz belegt | Stilbruch + Lizenzlücke; ggf. später als Mod-/Bonus-Skin |

## 6. Nächste Schritte (Verifikation)
1. Import-Test in Godot 4: GLB laden, Animationen abspielen, Skalierung/Pivot prüfen (Füße am Boden, Blickrichtung).
2. Kamera-Test bei ca. 70° mit 8 Figuren: Lesbarkeit von Spielerfarben, Bomben und Explosionsstrahl auf dem Dungeon-Floor.
3. Spielerfarb-Konzept festlegen (Tint-Shader, Bodenring oder Namensmarker).
4. Blockbau-Prototyp: Wall-Block und Box aus Primitiven mit Kit-Palette; Optik gegen Kit-Boden bewerten.
5. Quelle und Lizenz des glTF-Pakets klären (Herkunftsseite, Lizenztext sichern) oder Paket entfernen.
6. Auswahl der tatsächlich benötigten Dateien in ein Asset-Verzeichnis des Projekts kopieren und `CREDITS`/Lizenzvermerk anlegen (CC0 verlangt keine Nennung, Kenney bittet freiwillig darum).
