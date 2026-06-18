-- Test deployment: abridged pipeline (matches_summary only) in TEST_PIPELINE_DB
-- Co-authored with CoCo
-------------------------------------------------------------------------------------------
-- TEST DEPLOYMENT SCRIPT (ABRIDGED — MATCHES_SUMMARY PATH ONLY)
-- Creates TEST_PIPELINE_DB and deploys just enough of the pipeline to validate the
-- matches_summary flow: seed → simulate_daily_load → bronze → silver.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE DATABASE TEST_PIPELINE_DB
    COMMENT = 'Ephemeral test database for pipeline integration tests.';

USE WAREHOUSE COMPUTE_WH;
USE DATABASE TEST_PIPELINE_DB;

-------------------------------------------------------------------------------------------
-- INFRASTRUCTURE (schemas + file format + seed tables + simulate_daily_load procedure)
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/_infra/01_db_and_schema.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/_infra/02_seed_tables.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/_infra/03_simulate_daily_load.sql';

-------------------------------------------------------------------------------------------
-- BRONZE (file format + matches_summary table, stream, stage, pipe)
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/bronze/00_file_format.sql';
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/bronze/01_matches_summary_bronze.sql';

-------------------------------------------------------------------------------------------
-- SILVER (matches_summary cleaning view, table, merge task)
-------------------------------------------------------------------------------------------
EXECUTE IMMEDIATE FROM 'snow://workspace/USER$.PUBLIC."league-snowflake"/versions/live/models/silver/01_matches_summary_silver.sql';
