# ============================================================
# KIKA – Erste Datenexploration
# Source ausfuehren: Strg+Shift+S  oder  Source-Button oben rechts
# ============================================================

library(DBI)
library(RPostgres)
library(dplyr)
library(ggplot2)
library(jsonlite)

# --- Verbindung zur Datenbank ---
con <- dbConnect(
  RPostgres::Postgres(),
  host     = "central-db",
  port     = 5432,
  dbname   = "krebs",
  user     = "postgres",
  password = "1234"
)

patienten <- dbReadTable(con, "patient_report")
tumoren   <- dbReadTable(con, "tumor_report")
dbDisconnect(con)

# ============================================================
# 1. FALLZAHLEN
# ============================================================
cat("=== Fallzahlen ===\n")
cat("Patienten gesamt:  ", nrow(patienten), "\n")
cat("Tumorfaelle gesamt:", nrow(tumoren),   "\n\n")

# ============================================================
# 2. ICD-CODES
# ============================================================
cat("=== ICD-Codes (haeufigste Diagnosen) ===\n")
icd_codes   <- sapply(tumoren$icd, \(x) fromJSON(x)$code)
icd_tabelle <- sort(table(icd_codes), decreasing = TRUE)
print(head(icd_tabelle, 20))

# ============================================================
# 3. ALTERSVERTEILUNG
# ============================================================
df <- tumoren |>
  select(patient_report_id, diagnosis_date) |>
  left_join(
    patienten |> select(id, date_of_birth),
    by = c("patient_report_id" = "id")
  ) |>
  mutate(
    alter = as.numeric(as.Date(diagnosis_date) - as.Date(date_of_birth)) / 365.25
  ) |>
  filter(!is.na(alter))

cat("\n=== Altersverteilung bei Erstdiagnose ===\n")
cat("Median:", round(median(df$alter), 1), "Jahre\n")
cat("Mittel:", round(mean(df$alter),   1), "Jahre\n")
cat("Min:   ", round(min(df$alter),    1), "Jahre\n")
cat("Max:   ", round(max(df$alter),    1), "Jahre\n")

ggplot(df, aes(x = alter)) +
  geom_histogram(binwidth = 5, fill = "#003063", color = "white") +
  labs(
    title = "Altersverteilung bei Erstdiagnose",
    x     = "Alter (Jahre)",
    y     = "Anzahl Faelle"
  ) +
  theme_minimal()
