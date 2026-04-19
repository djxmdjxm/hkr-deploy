# CLAUDE.md — KIKA Projektregeln

## Entwicklungsprozess: PIV-Loop

Jedes Feature folgt dem `/end-to-end-feature`-Command. **Nie überspringen, nie abkürzen.**

```
Schritt 1  /core:prime                  Kontext laden (Repo, PRD, Git-Status)
Schritt 2  /core:plan-feature           Plan im SCQ-Format erstellen → .agents/plans/*.md
Schritt 2b TaskCreate                   Je einen Task pro Implementierungsschritt anlegen

           *** GATE: Warten auf explizite Freigabe von Christopher ***

Schritt 3  /core:execute                Feature implementieren (Tasks in_progress → completed)
Schritt 4  /validation:validate         Build, Lint, Playwright-Tests (alle Testfälle!)
Schritt 5  /validation:code-review      Technische Qualitätsprüfung
Schritt 6  /validation:execution-report Implementierung dokumentieren (empfohlen)
Schritt 7  /validation:system-review    Prozessverbesserungen ableiten (empfohlen)
Schritt 8  /validation:commit           Conventional Commit + Push nach Freigabe
```

Der `/end-to-end-feature`-Command kettet alle Schritte. Einzelne Commands können auch direkt aufgerufen werden (z.B. nur `/core:plan-feature` für Planung, dann Freigabe abwarten).

### Wichtigste Regel: Diskussion ≠ Freigabe

Eine Idee die Christopher beschreibt oder eine Frage die er stellt ist **kein Execute-Signal**.
Erst nach explizitem "ja" / "mach das" / "leg los" darf mit Schritt 3 (`/core:execute`) begonnen werden.
Vor der Freigabe: planen, fragen, erklären — aber keinen Code schreiben und keine Dateien ändern.

---

## Projektstruktur

```
KIKA/
├── hkr-krebs-web/      Next.js 15 + React 19 + Tailwind v4 (Frontend)
├── hkr-krebs-api/      FastAPI (Upload-Endpoint, Report-Summary)
├── hkr-import-worker/  Python Worker (XSD-Validierung, DB-Import)
├── hkr-deploy/         Docker Compose, nginx, deploy.sh
├── .agents/
│   ├── plans/          Feature-Pläne (aktiv: *.md, fertig: *_done.md)
│   ├── execution-reports/
│   ├── system-reviews/
│   └── context/        On-Demand-Kontext-Dateien
├── PRD.md              Wahrheitsquelle für Features und Status
└── CLAUDE.md           Diese Datei
```

**Repos:** github.com/djxmdjxm/hkr-krebs-web, hkr-krebs-api, hkr-import-worker, hkr-deploy

---

## Infrastruktur

**ubuntu-ai (Produktionsserver):**
- LAN: `192.168.2.7` (SSH-Alias `ubuntu-ai`) — zuerst versuchen
- Remote/Tailscale: `christopher-mangels@100.71.14.29` — bei Timeout
- Repos: `/media/christopher-mangels/4TB/projectClones/kika/`
- Docker Compose Projektname: immer `-p hkr-clean`
- Compose-Datei liegt in: `.../kika/kika/docker-compose.yml`

**Deploy-Befehl (Standard — deploy.sh verwenden):**
```bash
# Einzelner Service:
ssh christopher-mangels@100.71.14.29 '~/deploy.sh web'
ssh christopher-mangels@100.71.14.29 '~/deploy.sh api'
ssh christopher-mangels@100.71.14.29 '~/deploy.sh worker'

# Alle Services auf einmal:
ssh christopher-mangels@100.71.14.29 '~/deploy.sh all'
```

Das Skript `hkr-deploy/deploy.sh` kapselt: git stash, git pull, docker build (mit korrektem BUILD_VERSION direkt auf ubuntu-ai), docker compose -p hkr-clean. Single-Quote verwenden damit keine lokale Shell-Expansion stattfindet.

**Manueller Deploy-Befehl (Fallback falls deploy.sh nicht verfügbar):**
```bash
# Wichtig: \$(date ...) mit Backslash escapen, damit Expansion auf ubuntu-ai stattfindet!
ssh christopher-mangels@100.71.14.29 "
  cd /media/christopher-mangels/4TB/projectClones/kika/hkr-krebs-web &&
  git stash && git pull &&
  docker build --build-arg BUILD_VERSION=\$(date +%Y%m%d-%H%M) -t hkr/krebs-web:latest . &&
  cd ../kika &&
  docker compose -p hkr-clean up -d --force-recreate --no-build krebs-web
"
```

**Häufige Fehler vermeiden:**
- `$(date ...)` ohne `\` wird auf Windows expandiert → leer → BUILD_VERSION fehlt (deploy.sh löst das)
- `git pull` schlägt fehl wenn ubuntu-ai lokale Änderungen hat → immer `git stash` davor (deploy.sh löst das)
- `docker compose up` ohne `-p hkr-clean` startet unter falschem Projektnamen (deploy.sh löst das)

---

## Tech Stack

| Schicht | Technologie |
|---------|------------|
| Frontend | Next.js 15.5, React 19, TypeScript, Tailwind CSS 4 |
| API | FastAPI, SQLAlchemy, Pydantic |
| Worker | Python, xmlschema, BullMQ (via Redis) |
| Datenbank | PostgreSQL (zwei DBs: main_db, krebs_db) |
| Queue | Redis |
| Ingress | nginx |

**Design:** Hamburg Corporate Design — Navy `#003063`, Rot `#E10019`, BG `#F2F5F7`, Font: Lato

---

## Validierung

Build läuft nicht lokal auf Windows (Next.js CLI nicht in PATH).
Validierung immer via Docker-Build auf ubuntu-ai:
```bash
ssh christopher-mangels@100.71.14.29 "cd .../hkr-krebs-web && docker build ... 2>&1 | tail -20"
```
TypeScript-Fehler erscheinen als Build-Fehler im Docker-Output.

Playwright-Tests: Alle im Plan definierten Testfälle müssen abgehakt sein — nicht nur der Happy Path.

---

## Commit-Stil

```
feat(web): kurze Beschreibung im Imperativ

Längere Erklärung falls nötig.

Co-Authored-By: Claude <noreply@anthropic.com>
```

Scopes: `web`, `api`, `worker`, `deploy`, `prd`

---

## Testing

- **Playwright:** Nach jedem Deploy selbst testen (Screenshot zeigen) bevor Christopher gebeten wird zu prüfen
- **Hard Refresh** nach krebs-web Rebuild: Strg+Shift+R (Browser cached alte Chunks)
- Keine lokalen Unit-Tests vorhanden — Validierung via Build + Playwright

## PRD-Pflege (nach jedem Feature)

Nach Abschluss jedes Features zwingend:
1. Feature-Status in der Tabelle auf `✅ Done` setzen
2. Alle Acceptance Criteria auf `[x]` setzen
3. Build-Version eintragen, in der das Feature deployed wurde (z.B. `deployed in 20260419-1412`)
4. "Zuletzt aktualisiert"-Zeile am Ende der Metadaten aktualisieren
5. PRD.md committen und nach `hkr-deploy` pushen — PRD ist Wahrheitsquelle, muss versioniert sein

## CLAUDE.md Sync-Regel

`KIKA/CLAUDE.md` ist die **Quelle**. `hkr-deploy/CLAUDE.md` ist eine versionierte Kopie.
Nach jeder Änderung an `KIKA/CLAUDE.md` zwingend synchronisieren:
```bash
cp KIKA/CLAUDE.md hkr-deploy/CLAUDE.md
# dann in hkr-deploy committen und pushen
```
