# Setup Guide

This guide walks you through deploying the League of Legends match analytics pipeline from scratch on Snowflake.

---

## Prerequisites

- A Snowflake account with `ACCOUNTADMIN` privileges (a free trial gives you 30 days)
- A GitHub account (just to browse/download release assets — no push access needed)
- The source CSV files downloaded locally

---

## Step 1 — Link a Snowflake Git Workspace to this Repo

1. In Snowsight, top left, click **Workspaces**, then the **+** to the right, then **Create new → Git Workspace**
2. In the form that pops up, fill in the **Repository URL**: `https://github.com/TotoriYoyori/league-snowflake` — the workspace name auto-fills
3. Under API Integration, click **+ API Integration** to create a new one:
   - Name: `GITHUB_TOTORI_YOYORI`
   - Allowed prefix: `https://github.com/TotoriYoyori/`
4. Select that API integration
5. Select **Public Repository** — this gives you read/fetch access only (no push, no changes)
6. Click **Create**

Once created, every file in the repo is fetched into your Workspace and browsable/openable directly from the file tree.

---

## Step 2 — Download the Seed Dataset

1. Go to the release page: **https://github.com/TotoriYoyori/league-snowflake/releases/tag/sample**
2. Under **Assets**, download the following files:
   - `matches_summary.csv` (~40K rows)
   - `players_summary.csv` (~400K rows)
   - `intervals.csv` (~2.1M rows)
   - `items_ref.csv` (635 rows)
   - `champions_ref.csv` (173 rows)
3. Save the files to `C:\postgres_staging\league\` (e.g. `C:\postgres_staging\league\matches_summary.csv`)

---

## Step 3 — Deploy the Pipeline

1. From your new Workspace, open `setup/01_deploy.sql`.
2. Run it top to bottom as ACCOUNTADMIN, using the Run button in the top left of the sheet editor.


It then builds all schemas, seed tables, bronze tables, stages, pipes, and procedures.
It does this using your Workspace's local copy of the repo files directly.

---

## Step 4 — Seed the Source Data

Open `setup/02_seed_source.sql` worksheet and run each section:

```sql
-- 1. Upload to table stages
PUT 'file://C:\postgres_staging\league\matches_summary.csv' @LEAGUE_RECORDS.SEED.%SEED_MATCHES_SUMMARY AUTO_COMPRESS = TRUE OVERWRITE = TRUE;
PUT 'file://C:\postgres_staging\league\players_summary.csv' @LEAGUE_RECORDS.SEED.%SEED_PLAYERS_SUMMARY AUTO_COMPRESS = TRUE OVERWRITE = TRUE;
PUT 'file://C:\postgres_staging\league\match_intervals.csv' @LEAGUE_RECORDS.SEED.%SEED_MATCH_INTERVALS AUTO_COMPRESS = TRUE OVERWRITE = TRUE;
PUT 'file://C:\postgres_staging\league\items_ref.csv' @LEAGUE_RECORDS.SEED.%SEED_ITEMS_REF AUTO_COMPRESS = TRUE OVERWRITE = TRUE;
PUT 'file://C:\postgres_staging\league\champions_ref.csv' @LEAGUE_RECORDS.SEED.%SEED_CHAMPIONS_REF AUTO_COMPRESS = TRUE OVERWRITE = TRUE;

-- 2. Load into seed tables
COPY INTO LEAGUE_RECORDS.SEED.SEED_MATCHES_SUMMARY FILE_FORMAT = LEAGUE_RECORDS.BRONZE.LEAGUE_CSV_FMT;
COPY INTO LEAGUE_RECORDS.SEED.SEED_PLAYERS_SUMMARY FILE_FORMAT = LEAGUE_RECORDS.BRONZE.LEAGUE_CSV_FMT;
COPY INTO LEAGUE_RECORDS.SEED.SEED_MATCH_INTERVALS FILE_FORMAT = LEAGUE_RECORDS.BRONZE.LEAGUE_CSV_FMT;
COPY INTO LEAGUE_RECORDS.SEED.SEED_ITEMS_REF FILE_FORMAT = LEAGUE_RECORDS.BRONZE.LEAGUE_CSV_FMT;
COPY INTO LEAGUE_RECORDS.SEED.SEED_CHAMPIONS_REF FILE_FORMAT = LEAGUE_RECORDS.BRONZE.LEAGUE_CSV_FMT;
```

---
## Step 5 — One-Time Load: Reference Data into Bronze
Reference tables (items, champions) go through their pipe just once. These are already included at the end of `setup/02_seed_source.sql`, but shown here for reference:
```sql
-- Stage reference data from seed
COPY INTO @LEAGUE_RECORDS.BRONZE.REFERENCE_STG/items_ref.csv
FROM (SELECT ITEM_ID, ITEM_NAME FROM LEAGUE_RECORDS.SEED.SEED_ITEMS_REF)
FILE_FORMAT = (TYPE = CSV HEADER = TRUE) OVERWRITE = TRUE SINGLE = TRUE;

COPY INTO @LEAGUE_RECORDS.BRONZE.REFERENCE_STG/champions_ref.csv
FROM (SELECT CHAMPION_ID, CHAMPION_NAME FROM LEAGUE_RECORDS.SEED.SEED_CHAMPIONS_REF)
FILE_FORMAT = (TYPE = CSV HEADER = TRUE) OVERWRITE = TRUE SINGLE = TRUE;

-- Refresh reference pipes
ALTER PIPE LEAGUE_RECORDS.BRONZE.ITEMS_REF_PP REFRESH;
ALTER PIPE LEAGUE_RECORDS.BRONZE.CHAMPIONS_REF_PP REFRESH;
```

---
## Step 6 — Activate the Bronze-to-Silver Tasks

Once the pipeline is deployed and seed data is loaded, activate the tasks that move data from bronze to silver. Open `setup/03_activate_tasks.sql` and run it:

```sql
ALTER TASK LEAGUE_RECORDS.SILVER.BRONZE_TO_SILVER_MATCHES_TASK RESUME;
ALTER TASK LEAGUE_RECORDS.SILVER.BRONZE_TO_SILVER_PLAYERS_TASK RESUME;
ALTER TASK LEAGUE_RECORDS.SILVER.BRONZE_TO_SILVER_ITEMS_TASK RESUME;
ALTER TASK LEAGUE_RECORDS.SILVER.BRONZE_TO_SILVER_CHAMPIONS_TASK RESUME;
ALTER TASK LEAGUE_RECORDS.SILVER.BRONZE_TO_SILVER_INTERVALS_TASK RESUME;
```

Tasks run on a 1-minute schedule and only fire when their respective bronze stream has new data.

---
## Step 7 — Simulate Daily Ingestion
Each call to `SIMULATE_DAILY_LOAD()` stages one day's worth of data (latest date first) across all three fact tables, then refreshes the pipes:
```sql
CALL LEAGUE_RECORDS.SEED.SIMULATE_DAILY_LOAD();
```

Example output:
```sql
Loaded date 2026-01-30. Next date: 2026-01-29 (min: 2024-06-15).
```

Call it repeatedly to ingest more days. The procedure tracks state automatically and stops when all dates are exhausted.

---

## Verifying the Pipeline

After running a few loads, check that bronze tables are populated:

```sql
SELECT COUNT(*) FROM LEAGUE_RECORDS.BRONZE.MATCHES_SUMMARY_BRONZE;
SELECT COUNT(*) FROM LEAGUE_RECORDS.BRONZE.PLAYERS_SUMMARY_BRONZE;
SELECT COUNT(*) FROM LEAGUE_RECORDS.BRONZE.MATCH_INTERVALS_BRONZE;
SELECT COUNT(*) FROM LEAGUE_RECORDS.BRONZE.ITEMS_REF_BRONZE;
SELECT COUNT(*) FROM LEAGUE_RECORDS.BRONZE.CHAMPIONS_REF_BRONZE;

-- Check load state
SELECT * FROM LEAGUE_RECORDS.SEED.SEED_LOAD_STATE;

-- Check pipe status
SHOW PIPES IN SCHEMA LEAGUE_RECORDS.BRONZE;
```