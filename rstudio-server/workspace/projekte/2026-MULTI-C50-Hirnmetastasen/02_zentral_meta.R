# =============================================================================
# KIKA – Federated Multi-Register-Analyse: C50 Hirnmetastasen
# 02_zentral_meta.R — Läuft zentral bei HKR
#
# Liest die Export-RDS-Dateien aus allen 15 Registern und führt durch:
#   A. Gepoolte Kaplan-Meier-Kurven (OS + BM) — exaktes Pooling
#   B. Two-Stage Cox-Meta-Analyse (Fixed + Random Effects)
#   C. Poisson-Trendmodell mit Register als Random Effect
#   D. Bayesianische Glättung (INLA BYM2) für Inzidenztrends
#   E. Deskriptive Zusammenfassung über alle Register
# =============================================================================

rm(list = ls())
source("00_config.R")

# ============================================================
# 0. PAKETE
# ============================================================
pkgs = c("data.table", "survival", "ggplot2", "scales",
         "metafor",    # Two-Stage Meta-Analyse
         "lme4",       # Poisson Mixed Model
         "broom",      # GLM-Koeffizienten (Einzelregister-Fallback)
         "gridExtra", "grid")
pkgs_optional = c("INLA")  # Bayesianische Glättung — separat installieren falls nötig

for (p in pkgs) {
  if (!require(p, character.only = TRUE, quietly = TRUE))
    install.packages(p, repos = "https://cloud.r-project.org", quiet = TRUE)
  library(p, character.only = TRUE, quietly = TRUE)
}

inla_verfuegbar = requireNamespace("INLA", quietly = TRUE)
if (!inla_verfuegbar)
  cat("HINWEIS: INLA nicht installiert — Abschnitt D wird übersprungen.\n",
      "Installation: install.packages('INLA', repos='https://inla.r-inla-download.org/R/stable')\n\n")

# ============================================================
# 1. EXPORTE LADEN
# ============================================================
cat("--- Lade Register-Exporte ---\n")

export_dateien = list.files("exports", pattern = "_export\\.rds$",
                             full.names = TRUE)
if (length(export_dateien) == 0)
  stop("Keine Export-Dateien in exports/ gefunden.")

exporte = lapply(export_dateien, readRDS)
names(exporte) = sapply(exporte, function(x) x$meta$register)
cat("Register geladen:", paste(names(exporte), collapse = ", "), "\n")
cat("Anzahl Register:", length(exporte), "\n\n")

# Meta-Übersicht
meta_tab = rbindlist(lapply(exporte, function(x) as.data.table(x$meta)))
print(meta_tab[, .(register, register_name, datum_export, n_gesamt)])

# ============================================================
# 2. HILFSFUNKTIONEN
# ============================================================

# Gepoolte KM aus aggregierten Event-Tabellen mehrerer Register.
# Methode: Summiere n.risk und n.event an jedem Zeitpunkt über alle Register.
# Das Ergebnis ist äquivalent zur KM auf dem gepoolten Datensatz.
pool_km = function(km_listen, subtyp_filter = NULL) {
  alle = rbindlist(lapply(exporte, function(x) x[[km_listen]]))
  if (!is.null(subtyp_filter))
    alle = alle[subtyp == subtyp_filter]

  # Aggregiere über alle Zeitpunkte je Subtyp
  alle[, subtyp := factor(subtyp, levels = subtyp_levels)]
  gepoolte_zeiten = alle[, .(
    n.risk  = sum(n.risk,  na.rm = TRUE),
    n.event = sum(n.event, na.rm = TRUE)
  ), by = .(subtyp, t)]
  setorder(gepoolte_zeiten, subtyp, t)

  # KM manuell berechnen
  gepoolte_zeiten[, surv := cumprod(1 - n.event / n.risk), by = subtyp]
  # Greenwood-Varianz
  gepoolte_zeiten[, greenwood := cumsum(n.event / (n.risk * (n.risk - n.event))),
                  by = subtyp]
  gepoolte_zeiten[, se   := surv * sqrt(greenwood)]
  gepoolte_zeiten[, lower := pmax(0, surv - 1.96 * se)]
  gepoolte_zeiten[, upper := pmin(1, surv + 1.96 * se)]

  # Startzeile (t=0) anfügen
  starts = unique(gepoolte_zeiten[, .(subtyp)])[,
    .(subtyp, t=0, n.risk=NA_integer_, n.event=0L,
      surv=1, se=0, lower=1, upper=1, greenwood=0)]
  rbind(starts, gepoolte_zeiten)[order(subtyp, t)]
}

# ============================================================
# ANALYSE A: GEPOOLTE KM — GESAMTÜBERLEBEN
# ============================================================
cat("\n--- Analyse A: Gepoolte KM (Gesamtüberleben) ---\n")

km_os_pool = pool_km("km_os_tab")
n_register = length(exporte)
n_gesamt   = sum(sapply(exporte, function(x) x$meta$n_gesamt), na.rm = TRUE)

p_km_pool = ggplot(km_os_pool[!is.na(surv)],
                   aes(x = t, y = surv * 100, color = subtyp, fill = subtyp)) +
  geom_step(linewidth = 0.9) +
  geom_ribbon(aes(ymin = lower * 100, ymax = upper * 100),
              alpha = 0.10, color = NA) +
  scale_color_manual(values = subtyp_farben, name = "Molekularer Subtyp") +
  scale_fill_manual( values = subtyp_farben, guide  = "none") +
  scale_x_continuous(breaks = seq(0, MAX_FU_MO, 12), limits = c(0, MAX_FU_MO),
                     expand = expansion(mult = c(0.01, 0.02)),
                     name   = "Zeit ab Diagnose (Monate)") +
  scale_y_continuous(limits = c(0, 101), breaks = seq(0, 100, 20),
                     labels = function(x) paste0(x, "%"),
                     name   = "Gesamtüberleben") +
  labs(
    title    = "Gepooltes Gesamtüberleben nach molekularem Subtyp",
    subtitle = paste0("Kaplan-Meier | N = ", suppressWarnings(formatC(n_gesamt, format = "d", big.mark = ".")),
                      " Patientinnen | ", n_register, " Landeskrebsregister\n",
                      "Zensierung bei 60 Monaten | Federated Analysis"),
    caption  = "Schraffierter Bereich: 95%-KI (Greenwood) | HKR-KIKA Multi-Register"
  ) +
  theme_hkr() +
  theme(legend.position   = c(0.82, 0.75),
        legend.background = element_rect(fill = "white", color = hh_grau, linewidth = 0.4))

save_png(p_km_pool, "MULTI_Fig1_KM_OS_gepoolte.png", breite = 11, hoehe = 7)

# ============================================================
# ANALYSE B: GEPOOLTE KM — HIRNMETASTASEN (cause-specific)
# ============================================================
cat("--- Analyse B: Gepoolte KM (Hirnmetastasen) ---\n")

km_bm_pool = pool_km("km_bm_tab")
# Hier ist surv = 1 - kumulative Inzidenz (cause-specific Hazard Schätzer)
km_bm_pool[, cuminc := (1 - surv) * 100]

p_cuminc_pool = ggplot(km_bm_pool[!is.na(cuminc)],
                       aes(x = t, y = cuminc, color = subtyp, fill = subtyp)) +
  geom_step(linewidth = 0.9) +
  scale_color_manual(values = subtyp_farben, name = "Molekularer Subtyp") +
  scale_fill_manual( values = subtyp_farben, guide  = "none") +
  scale_x_continuous(breaks = seq(0, MAX_FU_MO, 12), limits = c(0, MAX_FU_MO),
                     expand = expansion(mult = c(0.01, 0.02)),
                     name   = "Zeit ab Diagnose (Monate)") +
  scale_y_continuous(limits = c(0, NA),
                     expand = expansion(mult = c(0.01, 0.12)),
                     labels = function(x) paste0(x, "%"),
                     name   = "Kumulative Inzidenz Hirnmetastasen") +
  labs(
    title    = "Kumulative Inzidenz von Hirnmetastasen nach Subtyp",
    subtitle = paste0("Cause-Specific Hazard | N = ", suppressWarnings(formatC(n_gesamt, format = "d", big.mark = ".")),
                      " Patientinnen | ", n_register, " Landeskrebsregister"),
    caption  = "Federated Analysis: gepoolte Event-Tabellen aus 15 Registern | HKR-KIKA"
  ) +
  theme_hkr() +
  theme(legend.position   = c(0.18, 0.78),
        legend.background = element_rect(fill = "white", color = hh_grau, linewidth = 0.4))

save_png(p_cuminc_pool, "MULTI_Fig2_CumInc_BM_gepoolte.png", breite = 11, hoehe = 7)

# ============================================================
# ANALYSE C: TWO-STAGE COX META-ANALYSE
# ============================================================
# Jedes Register hat coxph() auf denselben Prädiktoren geschätzt.
# Hier werden die Koeffizientenvektoren über alle Register
# zu gepoolten HR mit KI zusammengefasst (Random Effects, REML).
cat("\n--- Analyse C: Two-Stage Cox Meta-Analyse ---\n")

meta_cox = function(cox_liste_name, endpoint_label) {
  cox_daten = lapply(names(exporte), function(reg) {
    x = exporte[[reg]][[cox_liste_name]]
    if (is.null(x)) return(NULL)
    data.table(
      register = reg,
      variable = names(x$coef),
      coef     = as.numeric(x$coef),
      se       = sqrt(diag(x$vcov)),
      n        = x$n,
      events   = x$events
    )
  })
  cox_daten = rbindlist(cox_daten[!sapply(cox_daten, is.null)])

  # Meta-Analyse je Variable
  variablen = unique(cox_daten$variable)
  ergebnisse = rbindlist(lapply(variablen, function(v) {
    sub_dat = cox_daten[variable == v]
    if (nrow(sub_dat) == 0) return(NULL)
    if (nrow(sub_dat) == 1) {
      # Einzelregister: KI direkt aus Koeffizient + SE
      return(data.table(
        endpoint   = endpoint_label, variable  = v,
        HR         = round(exp(sub_dat$coef), 3),
        HR_lower   = round(exp(sub_dat$coef - 1.96 * sub_dat$se), 3),
        HR_upper   = round(exp(sub_dat$coef + 1.96 * sub_dat$se), 3),
        p_val      = NA_real_, I2 = NA_real_, n_register = 1L
      ))
    }
    tryCatch({
      ma = rma(yi = coef, sei = se, data = sub_dat, method = "REML")
      data.table(
        endpoint  = endpoint_label,
        variable  = v,
        HR        = round(exp(ma$beta), 3),
        HR_lower  = round(exp(ma$ci.lb), 3),
        HR_upper  = round(exp(ma$ci.ub), 3),
        p_val     = round(ma$pval, 4),
        I2        = round(ma$I2, 1),
        n_register = nrow(sub_dat)
      )
    }, error = function(e) NULL)
  }))
  ergebnisse
}

cox_os_meta = meta_cox("cox_os", "Gesamtüberleben")
cox_bm_meta = meta_cox("cox_bm", "Hirnmetastasen")
cox_meta_tab = rbind(cox_os_meta, cox_bm_meta)

cat("\nCox Meta-Analyse Ergebnisse:\n")
print(cox_meta_tab)
fwrite(cox_meta_tab, "MULTI_Cox_Meta_Ergebnisse.csv", sep = ";", bom = TRUE)

# Forest-Plot: Subtyp-HRs für Gesamtüberleben
if (!is.null(cox_os_meta) && nrow(cox_os_meta) > 0 && "variable" %in% names(cox_os_meta)) {
  fp_dat = cox_os_meta[grepl("subtyp", variable)]
  if (nrow(fp_dat) > 0) {
    fp_dat[, variable  := sub("subtyp", "", variable)]
    fp_dat[, variable  := factor(variable, levels = rev(unique(variable)))]
    fp_dat[, I2_label  := ifelse(is.na(I2), "—", paste0("I²=", I2, "%"))]

    p_forest = ggplot(fp_dat, aes(y = variable, x = HR, xmin = HR_lower, xmax = HR_upper)) +
      geom_vline(xintercept = 1, linetype = "dashed", color = hh_dunkelgrau, linewidth = 0.6) +
      geom_errorbarh(height = 0.25, color = hh_dunkelblau, linewidth = 0.7) +
      geom_point(size = 3.5, color = hh_blau, shape = 18) +
      geom_text(aes(label = sprintf("%.2f [%.2f–%.2f]", HR, HR_lower, HR_upper)),
                hjust = -0.12, size = 3.2, color = "#333333") +
      geom_text(aes(x = max(HR_upper) * 1.6, y = variable, label = I2_label),
                hjust = 1, size = 3.0, color = hh_dunkelgrau) +
      scale_x_continuous(
        trans  = "log",
        breaks = c(0.5, 1, 2, 4, 8),
        limits = c(0.3, max(fp_dat$HR_upper) * 2.2),
        name   = "Hazard Ratio (95%-KI) — log-Skala"
      ) +
      labs(
        title    = "Two-Stage Meta-Analyse: Gesamtüberleben nach Subtyp",
        subtitle = paste0("Cox Proportional Hazards | Random Effects (REML) | ",
                          n_register, " Register\nReferenz: HR+/HER2-"),
        y        = NULL,
        caption  = "I² = Heterogenität zwischen Registern | HKR-KIKA Multi-Register"
      ) +
      theme_hkr() +
      theme(panel.grid.major.y = element_line(color = hh_grau, linewidth = 0.3))

    save_png(p_forest, "MULTI_Fig3_Forest_Cox_OS.png", breite = 10, hoehe = 5)
  } else {
    cat("Forest-Plot: Keine Subtyp-Variablen in Cox-Meta-Ergebnissen.\n")
  }
} else {
  cat("Forest-Plot: Cox-Meta-Analyse ohne auswertbares Ergebnis (ggf. zu wenige Register).\n")
}

# ============================================================
# ANALYSE D: POISSON-TRENDMODELL (Inzidenztrend nach Jahr)
# ============================================================
cat("\n--- Analyse D: Poisson-Trendmodell ---\n")

poisson_all = rbindlist(lapply(exporte, function(x) x$poisson_tab))
poisson_all = poisson_all[!is.na(n_bm) & py > 0]
poisson_all[, diagnosejahr_z := diagnosejahr - 2015]

poisson_all[, subtyp    := factor(subtyp,    levels = subtyp_levels)]
poisson_all[, alter_grp := factor(alter_grp, levels = ALTERS_LABELS)]
poisson_all[, register  := factor(register)]

tryCatch({
  if (n_register == 1) {
    # Einzelregister: Marginalmodell (summiere über Altersgruppen)
    # Hinweis: DSGVO-Suppression auf Zellebene kann bei wenig Registern zu artifiziellen
    # Nullzellen führen, daher Fallback auf deskriptive Darstellung.
    pois_marg = poisson_all[, .(
      n_bm = sum(n_bm, na.rm = TRUE),
      py   = sum(py,   na.rm = TRUE)
    ), by = .(subtyp, diagnosejahr_z)]
    pois_marg = pois_marg[py >= 0.5]  # mind. 6 Monate Exposition
    pois_marg = droplevels(pois_marg)

    # Stichprobe: Zeilen mit Ereignissen
    n_mit_ereignissen = sum(pois_marg$n_bm > 0)
    cat("Poisson-Daten: ", nrow(pois_marg), "Zellen, davon",
        n_mit_ereignissen, "mit n_bm > 0\n")

    xmat    = model.matrix(~ subtyp + diagnosejahr_z, data = pois_marg)
    glm_fit = glm(
      n_bm ~ subtyp + diagnosejahr_z,
      offset  = log(py),
      family  = poisson(link = "log"),
      data    = pois_marg,
      start   = rep(0, ncol(xmat)),
      control = glm.control(maxit = 500, epsilon = 1e-10)
    )
    glmm_coef = as.data.table(broom::tidy(glm_fit, conf.int = TRUE))
    glmm_coef[, IRR       := round(exp(estimate), 3)]
    glmm_coef[, IRR_lower := round(exp(conf.low),  3)]
    glmm_coef[, IRR_upper := round(exp(conf.high), 3)]

    cat("\nPoisson GLM (Einzelregister, Marginalmodell) — Inzidenz-Rate-Ratios:\n")
    print(glmm_coef[, .(term, IRR, IRR_lower, IRR_upper, p.value)])
    fwrite(glmm_coef, "MULTI_Poisson_GLMM_Ergebnisse.csv", sep = ";", bom = TRUE)

    pred_grid = CJ(
      subtyp         = factor(levels(pois_marg$subtyp)[1:4], levels = subtyp_levels),
      diagnosejahr_z = seq(JAHRE_VON - 2015, JAHRE_BIS - 2015),
      py             = 1000
    )
    pred_grid[, pred_rate := predict(glm_fit, newdata = pred_grid, type = "response")]
    pred_grid[, diagnosejahr := diagnosejahr_z + 2015]

    trend_subtitle = "Poisson GLM | Einzelregister | Marginale Rate pro 1.000 Patientenjahre"
    trend_caption  = "Modell: n_bm ~ subtyp + diagnosejahr | HKR-KIKA"

  } else {
    # Mehrere Register: Gemischtes Modell mit Register als Random Effect
    glmm_fit = glmer(
      n_bm ~ subtyp + alter_grp + diagnosejahr_z + (1 | register),
      offset   = log(py),
      family   = poisson(link = "log"),
      data     = poisson_all
    )
    glmm_coef = as.data.table(broom.mixed::tidy(glmm_fit, conf.int = TRUE))
    glmm_coef[, IRR       := round(exp(estimate), 3)]
    glmm_coef[, IRR_lower := round(exp(conf.low),  3)]
    glmm_coef[, IRR_upper := round(exp(conf.high), 3)]

    cat("\nPoisson GLMM — Inzidenz-Rate-Ratios:\n")
    print(glmm_coef[, .(term, IRR, IRR_lower, IRR_upper, p.value)])
    fwrite(glmm_coef, "MULTI_Poisson_GLMM_Ergebnisse.csv", sep = ";", bom = TRUE)

    pred_grid = CJ(
      subtyp         = factor(levels(poisson_all$subtyp)[1:4], levels = subtyp_levels),
      alter_grp      = factor("50-59", levels = ALTERS_LABELS),
      diagnosejahr_z = seq(JAHRE_VON - 2015, JAHRE_BIS - 2015),
      register       = levels(poisson_all$register)[1],
      py             = 100
    )
    pred_grid[, pred_rate := predict(glmm_fit, newdata = pred_grid,
                                     type = "response", re.form = NA) / 100 * 1000]
    pred_grid[, diagnosejahr := diagnosejahr_z + 2015]

    trend_subtitle = paste0("Poisson GLMM | Register als Random Effect | ",
                            n_register, " Register\nAltersgruppe 50–59 Jahre, Rate pro 1.000 Patientenjahre")
    trend_caption  = "Modell: n_bm ~ subtyp + alter_grp + diagnosejahr + (1|register) | HKR-KIKA"
  }

  p_trend = ggplot(pred_grid, aes(x = diagnosejahr, y = pred_rate, color = subtyp)) +
    geom_line(linewidth = 1) +
    scale_color_manual(values = subtyp_farben, name = "Molekularer Subtyp") +
    scale_x_continuous(breaks = seq(JAHRE_VON, JAHRE_BIS, 2)) +
    labs(
      title    = "Zeittrend der Hirnmetastasen-Rate nach Subtyp",
      subtitle = trend_subtitle,
      x        = "Diagnosejahr",
      y        = "Vorhergesagte BM-Rate (pro 1.000 PJ)",
      caption  = trend_caption
    ) +
    theme_hkr()

  save_png(p_trend, "MULTI_Fig4_Poisson_Trend.png", breite = 11, hoehe = 7)

}, error = function(e) {
  cat("Poisson-Modell nicht konvergiert:", conditionMessage(e), "\n")
  cat("  -> Fallback: beobachtete BM-Raten (kein Modell)\n")
  # Stub-CSV damit die Datei existiert
  fwrite(data.table(hinweis = "Poisson-Modell nicht konvergiert (zu wenige Ereignisse nach DSGVO-Suppression)"),
         "MULTI_Poisson_GLMM_Ergebnisse.csv", sep = ";", bom = TRUE)

  # Beobachtete Rate: Rohrate pro 1.000 Patientenjahre je Subtyp und Jahr
  pois_obs = poisson_all[, .(
    n_bm = sum(n_bm, na.rm = TRUE),
    py   = sum(py,   na.rm = TRUE)
  ), by = .(subtyp, diagnosejahr_z)]
  pois_obs = pois_obs[py >= 1]
  pois_obs[, rate         := n_bm / py * 1000]
  pois_obs[, diagnosejahr := diagnosejahr_z + 2015]
  pois_obs[, subtyp       := factor(subtyp, levels = subtyp_levels)]

  p_trend = ggplot(pois_obs[subtyp != "Unbekannt"],
                   aes(x = diagnosejahr, y = rate, color = subtyp)) +
    geom_point(alpha = 0.6, size = 2.5) +
    geom_smooth(method = "loess", se = FALSE, linewidth = 0.9, span = 0.8) +
    scale_color_manual(values = subtyp_farben, name = "Molekularer Subtyp") +
    scale_x_continuous(breaks = seq(JAHRE_VON, JAHRE_BIS, 2)) +
    labs(
      title    = "Zeittrend der Hirnmetastasen-Rate nach Subtyp",
      subtitle = paste0("Beobachtete Rohraten (Loess-Glättung) | ",
                        n_register, " Register | Aggregiert über Altersgruppen"),
      x        = "Diagnosejahr",
      y        = "BM-Rate (pro 1.000 Patientenjahre)",
      caption  = "Hinweis: DSGVO-Suppression kann Nullzellen erzeugen — Werte < 5 Ereignisse supprimiert | HKR-KIKA"
    ) +
    theme_hkr()

  save_png(p_trend, "MULTI_Fig4_Poisson_Trend.png", breite = 11, hoehe = 7)
})

# ============================================================
# ANALYSE E (optional): BAYESIANISCHE GLÄTTUNG MIT INLA
# ============================================================
if (inla_verfuegbar) {
  cat("\n--- Analyse E: Bayesianische Glättung (INLA) ---\n")
  library(INLA)

  # Aggregiere über Register: Gesamtcounts + PY nach Altersgruppe × Jahr
  inla_dat = poisson_all[, .(
    n_bm = sum(n_bm, na.rm = TRUE),
    py   = sum(py,   na.rm = TRUE)
  ), by = .(subtyp, alter_grp, diagnosejahr)]

  inla_dat = inla_dat[n_bm >= DSGVO_MINZAHL & py > 0]
  inla_dat[, jahr_idx  := as.integer(factor(diagnosejahr))]
  inla_dat[, alter_idx := as.integer(alter_grp)]

  # BYM2-ähnliches Modell: RW1 über Diagnosejahr, iid über Altersgruppe
  inla_formel = n_bm ~ subtyp +
    f(jahr_idx,  model = "rw1",  scale.model = TRUE) +
    f(alter_idx, model = "iid")

  inla_fit = inla(
    inla_formel,
    family   = "poisson",
    data     = inla_dat,
    offset   = log(inla_dat$py),
    control.compute = list(dic = TRUE, waic = TRUE)
  )

  # Geglätteter Zeittrend (Marginals des RW1-Effekts)
  rw1_mean = inla_fit$summary.random$jahr_idx
  jahre_seq = sort(unique(inla_dat$diagnosejahr))
  rw1_tab = data.table(
    diagnosejahr = jahre_seq[seq_len(nrow(rw1_mean))],
    mean  = rw1_mean$mean,
    lower = rw1_mean$`0.025quant`,
    upper = rw1_mean$`0.975quant`
  )

  p_inla = ggplot(rw1_tab, aes(x = diagnosejahr, y = exp(mean))) +
    geom_ribbon(aes(ymin = exp(lower), ymax = exp(upper)),
                fill = hh_blau, alpha = 0.25) +
    geom_line(color = hh_blau, linewidth = 1.1) +
    geom_hline(yintercept = 1, linetype = "dashed",
               color = hh_dunkelgrau, linewidth = 0.5) +
    scale_x_continuous(breaks = seq(JAHRE_VON, JAHRE_BIS, 2)) +
    labs(
      title    = "Bayesianisch geglätteter Zeittrend: Hirnmetastasen-Rate",
      subtitle = paste0("INLA RW1-Modell | Gesamter Zeittrend (alle Subtypen)\n",
                        n_register, " Register | ", formatC(sum(inla_dat$n_bm), format = "d", big.mark = "."),
                        " BM-Ereignisse (INLA)"),
      x        = "Diagnosejahr",
      y        = "Relatives Risiko (vs. Gesamtmittel)",
      caption  = "Schraffierter Bereich: 95%-Kredibilitätsintervall | HKR-KIKA Multi-Register"
    ) +
    theme_hkr()

  save_png(p_inla, "MULTI_Fig5_INLA_Trend.png", breite = 10, hoehe = 6)
  cat("INLA-Analyse abgeschlossen. DIC:", round(inla_fit$dic$dic, 1), "\n")

} else {
  cat("Analyse E übersprungen (INLA nicht verfügbar).\n")
}

# ============================================================
# DESKRIPTIVE ZUSAMMENFASSUNG ALLER REGISTER
# ============================================================
cat("\n--- Deskriptive Zusammenfassung ---\n")

desk_all = rbindlist(lapply(exporte, function(x) x$deskriptiv))
desk_all[, subtyp := factor(subtyp, levels = subtyp_levels)]

desk_gesamt = desk_all[, .(
  n_gesamt     = sum(n_gesamt,     na.rm = TRUE),
  n_bm         = sum(n_bm,         na.rm = TRUE),
  n_verstorben = sum(n_verstorben, na.rm = TRUE)
), by = subtyp]
desk_gesamt[, bm_rate    := round(100 * n_bm / n_gesamt, 1)]
desk_gesamt[, mort_rate  := round(100 * n_verstorben / n_gesamt, 1)]
desk_gesamt[, n_register := n_register]

# DSGVO: Im zentralen Ergebnis können auch gepoolte Zellen < 5 entstehen
desk_gesamt[n_bm < DSGVO_MINZAHL, `:=`(n_bm = NA_integer_, bm_rate = NA_real_)]

cat("\nGepoolte Deskriptivstatistik:\n")
print(desk_gesamt)
fwrite(desk_gesamt, "MULTI_Deskriptiv_Gesamt.csv", sep = ";", bom = TRUE)

# ============================================================
# KONSOLENZUSAMMENFASSUNG
# ============================================================
cat("\n========== ZENTRALE ANALYSE ABGESCHLOSSEN ==========\n")
cat("Register analysiert:", n_register, "\n")
cat("N gesamt (alle Register):", suppressWarnings(suppressWarnings(formatC(n_gesamt, format = "d", big.mark = "."))), "\n")
cat("\nGespeicherte Dateien:\n")
cat("  MULTI_Fig1_KM_OS_gepoolte.png\n")
cat("  MULTI_Fig2_CumInc_BM_gepoolte.png\n")
cat("  MULTI_Fig3_Forest_Cox_OS.png\n")
cat("  MULTI_Fig4_Poisson_Trend.png\n")
if (inla_verfuegbar) cat("  MULTI_Fig5_INLA_Trend.png\n")
cat("  MULTI_Cox_Meta_Ergebnisse.csv\n")
cat("  MULTI_Poisson_GLMM_Ergebnisse.csv\n")
cat("  MULTI_Deskriptiv_Gesamt.csv\n")
cat("=====================================================\n")
