-- FILE: 07_window_functions_advanced.sql
-- Purpose: Advanced window function patterns for analytics engineering interviews

-- ============================================================
-- 1. RANK() + DENSE_RANK() + ROW_NUMBER()
-- Provider cost ranking within each state
-- ============================================================

SELECT
  provider_id,
  provider_name,
  state_code,
  year,
  ROUND(avg_inpatient_payment, 2)                                               AS avg_cost,
  ROW_NUMBER() OVER (PARTITION BY state_code, year ORDER BY avg_inpatient_payment DESC)
    AS row_num,
  RANK()       OVER (PARTITION BY state_code, year ORDER BY avg_inpatient_payment DESC)
    AS cost_rank,
  DENSE_RANK() OVER (PARTITION BY state_code, year ORDER BY avg_inpatient_payment DESC)
    AS cost_dense_rank
FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
WHERE year = 2015
QUALIFY RANK() OVER (PARTITION BY state_code, year ORDER BY avg_inpatient_payment DESC) <= 5
ORDER BY state_code, cost_rank;

-- ============================================================
-- 2. LAG() / LEAD() — Year-over-year cost change per provider
-- ============================================================

SELECT
  provider_id,
  provider_name,
  state_code,
  year,
  ROUND(avg_inpatient_payment, 2)                                               AS avg_cost,
  ROUND(LAG(avg_inpatient_payment)  OVER (PARTITION BY provider_id ORDER BY year), 2)
    AS prev_year_cost,
  ROUND(LEAD(avg_inpatient_payment) OVER (PARTITION BY provider_id ORDER BY year), 2)
    AS next_year_cost,
  ROUND(avg_inpatient_payment - LAG(avg_inpatient_payment) OVER (
    PARTITION BY provider_id ORDER BY year), 2)                                 AS yoy_change,
  ROUND(SAFE_DIVIDE(
    avg_inpatient_payment - LAG(avg_inpatient_payment) OVER (PARTITION BY provider_id ORDER BY year),
    NULLIF(LAG(avg_inpatient_payment) OVER (PARTITION BY provider_id ORDER BY year), 0)
  ) * 100, 2)                                                                   AS yoy_pct_change
FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
ORDER BY provider_id, year;

-- ============================================================
-- 3. Rolling average — 2-year rolling avg cost by state
-- ============================================================

WITH state_yearly AS (
  SELECT
    state_code,
    census_region,
    year,
    ROUND(AVG(avg_inpatient_payment), 2)          AS avg_cost,
    SUM(total_discharges)                         AS total_discharges
  FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
  GROUP BY state_code, census_region, year
)
SELECT
  state_code,
  census_region,
  year,
  avg_cost,
  ROUND(AVG(avg_cost) OVER (
    PARTITION BY state_code
    ORDER BY year
    ROWS BETWEEN 1 PRECEDING AND CURRENT ROW
  ), 2)                                           AS rolling_2yr_avg_cost,
  SUM(total_discharges) OVER (
    PARTITION BY state_code
    ORDER BY year
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  )                                               AS cumulative_discharges
FROM state_yearly
ORDER BY state_code, year;

-- ============================================================
-- 4. NTILE() — Bucket providers into cost quartiles
-- ============================================================

SELECT
  provider_id,
  provider_name,
  state_code,
  census_region,
  provider_size_category,
  ROUND(avg_inpatient_payment, 2)                 AS avg_cost,
  NTILE(4)  OVER (ORDER BY avg_inpatient_payment) AS cost_quartile,
  NTILE(10) OVER (ORDER BY avg_inpatient_payment) AS cost_decile,
  CASE NTILE(4) OVER (ORDER BY avg_inpatient_payment)
    WHEN 1 THEN 'Low cost (Q1)'
    WHEN 2 THEN 'Below average (Q2)'
    WHEN 3 THEN 'Above average (Q3)'
    WHEN 4 THEN 'High cost (Q4)'
  END                                             AS cost_quartile_label
FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
WHERE year = 2015
ORDER BY avg_inpatient_payment;

-- ============================================================
-- 5. PERCENT_RANK() + CUME_DIST()
-- ============================================================

SELECT
  provider_id,
  provider_name,
  state_code,
  ROUND(avg_inpatient_payment, 2)                 AS avg_cost,
  ROUND(PERCENT_RANK() OVER (ORDER BY avg_inpatient_payment) * 100, 1)
    AS cost_percentile,
  ROUND(CUME_DIST() OVER (ORDER BY avg_inpatient_payment) * 100, 1)
    AS cumulative_dist_pct
FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
WHERE year = 2015
ORDER BY avg_inpatient_payment DESC
LIMIT 50;

-- ============================================================
-- 6. Partitioned aggregation — provider vs state average
-- ============================================================

SELECT
  provider_id,
  provider_name,
  state_code,
  year,
  ROUND(avg_inpatient_payment, 2)                 AS provider_cost,
  ROUND(AVG(avg_inpatient_payment) OVER (
    PARTITION BY state_code, year
  ), 2)                                           AS state_avg_cost,
  ROUND(avg_inpatient_payment - AVG(avg_inpatient_payment) OVER (
    PARTITION BY state_code, year
  ), 2)                                           AS diff_from_state_avg,
  ROUND(SAFE_DIVIDE(
    avg_inpatient_payment,
    NULLIF(AVG(avg_inpatient_payment) OVER (PARTITION BY state_code, year), 0)
  ) * 100 - 100, 1)                               AS pct_above_state_avg
FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
WHERE year = 2015
ORDER BY pct_above_state_avg DESC;

-- ============================================================
-- 7. Rolling sum — cumulative discharges by region
-- ============================================================

WITH region_yearly AS (
  SELECT
    census_region,
    year,
    SUM(total_discharges)                         AS yearly_discharges
  FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
  GROUP BY census_region, year
)
SELECT
  census_region,
  year,
  yearly_discharges,
  SUM(yearly_discharges) OVER (
    PARTITION BY census_region
    ORDER BY year
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  )                                               AS cumulative_discharges,
  ROUND(SAFE_DIVIDE(
    yearly_discharges,
    SUM(yearly_discharges) OVER (PARTITION BY year)
  ) * 100, 2)                                     AS pct_of_national_volume
FROM region_yearly
ORDER BY census_region, year;
