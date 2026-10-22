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

## Exploratory Data Analysis

### Data Sources (`cleaned_data/`)
**`shop_data.csv`**: 1,500 retail transaction records across 2023[cite: 5].
**`cpi_data.csv`**: Consumer Price Index records (213 rows)[cite: 5].
**`inflation_data.csv`**: Monthly inflation metrics (201 rows)[cite: 5].
**`holidays_data.csv`**: Kenyan public holiday calendar (84 rows)[cite: 5].
**`population_data.csv`**: Official Kenya Population and Housing Census data structured by county and gender[cite: 5].

### What the notebook does `exploratory_data_analysis`

1. **Import data**: loads the five files.
2. **Build the county table**: turns the raw census file (one row per area and sex) into one row per county, 47 in total.
3. **Join shop and population data**: maps each shop town to its county (Nairobi, Roysambu and Umoja to Nairobi; Thika, Ruiru and Ruaka to Kiambu; Kitengela and Rongai to Kajiado), then merges the county population onto each order.
4. **Distributions**: order value, units per order, and unit price by product.
5. **Trends**: orders and average order value by month and by day.
6. **Seasonality**: weekday, day of month, pay-window and holiday effects.
7. **Stores, towns and counties**: revenue and order value by town, and orders against population by county.
8. **Products**: revenue share, price against order count, and product mix by town.
9. **Customer segments**: Budget, Regular and Premium compared on price paid, revenue share and product mix.
10. **Macro context**: shop prices compared with national CPI and inflation.

### Top findings

1. **Activity collapses after April.** January to April holds 84% of all orders (about 299 a month) against about 28 a month from May to December. Average order value stays flat, so it is lost volume, not smaller baskets.
2. **Three products carry 60% of revenue.** Eggs, cooking oil and sanitary towels are 34% of orders but 60% of revenue.
3. **Kajiado over-indexes, Nairobi under-indexes.** Kajiado has 14% of the three counties' population but 22% of orders (2.8 orders per 10,000 residents against 1.5 in Nairobi).
4. **Premium customers pay the least for the same product.** About 7% below the product median, while Budget customers pay about 2% above.
5. **Shop prices lag inflation.** The basket price rose about 3% over 2023 against CPI up 6.4%. With only 12 monthly points.

### Assumptions and limits

- The data has no store column, so the eight towns stand in for "stores".
- Rongai is taken to be Ongata Rongai (Kajiado). There is another (Rongai in Nakuru), 
- Census area names repeat across levels (for example KIAMBU is also a ward), so the county table keeps the largest row per county name. The 47 counties sum exactly to the national total of 47,564,296.
- Orders with zero quantity (78 of 1,500 rows) are not real sales and are excluded.
- No orders were found on 98 of 365 days, nearly all after April.
- The population figures are from the 2019 census, while the shop data is from 2023.

### Tech Stack & Libraries
* **Language:** Python
* **Data Manipulation:** `pandas`, `numpy`
* **Statistical Analysis:** `scipy.stats`
* **Visualization:** `matplotlib`, `seaborn`
























