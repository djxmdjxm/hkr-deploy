# ============================================================
# KIKA – C50 Mammakarzinom: BET vs. Mastektomie, RT nach BET
# Datenquelle: KIKA-Datenbank (PostgreSQL)
# Erstellt:    2026-04-22
#
# Source ausfuehren: Strg+Shift+S  oder  Source-Button
# Ergebnisse: Konsole + PNG/PDF + Excel im Working Directory
# ============================================================

rm(list = ls())
graphics.off()

# ============================================================
# PAKETE
# ============================================================
library(DBI)
library(RPostgres)
library(data.table)
library(jsonlite)
library(ggplot2)
library(sf)
library(openxlsx)

# Hamburg Corporate Design
hh_blau       <- "#005CA9"
hh_rot        <- "#E10019"
hh_dunkelblau <- "#003063"
hh_dunkelgrau <- "#757575"

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

# Basis: C50-Tumoren mit Patientendaten und Histologie
basis <- as.data.table(dbGetQuery(con, "
  SELECT
    pr.patient_id,
    pr.gender,
    pr.date_of_birth,
    pr.is_deceased,
    pr.vital_status_date,
    tr.id              AS tr_id,
    tr.tumor_id,
    tr.diagnosis_date,
    tr.icd->>'code'    AS icd_code,
    tr.laterality,
    th.grading
  FROM patient_report pr
  JOIN tumor_report    tr ON tr.patient_report_id = pr.id
  LEFT JOIN tumor_histology th ON th.tumor_report_id = tr.id
  WHERE tr.icd->>'code' LIKE 'C50%'
"))
cat("C50-Tumorfaelle geladen:", nrow(basis), "\n")

# Operationen (OPS-Codes als JSON-Array)
ops_raw <- rt_raw <- data.table()
if (nrow(basis) > 0) {
  tr_ids <- paste(unique(basis$tr_id), collapse = ",")

  ops_raw <- as.data.table(dbGetQuery(con, sprintf("
    SELECT tumor_report_id AS tr_id,
           date            AS op_datum,
           operations      AS ops_json
    FROM   tumor_surgery
    WHERE  tumor_report_id IN (%s)
    ORDER  BY tumor_report_id, date
  ", tr_ids)))

  # Frueheste RT-Session pro Tumor (ueber tumor_radiotherapy → radiotherapy_session)
  rt_raw <- as.data.table(dbGetQuery(con, sprintf("
    SELECT trt.tumor_report_id AS tr_id,
           MIN(rs.start_date)  AS rt_datum
    FROM   tumor_radiotherapy trt
    JOIN   radiotherapy_session rs ON rs.tumor_radiotherapy_id = trt.id
    WHERE  trt.tumor_report_id IN (%s)
    GROUP  BY trt.tumor_report_id
  ", tr_ids)))
}
dbDisconnect(con)
cat("Datenbankverbindung geschlossen.\n\n")

# ============================================================
# OPS-CODES PARSEN
# ============================================================
if (nrow(ops_raw) > 0) {
  # Ersten OP pro Tumor (zeitlich)
  ops_first <- ops_raw[order(tr_id, op_datum)][, .SD[1], by = tr_id]

  # OPS-Codes aus JSON-Array: [{code: "5-870.x", version: "..."}, ...]
  ops_first[, ops_codes := sapply(ops_json, function(j) {
    tryCatch(paste(fromJSON(j)$code, collapse = "|"), error = function(e) NA_character_)
  })]
} else {
  ops_first <- data.table(tr_id = integer(), op_datum = as.Date(character()), ops_codes = character())
}

# ============================================================
# DATEN ZUSAMMENFUEHREN UND AUFBEREITEN
# ============================================================
dat <- copy(basis)
dat <- merge(dat, ops_first[, .(tr_id, op_datum, ops_codes)], by = "tr_id", all.x = TRUE)
dat <- merge(dat, rt_raw,                                      by = "tr_id", all.x = TRUE)

dat[, diagnosis_date := as.Date(diagnosis_date)]
dat[, date_of_birth  := as.Date(date_of_birth)]
dat[, op_datum       := as.Date(op_datum)]
dat[, rt_datum       := as.Date(rt_datum)]

dat[, diagnosejahr  := as.integer(format(diagnosis_date, "%Y"))]
dat[, diagnosealter := as.integer(floor(
  as.numeric(diagnosis_date - date_of_birth) / 365.25
))]

dat[, ag_gr := fcase(
  diagnosealter <  40,                                   "<40",
  diagnosealter >= 40 & diagnosealter < 50, "40-49",
  diagnosealter >= 50 & diagnosealter < 60, "50-59",
  diagnosealter >= 60 & diagnosealter < 70, "60-69",
  diagnosealter >= 70 & diagnosealter < 80, "70-79",
  diagnosealter >= 80,                                   ">=80",
  default = NA_character_
)]
dat[, ag_gr := factor(ag_gr, levels = c("<40","40-49","50-59","60-69","70-79",">=80"))]

# Nur erste C50-Diagnose pro Patientin
setorder(dat, patient_id, diagnosis_date)
dat <- dat[, .SD[1], by = patient_id]
cat("Erste C50-Diagnose pro Patientin:", nrow(dat), "\n\n")

# ============================================================
# OP-KLASSIFIKATION: BET / MASTEKTOMIE
# OPS: BET = 5-870.x | Mastektomie = 5-877.x, 5-872.x, 5-874.x
# ============================================================
dat[, bet  := !is.na(ops_codes) & grepl("5-870",          ops_codes)]
dat[, mast := !is.na(ops_codes) & grepl("5-877|5-872|5-874", ops_codes)]
dat[bet == TRUE & mast == TRUE, bet := FALSE]   # Mastektomie gewinnt

dat[, op_typ := fcase(
  bet  == TRUE,     "BET",
  mast == TRUE,     "Mastektomie",
  !is.na(op_datum), "Andere OP",
  default = "Keine OP"
)]

# ============================================================
# RT-VARIABLEN
# ============================================================
dat[, tage_diag_op := as.integer(op_datum - diagnosis_date)]
dat[, tage_op_rt   := as.integer(rt_datum - op_datum)]
dat[, tage_diag_rt := as.integer(rt_datum - diagnosis_date)]

# RT-Flag: zeitlich plausibel (0-730 Tage nach Diagnose)
dat[, rt          := fifelse(!is.na(rt_datum) & tage_diag_rt >= 0 & tage_diag_rt <= 730, 1L, 0L)]
dat[, rt_nach_bet := fifelse(op_typ == "BET" & rt == 1L, 1L, 0L)]

# ============================================================
# KENNZAHLEN
# ============================================================
n_ges    <- nrow(dat)
n_bet    <- dat[op_typ == "BET", .N]
n_mast   <- dat[op_typ == "Mastektomie", .N]
n_op     <- n_bet + n_mast
n_bet_rt <- dat[op_typ == "BET", sum(rt_nach_bet, na.rm = TRUE)]
rt_rate  <- round(100 * n_bet_rt / max(n_bet, 1), 1)

# ============================================================
# 1. PATIENTINNEN-CHARAKTERISTIKA
# ============================================================
cat("============================================================\n")
cat("TABELLE 1: Patientinnen-Charakteristika\n")
cat("============================================================\n")

ag_tab <- dat[, .N, by = ag_gr][order(ag_gr)]
ag_tab[, pct := round(100 * N / n_ges, 1)]
print(ag_tab)

cat(sprintf("\nAlter bei Diagnose: Median %d J. (IQR %d-%d)\n",
    median(dat$diagnosealter, na.rm = TRUE),
    quantile(dat$diagnosealter, 0.25, na.rm = TRUE),
    quantile(dat$diagnosealter, 0.75, na.rm = TRUE)))

# ICD Subkodes
icd_tab <- dat[, .N, by = icd_code][order(-N)]
icd_tab[, pct := round(100 * N / n_ges, 1)]
cat("\nICD C50 Subkodes (Top 5):\n")
print(head(icd_tab, 5))

# Grading
gr_tab <- dat[!is.na(grading), .N, by = grading][order(-N)]
gr_tab[, pct := round(100 * N / n_ges, 1)]
cat("\nGrading:\n")
print(gr_tab)

# Diagnosejahre
dj_tab <- dat[, .N, by = diagnosejahr][order(diagnosejahr)]
cat("\nDiagnosejahre:\n")
print(dj_tab)

# ============================================================
# 2. OP-TYPEN
# ============================================================
cat("\n============================================================\n")
cat("TABELLE 2: OP-Typen\n")
cat("============================================================\n")

op_tab <- dat[, .N, by = op_typ][order(-N)]
op_tab[, pct := round(100 * N / n_ges, 1)]
print(op_tab)

cat(sprintf("\nBET-Rate (BET von BET+Mast): %.1f%%\n",
    100 * n_bet / max(n_op, 1)))

# ============================================================
# 3. RT NACH BET
# ============================================================
cat("\n============================================================\n")
cat("TABELLE 3: RT nach BET\n")
cat("============================================================\n")

cat(sprintf("BET-Patientinnen gesamt: %d\n", n_bet))
cat(sprintf("Davon mit RT:            %d\n", n_bet_rt))
cat(sprintf("RT-Rate nach BET:        %.1f%%  (Ziel: 72%%)\n", rt_rate))

rt_ag <- dat[op_typ == "BET", .(
  n_bet   = .N,
  n_rt    = sum(rt_nach_bet, na.rm = TRUE),
  rt_rate = round(100 * sum(rt_nach_bet, na.rm = TRUE) / .N, 1)
), by = ag_gr][order(ag_gr)]
cat("\nRT-Rate nach BET nach Altersgruppe:\n")
print(rt_ag)

# ============================================================
# 4. ABSTAND OP -> RT
# ============================================================
cat("\n============================================================\n")
cat("TABELLE 4: Abstand OP -> RT (BET mit RT, 0-365 Tage)\n")
cat("============================================================\n")

dat_rt <- dat[op_typ == "BET" & rt_nach_bet == 1 & !is.na(tage_op_rt) &
              tage_op_rt >= 0 & tage_op_rt <= 365]

if (nrow(dat_rt) > 0) {
  cat(sprintf("N:           %d\n", nrow(dat_rt)))
  cat(sprintf("Median OP->RT: %d Tage\n", as.integer(median(dat_rt$tage_op_rt))))
  cat(sprintf("IQR:          %d - %d Tage\n",
      as.integer(quantile(dat_rt$tage_op_rt, 0.25)),
      as.integer(quantile(dat_rt$tage_op_rt, 0.75))))
  cat(sprintf("Min / Max:    %d / %d Tage\n", min(dat_rt$tage_op_rt), max(dat_rt$tage_op_rt)))
  cat(sprintf("Direkt (<=56 Tage): %d (%.1f%%)\n",
      dat_rt[tage_op_rt <= 56, .N],
      100 * dat_rt[tage_op_rt <= 56, .N] / nrow(dat_rt)))
  cat(sprintf("Nach Chemo (>56 Tage): %d (%.1f%%)\n",
      dat_rt[tage_op_rt > 56, .N],
      100 * dat_rt[tage_op_rt > 56, .N] / nrow(dat_rt)))
} else {
  cat("Keine Faelle mit BET + RT im plausiblen Zeitfenster.\n")
}

# ============================================================
# GRAFIKEN
# ============================================================

# Grafik 1: BET vs. Mastektomie
op_plot <- dat[op_typ %in% c("BET","Mastektomie"), .N, by = op_typ]
op_plot[, pct := round(100 * N / sum(N), 1)]

p1 <- ggplot(op_plot, aes(x = op_typ, y = N, fill = op_typ)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = paste0(N, "\n(", pct, "%)")),
            vjust = -0.3, size = 4, color = hh_dunkelblau) +
  scale_fill_manual(values = c("BET" = hh_blau, "Mastektomie" = hh_rot)) +
  labs(title = "OP-Typ bei C50", subtitle = "BET vs. Mastektomie",
       x = NULL, y = "Anzahl Patientinnen") +
  theme_minimal(base_size = 13) +
  theme(legend.position = "none",
        plot.title    = element_text(color = hh_dunkelblau, face = "bold"),
        plot.subtitle = element_text(color = hh_dunkelgrau))
ggsave("C50_OP_Typ.png", p1, width = 6, height = 5, dpi = 300)
ggsave("C50_OP_Typ.pdf", p1, width = 6, height = 5)

# Grafik 2: RT-Rate nach BET nach Altersgruppe
p2 <- ggplot(rt_ag[!is.na(ag_gr)], aes(x = ag_gr, y = rt_rate)) +
  geom_col(fill = hh_blau, width = 0.6) +
  geom_text(aes(label = paste0(rt_rate, "%")),
            vjust = -0.3, size = 3.5, color = hh_dunkelblau) +
  geom_hline(yintercept = 72, linetype = "dashed", color = hh_rot, linewidth = 0.8) +
  annotate("text", x = 0.7, y = 74, label = "Ziel: 72%",
           color = hh_rot, hjust = 0, size = 3.5) +
  scale_y_continuous(limits = c(0, 105), labels = function(x) paste0(x, "%")) +
  labs(title = "RT-Rate nach BET nach Altersgruppe",
       x = "Altersgruppe", y = "RT-Rate (%)") +
  theme_minimal(base_size = 13) +
  theme(plot.title = element_text(color = hh_dunkelblau, face = "bold"))
ggsave("C50_RT_Rate_Altersgruppe.png", p2, width = 7, height = 5, dpi = 300)
ggsave("C50_RT_Rate_Altersgruppe.pdf", p2, width = 7, height = 5)

# Grafik 3: Histogramm Abstand OP -> RT
if (nrow(dat_rt) > 0) {
  p3 <- ggplot(dat_rt, aes(x = tage_op_rt)) +
    geom_histogram(binwidth = 7, fill = hh_blau, color = "white") +
    geom_vline(xintercept = 56, linetype = "dashed", color = hh_rot, linewidth = 0.8) +
    annotate("text", x = 58, y = Inf, vjust = 1.5,
             label = "56 Tage\n(8 Wochen)", color = hh_rot, hjust = 0, size = 3.5) +
    labs(title = "Abstand OP -> Beginn Bestrahlung",
         subtitle = "BET-Patientinnen mit RT",
         x = "Tage OP bis RT-Beginn", y = "Anzahl") +
    theme_minimal(base_size = 13) +
    theme(plot.title    = element_text(color = hh_dunkelblau, face = "bold"),
          plot.subtitle = element_text(color = hh_dunkelgrau))
  ggsave("C50_Abstand_OP_RT.png", p3, width = 7, height = 5, dpi = 300)
  ggsave("C50_Abstand_OP_RT.pdf", p3, width = 7, height = 5)
}

# ============================================================
# KARTE: RT-Rate nach BET – Hamburg hervorgehoben
# ============================================================
# Hamburg hat aktuell keinen Wohnort-AGS pro Patient im DB-Schema.
# Die Karte zeigt daher die Gesamtrate fuer die Region Hamburg.

gpkg_pfad <- list.files(
  "/home/rstudio/referenz/shapefiles",
  pattern = "\\.gpkg$",
  full.names = TRUE
)[1]

if (length(gpkg_pfad) > 0 && file.exists(gpkg_pfad)) {
  kreise <- st_read(gpkg_pfad, layer = "vg250_krs", quiet = TRUE) |>
    st_transform(25832)

  # Hamburg: AGS beginnt mit "02"
  hh    <- kreise[startsWith(kreise$AGS, "02"), ]
  andere <- kreise[!startsWith(kreise$AGS, "02"), ]

  # RT-Rate als Fuellfarbe und Label
  # Gruen = Ziel erreicht (>=72%), Rot = unter Ziel
  hh_farbe <- if (rt_rate >= 72) "#2e7d32" else hh_rot

  hh_center <- st_coordinates(st_centroid(st_union(hh)))

  rt_label <- sprintf("RT-Rate nach BET\n%.1f%%\n(Ziel: ≥72%%)", rt_rate)

  p_karte <- ggplot() +
    geom_sf(data = andere, fill = "#DDE4ED", color = "white", linewidth = 0.15) +
    geom_sf(data = hh,     fill = hh_farbe,  color = "white", linewidth = 0.4,
            alpha = 0.85) +
    annotate("label",
             x = hh_center[1],
             y = hh_center[2] - 90000,
             label    = rt_label,
             size     = 3.8,
             fontface = "bold",
             fill     = "white",
             color    = hh_farbe,
             label.size = 0.7,
             label.padding = unit(0.4, "lines")) +
    labs(
      title    = "C50 Mammakarzinom: RT-Rate nach BET",
      subtitle = sprintf(
        "Hamburgisches Krebsregister  |  N = %d BET-Patientinnen, davon %d mit RT",
        n_bet, n_bet_rt),
      caption  = "Datenquelle: KIKA-Datenbank  |  Shapefile: BKG VG250"
    ) +
    theme_void(base_size = 12) +
    theme(
      plot.title    = element_text(color = hh_dunkelblau, face = "bold",
                                   hjust = 0.5, size = 14),
      plot.subtitle = element_text(color = hh_dunkelgrau, hjust = 0.5, size = 9),
      plot.caption  = element_text(color = "#A0A0A0", size = 7, hjust = 1),
      plot.margin   = margin(12, 12, 12, 12)
    )

  ggsave("C50_Karte_HH_RT_Rate.png", p_karte, width = 7, height = 9, dpi = 300)
  ggsave("C50_Karte_HH_RT_Rate.pdf", p_karte, width = 7, height = 9)
  cat("Karte gespeichert: C50_Karte_HH_RT_Rate.png\n")
} else {
  cat("Shapefile nicht gefunden – Karte uebersprungen.\n")
}

# ============================================================
# EXCEL-EXPORT
# ============================================================
wb <- createWorkbook()

addWorksheet(wb, "Charakteristika")
writeData(wb, "Charakteristika", data.frame(
  Merkmal = c("Patientinnen gesamt", "Alter Median (IQR)", "Diagnosejahre"),
  Wert = c(
    n_ges,
    sprintf("%d (%d-%d)",
      median(dat$diagnosealter, na.rm = TRUE),
      quantile(dat$diagnosealter, 0.25, na.rm = TRUE),
      quantile(dat$diagnosealter, 0.75, na.rm = TRUE)),
    sprintf("%d-%d",
      min(dat$diagnosejahr, na.rm = TRUE),
      max(dat$diagnosejahr, na.rm = TRUE))
  )
))
writeData(wb, "Charakteristika", ag_tab, startRow = 6)

addWorksheet(wb, "OP_Typ")
writeData(wb, "OP_Typ", op_tab)

addWorksheet(wb, "RT_nach_BET")
writeData(wb, "RT_nach_BET", rt_ag)

if (nrow(dat_rt) > 0) {
  addWorksheet(wb, "Abstand_OP_RT")
  writeData(wb, "Abstand_OP_RT", data.frame(
    Kennzahl = c("N (BET mit RT)", "Median Tage", "Q25", "Q75", "Min", "Max",
                 "Direkt <=56 Tage N", "Direkt <=56 Tage %",
                 "Nach Chemo >56 Tage N", "Nach Chemo >56 Tage %"),
    Wert = c(
      nrow(dat_rt),
      as.integer(median(dat_rt$tage_op_rt)),
      as.integer(quantile(dat_rt$tage_op_rt, 0.25)),
      as.integer(quantile(dat_rt$tage_op_rt, 0.75)),
      min(dat_rt$tage_op_rt), max(dat_rt$tage_op_rt),
      dat_rt[tage_op_rt <= 56, .N],
      round(100 * dat_rt[tage_op_rt <= 56, .N] / nrow(dat_rt), 1),
      dat_rt[tage_op_rt >  56, .N],
      round(100 * dat_rt[tage_op_rt >  56, .N] / nrow(dat_rt), 1)
    )
  ))
}

saveWorkbook(wb, "C50_BET_RT_Analyse.xlsx", overwrite = TRUE)
cat("Excel gespeichert: C50_BET_RT_Analyse.xlsx\n")
cat("\nFertig.\n")
