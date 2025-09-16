# MenuPy – Interne Projektbeschreibung

## Kurzfassung
MenuPy ist eine schlanke macOS‑Menüleisten‑App, um Python‑Skripte schnell und ohne Terminal auszuführen. Die App bietet: Skriptverwaltung (Ordner/einzeln), Interpreter‑Auswahl (Homebrew, pyenv, System, benutzerdefiniert), Start/Stop laufender Skripte, anpassbares Menüleisten‑Icon (Bild oder SF‑Symbol), optionales Badge mit der Anzahl laufender Skripte, sowie ein kompaktes Einstellungsfenster und einen About‑Dialog mit Projektlink.

Ziel: Alltägliche Automatisierungen und Tools mit einem Klick starten, ohne Terminal und ohne komplexe UI.

## Zielgruppen und typische Use‑Cases
- Entwickler/Power‑User, die häufig wiederkehrende Python‑Skripte ausführen (Build‑Hilfen, Datenaufbereitung, Deployment‑Snippets, Admin‑Tasks).
- Nicht‑Entwickler, die vorhandene `.py`‑Tools komfortabel starten möchten.

Beispiele:
- „Daten exportieren“: CSV/Excel erzeugen und in einen Ordner legen.
- „Repository bereinigen“: lokales Cleanup‑Skript ausführen.
- „Backup“: lokales Backup‑Skript triggern.

## Kernfunktionen
- Skripte starten per Klick aus der Menüleiste
- Zwei Quellenformen:
  - Skripte‑Ordner: listet automatisch alle `.py` in einem Ordner
  - Einzelne `.py` hinzufügen: Dateien beliebiger Orte, separat verwaltbar
- Laufende Skripte anzeigen und beenden (einzeln, „Alle stoppen“)
- Python‑Interpreter auswählen: Homebrew, pyenv, System, benutzerdefinierter Pfad; Python 3.12 wird bevorzugt, falls vorhanden
- Menüleisten‑Icon anpassen:
  - Bilddatei (PNG/JPEG/TIFF/PDF)
  - SF‑Symbol (aus Vorschlagsliste oder per Namen)
  - Reset auf Standard
- Badge (Anzahl laufender Skripte) optional anzeigen
- About‑Dialog mit Icon, Version/Build und Link zur GitHub‑Repo

## Benutzerführung und Menüstruktur
- Hauptmenü (Auszug):
  - Dynamische Liste der Skripte (aus Ordner + hinzugefügte Dateien)
    - Für laufende Skripte: zusätzlicher „Stop <Name>“-Eintrag direkt daneben
  - Skripte‑Ordner… / Skripte‑Ordner entfernen
  - Skripte hinzufügen (.py)…
  - Hinzugefügte Skripte entfernen → Untermenü mit Einträgen
  - Laufende Skripte → Untermenü (einzeln stoppen / Alle stoppen)
  - Aktualisieren
  - Einstellungen… (⌘,)
  - Über MenuPy (⌘I)
  - Beenden (⌘Q)

## Einstellungsfenster (SwiftUI)
- Vorschau des Menüleisten‑Icons
- Icon anpassen:
  - „Bilddatei wählen…“
  - „SF‑Symbol setzen“ via Liste
  - Freies Textfeld „SF‑Symbolname“ + Übernehmen
  - „Standard“ für Reset
- Badge‑Option: „Badge mit Anzahl laufender Skripte anzeigen“ (Toggle)

## Technische Architektur
- App‑Technologien: Swift/SwiftUI + AppKit (NSStatusItem, NSMenu, NSAlert, NSOpenPanel)
- Einstiegspunkt: `MenuPyApp` (SwiftUI) + `AppDelegate` (NSApp Agent)
- Statusleisten‑Logik: `StatusItemController`
- Skript‑ und Prozessmanagement: `ScriptManager`
- Einstellungen: `SettingsView` (SwiftUI) + `SettingsWindowController` (NSWindowController)

### Skriptverwaltung
- Quellen:
  - Ordner (UserDefaults‑Pfad) → alle `.py` im Verzeichnis
  - Manuell hinzugefügte `.py` (UserDefaults‑Liste), Deduplizierung per kanonischem Pfad
- Entfernen: Untermenü „Hinzugefügte Skripte entfernen“
- Aktualisieren: Ordner neu lesen, nicht mehr existierende Einzeldateien bereinigen, Menü neu aufbauen

### Interpreterverwaltung
- Automatische Erkennung typischer Pfade:
  - Homebrew (arm64/Intel): `/opt/homebrew`, `/usr/local`, inkl. `python@3.12`
  - System: `/usr/bin/python3`
  - pyenv: `~/.pyenv/versions/*/bin/python3` + `~/.pyenv/shims/python3`
- Benutzerdefinierter Interpreter per Dateiauswahl
- Fallback: `/usr/bin/env python3`
- Aktiver Interpreter wird im Menü markiert

### Prozesse und Beenden
- Ausführung über `Process` mit `stdout/stderr` Capture, `cwd` = Ordner des Skripts
- Keine Alerts nach Abschluss (ruhiges UX)
- Beenden: SIGINT → (1s) SIGTERM → (1s) SIGKILL; robuste Kaskade für „hängende“ Skripte
- Laufstatus tracking: Map `scriptPath → Process`, Normalisierung über kanonische Pfade
- Menü aktualisiert sich via Notifications beim Start/Ende

### Menüleisten‑Icon
- Priorität: Benutzerbild > SF‑Symbol > Standard („terminal“)
- Bild wird als Template‑Icon gesetzt (monochrom, systemtint), Größe etwa 18pt
- Badge: wenn aktiv, zeigt eine Zahl neben dem Icon (laufende Skripte)

### About‑Icon
- Primär aus Asset‑Katalog `AboutIcon` (PNG)
- Fallback: `Resources/AboutIcon.png`
- About‑Dialog: Version/Build, Beschreibung, Entwicklerhinweis, GitHub‑Link

### Persistenz (UserDefaults)
- Schlüssel (Auszug):
  - `scriptsDirectoryPath` (Ordner)
  - `additionalScriptsPaths` (String‑Array)
  - `pythonInterpreterPath` (Interpreter)
  - `customStatusIconPath` (Dateipfad Icon)
  - `customStatusIconSymbolName` (SF‑Symbol)
  - `showStatusBadge` (Bool)

## Sicherheit und Privacy
- Hardened Runtime aktiv
- Keine Netzwerkzugriffe, keine Telemetrie
- Keine sensiblen Daten in Logs; keine persistente Speicherung außer Einstellungen
- LSUIElement: App erscheint nicht im Dock, nur als Status‑Icon
- Gatekeeper: ohne Notarisierung ggf. „Trotzdem öffnen“ nötig

## Build & Packaging (lokal)
- Release‑Build (Xcode/XcodeGen)
- Lokale Artefakte: ZIP/DMG unter `dist/` (z. B. `MenuPy-1.0.zip`, `MenuPy-1.0.dmg`)
- Signierung: ad‑hoc bzw. Developer ID (optional, für Notarisierung erforderlich)
- Notarisierung (optional): Apple‑Notary‑Service, danach „stapling“; reduziert Gatekeeper‑Warnungen

## GitHub
- Branch: `main`
- Tags/Release: `v1.0` etc. (SemVer empfohlen)
- Release‑Assets: ZIP/DMG anhängen
- Repository‑Themen (Topics): `menubar-app, macos, swift, swiftui, appkit, python, python3, python-scripts, scripting, automation, pyenv, homebrew, xcode, xcodegen`

## Troubleshooting (kurz)
- App startet nicht: Gatekeeper → „Trotzdem öffnen“
- Interpreter fehlt: Menü „Python‑Interpreter“ → Pfad wählen
- Icon erscheint nicht (About): Dateiname exakt `AboutIcon.png`; Clean Build; Fallback in `Resources/`
- Badge fehlt: Einstellungen → Badge‑Toggle aktivieren
- Stop wirkt nicht: blockierendes Skript → mehrfacher Stop löst SIGKILL aus; ggf. Skript prüfen

## Roadmap / Ideen
- Pro‑Skript Argumente/Umgebungsvariablen/Timeouts
- Per‑Skript Interpreter/venv
- Kategorien/Gruppierung, Suchfeld, Favoriten, Tastaturkürzel je Skript
- Logs‑Panel (sichtbare stdout/stderr‑Historie)
- Export/Import von Einstellungen
- Automatische Releases via GitHub Actions (signiert/notarisiert)

## Versionierung & Release‑Prozess (empfohlen)
- SemVer: `MAJOR.MINOR.PATCH`
- Taggen (`vX.Y.Z`) → Release‑Notes → ZIP/DMG anhängen
- Für öffentliche Verteilung: signieren + notarisieren

## Wartung
- Abhängigkeiten (keine externen Packages) → geringes Risiko
- Regelmäßig gegen aktuelle Xcode/macOS SDKs bauen
- README aktuell halten (Installation, Features)
- .gitignore schützt interne Dateien (diese Datei: `INTERNAL_PROJECT_OVERVIEW.md`)

— Internes Dokument. Nicht veröffentlichen. —
