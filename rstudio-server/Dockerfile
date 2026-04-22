FROM rocker/rstudio:4.4

# System-Abhaengigkeiten fuer sf (Shapefiles), s2 und Datenbank
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgdal-dev libgeos-dev libproj-dev libudunits2-dev \
    libabsl-dev cmake \
    libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
    libuv1-dev \
    libpq-dev libssl-dev \
    curl unzip \
    && rm -rf /var/lib/apt/lists/*

# Cache-Busting: Wert aendern wenn Pakete hinzukommen → erzwingt Neuinstallation
ENV R_PACKAGES_VERSION=2026-04-22

# R-Pakete installieren (einmalig beim Build -- kein Internet zur Laufzeit noetig)
# dependencies=c(...) vermeidet optionale Pakete mit komplexen Build-Anforderungen
RUN R -q -e 'install.packages(c(\
    "DBI", "RPostgres", "jsonlite", \
    "dplyr", "tidyr", "lubridate", \
    "ggplot2", "scales", "RColorBrewer", \
    "s2", "sf", \
    "data.table", "readxl", "writexl", "openxlsx", \
    "tableone", "epitools", \
    "sandwich", "lmtest" \
), repos="https://cloud.r-project.org", dependencies=c("Depends","Imports","LinkingTo"))'

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
