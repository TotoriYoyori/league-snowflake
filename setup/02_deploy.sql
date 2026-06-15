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
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/infra/02_file_stage_and_pipe.sql;
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/infra/03_seed_table.sql;

-------------------------------------------------------------------------------------------
-- BRONZE - RAW INGESTION
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/bronze/01_match_intervals_bronze.sql;

-------------------------------------------------------------------------------------------
-- PROCEDURES
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/infra/simulate_daily_load.sql;
