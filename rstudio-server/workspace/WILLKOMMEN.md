# Willkommen im KIKA Analyse-System

## So starten Sie Ihre erste Analyse

1. Klicken Sie oben links auf **`analyse.R`**
2. Klicken Sie auf **Source** (▶▶ oben rechts im Editor)
3. Ergebnisse erscheinen unten in der **Konsole**, Grafiken rechts unten im **Plots-Panel**

---

## Dateien in diesem Workspace

| Datei | Inhalt |
|-------|--------|
| `analyse.R` | Erste Übersicht: Fallzahlen, ICD-Codes, Altersverteilung |
| `karte_kreise.R` | Deutschlandkarte auf Kreisebene (Beispiel) |
| `projekte/` | Forschungsprojekte (siehe `projekte/2026-C50-BET/` als Beispiel) |
| `referenz/shapefiles/` | BKG VG250 Kreise (GeoPackage) |
| `referenz/bevoelkerung/` | Destatis Bevölkerungsdaten nach Kreisen |

---

## Forschungsprojekte

Jedes Projekt liegt in einem eigenen Ordner unter `projekte/<JAHR>-<KÜRZEL>/`
mit `README.md`, durchnummerierten Skripten (`01_…`, `02_…`) und falls nötig
einem `packages.R` für zusätzliche R-Pakete.

Standardmäßig sind 28 R-Pakete vorinstalliert (Tidyverse, data.table, sf,
Survival, Reporting). Liste siehe `R_PACKAGES.md` im hkr-deploy-Repo.

---

## Eigene Dateien hinzufügen

**Im Browser:**
- Panel unten rechts → Reiter **Files**
- Button **Upload** → Datei von Ihrem PC hochladen

**Für dauerhafte Aufnahme ins System:**
- Datei in `referenz/` oder `projekte/<projektordner>/` ablegen
- KIKA-Administrator informieren (Hamburgisches Krebsregister) →
  Datei wird ins nächste Image eingebaut

---

## Datenbankverbindung

Die Verbindung zur Krebsregister-Datenbank ist in allen Skripten
voreingestellt — kein Passwort, keine Konfiguration nötig.

---

*Bei Fragen: Hamburgisches Krebsregister — annemarie.schultz@bwfg.hamburg.de · frederik.peters@bwfg.hamburg.de*
