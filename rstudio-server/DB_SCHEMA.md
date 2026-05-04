# KIKA Datenbank-Schema

_Stand: 2026-05-04 — automatisch generiert von `00_db_schema.R`._

Tabellen: **17**  ·  Foreign Keys: **17**

## Tabellenuebersicht

| Tabelle | Zeilen |
|---------|--------|
| `alembic_version` | 1 |
| `patient_report` | 5460 |
| `radiotherapy_session` | 2047 |
| `radiotherapy_session_brachytherapy` | 3 |
| `radiotherapy_session_metabolic` | 0 |
| `radiotherapy_session_percutaneous` | 2044 |
| `tnm` | 227582 |
| `tumor_follow_up` | 1660 |
| `tumor_histology` | 5490 |
| `tumor_radiotherapy` | 1462 |
| `tumor_report` | 5490 |
| `tumor_report_breast` | 0 |
| `tumor_report_colorectal` | 0 |
| `tumor_report_melanoma` | 0 |
| `tumor_report_prostate` | 0 |
| `tumor_surgery` | 2200 |
| `tumor_systemic_therapy` | 5610 |

## Tabellen im Detail

### `alembic_version`  _(1 Zeilen)_

| Spalte | Typ | NULL? |
|--------|-----|-------|
| `version_num` | character varying | nein |

### `patient_report`  _(5460 Zeilen)_

| Spalte | Typ | NULL? |
|--------|-----|-------|
| `id` | integer | nein |
| `patient_id` | character varying | nein |
| `gender` | character varying | nein |
| `date_of_birth` | date | nein |
| `date_of_birth_accuracy` | character varying | ja |
| `is_deceased` | boolean | nein |
| `vital_status_date` | date | ja |
| `vital_status_date_accuracy` | character varying | ja |
| `death_causes` | jsonb | ja |
| `register` | character varying | nein |
| `reported_at` | date | nein |
| `updated_at` | timestamp without time zone | nein |
| `created_at` | timestamp without time zone | nein |

### `radiotherapy_session`  _(2047 Zeilen)_

| Spalte | Typ | NULL? |
|--------|-----|-------|
| `id` | integer | nein |
| `tumor_radiotherapy_id` | integer | nein |
| `start_date` | date | nein |
| `start_date_accuracy` | character varying | ja |
| `duration_days` | integer | ja |
| `target_area` | character varying | ja |
| `laterality` | character varying | ja |
| `updated_at` | timestamp without time zone | nein |
| `created_at` | timestamp without time zone | nein |

### `radiotherapy_session_brachytherapy`  _(3 Zeilen)_

| Spalte | Typ | NULL? |
|--------|-----|-------|
| `radiotherapy_session_id` | integer | nein |
| `type` | character varying | nein |
| `dose_rate` | character varying | ja |
| `updated_at` | timestamp without time zone | nein |
| `created_at` | timestamp without time zone | nein |

### `radiotherapy_session_metabolic`  _(0 Zeilen)_

| Spalte | Typ | NULL? |
|--------|-----|-------|
| `radiotherapy_session_id` | integer | nein |
| `type` | character varying | nein |
| `updated_at` | timestamp without time zone | nein |
| `created_at` | timestamp without time zone | nein |

### `radiotherapy_session_percutaneous`  _(2044 Zeilen)_

| Spalte | Typ | NULL? |
|--------|-----|-------|
| `radiotherapy_session_id` | integer | nein |
| `chemoradio` | character varying | ja |
| `stereotactic` | boolean | nein |
| `respiratory_gated` | boolean | nein |
| `updated_at` | timestamp without time zone | nein |
| `created_at` | timestamp without time zone | nein |

### `tnm`  _(227582 Zeilen)_

| Spalte | Typ | NULL? |
|--------|-----|-------|
| `id` | integer | nein |
| `version` | character varying | ja |
| `y_symbol` | boolean | ja |
| `r_symbol` | boolean | ja |
| `a_symbol` | boolean | ja |
| `t_prefix` | character varying | ja |
| `t` | character varying | ja |
| `m_symbol` | character varying | ja |
| `n_prefix` | character varying | ja |
| `n` | character varying | ja |
| `m_prefix` | character varying | ja |
| `m` | character varying | ja |
| `l` | character varying | ja |
| `v` | character varying | ja |
| `pn` | character varying | ja |
| `s` | character varying | ja |
| `uicc_stage` | character varying | ja |
| `updated_at` | timestamp without time zone | nein |
| `created_at` | timestamp without time zone | nein |

### `tumor_follow_up`  _(1660 Zeilen)_

| Spalte | Typ | NULL? |
|--------|-----|-------|
| `id` | integer | nein |
| `tumor_report_id` | integer | nein |
| `tnm_id` | integer | ja |
| `other_classification` | jsonb | ja |
| `date` | date | nein |
| `date_accuracy` | character varying | nein |
| `overall_tumor_status` | character varying | nein |
| `local_tumor_status` | character varying | ja |
| `lymph_node_tumor_status` | character varying | ja |
| `distant_metastasis_tumor_status` | character varying | ja |
| `distant_metastasis` | jsonb | ja |
| `updated_at` | timestamp without time zone | nein |
| `created_at` | timestamp without time zone | nein |

### `tumor_histology`  _(5490 Zeilen)_

| Spalte | Typ | NULL? |
|--------|-----|-------|
| `tumor_report_id` | integer | nein |
| `morphology_icd` | jsonb | nein |
| `grading` | character varying | nein |
| `lymph_nodes_examined` | integer | ja |
| `lymph_nodes_affected` | integer | ja |
| `updated_at` | timestamp without time zone | nein |
| `created_at` | timestamp without time zone | nein |

### `tumor_radiotherapy`  _(1462 Zeilen)_

| Spalte | Typ | NULL? |
|--------|-----|-------|
| `id` | integer | nein |
| `tumor_report_id` | integer | nein |
| `intent` | character varying | ja |
| `surgery_relation` | character varying | ja |
| `updated_at` | timestamp without time zone | nein |
| `created_at` | timestamp without time zone | nein |

### `tumor_report`  _(5490 Zeilen)_

| Spalte | Typ | NULL? |
|--------|-----|-------|
| `id` | integer | nein |
| `patient_report_id` | integer | nein |
| `tumor_id` | character varying | nein |
| `diagnosis_date` | date | nein |
| `diagnosis_date_accuracy` | character varying | nein |
| `incidence_location` | character varying | nein |
| `icd` | jsonb | nein |
| `topographie` | jsonb | ja |
| `diagnostic_certainty` | character varying | nein |
| `c_tnm_id` | integer | ja |
| `p_tnm_id` | integer | ja |
| `distant_metastasis` | jsonb | ja |
| `other_classification` | jsonb | ja |
| `laterality` | character varying | nein |
| `updated_at` | timestamp without time zone | nein |
| `created_at` | timestamp without time zone | nein |

### `tumor_report_breast`  _(0 Zeilen)_

| Spalte | Typ | NULL? |
|--------|-----|-------|
| `tumor_report_id` | integer | nein |
| `menopause_status_at_diagnosis` | character varying | ja |
| `estrogen_receptor_status` | character varying | ja |
| `progesterone_receptor_status` | character varying | ja |
| `her2neu_status` | character varying | ja |
| `tumor_size_mm_invasive` | integer | ja |
| `tumor_size_mm_dcis` | integer | ja |
| `updated_at` | timestamp without time zone | nein |
| `created_at` | timestamp without time zone | nein |

### `tumor_report_colorectal`  _(0 Zeilen)_

| Spalte | Typ | NULL? |
|--------|-----|-------|
| `tumor_report_id` | integer | nein |
| `ras_mutation` | character varying | ja |
| `rectum_distance_anocutaneous_line_cm` | integer | ja |
| `updated_at` | timestamp without time zone | nein |
| `created_at` | timestamp without time zone | nein |

### `tumor_report_melanoma`  _(0 Zeilen)_

| Spalte | Typ | NULL? |
|--------|-----|-------|
| `tumor_report_id` | integer | nein |
| `tumor_thickness_mm` | numeric | ja |
| `ldh` | numeric | ja |
| `ulceration` | boolean | ja |
| `updated_at` | timestamp without time zone | nein |
| `created_at` | timestamp without time zone | nein |

### `tumor_report_prostate`  _(0 Zeilen)_

| Spalte | Typ | NULL? |
|--------|-----|-------|
| `tumor_report_id` | integer | nein |
| `gleason_primary_grade` | character varying | ja |
| `gleason_secondary_grade` | character varying | ja |
| `gleason_score_result` | character varying | ja |
| `gleason_score_reason` | character varying | ja |
| `psa` | numeric | ja |
| `psa_date` | date | ja |
| `psa_date_accuracy` | character varying | ja |
| `updated_at` | timestamp without time zone | nein |
| `created_at` | timestamp without time zone | nein |

### `tumor_surgery`  _(2200 Zeilen)_

| Spalte | Typ | NULL? |
|--------|-----|-------|
| `id` | integer | nein |
| `tumor_report_id` | integer | nein |
| `intent` | character varying | nein |
| `date` | date | nein |
| `date_accuracy` | character varying | ja |
| `operations` | jsonb | nein |
| `local_residual_status` | character varying | ja |
| `updated_at` | timestamp without time zone | nein |
| `created_at` | timestamp without time zone | nein |

### `tumor_systemic_therapy`  _(5610 Zeilen)_

| Spalte | Typ | NULL? |
|--------|-----|-------|
| `id` | integer | nein |
| `tumor_report_id` | integer | nein |
| `start_date` | date | nein |
| `start_date_accuracy` | character varying | ja |
| `duration_days` | integer | ja |
| `intent` | character varying | nein |
| `surgery_relation` | character varying | ja |
| `type` | character varying | nein |
| `protocol` | jsonb | ja |
| `drugs` | jsonb | nein |
| `updated_at` | timestamp without time zone | nein |
| `created_at` | timestamp without time zone | nein |

## Beziehungen (Foreign Keys)

| Von | Spalte | -> | Zu | Spalte |
|-----|--------|----|----|--------|
| `radiotherapy_session` | `tumor_radiotherapy_id` | -> | `tumor_radiotherapy` | `id` |
| `radiotherapy_session_brachytherapy` | `radiotherapy_session_id` | -> | `radiotherapy_session` | `id` |
| `radiotherapy_session_metabolic` | `radiotherapy_session_id` | -> | `radiotherapy_session` | `id` |
| `radiotherapy_session_percutaneous` | `radiotherapy_session_id` | -> | `radiotherapy_session` | `id` |
| `tumor_follow_up` | `tnm_id` | -> | `tnm` | `id` |
| `tumor_follow_up` | `tumor_report_id` | -> | `tumor_report` | `id` |
| `tumor_histology` | `tumor_report_id` | -> | `tumor_report` | `id` |
| `tumor_radiotherapy` | `tumor_report_id` | -> | `tumor_report` | `id` |
| `tumor_report` | `c_tnm_id` | -> | `tnm` | `id` |
| `tumor_report` | `p_tnm_id` | -> | `tnm` | `id` |
| `tumor_report` | `patient_report_id` | -> | `patient_report` | `id` |
| `tumor_report_breast` | `tumor_report_id` | -> | `tumor_report` | `id` |
| `tumor_report_colorectal` | `tumor_report_id` | -> | `tumor_report` | `id` |
| `tumor_report_melanoma` | `tumor_report_id` | -> | `tumor_report` | `id` |
| `tumor_report_prostate` | `tumor_report_id` | -> | `tumor_report` | `id` |
| `tumor_surgery` | `tumor_report_id` | -> | `tumor_report` | `id` |
| `tumor_systemic_therapy` | `tumor_report_id` | -> | `tumor_report` | `id` |

## Haeufige Beispiel-Queries

**Anzahl Patientinnen / Tumorfaelle**

```r
library(DBI); library(RPostgres)
con <- dbConnect(RPostgres::Postgres(),
                 host="central-db", port=5432, dbname="krebs",
                 user="postgres", password="1234")

dbGetQuery(con, "SELECT COUNT(*) FROM patient_report")
dbGetQuery(con, "SELECT COUNT(*) FROM tumor_report")
```

**Tumoren mit Patientendaten verknuepfen**

```r
dbGetQuery(con, "
  SELECT pr.patient_id, pr.gender, pr.date_of_birth,
         tr.diagnosis_date, tr.icd->>'code' AS icd_code
  FROM   patient_report pr
  JOIN   tumor_report   tr ON tr.patient_report_id = pr.id
  LIMIT  10
")
```

**ICD-Codes haeufigste Diagnosen**

```r
dbGetQuery(con, "
  SELECT icd->>'code' AS code, COUNT(*) AS n
  FROM   tumor_report
  GROUP  BY icd->>'code'
  ORDER  BY n DESC
  LIMIT  20
")
```

**JSON-Felder parsen** — z.B. `tumor_report.icd`, `patient_report.address`

```r
library(jsonlite)
row <- dbGetQuery(con, "SELECT icd FROM tumor_report LIMIT 1")
fromJSON(row$icd[1])
```

