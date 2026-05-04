# KIKA IT-Handbuch

Anleitung zur Installation und zum Betrieb von KIKA in einer Krebsregister-Umgebung.
Zielgruppe: IT-Administration, die das Air-Gap-Paket entgegennimmt und einrichtet.

---

## Inhaltsverzeichnis

1. [Systemvoraussetzungen](#1-systemvoraussetzungen)
2. [Lieferumfang des Air-Gap-Pakets](#2-lieferumfang)
3. [Installation Schritt-für-Schritt](#3-installation)
4. [Anpassungen vor dem ersten Start](#4-anpassungen)
5. [Desktop-Launcher einrichten](#5-desktop-launcher)
6. [Smoke-Test nach der Installation](#6-smoke-test)
7. [Update auf eine neue Version](#7-update)
8. [Backup und Wiederherstellung](#8-backup)
9. [Troubleshooting](#9-troubleshooting)
10. [Kontakt](#10-kontakt)

---

<a id="1-systemvoraussetzungen"></a>
## 1. Systemvoraussetzungen

| Komponente | Mindestens | Empfohlen |
|------------|-----------|-----------|
| Betriebssystem | Windows 10 Pro 64-Bit (Version 21H2) | Windows 11 Pro 64-Bit |
| CPU | 4 Kerne | 8 Kerne |
| RAM | 16 GB | 32 GB |
| Freier Festplattenplatz | 50 GB SSD | 100 GB SSD |
| Software | Docker Desktop ≥ 4.30 mit WSL2-Backend | Aktuelle Version |
| Netzwerk | Kein Internetzugang erforderlich | LAN für Multi-User |

**Wichtig:** Docker Desktop muss mindestens **8 GB RAM** zugewiesen
bekommen (Settings → Resources → Memory). Mit weniger crashen Container
während Importen großer XML-Dateien.

**WSL2** muss aktiviert sein. Wenn Docker Desktop frisch installiert wird,
führt der Installer normalerweise dorthin.

---

<a id="2-lieferumfang"></a>
## 2. Lieferumfang des Air-Gap-Pakets

Das Paket kommt als Ordner (z.B. auf USB-Stick) mit folgender Struktur:

```
kika-air-gap/
├── docker-compose.yml         <- definiert alle Services
├── README.txt                 <- Schnellstart (siehe dieses Handbuch ausführlicher)
├── images/                    <- 9 Container-Images als .tar
│   ├── central-db.tar              ~104 MB  (PostgreSQL für KIKA-Daten)
│   ├── import-worker.tar           ~50 MB   (XSD-Validierung, DB-Import)
│   ├── ingress.tar                 ~25 MB   (nginx Reverse-Proxy)
│   ├── job-queue.tar               ~33 MB   (Redis für Job-Warteschlange)
│   ├── krebs-api.tar               ~80 MB   (FastAPI Upload-Endpoint)
│   ├── krebs-db-migrations.tar     ~45 MB   (Schema-Migrations krebs_db)
│   ├── krebs-web.tar               ~417 MB  (Next.js Frontend)
│   ├── main-db-migrations.tar      ~42 MB   (Schema-Migrations main_db)
│   └── rstudio-server.tar          ~1 GB    (R + RStudio + Geo-Pakete)
└── desktop-launcher/          <- Mini-GUI mit Start/Stop-Knöpfen
    ├── KIKA.bat                    Doppelklick öffnet die GUI
    ├── KIKA.ps1                    PowerShell-Skript dahinter
    └── README.md                   Setup-Hinweise

Gesamtgröße: ca. 1,8 GB
```

---

<a id="3-installation"></a>
## 3. Installation Schritt-für-Schritt

### Schritt 1: Ordner an festen Platz legen

Den kompletten `kika-air-gap`-Ordner an einen Ort kopieren, wo er
**dauerhaft liegen bleiben kann** — der Pfad wird in der Konfiguration
verwendet.

**Empfehlung:** `D:\KIKA\` oder `C:\KIKA\` (kurzer Pfad ohne Leerzeichen).

> **Vermeide** Pfade mit Leerzeichen oder Sonderzeichen wie `D:\KiKA RGAP\` —
> einige Tools haben damit Probleme. Lieber `D:\KIKA\`.

### Schritt 2: Docker Desktop installieren

Falls noch nicht vorhanden — Installer von Docker (vorher von einem
vernetzten Rechner herunterladen) auf den Zielrechner bringen und
installieren. Während der Installation:

- WSL2-Backend wählen (Standard)
- Nach Installation: Neustart des Rechners
- Docker Desktop starten → wartet bis "Engine running" in der Taskleiste

**RAM-Setting:** Docker Desktop → ⚙️ Settings → Resources → Memory →
auf mindestens **8 GB** stellen → Apply & Restart.

### Schritt 3: Container-Images laden

PowerShell als normaler Benutzer öffnen, in den `kika-air-gap`-Ordner wechseln:

```powershell
cd D:\KIKA
Get-ChildItem images\*.tar | ForEach-Object {
  Write-Host "Loading $($_.Name)..."
  docker load -i $_.FullName
}
```

Dauer: ca. 2–5 Minuten. Am Ende:

```powershell
docker images | Select-String "hkr/"
```

Sollte 9 KIKA-Images zeigen (`hkr/krebs-web:latest`, `hkr/krebs-api:latest`, ...).

### Schritt 4: Container starten

```powershell
cd D:\KIKA
docker compose -p hkr-clean up -d
```

Beim **ersten** Start:
- DB-Migrations laufen einmalig (kann 30 Sekunden dauern)
- Alle Services starten in der richtigen Reihenfolge
- Ausgabe sollte mit `✓ Started` für jeden Container enden

### Schritt 5: Status prüfen

```powershell
docker compose -p hkr-clean ps
```

Alle Container sollten `Up` zeigen, `central-db` zusätzlich `(healthy)`.

---

<a id="4-anpassungen"></a>
## 4. Anpassungen vor dem ersten Start

In den meisten Fällen funktioniert KIKA ohne Anpassungen. Wenn etwas
geändert werden muss — alle Anpassungen in **`docker-compose.yml`**.

### Ports (falls Standardports belegt)

Standardmäßig nutzt KIKA:
- **8090** — Web-UI (Upload, About-Seite)
- **8787** — RStudio
- **5432** — PostgreSQL (intern, nicht von außen sichtbar)

Wenn 8090 oder 8787 schon vergeben sind, in `docker-compose.yml` ändern:

```yaml
ingress:
  ports:
    - "8090:80"     # links den freien Port wählen, z.B. "9090:80"

krebs-code:
  ports:
    - "8787:8787"   # links den freien Port wählen
```

Nach Änderung: `docker compose -p hkr-clean up -d` — der betroffene Container
wird neu erstellt.

### Volumes (wo werden Daten gespeichert?)

Standardmäßig persistieren die PostgreSQL-Datenbanken in **Docker-internen Volumes**
(nicht im Dateisystem direkt sichtbar). Das ist robust, aber bei
Server-Migration unhandlich.

Für ein **explizites Verzeichnis** in der `docker-compose.yml`:

```yaml
volumes:
  central-db:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: D:\KIKA\daten\central-db    # <- expliziter Pfad
```

Vorteil: Die Datenbank-Daten liegen klar sichtbar an einem definierten Ort
und können einfach gesichert werden.

### Datenbank-Passwort ändern

Standardmäßig ist das PostgreSQL-Passwort `1234` (intern, nicht von außen
erreichbar). Wenn es geändert werden soll:

1. In `docker-compose.yml` beim Service `central-db` die Environment-Variable
   `POSTGRES_PASSWORD` anpassen.
2. **Wichtig:** In der Pythonseite (`krebs-api`, `import-worker`) und in den
   R-Beispielskripten (`/home/rstudio/*.R`) muss das Passwort auch angepasst
   werden — sonst kommt keine Verbindung zustande.
3. Bestehende Volumes wegwerfen und neu initialisieren — sonst behält PostgreSQL
   das alte Passwort:
   ```powershell
   docker compose -p hkr-clean down -v
   docker compose -p hkr-clean up -d
   ```
   ⚠️ **Vorsicht:** `down -v` löscht alle DB-Daten. Nur bei frischer Installation
   verwenden, sonst vorher Backup ziehen (Abschnitt 8).

---

<a id="5-desktop-launcher"></a>
## 5. Desktop-Launcher einrichten

Damit Endnutzer KIKA ohne PowerShell-Wissen starten/stoppen können:

1. Im Ordner `kika-air-gap\desktop-launcher\` die Datei `KIKA.ps1` öffnen
   und ggf. den Pfad zur `docker-compose.yml` anpassen, falls KIKA nicht im
   übergeordneten Ordner liegt:
   ```powershell
   $ComposeFile = "D:\KIKA\docker-compose.yml"
   ```
   (Standard ist `Join-Path (Split-Path -Parent $ScriptDir) "docker-compose.yml"` —
   das funktioniert, wenn der Launcher unter `D:\KIKA\desktop-launcher\` liegt
   und die Compose-Datei direkt unter `D:\KIKA\`.)

2. Rechtsklick auf `KIKA.bat` → **Senden an → Desktop (Verknüpfung erstellen)**.

3. Verknüpfung auf dem Desktop umbenennen zu **„KIKA"**.

4. Optional: Eigene `.ico`-Datei zuweisen (Rechtsklick → Eigenschaften → Anderes Symbol).

5. Doppelklick auf das neue Desktop-Symbol → das KIKA-Fenster öffnet sich
   mit Status-Lampe und Start/Stop-Knöpfen.

Details: `desktop-launcher\README.md`.

---

<a id="6-smoke-test"></a>
## 6. Smoke-Test nach der Installation

Folgende Schritte funktionieren als Test, ob alles läuft:

1. **Web-UI öffnen:** Browser auf `http://localhost:8090`. Es sollte die
   KIKA-Startseite mit Begrüßung erscheinen.
2. **Über-Seite:** `http://localhost:8090/about` — Beschreibung sichtbar.
3. **Upload-Test:** Auf „Daten importieren" klicken → Einzelimport → eine
   kleine oBDS-XML-Datei hochladen → muss ohne Fehler durchlaufen.
4. **RStudio öffnen:** Browser auf `http://localhost:8787` → RStudio erscheint
   ohne Login-Maske.
5. **Datenbankverbindung im RStudio testen:**
   - Im Files-Panel: `analyse.R` öffnen → `Strg+Shift+S` (Source)
   - In der Konsole müssen Fallzahlen und ein Histogramm erscheinen.
6. **Stop & Start über Launcher:** Doppelklick KIKA-Icon → Stop drücken →
   Container fahren runter → Start drücken → fahren wieder hoch.

Wenn alle 6 Schritte funktionieren, ist die Installation komplett.

---

<a id="7-update"></a>
## 7. Update auf eine neue Version

Wenn ein neues Air-Gap-Paket geliefert wird (Bugfix oder neue Funktion):

1. **Daten sichern** (Abschnitt 8) — *immer* vor einem Update.
2. Container stoppen:
   ```powershell
   cd D:\KIKA
   docker compose -p hkr-clean down
   ```
3. Neue `.tar`-Dateien aus dem neuen Paket in `D:\KIKA\images\` kopieren
   (alte überschreiben).
4. Falls `docker-compose.yml` im Update neu ist — die alte sichern, neue
   einspielen, eigene Anpassungen (Ports, Volumes) wieder einbauen.
5. Images neu laden:
   ```powershell
   Get-ChildItem D:\KIKA\images\*.tar | ForEach-Object { docker load -i $_.FullName }
   ```
6. Container neu starten:
   ```powershell
   docker compose -p hkr-clean up -d
   ```
7. Smoke-Test (Abschnitt 6) erneut durchlaufen.

**Welche Container betroffen sind**, sollte das Release-Notes-Dokument
des Updates angeben — dann muss man nur die geänderten `.tar` neu laden.

---

<a id="8-backup"></a>
## 8. Backup und Wiederherstellung

### Was gesichert werden muss

Die importierten Krebsregister-Daten liegen in zwei PostgreSQL-Datenbanken
(`main_db` und `krebs_db`). Beide leben im Docker-Volume `central-db_data`
(oder im expliziten Verzeichnis, wenn so konfiguriert — siehe Abschnitt 4).

### Backup ziehen (täglich empfohlen)

```powershell
$datum = Get-Date -Format "yyyy-MM-dd"
docker exec central-db pg_dumpall -U postgres > "D:\KIKA\backup\kika_$datum.sql"
```

Dump-Datei wegsichern (NAS, Tape, externer Datenträger).

### Backup einspielen

```powershell
# Container müssen laufen
Get-Content "D:\KIKA\backup\kika_2026-05-04.sql" | docker exec -i central-db psql -U postgres
```

⚠️ Vor dem Einspielen sicherstellen, dass die Datenbanken leer sind oder
die Inhalte überschrieben werden dürfen.

### Was **nicht** gesichert werden muss
- Container-Images (kommen aus dem Air-Gap-Paket)
- RStudio-Workspace-Dateien (sind im Image — Forscher-Outputs sollten
  manuell exportiert werden, Abschnitt 7 im Forscher-Handbuch)
- Hochgeladene XML-Dateien (werden nach Import in die DB überführt und
  sind dort gesichert)

---

<a id="9-troubleshooting"></a>
## 9. Troubleshooting

### „Docker Desktop läuft nicht" im Launcher
Docker Desktop in der Taskleiste suchen — wenn nicht da, manuell aus dem
Startmenü starten. Engine braucht 30–60 Sekunden, bis das Walfisch-Symbol
„grün" wird.

### Browser zeigt „Verbindung verweigert" bei `localhost:8090`
- Container-Status prüfen: `docker compose -p hkr-clean ps`
- Wenn Status `Restarting` oder `Exited`: Logs ansehen
  `docker compose -p hkr-clean logs --tail 50 ingress`
- Häufig: Port 8090 ist von einem anderen Programm belegt → Port in
  `docker-compose.yml` ändern (Abschnitt 4).

### Upload bricht mit „Netzwerkfehler"
- Prüfen ob alle Container laufen
- Logs des `krebs-api` ansehen: `docker compose -p hkr-clean logs --tail 100 krebs-api`
- Häufig: Docker Desktop hat zu wenig RAM (siehe Voraussetzungen)

### „Out of memory" bei großen XML-Dateien
- Docker Desktop → Settings → Resources → Memory → auf 12 oder 16 GB hochsetzen
- Apply & Restart

### Container starten in falscher Reihenfolge / DB-Verbindung schlägt fehl
Die Compose-Datei hat `depends_on` mit `condition: service_healthy` gesetzt —
das funktioniert in der Regel. Bei hartnäckigen Problemen:

```powershell
docker compose -p hkr-clean down
docker compose -p hkr-clean up -d central-db job-queue
# warten bis healthy
docker compose -p hkr-clean ps
# dann den Rest:
docker compose -p hkr-clean up -d
```

### RStudio reagiert nicht / hängt
- Browser-Tab schließen und neu öffnen — die Session wird oft auf der
  Server-Seite weitergeführt.
- Notfalls Container neu starten:
  `docker compose -p hkr-clean restart krebs-code`

### Logs zentral ansehen
```powershell
docker compose -p hkr-clean logs --tail 200
```
oder pro Service:
```powershell
docker compose -p hkr-clean logs -f krebs-api
```
(`-f` = follow, also live mitlesen)

---

<a id="10-kontakt"></a>
## 10. Kontakt

**Technischer Support und Rückfragen:**
Hamburgisches Krebsregister
- PD Dr. Frederik Peters — frederik.peters@bwfg.hamburg.de
- Dr. Annemarie Schultz — annemarie.schultz@bwfg.hamburg.de

**Beim Melden eines Problems bitte angeben:**
- Genaue Fehlermeldung (Screenshot ist hilfreich)
- `docker compose -p hkr-clean ps` als Ausgabe
- Bei Container-Fehler: die letzten 100 Zeilen aus
  `docker compose -p hkr-clean logs <servicename>`
