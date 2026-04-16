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
| F2 | Schema-Versionsauswahl (Multi-XSD) | 📋 Planned | Dropdown fuer beide XSD-Versionen |
| F3 | Streaming-Upload via Docker Volume | ✅ Done | Kein base64 mehr, kein Timeout |
| F5 | Willkommensseite mit Prozess-Stepper | 📋 Planned | Hamburg CD, 4 Schritte |
| F6 | Upload-Fortschrittsanzeige (Rote Rose) | 📋 Planned | Animierte SVG-Rose |
| F7 | Ergebnis-Dashboard (Kennzahlen-Cards) | 📋 Planned | 4 Kacheln nach Import |
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

---

## Feature 5: Willkommensseite mit Prozess-Stepper 📋

### Situation
Das aktuelle Frontend zeigt sofort die Upload-Seite ohne Kontext. Neue Nutzer
wissen nicht, was als nächstes kommt oder wo sie im Prozess stehen.

### Complication
Nicht-technikaffine Registerbenutzer brauchen eine klare Orientierung:
Was muss ich tun? Was passiert nach dem Upload? Bin ich fertig?

### Question
**Wie geben wir dem Nutzer einen sofortigen Überblick über den Gesamtprozess
und zeigen transparent, in welchem Schritt er sich befindet?**

### Geplante Implementierung
- Horizontaler Stepper oben: Upload → Validierung → Import → Ergebnis
- Aktiver Schritt: Navy #003063, inaktiv: #D8D8D8, Fehler: #E10019
- Willkommens-Headline mit kurzer Prozessbeschreibung
- Hamburg Corporate Design (Lato, Navy/Rot/Grau)

### Acceptance Criteria
- [ ] Stepper sichtbar auf allen Upload-Seiten
- [ ] Aktiver Schritt klar erkennbar
- [ ] Verstaendlich ohne IT-Kenntnisse

---

## Feature 6: Upload-Fortschrittsanzeige (Animierte rote Rose) 📋

### Situation
Beim Upload großer XML-Dateien (bis 200 MB) gibt es kein visuelles Feedback.
Der Nutzer sieht eine leere Seite und weiß nicht ob etwas passiert.

### Complication
Ein klassischer Ladebalken ist funktional aber uninspirierend. KIKA soll sich
als modernes, einladendes System anfuehlen.

### Question
**Wie zeigen wir den Upload-Fortschritt auf eine Art, die informativ ist
und gleichzeitig den Charakter des Systems unterstreicht?**

### Geplante Implementierung
- Animierte SVG-Rose waechst mit dem Upload-Fortschritt (0–100%)
- Farbe: Hamburg-Rot #E10019 (Blume), Gruen (Stiel/Blaetter)
- Technik: stroke-dasharray/stroke-dashoffset, gesteuert durch XHR-Progress
- Zusaetzlich: MB-Zaehler als Text (4,2 MB von 18,7 MB)
- Bei 100%: Rose vollstaendig geoeffnet, Animation haelt an

### Acceptance Criteria
- [ ] Rose waechst sichtbar mit dem Fortschritt
- [ ] MB-Zaehler aktualisiert sich in Echtzeit
- [ ] Funktioniert bei Dateien bis 200 MB ohne Timeout

---

## Feature 7: Importbericht (Kennzahlen-Cards nach Import) 📋

### Situation
Nach erfolgreichem Import sieht der Nutzer nur eine Erfolgsmeldung.
Es gibt keine Zusammenfassung was importiert wurde.

### Complication
Der Nutzer muss manuell pruefen ob er die richtige Datei hochgeladen hat,
ob die Fallzahlen plausibel sind und ob die Daten in die R-Umgebung
uebernommen wurden.

### Question
**Wie zeigen wir dem Nutzer nach dem Import auf einen Blick die wichtigsten
Kennzahlen — und leiten ihn nahtlos in die R-Umgebung weiter?**

### Konzept (besprochen 2026-04-15)
Die Ergebnisseite (Schritt 4) heisst "Importbericht" und zeigt:

**Kennzahlen-Cards (3-4 Kacheln, Icon + Zahl):**
- Anzahl importierter Patienten
- Diagnosejahre (z.B. 2019–2024)
- Medianes Alter (+ Min/Max)
- Anzahl Tumormeldungen

**Zweck:** Der Nutzer erkennt sofort ob die richtigen Daten importiert wurden
und ob die Zahlen realistisch sind — ohne die R-Umgebung oeffnen zu muessen.

**R-Umgebung Button:**
- Prominenter Navy-Button: "Daten in R-Umgebung analysieren"
- Direkt-Link auf http://192.168.2.7:8081/
- Erklaerung: "Die importierten Daten stehen jetzt in der R-Umgebung bereit."

**Datenquelle:** API-Endpoint der die Kennzahlen aus der DB abfragt
(COUNT patients, MIN/MAX/MEDIAN age, MIN/MAX diagnosis year) — bezogen
auf die zuletzt importierte Batch-ID oder den letzten Import-Zeitstempel.

### Geplante Implementierung
1. Neuer API-Endpoint: GET /api/report/summary -> { patients, years, median_age, ... }
2. Neue Seite: /result (oder Ergebnis-State in UploadSection)
3. KennzahlenCard-Komponente: Icon + grosse Zahl + Label
4. "In R-Umgebung analysieren" Button prominent platziert

### Acceptance Criteria
- [ ] 3-4 Kennzahlen-Cards mit echten Daten aus der DB
- [ ] Medianes Alter, Min/Max sichtbar
- [ ] Diagnosejahre-Spanne sichtbar
- [ ] "R-Umgebung" Button prominent und funktional
- [ ] Verstaendlich ohne IT-Kenntnisse



---

## Feature 8: Datei-Dialog-Fix (Drop-Zone Klick) 📋

### Situation
Die Upload-Zone zeigt "XML-Datei hier ablegen oder klicken".
Klicken oeffnet aber keinen Datei-Oeffnen-Dialog.

### Complication
Nutzer ohne Drag-and-Drop-Erfahrung (typisch in Behoerden) erwarten,
dass ein Klick auf die Zone den System-Dateidialog oeffnet.
Das ist aktuell nicht zuverlaessig.

### Ursache
Das versteckte input[type=file] wird durch das Label-Click-Event
nicht korrekt ausgeloest, weil das Label interaktive Kindelemente
enthaelt (DragOver/DragLeave Handler).

### Fix
useRef auf das input-Element, expliziter inputRef.current.click()
im onClick-Handler der Zone statt implizitem Label-for-Binding.

### Acceptance Criteria
- [ ] Klick irgendwo in die Drop-Zone oeffnet den System-Dateidialog
- [ ] Drag and Drop funktioniert weiterhin
- [ ] Funktioniert in Chrome, Firefox und Edge

---

## Sprint: V1.0 Release-Kandidat (2026-04-16)

**Ziel:** Erste pushbare Version auf GitHub — Annemarie und Kolleginnen können
vor Ort testen.

**Prio 1 — Muss rein:**
- [ ] S1: F8 Datei-Dialog verifizieren (Drop-Zone Klick oeffnet System-Dialog)
- [ ] S2: F2 import-worker XSD-Auswahl (korrektes Schema je nach Dropdown-Wahl)
- [ ] S3: Fehlerdarstellung bei ungueltigem XML (roter Zustand, Fehlermeldung sichtbar)

**Prio 2 — Soll rein:**
- [ ] S4: Prüfsummen/Importstatistik nach erfolgreichem Upload in Postgres speichern
- [ ] S5: Prominenter "R-Umgebung" Button auf Ergebnisseite

**Prio 3 — Nice to have:**
- [ ] S6: VS Code Theme hell + barrierefrei (Schriftgroesse, Kontrast)
- [ ] S7: GitHub Push aller Repos (hkr-krebs-web, hkr-deploy, hkr-import-worker, hkr-krebs-api)

**Definition of Done:**
- Alle P1-Punkte gruener Haken
- Stack neu gebaut und getestet mit (a) gueltiger XML und (b) absichtlich ungueltigem XML
- Kein bekannter Crash im import-worker
- Auf GitHub gepusht

---

## F9 — XSD-Fehlermeldung anzeigen (Backlog)

**Problem:** Bei XSD-Validierungsfehler wird  nicht befüllt.
Das Frontend zeigt einen generischen Fehler ohne Details.

**Lösung:**
- import-worker: Exception-Text (XSD-Fehlermeldung) in  schreiben
- Frontend:  aus  auslesen und im Fehler-Banner darstellen

**Acceptance Criteria:**
- [ ] Bei ungültigem XML ist `additional_info` in der DB gefüllt (XSD-Fehlermeldung)
- [ ] Frontend zeigt die Fehlermeldung im roten Fehler-Banner an
- [ ] Bei gültigem XML bleibt `additional_info` null
