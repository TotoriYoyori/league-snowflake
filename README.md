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
│             │ + metadata    │                   │                   │
└─────────────┴───────────────┴───────────────────┴───────────────────┘
```

### Pipeline Flow

1. **Seed** — Full source datasets loaded once (simulates a source system)
2. **SIMULATE_DAILY_LOAD()** — Chunks data by date (latest first), stages CSVs, refreshes pipes
3. **Bronze** — Pipes load staged files into landing tables with ingestion metadata
4. **Silver** — Streams detect new bronze rows → tasks merge into cleaned/enriched tables *(planned)*
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
├── INSTALL_GUIDE.md
├── .gitignore
├── assets/
│
├── setup/
│   ├── 01_bootstrap.sql              -- creates warehouse, DB, Git repo, calls deploy
│   ├── 02_deploy.sql                 -- orchestrates all model scripts in order
│   └── 03_seed_staging_tables.sql    -- PUT + COPY INTO seed tables from local CSVs
│
├── models/
│   ├── infra/
│   │   ├── 01_db_and_schema.sql      -- database + SEED/BRONZE/SILVER/GOLD schemas
│   │   ├── 02_seed_tables.sql        -- seed table DDLs + date index view + load state
│   │   └── 03_simulate_daily_load.sql -- orchestrator + 3 child staging procedures
│   │
│   ├── bronze/
│   │   ├── 01_matches_summary_bronze.sql
│   │   ├── 02_players_summary_bronze.sql
│   │   ├── 03_match_intervals_bronze.sql
│   │   ├── 04_references_bronze.sql
│   │   └── 05_stages_and_pipes.sql   -- file format, stages, pipes (depends on tables)
│   │
│   ├── silver/                        -- (planned) stream + task + enriched tables
│   └── gold/                          -- (planned) aggregated analytics views
│
└── data_vault_ref/                    -- archived data vault implementation (reference only)
```

## Stacks Used

- **Snowflake** — warehouse, stages, pipes, streams, tasks, stored procedures
- **Git Integration** — Snowflake Git repository for deployment from GitHub

## Archived: Data Vault Reference

The `data_vault_ref/` directory contains a previous implementation using data vault modeling (hubs, satellites, streams, tasks). It is kept as a portfolio reference but is not deployed or maintained. The active pipeline uses the medallion architecture described above.
