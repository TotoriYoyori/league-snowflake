-------------------------------------------------------------------------------------------
-- 00. SETUP DATABASE AND DEPLOY SESSION CONTEXT
-------------------------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS LEAGUE_RECORDS
    COMMENT = '2.11 million time-series snapshots extracted from 39,954 high-elo, Summoner's Rift LoL matches.';

USE WAREHOUSE COMPUTE_WH;

USE DATABASE LEAGUE_RECORDS;

-------------------------------------------------------------------------------------------
-- 01. INFRASTRUCTURE
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/_infra/01_db_and_schema.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/_infra/02_seed_tables.sql';

-------------------------------------------------------------------------------------------
-- 02. BRONZE: RAW INGESTION
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/bronze/00_league_csv_fmt.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/bronze/01_matches.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/bronze/02_players.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/bronze/03_items_ref.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/bronze/04_champions_ref.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/bronze/05_intervals.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/bronze/06_unlogged_matches.sql';

-------------------------------------------------------------------------------------------
-- 03. SILVER: CLEANED & ENRICHED
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/silver/00_functions.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/silver/01_matches.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/silver/02_players.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/silver/03_items_ref.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/silver/04_champions_ref.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/silver/05_intervals.sql';

-------------------------------------------------------------------------------------------
-- 04. GOLD: ANALYTICAL (dynamic tables; self-refresh via TARGET_LAG, no task activation)
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/gold/01_matchend_player_stats.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/gold/02_champion_intervals.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/gold/03_champion_overviews.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/gold/04_matchend_pivot_teamstats.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/gold/05_item_recommendations.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/gold/06_diff_intervals.sql';

-------------------------------------------------------------------------------------------
-- 05. PATCHES: AD-HOC TO THE PIPELINE DURING DEVELOPMENTS
--     NOTE: 20260627_view_flag_missing_records.sql is intentionally not run here — it has
--     been promoted to models/bronze/06_unlogged_matches.sql (see BRONZE section above).
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/patch/20260625_add_orphan_item_id_under_ref.sql';

-------------------------------------------------------------------------------------------
-- 06. PROCEDURES
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/_infra/03_validate_seed_upload.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/_infra/04_simulate_daily_load.sql';
