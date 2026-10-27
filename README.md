# World Layoffs: SQL Data Cleaning & Exploratory Data Analysis

An end-to-end SQL project in **MySQL** that takes a raw dataset of global layoffs, cleans it into an analysis-ready table, and then explores it to find trends by company, industry, location, country, funding stage, and time.

---

## 📌 Project Overview

| | |
|---|---|
| **Tool** | MySQL 8.0+ (MySQL Workbench) |
| **Database / schema** | `world_layoffs` |
| **Raw table** | `layoffs` |
| **Clean table** | `layoffs_staging2` |
| **Dataset** | [Layoffs 2022 on Kaggle](https://www.kaggle.com/datasets/swaptr/layoffs-2022) |
| **Skills used** | Staging tables, window functions (`ROW_NUMBER`, `DENSE_RANK`, running `SUM`), CTEs, self-joins, string & date functions, `GROUP BY` aggregation |

The project has two parts:

1. **Data cleaning** (`CLEANING DATA.sql`): turn messy raw data into a reliable table.
2. **Exploratory data analysis** (`analysis project.sql`): query the clean table to answer business questions.

---

## 📂 Repository Structure

```
├── CLEANING DATA.sql        # Part 1: data cleaning pipeline
├── analysis project.sql     # Part 2: exploratory data analysis
└── README.md
```

---

## 🗃️ Dataset

Each row is one layoff event.

| Column | Description |
|---|---|
| `company` | Company name |
| `location` | City |
| `industry` | Industry sector |
| `total_laid_off` | Number of employees laid off |
| `percentage_laid_off` | Share of the workforce laid off (`1` = 100%) |
| `date` | Date of the layoff |
| `stage` | Funding stage (Seed, Series A–J, Post-IPO, Acquired, etc.) |
| `country` | Country |
| `funds_raised_millions` | Total funding raised (USD millions) |

---

## 🧹 Part 1: Data Cleaning

The raw table is never modified. All work happens in staging copies, so the original data is always available if something goes wrong.

### Step 0: Create a staging table
```sql
CREATE TABLE world_layoffs.layoffs_staging LIKE world_layoffs.layoffs;

INSERT layoffs_staging
SELECT * FROM world_layoffs.layoffs;
```

### Step 1: Remove duplicates
The dataset has no unique ID column, so duplicates are found with `ROW_NUMBER()`.

- A first pass partitioned on only `company, industry, total_laid_off, date` flagged rows such as **Oda** that turned out **not** to be true duplicates, because their location or other details differed.
- Partitioning over **every** column identifies the real duplicates.

MySQL can't delete rows through a CTE. Instead, the data is copied into a second staging table (`layoffs_staging2`) with an extra `row_num` column, and the duplicates are deleted from there:

```sql
INSERT INTO world_layoffs.layoffs_staging2
SELECT *,
       ROW_NUMBER() OVER (
         PARTITION BY company, location, industry, total_laid_off, percentage_laid_off,
                      `date`, stage, country, funds_raised_millions
       ) AS row_num
FROM world_layoffs.layoffs_staging;

DELETE FROM world_layoffs.layoffs_staging2
WHERE row_num >= 2;
```

### Step 2: Standardize data
| Issue | Fix |
|---|---|
| Blank (`''`) industry values | Set to `NULL` |
| Missing industry where the same company has a known industry elsewhere (e.g. Airbnb) | Filled with a **self-join** |
| `Crypto`, `Crypto Currency`, `CryptoCurrency` | All set to `Crypto` |
| `United States` vs `United States.` | `TRIM(TRAILING '.' FROM country)` |
| `date` stored as text (`MM/DD/YYYY`) | `STR_TO_DATE(...)`, then `MODIFY COLUMN` to `DATE` |

Filling in missing industries:
```sql
UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
  ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;
```
After this, **Bally's** is the only company left with a `NULL` industry, because it has no other row to copy from.

### Step 3: Remove unusable rows and helper columns
- Rows where **both** `total_laid_off` and `percentage_laid_off` are `NULL` are deleted, since they carry no layoff information.
- The helper column `row_num` is dropped.

**Result:** `world_layoffs.layoffs_staging2` is a clean, de-duplicated table with consistent text values and a proper `DATE` column.

---

## 📊 Part 2: Exploratory Data Analysis

### Basic queries
- Largest single layoff (`MAX(total_laid_off)`)
- Range of `percentage_laid_off`
- Companies that laid off **100%** of staff, ordered by `funds_raised_millions` to show how large some of these companies were

### Aggregations with `GROUP BY`
- Top 5 biggest single layoff events
- Top 10 companies by total layoffs
- Top 10 locations by total layoffs
- Total layoffs by **country**, **year**, **industry**, and **funding stage**

### Advanced queries
**Top 3 companies by layoffs in each year** using chained CTEs and `DENSE_RANK()`:
```sql
WITH Company_Year AS (
  SELECT company, YEAR(date) AS years, SUM(total_laid_off) AS total_laid_off
  FROM layoffs_staging2
  GROUP BY company, YEAR(date)
), Company_Year_Rank AS (
  SELECT company, years, total_laid_off,
         DENSE_RANK() OVER (PARTITION BY years ORDER BY total_laid_off DESC) AS ranking
  FROM Company_Year
)
SELECT company, years, total_laid_off, ranking
FROM Company_Year_Rank
WHERE ranking <= 3
  AND years IS NOT NULL
ORDER BY years ASC, total_laid_off DESC;
```

**Rolling (cumulative) total of layoffs by month** using a window function:
```sql
WITH DATE_CTE AS (
  SELECT SUBSTRING(date, 1, 7) AS dates, SUM(total_laid_off) AS total_laid_off
  FROM layoffs_staging2
  GROUP BY dates
)
SELECT dates, SUM(total_laid_off) OVER (ORDER BY dates ASC) AS rolling_total_layoffs
FROM DATE_CTE
ORDER BY dates ASC;
```

---

## 🔍 Key Insights

- Companies with `percentage_laid_off = 1` were mostly **startups that went out of business**, some of which had raised large amounts of funding.
- A small number of large companies account for a large share of total layoffs.
- Ranking companies by year shows that the companies leading layoffs changed from year to year.
- The monthly rolling total shows how quickly layoffs accumulated over the period covered by the dataset.

---

## ▶️ How to Run

1. Install **MySQL 8.0+** (window functions require 8.0) and MySQL Workbench.
2. Create the schema:
   ```sql
   CREATE DATABASE world_layoffs;
   ```
3. Download the CSV from [Kaggle](https://www.kaggle.com/datasets/swaptr/layoffs-2022) and import it into a table named `layoffs` using the **Table Data Import Wizard**.
4. Run `CLEANING DATA.sql` from top to bottom.
5. Run the queries in `analysis project.sql`.

---

## 🛠️ SQL Concepts Demonstrated

- Staging tables to protect raw data
- `ROW_NUMBER()` for duplicate detection
- `DENSE_RANK()` for ranking within groups
- Running totals with `SUM() OVER (ORDER BY ...)`
- Common Table Expressions (CTEs), including chained CTEs
- Self-joins to fill in missing values
- String functions: `TRIM`, `SUBSTRING`, `LIKE`
- Date functions: `STR_TO_DATE`, `YEAR`
- Schema changes: `ALTER TABLE ... MODIFY COLUMN`, `ADD`, `DROP COLUMN`

---

## 👤 Author

**Rajula Vinay Kumar**
