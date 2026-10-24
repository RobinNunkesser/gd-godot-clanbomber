# ClanBomber (Godot Edition) - Game Design Document (GDD)

Willkommen im Game Design Document für **ClanBomber: Godot Edition**.

Dieses GDD ist modular nach dem Standard des IGA-Curriculums aufgebaut, um optimale Übersicht für Entwickler und minimalen Token-Aufwand bei KI-Agenten-Workflows zu gewährleisten:

---

## Modulübersicht

1. **[01 - High Concept & Core Gameplay Loop](01_concept_and_loop.md)**
   - High Concept, 2.5D-Vision, 10-Sekunden-Core-Loop, Siegbedingungen (Best of 5) und Scoring.
2. **[02 - Input, Steuerung & Multiplayer](02_input_and_controls.md)**
   - Kontinuierliche Bewegung, Corner-Sliding, Bombenaktionen (Legen, Kicken, Werfen), bis zu 8 lokale Spieler, Godot 4 `InputMap`.
3. **[03 - Duale Architektur: 2D-Simulationskern vs. 2.5D-Präsentation](03_architecture_dual.md)**
   - Strikte Trennung von 100 % 2D-Logik (`core/`, RefCounted, headless testbar) und 2.5D-Visualisierung (`scene/`, Camera3D $70^\circ$ Tilt, dynamisches Licht, Trümmerphysik, Verdeckungsschutz).
4. **[04 - Match-Flow & State Machine](04_state_machine.md)**
   - Runden-Zustandsautomat: Intro-Flug $\to$ Playing ($90\,\text{s}$) $\to$ Hurry-Up $\to$ Sudden Death (Observer vernichtet Kacheln) $\to$ Round Over $\to$ Match Over.
5. **[05 - Tuning-Parameter, Tabellen & Konfiguration](05_parameters.md)**
   - Exakte Simulationskonstanten, Kacheltabelle (Ice, Arrow, Trap, Hole), Power-Ups, Handicaps, Kisten-Dropraten ($\approx 52\,\%$) und Spezifikation des 33-Karten-Textformats (`*.map`).

---

## Schnelleinstieg für KI-Agenten nach Phasen

- **Phase 1 (MVP - Scaffolding & Movement):** Lies `01_concept_and_loop.md` und `02_input_and_controls.md`.
- **Phase 2 (Physik, Extras & Sudden Death):** Lies `04_state_machine.md` und `05_parameters.md`.
- **Phase 3 (Karten-Import & 8-Spieler-Input):** Lies `02_input_and_controls.md` und `05_parameters.md`.
- **Phase 4 (2.5D Rendering, Licht & Polish):** Lies `03_architecture_dual.md`.
