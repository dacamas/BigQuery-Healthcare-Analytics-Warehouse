-- FILE: 03_intermediate_models.sql
-- Purpose: Join staged tables, engineer features, aggregate to provider level

-- ============================================================
-- int_provider_inpatient_summary
-- Aggregate inpatient metrics per provider per year
-- ============================================================

CREATE OR REPLACE TABLE `healthcare-analytics-warehouse.healthcare_warehouse.int_provider_inpatient_summary` AS
SELECT
  provider_id,
  provider_name,
  provider_state,
  provider_city,
  hrr_description,
  data_year,
  COUNT(DISTINCT drg_code)                      AS distinct_drg_count,
  SUM(total_discharges)                         AS total_discharges,
  ROUND(AVG(avg_covered_charges), 2)            AS avg_covered_charges,
  ROUND(AVG(avg_total_payments), 2)             AS avg_total_payments,
  ROUND(AVG(avg_medicare_payments), 2)          AS avg_medicare_payments,
  ROUND(SAFE_DIVIDE(
    AVG(avg_medicare_payments),
    NULLIF(AVG(avg_covered_charges), 0)
  ), 4)                                         AS medicare_payment_ratio
FROM `healthcare-analytics-warehouse.healthcare_warehouse.stg_inpatient_charges`
GROUP BY provider_id, provider_name, provider_state, provider_city, hrr_description, data_year;

-- ============================================================
-- int_provider_outpatient_summary
-- Aggregate outpatient metrics per provider per year
-- ============================================================

CREATE OR REPLACE TABLE `healthcare-analytics-warehouse.healthcare_warehouse.int_provider_outpatient_summary` AS
SELECT
  provider_id,
  provider_name,
  provider_state,
  provider_city,
  data_year,
  COUNT(DISTINCT apc)                           AS distinct_apc_count,
  SUM(outpatient_services)                      AS total_outpatient_services,
  ROUND(AVG(avg_submitted_charges), 2)          AS avg_submitted_charges,
  ROUND(AVG(avg_total_payments), 2)             AS avg_total_payments
FROM `healthcare-analytics-warehouse.healthcare_warehouse.stg_outpatient_charges`
GROUP BY provider_id, provider_name, provider_state, provider_city, data_year;

-- ============================================================
-- int_physician_summary
-- Aggregate physician metrics per provider_type per state
-- ============================================================

CREATE OR REPLACE TABLE `healthcare-analytics-warehouse.healthcare_warehouse.int_physician_summary` AS
SELECT
  provider_state,
  provider_type,
  data_year,
  COUNT(DISTINCT npi)                           AS distinct_physicians,
  SUM(line_service_count)                       AS total_services,
  SUM(beneficiary_count)                        AS total_beneficiaries,
  ROUND(AVG(avg_medicare_payment), 2)           AS avg_medicare_payment,
  ROUND(AVG(avg_submitted_charge), 2)           AS avg_submitted_charge,
  ROUND(SAFE_DIVIDE(
    AVG(avg_medicare_payment),
    NULLIF(AVG(avg_submitted_charge), 0)
  ), 4)                                         AS payment_to_charge_ratio
FROM `healthcare-analytics-warehouse.healthcare_warehouse.stg_physicians`
GROUP BY provider_state, provider_type, data_year;

-- ============================================================
-- int_state_metrics
-- State-level aggregation joining inpatient + outpatient
-- ============================================================

CREATE OR REPLACE TABLE `healthcare-analytics-warehouse.healthcare_warehouse.int_state_metrics` AS
WITH inpatient_by_state AS (
  SELECT
    provider_state                              AS state,
    data_year,
    COUNT(DISTINCT provider_id)                 AS inpatient_provider_count,
    SUM(total_discharges)                       AS total_inpatient_discharges,
    ROUND(AVG(avg_total_payments), 2)           AS avg_inpatient_payment,
    ROUND(AVG(avg_covered_charges), 2)          AS avg_covered_charges
  FROM `healthcare-analytics-warehouse.healthcare_warehouse.stg_inpatient_charges`
  GROUP BY provider_state, data_year
),
outpatient_by_state AS (
  SELECT
    provider_state                              AS state,
    data_year,
    COUNT(DISTINCT provider_id)                 AS outpatient_provider_count,
    SUM(outpatient_services)                    AS total_outpatient_services,
    ROUND(AVG(avg_total_payments), 2)           AS avg_outpatient_payment
  FROM `healthcare-analytics-warehouse.healthcare_warehouse.stg_outpatient_charges`
  GROUP BY provider_state, data_year
)
SELECT
  i.state,
  i.data_year,
  i.inpatient_provider_count,
  i.total_inpatient_discharges,
  i.avg_inpatient_payment,
  i.avg_covered_charges,
  o.outpatient_provider_count,
  o.total_outpatient_services,
  o.avg_outpatient_payment,
  ROUND(SAFE_DIVIDE(
    (i.avg_inpatient_payment * i.total_inpatient_discharges)
      + (o.avg_outpatient_payment * o.total_outpatient_services),
    NULLIF(i.total_inpatient_discharges + o.total_outpatient_services, 0)
  ), 2)                                         AS combined_cost_index
FROM inpatient_by_state i
LEFT JOIN outpatient_by_state o
  ON i.state = o.state
  AND i.data_year = o.data_year;

-- ============================================================
-- int_provider_combined
-- Join inpatient + outpatient at provider level for fact table
-- ============================================================

CREATE OR REPLACE TABLE `healthcare-analytics-warehouse.healthcare_warehouse.int_provider_combined` AS
SELECT
  i.provider_id,
  i.provider_name,
  i.provider_state,
  i.provider_city,
  i.hrr_description,
  i.data_year,
  i.distinct_drg_count,
  i.total_discharges,
  i.avg_total_payments                          AS avg_inpatient_payment,
  i.avg_medicare_payments,
  i.medicare_payment_ratio,
  COALESCE(o.total_outpatient_services, 0)      AS total_outpatient_services,
  COALESCE(o.avg_total_payments, 0)             AS avg_outpatient_payment,
  i.total_discharges
    + COALESCE(o.total_outpatient_services, 0)  AS total_patient_volume
FROM `healthcare-analytics-warehouse.healthcare_warehouse.int_provider_inpatient_summary` i
LEFT JOIN `healthcare-analytics-warehouse.healthcare_warehouse.int_provider_outpatient_summary` o
  ON i.provider_id = o.provider_id
  AND i.data_year = o.data_year;
