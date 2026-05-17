# =============================================================================
# KIKA – Federated Multi-Register-Analyse: C50 Hirnmetastasen
# 03_praesentation.R — Erstellt PowerPoint-Präsentation zum Prozess
#
# Paket: officer (CRAN)
# Output: MULTI_Federated_Prozess.pptx
# =============================================================================

rm(list = ls())

if (!require("officer",    quietly = TRUE)) install.packages("officer")
if (!require("data.table", quietly = TRUE)) install.packages("data.table")
library(officer)
library(data.table)

# ============================================================
# DESIGN-KONSTANTEN (HKR Corporate Design)
# ============================================================
HH_DUNKELBLAU = "#003063"
HH_BLAU       = "#005CA9"
HH_ROT        = "#E10019"
HH_GRAU       = "#E3E3E3"
HH_DUNKELGRAU = "#757575"
WEISS         = "#FFFFFF"

FONT_TITEL = "Calibri"
FONT_TEXT  = "Calibri"

# ============================================================
# HILFSFUNKTIONEN
# ============================================================

neue_folie = function(prs, layout = "Blank") {
  add_slide(prs, layout = layout, master = "Office Theme")
}

fmt_titel = function(text, sz = 28, bold = TRUE, color = HH_DUNKELBLAU) {
  fpar(ftext(text, fp_text(font.size = sz, bold = bold,
                           color = color, font.family = FONT_TITEL)))
}

fmt_text = function(text, sz = 14, bold = FALSE, color = "#222222") {
  fpar(ftext(text, fp_text(font.size = sz, bold = bold,
                           color = color, font.family = FONT_TEXT)))
}

fmt_bullet = function(text, sz = 13, color = "#222222") {
  fpar(
    ftext(paste0("•  ", text),
          fp_text(font.size = sz, color = color, font.family = FONT_TEXT)),
    fp_p = fp_par(padding.left = 22)
  )
}

# ============================================================
# PRÄSENTATION ERSTELLEN
# ============================================================
prs = read_pptx()

BREITE = 10
HOEHE  = 7.5

# ============================================================
# FOLIE 1: TITELFOLIE
# ============================================================
prs = neue_folie(prs)

prs = ph_with(prs,
  value = fpar(ftext("", fp_text(font.size = 1))),
  location = ph_location(left = 0, top = 0, width = BREITE, height = 2.2))

prs = ph_with(prs,
  value = block_list(
    fpar(ftext("Federated Datenanalyse",
               fp_text(font.size = 36, bold = TRUE,
                       color = HH_DUNKELBLAU, font.family = FONT_TITEL))),
    fpar(ftext("mit 15 Landeskrebsregistern",
               fp_text(font.size = 36, bold = TRUE,
                       color = HH_BLAU, font.family = FONT_TITEL)))
  ),
  location = ph_location(left = 0.5, top = 1.3, width = 9, height = 1.6))

prs = ph_with(prs,
  value = block_list(
    fpar(ftext("C50 Mammakarzinom – Hirnmetastasen-Analyse",
               fp_text(font.size = 18, color = HH_DUNKELGRAU,
                       font.family = FONT_TEXT))),
    fpar(ftext("")),
    fpar(ftext("Methodisches Konzept | Datenschutz | Skriptstruktur",
               fp_text(font.size = 14, color = HH_DUNKELGRAU,
                       font.family = FONT_TEXT)))
  ),
  location = ph_location(left = 0.5, top = 3.2, width = 9, height = 1.5))

prs = ph_with(prs,
  value = fpar(ftext(paste0("Hamburg Krebsregister (KIKA) | ", format(Sys.Date(), "%B %Y")),
               fp_text(font.size = 11, color = HH_DUNKELGRAU, font.family = FONT_TEXT))),
  location = ph_location(left = 0.5, top = 6.8, width = 9, height = 0.4))

prs = ph_with(prs,
  value = fpar(ftext(" ", fp_text(font.size = 4, color = HH_BLAU))),
  location = ph_location(left = 0, top = 2.95, width = BREITE, height = 0.06))

# ============================================================
# FOLIE 2: AUSGANGSLAGE & FRAGESTELLUNG
# ============================================================
prs = neue_folie(prs)

prs = ph_with(prs,
  value = fmt_titel("Ausgangslage & Fragestellung"),
  location = ph_location(left = 0.5, top = 0.3, width = 9, height = 0.7))

prs = ph_with(prs,
  value = block_list(
    fpar(ftext("Epidemiologische Fragestellung",
               fp_text(font.size = 15, bold = TRUE,
                       color = HH_DUNKELBLAU, font.family = FONT_TITEL))),
    fpar(ftext("")),
    fmt_bullet("Unterscheidet sich die Hirnmetastasen-Rate bei C50 nach molekularem Subtyp?"),
    fmt_bullet("Gibt es einen zeitlichen Trend? Ist das Muster in allen Registern stabil?"),
    fmt_bullet("Methoden: Kaplan-Meier, Competing Risks (CIF), Cox-Regression, Poisson-Trend"),
    fpar(ftext("")),
    fpar(ftext("Herausforderung: Datenschutz & Dezentralisierung",
               fp_text(font.size = 15, bold = TRUE,
                       color = HH_DUNKELBLAU, font.family = FONT_TITEL))),
    fpar(ftext("")),
    fmt_bullet("15 Landeskrebsregister — jedes unterliegt eigenen Datenschutzgesetzen"),
    fmt_bullet("Einzelfalldaten dürfen das jeweilige Register NICHT verlassen"),
    fmt_bullet("Herkömmliche Datenpoolierung ist rechtlich nicht möglich"),
    fpar(ftext("")),
    fpar(ftext("Lösung: Federated Analysis",
               fp_text(font.size = 15, bold = TRUE,
                       color = HH_ROT, font.family = FONT_TITEL))),
    fpar(ftext("")),
    fmt_bullet("Nur aggregierte Summary Statistics verlassen das Register"),
    fmt_bullet("Methodisch äquivalent zur zentralisierten Analyse (exaktes Pooling)")
  ),
  location = ph_location(left = 0.5, top = 1.1, width = 9, height = 6.0))

# ============================================================
# FOLIE 3: DAS DATENSCHUTZ-PRINZIP
# ============================================================
prs = neue_folie(prs)

prs = ph_with(prs,
  value = fmt_titel("Das Datenschutz-Prinzip: Was das Register verlässt"),
  location = ph_location(left = 0.5, top = 0.3, width = 9, height = 0.7))

# Linke Spalte: Nicht erlaubt
prs = ph_with(prs,
  value = block_list(
    fpar(ftext("NICHT erlaubt",
               fp_text(font.size = 14, bold = TRUE,
                       color = HH_ROT, font.family = FONT_TITEL))),
    fpar(ftext("")),
    fmt_bullet("Patientenlisten oder Einzelfalldaten", sz = 12, color = "#333333"),
    fmt_bullet("Diagnose- und Verlaufsdaten je Patient", sz = 12, color = "#333333"),
    fmt_bullet("Zellen mit N < 5 (DSGVO-Mindestzahl)", sz = 12, color = "#333333"),
    fmt_bullet("Jede Kombination, die Rückschlüsse auf Einzelpersonen ermöglicht",
               sz = 12, color = "#333333")
  ),
  location = ph_location(left = 0.4, top = 1.1, width = 4.3, height = 3.0))

# Rechte Spalte: Erlaubt
prs = ph_with(prs,
  value = block_list(
    fpar(ftext("ERLAUBT (aggregierte Statistiken)",
               fp_text(font.size = 14, bold = TRUE,
                       color = "#2E7D32", font.family = FONT_TITEL))),
    fpar(ftext("")),
    fmt_bullet("KM-Ereignistabelle: t, n.risk, n.event", sz = 12, color = "#333333"),
    fmt_bullet("Cox-Koeffizientenvektor + Varianz-Kovarianz-Matrix", sz = 12, color = "#333333"),
    fmt_bullet("Counts + Personenjahre je Stratum (N ≥ 5)", sz = 12, color = "#333333"),
    fmt_bullet("Median-FU, Ereignisraten je Subtyp (aggregiert)", sz = 12, color = "#333333")
  ),
  location = ph_location(left = 5.3, top = 1.1, width = 4.3, height = 3.0))

# Grundsatz-Box unten (volle Breite, dunkler Hintergrund)
prs = ph_with(prs,
  value = block_list(
    fpar(ftext("Grundsatz: Die Analyse kommt zu den Daten — nicht die Daten zur Analyse.",
               fp_text(font.size = 14, bold = TRUE, color = WEISS,
                       font.family = FONT_TITEL)),
         fp_p = fp_par(text.align = "center")),
    fpar(ftext("")),
    fpar(ftext("Jedes Register führt dieselben Skripte auf seinen eigenen Daten aus.",
               fp_text(font.size = 12, color = HH_GRAU, font.family = FONT_TEXT)),
         fp_p = fp_par(text.align = "center"))
  ),
  location = ph_location(left = 0.4, top = 4.5, width = 9.2, height = 1.4))

# ============================================================
# FOLIE 4: ZWEISTUFIGER PROZESS
# ============================================================
prs = neue_folie(prs)

prs = ph_with(prs,
  value = fmt_titel("Zweistufiger Analyseprozess"),
  location = ph_location(left = 0.5, top = 0.3, width = 9, height = 0.7))

# Stufe 1
prs = ph_with(prs,
  value = block_list(
    fpar(ftext("STUFE 1 — In jedem der 15 Register (lokal)",
               fp_text(font.size = 13, bold = TRUE, color = WEISS, font.family = FONT_TITEL)),
         fp_p = fp_par(text.align = "center"))
  ),
  location = ph_location(left = 0.3, top = 1.1, width = 4.2, height = 0.45))

prs = ph_with(prs,
  value = block_list(
    fmt_bullet("Datenbank-Abfrage (lokal, KIKA-Schema)", sz = 11),
    fmt_bullet("Subtyp-Klassifikation (ER/PR/HER2)", sz = 11),
    fmt_bullet("Zeitvariablen berechnen (OS, CIF)", sz = 11),
    fmt_bullet("Summary Statistics aggregieren", sz = 11),
    fmt_bullet("DSGVO-Prüfung: N < 5 supprimieren", sz = 11),
    fmt_bullet("Export: {REGISTER}_export.rds", sz = 11)
  ),
  location = ph_location(left = 0.3, top = 1.65, width = 4.2, height = 2.8))

# Pfeil
prs = ph_with(prs,
  value = fpar(ftext("  ➤  ", fp_text(font.size = 32, color = HH_BLAU))),
  location = ph_location(left = 4.5, top = 2.2, width = 1.0, height = 0.8))

# Stufe 2
prs = ph_with(prs,
  value = block_list(
    fpar(ftext("STUFE 2 — Zentral bei HKR",
               fp_text(font.size = 13, bold = TRUE, color = WEISS, font.family = FONT_TITEL)),
         fp_p = fp_par(text.align = "center"))
  ),
  location = ph_location(left = 5.5, top = 1.1, width = 4.2, height = 0.45))

prs = ph_with(prs,
  value = block_list(
    fmt_bullet("15 Export-Dateien einlesen", sz = 11),
    fmt_bullet("Gepoolte KM-Kurven berechnen (exakt)", sz = 11),
    fmt_bullet("Two-Stage Cox-Meta-Analyse (metafor)", sz = 11),
    fmt_bullet("Poisson GLMM (Register = Random Effect)", sz = 11),
    fmt_bullet("Bayesian Smoothing (INLA RW1)", sz = 11),
    fmt_bullet("Grafiken + CSV-Berichte erstellen", sz = 11)
  ),
  location = ph_location(left = 5.5, top = 1.65, width = 4.2, height = 2.8))

# Zeitplan als drei separate Zeilen statt einer langen Zeile
prs = ph_with(prs,
  value = block_list(
    fpar(ftext("Zeitlicher Ablauf",
               fp_text(font.size = 13, bold = TRUE,
                       color = HH_DUNKELBLAU, font.family = FONT_TITEL))),
    fpar(ftext("")),
    fpar(
      ftext("①  ", fp_text(font.size = 11, bold = TRUE, color = HH_BLAU,
                                font.family = FONT_TEXT)),
      ftext("Phase 1: Abstimmung Skripte & Kodierungen mit allen Registern",
            fp_text(font.size = 11, color = "#333333", font.family = FONT_TEXT)),
      ftext("  —  4 Wochen",
            fp_text(font.size = 11, color = HH_DUNKELGRAU, font.family = FONT_TEXT))
    ),
    fpar(
      ftext("②  ", fp_text(font.size = 11, bold = TRUE, color = HH_BLAU,
                                font.family = FONT_TEXT)),
      ftext("Phase 2: Lokale Läufe in jedem der 15 Register",
            fp_text(font.size = 11, color = "#333333", font.family = FONT_TEXT)),
      ftext("  —  2 Wochen",
            fp_text(font.size = 11, color = HH_DUNKELGRAU, font.family = FONT_TEXT))
    ),
    fpar(
      ftext("③  ", fp_text(font.size = 11, bold = TRUE, color = HH_BLAU,
                                font.family = FONT_TEXT)),
      ftext("Phase 3: Zentrale Meta-Analyse & Abschlussbericht",
            fp_text(font.size = 11, color = "#333333", font.family = FONT_TEXT)),
      ftext("  —  2 Wochen",
            fp_text(font.size = 11, color = HH_DUNKELGRAU, font.family = FONT_TEXT))
    )
  ),
  location = ph_location(left = 0.3, top = 4.8, width = 9.4, height = 1.5))

# ============================================================
# FOLIE 5: WAS JEDES REGISTER EXPORTIERT
# ============================================================
prs = neue_folie(prs)

prs = ph_with(prs,
  value = fmt_titel("Export-Statistiken: Was jedes Register liefert"),
  location = ph_location(left = 0.5, top = 0.3, width = 9, height = 0.7))

export_tab = data.frame(
  Export      = c("A: KM-Ereignistabelle OS",
                  "B: KM-Ereignistabelle BM",
                  "C: Cox-Koeffizienten OS",
                  "D: Cox-Koeffizienten BM",
                  "E: Poisson-Zähltabelle",
                  "F: Deskriptivstatistik"),
  Inhalt      = c("t, n.risk, n.event, n.censor je Subtyp",
                  "t, n.risk, n.event, n.censor je Subtyp",
                  "coef + Var-Kov-Matrix + N + Events",
                  "coef + Var-Kov-Matrix + N + Events",
                  "Counts + PJ nach Subtyp × Alter × Jahr",
                  "N, BM-Rate, Median-FU je Subtyp"),
  Datenschutz = c("Kein Einzelfall", "Kein Einzelfall", "Kein Einzelfall",
                  "Kein Einzelfall", "N<5 supprimiert", "N<5 supprimiert"),
  Verwendung  = c("Gepoolte KM exakt", "Gepoolte CIF",
                  "Random-Effects-Meta-Analyse", "Random-Effects-Meta-Analyse",
                  "Poisson GLMM, INLA", "Übersichtstabelle"),
  stringsAsFactors = FALSE
)

tab_rows = lapply(seq_len(nrow(export_tab)), function(i) {
  block_list(
    fpar(
      ftext(export_tab$Export[i],
            fp_text(font.size = 11, bold = TRUE, color = HH_DUNKELBLAU,
                    font.family = FONT_TEXT)),
      ftext(paste0("  —  ", export_tab$Inhalt[i]),
            fp_text(font.size = 11, color = "#222222", font.family = FONT_TEXT))
    ),
    fpar(
      ftext(paste0("    Datenschutz: ", export_tab$Datenschutz[i], "   |   "),
            fp_text(font.size = 10, color = "#2E7D32", font.family = FONT_TEXT)),
      ftext(paste0("Verwendung: ", export_tab$Verwendung[i]),
            fp_text(font.size = 10, color = HH_DUNKELGRAU, font.family = FONT_TEXT))
    ),
    fpar(ftext(""))
  )
})

prs = ph_with(prs,
  value = do.call(block_list, c(
    list(fpar(ftext("Datei: {REGISTER}_export.rds (eine Datei je Register)",
                    fp_text(font.size = 12, bold = TRUE, color = HH_DUNKELGRAU,
                            font.family = FONT_TEXT)),
              fp_p = fp_par())),
    unlist(tab_rows, recursive = FALSE)
  )),
  location = ph_location(left = 0.3, top = 1.1, width = 9.4, height = 5.5))

# ============================================================
# FOLIE 6: METHODEN — ÜBERBLICK
# ============================================================
prs = neue_folie(prs)

prs = ph_with(prs,
  value = fmt_titel("Methoden im Überblick"),
  location = ph_location(left = 0.5, top = 0.3, width = 9, height = 0.7))

methoden = list(
  list(titel = "Kaplan-Meier Pooling (exakt)",
       zeilen = c(
         "Jedes Register liefert die vollständige Ereignistabelle (t, n.risk, n.event).",
         "Zentral: Summiere n.risk und n.event an jedem Zeitpunkt über alle Register.",
         "Ergebnis ist identisch mit KM auf dem gepoolten Datensatz — kein Informationsverlust.",
         "Greenwood-Varianz für 95%-KI auf dem gepoolten Schätzer."
       )),
  list(titel = "Cox-Regression (Two-Stage Meta-Analyse)",
       zeilen = c(
         "Jedes Register schätzt coxph() mit identischer Formel (definiert in 00_config.R).",
         "Export: Koeffizientenvektor + Varianz-Kovarianz-Matrix.",
         "Zentral: Random-Effects-Meta-Analyse mit metafor::rma() (REML).",
         "I²-Statistik quantifiziert Heterogenität zwischen den Registern."
       )),
  list(titel = "Poisson-Trendmodell (Mixed Model)",
       zeilen = c(
         "Jedes Register exportiert Counts + Personenjahre nach Subtyp × Alter × Jahr.",
         "Zentral: Poisson GLMM mit Register als Random Intercept (lme4::glmer).",
         "Liefert adjustierte Inzidenz-Rate-Ratios mit 95%-KI.",
         "Ermöglicht Trendanalyse über Diagnosejahre bei Kontrolle für Alter."
       )),
  list(titel = "Bayesianische Glättung (INLA RW1)",
       zeilen = c(
         "Aggregierte Counts + PJ (über Register summiert) als Input.",
         "Random-Walk-1-Prior über Diagnosejahr: zeitlich geglätteter Trend.",
         "95%-Kredibilitätsintervall statt Konfidenzintervall.",
         "Vorteil: stabile Schätzung auch bei kleinen Registern / seltenen Ereignissen."
       ))
)

y_pos = 1.1
for (m in methoden) {
  prs = ph_with(prs,
    value = block_list(
      fpar(ftext(m$titel, fp_text(font.size = 13, bold = TRUE,
                                   color = HH_DUNKELBLAU, font.family = FONT_TITEL))),
      fpar(ftext("")),
      fmt_bullet(m$zeilen[1], sz = 11),
      fmt_bullet(m$zeilen[2], sz = 11),
      fmt_bullet(m$zeilen[3], sz = 11),
      fmt_bullet(m$zeilen[4], sz = 11)
    ),
    location = ph_location(left = 0.4, top = y_pos, width = 9.2, height = 1.5))
  y_pos = y_pos + 1.52
}

# ============================================================
# FOLIE 7: SKRIPTSTRUKTUR
# ============================================================
prs = neue_folie(prs)

prs = ph_with(prs,
  value = fmt_titel("Skriptstruktur & Workflow"),
  location = ph_location(left = 0.5, top = 0.3, width = 9, height = 0.7))

prs = ph_with(prs,
  value = block_list(
    fpar(ftext("Projektordner",
               fp_text(font.size = 13, bold = TRUE,
                       color = HH_DUNKELBLAU, font.family = FONT_TITEL))),
    fpar(ftext("")),
    fpar(ftext("2026-MULTI-C50-Hirnmetastasen/",
               fp_text(font.size = 11, bold = TRUE,
                       font.family = "Courier New", color = "#333333"))),
    fpar(ftext("  00_config.R",
               fp_text(font.size = 11, font.family = "Courier New", color = HH_BLAU))),
    fpar(ftext("  01_lokal_export.R",
               fp_text(font.size = 11, font.family = "Courier New", color = HH_BLAU))),
    fpar(ftext("  02_zentral_meta.R",
               fp_text(font.size = 11, font.family = "Courier New", color = HH_ROT))),
    fpar(ftext("  03_praesentation.R",
               fp_text(font.size = 11, font.family = "Courier New", color = HH_DUNKELGRAU))),
    fpar(ftext("  exports/",
               fp_text(font.size = 11, font.family = "Courier New", color = "#333333"))),
    fpar(ftext("    HH_export.rds",
               fp_text(font.size = 10, font.family = "Courier New", color = HH_DUNKELGRAU))),
    fpar(ftext("    BY_export.rds",
               fp_text(font.size = 10, font.family = "Courier New", color = HH_DUNKELGRAU))),
    fpar(ftext("    NW_export.rds  ...",
               fp_text(font.size = 10, font.family = "Courier New", color = HH_DUNKELGRAU)))
  ),
  location = ph_location(left = 0.4, top = 1.1, width = 4.3, height = 4.5))

prs = ph_with(prs,
  value = block_list(
    fpar(ftext("Wer führt was aus?",
               fp_text(font.size = 13, bold = TRUE,
                       color = HH_DUNKELBLAU, font.family = FONT_TITEL))),
    fpar(ftext("")),
    fpar(ftext("Jedes Register (lokal):",
               fp_text(font.size = 12, bold = TRUE,
                       color = HH_BLAU, font.family = FONT_TEXT))),
    fmt_bullet("00_config.R sourct (shared definition)", sz = 11),
    fmt_bullet("01_lokal_export.R ausführen", sz = 11),
    fmt_bullet("exports/{REG}_export.rds an HKR senden", sz = 11),
    fpar(ftext("")),
    fpar(ftext("HKR (zentral):",
               fp_text(font.size = 12, bold = TRUE,
                       color = HH_ROT, font.family = FONT_TEXT))),
    fmt_bullet("Alle RDS-Dateien in exports/ ablegen", sz = 11),
    fmt_bullet("02_zentral_meta.R ausführen", sz = 11),
    fmt_bullet("Alle Grafiken + CSVs werden erzeugt", sz = 11),
    fpar(ftext("")),
    fpar(ftext("Hinweis:",
               fp_text(font.size = 12, bold = TRUE,
                       color = HH_DUNKELGRAU, font.family = FONT_TEXT))),
    fmt_bullet("00_config.R wird vorab abgestimmt und", sz = 11),
    fmt_bullet("unverändert an alle Register verteilt.", sz = 11)
  ),
  location = ph_location(left = 5.1, top = 1.1, width = 4.6, height = 4.5))

# ============================================================
# FOLIE 8: NÄCHSTE SCHRITTE
# ============================================================
prs = neue_folie(prs)

prs = ph_with(prs,
  value = fmt_titel("Nächste Schritte"),
  location = ph_location(left = 0.5, top = 0.3, width = 9, height = 0.7))

schritte = list(
  list(nr = "1", titel = "Abstimmung 00_config.R mit allen Registern",
       details = c(
         "Subtyp-Kodierungen (oBDS-Codes) prüfen — Register-spezifische Abweichungen?",
         "Datenbankschema: Spaltennamen und JSONB-Felder verifizieren",
         "Anpassung DB_HOST / Credentials in 01_lokal_export.R je Register"
       )),
  list(nr = "2", titel = "Pilotlauf mit einem Testregister",
       details = c(
         "Synthetische Daten generieren (XML-Generator v3) als Fallback",
         "01_lokal_export.R vollständig testen — Prüfdatei kontrollieren",
         "Ergebnis an HKR senden und 02_zentral_meta.R mit 1 Register testen"
       )),
  list(nr = "3", titel = "Roll-out auf alle 15 Register",
       details = c(
         "Rollout-Reihenfolge nach Datenverfügbarkeit und Kapazität",
         "Jedes Register prüft Prüfdatei vor Weitergabe (DSGVO-Kontrolle)",
         "HKR sammelt RDS-Dateien und führt Gesamtanalyse durch"
       )),
  list(nr = "4", titel = "Ergebnisse & Publikation",
       details = c(
         "Grafiken + Tabellen aus 02_zentral_meta.R für Manuskript",
         "Methodik-Abschnitt: Federated Analysis, Two-Stage, INLA",
         "Sensitivitätsanalysen: Fixed vs. Random Effects, Zeitfenster"
       ))
)

y_pos = 1.1
for (s in schritte) {
  prs = ph_with(prs,
    value = block_list(
      fpar(
        ftext(paste0("  ", s$nr, "  "),
              fp_text(font.size = 14, bold = TRUE, color = WEISS,
                      font.family = FONT_TITEL)),
        ftext(paste0("  ", s$titel),
              fp_text(font.size = 13, bold = TRUE, color = HH_DUNKELBLAU,
                      font.family = FONT_TITEL))
      ),
      fpar(ftext("")),
      fmt_bullet(s$details[1], sz = 11),
      fmt_bullet(s$details[2], sz = 11),
      fmt_bullet(s$details[3], sz = 11)
    ),
    location = ph_location(left = 0.4, top = y_pos, width = 9.2, height = 1.48))
  y_pos = y_pos + 1.5
}

# ============================================================
# FOLIE 9: SYSTEM-ARCHITEKTUR (ggplot-Diagramm eingebettet)
# ============================================================
if (!require("ggplot2", quietly = TRUE)) install.packages("ggplot2")
library(ggplot2)

arch_png = tempfile(fileext = ".png")

arch_p = local({
  # 9 Container in 4 Schichten
  # Schicht 1 (Frontend):   y 7.1 - 8.4
  # Schicht 2 (Backend):    y 5.0 - 6.3
  # Schicht 3 (Migration):  y 3.5 - 4.4  (einmalig, restart:no)
  # Schicht 4 (Analyse):    y 1.1 - 2.6
  boxes = data.frame(
    xmin  = c(0.75, 2.5,  5.9,   0.05, 3.15, 6.35,  0.05, 5.05,  0.05),
    xmax  = c(2.4,  5.8,  9.95,  3.05, 6.25, 9.95,  4.95, 9.95,  9.95),
    ymin  = c(7.1,  7.1,  7.1,   5.0,  5.0,  5.0,   3.5,  3.5,   1.1),
    ymax  = c(8.4,  8.4,  8.4,   6.3,  6.3,  6.3,   4.4,  4.4,   2.6),
    label = c("ingress", "krebs-web", "krebs-api",
              "job-queue", "import-worker", "central-db",
              "krebs-db-migrations", "main-db-migrations",
              "krebs-code"),
    sub   = c("nginx · Port 8090 → 80",
              "Next.js 15 / React 19\nTypeScript / Tailwind 4",
              "FastAPI / Python 3.12\nUpload · Auth · Reports",
              "Redis\nMessage Queue",
              "Python 3.12-Alpine\nXSD-Validierung · DB-Import",
              "PostgreSQL\nmain_db + krebs_db",
              "Schema-Migration krebs_db\neinmalig (restart: no)",
              "Schema-Migration main_db\neinmalig (restart: no)",
              "RStudio Server · Port 8091  —  R 4.4  —  ggplot2, survival, data.table, metafor, lme4, officer"),
    fill  = c("#546E7A", "#005CA9", "#003063",
              "#E65100", "#37474F", "#4E342E",
              "#78909C", "#78909C",
              "#B71C1C"),
    stringsAsFactors = FALSE
  )
  boxes$xc = (boxes$xmin + boxes$xmax) / 2
  boxes$yc  = (boxes$ymin + boxes$ymax) / 2

  sl = data.frame(
    x   = c(5, 5, 5, 5),
    y   = c(8.85, 6.72, 4.8, 3.12),
    txt = c("NUTZER- & FRONTEND-SCHICHT",
            "BACKEND- & QUEUE-SCHICHT",
            "MIGRATIONS  (einmalig · restart: no)",
            "ANALYSE-SCHICHT  (direkter DB-Zugriff über krebs-net)")
  )

  ggplot() +
    # Zeilen-Hintergrund
    annotate("rect", xmin = 0, xmax = 10, ymin = 6.8,  ymax = 8.65, fill = "#EEF2F5", color = NA) +
    annotate("rect", xmin = 0, xmax = 10, ymin = 4.7,  ymax = 6.55, fill = "#FFF8EC", color = NA) +
    annotate("rect", xmin = 0, xmax = 10, ymin = 3.25, ymax = 4.65, fill = "#F1F8E9", color = NA) +
    annotate("rect", xmin = 0, xmax = 10, ymin = 0.8,  ymax = 2.85, fill = "#FFF0F0", color = NA) +
    # Container-Boxen
    geom_rect(data = boxes,
              aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = fill),
              color = "white", linewidth = 0.7) +
    # Migrations-Boxen: gestrichelter Rand als visueller Hinweis "einmalig"
    annotate("rect", xmin = 0.05, xmax = 4.95, ymin = 3.5, ymax = 4.4,
             fill = NA, color = "white", linewidth = 0.5, linetype = "dashed") +
    annotate("rect", xmin = 5.05, xmax = 9.95, ymin = 3.5, ymax = 4.4,
             fill = NA, color = "white", linewidth = 0.5, linetype = "dashed") +
    scale_fill_identity() +
    # Container-Namen
    geom_text(data = boxes, aes(x = xc, y = yc + 0.35, label = label),
              color = "white", fontface = "bold", size = 3.2, hjust = 0.5) +
    # Sub-Labels
    geom_text(data = boxes, aes(x = xc, y = yc - 0.2, label = sub),
              color = "#E0E0E0", size = 2.2, hjust = 0.5, lineheight = 0.88) +
    # Schicht-Labels
    geom_text(data = sl, aes(x = x, y = y, label = txt),
              color = "#607D8B", size = 2.3, fontface = "bold", hjust = 0.5) +
    # ── Pfeile ──
    # Browser → ingress
    annotate("text",    x = 0.1,  y = 7.75, label = "Browser\n►",
             hjust = 0, size = 1.9, color = "#607D8B", lineheight = 0.8) +
    annotate("segment", x = 0.72, xend = 0.74, y = 7.75, yend = 7.75,
             arrow = arrow(length = unit(0.15, "cm"), type = "closed"),
             color = "#90A4AE", linewidth = 0.7) +
    # ingress → krebs-web
    annotate("segment", x = 2.41, xend = 2.49, y = 7.75, yend = 7.75,
             arrow = arrow(length = unit(0.15, "cm"), type = "closed"),
             color = "#90A4AE", linewidth = 0.7) +
    # krebs-web ↔ krebs-api
    annotate("segment", x = 5.82, xend = 5.88, y = 7.75, yend = 7.75,
             arrow = arrow(length = unit(0.15, "cm"), type = "closed", ends = "both"),
             color = "#90A4AE", linewidth = 0.7) +
    # krebs-api → job-queue (gestrichelt, diagonal)
    annotate("segment", x = 6.5, xend = 3.0, y = 7.1, yend = 6.3,
             arrow = arrow(length = unit(0.15, "cm"), type = "closed"),
             color = "#90A4AE", linewidth = 0.5, linetype = "dashed") +
    # krebs-api → central-db (vertikal)
    annotate("segment", x = 8.15, xend = 8.15, y = 7.1, yend = 6.3,
             arrow = arrow(length = unit(0.15, "cm"), type = "closed"),
             color = "#90A4AE", linewidth = 0.7) +
    # job-queue → import-worker
    annotate("segment", x = 3.06, xend = 3.13, y = 5.65, yend = 5.65,
             arrow = arrow(length = unit(0.15, "cm"), type = "closed"),
             color = "#90A4AE", linewidth = 0.7) +
    # import-worker → central-db
    annotate("segment", x = 6.26, xend = 6.33, y = 5.65, yend = 5.65,
             arrow = arrow(length = unit(0.15, "cm"), type = "closed"),
             color = "#90A4AE", linewidth = 0.7) +
    # krebs-db-migrations → central-db (diagonal hoch rechts)
    annotate("segment", x = 4.95, xend = 6.35, y = 3.95, yend = 5.0,
             arrow = arrow(length = unit(0.15, "cm"), type = "closed"),
             color = "#AED581", linewidth = 0.6, linetype = "dotted") +
    # main-db-migrations → central-db (vertikal)
    annotate("segment", x = 8.15, xend = 8.15, y = 4.4, yend = 5.0,
             arrow = arrow(length = unit(0.15, "cm"), type = "closed"),
             color = "#AED581", linewidth = 0.6, linetype = "dotted") +
    # krebs-code ↔ central-db (rechts vorbei an Migrations-Schicht)
    annotate("segment", x = 9.7, xend = 9.7, y = 2.6, yend = 5.0,
             arrow = arrow(length = unit(0.15, "cm"), type = "closed", ends = "both"),
             color = "#E57373", linewidth = 0.8) +
    # Pfeil-Labels
    annotate("text", x = 4.6,  y = 6.85, label = "Job enqueue",
             size = 1.8, color = "#90A4AE", hjust = 0.5) +
    annotate("text", x = 8.45, y = 6.85, label = "R/W",
             size = 1.9, color = "#90A4AE", hjust = 0) +
    annotate("text", x = 9.75, y = 3.8,  label = "Analyse\nR/W",
             size = 1.9, color = "#E57373", hjust = 0, lineheight = 0.85) +
    # Footer
    annotate("text", x = 5, y = 0.2,
             label = "Docker-Netzwerk krebs-net  ·  Volumes: krebs-db (DB-Daten), upload-data (XML-Uploads)",
             size = 1.8, color = "#9E9E9E", hjust = 0.5) +
    xlim(0, 10) + ylim(0, 9.1) +
    theme_void() +
    theme(plot.background = element_rect(fill = "white", color = NA),
          plot.margin = margin(4, 6, 2, 6))
})

ggsave(arch_png, arch_p, width = 9.4, height = 5.5, dpi = 200, bg = "white")

prs = neue_folie(prs)

prs = ph_with(prs,
  value = fmt_titel("KIKA — System-Architektur (9 Container)"),
  location = ph_location(left = 0.5, top = 0.25, width = 9, height = 0.6))

prs = ph_with(prs,
  value = external_img(arch_png, width = 9.4, height = 5.5),
  location = ph_location(left = 0.3, top = 0.95, width = 9.4, height = 5.5))

prs = ph_with(prs,
  value = fpar(
    ftext("Alle Container laufen auf ubuntu-ai (192.168.2.7 / LAN) via Docker Compose — Projekt: hkr-clean",
          fp_text(font.size = 10, color = HH_DUNKELGRAU, font.family = FONT_TEXT))
  ),
  location = ph_location(left = 0.3, top = 6.55, width = 9.4, height = 0.35))

# ============================================================
# SPEICHERN
# ============================================================
output_datei = "MULTI_Federated_Prozess.pptx"
print(prs, target = output_datei)
cat("\nPraesentationsdatei gespeichert:", output_datei, "\n")
cat("Folien: 9 | Format: Widescreen 10x7.5 inch\n")
