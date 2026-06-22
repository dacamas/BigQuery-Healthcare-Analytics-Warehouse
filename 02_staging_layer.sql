-- FILE: 02_staging_layer.sql
-- Purpose: Clean and standardize raw CMS Medicare data (Silver layer)

-- ============================================================
-- stg_inpatient_charges
-- Combines 2014 + 2015 inpatient data, cleans and standardizes
-- ============================================================

CREATE OR REPLACE TABLE `healthcare-analytics-warehouse.healthcare_warehouse.stg_inpatient_charges` AS
SELECT
  TRIM(provider_id)                                     AS provider_id,
  TRIM(provider_name)                                   AS provider_name,
  TRIM(provider_street_address)                         AS provider_street_address,
  TRIM(provider_city)                                   AS provider_city,
  TRIM(provider_state)                                  AS provider_state,
  TRIM(provider_zipcode)                                AS provider_zipcode,
  TRIM(hospital_referral_region_description)            AS hrr_description,
  total_discharges,
  average_covered_charges                               AS avg_covered_charges,
  average_total_payments                                AS avg_total_payments,
  average_medicare_payments                             AS avg_medicare_payments,
  TRIM(drg_definition)                                  AS drg_definition,
  SAFE_CAST(SPLIT(TRIM(drg_definition), ' ')[OFFSET(0)] AS INT64) AS drg_code,
  2015                                                  AS data_year
FROM `bigquery-public-data.cms_medicare.inpatient_charges_2015`
WHERE
  provider_id IS NOT NULL
  AND total_discharges IS NOT NULL
  AND average_total_payments > 0
  AND average_total_payments < 1000000

UNION ALL

SELECT
  TRIM(provider_id),
  TRIM(provider_name),
  TRIM(provider_street_address),
  TRIM(provider_city),
  TRIM(provider_state),
  TRIM(provider_zipcode),
  TRIM(hospital_referral_region_description),
  total_discharges,
  average_covered_charges,
  average_total_payments,
  average_medicare_payments,
  TRIM(drg_definition),
  SAFE_CAST(SPLIT(TRIM(drg_definition), ' ')[OFFSET(0)] AS INT64),
  2014
FROM `bigquery-public-data.cms_medicare.inpatient_charges_2014`
WHERE
  provider_id IS NOT NULL
  AND total_discharges IS NOT NULL
  AND average_total_payments > 0
  AND average_total_payments < 1000000;

-- ============================================================
-- stg_outpatient_charges
-- ============================================================

CREATE OR REPLACE TABLE `healthcare-analytics-warehouse.healthcare_warehouse.stg_outpatient_charges` AS
SELECT
  TRIM(provider_id)                                        AS provider_id,
  TRIM(provider_name)                                      AS provider_name,
  TRIM(provider_city)                                      AS provider_city,
  TRIM(provider_state)                                     AS provider_state,
  SAFE_CAST(provider_zipcode AS STRING)                    AS provider_zipcode,
  TRIM(hospital_referral_region)                           AS hrr_description,
  TRIM(apc)                                                AS apc,
  outpatient_services,
  average_estimated_submitted_charges                      AS avg_submitted_charges,
  average_total_payments                                   AS avg_total_payments,
  2015                                                     AS data_year
FROM `bigquery-public-data.cms_medicare.outpatient_charges_2015`
WHERE
  provider_id IS NOT NULL
  AND average_total_payments > 0;

-- ============================================================
-- stg_physicians
-- One row per physician per HCPCS service code
-- ============================================================

CREATE OR REPLACE TABLE `healthcare-analytics-warehouse.healthcare_warehouse.stg_physicians` AS
SELECT
  TRIM(npi)                                              AS npi,
  TRIM(nppes_provider_last_org_name)                     AS provider_last_name,
  TRIM(nppes_provider_first_name)                        AS provider_first_name,
  TRIM(nppes_provider_city)                              AS provider_city,
  TRIM(nppes_provider_state)                             AS provider_state,
  TRIM(nppes_provider_zip)                               AS provider_zip,
  TRIM(nppes_entity_code)                                AS entity_code,
  TRIM(provider_type)                                    AS provider_type,
  TRIM(hcpcs_code)                                       AS hcpcs_code,
  TRIM(hcpcs_description)                                AS hcpcs_description,
  TRIM(place_of_service)                                 AS place_of_service,
  line_srvc_cnt                                          AS line_service_count,
  bene_unique_cnt                                        AS beneficiary_count,
  bene_day_srvc_cnt                                      AS beneficiary_day_service_count,
  average_medicare_allowed_amt                           AS avg_medicare_allowed,
  average_submitted_chrg_amt                             AS avg_submitted_charge,
  average_medicare_payment_amt                           AS avg_medicare_payment,
  average_medicare_standard_amt                          AS avg_medicare_standard,
  2014                                                   AS data_year
FROM `bigquery-public-data.cms_medicare.physicians_and_other_supplier_2014`
WHERE
  npi IS NOT NULL
  AND line_srvc_cnt > 0
  AND average_medicare_payment_amt > 0;
