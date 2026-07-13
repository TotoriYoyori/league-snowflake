![League of Legends banner](assets/img/league_banner.jpg)

# League of Legends ELT pipeline for 2.1 million in-game snapshots
## Click here to setup yourself → **[`setup/INSTALL_GUIDE.md`](setup/INSTALL_GUIDE.md)**

This project takes **39,954 real matches**, and runs it through a full medallion pipeline on Snowflake. You can query the final tables, and even interact with them via Streamlit apps.

The source data is hooked to a `simulate_daily_load` procedure so that users can slowly ingest the above **2.1 millions** records over a period of ~700 days (make pretend daily data load!). 

Regardless, this pipeline is built to look and behave like a *real* production worthy pipeline: run now and forever. Data arrives daily, cleans itself, aggregates itself, and refreshes on a schedule. Built entirely within Snowflake's **$400 free trial credits**,
in **under three weeks of solo development**.

----
## Here's the whole thing in five lines:

* **Bronze → Silver → Gold** pipeline, built entirely on Snowflake.
* Source data is fed in **one simulated day at a time**, just like a real source system.
* **Bronze** lands it raw, **Silver** cleans it via streams + tasks, **Gold** aggregates it via dynamic tables.
* On top of Gold sit **Streamlit apps** for exploring items, modeling KDA odds, and monitoring the pipeline activites.
* **Monitoring notebooks, health checks scripts, and notification integration** are also set up for your convenience, just fill in your own information.



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
├── setup/              
├── models/
│   ├── _infra/         # DDL for tables, views, pipes, etc. per folder under model.
│   ├── bronze/        
│   ├── silver/         
│   └── gold/           
├── patch/              # ad-hoc fixes applied to the live pipeline over time
├── analysis/           
├── tests/              
├── data_vault_ref/     # archived earlier modeling approach (reference only)
└── run_daily_ingestion.sql   # one-click: ingest the next simulated day
```

----
## What can it answer?

The Gold layer is designed around the questions an analyst (or a curious player) actually asks. Each one maps to a table you can query directly:

| Question | Answered by |
|----------|-------------|
| Does an early gold lead actually win games? | `MATCH_TEAM_STATS_SUMMARY` |
| Which objectives — dragons, barons, grubs — swing a match most? | `MATCH_TEAM_STATS_SUMMARY` |
| How does a champion grow over the course of a game? | `CHAMPION_INTERVALS` |
| How did a given player's game actually end up? | `PLAYER_STATS_SUMMARY` |
| Which champions and lanes dominate the meta? | `CHAMPION_OVERVIEW` |
| What should I build on champion *X*? | `ITEM_STATS_AND_RECOMMENDATIONS` |

----
## But why not just go to OP.gg ?

Fair question. Sites like *op.gg* or *u.gg* already show win rates and item builds.

But they're built for a different audience. This pipeline is for **internal development and analytics teams**, not casual lookups, and that changes what it offers:

* **Transparent statistics.** Every number is open source — you can read exactly how a win rate is computed instead of trusting a black box.
* **Adjustable parameters.** Shrinkage strength, minimum sample size, time windows — these are knobs you turn.
* **Continuously ingesting.** Data flows in daily and Gold refreshes itself, with potential for NRT (near real time) loading.
* **Honest about its limits.** Every row carries how stale it might be and how large its sample was. Teams can judge the data and make decisions.

> **The short of it:** stat sites answer *"what's good right now?"* This answers *"why, by how much, and how confident are we?"*. This pipeline is also very easy to setup. 

----
## The apps

This pipeline comes with the following three Streamlit apps:
1. **Itemization Explorer** *(browsing — live)* — pick a champion and browse every item by buy rate and win rate. Raw win rates get smoothed with empirical-Bayes shrinkage toward each champion's own baseline, which tames the noisy long tail and surfaces genuine **hidden gems** and **trap items**.
2. **Probability of KDA** *(statistical modeling — live)* — choose a stat and a match minute, and get the probability that a player — or a whole group — clears a KDA threshold, built from sampling distributions and the central limit theorem.
3. **Pipeline Monitor** *(observability — planned)* — a live dashboard for the pipeline itself: ingestion progress, stream lag, task history, and Gold refresh state, all in one place.

> **Info:** Each app runs two ways from the same code — against the live warehouse inside Snowflake, or fully offline against CSV exports for local development and demos.

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
## Known limitations / future work

- **No run/data-snapshot tracking.** Each `role_importance()` call reflects whatever is in `GOLD.DIFF_INTERVAL_STATE` at the moment it's run, but the output isn't currently logged or timestamped against the underlying data state. This means results aren't directly comparable across runs over time (e.g., "did lane importance shift after the role-quest patch?") without manually noting when each run happened. Adding a lightweight run log (timestamp + `GAME_DATE` range + resulting `lane_importance` table) would support that comparison later.

----
*(Rito if you like this send me an email and hire me please. I make you money. → stan.mng@gmail.com)*