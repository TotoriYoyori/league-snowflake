-- Test matches run: load seed, call simulate daily load, verify bronze ingestion
-- Co-authored with CoCo
-------------------------------------------------------------------------------------------
-- TEST MATCHES RUN
-- Run AFTER test_matches_setup.sql and uploading matches_summary.csv to SEED_UPLOAD_STG
-------------------------------------------------------------------------------------------
USE WAREHOUSE COMPUTE_WH;
USE DATABASE TEST_PIPELINE_DB;


-------------------------------------------------------------------------------------------
-- 1. COPY FROM SEED STAGE INTO SEED TABLE
-------------------------------------------------------------------------------------------
COPY INTO SEED.SEED_MATCHES_SUMMARY
    FROM @SEED.SEED_UPLOAD_STG/matches_summary
    FILE_FORMAT = BRONZE.TEST_CSV_FMT;

SELECT 'SEED_MATCHES_SUMMARY' AS TABLE_NAME, COUNT(*) AS ROW_COUNT
FROM SEED.SEED_MATCHES_SUMMARY;


-------------------------------------------------------------------------------------------
-- 2. VERIFY DATE INDEX (should show distinct dates available)
-------------------------------------------------------------------------------------------
SELECT GAME_DATE_DAY, COUNT(*) AS MATCHES
FROM SEED.SEED_MATCH_DATE_INDEX
GROUP BY GAME_DATE_DAY
ORDER BY GAME_DATE_DAY DESC
LIMIT 10;


-------------------------------------------------------------------------------------------
-- 3. RUN SIMULATE DAILY LOAD (processes one date, latest first)
-------------------------------------------------------------------------------------------
CALL SEED.TEST_SIMULATE_DAILY_LOAD();


-------------------------------------------------------------------------------------------
-- 4. VERIFY: Check load state advanced
-------------------------------------------------------------------------------------------
SELECT * FROM SEED.SEED_LOAD_STATE;


-------------------------------------------------------------------------------------------
-- 5. VERIFY: Check bronze table (wait a few seconds for pipe, then run)
-------------------------------------------------------------------------------------------
SELECT COUNT(*) AS BRONZE_ROW_COUNT FROM BRONZE.MATCHES_SUMMARY_BRONZE;
SELECT * FROM BRONZE.MATCHES_SUMMARY_BRONZE


-------------------------------------------------------------------------------------------
-- 6. (OPTIONAL) RUN AGAIN to load next date
-------------------------------------------------------------------------------------------
-- CALL SEED.TEST_SIMULATE_DAILY_LOAD();
-- SELECT * FROM SEED.SEED_LOAD_STATE;
-- SELECT COUNT(*) FROM BRONZE.MATCHES_SUMMARY_BRONZE;
