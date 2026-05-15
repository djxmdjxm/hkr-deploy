# =============================================================================
# KIKA – C50 Mammakarzinom: Hirnmetastasen-Analyse
# Datenquelle: KIKA-Datenbank (PostgreSQL)
#
# Analysen:
#   1. Subtyp-Verteilung (Balkendiagramm)
#   2. Deskriptive Tabelle: N, Events, Median OS / CIF je Subtyp
#   3. Kaplan-Meier Gesamtüberleben nach Subtyp
#   4. CIF (Competing Risks) für Hirnmetastasen nach Subtyp
#
# Konventionen:
#   - data.table-Syntax, "=" statt "<-"
#   - Überlebensanalysen auf 60 Monate begrenzt (5-Jahres-Konvention HKR)
#   - Hamburg Corporate Design Farben
#   - Ausgabe: PNG, 300 dpi
#   - DSGVO: Keine absoluten N < 5 in Ausgabedateien
# =============================================================================

rm(list = ls())
graphics.off()

# ============================================================
# 0. PAKETE
# ============================================================
pkgs = c("DBI", "RPostgres", "data.table", "jsonlite",
         "survival", "cmprsk", "ggplot2", "scales", "ggtext")
for (p in pkgs) {
  if (!require(p, character.only = TRUE, quietly = TRUE))
    install.packages(p, repos = "https://cloud.r-project.org", quiet = TRUE)
  library(p, character.only = TRUE, quietly = TRUE)
}

# ============================================================
# ARBEITSVERZEICHNIS
# ============================================================
# setwd("Z:/#OFFEN/28-Auswertungen/2026/2026-03_C50 BRA-MET_Laakmann UKE")

# ============================================================
# HAMBURG CORPORATE DESIGN
# ============================================================
hh_blau       = "#005CA9"
hh_rot        = "#E10019"
hh_dunkelblau = "#003063"
hh_grau       = "#E3E3E3"
hh_dunkelgrau = "#757575"

# Subtyp-Farben (konsistent mit Paper-2-Skripten)
subtyp_farben = c(
  "HR+/HER2-"  = hh_blau,
  "HER2+/HR+"  = "#4CAF50",
  "HER2+/HR-"  = hh_rot,
  "TNBC"       = "#FF9800",
  "Unbekannt"  = hh_dunkelgrau
)
subtyp_levels = c("HR+/HER2-", "HER2+/HR+", "HER2+/HR-", "TNBC", "Unbekannt")

# ============================================================
# DATENSCHALTER
# ============================================================
# Option A: Synthetische Testdaten aus XML-Generator v3
#   → XML parsen und als RDS zwischenspeichern (separater Schritt)
#   → Dann hier als RDS laden:
# dat = readRDS("Daten/C50_BrainMet_synthetisch.rds")

# Option B: KIKA-Datenbank (Standard für Produktion) — aktiv
con = dbConnect(
  RPostgres::Postgres(),
  host     = "central-db",
  port     = 5432,
  dbname   = "krebs",
  user     = "postgres",
  password = "1234"
)
cat("Datenbankverbindung hergestellt.\n")

# ============================================================
# 1. DATEN LADEN
# ============================================================

# --- Basis: C50, Patientendaten, Histologie, Mamma-Modul ---
basis = as.data.table(dbGetQuery(con, "
  SELECT
    pr.patient_id,
    pr.date_of_birth,
    pr.is_deceased,
    pr.vital_status_date,
    tr.id                                        AS tr_id,
    tr.diagnosis_date,
    tr.icd->>'code'                              AS icd_code,
    th.grading,
    tb.estrogen_receptor_status                  AS er_status,
    tb.progesterone_receptor_status              AS pr_status,
    tb.her2neu_status                            AS her2_status,
    tb.menopause_status_at_diagnosis             AS menopause
  FROM patient_report   pr
  JOIN tumor_report     tr ON tr.patient_report_id = pr.id
  LEFT JOIN tumor_histology     th ON th.tumor_report_id = tr.id
  LEFT JOIN tumor_report_breast tb ON tb.tumor_report_id = tr.id
  WHERE tr.icd->>'code' LIKE 'C50%'
"))
cat("C50-Basisfälle geladen:", nrow(basis), "\n")

# --- Folgeereignisse: Hirnmetastasen ---
# Fernmetastasen in tumor_follow_up; Lokalisation als JSONB-Array
# Schema: tumor_follow_up → distant_metastasis (jsonb: [{location: "BRA",...}])
fe_raw = data.table()
if (nrow(basis) > 0) {
  tr_ids_sql = paste(unique(basis$tr_id), collapse = ",")

  fe_raw = as.data.table(dbGetQuery(con, sprintf("
    SELECT
      tfu.tumor_report_id          AS tr_id,
      tfu.date                     AS fe_datum,
      tfu.distant_metastasis       AS fm_json
    FROM tumor_follow_up tfu
    WHERE tfu.tumor_report_id IN (%s)
      AND tfu.date IS NOT NULL
    ORDER BY tfu.tumor_report_id, tfu.date
  ", tr_ids_sql)))
  cat("Folgeereignisse geladen:", nrow(fe_raw), "\n")

  # FM-Lokalisation bei Diagnose (tumor_report.distant_metastasis)
  fm_diag_raw = as.data.table(dbGetQuery(con, sprintf("
    SELECT
      tr.id                AS tr_id,
      tr.diagnosis_date    AS fm_datum,
      tr.distant_metastasis AS fm_json
    FROM tumor_report tr
    WHERE tr.id IN (%s)
      AND tr.distant_metastasis IS NOT NULL
  ", tr_ids_sql)))
  cat("FM bei Diagnose geladen:", nrow(fm_diag_raw), "\n")
}

dbDisconnect(con)
cat("Datenbankverbindung geschlossen.\n\n")

# ============================================================
# 2. DATENVORBEREITUNG
# ============================================================

# Typkonversionen
basis[, diagnosis_date   := as.Date(diagnosis_date)]
basis[, date_of_birth    := as.Date(date_of_birth)]
basis[, vital_status_date := as.Date(vital_status_date)]
basis[, diagnosejahr     := as.integer(format(diagnosis_date, "%Y"))]
basis[, alter_dx         := as.integer(floor(
  as.numeric(diagnosis_date - date_of_birth) / 365.25))]

# Erste C50-Diagnose pro Patientin
setorder(basis, patient_id, diagnosis_date)
basis = basis[, .SD[1], by = patient_id]
cat("Erste C50-Diagnose pro Patientin:", nrow(basis), "\n")

# --- Molekularer Subtyp ---
# oBDS-Codes: P = positiv, N = negativ, U = unbekannt
basis[, er   := fcase(er_status  == "P", "P", er_status  == "N", "N", default = "U")]
basis[, pr   := fcase(pr_status  == "P", "P", pr_status  == "N", "N", default = "U")]
basis[, her2 := fcase(her2_status == "P", "P", her2_status == "N", "N", default = "U")]

basis[, subtyp := fcase(
  her2 == "P" & er == "N" & pr == "N",               "HER2+/HR-",
  her2 == "P" & (er == "P" | pr == "P"),              "HER2+/HR+",
  her2 == "N" & er == "N" & pr == "N",               "TNBC",
  her2 == "N" & (er == "P" | pr == "P"),              "HR+/HER2-",
  default = "Unbekannt"
)]
basis[, subtyp := factor(subtyp, levels = subtyp_levels)]

# --- Hirnmetastasen aus Folgeereignissen parsen ---
hat_bra_in_json = function(json_str) {
  # Erkennt BRA-Lokalisation in JSONB-Feldern der KIKA-DB.
  # Unterstützte Formate (je nach Pipeline-Version):
  #   Array of objects: '[{"location":"BRA"}, ...]' oder '[{"Lokalisation":"BRA"}, ...]'
  #   Array of strings: '["BRA","OSS"]'
  #   Skalarer String:  '"BRA"'
  # Einmalig zur Diagnose ausführen: cat(fe_raw$fm_json[1])
  if (is.na(json_str) || json_str == "" || json_str == "null") return(FALSE)
  tryCatch({
    parsed = fromJSON(json_str, simplifyVector = TRUE)
    if (is.data.frame(parsed)) {
      lok_col = intersect(c("location", "Lokalisation", "lokalisation"), names(parsed))
      if (length(lok_col) > 0)
        return(any(toupper(parsed[[lok_col[1]]]) == "BRA", na.rm = TRUE))
    } else if (is.character(parsed)) {
      return(any(toupper(parsed) == "BRA", na.rm = TRUE))
    } else if (is.list(parsed)) {
      loks = sapply(parsed, function(x) {
        lok_col = intersect(c("location", "Lokalisation", "lokalisation"), names(x))
        if (length(lok_col) > 0) return(as.character(x[[lok_col[1]]]))
        NA_character_
      })
      return(any(toupper(loks) == "BRA", na.rm = TRUE))
    }
    FALSE
  }, error = function(e) FALSE)
}

# BM im Verlauf: erstes FE mit BRA-Lokalisation je Tumor
bm_fe = data.table()
if (nrow(fe_raw) > 0) {
  fe_raw[, fe_datum := as.Date(fe_datum)]
  fe_raw[, hat_bra  := sapply(fm_json, hat_bra_in_json)]
  bm_fe = fe_raw[hat_bra == TRUE][order(tr_id, fe_datum)][, .SD[1], by = tr_id]
  bm_fe = bm_fe[, .(tr_id, datum_bm_fe = fe_datum)]
  cat("Tumoren mit BM im Verlauf:", nrow(bm_fe), "\n")
}

# BM bei Diagnose
bm_diag = data.table()
if (nrow(fm_diag_raw) > 0) {
  fm_diag_raw[, hat_bra_diag := sapply(fm_json, hat_bra_in_json)]
  bm_diag = fm_diag_raw[hat_bra_diag == TRUE, .(tr_id, datum_bm_diag = as.Date(fm_datum))]
  cat("Tumoren mit BM bei Diagnose:", nrow(bm_diag), "\n")
}

# --- Analysedatensatz zusammenführen ---
dat = copy(basis)
dat = merge(dat, bm_fe,   by = "tr_id", all.x = TRUE)
dat = merge(dat, bm_diag, by = "tr_id", all.x = TRUE)

# Erstes BM-Ereignis (Diagnose oder Verlauf)
dat[, datum_bm := pmin(datum_bm_diag, datum_bm_fe, na.rm = TRUE)]
dat[, hat_bm   := as.integer(!is.na(datum_bm))]

# ============================================================
# 3. ZEITVARIABLEN
# ============================================================
# Gesamtüberleben: Diagnose bis Tod / Zensierung (max. 60 Monate = 1827 Tage)
dat[, status_os := as.integer(is_deceased == TRUE)]
dat[, fu_os     := as.numeric(vital_status_date - diagnosis_date)]

# Plausibilitätsprüfung: FU >= 0, nicht fehlend
dat[is.na(fu_os) | fu_os < 0, `:=`(fu_os = 0, status_os = 0L)]

# 60-Monats-Zensierung (HKR-Konvention)
MAX_FU = 1827  # 60 Monate in Tagen
dat[fu_os > MAX_FU, `:=`(status_os = 0L, fu_os = MAX_FU)]

# OS in Monaten (für Grafik)
dat[, fu_os_mo := fu_os / 30.4375]

# CIF: Zeit bis Hirnmetastase ab extrakranieller Metastase
# Competing events: 1 = Hirnmetastase, 2 = Tod ohne Hirnmetastase, 0 = zensiert
dat[, tage_bis_bm := as.numeric(datum_bm - diagnosis_date)]
dat[, event_cif := fcase(
  hat_bm == 1L & !is.na(tage_bis_bm) & tage_bis_bm > 0,  1L,   # BM-Ereignis
  status_os == 1L & hat_bm == 0L,                          2L,   # Tod ohne BM
  default = 0L                                                    # zensiert
)]
dat[, t_cif := fcase(
  event_cif == 1L, tage_bis_bm,
  event_cif == 2L, fu_os,
  default = fu_os
)]
dat[, t_cif_mo := t_cif / 30.4375]

# CIF ebenfalls auf 60 Monate begrenzen
dat[t_cif > MAX_FU, `:=`(event_cif = 0L, t_cif = MAX_FU, t_cif_mo = MAX_FU / 30.4375)]

cat(sprintf("\nAnalysekohorte: N = %d\n", nrow(dat)))
cat(sprintf("Hirnmetastasen gesamt: %d (%.1f%%)\n",
            sum(dat$hat_bm), 100 * mean(dat$hat_bm)))
cat(sprintf("Verstorben: %d (%.1f%%)\n",
            sum(dat$status_os), 100 * mean(dat$status_os)))

# ============================================================
# HILFSFUNKTIONEN FÜR GRAFIKEN
# ============================================================

# Publication-ready ggplot-Theme (HKR-Stil)
theme_hkr = function(base_size = 13) {
  theme_classic(base_size = base_size) %+replace%
    theme(
      plot.title    = element_text(color = hh_dunkelblau, face = "bold",
                                   size = base_size + 1, hjust = 0),
      plot.subtitle = element_text(color = hh_dunkelgrau, size = base_size - 1,
                                   hjust = 0, margin = margin(b = 8)),
      plot.caption  = element_text(color = "#A0A0A0", size = 8, hjust = 1),
      axis.title    = element_text(color = hh_dunkelblau, size = base_size - 1),
      axis.text     = element_text(color = "#333333"),
      legend.title  = element_text(color = hh_dunkelblau, face = "bold",
                                   size = base_size - 1),
      legend.text   = element_text(size = base_size - 2),
      legend.position = "right",
      panel.grid.major.y = element_line(color = hh_grau, linewidth = 0.4),
      panel.grid.major.x = element_blank(),
      strip.background   = element_rect(fill = hh_grau, color = NA),
      strip.text         = element_text(color = hh_dunkelblau, face = "bold"),
      plot.margin = margin(12, 16, 10, 12)
    )
}

save_png = function(plot, dateiname, breite = 10, hoehe = 7) {
  ggsave(dateiname, plot, width = breite, height = hoehe, dpi = 300, bg = "white")
  cat("Gespeichert:", dateiname, "\n")
}

# ============================================================
# GRAFIK 1: SUBTYP-VERTEILUNG
# ============================================================
cat("\n--- Grafik 1: Subtyp-Verteilung ---\n")

subtyp_tab = dat[, .N, by = subtyp][order(subtyp)]
subtyp_tab[, pct     := round(100 * N / sum(N), 1)]
subtyp_tab[, label   := paste0(format(N, big.mark = "."), "\n(", pct, "%)")]
subtyp_tab[, subtyp  := factor(subtyp, levels = subtyp_levels)]

p_subtyp = ggplot(subtyp_tab, aes(x = subtyp, y = N, fill = subtyp)) +
  geom_col(width = 0.65, color = "white", linewidth = 0.3) +
  geom_text(aes(label = label), vjust = -0.25, size = 3.6,
            color = hh_dunkelblau, lineheight = 1.1) +
  scale_fill_manual(values = subtyp_farben, guide = "none") +
  scale_y_continuous(
    expand = expansion(mult = c(0, 0.15)),
    labels = label_comma(big.mark = ".")
  ) +
  labs(
    title    = "Molekulare Subtypen bei Mammakarzinom (C50)",
    subtitle = paste0("N = ", format(nrow(dat), big.mark = "."),
                      " Patientinnen | KIKA-Datenbank"),
    x        = "Molekularer Subtyp",
    y        = "Anzahl Patientinnen",
    caption  = "Subtyp-Definition: ER/PR/HER2-Status aus tumor_report_breast"
  ) +
  theme_hkr()

save_png(p_subtyp, "C50_BM_Fig1_Subtyp_Verteilung.png", breite = 9, hoehe = 6)

# ============================================================
# GRAFIK 2: KAPLAN-MEIER GESAMTÜBERLEBEN NACH SUBTYP
# ============================================================
cat("\n--- Grafik 2: Kaplan-Meier OS nach Subtyp ---\n")

# Nur Patienten mit bekanntem Subtyp und FU > 0
dat_km = dat[subtyp != "Unbekannt" & fu_os > 0]
dat_km[, subtyp := droplevels(subtyp)]

km_fit = survfit(Surv(fu_os_mo, status_os) ~ subtyp, data = dat_km)
km_sum = summary(km_fit)$table

# KM-Kurven manuell aus survfit extrahieren (für ggplot)
extract_km = function(fit) {
  ld = data.table()
  nms = names(fit$strata)
  idx = 0
  for (g in nms) {
    n_g = fit$strata[g]
    rows = (idx + 1):(idx + n_g)
    ld = rbind(ld, data.table(
      subtyp  = sub("subtyp=", "", g),
      time    = fit$time[rows],
      surv    = fit$surv[rows],
      lower   = fit$lower[rows],
      upper   = fit$upper[rows],
      n.risk  = fit$n.risk[rows],
      n.event = fit$n.event[rows]
    ))
    idx = idx + n_g
  }
  # Startzeile (t=0, surv=1) je Gruppe einfügen
  starts = unique(ld[, .(subtyp)])[, .(subtyp, time=0, surv=1, lower=1, upper=1,
                                       n.risk=NA_integer_, n.event=0L)]
  rbind(starts, ld)[order(subtyp, time)]
}

km_dt = extract_km(km_fit)
km_dt[, subtyp := factor(subtyp, levels = subtyp_levels)]

# At-risk-Tabelle
at_risk_zeiten = c(0, 12, 24, 36, 48, 60)
at_risk_tab = rbindlist(lapply(at_risk_zeiten, function(t) {
  km_dt[time <= t, .SD[.N], by = subtyp][, .(subtyp, zeit = t, n_risk = n.risk)]
}))
# n.risk bei t=0 aus survfit
n0 = dat_km[, .N, by = subtyp][, .(subtyp, n_risk = N)]
at_risk_tab[zeit == 0, n_risk := n0$n_risk[match(subtyp, n0$subtyp)]]
at_risk_tab[, subtyp := factor(subtyp, levels = subtyp_levels)]
at_risk_tab[is.na(n_risk), n_risk := 0L]

p_km = ggplot(km_dt, aes(x = time, y = surv * 100, color = subtyp, fill = subtyp)) +
  geom_step(linewidth = 0.9) +
  geom_ribbon(aes(ymin = lower * 100, ymax = upper * 100),
              alpha = 0.10, color = NA) +
  scale_color_manual(values = subtyp_farben, name = "Molekularer Subtyp") +
  scale_fill_manual( values = subtyp_farben, guide  = "none") +
  scale_x_continuous(
    breaks = at_risk_zeiten,
    limits = c(0, 60),
    expand = expansion(mult = c(0.01, 0.02)),
    name   = "Zeit ab Diagnose (Monate)"
  ) +
  scale_y_continuous(
    limits = c(0, 101),
    breaks = seq(0, 100, 20),
    labels = function(x) paste0(x, "%"),
    name   = "Gesamtüberleben"
  ) +
  labs(
    title    = "Gesamtüberleben nach molekularem Subtyp",
    subtitle = paste0("Kaplan-Meier | N = ",
                      format(nrow(dat_km), big.mark = "."),
                      " Patientinnen | Zensierung bei 60 Monaten"),
    caption  = "Schraffierter Bereich: 95%-Konfidenzintervall\nHKR-Datenbank (KIKA)"
  ) +
  theme_hkr() +
  theme(
    legend.position  = c(0.82, 0.75),
    legend.background = element_rect(fill = "white", color = hh_grau, linewidth = 0.4)
  )

# At-risk-Tabelle als separaten Unterteil hinzufügen (manuell unter Plot)
# (survminer-frei — Textannotation mit geom_text)
p_km_final = p_km +
  annotate("text", x = -2, y = -12,
           label = "At risk:", hjust = 1, size = 3.2,
           color = hh_dunkelblau, fontface = "bold")

# At-risk als facettiertes Panel via separates ggplot, dann patchwork-artig
# Einfachere Lösung: under-plot als zweite Schicht
ar_plot = ggplot(at_risk_tab, aes(x = zeit, y = subtyp, label = n_risk)) +
  geom_text(aes(color = subtyp), size = 3.2, fontface = "bold") +
  scale_color_manual(values = subtyp_farben, guide = "none") +
  scale_x_continuous(limits = c(0, 60), breaks = at_risk_zeiten) +
  scale_y_discrete(limits = rev(subtyp_levels[-5])) +
  labs(x = "Monate", y = NULL) +
  theme_hkr(base_size = 11) +
  theme(
    axis.line  = element_blank(),
    axis.ticks = element_blank(),
    axis.text.x = element_blank(),
    axis.title.x = element_blank(),
    panel.grid  = element_blank(),
    plot.margin = margin(0, 16, 4, 12)
  )

# Kombinieren über grid
library(grid)
library(gridExtra)

km_grob = ggplotGrob(p_km)
ar_grob = ggplotGrob(ar_plot)

# Breiten angleichen
km_grob$widths = ar_grob$widths

km_combined = arrangeGrob(km_grob, ar_grob, nrow = 2, heights = c(3.5, 1))
ggsave("C50_BM_Fig2_KM_OS_Subtyp.png",
       km_combined, width = 10, height = 8, dpi = 300, bg = "white")
cat("Gespeichert: C50_BM_Fig2_KM_OS_Subtyp.png\n")

# ============================================================
# GRAFIK 3: CIF — HIRNMETASTASEN NACH SUBTYP
# ============================================================
cat("\n--- Grafik 3: CIF Hirnmetastasen nach Subtyp ---\n")

dat_cif = dat[subtyp != "Unbekannt" & t_cif > 0]
dat_cif[, subtyp := droplevels(subtyp)]

subtyp_vec = as.integer(dat_cif$subtyp)

cif_fit = cuminc(
  ftime   = dat_cif$t_cif_mo,
  fstatus = dat_cif$event_cif,
  group   = dat_cif$subtyp
)

# CIF-Ergebnisse in data.table überführen (Ereignis 1 = BM)
extract_cif = function(cif_obj) {
  nms = names(cif_obj)
  bm_nms = nms[grepl(" 1$", nms)]   # Ereignis 1 = Hirnmetastase
  rbindlist(lapply(bm_nms, function(nm) {
    data.table(
      subtyp = sub(" 1$", "", nm),
      time   = cif_obj[[nm]]$time,
      est    = cif_obj[[nm]]$est * 100,
      lower  = (cif_obj[[nm]]$est - 1.96 * sqrt(cif_obj[[nm]]$var)) * 100,
      upper  = (cif_obj[[nm]]$est + 1.96 * sqrt(cif_obj[[nm]]$var)) * 100
    )
  }))
}

cif_dt = extract_cif(cif_fit)
cif_dt[lower < 0, lower := 0]
cif_dt[, subtyp := factor(subtyp, levels = subtyp_levels)]

# Startzeilen einfügen (t=0, CIF=0)
cif_starts = unique(cif_dt[, .(subtyp)])[, .(subtyp, time=0, est=0, lower=0, upper=0)]
cif_dt = rbind(cif_starts, cif_dt)[order(subtyp, time)]

p_cif = ggplot(cif_dt, aes(x = time, y = est, color = subtyp, fill = subtyp)) +
  geom_step(linewidth = 0.9) +
  geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.10, color = NA) +
  scale_color_manual(values = subtyp_farben, name = "Molekularer Subtyp") +
  scale_fill_manual( values = subtyp_farben, guide  = "none") +
  scale_x_continuous(
    breaks = seq(0, 60, 12),
    limits = c(0, 60),
    expand = expansion(mult = c(0.01, 0.02)),
    name   = "Zeit ab Diagnose (Monate)"
  ) +
  scale_y_continuous(
    limits = c(0, NA),
    expand = expansion(mult = c(0.01, 0.10)),
    labels = function(x) paste0(x, "%"),
    name   = "Kumulative Inzidenz Hirnmetastasen"
  ) +
  labs(
    title    = "Kumulative Inzidenz von Hirnmetastasen nach Subtyp",
    subtitle = paste0(
      "Fine-Gray Competing Risks (Tod ohne Hirnmetastase = konkurrierendes Ereignis)\n",
      "N = ", format(nrow(dat_cif), big.mark = "."),
      " Patientinnen | Zensierung bei 60 Monaten"
    ),
    caption  = "Schraffierter Bereich: ±1.96 × SE\nHKR-Datenbank (KIKA)"
  ) +
  theme_hkr() +
  theme(
    legend.position   = c(0.18, 0.78),
    legend.background = element_rect(fill = "white", color = hh_grau, linewidth = 0.4)
  )

save_png(p_cif, "C50_BM_Fig3_CIF_BrainMet_Subtyp.png", breite = 10, hoehe = 7)

# ============================================================
# DESKRIPTIVE TABELLE: N, Events, Median OS & 60-Mo-CIF je Subtyp
# ============================================================
cat("\n--- Tabelle: Deskriptive Zusammenfassung ---\n")

# OS-Mediane aus KM
km_tbl = summary(km_fit)$table
km_df  = as.data.table(km_tbl, keep.rownames = "subtyp_raw")
km_df[, subtyp := sub("subtyp=", "", subtyp_raw)]
setnames(km_df, c("records","events","median","0.95LCL","0.95UCL"),
         c("n_os","events_os","median_os_mo","median_os_ll","median_os_ul"),
         skip_absent = TRUE)

# 60-Mo-CIF (letzter Schätzwert je Gruppe)
cif_60 = cif_dt[time <= 60][order(subtyp, -time)][, .SD[1], by = subtyp]
setnames(cif_60, c("est","lower","upper"), c("cif60_pct","cif60_ll","cif60_ul"))

# BM-Ereignisse
bm_n = dat[subtyp != "Unbekannt", .(n_total = .N, n_bm = sum(hat_bm)), by = subtyp]

# Zusammenführen
tab_final = merge(bm_n, km_df[, .(subtyp, events_os, median_os_mo,
                                  median_os_ll, median_os_ul)],
                  by = "subtyp", all.x = TRUE)
tab_final = merge(tab_final, cif_60[, .(subtyp, cif60_pct, cif60_ll, cif60_ul)],
                  by = "subtyp", all.x = TRUE)

tab_final[, subtyp := factor(subtyp, levels = subtyp_levels)]
setorder(tab_final, subtyp)

# Formatierung für Ausgabe
tab_out = tab_final[, .(
  Subtyp            = as.character(subtyp),
  N                 = format(n_total, big.mark = "."),
  `BM-Ereignisse`   = paste0(n_bm, " (",
                             round(100 * n_bm / n_total, 1), "%)"),
  `Median OS (Mo)`  = ifelse(is.na(median_os_mo), "n.e.",
                             paste0(round(median_os_mo, 1), " [",
                                    round(median_os_ll, 1), "–",
                                    round(median_os_ul, 1), "]")),
  `60-Mo-CIF BM`    = ifelse(is.na(cif60_pct), "–",
                             paste0(round(cif60_pct, 1), "% [",
                                    round(cif60_ll, 1), "–",
                                    round(cif60_ul, 1), "%]"))
)]

# DSGVO: N < 5 supprimieren
tab_out[as.integer(gsub("\\.", "", N)) < 5,
        `:=`(N = "< 5", `BM-Ereignisse` = "–",
             `Median OS (Mo)` = "–", `60-Mo-CIF BM` = "–")]

cat("\nTabelle: Subtyp-Zusammenfassung\n")
print(tab_out)

fwrite(tab_out, "C50_BM_Tabelle_Subtyp.csv", sep = ";", bom = TRUE)
cat("CSV gespeichert: C50_BM_Tabelle_Subtyp.csv\n")

# ============================================================
# GRAFIK 4: TABELLENPLOT — Übersicht je Subtyp
# ============================================================
cat("\n--- Grafik 4: Tabellenplot Deskriptive Zusammenfassung ---\n")

# Langformat für Heatmap-Tabellen-Plot
tab_plot = copy(tab_final)
tab_plot[, subtyp := factor(subtyp, levels = rev(subtyp_levels[-5]))]

# Balkendiagramm: BM-Rate nach Subtyp + Median OS als Punkte
tab_plot[, bm_rate := 100 * n_bm / n_total]

# Panel A: BM-Rate
p_bm_rate = ggplot(tab_plot[!is.na(subtyp) & subtyp != "Unbekannt"],
                   aes(x = subtyp, y = bm_rate, fill = subtyp)) +
  geom_col(width = 0.65, color = "white", linewidth = 0.3) +
  geom_text(aes(label = paste0(round(bm_rate, 1), "%\n(n=", n_bm, ")")),
            vjust = -0.2, size = 3.4, color = hh_dunkelblau, lineheight = 1.1) +
  scale_fill_manual(values = subtyp_farben, guide = "none") +
  scale_y_continuous(
    expand = expansion(mult = c(0, 0.18)),
    labels = function(x) paste0(x, "%"),
    name   = "Anteil Patientinnen mit BM (%)"
  ) +
  labs(
    title    = "Hirnmetastasen-Rate nach molekularem Subtyp",
    subtitle = paste0("N = ", format(nrow(dat[subtyp != "Unbekannt"]), big.mark = "."),
                      " Patientinnen | KIKA-Datenbank"),
    x        = "Molekularer Subtyp",
    caption  = "BM = Hirnmetastasen (bei Diagnose oder im Verlauf)"
  ) +
  theme_hkr()

save_png(p_bm_rate, "C50_BM_Fig4_BM_Rate_Subtyp.png", breite = 9, hoehe = 6)

# ============================================================
# GRAFIK 5: VIOLIN-PLOTS — ALTERSVERTEILUNG NACH SUBTYP
# ============================================================
# Drei Panels:
#   5A: Alter bei Erstdiagnose nach molekularem Subtyp
#   5B: Alter — BM-Patientinnen vs. ohne BM (alle Subtypen)
#   5C: Alter nach Subtyp × BM-Status (facettiert, DSGVO-bewacht)
# ============================================================
cat("\n--- Grafik 5: Violin-Plots Altersverteilung ---\n")

dat_viol = dat[subtyp != "Unbekannt" & !is.na(alter_dx) &
                 alter_dx >= 18 & alter_dx <= 99]
dat_viol[, subtyp := droplevels(subtyp)]

alter_stats = dat_viol[, .(
  med    = as.double(median(alter_dx, na.rm = TRUE)),
  q25    = as.double(quantile(alter_dx, 0.25, na.rm = TRUE)),
  q75    = as.double(quantile(alter_dx, 0.75, na.rm = TRUE)),
  n      = .N,
  y_anno = as.double(max(dat_viol$alter_dx, na.rm = TRUE)) + 2
), by = subtyp]

# ---- Fig 5A: Alter nach Subtyp ----
p_viol_a = ggplot(dat_viol, aes(x = subtyp, y = alter_dx, fill = subtyp)) +
  geom_violin(trim = FALSE, alpha = 0.65, color = "white",
              linewidth = 0.3, bw = "nrd0") +
  geom_boxplot(width = 0.12, fill = "white", color = hh_dunkelblau,
               outlier.shape = NA, linewidth = 0.55, alpha = 0.9) +
  stat_summary(fun = median, geom = "point", shape = 21, size = 2.8,
               fill = "white", color = hh_dunkelblau, stroke = 1.2) +
  geom_text(data = alter_stats,
            aes(x = subtyp, y = y_anno,
                label = paste0("n = ", format(n, big.mark = "."))),
            inherit.aes = FALSE, size = 3.2, color = hh_dunkelgrau) +
  geom_text(data = alter_stats,
            aes(x = subtyp, y = med - 5,
                label = paste0(round(med, 0), " [",
                               round(q25, 0), "–", round(q75, 0), "]")),
            inherit.aes = FALSE, size = 2.8,
            color = hh_dunkelblau, fontface = "bold") +
  scale_fill_manual(values = subtyp_farben, guide = "none") +
  scale_y_continuous(
    breaks = seq(20, 100, 10),
    limits = c(15, max(dat_viol$alter_dx, na.rm = TRUE) + 6),
    name   = "Alter bei Erstdiagnose (Jahre)"
  ) +
  labs(
    title    = "Altersverteilung bei Erstdiagnose nach molekularem Subtyp",
    subtitle = paste0("N = ", format(nrow(dat_viol), big.mark = "."),
                      " Patientinnen | KIKA-Datenbank\n",
                      "Innere Zahl: Median [IQR]"),
    x       = "Molekularer Subtyp",
    caption = "Weiße Linie im Boxplot: Median | Box: IQR"
  ) +
  theme_hkr() +
  theme(panel.grid.major.x = element_blank())

save_png(p_viol_a, "C50_BM_Fig5A_Alter_Subtyp_Violin.png", breite = 10, hoehe = 7)

# ---- Fig 5B: Alter nach BM-Status ----
dat_viol_b = dat[!is.na(alter_dx) & alter_dx >= 18 & alter_dx <= 99]
dat_viol_b[, bm_gruppe := factor(
  fifelse(hat_bm == 1L, "Mit Hirnmetastasen", "Ohne Hirnmetastasen"),
  levels = c("Ohne Hirnmetastasen", "Mit Hirnmetastasen")
)]

alter_bm_stats = dat_viol_b[, .(
  med    = as.double(median(alter_dx, na.rm = TRUE)),
  q25    = as.double(quantile(alter_dx, 0.25, na.rm = TRUE)),
  q75    = as.double(quantile(alter_dx, 0.75, na.rm = TRUE)),
  n      = .N,
  y_anno = as.double(max(dat_viol_b$alter_dx, na.rm = TRUE)) + 2
), by = bm_gruppe]

bm_farben = c("Ohne Hirnmetastasen" = hh_blau, "Mit Hirnmetastasen" = hh_rot)
gesamt_median = median(dat_viol_b$alter_dx, na.rm = TRUE)

p_viol_b = ggplot(dat_viol_b, aes(x = bm_gruppe, y = alter_dx, fill = bm_gruppe)) +
  geom_violin(trim = FALSE, alpha = 0.65, color = "white",
              linewidth = 0.3, bw = "nrd0") +
  geom_boxplot(width = 0.12, fill = "white", color = hh_dunkelblau,
               outlier.shape = NA, linewidth = 0.55, alpha = 0.9) +
  stat_summary(fun = median, geom = "point", shape = 21, size = 3.0,
               fill = "white", color = hh_dunkelblau, stroke = 1.2) +
  geom_hline(yintercept = gesamt_median, linetype = "dashed",
             color = hh_dunkelgrau, linewidth = 0.6) +
  annotate("text", x = 2.42, y = gesamt_median + 1.5,
           label = paste0("Gesamt-Median: ", round(gesamt_median, 1), " J."),
           size = 3.0, color = hh_dunkelgrau, hjust = 1) +
  geom_text(data = alter_bm_stats,
            aes(x = bm_gruppe, y = y_anno,
                label = paste0("n = ", format(n, big.mark = "."))),
            inherit.aes = FALSE, size = 3.4, color = hh_dunkelgrau) +
  geom_text(data = alter_bm_stats,
            aes(x = bm_gruppe, y = med - 5,
                label = paste0(round(med, 0), " [",
                               round(q25, 0), "–", round(q75, 0), "]")),
            inherit.aes = FALSE, size = 3.0,
            color = hh_dunkelblau, fontface = "bold") +
  scale_fill_manual(values = bm_farben, guide = "none") +
  scale_y_continuous(
    breaks = seq(20, 100, 10),
    limits = c(15, max(dat_viol_b$alter_dx, na.rm = TRUE) + 6),
    name   = "Alter bei Erstdiagnose (Jahre)"
  ) +
  labs(
    title    = "Altersverteilung: Patientinnen mit vs. ohne Hirnmetastasen",
    subtitle = paste0("N = ", format(nrow(dat_viol_b), big.mark = "."),
                      " Patientinnen | KIKA-Datenbank\n",
                      "Innere Zahl: Median [IQR] | Gestrichelte Linie: Gesamtmedian"),
    x       = NULL,
    caption = "Hirnmetastasen: bei Diagnose oder im Verlauf dokumentiert"
  ) +
  theme_hkr() +
  theme(panel.grid.major.x = element_blank())

save_png(p_viol_b, "C50_BM_Fig5B_Alter_BM_Status_Violin.png", breite = 8, hoehe = 7)

# ---- Fig 5C: Alter nach Subtyp x BM-Status (facettiert) ----
# DSGVO-Wächter: nur Subtypen mit >= 5 BM-Ereignissen
subtyp_bm_n = dat_viol[, .(n_bm = sum(hat_bm)), by = subtyp]
subtyp_ok   = subtyp_bm_n[n_bm >= 5, subtyp]
dat_viol_c  = dat_viol[subtyp %in% subtyp_ok]
dat_viol_c[, bm_gruppe := factor(
  fifelse(hat_bm == 1L, "Mit BM", "Ohne BM"),
  levels = c("Ohne BM", "Mit BM")
)]

if (nrow(dat_viol_c) > 0 && length(subtyp_ok) > 0) {
  # Median-Labels je Facette x BM-Gruppe
  facet_stats = dat_viol_c[, .(
    med  = as.double(median(alter_dx, na.rm = TRUE)),
    q25  = as.double(quantile(alter_dx, 0.25, na.rm = TRUE)),
    q75  = as.double(quantile(alter_dx, 0.75, na.rm = TRUE)),
    n    = .N,
    ypos = as.double(median(alter_dx, na.rm = TRUE)) - 6
  ), by = .(subtyp, bm_gruppe)]

  p_viol_c = ggplot(dat_viol_c,
                    aes(x = bm_gruppe, y = alter_dx, fill = subtyp)) +
    geom_violin(trim = FALSE, alpha = 0.60, color = "white",
                linewidth = 0.3, bw = "nrd0") +
    geom_boxplot(width = 0.15, fill = "white", color = hh_dunkelblau,
                 outlier.shape = NA, linewidth = 0.45, alpha = 0.85) +
    stat_summary(fun = median, geom = "point", shape = 21, size = 2.2,
                 fill = "white", color = hh_dunkelblau, stroke = 1.0) +
    geom_text(data = facet_stats,
              aes(x = bm_gruppe, y = ypos,
                  label = paste0(round(med, 0), "\n[",
                                 round(q25, 0), "–", round(q75, 0), "]")),
              inherit.aes = FALSE, size = 2.6,
              color = hh_dunkelblau, fontface = "bold", lineheight = 1.0) +
    scale_fill_manual(values = subtyp_farben, guide = "none") +
    scale_y_continuous(breaks = seq(20, 100, 20),
                       name   = "Alter bei Erstdiagnose (Jahre)") +
    facet_wrap(~ subtyp, nrow = 1) +
    labs(
      title    = "Altersverteilung nach Subtyp und Hirnmetastasen-Status",
      subtitle = paste0("Facetten: molekularer Subtyp | N = ",
                        format(nrow(dat_viol_c), big.mark = "."),
                        " Patientinnen\n",
                        "Nur Subtypen mit ≥ 5 BM-Ereignissen (DSGVO)"),
      x       = "Hirnmetastasen-Status",
      caption = "Innere Zahl: Median [IQR] | BM = Hirnmetastasen"
    ) +
    theme_hkr() +
    theme(panel.grid.major.x = element_blank(),
          strip.text = element_text(face = "bold", size = 11))

  save_png(p_viol_c, "C50_BM_Fig5C_Alter_Subtyp_BM_facet_Violin.png",
           breite = 12, hoehe = 7)
} else {
  cat("Fig 5C uebersprungen: zu wenige BM-Events fuer DSGVO-konforme Darstellung.\n")
}


# ============================================================
# KONSOLENZUSAMMENFASSUNG
# ============================================================
cat("\n========== ANALYSEZUSAMMENFASSUNG ==========\n")
cat(sprintf("Patientinnen gesamt:      %d\n",   nrow(dat)))
cat(sprintf("Davon mit Hirnmetastasen: %d (%.1f%%)\n",
            sum(dat$hat_bm), 100 * mean(dat$hat_bm)))
cat(sprintf("Davon verstorben:         %d (%.1f%%)\n",
            sum(dat$status_os), 100 * mean(dat$status_os)))
cat(sprintf("Medianes FU (OS):         %.1f Monate\n",
            median(dat$fu_os_mo, na.rm = TRUE)))
cat("\nSubtyp-Verteilung:\n")
print(dat[, .N, by = subtyp][order(subtyp)])
cat("\nGespeicherte Dateien:\n")
cat("  C50_BM_Fig1_Subtyp_Verteilung.png\n")
cat("  C50_BM_Fig2_KM_OS_Subtyp.png\n")
cat("  C50_BM_Fig3_CIF_BrainMet_Subtyp.png\n")
cat("  C50_BM_Fig4_BM_Rate_Subtyp.png\n")
cat("  C50_BM_Fig5A_Alter_Subtyp_Violin.png\n")
cat("  C50_BM_Fig5B_Alter_BM_Status_Violin.png\n")
cat("  C50_BM_Fig5C_Alter_Subtyp_BM_facet_Violin.png  (DSGVO-bewacht)\n")
cat("  C50_BM_Tabelle_Subtyp.csv\n")
cat("=============================================\n")

# HINWEIS: Ausgabe vor Weitergabe auf N < 5 prüfen (DSGVO).
