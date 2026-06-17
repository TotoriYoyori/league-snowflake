-- Test pipeline: load seed data, stage to bronze, refresh pipe, and verify
-- Co-authored with CoCo
-------------------------------------------------------------------------------------------
-- TEST PIPELINE RUN
-- Run this AFTER uploading items_ref.csv to @TEST_PIPELINE_DB.SEED.SEED_UPLOAD_STG
-------------------------------------------------------------------------------------------
USE WAREHOUSE COMPUTE_WH;
USE DATABASE TEST_PIPELINE_DB;


-------------------------------------------------------------------------------------------
-- 1. COPY FROM SEED STAGE INTO SEED TABLE
-------------------------------------------------------------------------------------------
COPY INTO SEED.SEED_ITEMS_REF
    FROM @SEED.SEED_UPLOAD_STG/items_ref
    FILE_FORMAT = BRONZE.TEST_CSV_FMT;

SELECT 'SEED_ITEMS_REF' AS TABLE_NAME, COUNT(*) AS ROW_COUNT
FROM SEED.SEED_ITEMS_REF;


-------------------------------------------------------------------------------------------
-- 2. STAGE REFERENCE DATA FROM SEED → BRONZE STAGE (simulates SIMULATE_DAILY_LOAD)
-------------------------------------------------------------------------------------------
COPY INTO @BRONZE.REFERENCE_STG/items_ref.csv
FROM (SELECT ITEM_ID, ITEM_NAME FROM SEED.SEED_ITEMS_REF)
    FILE_FORMAT = (TYPE = CSV)
    OVERWRITE = TRUE
    SINGLE = TRUE
    HEADER = TRUE;


-------------------------------------------------------------------------------------------
-- 3. REFRESH PIPE TO LOAD INTO BRONZE TABLE
-------------------------------------------------------------------------------------------
ALTER PIPE BRONZE.ITEMS_REF_PP REFRESH;


-------------------------------------------------------------------------------------------
-- 4. VERIFY BRONZE TABLE (wait a few seconds for pipe to process, then run this)
-------------------------------------------------------------------------------------------
SELECT 'ITEMS_REF_BRONZE' AS TABLE_NAME, COUNT(*) AS ROW_COUNT
FROM BRONZE.ITEMS_REF_BRONZE;

SELECT * 
FROM BRONZE.ITEMS_REF_BRONZE 
LIMIT 10;
