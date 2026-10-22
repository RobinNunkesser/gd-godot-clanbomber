# Third-Party-Hinweise & Lizenzstatus

Dieses Repository (Code, eigene Karten und neu erstellte Assets) steht final unter der **MIT-Lizenz** (`LICENSE`).

| Komponente | Lizenz | Hinweis |
|---|---|---|
| **Eigener GDScript-Code** (`core/`, `presentation/`, `scenes/`) | MIT (`LICENSE`) | 100 % Clean-Room-Neuimplementierung from scratch; kein Code aus dem Original übernommen |
| **Eigene Texturen** (`assets/textures/`) | MIT | Neu erstellte PBR-Assets (Münz-Tokens, nahtloses Eis, Schiefer-Steinboden, Himmels-Skybox) |
| **GdUnit4 v6.2.2** (`addons/gdUnit4/`) | MIT (`addons/gdUnit4/LICENSE`) | Test-Framework, Autor Mike Schulze |
| **Kenney-Assets** (`assets/audio/`, `assets/models/`) | CC0 1.0 Universal | Public Domain Dedication (kenney.nl); freie Nutzung ohne Copyleft |
| **Eigene Karten** (`maps/`) | MIT | 37 vom Autor erstellte Karten (Autoren im Dateikopf: *Robin Nunkesser*, *anonymous hendrik*, *cjl*) |
| **Originalkarten von ClanBomber** | GPL-2.0-or-later | **Nicht in diesem Repo.** Separates Datenpaket `gd-godot-clanbomber-original-maps` |
| **Originalsounds/-grafiken von ClanBomber** | Herkunft ungeklärt | **Nicht übernommen.** Vollständig durch CC0- und Neuschöpfungen ersetzt |

## Abgrenzung zum Original (Clean-Room-Status)

Der Code ist eine vollständige Clean-Room-Neuimplementierung auf Basis einer funktionalen Verhaltensbeschreibung (`ORIGINAL_BEHAVIOR.md` im Workspace `agent-workbench`). Es wurde kein Quellcode, keine Binärdatei und kein geschütztes Asset des historischen C++-Spiels übernommen. Damit besteht keinerlei GPL-Bindung für dieses Repository.
