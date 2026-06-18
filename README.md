![League of Legends banner](assets/img/league_banner.jpg)

# League of Legends Match Analytics

An ELT pipeline built entirely on Snowflake using a medallion architecture (Bronze → Silver → Gold). Raw match data from five source tables flows through simulated daily ingestion into clean, queryable analytics tables.

## Questions This Pipeline Can Answer

- How does early-game gold advantage translate into win probability?
- Which objective combinations (dragons, barons, heralds) have the strongest impact on game outcome?
- How do individual player stats (KDA, CS, items) evolve over the course of a match?
- What champion/role combinations dominate at different rank tiers?

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        LEAGUE_RECORDS DATABASE                       │
├─────────────┬───────────────┬───────────────────┬───────────────────┤
│    SEED     │    BRONZE     │      SILVER       │       GOLD        │
│             │               │                   │                   │
│ Source CSVs │ Raw landing   │ Cleaned/enriched  │ Aggregated        │
│ loaded once │ via pipes     │ via stream+task   │ analytical views  │
│             │ + metadata    │                   │   (planned)       │
└─────────────┴───────────────┴───────────────────┴───────────────────┘
```

### Pipeline Flow

1. **Seed** — Full source datasets uploaded once to `@SEED.SEED_UPLOAD_STG` (simulates a source system)
2. **`SIMULATE_DAILY_LOAD()`** — Chunks data by date (latest first), stages CSVs, refreshes pipes
3. **Bronze** — Pipes load staged files into landing tables with ingestion metadata
4. **Silver** — Streams detect new bronze rows → tasks merge into cleaned/enriched tables
5. **Gold** — Aggregated views for analytics consumption *(planned)*

## Data Sources

Five source tables from the Kaggle dataset:

| Source | Grain | Rows |
|--------|-------|------|
| `matches_summary` | 1 per match | ~40K |
| `players_summary` | 1 per player per match | ~400K |
| `match_intervals` | 1 per player per minute | ~2.1M |
| `items_ref` | 1 per item (lookup) | 635 |
| `champions_ref` | 1 per champion (lookup) | 173 |

Source: [LoL Match Intervals: 2 Million In-Game Snapshots](https://www.kaggle.com/datasets/nathansmallcalder/league-of-legends-match-interval-snapshots-2026)

## Project Structure

```
league-snowflake/
├── README.md
├── run_daily_ingestion.sql         -- one-click: ingest next day of data
├── .gitignore
├── assets/
│
├── setup/
│   ├── INSTALL_GUIDE.md            -- step-by-step setup walkthrough
│   ├── 01_deploy.sql               -- orchestrates all model scripts via EXECUTE IMMEDIATE
│   ├── 02_seed_source.sql          -- validates stage + loads CSVs into seed tables
│   └── 03_activate_tasks.sql       -- resumes all bronze-to-silver tasks
│
├── models/
│   ├── _infra/
│   │   ├── 01_db_and_schema.sql    -- SEED/BRONZE/SILVER/GOLD schemas
│   │   ├── 02_seed_tables.sql      -- seed table DDLs + date index + load state + upload stage
│   │   ├── 03_validate_seed_upload.sql -- guard: checks required files exist in stage
│   │   └── 04_simulate_daily_load.sql  -- orchestrator + staging procedures + state management
│   │
│   ├── bronze/                     -- each file is self-contained: table + stream + stage + pipe
│   │   ├── 00_file_format.sql      -- LEAGUE_CSV_FMT (shared by all bronze stages)
│   │   ├── 01_matches_summary_bronze.sql
│   │   ├── 02_players_summary_bronze.sql
│   │   ├── 03_match_intervals_bronze.sql
│   │   ├── 04_items_ref_bronze.sql
│   │   └── 05_champions_ref_bronze.sql
│   │
│   └── silver/                     -- cleaning views + tables + merge tasks
│       ├── 01_matches_summary_silver.sql
│       ├── 02_players_summary_silver.sql
│       ├── 03_references_silver.sql        -- items + champions
│       ├── 04_split_match_intervals_stream_cleaning.sql
│       ├── 05a_team_interval_silver.sql
│       ├── 05b_player_interval_silver.sql
│       └── 06_bronze_to_silver_intervals_task.sql
│
├── tests/
│   ├── 01_test_deploy.sql          -- deploys abridged pipeline to TEST_PIPELINE_DB
│   ├── 02_test_seed_and_run.sql    -- seeds + simulates one load (matches only)
│   ├── 03_test_teardown.sql        -- drops TEST_PIPELINE_DB
│   └── test_results.ipynb          -- notebook: cell-by-cell inspection queries
│
├── analysis/                       -- notebooks + streamlit apps for data exploration
│
└── data_vault_ref/                 -- archived data vault implementation (reference only)
```

## Getting Started

See **[`setup/INSTALL_GUIDE.md`](setup/INSTALL_GUIDE.md)** for the full walkthrough. The short version:

1. Create a Workspace from this repo
2. Run `setup/01_deploy.sql`
3. Upload CSVs to `@SEED.SEED_UPLOAD_STG` via Snowsight UI
4. Run `setup/02_seed_source.sql`
5. Run `setup/03_activate_tasks.sql`
6. Run `run_daily_ingestion.sql` — repeat for each simulated day

## Stacks Used

- **Snowflake** — warehouse, stages, pipes, streams, tasks, stored procedures
- **Snowflake Workspaces** — deployment directly from workspace file tree via `snow://` URIs

## Archived: Data Vault Reference

The `data_vault_ref/` directory contains a previous implementation using data vault modeling (hubs, satellites, streams, tasks). It is kept as a portfolio reference but is not deployed or maintained. The active pipeline uses the medallion architecture described above.
