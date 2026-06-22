# BigQuery Healthcare Analytics Warehouse

A production-style data warehouse built entirely in BigQuery SQL, using real public CMS Medicare datasets. Demonstrates layered warehouse architecture, star schema design, advanced SQL, and business KPI development.

---

## Architecture

```
bigquery-public-data (CMS Medicare)
        │
        ▼
┌─────────────────┐
│   RAW LAYER     │  Direct references to public dataset tables
│   (Bronze)      │  No transformations
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ STAGING LAYER   │  SAFE_CAST, null filtering, column renaming,
│   (Silver)      │  type standardization, outlier removal
└────────┬────────┘
         │
         ▼
┌──────────────────────┐
│ INTERMEDIATE LAYER   │  Cross-dataset joins, feature engineering,
│   (Silver+)          │  provider-level + state-level aggregations
└────────┬─────────────┘
         │
         ▼
┌─────────────────┐
│   MART LAYER    │  Star schema: fact_healthcare_metrics +
│   (Gold)        │  dim_provider, dim_region, dim_date
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    ANALYTICS    │  KPI queries, window functions, data quality checks
└─────────────────┘
```

---

## Data Sources

All data comes from `bigquery-public-data.cms_medicare` — publicly available in BigQuery at no cost.

| Table | Description |
|---|---|
| `inpatient_charges_2014` | Hospital inpatient DRG-level charges and payments, 2014 |
| `inpatient_charges_2015` | Hospital inpatient DRG-level charges and payments, 2015 |
| `outpatient_charges_2015` | Hospital outpatient APC-level charges and payments, 2015 |
| `physicians_and_other_supplier_2014` | Physician-level service counts and payment amounts, 2014 |

---

## Data Model

Star schema with one fact table and three dimensions.

### Fact Table: `fact_healthcare_metrics`

Grain: one row per provider per year.

| Column | Description |
|---|---|
| `provider_id` | FK to dim_provider |
| `state_code` | FK to dim_region |
| `year` | FK to dim_date |
| `total_discharges` | Inpatient discharge count |
| `avg_inpatient_payment` | Average total inpatient payment |
| `avg_medicare_payments` | Average Medicare reimbursement |
| `total_outpatient_services` | Outpatient service count |
| `avg_outpatient_payment` | Average outpatient payment |
| `medicare_payment_ratio` | Medicare paid ÷ covered charges |
| `combined_avg_cost` | Volume-weighted blended cost |

### Dimensions

**dim_provider** — hospital name, city, state, HRR region, size category (Small/Medium/Large by discharge volume)

**dim_region** — state code, state name, US census region (Northeast/South/Midwest/West)

**dim_date** — year, quarter, labels for time-series analysis

---

## Key Insights

Based on the 2014–2015 CMS Medicare data:

1. **Northeast and California providers consistently charge more.** States like NY, CA, and MA average 30–40% above the national mean for inpatient payments, while Southern states tend to run below average.

2. **Large hospitals are not always lower cost.** Medium-sized providers (2,000–10,000 discharges) show comparable or lower average costs vs large providers, suggesting volume alone does not drive efficiency.

3. **Medicare payment ratios vary significantly by state.** Some states show Medicare reimbursing as low as 25–30% of covered charges, while others are closer to 50%, reflecting negotiated rates and regional policy differences.

4. **Year-over-year cost growth was uneven.** Several states saw 5–10% cost increases from 2014 to 2015 while others remained flat, pointing to local market conditions and provider consolidation as key drivers.

---

## SQL Highlights

### SAFE_CAST with null filtering (staging)
```sql
SAFE_CAST(average_total_payments AS FLOAT64)
WHERE SAFE_CAST(average_total_payments AS FLOAT64) > 0
```

### Window functions (07_window_functions_advanced.sql)
- `RANK()` / `DENSE_RANK()` / `ROW_NUMBER()` — provider cost ranking within state
- `LAG()` / `LEAD()` — year-over-year cost change per provider
- Rolling averages with `ROWS BETWEEN N PRECEDING AND CURRENT ROW`
- `NTILE(4)` / `NTILE(10)` — cost quartile and decile bucketing
- `PERCENT_RANK()` / `CUME_DIST()` — national percentile position
- Partitioned aggregation — provider vs state average comparison

### QUALIFY clause (BigQuery-specific)
```sql
QUALIFY RANK() OVER (PARTITION BY state_code ORDER BY avg_inpatient_payment DESC) <= 5
```

---

## How to Run

### Prerequisites
- A Google Cloud account with BigQuery enabled
- A BigQuery project and dataset created (free tier works for exploration)

### Steps

1. Open [BigQuery Console](https://console.cloud.google.com/bigquery)
2. Run `01_data_exploration.sql` as-is — it reads directly from public data, no setup needed
3. For all other files, find-and-replace `your_project.your_dataset` with your actual project ID and dataset name
4. Run files in order: `02` → `03` → `04` → `05` → `06` → `07` → `08`
5. Each `CREATE OR REPLACE TABLE` statement writes results to your dataset
6. Run `08_data_quality_checks.sql` last to validate the pipeline

### Cost note
BigQuery charges per bytes scanned. The CMS Medicare tables are small (under 500MB total). Running the full pipeline should cost under $0.01 on a paid project, and is free within the 1TB/month free tier.

---

## Project Structure

```
bigquery-healthcare-warehouse/
├── 01_data_exploration.sql       # Row counts, schema inspection, distributions
├── 02_staging_layer.sql          # SAFE_CAST, null filtering, standardization
├── 03_intermediate_models.sql    # Cross-dataset joins, feature engineering
├── 04_dimension_tables.sql       # dim_provider, dim_region, dim_date
├── 05_fact_table.sql             # fact_healthcare_metrics (star schema core)
├── 06_kpi_queries.sql            # 7 business KPI queries
├── 07_window_functions_advanced.sql  # 7 advanced window function patterns
├── 08_data_quality_checks.sql    # Null, duplicate, referential, outlier checks
└── README.md
```
