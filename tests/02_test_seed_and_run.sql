-- Test: seed matches_summary, simulate one daily load, then activate task
-- Co-authored with CoCo
-------------------------------------------------------------------------------------------
-- TEST SEED & RUN (MATCHES_SUMMARY ONLY)
--
-- BEFORE RUNNING: Upload matches_summary.csv to @TEST_PIPELINE_DB.SEED.SEED_UPLOAD_STG
-- via the Snowsight UI (Databases > TEST_PIPELINE_DB > SEED > Stages > SEED_UPLOAD_STG > Upload).
-------------------------------------------------------------------------------------------
USE WAREHOUSE COMPUTE_WH;
USE DATABASE TEST_PIPELINE_DB;
USE SCHEMA SEED;


-------------------------------------------------------------------------------------------
-- 1. LOAD MATCHES_SUMMARY FROM STAGE INTO SEED TABLE
-------------------------------------------------------------------------------------------
COPY INTO SEED_MATCHES_SUMMARY
    FROM @SEED_UPLOAD_STG/matches_summary;


-------------------------------------------------------------------------------------------
-- 2. VERIFY ROW COUNT
-------------------------------------------------------------------------------------------
SELECT 'SEED_MATCHES_SUMMARY' AS TABLE_NAME, COUNT(*) AS ROW_COUNT
FROM SEED_MATCHES_SUMMARY;


-------------------------------------------------------------------------------------------
-- 3. SIMULATE ONE DAILY LOAD (matches_summary only)
--    Calls STAGE_MATCHES_SUMMARY directly + refreshes only the matches pipe.
-------------------------------------------------------------------------------------------

-- Initialize load state (same logic as SIMULATE_DAILY_LOAD first-run)
UPDATE SEED.SEED_LOAD_STATE
   SET CURRENT_LOAD_DATE = (SELECT MAX(GAME_DATE_DAY) FROM SEED.SEED_MATCH_DATE_INDEX),
       MIN_DATE          = (SELECT MIN(GAME_DATE_DAY) FROM SEED.SEED_MATCH_DATE_INDEX),
       MAX_DATE          = (SELECT MAX(GAME_DATE_DAY) FROM SEED.SEED_MATCH_DATE_INDEX)
 WHERE CURRENT_LOAD_DATE IS NULL;

-- Stage one day of matches
CALL SEED.STAGE_MATCHES_SUMMARY((SELECT CURRENT_LOAD_DATE FROM SEED.SEED_LOAD_STATE));

-- Refresh the matches pipe (must be in BRONZE context for pipe's internal resolution)
USE SCHEMA BRONZE;
ALTER PIPE BRONZE.MATCHES_SUMMARY_PP REFRESH;

USE SCHEMA SEED;

-- Advance load state to next date
UPDATE SEED.SEED_LOAD_STATE
   SET CURRENT_LOAD_DATE = (
           SELECT MAX(GAME_DATE_DAY)
           FROM SEED.SEED_MATCH_DATE_INDEX
           WHERE GAME_DATE_DAY < CURRENT_LOAD_DATE
       ),
       LAST_LOADED_AT = CURRENT_TIMESTAMP();


-------------------------------------------------------------------------------------------
-- 4. ACTIVATE BRONZE-TO-SILVER TASK (after data lands in bronze)
-------------------------------------------------------------------------------------------
ALTER TASK SILVER.BRONZE_TO_SILVER_MATCHES_TASK RESUME;
