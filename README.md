![League of Legends banner](assets/league_banner.jpg)

# League of Legends Match Analytics

An ELT pipeline and analytics project built entirely on Snowflake, using match data from League of Legends.

## What this project does

This data pipeline takes raw match interval data (snapshots of player and team stats every few minutes during a game) and transforms it into clean, queryable analytics tables. Some questions to answer are as follows:

- How does early-game gold advantage translate into win probability?
- Which objective combinations (dragons, barons, heralds) have the strongest impact on game outcome?
- How do individual player stats (KDA, CS, items) evolve over the course of a match?

## Data Vault (`dv/`)

For this project, I practiced a data vault modeling approaches on a single-source `.csv`-based dataset (hub / satellite / link modeling):
- **Staging** (`l00`): Raw data load and hash key generation
- **Raw Vault** (`l10`): Append-only hubs for players, teams, and intervals; Links connecting them; Satellites holding descriptive attributes.
- **Business Vault** (`l20`): Deduplicated, combined views joining hubs, links, and satellites for easier querying
- **Analytics** (`l30`): Fact and dimension views ready for end users (dashboards, eda, modelling, etc.)

## Stacks Used

- **Snowflake** — warehouse, stages, pipes, streams, tasks
- **Azure Blob Storage** — source file hosting via storage integration
- **Python** — other miscellanies

## Data source

'LoL Match Intervals: 2 Million In-Game Snapshots' sourced from Kaggle.

https://www.kaggle.com/datasets/nathansmallcalder/league-of-legends-match-interval-snapshots-2026