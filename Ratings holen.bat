@echo off
cd /d "%~dp0"
echo.
echo  === Barca Player Ratings (FotMob) ===
echo.
set "URL="
set /p URL= FotMob-Link einfuegen - oder einfach Enter fuer das letzte Barca-Spiel:
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ratings-holen.ps1" -Match "%URL%"
if errorlevel 1 (
  echo.
  echo  Fehler beim Laden. Siehe Meldung oben.
  pause
  exit /b 1
)
start "" "%~dp0ratings-generator.html"
