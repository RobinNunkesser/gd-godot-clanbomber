# 02 - Input, Steuerung & Multiplayer

## 1. Bewegungsmodell & Corner-Sliding

### 1.1 Kontinuierliche Bewegung im Gitter
- **Koordinatensystem:** Das logische Spielfeld misst $17 \times 13$ Zellen à $40 \times 40$ logischen Pixeln.
- **Freie Float-Bewegung:** Spielfiguren bewegen sich kontinuierlich im 2D-Raum (keine schrittweise Kachel-Bindung).
- **Zellzuordnung:** Erfolgt deterministisch über Rundung zur Zellmitte:
  $$\text{cell}_X = \lfloor (x + 20) / 40 \rfloor, \quad \text{cell}_Y = \lfloor (y + 20) / 40 \rfloor$$

### 1.2 Corner-Sliding (Exakter 1-Pixel-Rasterschritt)
Das Geheimnis des flüssigen Game Feels in ClanBomber liegt im deterministischen 1-Pixel-Sub-Stepping (`GameObject.cpp:117-260`):

1. **Sub-Step-Akkumulator pro Frame ($\Delta t$):**
   ```gdscript
   var step_dist: float = delta * speed + remainder
   var span: int = int(step_dist)
   remainder = step_dist - span
   for i in range(span):
       if not step_1px(move_dir):
           break
   ```

2. **Corner-Sliding-Logik am Beispiel `move_right()`:**
   - Berechne Zielkachel des vorderen Ankerpunkts: $T = \text{map}[(x + 40) / 40, (y + 20) / 40]$.
   - Wenn $T$ blockiert ist $\implies$ Bewegung stoppt (`return false`).
   - Wenn $T$ frei ist (oder eigene Bombe / $x \bmod 40 > 19$):
     - Inkrementiere $x \leftarrow x + 1$.
     - **Automatische Kantenkorrektur ($Y$-Achse):**
       - Falls $y \bmod 40 > 19$: Prüfe diagonale Kachel oben-rechts $\text{map}[(x+40)/40, (y-20)/40]$. Ist diese blockiert $\implies$ weiche nach unten aus ($y \leftarrow y + 1$).
       - Falls $0 < y \bmod 40 \le 19$: Prüfe diagonale Kachel unten-rechts $\text{map}[(x+40)/40, (y+60)/40]$. Ist diese blockiert $\implies$ weiche nach oben aus ($y \leftarrow y - 1$).
   - *(Analoge symmetrische Prüfung für `move_left`, `move_up` und `move_down`).*

### 1.3 Verlassen frisch gelegter Bomben
- Eine neu gelegte Bombe wird auf der aktuellen Zellmitte verankert.
- Der Leger wird **nicht blockiert**, solange er sich zu $\ge 50\,\%$ auf dem Quellfeld befindet (`x % 40 > 19` bzw. `y % 40 > 19`). Er kann die Bombe ungehindert verlassen, darf danach aber nicht mehr hindurchlaufen.

---

## 2. Aktionen & Mechaniken

### 2.1 Bombe legen (`Action: Bomb`)
- **Voraussetzung:** Aktuelle Bombenzahl $<$ maximale Bombenkapazität (`cur_bombs < max_bombs`).
- **Verankerung:** Platziert eine Bombe auf der Zellmitte der aktuellen Spielerkoordinate.
- **Entprellung:** $177\,\text{ms}$ Mindestintervall zwischen zwei Bombenlegungen, um versehentliches Doppellegen zu verhindern.

### 2.2 Bomben kicken (`Passive: Kick`)
- Besitzt der Spieler das Kick-Extra und läuft frontal gegen eine ruhende Bombe, wird diese in Laufrichtung mit **$160\,\text{px/s}$** ($4$ Zellen/s) in Bewegung gesetzt.
- Die Bombe rollt, bis sie auf ein Hindernis (Wand, Box, andere Bombe) trifft, und rastet dort zentriert ein.

### 2.3 Bomben werfen (`Glove-Mechanik`)
- **Trigger:** Drückt der Spieler `Action: Bomb`, während er **unbewegt** (`!moved`) direkt auf einer Bombe steht und das Glove-Extra besitzt, wird die Bombe aufgenommen und geworfen (`Bomber.cpp:283`).
- **Flugdistanz:** Exakt **4 Zellen** (`fields = 4`).
- **Wand-Kollision:** Fliegende Bomben fliegen **nicht** über Wände hinweg (`can_fly_over_walls = false`). Eine Wand stoppt den Flug vorzeitig, und die Bombe landet auf der letzten begehbaren Kachel vor der Wand.
- **Modernes Steuerungslayout:** Zusätzlich zur Ein-Tasten-Methode (Bombe drücken im Stillstand) kann optional eine dedizierte Taste (`Action: Special / Glove`) belegt werden.

---

## 3. Multiplayer-Architektur (Local-First bis 8 Spieler)

### 3.1 Input-Geräte
Das Spiel unterstützt **bis zu 8 lokale Spieler** an einem Rechner:
1. **Gamepads (1 bis 8 Controller):**
   - Xbox, PlayStation, Switch Pro oder generische USB-Controller.
   - Automatische Zuweisung über Godots `joy_connection_changed(device_id)`.
2. **Tastatur-Splits (für 2 Spieler ohne Controller):**
   - **Spieler 1:** `WASD` (Bewegung), `Leertaste` (Bombe), `E` (Werfen / Glove)
   - **Spieler 2:** `Pfeiltasten` (Bewegung), `Rechte Strg / Enter` (Bombe), `Rechtes Shift` (Glove)

### 3.2 Godot 4 InputMap-Namenskonvention
Für jeden Spieler $N \in \{1, \dots, 8\}$ werden standardisierte Aktionen in den `ProjectSettings` definiert:
- `p{N}_up`, `p{N}_down`, `p{N}_left`, `p{N}_right`
- `p{N}_bomb` (Primär-Aktion)
- `p{N}_special` (Sekundär-Aktion / Glove)

```typescript
// Abfragebeispiel im Controller-Skript
var move_dir = Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down")
if Input.is_action_just_pressed("p1_bomb"):
    try_place_bomb()
```
