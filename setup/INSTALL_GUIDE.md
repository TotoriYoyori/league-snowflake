# Install Guide

You can get the full pipeline running in about 10 minutes.

Let's go step by step.

---

## Prerequisites

You need:

* A **Snowflake account** with `ACCOUNTADMIN` role (a free trial works perfectly)
* A **GitHub account** (just to download files — no push access needed)

That's it. Everything else runs inside Snowflake.

---

## Create the Workspace

First, you'll connect this repo to Snowflake as a **Workspace** so you can run the SQL files directly.

In Snowsight:

1. Click **Workspaces** (top-left nav)
2. Click **+** → **Create new → Git Workspace**
3. Paste the repository URL:

```
https://github.com/TotoriYoyori/league-snowflake
```

4. Under **API Integration**, click **+ API Integration** and create one:
   * Name: `GITHUB_TOTORI_YOYORI`
   * Allowed prefix: `https://github.com/TotoriYoyori/`
5. Select **Public Repository**
6. Click **Create**

You'll now see every file in the repo in your Workspace file tree.

> **Info:** The workspace fetches a read-only copy of the repo. You can open and run any `.sql` file directly from the tree.

---

## Deploy the Pipeline

Open `setup/01_deploy.sql` from the file tree, then **Run All**.

```sql
-- That's it. One file deploys everything:
-- ✓ LEAGUE_RECORDS database
-- ✓ SEED, BRONZE, SILVER, GOLD schemas
-- ✓ Seed tables + upload stage
-- ✓ Bronze tables, streams, stages, pipes
-- ✓ Silver cleaning views, tables, tasks
-- ✓ All stored procedures
```

> **Tip:** Make sure you're running as `ACCOUNTADMIN` with a warehouse selected (e.g. `COMPUTE_WH`). The script handles the rest.

---

## Download the Data

Go to the **GitHub releases** page:

👉 **https://github.com/TotoriYoyori/league-snowflake/releases/tag/sample**

Download these 5 files under **Assets**:

| File | Rows | Size |
|------|------|------|
| `matches_summary.csv.gz` | ~40K | 1 MB |
| `players_summary.csv.gz` | ~400K | 2.5 MB |
| `intervals.csv.gz` | ~2.1M | ~64 MB |
| `items_ref.csv.gz` | 635 | 6 KB |
| `champions_ref.csv.gz` | 173 | 2 KB |

---

## Upload to the Seed Stage

Now you'll put those files into Snowflake.

In Snowsight, navigate to:

**Databases → LEAGUE_RECORDS → SEED → Stages → SEED_UPLOAD_STG**

Click **+ Files** and upload all 5 files you just downloaded.

That's the only manual step. Everything after this is automated SQL.

> **Tip:** The files can be in any order. The stage just needs to see these prefixes: `matches_summary`, `players_summary`, `intervals`, `items_ref`, `champions_ref`.

---

## Load the Seed Data

Open `setup/02_seed_source.sql` and **Run All**.

Here's what happens under the hood:

1. **Validation guard** — calls `SEED.VALIDATE_SEED_UPLOAD()` which checks the stage for all 5 required files. If anything is missing, it stops with a clear error:

```
Missing files in @SEED.SEED_UPLOAD_STG: intervals, champions_ref.
Upload via Snowsight UI before running 02_seed_source.sql.
```

2. **COPY INTO** — loads each file into its seed table

3. **Verify** — shows row counts:

```
SEED_MATCHES_SUMMARY    | 39,954
SEED_PLAYERS_SUMMARY    | 399,540
SEED_MATCH_INTERVALS    | 2,115,696
SEED_ITEMS_REF          | 635
SEED_CHAMPIONS_REF      | 173
```

4. **Reference bootstrap** — stages items/champions into their bronze pipes (one-time)

> **Warning:** If the validation fails, don't skip it and run the COPY statements manually. Go back and upload the missing files first. The COPY INTO will succeed on empty stage paths without error — it'll just load zero rows silently.

---

## Activate the Tasks

Open `setup/03_activate_tasks.sql` and **Run All**.

This resumes 5 tasks that move data from bronze → silver:

```sql
ALTER TASK SILVER.BRONZE_TO_SILVER_MATCHES_TASK RESUME;
ALTER TASK SILVER.BRONZE_TO_SILVER_PLAYERS_TASK RESUME;
ALTER TASK SILVER.BRONZE_TO_SILVER_ITEMS_TASK RESUME;
ALTER TASK SILVER.BRONZE_TO_SILVER_CHAMPIONS_TASK RESUME;
ALTER TASK SILVER.BRONZE_TO_SILVER_INTERVALS_TASK RESUME;
```

Each task runs on a **1-minute schedule** and only fires when its bronze stream has new data. No data in the stream? It skips — no cost.

---

## Simulate Daily Ingestion

The seed tables hold the *full* historical dataset. The `SIMULATE_DAILY_LOAD()` procedure stages **one day at a time**.

Note that for this pipeline the **latest date is ingested first then going backward** because the number of records are sparse on older dates, while more recent dates allows you to ingest more records, but the idea of daily simulation is the same.

### 👉 Open `run_daily_ingestion.sql` at the workspace root and click **Run All**.

That's the only file you need going forward. Run it once per simulated day.

Output:
```
Loaded date 2026-01-30. Next: 2026-01-29
```

Run it again → next day loads. And again. Keep going as many days as you want.

**What happens each time you run it:**

1. Picks the next date from the seed
2. Stages CSVs for matches, players, and intervals
3. Refreshes all 3 bronze pipes
4. Advances the date pointer

> **Info:** The procedure tracks its own state in `SEED.SEED_LOAD_STATE`. It stops automatically when all dates are exhausted — you'll see a message saying so.

---

## Check That It Works

After a few loads, verify data is flowing through each layer:

```sql
-- How much data landed in bronze?
SELECT COUNT(*) FROM LEAGUE_RECORDS.BRONZE.MATCHES_SUMMARY_BRONZE;
SELECT COUNT(*) FROM LEAGUE_RECORDS.BRONZE.PLAYERS_SUMMARY_BRONZE;
SELECT COUNT(*) FROM LEAGUE_RECORDS.BRONZE.MATCH_INTERVALS_BRONZE;

-- Did the tasks fire and populate silver?
SELECT COUNT(*) FROM LEAGUE_RECORDS.SILVER.MATCHES_SUMMARY_SILVER;
SELECT COUNT(*) FROM LEAGUE_RECORDS.SILVER.PLAYERS_SUMMARY_SILVER;
SELECT COUNT(*) FROM LEAGUE_RECORDS.SILVER.TEAM_INTERVAL_SILVER;
SELECT COUNT(*) FROM LEAGUE_RECORDS.SILVER.PLAYER_INTERVAL_SILVER;

-- Where are we in the simulation?
SELECT * FROM LEAGUE_RECORDS.SEED.SEED_LOAD_STATE;
```

> **Tip:** If silver tables are empty but bronze has data, wait 1-2 minutes for the tasks to fire. You can check task history with:
>
> ```sql
> SELECT NAME, STATE, QUERY_START_TIME
> FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
>     SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP())
> ))
> ORDER BY QUERY_START_TIME DESC;
> ```

---

## Recap

Here's the full flow you just set up:

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│   SEED   │────▶│  BRONZE  │────▶│  SILVER  │────▶│   GOLD   │
│          │     │          │     │          │     │ (planned) │
│ Full CSV │     │ Raw +    │     │ Cleaned  │     │           │
│ dataset  │     │ metadata │     │ enriched │     │           │
└──────────┘     └──────────┘     └──────────┘     └──────────┘
      │                │                │
 SIMULATE_        Pipes load       Tasks merge
 DAILY_LOAD()     from stage       from stream
```

Each layer is independent. You can re-run `01_deploy.sql` to rebuild everything from scratch at any time.
