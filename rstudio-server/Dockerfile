FROM rocker/rstudio:4.4

# System-Abhaengigkeiten fuer sf (Shapefiles) und Datenbank
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgdal-dev libgeos-dev libproj-dev libudunits2-dev \
    libpq-dev libssl-dev \
    curl unzip \
    && rm -rf /var/lib/apt/lists/*

# R-Pakete installieren (einmalig beim Build -- kein Internet zur Laufzeit noetig)
RUN R -q -e 'install.packages(c(\
    "DBI", "RPostgres", "jsonlite", \
    "dplyr", "tidyr", "lubridate", \
    "ggplot2", "scales", "RColorBrewer", \
    "sf", "tmap", \
    "data.table", "readxl", "writexl", \
    "tableone", "epitools", \
    "sandwich", "lmtest" \
), repos="https://cloud.r-project.org")'

# BKG VG250 Kreise herunterladen (GeoPackage, freie Open-Data-Lizenz)
RUN mkdir -p /home/rstudio/referenz/shapefiles && \
    curl -fsSL \
    "https://daten.gdz.bkg.bund.de/produkte/vg/vg250_ebenen_0101/aktuell/vg250_01-01.utm32s.gpkg.zip" \
    -o /tmp/vg250.zip && \
    unzip -o /tmp/vg250.zip -d /tmp/vg250/ && \
    cp /tmp/vg250/*.gpkg /home/rstudio/referenz/shapefiles/ && \
    rm -rf /tmp/vg250 /tmp/vg250.zip && \
    chown -R rstudio:rstudio /home/rstudio/referenz/

# Workspace-Dateien kopieren
COPY --chown=rstudio:rstudio workspace/ /home/rstudio/

# RStudio ohne Passwort starten
ENV DISABLE_AUTH=true

EXPOSE 8787
