# =============================================================================
# KIKA – Federated Multi-Register-Analyse: C50 Hirnmetastasen
# 00_config.R — Gemeinsame Konfiguration für alle Register-Skripte
#
# Dieses Skript wird sowohl vom lokalen Export-Skript (01_lokal_export.R)
# als auch vom zentralen Meta-Analyse-Skript (02_zentral_meta.R) gesourct.
# Alle Definitionen hier müssen in allen Registern identisch sein.
# =============================================================================

# ============================================================
# HAMBURG CORPORATE DESIGN
# ============================================================
hh_blau       = "#005CA9"
hh_rot        = "#E10019"
hh_dunkelblau = "#003063"
hh_grau       = "#E3E3E3"
hh_dunkelgrau = "#757575"

subtyp_farben = c(
  "HR+/HER2-"  = hh_blau,
  "HER2+/HR+"  = "#4CAF50",
  "HER2+/HR-"  = hh_rot,
  "TNBC"       = "#FF9800",
  "Unbekannt"  = hh_dunkelgrau
)
subtyp_levels = c("HR+/HER2-", "HER2+/HR+", "HER2+/HR-", "TNBC", "Unbekannt")

# ============================================================
# ANALYSEPARAMETER
# ============================================================
MAX_FU_TAGE   = 1827   # 60 Monate (5-Jahres-Konvention HKR)
MAX_FU_MO     = 60
DSGVO_MINZAHL = 5      # Zellen mit N < 5 werden supprimiert

# Altersgruppen für Poisson-Modell
ALTERS_BREAKS = c(0, 40, 50, 60, 70, 80, Inf)
ALTERS_LABELS = c("<40", "40-49", "50-59", "60-69", "70-79", ">=80")

# Diagnosejahre die im zentralen Modell berücksichtigt werden
JAHRE_VON = 2010
JAHRE_BIS = 2024

# Cox-Formel (identisch in allen Registern — Voraussetzung für Two-Stage)
# Referenzkategorie: HR+/HER2-, Altersgruppe 50-59, Diagnosejahr 2015
COX_OS_FORMEL   = "Surv(fu_os_mo,  status_os)  ~ subtyp + alter_grp + I(diagnosejahr - 2015)"
COX_BM_FORMEL   = "Surv(t_cif_mo,  event_bm1)  ~ subtyp + alter_grp + I(diagnosejahr - 2015)"

# ============================================================
# GEMEINSAMES GGPLOT-THEME
# ============================================================
theme_hkr = function(base_size = 13) {
  theme_classic(base_size = base_size) %+replace%
    theme(
      plot.title         = element_text(color = hh_dunkelblau, face = "bold",
                                        size = base_size + 1, hjust = 0),
      plot.subtitle      = element_text(color = hh_dunkelgrau, size = base_size - 1,
                                        hjust = 0, margin = margin(b = 8)),
      plot.caption       = element_text(color = "#A0A0A0", size = 8, hjust = 1),
      axis.title         = element_text(color = hh_dunkelblau, size = base_size - 1),
      axis.text          = element_text(color = "#333333"),
      legend.title       = element_text(color = hh_dunkelblau, face = "bold",
                                        size = base_size - 1),
      legend.text        = element_text(size = base_size - 2),
      legend.position    = "right",
      panel.grid.major.y = element_line(color = hh_grau, linewidth = 0.4),
      panel.grid.major.x = element_blank(),
      strip.background   = element_rect(fill = hh_grau, color = NA),
      strip.text         = element_text(color = hh_dunkelblau, face = "bold"),
      plot.margin        = margin(12, 16, 10, 12)
    )
}

save_png = function(plot, dateiname, breite = 10, hoehe = 7) {
  ggsave(dateiname, plot, width = breite, height = hoehe, dpi = 300, bg = "white")
  cat("Gespeichert:", dateiname, "\n")
}
