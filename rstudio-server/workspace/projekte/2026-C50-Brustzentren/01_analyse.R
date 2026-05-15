# ============================================================
# KIKA – C50 Mammakarzinom: Operationen in zertifizierten
# Brustzentren Hamburg
# Datenquelle: KIKA-Datenbank (PostgreSQL) +
#              Referenztabelle data/referenz_op_zentren_hamburg.csv
# Erstellt:    2026-05-15
#
# Source ausfuehren: Strg+Shift+S  oder  Source-Button
# Ergebnisse: Konsole + PNG/PDF + Excel in outputs/
# ============================================================

rm(list = ls())
graphics.off()

# ============================================================
# PAKETE
# ============================================================
library(DBI)
library(RPostgres)
library(data.table)
library(ggplot2)
library(openxlsx)

# Hamburg Corporate Design
hh_blau       <- "#005CA9"
hh_rot        <- "#E10019"
hh_dunkelblau <- "#003063"
hh_dunkelgrau <- "#757575"

# Output-Verzeichnis
OUT <- file.path(getwd(), "outputs")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

# ============================================================
# REFERENZTABELLE LADEN
# ============================================================
ref_pfad <- file.path(getwd(), "data", "referenz_op_zentren_hamburg.csv")
if (!file.exists(ref_pfad)) stop("Referenztabelle nicht gefunden: ", ref_pfad)
op_zentren <- fread(ref_pfad)
cat("Referenztabelle geladen:", nrow(op_zentren), "Faelle mit Zentrumszuordnung\n")

# ============================================================
# DATENBANKVERBINDUNG
# ============================================================
con <- dbConnect(
  RPostgres::Postgres(),
  host     = "central-db",
  port     = 5432,
  dbname   = "krebs",
  user     = "postgres",
  password = "1234"
)
cat("Datenbankverbindung hergestellt.\n")

# ============================================================
# DATEN LADEN
# ============================================================

# Basis: C50-Tumoren mit Patientendaten
basis <- as.data.table(dbGetQuery(con, "
  SELECT
    pr.patient_id,
    pr.gender,
    pr.date_of_birth,
    tr.id           AS tr_id,
    tr.tumor_id,
    tr.diagnosis_date,
    tr.icd->>'code' AS icd_code
  FROM patient_report pr
  JOIN tumor_report   tr ON tr.patient_report_id = pr.id
  WHERE tr.icd->>'code' LIKE 'C50%'
"))
cat("C50-Tumorfaelle geladen:", nrow(basis), "\n")

# Frueheste OP pro Tumor
if (nrow(basis) > 0) {
  tr_ids <- paste(unique(basis$tr_id), collapse = ",")
  ops <- as.data.table(dbGetQuery(con, sprintf("
    SELECT
      tumor_report_id AS tr_id,
      date            AS op_datum,
      intent
    FROM tumor_surgery
    WHERE tumor_report_id IN (%s)
    ORDER BY tumor_report_id, date
  ", tr_ids)))
} else {
  ops <- data.table()
}

dbDisconnect(con)
cat("Datenbankverbindung geschlossen.\n\n")

# ============================================================
# DATEN AUFBEREITEN
# ============================================================
basis[, diagnosis_date := as.Date(diagnosis_date)]
basis[, date_of_birth  := as.Date(date_of_birth)]
basis[, diagnosejahr   := as.integer(format(diagnosis_date, "%Y"))]
basis[, diagnosealter  := as.integer(floor(
  as.numeric(diagnosis_date - date_of_birth) / 365.25
))]

# Erste C50-Diagnose pro Patientin
setorder(basis, patient_id, diagnosis_date)
dat <- basis[, .SD[1], by = patient_id]
cat("Erste C50-Diagnose pro Patientin:", nrow(dat), "\n")

# Frueheste OP pro Tumor joinen
if (nrow(ops) > 0) {
  ops[, op_datum := as.Date(op_datum)]
  ops_first <- ops[order(tr_id, op_datum)][, .SD[1], by = tr_id]
  dat <- merge(dat, ops_first[, .(tr_id, op_datum, intent)],
               by = "tr_id", all.x = TRUE)
} else {
  dat[, c("op_datum", "intent") := list(as.Date(NA), NA_character_)]
}
dat[, operiert := !is.na(op_datum)]

# ============================================================
# JOIN MIT REFERENZTABELLE (tumor_id → OP_Zentrum)
# ============================================================
dat <- merge(dat, op_zentren, by = "tumor_id", all.x = TRUE)
dat[, in_zertifiziertem_zentrum := !is.na(OP_Zentrum)]

# ============================================================
# KENNZAHLEN
# ============================================================
n_ges     <- nrow(dat)
n_op      <- dat[operiert == TRUE, .N]
n_zentrum <- dat[in_zertifiziertem_zentrum == TRUE, .N]
n_op_kein <- dat[operiert == TRUE & in_zertifiziertem_zentrum == FALSE, .N]
n_nicht_op <- dat[operiert == FALSE, .N]
pct_zentrum <- round(100 * n_zentrum / max(n_op, 1), 1)

cat("============================================================\n")
cat("ERGEBNISSE: Operationen in zertifizierten Brustzentren\n")
cat("============================================================\n")
cat(sprintf("Patientinnen gesamt (C50):             %d\n", n_ges))
cat(sprintf("Davon operiert:                        %d (%.1f%%)\n",
    n_op, 100 * n_op / n_ges))
cat(sprintf("  In zertifiziertem Zentrum:           %d (%.1f%% der Operierten)\n",
    n_zentrum, pct_zentrum))
cat(sprintf("  Operiert, Zentrum unbekannt/extern:  %d (%.1f%% der Operierten)\n",
    n_op_kein, 100 * n_op_kein / max(n_op, 1)))
cat(sprintf("Nicht operiert:                        %d (%.1f%%)\n",
    n_nicht_op, 100 * n_nicht_op / n_ges))

# Verteilung nach Zentrum
cat("\n--- Faelle pro Zentrum ---\n")
zentrum_tab <- dat[in_zertifiziertem_zentrum == TRUE,
                   .N, by = OP_Zentrum][order(-N)]
zentrum_tab[, pct_von_operierten := round(100 * N / max(n_op, 1), 1)]
print(zentrum_tab)

# Altersgruppen
dat[, ag_gr := fcase(
  diagnosealter <  40,                                    "<40",
  diagnosealter >= 40 & diagnosealter < 50, "40-49",
  diagnosealter >= 50 & diagnosealter < 60, "50-59",
  diagnosealter >= 60 & diagnosealter < 70, "60-69",
  diagnosealter >= 70 & diagnosealter < 80, "70-79",
  diagnosealter >= 80,                                    ">=80",
  default = NA_character_
)]
dat[, ag_gr := factor(ag_gr,
    levels = c("<40","40-49","50-59","60-69","70-79",">=80"))]

ag_zentrum <- dat[, .(
  n_total   = .N,
  n_zentrum = sum(in_zertifiziertem_zentrum, na.rm = TRUE),
  pct       = round(100 * sum(in_zertifiziertem_zentrum, na.rm = TRUE) / .N, 1)
), by = ag_gr][order(ag_gr)]

cat("\n--- Zentrumsquote nach Altersgruppe ---\n")
print(ag_zentrum)

# ============================================================
# GRAFIKEN
# ============================================================

# G1: Operationsstatus gesamt (gestapelter Ueberblick)
status_dt <- data.table(
  Kategorie = factor(
    c("Zertifiziertes Zentrum", "Kein Zentrum / extern", "Nicht operiert"),
    levels = c("Zertifiziertes Zentrum", "Kein Zentrum / extern", "Nicht operiert")
  ),
  N = c(n_zentrum, n_op_kein, n_nicht_op)
)
status_dt[, pct := round(100 * N / n_ges, 1)]

p1 <- ggplot(status_dt, aes(x = Kategorie, y = N, fill = Kategorie)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = paste0(N, "\n(", pct, "%)")),
            vjust = -0.3, size = 4, color = hh_dunkelblau) +
  scale_fill_manual(values = c(
    "Zertifiziertes Zentrum"  = hh_blau,
    "Kein Zentrum / extern"   = hh_dunkelgrau,
    "Nicht operiert"          = "#D0D8E4"
  )) +
  expand_limits(y = max(status_dt$N) * 1.2) +
  labs(
    title    = "C50 Mammakarzinom: OP in zertifiziertem Brustzentrum",
    subtitle = sprintf("Hamburg | N = %d Patientinnen", n_ges),
    x = NULL, y = "Anzahl Patientinnen",
    caption  = "Datenquelle: KIKA-Datenbank | Referenz: DKG-zertifizierte Brustzentren Hamburg"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    legend.position = "none",
    plot.title    = element_text(color = hh_dunkelblau, face = "bold"),
    plot.subtitle = element_text(color = hh_dunkelgrau),
    plot.caption  = element_text(color = "#A0A0A0", size = 8)
  )
ggsave(file.path(OUT, "01_op_status_gesamt.png"), p1, width = 7, height = 5, dpi = 300)
ggsave(file.path(OUT, "01_op_status_gesamt.pdf"), p1, width = 7, height = 5)
cat("\nGrafik gespeichert: 01_op_status_gesamt\n")

# G2: Faelle pro Zentrum
p2 <- ggplot(zentrum_tab,
             aes(x = reorder(OP_Zentrum, N), y = N)) +
  geom_col(fill = hh_blau, width = 0.7) +
  geom_text(aes(label = paste0(N, "  (", pct_von_operierten, "%)")),
            hjust = -0.05, size = 3.5, color = hh_dunkelblau) +
  coord_flip() +
  expand_limits(y = max(zentrum_tab$N) * 1.3) +
  labs(
    title    = "Faelle pro zertifiziertem Brustzentrum",
    subtitle = sprintf("N = %d Patientinnen in Zentrumsversorgung", n_zentrum),
    x = NULL, y = "Anzahl Patientinnen"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title    = element_text(color = hh_dunkelblau, face = "bold"),
    plot.subtitle = element_text(color = hh_dunkelgrau)
  )
ggsave(file.path(OUT, "02_faelle_pro_zentrum.png"), p2, width = 8, height = 5, dpi = 300)
ggsave(file.path(OUT, "02_faelle_pro_zentrum.pdf"), p2, width = 8, height = 5)
cat("Grafik gespeichert: 02_faelle_pro_zentrum\n")

# G3: Zentrumsquote nach Altersgruppe
p3 <- ggplot(ag_zentrum[!is.na(ag_gr)], aes(x = ag_gr, y = pct)) +
  geom_col(fill = hh_blau, width = 0.6) +
  geom_text(aes(label = paste0(pct, "%")),
            vjust = -0.4, size = 3.8, color = hh_dunkelblau) +
  scale_y_continuous(limits = c(0, 100),
                     labels = function(x) paste0(x, "%")) +
  labs(
    title    = "Zentrumsquote nach Altersgruppe",
    subtitle = "Anteil Patientinnen mit OP in zertifiziertem Brustzentrum",
    x = "Altersgruppe bei Diagnose", y = "Anteil (%)"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title    = element_text(color = hh_dunkelblau, face = "bold"),
    plot.subtitle = element_text(color = hh_dunkelgrau)
  )
ggsave(file.path(OUT, "03_zentrumsquote_altersgruppe.png"), p3, width = 7, height = 5, dpi = 300)
ggsave(file.path(OUT, "03_zentrumsquote_altersgruppe.pdf"), p3, width = 7, height = 5)
cat("Grafik gespeichert: 03_zentrumsquote_altersgruppe\n")

# ============================================================
# EXCEL-EXPORT
# ============================================================
wb <- createWorkbook()

addWorksheet(wb, "Uebersicht")
writeData(wb, "Uebersicht", data.frame(
  Kennzahl = c(
    "Patientinnen gesamt (C50)",
    "Davon operiert",
    "  In zertifiziertem Zentrum",
    "  Operiert, Zentrum unbekannt/extern",
    "Nicht operiert",
    "Zentrumsquote (% der Operierten)"
  ),
  N = c(n_ges, n_op, n_zentrum, n_op_kein, n_nicht_op, NA),
  Prozent = c(
    "100%",
    sprintf("%.1f%%", 100 * n_op / n_ges),
    sprintf("%.1f%%", pct_zentrum),
    sprintf("%.1f%%", 100 * n_op_kein / max(n_op, 1)),
    sprintf("%.1f%%", 100 * n_nicht_op / n_ges),
    sprintf("%.1f%%", pct_zentrum)
  )
))

addWorksheet(wb, "Pro_Zentrum")
writeData(wb, "Pro_Zentrum", zentrum_tab)

addWorksheet(wb, "Nach_Altersgruppe")
writeData(wb, "Nach_Altersgruppe", ag_zentrum)

saveWorkbook(wb, file.path(OUT, "C50_Brustzentren_Hamburg.xlsx"), overwrite = TRUE)
cat("Excel gespeichert: C50_Brustzentren_Hamburg.xlsx\n")

cat("\n============================================================\n")
cat("Fertig. Outputs in:", OUT, "\n")
cat("============================================================\n")
