# KIKA Desktop-Launcher

Mini-GUI zum Starten, Stoppen und Beobachten der KIKA-Container.
Kein Installationsschritt — funktioniert auf jedem Windows 10/11 mit Docker Desktop.

## Was ist drin?

| Datei | Zweck |
|-------|-------|
| `KIKA.bat` | Doppelklick-Datei. Startet die GUI ohne CMD-Fenster. |
| `KIKA.ps1` | PowerShell + WinForms GUI mit Start/Stop/Status. |
| `README.md` | Diese Datei. |

## Setup (einmalig auf dem Air-Gap-Rechner)

1. Kompletten `desktop-launcher`-Ordner an einen festen Platz legen,
   z.B. `D:\KiKA RGAP\desktop-launcher\`.
   **Wichtig:** Der Ordner muss als Geschwister neben der `docker-compose.yml`
   liegen, also Struktur:
   ```
   D:\KiKA RGAP\
   ├── docker-compose.yml
   ├── images\
   └── desktop-launcher\
       ├── KIKA.bat
       ├── KIKA.ps1
       └── README.md
   ```
2. Rechtsklick auf `KIKA.bat` → **„Senden an" → „Desktop (Verknuepfung erstellen)"**.
3. Auf dem Desktop die neue Verknuepfung umbenennen zu **„KIKA"**.
4. Optional: Rechtsklick auf die Verknuepfung → **„Eigenschaften" → „Anderes Symbol"**
   und ein eigenes Icon waehlen (z.B. ein KIKA-Logo als `.ico`).

## Wenn die `docker-compose.yml` woanders liegt

In `KIKA.ps1` oben den Block bei `# --- Konfiguration ---` editieren:

```powershell
$ComposeFile = "C:\Pfad\zu\docker-compose.yml"
```

## Was die GUI macht

- **Status-Anzeige:** Lampe oben links zeigt:
  - 🟢 Gruen = alle Container laufen
  - 🟡 Gelb = teilweise (z.B. waehrend Start) oder Status unklar
  - 🔴 Rot = gestoppt
  Status wird alle 3 Sekunden automatisch aktualisiert.
- **Start:** Faehrt alle Container hoch (`docker compose up -d`).
- **Stop:** Faehrt alle Container herunter (`docker compose down`),
  mit Sicherheitsabfrage.
- **Im Browser oeffnen:** Oeffnet `http://localhost:8090`.

## Voraussetzungen

- Docker Desktop muss installiert sein und laufen.
- Die KIKA-Images muessen einmalig per `docker load -i images\*.tar` geladen sein
  (siehe haupt-README im Air-Gap-Paket).

## Troubleshooting

**„Status unbekannt - laeuft Docker Desktop?"**
- Pruefen ob Docker Desktop in der Taskleiste laeuft. Falls nicht: starten.

**„Start fehlgeschlagen"**
- Fenster meldet die Fehlermeldung von Docker. Haeufigste Ursache: Images
  noch nicht geladen, oder docker-compose.yml-Pfad falsch in `KIKA.ps1`.

**Die GUI oeffnet gar nicht**
- PowerShell-Skripte koennten via Group Policy gesperrt sein. Test:
  Rechtsklick `KIKA.ps1` → „Mit PowerShell ausfuehren". Falls das geht
  aber `KIKA.bat` nicht, ist die Bypass-Option blockiert.
