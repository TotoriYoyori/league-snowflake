![League of Legends banner](assets/img/league_banner.jpg)

# League of Legends ELT pipeline for 2.1 million in-game snapshots
## Click here to set it up yourself → **[`setup/INSTALL_GUIDE.md`](setup/INSTALL_GUIDE.md)**

This project takes **39,954 real matches**, and runs it through a full medallion pipeline on Snowflake. 
You can query the final tables, and even interact with them via Streamlit apps.

The source data is hooked to a `simulate_daily_load` procedure so that users can slowly ingest the above 
**2.1 millions** records over a period of ~700 days (make pretend daily data load!). Why did I bother with making this 
simulated system? Because I want to prove that I can design a living pipeline that is built once but runs forever. 
Designing a one-shot pipeline of course is much simpler.


Regardless, this pipeline is built to look and behave like a *real* production worthy pipeline: run now and forever. 
Data arrives daily, cleans itself, aggregates itself, and refreshes on a schedule. Built entirely within the limit of 
Snowflake's free trial credits, in **under a month of solo development**.

----
## The Streamlit Apps

This pipeline comes with the following three Streamlit apps. **All of which are capable of running either LIVE on Snowflake (using real data 
produced by the pipeline), or just using mock data.**

You can click on each highlighted name below to visit their demo site on Streamlit Cloud! This demo version uses mock data, which is a
sample of the real data that you would receive from the pipeline. 

1. **[Itemization Explorer](https://league-sf-item-browser.streamlit.app/)**: pick a champion and browse every item 
by buy rate and win rate. Employ empirical-Bayes shrinkage for noisy low-n buy samples.

https://github.com/user-attachments/assets/b4bfd5aa-1652-4e3f-8759-45b5abeab6c9

3. **[Role Importance](https://league-sf-role-importance.streamlit.app/)**: a logistic regression model that turns 
each lane's gold diff at a chosen match minute into a win coefficient. Same model also powers a live predictor: 
type in 5 gold diffs, get a win probability back.

https://github.com/user-attachments/assets/eb6cd0ef-abc9-4505-b540-1eff1882ee90

4. **[Pipeline Monitor](https://league-sf-pipeline.streamlit.app/)**: a live dashboard for the pipeline itself: 
27 checks across Seed, Bronze, Silver, and Gold. From ingestion progress, stream lag, task history, to Gold refresh 
state, all in one place.

https://github.com/user-attachments/assets/8df32ce6-13bb-42e8-b6f3-41875744a125

> **Info:** Each app runs two ways from the same code: 1. against the live warehouse inside Snowflake, or 2.
fully offline against CSV exports for local development and demos.

----
## Here's the whole pipeline:

* **Bronze → Silver → Gold** pipeline, built entirely on Snowflake.
* Source data is fed in **one simulated day at a time**, just like a real source system.
* **Bronze** lands it raw, **Silver** cleans it via streams + tasks, **Gold** aggregates it via dynamic tables.
* On top of Gold sit **Streamlit apps** for exploring items, modeling win probability from gold diffs, and monitoring 
the pipeline activites.
* **Monitoring notebooks and health checks scripts** are also set up for your convenience.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        LEAGUE_RECORDS DATABASE                       │
├─────────────┬───────────────┬───────────────────┬───────────────────┤
│    SEED     │    BRONZE     │      SILVER       │       GOLD        │
│             │               │                   │                   │
│ Source CSVs │ Raw landing   │ Cleaned/enriched  │ Aggregated        │
│ loaded once │ via pipes     │ via stream+task   │ analytical tables │
│             │ + metadata    │                   │ via dynamic tables│
└─────────────┴───────────────┴───────────────────┴───────────────────┘
```

```
league-snowflake/
├── assets/            
├── data_vault_ref/     # archived earlier modeling approach (reference only)
├── models/
│   ├── _infra/         # DDL for tables, views, pipes, etc. per folder under model.
│   ├── bronze/        
│   ├── gold/           
│   └── silver/         
├── notebook/                      
├── patch/              # ad-hoc fixes applied to the live pipeline over time
├── setup/   
└── run_daily_ingestion.sql   # one-click: ingest the next simulated day
```

This pipeline is for **internal development and analytics teams**, not casual lookups, and that changes what it offers
relatively to a stats aggregator site like OP.gg.

* **Transparent statistics.** Every number is open source, you can read exactly how a win rate is computed instead of trusting a black box.
* **Adjustable parameters.** Shrinkage strength, minimum sample size, time windows.
* **Continuously ingesting.** Data flows in daily and Gold refreshes itself, with potential for NRT (near real time) loading.
* **Honest about its limits.** Every row carries how stale it might be and how large its sample was. Teams can judge the data and make decisions.

----
## Showcase

The pipeline and all its item in the database tree.

https://github.com/user-attachments/assets/c3680031-7c95-44e1-8029-f626c2f202a4

Gold's dynamic table lineage and refresh lag example.

![Gold dynamic table dependency graph](assets/img/gold_graph.png)

![SHOW DYNAMIC TABLES output with differentiated TARGET_LAG per Gold table](assets/img/gold_refreshness.png)

The pipeline has a click and run data quality suite as well!

![health_check.sql output — 8 checks, including a real FAIL and REVIEW row](assets/img/health_check_result.png)

----
## What can it answer?

The Gold layer is designed around the questions an analyst (or a curious player) actually asks. 
Each one maps to a table you can query directly:

| Question                                                      | Answered by |
|---------------------------------------------------------------|-------------|
| Does an early gold lead actually win games?                   | `MATCH_TEAM_STATS_SUMMARY` |
| Which objectives (dragons, barons, grubs) swing a match most? | `MATCH_TEAM_STATS_SUMMARY` |
| How does a champion grow over the course of a game?           | `CHAMPION_INTERVALS` |
| What do different match-end player lineups looks like?        | `PLAYER_STATS_SUMMARY` |
| Which champions and lanes dominate the meta?                  | `CHAMPION_OVERVIEW` |
| What should I build on champion *X*?                          | `ITEM_STATS_AND_RECOMMENDATIONS` |


----
## Data sources

Five source tables from the Kaggle dataset:

| Source | Grain | Rows |
|--------|-------|------|
| `matches_summary` | 1 per match | ~40K |
| `players_summary` | 1 per player per match | ~400K |
| `match_intervals` | 1 per player per minute | ~2.1M |
| `items_ref` | 1 per item (lookup) | 635 |
| `champions_ref` | 1 per champion (lookup) | 173 |

Source: [LoL Match Intervals: 2 Million In-Game Snapshots](https://www.kaggle.com/datasets/nathansmallcalder/league-of-legends-match-interval-snapshots-2026)

----
## Known limitations

- **No run/data-snapshot tracking for the Streamlit apps:** Each of the app uses whatever data currently exists 
at the moment it's run, but the output isn't currently logged or timestamped against the underlying data state. 
This means results aren't directly comparable across runs over time (e.g., "did lane importance shift after the 
role-quest patch?"). You have to eyeball and track things manually for now.
- Has subtitles and descriptions in Chinese for all Streamlit apps, but no proper language setting button at the moment. 
- **Warehouse Runtime outdated:** The Streamlit apps are currently deployed on Snowflake using WH runtime, which is the 
legacy mode. Modern standard is using Container Runtime, but because I'm on a trial account I do not have access to
external package dependencies.
