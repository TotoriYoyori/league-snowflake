-- Test: seed matches_summary, activate task, and run one simulated daily load
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
-- 3. ACTIVATE BRONZE-TO-SILVER TASK
-------------------------------------------------------------------------------------------
ALTER TASK SILVER.BRONZE_TO_SILVER_MATCHES_TASK RESUME;


-------------------------------------------------------------------------------------------
-- 4. SIMULATE ONE DAILY LOAD (stages + refreshes pipe into bronze)
-------------------------------------------------------------------------------------------
CALL SEED.SIMULATE_DAILY_LOAD();
