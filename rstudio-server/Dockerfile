FROM rocker/rstudio:4.4

# System-Abhaengigkeiten fuer:
#  - sf, s2 (Shapefiles, Geo)
#  - officer/flextable (Word/PowerPoint Output via libxml2/libssl)
#  - DB (libpq)
#  - Schriften (Cairo/Pango fuer hochqualitatives ggplot)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgdal-dev libgeos-dev libproj-dev libudunits2-dev \
    libabsl-dev cmake \
    libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
    libuv1-dev \
    libpq-dev libssl-dev \
    libxml2-dev libcairo2-dev libpango1.0-dev \
    curl unzip \
    && rm -rf /var/lib/apt/lists/*

# Cache-Busting: Datum hochzaehlen wenn Pakete hinzukommen -> erzwingt Neuinstallation.
# Stand: 2026-05-04 -- Standardbibliothek erweitert um Survival/Reporting-Pakete
ENV R_PACKAGES_VERSION=2026-05-04

# R-Pakete installieren (einmalig beim Build -- kein Internet zur Laufzeit noetig).
# dependencies=c(...) vermeidet optionale Pakete mit komplexen Build-Anforderungen.
# Liste ist gegliedert: Daten/DB, Tidyverse, Geo, IO/Reporting, Statistik, Survival.
# Aenderungen bitte zusaetzlich in R_PACKAGES.md dokumentieren.
RUN R -q -e 'install.packages(c(\
    "DBI", "RPostgres", "jsonlite", \
    "dplyr", "tidyr", "lubridate", \
    "data.table", \
    "ggplot2", "scales", "RColorBrewer", \
    "s2", "sf", \
    "readxl", "writexl", "openxlsx", \
    "flextable", "officer", \
    "tableone", "epitools", "gtsummary", "broom", \
    "sandwich", "lmtest", \
    "survival", "survminer", \
    "forestplot", "meta", \
    "mgcv" \
), repos="https://cloud.r-project.org", dependencies=c("Depends","Imports","LinkingTo"))'

# Build-Validation: jedes Paket muss ladbar sein, sonst schlaegt der Build fehl.
# Verhindert silent install-Failures wie sie beim ersten s2-Build passierten.
RUN R -q -e 'pkgs <- c( \
    "DBI","RPostgres","jsonlite", \
    "dplyr","tidyr","lubridate", \
    "data.table", \
    "ggplot2","scales","RColorBrewer", \
    "s2","sf", \
    "readxl","writexl","openxlsx", \
    "flextable","officer", \
    "tableone","epitools","gtsummary","broom", \
    "sandwich","lmtest", \
    "survival","survminer", \
    "forestplot","meta", \
    "mgcv" \
  ); \
  missing <- pkgs[!sapply(pkgs, function(p) requireNamespace(p, quietly=TRUE))]; \
  if (length(missing) > 0) { \
    cat("\n*** BUILD ABORT: missing R packages:", paste(missing, collapse=", "), "\n\n"); \
    quit(status=1) \
  } else { \
    cat("\nAll", length(pkgs), "R packages OK.\n") \
  }'

# BKG VG250 Kreise herunterladen (GeoPackage, freie Open-Data-Lizenz)
RUN mkdir -p /home/rstudio/referenz/shapefiles && \
    curl -fsSL \
    "https://daten.gdz.bkg.bund.de/produkte/vg/vg250_ebenen_0101/aktuell/vg250_01-01.utm32s.gpkg.ebenen.zip" \
    -o /tmp/vg250.zip && \
    unzip -o /tmp/vg250.zip -d /tmp/vg250/ && \
    find /tmp/vg250 -name "*.gpkg" -exec cp {} /home/rstudio/referenz/shapefiles/ \; && \
    rm -rf /tmp/vg250 /tmp/vg250.zip && \
    chown -R rstudio:rstudio /home/rstudio/referenz/

# Workspace-Dateien kopieren
COPY --chown=rstudio:rstudio workspace/ /home/rstudio/

# RStudio ohne Passwort starten
ENV DISABLE_AUTH=true

EXPOSE 8787
