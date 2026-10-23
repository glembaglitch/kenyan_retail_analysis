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

### How to run
1. Install the libraries:
 ```
 pip install pandas numpy matplotlib seaborn scipy 
 ```
2. Update the file paths in the "Import data" cell to where your CSVs are.
3. Run the notebook from top to bottom (Run All). The order matters, because later cells use tables built earlier

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

### How to run
1. **Open the environment:** Launch Jupyter Notebook or JupyterLab on your machine.
2. **Set up files:** Ensure the dataset files (`shop_data.csv`, `inflation_data.csv`, `holidays_data.csv`, `cpi_data.csv`, `population_data.csv`) are placed in the `cleaned_data` folder on your desktop.
3. **Check paths:** Verify that the file path match your local directory structure.
4. **Install dependencies:** Confirm that required libraries (`pandas`, `numpy`, `matplotlib`, `seaborn`, `scipy`) are installed in your Python environment.
5. **Run all cells:** Execute the notebook cells sequentially from top to bottom to load libraries, merge data, and generate the analysis and visualizations.

## SQL Analytics
### Schema design and Data Pipeline
The project operates under `sql_analysis` schema and transforms raw data imports into clean, normalized analysis tables.

### Cleaned Analysis Tables
- `shop_clean`: Transaction level detailed cleaned of nulls, negative quantities/prices and duplicate line items. Key primary key `line_id`.
- `cpi_clean` & `inflation_clean`: Time series macroeconomic data normalized to monthly dates(`period_month`).
- `holidays_clean`: Calendar table of national holidays used to uvaluate holiday demand lift.
- `population_clean`: Regional census data used to callcute revenue per capita.
- `rfm_segmments`:Persistent customer scoring table based on Recency, Frequency and Monetary scores(1 to 5 scale).

### Key Business Analysis & SQL Implementation
**A. Core Aggregation & KPIs**
- *Overal Metrics*: Compute aggregate revenue, total orders, distinct customers, Average Order Value (AOV), and Units per Order.
- *DimensionalBreakdown*: Revenue cut by product, region/location, customer type, and time dimensions (day of week, hour of day).

**B. Analytical Joins**
- *Macro Intergration(`c_cpi_monthly`, `v_inflation_monthly`)*: Combines monthly sales with CPI data to calculate real life inflation-adjusted revenue growth.
- *Holiday Lift Analysis*: Joins holiday dates with sales to compare average daily revenue on regular vs. holiday days and 3-day pre-holiday windows.
- *Population Normalization*: Evaluates regional market penetration by calculating revenue per capita against official census population figures.
- *Market Basket Analysis*: Self-joins `shop_clean` to identify co-purchased product pairs at the invoice level and customer level.

**C. Window Functions**
- *Growth & MoM Trends*: Utilizes `LAG()` and moving averages over 3-month frames to measure revenue momentum and MoM growth rate.
- *Ranking & Pareto Distribution*: Uses `DENSE_RANK()` for top three products per location and `RANK()`/`NTILE()` to verify revenue concentration (Pareto principle).
- *Customer Lifetime Value & Recency*: Uses windowed `ROW_NUMBER()`, cumulative `SUM()` and `LAG()` to track order sequencing and inter-purchase intervals.

**D. Customer Cohorts & Retention Analysis**
- Tracks customer acquisition month cohorts(`cohort_month`) using `MIN(invoice_month)`.
- Generates a Retention Matrix (Heatmap) showing active customer drop-off over 0 to 60 months post-acquisition.
- Analyzes revenue expansion per active customer across cohort lifecycles

**E. RFM Segmentation**
Customers are categorized into 10 actionable marketing tiers based on `NTILE(5)` scores across Recency, Frequency and Monetary value:
   - *Champions*: High recency, frequency and spend (R $\ge$ 4, F $\ge$ 4, M $\ge$ 4).
   - *Loyal Customers/Potential Loyalists*: Stable repeat purchasers.
   - *At Risk/Can't Loose them*: High historical monetary spend with lagging recent activity.
   - *Hibernating/Lost*: Low scores across all dimensions.

### Reporting View and Execution
To support downstreamm dashboard, a unified wide reporting view `v_sals_enriched` is created.
It pre-joins sales transactions with holiday flags, inflation trends, and RFM segments, backed by database indexes on `customer_id`, `invoice_no`, and date keys for query perfomance.

### How to run
1. Create a PostgreSQL database 
2. Run the script's section 1 to create the raw_* tables (all columns text).
3. Import each CSV into its raw_* table with DBeaver (Import Data > CSV). Check every column maps to existing, not skip.
4. Run the rest of sql_analysis.sql in order

## Statistical Analysis
(`statistical_analysis.ipynb`) notebook that uses hypothesis tests, confidence intervals and simple regression to answer practical questions about  sales, with the assumptions checked and a plain-language conclusion for each test.

### What's in the notebook

| # | Question | Methods |
|---|----------|---------|
| 1 | Do Premium customers pay more per transaction? | Shapiro-Wilk, Welch t-test, Mann-Whitney U, 95% CI for the difference |
| 2 | Does average spend differ across Budget / Regular / Premium? | One-way ANOVA, Levene, Tukey HSD |
| 3 | Do sales differ on public holidays? | Welch t-test, Mann-Whitney U |
| 4 | Do weekends differ from weekdays? | Welch t-test, Mann-Whitney U |
| 5 | Does spend differ across the 8 locations? | ANOVA, Kruskal-Wallis, Tukey HSD |
| 6 | Is customer type linked to location? | Chi-square test, heatmap |
| 7 | What is the overall mean transaction value, and how common are zero-quantity rows? | t-based CI, Wilson CI |
| 8 | Do monthly sales move with inflation? | Pearson and Spearman correlation |
| 9 | What drives transaction value? | Correlation, OLS regression, residual diagnostics |
| 10 | Do segments differ when each customer counts once? | Customer-level aggregation, ANOVA |

### Data files
- `shop_data.csv`: 1,500 invoices (product, quantity, price, date, location, customer type)
- `holidays_data.csv`: Kenyan public holidays
- `inflation_data.csv`: national monthly inflation rate

### Key Features
- **Comprehensive Hypothesis Testing:** Utilizes both parametric and non-parametric tests (Welch t-tests, Mann-Whitney U, ANOVA, and Kruskal-Wallis) to handle varying data distributions.   
- **Robust Diagnostic Checks:** Validates statistical assumptions including normality (Shapiro-Wilk, Jarque-Bera), homoscedasticity (Levene, Breusch-Pagan), and autocorrelation (Durbin-Watson).   
- **Multi-Level Segmentation:** Analyzes performance across temporal factors (weekends, holidays, inflation trends), geographical segments, and customer-level aggregation.
- **Predictive Modeling:** Implements OLS regression with proper feature encoding and complete residual diagnostics (Residuals vs. Fitted, QQ-plots, Scale-Location). 

### Key findings
- **Premium customers spend more per transaction**, by about KES 60 (CI roughly 20 to 99). The rank-based test is borderline (p = 0.068), so the evidence is moderate.
- **Segment spend differs** (ANOVA p < 0.001): Premium is above both Budget and Regular, while Budget and Regular are not clearly different.
- **No clear effect** of public holidays, weekends or location on transaction value.
- **Customer type is linked to location** (chi-square p < 0.001).
- **Monthly sales and inflation correlate**, but sales collapse after April, so this shouldn't be read as inflation driving sales.
- **Customer-level check:** segments still differ in total spend (p = 0.021).

### How to run
1. Clone the repository and navigate to the project directory.
2. Install the required dependencies:
```
pip install pandas numpy scipy statsmodels matplotlib seaborn
```
3. Open the Jupyter Notebook to run the pipeline:
```
jupyter notebook notebooks/statistical_analysis.ipynb
```

## Retail Demand Forecasting Model
A time-series demand forecasting project built on sales transactions and national holiday data from Kenyan retail operations. This project establishes a naive baseline and evaluates a machine learning model using a strict, time-aware validation split.

### Overview
- **Goal:** Predict daily total item quantity demanded (`Quantity`).
- **Data Source:** Kenyan retail store transactions (`shop_data.csv`) enriched with calendar holiday data (`holidays_data.csv`).
- **Validation Strategy:** Chronological time-based split to avoid data leakage.
  - **Train:** Jan 1, 2023 – Sep 30, 2023
  - **Validation:** Oct 1, 2023 – Dec 31, 2023

### Feature Engineering
1. **Calendar Features:** Day of week, Month, Is Weekend, Is Holiday (`IsHoliday`).
2. **Lagged Demand:** Lags for 1 day (`lag_1`), 7 days (`lag_7`), and 14 days (`lag_14`).
3. **Rolling Statistics:** 7-day rolling mean (`roll_mean_7`) and 7-day rolling standard deviation (`roll_std_7`).

### Model Performance & Results
Models were evaluated on unseen test data (Q4 2023) using **Root Mean Squared Error (RMSE)** and **Mean Absolute Error (MAE)**:

| Model | RMSE | MAE |
| :--- | :---: | :---: |
| **Baseline** (Lag-7 Persistence) | 1.51 | 1.11 |
| **Random Forest Model** | **1.30** | **0.90** |

The Random Forest model reduced absolute prediction error by **18.9%** over the naive baseline.

### Model Limitations & Error Analysis
What the model struggles with:
1. **Unpredictable Demand Spikes:** Sudden, unannounced bulk purchases deviate from rolling window estimates.
2. **Post-Holiday Dropoffs:** Sharply declining demand immediately following holidays can cause slight overestimation due to lagging features.

### How to Run
1. **Install Dependencies:**
   ```bash
   pip install pandas numpy scikit-learn
   ```
2. **Directory Setup:**
   Place `shop_data.csv` and `holidays_data.csv` in your specified data path.
3. **Execution:**
   Run the Jupyter Notebook cells sequentially to aggregate data, engineer features, evaluate the baseline, and fit the model.
















