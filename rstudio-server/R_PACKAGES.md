# Vorinstallierte R-Pakete im KIKA-Container

Stand: 2026-05-04 — `R_PACKAGES_VERSION` im Dockerfile entsprechend aktualisieren wenn etwas hinzukommt.

Alle Pakete sind beim Container-Build installiert und ohne Internetzugang verfügbar (wichtig für Air-Gap-Betrieb).

## Daten & Datenbank

| Paket | Wofür |
|-------|-------|
| `DBI` | Generische DB-Schnittstelle |
| `RPostgres` | PostgreSQL-Treiber für KIKA-Datenbank |
| `jsonlite` | JSON-Felder aus den Reports parsen |
| **`data.table`** | **Standard-Datenmanagement** (essentiell, schneller als data.frame bei großen Datenmengen) |

## Tidyverse / Datentransformation

| Paket | Wofür |
|-------|-------|
| `dplyr` | Datenmanipulation (filter, mutate, join, ...) |
| `tidyr` | Pivot, unnest |
| `lubridate` | Datums-/Zeitberechnungen |

## Visualisierung & Geo

| Paket | Wofür |
|-------|-------|
| `ggplot2` | Standard-Grafiken |
| `scales` | Achsen-Formatierung |
| `RColorBrewer` | Farbpaletten |
| `sf` | Vektor-Geodaten (Shapefiles, GeoPackage) |
| `s2` | Sphärische Geometrie (von sf benötigt für globale Operationen) |

## I/O & Reporting

| Paket | Wofür |
|-------|-------|
| `readxl` / `writexl` | Excel-Files lesen/schreiben (einfache Fälle) |
| `openxlsx` | Excel mit Formatierung, mehreren Tabellenblättern |
| `flextable` | Tabellen für Word/PowerPoint |
| `officer` | Word- und PowerPoint-Dokumente generieren |

## Statistik & Epidemiologie

| Paket | Wofür |
|-------|-------|
| `tableone` | „Table 1" für Patientencharakteristika |
| `epitools` | Inzidenzraten, Risikoschätzer |
| `gtsummary` | Publikationsfertige Tabellen mit p-Werten |
| `broom` | Modell-Outputs in tidy-Form bringen |
| `sandwich` | Robuste Standardfehler |
| `lmtest` | Hypothesentests für lineare Modelle |
| `mgcv` | Generalisierte Additive Modelle (Splines) |

## Survival-Analyse

| Paket | Wofür |
|-------|-------|
| `survival` | Cox-Regression, Kaplan-Meier |
| `survminer` | Überlebenskurven plotten |

## Meta-Analyse / Forest-Plots

| Paket | Wofür |
|-------|-------|
| `forestplot` | Forest-Plot-Visualisierung |
| `meta` | Meta-Analyse-Modelle |

---

## Wenn ein Paket fehlt

1. Im `rstudio-server/Dockerfile` die `install.packages(...)`-Liste **und** die Validation-Liste ergänzen.
2. `R_PACKAGES_VERSION` auf das heutige Datum hochsetzen (Cache-Bust).
3. Diese Datei aktualisieren — kurze Beschreibung wofür.
4. `bash ~/deploy.sh code` (oder `rstudio`) auf ubuntu-ai → Build prüft die Validation automatisch.
5. Air-Gap: anschließend `docker save hkr/rstudio-server:latest -o ~/kika-air-gap/images/rstudio-server.tar`.

## Konvention für neue Forschungsprojekte

Jedes Forschungsprojekt bekommt einen eigenen Unterordner unter `workspace/projekte/`:

```
workspace/projekte/<JAHR>-<KUERZEL>/
├── README.md         # Frage, Methode, Datenstand
├── packages.R        # nur falls Standard-Liste nicht reicht (mit Hinweis warum)
├── 01_daten.R        # Daten laden + bereinigen
├── 02_analyse.R      # Statistik
└── 03_outputs.R      # Tabellen + Grafiken + Reports
```

Vorhandenes Beispiel: `workspace/projekte/2026-C50-BET/`
