-- FILE: 04_dimension_tables.sql
-- Purpose: Build star schema dimension tables

-- ============================================================
-- dim_provider
-- ============================================================

CREATE OR REPLACE TABLE `healthcare-analytics-warehouse.healthcare_warehouse.dim_provider` AS
WITH deduped AS (
  SELECT
    provider_id,
    provider_name,
    provider_city,
    provider_state,
    provider_zipcode,
    hrr_description,
    SUM(total_discharges) AS lifetime_discharges,
    ROW_NUMBER() OVER (PARTITION BY provider_id ORDER BY data_year DESC) AS rn
  FROM `healthcare-analytics-warehouse.healthcare_warehouse.stg_inpatient_charges`
  GROUP BY provider_id, provider_name, provider_city, provider_state, provider_zipcode, hrr_description, data_year
)
SELECT
  provider_id,
  provider_name,
  provider_city,
  provider_state,
  provider_zipcode,
  hrr_description,
  lifetime_discharges,
  CASE
    WHEN lifetime_discharges >= 10000 THEN 'Large'
    WHEN lifetime_discharges >= 2000  THEN 'Medium'
    ELSE 'Small'
  END AS provider_size_category
FROM deduped
WHERE rn = 1;

-- ============================================================
-- dim_region
-- ============================================================

CREATE OR REPLACE TABLE `healthcare-analytics-warehouse.healthcare_warehouse.dim_region` AS
WITH state_base AS (
  SELECT DISTINCT provider_state AS state_code
  FROM `healthcare-analytics-warehouse.healthcare_warehouse.stg_inpatient_charges`
  WHERE provider_state IS NOT NULL
)
SELECT
  state_code,
  CASE state_code
    WHEN 'CT' THEN 'Connecticut'    WHEN 'ME' THEN 'Maine'
    WHEN 'MA' THEN 'Massachusetts'  WHEN 'NH' THEN 'New Hampshire'
    WHEN 'RI' THEN 'Rhode Island'   WHEN 'VT' THEN 'Vermont'
    WHEN 'NJ' THEN 'New Jersey'     WHEN 'NY' THEN 'New York'
    WHEN 'PA' THEN 'Pennsylvania'   WHEN 'IL' THEN 'Illinois'
    WHEN 'IN' THEN 'Indiana'        WHEN 'MI' THEN 'Michigan'
    WHEN 'OH' THEN 'Ohio'           WHEN 'WI' THEN 'Wisconsin'
    WHEN 'IA' THEN 'Iowa'           WHEN 'KS' THEN 'Kansas'
    WHEN 'MN' THEN 'Minnesota'      WHEN 'MO' THEN 'Missouri'
    WHEN 'NE' THEN 'Nebraska'       WHEN 'ND' THEN 'North Dakota'
    WHEN 'SD' THEN 'South Dakota'   WHEN 'DE' THEN 'Delaware'
    WHEN 'FL' THEN 'Florida'        WHEN 'GA' THEN 'Georgia'
    WHEN 'MD' THEN 'Maryland'       WHEN 'NC' THEN 'North Carolina'
    WHEN 'SC' THEN 'South Carolina' WHEN 'VA' THEN 'Virginia'
    WHEN 'DC' THEN 'Washington DC'  WHEN 'WV' THEN 'West Virginia'
    WHEN 'AL' THEN 'Alabama'        WHEN 'KY' THEN 'Kentucky'
    WHEN 'MS' THEN 'Mississippi'    WHEN 'TN' THEN 'Tennessee'
    WHEN 'AR' THEN 'Arkansas'       WHEN 'LA' THEN 'Louisiana'
    WHEN 'OK' THEN 'Oklahoma'       WHEN 'TX' THEN 'Texas'
    WHEN 'AZ' THEN 'Arizona'        WHEN 'CO' THEN 'Colorado'
    WHEN 'ID' THEN 'Idaho'          WHEN 'MT' THEN 'Montana'
    WHEN 'NV' THEN 'Nevada'         WHEN 'NM' THEN 'New Mexico'
    WHEN 'UT' THEN 'Utah'           WHEN 'WY' THEN 'Wyoming'
    WHEN 'AK' THEN 'Alaska'         WHEN 'CA' THEN 'California'
    WHEN 'HI' THEN 'Hawaii'         WHEN 'OR' THEN 'Oregon'
    WHEN 'WA' THEN 'Washington'
    ELSE state_code
  END AS state_name,
  CASE state_code
    WHEN 'CT' THEN 'Northeast' WHEN 'ME' THEN 'Northeast'
    WHEN 'MA' THEN 'Northeast' WHEN 'NH' THEN 'Northeast'
    WHEN 'RI' THEN 'Northeast' WHEN 'VT' THEN 'Northeast'
    WHEN 'NJ' THEN 'Northeast' WHEN 'NY' THEN 'Northeast'
    WHEN 'PA' THEN 'Northeast'
    WHEN 'IL' THEN 'Midwest'   WHEN 'IN' THEN 'Midwest'
    WHEN 'MI' THEN 'Midwest'   WHEN 'OH' THEN 'Midwest'
    WHEN 'WI' THEN 'Midwest'   WHEN 'IA' THEN 'Midwest'
    WHEN 'KS' THEN 'Midwest'   WHEN 'MN' THEN 'Midwest'
    WHEN 'MO' THEN 'Midwest'   WHEN 'NE' THEN 'Midwest'
    WHEN 'ND' THEN 'Midwest'   WHEN 'SD' THEN 'Midwest'
    WHEN 'DE' THEN 'South'     WHEN 'FL' THEN 'South'
    WHEN 'GA' THEN 'South'     WHEN 'MD' THEN 'South'
    WHEN 'NC' THEN 'South'     WHEN 'SC' THEN 'South'
    WHEN 'VA' THEN 'South'     WHEN 'DC' THEN 'South'
    WHEN 'WV' THEN 'South'     WHEN 'AL' THEN 'South'
    WHEN 'KY' THEN 'South'     WHEN 'MS' THEN 'South'
    WHEN 'TN' THEN 'South'     WHEN 'AR' THEN 'South'
    WHEN 'LA' THEN 'South'     WHEN 'OK' THEN 'South'
    WHEN 'TX' THEN 'South'
    ELSE 'West'
  END AS census_region
FROM state_base;

-- ============================================================
-- dim_date
-- ============================================================

CREATE OR REPLACE TABLE `healthcare-analytics-warehouse.healthcare_warehouse.dim_date` AS
SELECT
  year_val                                      AS year,
  quarter_val                                   AS quarter,
  CONCAT(CAST(year_val AS STRING), '-Q', CAST(quarter_val AS STRING)) AS year_quarter_label,
  CASE quarter_val
    WHEN 1 THEN 'Q1 (Jan-Mar)'
    WHEN 2 THEN 'Q2 (Apr-Jun)'
    WHEN 3 THEN 'Q3 (Jul-Sep)'
    WHEN 4 THEN 'Q4 (Oct-Dec)'
  END AS quarter_label,
  CASE year_val WHEN 2014 THEN 1 WHEN 2015 THEN 2 ELSE NULL END AS year_index
FROM
  UNNEST(GENERATE_ARRAY(2014, 2015)) AS year_val,
  UNNEST(GENERATE_ARRAY(1, 4))       AS quarter_val;
