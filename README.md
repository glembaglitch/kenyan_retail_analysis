# Customer and Sales Intelligence for a Kenyan Retailer

## Project Overview 
The project analyzes sales, customer behavior, and economic data for a growing Kenyan retail chain. The goal is to turn raw retail data into actionable insights, build predictive models, and deliver a comprehensive dashboard to guide management decisions.

## Business Questions 
- Who are the most valuable customers, and which ones are drifting away?
- Which categories and regions generate the highest revenue?
- How do external factors like population, inflation, public holidays and M-Pesa usage impact sales?
- What is the projected product demand for the upcoming month?

## Data Sources and Licensing
- **Sales Transactions:** Adapted from `kenya_online_shop_data(Kaggle)` covering 12+ months across Nairobi and other Kenyan sub-counties.
- **Economics Data:** Monthly CPI and inflation rates from `Kenya National Bureau of Statistics (KNBS)`.
- **Demographics:** 2019 Kenya Population and Housing Census from (KNBS) and Kenyan public holidays from the web.
- **Licensing:** Open data(public domain)

## Data Cleaning and Preparation
Raw datasets we're processed using python pipelines `notebooks/cleaning_pipeline.ipynb` that has the following:
- **Duplicates:** Scanned and removed duplicates from `Kenya population and Housing Census Population households density by county (KE1,DF_POP_CENSUS_COU,1.0)`
- **Blank Columns:** Scanned and removed unnecessary columns from `Kenya population and Housing Census Population households density by county (KE1,DF_POP_CENSUS_COU,1.0)`

The other datasets had everything in order after running `basic_ckecks`.

### Before and After Summary
- `kenya_online_shop_data`, `kenya_cpi_values_2009-01-01_to_2026-09-01`, `kenya_cpi_inflation_rates_2009-01-01_to_2026-09-01`, and `kenya_public_holidays_2020_2026` had everything in order, hence no changes we're made.
- `Kenya population and Housing Census Population households density by county (KE1,DF_POP_CENSUS_COU,1.0)` :
    - Before: `Shape(42507, 13)`
    - After: `Shape(40491, 8)`
    - Duplicates we're removed and unnecessary columns, which we're mainly blank we're removed.
 
### Processed Data Output
All cleaned datasets are saved separately from raw data to ensure raw records remain untouched.
- Output directory: `cleaned_data`
- Files generated:
   - `cleaned_data/shop_data`
   - `cleaned_data/population_data`
   - `cleaned_data/inflation_data`
   - `cleaned_data/holidays_data`
   - `cleaned_data/cpi_data`























