# 05 - Tuning-Parameter, Tabellen & Konfiguration

## 1. Spielfeld- & Simulations-Konstanten

| Parameter | Standardwert | Beschreibung |
|---|:---:|---|
| `GRID_WIDTH` | 17 | Spalten im Spielfeld |
| `GRID_HEIGHT` | 13 | Zeilen im Spielfeld |
| `CELL_SIZE` | 40.0 px | Logische Kachelbreite und -höhe |
| `BASE_PLAYER_SPEED` | 90.0 px/s | Grundgeschwindigkeit des Bombers |
| `SKATEBOARD_SPEED_BONUS` | +40.0 px/s | Geschwindigkeitsgewinn pro Skateboard (max. 5 $\implies 290\,\text{px/s}$) |
| `KICK_BOMB_SPEED` | 160.0 px/s | Rollgeschwindigkeit gekickter Bomben (4 Zellen/s) |
| `FLY_SPEED_INTRO` | 200.0 px/s | Fluggeschwindigkeit der Figuren beim Rundenstart |
| `OBSERVER_SPEED` | 500.0 px/s | Fluggeschwindigkeit des Sudden-Death-Observers |
| `BOMB_COUNTDOWN` | 2.5 s | Zünderdauer einer frisch gelegten Bombe |
| `BOMB_CHAIN_DELAY` | 0.1 s | Maximale Zündverzögerung bei Kettenreaktion |
| `EXPLOSION_DURATION` | 0.5 s | Aktive Schadens- und Anzeigedauer eines Explosionsstrahls |
| `ROUND_TIME_DEFAULT` | 90.0 s | Reguläre Rundenzeit vor dem Sudden Death |
| `POINTS_TO_WIN` | 5 | Benötigte Rundensiege für den Matchgewinn |

---

## 2. Kacheln (Map Tiles)

| Kachel | Symbol | Blockierend | Zerstörbar | Spezifisches Verhalten |
|---|:---:|:---:|:---:|---|
| **Ground** | ` ` | Nein | Nein | Frei begehbar; nimmt Bomben und Extras auf. |
| **Wall** | `*` | **Ja** | Nein | Unzerstörbar. Stoppt Spieler, Bomben und Explosionsstrahlen. |
| **Box** | `+` | **Ja** | **Ja** | Durch Explosionen zerstörbar (0,5 s Animation). Droppt mit $\approx 52\,\%$ Chance ein Extra. |
| **Random** | `R` | Variiert | Variiert | Kartengenerator ersetzt dies zu $2/3$ durch Boxen und zu $1/3$ durch Ground. |
| **Ice** | `S` | Nein | Nein | Begehbar. Reibungsfrei: Schiebt jedes Objekt mit $80\,\text{px/s}$ in seiner aktuellen Richtung weiter (Rutschen). |
| **Arrow** | `< > ^ v`| Nein | Nein | Kickt rollende oder landende Bomben in Pfeilrichtung. Bei Gegenverkehr (`(dir_bomb + dir_arrow) % 2 == 0`): Bombe rastet zentriert ein, pausiert $0{,}5\,\text{s}$ ("Chill-Countdown"), wird dann in Pfeilrichtung beschleunigt. |
| **Trap** | `o` | Nein | Nein | Katapultiert eine Bombe für 1,0 s aus dem Spiel und wirft sie auf ein freies Feld mit $0{,}01\,\text{s}$ Instant-Zünder! |
| **None** | `-` | **Ja** | Nein | Unbespielbarer Bereich außerhalb der Arena (so im Original, z. B. `Arena.map`); vom Sudden Death ausgenommen. |
| **Hole (Vanish)**| – (nur zur Laufzeit) | **Ja** | Nein | Durch Sudden Death entstandenes Bodenloch. Jeder hineintretende Spieler stürzt ab und stirbt (`fallen_down`). |

---

## 3. Extras & Power-Ups

| Extra | Name | Startwert | Maximum | Effekt |
|---|---|:---:|:---:|---|
| 💣 | **Bomb** | 1 | 9 | Erhöht die maximale Anzahl gleichzeitig legbarer Bomben um $+1$. |
| 🔥 | **Power** | 1 | 12 | Erhöht die Explosionsreichweite in alle 4 Richtungen um $+1$ Kachel. |
| 🛹 | **Skateboard** | 0 | 5 | Erhöht die Laufgeschwindigkeit um $+40\,\text{px/s}$ (bis $290\,\text{px/s}$). |
| 👟 | **Kick** | Aus | 1 | Erlaubt das Treten ruhender Bomben durch Anlaufen. |
| 🧤 | **Glove** | Aus | 1 | Erlaubt das Aufheben und Werfen von Bomben; Wände und Boxen stoppen den Flug. |

*Hinweis:* Jede Aufnahme eines regulären Extras heilt sofort alle aktiven Handicaps!

---

## 4. Handicaps (Bereinigte Nomenklatur)

| Interner Code | Neuer Name | Dauer | Effekt & Spielgefühl |
|---|---|:---:|---|
| *Fast* | **Overdrive** | 10 s | Extreme Geschwindigkeit ($+600\,\text{px/s}$), kaum beherrschbar. |
| *Stoned* | **Reverse** | 10 s | Steuerungsachsen (oben/unten, links/rechts) sind komplett vertauscht. |
| *PutBomb* | **Autobomb** | 10 s | Legt permanent automatisch Bomben, sobald Kapazität verfügbar ist. |

*Freeze* wird bewusst nicht übernommen: Im Original ist es reiner Totcode und wird nie erzeugt.

- **Ansteckung:** Läuft ein infizierter Spieler gegen einen Mitspieler, überträgt sich das Handicap sofort (`infect_others`).

---

## 5. Extra-Drop-Verteilung aus Kisten

Beim Zerstören einer Kiste wird deterministisch gewürfelt (`rand % 8`):

```text
r = rand() % 8
├── 0: Power (12,5 %)
├── 1: Bomb (12,5 %)
├── 2: Skateboard (12,5 %)
├── 3: 50 % Kick / 50 % Glove (je 6,25 %; nur falls nicht Startausrüstung, sonst Neuwurf)
├── 4: zweiter Wurf rand % 16: 0 Reverse, 1 Autobomb, 2 Overdrive (je 1/128 = 0,78 %), 3–15 nichts
└── 5 bis 7: Kein Extra / Leer (37,5 %)
```
$\implies$ **Gesamte Extra-Droprate pro Kiste: ca. $52\,\%$.**

---

## 6. Karten-Format (`*.map`)

Jede der 33 Original-Karten ist eine lesbare Plain-Text-Datei mit 15 Zeilen:
- **Zeile 1:** Autorenname (z. B. `Andreas Hundt`)
- **Zeile 2:** Maximale Spielerzahl (z. B. `8`)
- **Zeilen 3 bis 15:** Genau 13 Zeilen mit jeweils 17 Zeichen (`*`, `+`, ` `, `R`, `S`, `<`, `>`, `^`, `v`, `o`, `0`–`7`).

```text
Beispiel (Klassische Standard-Arena):
Andreas Hundt
8
*****************
*0 +   + +   + 1*
* * * * * * * * *
*+   + + + +   +*
* * * * * * * * *
* +   + + +   + *
* * * * * * * * *
* +   + + +   + *
* * * * * * * * *
*+   + + + +   +*
* * * * * * * * *
*2 +   + +   + 3*
*****************
```
- Ziffern `0` bis `7` markieren feste Startpositionen auf begehbarem Boden.

---

## 7. KI-Bewertungsmatrix & Heuristik (`Controller_AI`)

Für autonome Bots nutzt ClanBomber eine deterministische Heatmap-Bewertung (`Controller_AI.h`):

### 7.1 Statische Feld-Ratings (Sicherheit & Wegfindung)
| Konstante | Wert | Bedeutung |
|---|:---:|---|
| `RATING_EXTRA` | `+30` | Begehrtes Feld (enthält unberührtes Power-Up). |
| `RATING_HOT` | `-100` | Gefahrenzone (eine Bombe wird dieses Feld erreichen). |
| `RATING_X` | `-666` | Tödliche Zone (aktive Explosion oder Loch). Sofort meiden! |
| `RATING_BLOCKING`| `-1000` | Unpassierbar (feste Wand oder Hindernis). |

### 7.2 Dynamische Taktik-Ratings (`DRATING_*` für Bombenplatzierung)
Entscheidet, ob ein Bot an seiner aktuellen Position eine Bombe legen sollte:
| Konstante | Score | Taktische Auswirkung |
|---|:---:|---|
| `DRATING_ENEMY` | `+150` | Belohnt das Treffen eines feindlichen Bombers. |
| `DRATING_BOX` | `+20` | Belohnt das Sprengen erreichbarer Kisten. |
| `DRATING_DISEASE` | `+10` | Zusätzlicher Bonus gegen bereits geschwächte Gegner. |
| `DRATING_DBOX` | `-50` | Strafe, wenn die Explosion eigene Kisten-Deckung zerstört. |
| `DRATING_EXTRA` | `-90` | Strenge Strafe, wenn liegende Extras vaporisiert würden. |
| `DRATING_BOMB` | `-100` | Strafe bei unkontrollierbaren Kettenreaktionen. |
| `DRATING_FRIEND` | `-200` | Höchste Strafe im Team-Modus bei Gefährdung eines Verbündeten. |
