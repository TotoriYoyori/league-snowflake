![League of Legends banner](assets/league_banner.jpg)

# League of Legends Match Analytics

An ELT pipeline and analytics project built entirely on Snowflake. This data pipeline takes raw match interval data (snapshots of player and team stats every few minutes during a game) and transforms it into clean, queryable analytics tables. Some questions to answer are as follows:

- How does early-game gold advantage translate into win probability?
- Which objective combinations (dragons, barons, heralds) have the strongest impact on game outcome?
- How do individual player stats (KDA, CS, items) evolve over the course of a match?

## Data Vault (`dv/`)

For this project, I practiced a data vault modeling approaches on a single-source `.csv`-based dataset (hub / satellite / link modeling):
- **Staging** (`l00`): Raw data load and hash key generation
- **Raw Vault** (`l10`): Append-only hubs for players, teams, and intervals; Links connecting them; Satellites holding descriptive attributes.
- **Business Vault** (`l20`): Deduplicated, combined views joining hubs, links, and satellites for easier querying
- **Analytics** (`l30`): Fact and dimension views ready for end users (dashboards, eda, modelling, etc.)

## Reflection: Why Data Vault?

League of Legends is a constantly updating game — new champions, reworked items, overhauled objective systems every season. This creates real data engineering challenges that influenced why I chose a data vault approach for this project.

### 1. Schema changes are inevitable

Riot regularly adds new columns to their match data. When they introduced Void Grubs in Season 14, every match record suddenly had new fields that didn't exist before. In a traditional star schema, that means altering fact tables, rewriting ETL logic, and hoping nothing downstream breaks. In data vault, new attributes just get their own satellite table. The existing hubs and links stay untouched — I just attach a new `SAT_TEAM_INTERVALS_OBJV` with the new fields, and historical records remain intact.

### 2. Patch history needs to be preserved, not overwritten

A match played on Patch 14.1 has different game mechanics than one played on Patch 14.10. If I used a traditional approach with UPDATE/MERGE into dimension tables (e.g., updating a champion's base stats), I'd lose the historical context — a champion's win rate would look wrong when compared against a patch where they had completely different numbers. Data vault's append-only satellites handle this naturally. Each record carries a load timestamp, so I can always trace back what the data looked like at any point in time without needing slowly changing dimension logic.

### 3. Multiple sources, multiple schemas

League generates data through many clients globally, and many third-party apps track different aspects of the game (Riot API, op.gg, u.gg, third-party scraping tools). Each source has its own schema and its own update cadence. In a normalized or star schema approach, integrating a new source means redesigning joins, resolving conflicts, and potentially restructuring existing tables. Data vault handles this cleanly — each source feeds into its own staging layer and its own satellites, all linked through the same business keys (match ID, player ID). Adding a new data provider is just adding new satellites to existing hubs, not rearchitecting the model.

## Project Structure

```
league-snowflake/
├── README.md
├── .gitignore
├── assets/
│
├── infrastructure/
│   ├── 01_setup.sql                  -- warehouse, database, schemas
│   ├── 02_storage_integration.sql    -- Azure stage + file formats
│   └── 03_ingestion.sql              -- COPY INTO, pipes, streams
│
├── models/
│   ├── staging.sql                   -- hash keys, type casting
│   ├── raw_vault.sql                 -- hubs, links, satellites
│   ├── business_vault.sql            -- joined views for querying
│   └── analytics.sql                 -- fact + dimension views
│
└── analysis/
    └── eda.sql                       -- exploratory queries
```

Each `models/` file maps to a data vault layer. As the project grows, any file can be split into its own folder (e.g., `models/raw_vault/hubs/`, `models/raw_vault/satellites/`) without changing the overall structure.

## Stacks Used

- **Snowflake** — warehouse, stages, pipes, streams, tasks
- **Azure Blob Storage** — source file hosting via storage integration
- **Python** — other miscellanies

I chose Snowflake to practice working with SQL-based data engineering, as well as just Snowflake in general, but this project can also be ported as a Databricks job and pipeline using notebooks and Spark.

## Data Source

'LoL Match Intervals: 2 Million In-Game Snapshots' sourced from Kaggle.

https://www.kaggle.com/datasets/nathansmallcalder/league-of-legends-match-interval-snapshots-2026