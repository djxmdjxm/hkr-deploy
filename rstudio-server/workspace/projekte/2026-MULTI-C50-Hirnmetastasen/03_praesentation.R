# =============================================================================
# KIKA – Federated Multi-Register-Analyse: C50 Hirnmetastasen
# 03_praesentation.R — Erstellt PowerPoint-Präsentation zum Prozess
#
# Paket: officer (CRAN)
# Output: MULTI_Federated_Prozess.pptx
# =============================================================================

rm(list = ls())

if (!require("officer",   quietly = TRUE)) install.packages("officer")
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

# Schriften
FONT_TITEL = "Calibri"
FONT_TEXT  = "Calibri"

# ============================================================
# HILFSFUNKTIONEN
# ============================================================

# Fügt eine neue Folie mit Layout hinzu und setzt Hintergrundfarbe
neue_folie = function(prs, layout = "Blank") {
  add_slide(prs, layout = layout, master = "Office Theme")
}

# Textformat-Shortcuts
fmt_titel = function(text, sz = 28, bold = TRUE, color = HH_DUNKELBLAU) {
  fpar(ftext(text, fp_text(font.size = sz, bold = bold,
                           color = color, font.family = FONT_TITEL)))
}

fmt_untertitel = function(text, sz = 16, color = HH_DUNKELGRAU) {
  fpar(ftext(text, fp_text(font.size = sz, bold = FALSE,
                           color = color, font.family = FONT_TEXT)))
}

fmt_text = function(text, sz = 14, bold = FALSE, color = "#222222") {
  fpar(ftext(text, fp_text(font.size = sz, bold = bold,
                           color = color, font.family = FONT_TEXT)))
}

fmt_bullet = function(text, sz = 13, color = "#222222", indent = 0.3) {
  fpar(
    ftext(paste0("•  ", text),
          fp_text(font.size = sz, color = color, font.family = FONT_TEXT)),
    fp_p = fp_par(padding.left = round(indent * 72))
  )
}

fmt_bullet2 = function(text, sz = 12, color = HH_DUNKELGRAU) {
  fpar(
    ftext(paste0("    ◦  ", text),
          fp_text(font.size = sz, color = color, font.family = FONT_TEXT)),
    fp_p = fp_par(padding.left = 43)
  )
}

# Positionierter Text-Platzhalter
textbox = function(prs, content, left, top, width, height,
                   bg = NULL, border_color = NULL, border_width = 0) {
  ph_pos = ph_location(left = left, top = top, width = width, height = height)
  if (!is.null(bg)) {
    prs = ph_with(prs, value = block_list(content[[1]]),
                  location = ph_pos)
  } else {
    bl = if (length(content) == 1) block_list(content[[1]])
         else do.call(block_list, content)
    prs = ph_with(prs, value = bl, location = ph_pos)
  }
  prs
}

# Farbige Box (Rechteck als Hintergrund-Element)
farbige_box = function(prs, left, top, width, height,
                       fill = HH_DUNKELBLAU, text = "", text_color = WEISS,
                       font_size = 13, bold = FALSE) {
  loc = ph_location(left = left, top = top, width = width, height = height)
  prs = ph_with(
    prs,
    value = fpar(ftext(text, fp_text(font.size = font_size, bold = bold,
                                     color = text_color, font.family = FONT_TEXT)),
                 fp_p = fp_par(text.align = "center")),
    location = loc
  )
  prs
}

# ============================================================
# PRÄSENTATION ERSTELLEN
# ============================================================
prs = read_pptx()

BREITE = 10   # inches (Widescreen 16:9)
HOEHE  = 7.5

# ============================================================
# FOLIE 1: TITELFOLIE
# ============================================================
prs = neue_folie(prs)

# Hintergrund-Balken oben
prs = ph_with(prs,
  value = fpar(ftext("", fp_text(font.size = 1))),
  location = ph_location(left = 0, top = 0, width = BREITE, height = 2.2))

# Haupttitel
prs = ph_with(prs,
  value = block_list(
    fpar(ftext("Federated Datenanalyse", fp_text(font.size = 36, bold = TRUE,
               color = HH_DUNKELBLAU, font.family = FONT_TITEL))),
    fpar(ftext("mit 15 Landeskrebsregistern",
               fp_text(font.size = 36, bold = TRUE, color = HH_BLAU,
                       font.family = FONT_TITEL)))
  ),
  location = ph_location(left = 0.5, top = 1.3, width = 9, height = 1.6))

# Untertitel
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

# Footer
prs = ph_with(prs,
  value = fpar(ftext(paste0("Hamburg Krebsregister (KIKA) | ", format(Sys.Date(), "%B %Y")),
               fp_text(font.size = 11, color = HH_DUNKELGRAU, font.family = FONT_TEXT))),
  location = ph_location(left = 0.5, top = 6.8, width = 9, height = 0.4))

# Trennlinie als schmaler blauer Balken
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
    fpar(ftext("Epidemiologische Fragestellung", fp_text(font.size = 15, bold = TRUE,
               color = HH_DUNKELBLAU, font.family = FONT_TITEL))),
    fpar(ftext("")),
    fmt_bullet("Unterscheidet sich die Hirnmetastasen-Rate bei C50 nach molekularem Subtyp?"),
    fmt_bullet("Gibt es einen zeitlichen Trend? Ist das Muster in allen Registern stabil?"),
    fmt_bullet("Methoden: Kaplan-Meier, Competing Risks (CIF), Cox-Regression, Poisson-Trend"),
    fpar(ftext("")),
    fpar(ftext("Herausforderung: Datenschutz & Dezentralisierung", fp_text(font.size = 15,
               bold = TRUE, color = HH_DUNKELBLAU, font.family = FONT_TITEL))),
    fpar(ftext("")),
    fmt_bullet("15 Landeskrebsregister — jedes unterliegt eigenen Datenschutzgesetzen"),
    fmt_bullet("Einzelfalldaten duerfen das jeweilige Register NICHT verlassen"),
    fmt_bullet("Herkoemmliche Datenpoolierung ist rechtlich nicht moeglich"),
    fpar(ftext("")),
    fpar(ftext("Loesung: Federated Analysis", fp_text(font.size = 15, bold = TRUE,
               color = HH_ROT, font.family = FONT_TITEL))),
    fpar(ftext("")),
    fmt_bullet("Nur aggregierte Summary Statistics verlassen das Register"),
    fmt_bullet("Methodisch aequivalent zur zentralisierten Analyse (exaktes Pooling)")
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
    fpar(ftext("NICHT erlaubt", fp_text(font.size = 14, bold = TRUE,
               color = HH_ROT, font.family = FONT_TITEL))),
    fpar(ftext("")),
    fmt_bullet("Patientenlisten oder Einzelfalldaten", sz = 12, color = "#333333"),
    fmt_bullet("Diagnose- und Verlaufsdaten je Patient", sz = 12, color = "#333333"),
    fmt_bullet("Zellen mit N < 5 (DSGVO-Mindestzahl)", sz = 12, color = "#333333"),
    fmt_bullet("Jede Kombination, die Rueckschluesse auf Einzelpersonen ermoeglicht",
               sz = 12, color = "#333333")
  ),
  location = ph_location(left = 0.4, top = 1.1, width = 4.3, height = 3.0))

# Rechte Spalte: Erlaubt
prs = ph_with(prs,
  value = block_list(
    fpar(ftext("ERLAUBT (aggregierte Statistiken)", fp_text(font.size = 14, bold = TRUE,
               color = "#2E7D32", font.family = FONT_TITEL))),
    fpar(ftext("")),
    fmt_bullet("KM-Ereignistabelle: t, n.risk, n.event", sz = 12, color = "#333333"),
    fmt_bullet("Cox-Koeffizientenvektor + Varianz-Kovarianz-Matrix", sz = 12, color = "#333333"),
    fmt_bullet("Counts + Personenjahre je Stratum (N >= 5)", sz = 12, color = "#333333"),
    fmt_bullet("Median-FU, Ereignisraten je Subtyp (aggregiert)", sz = 12, color = "#333333")
  ),
  location = ph_location(left = 5.3, top = 1.1, width = 4.3, height = 3.0))

# Trennlinie vertikal (als Textbox-Umrandung simuliert)
prs = ph_with(prs,
  value = fpar(ftext("|", fp_text(font.size = 60, color = HH_GRAU))),
  location = ph_location(left = 4.85, top = 1.1, width = 0.3, height = 3.0))

# Grundsatz-Box unten
prs = ph_with(prs,
  value = block_list(
    fpar(ftext("Grundsatz: Die Analyse kommt zu den Daten — nicht die Daten zur Analyse.",
               fp_text(font.size = 14, bold = TRUE, color = WEISS,
                       font.family = FONT_TITEL)),
         fp_p = fp_par(text.align = "center")),
    fpar(ftext("")),
    fpar(ftext("Jedes Register fuehrt dieselben Skripte auf seinen eigenen Daten aus.",
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

# Stufe 1: Register-Boxen
prs = ph_with(prs,
  value = block_list(
    fpar(ftext("STUFE 1 — In jedem der 15 Register (lokal)", fp_text(font.size = 13,
               bold = TRUE, color = WEISS, font.family = FONT_TITEL)),
         fp_p = fp_par(text.align = "center"))
  ),
  location = ph_location(left = 0.3, top = 1.1, width = 4.2, height = 0.45))

prs = ph_with(prs,
  value = block_list(
    fmt_bullet("Datenbank-Abfrage (lokal, KIKA-Schema)", sz = 11),
    fmt_bullet("Subtyp-Klassifikation (ER/PR/HER2)", sz = 11),
    fmt_bullet("Zeitvariablen berechnen (OS, CIF)", sz = 11),
    fmt_bullet("Summary Statistics aggregieren", sz = 11),
    fmt_bullet("DSGVO-Pruefung: N < 5 supprimieren", sz = 11),
    fmt_bullet("Export: {REGISTER}_export.rds", sz = 11)
  ),
  location = ph_location(left = 0.3, top = 1.65, width = 4.2, height = 2.8))

# Pfeil
prs = ph_with(prs,
  value = fpar(ftext("  ➤  ", fp_text(font.size = 32, color = HH_BLAU))),
  location = ph_location(left = 4.5, top = 2.2, width = 1.0, height = 0.8))

# Stufe 2: HKR-Box
prs = ph_with(prs,
  value = block_list(
    fpar(ftext("STUFE 2 — Zentral bei HKR", fp_text(font.size = 13, bold = TRUE,
               color = WEISS, font.family = FONT_TITEL)),
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

# Zeitplan-Leiste
prs = ph_with(prs,
  value = block_list(
    fpar(ftext("Zeitlicher Ablauf", fp_text(font.size = 13, bold = TRUE,
               color = HH_DUNKELBLAU, font.family = FONT_TITEL))),
    fpar(ftext("")),
    fpar(ftext(
      paste0(
        "Phase 1: Abstimmung Skripte & Kodierungen (alle Register, 4 Wochen)     |     ",
        "Phase 2: Lokale Laeufe in jedem Register (2 Wochen)     |     ",
        "Phase 3: Zentrale Meta-Analyse & Bericht (2 Wochen)"
      ),
      fp_text(font.size = 10, color = "#333333", font.family = FONT_TEXT)),
      fp_p = fp_par(text.align = "left"))
  ),
  location = ph_location(left = 0.3, top = 4.8, width = 9.4, height = 1.4))

# ============================================================
# FOLIE 5: WAS JEDES REGISTER EXPORTIERT
# ============================================================
prs = neue_folie(prs)

prs = ph_with(prs,
  value = fmt_titel("Export-Statistiken: Was jedes Register liefert"),
  location = ph_location(left = 0.5, top = 0.3, width = 9, height = 0.7))

export_tab = data.frame(
  Export     = c("A: KM-Ereignistabelle OS",
                 "B: KM-Ereignistabelle BM",
                 "C: Cox-Koeffizienten OS",
                 "D: Cox-Koeffizienten BM",
                 "E: Poisson-Zaehltabelle",
                 "F: Deskriptivstatistik"),
  Inhalt     = c("t, n.risk, n.event, n.censor je Subtyp",
                 "t, n.risk, n.event, n.censor je Subtyp",
                 "coef + Var-Kov-Matrix + N + Events",
                 "coef + Var-Kov-Matrix + N + Events",
                 "Counts + PJ nach Subtyp x Alter x Jahr",
                 "N, BM-Rate, Median-FU je Subtyp"),
  Datenschutz = c("Kein Einzelfall", "Kein Einzelfall", "Kein Einzelfall",
                  "Kein Einzelfall", "N<5 supprimiert", "N<5 supprimiert"),
  Verwendung  = c("Gepoolte KM exakt", "Gepoolte CIF",
                  "Random-Effects-Meta-Analyse", "Random-Effects-Meta-Analyse",
                  "Poisson GLMM, INLA", "Uebersichtstabelle"),
  stringsAsFactors = FALSE
)

ft_loc = ph_location(left = 0.3, top = 1.1, width = 9.4, height = 5.5)

# Tabelle als formatierter Text (officer table)
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
                            font.family = FONT_TEXT)))),
    unlist(tab_rows, recursive = FALSE)
  )),
  location = ft_loc)

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
         "Jedes Register liefert die vollstaendige Ereignistabelle (t, n.risk, n.event).",
         "Zentral: Summiere n.risk und n.event an jedem Zeitpunkt ueber alle Register.",
         "Ergebnis ist identisch mit KM auf dem gepoolten Datensatz — kein Informationsverlust.",
         "Greenwood-Varianz fuer 95%-KI auf dem gepoolten Schaetzer."
       )),
  list(titel = "Cox-Regression (Two-Stage Meta-Analyse)",
       zeilen = c(
         "Jedes Register schaetzt coxph() mit identischer Formel (definiert in 00_config.R).",
         "Export: Koeffizientenvektor + Varianz-Kovarianz-Matrix.",
         "Zentral: Random-Effects-Meta-Analyse mit metafor::rma() (REML).",
         "I²-Statistik quantifiziert Heterogenitaet zwischen den Registern."
       )),
  list(titel = "Poisson-Trendmodell (Mixed Model)",
       zeilen = c(
         "Jedes Register exportiert Counts + Personenjahre nach Subtyp x Alter x Jahr.",
         "Zentral: Poisson GLMM mit Register als Random Intercept (lme4::glmer).",
         "Liefert adjustierte Inzidenz-Rate-Ratios mit 95%-KI.",
         "Ermoeglicht Trendanalyse ueber Diagnosejahre bei Kontrolle fuer Alter."
       )),
  list(titel = "Bayesianische Glaettung (INLA RW1)",
       zeilen = c(
         "Aggregierte Counts + PJ (ueber Register summiert) als Input.",
         "Random-Walk-1-Prior ueber Diagnosejahr: zeitlich geglatteter Trend.",
         "95%-Kredibilitaetsintervall statt Konfidenzintervall.",
         "Vorteil: stabile Schaetzung auch bei kleinen Registern / seltenen Ereignissen."
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

# Linke Spalte: Dateistruktur
prs = ph_with(prs,
  value = block_list(
    fpar(ftext("Projektordner", fp_text(font.size = 13, bold = TRUE,
               color = HH_DUNKELBLAU, font.family = FONT_TITEL))),
    fpar(ftext("")),
    fpar(ftext("2026-MULTI-C50-Hirnmetastasen/",
               fp_text(font.size = 11, bold = TRUE, font.family = "Courier New",
                       color = "#333333"))),
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

# Rechte Spalte: Zuordnung Register / HKR
prs = ph_with(prs,
  value = block_list(
    fpar(ftext("Wer fuehrt was aus?", fp_text(font.size = 13, bold = TRUE,
               color = HH_DUNKELBLAU, font.family = FONT_TITEL))),
    fpar(ftext("")),
    fpar(ftext("Jedes Register (lokal):", fp_text(font.size = 12, bold = TRUE,
               color = HH_BLAU, font.family = FONT_TEXT))),
    fmt_bullet("00_config.R sourct (shared definition)", sz = 11),
    fmt_bullet("01_lokal_export.R ausfuehren", sz = 11),
    fmt_bullet("exports/{REG}_export.rds an HKR senden", sz = 11),
    fpar(ftext("")),
    fpar(ftext("HKR (zentral):", fp_text(font.size = 12, bold = TRUE,
               color = HH_ROT, font.family = FONT_TEXT))),
    fmt_bullet("Alle RDS-Dateien in exports/ ablegen", sz = 11),
    fmt_bullet("02_zentral_meta.R ausfuehren", sz = 11),
    fmt_bullet("Alle Grafiken + CSVs werden erzeugt", sz = 11),
    fpar(ftext("")),
    fpar(ftext("Hinweis:", fp_text(font.size = 12, bold = TRUE,
               color = HH_DUNKELGRAU, font.family = FONT_TEXT))),
    fmt_bullet("00_config.R wird vorab abgestimmt und", sz = 11),
    fmt_bullet("unveraendert an alle Register verteilt.", sz = 11)
  ),
  location = ph_location(left = 5.1, top = 1.1, width = 4.6, height = 4.5))

# ============================================================
# FOLIE 8: NAECHSTE SCHRITTE
# ============================================================
prs = neue_folie(prs)

prs = ph_with(prs,
  value = fmt_titel("Nächste Schritte"),
  location = ph_location(left = 0.5, top = 0.3, width = 9, height = 0.7))

schritte = list(
  list(nr = "1", titel = "Abstimmung 00_config.R mit allen Registern",
       details = c(
         "Subtyp-Kodierungen (oBDS-Codes) pruefen — Register-spezifische Abweichungen?",
         "Datenbankschema: Spaltennamen und JSONB-Felder verifizieren",
         "Anpassung DB_HOST / Credentials in 01_lokal_export.R je Register"
       )),
  list(nr = "2", titel = "Pilotlauf mit einem Testregister",
       details = c(
         "Synthetische Daten generieren (XML-Generator v3) als Fallback",
         "01_lokal_export.R vollstaendig testen — Pruefdatei kontrollieren",
         "Ergebnis an HKR senden und 02_zentral_meta.R mit 1 Register testen"
       )),
  list(nr = "3", titel = "Roll-out auf alle 15 Register",
       details = c(
         "Rollout-Reihenfolge nach Datenverfuegbarkeit und Kapazitaet",
         "Jedes Register prueft Pruefdatei vor Weitergabe (DSGVO-Kontrolle)",
         "HKR sammelt RDS-Dateien und fuehrt Gesamtanalyse durch"
       )),
  list(nr = "4", titel = "Ergebnisse & Publikation",
       details = c(
         "Grafiken + Tabellen aus 02_zentral_meta.R fuer Manuskript",
         "Methodik-Abschnitt: Federated Analysis, Two-Stage, INLA",
         "Sensitivitaetsanalysen: Fixed vs. Random Effects, Zeitfenster"
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
# SPEICHERN
# ============================================================
output_datei = "MULTI_Federated_Prozess.pptx"
print(prs, target = output_datei)
cat("\nPraesentationsdatei gespeichert:", output_datei, "\n")
cat("Folien: 8 | Format: Widescreen 10x7.5 inch\n")
