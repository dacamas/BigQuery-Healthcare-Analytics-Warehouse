-- FILE: 01_data_exploration.sql
-- Purpose: Explore CMS Medicare public datasets before modeling
-- Dataset: bigquery-public-data.cms_medicare

-- ============================================================
-- 1. ROW COUNTS — understand dataset sizes
-- ============================================================

SELECT 'inpatient_charges_2015' AS table_name, COUNT(*) AS row_count
FROM `bigquery-public-data.cms_medicare.inpatient_charges_2015`
UNION ALL
SELECT 'inpatient_charges_2014', COUNT(*)
FROM `bigquery-public-data.cms_medicare.inpatient_charges_2014`
UNION ALL
SELECT 'outpatient_charges_2015', COUNT(*)
FROM `bigquery-public-data.cms_medicare.outpatient_charges_2015`
UNION ALL
SELECT 'physicians_and_other_supplier_2014', COUNT(*)
FROM `bigquery-public-data.cms_medicare.physicians_and_other_supplier_2014`;

-- ============================================================
-- 2. SCHEMA INSPECTION — preview columns and sample rows
-- ============================================================

-- Inpatient charges sample
SELECT *
FROM `bigquery-public-data.cms_medicare.inpatient_charges_2015`
LIMIT 10;

-- Outpatient charges sample
SELECT *
FROM `bigquery-public-data.cms_medicare.outpatient_charges_2015`
LIMIT 10;

-- Physician/supplier sample
SELECT *
FROM `bigquery-public-data.cms_medicare.physicians_and_other_supplier_2014`
LIMIT 10;

-- ============================================================
-- 3. MISSING VALUE CHECKS — inpatient charges
-- ============================================================

SELECT
  COUNTIF(provider_id IS NULL)             AS null_provider_id,
  COUNTIF(provider_name IS NULL)           AS null_provider_name,
  COUNTIF(provider_state IS NULL)          AS null_provider_state,
  COUNTIF(drg_definition IS NULL)          AS null_drg_definition,
  COUNTIF(average_total_payments IS NULL)  AS null_avg_total_payments,
  COUNTIF(average_covered_charges IS NULL) AS null_avg_covered_charges,
  COUNTIF(total_discharges IS NULL)        AS null_total_discharges,
  COUNT(*)                                 AS total_rows
FROM `bigquery-public-data.cms_medicare.inpatient_charges_2015`;

-- Missing values — outpatient charges
SELECT
  COUNTIF(provider_id IS NULL)            AS null_provider_id,
  COUNTIF(provider_state IS NULL)         AS null_provider_state,
  COUNTIF(average_total_payments IS NULL) AS null_avg_total_payments,
  COUNTIF(outpatient_services IS NULL)    AS null_outpatient_services,
  COUNT(*)                                AS total_rows
FROM `bigquery-public-data.cms_medicare.outpatient_charges_2015`;

-- ============================================================
-- 4. DISTINCT VALUE CHECKS — cardinality exploration
-- ============================================================

SELECT
  COUNT(DISTINCT provider_id)    AS distinct_providers,
  COUNT(DISTINCT provider_state) AS distinct_states,
  COUNT(DISTINCT drg_definition) AS distinct_drg_codes
FROM `bigquery-public-data.cms_medicare.inpatient_charges_2015`;

-- ============================================================
-- 5. DISTRIBUTION — average total payments
-- ============================================================

SELECT
  MIN(average_total_payments)    AS min_payment,
  MAX(average_total_payments)    AS max_payment,
  AVG(average_total_payments)    AS avg_payment,
  STDDEV(average_total_payments) AS stddev_payment,
  APPROX_QUANTILES(average_total_payments, 4)[OFFSET(1)] AS p25,
  APPROX_QUANTILES(average_total_payments, 4)[OFFSET(2)] AS p50,
  APPROX_QUANTILES(average_total_payments, 4)[OFFSET(3)] AS p75
FROM `bigquery-public-data.cms_medicare.inpatient_charges_2015`;

-- ============================================================
-- 6. TOP STATES BY VOLUME
-- ============================================================

SELECT
  provider_state,
  COUNT(DISTINCT provider_id) AS provider_count,
  SUM(total_discharges)       AS total_discharges,
  ROUND(AVG(average_total_payments), 2) AS avg_payment
FROM `bigquery-public-data.cms_medicare.inpatient_charges_2015`
GROUP BY provider_state
ORDER BY total_discharges DESC
LIMIT 20;

-- ============================================================
-- 7. TOP DRG CODES BY VOLUME
-- ============================================================

SELECT
  drg_definition,
  SUM(total_discharges)                 AS total_discharges,
  ROUND(AVG(average_total_payments), 2) AS avg_payment,
  ROUND(AVG(average_covered_charges), 2) AS avg_covered_charges
FROM `bigquery-public-data.cms_medicare.inpatient_charges_2015`
GROUP BY drg_definition
ORDER BY total_discharges DESC
LIMIT 20;

-- ============================================================
-- 8. YEAR-OVER-YEAR AVAILABILITY CHECK
-- ============================================================

SELECT '2014' AS year, COUNT(*) AS inpatient_rows
FROM `bigquery-public-data.cms_medicare.inpatient_charges_2014`
UNION ALL
SELECT '2015', COUNT(*)
FROM `bigquery-public-data.cms_medicare.inpatient_charges_2015`;
