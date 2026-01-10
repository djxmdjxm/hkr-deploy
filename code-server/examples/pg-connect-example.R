# Load required libraries
library(DBI)
library(RPostgres)

# ---- Configuration ----
# Replace with your actual database credentials
db_host <- "central-db"        # or e.g. "db.yourserver.com"
db_port <- 5432               # default Postgres port
db_name <- "krebs"
db_user <- "postgres"
db_password <- "1234"

# ---- Connect to PostgreSQL ----
con <- dbConnect(
  RPostgres::Postgres(),
  host = db_host,
  port = db_port,
  dbname = db_name,
  user = db_user,
  password = db_password
)

# ---- Verify connection ----
if (!dbIsValid(con)) {
  stop("Database connection failed.")
} else {
  cat("Successfully connected to the database.\n")
}

# ---- Optional: Check if table exists ----
tables <- dbListTables(con)
if (!"patient_report" %in% tables) {
  stop("Table 'patient_report' not found in the database.")
}

# ---- Fetch all rows ----
query <- "SELECT * FROM patient_report;"
patient_report <- dbGetQuery(con, query)

# ---- Inspect result ----
cat(sprintf("Retrieved %d rows and %d columns.\n", nrow(patient_report), ncol(patient_report)))
str(patient_report)

# ---- Disconnect ----
dbDisconnect(con)
cat("Database connection closed.\n")