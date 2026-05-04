@echo off
REM KIKA Desktop-Launcher
REM Startet KIKA.ps1 ohne sichtbares CMD-Fenster.
REM Doppelklick auf diese Datei -> KIKA-Fenster oeffnet sich.

set "SCRIPT_DIR=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%SCRIPT_DIR%KIKA.ps1"
