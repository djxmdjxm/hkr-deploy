# On-Demand Context: Deploy-Workflow

## Standard-Deploy-Befehl

```bash
# Einzelner Service (Single-Quote — kein lokales Shell-Expansion-Problem):
ssh 192.168.2.7 '~/deploy.sh web'
ssh 192.168.2.7 '~/deploy.sh api'
ssh 192.168.2.7 '~/deploy.sh worker'

# Alle Services auf einmal:
ssh 192.168.2.7 '~/deploy.sh all'

# Bei Timeout (unterwegs / Tailscale):
ssh christopher-mangels@100.71.14.29 '~/deploy.sh web'
```

## Was deploy.sh intern tut

1. `git stash || true` — verhindert Konflikte bei lokalen ubuntu-ai-Änderungen
2. `git pull` — holt aktuelle Version aus GitHub
3. `docker build --build-arg BUILD_VERSION=$(date +%Y%m%d-%H%M)` — Build mit Zeitstempel (lokal auf ubuntu-ai, kein Windows-Escaping)
4. `docker compose -p hkr-clean -f .../docker-compose.yml up -d --force-recreate --no-build <service>` — Container neu starten

## Skript-Struktur auf ubuntu-ai

- **Quelle**: `/media/christopher-mangels/4TB/projectClones/kika/hkr-deploy/deploy.sh`
- **Symlink**: `~/deploy.sh` → Repo-Datei
- **Update**: `git pull` in `hkr-deploy/` — Symlink zeigt automatisch auf neue Version

## Commit-Reihenfolge bei Server-Features

Features die ein Server-Skript ändern brauchen zwei Commits:

1. **Commit 1 (push sofort)**: Skript/Code-Änderung → `git push` → auf ubuntu-ai `git pull` + installieren → testen
2. **Commit 2**: Dokumentation (CLAUDE.md, PRD.md) nach bestandenem Test

Grund: Das Skript muss auf ubuntu-ai verfügbar sein, bevor getestet werden kann.

## CLAUDE.md Sync

`KIKA/CLAUDE.md` ist die Quelle. `hkr-deploy/CLAUDE.md` ist eine Kopie (versioniert).

```bash
cp KIKA/CLAUDE.md hkr-deploy/CLAUDE.md
cd hkr-deploy && git add CLAUDE.md && git commit -m "docs: CLAUDE.md sync"
```

## Playwright-Tests nach Deploy

- LAN: `http://192.168.2.7:8090` (bevorzugt)
- Tailscale-Fallback: `http://100.71.14.29:8090`
- Nach krebs-web Rebuild: Hard Refresh im Browser (Strg+Shift+R) — Browser cached alte JS-Chunks
- Build-Version unten rechts im UI verifizieren (Format: `YYYYMMDD-HHMM`)
