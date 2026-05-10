# 2026-MET-Hirnmetastasen — Pilot Mammakarzinom + Hirnmetastasen

## Forschungsfrage

Wie sieht die Epidemiologie der Hirnmetastasen beim Mammakarzinom in
Deutschland aus? Inzidenz, Altersverteilung, Zeit zwischen Erstdiagnose und
Hirnmetastase, Histologie, Therapie. Vergleich mit Bronchialkarzinom (C34)
und Melanom (C43).

## Hintergrund

- Stipendienprojekt der Hamburger Krebsgesellschaft (03/2025 – 02/2026)
- Tandem-Konzept: PD Dr. Laakmann (UKE), Dr. Schultz / PD Dr. Peters (HKR),
  Stipendiatin Leonie Rosenberg (HAW Hamburg)
- Ziel laut Antrag: Methodischer Ansatz zum verteilten Rechnen + epidemiolog.
  Faktenblatt zu Hirnmetastasen beim Mammakarzinom

## Vorgehen mit KIKA

1. Jedes Landeskrebsregister installiert den KIKA-Container (Air-Gap-Paket).
2. Lokal werden die eigenen oBDS-Daten in den Container importiert.
3. Dieses Skript (`01_analyse.R`) wird ausgefuehrt — Daten verlassen den
   Container nicht.
4. Die generierte Aggregat-Datei `outputs/agg_hirnmet_hamburg.rds` wird
   an die Hamburger Koordinationsstelle gesendet.
5. Hamburg konsolidiert die 15 Aggregate zur deutschlandweiten Analyse.

## oBDS-Codes

| Code | Bedeutung               |
|------|-------------------------|
| C50  | Mammakarzinom           |
| C34  | Bronchialkarzinom       |
| C43  | Melanom                 |
| BRA  | Brain (Hirnmetastase)   |
| HEP  | Hepar (Leber)           |
| PUL  | Pulmo (Lunge)           |
| OSS  | Ossär (Knochen)         |

## Outputs

Im Unterordner `outputs/`:

| Datei | Inhalt |
|-------|--------|
| `01_anteil_hirnmet.png`              | Hirnmet-Anteil je Entitaet |
| `02_alter_bei_hirnmet_C50.png`       | Altersverteilung bei BRM (C50) |
| `03_zeit_diagnose_bis_hirnmet.png`   | Zeit Erstdiagnose -> BRM |
| `04_zeitverlauf_anteil.png`          | Anteil im zeitlichen Verlauf |
| `Hirnmetastasen_Hamburg.xlsx`        | Alle Tabellen |
| `agg_hirnmet_hamburg.rds`            | **An Koordinationsstelle senden** |

## Datenschutz

Das Aggregat (`agg_*.rds`) enthaelt ausschliesslich Kennzahlen — keine
Patient:innen-IDs, keine Geburtsdaten, keine Lokalisationen unter
N=10. Es kann ohne weiteres Antragsverfahren weitergegeben werden.

## Ausfuehren

In RStudio:
1. Working Directory auf den Projektordner setzen
2. `Strg+Shift+S` (Source) auf `01_analyse.R`
