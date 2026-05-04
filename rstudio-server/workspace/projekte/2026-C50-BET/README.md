# 2026-C50-BET — RT-Rate nach BET bei Mammakarzinom

## Forschungsfrage

Welcher Anteil der Patientinnen mit C50-Mammakarzinom und brusterhaltender
Therapie (BET) erhält im Anschluss eine Strahlentherapie? Ziel ist eine
Quote von ≥ 72 %.

## Methode

- Population: erste C50-Diagnose pro Patientin
- BET-Identifikation: OPS-Code 5-870.x
- Mastektomie-Ausschluss: 5-877 / 5-872 / 5-874 (Mastektomie schlägt BET)
- RT-Fenster: 0–730 Tage nach Diagnose
- Schichtung nach Altersgruppe (<40, 40–49, 50–59, 60–69, 70–79, ≥80)

## Daten

- Tabellen: `tumor_report`, `patient_report`, `tumor_surgery`,
  `tumor_radiotherapy`, `radiotherapy_session`, `tumor_histology`
- Stand: KIKA-Datenbank, abgefragt zur Laufzeit

## Datenschutz

Auswertung erfolgt aggregiert, keine personenbezogenen Outputs.
Reports werden im `outputs/`-Unterordner abgelegt (nicht im Repo).

## Skripte

| Datei | Zweck |
|-------|-------|
| `01_analyse.R` | Vollständige Analyse: SQL-Query, Aufbereitung, Tabellen, Grafiken, Karte, Excel-Export |

## Ausführung

In RStudio:
1. Projekt-Ordner als Working Directory setzen (Files-Tab → More → Set As Working Directory)
2. `01_analyse.R` mit Strg+Shift+S sourcen

Outputs landen im aktuellen Working Directory:
- `C50_OP_Typ.png` / `.pdf`
- `C50_RT_Rate_Altersgruppe.png` / `.pdf`
- `C50_Abstand_OP_RT.png` / `.pdf`
- `C50_Karte_HH_RT_Rate.png` / `.pdf`
- `C50_BET_RT_Analyse.xlsx`

## Benötigte Packages

Alle aus der Standard-Bibliothek (siehe `../../R_PACKAGES.md`):
DBI, RPostgres, data.table, jsonlite, ggplot2, sf, openxlsx.
Kein zusätzliches `packages.R` nötig.
