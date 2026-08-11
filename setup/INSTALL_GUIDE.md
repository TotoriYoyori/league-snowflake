## Prerequisites

* A **Snowflake account** with `ACCOUNTADMIN` role (a free trial works perfectly)


---

## 01. Create the Workspace

First, you'll connect this repo to Snowflake as a **Workspace** so you can run the SQL files directly.

In Snowsight:

1. Click **Workspaces** (top-left nav)
2. Click **+** → **Create new → Git Workspace**
3. In the resulting window, fill out the forms exactly as shown:
   * Repository URL: `https://github.com/TotoriYoyori/league-snowflake`
   * Workspace name: `league-snowflake`
   
![Create new workspace](../assets/setup/setup_00_create_workspace.png)

4. Click **+ API Integration** and fill out the form as followed, then hit **Create**.
   * Name: `GITHUB_TOTORI_YOYORI`
   * Allowed prefix: `https://github.com/TotoriYoyori/`

![Create new API integration](../assets/setup/setup_01_create_api_int.png)

5. You will then go back to the previous screen to complete your workspace. Select the API integration `GITHUB_TOTORI_YOYORI`
you just created (it should be auto-populated), select **Public Repository** and hit **Create**.

> **Warning:** Keep the Workspace name exactly `league-snowflake` (Snowsight defaults to this from the repo URL,
don't rename it!). Every `EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/...'` 
call in `01_deploy.sql` depends on this name. See picture below for example of this name.

![Connect API to workspace and create](../assets/setup/setup_02_connect_api_to_workspace.png)

You'll now see every file in the repo in your Workspace file tree.

> **Info:** The workspace fetches a read-only copy of the repo (that means no pushing). You can open and run 
any `.sql` file directly from the tree. 

---
## 02. Deploy the Pipeline

Open `setup/01_deploy.sql` from the file tree, then hit **Run All** at the top left.

---

## 03. Download the Data

Go to the **GitHub releases** page:

**https://github.com/TotoriYoyori/league-snowflake/releases/tag/sample**

**Download these 5 files under Assets:**

| File | Rows | Size |
|------|------|------|
| `matches_summary.csv.gz` | ~40K | 1 MB |
| `players_summary.csv.gz` | ~400K | 2.5 MB |
| `intervals.csv.gz` | ~2.1M | ~64 MB |
| `items_ref.csv.gz` | 635 | 6 KB |
| `champions_ref.csv.gz` | 173 | 2 KB |

---

## 04. Upload to the Seed Stage

Now you'll put those files into Snowflake.

In Snowsight, in the sidebar to the left, navigate to:

**Catalog → Databases → LEAGUE_RECORDS → SEED → Stages → UPLOAD_STG**

**Click + Files and upload all 5 files you just downloaded.**

That's the only manual step. Everything after this is automated SQL.

> **Tip:** The files can be in any order. The stage just needs to see these prefixes: `matches_summary`, 
`players_summary`, `intervals`, `items_ref`, `champions_ref`.

Internal-stage directory listings can lag a few seconds behind an upload. If `02_seed_source.sql`'s validation 
step (next) reports a file missing right after you just uploaded it, wait a moment and re-run rather than assuming 
the upload failed.

---
## 05. Load the Seed Data

**Open `setup/02_seed_source.sql` and Run All.**

Here's what happens under the hood:

1. **Validation guard**: calls `SEED.VALIDATE_SEED_UPLOAD()`, which checks the stage for all 5 required files.
If anything is missing or duplicated, it halts the script with a Snowflake compilation error whose object name
encodes exactly which files are missing (and any duplicates found) — e.g. an error mentioning
`MISSING_FILES___INTERVALS__CHAMPIONS_REF___...`. That's expected behavior, not a bug: upload the missing file(s)
and re-run.

2. **Load into seed tables**: `COPY INTO` for each of the 5 seed tables (`SEED.MATCHES`, `SEED.PLAYERS`,
`SEED.INTERVALS`, `SEED.ITEMS_REF`, `SEED.CHAMPIONS_REF`) from the matching file on the stage.

![SEED schema populated with all 6 tables](../assets/img/seed_table.png)

3. **Reference bootstrap**: the two small reference tables (`items_ref`, `champions_ref`) get staged and loaded
one time straight into their Bronze tables, since they don't go through the daily simulation.

4. **Kickstart**: calls `SEED.SIMULATE_DAILY_LOAD()` once, staging the first simulated day's matches/players/intervals 
straight into Bronze. Tasks aren't active yet (next step), so this data just sits in the Bronze streams for now.

> **Warning:** If the validation fails, don't skip it and run the COPY statements manually. Go back and upload the 
missing files first. The COPY INTO will succeed on empty stage paths without error. It'll just load zero rows silently.

---
## 06. Activate the Tasks

**Open `setup/03_activate_tasks.sql` and Run All.**

This resumes all the tasks that move data from bronze → silver, since all tasks start suspended after first created.

```sql
ALTER TASK SILVER.BRONZE_TO_SILVER_MATCHES_TASK RESUME;
ALTER TASK SILVER.BRONZE_TO_SILVER_PLAYERS_TASK RESUME;
ALTER TASK SILVER.BRONZE_TO_SILVER_ITEMS_REF_TASK RESUME;
ALTER TASK SILVER.BRONZE_TO_SILVER_CHAMPIONS_REF_TASK RESUME;
ALTER TASK SILVER.BRONZE_TO_SILVER_INTERVALS_TASK RESUME;
```

Each task runs on a **1-minute schedule** and only fires when its bronze stream has new data. No data in the stream? 
It skips, no cost accrued.

> **Tip:** The previous step already staged one day of data into Bronze, so these tasks have real work waiting 
the moment they're resumed. Give it a minute or two for the first scheduled run to actually fire, then head to 
[Check That It Works](#check-that-it-works) below.

---
## 07. Deploy the Streamlit Apps

**Open `setup/04_create_streamlit_app.sql` and Run All**, same context as before (`ACCOUNTADMIN`, a warehouse selected).

### Find your apps
In Snowsight, in the sidebar: **Projects → Streamlit**, or run:

```sql
SHOW STREAMLITS IN DATABASE LEAGUE_RECORDS;
```

![All three Streamlit apps registered in Snowsight](../assets/img/streamlit_app_browse.png)

Click any app name to open it. Each opens against the `STREAMLIT_WH` warehouse created above.
First load may take a few seconds for the warehouse to figure things out. Also note that **the pipeline needs
time to process new data**, so it might take up to 5 minutes before your app picks up new data and loads correctly.

----
# How to Use
This section covers the following:
1. How to use the simulated daily ingestion system
2. Verify that the pipeline is working
3. How to rebuild the pipeline

## Simulate Daily Ingestion

The seed tables hold the *full* historical dataset. The `SIMULATE_DAILY_LOAD()` procedure stages **one day at a time**.

Note that for this pipeline the **latest date is ingested first then going backward**. This is because the number of records
are sparse on older dates unfortunately, while more recent dates allows you to ingest more records, but the idea of daily simulation 
is the same.

### Whenever you want to ingest 'another day worth of data', open `run_daily_ingestion.sql` at the workspace root and click **Run All**.

That's the only file you need going forward.

> **Info:** You will have already loaded one day back in [Load the Seed Data](#05-load-the-seed-data)!

Output:
```
Loaded date 2026-01-28. Advanced to 2026-01-27 (min: 2024-02-21)
```

![run_daily_ingestion.sql output showing the loaded date and next date](../assets/img/success_simulated_load.png)

Run it again → next day loads. And again. Keep going as many days as you want.

`SEED.LOAD_STATE` after several runs. `CURRENT_LOAD_DATE` visibly earlier than `MAX_DATE`, proof the simulation advances over repeated runs, not just once:

![SEED.LOAD_STATE table after several ingestion runs](../assets/img/simulated_history.png)

## Check That It Works
Give it 1-5 minutes for the pipeline to load data through each layer.

**Run this single query to verify data is flowing through every layer at once:**

```sql
-- One grid: bronze landed it, silver cleaned it, gold aggregated it, seed tracks where we are.
SELECT LAYER, TABLE_NAME, ROW_COUNT, DETAIL
FROM (
    SELECT 
        1 AS SEQ, 
        'BRONZE' AS LAYER, 
        'MATCHES' AS TABLE_NAME, 
        COUNT(*) AS ROW_COUNT, NULL AS DETAIL
    FROM LEAGUE_RECORDS.BRONZE.MATCHES
        UNION ALL
    SELECT 2, 'BRONZE', 'PLAYERS', COUNT(*), NULL
    FROM LEAGUE_RECORDS.BRONZE.PLAYERS
        UNION ALL
    SELECT 3, 'BRONZE', 'INTERVALS', COUNT(*), NULL
    FROM LEAGUE_RECORDS.BRONZE.INTERVALS
        UNION ALL
    SELECT 4, 'SILVER', 'MATCHES', COUNT(*), NULL
    FROM LEAGUE_RECORDS.SILVER.MATCHES
        UNION ALL
    SELECT 5, 'SILVER', 'PLAYERS', COUNT(*), NULL
    FROM LEAGUE_RECORDS.SILVER.PLAYERS
        UNION ALL
    SELECT 6, 'SILVER', 'INTERVALS', COUNT(*), NULL
    FROM LEAGUE_RECORDS.SILVER.INTERVALS
        UNION ALL
    SELECT 7, 'GOLD', 'MATCHEND_PIVOT_TEAMSTATS', COUNT(*), NULL
    FROM LEAGUE_RECORDS.GOLD.MATCHEND_PIVOT_TEAMSTATS
        UNION ALL
    SELECT 8, 'GOLD', 'MATCHEND_PLAYER_STATS', COUNT(*), NULL
    FROM LEAGUE_RECORDS.GOLD.MATCHEND_PLAYER_STATS
        UNION ALL
    SELECT 9, 'GOLD', 'CHAMPION_INTERVALS', COUNT(*), NULL
    FROM LEAGUE_RECORDS.GOLD.CHAMPION_INTERVALS
        UNION ALL
    SELECT 10, 'GOLD', 'CHAMPION_OVERVIEWS', COUNT(*), NULL
    FROM LEAGUE_RECORDS.GOLD.CHAMPION_OVERVIEWS
        UNION ALL
    SELECT 11, 'GOLD', 'ITEM_RECOMMENDATIONS', COUNT(*), NULL
    FROM LEAGUE_RECORDS.GOLD.ITEM_RECOMMENDATIONS
        UNION ALL
    SELECT 12, 'GOLD', 'DIFF_INTERVALS', COUNT(*), NULL
    FROM LEAGUE_RECORDS.GOLD.DIFF_INTERVALS
        UNION ALL
    SELECT 13, 'SEED', 'LOAD_STATE', NULL,
        'current=' || COALESCE(TO_VARCHAR(CURRENT_LOAD_DATE), '<null>')
        || '  min=' || COALESCE(TO_VARCHAR(MIN_DATE), '<null>')
        || '  max=' || COALESCE(TO_VARCHAR(MAX_DATE), '<null>')
        || '  last_loaded_at=' || COALESCE(TO_VARCHAR(LAST_LOADED_AT), '<null>')
    FROM LEAGUE_RECORDS.SEED.LOAD_STATE
) AS T
ORDER BY SEQ;
```
You should be seeing something like this, with perhaps different row count numbers from mine (since my version here
has simulated daily ingestion by couple days ahead)

![Check that it works — Bronze, Silver, Gold, and Seed row counts in one grid](../assets/img/check_that_it_works.png)

> **Tip:** If silver tables are empty but bronze has data, wait 1-2 minutes for the tasks to fire. You can check task history with:
>
> ```sql
> SELECT NAME, STATE, QUERY_START_TIME
> FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
>     SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP())
> ))
> ORDER BY QUERY_START_TIME DESC;
> ```

> **Warning:** Gold tables are **dynamic tables**, not tasks. They refresh on their own schedule (`TARGET_LAG`), 
not the moment new silver data lands. `GOLD.MATCHEND_PIVOT_TEAMSTATS` is set to `TARGET_LAG = '1 day'`, so it can 
take up to a day to reflect a fresh load on its own. If you want to see current data immediately (e.g. right 
before opening a Streamlit app below), force a refresh instead of waiting by **running the query block below.**
>
> ```sql
> ALTER DYNAMIC TABLE LEAGUE_RECORDS.GOLD.MATCHEND_PLAYER_STATS REFRESH;
> ALTER DYNAMIC TABLE LEAGUE_RECORDS.GOLD.CHAMPION_INTERVALS REFRESH;
> ALTER DYNAMIC TABLE LEAGUE_RECORDS.GOLD.CHAMPION_OVERVIEWS REFRESH;
> ALTER DYNAMIC TABLE LEAGUE_RECORDS.GOLD.MATCHEND_PIVOT_TEAMSTATS REFRESH;
> ALTER DYNAMIC TABLE LEAGUE_RECORDS.GOLD.ITEM_RECOMMENDATIONS REFRESH;
> ALTER DYNAMIC TABLE LEAGUE_RECORDS.GOLD.DIFF_INTERVALS REFRESH;
> ```
