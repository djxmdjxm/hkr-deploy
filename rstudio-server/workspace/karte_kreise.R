# ============================================================
# KIKA – Deutschlandkarte auf Kreisebene
# Source ausfuehren: Strg+Shift+S  oder  Source-Button oben rechts
# ============================================================

library(DBI)
library(RPostgres)
library(dplyr)
library(sf)
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

tumoren   <- dbReadTable(con, "tumor_report")
patienten <- dbReadTable(con, "patient_report")
dbDisconnect(con)

# --- Shapefile laden ---
gpkg_path <- list.files(
  "/home/rstudio/referenz/shapefiles",
  pattern = "\\.gpkg$",
  full.names = TRUE
)[1]

kreise <- st_read(gpkg_path, layer = "vg250_krs", quiet = TRUE) |>
  st_transform(4326) |>
  select(AGS, GEN, geometry)

# --- Faelle pro Kreis zaehlen ---
# Wohnort-AGS aus patient_report (JSON-Feld "residence")
extract_ags <- function(x) {
  tryCatch({
    obj <- fromJSON(x)
    ags <- obj$ags %||% obj$AGS %||% obj$gemeinde_ags %||% NA_character_
    if (is.null(ags)) NA_character_ else as.character(ags)
  }, error = function(e) NA_character_)
}

# Null-coalescing helper
`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0 && !is.na(a[1])) a else b

ags_vec <- sapply(patienten$address, extract_ags)

faelle_kreis <- data.frame(
  AGS = substr(ags_vec, 1, 5)  # erste 5 Stellen = Kreisschluessel
) |>
  filter(!is.na(AGS), nchar(AGS) == 5) |>
  count(AGS, name = "faelle")

# --- Join mit Shapefile ---
karte_df <- kreise |>
  left_join(faelle_kreis, by = "AGS") |>
  mutate(faelle = replace(faelle, is.na(faelle), 0))

# --- Bevölkerungsdaten einlesen (falls vorhanden) ---
bev_path <- "/home/rstudio/referenz/bevoelkerung/bevoelkerung_kreise.csv"
if (file.exists(bev_path)) {
  bev <- read.csv(bev_path, colClasses = c(AGS = "character")) |>
    select(AGS, bevoelkerung)
  karte_df <- karte_df |>
    left_join(bev, by = "AGS") |>
    mutate(
      rate_100k = ifelse(!is.na(bevoelkerung) & bevoelkerung > 0,
                         faelle / bevoelkerung * 100000, NA_real_)
    )
  cat("Bevölkerungsdaten geladen — Karte zeigt Inzidenz pro 100.000 Einwohner\n")
  fill_var  <- "rate_100k"
  fill_lab  <- "Faelle\npro 100.000 EW"
} else {
  cat("Keine Bevölkerungsdaten gefunden — Karte zeigt absolute Fallzahlen\n")
  fill_var  <- "faelle"
  fill_lab  <- "Faelle\n(absolut)"
}

# --- Karte zeichnen ---
ggplot(karte_df) +
  geom_sf(aes(fill = .data[[fill_var]]), color = "white", linewidth = 0.1) +
  scale_fill_gradient(
    low      = "#cce0ff",
    high     = "#003063",
    na.value = "#e0e0e0",
    name     = fill_lab
  ) +
  labs(
    title    = "Krebsfaelle nach Kreisen",
    subtitle = "Quelle: Hamburgisches Krebsregister",
    caption  = "BKG VG250 | Darstellung: KIKA"
  ) +
  theme_void() +
  theme(
    plot.title    = element_text(face = "bold", size = 14, color = "#003063"),
    plot.subtitle = element_text(size = 10, color = "#555555"),
    plot.caption  = element_text(size = 7, color = "#888888"),
    legend.position = "right"
  )
