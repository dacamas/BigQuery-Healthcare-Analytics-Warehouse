-- FILE: 06_kpi_queries.sql
-- Purpose: Business KPI queries for stakeholder reporting

-- ============================================================
-- KPI 1: Average inpatient cost by state
-- ============================================================

SELECT
  state_code,
  census_region,
  COUNT(DISTINCT provider_id)                     AS provider_count,
  SUM(total_discharges)                           AS total_discharges,
  ROUND(AVG(avg_inpatient_payment), 2)            AS avg_inpatient_cost,
  ROUND(AVG(avg_medicare_payments), 2)            AS avg_medicare_payment,
  ROUND(AVG(medicare_payment_ratio), 4)           AS avg_medicare_ratio
FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
WHERE year = 2015
GROUP BY state_code, census_region
ORDER BY avg_inpatient_cost DESC;

-- ============================================================
-- KPI 2: Top 20 highest-cost providers
-- ============================================================

SELECT
  provider_id,
  provider_name,
  provider_city,
  state_code,
  provider_size_category,
  total_discharges,
  ROUND(avg_inpatient_payment, 2)                 AS avg_inpatient_cost,
  ROUND(avg_medicare_payments, 2)                 AS avg_medicare_cost,
  ROUND(combined_avg_cost, 2)                     AS combined_cost
FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
WHERE year = 2015
ORDER BY avg_inpatient_payment DESC
LIMIT 20;

-- ============================================================
-- KPI 3: Cost by census region
-- ============================================================

SELECT
  census_region,
  year,
  COUNT(DISTINCT provider_id)                     AS provider_count,
  SUM(total_patient_volume)                       AS total_patient_volume,
  ROUND(AVG(avg_inpatient_payment), 2)            AS avg_inpatient_cost,
  ROUND(AVG(avg_outpatient_payment), 2)           AS avg_outpatient_cost,
  ROUND(AVG(combined_avg_cost), 2)                AS avg_combined_cost,
  ROUND(AVG(medicare_payment_ratio), 4)           AS avg_medicare_ratio
FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
GROUP BY census_region, year
ORDER BY census_region, year;

-- ============================================================
-- KPI 4: Year-over-year cost change by state
-- ============================================================

WITH yearly AS (
  SELECT
    state_code,
    year,
    ROUND(AVG(avg_inpatient_payment), 2)          AS avg_cost
  FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
  GROUP BY state_code, year
)
SELECT
  y2015.state_code,
  y2014.avg_cost                                  AS avg_cost_2014,
  y2015.avg_cost                                  AS avg_cost_2015,
  ROUND(y2015.avg_cost - y2014.avg_cost, 2)       AS absolute_change,
  ROUND(SAFE_DIVIDE(
    y2015.avg_cost - y2014.avg_cost,
    NULLIF(y2014.avg_cost, 0)
  ) * 100, 2)                                     AS pct_change
FROM yearly y2015
JOIN yearly y2014
  ON y2015.state_code = y2014.state_code
  AND y2015.year = 2015
  AND y2014.year = 2014
ORDER BY pct_change DESC;

-- ============================================================
-- KPI 5: Provider volume tiers
-- ============================================================

SELECT
  provider_size_category,
  year,
  COUNT(DISTINCT provider_id)                     AS provider_count,
  ROUND(AVG(total_discharges), 0)                 AS avg_discharges,
  ROUND(AVG(avg_inpatient_payment), 2)            AS avg_inpatient_cost,
  ROUND(AVG(avg_medicare_payments), 2)            AS avg_medicare_cost,
  ROUND(AVG(medicare_payment_ratio), 4)           AS avg_medicare_ratio,
  ROUND(AVG(distinct_drg_count), 1)               AS avg_drg_complexity
FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
GROUP BY provider_size_category, year
ORDER BY year, avg_inpatient_cost DESC;

-- ============================================================
-- KPI 6: Outpatient vs inpatient cost mix by state
-- ============================================================

SELECT
  state_code,
  year,
  ROUND(AVG(avg_inpatient_payment), 2)            AS avg_inpatient_cost,
  ROUND(AVG(avg_outpatient_payment), 2)           AS avg_outpatient_cost,
  ROUND(AVG(outpatient_volume_share_pct), 2)      AS outpatient_pct_of_volume,
  ROUND(AVG(combined_avg_cost), 2)                AS combined_cost
FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
GROUP BY state_code, year
ORDER BY outpatient_pct_of_volume DESC;

-- ============================================================
-- KPI 7: Medicare coverage efficiency by state
-- ============================================================

SELECT
  state_code,
  census_region,
  ROUND(AVG(medicare_payment_ratio), 4)           AS avg_medicare_ratio,
  ROUND(AVG(avg_inpatient_payment), 2)            AS avg_inpatient_cost,
  ROUND(AVG(avg_medicare_payments), 2)            AS avg_medicare_payment,
  SUM(total_discharges)                           AS total_discharges
FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
WHERE year = 2015
GROUP BY state_code, census_region
ORDER BY avg_medicare_ratio DESC;
