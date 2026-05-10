# ============================================================
# KIKA Pilotprojekt — Hirnmetastasen beim Mammakarzinom
# ============================================================
# Stipendienprojekt der Hamburger Krebsgesellschaft
# Tandem: Laakmann (UKE) / Schultz / Peters (HKR) / Rosenberg
# Laufzeit: 03/2025 – 02/2026
#
# Dieses Skript ist die Pilotvorlage, die an die anderen 14 Land-
# eskrebsregister verteilt wird. Jedes Register fuehrt es lokal aus,
# liefert das Aggregat-Ergebnis (data/agg_*.rds) zurueck.
#
# oBDS-Codes:
#   ICD C50    = Mammakarzinom
#   ICD C34    = Bronchialkarzinom (Vergleichskohorte)
#   ICD C43    = Melanom           (Vergleichskohorte)
#   distant_metastasis.location:
#     BRA = Brain   HEP = Hepar    PUL = Pulmo
#     OSS = Ossär   LYM = Lymphkn. PER = Peritoneum
#     PLE = Pleura  SKI = Skin     OTH = Other
#
# Output: outputs/  (PNGs + XLSX + agg_*.rds zur Weitergabe)
# ============================================================

rm(list = ls()); graphics.off()

library(DBI); library(RPostgres); library(jsonlite)
library(data.table); library(ggplot2); library(openxlsx)

# Hamburg-CD-Farben
hh_blau       <- "#005CA9"
hh_dunkelblau <- "#003063"
hh_rot        <- "#E10019"
hh_grau       <- "#757575"
farben_subtyp <- c(C50 = hh_blau, C34 = hh_rot, C43 = "#16A34A")

# Output-Verzeichnis (relativ zum Skript)
OUT <- file.path(getwd(), "outputs")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
cat("Outputs nach:", OUT, "\n\n")

# ============================================================
# 1. DATEN LADEN
# ============================================================
con <- dbConnect(
  RPostgres::Postgres(),
  host="central-db", port=5432, dbname="krebs",
  user="postgres", password="1234"
)

# Alle Tumormeldungen + Patientendaten + Histologie + Erstdiagnose-TNM
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
    th.grading,
    p_tnm.t            AS p_t,
    p_tnm.n            AS p_n,
    p_tnm.m            AS p_m,
    p_tnm.uicc_stage   AS uicc_stage
  FROM patient_report pr
  JOIN tumor_report   tr    ON tr.patient_report_id = pr.id
  LEFT JOIN tumor_histology th  ON th.tumor_report_id = tr.id
  LEFT JOIN tnm           p_tnm ON p_tnm.id = tr.p_tnm_id
  WHERE tr.icd->>'code' SIMILAR TO 'C(50|34|43)%'
"))
basis[, icd3 := substr(icd_code, 1, 3)]
basis[, diagnosis_date    := as.Date(diagnosis_date)]
basis[, date_of_birth     := as.Date(date_of_birth)]
basis[, vital_status_date := as.Date(vital_status_date)]
basis[, diagnosis_year    := as.integer(format(diagnosis_date, "%Y"))]
basis[, diagnose_alter    := as.integer(floor(
  as.numeric(diagnosis_date - date_of_birth) / 365.25))]
cat("Tumormeldungen geladen:", nrow(basis),
    " (C50:", basis[icd3=="C50",.N],
    ", C34:", basis[icd3=="C34",.N],
    ", C43:", basis[icd3=="C43",.N], ")\n")

# Verlaufskontrollen mit Metastasen-Lokalisationen
metas <- as.data.table(dbGetQuery(con, "
  SELECT
    tf.tumor_report_id   AS tr_id,
    tf.date              AS verlauf_date,
    loc.value->>'location' AS met_lok
  FROM tumor_follow_up tf,
  LATERAL jsonb_array_elements(tf.distant_metastasis) AS loc(value)
"))
metas[, verlauf_date := as.Date(verlauf_date)]
cat("Metastasen-Eintraege gesamt:", nrow(metas), "\n\n")

dbDisconnect(con)

# ============================================================
# 2. HIRNMETASTASEN PRO TUMOR — frueheste BRA-Erfassung
# ============================================================
hirn <- metas[met_lok == "BRA", .(
  hirn_date = min(verlauf_date, na.rm = TRUE)
), by = tr_id]
cat("Tumoren mit Hirnmetastasen (BRA):", nrow(hirn), "\n")

# Auch andere distante Metastasen (extracerebral)
extra <- metas[met_lok != "BRA", .(
  extra_date = min(verlauf_date, na.rm = TRUE)
), by = tr_id]

dat <- merge(basis, hirn,  by = "tr_id", all.x = TRUE)
dat <- merge(dat,   extra, by = "tr_id", all.x = TRUE)
dat[, hat_brm   := !is.na(hirn_date)]
dat[, hat_extra := !is.na(extra_date)]
dat[, alter_bei_brm := as.integer(floor(
  as.numeric(hirn_date - date_of_birth) / 365.25))]
dat[, monate_diag_brm := as.integer(round(
  as.numeric(hirn_date - diagnosis_date) / 30.44))]

# Pro Patient nur erste C50-/C34-/C43-Diagnose
setorder(dat, patient_id, diagnosis_date)
dat <- dat[, .SD[1], by = .(patient_id, icd3)]

# ============================================================
# 3. KENNZAHLEN
# ============================================================
n_total       <- dat[, .N, by = icd3]
n_brm         <- dat[hat_brm == TRUE, .N, by = icd3]
n_brm_only    <- dat[hat_brm == TRUE & hat_extra == FALSE, .N, by = icd3]

kennzahlen <- merge(n_total, n_brm, by = "icd3", suffixes = c("_total","_brm"), all = TRUE)
kennzahlen <- merge(kennzahlen, n_brm_only[, .(icd3, N_brm_only = N)], by = "icd3", all.x = TRUE)
kennzahlen[is.na(N_brm), N_brm := 0L]
kennzahlen[is.na(N_brm_only), N_brm_only := 0L]
kennzahlen[, brm_anteil_pct := round(100 * N_brm / N_total, 2)]

cat("\n============================================================\n")
cat("KENNZAHLEN — Patientinnen mit Hirnmetastasen\n")
cat("============================================================\n")
print(kennzahlen)

# ============================================================
# 4. ALTERS-/ZEIT-VERTEILUNG (nur C50)
# ============================================================
c50_brm <- dat[icd3 == "C50" & hat_brm == TRUE]
cat("\n--- C50-Hirnmetastasen-Kohorte ---\n")
cat("N =", nrow(c50_brm), "\n")
if (nrow(c50_brm) > 0) {
  cat(sprintf("Alter bei Erstdiagnose Mammakarzinom: Median %.0f J. (IQR %.0f-%.0f)\n",
      median(c50_brm$diagnose_alter, na.rm = TRUE),
      quantile(c50_brm$diagnose_alter, 0.25, na.rm = TRUE),
      quantile(c50_brm$diagnose_alter, 0.75, na.rm = TRUE)))
  cat(sprintf("Alter bei Hirnmetastase:              Median %.0f J. (IQR %.0f-%.0f)\n",
      median(c50_brm$alter_bei_brm, na.rm = TRUE),
      quantile(c50_brm$alter_bei_brm, 0.25, na.rm = TRUE),
      quantile(c50_brm$alter_bei_brm, 0.75, na.rm = TRUE)))
  cat(sprintf("Zeit Diagnose -> Hirnmetastase:       Median %.0f Monate (IQR %.0f-%.0f)\n",
      median(c50_brm$monate_diag_brm, na.rm = TRUE),
      quantile(c50_brm$monate_diag_brm, 0.25, na.rm = TRUE),
      quantile(c50_brm$monate_diag_brm, 0.75, na.rm = TRUE)))
}

# Diagnosejahre
dj_tab <- c50_brm[, .N, by = diagnosis_year][order(diagnosis_year)]
cat("\nC50-Hirnmet nach Diagnosejahr:\n")
print(dj_tab)

# TNM bei Erstdiagnose
tnm_tab <- c50_brm[, .N, by = .(p_t, p_n, p_m)][order(-N)]
cat("\nTNM-Verteilung (Top 10):\n")
print(head(tnm_tab, 10))

# ============================================================
# 5. GRAFIKEN
# ============================================================
# G1: Hirnmetastasen-Anteil je ICD
p1 <- ggplot(kennzahlen, aes(x = icd3, y = brm_anteil_pct, fill = icd3)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = sprintf("%.1f%%\nN=%d/%d", brm_anteil_pct, N_brm, N_total)),
            vjust = -0.3, size = 4, color = hh_dunkelblau) +
  scale_fill_manual(values = farben_subtyp) +
  labs(title    = "Anteil Patient:innen mit Hirnmetastasen",
       subtitle = "C50 Mammakarzinom · C34 Bronchial · C43 Melanom",
       x = NULL, y = "Anteil mit Hirnmet. (%)") +
  expand_limits(y = max(kennzahlen$brm_anteil_pct, na.rm = TRUE) * 1.4) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "none",
        plot.title    = element_text(color = hh_dunkelblau, face = "bold"),
        plot.subtitle = element_text(color = hh_grau))
ggsave(file.path(OUT, "01_anteil_hirnmet.png"), p1, width = 7, height = 5, dpi = 300)

# G2: Altersverteilung bei Hirnmet (C50)
if (nrow(c50_brm) > 0) {
  p2 <- ggplot(c50_brm, aes(x = alter_bei_brm)) +
    geom_histogram(binwidth = 5, fill = hh_blau, color = "white") +
    labs(title = "Alter bei Diagnose der Hirnmetastasen — C50",
         x = "Alter (Jahre)", y = "Anzahl Patientinnen") +
    theme_minimal(base_size = 13) +
    theme(plot.title = element_text(color = hh_dunkelblau, face = "bold"))
  ggsave(file.path(OUT, "02_alter_bei_hirnmet_C50.png"), p2, width = 7, height = 5, dpi = 300)
}

# G3: Zeit Erstdiagnose -> Hirnmet (C50)
zeit <- c50_brm[!is.na(monate_diag_brm) & monate_diag_brm >= 0]
if (nrow(zeit) > 0) {
  p3 <- ggplot(zeit, aes(x = monate_diag_brm)) +
    geom_histogram(binwidth = 6, fill = hh_blau, color = "white") +
    labs(title    = "Zeit Erstdiagnose Mammakarzinom -> Hirnmetastase",
         subtitle = "in Monaten seit Erstdiagnose",
         x = "Monate", y = "Anzahl Patientinnen") +
    theme_minimal(base_size = 13) +
    theme(plot.title    = element_text(color = hh_dunkelblau, face = "bold"),
          plot.subtitle = element_text(color = hh_grau))
  ggsave(file.path(OUT, "03_zeit_diagnose_bis_hirnmet.png"), p3, width = 7, height = 5, dpi = 300)
}

# G4: Vergleich Hirnmet-Anteil ueber die drei Entitaeten
brm_vergleich <- merge(
  metas[met_lok == "BRA"][, .(brain = .N), by = tr_id],
  basis[, .(tr_id, icd3, diagnosis_year)],
  by = "tr_id"
)
brm_pro_jahr <- brm_vergleich[, .(brm = .N), by = .(icd3, diagnosis_year)]
basis_pro_jahr <- basis[, .(total = .N), by = .(icd3, diagnosis_year)]
inzidenz <- merge(basis_pro_jahr, brm_pro_jahr, by = c("icd3","diagnosis_year"), all.x = TRUE)
inzidenz[is.na(brm), brm := 0L]
inzidenz[, anteil := round(100 * brm / total, 2)]

if (nrow(inzidenz) > 0) {
  p4 <- ggplot(inzidenz, aes(x = diagnosis_year, y = anteil, color = icd3, group = icd3)) +
    geom_line(linewidth = 1) + geom_point(size = 2) +
    scale_color_manual(values = farben_subtyp) +
    labs(title = "Hirnmetastasen-Anteil im zeitlichen Verlauf",
         x = "Diagnosejahr", y = "Anteil mit Hirnmet. (%)",
         color = "ICD") +
    theme_minimal(base_size = 13) +
    theme(plot.title = element_text(color = hh_dunkelblau, face = "bold"))
  ggsave(file.path(OUT, "04_zeitverlauf_anteil.png"), p4, width = 8, height = 5, dpi = 300)
}

# ============================================================
# 6. AGGREGAT-EXPORT (an andere Register weitergebbar)
# ============================================================
# Diese RDS-Datei enthaelt KEINE Patientendaten, nur aggregierte
# Kennzahlen — geeignet zum Versand an Koordinationsstelle.
agg <- list(
  register     = "Hamburg",
  stand        = Sys.Date(),
  kennzahlen   = kennzahlen,
  c50_alter_diag    = if (nrow(c50_brm)>0) summary(c50_brm$diagnose_alter)  else NULL,
  c50_alter_brm     = if (nrow(c50_brm)>0) summary(c50_brm$alter_bei_brm)   else NULL,
  c50_zeit_monate   = if (nrow(c50_brm)>0) summary(c50_brm$monate_diag_brm) else NULL,
  c50_diagnosejahre = dj_tab,
  c50_tnm           = head(tnm_tab, 20),
  inzidenz_zeitlich = inzidenz
)
saveRDS(agg, file.path(OUT, "agg_hirnmet_hamburg.rds"))

# Excel mit allen Tabellen
wb <- createWorkbook()
addWorksheet(wb, "Kennzahlen");           writeData(wb, "Kennzahlen",           kennzahlen)
addWorksheet(wb, "C50_Diagnosejahre");    writeData(wb, "C50_Diagnosejahre",    dj_tab)
addWorksheet(wb, "C50_TNM_Verteilung");   writeData(wb, "C50_TNM_Verteilung",   tnm_tab)
addWorksheet(wb, "Anteil_im_Zeitverlauf");writeData(wb, "Anteil_im_Zeitverlauf",inzidenz)
saveWorkbook(wb, file.path(OUT, "Hirnmetastasen_Hamburg.xlsx"), overwrite = TRUE)

cat("\n============================================================\n")
cat("Fertig. Outputs in:", OUT, "\n")
cat("Zur Weitergabe: agg_hirnmet_hamburg.rds (aggregat, keine Patientendaten)\n")
cat("============================================================\n")
