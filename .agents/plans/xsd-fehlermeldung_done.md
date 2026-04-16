# Plan: F9 - XSD-Fehlermeldung anzeigen

## Situation

Der KIKA Import-Stack verarbeitet XML-Meldedateien in drei Diensten:
- **import-worker** (rki_report_processor.py): validiert XML gegen XSD mit xmlschema, wirft ValueError bei Fehler
- **main.py**: faengt Exception, setzt status=Failure, schreibt nichts in additional_info
- **Frontend** (UploadSection.tsx): wertet nur HTTP-Status-Code aus, zeigt generischen roten Banner

Das DB-Feld additional_info (JSON, nullable) existiert in ReportImport und wird von
GET /api/report/{uid} zurueckgegeben - aber nie befuellt.

Technisches Detail: Der Processor nutzt das Paket xmlschema (nicht lxml).
Die relevante Exception-Klasse ist XMLSchemaValidationError mit dem Attribut .reason,
das den menschenlesbaren Fehlertext enthaelt (z.B. "not expected", "enumeration").

## Complication

Mediziner sehen bei XSD-Fehler nur: Import fehlgeschlagen. Kein Hinweis darauf,
ob das Schema falsch gewaehlt wurde, ein Pflichtfeld fehlt, ein Codierwert ungueltig
ist oder ein anderes Problem vorliegt. Das erzeugt Support-Aufwand und Frustration.

Der Fehlertext steht in XMLSchemaValidationError.reason maschinell lesbar zur Verfuegung
und wird bisher nur geloggt und verworfen.

## Question

Wie koennen wir bei XSD-Validierungsfehlern dem Mediziner eine verstaendliche,
kontextspezifische Fehlermeldung zeigen - ohne KI, regelbasiert, ohne Rebuild
des import-workers (hot-reload aktiv)?

Out-of-Scope:
- Keine Details zu Laufzeitfehlern (DB-Fehler, Netzwerkfehler) - nur XSD-Validierungsfehler
- Kein Mehrfach-Fehlerliste (nur erster Fehler)
- Keine Internationalisierung
- Keine API-Aenderungen (additional_info wird bereits zurueckgegeben)

## Answer - Implementierungsschritte

### Schritt 1: rki_report_processor.py - Exception-Klasse und Kategorisierungsfunktion

Datei: hkr-import-worker/processor/rki_report_processor.py

(a) Neue Exception-Klasse nach den Imports einfuegen:

    class XsdValidationError(Exception):
        def __init__(self, info_dict: dict):
            self.info_dict = info_dict
            super().__init__(info_dict.get("technical_message", "XSD validation error"))

(b) Kategorisierungsfunktion _categorize_xsd_error einfuegen:

    def _categorize_xsd_error(reason: str, path: str) -> dict:
        r = reason.lower()
        # Kategorie und Hint per Keyword-Matching bestimmen:
        if "not expected" in r or "not allowed" in r:
            cat = "wrong_schema_version"
            hint = "Bitte pruefen Sie, ob die richtige Schema-Version (z. B. 3.0.4) im Dropdown ausgewaehlt ist."
        elif "not facet-valid" in r or "enumeration" in r:
            cat = "invalid_code_value"
            hint = "Ein Codierwert in der Datei ist ungueltig. Bitte pruefen Sie die betroffene Stelle."
        elif "not complete" in r or "missing" in r:
            cat = "missing_required_field"
            hint = "Ein Pflichtfeld fehlt in der Datei. Bitte pruefen Sie die Vollstaendigkeit des Meldebogens."
        elif "pattern-valid" in r or "pattern" in r:
            cat = "wrong_format"
            hint = "Ein Feld hat das falsche Format (z. B. Datum). Erwartet wird meist JJJJ-MM-TT."
        elif "namespace" in r:
            cat = "wrong_namespace"
            hint = "Die Datei scheint kein gueltiger oBDS-Meldebogen zu sein. Bitte pruefen Sie die Dateiherkunft."
        else:
            cat = "unknown"
            hint = "Die Datei enthaelt einen unbekannten Fehler. Bitte wenden Sie sich an Ihre IT-Stelle."
        return {
            "error_type": "xsd_validation",
            "category": cat,
            "technical_message": reason,
            "path": path,
            "hint": hint,
        }

(c) Validierungsblock ersetzen (aktuell Zeilen 53-55):

    Vorher:
        if not schema.is_valid(xml_file):
            errors = schema.validate(xml_file)
            raise ValueError(f"XML does not conform to schema: {errors}")

    Nachher:
        errors = list(schema.iter_errors(xml_file))
        if errors:
            first = errors[0]
            info_dict = _categorize_xsd_error(
                reason=first.reason or str(first),
                path=first.path or ""
            )
            raise XsdValidationError(info_dict)

    Hinweis: schema.iter_errors() liefert XMLSchemaValidationError-Objekte mit .reason und .path.
    Der erste Fehler wird kategorisiert und als XsdValidationError geworfen.

### Schritt 2: main.py - additional_info beim Failure setzen

Datei: hkr-import-worker/main.py

(a) Import am Dateianfang ergaenzen:
    from processor.rki_report_processor import XsdValidationError

(b) Exception-Block in process_report_import() erweitern.
    Den XsdValidationError-Block VOR den generischen Exception-Block stellen:

    Vorher:
        except Exception as e:
            logger.error(e)
            report_import.status = ReportImportStatus.Failure

    Nachher:
        except XsdValidationError as e:
            logger.error(
                "XSD validation failed",
                extra={
                    "category": e.info_dict["category"],
                    "path": e.info_dict["path"],
                    "technical_message": e.info_dict["technical_message"],
                }
            )
            report_import.additional_info = e.info_dict
            report_import.status = ReportImportStatus.Failure
        except Exception as e:
            logger.error(e)
            report_import.status = ReportImportStatus.Failure

    Hinweis: Python prueft Exceptions in Reihenfolge. XsdValidationError muss
    zuerst stehen, da es eine Unterklasse von Exception ist.

### Schritt 3: UploadSection.tsx - Polling nach Upload einbauen

Datei: hkr-krebs-web/src/components/UploadSection.tsx

Hintergrund: POST /api/report gibt nur {uid: string} zurueck. Der finale
Import-Status + additional_info steht nur in GET /api/report/{uid}.
Das Frontend muss nach dem Upload pollen.

(a) Neuen State nach den bestehenden useState-Aufrufen hinzufuegen:

    const [additionalInfo, setAdditionalInfo] = useState<{
      hint?: string;
      technical_message?: string;
      category?: string;
    } | null>(null);

(b) handleReset() um setAdditionalInfo(null) erweitern.

(c) Neue Funktion pollImportStatus in der Komponente hinzufuegen (vor handleSubmit):

    const pollImportStatus = (uid: string) => {
      const maxAttempts = 60; // 60 x 2s = 120s Timeout
      let attempts = 0;
      const interval = setInterval(async () => {
        attempts++;
        if (attempts > maxAttempts) {
          clearInterval(interval);
          setUploadState("error");
          setErrorMsg("Zeitueberschreitung: Der Import hat zu lange gedauert.");
          return;
        }
        try {
          const res = await fetch("/api/report/" + uid);
          if (!res.ok) return; // Verbindungsfehler: naechster Versuch
          const data = await res.json();
          if (data.status === "success") {
            clearInterval(interval);
            setUploadState("done");
          } else if (data.status === "failure") {
            clearInterval(interval);
            setAdditionalInfo(data.additional_info ?? null);
            setErrorMsg(data.additional_info?.hint ?? "Import fehlgeschlagen.");
            setUploadState("error");
          }
          // status "created" oder "pending": weiter warten
        } catch (_) { /* Netzwerkfehler: naechster Versuch */ }
      }, 2000);
    };

(d) xhr.onload-Block in handleSubmit anpassen:

    Vorher:
        xhr.onload = () => {
          if (xhr.status >= 200 && xhr.status < 300) {
            setUploadState("importing");
            setTimeout(() => setUploadState("done"), 1500);
          } else { ... }
        };

    Nachher:
        xhr.onload = () => {
          if (xhr.status >= 200 && xhr.status < 300) {
            const { uid } = JSON.parse(xhr.responseText);
            setUploadState("importing");
            pollImportStatus(uid);
          } else { ... }
        };

### Schritt 4: UploadSection.tsx - Fehler-Banner um additionalInfo erweitern

Datei: hkr-krebs-web/src/components/UploadSection.tsx

Im uploadState === "error" JSX-Block den bestehenden statischen Hinweis-Block ersetzen.

Der rote Fehler-Banner (erster div) bleibt unveraendert.

Neue Struktur unterhalb des roten Banners:

(a) Wenn additionalInfo?.hint vorhanden: gelbe Hinweis-Box mit hint-Text:
    - backgroundColor: #FFF8E1, border: 1px solid #F0B429
    - Ueberschrift: "Was koennen Sie tun?" (bold, color: #7A4100)
    - Text: additionalInfo.hint (color: #505050)

(b) Wenn kein hint (additionalInfo === null): bestehenden generischen Hinweis-Block
    unveraendert lassen (Fallback fuer Netzwerkfehler etc.).

(c) Einklappbare technische Details (nur wenn additionalInfo?.technical_message vorhanden):
    <details className="mb-6 text-xs" style={{ color: "#505050" }}>
      <summary className="cursor-pointer font-semibold">Technische Details anzeigen</summary>
      <pre className="mt-2 p-3 rounded overflow-x-auto whitespace-pre-wrap"
        style={{ backgroundColor: "#F2F5F7", border: "1px solid #D8D8D8" }}>
        {additionalInfo.technical_message}
      </pre>
    </details>

Danach folgt unveraendert der "Erneut versuchen"-Button.

### Schritt 5: Rebuild und Neustart

import-worker (kein Rebuild noetig, watchmedo hot-reload aktiv):
  sudo docker restart import-worker

Frontend (Rebuild noetig nach TSX-Aenderungen):
  cd /media/christopher-mangels/4TB/projectClones/kika/hkr-krebs-web
  npm run build  # TypeScript-Fehler ausschliessen
  docker build -t hkr-krebs-web:latest .

## Acceptance Criteria

- [ ] Bei XSD-Fehler: additional_info in DB enthaelt error_type, category, hint, technical_message, path
- [ ] GET /api/report/{uid} gibt befuelltes additional_info-Objekt zurueck
- [ ] Frontend pollt nach Upload /api/report/{uid} alle 2s und reagiert auf status=failure
- [ ] Frontend zeigt hint-Text in gelber Hinweis-Box an
- [ ] Technische Meldung (technical_message) ist einklappbar via details-Element sichtbar
- [ ] Generischer Fallback erscheint wenn additional_info null ist (z.B. Netzwerkfehler)
- [ ] Bei success bleibt der bisherige Ablauf unveraendert
- [ ] Polling-Timeout nach 120s setzt uploadState auf error
- [ ] npm run build schlaegt nicht fehl (TypeScript kompiliert fehlerfrei)

## Bekannte Risiken und Hinweise

1. xmlschema, nicht lxml: Der Processor nutzt das Paket xmlschema.
   XMLSchemaValidationError.reason ist das korrekte Aequivalent zum lxml-Exception-Text.
   Kein Paket-Wechsel noetig.

2. Mehrfach-Fehler: Nur der erste Fehler aus iter_errors() wird gespeichert.
   Ausreichend fuer F9. Erweiterung auf mehrere Fehler ist zukunftiges Feature.

3. Kategorie-Matching Reihenfolge: Der pattern-Check muss nach not facet-valid/enumeration
   stehen, da "pattern" als Substring in anderen Meldungen vorkommen kann.
   Reihenfolge in _categorize_xsd_error ist korrekt so.

4. Polling-Overhead: 2s-Interval ist pragmatisch fuer den Use Case (Import typ. <10s).
   WebSocket-Upgrade ist YAGNI.
