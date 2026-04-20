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
| F2 | Schema-Versionsauswahl (Multi-XSD) | ✅ Done | XSD_MAP + ReportType Enum, end-to-end implementiert |
| F3 | Streaming-Upload via Docker Volume | ✅ Done | Kein base64 mehr, kein Timeout |
| F4 | Schema 3.0.4_RKI einbinden | ✅ Done | Neue XSD von HKR, April 2024 |
| F5 | Willkommensseite mit Prozess-Stepper | ✅ Done | Hamburg CD, 4 Schritte |
| F6 | Upload-Fortschrittsanzeige (Rote Rose) | ✅ Done | Animierte SVG-Rose |
| F7 | Importbericht (Kennzahlen-Cards) | ✅ Done | 4 Kacheln nach Import, distinct patient_id/tumor_id, median age |
| F8 | Datei-Dialog-Fix (Drop-Zone Klick) | ✅ Done | label[htmlFor] + sr-only input (Browser-kompatibel) |
| F9 | XSD-Fehlermeldung anzeigen | ✅ Done | Technische Details + Handlungshinweis im UI sichtbar |
| F10 | Schema-Auto-Erkennung aus XML | ✅ Done | Dropdown entfernt, client-seitig aus XML-Header erkannt, Badge-Feedback (20260419-1412) |
| F11 | Fehlerkategorie Schema-Versions-Mismatch | ✅ Done | Falschklassifizierung als invalid_code_value korrigiert via Path-Check |
| F12 | Build-Version-Anzeige im UI | ✅ Done | NEXT_PUBLIC_BUILD_VERSION via Docker ARG eingebacken |
| F13 | Validierungsfortschritt-Animation | 📋 Planned (Prio 6) | Blütenblätter korrelieren mit Validierungsfortschritt |
| F14 | Bulk Upload (bis zu 30 Dateien) | ✅ Done | Tab-Toggle, Rosen-Garten, N=3 parallel, CSV-Log — deployed in 20260420-0611 |
| F15 | Deploy-Skript auf ubuntu-ai | ✅ Done | deploy.sh web/api/all — deployed in 20260419-1434 |
| B1 | R-Umgebungs-URL zeigt localhost im Airgap | 🐛 Open | NEXT_PUBLIC_CODE_SERVER_URL wird zur Build-Zeit eingebettet → Fallback localhost:8081. Fix: window.location.hostname dynamisch nutzen. Gemeldet von Annemarie 2026-04-20 |

---

## Feature 1: cTNM-Bug-Fix ✅

**Problem:** Der Import-Worker crashte, wenn eine XML-Datei pTNM enthielt aber kein cTNM.
Der Processor hat bedingungslos auf beide TNM-Blöcke zugegriffen.

**Fix:** Beide Parsing-Blöcke (cTNM und pTNM) werden mit `if ... is not None` abgesichert.

**Getestet mit:** `oBDS_test_5patienten.xml` (5 Patienten, verschiedene TNM-Kombinationen,
darunter pTNM-only und pTNM mit y/r/a-Symbolen).

---

## Feature 2: Schema-Versionsauswahl (Multi-XSD) ✅

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
- [x] Dropdown zeigt alle verfügbaren Schema-Versionen
- [x] Standard ist die neueste Version (3.0.4_RKI)
- [x] Import validiert gegen die gewählte Version
- [x] Ältere Dateien (3.0.0.8a) importieren weiterhin fehlerfrei
- [x] Neue XSD-Version kann durch Datei + Enum-Eintrag ergänzt werden, ohne weiteren Code

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
*Zuletzt aktualisiert: 2026-04-20 — B1 R-Umgebungs-URL Airgap-Bug gemeldet von Annemarie*

---

## Feature 5: Willkommensseite mit Prozess-Stepper ✅

### Situation
Das aktuelle Frontend zeigt sofort die Upload-Seite ohne Kontext. Neue Nutzer
wissen nicht, was als nächstes kommt oder wo sie im Prozess stehen.

### Complication
Nicht-technikaffine Registerbenutzer brauchen eine klare Orientierung:
Was muss ich tun? Was passiert nach dem Upload? Bin ich fertig?

### Question
**Wie geben wir dem Nutzer einen sofortigen Überblick über den Gesamtprozess
und zeigen transparent, in welchem Schritt er sich befindet?**

### Implementierung
- Horizontaler Stepper oben: Upload → Validierung → Import → Ergebnis
- Aktiver Schritt: Navy #003063, inaktiv: #D8D8D8, Fehler: #E10019
- Willkommens-Headline mit kurzer Prozessbeschreibung
- Hamburg Corporate Design (Lato, Navy/Rot/Grau)

### Acceptance Criteria
- [x] Stepper sichtbar auf allen Upload-Seiten
- [x] Aktiver Schritt klar erkennbar
- [x] Verstaendlich ohne IT-Kenntnisse

---

## Feature 6: Upload-Fortschrittsanzeige (Animierte rote Rose) ✅

### Situation
Beim Upload großer XML-Dateien (bis 200 MB) gibt es kein visuelles Feedback.
Der Nutzer sieht eine leere Seite und weiß nicht ob etwas passiert.

### Complication
Ein klassischer Ladebalken ist funktional aber uninspirierend. KIKA soll sich
als modernes, einladendes System anfuehlen.

### Question
**Wie zeigen wir den Upload-Fortschritt auf eine Art, die informativ ist
und gleichzeitig den Charakter des Systems unterstreicht?**

### Implementierung
- Animierte SVG-Rose waechst mit dem Upload-Fortschritt (0–100%)
- Farbe: Hamburg-Rot #E10019 (Blume), Gruen (Stiel/Blaetter)
- Technik: stroke-dasharray/stroke-dashoffset, gesteuert durch XHR-Progress
- Zusaetzlich: MB-Zaehler als Text (4,2 MB von 18,7 MB)
- Bei 100%: Rose vollstaendig geoeffnet, Animation haelt an

### Acceptance Criteria
- [x] Rose waechst sichtbar mit dem Fortschritt
- [x] MB-Zaehler aktualisiert sich in Echtzeit
- [x] Funktioniert bei Dateien bis 200 MB ohne Timeout

---

## Feature 7: Importbericht (Kennzahlen-Cards nach Import) ✅

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
- [x] 3-4 Kennzahlen-Cards mit echten Daten aus der DB
- [x] Medianes Alter, Min/Max sichtbar
- [x] Diagnosejahre-Spanne sichtbar
- [x] "R-Umgebung" Button prominent und funktional
- [x] Verstaendlich ohne IT-Kenntnisse

---

## Feature 8: Datei-Dialog-Fix (Drop-Zone Klick) ✅

### Situation
Die Upload-Zone zeigt "XML-Datei hier ablegen oder klicken".
Klicken oeffnet aber keinen Datei-Oeffnen-Dialog.

### Complication
Nutzer ohne Drag-and-Drop-Erfahrung (typisch in Behoerden) erwarten,
dass ein Klick auf die Zone den System-Dateidialog oeffnet.
Das ist aktuell nicht zuverlaessig.

### Ursache
Das versteckte `input[type=file]` wird durch programmatisches `.click()`
in bestimmten Browsern (Chrome Security-Policy) blockiert, wenn der Aufruf
nicht direkt aus einem User-Gesture-Event stammt.

### Fix
`<label htmlFor="file">` umschließt die gesamte Drop-Zone.
Das `input[type=file]` bekommt `className="sr-only"` (visuell versteckt,
aber im DOM sichtbar) — Browser öffnen den Dialog nativ ohne .click().

### Acceptance Criteria
- [x] Klick irgendwo in die Drop-Zone oeffnet den System-Dateidialog
- [x] Drag and Drop funktioniert weiterhin
- [x] Funktioniert in Chrome, Firefox und Edge

---

## Feature 9: XSD-Fehlermeldung anzeigen 📋

**Problem:** Bei XSD-Validierungsfehler wird `additional_info` nicht befüllt.
Das Frontend zeigt einen generischen Fehler ohne Details.

**Lösung:**
- import-worker: Exception-Text (XSD-Fehlermeldung) in `additional_info` schreiben
- Frontend: `additional_info` auslesen und im Fehler-Banner darstellen

**Technischer Ansatz:**
- import-worker: lxml-Exception-Text in `additional_info` speichern
- import-worker: Fehlertyp regelbasiert kategorisieren (kein KI) — `if/elif` auf Schlüsselwörter
- Frontend: technische Fehlermeldung anzeigen (für IT/Admin)
- Frontend: kategorisierten Handlungshinweis anzeigen (für Mediziner ohne Technik-Hintergrund)

**Fehlerkategorien (regelbasiert):**

| Schlüsselwort in lxml-Fehler | Angezeigter Hinweis |
|------------------------------|---------------------|
| `not expected` / `not allowed` | "Bitte prüfen Sie, ob die richtige Schema-Version (z. B. 3.0.4) im Dropdown ausgewählt ist." |
| `not facet-valid` / `enumeration` | "Ein Codierwert in der Datei ist ungültig. Bitte prüfen Sie die betroffene Stelle in der Quelldatei." |
| `not complete` / `missing` | "Ein Pflichtfeld fehlt in der Datei. Bitte prüfen Sie die Vollständigkeit des Meldebogens." |
| `pattern-valid` / `pattern` | "Ein Feld hat das falsche Format (z. B. Datum). Erwartet wird meist JJJJ-MM-TT." |
| `namespace` | "Die Datei scheint kein gültiger oBDS-Meldebogen zu sein. Bitte prüfen Sie die Dateiherkunft." |
| (kein Treffer) | "Die Datei enthält einen unbekannten Fehler. Bitte wenden Sie sich an Ihre IT-Stelle." |

**Acceptance Criteria:**
- [x] Bei ungültigem XML ist `additional_info` in der DB gefüllt (lxml-Fehlermeldung)
- [x] Frontend zeigt technische Fehlermeldung an (für Admins)
- [x] Frontend zeigt Titel "Validierung fehlgeschlagen" statt "Import fehlgeschlagen" bei XSD-Fehler
- [x] Frontend zeigt kategorisierten Handlungshinweis an (prominent, für Mediziner)
- [x] Bei gültigem XML bleibt `additional_info` null

**Hinweis:** Schema-Versions-Mismatch (`Schema_Version='3.0.4_RKI': value must be one of [...]`)
wird noch als `invalid_code_value` statt `wrong_schema_version` klassifiziert → F11.

---

## Feature 10: Schema-Auto-Erkennung aus XML 📋

### Situation
Der Nutzer wählt die Schema-Version manuell im Dropdown. Eine XML-Datei enthält
das Attribut `Schema_Version='3.0.4_RKI'` direkt im `<oBDS>`-Root-Element.

### Complication
Wählt der Nutzer die falsche Version, erhält er einen kryptischen XSD-Fehler
(z. B. `value must be one of ['3.0.0.8a_RKI']`). Die korrekte Version steht
aber bereits in der Datei selbst — das System ignoriert sie bisher.

### Question
**Wie können wir die Schema-Version automatisch aus der XML-Datei lesen
und dem Nutzer einen gezielten, handlungsorientierten Hinweis geben
oder die Version direkt vorauswählen?**

### Geplante Implementierung

**Ansatz A (Hinweis, minimal-invasiv):**
- import-worker: Vor XSD-Validierung `Schema_Version`-Attribut aus XML lesen
- Falls Version ≠ gewählter ReportType: `additional_info` mit gezieltem Hinweis befüllen
  z. B. `"Ihre Datei deklariert Schema-Version 3.0.4_RKI. Bitte wählen Sie diese Version im Dropdown."`
- `error_type = "wrong_schema_version"`

**Ansatz B (Auto-Select, komfortabler):**
- API: XML-Datei auf `Schema_Version`-Attribut prüfen, Version als Antwort zurückgeben
- Frontend: Dropdown automatisch auf erkannte Version setzen, Nutzer kann überschreiben

**Empfehlung:** Ansatz A zuerst (kein API-Refactoring nötig), Ansatz B als Folge-Feature.

### Betroffene Dateien
- `hkr-import-worker/processor/rki_report_processor.py` — Schema_Version lesen, Hinweis befüllen
- `hkr-krebs-web/src/components/UploadSection.tsx` — Hinweis für `wrong_schema_version` anzeigen

### Acceptance Criteria
- [ ] import-worker liest `Schema_Version`-Attribut aus dem XML-Root-Element
- [ ] Bei Versions-Mismatch: `error_type = "wrong_schema_version"`, Hinweis mit erkannter Version
- [ ] Frontend zeigt: "Ihre Datei deklariert Version X. Bitte wählen Sie diese im Dropdown."
- [ ] Bei nicht vorhandenem `Schema_Version`-Attribut: kein Absturz, normaler Fehler-Pfad

---

## Feature 11: Fehlerkategorie Schema-Versions-Mismatch korrigieren ✅

### Situation
Bei einer falsch gewählten Schema-Version schlägt die XSD-Validierung am
`Schema_Version`-Attribut des Root-Elements fehl. Das oBDS_3.0.0.8a-Schema
definiert dieses Attribut als feste Enumeration (`"3.0.0.8a_RKI"`). Wird eine
3.0.4-Datei dagegen validiert, erzeugt xmlschema einen Fehler mit `"enumeration"`
im `reason`-Text.

### Complication
`_categorize_xsd_error()` trifft auf `enumeration` und klassifiziert den Fehler
als `invalid_code_value`. Im Frontend erscheint "Ein Codierwert ist ungültig" —
korrekt wäre "falsche Schema-Version, bitte Dropdown prüfen".

### Question
**Wie stellen wir sicher, dass ein Schema-Versions-Mismatch als
`wrong_schema_version` und nicht als `invalid_code_value` eingestuft wird?**

### Implementierung

**Path-first Strategie:** xmlschema liefert neben dem `reason`-Text auch einen
`path`-Wert, der den XML-Pfad des fehlerhaften Attributs enthält (z. B. `@Schema_Version`).
Dieser Path ist stabil und unabhängig von xmlschema-Versionen.

```python
# In _categorize_xsd_error(), vor den reason-basierten Checks:
p = path.lower()
if "schema_version" in p:
    cat  = "wrong_schema_version"
    hint = ("Die Schema-Version der Datei stimmt nicht mit der ausgewaehlten Version "
            "ueberein. Bitte waehlen Sie im Dropdown die passende Schema-Version aus.")
```

Die bestehende `reason`-basierte Logik bleibt als Fallback unverändert.

### Betroffene Dateien
- `hkr-import-worker/processor/rki_report_processor.py` — `_categorize_xsd_error()` L40–74

### Acceptance Criteria
- [x] Schema_Version-Fehler → `category = "wrong_schema_version"` statt `invalid_code_value`
- [x] Hinweis verweist explizit auf das Dropdown
- [x] Echte `invalid_code_value`-Fehler (Enum-Fehler an anderen Pfaden) bleiben korrekt klassifiziert

---

## Sprint: V1.0 Release-Kandidat (2026-04-16) ✅ Abgeschlossen

**Ergebnis:** Alle P1-Punkte erledigt, Stack getestet, auf GitLab gepusht.
Annemarie und Kolleginnen testen aktuell vor Ort.

- [x] S1: F8 Datei-Dialog verifizieren (Drop-Zone Klick oeffnet System-Dialog)
- [x] S2: F2 import-worker XSD-Auswahl (korrektes Schema je nach Dropdown-Wahl)
- [x] S3: Fehlerdarstellung bei ungueltigem XML (roter Zustand, Fehlermeldung sichtbar)
- [x] S7: GitLab Push aller Repos (hkr-krebs-web, hkr-deploy, hkr-import-worker, hkr-krebs-api)

---

## Sprint: V1.1 Vor-Ort-Test (2026-04-16)

**Ziel:** Importstatistik und prominenter R-Umgebung-Button.

**Prio 1 — Muss rein:**
- [x] S4: Importstatistik nach erfolgreichem Upload anzeigen (Kennzahlen-Cards: Patienten, Fälle, Diagnosejahre, Medianes Alter)
- [x] S5: Prominenter "R-Umgebung analysieren" Button auf Ergebnisseite

**Prio 2 — Infrastruktur:**
- [ ] S6: Performanceanalyse deploy.all-Skript (Laufzeit messen, Bottlenecks identifizieren)

**Definition of Done:**
- S4 und S5 im Frontend sichtbar nach erfolgreichem Import
- Kennzahlen kommen aus echter DB-Abfrage (kein Dummy)
- Vor-Ort-Test durch Annemarie bestanden

---

## Feature 12: Build-Version-Anzeige im UI ✅

### Situation
Nach einem Deployment ist unklar ob der Browser noch die alte oder schon die neue Version laed.

### Complication
Verwirrung beim Testen: Man sieht eine falsche UI, weiss aber nicht ob es ein Bug oder ein Cache-Problem ist.

### Question
**Wie sieht man auf einen Blick, welche Build-Version gerade im Browser laeuft?**

### Konzept
- Build-Zeitstempel (YYYYMMDD-HHMM) wird beim Docker-Build als `NEXT_PUBLIC_BUILD_VERSION` eingebacken
- Kleine Versionsanzeige in der unteren rechten Ecke der Seite (z.B. `v2026-04-19.1`)
- Claude nennt die erwartete Versionsnummer nach jedem Deployment

### Acceptance Criteria
- [x] Versionsnummer ist im UI sichtbar (klein, unaufdringlich)
- [x] Stimmt mit dem Build-Zeitpunkt ueberein
- [x] Wird beim naechsten Deploy automatisch aktualisiert

---

## Feature 13: Validierungsfortschritt-Animation (Prio 6)

### Situation
Die XSD-Validierung dauert bei grossen Dateien 10-30 Sekunden.
Die Blütenblätter der Rose erscheinen sofort, dann gibt es 20+ Sekunden keine Veraenderung.

### Complication
Der Nutzer weiss nicht ob das System noch arbeitet oder haengt.

### Question
**Koennen wir die Blütenblätter mit dem Validierungsfortschritt korrelieren?**

### Konzept (offen)
- Option A: Fortschrittsschaetzung anhand Dateigroesse (grob, keine echten Daten)
- Option B: Import-Worker sendet Streaming-Events (BullMQ Progress API), Frontend pollt
- Option C: Animierter Pulse/Shimmer waehrend Validierung ohne echter Fortschrittsdaten

**Empfehlung:** Option B wenn der Worker-Umbau vertretbar ist, sonst Option C als Quick-Win.

### Acceptance Criteria
- [ ] Blütenblätter oeffnen sich sichtbar waehrend der Validierung (nicht sofort fertig)
- [ ] Nutzer erkennt dass das System aktiv arbeitet

---

## Feature 14: Bulk Upload (bis zu 30 Dateien)

### Situation
Manche Krebsregister liefern bis zu 30 oBDS-XML-Dateien pro Lieferung.
Aktuell muss jede Datei einzeln hochgeladen werden.

### Complication
30 manuelle Upload-Zyklen sind nicht praxistauglich.

### Question
**Wie koennen mehrere Dateien in einem Durchgang hochgeladen, validiert und importiert werden?**

### Konzept (besprochen 2026-04-19)
**Dateiauswahl:**
- Filepicker erlaubt Mehrfachauswahl (`multiple`-Attribut)
- Alternativ: mehrfaches Drag-and-Drop oder Ordner-Upload

**Parallelisierung:**
- Waehrend Datei 1 validiert/importiert wird, startet Upload von Datei 2
- Maximal N parallele Imports (konfigurierbar, Vorschlag N=3)
- BullMQ-Queue verarbeitet Jobs parallel

**Ergebnis-Log:**
- Pro Datei: Status (Erfolg/Fehler), Fehlermeldung falls vorhanden, Zeitstempel
- Gesamtzusammenfassung: X von Y erfolgreich, Z fehlgeschlagen
- Log als Download-Option (CSV oder TXT)

**UI:**
- Fortschrittsliste: Dateiname | Status-Icon | Ergebnis
- Kennzahlen-Gesamtbericht am Ende (aggregiert ueber alle Dateien)

### Acceptance Criteria
- [ ] Mehrfachauswahl im Filepicker moeglich
- [ ] Dateien werden sequenziell oder pipeline-parallelisiert verarbeitet
- [ ] Log-Datei mit Ergebnis pro Datei erzeugt
- [ ] Gesamtbericht nach Abschluss aller Importe

---

## Feature 15: Deploy-Skript auf ubuntu-ai (deploy.sh)

### Situation
Jedes Deployment erfordert mehrere manuelle SSH-Befehle: git stash, git pull, docker build (mit korrektem BUILD_VERSION-Timestamp), docker compose up. Die Befehle sind fehleranfällig (z.B. fehlerhaftes `$(date ...)` Escaping) und muessen jedes Mal neu zusammengesetzt werden.

### Complication
Wiederkehrende Fehler: BUILD_VERSION leer weil Shell-Expansion auf falscher Seite passiert, git-Konflikte weil ubuntu-ai lokale Aenderungen hat, falscher Compose-Projektname. Jeder Deploy kostet Debugging-Zeit fuer dieselben Probleme.

### Question
**Wie koennen wir einen einzelnen Befehl definieren der zuverlässig alle Services auf ubuntu-ai aktualisiert?**

### Konzept
Shell-Skript `deploy.sh` direkt auf ubuntu-ai (im hkr-deploy-Repo), das per `ssh ubuntu-ai ./deploy.sh [web|api|all]` aufrufbar ist:

```bash
# Beispiel-Aufruf:
ssh christopher-mangels@100.71.14.29 "~/deploy.sh web"
ssh christopher-mangels@100.71.14.29 "~/deploy.sh api"
ssh christopher-mangels@100.71.14.29 "~/deploy.sh all"
```

**Was das Skript intern macht:**
- `git stash` vor pull (verhindert Konflikte bei lokalen Aenderungen)
- `git pull` im richtigen Repo-Verzeichnis
- `docker build` mit `BUILD_VERSION=$(date +%Y%m%d-%H%M)` (lokal auf ubuntu-ai, kein Escaping-Problem)
- `docker compose -p hkr-clean up -d --force-recreate --no-build <service>`
- Ausgabe: `✅ Version: YYYYMMDD-HHMM deployed`

### Acceptance Criteria
- [x] `~/deploy.sh web` aktualisiert krebs-web vollstaendig (pull + build + restart)
- [x] `~/deploy.sh api` aktualisiert krebs-api vollstaendig
- [x] `~/deploy.sh all` aktualisiert beide Services (web + api + worker)
- [x] BUILD_VERSION wird korrekt gesetzt und ist im UI sichtbar (getestet: 20260419-1434)
- [x] Bei git-Konflikten: automatisch stash, dann pull
- [x] Skript liegt im hkr-deploy-Repo und ist versioniert
