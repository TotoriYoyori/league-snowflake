-------------------------------------------------------------------------------------------
-- LEAGUE-SNOWFLAKE DEPLOYMENT SCRIPT
-- DEPENDS ON: ./run_first.sql must be run first
-- Run top to bottom from any Snowsight worksheet
-------------------------------------------------------------------------------------------
USE WAREHOUSE DV_COMPUTE_WH;

-- Pull latest from GitHub before deploying
ALTER GIT REPOSITORY LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO FETCH;

-------------------------------------------------------------------------------------------
-- INFRASTRUCTURE
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/infrastructure/00_utils.sql;
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/infrastructure/01_create_db.sql;
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/infrastructure/02_azure_integration.sql;

-------------------------------------------------------------------------------------------
-- L00_STG - STAGING
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/l00_stg/00_utils.sql;
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/l00_stg/01_stage_pipe.sql;
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/l00_stg/02_set_stream_on_staging_table.sql;

-------------------------------------------------------------------------------------------
-- L10_RDV - RAW DATA VAULT
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/l10_rdv/01_hub_satellite_ddl.sql;
EXECUTE IMMEDIATE FROM @LEAGUE_RECORDS.PUBLIC.LEAGUE_REPO/branches/main/models/l10_rdv/02_task_to_consume_stream.sql;
