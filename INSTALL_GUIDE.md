# Setup Guide

This guide walks you through deploying the League of Legends match analytics pipeline from scratch on Snowflake.

---

## Prerequisites

- A Snowflake account with `ACCOUNTADMIN` privileges (a free trial gives you 30 days)
- A Snowsight worksheet (for running SQL and `PUT` commands)
- The source CSV files downloaded locally

---

## Step 1 — Download the Dataset

1. Go to the release page: **https://github.com/TotoriYoyori/league-snowflake/releases/tag/sample**
2. Under **Assets**, download the following files:
   - `matches_summary.csv` (~40K rows)
   - `players_summary.csv` (~400K rows)
   - `match_intervals.csv` (~2.1M rows)
   - `items_ref.csv` (635 rows)
   - `champions_ref.csv` (173 rows)
3. Note the local paths (e.g. `/Users/you/Downloads/matches_summary.csv`)

---

## Step 2 — Run Bootstrap

1. Open `setup/01_bootstrap.sql` in a **Snowsight SQL worksheet** (not inside a workspace)
2. Run it top to bottom as `ACCOUNTADMIN`

This creates:
- The `DV_COMPUTE_WH` warehouse
- The `LEAGUE_RECORDS` database
- A GitHub API integration pointing at this repo
- Fetches the repo and executes `setup/02_deploy.sql`, which builds all schemas, seed tables, bronze tables, stages, pipes, and procedures

---

## Step 3 — Seed the Source Data

Open `setup/03_seed_staging_tables.sql` in a **Snowsight worksheet** (PUT requires a classic worksheet).

Update the file paths and run each section:

```sql
-- 1. Upload to table stages
PUT file:///Users/you/Downloads/matches_summary.csv @LEAGUE_RECORDS.SEED.%SEED_MATCHES_SUMMARY AUTO_COMPRESS = TRUE OVERWRITE = TRUE;
PUT file:///Users/you/Downloads/players_summary.csv @LEAGUE_RECORDS.SEED.%SEED_PLAYERS_SUMMARY AUTO_COMPRESS = TRUE OVERWRITE = TRUE;
PUT file:///Users/you/Downloads/match_intervals.csv @LEAGUE_RECORDS.SEED.%SEED_MATCH_INTERVALS AUTO_COMPRESS = TRUE OVERWRITE = TRUE;
PUT file:///Users/you/Downloads/items_ref.csv @LEAGUE_RECORDS.SEED.%SEED_ITEMS_REF AUTO_COMPRESS = TRUE OVERWRITE = TRUE;
PUT file:///Users/you/Downloads/champions_ref.csv @LEAGUE_RECORDS.SEED.%SEED_CHAMPIONS_REF AUTO_COMPRESS = TRUE OVERWRITE = TRUE;

-- 2. Load into seed tables
COPY INTO LEAGUE_RECORDS.SEED.SEED_MATCHES_SUMMARY FILE_FORMAT = LEAGUE_RECORDS.BRONZE.LEAGUE_CSV_FMT;
COPY INTO LEAGUE_RECORDS.SEED.SEED_PLAYERS_SUMMARY FILE_FORMAT = LEAGUE_RECORDS.BRONZE.LEAGUE_CSV_FMT;
COPY INTO LEAGUE_RECORDS.SEED.SEED_MATCH_INTERVALS FILE_FORMAT = LEAGUE_RECORDS.BRONZE.LEAGUE_CSV_FMT;
COPY INTO LEAGUE_RECORDS.SEED.SEED_ITEMS_REF FILE_FORMAT = LEAGUE_RECORDS.BRONZE.LEAGUE_CSV_FMT;
COPY INTO LEAGUE_RECORDS.SEED.SEED_CHAMPIONS_REF FILE_FORMAT = LEAGUE_RECORDS.BRONZE.LEAGUE_CSV_FMT;
```

---

## Step 4 — Load Reference Data into Bronze

Reference tables (items, champions) go through their pipe just once:

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

## Step 5 — Simulate Daily Ingestion

Each call to `SIMULATE_DAILY_LOAD()` stages one day's worth of data (latest date first) across all three fact tables, then refreshes the pipes:

```sql
CALL LEAGUE_RECORDS.SEED.SIMULATE_DAILY_LOAD();
```

Example output:
```
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

---

## Deploy Order Reference

The `setup/02_deploy.sql` executes scripts in this order:

| # | Script | Creates |
|---|--------|---------|
| 1 | `infra/01_db_and_schema.sql` | Database + SEED/BRONZE/SILVER/GOLD schemas |
| 2 | `infra/02_seed_tables.sql` | Seed tables, date index view, load state |
| 3 | `bronze/01_matches_summary_bronze.sql` | Matches summary landing table |
| 4 | `bronze/02_players_summary_bronze.sql` | Players summary landing table |
| 5 | `bronze/03_match_intervals_bronze.sql` | Match intervals landing table |
| 6 | `bronze/04_references_bronze.sql` | Items + champions reference tables |
| 7 | `bronze/05_stages_and_pipes.sql` | File format, stages, pipes |
| 8 | `infra/03_simulate_daily_load.sql` | Staging procedures + orchestrator |
