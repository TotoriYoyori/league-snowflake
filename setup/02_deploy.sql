-------------------------------------------------------------------------------------------
-- LEAGUE-SNOWFLAKE DEPLOYMENT SCRIPT
-- DEPENDS ON: ./run_first.sql must be run first
-- Run top to bottom from any Snowsight worksheet
-------------------------------------------------------------------------------------------
USE WAREHOUSE DV_COMPUTE_WH;

-------------------------------------------------------------------------------------------
-- SETUP
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/ddl/infrastructure/01_db_and_schema.sql;
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/ddl/infrastructure/02_file_stage_and_pipe.sql;
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/ddl/infrastructure/03_seed_table.sql;

-------------------------------------------------------------------------------------------
-- L00_STG - STAGING
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/ddl/l00_stg/00_utils.sql;
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/ddl/l00_stg/01_raw_staging_table.sql;
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/ddl/l00_stg/02_set_stream_on_staging_table.sql;

-------------------------------------------------------------------------------------------
-- L10_RDV - RAW DATA VAULT
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/ddl/l10_rdv/01_hub_satellite_ddl.sql;
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/ddl/l10_rdv/02_task_to_consume_stream.sql;

-------------------------------------------------------------------------------------------
-- PROCEDURES
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/ddl/simulate_daily_load.sql;
