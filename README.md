# Kenyan Retail Analysis

## Project Overview

This project analyzes 2023 sales for a Kenyan retail business alongside public holiday, census, CPI, and inflation data. It combines data preparation, exploratory analysis, demand forecasting, statistical tests, SQL analytics, and a Power BI dashboard to support retail decisions.

## Business Questions

- How do sales vary by time, product, customer segment, and location?
- Which products and customer segments contribute the most revenue?
- How do public holidays, population, CPI, and inflation relate to sales?
- Can daily product demand be forecast from recent sales and calendar features?

## Project Layout

```text
00_raw_data/       Source CSV and Excel files
01_cleaned_data/   Prepared CSV files used by analysis notebooks
02_notebooks/      Cleaning, EDA, forecasting, and statistical notebooks
03_SQL_analysis/   PostgreSQL analytics script
04_Dashboard/      Power BI report and dashboard Q&A document
README.md
```

## Data Sources

| Data | Source file | Source / use |
|---|---|---|
| Retail transactions | `kenyan_online_shop_data.csv` | Online shop dataset; transaction, product, customer, and location analysis |
| Population | `Kenya population and Housing Census Population households density by county (KE1,DF_POP_CENSUS_COU,1.0).csv` | Kenya National Bureau of Statistics (KNBS), 2019 census |
| Inflation | `kenya_cpi_inflation_rates_2009-01-01_to_2026-09-01.csv` | National monthly inflation series |
| CPI | `kenya_cpi_values_2009-01-01_to_2026-09-01.csv` | National monthly Consumer Price Index series |
| Public holidays | `kenya_public_holidays_2020_2026.xlsx` | Holiday dates used to flag sales and build calendar features |

The source files are stored in `00_raw_data/`. The cleaning notebook writes its outputs to `01_cleaned_data/`.

## Notebook Workflow

Run the notebooks in this order. The forecasting and statistical notebooks depend on the prepared files created by the cleaning notebook.

### 1. Data Cleaning and Preparation

Notebook: [`02_notebooks/cleanig_pipeline.ipynb`](02_notebooks/cleanig_pipeline.ipynb)

The pipeline profiles the input files, parses transaction dates and numeric fields, checks missing values and duplicates, reviews quantity and unit-price outlier candidates, and prepares calendar, holiday, revenue, and county fields for analysis.

For the retail data, the source has 1,500 rows. The notebook finds no invalid dates or numeric values, saves the 78 zero-quantity rows separately, and excludes them from sales analysis, leaving 1,422 rows. The IQR check flags 29 quantity candidates and no unit-price candidates; these are listed for review and not automatically removed. For the census data, it removes 2,016 duplicate rows while preparing the county population table, which contains 47 counties.

The notebook saves these files in `01_cleaned_data/`:

- `shop_data.csv` — sales rows with derived calendar, holiday, revenue, and county fields
- `zero_quantity_rows.csv` — the 78 zero-quantity records excluded from sales analysis
- `population_data.csv` and `county_population.csv` — census source data and the 47-county population table
- `inflation_data.csv` and `cpi_data.csv` — national monthly series
- `holidays_data.csv` — holiday calendar

### 2. Exploratory Data Analysis

Notebook: [`02_notebooks/exploratory_data_analysis.ipynb`](02_notebooks/exploratory_data_analysis.ipynb)

The analysis loads the prepared sales, CPI, inflation, holiday, and county population files. It examines transaction distributions, monthly and daily patterns, holiday and pay-window effects, towns and counties, product mix, customer segments, and shop prices against national CPI.

Key findings from the notebook:

- **Sales are concentrated early in the year:** January–April account for 84% of orders, averaging 299 orders per month; May–December average 28. There are no orders on 98 of the 365 days.
- **A few products contribute much of revenue:** eggs, cooking oil, and sanitary towels together account for about 60% of revenue and 34% of orders.
- **Budget is the largest revenue segment:** it represents 59.1% of customers and 61.1% of revenue. Premium has the highest average order value (KES 209.92) and averages 1.71 units per order, even though its unit prices average 0.927 times the median for each product.
- **Order values vary across towns, but the notebook does not find a statistically significant difference** (Kruskal–Wallis p = 0.135). The customer-type mix does vary by location.
- **Shop prices rose more slowly than CPI by the notebook’s trend estimate:** the estimated shop-price drift is 3.2% from January to December 2023, compared with a 6.4% CPI increase. This comparison uses only 12 monthly observations.

Analysis assumptions and limits:

- The sales data contains town/location names but no store identifier, so the eight locations are used as the geographic units.
- The notebook maps Kitengela and Rongai to Kajiado; Nairobi, Roysambu, and Umoja to Nairobi; and Ruaka, Ruiru, and Thika to Kiambu.
- Rongai is assumed to refer to Ongata Rongai in Kajiado.
- The population data is from the 2019 census, while the transactions are from 2023. County names can also appear as lower-level census areas, so the county table selects the largest matching population rows.
- The sales decline after April is visible in the data, but the notebooks do not establish its cause.

### 3. Retail Demand Forecasting

Notebook: [`02_notebooks/predictive_model.ipynb`](02_notebooks/predictive_model.ipynb)

The notebook aggregates transactions into daily total quantity, fills calendar dates with no orders as zero, and adds weekday, month, weekend, holiday, lagged-demand, and rolling-window features. It compares a Random Forest regressor with lag-7 and training-mean baselines using a chronological split. The validation period is October 2–December 31, 2023.

| Model | RMSE (units/day) | MAE (units/day) |
|---|---:|---:|
| Lag-7 baseline | 1.52 | 1.11 |
| Training-mean baseline | 3.94 | 3.80 |
| Random Forest | 1.19 | 0.94 |

The Random Forest scores lower error than the lag-7 baseline on this holdout. The notebook also reports WAPE of 100.2%; daily average demand falls from 4.72 units in training to 0.93 in validation. This sharp change and the high WAPE are important limits when interpreting the forecast. Five-fold time-series validation also shows the Random Forest beating the lag-7 baseline on folds 1–4; both models perform poorly on the first fold, which has little training history.

### 4. Statistical Analysis

Notebook: [`02_notebooks/statistical_analysis.ipynb`](02_notebooks/statistical_analysis.ipynb)

The notebook tests differences in transaction value by customer type, holiday, weekend, and location; tests the relationship between customer type and location; estimates confidence intervals; examines monthly sales and inflation; and fits an OLS model with residual diagnostics. It also repeats segment comparisons after aggregating to the customer level.

Selected results:

- Premium transactions average about KES 209.92 versus KES 150.23 for non-Premium transactions. The mean difference is KES 59.69 (95% CI: KES 20.12–99.27); Welch’s test is significant (p = 0.002), while the Mann–Whitney result is borderline (p = 0.068).
- Average transaction value does not differ significantly by holiday, weekend, or location in the notebook’s tests.
- Customer type is associated with location (chi-square p < 0.001); this is an association, not evidence that location causes customer-type differences.
- The 95% confidence interval for mean transaction value is KES 149.31–161.21. The Wilson interval for the share of zero-quantity rows is 4.2%–6.4%.
- Monthly sales correlate with inflation in the 2023 data, but the sharp sales decline after April makes that relationship fragile and unsuitable for a causal interpretation.
- At the customer level, total spend differs across segments (ANOVA p = 0.021); average order value also differs (ANOVA p < 0.001).

## Running the Notebooks

1. Install Python and Jupyter, then install the notebook libraries:

   ```bash
   pip install pandas numpy scipy statsmodels matplotlib seaborn scikit-learn openpyxl jupyter
   ```

2. Keep the source files in `00_raw_data/` and ensure `01_cleaned_data/` exists.
3. The notebooks currently contain absolute Windows paths. Update the file paths in their import and output cells to match your local project folder.
4. Run `cleanig_pipeline.ipynb` first, then run the EDA, forecasting, and statistical notebooks from top to bottom.

## SQL Analytics

The PostgreSQL script is [`03_SQL_analysis/sql_analysis.sql`](03_SQL_analysis/sql_analysis.sql). It creates the `sql_analysis` schema, imports raw tables, prepares clean analysis tables, and includes queries for KPIs, product and location summaries, holiday and macroeconomic joins, market baskets, time-based window analyses, customer cohorts, and RFM segmentation. The script creates the `v_sales_enriched` reporting view for BI tools.

To run it, create a PostgreSQL database, run the script’s setup section, import the CSV data into the corresponding `raw_*` tables, follow the column-renaming steps, then execute the remaining sections in order.

## Dashboard

The Power BI report is [`04_Dashboard/kr_dashboard.pbix`](04_Dashboard/kr_dashboard.pbix). It summarizes revenue, quantity, invoices, customers, locations, customer types, products, monthly sales, and RFM segments. The accompanying [`04_Dashboard/kenyan-retail-qa-insights.docx`](04_Dashboard/kenyan-retail-qa-insights.docx) contains questions the dashboard is designed to answer.

Open the report in Power BI Desktop, update its data-source paths if prompted, and refresh the report. Slicers let users filter by date, customer type, location, and product.
