# KIKA Forscher-Handbuch

Praktischer Leitfaden für Wissenschaftler, die in der KIKA-R-Umgebung
Forschungsprojekte auf Krebsregister-Daten durchführen.

> Eine Kopie liegt auch direkt im RStudio-Workspace unter
> `HANDBUCH-FORSCHER.md` — kann offline aus dem Browser geöffnet werden.

---

## Inhaltsverzeichnis

1. [Was ist KIKA und welche Daten gibt es?](#1-was-ist-kika)
2. [Datenbank-Schema verstehen](#2-datenbank-schema)
3. [Ein neues Forschungsprojekt anlegen](#3-neues-projekt)
4. [R-Pakete im Container — was ist da, wie kommt Neues hinzu?](#4-r-pakete)
5. [Eigene Skripte einbringen](#5-eigene-skripte)
6. [Eigene Referenzdaten einbringen](#6-eigene-referenzdaten)
7. [Outputs (Tabellen, Grafiken, Excel) abholen](#7-outputs)
8. [Datenbankverbindung — Beispielcode](#8-datenbankverbindung)
9. [Häufige Fragen](#9-faq)

---

<a id="1-was-ist-kika"></a>
## 1. Was ist KIKA und welche Daten gibt es?

KIKA ist die Analyse-Umgebung des Hamburgischen Krebsregisters. Sie enthält:

- **Eine PostgreSQL-Datenbank `krebs`** mit den importierten oBDS-Meldedaten
  (Patienten, Tumoren, Operationen, Strahlentherapien, Histologien, ...).
- **RStudio im Browser** (Port 8787) mit einer fertig konfigurierten
  R-Umgebung — vorinstallierte Pakete, Datenbankverbindung ohne Login.
- **Referenzdaten** unter `/home/rstudio/referenz/`:
  - `shapefiles/DE_VG250.gpkg` — Deutschland-Kreisgrenzen (BKG VG250)
  - `bevoelkerung/bevoelkerung_kreise.csv` — Destatis-Bevölkerung pro Kreis

Die Daten kommen aus oBDS-XML-Dateien, die über den Web-Upload (`/registry`)
in die Datenbank geschrieben werden. Das macht in der Regel ein anderer
Mitarbeiter — als Forscher arbeitest du mit dem aktuellen Stand der DB.

---

<a id="2-datenbank-schema"></a>
## 2. Datenbank-Schema verstehen

**Erste Anlaufstelle:** [`DB_SCHEMA.md`](DB_SCHEMA.md) im selben Ordner —
zeigt alle Tabellen, Spalten, Datentypen und Foreign Keys.

**Aktuelles Schema live abfragen:**

```r
# In RStudio: Files-Panel öffnen, 00_db_schema.R doppelklicken,
# dann Strg+Shift+S (Source).
# Das Skript schreibt eine frische DB_SCHEMA.md ins Working Directory.
```

### Wichtigste Tabellen im Überblick

| Tabelle | Inhalt | Schlüssel |
|---------|--------|-----------|
| `patient_report` | Patient: Geburt, Geschlecht, Vitalstatus, Adresse | `id`, `patient_id` |
| `tumor_report` | Tumor: Diagnose, ICD, Lateralität, TNM-Refs | `id`, FK `patient_report_id` |
| `tumor_histology` | Histologie + Grading | FK `tumor_report_id` |
| `tumor_surgery` | Operationen mit OPS-Codes als JSON | FK `tumor_report_id` |
| `tumor_radiotherapy` | Strahlentherapie-Übersicht | FK `tumor_report_id` |
| `radiotherapy_session` | Einzelne RT-Sitzungen | FK `tumor_radiotherapy_id` |
| `tumor_systemic_therapy` | Chemo/Hormone als JSON-Array | FK `tumor_report_id` |
| `tumor_follow_up` | Verlaufskontrollen | FK `tumor_report_id`, `tnm_id` |
| `tnm` | TNM-Klassifikation (cTNM/pTNM/follow-up) | `id` |

### JSON-Felder
Manche Spalten sind `jsonb` (z.B. `tumor_report.icd`, `patient_report.address`,
`tumor_surgery.operations`, `tumor_systemic_therapy.drugs`). Zugriff:

```r
library(jsonlite)
row <- dbGetQuery(con, "SELECT icd FROM tumor_report LIMIT 1")
fromJSON(row$icd[1])      # in R-Liste umwandeln

# In SQL direkt:
dbGetQuery(con, "SELECT icd->>'code' AS icd_code FROM tumor_report LIMIT 5")
```

---

<a id="3-neues-projekt"></a>
## 3. Ein neues Forschungsprojekt anlegen

**Konvention:** Jedes Projekt liegt in einem eigenen Ordner unter

```
workspace/projekte/<JAHR>-<KÜRZEL>/
```

Beispiel: `workspace/projekte/2026-C50-BET/` (siehe dort als Vorlage).

**Empfohlene Struktur:**

```
workspace/projekte/2026-C61-PSA/
├── README.md         # Frage, Methode, Datenstand, Stakeholder
├── packages.R        # NUR falls Standard-Liste nicht reicht (selten)
├── 01_daten.R        # SQL-Query, Aufbereitung
├── 02_analyse.R      # Statistik
└── 03_outputs.R      # Tabellen + Grafiken + Excel/Word
```

**Working Directory setzen:** Damit deine Outputs im Projektordner landen
und nicht im Workspace-Root, vor jedem Source:

- Files-Panel → in den Projektordner navigieren
- Zahnrad-Symbol → **Set As Working Directory**

Oder programmatisch am Anfang jedes Skripts:

```r
setwd("/home/rstudio/projekte/2026-C61-PSA")
```

---

<a id="4-r-pakete"></a>
## 4. R-Pakete im Container

### Was ist schon installiert?
Siehe **[`R_PACKAGES.md`](R_PACKAGES.md)** im selben Ordner — vollständige
Liste mit Begründung. Aktuell 28 Pakete (Tidyverse, data.table, sf,
Survival, gtsummary, officer, ...).

### Wie prüfe ich live?

```r
"data.table" %in% rownames(installed.packages())   # TRUE
```

### Wenn ein Paket fehlt — drei Szenarien

#### A) **Nur für deine Session** (schnell, online-System)
```r
install.packages("forcats")
library(forcats)
```
**Problem:** Bei Container-Neustart oder Re-Build ist das Paket weg.
Außerdem funktioniert das **nicht** im Air-Gap-Betrieb (kein Internet).

#### B) **Dauerhaft im Container** (empfohlen, reproduzierbar)
**So geht es:**

1. Im Projektordner eine `packages.R` anlegen mit den fehlenden Paketen:
   ```r
   # packages.R — zusätzliche R-Pakete für Projekt 2026-C61-PSA
   # Standard-Bibliothek siehe R_PACKAGES.md
   needed <- c("forcats", "ggridges")
   ```
2. Datei + kurze Begründung an den KIKA-Administrator schicken
   (siehe Abschnitt 9, Kontakt) — die Pakete kommen ins nächste
   Container-Image.
3. Nach Re-Deploy stehen sie für alle bereit.

**Warum nicht jeder selbst?** Weil der Air-Gap-Container kein Internet hat
und Reproduzierbarkeit über Image-Versionen wichtig ist.

#### C) **Notfall: temporär ins persönliche Verzeichnis** (nur in der Not)
```r
dir.create("~/Rlibs", showWarnings = FALSE)
.libPaths(c("~/Rlibs", .libPaths()))
install.packages("forcats", lib = "~/Rlibs")
```
Bleibt erhalten solange das Home-Verzeichnis persistiert wird, aber
**kein offizieller Pfad** — bitte nur als Stop-Gap nutzen.

---

<a id="5-eigene-skripte"></a>
## 5. Eigene Skripte einbringen

### Während der Entwicklung
- **Variante 1** — direkt im RStudio-Editor schreiben, im Projektordner speichern.
- **Variante 2** — Files-Panel → **Upload** → eigene `.R`-Datei aus dem
  Browser hochladen.

### Für dauerhafte Aufnahme ins System
Das gleiche Vorgehen wie bei Paketen:

1. Skript in `workspace/projekte/<projektname>/` ablegen.
2. An den Administrator weiterleiten.
3. Kommt ins nächste Image und ist dann auch nach Container-Neustart da.

**Warum nicht direkt im laufenden Container belassen?** Weil das `/home/rstudio`
nur dann persistiert, wenn der Container nicht neu erstellt wird. Bei
Updates oder Migration auf einen anderen Rechner gehen lokale Änderungen
verloren — alles, was offiziell ist, gehört ins Image.

### Variante B (Notfall): Shared Volume vom Host
Der Admin kann ein Host-Verzeichnis als Volume in `/home/rstudio/projekte/`
mounten — dann sind Änderungen sofort persistent. **Aber:** weniger
reproduzierbar, weil der Container dann von einer Datei abhängt, die
nicht im Image steckt. Nur als Übergangslösung.

---

<a id="6-eigene-referenzdaten"></a>
## 6. Eigene Referenzdaten einbringen

Zum Beispiel zusätzliche Bevölkerungsdaten, eigene Lookup-Tabellen,
weitere Shapefiles, Codeplane.

### Klein (< 50 MB) und persönlich
Files-Panel → **Upload** → unter `~/eigene-referenz/` ablegen.
```r
read.csv("~/eigene-referenz/meine_codes.csv")
```

### Klein und für alle relevant
Datei + Beschreibung an den Administrator → kommt unter
`/home/rstudio/referenz/<unterordner>/` ins nächste Image.

### Groß (> 50 MB) oder regelmäßig aktualisiert
Mit Admin sprechen — wahrscheinlich besser als Volume-Mount lösen, damit
das Image nicht aufgebläht wird.

---

<a id="7-outputs"></a>
## 7. Outputs (Tabellen, Grafiken, Excel, Word) abholen

**Wo sie landen:** Im aktuellen Working Directory (siehe Abschnitt 3).
Wenn du dein WD auf den Projektordner gesetzt hast, landen alle Outputs
dort.

**Wie du sie aus RStudio rausbekommst:**
- Files-Panel → Datei markieren → **More → Export...** → Download startet.
- Mehrere Dateien: vorher in einen Unterordner verschieben, dann markieren
  und exportieren — RStudio packt sie automatisch in eine ZIP.

**Beispiele für Output-Erzeugung:**

```r
# Grafik
ggsave("alters_histogramm.png", p, width = 7, height = 5, dpi = 300)
ggsave("alters_histogramm.pdf", p, width = 7, height = 5)

# Excel mit mehreren Tabellenblättern
library(openxlsx)
wb <- createWorkbook()
addWorksheet(wb, "Charakteristika"); writeData(wb, "Charakteristika", df_chars)
addWorksheet(wb, "Ergebnisse");      writeData(wb, "Ergebnisse",      df_erg)
saveWorkbook(wb, "auswertung.xlsx", overwrite = TRUE)

# Word-Bericht
library(officer); library(flextable)
doc <- read_docx() |>
  body_add_par("Auswertung Brustkrebs", style = "heading 1") |>
  body_add_flextable(flextable(df_erg))
print(doc, target = "bericht.docx")
```

---

<a id="8-datenbankverbindung"></a>
## 8. Datenbankverbindung — Beispielcode

Die Verbindung ist in allen Beispiel-Skripten gleich vorkonfiguriert.
Der Container kennt `central-db` als Hostname (Docker-internes Netz).

```r
library(DBI)
library(RPostgres)

con <- dbConnect(
  RPostgres::Postgres(),
  host     = "central-db",
  port     = 5432,
  dbname   = "krebs",
  user     = "postgres",
  password = "1234"
)

# Daten holen
patienten <- dbGetQuery(con, "SELECT * FROM patient_report LIMIT 100")

# Komplexere Query
fall_alter <- dbGetQuery(con, "
  SELECT pr.patient_id, pr.gender,
         tr.diagnosis_date,
         EXTRACT(YEAR FROM AGE(tr.diagnosis_date, pr.date_of_birth)) AS alter,
         tr.icd->>'code' AS icd_code
  FROM patient_report pr
  JOIN tumor_report   tr ON tr.patient_report_id = pr.id
  WHERE tr.icd->>'code' LIKE 'C50%'
")

# Wichtig: Verbindung am Ende schließen
dbDisconnect(con)
```

**Tipp:** Für große Auswertungen lohnt es sich, die SQL-Query möglichst
viel filtern zu lassen (WHERE / LIMIT) statt alles nach R zu holen und
dort zu filtern.

---

<a id="9-faq"></a>
## 9. Häufige Fragen

**Wo ist mein Working Directory?**
```r
getwd()
```

**Wie verbinde ich mich mit der Datenbank ohne Passwort?**
Das Passwort `1234` ist Default für die Container-interne PostgreSQL.
Im Air-Gap-Betrieb ist die DB nicht von außen erreichbar — das ist okay.
Wenn der Admin das Passwort ändert, muss er auch die Skripte anpassen.

**Mein Plot wird nicht angezeigt.**
- Sicherstellen, dass das `Plots`-Panel rechts unten offen ist
- Bei `ggplot()` ohne `print()` reicht das Sourcen — Source mit `Strg+Shift+S`,
  nicht `Run` mit `Strg+Enter`

**Mein Skript bricht ab mit `could not find function ...`.**
Package nicht installiert oder nicht geladen. Prüfen mit:
```r
"forcats" %in% rownames(installed.packages())
```

**Container ist langsam / hängt.**
- IT informieren: vermutlich ist Docker Desktop am RAM-Limit
- Standard: 8 GB RAM für Docker — bei großen Auswertungen ggf. höher

**Ich brauche meine Daten zurück nach einem Container-Reset.**
Outputs aus dem Working Directory rauskopieren, **bevor** der Container
neu erstellt wird. Alles unter `~/projekte/<…>/` was nicht im Image ist,
geht sonst verloren.

**Wer betreut KIKA inhaltlich und technisch?**
Hamburgisches Krebsregister:
- Dr. Annemarie Schultz — annemarie.schultz@bwfg.hamburg.de
  (inhaltliche Fragen, Forschungsprojekte, Datenzugang)
- PD Dr. Frederik Peters — frederik.peters@bwfg.hamburg.de
  (technische Betreuung, Container-Updates)
