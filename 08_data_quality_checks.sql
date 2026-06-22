-- FILE: 08_data_quality_checks.sql
-- Purpose: Validate data quality across all warehouse layers

-- ============================================================
-- 1. NULL CHECKS — staging layer
-- ============================================================

SELECT
  'stg_inpatient_charges'                               AS table_name,
  COUNTIF(provider_id IS NULL)                          AS null_provider_id,
  COUNTIF(provider_state IS NULL)                       AS null_provider_state,
  COUNTIF(total_discharges IS NULL)                     AS null_total_discharges,
  COUNTIF(avg_total_payments IS NULL)                   AS null_avg_total_payments,
  COUNTIF(avg_medicare_payments IS NULL)                AS null_avg_medicare_payments,
  COUNTIF(drg_definition IS NULL)                       AS null_drg_definition,
  COUNT(*)                                              AS total_rows
FROM `healthcare-analytics-warehouse.healthcare_warehouse.stg_inpatient_charges`

UNION ALL

SELECT
  'stg_outpatient_charges',
  COUNTIF(provider_id IS NULL),
  COUNTIF(provider_state IS NULL),
  COUNTIF(outpatient_services IS NULL),
  COUNTIF(avg_total_payments IS NULL),
  0, NULL,
  COUNT(*)
FROM `healthcare-analytics-warehouse.healthcare_warehouse.stg_outpatient_charges`

UNION ALL

SELECT
  'stg_physicians',
  COUNTIF(npi IS NULL),
  COUNTIF(provider_state IS NULL),
  COUNTIF(line_service_count IS NULL),
  COUNTIF(avg_medicare_payment IS NULL),
  0, NULL,
  COUNT(*)
FROM `healthcare-analytics-warehouse.healthcare_warehouse.stg_physicians`;

-- ============================================================
-- 2. DUPLICATE DETECTION
-- ============================================================

-- Duplicate provider+year in fact table (should return 0 rows)
SELECT provider_id, year, COUNT(*) AS row_count
FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
GROUP BY provider_id, year
HAVING COUNT(*) > 1
ORDER BY row_count DESC;

-- Duplicate provider_ids in dim_provider (should return 0 rows)
SELECT provider_id, COUNT(*) AS row_count
FROM `healthcare-analytics-warehouse.healthcare_warehouse.dim_provider`
GROUP BY provider_id
HAVING COUNT(*) > 1;

-- Duplicate state codes in dim_region (should return 0 rows)
SELECT state_code, COUNT(*) AS row_count
FROM `healthcare-analytics-warehouse.healthcare_warehouse.dim_region`
GROUP BY state_code
HAVING COUNT(*) > 1;

-- ============================================================
-- 3. REFERENTIAL INTEGRITY
-- ============================================================

-- Fact rows with no matching dim_provider
SELECT f.provider_id, f.year, f.state_code
FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics` f
LEFT JOIN `healthcare-analytics-warehouse.healthcare_warehouse.dim_provider` dp
  ON f.provider_id = dp.provider_id
WHERE dp.provider_id IS NULL;

-- Fact rows with no matching dim_region
SELECT f.state_code, COUNT(*) AS unmatched_rows
FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics` f
LEFT JOIN `healthcare-analytics-warehouse.healthcare_warehouse.dim_region` dr
  ON f.state_code = dr.state_code
WHERE dr.state_code IS NULL
GROUP BY f.state_code;

-- ============================================================
-- 4. OUTLIER DETECTION
-- ============================================================

WITH stats AS (
  SELECT
    AVG(avg_inpatient_payment)    AS mean_cost,
    STDDEV(avg_inpatient_payment) AS stddev_cost
  FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
  WHERE year = 2015
)
SELECT
  f.provider_id,
  f.provider_name,
  f.state_code,
  ROUND(f.avg_inpatient_payment, 2)               AS avg_cost,
  ROUND(s.mean_cost, 2)                           AS national_mean,
  ROUND((f.avg_inpatient_payment - s.mean_cost) / NULLIF(s.stddev_cost, 0), 2) AS z_score
FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics` f
CROSS JOIN stats s
WHERE year = 2015
  AND ABS((f.avg_inpatient_payment - s.mean_cost) / NULLIF(s.stddev_cost, 0)) > 3
ORDER BY z_score DESC;

-- ============================================================
-- 5. PIPELINE HEALTH REPORT — pass/fail summary
-- ============================================================

WITH checks AS (
  SELECT 'Fact table has rows' AS check_name,
    CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS status
  FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`

  UNION ALL

  SELECT 'No duplicate provider+year',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
  FROM (
    SELECT provider_id, year FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
    GROUP BY provider_id, year HAVING COUNT(*) > 1
  )

  UNION ALL

  SELECT 'dim_provider has rows',
    CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
  FROM `healthcare-analytics-warehouse.healthcare_warehouse.dim_provider`

  UNION ALL

  SELECT 'dim_region covers 50+ states',
    CASE WHEN COUNT(*) >= 50 THEN 'PASS' ELSE 'FAIL' END
  FROM `healthcare-analytics-warehouse.healthcare_warehouse.dim_region`

  UNION ALL

  SELECT 'Both years present in fact table',
    CASE WHEN COUNT(DISTINCT year) = 2 THEN 'PASS' ELSE 'FAIL' END
  FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
)
SELECT check_name, status
FROM checks
ORDER BY status, check_name;
