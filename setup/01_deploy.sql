-------------------------------------------------------------------------------------------
-- 00. SETUP DATABASE AND DEPLOY SESSION CONTEXT
--
-- WARNING: DESTRUCTIVE. CREATE OR REPLACE DATABASE below drops LEAGUE_RECORDS and everything
-- in it -- all seeded data, all simulated ingestion progress (SEED.SEED_LOAD_STATE), all Gold
-- history -- before rebuilding from scratch. Re-running this file is a full teardown/rebuild,
-- not an incremental update. Re-seed and re-run run_daily_ingestion.sql afterward if you want
-- data back.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE DATABASE LEAGUE_RECORDS
    COMMENT = '2.11 million time-series snapshots extracted from 39,954 high-elo and standard League of Legends matches.';

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
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/bronze/00_file_format.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/bronze/01_matches_summary_bronze.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/bronze/02_players_summary_bronze.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/bronze/03_match_intervals_bronze.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/bronze/04_items_ref_bronze.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/bronze/05_champions_ref_bronze.sql';

-------------------------------------------------------------------------------------------
-- 03. SILVER: CLEANED & ENRICHED
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/silver/01_matches_summary_silver.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/silver/02_players_summary_silver.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/silver/03_references_silver.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/silver/04_split_match_intervals_stream_cleaning.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/silver/05a_team_interval_silver.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/silver/05b_player_interval_silver.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/silver/06_bronze_to_silver_intervals_task.sql';

-------------------------------------------------------------------------------------------
-- 04. GOLD: ANALYTICAL (dynamic tables; self-refresh via TARGET_LAG, no task activation)
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/gold/01_player_stats_summary.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/gold/02_champion_intervals.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/gold/03_champion_overview.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/gold/04_match_team_stats_summary.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/gold/05_item_stats_and_recommendations.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/gold/06_diff_interval_state.sql';

-------------------------------------------------------------------------------------------
-- 05. PATCHES: AD-HOC TO THE PIPELINE DURING DEVELOPMENTS
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/patch/20260625_add_orphan_item_id_under_ref.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/patch/20260627_view_flag_missing_records.sql';

-------------------------------------------------------------------------------------------
-- 06. PROCEDURES
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/_infra/03_validate_seed_upload.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/_infra/04_simulate_daily_load.sql';
