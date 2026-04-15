# PRD: KIKA — HKR Import-System (Hamburgisches Krebsregister)

## Produkt-Vision

KIKA ist ein webbasiertes Import-System für das Hamburgisches Krebsregister (HKR).
Es ermöglicht den strukturierten Upload, die Validierung und den Import von
oBDS_RKI-konformen XML-Dateien in die HKR-Datenbank. Das System läuft vollständig
in einer air-gapped Docker-Umgebung auf einem Linux-Server im HKR-Intranet.

---

## Status: Features

| # | Feature | Status | Anmerkungen |
|---|---------|--------|-------------|
| F1 | cTNM-Bug-Fix (Crash bei fehlendem cTNM) | ✅ Done | pTNM ohne cTNM wird korrekt verarbeitet |
| F2 | Schema-Versionsauswahl (Multi-XSD) | 📋 Planned | Beschreibung s.u. |
| F3 | Streaming-Upload via Docker Volume | ✅ Done | Kein base64 mehr, kein Timeout |
| F4 | Schema 3.0.4_RKI einbinden | ✅ Done | Neue XSD von HKR, April 2024 |

---

## Feature 1: cTNM-Bug-Fix ✅

**Problem:** Der Import-Worker crashte, wenn eine XML-Datei pTNM enthielt aber kein cTNM.
Der Processor hat bedingungslos auf beide TNM-Blöcke zugegriffen.

**Fix:** Beide Parsing-Blöcke (cTNM und pTNM) werden mit `if ... is not None` abgesichert.

**Getestet mit:** `oBDS_test_5patienten.xml` (5 Patienten, verschiedene TNM-Kombinationen,
darunter pTNM-only und pTNM mit y/r/a-Symbolen).

---

## Feature 2: Schema-Versionsauswahl (Multi-XSD) 📋

### Situation
Das HKR liefert XML-Dateien im oBDS_RKI-Format. Die zugrundeliegenden XSD-Schemas
werden gelegentlich aktualisiert (zuletzt: 3.0.0.8a → 3.0.4). Aktuell ist die
zu verwendende Schema-Version hart im Code verankert.

### Complication
Wenn das HKR eine neue Schema-Version einführt, muss die Änderung im Code vorgenommen
werden. Es gibt keine Möglichkeit, ältere Dateien (die gegen eine ältere XSD valide
waren) erneut zu importieren, ohne die Code-Änderung rückgängig zu machen.

### Question
**Wie können wir neue XSD-Versionen ohne Code-Änderung ergänzen, und dem Nutzer
ermöglichen, beim Upload auszuwählen, gegen welche Schema-Version die Datei
validiert werden soll?**

**Out-of-Scope:** Automatische Schema-Erkennung aus der XML-Datei heraus.

### Geplante Implementierung

**Architektur-Ansatz: XSD_MAP + ReportType Enum**

1. **`hkr-import-worker/processor/rki_report_processor.py`**
   ```python
   XSD_MAP = {
       ReportType.XML_oBDS_3_0_0_8a_RKI: 'schemas/oBDS_v3.0.0.8a_RKI_Schema.xsd',
       ReportType.XML_oBDS_3_0_4_RKI:    'schemas/oBDS_v3.0.4_RKI_Schema.xsd',
   }
   # execute() erhält report_type als Parameter und wählt die XSD dynamisch:
   xsd_path = XSD_MAP[report_type]
   ```

2. **`hkr-import-worker/main_db/enums/report_type.py`**
   ```python
   class ReportType(enum.Enum):
       XML_oBDS_3_0_0_8a_RKI = 'XML:oBDS_3.0.0.8a_RKI'  # historisch
       XML_oBDS_3_0_4_RKI    = 'XML:oBDS_3.0.4_RKI'      # aktuell
   ```

3. **`hkr-krebs-api/app/main_db/enums/report_type.py`**
   Beide Enum-Werte eintragen (analog zum import-worker).

4. **`hkr-krebs-web/src/components/UploadSection.tsx`**
   Dropdown-Menü mit allen verfügbaren Schema-Versionen:
   ```
   [XML:oBDS_3.0.4_RKI   ▾]   ← Standard / neueste Version oben
   [XML:oBDS_3.0.0.8a_RKI]
   ```

5. **Erweiterbarkeit:** Neue Schema-Version hinzufügen = XSD-Datei ins `schemas/`-
   Verzeichnis kopieren + Enum-Wert + Map-Eintrag ergänzen. Kein weiterer Code nötig.

### Acceptance Criteria
- [ ] Dropdown zeigt alle verfügbaren Schema-Versionen
- [ ] Standard ist die neueste Version (3.0.4_RKI)
- [ ] Import validiert gegen die gewählte Version
- [ ] Ältere Dateien (3.0.0.8a) importieren weiterhin fehlerfrei
- [ ] Neue XSD-Version kann durch Datei + Enum-Eintrag ergänzt werden, ohne weiteren Code

---

## Feature 3: Streaming-Upload via Docker Volume ✅

**Problem:** Base64-kodierter XML-Inhalt im JSON-Body hat zu Gunicorn-Timeouts bei
größeren Dateien geführt. Die gesamte Datei musste im Arbeitsspeicher gehalten werden.

**Fix:**
- Frontend: `FormData` mit `UploadFile` (multipart/form-data)
- API: Chunk-weises Schreiben in `/data/uploads/` (1 MB Chunks)
- Worker: Liest die Datei direkt vom Dateisystem-Pfad
- Docker: Named Volume `xml-uploads` in beiden Containern gemountet
- nginx: `client_max_body_size 200M`, Timeouts auf 300s hochgesetzt
- Gunicorn: `--timeout 300`

---

## Feature 4: Schema 3.0.4_RKI ✅

**Neue XSD erhalten vom HKR, April 2024.**

**Wesentliche Änderungen gegenüber 3.0.0.8a:**
- Neue Felder: `Sentinel_LK_untersucht`, `Sentinel_LK_befallen`
- Umbenannt: `Anzahl_Tage_ST_Dauer` → `Anzahl_Tage_Bestrahlung_Dauer`
- ICD-Versionsfeld: Statt fester Werteliste jetzt Regex-Pattern (flexibler)
- Schema-Versionsstring: `3.0.0.8a_RKI` → `3.0.4_RKI`

Die neue XSD ist abwärtskompatibel für die im HKR vorhandenen Bestandsdaten.

---

## Technische Rahmenbedingungen

- **Deployment:** Air-gapped Docker-Stack (kein Internet nach Auslieferung)
- **Repos (GitHub, djxmdjxm-Forks):**
  - `hkr-deploy` — Docker Compose, nginx, Volume-Konfiguration
  - `hkr-krebs-api` — FastAPI Upload-Endpoint
  - `hkr-import-worker` — XML-Processor, XSD-Validierung, DB-Import
  - `hkr-krebs-web` — React/TypeScript Frontend
- **DB:** PostgreSQL `krebs`-Datenbank
- **R-Umgebung:** `krebs-code` Container (code-server, Port 8081) für Datenanalyse

---

*Erstellt: 2026-04-15 | Autor: Christopher Mangels / Claude Code (oikos-dev)*
