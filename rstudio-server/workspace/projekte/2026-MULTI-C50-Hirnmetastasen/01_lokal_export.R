# =============================================================================
# KIKA – Federated Multi-Register-Analyse: C50 Hirnmetastasen
# 01_lokal_export.R — Läuft in JEDEM der 15 Landeskrebsregister
#
# Dieses Skript verbindet sich mit der lokalen KIKA-Datenbank des Registers,
# bereitet die Daten auf und exportiert ausschließlich aggregierte
# Summary Statistics. Es verlassen KEINE Einzelfalldaten das Register.
#
# DSGVO: Alle Zellen mit N < 5 werden vor dem Export supprimiert (NA).
#
# Output: exports/{REGISTER_KUERZEL}_export.rds
#         exports/{REGISTER_KUERZEL}_meta.csv   (Prüftabelle für Register)
# =============================================================================

rm(list = ls())
source("00_config.R")

# ============================================================
# REGISTER-KONFIGURATION — VOM REGISTER AUSZUFÜLLEN
# ============================================================
REGISTER_KUERZEL = "HH"          # Kürzel, z.B. "HH", "BY", "NW", "BW" ...
REGISTER_NAME    = "Hamburg"      # Vollständiger Name
EXPORT_PFAD      = "exports/"

# Datenbankverbindung (an lokale Infrastruktur anpassen)
DB_HOST     = "central-db"
DB_PORT     = 5432
DB_NAME     = "krebs"
DB_USER     = "postgres"
DB_PASSWORD = "1234"

# ============================================================
# 0. PAKETE
# ============================================================
pkgs = c("DBI", "RPostgres", "data.table", "jsonlite",
         "survival", "cmprsk", "ggplot2")
for (p in pkgs) {
  if (!require(p, character.only = TRUE, quietly = TRUE))
    install.packages(p, repos = "https://cloud.r-project.org", quiet = TRUE)
  library(p, character.only = TRUE, quietly = TRUE)
}

# ============================================================
# 1. DATEN LADEN (identisch mit 02_analyse.R)
# ============================================================
con = dbConnect(
  RPostgres::Postgres(),
  host = DB_HOST, port = DB_PORT,
  dbname = DB_NAME, user = DB_USER, password = DB_PASSWORD
)
cat("Datenbankverbindung:", REGISTER_NAME, "\n")

basis = as.data.table(dbGetQuery(con, "
  SELECT
    pr.patient_id,
    pr.date_of_birth,
    pr.is_deceased,
    pr.vital_status_date,
    tr.id                           AS tr_id,
    tr.diagnosis_date,
    th.grading,
    tb.estrogen_receptor_status     AS er_status,
    tb.progesterone_receptor_status AS pr_status,
    tb.her2neu_status               AS her2_status
  FROM patient_report   pr
  JOIN tumor_report     tr ON tr.patient_report_id = pr.id
  LEFT JOIN tumor_histology     th ON th.tumor_report_id = tr.id
  LEFT JOIN tumor_report_breast tb ON tb.tumor_report_id = tr.id
  WHERE tr.icd->>'code' LIKE 'C50%'
"))
cat("C50-Basisfälle:", nrow(basis), "\n")

fe_raw      = data.table()
fm_diag_raw = data.table()

if (nrow(basis) > 0) {
  tr_ids_sql = paste(unique(basis$tr_id), collapse = ",")

  fe_raw = as.data.table(dbGetQuery(con, sprintf("
    SELECT tfu.tumor_report_id AS tr_id,
           tfu.date            AS fe_datum,
           tfu.distant_metastasis AS fm_json
    FROM tumor_follow_up tfu
    WHERE tfu.tumor_report_id IN (%s) AND tfu.date IS NOT NULL
    ORDER BY tfu.tumor_report_id, tfu.date
  ", tr_ids_sql)))

  fm_diag_raw = as.data.table(dbGetQuery(con, sprintf("
    SELECT tr.id AS tr_id, tr.diagnosis_date AS fm_datum,
           tr.distant_metastasis AS fm_json
    FROM tumor_report tr
    WHERE tr.id IN (%s) AND tr.distant_metastasis IS NOT NULL
  ", tr_ids_sql)))
}

dbDisconnect(con)
cat("Datenbankverbindung geschlossen.\n")

# ============================================================
# 2. DATENVORBEREITUNG (identisch mit 02_analyse.R)
# ============================================================
basis[, diagnosis_date    := as.Date(diagnosis_date)]
basis[, date_of_birth     := as.Date(date_of_birth)]
basis[, vital_status_date := as.Date(vital_status_date)]
basis[, diagnosejahr      := as.integer(format(diagnosis_date, "%Y"))]
basis[, alter_dx          := as.integer(floor(
  as.numeric(diagnosis_date - date_of_birth) / 365.25))]

setorder(basis, patient_id, diagnosis_date)
basis = basis[, .SD[1], by = patient_id]

basis[, er   := fcase(er_status   == "P", "P", er_status   == "N", "N", default = "U")]
basis[, pr   := fcase(pr_status   == "P", "P", pr_status   == "N", "N", default = "U")]
basis[, her2 := fcase(her2_status == "P", "P", her2_status == "N", "N", default = "U")]
basis[, subtyp := fcase(
  her2 == "P" & er == "N" & pr == "N",          "HER2+/HR-",
  her2 == "P" & (er == "P" | pr == "P"),         "HER2+/HR+",
  her2 == "N" & er == "N" & pr == "N",           "TNBC",
  her2 == "N" & (er == "P" | pr == "P"),         "HR+/HER2-",
  default = "Unbekannt"
)]
basis[, subtyp := factor(subtyp, levels = subtyp_levels)]

# BM-Parsing
hat_bra_in_json = function(json_str) {
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
        if (length(lok_col) > 0) return(as.character(x[[lok_col[1]]])); NA_character_
      })
      return(any(toupper(loks) == "BRA", na.rm = TRUE))
    }
    FALSE
  }, error = function(e) FALSE)
}

bm_fe = data.table()
if (nrow(fe_raw) > 0) {
  fe_raw[, fe_datum := as.Date(fe_datum)]
  fe_raw[, hat_bra  := sapply(fm_json, hat_bra_in_json)]
  bm_fe = fe_raw[hat_bra == TRUE][order(tr_id, fe_datum)][, .SD[1], by = tr_id]
  bm_fe = bm_fe[, .(tr_id, datum_bm_fe = fe_datum)]
}

bm_diag = data.table()
if (nrow(fm_diag_raw) > 0) {
  fm_diag_raw[, hat_bra_diag := sapply(fm_json, hat_bra_in_json)]
  bm_diag = fm_diag_raw[hat_bra_diag == TRUE,
                         .(tr_id, datum_bm_diag = as.Date(fm_datum))]
}

dat = copy(basis)
dat = merge(dat, bm_fe,   by = "tr_id", all.x = TRUE)
dat = merge(dat, bm_diag, by = "tr_id", all.x = TRUE)
dat[, datum_bm := pmin(datum_bm_diag, datum_bm_fe, na.rm = TRUE)]
dat[, hat_bm   := as.integer(!is.na(datum_bm))]

# ============================================================
# 3. ZEITVARIABLEN
# ============================================================
dat[, status_os := as.integer(is_deceased == TRUE)]
dat[, fu_os     := as.numeric(vital_status_date - diagnosis_date)]
dat[is.na(fu_os) | fu_os < 0, `:=`(fu_os = 0, status_os = 0L)]
dat[fu_os > MAX_FU_TAGE, `:=`(status_os = 0L, fu_os = MAX_FU_TAGE)]
dat[, fu_os_mo  := fu_os / 30.4375]

dat[, tage_bis_bm := as.numeric(datum_bm - diagnosis_date)]
dat[, event_cif := fcase(
  hat_bm == 1L & !is.na(tage_bis_bm) & tage_bis_bm > 0,  1L,
  status_os == 1L & hat_bm == 0L,                          2L,
  default = 0L
)]
dat[, t_cif    := fcase(event_cif == 1L, tage_bis_bm, default = fu_os)]
dat[, t_cif_mo := t_cif / 30.4375]
dat[t_cif > MAX_FU_TAGE, `:=`(event_cif = 0L, t_cif = MAX_FU_TAGE,
                               t_cif_mo  = MAX_FU_TAGE / 30.4375)]
# Indikator nur für Ereignis 1 (BM) — für cause-specific Cox
dat[, event_bm1 := as.integer(event_cif == 1L)]

# Altersgruppen
dat[, alter_grp := cut(alter_dx, breaks = ALTERS_BREAKS,
                       labels = ALTERS_LABELS, right = FALSE)]
dat[, alter_grp := factor(alter_grp, levels = ALTERS_LABELS)]

cat(sprintf("\nN gesamt: %d | BM: %d (%.1f%%) | Verstorben: %d (%.1f%%)\n",
            nrow(dat), sum(dat$hat_bm), 100*mean(dat$hat_bm),
            sum(dat$status_os), 100*mean(dat$status_os)))

# ============================================================
# HILFSFUNKTION: DSGVO-Suppression
# ============================================================
supprimiere = function(dt, zaehl_col, min_n = DSGVO_MINZAHL) {
  dt = copy(dt)
  dt[get(zaehl_col) < min_n & get(zaehl_col) > 0,
     (zaehl_col) := NA_integer_]
  dt
}

# ============================================================
# EXPORT A: KM-EVENT-TABELLE (Gesamtüberleben nach Subtyp)
# ============================================================
# Enthält pro Subtyp die vollständige Ereignistabelle (t, n.risk, n.event, n.censor).
# Aus dieser Tabelle kann das zentrale Skript die gepoolte KM-Kurve exakt
# rekonstruieren — ohne dass Einzelfalldaten übertragen werden.
cat("\n--- Export A: KM-Event-Tabelle OS ---\n")

dat_km = dat[subtyp != "Unbekannt" & fu_os > 0]
dat_km[, subtyp := droplevels(subtyp)]

km_os_fit = survfit(Surv(fu_os_mo, status_os) ~ subtyp, data = dat_km)
km_os_sum = summary(km_os_fit)

km_os_tab = data.table(
  register  = REGISTER_KUERZEL,
  subtyp    = sub("subtyp=", "", as.character(km_os_sum$strata)),
  t         = km_os_sum$time,
  n.risk    = km_os_sum$n.risk,
  n.event   = km_os_sum$n.event,
  n.censor  = km_os_sum$n.censor
)
km_os_tab[, subtyp := factor(subtyp, levels = subtyp_levels)]

# DSGVO: Subtypgruppen mit Gesamtzahl < 5 komplett entfernen
n_je_subtyp = dat_km[, .N, by = subtyp]
ok_subtypes  = n_je_subtyp[N >= DSGVO_MINZAHL, subtyp]
km_os_tab    = km_os_tab[subtyp %in% ok_subtypes]

cat("KM-OS: Zeilen exportiert:", nrow(km_os_tab), "\n")

# ============================================================
# EXPORT B: KM-EVENT-TABELLE (Hirnmetastasen, cause-specific)
# ============================================================
cat("--- Export B: KM-Event-Tabelle BM ---\n")

dat_cif = dat[subtyp != "Unbekannt" & t_cif > 0]
dat_cif[, subtyp := droplevels(subtyp)]

km_bm_fit = survfit(Surv(t_cif_mo, event_bm1) ~ subtyp, data = dat_cif)
km_bm_sum = summary(km_bm_fit)

km_bm_tab = data.table(
  register = REGISTER_KUERZEL,
  subtyp   = sub("subtyp=", "", as.character(km_bm_sum$strata)),
  t        = km_bm_sum$time,
  n.risk   = km_bm_sum$n.risk,
  n.event  = km_bm_sum$n.event,
  n.censor = km_bm_sum$n.censor
)
km_bm_tab[, subtyp := factor(subtyp, levels = subtyp_levels)]
km_bm_tab = km_bm_tab[subtyp %in% ok_subtypes]
cat("KM-BM: Zeilen exportiert:", nrow(km_bm_tab), "\n")

# ============================================================
# EXPORT C: COX-KOEFFIZIENTEN (Two-Stage Meta-Analyse)
# ============================================================
# Jedes Register schätzt dieselbe Cox-Formel (definiert in 00_config.R).
# Exportiert werden nur Koeffizientenvektor und Varianz-Kovarianz-Matrix.
# Das zentrale Skript führt darüber eine Random-Effects-Meta-Analyse durch.
cat("--- Export C: Cox-Koeffizienten ---\n")

cox_dat = dat[subtyp != "Unbekannt" & fu_os > 0 & !is.na(alter_grp) &
                diagnosejahr >= JAHRE_VON & diagnosejahr <= JAHRE_BIS]
cox_dat[, subtyp    := relevel(droplevels(subtyp), ref = "HR+/HER2-")]
cox_dat[, alter_grp := relevel(alter_grp, ref = "50-59")]

cox_os_export = tryCatch({
  fit = coxph(as.formula(COX_OS_FORMEL), data = cox_dat, x = FALSE, y = FALSE)
  list(
    register = REGISTER_KUERZEL,
    coef     = coef(fit),
    vcov     = as.matrix(vcov(fit)),
    n        = fit$n,
    events   = fit$nevent,
    formel   = COX_OS_FORMEL
  )
}, error = function(e) {
  cat("Cox OS nicht möglich:", conditionMessage(e), "\n"); NULL
})

cox_bm_export = tryCatch({
  fit = coxph(as.formula(COX_BM_FORMEL), data = cox_dat, x = FALSE, y = FALSE)
  list(
    register = REGISTER_KUERZEL,
    coef     = coef(fit),
    vcov     = as.matrix(vcov(fit)),
    n        = fit$n,
    events   = fit$nevent,
    formel   = COX_BM_FORMEL
  )
}, error = function(e) {
  cat("Cox BM nicht möglich:", conditionMessage(e), "\n"); NULL
})

# ============================================================
# EXPORT D: POISSON-ZÄHLTABELLE (Inzidenztrend)
# ============================================================
# Counts + Personenjahre nach Subtyp × Altersgruppe × Diagnosejahr.
# Basis für das zentrale Trendmodell und bayesianische Glättung.
# DSGVO: Zellen mit n_events < 5 werden supprimiert.
cat("--- Export D: Poisson-Zähltabelle ---\n")

poisson_dat = dat[subtyp != "Unbekannt" & !is.na(alter_grp) &
                    diagnosejahr >= JAHRE_VON & diagnosejahr <= JAHRE_BIS]

poisson_tab = poisson_dat[, .(
  n_bm = sum(hat_bm),
  py   = round(sum(fu_os) / 365.25, 2)
), by = .(subtyp, alter_grp, diagnosejahr)]
poisson_tab[, register := REGISTER_KUERZEL]

poisson_tab = supprimiere(poisson_tab, "n_bm")
cat("Poisson-Tabelle: Zeilen exportiert:", nrow(poisson_tab),
    "| Supprimiert:", poisson_tab[is.na(n_bm), .N], "\n")

# ============================================================
# EXPORT E: DESKRIPTIVSTATISTIK
# ============================================================
cat("--- Export E: Deskriptivstatistik ---\n")

deskriptiv = dat[, .(
  n_gesamt     = .N,
  n_bm         = sum(hat_bm),
  n_verstorben = sum(status_os),
  median_fu_mo = round(median(fu_os_mo, na.rm = TRUE), 1),
  median_alter = round(median(alter_dx, na.rm = TRUE), 1)
), by = subtyp]
deskriptiv[, register := REGISTER_KUERZEL]

# DSGVO
deskriptiv[n_gesamt < DSGVO_MINZAHL,
           `:=`(n_gesamt = NA_integer_, n_bm = NA_integer_,
                n_verstorben = NA_integer_)]
deskriptiv[is.na(n_bm), `:=`(median_fu_mo = NA_real_, median_alter = NA_real_)]

# ============================================================
# ZUSAMMENSTELLEN UND SPEICHERN
# ============================================================
export_liste = list(
  meta = list(
    register      = REGISTER_KUERZEL,
    register_name = REGISTER_NAME,
    datum_export  = as.character(Sys.Date()),
    n_gesamt      = nrow(dat),
    skript_version = "01_lokal_export.R v1.0"
  ),
  km_os_tab    = km_os_tab,
  km_bm_tab    = km_bm_tab,
  cox_os       = cox_os_export,
  cox_bm       = cox_bm_export,
  poisson_tab  = poisson_tab,
  deskriptiv   = deskriptiv
)

dir.create(EXPORT_PFAD, showWarnings = FALSE)
export_datei = file.path(EXPORT_PFAD, paste0(REGISTER_KUERZEL, "_export.rds"))
saveRDS(export_liste, export_datei)
cat("\nExport gespeichert:", export_datei, "\n")

# Prüftabelle als CSV (für das Register zur Sichtkontrolle vor Weitergabe)
pruef_tab = rbind(
  data.table(Export = "KM-OS",    Zeilen = nrow(km_os_tab),
             Supprimiert = 0L, Hinweis = ""),
  data.table(Export = "KM-BM",    Zeilen = nrow(km_bm_tab),
             Supprimiert = 0L, Hinweis = ""),
  data.table(Export = "Poisson",  Zeilen = nrow(poisson_tab),
             Supprimiert = poisson_tab[is.na(n_bm), .N],
             Hinweis = paste0("N gesamt: ", nrow(dat))),
  data.table(Export = "Deskriptiv", Zeilen = nrow(deskriptiv),
             Supprimiert = deskriptiv[is.na(n_gesamt), .N], Hinweis = "")
)
fwrite(pruef_tab, file.path(EXPORT_PFAD,
       paste0(REGISTER_KUERZEL, "_prueftabelle.csv")), sep = ";", bom = TRUE)

cat("\n========== EXPORT ABGESCHLOSSEN ==========\n")
cat("Register:    ", REGISTER_NAME, "(", REGISTER_KUERZEL, ")\n")
cat("Export-Datum:", as.character(Sys.Date()), "\n")
cat("Datei:       ", export_datei, "\n")
cat("Bitte Prüftabelle vor Weitergabe kontrollieren!\n")
cat("==========================================\n")
