-------------------------------------------------------------------------------------------
-- LEAGUE-SNOWFLAKE DEPLOYMENT SCRIPT (MEDALLION ARCHITECTURE)
-- DEPENDS ON: 01_bootstrap.sql must be run first
-- Run top to bottom from any Snowsight worksheet
-------------------------------------------------------------------------------------------
USE WAREHOUSE DV_COMPUTE_WH;

-------------------------------------------------------------------------------------------
-- INFRASTRUCTURE
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/infra/01_db_and_schema.sql;
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/infra/02_seed_tables.sql;

-------------------------------------------------------------------------------------------
-- BRONZE - RAW INGESTION
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/bronze/01_matches_summary_bronze.sql;
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/bronze/02_players_summary_bronze.sql;
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/bronze/03_match_intervals_bronze.sql;
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/bronze/04_references_bronze.sql;
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/bronze/05_stages_and_pipes.sql;

-------------------------------------------------------------------------------------------
-- SILVER - CLEANED & ENRICHED
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/silver/01_matches_summary_silver.sql;
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/silver/02_players_summary_silver.sql;
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/silver/03_match_intervals_silver.sql;
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/silver/04_references_silver.sql;

-------------------------------------------------------------------------------------------
-- PROCEDURES
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/infra/03_simulate_daily_load.sql;
