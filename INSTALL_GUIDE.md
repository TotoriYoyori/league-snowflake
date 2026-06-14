# Setup Guide

This guide walks you through deploying the League of Legends match analytics pipeline from scratch on Snowflake.

---

## Prerequisites

- A Snowflake account with `ACCOUNTADMIN` privileges (a free trial gives you 30 days)
- A Snowsight worksheet (for running SQL and `PUT` commands)

---

## What's in `bootstrap/`

Copy the contents of the `bootstrap/` folder into your own Snowflake workspace and run the scripts in order:

| # | File | What it does |
|---|---|---|
| 1 | `bootstrap.sql` | Creates the warehouse, database, GitHub integration, fetches the repo, and runs `deploy.sql` |
| 2 | `deploy.sql` | Executed automatically by `bootstrap.sql` — builds schemas, tables, stages, file formats, streams, and tasks |
| 3 | `04_seed_staging_table.sql` | Uploads the downloaded CSV into `@DAILY_MATCH_SEED_STG` |

---

## Step 1 — Download the Dataset

1. Go to the release page: **https://github.com/TotoriYoyori/league-snowflake/releases/tag/sample**
2. Under **Assets**, download `intervals.csv` to your local machine
3. Note the full local path (e.g. `/Users/you/Downloads/intervals.csv`)

The file is ~250 MB and contains 2.1 million match interval snapshots.

---

## Step 2 — Copy `bootstrap/` to Your Workspace and Run

1. Create a new Snowflake workspace (or use an existing one)
2. Copy the contents of the `bootstrap/` folder into it
3. Open `bootstrap.sql` in a **SQL worksheet** and run it top to bottom as `ACCOUNTADMIN`

This creates:
- The `DV_COMPUTE_WH` warehouse
- The `LEAGUE_RECORDS` database
- A GitHub API integration pointing at this repo
- Fetches the repo and executes `deploy.sql`, which builds all schemas, tables, streams, tasks, file formats, and stages

4. Open `04_seed_staging_table.sql` in a **Snowsight worksheet** (not a Notebook — `PUT` requires a classic worksheet to read from your local filesystem)
5. Update the `PUT` path to match where you saved the file, then run:

```sql
PUT file:///Users/you/Downloads/intervals.csv @DAILY_MATCH_SEED_STG
    AUTO_COMPRESS = TRUE
    OVERWRITE = TRUE;
```

This uploads the full dataset into `@DAILY_MATCH_SEED_STG`. This stage holds the original, complete dataset only.

---

## Simulating Daily Ingestion

In production, league clients upload a new batch of match records each day (e.g. `match_20250601.csv`, `match_20250602.csv`). These land in `@DAILY_MATCH_AZSTG`, which triggers the stream/task pipeline.

To simulate this, `tools/simulate_stream.py` reads from the seed stage, splits the data into daily-sized chunks, and uploads each chunk to `@DAILY_MATCH_AZSTG`. Each upload triggers the stream → task pipeline and populates `HUB_INTERVALS` and `SAT_INTERVALS` automatically.

### How to schedule this in Snowflake

Rather than running a Python script locally on a cron, you can keep this entirely inside Snowflake using a **Task + Stored Procedure**:

1. A **Python stored procedure** reads from `@DAILY_MATCH_SEED_STG`, picks the next chunk of rows, and writes it to `@DAILY_MATCH_AZSTG` as `chunk_{YYYYMMDD}.csv`
2. A **Snowflake Task** runs that procedure on a daily schedule (e.g. `SCHEDULE = 'USING CRON 0 6 * * * UTC'`)

This way Snowflake handles the scheduling natively — no external orchestrator, no local machine running overnight. The existing stream/task pipeline picks up each new file automatically.

> This is planned but not yet implemented in this repo. For now, run `simulate_stream.py` manually or on a local cron.

---

## Verifying the Pipeline

After seeding and running the simulate script, check that each layer is populated:

```sql
-- Staging layer
SELECT COUNT(*) FROM LEAGUE_RECORDS.L00_STG.STG_INTERVALS;

-- Raw Data Vault
SELECT COUNT(*) FROM LEAGUE_RECORDS.L10_RDV.HUB_INTERVALS;
SELECT COUNT(*) FROM LEAGUE_RECORDS.L10_RDV.SAT_INTERVALS;

-- Stream status
SHOW STREAMS IN DATABASE LEAGUE_RECORDS;
```

Key things to check:
- `STG_INTERVALS` has rows after the first chunk lands in `@DAILY_MATCH_AZSTG`
- `HUB_INTERVALS` and `SAT_INTERVALS` populate within ~1 minute (the task runs on a 1-minute schedule)
- The stream shows as active

---

## Architecture Reference

For a full explanation of the pipeline architecture, the data vault modeling approach, and the production Azure ingestion pattern this demo simulates, see `README.md`.

The Azure integration (`infrastructure/02a_azure_integrated_stage.sql`) documents what `@DAILY_MATCH_AZSTG` would be replaced with in production — an Azure Blob Storage stage with Snowpipe auto-ingest triggered by Event Grid.
