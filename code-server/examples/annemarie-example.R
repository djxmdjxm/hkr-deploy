# Sauberes, funktionierendes Analyse-Skript
# RT-nach-BET Analyse-Skript für neue CSV-Struktur
# Angepasst von ursprünglichem C50-Analyse-Skript
# Berechnet Radiotherapie-Raten nach brusterhaltender Therapie (BET)

# Arbeitsspeicher leeren
rm(list=ls())

# Plots schließen
graphics.off()

# Pakete laden
library(data.table)
library(readxl)
library(tableone)
library(splines)
library(ggplot2)
library(writexl)
library(sandwich)
library(lmtest)
library(jsonlite)
library(DBI)
library(RPostgres)

# Helpers --------------------------------------------------------------

.pg_get <- function(var, default = NULL) {
  val <- Sys.getenv(var, unset = "")
  if (nzchar(val)) {
    val
  } else {
    default
  }
}

extract_icd_code <- function(value) {
  if (is.null(value) || (length(value) == 1 && is.na(value))) {
    return(NA_character_)
  }

  # If we already have a list/data.frame, inspect for a `code` element
  if (is.list(value)) {
    if (!is.null(value$code)) {
      return(as.character(value$code))
    }
    # Sometimes dbReadTable returns a list of lists for JSON arrays
    flat <- unlist(lapply(value, function(item) {
      if (is.list(item) && !is.null(item$code)) {
        return(item$code)
      }
      if (is.character(item)) {
        return(item)
      }
      NA_character_
    }), use.names = FALSE)
    flat <- flat[!is.na(flat)]
    if (length(flat) > 0) {
      return(as.character(flat[1]))
    }
  }

  if (is.character(value)) {
    trimmed <- trimws(value[1])
    if (!nzchar(trimmed)) {
      return(NA_character_)
    }
    if (startsWith(trimmed, "{") || startsWith(trimmed, "[")) {
      parsed <- try(fromJSON(trimmed, simplifyVector = FALSE), silent = TRUE)
      if (!inherits(parsed, "try-error")) {
        return(extract_icd_code(parsed))
      }
    }
    return(trimmed)
  }

  if (is.atomic(value)) {
    return(as.character(value[1]))
  }

  NA_character_
}

parse_ops_codes <- function(raw_ops) {
  if (is.null(raw_ops) || length(raw_ops) == 0) {
    return(character(0))
  }

  if (is.list(raw_ops) && !is.data.frame(raw_ops)) {
    flat <- unlist(lapply(raw_ops, parse_ops_codes), use.names = FALSE)
    flat <- flat[!is.na(flat)]
    return(unique(as.character(flat)))
  }

  if (is.data.frame(raw_ops)) {
    if (!is.null(raw_ops$code)) {
      return(as.character(raw_ops$code))
    }
    flat <- unlist(lapply(raw_ops, parse_ops_codes), use.names = FALSE)
    flat <- flat[!is.na(flat)]
    return(unique(as.character(flat)))
  }

  if (is.character(raw_ops)) {
    trimmed <- trimws(raw_ops[1])
    if (!nzchar(trimmed)) {
      return(character(0))
    }
    if (startsWith(trimmed, "{") || startsWith(trimmed, "[")) {
      parsed <- try(fromJSON(trimmed, simplifyVector = FALSE), silent = TRUE)
      if (!inherits(parsed, "try-error")) {
        return(parse_ops_codes(parsed))
      }
    }
    return(trimmed)
  }

  character(0)
}

# Arbeitsverzeichnis festlegen - anpassen an Ihren Pfad
# setwd(".")

cat("=== RT-NACH-BET ANALYSE MIT NEUER DB-STRUKTUR ===\n\n")

# ---- DB: Verbindung & Tabelleneinlese ----

pg_host <- .pg_get("PGHOST", "central-db")
pg_port <- as.integer(.pg_get("PGPORT", "5432"))
pg_db   <- .pg_get("PGDATABASE", "krebs")
pg_user <- .pg_get("PGUSER", "postgres")
pg_pwd  <- .pg_get("PGPASSWORD", "1234")
pg_schema <- .pg_get("PGSCHEMA", "public")

cat("1. Stelle Verbindung zu PostgreSQL her...\n")
con <- tryCatch(
  dbConnect(
    RPostgres::Postgres(),
    host = pg_host, port = pg_port,
    dbname = pg_db, user = pg_user, password = pg_pwd
  ),
  error = function(e) {
    stop(sprintf("FEHLER: Konnte keine DB-Verbindung herstellen (%s)", e$message))
  }
)

# Helper: read a table as data.table safely
read_tbl <- function(tbl_name, schema = pg_schema) {
  # schema-qualified identifier (defaults to configured schema)
  if (!is.null(schema) && nzchar(schema)) {
    id <- Id(schema = schema, table = tbl_name)
  } else {
    id <- Id(table = tbl_name)
  }
  if (!dbExistsTable(con, id)) {
    stop(sprintf("FEHLER: Tabelle '%s' nicht gefunden.", tbl_name))
  }
  # Use dbReadTable for simple * and convert to data.table
  dt <- as.data.table(dbReadTable(con, id))
  # Convert typical date/datetime columns if they came as character
  date_cols <- grep("(date$|_date$|^date_)", names(dt), ignore.case = TRUE, value = TRUE)
  for (cn in date_cols) {
    # only coerce character to Date; leave POSIXct to user if needed
    if (is.character(dt[[cn]]) && !any(grepl("T|:", dt[[cn]]))) {
      suppressWarnings(dt[, (cn) := as.Date(get(cn))])
    }
  }
  dt
}

cat("1a. Lese Tabellen aus Schema '", pg_schema, "'...\n", sep = "")
tryCatch({
  patient_report          <- read_tbl("patient_report")
  tumor_report            <- read_tbl("tumor_report")
  tumor_surgery           <- read_tbl("tumor_surgery")
  tumor_radiotherapy      <- read_tbl("tumor_radiotherapy")
  tumor_systemic_therapy  <- read_tbl("tumor_systemic_therapy")
  tumor_histology         <- read_tbl("tumor_histology")
  tnm_data                <- read_tbl("tnm")
  cat("Alle Tabellen erfolgreich geladen\n")
}, error = function(e) {
  # Cleanly close connection before aborting
  try(dbDisconnect(con), silent = TRUE)
  stop(e)
})

# IMPORTANT: Disconnect at the very end of your script
.on.exit_disconnect <- local({
  con_local <- con
  reg.finalizer(environment(), function(...) try(dbDisconnect(con_local), silent = TRUE), onexit = TRUE)
  NULL
})

# Schritt 2: C50-Fälle filtern (Mammakarzinom)
cat("\n2. Filtere C50-Fälle (Mammakarzinom)...\n")
# JSON-Spalte `icd` enthält Typ/Code – extrahiere den Code zur Filterung
tumor_report[, icd_code := vapply(icd, extract_icd_code, character(1), USE.NAMES = FALSE)]
c50_cases <- tumor_report[!is.na(icd_code) & grepl("^C50\\.[0-6]", icd_code)]
cat("C50-Fälle gefunden:", nrow(c50_cases), "\n")

if(nrow(c50_cases) == 0) {
  cat("KEINE C50-Fälle gefunden. Analyse beendet.\n")
  quit()
}

# Schritt 3: Patientendaten hinzufügen und Alter berechnen
cat("\n3. Füge Patientendaten hinzu...\n")
patients_subset <- patient_report[id %in% c50_cases$patient_report_id]
setnames(patients_subset, "id", "patient_report_id")
cohort <- merge(
  c50_cases,
  patients_subset,
  by = "patient_report_id",
  all.x = TRUE,
  suffixes = c("", "_patient")
)

# Echte Altersberechnung aus Geburtsdatum
cohort[, diagnosis_date := as.Date(diagnosis_date)]
cohort[, date_of_birth := as.Date(date_of_birth)]
cohort[, diagnosealter := as.numeric(difftime(diagnosis_date, date_of_birth, units = "days")) / 365.25]
cohort[, diagnosejahr := as.integer(format(diagnosis_date, "%Y"))]

cat("Kohorte nach Patientenverknüpfung:", nrow(cohort), "Fälle\n")

# Schritt 4: OPS-Code-Analyse für BET (brusterhaltende Therapie)
cat("\n4. Analysiere Operationen (BET/Mastektomie)...\n")
ops <- tumor_surgery[tumor_report_id %in% cohort$id]
cat("OP-Einträge gefunden:", nrow(ops), "\n")

if(nrow(ops) > 0) {
  # Debugging: OPS-Codes anschauen
  cat("Beispiel OPS-Codes:\n")
  ops[, operations_list := lapply(operations, parse_ops_codes)]
  ops[, operations_text := vapply(
    operations_list,
    function(codes) if (length(codes) == 0) "" else paste(codes, collapse = "; "),
    character(1)
  )]
  print(head(ops$operations_text, 3))

  # BET-Suche (5-870: brusterhaltende Eingriffe)
  ops[, is_bet := grepl("5-870", operations_text, ignore.case = TRUE)]

  # Mastektomie-Suche (5-877, 5-872, 5-874)
  ops[, is_mast := grepl("5-877|5-872|5-874", operations_text, ignore.case = TRUE)]
  
  cat("BET-Operationen gefunden:", sum(ops$is_bet), "\n")
  cat("Mastektomie-Operationen gefunden:", sum(ops$is_mast), "\n")
  
  if(sum(ops$is_bet) > 0) {
    bet_ops <- ops[is_bet == TRUE]
    bet_tumors <- unique(bet_ops$tumor_report_id)
    cohort_bet <- cohort[id %in% bet_tumors]
    cat("BET-Kohorte:", nrow(cohort_bet), "Fälle\n")
  } else {
    cat("Keine BET-Fälle gefunden - verwende alle C50-Fälle für Demo\n")
    cohort_bet <- cohort
  }
} else {
  cat("Keine OP-Daten - verwende alle C50-Fälle\n")
  cohort_bet <- cohort
}

# Schritt 5: Bestrahlung hinzufügen (RT nach BET)
cat("\n5. Analysiere Bestrahlung nach BET...\n")
rt_data <- tumor_radiotherapy[tumor_report_id %in% cohort_bet$id]
cat("RT-Einträge gefunden:", nrow(rt_data), "\n")

if(nrow(rt_data) > 0) {
  rt_tumors <- unique(rt_data$tumor_report_id)
  cohort_bet[, rt := ifelse(id %in% rt_tumors, 1, 0)]
} else {
  cohort_bet[, rt := 0]
}

rt_rate <- round(sum(cohort_bet$rt) / nrow(cohort_bet) * 100, 1)
cat("RT-Rate nach BET:", rt_rate, "% (", sum(cohort_bet$rt), "/", nrow(cohort_bet), ")\n")

# Schritt 6: Systemtherapie hinzufügen
cat("\n6. Analysiere Systemtherapie...\n")
syst_data <- tumor_systemic_therapy[tumor_report_id %in% cohort_bet$id]
cat("Systemtherapie-Einträge gefunden:", nrow(syst_data), "\n")

if(nrow(syst_data) > 0) {
  syst_tumors <- unique(syst_data$tumor_report_id)
  cohort_bet[, syst := ifelse(id %in% syst_tumors, 1, 0)]
} else {
  cohort_bet[, syst := 0]
}

syst_rate <- round(sum(cohort_bet$syst) / nrow(cohort_bet) * 100, 1)
cat("Systemtherapie-Rate:", syst_rate, "% (", sum(cohort_bet$syst), "/", nrow(cohort_bet), ")\n")

# Schritt 7: Histologie hinzufügen
cat("\n7. Füge Histologie hinzu...\n")
hist_data <- tumor_histology[tumor_report_id %in% cohort_bet$id]
if(nrow(hist_data) > 0) {
  cohort_bet <- merge(
    cohort_bet,
    hist_data,
    by.x = "id",
    by.y = "tumor_report_id",
    all.x = TRUE
  )
  
  # Grading vereinfachen
  cohort_bet[, grade_simple := "unbekannt"]
  cohort_bet[grading %in% c("1", "2", "L", "M"), grade_simple := "gut/maessig"]
  cohort_bet[grading %in% c("3", "4", "H"), grade_simple := "schlecht"]
  
  cat("Histologie-Daten verknüpft\n")
} else {
  cohort_bet[, grade_simple := "unbekannt"]
}

# Schritt 8: Altersgruppen erstellen
cohort_bet[, altersgruppe := cut(diagnosealter, 
                                 breaks = c(0, 49.99, 69.99, Inf), 
                                 labels = c("<50", "50-69", "70+"))]

# Schritt 9: Einfache Tabelle 1 (nur verfügbare Variablen)
cat("\n8. Erstelle Übersichtstabelle...\n")

# Nur Variablen verwenden, die definitiv existieren
basic_vars <- c("diagnosejahr", "altersgruppe", "rt", "syst")
if("grade_simple" %in% names(cohort_bet)) {
  basic_vars <- c(basic_vars, "grade_simple")
}

# Verfügbare Variablen prüfen
available_vars <- intersect(basic_vars, names(cohort_bet))
cat("Verfügbare Variablen für Tabelle:", paste(available_vars, collapse = ", "), "\n")

if(length(available_vars) > 0) {
  cat_vars <- available_vars[!available_vars %in% c("diagnosealter")]
  
  tryCatch({
    tab1 <- CreateTableOne(vars = available_vars, 
                           data = cohort_bet, 
                           factorVars = cat_vars,
                           includeNA = TRUE,
                           test = FALSE)
    
    # Tabelle ausgeben
    print(tab1)
    
    cat("\n=== ENDERGEBNISSE ===\n")
    cat("Alle C50-Fälle:", nrow(cohort), "\n")
    cat("BET-Kohorte (finale Analyse):", nrow(cohort_bet), "Fälle\n")
    cat("Mittleres Alter:", round(mean(cohort_bet$diagnosealter, na.rm = TRUE), 1), "Jahre\n")
    cat("RT-Rate nach BET:", rt_rate, "%\n")
    cat("Systemtherapie-Rate:", syst_rate, "%\n")
    
    if("grade_simple" %in% names(cohort_bet)) {
      cat("Grading-Verteilung:\n")
      print(table(cohort_bet$grade_simple, useNA = "always"))
    }
    
  }, error = function(e) {
    cat("Fehler bei Tabellenerstellung:", e$message, "\n")
    cat("Erstelle einfache Übersicht...\n")
    
    cat("\n=== EINFACHE ÜBERSICHT ===\n")
    cat("Alle C50-Fälle:", nrow(cohort), "\n")
    cat("BET-Kohorte:", nrow(cohort_bet), "\n")
    cat("Alter (Mittelwert):", round(mean(cohort_bet$diagnosealter, na.rm = TRUE), 1), "\n")
    cat("RT nach BET:", sum(cohort_bet$rt), "/", nrow(cohort_bet), " (", rt_rate, "%)\n")
    cat("Systemtherapie:", sum(cohort_bet$syst), "/", nrow(cohort_bet), " (", syst_rate, "%)\n")
  })
} else {
  cat("Keine Variablen für Tabelle verfügbar\n")
}

# Schritt 10: Raten als CSV exportieren (medizinisch korrekt beschriftet)
cat("\n9. Exportiere Ergebnisse als CSV...\n")

# Medizinisch korrekte Zusammenfassung der RT-nach-BET-Raten
summary_data <- data.table(
  Kennzahl = c("C50_Faelle_Gesamt", "BET_Faelle_Gesamt", "Mittleres_Alter_BET_Kohorte", 
               "RT_nach_BET_Anzahl", "RT_nach_BET_Rate_Prozent", 
               "Systemtherapie_nach_BET_Anzahl", "Systemtherapie_nach_BET_Rate_Prozent"),
  Wert = c(nrow(cohort),  # Alle C50-Fälle
           nrow(cohort_bet),  # BET-Kohorte (Nenner)
           round(mean(cohort_bet$diagnosealter, na.rm = TRUE), 1),
           sum(cohort_bet$rt),  # Zähler: BET-Fälle mit RT
           rt_rate,  # RT-Rate in BET-Kohorte
           sum(cohort_bet$syst),  # BET-Fälle mit Systemtherapie
           syst_rate),  # Systemtherapie-Rate in BET-Kohorte
  Beschreibung = c("Gesamtzahl Mammakarzinom-Fälle (C50.0-C50.6)",
                   "Anzahl Fälle mit brusterhaltender Therapie (BET) - Nenner für Raten",
                   "Durchschnittsalter bei Diagnose in BET-Kohorte (Jahre)",
                   "Anzahl BET-Fälle mit adjuvanter Radiotherapie", 
                   "Anteil BET-Fälle mit adjuvanter Radiotherapie (%)",
                   "Anzahl BET-Fälle mit Systemtherapie",
                   "Anteil BET-Fälle mit Systemtherapie (%)")
)

# Altersgruppen-Verteilung in BET-Kohorte hinzufügen
if("altersgruppe" %in% names(cohort_bet)) {
  age_dist <- table(cohort_bet$altersgruppe, useNA = "ifany")
  for(i in 1:length(age_dist)) {
    age_name <- names(age_dist)[i]
    if(is.na(age_name)) age_name <- "Unbekannt"
    summary_data <- rbind(summary_data, 
                          data.table(Kennzahl = paste0("BET_Altersgruppe_", age_name),
                                     Wert = as.numeric(age_dist[i]),
                                     Beschreibung = paste("Anzahl BET-Fälle Altersgruppe", age_name)))
  }
}

# Grading-Verteilung in BET-Kohorte hinzufügen
if("grade_simple" %in% names(cohort_bet)) {
  grade_dist <- table(cohort_bet$grade_simple, useNA = "ifany")
  for(i in 1:length(grade_dist)) {
    grade_name <- names(grade_dist)[i]
    if(is.na(grade_name)) grade_name <- "Unbekannt"
    # Encoding-Problem beheben
    grade_name_clean <- gsub("ä", "ae", grade_name)
    grade_name_clean <- gsub("ü", "ue", grade_name_clean)
    grade_name_clean <- gsub("ö", "oe", grade_name_clean)
    grade_name_clean <- gsub("ß", "ss", grade_name_clean)
    grade_name_clean <- gsub("/", "_", grade_name_clean)
    
    summary_data <- rbind(summary_data,
                          data.table(Kennzahl = paste0("BET_Grading_", grade_name_clean),
                                     Wert = as.numeric(grade_dist[i]),
                                     Beschreibung = paste("Anzahl BET-Fälle Grading", grade_name)))
  }
}

# CSV-Export mit korrektem Encoding
tryCatch({
  filename <- paste0(Sys.Date(), "_RT_nach_BET_raten_analyse.csv")
  # Explizit UTF-8 mit BOM für bessere Excel-Kompatibilität
  write.table(summary_data, filename, row.names = FALSE, sep = ",", 
              fileEncoding = "UTF-8", quote = TRUE)
  cat("Ratentabelle (RT nach BET) exportiert:", filename, "\n")
}, error = function(e) {
  cat("WARNUNG: CSV-Export fehlgeschlagen (", e$message, ")\n")
  cat("Ergebnisse werden nur in Konsole angezeigt\n")
})

# Zusätzlich: Detaillierte BET-Patientendaten exportieren
if(nrow(cohort_bet) > 0) {
  # Wichtigste Variablen für BET-Analyse
  export_vars <- c("patient_id", "tumor_id", "diagnosealter", "diagnosejahr", 
                   "rt", "syst", "altersgruppe")
  if("grade_simple" %in% names(cohort_bet)) {
    export_vars <- c(export_vars, "grade_simple")
  }
  
  # Nur existierende Variablen nehmen
  export_vars <- intersect(export_vars, names(cohort_bet))
  
  if(length(export_vars) > 0) {
    tryCatch({
      patient_details <- cohort_bet[, ..export_vars]
      # Spaltennamen medizinisch korrekt beschriften
      if("rt" %in% names(patient_details)) {
        setnames(patient_details, "rt", "RT_nach_BET")
      }
      if("syst" %in% names(patient_details)) {
        setnames(patient_details, "syst", "Systemtherapie_nach_BET")
      }
      
      detail_filename <- paste0(Sys.Date(), "_BET_kohorte_patientendaten.csv")
      write.table(patient_details, detail_filename, row.names = FALSE, sep = ",",
                  fileEncoding = "UTF-8", quote = TRUE)
      cat("BET-Patientendaten exportiert:", detail_filename, "\n")
    }, error = function(e) {
      cat("WARNUNG: Patientendaten-Export fehlgeschlagen\n")
    })
  }
}

cat("\n=== ANALYSE ABGESCHLOSSEN ===\n")
cat("\nMedizinisch korrekte Interpretation:\n")
cat("- RT_nach_BET_Rate = Anteil der BET-Fälle mit adjuvanter Radiotherapie\n")
cat("- Nenner: Alle Fälle mit brusterhaltender Therapie (BET)\n") 
cat("- Zähler: BET-Fälle mit anschließender Bestrahlung\n")
cat("- Klinische Relevanz: Leitlinien-konforme adjuvante RT nach BET\n")

cat("\nExportierte Dateien:\n")
cat("1. ", Sys.Date(), "_RT_nach_BET_raten_analyse.csv (Zusammenfassung)\n")
cat("2. ", Sys.Date(), "_BET_kohorte_patientendaten.csv (Detaildaten)\n")

cat("\nHinweise für weitere Entwicklung:\n")
cat("- BET-Erkennung kann verfeinert werden (detailliertere OPS-Codes)\n")
cat("- RT-Zeitfenster können implementiert werden (Abstand OP-RT)\n")
cat("- TNM-Staging kann hinzugefügt werden\n")
cat("- SES-Daten können ergänzt werden\n")
cat("- Bei Exportproblemen: Excel schließen oder anderes Verzeichnis wählen\n")
