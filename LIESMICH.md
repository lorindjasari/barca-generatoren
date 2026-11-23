# Barça-Generatoren (LJ)

Alle Dateien müssen zusammen in diesem Ordner bleiben.
**Start:** `index.html` doppelklicken → dort den passenden Generator wählen.

## Line-up vor dem Spiel
1. In der Übersicht **Line-up** öffnen.
2. Possible XI / Official XI, Gegner, Datum, Trikot, Formation, Spieler, Leaks und Ausfälle einstellen.
3. **PNG herunterladen**.

## Ratings nach dem Spiel
1. `Ratings holen.bat` doppelklicken → Enter (letztes Barça-Spiel) oder FotMob-Link einfügen.
2. Der Ratings-Generator öffnet sich mit den FotMob-Daten → **PNG herunterladen**.

## Spieler-Analyse nach dem Spiel
1. Zuerst `Ratings holen.bat` (übernimmt Spieler, Tore, Assists, FotMob-Noten als Vorschlag).
2. In der Übersicht **Spieler-Analyse** öffnen, Noten anpassen und pro Spieler einen kurzen Text schreiben.
3. Player of the Match (Gold) und Aufbau-Highlight (ruhiges Blau) laufen automatisch, lassen sich aber umstellen.
4. **Alle Seiten als PNG** → fertiges Karussell (3 Spieler pro Seite).

## Dateien
| Datei | Inhalt |
|---|---|
| `index.html` | Übersicht aller Generatoren |
| `lineup-generator.html` | Possible/Official-XI-Grafik |
| `ratings-generator.html` | Player-Ratings-Grafik |
| `analyse-generator.html` | Spieler-Analyse mit Noten und Texten |
| `player-photos.js` | Offizielle Heim-Fotos (fcbarcelona.com) |
| `player-photos-away.js` / `player-photos-third.js` | Fotos mit Auswärts- / 3. Trikot (aus `tools\trikot-vorlagen` erzeugt) |
| `coach-photo.js` | Trainer-Foto |
| `brand-logo.js` | LJ-Logo |
| `ratings-holen.ps1` / `Ratings holen.bat` | Holt Ratings von FotMob → `match-ratings.js` |
| `tools\trikots-umfaerben.ps1` | Erzeugt die Auswärts-/3.-Trikot-Fotos neu |
| `Gespraechsverlauf.zip` | Export des Claude-Gesprächs, in dem alles gebaut wurde |

## Auf einem anderen PC
- Eigene Fotos (hochgeladen), eigenes Logo und Einstellungen liegen nur im Browser:
  im Line-up-Generator unter **6 · Backup** exportieren und auf dem anderen PC importieren.
- Zum Weiterbearbeiten: in der Claude-App eine neue Sitzung mit diesem Ordner öffnen.
