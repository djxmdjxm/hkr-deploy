# ============================================================
# KIKA — Datenbank-Schema erkunden
#
# Dieses Skript zeigt:
#  - alle Tabellen in der Krebsregister-Datenbank
#  - alle Spalten je Tabelle (Name, Typ, NULL erlaubt?)
#  - Foreign-Key-Beziehungen
#  - Beispiel-Queries fuer haeufige Auswertungen
#
# Source: Strg+Shift+S
# Output: Konsole + Datei DB_SCHEMA.md im Working Directory
# ============================================================

library(DBI)
library(RPostgres)

con <- dbConnect(
  RPostgres::Postgres(),
  host     = "central-db",
  port     = 5432,
  dbname   = "krebs",
  user     = "postgres",
  password = "1234"
)

# ============================================================
# SCHEMA-METADATEN ABFRAGEN
# ============================================================

tables <- dbGetQuery(con, "
  SELECT table_name
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_type = 'BASE TABLE'
  ORDER BY table_name
")

columns <- dbGetQuery(con, "
  SELECT
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
  FROM information_schema.columns
  WHERE table_schema = 'public'
  ORDER BY table_name, ordinal_position
")

fks <- dbGetQuery(con, "
  SELECT
    tc.table_name      AS from_table,
    kcu.column_name    AS from_column,
    ccu.table_name     AS to_table,
    ccu.column_name    AS to_column
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
   AND tc.table_schema    = kcu.table_schema
  JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
   AND ccu.table_schema    = tc.table_schema
  WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema    = 'public'
  ORDER BY from_table, from_column
")

row_counts <- do.call(rbind, lapply(tables$table_name, function(t) {
  n <- tryCatch(
    dbGetQuery(con, sprintf('SELECT COUNT(*) AS n FROM "%s"', t))$n,
    error = function(e) NA_integer_
  )
  data.frame(table_name = t, rows = n, stringsAsFactors = FALSE)
}))

dbDisconnect(con)

# ============================================================
# KONSOLEN-AUSGABE
# ============================================================

cat("\n=== KIKA Datenbank-Schema ===\n\n")
cat("Tabellen gesamt:", nrow(tables), "\n\n")

for (tn in tables$table_name) {
  cols <- columns[columns$table_name == tn, ]
  rc   <- row_counts$rows[row_counts$table_name == tn]
  cat(sprintf("--- %s   (%s Zeilen) ---\n", tn, format(rc, big.mark=".")))
  for (i in seq_len(nrow(cols))) {
    nullable <- ifelse(cols$is_nullable[i] == "YES", "NULL", "NOT NULL")
    cat(sprintf("  %-32s %-20s %s\n", cols$column_name[i], cols$data_type[i], nullable))
  }
  cat("\n")
}

if (nrow(fks) > 0) {
  cat("=== Foreign Keys ===\n")
  for (i in seq_len(nrow(fks))) {
    cat(sprintf("  %s.%s -> %s.%s\n",
        fks$from_table[i], fks$from_column[i],
        fks$to_table[i],   fks$to_column[i]))
  }
  cat("\n")
}

# ============================================================
# MARKDOWN-DATEI SCHREIBEN
# ============================================================

md <- c(
  "# KIKA Datenbank-Schema",
  "",
  sprintf("_Stand: %s — automatisch generiert von `00_db_schema.R`._", format(Sys.Date())),
  "",
  sprintf("Tabellen: **%d**  ·  Foreign Keys: **%d**", nrow(tables), nrow(fks)),
  ""
)

md <- c(md, "## Tabellenuebersicht", "")
md <- c(md, "| Tabelle | Zeilen |")
md <- c(md, "|---------|--------|")
for (i in seq_len(nrow(row_counts))) {
  md <- c(md, sprintf("| `%s` | %s |", row_counts$table_name[i], format(row_counts$rows[i], big.mark=".")))
}
md <- c(md, "")

md <- c(md, "## Tabellen im Detail", "")

for (tn in tables$table_name) {
  cols <- columns[columns$table_name == tn, ]
  rc   <- row_counts$rows[row_counts$table_name == tn]
  md <- c(md, sprintf("### `%s`  _(%s Zeilen)_", tn, format(rc, big.mark=".")), "")
  md <- c(md, "| Spalte | Typ | NULL? |")
  md <- c(md, "|--------|-----|-------|")
  for (i in seq_len(nrow(cols))) {
    md <- c(md, sprintf("| `%s` | %s | %s |",
        cols$column_name[i], cols$data_type[i],
        ifelse(cols$is_nullable[i] == "YES", "ja", "nein")))
  }
  md <- c(md, "")
}

if (nrow(fks) > 0) {
  md <- c(md, "## Beziehungen (Foreign Keys)", "")
  md <- c(md, "| Von | Spalte | -> | Zu | Spalte |")
  md <- c(md, "|-----|--------|----|----|--------|")
  for (i in seq_len(nrow(fks))) {
    md <- c(md, sprintf("| `%s` | `%s` | -> | `%s` | `%s` |",
        fks$from_table[i], fks$from_column[i],
        fks$to_table[i],   fks$to_column[i]))
  }
  md <- c(md, "")
}

# Beispiel-Queries
md <- c(md, "## Haeufige Beispiel-Queries", "",
  "**Anzahl Patientinnen / Tumorfaelle**",
  "",
  "```r",
  "library(DBI); library(RPostgres)",
  "con <- dbConnect(RPostgres::Postgres(),",
  "                 host=\"central-db\", port=5432, dbname=\"krebs\",",
  "                 user=\"postgres\", password=\"1234\")",
  "",
  "dbGetQuery(con, \"SELECT COUNT(*) FROM patient_report\")",
  "dbGetQuery(con, \"SELECT COUNT(*) FROM tumor_report\")",
  "```",
  "",
  "**Tumoren mit Patientendaten verknuepfen**",
  "",
  "```r",
  "dbGetQuery(con, \"",
  "  SELECT pr.patient_id, pr.gender, pr.date_of_birth,",
  "         tr.diagnosis_date, tr.icd->>'code' AS icd_code",
  "  FROM   patient_report pr",
  "  JOIN   tumor_report   tr ON tr.patient_report_id = pr.id",
  "  LIMIT  10",
  "\")",
  "```",
  "",
  "**ICD-Codes haeufigste Diagnosen**",
  "",
  "```r",
  "dbGetQuery(con, \"",
  "  SELECT icd->>'code' AS code, COUNT(*) AS n",
  "  FROM   tumor_report",
  "  GROUP  BY icd->>'code'",
  "  ORDER  BY n DESC",
  "  LIMIT  20",
  "\")",
  "```",
  "",
  "**JSON-Felder parsen** — z.B. `tumor_report.icd`, `patient_report.address`",
  "",
  "```r",
  "library(jsonlite)",
  "row <- dbGetQuery(con, \"SELECT icd FROM tumor_report LIMIT 1\")",
  "fromJSON(row$icd[1])",
  "```",
  ""
)

writeLines(md, "DB_SCHEMA.md")
cat("\nDB_SCHEMA.md geschrieben (", length(md), "Zeilen,", nrow(tables), "Tabellen).\n")
