-- FILE: 06_tableau_views.sql
-- Purpose: BigQuery Views optimized for Tableau connection
-- Run once — Tableau queries these live

-- ============================================================
-- VIEW 1: vw_cost_by_state
-- Use for: filled map, bar chart by state
-- ============================================================

CREATE OR REPLACE VIEW `healthcare-analytics-warehouse.healthcare_warehouse.vw_cost_by_state` AS
SELECT
  state_code,
  census_region,
  year,
  COUNT(DISTINCT provider_id)                     AS provider_count,
  SUM(total_discharges)                           AS total_discharges,
  ROUND(AVG(avg_inpatient_payment), 2)            AS avg_inpatient_cost,
  ROUND(AVG(avg_outpatient_payment), 2)           AS avg_outpatient_cost,
  ROUND(AVG(avg_medicare_payments), 2)            AS avg_medicare_payment,
  ROUND(AVG(medicare_payment_ratio), 4)           AS avg_medicare_ratio,
  ROUND(AVG(combined_avg_cost), 2)                AS avg_combined_cost,
  ROUND(AVG(outpatient_volume_share_pct), 2)      AS outpatient_pct_of_volume
FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
GROUP BY state_code, census_region, year;

-- ============================================================
-- VIEW 2: vw_provider_details
-- Use for: scatter plot (cost vs volume), provider drill-down
-- ============================================================

CREATE OR REPLACE VIEW `healthcare-analytics-warehouse.healthcare_warehouse.vw_provider_details` AS
SELECT
  provider_id,
  provider_name,
  provider_city,
  state_code,
  census_region,
  provider_size_category,
  year,
  total_discharges,
  total_outpatient_services,
  total_patient_volume,
  distinct_drg_count,
  ROUND(avg_inpatient_payment, 2)                 AS avg_inpatient_cost,
  ROUND(avg_medicare_payments, 2)                 AS avg_medicare_cost,
  ROUND(avg_outpatient_payment, 2)                AS avg_outpatient_cost,
  ROUND(combined_avg_cost, 2)                     AS combined_avg_cost,
  medicare_payment_ratio,
  outpatient_volume_share_pct,
  ROUND(PERCENT_RANK() OVER (
    PARTITION BY year ORDER BY avg_inpatient_payment
  ) * 100, 1)                                     AS national_cost_percentile
FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`;

-- ============================================================
-- VIEW 3: vw_yoy_change
-- Use for: YoY bar chart, diverging color highlight table
-- ============================================================

CREATE OR REPLACE VIEW `healthcare-analytics-warehouse.healthcare_warehouse.vw_yoy_change` AS
WITH yearly AS (
  SELECT
    state_code,
    census_region,
    year,
    ROUND(AVG(avg_inpatient_payment), 2)          AS avg_cost,
    SUM(total_discharges)                         AS total_discharges,
    COUNT(DISTINCT provider_id)                   AS provider_count
  FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
  GROUP BY state_code, census_region, year
)
SELECT
  y2015.state_code,
  y2015.census_region,
  y2014.avg_cost                                  AS avg_cost_2014,
  y2015.avg_cost                                  AS avg_cost_2015,
  ROUND(y2015.avg_cost - y2014.avg_cost, 2)       AS absolute_change,
  ROUND(SAFE_DIVIDE(
    y2015.avg_cost - y2014.avg_cost,
    NULLIF(y2014.avg_cost, 0)
  ) * 100, 2)                                     AS pct_change,
  y2015.total_discharges                          AS discharges_2015,
  CASE
    WHEN SAFE_DIVIDE(y2015.avg_cost - y2014.avg_cost, NULLIF(y2014.avg_cost,0)) * 100 > 3
      THEN 'Increasing'
    WHEN SAFE_DIVIDE(y2015.avg_cost - y2014.avg_cost, NULLIF(y2014.avg_cost,0)) * 100 < -3
      THEN 'Decreasing'
    ELSE 'Stable'
  END                                             AS cost_trend
FROM yearly y2015
JOIN yearly y2014
  ON y2015.state_code = y2014.state_code
  AND y2015.year = 2015
  AND y2014.year = 2014;

-- ============================================================
-- VIEW 4: vw_region_summary
-- Use for: region KPI cards, region vs national benchmark
-- ============================================================

CREATE OR REPLACE VIEW `healthcare-analytics-warehouse.healthcare_warehouse.vw_region_summary` AS
WITH region_data AS (
  SELECT
    census_region,
    year,
    COUNT(DISTINCT provider_id)                   AS provider_count,
    SUM(total_patient_volume)                     AS total_patient_volume,
    SUM(total_discharges)                         AS total_discharges,
    ROUND(AVG(avg_inpatient_payment), 2)          AS avg_inpatient_cost,
    ROUND(AVG(avg_outpatient_payment), 2)         AS avg_outpatient_cost,
    ROUND(AVG(combined_avg_cost), 2)              AS avg_combined_cost,
    ROUND(AVG(medicare_payment_ratio), 4)         AS avg_medicare_ratio
  FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
  GROUP BY census_region, year
),
national AS (
  SELECT year, ROUND(AVG(avg_inpatient_payment), 2) AS national_avg_cost
  FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
  GROUP BY year
)
SELECT
  r.*,
  n.national_avg_cost,
  ROUND(r.avg_inpatient_cost - n.national_avg_cost, 2)    AS diff_from_national,
  ROUND(SAFE_DIVIDE(
    r.avg_inpatient_cost - n.national_avg_cost,
    NULLIF(n.national_avg_cost, 0)
  ) * 100, 1)                                             AS pct_above_national
FROM region_data r
JOIN national n ON r.year = n.year;

-- ============================================================
-- VIEW 5: vw_size_category_comparison
-- Use for: grouped bar chart Small/Medium/Large by year
-- ============================================================

CREATE OR REPLACE VIEW `healthcare-analytics-warehouse.healthcare_warehouse.vw_size_category_comparison` AS
SELECT
  provider_size_category,
  year,
  COUNT(DISTINCT provider_id)                     AS provider_count,
  ROUND(AVG(total_discharges), 0)                 AS avg_discharges,
  ROUND(AVG(avg_inpatient_payment), 2)            AS avg_inpatient_cost,
  ROUND(AVG(avg_medicare_payments), 2)            AS avg_medicare_cost,
  ROUND(AVG(avg_outpatient_payment), 2)           AS avg_outpatient_cost,
  ROUND(AVG(medicare_payment_ratio), 4)           AS avg_medicare_ratio,
  ROUND(AVG(distinct_drg_count), 1)               AS avg_drg_complexity,
  ROUND(AVG(outpatient_volume_share_pct), 2)      AS avg_outpatient_share_pct
FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
GROUP BY provider_size_category, year
ORDER BY year, avg_inpatient_cost DESC;
