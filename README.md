# KIKA — KI-gestütztes Krebsregister-Analysesystem

Deployment-Repository für den KIKA-Stack. Enthält Docker Compose Konfigurationen,
Nginx Ingress, Datenbankinitialisierung und Betriebsdokumentation.

---

## Inhaltsverzeichnis

1. [Übersicht](#übersicht)
2. [Voraussetzungen](#voraussetzungen)
3. [Verzeichnisstruktur](#verzeichnisstruktur)
4. [Schnellstart (Entwicklung)](#schnellstart-entwicklung)
5. [Umgebungsvariablen](#umgebungsvariablen)
6. [Services & Ports](#services--ports)
7. [Erster Test](#erster-test)
8. [Produktiv-Deployment](#produktiv-deployment)
9. [Häufige Probleme](#häufige-probleme)

---

## Übersicht

KIKA ermöglicht Krebsregistern den Import und die Analyse von oBDS_RKI-konformen
XML-Meldedateien. Der Stack besteht aus:

| Service | Beschreibung |
|---------|-------------|
| `krebs-web` | Next.js 15 Frontend — Upload-Maske, Fortschrittsanzeige |
| `krebs-api` | FastAPI Backend — Upload-Endpoint, Job-Verwaltung |
| `import-worker` | Python Worker — XSD-Validierung, Datenbankimport |
| `central-db` | PostgreSQL — Haupt- und Krebsdatenbank |
| `job-queue` | Redis — asynchrone Job-Warteschlange |
| `ingress` | Nginx — Routing, TLS-Termination, Upload-Limits |
| `krebs-code` | code-server (VS Code im Browser) — R-Umgebung für Analysen |

---

## Voraussetzungen

- **Betriebssystem:** Linux (Ubuntu 22.04 LTS empfohlen)
- **Docker:** >= 24.0
- **Docker Compose:** >= 2.20 (als Plugin: `docker compose`)
- **RAM:** mindestens 8 GB (16 GB empfohlen)
- **Festplatte:** mindestens 20 GB frei
- **Netzwerk:** Die verwendeten Ports (8080, 8081) müssen erreichbar sein

Installation Docker (Ubuntu):
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Neu einloggen damit Gruppenänderung aktiv wird
```

---

## Verzeichnisstruktur

Alle Repos müssen im selben Elternverzeichnis liegen:

```
/ihr/pfad/
├── hkr-deploy/          # Dieses Repo — docker-compose, nginx, DB-Init
├── hkr-krebs-web/       # Frontend (Next.js)
├── hkr-krebs-api/       # Backend API (FastAPI)
├── hkr-import-worker/   # Import Worker (Python)
├── krebs-db-migrations/ # Datenbankmigrationen (Krebsdaten)
└── main-db-migrations/  # Datenbankmigrationen (Importverwaltung)
```

Repos klonen:
```bash
mkdir kika && cd kika
git clone https://github.com/djxmdjxm/hkr-deploy.git
git clone https://github.com/djxmdjxm/hkr-krebs-web.git
git clone https://github.com/djxmdjxm/hkr-krebs-api.git
git clone https://github.com/djxmdjxm/hkr-import-worker.git
# Migrationsrepos separat bereitstellen (nicht öffentlich)
```

---

## Schnellstart (Entwicklung)

### 1. Umgebungsvariablen konfigurieren

```bash
cd hkr-deploy
cp .env.example .env
# .env mit einem Texteditor öffnen und anpassen (siehe Abschnitt unten)
nano .env
```

### 2. Stack bauen und starten

```bash
# Alle Images bauen (einmalig, dauert 3-5 Minuten):
docker compose -f docker-compose.dev.yml build

# Stack starten:
docker compose -f docker-compose.dev.yml up -d

# Status prüfen:
docker compose -f docker-compose.dev.yml ps
```

### 3. Datenbank initialisieren (einmalig)

Die Migrationscontainer laufen automatisch beim ersten Start und beenden sich
danach selbständig. Kein manueller Eingriff nötig.

### 4. Anwendung öffnen

```
http://IHRE-SERVER-IP:8080
```

---

## Umgebungsvariablen

### `.env` Datei (im hkr-deploy Verzeichnis anlegen)

Kopieren Sie `.env.example` nach `.env` und passen Sie folgende Werte an:

| Variable | Beschreibung | Beispiel |
|----------|-------------|---------|
| `NEXT_PUBLIC_CODE_SERVER_URL` | URL der R-Umgebung (code-server) | `http://192.168.2.7:8081` |

**Wichtig:** `NEXT_PUBLIC_CODE_SERVER_URL` muss die IP-Adresse enthalten,
unter der der Server **vom Browser des Nutzers** erreichbar ist — nicht
`localhost`. Der Browser des Nutzers öffnet diese URL direkt.

Beispiel `.env`:
```env
# URL der R-Analyse-Umgebung (VS Code im Browser)
# Muss vom Client-Browser aus erreichbar sein (keine interne Docker-IP)
NEXT_PUBLIC_CODE_SERVER_URL=http://192.168.2.7:8081
```

### Passwörter (in docker-compose.dev.yml)

Für den Entwicklungsbetrieb sind folgende Standardpasswörter gesetzt.
**Für Produktivbetrieb unbedingt ändern:**

| Service | Variable | Standardwert | Ändern in |
|---------|----------|-------------|-----------|
| PostgreSQL | `POSTGRES_PASSWORD` | `1234` | `docker-compose.dev.yml` |
| Redis | Passwort in Connection-URL | `1234` | `docker-compose.dev.yml` |
| code-server | `USER_PASSWORD` | `1234` | `docker-compose.dev.yml` |
| code-server | `SUDO_PASSWORD` | `123456` | `docker-compose.dev.yml` |

---

## Services & Ports

Nach dem Start sind folgende Dienste erreichbar:

| Service | Port | URL | Beschreibung |
|---------|------|-----|-------------|
| **Frontend** | 8080 | `http://SERVER-IP:8080` | Upload-Maske (Hauptanwendung) |
| **R-Umgebung** | 8081 | `http://SERVER-IP:8081` | VS Code im Browser mit R |
| **PostgreSQL** | 5432 | — | Nur intern (kein direkter Zugriff nötig) |

Die API (`/api/`) ist über den Ingress unter Port 8080 erreichbar,
nicht direkt als eigener Port.

---

## Erster Test

### Erfolgreicher Import

1. Browser öffnen: `http://SERVER-IP:8080/registry`
2. Schema-Version **oBDS 3.0.4 RKI** auswählen
3. Eine gültige oBDS_RKI XML-Datei hochladen
4. Die animierte Rose zeigt den Fortschritt:
   - **Stiel wächst** → Upload läuft
   - **Blütenblätter öffnen** → Validierung
   - **Rote Mitte** → Import in Datenbank
5. Nach erfolgreichem Import erscheint der Button **"Daten in R-Umgebung analysieren"**

### Fehlerfall testen

1. Schema-Version **oBDS 3.0.4 RKI** auswählen
2. Eine XML-Datei im falschen Format hochladen
3. Es erscheint ein roter Fehler-Banner mit:
   - Konkretem Hinweis was zu prüfen ist (gelbe Box)
   - Technischen Details (aufklappbar, für IT-Support)

---

## Produktiv-Deployment

Für den Produktivbetrieb `docker-compose.prd.yml` verwenden. Dieser setzt
voraus, dass die Images bereits gebaut und getaggt sind:

```bash
# Images bauen und taggen:
docker build -t hkr/krebs-web:latest ../hkr-krebs-web/
docker build -t hkr/krebs-api:latest ../hkr-krebs-api/
docker build -t hkr/import-worker:latest ../hkr-import-worker/
docker build -t hkr/ingress:latest ./ingress/
docker build -t hkr/central-db:latest ./central-db/
docker build -t hkr/job-queue:latest ./job-queue/
docker build -t hkr/krebs-code:latest ./code-server/

# Stack starten (Port 8090 statt 8080, code-server auf 8091):
docker compose -f docker-compose.prd.yml up -d
```

**Unterschiede dev vs. prd:**

| | dev | prd |
|-|-----|-----|
| Frontend-Port | 8080 | 8090 |
| code-server-Port | 8081 | 8091 |
| Source-Mounting | Ja (hot-reload) | Nein (Images) |
| Image-Quelle | Lokaler Build | Vorgefertigte Images |

---

## Häufige Probleme

### Stack startet nicht — "port already in use"
```bash
# Prüfen welcher Prozess Port 8080 belegt:
sudo lsof -i :8080
# oder:
sudo ss -tlnp | grep 8080
```

### Datenbankfehler beim ersten Start
Die Migrationscontainer benötigen manchmal einen zweiten Anlauf wenn
PostgreSQL noch nicht bereit war:
```bash
docker compose -f docker-compose.dev.yml restart krebs-db-migrations main-db-migrations
```

### Upload schlägt fehl — "502 Bad Gateway"
Nginx kennt die neue Container-IP nach einem Neustart nicht mehr:
```bash
docker restart ingress
```

### R-Umgebung nicht erreichbar
Prüfen ob `NEXT_PUBLIC_CODE_SERVER_URL` die richtige IP enthält
(muss vom Browser des Nutzers erreichbar sein, nicht `localhost`):
```bash
docker exec krebs-web env | grep CODE_SERVER
```

### Speicher prüfen
```bash
# RAM-Auslastung:
free -h
# Swap (sollte 0 sein im Normalbetrieb):
swapon --show
# Docker-Volumes:
docker system df
```

---

## Support

Bei Fragen oder Problemen: Hamburgisches Krebsregister, IT-Abteilung.
