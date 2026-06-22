-- FILE: 05_fact_table.sql
-- Purpose: Build the core analytics fact table — fact_healthcare_metrics
-- Grain: one row per provider per year

CREATE OR REPLACE TABLE `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics` AS
WITH provider_enriched AS (
  SELECT
    pc.provider_id,
    pc.provider_state                                   AS state_code,
    pc.data_year                                        AS year,
    pc.provider_name,
    pc.provider_city,
    pc.distinct_drg_count,
    pc.total_discharges,
    pc.avg_inpatient_payment,
    pc.avg_medicare_payments,
    pc.medicare_payment_ratio,
    pc.total_outpatient_services,
    pc.avg_outpatient_payment,
    pc.total_patient_volume,
    dp.provider_size_category,
    dr.census_region,
    ROUND(SAFE_DIVIDE(
      pc.avg_inpatient_payment,
      NULLIF(pc.avg_medicare_payments, 0)
    ), 4)                                               AS inpatient_to_medicare_ratio,
    ROUND(SAFE_DIVIDE(
      pc.total_outpatient_services,
      NULLIF(pc.total_patient_volume, 0)
    ), 4)                                               AS outpatient_volume_share
  FROM `healthcare-analytics-warehouse.healthcare_warehouse.int_provider_combined` pc
  LEFT JOIN `healthcare-analytics-warehouse.healthcare_warehouse.dim_provider` dp
    ON pc.provider_id = dp.provider_id
  LEFT JOIN `healthcare-analytics-warehouse.healthcare_warehouse.dim_region` dr
    ON pc.provider_state = dr.state_code
)
SELECT
  provider_id,
  state_code,
  year,
  provider_name,
  provider_city,
  provider_size_category,
  census_region,
  total_discharges,
  total_outpatient_services,
  total_patient_volume,
  distinct_drg_count,
  ROUND(avg_inpatient_payment, 2)                       AS avg_inpatient_payment,
  ROUND(avg_medicare_payments, 2)                       AS avg_medicare_payments,
  ROUND(avg_outpatient_payment, 2)                      AS avg_outpatient_payment,
  medicare_payment_ratio,
  inpatient_to_medicare_ratio,
  ROUND(outpatient_volume_share * 100, 2)               AS outpatient_volume_share_pct,
  ROUND(SAFE_DIVIDE(
    (avg_inpatient_payment * total_discharges)
      + (avg_outpatient_payment * total_outpatient_services),
    NULLIF(total_patient_volume, 0)
  ), 2)                                                 AS combined_avg_cost,
  CURRENT_TIMESTAMP()                                   AS loaded_at
FROM provider_enriched;

-- Verification
SELECT
  year,
  COUNT(*)                              AS row_count,
  COUNT(DISTINCT provider_id)           AS providers,
  COUNT(DISTINCT state_code)            AS states,
  ROUND(AVG(avg_inpatient_payment), 2)  AS overall_avg_inpatient_cost
FROM `healthcare-analytics-warehouse.healthcare_warehouse.fact_healthcare_metrics`
GROUP BY year
ORDER BY year;
